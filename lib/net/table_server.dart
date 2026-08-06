import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'protocol.dart';

/// Baglanmis bir oyuncu.
class ConnectedPlayer {
  ConnectedPlayer({
    required this.token,
    required this.name,
    this.characterId,
    this.presence = PlayerPresence.active,
  });

  final String token;
  String name;
  String? characterId;

  /// Tarayici gorunurlugu: arka plana gecince 'away', donunce 'active'.
  /// DM paneli bu degeri renkli nokta olarak gosterir.
  PlayerPresence presence;

  /// Son baglanti koptugu an; soket kapaliyken ("offline") DM bunu gorur.
  DateTime? lastSeen;
}

/// DM cihazinda calisan yerel ag sunucusu.
///
/// Oyuncular ayni Wi-Fi uzerinden tarayiciyla baglanir; hesap ya da internet
/// gerekmez. Sunucu iki sey servis eder: gomulu oyuncu paneli (statik web
/// derlemesi) ve `/ws` uzerindeki gercek zamanli kanal.
///
/// DM otoritedir: istemciden gelen her mesaj [onClientMessage] ile dogrulanir,
/// veritabanina DM tarafinda yazilir ve sonuc [broadcast] ile herkese
/// yayinlanir. Istemci kendi durumunu asla dogrudan degistirmez.
class TableServer {
  TableServer({
    required this.buildSnapshot,
    required this.onClientMessage,
    this.questsFor,
    this.chatsFor,
    this.partyInventoriesFor,
    this.playerAppHandler,
    this.resolveMedia,
  });

  /// Guncel durumu uretir. Her yeni baglantida ve her yayinda cagrilir.
  final Future<TableSnapshot> Function() buildSnapshot;

  /// Verilen karakteri sahiplenen oyuncuya gösterilecek görevleri döner
  /// (oyuncu-başına süzme). Verilmezse snapshot'taki görevler kullanılır.
  final Future<List<QuestView>> Function(String? characterId)? questsFor;

  /// Verilen karakteri sahiplenen oyuncunun görebildiği sohbet mesajlarını
  /// döner (genel + kendine gelen/gönderdiği fısıltılar; DM her şeyi görür).
  /// Verilmezse snapshot'taki mesajlar kullanılır.
  final Future<List<ChatMessage>> Function(String? characterId)? chatsFor;

  /// Verilen karakterin ÜYE OLDUĞU ortak keseleri döner; üye olmadığı kese
  /// hiç gönderilmez. Verilmezse snapshot'taki liste kullanılır.
  final Future<List<PartyInventoryView>> Function(String? characterId)?
  partyInventoriesFor;

  /// Oyuncudan gelen istegi uygular. Hata mesaji donerse istemciye
  /// `rejected` olarak iletilir; null donerse islem kabul edilmistir.
  final Future<String?> Function(ConnectedPlayer player, ClientMessage message)
  onClientMessage;

  /// Gomulu oyuncu web uygulamasini servis eden handler. Verilmezse
  /// koke kisa bir bilgi sayfasi konur (Faz 1b'de web derlemesi eklenene
  /// kadar boyle calisir).
  final Handler? playerAppHandler;

  /// Harita gorsellerini cozer. Kimlik yerine dosya adi kullaniliyor;
  /// yerel agda ek bir yetkilendirme katmanina gerek yok ve oyuncunun
  /// tarayicisi gorseli dogrudan `<img>` ile indirebiliyor.
  final Future<File?> Function(String name)? resolveMedia;

  HttpServer? _server;
  final _sockets = <WebSocketChannel, ConnectedPlayer>{};
  final _players = <String, ConnectedPlayer>{};

  /// Oturum kodu: QR'a ve adrese girer, yanlis masaya baglanmayi engeller.
  late String sessionCode;

  bool get isRunning => _server != null;
  int get port => _server?.port ?? 0;
  List<ConnectedPlayer> get players => _players.values.toList();

