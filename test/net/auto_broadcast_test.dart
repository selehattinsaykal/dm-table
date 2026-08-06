import 'package:dm_table/data/character_repository.dart';
import 'package:dm_table/data/combat_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/import/asset_importer.dart';
import 'package:dm_table/data/shop_repository.dart';
import 'package:dm_table/data/world_repository.dart';
import 'package:dm_table/domain/models/ability.dart';
import 'package:dm_table/features/session/session_service.dart';
import 'package:dm_table/net/protocol.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// DM cihazda bir sey degistirdiginde oyunculara ANLIK yansiyor mu?
///
/// Rapor: "envanter anlık güncellenmiyor". Sunucu artik veritabani degisim
/// akisini dinleyip otomatik yayin yapiyor; bu test DM tarafi bir yazma
/// yaptiginda bagli istemciye yeni snapshot dustugunu dogrular.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SessionService session;
  late CharacterRepository characters;

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
      classKey: 'srd-2024_rogue',
      abilities: const AbilityScores(),
      savingThrows: const {},
      skills: const {},
      hitDieSides: 8,
    );
    await session.start();
  });

  tearDown(() async {
    await session.stop();
    await db.close();
  });

  test('DM envantere eşya ekleyince oyuncuya yeni snapshot düşer', () async {
    final channel = WebSocketChannel.connect(
      Uri.parse('ws://127.0.0.1:${session.server!.port}/ws'),
    );
    await channel.ready;

    final received = <ServerMessage>[];
    final sub = channel.stream.listen(
      (raw) => received.add(ServerMessage.decode('$raw')),
    );

    channel.sink.add(
      const ClientMessage(
        type: ClientMessageType.join,
        playerName: 'Ali',
      ).encode(),
    );
    // Ilk snapshot (join yaniti) gelsin.
    await _until(() => received.isNotEmpty);
    final before = received.length;

    // DM tarafi: dogrudan repository uzerinden envantere ekle (istemci
    // mesaji YOK). Otomatik yayin devreye girmeli.
    await characters.addItem(characterId: 'vex', customName: 'Meşale');

    await _until(() => received.length > before);

    final last = received.last.snapshot!;
    expect(
      last.characters.single.inventory.any((i) => i.name == 'Meşale'),
      isTrue,
      reason: 'DM değişikliği oyuncuya yansımadı',
    );

    await sub.cancel();
    await channel.sink.close();
  });

  test('DM canı değiştirince oyuncuya yansır', () async {
    final channel = WebSocketChannel.connect(
      Uri.parse('ws://127.0.0.1:${session.server!.port}/ws'),
    );
    await channel.ready;
    final received = <ServerMessage>[];
    final sub = channel.stream.listen(
      (raw) => received.add(ServerMessage.decode('$raw')),
    );
    channel.sink.add(
      const ClientMessage(
        type: ClientMessageType.join,
        playerName: 'Ali',
      ).encode(),
    );
    await _until(() => received.isNotEmpty);
    final before = received.length;

    await characters.applyDamage('vex', 3);
    await _until(() => received.length > before);

    expect(received.last.snapshot!.characters.single.hitPointsCurrent, 5);

    await sub.cancel();
    await channel.sink.close();
  });
}

Future<void> _until(bool Function() done) async {
  for (var i = 0; i < 60; i++) {
    if (done()) return;
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
  throw StateError('Beklenen yayın gelmedi');
}
