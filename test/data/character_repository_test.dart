import 'package:dm_table/data/character_repository.dart';
import 'package:dm_table/data/db/character_tables.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/import/asset_importer.dart';
import 'package:dm_table/domain/models/ability.dart';
import 'package:dm_table/domain/models/character_build.dart';
import 'package:dm_table/domain/rules/character_math.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repository'nin gercek SRD ilerleme tablolariyla dogru sonuc uretmesi.
/// Buyu yuvasi hesabi elle yazilmis bir tabloya degil, ice aktarilan veriye
/// dayandigi icin burasi hem motoru hem veriyi birlikte dogruluyor.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CharacterRepository repo;

  setUpAll(() async {
    db = AppDatabase(NativeDatabase.memory());
    await AssetImporter(db).importIfNeeded();
    repo = CharacterRepository(db);
  });

  tearDownAll(() async => db.close());

  var counter = 0;
  Future<String> makeCharacter(
    List<({String classKey, int level})> classes, {
    AbilityScores abilities = const AbilityScores(),
  }) async {
    final id = 'test-${counter++}';
    await db
        .into(db.characters)
        .insert(
          CharactersCompanion.insert(
            id: id,
            name: id,
            strength: Value(abilities.strength),
            dexterity: Value(abilities.dexterity),
            constitution: Value(abilities.constitution),
            intelligence: Value(abilities.intelligence),
            wisdom: Value(abilities.wisdom),
            charisma: Value(abilities.charisma),
          ),
        );
    for (final (index, c) in classes.indexed) {
      await db
          .into(db.characterClassLevels)
          .insert(
            CharacterClassLevelsCompanion.insert(
              characterId: id,
              classKey: c.classKey,
              level: Value(c.level),
              order: Value(index),
            ),
          );
    }
    return id;
  }

  test('sinif meta verisi kutuphaneden okunur', () async {
    final id = await makeCharacter([
      (classKey: 'srd-2024_barbarian', level: 3),
    ]);
    final build = await repo.buildFor(id);

    final barb = build.classes.single;
    expect(barb.hitDieSides, 12);
    expect(barb.casterType, CasterType.none);
    // Barbarian zirhsiz savunmayi CON ile alir.
    expect(build.unarmoredDefenseAbility, Ability.constitution);
  });

  group('buyu yuvalari', () {
    test('tek sinif Wizard 5: 4/3/2', () async {
      final id = await makeCharacter([(classKey: 'srd-2024_wizard', level: 5)]);
      final slots = await repo.spellSlots(await repo.buildFor(id));
      expect(slots, {1: 4, 2: 3, 3: 2});
    });

    test('Cleric 1: sadece bir adet 1. seviye yuva', () async {
      final id = await makeCharacter([(classKey: 'srd-2024_cleric', level: 1)]);
      final slots = await repo.spellSlots(await repo.buildFor(id));
      expect(slots, {1: 2});
    });

    test('Paladin 5 tek basina: yarim buyucu tablosu', () async {
      final id = await makeCharacter([
        (classKey: 'srd-2024_paladin', level: 5),
      ]);
      final slots = await repo.spellSlots(await repo.buildFor(id));
      expect(slots, {1: 4, 2: 2});
    });

    test('Paladin 6 / Sorcerer 4 -> 7. seviye tam buyucu yuvalari', () async {
      final id = await makeCharacter([
        (classKey: 'srd-2024_paladin', level: 6),
        (classKey: 'srd-2024_sorcerer', level: 4),
      ]);
      final build = await repo.buildFor(id);
      expect(build.combinedCasterLevel, 7);

      final slots = await repo.spellSlots(build);
      // 7. seviye tam buyucu: 4/3/3/1
      expect(slots, {1: 4, 2: 3, 3: 3, 4: 1});
    });

    test('savascida yuva yok', () async {
      final id = await makeCharacter([
        (classKey: 'srd-2024_fighter', level: 10),
      ]);
      expect(await repo.spellSlots(await repo.buildFor(id)), isEmpty);
    });

    test('Warlock Pact Magic ayri havuzda', () async {
      final id = await makeCharacter([
        (classKey: 'srd-2024_warlock', level: 5),
      ]);
      final build = await repo.buildFor(id);

      // Pact Magic ortak havuza girmez.
      expect(await repo.spellSlots(build), isEmpty);

      final pact = await repo.pactMagic(build);
      expect(pact, isNotNull);
      expect(pact!.slotLevel, 3);
      expect(pact.count, 2);
    });
  });

  test('yeterlilikler build\'e yansir', () async {
    final id = await makeCharacter([
      (classKey: 'srd-2024_rogue', level: 5),
    ], abilities: const AbilityScores(dexterity: 16));

    await db.batch((b) {
      b.insertAll(db.characterProficiencies, [
        CharacterProficienciesCompanion.insert(
          characterId: id,
          kind: ProficiencyKind.skill,
          value: 'stealth',
          expertise: const Value(true),
        ),
        CharacterProficienciesCompanion.insert(
          characterId: id,
          kind: ProficiencyKind.save,
          value: 'dexterity',
        ),
      ]);
    });

    final build = await repo.buildFor(id);
    // PB 3, uzmanlik -> +6, DEX +3
    expect(build.skillModifier(Skill.stealth), 9);
    expect(build.savingThrow(Ability.dexterity), 6);
  });

  test('giyili zirh ve kalkan AC hesabina girer', () async {
    final id = await makeCharacter([
      (classKey: 'srd-2024_fighter', level: 1),
    ], abilities: const AbilityScores(dexterity: 14));

    // SRD anahtarlari: chain mail agir zirh (AC 16), shield +2.
    await db.batch((b) {
      b.insertAll(db.characterItems, [
        CharacterItemsCompanion.insert(
          id: '$id-armor',
          characterId: id,
          itemKey: const Value('srd-2024_chain-mail'),
          equipped: const Value(true),
        ),
        CharacterItemsCompanion.insert(
          id: '$id-shield',
          characterId: id,
          itemKey: const Value('srd-2024_shield'),
          equipped: const Value(true),
        ),
      ]);
    });

    final build = await repo.buildFor(id);
    expect(build.armor, isNotNull);
    expect(build.hasShield, isTrue);
    expect(build.armorClass, 18); // 16 + 2, Dex eklenmez
  });

  test('seviyede kazanilan feature anahtarlari okunur', () async {
    final keys = await repo.featureKeysAt('srd-2024_wizard', 4);
    expect(keys.any((k) => k.contains('ability-score-improvement')), isTrue);
  });
}
