import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../net/protocol.dart';

/// DM'in istedigi bir kurtarma atisi (yetenek + DC).
typedef SaveRequest = ({String ability, int dc, String id});

/// Baska bir oyuncunun bu oyuncuya gonderme teklifi.
typedef IncomingTransfer = ({
  String id,
  String fromName,
  String itemName,
  bool magic,
  int quantity,
  int coinsCp,
});

/// Oyuncu panelinin sunucuya baglantisi.
///
/// Baglanti koparsa (telefon uykuya girer, tarayici sekmesi arka plana
/// duser) kendiliginden yeniden baglanir ve tam snapshot ister -- masada
/// "benim ekranim donmus" durumunu engellemek icin.
class PlayerClient {
  PlayerClient({required this.uri, this.savedToken, this.onTokenIssued});

  final Uri uri;
  final String? savedToken;

  /// Sunucu kimlik verdiginde cagrilir; istemci bunu localStorage'a yazar
  /// ki sekme yenilendiginde karakteri tekrar sahiplenmek gerekmesin.
  final void Function(String token)? onTokenIssued;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnect;
  bool _disposed = false;

  String? _token;
  String _playerName = 'Oyuncu';

  final _snapshots = StreamController<TableSnapshot>.broadcast();
  final _errors = StreamController<String>.broadcast();
  final _connection = StreamController<bool>.broadcast();
  final _announcements = StreamController<String>.broadcast();
  final _saveRequests = StreamController<SaveRequest>.broadcast();
  final _notes = StreamController<List<NoteSection>>.broadcast();
  final _transfers = StreamController<IncomingTransfer>.broadcast();
  final _notices = StreamController<String>.broadcast();
  final _creationOptions = StreamController<Map<String, dynamic>>.broadcast();

  Stream<TableSnapshot> get snapshots => _snapshots.stream;
  Stream<String> get errors => _errors.stream;
  Stream<bool> get connection => _connection.stream;
  Stream<String> get announcements => _announcements.stream;
  Stream<SaveRequest> get saveRequests => _saveRequests.stream;
  Stream<List<NoteSection>> get notes => _notes.stream;
  Stream<IncomingTransfer> get transfers => _transfers.stream;

  /// DM'in `broadcast(notice:)` ile yolladigi bilgi notu (or. satin alma
  /// onayi). Snapshot mesajinin `text` alaninda gelir; token'dan ayridir.
  Stream<String> get notices => _notices.stream;

  /// Karakter olusturma katalogu (sinif/tur/gecmis). Yalnizca istendiginde
  /// ve yalnizca isteyen sokete gelir.
  Stream<Map<String, dynamic>> get creationOptions => _creationOptions.stream;

