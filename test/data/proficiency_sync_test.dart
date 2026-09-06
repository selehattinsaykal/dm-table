import 'package:dm_table/data/character_repository.dart';
import 'package:dm_table/data/db/character_tables.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/import/asset_importer.dart';
import 'package:dm_table/domain/models/ability.dart';
import 'package:dm_table/domain/rules/proficiency_parsing.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Zirh/silah/alet/dil yeterliliklerinin sinif, background ve feat'lerden
/// turetilmesi. Gercek SRD verisiyle calisiyor: hem tureticiyi hem veriyi
/// birlikte dogruluyor.
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
  Future<String> makeCharacter({
    required String classKey,
    String? backgroundKey,
  }) async {
    final id = 'prof-${counter++}';
    await repo.createLevelOneCharacter(
      id: id,
      name: id,
      classKey: classKey,
      backgroundKey: backgroundKey,
      abilities: const AbilityScores(),
      savingThrows: const {},
      skills: const {},
      hitDieSides: 10,
    );
    return id;
  }

  Future<Set<String>> valuesOf(String id, ProficiencyKind kind) async {
    final rows = await (db.select(
      db.characterProficiencies,
    )..where((t) => t.characterId.equals(id) & t.kind.equalsValue(kind))).get();
    return rows.map((r) => r.value).toSet();
  }

  test('Fighter sinifindan zirh ve silah yeterliligi gelir', () async {
    final id = await makeCharacter(classKey: 'srd-2024_fighter');
    expect(await valuesOf(id, ProficiencyKind.armor), {
      ArmorTraining.light,
      ArmorTraining.medium,
      ArmorTraining.heavy,
      ArmorTraining.shield,
    });
    expect(await valuesOf(id, ProficiencyKind.weapon), {
      WeaponProficiency.simple,
      WeaponProficiency.martial,
    });
  });

  test('Wizard zirh egitimi almaz', () async {
    final id = await makeCharacter(classKey: 'srd-2024_wizard');
    expect(await valuesOf(id, ProficiencyKind.armor), isEmpty);
    expect(await valuesOf(id, ProficiencyKind.weapon), {
      WeaponProficiency.simple,
    });
  });

  test('Rogue alet yeterliligi ve kosullu martial alir', () async {
    final id = await makeCharacter(classKey: 'srd-2024_rogue');
    expect(
      await valuesOf(id, ProficiencyKind.tool),
      contains("Thieves' Tools"),
    );
    expect(
      await valuesOf(id, ProficiencyKind.weapon),
      contains(WeaponProficiency.martialFinesseOrLight),
    );
  });

  test('Rogue "Thieves\' Cant" ozelliginden dil gelir', () async {
    final id = await makeCharacter(classKey: 'srd-2024_rogue');
    expect(
      await valuesOf(id, ProficiencyKind.language),
      contains("Thieves' Cant"),
    );
  });

  test('Druid "Druidic" ozelliginden dil gelir', () async {
    final id = await makeCharacter(classKey: 'srd-2024_druid');
    expect(await valuesOf(id, ProficiencyKind.language), contains('Druidic'));
  });

  test(
    'background alet yeterliligi eklenir ve kaynagi background olur',
    () async {
      final id = await makeCharacter(
        classKey: 'srd-2024_fighter',
        backgroundKey: 'srd-2024_acolyte',
      );
      final rows =
          await (db.select(db.characterProficiencies)..where(
                (t) =>
                    t.characterId.equals(id) &
                    t.kind.equalsValue(ProficiencyKind.tool),
              ))
              .get();
      final acolyte = rows.where((r) => r.value == "Calligrapher's Supplies");
      expect(acolyte, hasLength(1));
      expect(acolyte.single.source, ProficiencySource.background);
    },
  );

  test('background degisince eski alet gider, yenisi gelir', () async {
    final id = await makeCharacter(
      classKey: 'srd-2024_fighter',
      backgroundKey: 'srd-2024_acolyte',
    );
    expect(
      await valuesOf(id, ProficiencyKind.tool),
      contains("Calligrapher's Supplies"),
    );

    await repo.setBackground(id, 'srd-2024_criminal');
    final tools = await valuesOf(id, ProficiencyKind.tool);
    expect(tools, isNot(contains("Calligrapher's Supplies")));
    expect(tools, contains("Thieves' Tools"));
  });

  test('feat zirh egitimi ekler', () async {
    final id = await makeCharacter(classKey: 'srd-2024_wizard');
    expect(await valuesOf(id, ProficiencyKind.armor), isEmpty);

    final key = await repo.featKeyByName('Moderately Armored');
    expect(key, isNotNull);
    await repo.grantFeat(id, key!);

    expect(await valuesOf(id, ProficiencyKind.armor), {ArmorTraining.medium});
  });

  test('elle eklenen dil yeniden turetmede korunur', () async {
    final id = await makeCharacter(classKey: 'srd-2024_fighter');
    await db
        .into(db.characterProficiencies)
        .insert(
          CharacterProficienciesCompanion.insert(
            characterId: id,
            kind: ProficiencyKind.language,
            value: 'Ortak Dil',
            source: const Value(ProficiencySource.manual),
          ),
        );

    await repo.syncDerivedProficiencies(id);
    expect(await valuesOf(id, ProficiencyKind.language), contains('Ortak Dil'));
  });

  test('yeniden turetme cift kayit uretmez', () async {
    final id = await makeCharacter(classKey: 'srd-2024_fighter');
    final before = await valuesOf(id, ProficiencyKind.armor);
    await repo.syncDerivedProficiencies(id);
    await repo.syncDerivedProficiencies(id);
    expect(await valuesOf(id, ProficiencyKind.armor), before);
  });

  test('Bard bekleyen calgi secimi bildirir', () async {
    final id = await makeCharacter(classKey: 'srd-2024_bard');
    final pending = await repo.pendingProficiencyChoices(id);
    final tool = pending.where((p) => p.choice.type == ProficiencyType.tool);
    expect(tool, isNotEmpty);
    expect(tool.first.choice.count, 3);
    expect(tool.first.choice.toolGroups, [ToolGroup.musicalInstrument]);
  });

  test('Fighter silah ustaligi sayisini sinif tablosundan alir', () async {
    final id = await makeCharacter(classKey: 'srd-2024_fighter');
    // 1. seviyede Fighter uc silah ustaligi seciyor.
    expect(await repo.weaponMasterySlots(id), 3);

    final pending = await repo.pendingProficiencyChoices(id);
    final mastery = pending.where(
      (p) => p.choice.type == ProficiencyType.weaponMastery,
    );
    expect(mastery, isNotEmpty);
    expect(mastery.first.choice.count, 3);
  });

  test('Wizard silah ustaligi almaz', () async {
    final id = await makeCharacter(classKey: 'srd-2024_wizard');
    expect(await repo.weaponMasterySlots(id), 0);
  });

  test('Weapon Master feati fazladan ustalik sectirir', () async {
    final id = await makeCharacter(classKey: 'srd-2024_wizard');
    final key = await repo.featKeyByName('Weapon Master');
    expect(key, isNotNull);
    await repo.grantFeat(id, key!);

    final pending = await repo.pendingProficiencyChoices(id);
    final mastery = pending.where(
      (p) => p.choice.type == ProficiencyType.weaponMastery,
    );
    expect(mastery, hasLength(1));
    expect(mastery.single.source, ProficiencySource.feat);
  });
}
