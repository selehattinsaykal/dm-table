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

/// Zar atma ve oyuncu envanter degisikligi oturum servisinde dogru calisiyor
/// mu, yetki kurallari korunuyor mu?
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
      abilities: const AbilityScores(dexterity: 16),
      savingThrows: {Ability.dexterity},
      skills: {Skill.stealth},
      hitDieSides: 8,
    );
  });

  tearDown(() async {
    await session.stop();
    await db.close();
  });

  ConnectedPlayer player(String name) =>
      ConnectedPlayer(token: name, name: name);

  Future<void> claim(ConnectedPlayer p) => session.handleClientMessage(
    p,
    const ClientMessage(
      type: ClientMessageType.claimCharacter,
      characterId: 'vex',
    ),
  );

  group('zar', () {
    test('oyuncu zar atınca günlüğe düşer ve kaynağı yazılır', () async {
      final ali = player('Ali');
      await session.handleClientMessage(
        ali,
        const ClientMessage(
          type: ClientMessageType.rollDice,
          rollLabel: 'Gizlilik',
          diceSides: 20,
          amount: 5,
        ),
      );

      final rolls = (await session.buildSnapshot()).rolls;
      expect(rolls, hasLength(1));
      expect(rolls.single.label, 'Gizlilik');
      expect(rolls.single.source, 'Ali');
      // d20 + 5 -> 6..25
      expect(rolls.single.total, inInclusiveRange(6, 25));
    });

    test('zar sonucu sunucuda üretilir, istemci sonucu dikte edemez', () async {
      // Istemci "total" gondermiyor; yalnizca ne atacagini soyluyor.
      final ali = player('Ali');
      for (var i = 0; i < 20; i++) {
        await session.handleClientMessage(
          ali,
          const ClientMessage(
            type: ClientMessageType.rollDice,
            rollLabel: 'd6',
            diceSides: 6,
          ),
        );
      }
      final rolls = (await session.buildSnapshot()).rolls;
      expect(rolls.every((r) => r.total >= 1 && r.total <= 6), isTrue);
    });

    test('günlük son 30 atışla sınırlı', () async {
      final ali = player('Ali');
      for (var i = 0; i < 40; i++) {
        await session.handleClientMessage(
          ali,
          const ClientMessage(
            type: ClientMessageType.rollDice,
            rollLabel: 'd20',
            diceSides: 20,
          ),
        );
      }
      expect((await session.buildSnapshot()).rolls.length, 30);
    });

    test('DM kendi atışını paylaşabilir', () async {
      await session.pushRoll(
        const DiceRoll(
          label: 'Gizli kapı',
          sides: 20,
          count: 1,
          modifier: 0,
          results: [14],
          total: 14,
        ),
      );
      expect((await session.buildSnapshot()).rolls.single.total, 14);
    });
  });

  group('oyuncu envanteri', () {
    setUp(() async {
      await characters.addItem(
        characterId: 'vex',
        customName: 'Meşale',
        quantity: 3,
      );
    });

    test('sahiplenen oyuncu eşyayı kuşanabilir', () async {
      final ali = player('Ali');
      await claim(ali);
      final itemId = (await characters.items('vex')).single.id;

      await session.handleClientMessage(
        ali,
        ClientMessage(
          type: ClientMessageType.inventoryChange,
          itemId: itemId,
          inventoryAction: InventoryAction.toggleEquipped,
        ),
      );
      expect((await characters.items('vex')).single.equipped, isTrue);
    });

    test('bırakınca adet azalır', () async {
      final ali = player('Ali');
      await claim(ali);
      final itemId = (await characters.items('vex')).single.id;

      await session.handleClientMessage(
        ali,
        ClientMessage(
          type: ClientMessageType.inventoryChange,
          itemId: itemId,
          inventoryAction: InventoryAction.drop,
        ),
      );
      expect((await characters.items('vex')).single.quantity, 2);
    });

    test('karakter sahiplenmeden envanter değiştirilemez', () async {
      final veli = player('Veli');
      final itemId = (await characters.items('vex')).single.id;

      final error = await session.handleClientMessage(
        veli,
        ClientMessage(
          type: ClientMessageType.inventoryChange,
          itemId: itemId,
          inventoryAction: InventoryAction.toggleEquipped,
        ),
      );
      expect(error, isNotNull);
      expect((await characters.items('vex')).single.equipped, isFalse);
    });

    test('başkasının eşyasına dokunamaz', () async {
      // Ikinci karakter + esya.
      await characters.createLevelOneCharacter(
        id: 'pike',
        name: 'Pike',
        classKey: 'srd-2024_cleric',
        abilities: const AbilityScores(),
        savingThrows: const {},
        skills: const {},
        hitDieSides: 8,
      );
      await characters.addItem(characterId: 'pike', customName: 'Kalkan');
      final pikeItemId = (await characters.items('pike')).single.id;

      // Ali, Vex'i sahiplenip Pike'in esyasina dokunmayi denesin.
      final ali = player('Ali');
      await claim(ali);
      final error = await session.handleClientMessage(
        ali,
        ClientMessage(
          type: ClientMessageType.inventoryChange,
          itemId: pikeItemId,
          inventoryAction: InventoryAction.toggleEquipped,
        ),
      );
      expect(error, isNotNull);
      expect((await characters.items('pike')).single.equipped, isFalse);
    });

    test('envanter oyuncu görünümünde id ile gelir', () async {
      final ali = player('Ali');
      await claim(ali);
      final view = (await session.buildSnapshot()).characters.single;
      expect(view.inventory.single.id, isNotEmpty);
      expect(view.inventory.single.name, 'Meşale');
      expect(view.inventory.single.quantity, 3);
    });
  });
}
