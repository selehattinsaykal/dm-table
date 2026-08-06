import 'dart:convert';

import 'package:dm_table/data/character_repository.dart';
import 'package:dm_table/data/custom_content_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/import/asset_importer.dart';
import 'package:dm_table/domain/models/ability.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Homebrew alt sinif, SRD alt siniflariyla ayni sekilde davranmali:
/// ilerleme tablosu uretilmeli, level atlarken yetenekleri gelmeli,
/// sayaclari karakter kagidina yansimali.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CustomContentRepository custom;
  late CharacterRepository characters;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await AssetImporter(db).importIfNeeded();
    custom = CustomContentRepository(db);
    characters = CharacterRepository(db);
  });

  tearDown(() async => db.close());

  /// Masada tipik bir alt sinif: 3. seviyede iki yetenek, bir de seviyeye
  /// gore buyuyen sayac.
  Future<String> addBattleMasterLike() => custom.addSubclass(
    name: 'Savaş Ustası',
    parentClassKey: 'srd-2024_fighter',
    parentClassName: 'Fighter',
    features: const [
      (
        level: 3,
        name: 'Üstünlük Zarları',
        description: 'Manevralarını beslemek için üstünlük zarların olur.',
      ),
      (level: 3, name: 'Manevralar', description: 'Üç manevra öğrenirsin.'),
      (
        level: 7,
        name: 'Bilgin',
        description: 'Bir alette uzmanlık kazanırsın.',
      ),
      (
        level: 10,
        name: 'Geliştirilmiş Manevra',
        description: 'İki manevra daha.',
      ),
    ],
    resources: const [
      (name: 'Üstünlük Zarı', valuesByLevel: {3: '4', 7: '5', 15: '6'}),
    ],
  );

  Future<String> makeFighter({int toLevel = 1}) async {
    await characters.createLevelOneCharacter(
      id: 'grog',
      name: 'Grog',
      classKey: 'srd-2024_fighter',
      abilities: const AbilityScores(constitution: 14),
      savingThrows: const {},
      skills: const {},
      hitDieSides: 10,
    );
    for (var l = 1; l < toLevel; l++) {
      await characters.levelUp(
        characterId: 'grog',
        classKey: 'srd-2024_fighter',
      );
    }
    return 'grog';
  }

  test('alt sinif SRD sekliyle saklanir', () async {
    final key = await addBattleMasterLike();

    final row = await (db.select(
      db.classDefinitions,
    )..where((t) => t.key.equals(key))).getSingle();

    expect(row.subclassOf, 'srd-2024_fighter');
    final data = jsonDecode(row.dataJson) as Map<String, dynamic>;
    final features = (data['features'] as List).cast<Map<String, dynamic>>();

    // Yetenekler ve sayac ayni listede, SRD'deki gibi tiplenmis.
    expect(
      features.where((f) => f['feature_type'] == 'CLASS_LEVEL_FEATURE').length,
      4,
    );
    expect(
      features.where((f) => f['feature_type'] == 'CLASS_TABLE_DATA').length,
      1,
    );

    final first = features.first;
    expect((first['gained_at'] as List).single['level'], 3);
  });

  test('ilerleme tablosu uretilir', () async {
    final key = await addBattleMasterLike();

    final rows = await (db.select(
      db.classProgressions,
    )..where((t) => t.classKey.equals(key))).get();
    expect(rows, isNotEmpty);

    Map<String, dynamic> tableAt(int level) =>
        jsonDecode(rows.firstWhere((r) => r.level == level).classTableJson)
            as Map<String, dynamic>;

    // Esikler ileriye dogru doldurulmali.
    expect(tableAt(3)['Üstünlük Zarı'], '4');
    expect(tableAt(5)['Üstünlük Zarı'], '4');
    expect(tableAt(7)['Üstünlük Zarı'], '5');
    expect(tableAt(14)['Üstünlük Zarı'], '5');
    expect(tableAt(15)['Üstünlük Zarı'], '6');
    expect(tableAt(20)['Üstünlük Zarı'], '6');

    // Ilk esikten once sayac olmamali.
    expect(tableAt(1).containsKey('Üstünlük Zarı'), isFalse);
  });

  test('level atlama onizlemesi alt sinif yeteneklerini gosterir', () async {
    final subclassKey = await addBattleMasterLike();
    await makeFighter(toLevel: 2);

    // 3. seviyeye cikarken alt sinif seciliyor.
    await characters.levelUp(
      characterId: 'grog',
      classKey: 'srd-2024_fighter',
      subclassKey: subclassKey,
    );

    // 7. seviyeye giderken alt sinifin o seviyedeki yetenegi gorunmeli.
    await characters.levelUp(characterId: 'grog', classKey: 'srd-2024_fighter');
    await characters.levelUp(characterId: 'grog', classKey: 'srd-2024_fighter');
    await characters.levelUp(characterId: 'grog', classKey: 'srd-2024_fighter');

    final preview = await characters.previewLevelUp(
      characterId: 'grog',
      classKey: 'srd-2024_fighter',
    );
    expect(preview.newLevel, 7);
    expect(
      preview.features.any((f) => f.name == 'Bilgin'),
      isTrue,
      reason:
          'alt sınıfın 7. seviye yeteneği bekleniyordu: '
          '${preview.features.map((f) => f.name).join(", ")}',
    );
  });

  test('alt sinif yetenekleri karakter kagidina islenir', () async {
    final subclassKey = await addBattleMasterLike();
    await makeFighter(toLevel: 2);

    await characters.levelUp(
      characterId: 'grog',
      classKey: 'srd-2024_fighter',
      subclassKey: subclassKey,
    );

    final features = await characters.features('grog');
    final names = features.map((f) => f.name).toList();

    expect(names, contains('Üstünlük Zarları'));
    expect(names, contains('Manevralar'));
    // Aciklama da tasinmali; kagitta okunabilsin.
    final dice = features.firstWhere((f) => f.name == 'Üstünlük Zarları');
    expect(dice.description, contains('üstünlük zarların'));
    expect(dice.gainedAtLevel, 3);
  });

  test('alt sinif olmadan o yetenekler gelmez', () async {
    await addBattleMasterLike();
    await makeFighter(toLevel: 2);

    // Alt sinif secilmeden 3. seviyeye cik.
    await characters.levelUp(characterId: 'grog', classKey: 'srd-2024_fighter');

    final names = (await characters.features('grog')).map((f) => f.name);
    expect(names, isNot(contains('Üstünlük Zarları')));
  });

  test(
    'ayni alt sinif tekrar kaydedilince ilerleme tablosu tazelenir',
    () async {
      final key = await addBattleMasterLike();

      // Ayni adla, farkli sayac degerleriyle tekrar kaydet.
      await custom.addSubclass(
        name: 'Savaş Ustası',
        parentClassKey: 'srd-2024_fighter',
        parentClassName: 'Fighter',
        features: const [
          (level: 3, name: 'Üstünlük Zarları', description: 'Güncellendi.'),
        ],
        resources: const [
          (name: 'Üstünlük Zarı', valuesByLevel: {3: '6'}),
        ],
      );

      final rows = await (db.select(
        db.classProgressions,
      )..where((t) => t.classKey.equals(key))).get();

      final table =
          jsonDecode(rows.firstWhere((r) => r.level == 3).classTableJson)
              as Map<String, dynamic>;
      expect(table['Üstünlük Zarı'], '6');

      // Eski satirlar birikmemeli.
      expect(rows.where((r) => r.level == 3).length, 1);
    },
  );

  test('SRD alt siniflari da ayni yoldan calisir', () async {
    // Evoker (SRD) ile ayni akis: alt sinif secilince yetenekleri gelmeli.
    await makeFighter(toLevel: 2);
    await characters.levelUp(
      characterId: 'grog',
      classKey: 'srd-2024_fighter',
      subclassKey: 'srd-2024_champion',
    );

    final level = (await characters.classLevels('grog')).single;
    expect(level.subclassKey, 'srd-2024_champion');
    expect(await characters.features('grog'), isNotEmpty);
  });
}
