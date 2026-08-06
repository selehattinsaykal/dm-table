import 'dart:convert';
import 'dart:io';

import 'package:dm_table/data/character_repository.dart';
import 'package:dm_table/data/combat_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/shop_repository.dart';
import 'package:dm_table/data/world_repository.dart';
import 'package:dm_table/data/import/asset_importer.dart';
import 'package:dm_table/domain/models/ability.dart';
import 'package:dm_table/features/session/session_service.dart';
import 'package:dm_table/net/protocol.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Faz 1b'nin uctan uca kaniti.
///
/// Gercek veritabani + gercek HTTP sunucusu + gercek WebSocket ile: oyuncunun
/// tarayicisinin gordugu her seyi taklit ediyoruz. Panelin indirilmesi,
/// oturuma katilma, karakter sahiplenme ve DM tarafinda gercekten veri
/// degismesi tek akista dogrulaniyor.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SessionService session;
  late CharacterRepository characters;
  late Uri base;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await AssetImporter(db).importIfNeeded();
    characters = CharacterRepository(db);

    session = SessionService(
      db: db,
      characters: characters,
      combat: CombatRepository(db),
      shops: ShopRepository(db),
      world: WorldRepository(db),
    );

    await characters.createLevelOneCharacter(
      id: 'vex',
      name: 'Vex',
      classKey: 'srd-2024_wizard',
      abilities: const AbilityScores(constitution: 14, intelligence: 16),
      savingThrows: {Ability.intelligence},
      skills: {Skill.arcana},
      hitDieSides: 6,
    );

    await session.start();
    // Testte gercek LAN adresi yerine loopback kullaniyoruz.
    base = Uri.parse('http://127.0.0.1:${session.server!.port}');
  });

  tearDown(() async {
    await session.stop();
    await db.close();
  });

  test('oyuncu paneli LAN uzerinden indirilebiliyor', () async {
    final response = await _rawGet(base, '/');
    expect(response.status, 200);
    expect(response.body, contains('flutter_bootstrap.js'));
  });

  test('panelin ana betigi de servis ediliyor', () async {
    final response = await _rawGet(base, '/main.dart.js');
    expect(response.status, 200);
    expect(response.headers, contains('application/javascript'));
    expect(response.byteCount, greaterThan(100000));
  });

  test('oyuncu katilip karakterini alir ve canini degistirir', () async {
    final channel = WebSocketChannel.connect(
      base.replace(path: '/ws', scheme: 'ws'),
    );
    await channel.ready;

    final received = <ServerMessage>[];
    final sub = channel.stream.listen(
      (raw) => received.add(ServerMessage.decode('$raw')),
    );

    Future<void> waitFor(int count) async {
      for (var i = 0; i < 60 && received.length < count; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
      expect(received.length, greaterThanOrEqualTo(count));
    }

    // 1) Katil -> tam snapshot gelmeli.
    channel.sink.add(
      const ClientMessage(
        type: ClientMessageType.join,
        playerName: 'Ali',
      ).encode(),
    );
    await waitFor(1);

    final snapshot = received.first.snapshot!;
    expect(snapshot.characters.single.name, 'Vex');
    expect(snapshot.characters.single.hitPointsMax, 8);
    // Kural motorundan gelen turetilmis degerler de tasinmali.
    expect(snapshot.characters.single.skills['Arcana'], 5);
    expect(snapshot.characters.single.spellSlots, {1: 2});

    // 2) Karakteri sahiplen.
    channel.sink.add(
      const ClientMessage(
        type: ClientMessageType.claimCharacter,
        characterId: 'vex',
      ).encode(),
    );
    await waitFor(2);
    expect(
      received.last.snapshot!.characters.single.claimedBy,
      'Ali',
      reason: 'sahiplik yayinlanmali',
    );

    // 3) Hasar al -> DM tarafindaki veritabani gercekten degismeli.
    channel.sink.add(
      const ClientMessage(
        type: ClientMessageType.updateHitPoints,
        amount: -3,
      ).encode(),
    );
    await waitFor(3);

    expect((await characters.find('vex'))!.hitPointsCurrent, 5);
    expect(received.last.snapshot!.characters.single.hitPointsCurrent, 5);

    await sub.cancel();
    await channel.sink.close();
  });

  test('ikinci oyuncu ayni karakteri alamaz', () async {
    Future<WebSocketChannel> join(String name) async {
      final channel = WebSocketChannel.connect(
        base.replace(path: '/ws', scheme: 'ws'),
      );
      await channel.ready;
      channel.sink.add(
        ClientMessage(type: ClientMessageType.join, playerName: name).encode(),
      );
      return channel;
    }

    final ali = await join('Ali');
    final veli = await join('Veli');

    final veliMessages = <ServerMessage>[];
    final sub = veli.stream.listen(
      (raw) => veliMessages.add(ServerMessage.decode('$raw')),
    );

    ali.sink.add(
      const ClientMessage(
        type: ClientMessageType.claimCharacter,
        characterId: 'vex',
      ).encode(),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));

    veli.sink.add(
      const ClientMessage(
        type: ClientMessageType.claimCharacter,
        characterId: 'vex',
      ).encode(),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final rejection = veliMessages
        .where((m) => m.type == ServerMessageType.rejected)
        .lastOrNull;
    expect(rejection, isNotNull, reason: 'ikinci sahiplenme reddedilmeliydi');
    expect(rejection!.text, contains('Ali'));

    await sub.cancel();
    await ali.sink.close();
    await veli.sink.close();
  });

  test('katilim adresi loopback degil, yerel ag adresi olmali', () async {
    final lan = await SessionService.findLanAddress();
    if (lan == null) {
      // CI/sanal makinede ag arayuzu olmayabilir; testi anlamsizca
      // dusurmek yerine atliyoruz.
      markTestSkipped('Makinede yerel ağ adresi bulunamadı');
      return;
    }

    final host = session.server!.joinUri.host;
    // Oyuncunun telefonu `localhost` yazarsa kendine baglanmaya calisir.
    expect(host, isNot('localhost'));
    expect(host, isNot('127.0.0.1'));
    expect(host, lan);
  });
}

/// Ham soket uzerinden HTTP GET.
///
/// `TestWidgetsFlutterBinding` `HttpClient`'i sahteleyip tum isteklere 400
/// donduruyor; sunucunun gercekten cevap verdigini gormek icin istegi elle
/// yaziyoruz.
Future<({int status, String headers, String body, int byteCount})> _rawGet(
  Uri base,
  String path,
) async {
  final socket = await Socket.connect(base.host, base.port);
  socket.write(
    'GET $path HTTP/1.1\r\n'
    'Host: ${base.host}:${base.port}\r\n'
    'Connection: close\r\n\r\n',
  );
  await socket.flush();

  final bytes = <int>[];
  await for (final chunk in socket) {
    bytes.addAll(chunk);
  }
  socket.destroy();

  // Govde ikili olabilir (wasm, js); basliklari latin-1 ile ayiriyoruz.
  final text = latin1.decode(bytes, allowInvalid: true);
  final split = text.indexOf('\r\n\r\n');
  final head = split < 0 ? text : text.substring(0, split);
  final body = split < 0 ? '' : text.substring(split + 4);

  final status =
      int.tryParse(
        RegExp(r'HTTP/1\.\d (\d{3})').firstMatch(head)?.group(1) ?? '',
      ) ??
      0;

  return (status: status, headers: head, body: body, byteCount: body.length);
}
