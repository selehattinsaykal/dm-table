/// DM ile oyuncu paneli arasindaki mesajlar.
///
/// Hem DM uygulamasi (Android/Windows) hem de web'e derlenen oyuncu paneli
/// bu dosyayi kullanir; bu yuzden burada `dart:io` ya da Flutter'a bagimlilik
/// YOKTUR ve olmamalidir.
///
/// Tasarim: DM otoritedir. Oyuncudan gelen her sey bir *istektir*; DM tarafi
/// dogrular, uygular ve sonucu tum istemcilere yayinlar. Istemci kendi
/// durumunu asla tek basina dogru kabul etmez.
library;

import 'dart:convert';

import '../domain/rules/dice.dart';

export '../domain/rules/dice.dart' show DiceRoll, Advantage;

/// Sunucudan istemciye giden mesaj tipleri.
enum ServerMessageType {
  /// Baglanti kurulunca ve her yeniden baglanmada gonderilen tam durum.
  snapshot,

  /// Savas durumu degisti (initiative, HP, sira, tur).
  combat,

  /// DM bir duyuru/zar sonucu yayinladi.
  notice,

  /// Istemcinin gonderdigi istek reddedildi.
  rejected,

  /// DM'in oyuncu(lar)a gonderdigi mesaj/duyuru; ortada pop-up cikar.
  announcement,

  /// DM kurtarma atisi istedi. payload: {ability, dc, id}.
  saveRequest,

  /// Karakter olusturma katalogu (sinif/tur/gecmis). payload:
  /// {classes: [...], species: [...], backgrounds: [...]}.
  creationOptions,

  /// Oyuncunun (karaktere bagli) kayitli notlari. payload: {sections: [...]}.
  /// Yalnizca o karakteri sahiplenen oyuncunun soketine gonderilir.
  notes,

  /// Baska bir oyuncu bu oyuncuya esya/para gondermek istiyor. payload:
  /// {id, fromName, itemName, magic, quantity, coinsCp}. Alicinin soketine
  /// gonderilir; ortada kabul/ret pop-up'i cikar.
  transferOffer,
}

/// Istemciden sunucuya giden mesaj tipleri.
enum ClientMessageType {
  /// Oturuma katil; token varsa onceki kimlik geri alinir.
  join,

  /// Bir karakteri sahiplen.
  claimCharacter,

  /// Kendi karakterinin canini degistir.
  updateHitPoints,

  /// Buyu yuvasi harca / geri al.
  setSpentSlots,

  /// Inisiyatif atisini bildir.
  rollInitiative,

  /// Acik magazadan bir esya satin almak iste.
  buyItem,

  /// Zar at (beceri/kurtarma/genel); sunucu atar ve herkese yayinlar.
  rollDice,

  /// Kendi envanterinde degisiklik (giy/cikar ya da birak).
  inventoryChange,

  /// Acik bir kisa dinlenmede BIR hit die harca.
  ///
  /// Eskiden bu mesaj oyuncunun istedigi an dinlenmesini sagliyordu; artik
  /// dinlenmeyi DM baslatir ve mesaj yalnizca DM'in actigi kisa dinlenmeye
  /// dahil edilen karakterlerden kabul edilir. Uzun dinlenmenin oyuncu
  /// tarafindaki karsiligi BILINCLI OLARAK YOK (yalniz DM verir).
  spendHitDie,

  /// Ganimetten bir esya ya da parayi al. `lootItemId` doluysa o esya,
  /// bossa para alinir.
  takeLoot,

  /// Haritadaki hazine pininden esya/para al. `lootPinId` pin; `lootItemId`
  /// doluysa o esya, bossa kalan para alinir.
  takeTreasureLoot,

  /// Haritadaki hazine pininden kalan TUM ganimeti al ve pini sil.
  /// `lootPinId` pin.
  takeAllTreasureLoot,

  /// Kendi (karaktere bagli) not belgesini butunuyle kaydet. `notes` tasir.
  saveNotes,

  /// Kendi kayitli notlarini iste; sunucu `notes` mesajiyla yanitlar.
  requestNotes,

  /// Baska bir oyuncuya esya ya da para gondermeyi teklif et. `toCharacterId`
  /// hedef; `itemId`(+`quantity`) esya, `coinsCp` para. Alici kabul edince
  /// sunucu aktarimi yapar.
  offerTransfer,

  /// Gelen bir gonderme teklifini kabul et/reddet. `transferId` + `accept`.
  respondTransfer,

  /// 0 HP'deyken olum kurtarma atisi yap. Sunucu d20 atar, 5e kurallarini
  /// uygular (10+ basari, <10 basarisizlik, dogal 20 -> 1 HP, dogal 1 -> iki
  /// basarisizlik) ve sonucu paylasilan zar gunluguine dusurur.
  rollDeathSave,

  /// DM'in gosterdigi bir gorevi kabul et/reddet. `questId` + `accept`.
  /// Oylama modunda bu ayni zamanda oyun oyudur.
  respondQuest,

  /// Tamamlanan bir gorevin ODUL HAVUZUNDAN esya/para al. `questId` gorev;
  /// `lootItemId` doluysa o esya, bossa kalan para alinir. Havuz ortaktir:
  /// bir esyayi kim once alirsa digerlerinden kaybolur.
  takeQuestReward,

  /// Tamamlanan bir gorevin odul havuzunda KALAN HER SEYI al ve gorevi bitir.
  /// `questId` gorev.
  takeAllQuestReward,

  /// Sohbet mesaji gonder. `chatText` mesaj; `toCharacterId` doluysa fisilti
  /// (yalnizca o karakterin oyuncusuna + DM'e), bossa genel (herkese + DM'e).
  sendChat,

  /// Oyuncunun uygulama gorunurlugunu bildirir: tarayici sekmesi/uygulama
  /// arka plana gectiginde `presence` = 'away', geri donunce 'active'.
  setPresence,

  /// Ortak keseden esya al. `partyInventoryId` + `itemId` (kesedeki kalici
  /// uuid) + istege bagli `quantity`. Yalnizca UYE olan alabilir.
  takePartyItem,

  /// Ortak keseden para al. `partyInventoryId`; `coinsCp` bossa KALANIN
  /// TAMAMI alinir.
  takePartyCoins,

  /// Ortak keseye KENDI envanterinden esya koy. `partyInventoryId` +
  /// `itemId` (kendi envanter satirinin id'si) + istege bagli `quantity`.
  depositPartyItem,

  /// Ortak keseye kendi kesenden para koy. `partyInventoryId` + `coinsCp`.
  depositPartyCoins,

  /// Karakter olusturma secenekleri istenir (sinif/tur/gecmis katalogu).
  /// Yaniti `ServerMessageType.creationOptions` ile YALNIZ isteyen sokete
  /// gider; tum masaya yayinlamanin anlami yok.
  requestCreationOptions,