  /// Su anda canli soketi olan oyuncularin token'lari. DM paneli "online"
  /// durumunu bu kumeye gore belirler (token kimligi kopmalarda korunur).
  Set<String> get connectedTokens =>
      {for (final p in _sockets.values) p.token}..remove('');

  final _playersChanged = StreamController<void>.broadcast();
  Stream<void> get playersChanged => _playersChanged.stream;

  /// Sunucuyu baslatir ve dinledigi adresi doner.
  Future<Uri> start({int preferredPort = 8080}) async {
    if (_server != null) return joinUri;

    sessionCode = _generateCode();

    final router = Router()
      ..get('/ws', webSocketHandler(_onSocket))
      ..get('/api/health', (Request request) => Response.ok('ok'))
      ..get('/media/<name>', _serveMedia);

    final handler = const Pipeline()
        .addMiddleware(logRequests(logger: (_, _) {}))
        .addHandler(
          Cascade()
              .add(router.call)
              .add(playerAppHandler ?? _fallbackApp)
              .handler,
        );

    // 0.0.0.0: yalnizca localhost degil, yerel agdan da erisilebilsin.
    // Port mesgulse sistemin bos bir port secmesine izin veriyoruz.
    try {
      _server = await shelf_io.serve(handler, '0.0.0.0', preferredPort);
    } on SocketException {
      _server = await shelf_io.serve(handler, '0.0.0.0', 0);
    }
    return joinUri;
  }

  Future<void> stop() async {
    for (final socket in _sockets.keys.toList()) {
      await socket.sink.close();
    }
    _sockets.clear();
    await _server?.close(force: true);
    _server = null;
  }

  /// Oyuncularin tarayicisina yazacagi adres.
  Uri get joinUri => Uri(
    scheme: 'http',
    host: _lanAddress ?? 'localhost',
    port: port,
    queryParameters: {'s': sessionCode},
  );

  String? _lanAddress;

  /// Cihazin yerel ag adresini disaridan verir (network_info_plus ya da
  /// NetworkInterface ile bulunur; burasi saf tutulsun diye enjekte ediliyor).
  set lanAddress(String? value) => _lanAddress = value;

  /// Guncel durumu tum baglantilara yollar. Gorevler ve sohbet mesajlari
  /// oyuncu-basina suzuldugu icin [questsFor]/[chatsFor] verilirse her sokete
  /// o oyuncuya ait verilerle ayri kodlanmis snapshot gonderilir; hicbiri
  /// verilmezse ayni snapshot herkese gider.
  Future<void> broadcast({String? notice}) async {
    if (_sockets.isEmpty) return;
    final base = await buildSnapshot();
    final perPlayer =
        questsFor != null || chatsFor != null || partyInventoriesFor != null;

    if (!perPlayer) {
      final message = ServerMessage(
        type: ServerMessageType.snapshot,
        snapshot: base,
        text: notice,
      ).encode();
      for (final socket in _sockets.keys.toList()) {
        try {
          socket.sink.add(message);
        } on StateError {
          // Kapanmis soket; temizligi onDone yapiyor.
        }
      }
      return;
    }

    for (final entry in _sockets.entries.toList()) {
      final snap = await _filterFor(base, entry.value.characterId);
      final message = ServerMessage(
        type: ServerMessageType.snapshot,
        snapshot: snap,
        text: notice,
      ).encode();
      try {
        entry.key.sink.add(message);
      } on StateError {
        // Kapanmis soket; temizligi onDone yapiyor.
      }
    }
  }

  /// Taban snapshot'i bu karakterin oyuncusu icin suzer (gorev + sohbet +
  /// ortak keseler).
  Future<TableSnapshot> _filterFor(
    TableSnapshot base,
    String? characterId,
  ) async {
    var snap = base;
    if (questsFor != null) {
      snap = snap.copyWith(quests: await questsFor!(characterId));
    }
    if (chatsFor != null) {
      snap = snap.copyWith(chats: await chatsFor!(characterId));
    }
    if (partyInventoriesFor != null) {
      snap = snap.copyWith(
        partyInventories: await partyInventoriesFor!(characterId),
      );
    }
    return snap;
  }

