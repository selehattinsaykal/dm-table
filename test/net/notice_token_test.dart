import 'dart:async';

import 'package:dm_table/net/protocol.dart';
import 'package:dm_table/net/table_server.dart';
import 'package:dm_table/player/player_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regresyon: `broadcast(notice:)` bildirimi oyuncunun reconnect token'ini
/// BOZMAMALI.
///
/// Eski hata: token da notice da `ServerMessage.text`'ten okunuyordu. DM bir
/// bildirim yayinlayinca (or. satin alma onayi) istemcinin `_token`'i bildirim
/// metniyle eziliyor, oyuncu uyku/sekme donusunde bozuk token'i gonderiyor,
/// sunucu kimligi bulamayip YENI oyuncu aciyor -> karakter sahipligi dusuyordu.
/// Artik token `payload`'ta, notice `text`'te; ikisi ayri.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TableServer server;

  setUp(() async {
    server = TableServer(
      buildSnapshot: () async => const TableSnapshot(
        characters: [
          PlayerCharacterView(
            id: 'c1',
            name: 'Vex',
            hitPointsCurrent: 20,
            hitPointsMax: 22,
          ),
        ],
      ),
      onClientMessage: (player, message) async => null,
    );
    await server.start(preferredPort: 0);
  });

  tearDown(() async {
    await server.stop();
  });

  test('notice token bozmaz; reconnect claim korunur', () async {
    final base = Uri.parse('http://127.0.0.1:${server.port}');

    final tokens = <String>[];
    final firstToken = Completer<String>();
    final client = PlayerClient(
      uri: base,
      onTokenIssued: (t) {
        tokens.add(t);
        if (!firstToken.isCompleted) firstToken.complete(t);
      },
    );
    addTearDown(client.dispose);

    client.connect(playerName: 'Ali');
    await firstToken.future.timeout(const Duration(seconds: 5));

    // Join islendi: oyuncu kayitli ve bir karakter sahipleniyor.
    expect(server.players.length, 1);
    server.players.single.characterId = 'c1';

    // DM bir bildirim yayinlar. Bildirim `notices` akisinda gorulmeli (eskiden
    // token sanildigi icin oyuncuya HIC gosterilmiyordu).
    final noticeArrived = client.notices.first;
    await server.broadcast(notice: 'Vex Kılıç aldı.');
    expect(
      await noticeArrived.timeout(const Duration(seconds: 5)),
      'Vex Kılıç aldı.',
    );

    // Bildirim token'i tetiklememeli: onTokenIssued yeniden cagrilmaz.
    expect(tokens, hasLength(1), reason: 'notice token vermemeli');

    // Uyku/sekme donusunu taklit et: ayni istemci yeniden baglanir. Token hala
    // dogruysa sunucu ayni kimligi bulur; bozuksa YENI oyuncu acar (claim duser).
    final reconnected = client.snapshots.first;
    client.connect(playerName: 'Ali');
    await reconnected.timeout(const Duration(seconds: 5));

    expect(server.players.length, 1, reason: 'bozuk token yeni oyuncu acardi');
    expect(
      server.players.single.characterId,
      'c1',
      reason: 'reconnect karakter sahipligini korumali',
    );
    expect(tokens, hasLength(1), reason: 'token degismemis olmali');
  });
}