  /// Oyuncu kendi karakterini olusturur. `creation` alani taslagi tasir.
  /// Sunucu dogrular, DM tarafinda yazar ve karakteri oyuncuya sahiplendirir.
  createCharacter,
}

/// Oyuncunun uygulamadaki varlik durumu.
enum PlayerPresence {
  /// Sekme/uygulama on planda, oyuncu aktif.
  active,

  /// Tarayici sekmesi arka plana gecti (baska sekme/uygulama).
  away,
}

/// Oyuncunun envanterinde yapmak istedigi degisiklik.
enum InventoryAction { toggleEquipped, drop }

/// Oyuncunun envanterindeki bir satir.
class InventoryLine {
  const InventoryLine({
    required this.id,
    required this.name,
    this.quantity = 1,
    this.equipped = false,
    this.attuned = false,
    this.magic = false,
  });

  /// Envanter satirinin id'si; oyuncu giy/birak islemi icin gonderiyor.
  final String id;
  final String name;
  final int quantity;
  final bool equipped;

  /// Bagli (attuned) bir buyulu esya mi.
  final bool attuned;

  /// Buyulu esya mi (kutuphanede magic_item karsiligi var).
  final bool magic;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'quantity': quantity,
    'equipped': equipped,
    'attuned': attuned,
    'magic': magic,
  };

  static InventoryLine fromJson(Map<String, dynamic> json) => InventoryLine(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    quantity: json['quantity'] as int? ?? 1,
    equipped: json['equipped'] as bool? ?? false,
    attuned: json['attuned'] as bool? ?? false,
    magic: json['magic'] as bool? ?? false,
  );
}

/// Oyuncuya gonderilen, karakterin bildigi bir buyu.
class PlayerSpellView {
  const PlayerSpellView({
    required this.name,
    required this.level,
    this.school,
    this.concentration = false,
    this.ritual = false,
    this.prepared = false,
    this.alwaysPrepared = false,
  });

  final String name;
  final int level;
  final String? school;
  final bool concentration;
  final bool ritual;
  final bool prepared;
  final bool alwaysPrepared;

  Map<String, dynamic> toJson() => {
    'name': name,
    'level': level,
    'school': school,
    'concentration': concentration,
    'ritual': ritual,
    'prepared': prepared,
    'alwaysPrepared': alwaysPrepared,
  };

  static PlayerSpellView fromJson(Map<String, dynamic> json) => PlayerSpellView(
    name: json['name'] as String? ?? '',
    level: json['level'] as int? ?? 0,
    school: json['school'] as String?,
    concentration: json['concentration'] as bool? ?? false,
    ritual: json['ritual'] as bool? ?? false,
    prepared: json['prepared'] as bool? ?? false,
    alwaysPrepared: json['alwaysPrepared'] as bool? ?? false,
  );
}

/// Oyuncuya acilan magazadaki bir satir.
class ShopItemView {
  const ShopItemView({
    required this.stockId,
    required this.name,
    required this.priceCp,
    this.description = '',
    this.category,
    this.rarity,
    this.requiresAttunement = false,
    this.quantity = -1,
  });

  final String stockId;
  final String name;
  final int priceCp;
  final String description;
  final String? category;
  final String? rarity;
  final bool requiresAttunement;

  /// -1 sinirsiz.
  final int quantity;

  bool get unlimited => quantity < 0;
  bool get soldOut => !unlimited && quantity <= 0;

  Map<String, dynamic> toJson() => {
    'stockId': stockId,
    'name': name,
    'priceCp': priceCp,
    'description': description,
    'category': category,
    'rarity': rarity,
    'requiresAttunement': requiresAttunement,
    'quantity': quantity,
  };

  static ShopItemView fromJson(Map<String, dynamic> json) => ShopItemView(
    stockId: json['stockId'] as String,
    name: json['name'] as String? ?? '',
    priceCp: json['priceCp'] as int? ?? 0,
    description: json['description'] as String? ?? '',
    category: json['category'] as String?,
    rarity: json['rarity'] as String?,
    requiresAttunement: json['requiresAttunement'] as bool? ?? false,
    quantity: json['quantity'] as int? ?? -1,
  );
}

/// Oyuncuya gosterilen harita pini.
///
/// Yalnizca acilmis pinler gonderilir; DM'e ozel notlar hic yola cikmaz.
class MapPinView {
  const MapPinView({
    required this.id,
    required this.kind,
    required this.label,
    required this.x,
    required this.y,
    this.note = '',
    this.targetLocationId,
    this.targetShopId,
    this.lootCoinsCp,
    this.lootItems,
  });

  final String id;

  /// `location`, `note`, `npc`, `shop`, `encounter`, `treasure`.
  final String kind;
  final String label;
  final double x;
  final double y;
  final String note;

  /// `location` tipli pinin isaret ettigi alt lokasyon. Yalnizca DM o yeri
  /// oyunculara ACTIYSA (revealed) ve haritasi varsa dolu gelir; oyuncu pine
  /// dokununca o alt haritaya girebilir. Erisilemeyen yerlerde null.
  final String? targetLocationId;

  /// `shop` tipli pinin isaret ettigi magaza. Yalnizca DM o magazayi
  /// "haritadan erisilebilir" yaptiysa dolu gelir; oyuncu pine dokununca
  /// magaza acilir. Erisilemeyen dukkanlarda null.
  final String? targetShopId;

  /// `treasure` pinlerinde kalan para (cp). Oyuncular pine dokununca bunlari
  /// gorur ve alir; esyalar/para tukenince pin DB'den silinir.
  final int? lootCoinsCp;

  /// `treasure` pinlerinde kalan esyalar. null = hazine pini degil.
  final List<LootItemView>? lootItems;

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'label': label,
    'x': x,
    'y': y,
    'note': note,
    if (targetLocationId != null) 'targetLocationId': targetLocationId,
    if (targetShopId != null) 'targetShopId': targetShopId,
    if (lootCoinsCp != null) 'lootCoinsCp': lootCoinsCp,
    if (lootItems != null)
      'lootItems': [for (final i in lootItems!) i.toJson()],
  };

  static MapPinView fromJson(Map<String, dynamic> json) => MapPinView(
    id: json['id'] as String,
    kind: json['kind'] as String? ?? 'note',
    label: json['label'] as String? ?? '',
    x: (json['x'] as num?)?.toDouble() ?? 0,
    y: (json['y'] as num?)?.toDouble() ?? 0,
    note: json['note'] as String? ?? '',
    targetLocationId: json['targetLocationId'] as String?,
    targetShopId: json['targetShopId'] as String?,
    lootCoinsCp: json['lootCoinsCp'] as int?,
    lootItems: json['lootItems'] == null
        ? null
        : [
            for (final i in json['lootItems'] as List)
              LootItemView.fromJson((i as Map).cast<String, dynamic>()),
          ],
  );
}

