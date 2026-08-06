import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../data/calendar_repository.dart';
import '../../data/character_repository.dart';
import '../../data/combat_repository.dart';
import '../../data/db/character_tables.dart';
import '../../data/db/combat_tables.dart';
import '../../data/db/database.dart';
import '../../domain/models/ability.dart';
import '../../domain/rules/character_math.dart';
import '../../domain/rules/combat_conditions.dart';
import '../../domain/rules/dice.dart';
import 'package:path/path.dart' as p;

import '../../data/db/world_tables.dart';
import '../../data/loot_repository.dart';
import '../../data/notes_repository.dart';
import '../../data/party_inventory_repository.dart';
import '../../data/quest_repository.dart';
import '../../data/shop_repository.dart';
import '../../data/world_repository.dart';
import '../../net/player_app_handler.dart';
// Protokoldeki `MapView` Flutter'in widget'iyla ayni adda; onek zorunlu.
import '../../net/protocol.dart' as protocol;
import '../../net/protocol.dart';
import '../../net/table_server.dart';
import 'character_creation_service.dart';

/// DM onayi bekleyen bir satin alma.
class PendingPurchase {
  const PendingPurchase({
    required this.id,
    required this.player,
    required this.characterId,
    required this.characterName,
    required this.stockId,
    required this.itemName,
    required this.totalCp,
    required this.quantity,
  });

  final String id;
  final ConnectedPlayer player;
  final String characterId;
  final String characterName;
  final String stockId;
  final String itemName;
  final int totalCp;
  final int quantity;
}

/// Oyuncunun baska bir oyuncuya gonderdigi, alici onayi bekleyen aktarim.
///
/// Ya bir esya ([itemId] dolu) ya da para ([coinsCp] > 0). Kalici degil,
/// oturumla yasar; alici kabul edene kadar uygulanmaz.
class PendingTransfer {
  const PendingTransfer({
    required this.id,
    required this.fromToken,
    required this.fromCharacterId,
    required this.fromCharacterName,
    required this.toCharacterId,
    required this.toCharacterName,
    this.itemId,
    this.itemName = '',
    this.magic = false,
    this.quantity = 1,
    this.coinsCp = 0,
  });

  final String id;
  final String fromToken;
  final String fromCharacterId;
  final String fromCharacterName;
  final String toCharacterId;
  final String toCharacterName;

  /// Esya aktarimiysa gonderenin envanter satiri; para aktariminda null.
  final String? itemId;
  final String itemName;
  final bool magic;
  final int quantity;

  /// Para aktarimiysa miktar (cp); esya aktariminda 0.
  final int coinsCp;

  bool get isCoins => itemId == null;
}

/// LAN sunucusunu veritabanina baglar.
///
/// Sunucu saf kalsin diye tum veri erisimi burada: snapshot uretimi ve
/// oyuncu isteklerinin dogrulanmasi.
class SessionService {
  SessionService({
    required this.db,
    required this.characters,
    required this.combat,
    required this.shops,
    required this.world,
    DiceRoller? dice,
  }) : _dice = dice ?? DiceRoller();

  final AppDatabase db;
  final CharacterRepository characters;
  final CombatRepository combat;
  final ShopRepository shops;
  final WorldRepository world;

  /// Oyuncu notlari (karaktere bagli). Sunucu saf kalsin diye burada kuruluyor.
  late final NotesRepository notes = NotesRepository(db);

  /// Gorevler (DM gorevleri, oyunculara hedefli).
  late final QuestRepository quests = QuestRepository(db);

  /// Oyun-ici takvim; oyunculara yalnizca bicimlenmis GUNCEL TARIH gider
  /// (tarihce DM'de kalir).
  late final CalendarRepository calendar = CalendarRepository(db);

  /// Ortak parti keseleri; oyuncuya yalnizca UYE oldugu keseler gider.
  late final PartyInventoryRepository party = PartyInventoryRepository(db);

  TableServer? _server;
  TableServer? get server => _server;

  final DiceRoller _dice;

  /// Paylasilan zar gunlugu; en yeni en sonda. Oturumla yasar, saklanmaz.
  final _rolls = <protocol.DiceRoll>[];
  static const _maxRolls = 30;

  /// Su an oyunculara yansitilan karsilasma. DM secer; secilmezse oyuncular
  /// savas gormez.
  String? activeEncounterId;

  /// Su an oyunculara gosterilen harita.
  String? activeLocationId;

  /// Karakter sahiplikleri: karakter id -> oyuncu.
  ///
  /// Sunucunun baglanti listesinden turetmek yerine burada tutuluyor:
  /// dogrulama sunucudan bagimsiz calisabilmeli ve oyuncu karakter
  /// degistirdiginde eskisi serbest kalmali.
  final _claims = <String, ConnectedPlayer>{};

  /// DM onayi bekleyen satin almalar.
  ///
  /// Kalici degil, oturumla birlikte yasar: masada onaylanmayan istek
  /// sonraki oturuma tasinmamali.
  final _pendingPurchases = <PendingPurchase>[];
  final _pendingChanged = StreamController<void>.broadcast();

  /// Alici onayi bekleyen oyuncular-arasi aktarimlar (id -> teklif).
  final _pendingTransfers = <String, PendingTransfer>{};
  int _transferSeq = 0;

  /// Bekleyen aktarim teklifleri (test/tani icin).
  List<PendingTransfer> get pendingTransfers =>
      _pendingTransfers.values.toList();

  /// DM'in gordugu kisa aktivite bildirimleri (aktarim tamamlaninca vb.).
  /// Oturum sayfasi bunu SnackBar olarak gosteriyor.
  final _activity = StreamController<String>.broadcast();
  Stream<String> get activity => _activity.stream;

  /// Sohbet mesajlari (yalniz bellekte; oturum kapaninca kaybolur). DM host
  /// tarafinda oldugu icin bu liste tek dogru kaynaktir; oyunculara snapshot
  /// uzerinden oyuncu-basina suzulerek gider.
  final _chats = <ChatMessage>[];

  /// DM'in ACIK kisa dinlenmesine dahil karakterler.
  ///
  /// Oturum-ici anlik bir durum: kisa dinlenme masada birkac dakika surer,
  /// veritabanina yazmaya degmez (sohbet tamponuyla ayni gerekce). DM
  /// uygulamasi yeniden baslarsa dinlenme kapanir, DM yeniden acar.
  final _shortRest = <String>{};

  /// Kisa dinlenmeyi acar; oyuncular kendi panellerinden hit die harcar.
  /// Bos kume vermek dinlenmeyi KAPATIR.
  Future<void> setShortRest(Set<String> characterIds) async {
    _shortRest
      ..clear()
      ..addAll(characterIds);
    await broadcast();
  }

  Set<String> get shortRestCharacters => Set.unmodifiable(_shortRest);
  static const _maxChats = 100;
  int _chatSeq = 0;

  final _chatsChanged = StreamController<List<ChatMessage>>.broadcast();
  Stream<List<ChatMessage>> get chatMessages => _chatsChanged.stream;
  List<ChatMessage> get chats => List.unmodifiable(_chats);

  /// Bir oyuncunun gorebildigi sohbet mesajlari: genel (hedefsiz) + kendisine
  /// gelen ya da kendisinin gonderdigi fisiltilar. Karakter sahiplenmemis
  /// oyuncu (DM benzeri) her seyi gorur.
  Future<List<ChatMessage>> chatsFor(String? characterId) async {
    // characterId == null -> DM: her seyi gorur (DM'e ozel mesajlar dahil).
    if (characterId == null) return List.unmodifiable(_chats);
    return [
      for (final m in _chats)
        // DM'e ozel mesaji YALNIZCA gonderen oyuncu (ve DM) gorur.
        if (m.toDm
            ? m.fromCharacterId == characterId
            : (m.toCharacterId == null ||
                  m.toCharacterId == characterId ||
                  m.fromCharacterId == characterId))
          m,
    ];
  }

  /// DM'den sohbet gonderir. [toCharacterId] bossa genel, doluysa fisilti.
  Future<void> sendChatAsDm(String text, {String? toCharacterId}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await _appendChat(
      ChatMessage(
        id: 'dm${++_chatSeq}',
        fromName: 'DM',
        fromCharacterId: null,
        toCharacterId: toCharacterId,
        text: trimmed,
        seq: _chatSeq,
        isDm: true,
      ),
    );
  }

  Future<void> _appendChat(ChatMessage message) async {
    _chats.add(message);
    if (_chats.length > _maxChats) _chats.removeAt(0);
    _chatsChanged.add(List.unmodifiable(_chats));
    // Yeni mesaj snapshot'ta oyunculara gitsin (oyuncu-basina süzülür).
    await broadcast();
  }

  List<PendingPurchase> get pendingPurchases =>
      List.unmodifiable(_pendingPurchases);

  /// Bekleyen istek listesi degistikce tetiklenir.
  Stream<void> get pendingChanged => _pendingChanged.stream;