  /// Anlik bir mesaji (duyuru/kurtarma) oyunculara yollar. [characterId]
  /// verilirse yalnizca o karakteri sahiplenen oyuncuya; yoksa herkese.
  /// [token] verilirse mesaj YALNIZ o oyuncunun soketine gider. Karakteri
  /// olmayan oyuncuya (henuz sahiplenmemis / karakter kuruyor) ulasmanin tek
  /// yolu bu: [characterId] ile suzmek onlari disarida birakiyordu.
  void pushToPlayers(
    ServerMessage message, {
    String? characterId,
    String? token,
  }) {
    final encoded = message.encode();
    for (final entry in _sockets.entries.toList()) {
      if (characterId != null && entry.value.characterId != characterId) {
        continue;
      }
      if (token != null && entry.value.token != token) continue;
      try {
        entry.key.sink.add(encoded);
      } on StateError {
        // Kapanmis soket; temizligi onDone yapiyor.
      }
    }
  }

  /// Harita onizlemelerini servis eder.
  Future<Response> _serveMedia(Request request, String name) async {
    final resolver = resolveMedia;
    if (resolver == null) return Response.notFound('Medya yok');

    // Dosya adi disina cikilamasin.
    if (name.contains('/') || name.contains('\\') || name.contains('..')) {
      return Response.forbidden('Geçersiz ad');
    }

    final file = await resolver(name);
    if (file == null || !file.existsSync()) {
      return Response.notFound('Bulunamadı');
    }

    // Baytlari onceden okuyup GOVDEYI SABIT UZUNLUKLA sunuyoruz. `openRead()`
    // akisi Content-Length yerine `Transfer-Encoding: chunked` uretiyordu;
    // masaustu tarayici bunu tolere etse de mobil tarayici chunked + keep-alive
    // durumunda cevabin bittigini yakalayamayip istegi sonsuza dek "beklemede"
    // tutabiliyor -- oyuncunun ekraninda harita "bos/gri, surekli donuyor"
    // olarak goruluyordu. Onizleme gorselleri kucuk (<~1 MB), bellege almak
    // sorun degil. Content-Length ile cerceveleme her tarayicida kesin.
    final bytes = await file.readAsBytes();
    return Response.ok(
      bytes,
      headers: {
        'content-type': name.endsWith('.png') ? 'image/png' : 'image/jpeg',
        'content-length': '${bytes.length}',
        // Haritalar buyuk ve degismiyor; tarayici onbellege alsin.
        'cache-control': 'max-age=3600',
        // Flutter Web'in CanvasKit motoru gorseli canvas'a cizerken CORS
        // basligi ariyor; yoksa harita "yüklenemedi"ye dusuyordu. Yerel
        // agda serbest izin zararsiz.
        'access-control-allow-origin': '*',
      },
    );
  }