/// DM'in su an oyunculara gosterdigi harita.
class MapView {
  const MapView({
    required this.locationId,
    required this.locationName,
    this.description = '',
    this.imageUrl,
    this.aspectRatio = 1,
    this.pins = const [],
    this.parentLocationId,
  });

  final String locationId;
  final String locationName;
  final String description;

  /// Sunucudaki gorsel adresi; oyuncunun tarayicisi buradan indirir.
  final String? imageUrl;
  final double aspectRatio;
  final List<MapPinView> pins;

  /// Ust lokasyonun id'si; oyuncu paneli gorunur haritalarin agacini/koklerini
  /// bununla cikarir (ust'u gorunur degilse bu bir koktur).
  final String? parentLocationId;

  Map<String, dynamic> toJson() => {
    'locationId': locationId,
    'locationName': locationName,
    'description': description,
    'imageUrl': imageUrl,
    'aspectRatio': aspectRatio,
    'pins': [for (final p in pins) p.toJson()],
    'parentLocationId': parentLocationId,
  };

  static MapView fromJson(Map<String, dynamic> json) => MapView(
    locationId: json['locationId'] as String,
    locationName: json['locationName'] as String? ?? '',
    description: json['description'] as String? ?? '',
    imageUrl: json['imageUrl'] as String?,
    aspectRatio: (json['aspectRatio'] as num?)?.toDouble() ?? 1,
    pins: [
      for (final p in (json['pins'] as List? ?? const []))
        MapPinView.fromJson((p as Map).cast<String, dynamic>()),
    ],
    parentLocationId: json['parentLocationId'] as String?,
  );
}

/// DM'in oyunculara actigi magaza.
class ShopView {
  const ShopView({
    required this.id,
    required this.name,
    this.ownerName,
    this.description = '',
    this.items = const [],
    this.requiresApproval = true,
    this.closed = false,
  });

  final String id;
  final String name;
  final String? ownerName;
  final String description;
  final List<ShopItemView> items;

  /// Aciksa satin alma DM onayindan gecer.
  final bool requiresApproval;

  /// Magaza kapaliysa oyuncular eşyaları gormez, satin alamaz; arayuz
  /// "magaza kapali" gosterir.
  final bool closed;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'ownerName': ownerName,
    'description': description,
    'requiresApproval': requiresApproval,
    'closed': closed,
    'items': [for (final i in items) i.toJson()],
  };

  static ShopView fromJson(Map<String, dynamic> json) => ShopView(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    ownerName: json['ownerName'] as String?,
    description: json['description'] as String? ?? '',
    requiresApproval: json['requiresApproval'] as bool? ?? true,
    closed: json['closed'] as bool? ?? false,
    items: [
      for (final i in (json['items'] as List? ?? const []))
        ShopItemView.fromJson((i as Map).cast<String, dynamic>()),
    ],
  );
}

/// Oyuncu panelinin gordugu karakter ozeti.
///
/// Tam karakter kaydi gonderilmez: oyuncunun ihtiyaci olan alanlar kadari
/// yeterli ve boylece DM'e ozel notlar sizmaz.
class PlayerCharacterView {
  const PlayerCharacterView({
    required this.id,
    required this.name,
    required this.hitPointsCurrent,
    required this.hitPointsMax,
    this.temporaryHitPoints = 0,
    this.deathSaveSuccesses = 0,
    this.deathSaveFailures = 0,
    this.armorClass,
    this.initiative,
    this.level = 1,
    this.classLine = '',
    this.claimedBy,
    this.spellSlots = const {},
    this.spentSlots = const {},
    this.abilityModifiers = const {},
    this.savingThrows = const {},
    this.skills = const {},
    this.proficiencyBonus = 2,
    this.passivePerception = 10,
    this.coinsCp = 0,
    this.inventory = const [],
    this.speciesName,
    this.backgroundName,
    this.alignment,
    this.weaponProficiencies = const [],
    this.armorProficiencies = const [],
    this.toolProficiencies = const [],
    this.languages = const [],
    this.notes = '',
    this.appearance = '',
    this.personality = '',
    this.ideal = '',
    this.bond = '',
    this.flaw = '',
    this.portraitUrl,
    this.spells = const [],
    this.hitDiceTotal = 0,
    this.hitDiceUsed = 0,
  });

  final String id;
  final String name;
  final int hitPointsCurrent;
  final int hitPointsMax;
  final int temporaryHitPoints;

  /// Toplam ve harcanmis hit dice. Kisa dinlenmede oyuncu kacini
  /// harcayacagina KENDI karar verdigi icin panelde gorunmesi gerekiyor.
  final int hitDiceTotal;
  final int hitDiceUsed;

  /// Olum kurtarma sayaclari (0-3). Yalnizca [hitPointsCurrent] == 0 iken
  /// anlamli; oyuncu paneli bu durumda kurtarma kartini gosterir.
  final int deathSaveSuccesses;
  final int deathSaveFailures;

  final int? armorClass;
  final int? initiative;
  final int level;
  final String classLine;

  /// Bu karakteri sahiplenen oyuncunun adi; bostaysa null.
  final String? claimedBy;

  final Map<int, int> spellSlots;
  final Map<int, int> spentSlots;

  final Map<String, int> abilityModifiers;
  final Map<String, int> savingThrows;
  final Map<String, int> skills;
  final int proficiencyBonus;
  final int passivePerception;
  final int coinsCp;
  final List<InventoryLine> inventory;

