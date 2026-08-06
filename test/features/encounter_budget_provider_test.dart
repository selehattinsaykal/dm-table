import 'package:dm_table/data/combat_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/import/asset_importer.dart';
import 'package:dm_table/data/providers.dart';
import 'package:dm_table/domain/models/ability.dart';
import 'package:dm_table/domain/rules/encounter_budget.dart';
import 'package:dm_table/features/characters/character_providers.dart';
import 'package:dm_table/features/combat/combat_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// encounterBudgetProvider'in savas katilimcilarindan parti seviyesi + canavar
/// XP'sini dogru toplayip zorluk cikardigini dogrular.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;
  late CombatRepository combat;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await AssetImporter(db).importIfNeeded();
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    combat = container.read(combatRepositoryProvider);
  });

  tearDown(() {
    container.dispose();
    db.close();
  });

  test('parti seviyesi ve canavar XP toplanip zorluk cikar', () async {
    final characters = container.read(characterRepositoryProvider);
    await characters.createLevelOneCharacter(
      id: 'pc1',
      name: 'Rohan',
      classKey: 'srd-2024_fighter',
      abilities: const AbilityScores(),
      savingThrows: const {},
      skills: const {},
      hitDieSides: 10,
    );

    final goblin = await (db.select(
      db.monsters,
    )..where((t) => t.name.equals('Goblin Warrior'))).getSingle();

    final encounterId = await combat.createEncounter('Test');
    await combat.addCharacters(
      encounterId: encounterId,
      characters: [(await characters.find('pc1'))!],
    );
    await combat.addMonsters(encounterId: encounterId, monster: goblin);

    final a = await container.read(encounterBudgetProvider(encounterId).future);

    expect(a.partyLevels, [1]);
    expect(a.monsterXp, goblin.experiencePoints);
    expect(a.uncounted, 0);
    // 1. seviye tek karakterin butcesi (50,75,100); Goblin ~50 XP.
    expect(a.budget, (50, 75, 100));
    expect(a.difficulty, EncounterBudget.classify(a.monsterXp, [1]));
  });

  test('adhoc (XP siz) katilimci uncounted sayilir', () async {
    final encounterId = await combat.createEncounter('Test');
    await combat.addAdhoc(
      encounterId: encounterId,
      name: 'Gizemli',
      hitPoints: 10,
    );

    final a = await container.read(encounterBudgetProvider(encounterId).future);
    expect(a.monsterXp, 0);
    expect(a.uncounted, 1);
    expect(a.hasParty, isFalse);
  });
}