  void _onSocket(WebSocketChannel channel, String? protocol) {
    // Kimlik `join` mesajiyla belirlenene kadar gecici bir kayit.
    final pending = ConnectedPlayer(token: '', name: 'Bağlanıyor…');
    _sockets[channel] = pending;

    channel.stream.listen(
      (raw) async {
        ClientMessage message;
        try {
          message = ClientMessage.decode('$raw');
        } on FormatException {
          return;
        }

        if (message.type == ClientMessageType.join) {
          final player = _resolvePlayer(message);
          _sockets[channel] = player;
          _playersChanged.add(null);
          final snap = await _filterFor(
            await buildSnapshot(),
            player.characterId,
          );
          channel.sink.add(
            ServerMessage(
              type: ServerMessageType.snapshot,
              snapshot: snap,
              // Istemci token'i saklayip yeniden baglanmada kullanir. Token
              // `payload`'ta gider; `text` alani `broadcast(notice:)`'in bilgi
              // notuna ayrildi (ikisini karistirmak token'i bozuyordu).
              payload: {'token': player.token},
            ).encode(),
          );
          return;
        }

        final player = _sockets[channel];
        if (player == null || player.token.isEmpty) {
          channel.sink.add(
            ServerMessage(
              type: ServerMessageType.rejected,
              text: encodeServerMsg('mustJoinFirst'),
            ).encode(),
          );
          return;
        }

        // Varlik durumu isletimseldir; oturum servisine gitmez.
        if (message.type == ClientMessageType.setPresence) {
          player.presence = message.presence == 'away'
              ? PlayerPresence.away
              : PlayerPresence.active;
          _playersChanged.add(null);
          return;
        }

        final error = await onClientMessage(player, message);
        if (error != null) {
          channel.sink.add(
            ServerMessage(
              type: ServerMessageType.rejected,
              text: error,
            ).encode(),
          );
          return;
        }
        _playersChanged.add(null);
        await broadcast();
      },
      onDone: () {
        _markDisconnected(channel);
        _sockets.remove(channel);
        _playersChanged.add(null);
      },
      onError: (_) {
        _markDisconnected(channel);
        _sockets.remove(channel);
        _playersChanged.add(null);
      },
      cancelOnError: true,
    );
  }

  /// Soket kapaninca son gorulme anini isaretler. Oyuncu `_players`'ta kalir
  /// (token ile yeniden baglanir) ama "online" degildir; DM paneli gri nokta
  /// + son gorulme zamanini gosterir.
  void _markDisconnected(WebSocketChannel channel) {
    final p = _sockets[channel];
    if (p != null && p.token.isNotEmpty) p.lastSeen = DateTime.now();
  }

  /// Token varsa onceki kimligi geri verir; yoksa yeni oyuncu acar.
  ///
  /// Tarayici sekmesi kapanip acildiginda oyuncunun karakterini yeniden
  /// sahiplenmesi gerekmesin diye token localStorage'da saklaniyor.
  ConnectedPlayer _resolvePlayer(ClientMessage message) {
    final existing = message.token == null ? null : _players[message.token];
    if (existing != null) {
      if (message.playerName != null && message.playerName!.isNotEmpty) {
        existing.name = message.playerName!;
      }
      return existing;
    }

    final token = _generateToken();
    final player = ConnectedPlayer(
      token: token,
      name: message.playerName?.trim().isNotEmpty ?? false
          ? message.playerName!.trim()
          : 'Oyuncu',
    );
    _players[token] = player;
    return player;
  }

  /// Oyuncu web uygulamasi henuz gomulmediginde gosterilen sayfa.
  Response _fallbackApp(Request request) => Response.ok(
    '<!doctype html><meta charset="utf-8">'
    '<title>DM Table</title>'
    '<body style="font-family:system-ui;padding:2rem">'
    '<h1>DM Table</h1>'
    '<p>Sunucu çalışıyor. Oturum kodu: <b>$sessionCode</b></p>'
    '<p>Oyuncu paneli bu sürüme henüz gömülmedi.</p>',
    headers: {'content-type': 'text/html; charset=utf-8'},
  );

  static String _generateCode() {
    // Karistirilmasi kolay harfler (I, O, 0, 1) disarida.
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final now = DateTime.now().microsecondsSinceEpoch;
    var value = now;
    final buffer = StringBuffer();
    for (var i = 0; i < 4; i++) {
      buffer.write(alphabet[value % alphabet.length]);
      value ~/= alphabet.length;
    }
    return buffer.toString();
  }

  static String _generateToken() => base64Url.encode(
    List.generate(
      12,
      (i) => (DateTime.now().microsecondsSinceEpoch + i * 7919) % 256,
    ),
  );
}