  // Zengin karakter kagidi alanlari.
  final String? speciesName;
  final String? backgroundName;
  final String? alignment;
  final List<String> weaponProficiencies;
  final List<String> armorProficiencies;
  final List<String> toolProficiencies;
  final List<String> languages;
  final String notes;
  final String appearance;
  final String personality;
  final String ideal;
  final String bond;
  final String flaw;
  final String? portraitUrl;
  final List<PlayerSpellView> spells;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'hp': hitPointsCurrent,
    'hpMax': hitPointsMax,
    'tempHp': temporaryHitPoints,
    'dsS': deathSaveSuccesses,
    'dsF': deathSaveFailures,
    'ac': armorClass,
    'initiative': initiative,
    'level': level,
    'classLine': classLine,
    'claimedBy': claimedBy,
    'spellSlots': spellSlots.map((k, v) => MapEntry('$k', v)),
    'spentSlots': spentSlots.map((k, v) => MapEntry('$k', v)),
    'abilityModifiers': abilityModifiers,
    'savingThrows': savingThrows,
    'skills': skills,
    'proficiencyBonus': proficiencyBonus,
    'passivePerception': passivePerception,
    'coinsCp': coinsCp,
    'inventory': [for (final i in inventory) i.toJson()],
    'speciesName': speciesName,
    'backgroundName': backgroundName,
    'alignment': alignment,
    'weaponProficiencies': weaponProficiencies,
    'armorProficiencies': armorProficiencies,
    'toolProficiencies': toolProficiencies,
    'languages': languages,
    'notes': notes,
    'appearance': appearance,
    'personality': personality,
    'ideal': ideal,
    'bond': bond,
    'flaw': flaw,
    'portraitUrl': portraitUrl,
    'spells': [for (final s in spells) s.toJson()],
    'hitDiceTotal': hitDiceTotal,
    'hitDiceUsed': hitDiceUsed,
  };

  static PlayerCharacterView fromJson(Map<String, dynamic> json) =>
      PlayerCharacterView(
        id: json['id'] as String,
        name: json['name'] as String,
        hitPointsCurrent: json['hp'] as int? ?? 0,
        hitPointsMax: json['hpMax'] as int? ?? 0,
        temporaryHitPoints: json['tempHp'] as int? ?? 0,
        deathSaveSuccesses: json['dsS'] as int? ?? 0,
        deathSaveFailures: json['dsF'] as int? ?? 0,
        armorClass: json['ac'] as int?,
        initiative: json['initiative'] as int?,
        level: json['level'] as int? ?? 1,
        classLine: json['classLine'] as String? ?? '',
        claimedBy: json['claimedBy'] as String?,
        spellSlots: _intMap(json['spellSlots']),
        spentSlots: _intMap(json['spentSlots']),
        abilityModifiers: _stringIntMap(json['abilityModifiers']),
        savingThrows: _stringIntMap(json['savingThrows']),
        skills: _stringIntMap(json['skills']),
        proficiencyBonus: json['proficiencyBonus'] as int? ?? 2,
        passivePerception: json['passivePerception'] as int? ?? 10,
        coinsCp: json['coinsCp'] as int? ?? 0,
        inventory: [
          for (final i in (json['inventory'] as List? ?? const []))
            InventoryLine.fromJson((i as Map).cast<String, dynamic>()),
        ],
        speciesName: json['speciesName'] as String?,
        backgroundName: json['backgroundName'] as String?,
        alignment: json['alignment'] as String?,
        weaponProficiencies: _stringList(json['weaponProficiencies']),
        armorProficiencies: _stringList(json['armorProficiencies']),
        toolProficiencies: _stringList(json['toolProficiencies']),
        languages: _stringList(json['languages']),
        notes: json['notes'] as String? ?? '',
        appearance: json['appearance'] as String? ?? '',
        personality: json['personality'] as String? ?? '',
        ideal: json['ideal'] as String? ?? '',
        bond: json['bond'] as String? ?? '',
        flaw: json['flaw'] as String? ?? '',
        portraitUrl: json['portraitUrl'] as String?,
        hitDiceTotal: json['hitDiceTotal'] as int? ?? 0,
        hitDiceUsed: json['hitDiceUsed'] as int? ?? 0,
        spells: [
          for (final s in (json['spells'] as List? ?? const []))
            PlayerSpellView.fromJson((s as Map).cast<String, dynamic>()),
        ],
      );
}

List<String> _stringList(dynamic raw) => [
  for (final e in (raw as List? ?? const [])) '$e',
];

/// Oyuncunun gordugu savas satiri.
///
/// DM'in gizledigi katilimcilar bu listeye hic konulmaz; canavarlarin kesin
/// HP'si yerine kabaca durumu gonderilir ki oyuncular sayidan okumasin.
class CombatantView {
  const CombatantView({
    required this.id,
    required this.name,
    required this.initiative,
    required this.isPlayer,
    this.initiativeRolled = true,
    this.defeated = false,
    this.healthLabel,
    this.conditions = const [],
    this.characterId,
    this.portraitUrl,
  });

  final String id;
  final String name;
  final int initiative;
  final bool isPlayer;

  /// Inisiyatif atildi mi? Atilmamis (oyuncu, henuz atmamis) katilimcilar
  /// panelde sayi yerine zar dugmesi gosterir.
  final bool initiativeRolled;

  final bool defeated;

  /// Canavarlarda "Sağlam / Yaralı / Ağır yaralı" gibi kaba durum;
  /// oyuncularda null (kendi kesin canlarini zaten goruyorlar).
  final String? healthLabel;

  final List<String> conditions;
  final String? characterId;

  /// Portre medya yolu (`/media/<ad>`); canavarda DM'in ekledigi gorsel,
  /// oyuncuda karakter portresi. Yoksa null.
  final String? portraitUrl;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'initiative': initiative,
    'isPlayer': isPlayer,
    'rolled': initiativeRolled,
    'defeated': defeated,
    'healthLabel': healthLabel,
    'conditions': conditions,
    'characterId': characterId,
    'portrait': portraitUrl,
  };

  static CombatantView fromJson(Map<String, dynamic> json) => CombatantView(
    id: json['id'] as String,
    name: json['name'] as String,
    initiative: json['initiative'] as int? ?? 0,
    isPlayer: json['isPlayer'] as bool? ?? false,
    initiativeRolled: json['rolled'] as bool? ?? true,
    defeated: json['defeated'] as bool? ?? false,
    healthLabel: json['healthLabel'] as String?,
    conditions: (json['conditions'] as List? ?? const []).cast<String>(),
    characterId: json['characterId'] as String?,
    portraitUrl: json['portrait'] as String?,
  );
}

/// Oyuncunun gordugu savas durumu.
class CombatView {
  const CombatView({
    this.encounterName,
    this.round = 0,
    this.activeCombatantId,
    this.combatants = const [],
    this.started = false,
  });

  final String? encounterName;
  final int round;
  final String? activeCombatantId;
  final List<CombatantView> combatants;
  final bool started;

  Map<String, dynamic> toJson() => {
    'encounterName': encounterName,
    'round': round,
    'activeCombatantId': activeCombatantId,
    'started': started,
    'combatants': [for (final c in combatants) c.toJson()],
  };

  static CombatView fromJson(Map<String, dynamic> json) => CombatView(
    encounterName: json['encounterName'] as String?,
    round: json['round'] as int? ?? 0,
    activeCombatantId: json['activeCombatantId'] as String?,
    started: json['started'] as bool? ?? false,
    combatants: [
      for (final c in (json['combatants'] as List? ?? const []))
        CombatantView.fromJson((c as Map).cast<String, dynamic>()),
    ],
  );
}

/// Ganimetteki bir esya.
class LootItemView {
  const LootItemView({
    required this.id,
    required this.name,
    this.magic = false,
  });