  StreamSubscription<void>? _dbWatch;
  Timer? _broadcastDebounce;

  Future<Uri> start() async {
    final existing = _server;
    if (existing != null && existing.isRunning) return existing.joinUri;
    _stopped = false;

    final server = TableServer(
      buildSnapshot: buildSnapshot,
      onClientMessage: handleClientMessage,
      questsFor: questViewsFor,
      chatsFor: chatsFor,
      partyInventoriesFor: partyInventoryViewsFor,
      // Oyuncu paneli APK'nin icinde gomulu; asset paketinden servis ediliyor.
      playerAppHandler: createPlayerAppHandler(),
      resolveMedia: resolveMedia,
    )..lanAddress = await findLanAddress();

    _server = server;

    // DM cihazda bir sey degistirdiginde (envanter, can, harita secimi,
    // magaza...) oyunculara ANLIK yansisin. Sunucu daha once yalnizca
    // oyuncudan mesaj gelince yayin yapiyordu; DM'in kendi degisiklikleri
    // yansimiyordu. Veritabani degisim akisini dinleyip yayinliyoruz.
    _dbWatch = db.tableUpdates().listen((_) => _scheduleBroadcast());

    return server.start();
  }

  /// Kisa araliktaki cok sayida yazmayi tek yayinda birlestir.
  ///
  /// Timer'in hatasi yutulur: kampanya degistirilirken (bkz. `CampaignRoot`)
  /// veritabani kapaniyor olabilir ve gec ates eden bir yayin, kimsenin
  /// dinlemedigi bir zone hatasina donusurdu.
  void _scheduleBroadcast() {
    _broadcastDebounce?.cancel();
    _broadcastDebounce = Timer(
      const Duration(milliseconds: 120),
      () => unawaited(broadcast().catchError((Object _) {})),
    );
  }

  Future<void> stop() async {
    _stopped = true;
    _broadcastDebounce?.cancel();
    await _dbWatch?.cancel();
    _dbWatch = null;
    await _server?.stop();
    _server = null;
  }

  /// `stop()` sonrasi yayin yapilmaz: sunucu kapandiktan sonra gelen her
  /// yayin kapali bir veritabanina sorgu atar (`StateError`).
  bool _stopped = false;

  Future<void> broadcast({String? notice}) {
    if (_stopped) return Future.value();
    return _server?.broadcast(notice: notice) ?? Future.value();
  }

