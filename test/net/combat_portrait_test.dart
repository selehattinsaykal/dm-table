import 'package:dm_table/data/character_repository.dart';
import 'package:dm_table/data/combat_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/shop_repository.dart';
import 'package:dm_table/data/world_repository.dart';
import 'package:dm_table/data/import/asset_importer.dart';
import 'package:dm_table/domain/models/ability.dart';
import 'package:dm_table/features/session/session_service.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Savas gorunumunde portreler: oyuncu karakterinin ve DM'in canavara ekledigi
/// gorselin `/media` yolu oyunculara gider.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SessionService session;
  late CharacterRepository characters;
  late CombatRepository combat;
  late String encounterId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await AssetImporter(db).importIfNeeded();
    characters = CharacterRepository(db);
    combat = CombatRepository(db);
    session = SessionService(
      db: db,
      characters: characters,
      combat: combat,
      shops: ShopRepository(db),
      world: WorldRepository(db),
    );

    await characters.createLevelOneCharacter(
      id: 'ali-c',
      name: 'Rohan',
      classKey: 'srd-2024_fighter',
      abilities: const AbilityScores(),
      savingThrows: const {},
      skills: const {},
      hitDieSides: 10,
    );
    // Portre yollarini dogrudan yaz (dosya gerekmeyen izdusum testi).
    await (db.update(db.characters)..where((t) => t.id.equals('ali-c'))).write(
      const CharactersCompanion(portraitPath: Value('portraits/hero.jpg')),
    );

    final goblin = await (db.select(
      db.monsters,
    )..where((t) => t.name.equals('Goblin Warrior'))).getSingle();
    await (db.update(
      db.monsters,
    )..where((t) => t.key.equals(goblin.key))).write(
      const MonstersCompanion(portraitPath: Value('portraits/gob.png')),
    );

    encounterId = await combat.createEncounter('Test');
    await combat.addCharacters(
      encounterId: encounterId,
      characters: [(await characters.find('ali-c'))!],
    );
    await combat.addMonsters(encounterId: encounterId, monster: goblin);
    await combat.start(encounterId);
  });

  tearDown(() async {
    await session.stop();
    await db.close();
  });

  test('oyuncu karakterinin portresi savas gorunumune girer', () async {
    final snapshot = await session.buildSnapshot();
    final me = snapshot.combat!.combatants.firstWhere(
      (c) => c.characterId == 'ali-c',
    );
    expect(me.portraitUrl, '/media/hero.jpg');
  });

  test('canavar portresi savas gorunumune girer', () async {
    final snapshot = await session.buildSnapshot();
    final goblin = snapshot.combat!.combatants.firstWhere((c) => !c.isPlayer);
    expect(goblin.portraitUrl, '/media/gob.png');
  });

  test('portresiz katilimcida url null', () async {
    // Canavarin portresini kaldir.
    final key = (await (db.select(
      db.monsters,
    )..where((t) => t.name.equals('Goblin Warrior'))).getSingle()).key;
    await (db.update(db.monsters)..where((t) => t.key.equals(key))).write(
      const MonstersCompanion(portraitPath: Value(null)),
    );

    final snapshot = await session.buildSnapshot();
    final goblin = snapshot.combat!.combatants.firstWhere((c) => !c.isPlayer);
    expect(goblin.portraitUrl, isNull);
  });
}