  final String id;
  final String name;
  final bool magic;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'magic': magic};

  static LootItemView fromJson(Map<String, dynamic> json) => LootItemView(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    magic: json['magic'] as bool? ?? false,
  );
}

/// DM'in oyunculara sundugu ganimet (esya + para). Oyuncu pop-up'tan alir.
class LootView {
  const LootView({
    required this.id,
    this.coinsCp = 0,
    this.items = const [],
    this.targetCharacterId,
  });

  /// Yeni ganimeti ayirt etmek icin artan numara (pop-up bir kez acilir).
  final String id;
  final int coinsCp;
  final List<LootItemView> items;

  /// Yalnizca bu karaktere gosterilir; null ise herkese.
  final String? targetCharacterId;

  Map<String, dynamic> toJson() => {
    'id': id,
    'coinsCp': coinsCp,
    'items': [for (final i in items) i.toJson()],
    'targetCharacterId': targetCharacterId,
  };

  static LootView fromJson(Map<String, dynamic> json) => LootView(
    id: json['id'] as String? ?? '',
    coinsCp: json['coinsCp'] as int? ?? 0,
    items: [
      for (final i in (json['items'] as List? ?? const []))
        LootItemView.fromJson((i as Map).cast<String, dynamic>()),
    ],
    targetCharacterId: json['targetCharacterId'] as String?,
  );
}

/// Ortak kesedeki bir esya (oyuncu gorunumu).
///
/// Katalog anahtarlari GONDERILMEZ: oyuncunun onlara ihtiyaci yok, alma
/// islemi kalici [id] ile yapiliyor ve anahtar sunucu tarafinda korunuyor.
class PartyItemView {
  const PartyItemView({
    required this.id,
    required this.name,
    this.magic = false,
    this.quantity = 1,
  });

  final String id;
  final String name;
  final bool magic;
  final int quantity;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'magic': magic,
    'quantity': quantity,
  };

  static PartyItemView fromJson(Map<String, dynamic> json) => PartyItemView(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    magic: json['magic'] as bool? ?? false,
    quantity: json['quantity'] as int? ?? 1,
  );
}

/// Oyuncunun UYE oldugu bir ortak kese.
///
/// Uye listesi gonderilmez: kimin hangi keseye uye oldugu sunucu tarafi bir
/// suzgectir (uye olmayan keseyi hic gormez).
class PartyInventoryView {
  const PartyInventoryView({
    required this.id,
    required this.name,
    this.coinsCp = 0,
    this.items = const [],
  });

  final String id;
  final String name;
  final int coinsCp;
  final List<PartyItemView> items;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'coinsCp': coinsCp,
    'items': [for (final i in items) i.toJson()],
  };

  static PartyInventoryView fromJson(Map<String, dynamic> json) =>
      PartyInventoryView(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        coinsCp: json['coinsCp'] as int? ?? 0,
        items: [
          for (final i in (json['items'] as List? ?? const []))
            PartyItemView.fromJson((i as Map).cast<String, dynamic>()),
        ],
      );
}

/// Sunucunun urettigi, istemcide cevrilecek mesajlar icin kodlama.
///
/// Sunucu oyuncunun secili dilini bilemedigi icin hazir Turkce cumle yerine
/// bir KOD (+ argumanlar) gonderir; istemci kendi diline gore cevirir. DM'in
/// elle yazdigi serbest duyuru metni kodlanmaz -- sentinel karakteri ikisini
/// ayirt eder (DM kullanicisi kontrol karakteri yazmaz).
const String _msgSentinel = '';
const String _msgArgSep = '';

/// `code` (+ `args`) -> tasinabilir string. Basindaki sentinel bunun cevrilecek
/// bir sistem mesaji oldugunu isaretler.
String encodeServerMsg(String code, [List<String> args = const []]) =>
    args.isEmpty
    ? '$_msgSentinel$code'
    : '$_msgSentinel$code$_msgArgSep${args.join(_msgArgSep)}';

/// Kodlu sistem mesajini cozer. Sentinel yoksa (ham DM metni) null doner.
({String code, List<String> args})? decodeServerMsg(String s) {
  if (!s.startsWith(_msgSentinel)) return null;
  final parts = s.substring(_msgSentinel.length).split(_msgArgSep);
  return (code: parts.first, args: parts.skip(1).toList());
}

/// Bir baslik altindaki tek not.
class NoteEntry {
  const NoteEntry({required this.id, this.title = '', this.body = ''});

  final String id;
  final String title;
  final String body;

  NoteEntry copyWith({String? title, String? body}) =>
      NoteEntry(id: id, title: title ?? this.title, body: body ?? this.body);

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'body': body};

  static NoteEntry fromJson(Map<String, dynamic> json) => NoteEntry(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    body: json['body'] as String? ?? '',
  );
}

/// Bir baslik (bolum) ve altindaki notlar.
class NoteSection {
  const NoteSection({
    required this.id,
    this.title = '',
    this.entries = const [],
  });

  final String id;
  final String title;
  final List<NoteEntry> entries;

  NoteSection copyWith({String? title, List<NoteEntry>? entries}) =>
      NoteSection(
        id: id,
        title: title ?? this.title,
        entries: entries ?? this.entries,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'entries': [for (final e in entries) e.toJson()],
  };

  static NoteSection fromJson(Map<String, dynamic> json) => NoteSection(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    entries: [
      for (final e in (json['entries'] as List? ?? const []))
        NoteEntry.fromJson((e as Map).cast<String, dynamic>()),
    ],
  );
}

/// Not belgesini (baslik listesi) JSON listesine cevirir.
List<Map<String, dynamic>> notesToJson(List<NoteSection> sections) => [
  for (final s in sections) s.toJson(),
];

/// JSON listesinden not belgesini cozer (bozuk/eksik veriye dayanikli).
List<NoteSection> notesFromJson(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final s in raw)
      if (s is Map) NoteSection.fromJson(s.cast<String, dynamic>()),
  ];
}

/// Oyuncu panelinin tam durumu.
/// DM'in oyunculara gosterdigi handout. Iki tur: gorsel ([url] `/media/<ad>`)
/// ya da metin ([text] — ornegin AI ureteclerinden gelen gorev metni). Ikisinde
/// de istege bagli [caption] baslik olur. Gorsel handout'ta [text] null,
/// metin handout'ta [url] null.
class HandoutView {
  const HandoutView({required this.id, this.url, this.text, this.caption});

  final String id;
  final String? url;
  final String? text;
  final String? caption;

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'text': text,
    'caption': caption,
  };

  static HandoutView fromJson(Map<String, dynamic> json) => HandoutView(
    id: json['id'] as String,
    url: json['url'] as String?,
    text: json['text'] as String?,
    caption: json['caption'] as String?,
  );
}

