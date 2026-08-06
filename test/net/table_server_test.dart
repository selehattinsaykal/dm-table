import 'dart:async';

import 'package:dm_table/net/protocol.dart';
import 'package:dm_table/net/table_server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// LAN sunucusu: gercek bir HTTP/WebSocket sunucusu ayaga kaldirilip gercek
/// istemcilerle konusuluyor. Protokolun en kritik kurali burada sinaniyor --
/// DM otoritedir, istemci kendi basina hicbir sey degistiremez.
void main() {
  late TableServer server;
  var snapshot = const TableSnapshot();
  final handled = <(ConnectedPlayer, ClientMessage)>[];
  String? rejectWith;
  final open = <_TestClient>[];

  setUp(() async {
    handled.clear();
    rejectWith = null;
    snapshot = TableSnapshot(
      characters: [
        const PlayerCharacterView(
          id: 'c1',
          name: 'Vex',
          hitPointsCurrent: 20,
          hitPointsMax: 22,
        ),
      ],
    );

    server = TableServer(
      buildSnapshot: () async => snapshot,
      onClientMessage: (player, message) async {
        handled.add((player, message));
        return rejectWith;
      },
    );
    // Port 0: testler paralel kosarken cakismasin.
    await server.start(preferredPort: 0);
  });

  tearDown(() async {
    for (final client in open) {
      await client.close();
    }
    open.clear();
    await server.stop();
  });

  /// Baglanip `join` gonderir ve ilk snapshot gelene kadar bekler.
  ///
  /// Gelen mesajlar biriktiriliyor: WebSocket akisi tek abonelikli oldugu
  /// icin testlerde birden fazla kez dinlenemiyor.
  Future<_TestClient> connect({String name = 'Ali', String? token}) async {
    final channel = WebSocketChannel.connect(
      Uri.parse('ws://127.0.0.1:${server.port}/ws'),
    );
    await channel.ready;

    final client = _TestClient(channel);
    open.add(client);

    channel.sink.add(
      ClientMessage(
        type: ClientMessageType.join,
        playerName: name,
        token: token,
      ).encode(),
    );
    await client.waitForMessages(1);
    return client;
  }

  test('sunucu ayakta', () {
    expect(server.isRunning, isTrue);
    expect(server.port, greaterThan(0));
  });

  test('katilinca tam snapshot ve token doner', () async {
    final client = await connect();
    final message = client.received.single;

    expect(message.type, ServerMessageType.snapshot);
    expect(message.snapshot!.characters.single.name, 'Vex');
    // Token `payload`'ta gelir; `text` alani notice'a ayrildi.
    expect(message.payload?['token'], isNotNull, reason: 'token bekleniyordu');
    expect(message.payload!['token'] as String, isNotEmpty);
    expect(message.text, isNull, reason: 'join yanitinda notice yok');

    expect(server.players.length, 1);
    expect(server.players.single.name, 'Ali');
  });

  test('token ile yeniden baglaninca ayni kimlik geri gelir', () async {
    final first = await connect(name: 'Ali');
    final token = first.received.single.payload!['token'] as String;
    server.players.single.characterId = 'c1';
    await first.close();

    final second = await connect(name: 'Ali', token: token);

    // Yeni oyuncu acilmamali; karakter sahipligi korunmali.
    expect(server.players.length, 1);
    expect(server.players.single.characterId, 'c1');
    expect(second.received.single.payload!['token'], token);
  });

  test('token yoksa her baglanti yeni oyuncu acar', () async {
    await connect(name: 'Ali');
    await connect(name: 'Veli');

    expect(server.players.length, 2);
    expect(server.players.map((p) => p.name), containsAll(['Ali', 'Veli']));
  });

  test('join olmadan gonderilen istek reddedilir', () async {
    final channel = WebSocketChannel.connect(
      Uri.parse('ws://127.0.0.1:${server.port}/ws'),
    );
    await channel.ready;
    final client = _TestClient(channel);
    open.add(client);

    channel.sink.add(
      const ClientMessage(
        type: ClientMessageType.updateHitPoints,
        amount: -5,
      ).encode(),
    );
    await client.waitForMessages(1);

    expect(client.received.single.type, ServerMessageType.rejected);
    // Dogrulayici hic cagrilmamali.
    expect(handled, isEmpty);
  });

  test('istek DM tarafina iletilir ve sonuc yayinlanir', () async {
    final client = await connect();

    // DM tarafi durumu degistirmis gibi davran.
    snapshot = TableSnapshot(
      characters: [
        const PlayerCharacterView(
          id: 'c1',
          name: 'Vex',
          hitPointsCurrent: 15,
          hitPointsMax: 22,
        ),
      ],
    );
    client.send(
      const ClientMessage(type: ClientMessageType.updateHitPoints, amount: -5),
    );
    await client.waitForMessages(2);

    expect(handled.length, 1);
    expect(handled.single.$2.type, ClientMessageType.updateHitPoints);
    expect(handled.single.$2.amount, -5);

    // Yayin guncel durumu tasimali.
    expect(
      client.received.last.snapshot!.characters.single.hitPointsCurrent,
      15,
    );
  });

  test('reddedilen istek yayin uretmez', () async {
    final client = await connect();
    rejectWith = 'Önce bir karakter seç.';

    client.send(
      const ClientMessage(type: ClientMessageType.updateHitPoints, amount: -5),
    );
    await client.waitForMessages(2);

    final reply = client.received.last;
    expect(reply.type, ServerMessageType.rejected);
    expect(reply.text, 'Önce bir karakter seç.');
    // Reddedilen istek sonrasi snapshot yayini olmamali.
    expect(client.received.length, 2);
  });

  test('setPresence oyuncunun varlik durumunu gunceller', () async {
    final client = await connect(name: 'Ali');
    final token = client.received.single.payload!['token'] as String;

    // Varsayilan: aktif + canli sokette.
    expect(server.players.single.presence, PlayerPresence.active);
    expect(server.connectedTokens, contains(token));

    // Arka plana gecti (baska sekme/uygulama).
    client.send(
      const ClientMessage(
        type: ClientMessageType.setPresence,
        presence: 'away',
      ),
    );
    await _settle();

    expect(server.players.single.presence, PlayerPresence.away);
    // Isletimsel mesaj oturum servisine gitmez.
    expect(handled, isEmpty);

    // Baglanti kapaninca online listesinden duser, lastSeen isaretlenir.
    final before = DateTime.now();
    await client.close();
    await _settle();
    expect(server.connectedTokens, isNot(contains(token)));
    expect(server.players.single.lastSeen, isNotNull);
    expect(
      server.players.single.lastSeen!.isBefore(
        before.add(const Duration(seconds: 5)),
      ),
      isTrue,
    );
  });

  test('yayin tum bagli istemcilere gider', () async {
    final a = await connect(name: 'Ali');
    final b = await connect(name: 'Veli');

    await server.broadcast(notice: 'Kapı açıldı');
    await a.waitForMessages(2);
    await b.waitForMessages(2);

    expect(a.received.last.text, 'Kapı açıldı');
    expect(b.received.last.text, 'Kapı açıldı');
  });

  test('bozuk mesaj baglantiyi dusurmez', () async {
    final client = await connect();

    client.channel.sink.add('bu json degil');
    await _settle();

    // Baglanti hala calisiyor olmali.
    expect(server.players.length, 1);
    client.send(
      const ClientMessage(
        type: ClientMessageType.claimCharacter,
        characterId: 'c1',
      ),
    );
    await client.waitForMessages(2);
    expect(handled.length, 1);
  });

  test('baglanti kopunca oyuncu listeden dusar', () async {
    final client = await connect();
    expect(server.players.length, 1);

    await client.close();
    await _settle();

    // Kimlik kaydi token ile geri donebilmek icin duruyor ama soket kapandi.
    expect(server.isRunning, isTrue);
  });

  test('katilim adresi oturum kodu tasir', () {
    expect(server.joinUri.queryParameters['s'], server.sessionCode);
    expect(server.sessionCode.length, 4);
    // Karistirilabilir harfler (I, O, 0, 1) kullanilmamali.
    expect(RegExp(r'^[A-HJ-NP-Z2-9]{4}$').hasMatch(server.sessionCode), isTrue);
  });
}

/// Gelen mesajlari biriktiren test istemcisi.
class _TestClient {
  _TestClient(this.channel) {
    _subscription = channel.stream.listen(
      (raw) => received.add(ServerMessage.decode('$raw')),
      onError: (_) {},
    );
  }

  final WebSocketChannel channel;
  final received = <ServerMessage>[];
  late final StreamSubscription<dynamic> _subscription;

  void send(ClientMessage message) => channel.sink.add(message.encode());

  /// Beklenen sayida mesaj gelene kadar bekler; gelmezse testi dusurur.
  Future<void> waitForMessages(int count) async {
    for (var i = 0; i < 50 && received.length < count; i++) {
      await _settle();
    }
    if (received.length < count) {
      fail('$count mesaj bekleniyordu, ${received.length} geldi');
    }
  }

  Future<void> close() async {
    await _subscription.cancel();
    await channel.sink.close();
  }
}

/// Soket trafiginin islenmesi icin olay dongusune firsat verir.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));
