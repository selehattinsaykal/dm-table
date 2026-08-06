import 'package:dm_table/data/character_repository.dart';
import 'package:dm_table/data/combat_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/import/asset_importer.dart';
import 'package:dm_table/data/shop_repository.dart';
import 'package:dm_table/data/world_repository.dart';
import 'package:dm_table/domain/models/ability.dart';
import 'package:dm_table/features/session/session_service.dart';
import 'package:dm_table/net/protocol.dart';
import 'package:dm_table/net/table_server.dart' show ConnectedPlayer;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ganimet: DM sunar, oyuncu esya/para alir, hepsi alininca kapanir.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CharacterRepository characters;
  late SessionService session;
  late ConnectedPlayer ali;

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
      id: 'c1',
      name: 'Vex',
      classKey: 'srd-2024_wizard',
      abilities: const AbilityScores(),
      savingThrows: const {},
      skills: const {},
      hitDieSides: 6,
    );
    ali = ConnectedPlayer(token: 'a', name: 'Ali');
    await session.handleClientMessage(
      ali,
      const ClientMessage(
        type: ClientMessageType.claimCharacter,
        characterId: 'c1',
      ),
    );
  });

  tearDown(() => db.close());

  test('DM ganimet sunar, oyuncu esya ve parayi alir, biter', () async {
    await session.giveLoot(
      coinsCp: 500,
      items: const [
        (name: 'Kılıç', magic: false),
        (name: 'İksir', magic: true),
      ],
    );

    var loot = (await session.buildSnapshot()).loot!;
    expect(loot.coinsCp, 500);
    expect(loot.items.length, 2);

    // Esya al -> envantere gecer, ganimetten cikar.
    final swordId = loot.items.firstWhere((i) => i.name == 'Kılıç').id;
    await session.handleClientMessage(
      ali,
      ClientMessage(type: ClientMessageType.takeLoot, lootItemId: swordId),
    );
    expect(
      (await characters.items('c1')).any((i) => i.customName == 'Kılıç'),
      isTrue,
    );
    loot = (await session.buildSnapshot()).loot!;
    expect(loot.items.length, 1);

    // Para al.
    final before = (await characters.find('c1'))!.coinsCp;
    await session.handleClientMessage(
      ali,
      const ClientMessage(type: ClientMessageType.takeLoot),
    );
    expect((await characters.find('c1'))!.coinsCp, before + 500);

    // Kalan tek esyayi da al -> ganimet biter, kapanir.
    loot = (await session.buildSnapshot()).loot!;
    await session.handleClientMessage(
      ali,
      ClientMessage(
        type: ClientMessageType.takeLoot,
        lootItemId: loot.items.single.id,
      ),
    );
    expect((await session.buildSnapshot()).loot, isNull);
  });

  test('hedefli ganimeti baska oyuncu alamaz', () async {
    await session.giveLoot(coinsCp: 100, targetCharacterId: 'baskasi');
    final veli = ConnectedPlayer(token: 'v', name: 'Veli');
    await session.handleClientMessage(
      veli,
      const ClientMessage(
        type: ClientMessageType.claimCharacter,
        characterId: 'c1',
      ),
    );
    final error = await session.handleClientMessage(
      veli,
      const ClientMessage(type: ClientMessageType.takeLoot),
    );
    expect(error, isNotNull);
  });

  test('LootView JSON round-trip', () {
    const loot = LootView(
      id: '3',
      coinsCp: 250,
      items: [LootItemView(id: 'i1', name: 'Asa', magic: true)],
      targetCharacterId: 'c1',
    );
    final back = LootView.fromJson(loot.toJson());
    expect(back.id, '3');
    expect(back.coinsCp, 250);
    expect(back.items.single.name, 'Asa');
    expect(back.items.single.magic, isTrue);
    expect(back.targetCharacterId, 'c1');
  });
}