  /// Cihazin yerel ag adresi.
  ///
  /// QR'a yazilacak adres bu; `localhost` yazarsak oyuncularin telefonu
  /// kendi kendine baglanmaya calisir. Wi-Fi arayuzu tercih edilir.
  static Future<String?> findLanAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      // Sanal adaptorler (VirtualBox, WSL, Hyper-V) once elenmeli, yoksa
      // oyuncularin ulasamayacagi bir adres yaziyoruz.
      const ignored = ['vethernet', 'virtualbox', 'vmware', 'loopback', 'wsl'];
      final candidates = [
        for (final i in interfaces)
          if (!ignored.any((x) => i.name.toLowerCase().contains(x)))
            for (final a in i.addresses)
              if (!a.isLoopback) a.address,
      ];
      // Ev aglarinda en yaygin araliklar once.
      candidates.sort((a, b) {
        int rank(String ip) =>
            ip.startsWith('192.168.') ? 0 : (ip.startsWith('10.') ? 1 : 2);
        return rank(a).compareTo(rank(b));
      });
      return candidates.firstOrNull;
    } on OSError {
      return null;
    }
  }

  /// Oyunculara yansitilan tam durumu uretir.
  Future<TableSnapshot> buildSnapshot() async {
    final rows = await db.select(db.characters).get();
    final claims = _claimsByCharacter();

    final views = <PlayerCharacterView>[];
    for (final c in rows) {
      final stats = await characters.buildFor(c.id);
      final slots = await characters.spellSlots(stats);
      final levels = await characters.classLevels(c.id);
      final profs = await characters.proficiencies(c.id);
      final known = await characters.knownSpells(c.id);
      final hitDice = await characters.hitDiceStatus(c.id);

      List<String> profOf(ProficiencyKind kind) => [
        for (final p in profs)
          if (p.kind == kind) p.value,
      ]..sort();

      views.add(
        PlayerCharacterView(
          id: c.id,
          name: c.name,
          hitPointsCurrent: c.hitPointsCurrent,
          hitPointsMax: c.hitPointsMax,
          temporaryHitPoints: c.temporaryHitPoints,
          deathSaveSuccesses: c.deathSaveSuccesses,
          deathSaveFailures: c.deathSaveFailures,
          armorClass: c.armorClassOverride ?? stats.armorClass,
          initiative: stats.initiative,
          level: stats.totalLevel,
          classLine: levels
              .map((l) => '${_shortClassName(l.classKey)} ${l.level}')
              .join(' / '),
          claimedBy: claims[c.id],
          spellSlots: slots,
          spentSlots: _spentSlots(c),
          abilityModifiers: {
            for (final a in Ability.values) a.short: stats.abilityModifier(a),
          },
          savingThrows: {
            for (final a in Ability.values) a.short: stats.savingThrow(a),
          },
          skills: {
            for (final s in Skill.values) s.label: stats.skillModifier(s),
          },
          proficiencyBonus: stats.proficiencyBonus,
          passivePerception: stats.passivePerception,
          coinsCp: c.coinsCp,
          inventory: await _inventoryOf(c.id),
          speciesName: await _speciesName(c.speciesKey),
          backgroundName: await _backgroundName(c.backgroundKey),
          alignment: c.alignment,
          weaponProficiencies: profOf(ProficiencyKind.weapon),
          armorProficiencies: profOf(ProficiencyKind.armor),
          toolProficiencies: profOf(ProficiencyKind.tool),
          languages: profOf(ProficiencyKind.language),
          notes: c.notes,
          appearance: c.appearance,
          personality: c.personality,
          ideal: c.ideal,
          bond: c.bond,
          flaw: c.flaw,
          portraitUrl: c.portraitPath == null
              ? null
              : '/media/${p.basename(c.portraitPath!)}',
          hitDiceTotal: hitDice.total,
          hitDiceUsed: hitDice.used,
          spells: [
            for (final s in known)
              protocol.PlayerSpellView(
                name: s.name,
                level: s.level,
                school: s.school,
                concentration: s.concentration,
                ritual: s.ritual,
                prepared: s.prepared,
                alwaysPrepared: s.alwaysPrepared,
              ),
          ],
        ),
      );
    }

    // Takvim henuz kurulmamissa (ay yoksa) tarih gonderilmez; oyuncu paneli
    // basligi sessizce gizler.
    final calendarSnap = await calendar.snapshot();
    final hasCalendar = calendarSnap.months.isNotEmpty;

    return TableSnapshot(
      characters: views,
      combat: await _buildCombatView(),
      shop: await _buildShopView(),
      mapShops: await _buildMapShops(),
      map: await _buildMapView(),
      maps: await _buildAccessibleMaps(),
      loot: _activeLoot,
      handout: _activeHandout,
      rolls: List.unmodifiable(_rolls),
      shortRestCharacterIds: List.unmodifiable(_shortRest),
      inGameDate: hasCalendar
          ? CalendarRepository.formatCurrent(calendarSnap)
          : null,
      inGameSeason: hasCalendar
          ? CalendarRepository.currentSeasonName(calendarSnap)
          : null,
    );
  }

  /// Paylasilan gunlukteki artan sira numarasi. Istemci "yeni atis"i ve kendi
  /// atisini bununla ayirt edip pop-up gosteriyor; gunluk 30'da kapansa da
  /// numara artmaya devam ettigi icin guvenilir.
  int _rollSeq = 0;

  /// Zar gunlugune ekler ve herkese yayinlar. DM kendi atislarini paylasmak
  /// isterse (or. gorunur bir yetenek atisi) bunu kullaniyor.
  Future<void> pushRoll(protocol.DiceRoll roll) async {
    _rolls.add(roll.withSeq(++_rollSeq));
    if (_rolls.length > _maxRolls) _rolls.removeAt(0);
    await broadcast();
  }

  // --- DM -> oyuncu anlik bildirimler --------------------------------------

  /// Oyuncu(lar)a bir mesaj/duyuru gonderir; ekranda pop-up cikar.
  /// [characterId] verilirse yalnizca o oyuncuya, yoksa herkese.
  Future<void> announce(String text, {String? characterId}) async {
    _server?.pushToPlayers(
      ServerMessage(type: ServerMessageType.announcement, text: text),
      characterId: characterId,
    );
  }

  int _saveSeq = 0;

  /// Kurtarma atisi ister. Oyuncunun panelinde "DC X yetenek at" komutu
  /// cikar; oyuncu atinca sonuc paylasilan gunluge duser.
  Future<void> requestSave({
    required String ability,
    required int dc,
    String? characterId,
  }) async {
    _server?.pushToPlayers(
      ServerMessage(
        type: ServerMessageType.saveRequest,
        payload: {'ability': ability, 'dc': dc, 'id': '${++_saveSeq}'},
      ),
      characterId: characterId,
    );
  }

  // --- Ganimet -------------------------------------------------------------

  LootView? _activeLoot;
  int _lootSeq = 0;

  /// Oyunculara ganimet sunar (esyalar + para). [targetCharacterId] verilirse
  /// yalnizca o oyuncu gorur/alir.
  Future<void> giveLoot({
    int coinsCp = 0,
    List<({String name, bool magic})> items = const [],
    String? targetCharacterId,
  }) async {
    final seq = ++_lootSeq;
    _activeLoot = LootView(
      id: '$seq',
      coinsCp: coinsCp,
      items: [
        for (final (i, item) in items.indexed)
          LootItemView(id: 'loot${seq}_$i', name: item.name, magic: item.magic),
      ],
      targetCharacterId: targetCharacterId,
    );
    await broadcast();
  }

  Future<void> clearLoot() async {
    _activeLoot = null;
    await broadcast();
  }

  // --- Handout (gorsel paylasimi) ------------------------------------------

  HandoutView? _activeHandout;
  int _handoutSeq = 0;

  HandoutView? get activeHandout => _activeHandout;

  /// Oyunculara harita disi bir gorsel gosterir (mektup, NPC portresi, ipucu).
  /// Gorsel portre klasorune kopyalanip `/media` ile sunulur; DM temizleyene
  /// kadar snapshot'ta kalir.
  Future<void> showHandout({required File image, String? caption}) async {
    final stored = await characters.portraits.store(image);
    final seq = ++_handoutSeq;
    final trimmed = caption?.trim();
    _activeHandout = HandoutView(
      id: '$seq',
      url: '/media/${p.basename(stored)}',
      caption: trimmed == null || trimmed.isEmpty ? null : trimmed,
    );
    await broadcast();
  }

  /// Oyunculara metin handout'u gonderir (AI ureteclerinden gorev metni gibi).
  /// Gorsel yok; oyuncu panelinde pop-up olarak okunur.
  Future<void> showHandoutText({required String text, String? caption}) async {
    final seq = ++_handoutSeq;
    final trimmedCaption = caption?.trim();
    _activeHandout = HandoutView(
      id: '$seq',
      text: text,
      caption: trimmedCaption == null || trimmedCaption.isEmpty
          ? null
          : trimmedCaption,
    );
    await broadcast();
  }

  Future<void> clearHandout() async {
    _activeHandout = null;
    await broadcast();
  }

  /// Eski tekil "aktif harita" alani. Gorunurluk artik lokasyon bazli
  /// (revealed) oldugu icin kullanilmiyor; oyuncu paneli [_buildAccessibleMaps]
  /// listesini kullaniyor. Geriye donuk uyumluluk icin null donuyor.
  Future<protocol.MapView?> _buildMapView() async => null;

  /// Oyuncunun gorebilecegi haritalarin lokasyon id'leri: DM'in "Oyunculara
  /// göster" (revealed) yaptigi, haritasi olan ve TUM ust zinciri de gorunur
  /// olan lokasyonlar. Ust yer gorunmeden alt yer (gorunur olsa bile) gozukmez;
  /// gizlilik burada belirlenir.
  Future<Set<String>> _accessibleMapLocationIds() async {
    final all = await db.select(db.locations).get();
    final byId = {for (final l in all) l.id: l};

    bool chainRevealed(Location start) {
      var current = start;
      final seen = <String>{};
      while (seen.add(current.id)) {
        if (!current.revealed) return false;
        final parentId = current.parentId;
        if (parentId == null) return true;
        final parent = byId[parentId];
        if (parent == null) return true; // kopuk zincir: kok say
        current = parent;
      }
      return true; // dongusel veri: sonsuz donme
    }

    return {
      for (final l in all)
        if (l.mapPreviewPath != null && chainRevealed(l)) l.id,
    };
  }

  /// Haritadan erisilebilir magaza id'leri.
  Future<Set<String>> _mapAccessibleShopIds() async =>
      (await shops.mapAccessibleShops()).map((s) => s.id).toSet();

  /// Oyuncunun gezebilecegi tum haritalar (gorunur yapilmis her yer).
  Future<List<protocol.MapView>> _buildAccessibleMaps() async {
    final ids = await _accessibleMapLocationIds();
    final shopIds = await _mapAccessibleShopIds();
    final maps = <protocol.MapView>[];
    for (final locationId in ids) {
      final location = await world.find(locationId);
      if (location == null) continue;
      maps.add(await _mapViewFor(location, ids, shopIds));
    }
    return maps;
  }

  /// Tek bir lokasyonu oyuncu gozuyle haritaya cevirir. [accessible] location
  /// pinlerin, [accessibleShops] shop pinlerin oyuncu icin tiklanabilir olup
  /// olmadigini belirler.
  Future<protocol.MapView> _mapViewFor(
    Location location,
    Set<String> accessible,
    Set<String> accessibleShops,
  ) async {
    final preview = location.mapPreviewPath;
    final pins = await world.pins(location.id);
    final width = location.mapWidth;
    final height = location.mapHeight;

    return protocol.MapView(
      locationId: location.id,
      locationName: location.name,
      description: location.description,
      parentLocationId: location.parentId,
      imageUrl: preview == null ? null : '/media/${p.basename(preview)}',
      aspectRatio: (width != null && height != null && height > 0)
          ? width / height
          : 1,
      pins: [
        for (final pin in pins)
          if (_pinVisibleToPlayers(pin, accessible, accessibleShops))
            _mapPinViewFor(pin),
      ],
    );
  }

  /// Tek bir pini oyuncu gozuyle olusturur. Hazine pinlerinde kalan ganimet
  /// (para + esyalar) de gonderilir -- oyuncu bunlari gorur ve alir.
  protocol.MapPinView _mapPinViewFor(MapPin pin) {
    final loot = pin.kind == PinKind.treasure
        ? LootRepository.pinLootOf(pin.lootDataJson)
        : null;
    return protocol.MapPinView(
      id: pin.id,
      kind: pin.kind.name,
      label: pin.label,
      x: pin.x,
      y: pin.y,
      // Not metni yalnizca not/hazine pinlerinde gonderilir.
      note: pin.kind == PinKind.note || pin.kind == PinKind.treasure
          ? pin.noteText
          : '',
      // Location/shop pinleri gorunuyorsa zaten erisilebilir; hedefi ver.
      targetLocationId: pin.kind == PinKind.location ? pin.targetId : null,
      targetShopId: pin.kind == PinKind.shop ? pin.targetId : null,
      lootCoinsCp: loot?.coinsCp,
      lootItems: loot == null
          ? null
          : [
              for (final i in loot.items)
                protocol.LootItemView(id: i.id, name: i.name, magic: i.magic),
            ],
    );
  }

  /// Bir pin oyuncu haritasinda gorunmeli mi?
  ///
  /// LOCATION/SHOP pinleri "aksiyonlu": yalnizca hedefi ERISILEBILIRSE gorunur
  /// (kapali yerin/dukkanin pini hic cizilmez; acilinca pini de otomatik cikar).
  /// Bilgilendirici pinler (not, npc, karsilasma, hazine) pin.revealed'a bagli.
  bool _pinVisibleToPlayers(
    MapPin pin,
    Set<String> accessible,
    Set<String> accessibleShops,
  ) {
    switch (pin.kind) {
      case PinKind.location:
        return pin.targetId != null && accessible.contains(pin.targetId);
      case PinKind.shop:
        return pin.targetId != null && accessibleShops.contains(pin.targetId);
      case PinKind.note:
      case PinKind.npc:
      case PinKind.encounter:
      case PinKind.treasure:
        return pin.revealed;
    }
  }

  /// Sunucunun harita gorsellerini ve karakter portrelerini cozmesi icin.
  /// `/media/<ad>` yolu duz oldugu icin once haritalarda, sonra portrelerde
  /// aranir.
  Future<File?> resolveMedia(String name) async {
    final map = await world.images.resolve(p.join('maps', name));
    if (map.existsSync()) return map;
    // Portre klasoru cozulemezse (or. dizin yoksa) medya servisi cokmesin.
    try {
      final portrait = await characters.portraits.resolve(
        p.join('portraits', name),
      );
      return portrait.existsSync() ? portrait : null;
    } on Object {
      return null;
    }
  }

  /// Tur/background adini kutuphaneden okur (kagit gosterimi icin).
  Future<String?> _speciesName(String? key) async {
    if (key == null) return null;
    final row = await (db.select(
      db.speciesEntries,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.name;
  }

  Future<String?> _backgroundName(String? key) async {
    if (key == null) return null;
    final row = await (db.select(
      db.backgrounds,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.name;
  }

  /// Acik magazayi oyuncu gozuyle hazirlar.
  Future<ShopView?> _buildShopView() async {
    final shop = await shops.openShop();
    if (shop == null) return null;
    return _shopViewOf(shop);
  }

  /// Haritadan erisilebilir yapilmis tum magazalar (dukkan pininden acilir).
  Future<List<ShopView>> _buildMapShops() async => [
    for (final shop in await shops.mapAccessibleShops())
      await _shopViewOf(shop),
  ];

  /// Bir magazayi oyuncu gozuyle ShopView'e cevirir.
  Future<ShopView> _shopViewOf(Shop shop) async {
    final entries = await shops.entries(shop.id);
    return ShopView(
      id: shop.id,
      name: shop.name,
      ownerName: shop.ownerName,
      description: shop.description,
      requiresApproval: shop.requiresApproval,
      closed: shop.closed,
      items: [
        for (final e in entries)
          ShopItemView(
            stockId: e.stock.id,
            name: e.name,
            priceCp: e.priceCp,
            description: e.description,
            category: e.category,
            rarity: e.rarity,
            requiresAttunement: e.requiresAttunement,
            quantity: e.stock.quantity,
          ),
      ],
    );
  }

  /// Oyunculara yansitilacak karsilasma. DM elle bir sey secmez: baslamis
  /// (started) karsilasma otomatik gosterilir, savas bitince kendiliginden
  /// kapanir. [activeEncounterId] yalnizca testlerde/gelecekte elle ezmek icin.
  Future<String?> _activeEncounterId() async =>
      activeEncounterId ?? (await combat.startedEncounter())?.id;

  Future<CombatView?> _buildCombatView() async {
    final id = await _activeEncounterId();
    if (id == null) return null;

    final encounter = await (db.select(
      db.encounters,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (encounter == null) return null;

    final rows = await combat.combatants(id);
    // DM'in gizledigi katilimcilar listeye hic girmez.
    final visible = rows.where((c) => !c.hiddenFromPlayers).toList();

    // Portre yollari tek seferde: oyuncu karakterleri + canavarlar. Ayni
    // canavardan birden fazla olabilir (Goblin 1/2/3), tekil anahtarla cekilir.
    final characterIds = visible
        .map((c) => c.characterId)
        .whereType<String>()
        .toSet();
    final monsterKeys = visible
        .map((c) => c.monsterKey)
        .whereType<String>()
        .toSet();
    final charPortraits = <String, String?>{};
    if (characterIds.isNotEmpty) {
      final crows = await (db.select(
        db.characters,
      )..where((t) => t.id.isIn(characterIds.toList()))).get();
      for (final cr in crows) {
        charPortraits[cr.id] = cr.portraitPath;
      }
    }
    final monsterPortraits = <String, String?>{};
    if (monsterKeys.isNotEmpty) {
      final mrows = await (db.select(
        db.monsters,
      )..where((t) => t.key.isIn(monsterKeys.toList()))).get();
      for (final mr in mrows) {
        monsterPortraits[mr.key] = mr.portraitPath;
      }
    }

    String? portraitFor(Combatant c) {
      final path = c.characterId != null
          ? charPortraits[c.characterId]
          : (c.monsterKey != null ? monsterPortraits[c.monsterKey] : null);
      return path == null ? null : '/media/${p.basename(path)}';
    }

    return CombatView(
      encounterName: encounter.name,
      round: encounter.round,
      started: encounter.started,
      activeCombatantId:
          encounter.started && encounter.activeIndex < rows.length
          ? rows[encounter.activeIndex].id
          : null,
      combatants: [
        for (final c in visible)
          CombatantView(
            id: c.id,
            name: c.name,
            initiative: c.initiative,
            isPlayer: c.kind == CombatantKind.player,
            initiativeRolled: c.initiativeRolled,
            defeated: c.defeated,
            characterId: c.characterId,
            // Canavarlarin kesin cani gizli: oyuncular sayidan okuyup
            // taktik kurmasin diye kaba bir etiket gonderiliyor.
            healthLabel: c.kind == CombatantKind.player
                ? null
                : _healthLabel(c),
            // Oyunculara yalnizca durum adlari gider (sure DM'e ozel).
            conditions: [
              for (final cond in parseConditions(c.conditionsJson)) cond.name,
            ],
            portraitUrl: portraitFor(c),
          ),
      ],
    );
  }

  /// Oyuncudan gelen istegi dogrular ve uygular.
  ///
  /// Kural: bir oyuncu yalnizca sahiplendigi karakteri degistirebilir.
  /// Hata metni donerse istek reddedilmis demektir.
  Future<String?> handleClientMessage(
    ConnectedPlayer player,
    ClientMessage message,
  ) async {
    switch (message.type) {
      case ClientMessageType.join:
        return null;

      case ClientMessageType.requestCreationOptions:
        // Katalog YALNIZ isteyen sokete gider; tum masaya yayinlamanin
        // anlami yok (kilobaytlarca sinif/gecmis verisi).
        final options = await CharacterCreationService(db).options();
        server?.pushToPlayers(
          ServerMessage(
            type: ServerMessageType.creationOptions,
            payload: options,
          ),
          token: player.token,
        );
        return null;

      case ClientMessageType.createCharacter:
        final draft = message.creation;
        if (draft == null) return encodeServerMsg('needName');
        try {
          final id = await CharacterCreationService(db).create(draft);
          // Olusturan oyuncu karakteri dogrudan sahiplenir: ayri bir
          // "sahiplen" adimi beklemek anlamsiz olurdu.
          _claims.removeWhere((_, p) => p.token == player.token);
          _claims[id] = player;
          player.characterId = id;
          _activity.add(
            encodeServerMsg('characterCreated', [
              player.name,
              '${draft['name']}',
            ]),
          );
          return null;
        } on CreationRejected catch (e) {
          return encodeServerMsg(e.code);
        }

      case ClientMessageType.claimCharacter:
        final characterId = message.characterId;
        if (characterId == null) return 'Karakter belirtilmedi.';

        final holder = _claims[characterId];
        if (holder != null && holder.token != player.token) {
          return encodeServerMsg('claimedBy', [holder.name]);
        }

        // Oyuncu baska bir karakteri birakiyorsa o serbest kalsin.
        _claims.removeWhere((_, p) => p.token == player.token);
        _claims[characterId] = player;
        player.characterId = characterId;
        return null;

      case ClientMessageType.updateHitPoints:
        final target = player.characterId;
        if (target == null) return encodeServerMsg('needCharacter');
        final amount = message.amount ?? 0;
        if (amount == 0) return null;

        if (amount < 0) {
          await characters.applyDamage(target, -amount);
        } else {
          await characters.applyHealing(target, amount);
        }
        // Savasta da ayni karakter varsa listedeki cani da guncelle.
        await _syncCombatantHitPoints(target);
        return null;

      case ClientMessageType.setSpentSlots:
        final target = player.characterId;
        if (target == null) return encodeServerMsg('needCharacter');
        await characters.setSpentSlots(target, message.spentSlots ?? const {});
        return null;

      case ClientMessageType.buyItem:
        return _handlePurchase(player, message);

      case ClientMessageType.rollInitiative:
        final target = player.characterId;
        if (target == null) return encodeServerMsg('needCharacter');
        final encounterId = await _activeEncounterId();
        if (encounterId == null) return encodeServerMsg('noActiveCombat');

        final rows = await combat.combatants(encounterId);
        final row = rows.where((c) => c.characterId == target).firstOrNull;
        if (row == null) return encodeServerMsg('notInCombat');

        // Zar sunucuda: d20 + karakterin inisiyatif modifiyesi. Sonuc
        // paylasilan gunluge duser (DM gorur) ve katilimci siraya oturur.
        final stats = await characters.buildFor(target);
        final roll = _dice.roll(
          sides: 20,
          modifier: stats.initiative,
          label: message.rollLabel ?? 'Initiative',
          source: player.name,
        );
        await combat.setInitiative(row.id, roll.total);
        await pushRoll(roll);
        return null;

      case ClientMessageType.rollDeathSave:
        final target = player.characterId;
        if (target == null) return encodeServerMsg('needCharacter');
        final c = await characters.find(target);
        // Yalnizca serilmis (0 HP) bir karakter olum kurtarmasi atar.
        if (c == null || c.hitPointsCurrent > 0) {
          return encodeServerMsg('notDying');
        }

        // Zar sunucuda atilir; herkes ayni dogal d20'yi gorsun diye gunluge
        // dusuruluyor.
        final roll = _dice.roll(
          sides: 20,
          label: message.rollLabel ?? 'Death save',
          source: player.name,
        );
        final natural = roll.results.first;

        if (natural == 20) {
          // Dogal 20: 1 HP ile ayaga kalkar. applyHealing sayaclari sifirlar.
          await characters.applyHealing(target, 1);
          await _syncCombatantHitPoints(target);
        } else {
          var successes = c.deathSaveSuccesses;
          var failures = c.deathSaveFailures;
          if (natural == 1) {
            failures += 2; // Dogal 1 iki basarisizlik sayilir.
          } else if (natural >= 10) {
            successes += 1;
          } else {
            failures += 1;
          }
          await characters.setDeathSaves(
            target,
            successes: successes > 3 ? 3 : successes,
            failures: failures > 3 ? 3 : failures,
          );
        }
        await pushRoll(roll);
        return null;

      case ClientMessageType.rollDice:
        // Zar sunucuda atiliyor: kimse tarayicidan sonuc uyduramasin, ve
        // herkes ayni sonucu gorsun.
        final roll = _dice.roll(
          sides: message.diceSides ?? 20,
          count: message.diceCount ?? 1,
          modifier: message.amount ?? 0,
          label: message.rollLabel ?? 'Zar',
          source: player.name,
        );
        await pushRoll(roll);
        return null;

      case ClientMessageType.inventoryChange:
        final target = player.characterId;
        if (target == null) return encodeServerMsg('needCharacter');
        final itemId = message.itemId;
        if (itemId == null) return encodeServerMsg('itemNotSpecified');

        // Yalnizca kendi karakterinin esyasina dokunabilir.
        final owned = await characters.items(target);
        final item = owned.where((i) => i.id == itemId).firstOrNull;
        if (item == null) return encodeServerMsg('itemNotYours');

        switch (message.inventoryAction ?? InventoryAction.toggleEquipped) {
          case InventoryAction.toggleEquipped:
            await characters.setEquipped(itemId, !item.equipped);
          case InventoryAction.drop:
            await characters.setItemQuantity(itemId, item.quantity - 1);
        }
        return null;

      case ClientMessageType.spendHitDie:
        return _handleSpendHitDie(player);

      case ClientMessageType.takeLoot:
        final target = player.characterId;
        if (target == null) return encodeServerMsg('needCharacter');
        final loot = _activeLoot;
        if (loot == null) return 'Ortada ganimet yok.';
        if (loot.targetCharacterId != null &&
            loot.targetCharacterId != target) {
          return encodeServerMsg('lootNotYours');
        }

        final lootItemId = message.lootItemId;
        if (lootItemId != null) {
          final item = loot.items.where((i) => i.id == lootItemId).firstOrNull;
          if (item == null) return encodeServerMsg('itemGone');
          await characters.addItem(characterId: target, customName: item.name);
          _activeLoot = LootView(
            id: loot.id,
            coinsCp: loot.coinsCp,
            items: [
              for (final i in loot.items)
                if (i.id != lootItemId) i,
            ],
            targetCharacterId: loot.targetCharacterId,
          );
        } else {
          if (loot.coinsCp <= 0) return encodeServerMsg('noMoneyLeft');
          final character = await characters.find(target);
          if (character != null) {
            await characters.setCoins(target, character.coinsCp + loot.coinsCp);
          }
          _activeLoot = LootView(
            id: loot.id,
            coinsCp: 0,
            items: loot.items,
            targetCharacterId: loot.targetCharacterId,
          );
        }
        // Ganimet bittiyse kapat.
        if (_activeLoot!.items.isEmpty && _activeLoot!.coinsCp <= 0) {
          _activeLoot = null;
        }
        return null;

      case ClientMessageType.takeTreasureLoot:
        return _handleTakeTreasureLoot(player, message);

      case ClientMessageType.takeAllTreasureLoot:
        return _handleTakeAllTreasureLoot(player, message);

      case ClientMessageType.saveNotes:
        final target = player.characterId;
        if (target == null) return encodeServerMsg('needCharacter');
        await notes.setFor(target, message.notes ?? const []);
        return null;

      case ClientMessageType.requestNotes:
        final target = player.characterId;
        // Karakter secilmemisse sessizce yok say (hata degil).
        if (target == null) return null;
        await _pushNotes(target);
        return null;

      case ClientMessageType.offerTransfer:
        return _handleOfferTransfer(player, message);

      case ClientMessageType.respondTransfer:
        return _handleRespondTransfer(player, message);

      case ClientMessageType.respondQuest:
        return _handleRespondQuest(player, message);

      case ClientMessageType.takeQuestReward:
        return _handleTakeQuestReward(player, message);

      case ClientMessageType.takeAllQuestReward:
        return _handleTakeAllQuestReward(player, message);

      case ClientMessageType.sendChat:
        return _handleSendChat(player, message);

      case ClientMessageType.takePartyItem:
        return _handleTakePartyItem(player, message);

      case ClientMessageType.takePartyCoins:
        return _handleTakePartyCoins(player, message);

      case ClientMessageType.depositPartyItem:
        return _handleDepositPartyItem(player, message);

      case ClientMessageType.depositPartyCoins:
        return _handleDepositPartyCoins(player, message);

      // Varlik durumu TableServer katmaninda islenir; buraya dusmez.
      case ClientMessageType.setPresence:
        return null;
    }
  }

  // --- Kisa dinlenme -------------------------------------------------------

  /// Oyuncu acik kisa dinlenmede bir hit die harcar.
  ///
  /// Hit die'i DM DEGIL oyuncunun kendisi harcar; DM yalnizca dinlenmeyi
  /// acar. Atis paylasilan zar gunluguine `source = oyuncu adi` ile dusuyor
  /// — oyuncu panelindeki "kendi atisim" pop-up'i bunu yakalayip zarin kendi
  /// 3B animasyonunu oynatiyor, ayri bir mesaj tipine gerek kalmiyor.
  Future<String?> _handleSpendHitDie(ConnectedPlayer player) async {
    final target = player.characterId;
    if (target == null) return encodeServerMsg('needCharacter');
    // Dinlenmeyi DM acar: davetsiz harcama kabul edilmez.
    if (!_shortRest.contains(target)) {
      return encodeServerMsg('noShortRest');
    }

    final spend = await characters.spendHitDie(target);
    if (spend == null) return encodeServerMsg('noHitDiceLeft');
    await _syncCombatantHitPoints(target);

    await pushRoll(
      protocol.DiceRoll(
        // Duz metin: zar gunlugundeki etiket oldugu gibi gosteriliyor,
        // kodlanmis sunucu mesajlarindan gecmiyor. "Hit Die" zaten iki dilde
        // de Ingilizce kalan bir oyun terimi.
        label: 'Hit Die',
        sides: spend.sides,
        count: 1,
        modifier: spend.conModifier,
        results: [spend.roll],
        total: spend.roll + spend.conModifier,
        source: player.name,
      ),
    );
    return null;
  }

  // --- Sohbet --------------------------------------------------------------

  /// Oyuncudan gelen sohbet mesajini dogrular, bellekte saklar ve yayinlar.
  /// [toCharacterId] bossa genel (herkes + DM gorur), doluysa fisilti
  /// (yalniz alici + gonderen + DM gorur). Bos mesaj sessizce yok sayilir.
  Future<String?> _handleSendChat(
    ConnectedPlayer player,
    ClientMessage message,
  ) async {
    final text = message.chatText?.trim();
    if (text == null || text.isEmpty) return null;

    _appendChat(
      ChatMessage(
        id: 'c${++_chatSeq}',
        fromName: player.name,
        fromCharacterId: player.characterId,
        toCharacterId: message.toCharacterId,
        toDm: message.toDm,
        text: text,
        seq: _chatSeq,
      ),
    );
    return null;
  }

  // --- Gorevler ------------------------------------------------------------

  /// Verilen karakterin UYE oldugu ortak keseler.
  ///
  /// Uye olmadigi kese hic gonderilmez (varligindan bile haberi olmaz).
  /// Katalog anahtarlari da gitmez; oyuncu esyayi kalici uuid ile alir.
  Future<List<protocol.PartyInventoryView>> partyInventoryViewsFor(
    String? characterId,
  ) async {
    if (characterId == null) return const [];
    final all = await party.all();
    return [
      for (final inv in all)
        if (PartyInventoryRepository.membersOf(inv).contains(characterId))
          protocol.PartyInventoryView(
            id: inv.id,
            name: inv.name,
            coinsCp: inv.coinsCp,
            items: [
              for (final i in PartyInventoryRepository.itemsOf(inv))
                protocol.PartyItemView(
                  id: i.id,
                  name: i.name,
                  magic: i.magic,
                  quantity: i.quantity,
                ),
            ],
          ),
    ];
  }

  /// Verilen karakteri sahiplenen oyuncuya gosterilecek gorevler (paylasilmis,
  /// tamamlanmamis, hedefinde bu karakter olanlar). Oyuncuya yalniz kendi
  /// durumu (myStatus) tasinir; DM notu/hedefler/baskalarinin kararlari GITMEZ.
  Future<List<protocol.QuestView>> questViewsFor(String? characterId) async {
    if (characterId == null) return const [];
    final all = await quests.all();
    final views = <protocol.QuestView>[];
    for (final q in all) {
      if (!QuestRepository.targetsOf(q).contains(characterId)) continue;
      final accepted = QuestRepository.acceptancesOf(q)[characterId];
      final pool = QuestRepository.poolOf(q);

      if (q.done) {
        // Tamamlanan gorev yalnizca ODUL HAVUZU acikken ve YALNIZCA gorevi
        // kabul etmis oyunculara gorunur; havuz bosalinca gorev zaten silinir.
        if (pool == null || accepted != true) continue;
        views.add(
          protocol.QuestView(
            id: q.id,
            title: q.title,
            text: q.questText,
            reward: q.reward,
            myStatus: 'accepted',
            mode: q.shareMode,
            voteStatus: q.voteStatus.isEmpty ? null : q.voteStatus,
            rewardReady: true,
            rewardCoinsCp: pool.coinsCp,
            rewardItems: [
              for (final i in pool.items)
                protocol.LootItemView(id: i.id, name: i.name, magic: i.magic),
            ],
          ),
        );
        continue;
      }

      // Basarisiz oylama: gorev kimseye verilmez, oyuncudan da kaybolur.
      if (!q.shared || q.voteStatus == QuestRepository.voteFailed) continue;
      views.add(
        protocol.QuestView(
          id: q.id,
          title: q.title,
          text: q.questText,
          reward: q.reward,
          myStatus: accepted == null
              ? null
              : (accepted ? 'accepted' : 'rejected'),
          mode: q.shareMode,
          voteStatus: q.voteStatus.isEmpty ? null : q.voteStatus,
        ),
      );
    }
    return views;
  }

  /// Oyuncu bir gorevi kabul/reddeder. Kimlik `player.characterId` ile
  /// dogrulanir (mesaj govdesine guvenilmez); karar DB'ye yazilir, DM gorur.
  Future<String?> _handleRespondQuest(
    ConnectedPlayer player,
    ClientMessage message,
  ) async {
    final id = message.questId;
    final characterId = player.characterId;
    if (id == null || characterId == null) return null;
    final quest = await quests.find(id);
    if (quest == null || !quest.shared || quest.done) return null;
    final targets = QuestRepository.targetsOf(quest);
    if (!targets.contains(characterId)) {
      return encodeServerMsg('offerNotForYou');
    }
    // Oylama bittiyse karar degistirilemez.
    final voting = quest.shareMode == QuestRepository.modeVote;
    if (voting && quest.voteStatus != QuestRepository.votePending) return null;

    final accept = message.accept ?? false;
    await quests.setAcceptance(id, characterId, accept);
    final character = await characters.find(characterId);
    final name = character?.name ?? characterId;
    final title = quest.title.isEmpty ? '(görev)' : quest.title;
    _activity.add('$name: $title — ${accept ? 'kabul' : 'ret'}');

    if (voting) await _resolveQuestVoteIfDecided(id, targets);
    return null;
  }

  /// Oylamayi matematiksel olarak kesinlestigi anda sonuclandirir: kabul
  /// oylari hedeflerin %50'sine ULASTIYSA gorev HERKESE verilir, ret oylari
  /// %50'yi GECTIYSE kimse alamaz. Boylece oy vermeyen birini beklemek
  /// gerekmez (sonucu degistiremeyecegi an karar verilir).
  Future<void> _resolveQuestVoteIfDecided(
    String questId,
    List<String> targets,
  ) async {
    if (targets.isEmpty) return;
    final quest = await quests.find(questId);
    if (quest == null) return;
    final votes = QuestRepository.acceptancesOf(quest);
    var accepts = 0;
    var rejects = 0;
    for (final t in targets) {
      switch (votes[t]) {
        case true:
          accepts++;
        case false:
          rejects++;
        case null:
          break;
      }
    }
    final total = targets.length;
    final title = quest.title.isEmpty ? '(görev)' : quest.title;
    if (accepts * 2 >= total) {
      await quests.resolveVote(questId, passed: true);
      _activity.add('$title — oylama geçti ($accepts/$total)');
    } else if (rejects * 2 > total) {
      await quests.resolveVote(questId, passed: false);
      _activity.add('$title — oylama düştü ($accepts/$total)');
    }
  }

  /// Tamamlanan bir gorevin ortak odul havuzundan tek esya ya da parayi alir.
  /// Havuzu YALNIZCA gorevi kabul etmis hedefler acabilir; havuz bosalinca
  /// gorev tablodan silinir.
  Future<String?> _handleTakeQuestReward(
    ConnectedPlayer player,
    ClientMessage message,
  ) async {
    final target = player.characterId;
    if (target == null) return encodeServerMsg('needCharacter');
    final questId = message.questId;
    if (questId == null) return null;
    final quest = await quests.find(questId);
    if (quest == null) return encodeServerMsg('noLoot');
    if (!QuestRepository.targetsOf(quest).contains(target) ||
        QuestRepository.acceptancesOf(quest)[target] != true ||
        !quest.done) {
      return encodeServerMsg('offerNotForYou');
    }

    final result = await quests.takeReward(questId, itemId: message.lootItemId);
    if (result.error != null) return encodeServerMsg(result.error!);

    if (message.lootItemId != null) {
      if (result.takenName != null) {
        await characters.addItem(
          characterId: target,
          customName: result.takenName!,
        );
      }
    } else if (result.takenCoinsCp > 0) {
      final character = await characters.find(target);
      if (character != null) {
        await characters.setCoins(
          target,
          character.coinsCp + result.takenCoinsCp,
        );
      }
    }
    await broadcast();
    return null;
  }

  /// Odul havuzunda kalan TUM ganimeti tek islemde alir; gorev silinir.
  Future<String?> _handleTakeAllQuestReward(
    ConnectedPlayer player,
    ClientMessage message,
  ) async {
    final target = player.characterId;
    if (target == null) return encodeServerMsg('needCharacter');
    final questId = message.questId;
    if (questId == null) return null;
    final quest = await quests.find(questId);
    if (quest == null) return encodeServerMsg('noLoot');
    if (!QuestRepository.targetsOf(quest).contains(target) ||
        QuestRepository.acceptancesOf(quest)[target] != true ||
        !quest.done) {
      return encodeServerMsg('offerNotForYou');
    }

    final result = await quests.takeAllReward(questId);
    if (result.error != null) return encodeServerMsg(result.error!);

    for (final item in result.items) {
      await characters.addItem(characterId: target, customName: item.name);
    }
    if (result.coinsCp > 0) {
      final character = await characters.find(target);
      if (character != null) {
        await characters.setCoins(target, character.coinsCp + result.coinsCp);
      }
    }
    await broadcast();
    return null;
  }

  // --- Oyuncular arasi esya/para gonderme ----------------------------------

  /// Bir oyuncunun baska bir oyuncuya gonderme teklifi. Dogrulanip alicinin
  /// soketine push edilir; asil aktarim alici kabul edince olur.
  Future<String?> _handleOfferTransfer(
    ConnectedPlayer player,
    ClientMessage message,
  ) async {
    final from = player.characterId;
    if (from == null) return encodeServerMsg('needCharacter');
    final toId = message.toCharacterId;
    if (toId == null) return encodeServerMsg('recipientNotSpecified');
    if (toId == from) return encodeServerMsg('cantSendToSelf');

    // Alici masada (bir oyuncu tarafindan sahiplenilmis) olmali.
    if (_claims[toId] == null) return encodeServerMsg('recipientNotAtTable');
    final toChar = await characters.find(toId);
    final fromChar = await characters.find(from);
    if (toChar == null || fromChar == null) {
      return encodeServerMsg('characterNotFound');
    }

    final id = 'tr${++_transferSeq}';
    final itemId = message.itemId;
    final coinsCp = message.coinsCp ?? 0;

    final PendingTransfer pending;
    if (itemId != null) {
      final rows = await characters.items(from);
      final row = rows.where((i) => i.id == itemId).firstOrNull;
      if (row == null) return encodeServerMsg('itemNotYours');
      final qty = (message.quantity ?? 1).clamp(1, row.quantity);
      pending = PendingTransfer(
        id: id,
        fromToken: player.token,
        fromCharacterId: from,
        fromCharacterName: fromChar.name,
        toCharacterId: toId,
        toCharacterName: toChar.name,
        itemId: itemId,
        itemName: await characters.itemDisplayName(row),
        magic: row.magicItemKey != null,
        quantity: qty,
      );
    } else if (coinsCp > 0) {
      if (fromChar.coinsCp < coinsCp) return 'Yeterli paran yok.';
      pending = PendingTransfer(
        id: id,
        fromToken: player.token,
        fromCharacterId: from,
        fromCharacterName: fromChar.name,
        toCharacterId: toId,
        toCharacterName: toChar.name,
        coinsCp: coinsCp,
      );
    } else {
      return encodeServerMsg('pickSomethingToSend');
    }

    _pendingTransfers[id] = pending;
    _server?.pushToPlayers(
      ServerMessage(
        type: ServerMessageType.transferOffer,
        payload: {
          'id': pending.id,
          'fromName': pending.fromCharacterName,
          'itemName': pending.itemName,
          'magic': pending.magic,
          'quantity': pending.quantity,
          'coinsCp': pending.coinsCp,
        },
      ),
      characterId: toId,
    );
    return null;
  }

  /// Alicinin gonderme teklifine yaniti (kabul/ret). Kabulde atomik aktarim
  /// yapilir, gonderene bildirilir ve DM bir aktivite satiri gorur.
  Future<String?> _handleRespondTransfer(
    ConnectedPlayer player,
    ClientMessage message,
  ) async {
    final id = message.transferId;
    if (id == null) return null;
    final pending = _pendingTransfers[id];
    if (pending == null) return null; // zaten cozulmus/iptal
    // Yalnizca teklifin alicisi yanitlayabilir.
    if (player.characterId != pending.toCharacterId) {
      return encodeServerMsg('offerNotForYou');
    }
    _pendingTransfers.remove(id);

    final label = pending.isCoins
        ? _formatCoins(pending.coinsCp)
        : (pending.quantity > 1
              ? '${pending.itemName} ×${pending.quantity}'
              : pending.itemName);

    if (!(message.accept ?? false)) {
      await announce(
        encodeServerMsg('transferDeclined', [pending.toCharacterName, label]),
        characterId: pending.fromCharacterId,
      );
      return null;
    }

    final ok = pending.isCoins
        ? await characters.transferCoins(
            fromCharacterId: pending.fromCharacterId,
            toCharacterId: pending.toCharacterId,
            amountCp: pending.coinsCp,
          )
        : await characters.transferItem(
            itemId: pending.itemId!,
            toCharacterId: pending.toCharacterId,
            quantity: pending.quantity,
          );

    if (!ok) {
      // Gonderen bu arada esyayi/parayi harcamis olabilir.
      await announce(
        encodeServerMsg('transferUnavailable', [label]),
        characterId: pending.toCharacterId,
      );
      return null;
    }

    _activity.add(
      '${pending.fromCharacterName} → ${pending.toCharacterName}: $label',
    );
    await announce(
      encodeServerMsg('transferAccepted', [pending.toCharacterName, label]),
      characterId: pending.fromCharacterId,
    );
    // Envanter/para degisimi tableUpdates uzerinden zaten yayinlaniyor.
    return null;
  }

  /// Bakiri kisa okunur paraya cevirir (DM bildirimi ve etiketler icin).
  static String _formatCoins(int cp) {
    if (cp <= 0) return '0 gp';
    final pp = cp ~/ 1000;
    final gp = (cp % 1000) ~/ 100;
    final sp = (cp % 100) ~/ 10;
    final rest = cp % 10;
    return [
      if (pp > 0) '$pp pp',
      if (gp > 0) '$gp gp',
      if (sp > 0) '$sp sp',
      if (rest > 0) '$rest cp',
    ].join(' ');
  }

  /// Bir karakterin kayitli notlarini yalnizca o karakteri sahiplenen
  /// oyuncunun soketine gonderir (baska oyunculara sizmaz).
  Future<void> _pushNotes(String characterId) async {
    final sections = await notes.getFor(characterId);
    _server?.pushToPlayers(
      ServerMessage(
        type: ServerMessageType.notes,
        payload: {'sections': notesToJson(sections)},
      ),
      characterId: characterId,
    );
  }

  /// Satin alma istegi.
  ///
  /// Magaza onay istiyorsa islem hemen yapilmaz, DM'in kuyruguna dusar;
  /// istemiyorsa dogrudan uygulanir. Her iki durumda da parayi ve stogu
  /// dusuren tek yer [ShopRepository.purchase] -- kural tek yerde kalsin.
  Future<String?> _handlePurchase(
    ConnectedPlayer player,
    ClientMessage message,
  ) async {
    final characterId = player.characterId;
    if (characterId == null) return encodeServerMsg('needCharacter');

    final stockId = message.stockId;
    if (stockId == null) return encodeServerMsg('itemNotSpecified');

    // Stok hangi magazada? Hem direkt panel hem haritadan erisilebilen
    // magazalardan alisveris yapilabilir -- tek kaynak `openShop` degil.
    final shop = await shops.shopOfStock(stockId);
    if (shop == null) return encodeServerMsg('shopNotFound');
    if (shop.closed) return encodeServerMsg('shopClosed');

    // Oyuncu bu magazayi GOREBILIYOR olmali: direkt panelde ya da haritada.
    final quantity = message.quantity ?? 1;
    if (!shop.openToPlayers && !shop.mapAccessible) {
      return encodeServerMsg('noShopOpen');
    }

    if (!shop.requiresApproval) {
      final result = await shops.purchase(
        characterId: characterId,
        stockId: stockId,
        quantity: quantity,
      );
      switch (result) {
        case PurchaseOk():
          return null;
        case PurchaseFailed(:final reason):
          return reason;
      }
    }

    // Onay bekleyen istek: fiyati simdiden hesaplayip DM'e gosteriyoruz.
    final entry = (await shops.entries(
      shop.id,
    )).where((e) => e.stock.id == stockId).firstOrNull;
    if (entry == null) return encodeServerMsg('itemNotFound');

    final character = await characters.find(characterId);
    if (character == null) return encodeServerMsg('characterNotFound');

    if (_pendingPurchases.any(
      (p) => p.player.token == player.token && p.stockId == stockId,
    )) {
      return encodeServerMsg('alreadyPending');
    }

    _pendingPurchases.add(
      PendingPurchase(
        id: '${player.token}:$stockId:${DateTime.now().microsecondsSinceEpoch}',
        player: player,
        characterId: characterId,
        characterName: character.name,
        stockId: stockId,
        itemName: entry.name,
        totalCp: entry.priceCp * quantity,
        quantity: quantity,
      ),
    );
    _pendingChanged.add(null);

    // Reddedilmis sayilmasin diye null donuyoruz; oyuncuya bilgi notu
    // yayinla birlikte gidiyor.
    await broadcast(notice: encodeServerMsg('purchasePending', [entry.name]));
    return null;
  }

  /// DM bekleyen istegi onaylar.
  Future<PurchaseResult> approvePurchase(String requestId) async {
    final request = _pendingPurchases
        .where((p) => p.id == requestId)
        .firstOrNull;
    if (request == null) {
      return PurchaseFailed(encodeServerMsg('requestNotFound'));
    }

    final result = await shops.purchase(
      characterId: request.characterId,
      stockId: request.stockId,
      quantity: request.quantity,
    );

    _pendingPurchases.removeWhere((p) => p.id == requestId);
    _pendingChanged.add(null);

    await broadcast(
      notice: switch (result) {
        PurchaseOk(:final itemName) => encodeServerMsg('purchaseBought', [
          request.characterName,
          itemName,
        ]),
        // reason zaten kodlu (shop_repository).
        PurchaseFailed(:final reason) => reason,
      },
    );
    return result;
  }

  /// DM bekleyen istegi reddeder.
  Future<void> rejectPurchase(String requestId, {String? reason}) async {
    final request = _pendingPurchases
        .where((p) => p.id == requestId)
        .firstOrNull;
    if (request == null) return;

    _pendingPurchases.removeWhere((p) => p.id == requestId);
    _pendingChanged.add(null);
    await broadcast(
      notice: reason ?? encodeServerMsg('purchaseRejected', [request.itemName]),
    );
  }

  Future<List<InventoryLine>> _inventoryOf(String characterId) async {
    final rows = await (db.select(
      db.characterItems,
    )..where((t) => t.characterId.equals(characterId))).get();
    if (rows.isEmpty) return const [];

    final itemKeys = rows.map((r) => r.itemKey).whereType<String>().toList();
    final magicKeys = rows
        .map((r) => r.magicItemKey)
        .whereType<String>()
        .toList();

    final names = <String, String>{};
    if (itemKeys.isNotEmpty) {
      for (final row in await (db.select(
        db.items,
      )..where((t) => t.key.isIn(itemKeys))).get()) {
        names[row.key] = row.name;
      }
    }
    if (magicKeys.isNotEmpty) {
      for (final row in await (db.select(
        db.magicItems,
      )..where((t) => t.key.isIn(magicKeys))).get()) {
        names[row.key] = row.name;
      }
    }

    return [
      for (final r in rows)
        InventoryLine(
          id: r.id,
          name: r.customName ?? names[r.itemKey] ?? names[r.magicItemKey] ?? '',
          quantity: r.quantity,
          equipped: r.equipped,
          attuned: r.attuned,
          magic: r.magicItemKey != null,
        ),
    ];
  }

  /// Oyuncu kagittan can degistirince savas listesindeki satiri da esitler.
  /// Mantik [CombatRepository.syncFromCharacter]'a tasindi; DM tarafindaki
  /// parti molasi da ayni senkronu kullanabilsin diye (yoksa moladan sonra
  /// savas listesi bayat cani gosteriyordu).
  Future<void> _syncCombatantHitPoints(String characterId) =>
      combat.syncFromCharacter(characterId);

  /// Haritadaki hazine pininden tek esya ya da parayi alir.
  ///
  /// Eksilen ganimet DB'de kalir; pin bosalirsa silinir ve oyuncu haritasi
  /// yayinla guncellenir (pin kaybolur). Ayni esyayi iki oyuncu almak
  /// isterse ikincisi hata alir.
  Future<String?> _handleTakeTreasureLoot(
    ConnectedPlayer player,
    ClientMessage message,
  ) async {
    final target = player.characterId;
    if (target == null) return encodeServerMsg('needCharacter');
    final pinId = message.lootPinId;
    if (pinId == null) return 'Hazine pini belirtilmedi.';

    final result = await world.takeTreasureLoot(
      pinId,
      itemId: message.lootItemId,
    );
    if (result.error != null) return encodeServerMsg(result.error!);

    if (message.lootItemId != null) {
      if (result.takenName != null) {
        await characters.addItem(
          characterId: target,
          customName: result.takenName!,
        );
      }
    } else if (result.takenCoinsCp > 0) {
      final character = await characters.find(target);
      if (character != null) {
        await characters.setCoins(
          target,
          character.coinsCp + result.takenCoinsCp,
        );
      }
    }
    await broadcast();
    return null;
  }

  /// Haritadaki hazine pininden kalan TUM ganimeti (esyalar + para) alir ve
  /// pini siler. Oyuncunun envanterine tek islemde aktarilir.
  Future<String?> _handleTakeAllTreasureLoot(
    ConnectedPlayer player,
    ClientMessage message,
  ) async {
    final target = player.characterId;
    if (target == null) return encodeServerMsg('needCharacter');
    final pinId = message.lootPinId;
    if (pinId == null) return 'Hazine pini belirtilmedi.';

    final result = await world.takeAllTreasureLoot(pinId);
    if (result.error != null) return encodeServerMsg(result.error!);

    for (final item in result.items) {
      await characters.addItem(characterId: target, customName: item.name);
    }
    if (result.coinsCp > 0) {
      final character = await characters.find(target);
      if (character != null) {
        await characters.setCoins(target, character.coinsCp + result.coinsCp);
      }
    }
    await broadcast();
    return null;
  }

  // --- Ortak parti kesesi --------------------------------------------------

  /// Kese + uyelik dogrulamasi; hata kodu ya da (kese, karakterId) doner.
  Future<({String? error, PartyInventory? inv, String? me})> _partyGuard(
    ConnectedPlayer player,
    ClientMessage message,
  ) async {
    final me = player.characterId;
    if (me == null) return (error: 'needCharacter', inv: null, me: null);
    final id = message.partyInventoryId;
    if (id == null) return (error: 'noInventory', inv: null, me: null);
    final inv = await party.find(id);
    if (inv == null) return (error: 'noInventory', inv: null, me: null);
    // Uye olmayan kesenin varligini zaten bilmemeli; yine de sunucu dogrular
    // (mesaj govdesine ASLA guvenilmez).
    if (!PartyInventoryRepository.membersOf(inv).contains(me)) {
      return (error: 'offerNotForYou', inv: null, me: null);
    }
    return (error: null, inv: inv, me: me);
  }

  /// Ortak keseden esya alir ve oyuncunun envanterine yazar.
  Future<String?> _handleTakePartyItem(
    ConnectedPlayer player,
    ClientMessage message,
  ) async {
    final guard = await _partyGuard(player, message);
    if (guard.error != null) return encodeServerMsg(guard.error!);

    final itemId = message.itemId;
    if (itemId == null) return encodeServerMsg('itemGone');

    final result = await party.takeItem(
      guard.inv!.id,
      itemId: itemId,
      quantity: message.quantity ?? 1,
    );
    if (result.error != null) return encodeServerMsg(result.error!);

    await characters.addItem(
      characterId: guard.me!,
      itemKey: result.itemKey,
      magicItemKey: result.magicItemKey,
      // Anahtarli esyada customName VERILMEZ: addItem'in eslesme mantigi once
      // anahtara bakar, serbest ada yalnizca iki anahtar da null'ken duser.
      customName: (result.itemKey == null && result.magicItemKey == null)
          ? result.name
          : null,
      customDesc: result.desc,
      quantity: result.quantity,
    );
    await broadcast();
    return null;
  }

  /// Ortak keseden para alir. `coinsCp` bossa kalanin tamami.
  Future<String?> _handleTakePartyCoins(
    ConnectedPlayer player,
    ClientMessage message,
  ) async {
    final guard = await _partyGuard(player, message);
    if (guard.error != null) return encodeServerMsg(guard.error!);

    final result = await party.takeCoins(
      guard.inv!.id,
      amountCp: message.coinsCp,
    );
    if (result.error != null) return encodeServerMsg(result.error!);

    final character = await characters.find(guard.me!);
    if (character != null) {
      await characters.setCoins(
        guard.me!,
        character.coinsCp + result.takenCoinsCp,
      );
    }
    await broadcast();
    return null;
  }

  /// Oyuncunun kendi envanterinden ortak keseye esya koyar.
  ///
  /// Kusanma/baglanma bayraklari havuza TASINMAZ (`transferItem` ile ayni
  /// kural); karakterin satirindaki adet dususu ile havuza ekleme AYNI
  /// transaction'da olur ki cift dokunusta esya cogalmasin.
  Future<String?> _handleDepositPartyItem(
    ConnectedPlayer player,
    ClientMessage message,
  ) async {
    final guard = await _partyGuard(player, message);
    if (guard.error != null) return encodeServerMsg(guard.error!);

    final itemId = message.itemId;
    if (itemId == null) return encodeServerMsg('itemNotFound');
    final quantity = message.quantity ?? 1;
    if (quantity < 1) return encodeServerMsg('invalidQuantity');

    final row = await (db.select(
      db.characterItems,
    )..where((t) => t.id.equals(itemId))).getSingleOrNull();
    if (row == null) return encodeServerMsg('itemNotFound');
    // Mesaj govdesine guvenilmez: esya gercekten bu oyuncunun mu?
    if (row.characterId != guard.me) return encodeServerMsg('itemNotYours');
    if (row.quantity < quantity) return encodeServerMsg('itemGone');

    final name = await characters.itemDisplayName(row);
    await db.transaction(() async {
      await characters.setItemQuantity(row.id, row.quantity - quantity);
      await party.depositItem(
        guard.inv!.id,
        item: PartyInventoryRepository.newItem(
          name: name,
          magic: row.magicItemKey != null,
          itemKey: row.itemKey,
          magicItemKey: row.magicItemKey,
          desc: row.customDesc,
          quantity: quantity,
        ),
      );
    });
    await broadcast();
    return null;
  }

  /// Oyuncunun kendi kesesinden ortak keseye para koyar.
  Future<String?> _handleDepositPartyCoins(
    ConnectedPlayer player,
    ClientMessage message,
  ) async {
    final guard = await _partyGuard(player, message);
    if (guard.error != null) return encodeServerMsg(guard.error!);

    final amount = message.coinsCp ?? 0;
    if (amount <= 0) return encodeServerMsg('invalidQuantity');

    final character = await characters.find(guard.me!);
    if (character == null) return encodeServerMsg('characterNotFound');
    if (character.coinsCp < amount) return encodeServerMsg('notEnoughMoney');

    await db.transaction(() async {
      await characters.setCoins(guard.me!, character.coinsCp - amount);
      await party.depositCoins(guard.inv!.id, amountCp: amount);
    });
    await broadcast();
    return null;
  }

  Map<String, String> _claimsByCharacter() => {
    for (final e in _claims.entries) e.key: e.value.name,
  };

  static Map<int, int> _spentSlots(Character character) {
    final raw =
        jsonDecode(character.spellSlotsUsedJson) as Map<String, dynamic>;
    return {
      for (final e in raw.entries)
        if (int.tryParse(e.key) case final level?)
          if (e.value is int) level: e.value as int,
    };
  }

  static String _healthLabel(Combatant c) {
    if (c.defeated || c.hitPointsCurrent == 0) return 'defeated';
    if (c.hitPointsMax == 0) return 'healthy';
    final ratio = c.hitPointsCurrent / c.hitPointsMax;
    if (ratio > 0.75) return 'healthy';
    if (ratio > 0.5) return 'scratched';
    if (ratio > 0.25) return 'wounded';
    return 'bloodied';
  }

  static String _shortClassName(String classKey) {
    final tail = classKey.split('_').last;
    return tail.isEmpty
        ? classKey
        : '${tail[0].toUpperCase()}${tail.substring(1)}';
  }
}