/// DM'in bir oyuncuya gösterdiği görev. Yalnızca oyuncuya açık alanlar taşınır
/// (DM notu ASLA gitmez). [myStatus] bu oyuncunun kendi durumu: 'accepted',
/// 'rejected' ya da null (bekliyor). Başkalarının durumu taşınmaz.
///
/// [mode] 'individual' (herkes kendi kararını verir) ya da 'vote' (hedefler
/// oylar; %50+ kabul çıkarsa görev hepsine verilir). Oylamada [voteStatus]
/// 'pending' | 'passed' olabilir (başarısız oylama oyuncuya hiç gitmez);
/// kimin ne oyladığı taşınmaz.
///
/// Görev tamamlanıp ödül dağıtıma açılınca [rewardReady] true olur ve
/// [rewardCoinsCp]/[rewardItems] havuzda KALAN ganimeti taşır (ortak havuz —
/// bir eşyayı kim önce alırsa diğerlerinden kaybolur).
class QuestView {
  const QuestView({
    required this.id,
    required this.title,
    required this.text,
    required this.reward,
    this.myStatus,
    this.mode = 'individual',
    this.voteStatus,
    this.rewardReady = false,
    this.rewardCoinsCp = 0,
    this.rewardItems = const [],
  });

  final String id;
  final String title;
  final String text;
  final String reward;
  final String? myStatus;
  final String mode;
  final String? voteStatus;
  final bool rewardReady;
  final int rewardCoinsCp;
  final List<LootItemView> rewardItems;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'text': text,
    'reward': reward,
    'myStatus': myStatus,
    'mode': mode,
    'voteStatus': voteStatus,
    'rewardReady': rewardReady,
    'rewardCoinsCp': rewardCoinsCp,
    'rewardItems': [for (final i in rewardItems) i.toJson()],
  };

  static QuestView fromJson(Map<String, dynamic> json) => QuestView(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    text: json['text'] as String? ?? '',
    reward: json['reward'] as String? ?? '',
    myStatus: json['myStatus'] as String?,
    mode: json['mode'] as String? ?? 'individual',
    voteStatus: json['voteStatus'] as String?,
    rewardReady: json['rewardReady'] as bool? ?? false,
    rewardCoinsCp: json['rewardCoinsCp'] as int? ?? 0,
    rewardItems: [
      for (final i in (json['rewardItems'] as List? ?? const []))
        LootItemView.fromJson((i as Map).cast<String, dynamic>()),
    ],
  );
}

/// Oyuncular arası (ve DM'den) bir sohbet mesajı.
///
/// [toCharacterId] boşsa genel (masadaki herkes + DM görür); doluysa fısıltı
/// (yalnız alıcı + gönderen + DM görür). [fromCharacterId] boşsa mesaj DM'den
/// gelir. Mesajlar yalnız bellekte tutulur (oturum süresince); sunucu
/// oyuncu-başına [TableSnapshot.chats]'ı süzer, DM her şeyi görür.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.fromName,
    required this.text,
    required this.seq,
    this.fromCharacterId,
    this.toCharacterId,
    this.isDm = false,
    this.toDm = false,
  });

  final String id;
  final String fromName;
  final String text;

  /// Yeni mesajı ayırt etmek için artan sıra numarası (dedup için).
  final int seq;

  /// Mesajı yazan karakter; boşsa DM.
  final String? fromCharacterId;

  /// Hedef karakter; boşsa genel mesaj.
  final String? toCharacterId;

  /// DM tarafından gönderildi mi.
  final bool isDm;

  /// Oyuncudan DM'e özel mesaj mı?
  ///
  /// [toCharacterId] ile ifade EDİLEMEZ: DM'in bir karakteri yok. Ayrı bir
  /// bayrak olmasının sebebi bu — mesaj yalnızca gönderen oyuncuya ve DM'e
  /// gider, diğer oyuncular hiç görmez.
  final bool toDm;

  bool get isWhisper => toCharacterId != null || toDm;

  Map<String, dynamic> toJson() => {
    'id': id,
    'fromName': fromName,
    'text': text,
    'seq': seq,
    if (fromCharacterId != null) 'fromCharacterId': fromCharacterId,
    if (toCharacterId != null) 'toCharacterId': toCharacterId,
    'isDm': isDm,
    if (toDm) 'toDm': true,
  };

  static ChatMessage fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String? ?? '',
    fromName: json['fromName'] as String? ?? '',
    text: json['text'] as String? ?? '',
    seq: json['seq'] as int? ?? 0,
    fromCharacterId: json['fromCharacterId'] as String?,
    toCharacterId: json['toCharacterId'] as String?,
    isDm: json['isDm'] as bool? ?? false,
    toDm: json['toDm'] as bool? ?? false,
  );
}

class TableSnapshot {
  const TableSnapshot({
    this.characters = const [],
    this.combat,
    this.shop,
    this.mapShops = const [],
    this.map,
    this.maps = const [],
    this.loot,
    this.handout,
    this.rolls = const [],
    this.notice,
    this.quests = const [],
    this.chats = const [],
    this.partyInventories = const [],
    this.shortRestCharacterIds = const [],
    this.inGameDate,
    this.inGameSeason,
  });

  /// Oyuncu-basina suzulen alanlari degistirilmis bir kopya.
  ///
  /// ⚠️ Yeni bir alan eklerken hem parametreyi hem de asagidaki ILETIM
  /// SATIRINI eklemeyi unutma. `questsFor` her zaman bagli oldugu icin
  /// `TableServer.broadcast` HER snapshot'i buradan geciriyor; iletim satiri
  /// eksik kalirsa hicbir hata cikmadan tum oyuncular o alani BOS gorur.
  TableSnapshot copyWith({
    List<QuestView>? quests,
    List<ChatMessage>? chats,
    List<PartyInventoryView>? partyInventories,
  }) => TableSnapshot(
    characters: characters,
    combat: combat,
    shop: shop,
    mapShops: mapShops,
    map: map,
    maps: maps,
    loot: loot,
    handout: handout,
    rolls: rolls,
    notice: notice,
    quests: quests ?? this.quests,
    chats: chats ?? this.chats,
    partyInventories: partyInventories ?? this.partyInventories,
    shortRestCharacterIds: shortRestCharacterIds,
    inGameDate: inGameDate,
    inGameSeason: inGameSeason,
  );

  final List<PlayerCharacterView> characters;
  final CombatView? combat;

  /// DM su an bir magaza actiysa; kapaliysa null.
  final ShopView? shop;

  /// Haritadan erisilebilir magazalar: oyuncu dukkan pinine dokununca acilir.
  /// [shop]'tan bagimsiz; ayni anda birden fazla olabilir.
  final List<ShopView> mapShops;

  /// DM su an bir harita gosteriyorsa (aktif/kok harita). Geriye donuk
  /// uyumluluk icin duruyor; oyuncu paneli gezinme icin [maps]'i kullanir.
  final MapView? map;