  void connect({String? playerName}) {
    if (_disposed) return;
    if (playerName != null && playerName.isNotEmpty) _playerName = playerName;
    _token ??= savedToken;

    _reconnect?.cancel();
    _subscription?.cancel();

    try {
      final channel = WebSocketChannel.connect(
        uri.replace(scheme: uri.scheme == 'https' ? 'wss' : 'ws', path: '/ws'),
      );
      _channel = channel;

      _subscription = channel.stream.listen(
        _onMessage,
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
        cancelOnError: true,
      );

      channel.sink.add(
        ClientMessage(
          type: ClientMessageType.join,
          playerName: _playerName,
          token: _token,
        ).encode(),
      );
      _connection.add(true);
    } on Object {
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    final ServerMessage message;
    try {
      message = ServerMessage.decode('$raw');
    } on FormatException {
      return;
    }

    switch (message.type) {
      case ServerMessageType.snapshot:
        // Token yalnizca `payload`'tan okunur. `text` alani ise DM'in
        // `broadcast(notice:)` bildirimini tasir; eskiden ikisi de `text`'ten
        // okunuyordu ve bir notice geldiginde token bilgi notuyla EZILIYORDU
        // (sonra reconnect'te bozuk token gonderilip claim dusuyordu).
        final token = message.payload?['token'] as String?;
        if (token != null && token.isNotEmpty && _token != token) {
          _token = token;
          onTokenIssued?.call(token);
        }
        final notice = message.text;
        if (notice != null && notice.isNotEmpty) _notices.add(notice);
        if (message.snapshot != null) _snapshots.add(message.snapshot!);
      case ServerMessageType.combat:
        if (message.snapshot != null) _snapshots.add(message.snapshot!);
      case ServerMessageType.notice:
      case ServerMessageType.rejected:
        if (message.text != null) _errors.add(message.text!);
      case ServerMessageType.announcement:
        if (message.text != null) _announcements.add(message.text!);
      case ServerMessageType.saveRequest:
        final p = message.payload;
        if (p != null) {
          _saveRequests.add((
            ability: '${p['ability']}',
            dc: p['dc'] as int? ?? 10,
            id: '${p['id']}',
          ));
        }
      case ServerMessageType.creationOptions:
        final p = message.payload;
        if (p != null) _creationOptions.add(p);
      case ServerMessageType.notes:
        _notes.add(notesFromJson(message.payload?['sections']));
      case ServerMessageType.transferOffer:
        final p = message.payload;
        if (p != null) {
          _transfers.add((
            id: '${p['id']}',
            fromName: '${p['fromName'] ?? ''}',
            itemName: '${p['itemName'] ?? ''}',
            magic: p['magic'] as bool? ?? false,
            quantity: p['quantity'] as int? ?? 1,
            coinsCp: p['coinsCp'] as int? ?? 0,
          ));
        }
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _connection.add(false);
    _reconnect?.cancel();
    // Sabit kisa aralik: yerel agda sunucu ya vardir ya yoktur, ustel
    // geri cekilmeye gerek yok ve masada hizli toparlanmasi onemli.
    _reconnect = Timer(const Duration(seconds: 2), connect);
  }

  void send(ClientMessage message) {
    final channel = _channel;
    if (channel == null) return;
    try {
      channel.sink.add(message.encode());
    } on StateError {
      _scheduleReconnect();
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _reconnect?.cancel();
    await _subscription?.cancel();
    await _channel?.sink.close();
    await _snapshots.close();
    await _errors.close();
    await _connection.close();
    await _announcements.close();
    await _saveRequests.close();
    await _creationOptions.close();
    await _notes.close();
    await _transfers.close();
    await _notices.close();
  }
}

/// Panelin durumu.
class PlayerState {
  const PlayerState({
    this.snapshot,
    this.connected = false,
    this.claimedCharacterId,
    this.lastError,
    this.playerName = '',
    this.announcement,
    this.announcementSeq = 0,
    this.notice,
    this.noticeSeq = 0,
    this.saveRequest,
    this.notes = const [],
    this.incomingTransfer,
    this.questAlert,
    this.questAlertSeq = 0,
    this.questTabRequestSeq = 0,
    this.creationOptions,
  });

  final TableSnapshot? snapshot;
  final bool connected;

  /// Karakter olusturma katalogu; `null` = henuz istenmedi/gelmedi.
  final Map<String, dynamic>? creationOptions;
  final String? claimedCharacterId;
  final String? lastError;

  /// Baska bir oyuncunun bekleyen gonderme teklifi (kabul/ret pop-up'i icin).
  final IncomingTransfer? incomingTransfer;

  /// Oyuncunun kendi (karaktere bagli) not belgesi. Sunucudan gelir; oyuncu
  /// duzenledikce sunucuya kaydedilir.
  final List<NoteSection> notes;

  /// Bu cihazdaki oyuncunun adi. Paylasilan zar gunlugunde `source == playerName`
  /// olan atislar "benim atislarim"dir -- zar pop-up'i yalnizca onlarda cikar.
  final String playerName;

  /// DM'in gonderdigi son duyuru; [announcementSeq] her yeni duyuruda artar
  /// (pop-up'i bir kez acmak icin).
  final String? announcement;
  final int announcementSeq;

  /// DM'in `broadcast(notice:)` ile yolladigi son bilgi notu (or. "X aldi.",
  /// "istegin DM onayinda."); [noticeSeq] her yeni notta artar (SnackBar'i bir
  /// kez gostermek icin). Duyurudan farkli: ortada pop-up yerine hafif SnackBar.
  final String? notice;
  final int noticeSeq;

  /// DM su an kurtarma atisi istediyse.
  final SaveRequest? saveRequest;

  /// Snapshot'tan TURETILEN gorev uyarisi: yeni bir gorev/oylama geldiginde
  /// ya da bir gorevin odulu dagitima acildiginda dolar. [questAlertSeq] her
  /// yeni uyarida artar (pop-up/SnackBar'i bir kez gostermek icin; duyuru ve
  /// bilgi notundaki "seq" deseninin aynisi).
  ///
  /// Sunucuya yeni bir mesaj tipi EKLENMEDI: gorev paylasimi, oylama baslangici
  /// ve odul havuzu zaten snapshot'a dusuyor; onu onceki snapshot'la
  /// karsilastirmak her yolu (DM'in hangi ekrandan paylastigi farketmeksizin)
  /// kendiliginden yakalar.
  final QuestAlert? questAlert;
  final int questAlertSeq;

  /// "Gorevlere git" istegi; her istekte artar. Sekme durumu alt agacta
  /// (`_ClaimedView`) yasadigi icin istek durum uzerinden tasinir.
  final int questTabRequestSeq;

  PlayerCharacterView? get myCharacter {
    final id = claimedCharacterId;
    if (id == null) return null;
    return snapshot?.characters.where((c) => c.id == id).firstOrNull;
  }

  PlayerState copyWith({
    TableSnapshot? snapshot,
    bool? connected,
    String? claimedCharacterId,
    String? lastError,
    String? playerName,
    String? announcement,
    int? announcementSeq,
    String? notice,
    int? noticeSeq,
    SaveRequest? saveRequest,
    bool clearSaveRequest = false,
    List<NoteSection>? notes,
    IncomingTransfer? incomingTransfer,
    bool clearIncomingTransfer = false,
    QuestAlert? questAlert,
    int? questAlertSeq,
    int? questTabRequestSeq,
    Map<String, dynamic>? creationOptions,
  }) => PlayerState(
    snapshot: snapshot ?? this.snapshot,
    connected: connected ?? this.connected,
    claimedCharacterId: claimedCharacterId ?? this.claimedCharacterId,
    lastError: lastError,
    playerName: playerName ?? this.playerName,
    announcement: announcement ?? this.announcement,
    announcementSeq: announcementSeq ?? this.announcementSeq,
    notice: notice ?? this.notice,
    noticeSeq: noticeSeq ?? this.noticeSeq,
    saveRequest: clearSaveRequest ? null : (saveRequest ?? this.saveRequest),
    notes: notes ?? this.notes,
    incomingTransfer: clearIncomingTransfer
        ? null
        : (incomingTransfer ?? this.incomingTransfer),
    questAlert: questAlert ?? this.questAlert,
    questAlertSeq: questAlertSeq ?? this.questAlertSeq,
    questTabRequestSeq: questTabRequestSeq ?? this.questTabRequestSeq,
    creationOptions: creationOptions ?? this.creationOptions,
  );

  /// Islem bekleyen gorev sayisi (sekme rozeti).
  ///
  /// Ayri bir "okundu" durumu tutulmaz: sayi zaten YAPILACAK isi sayar, oyuncu
  /// kabul/ret verince ya da odulu alinca kendiliginden duser.
  int get pendingQuestCount {
    final quests = snapshot?.quests ?? const <QuestView>[];
    return quests.where((q) => q.rewardReady || q.myStatus == null).length;
  }
}

/// Oyuncuya gosterilecek gorev uyarisinin turu.
enum QuestAlertKind {
  /// Yeni gorev teklifi (tek tek kabul modu).
  offered,

  /// Ekip oylamasi basladi.
  vote,

  /// Gorev tamamlandi, odul havuzu acildi.
  reward,
}

/// Snapshot karsilastirmasindan cikan gorev uyarisi.
class QuestAlert {
  const QuestAlert({required this.kind, required this.quest});

  final QuestAlertKind kind;
  final QuestView quest;
}

class PlayerController extends Notifier<PlayerState> {
  PlayerClient? _client;

  @override
  PlayerState build() {
    ref.onDispose(() => _client?.dispose());
    return const PlayerState();
  }

  void connect({
    required Uri uri,
    required String playerName,
    String? savedToken,
    void Function(String token)? onTokenIssued,
  }) {
    _client?.dispose();
    final client = PlayerClient(
      uri: uri,
      savedToken: savedToken,
      onTokenIssued: onTokenIssued,
    );
    _client = client;

    state = state.copyWith(playerName: playerName);
    client.snapshots.listen(_onSnapshot);
    client.connection.listen((c) {
      state = state.copyWith(connected: c);
      // Yeniden baglanmada (uyku/sekme donusu) notlari tazele: sunucu tarafi
      // token'dan karakteri geri yukledigi icin istek dogru sokete doner.
      if (c && state.claimedCharacterId != null) _requestNotes();
    });
    client.errors.listen((e) => state = state.copyWith(lastError: e));
    client.creationOptions.listen(
      (o) => state = state.copyWith(creationOptions: o),
    );
    client.notes.listen((n) => state = state.copyWith(notes: n));
    client.transfers.listen((t) => state = state.copyWith(incomingTransfer: t));
    client.announcements.listen(
      (text) => state = state.copyWith(
        announcement: text,
        announcementSeq: state.announcementSeq + 1,
      ),
    );
    client.saveRequests.listen(
      (req) => state = state.copyWith(saveRequest: req),
    );
    client.notices.listen(
      (text) =>
          state = state.copyWith(notice: text, noticeSeq: state.noticeSeq + 1),
    );

    client.connect(playerName: playerName);
  }

  /// Ilk snapshot'ta uyari cikarilmaz: yeniden baglanmada (uyku/sekme donusu)
  /// mevcut TUM gorevler "yeni" gorunur ve oyuncuya dialog yagardi.
  bool _questBaseline = false;

  /// Testler icin: sokete baglanmadan snapshot besler (gorev uyarisi mantigi
  /// gercek bir LAN sunucusu olmadan dogrulanabilsin diye).
  void debugApplySnapshot(TableSnapshot snapshot) => _onSnapshot(snapshot);

  /// Yeni snapshot'i oncekiyle karsilastirip gorev uyarisi uretir.
  void _onSnapshot(TableSnapshot next) {
    final previous = state.snapshot?.quests ?? const <QuestView>[];
    final alert = _questBaseline
        ? _detectQuestAlert(previous, next.quests)
        : null;
    _questBaseline = true;

    state = alert == null
        ? state.copyWith(snapshot: next)
        : state.copyWith(
            snapshot: next,
            questAlert: alert,
            questAlertSeq: state.questAlertSeq + 1,
          );
  }

  /// Tek bir uyari dondurur (ilk bulunan); masaya ust uste dialog yigmamak icin.
  static QuestAlert? _detectQuestAlert(
    List<QuestView> previous,
    List<QuestView> current,
  ) {
    QuestView? before(String id) =>
        previous.where((q) => q.id == id).firstOrNull;

    for (final quest in current) {
      final old = before(quest.id);
      // Odul havuzu YENI acildi.
      if (quest.rewardReady && !(old?.rewardReady ?? false)) {
        return QuestAlert(kind: QuestAlertKind.reward, quest: quest);
      }
      // Karar bekleyen YENI gorev (ya da yeniden paylasilmis gorev).
      if (!quest.rewardReady &&
          quest.myStatus == null &&
          (old == null || old.myStatus != null)) {
        return QuestAlert(
          kind: quest.mode == 'vote'
              ? QuestAlertKind.vote
              : QuestAlertKind.offered,
          quest: quest,
        );
      }
    }
    return null;
  }

  /// Gorevler sekmesine gecmeyi ister (odul SnackBar'indaki "Aç" aksiyonu).
  void openQuestsTab() =>
      state = state.copyWith(questTabRequestSeq: state.questTabRequestSeq + 1);

  /// Karakter olusturma katalogunu ister (yanit `creationOptions` ile gelir).
  void requestCreationOptions() {
    _client?.send(
      const ClientMessage(type: ClientMessageType.requestCreationOptions),
    );
  }

  /// Oyuncunun kurdugu karakteri sunucuya yollar. Sunucu dogrular, yazar ve
  /// karakteri bu oyuncuya sahiplendirir; sonuc snapshot ile geri gelir.
  void createCharacter(Map<String, dynamic> draft) {
    _client?.send(
      ClientMessage(type: ClientMessageType.createCharacter, creation: draft),
    );
  }

  void claim(String characterId) {
    state = state.copyWith(claimedCharacterId: characterId);
    _client?.send(
      ClientMessage(
        type: ClientMessageType.claimCharacter,
        characterId: characterId,
      ),
    );
    // Karakter secilir secilmez kayitli notlarini iste.
    _requestNotes();
  }

  void _requestNotes() =>
      _client?.send(const ClientMessage(type: ClientMessageType.requestNotes));

  /// Not belgesini butunuyle kaydeder (sunucuya gonderir, yereli gunceller).
  void saveNotes(List<NoteSection> sections) {
    state = state.copyWith(notes: sections);
    _client?.send(
      ClientMessage(type: ClientMessageType.saveNotes, notes: sections),
    );
  }

  void changeHitPoints(int amount) => _client?.send(
    ClientMessage(type: ClientMessageType.updateHitPoints, amount: amount),
  );

  void setSpentSlots(Map<int, int> spent) => _client?.send(
    ClientMessage(type: ClientMessageType.setSpentSlots, spentSlots: spent),
  );

  /// Inisiyatif atar. Sunucu d20 + karakterin inisiyatif modifiyesini atar,
  /// katilimciyi siraya oturtur ve sonucu paylasilan gunluge dusurur. [label]
  /// paylasilan gunlukte gorunen yerellestirilmis etiket.
  void rollInitiative({required String label}) => _client?.send(
    ClientMessage(type: ClientMessageType.rollInitiative, rollLabel: label),
  );

  /// 0 HP'deyken olum kurtarma atisi ister. Sunucu d20 atar, 5e kurallarini
  /// uygular ve sonucu paylasilan gunluge dusurur. [label] paylasilan gunlukte
  /// gorunen (yerellestirilmis) etiket.
  void rollDeathSave({required String label}) => _client?.send(
    ClientMessage(type: ClientMessageType.rollDeathSave, rollLabel: label),
  );

  void buy(String stockId, {int quantity = 1}) => _client?.send(
    ClientMessage(
      type: ClientMessageType.buyItem,
      stockId: stockId,
      quantity: quantity,
    ),
  );

  /// Zar atar; sunucu atip herkese yayinladigi icin sonuc paylasilan
  /// gunluge dusuyor.
  void rollDice({
    required String label,
    int sides = 20,
    int count = 1,
    int modifier = 0,
    Advantage advantage = Advantage.none,
  }) => _client?.send(
    ClientMessage(
      type: ClientMessageType.rollDice,
      rollLabel: label,
      diceSides: sides,
      diceCount: count,
      amount: modifier,
      advantage: advantage,
    ),
  );

  void toggleEquipped(String itemId) => _client?.send(
    ClientMessage(
      type: ClientMessageType.inventoryChange,
      itemId: itemId,
      inventoryAction: InventoryAction.toggleEquipped,
    ),
  );

  void dropItem(String itemId) => _client?.send(
    ClientMessage(
      type: ClientMessageType.inventoryChange,
      itemId: itemId,
      inventoryAction: InventoryAction.drop,
    ),
  );

  /// Acik kisa dinlenmede bir hit die harcar.
  ///
  /// Dinlenmeyi baslatmak DM'in isi; oyuncunun istedigi an dinlenmesi
  /// BILINCLI OLARAK kaldirildi (uzun dinlenmenin oyuncu karsiligi da yok).
  void spendHitDie() =>
      _client?.send(const ClientMessage(type: ClientMessageType.spendHitDie));

  /// Ganimetten bir esyayi al.
  void takeLootItem(String lootItemId) => _client?.send(
    ClientMessage(type: ClientMessageType.takeLoot, lootItemId: lootItemId),
  );

  /// Ganimetteki parayi al.
  void takeLootCoins() =>
      _client?.send(const ClientMessage(type: ClientMessageType.takeLoot));

  /// Haritadaki hazine pininden bir esyayi al.
  void takeTreasureLootItem(String pinId, String itemId) => _client?.send(
    ClientMessage(
      type: ClientMessageType.takeTreasureLoot,
      lootPinId: pinId,
      lootItemId: itemId,
    ),
  );

  /// Haritadaki hazine pinindeki parayi al.
  void takeTreasureLootCoins(String pinId) => _client?.send(
    ClientMessage(type: ClientMessageType.takeTreasureLoot, lootPinId: pinId),
  );

  /// Haritadaki hazine pininden kalan TUM ganimeti al ve pini bitir.
  void takeAllTreasureLoot(String pinId) => _client?.send(
    ClientMessage(
      type: ClientMessageType.takeAllTreasureLoot,
      lootPinId: pinId,
    ),
  );

  // --- Ortak parti kesesi --------------------------------------------------

  /// Ortak keseden esya al. [itemId] kesedeki kalici uuid'dir.
  void takePartyItem(String inventoryId, String itemId, {int quantity = 1}) =>
      _client?.send(
        ClientMessage(
          type: ClientMessageType.takePartyItem,
          partyInventoryId: inventoryId,
          itemId: itemId,
          quantity: quantity,
        ),
      );

  /// Ortak keseden para al. [amountCp] bossa kalanin tamami alinir.
  void takePartyCoins(String inventoryId, {int? amountCp}) => _client?.send(
    ClientMessage(
      type: ClientMessageType.takePartyCoins,
      partyInventoryId: inventoryId,
      coinsCp: amountCp,
    ),
  );

  /// Kendi envanterinden ortak keseye esya koy. [itemId] KENDI envanter
  /// satirinin id'sidir.
  void depositPartyItem(
    String inventoryId,
    String itemId, {
    int quantity = 1,
  }) => _client?.send(
    ClientMessage(
      type: ClientMessageType.depositPartyItem,
      partyInventoryId: inventoryId,
      itemId: itemId,
      quantity: quantity,
    ),
  );

  /// Kendi kesenden ortak keseye para koy.
  void depositPartyCoins(String inventoryId, int amountCp) => _client?.send(
    ClientMessage(
      type: ClientMessageType.depositPartyCoins,
      partyInventoryId: inventoryId,
      coinsCp: amountCp,
    ),
  );

  /// Baska bir oyuncuya esya gonderme teklifi.
  void offerItem({
    required String toCharacterId,
    required String itemId,
    int quantity = 1,
  }) => _client?.send(
    ClientMessage(
      type: ClientMessageType.offerTransfer,
      toCharacterId: toCharacterId,
      itemId: itemId,
      quantity: quantity,
    ),
  );

  /// Baska bir oyuncuya para gonderme teklifi (cp).
  void offerCoins({required String toCharacterId, required int coinsCp}) =>
      _client?.send(
        ClientMessage(
          type: ClientMessageType.offerTransfer,
          toCharacterId: toCharacterId,
          coinsCp: coinsCp,
        ),
      );

  /// Gelen bir gonderme teklifini yanitlar (kabul/ret) ve pop-up'i kapatir.
  void respondTransfer(String id, {required bool accept}) {
    _client?.send(
      ClientMessage(
        type: ClientMessageType.respondTransfer,
        transferId: id,
        accept: accept,
      ),
    );
    state = state.copyWith(clearIncomingTransfer: true);
  }

  /// DM'in gosterdigi bir gorevi kabul/reddeder. Durum snapshot'tan (myStatus)
  /// geldigi icin ayri state gerekmez; sunucu yaziip yeni snapshot yayinlar.
  void respondQuest(String id, {required bool accept}) {
    _client?.send(
      ClientMessage(
        type: ClientMessageType.respondQuest,
        questId: id,
        accept: accept,
      ),
    );
  }

  /// Tamamlanan gorevin odul havuzundan bir esyayi al.
  void takeQuestRewardItem(String questId, String itemId) => _client?.send(
    ClientMessage(
      type: ClientMessageType.takeQuestReward,
      questId: questId,
      lootItemId: itemId,
    ),
  );

  /// Tamamlanan gorevin odul havuzundaki parayi al.
  void takeQuestRewardCoins(String questId) => _client?.send(
    ClientMessage(type: ClientMessageType.takeQuestReward, questId: questId),
  );

  /// Odul havuzunda kalan TUM ganimeti al (gorev kapanir).
  void takeAllQuestReward(String questId) => _client?.send(
    ClientMessage(type: ClientMessageType.takeAllQuestReward, questId: questId),
  );

  /// Sohbet mesaji gonderir. [toCharacterId] bossa genel (herkes + DM gorur),
  /// doluysa fisilti (yalnizca hedef + DM gorur). Mesajlar snapshot'ta
  /// [PlayerState.snapshot.chats] uzerinden geri doner.
  void sendChat(String text, {String? toCharacterId, bool toDm = false}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _client?.send(
      ClientMessage(
        type: ClientMessageType.sendChat,
        chatText: trimmed,
        toCharacterId: toCharacterId,
        toDm: toDm,
      ),
    );
  }

  /// Oyuncunun tarayici gorunurlugunu sunucuya bildirir: `'active'` (sekme
  /// on planda) ya da `'away'` (arka plana gecti). DM paneli bunu izler.
  void setPresence(String presence) {
    _client?.send(
      ClientMessage(type: ClientMessageType.setPresence, presence: presence),
    );
  }

  /// Gelen teklif pop-up'ini (yanit vermeden) temizler.
  void clearIncomingTransfer() =>
      state = state.copyWith(clearIncomingTransfer: true);

  /// Kurtarma istegini (atildiktan/gorulduktan sonra) temizler.
  void clearSaveRequest() => state = state.copyWith(clearSaveRequest: true);

  /// Bilgi/hata notunu temizler (kullanici okuduktan sonra).
  void clearMessage() => state = state.copyWith();
}

final playerControllerProvider =
    NotifierProvider<PlayerController, PlayerState>(PlayerController.new);
