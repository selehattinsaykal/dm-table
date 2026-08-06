import 'dart:convert';

import 'package:dm_table/data/character_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/import/asset_importer.dart';
import 'package:dm_table/domain/models/ability.dart';
import 'package:dm_table/domain/rules/character_math.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Level atlama: HP matematigi, ASI'nin geriye donuk etkisi, alt sinif,
/// multiclass ve kazanilan yetenekler.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CharacterRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await AssetImporter(db).importIfNeeded();
    repo = CharacterRepository(db);
  });

  tearDown(() async => db.close());

  /// 1. seviye karakter kurar (sihirbazin yaptigini taklit eder).
  Future<String> makeLevelOne(
    String classKey, {
    int constitution = 14,
    int hitDieSides = 6,
  }) async {
    const id = 'c1';
    await repo.createLevelOneCharacter(
      id: id,
      name: 'Test',
      classKey: classKey,
      abilities: AbilityScores(constitution: constitution),
      savingThrows: const {},
      skills: const {},
      hitDieSides: hitDieSides,
    );
    return id;
  }

  test('1. seviyede hit die tam alinir', () async {
    final id = await makeLevelOne('srd-2024_wizard');
    final c = (await repo.find(id))!;
    expect(c.hitPointsMax, 8); // d6 tam (6) + CON +2
  });

  test('seviye atlayinca ortalama + CON eklenir', () async {
    final id = await makeLevelOne('srd-2024_wizard');
    await repo.levelUp(characterId: id, classKey: 'srd-2024_wizard');

    final c = (await repo.find(id))!;
    // 8 + (d6 ortalama 4 + CON 2) = 14
    expect(c.hitPointsMax, 14);
    expect(c.hitPointsCurrent, 14);

    final build = await repo.buildFor(id);
    expect(build.totalLevel, 2);
  });

  test('previewLevelUp her cagrida guncel yeni seviyeyi verir', () async {
    // Repo katmani dogru (her cagri DB'yi taze okur); "hep 2. seviye" hatasi
    // repoda DEGIL, provider onbelleginde idi (bkz. levelUpPreviewProvider).
    final id = await makeLevelOne('srd-2024_wizard');
    Future<int> preview() async => (await repo.previewLevelUp(
      characterId: id,
      classKey: 'srd-2024_wizard',
    )).newLevel;

    expect(await preview(), 2);
    await repo.levelUp(characterId: id, classKey: 'srd-2024_wizard');
    expect(await preview(), 3);
    await repo.levelUp(characterId: id, classKey: 'srd-2024_wizard');
    expect(await preview(), 4);
  });

  test('atilan zar verilirse o kullanilir', () async {
    final id = await makeLevelOne('srd-2024_wizard');
    await repo.levelUp(
      characterId: id,
      classKey: 'srd-2024_wizard',
      hitPointRoll: 6,
    );
    expect((await repo.find(id))!.hitPointsMax, 16); // 8 + 6 + 2
  });

  test('atilan zarlar saklanir ve kural motoru ayni sonucu verir', () async {
    final id = await makeLevelOne('srd-2024_wizard');
    await repo.levelUp(
      characterId: id,
      classKey: 'srd-2024_wizard',
      hitPointRoll: 5,
    );
    await repo.levelUp(
      characterId: id,
      classKey: 'srd-2024_wizard',
      hitPointRoll: 3,
    );

    final stored = (await repo.classLevels(id)).single;
    expect(jsonDecode(stored.hitPointRollsJson), [5, 3]);

    // Kagitta yazan ile motorun hesabi ayni olmali.
    final build = await repo.buildFor(id);
    expect(build.maxHitPoints, (await repo.find(id))!.hitPointsMax);
  });

  test('CON artisi gecmis seviyelere de yansir', () async {
    // CON 13 (+1) ile basla, 4. seviyede ASI ile 14'e (+2) cikar.
    final id = await makeLevelOne(
      'srd-2024_fighter',
      constitution: 13,
      hitDieSides: 10,
    );
    for (var i = 0; i < 3; i++) {
      await repo.levelUp(
        characterId: id,
        classKey: 'srd-2024_fighter',
        hitPointRoll: 6,
      );
    }
    // 10+1 + 3 x (6+1) = 32
    expect((await repo.find(id))!.hitPointsMax, 32);

    await repo.levelUp(
      characterId: id,
      classKey: 'srd-2024_fighter',
      hitPointRoll: 6,
      abilityIncreases: const {Ability.constitution: 1},
    );

    final c = (await repo.find(id))!;
    expect(c.constitution, 14);
    // 5 seviye x CON +2 = 10; 10+6+6+6+6 = 34 taban -> 44
    expect(c.hitPointsMax, 44);
    // Motorun bagimsiz hesabi da ayni olmali.
    expect((await repo.buildFor(id)).maxHitPoints, 44);
  });

  test('alt sinif secimi kaydedilir', () async {
    final id = await makeLevelOne('srd-2024_wizard');
    await repo.levelUp(characterId: id, classKey: 'srd-2024_wizard');
    await repo.levelUp(
      characterId: id,
      classKey: 'srd-2024_wizard',
      subclassKey: 'srd-2024_evoker',
    );

    final level = (await repo.classLevels(id)).single;
    expect(level.level, 3);
    expect(level.subclassKey, 'srd-2024_evoker');
  });

  test('multiclass ikinci sinif satiri acar', () async {
    final id = await makeLevelOne('srd-2024_wizard');
    await repo.levelUp(characterId: id, classKey: 'srd-2024_fighter');

    final levels = await repo.classLevels(id);
    expect(levels.length, 2);
    expect(levels.first.classKey, 'srd-2024_wizard');
    expect(levels.last.classKey, 'srd-2024_fighter');
    expect(levels.last.level, 1);

    final build = await repo.buildFor(id);
    expect(build.totalLevel, 2);
    // Ilk sinif hala birincil: HP'de tam hit die yalnizca ona verilir.
    expect(build.primaryClass!.classKey, 'srd-2024_wizard');
  });

  test('seviyede kazanilan yetenekler kagida islenir', () async {
    final id = await makeLevelOne('srd-2024_wizard');
    await repo.levelUp(characterId: id, classKey: 'srd-2024_wizard');
    await repo.levelUp(characterId: id, classKey: 'srd-2024_wizard');

    final features = await repo.features(id);
    expect(features, isNotEmpty);
    // 3. seviyede alt sinif secimi bir feature olarak geliyor.
    expect(
      features.any((f) => f.name.toLowerCase().contains('subclass')),
      isTrue,
      reason:
          'alt sinif yetenegi bekleniyordu: '
          '${features.map((f) => f.name).join(", ")}',
    );
    expect(features.every((f) => f.gainedAtLevel != null), isTrue);
  });

  test('ayni seviye tekrar islenirse yetenek kopyalanmaz', () async {
    final id = await makeLevelOne('srd-2024_wizard');
    await repo.levelUp(characterId: id, classKey: 'srd-2024_wizard');
    final first = (await repo.features(id)).length;

    // Ayni seviyeyi tekrar isle (idempotent olmali).
    await repo.levelUp(
      characterId: id,
      classKey: 'srd-2024_wizard',
      hitPointRoll: 1,
    );
    await (db.update(db.characterClassLevels)
          ..where((t) => t.characterId.equals(id)))
        .write(const CharacterClassLevelsCompanion(level: Value(2)));
    await repo.levelUp(characterId: id, classKey: 'srd-2024_wizard');

    final names = (await repo.features(id)).map((f) => f.name).toList();
    expect(names.length, names.toSet().length, reason: 'kopya yetenek var');
    expect(names.length, greaterThanOrEqualTo(first));
  });

  test('yeni seviyede buyu yuvalari acilir', () async {
    final id = await makeLevelOne('srd-2024_wizard');
    expect(await repo.spellSlots(await repo.buildFor(id)), {1: 2});

    await repo.levelUp(characterId: id, classKey: 'srd-2024_wizard');
    expect(await repo.spellSlots(await repo.buildFor(id)), {1: 3});

    await repo.levelUp(characterId: id, classKey: 'srd-2024_wizard');
    expect(await repo.spellSlots(await repo.buildFor(id)), {1: 4, 2: 2});
  });
}