  /// Oyuncunun gorebilecegi TUM haritalar: aktif harita + DM'in actigi
  /// (revealed) ve haritasi olan alt lokasyonlar. Oyuncu bir location-pine
  /// dokununca, hedefi bu listede varsa o alt haritaya girer. Erisilmeyen
  /// yerler listede olmaz -- gizlilik yine sunucu tarafinda.
  final List<MapView> maps;

  /// DM su an bir ganimet sundiysa; oyuncu pop-up'tan alir.
  final LootView? loot;

  /// DM su an bir handout (gorsel) gosteriyorsa; oyuncuda pop-up cikar.
  final HandoutView? handout;

  /// Son atilan zarlar (paylasilan gunluk); en yeni en sonda.
  final List<DiceRoll> rolls;

  /// DM'in ekrana bastigi serbest duyuru.
  final String? notice;

  /// Bu oyuncuya gösterilen görevler (sunucu tarafında oyuncu-başına süzülür).
  final List<QuestView> quests;

  /// Bu oyuncunun görebildiği sohbet mesajları (sunucu tarafında oyuncu-başına
  /// süzülür; DM her şeyi görür). Mesajlar yalnız bellekte tutulur.
  final List<ChatMessage> chats;

  /// Bu oyuncunun ÜYE OLDUĞU ortak keseler (sunucu tarafında oyuncu-başına
  /// süzülür; üye olmadığı keseyi hiç görmez).
  final List<PartyInventoryView> partyInventories;

  /// DM'in ACIK kisa dinlenmesine dahil edilen karakter id'leri.
  ///
  /// Bos = ortada kisa dinlenme yok. Oyuncu paneli yalnizca kendi karakteri
  /// bu listedeyken hit die harcama panelini gosterir; dinlenmeyi baslatmak
  /// ve bitirmek DM'in isidir. Oturum-ici anlik bir durum oldugu icin
  /// veritabaninda DEGIL `SessionService` belleginde tutulur.
  final List<String> shortRestCharacterIds;

  /// DM'in belirlediği oyun-içi tarih, HAZIR BİÇİMLENMİŞ ("Orsgün, 12 Hasat
  /// 1492 YS"). Oyuncu paneli takvim yapısını (ay uzunlukları, gün adları,
  /// mevsim aralıkları) bilmez; bu yüzden metin sunucuda üretilir.
  final String? inGameDate;

  /// Güncel mevsimin adı; mevsim tanımlı değilse null.
  final String? inGameSeason;

  Map<String, dynamic> toJson() => {
    'characters': [for (final c in characters) c.toJson()],
    'combat': combat?.toJson(),
    'shop': shop?.toJson(),
    'mapShops': [for (final s in mapShops) s.toJson()],
    'map': map?.toJson(),
    'maps': [for (final m in maps) m.toJson()],
    'loot': loot?.toJson(),
    'handout': handout?.toJson(),
    'rolls': [for (final r in rolls) r.toJson()],
    'notice': notice,
    'quests': [for (final q in quests) q.toJson()],
    'chats': [for (final c in chats) c.toJson()],
    'partyInventories': [for (final p in partyInventories) p.toJson()],
    'shortRestCharacterIds': shortRestCharacterIds,
    if (inGameDate != null) 'inGameDate': inGameDate,
    if (inGameSeason != null) 'inGameSeason': inGameSeason,
  };

  static TableSnapshot fromJson(Map<String, dynamic> json) => TableSnapshot(
    characters: [
      for (final c in (json['characters'] as List? ?? const []))
        PlayerCharacterView.fromJson((c as Map).cast<String, dynamic>()),
    ],
    combat: json['combat'] == null
        ? null
        : CombatView.fromJson((json['combat'] as Map).cast<String, dynamic>()),
    shop: json['shop'] == null
        ? null
        : ShopView.fromJson((json['shop'] as Map).cast<String, dynamic>()),
    mapShops: [
      for (final s in (json['mapShops'] as List? ?? const []))
        ShopView.fromJson((s as Map).cast<String, dynamic>()),
    ],
    map: json['map'] == null
        ? null
        : MapView.fromJson((json['map'] as Map).cast<String, dynamic>()),
    maps: [
      for (final m in (json['maps'] as List? ?? const []))
        MapView.fromJson((m as Map).cast<String, dynamic>()),
    ],
    loot: json['loot'] == null
        ? null
        : LootView.fromJson((json['loot'] as Map).cast<String, dynamic>()),
    handout: json['handout'] == null
        ? null
        : HandoutView.fromJson(
            (json['handout'] as Map).cast<String, dynamic>(),
          ),
    rolls: [
      for (final r in (json['rolls'] as List? ?? const []))
        DiceRoll.fromJson((r as Map).cast<String, dynamic>()),
    ],
    notice: json['notice'] as String?,
    quests: [
      for (final q in (json['quests'] as List? ?? const []))
        QuestView.fromJson((q as Map).cast<String, dynamic>()),
    ],
    inGameDate: json['inGameDate'] as String?,
    inGameSeason: json['inGameSeason'] as String?,
    chats: [
      for (final c in (json['chats'] as List? ?? const []))
        ChatMessage.fromJson((c as Map).cast<String, dynamic>()),
    ],
    partyInventories: [
      for (final p in (json['partyInventories'] as List? ?? const []))
        PartyInventoryView.fromJson((p as Map).cast<String, dynamic>()),
    ],
    shortRestCharacterIds: [
      for (final id in (json['shortRestCharacterIds'] as List? ?? const []))
        '$id',
    ],
  );
}

/// Sunucudan istemciye giden zarf.
class ServerMessage {
  const ServerMessage({
    required this.type,
    this.snapshot,
    this.text,
    this.payload,
  });

  final ServerMessageType type;
  final TableSnapshot? snapshot;
  final String? text;

  /// Duyuru/kurtarma gibi anlik olaylarin ek verisi (or. kurtarma: yetenek+DC).
  final Map<String, dynamic>? payload;

  String encode() => jsonEncode({
    'type': type.name,
    if (snapshot != null) 'snapshot': snapshot!.toJson(),
    if (text != null) 'text': text,
    if (payload != null) 'payload': payload,
  });

  static ServerMessage decode(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return ServerMessage(
      type: ServerMessageType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => ServerMessageType.notice,
      ),
      snapshot: json['snapshot'] == null
          ? null
          : TableSnapshot.fromJson(
              (json['snapshot'] as Map).cast<String, dynamic>(),
            ),
      text: json['text'] as String?,
      payload: json['payload'] == null
          ? null
          : (json['payload'] as Map).cast<String, dynamic>(),
    );
  }
}

/// Istemciden sunucuya giden zarf.
class ClientMessage {
  const ClientMessage({
    required this.type,
    this.playerName,
    this.token,
    this.characterId,
    this.amount,
    this.spentSlots,
    this.stockId,
    this.quantity,
    this.rollLabel,
    this.diceSides,
    this.diceCount,
    this.advantage,
    this.itemId,
    this.inventoryAction,
    this.lootItemId,
    this.lootPinId,
    this.notes,
    this.toCharacterId,
    this.coinsCp,
    this.transferId,
    this.accept,
    this.questId,
    this.chatText,
    this.presence,
    this.partyInventoryId,
    this.creation,
    this.toDm = false,
  });

  final ClientMessageType type;
  final String? playerName;
  final String? token;
  final String? characterId;

  /// Hasar icin negatif, iyilesme icin pozitif.
  final int? amount;
  final Map<int, int>? spentSlots;

  /// Satin alinmak istenen magaza satiri.
  final String? stockId;
  final int? quantity;

  /// Zar atma: ne icin, kac yuzlu, kac tane, avantaj. Modifier `amount`'ta.
  final String? rollLabel;
  final int? diceSides;
  final int? diceCount;
  final Advantage? advantage;

  /// Envanter degisikligi: hangi satir, hangi islem.
  final String? itemId;
  final InventoryAction? inventoryAction;

  /// Ganimetten alinan esyanin id'si (bossa para alinir).
  final String? lootItemId;

  /// `takeTreasureLoot` icin: hazine pininin id'si.
  final String? lootPinId;

  /// `saveNotes` icin: kaydedilecek tam not belgesi (baslik listesi).
  final List<NoteSection>? notes;

  /// `offerTransfer` icin: gonderilecek hedef karakter.
  final String? toCharacterId;

  /// `offerTransfer` icin: gonderilecek para (cp). Esya yerine para gonderilir.
  final int? coinsCp;

  /// `respondTransfer` icin: yanitlanan teklifin id'si ve karar.
  final String? transferId;
  final bool? accept;

  /// `respondQuest` icin: yanitlanan gorevin id'si (karar `accept`).
  final String? questId;

  /// `sendChat` icin: gonderme metni.
  final String? chatText;

  /// `setPresence` icin: 'active' ya da 'away'.
  final String? presence;

  /// `takeParty*` / `depositParty*` icin: ortak kesenin id'si. Esya/adet/para
  /// icin mevcut `itemId`/`quantity`/`coinsCp` alanlari kullanilir.
  final String? partyInventoryId;

  /// `createCharacter` icin: sihirbaz taslagi (ad/sinif/tur/gecmis/puanlar/
  /// beceriler/ekipman secimi/portre). Tek alan halinde tasiniyor; her secim
  /// icin ayri protokol alani acmak mesaji okunamaz hale getirirdi.
  final Map<String, dynamic>? creation;

  /// `sendChat` icin: mesaj DM'e ozel mi? DM'in karakteri olmadigi icin
  /// `toCharacterId` ile ifade edilemiyor.
  final bool toDm;

  String encode() => jsonEncode({
    'type': type.name,
    if (playerName != null) 'playerName': playerName,
    if (token != null) 'token': token,
    if (characterId != null) 'characterId': characterId,
    if (amount != null) 'amount': amount,
    if (spentSlots != null)
      'spentSlots': spentSlots!.map((k, v) => MapEntry('$k', v)),
    if (stockId != null) 'stockId': stockId,
    if (quantity != null) 'quantity': quantity,
    if (rollLabel != null) 'rollLabel': rollLabel,
    if (diceSides != null) 'diceSides': diceSides,
    if (diceCount != null) 'diceCount': diceCount,
    if (advantage != null) 'advantage': advantage!.name,
    if (itemId != null) 'itemId': itemId,
    if (inventoryAction != null) 'inventoryAction': inventoryAction!.name,
    if (lootItemId != null) 'lootItemId': lootItemId,
    if (lootPinId != null) 'lootPinId': lootPinId,
    if (notes != null) 'notes': notesToJson(notes!),
    if (toCharacterId != null) 'toCharacterId': toCharacterId,
    if (coinsCp != null) 'coinsCp': coinsCp,
    if (transferId != null) 'transferId': transferId,
    if (accept != null) 'accept': accept,
    if (questId != null) 'questId': questId,
    if (chatText != null) 'chatText': chatText,
    if (presence != null) 'presence': presence,
    if (partyInventoryId != null) 'partyInventoryId': partyInventoryId,
    if (creation != null) 'creation': creation,
    if (toDm) 'toDm': true,
  });

  static ClientMessage decode(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return ClientMessage(
      type: ClientMessageType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => ClientMessageType.join,
      ),
      playerName: json['playerName'] as String?,
      token: json['token'] as String?,
      characterId: json['characterId'] as String?,
      amount: json['amount'] as int?,
      spentSlots: json['spentSlots'] == null
          ? null
          : _intMap(json['spentSlots']),
      stockId: json['stockId'] as String?,
      quantity: json['quantity'] as int?,
      rollLabel: json['rollLabel'] as String?,
      diceSides: json['diceSides'] as int?,
      diceCount: json['diceCount'] as int?,
      advantage: json['advantage'] == null
          ? null
          : Advantage.values.firstWhere(
              (a) => a.name == json['advantage'],
              orElse: () => Advantage.none,
            ),
      itemId: json['itemId'] as String?,
      inventoryAction: json['inventoryAction'] == null
          ? null
          : InventoryAction.values.firstWhere(
              (a) => a.name == json['inventoryAction'],
              orElse: () => InventoryAction.toggleEquipped,
            ),
      lootItemId: json['lootItemId'] as String?,
      lootPinId: json['lootPinId'] as String?,
      notes: json['notes'] == null ? null : notesFromJson(json['notes']),
      toCharacterId: json['toCharacterId'] as String?,
      coinsCp: json['coinsCp'] as int?,
      transferId: json['transferId'] as String?,
      accept: json['accept'] as bool?,
      questId: json['questId'] as String?,
      chatText: json['chatText'] as String?,
      presence: json['presence'] as String?,
      partyInventoryId: json['partyInventoryId'] as String?,
      creation: json['creation'] == null
          ? null
          : (json['creation'] as Map).cast<String, dynamic>(),
      toDm: json['toDm'] as bool? ?? false,
    );
  }
}

Map<int, int> _intMap(Object? raw) {
  if (raw is! Map) return const {};
  return {
    for (final e in raw.entries)
      if (int.tryParse('${e.key}') case final k?)
        if (e.value is int) k: e.value as int,
  };
}

Map<String, int> _stringIntMap(Object? raw) {
  if (raw is! Map) return const {};
  return {
    for (final e in raw.entries)
      if (e.value is int) '${e.key}': e.value as int,
  };
}
