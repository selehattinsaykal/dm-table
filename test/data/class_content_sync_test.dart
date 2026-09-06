import 'package:dm_table/data/character_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/import/asset_importer.dart';
import 'package:dm_table/domain/models/ability.dart';
import 'package:dm_table/domain/rules/granted_spells.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sinif ve alt sinif iceriginin kagida tam yansimasi.
///
/// Yetenekler seviye atlarken tek tek yaziliyordu; kutuphane verisi sonradan
/// duzelince (eksik yetenekler eklenince) eski kagitlar donuk kaliyor,
/// Armorer'in zirh modelleri ya da alt sinifin verdigi buyuler hic
/// gorunmuyordu.
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

  Future<String> makeArtificer({int level = 3}) async {
    await repo.createLevelOneCharacter(
      id: 'a1',
      name: 'Sabra',
      classKey: 'eberron-forge_artificer',
      abilities: const AbilityScores(intelligence: 16),
      savingThrows: {Ability.constitution, Ability.intelligence},
      skills: {Skill.arcana},
      hitDieSides: 8,
    );
    if (level > 1) {
      await repo.setClassLevel(
        characterId: 'a1',
        classKey: 'eberron-forge_artificer',
        level: level,
      );
    }
    return 'a1';
  }

  Future<Set<String>> featureNames(String id) async => {
    for (final f in await repo.features(id)) f.name,
  };

  group('buyu tablosu ayristirma', () {
    test('markdown tablosundan seviye -> buyu cikar', () {
      const desc = '''
When you reach a Cleric level specified in the table, you always have the
listed spells prepared.

Table: Life Domain Spells
| Cleric Level | Prepared Spells |
|---|---|
| 3 | Aid, Bless, Cure Wounds |
| 5th | Mass Healing Word, Revivify |
''';
      expect(parseGrantedSpellTable(desc), {
        3: ['Aid', 'Bless', 'Cure Wounds'],
        5: ['Mass Healing Word', 'Revivify'],
      });
    });

    test('dipnot yildizi ve parantez temizlenir', () {
      const desc = '''
| Cleric Level | Spells |
|---|---|
| 3 | Detect Magic*, Rations (3 days) |
''';
      expect(parseGrantedSpellTable(desc), {
        3: ['Detect Magic', 'Rations'],
      });
    });

    test('sinif sayaci tablolari buyu sanilmaz', () {
      const desc = '''
| Rages | Rage Damage |
|---|---|
| 2 | +2 |
''';
      expect(parseGrantedSpellTable(desc), isEmpty);
    });
  });

  group('yetenekler', () {
    test('1. seviye karakterin kagidi bos acilmaz', () async {
      final id = await makeArtificer(level: 1);
      final names = await featureNames(id);
      expect(names, contains('Spellcasting'));
    });

    test('alt sinif secilince ic ice yetenekler de gelir', () async {
      final id = await makeArtificer();
      await repo.setSubclass(
        characterId: id,
        classKey: 'eberron-forge_artificer',
        subclassKey: 'eberron-forge_armorer',
      );

      final names = await featureNames(id);
      // Zirh modelleri, 5etools'ta ust yetenegin govdesinden referansla
      // geliyor; cozulmezse kagitta hic gorunmuyorlardi.
      expect(names, containsAll(['Arcane Armor', 'Armor Model']));
      expect(names, containsAll(['Dreadnaught', 'Guardian', 'Infiltrator']));
      expect(names, contains('Armorer Spells'));
    });

    test('yetenegin isaret ettigi stat blogu metne gomulur', () async {
      final id = await makeArtificer();
      await repo.setSubclass(
        characterId: id,
        classKey: 'eberron-forge_artificer',
        subclassKey: 'eberron-forge_artillerist',
      );

      final cannon = (await repo.features(
        id,
      )).firstWhere((f) => f.name == 'Eldritch Cannon');
      // Topun ne oldugunu gormek icin kutuphaneye gitmek gerekmemeli.
      expect(cannon.description, contains('Table: Eldritch Cannon'));
      expect(cannon.description, contains('Armor Class'));
      expect(cannon.description, contains('Flamethrower'));
      expect(cannon.description, contains('Force Ballista'));
      expect(cannon.description, contains('Protector'));
    });

    test('kutuphane guncellenince eski kagit tazelenir', () async {
      final id = await makeArtificer();
      await repo.setSubclass(
        characterId: id,
        classKey: 'eberron-forge_artificer',
        subclassKey: 'eberron-forge_armorer',
      );

      // Eski surumden kalmis eksik bir kagidi taklit et.
      await db.customStatement(
        "DELETE FROM character_features WHERE character_id = 'a1' "
        "AND name IN ('Guardian', 'Infiltrator', 'Dreadnaught')",
      );
      expect(await featureNames(id), isNot(contains('Guardian')));

      await repo.syncAllCharacters();

      expect(await featureNames(id), contains('Guardian'));
    });

    test('elle eklenen yetenek ve harcanan kullanim korunur', () async {
      final id = await makeArtificer();
      await repo.addManualFeature(id, name: 'Kadim Ant', usesMax: 2);
      final feature = (await repo.features(
        id,
      )).firstWhere((f) => f.name == 'Spellcasting');
      await repo.setFeatureUsesSpent(feature.id, 1);

      await repo.syncClassContent(id);

      final after = await repo.features(id);
      expect(after.map((f) => f.name), contains('Kadim Ant'));
      expect(
        after.firstWhere((f) => f.name == 'Spellcasting').usesSpent,
        1,
        reason: 'harcanan kullanim sifirlanmamali',
      );
    });
  });

  group('alt sinifin verdigi buyuler', () {
    test('seviyeye kadar olanlar daima hazir olarak eklenir', () async {
      final id = await makeArtificer(level: 5);
      await repo.setSubclass(
        characterId: id,
        classKey: 'eberron-forge_artificer',
        subclassKey: 'eberron-forge_armorer',
      );

      final spells = await repo.knownSpells(id);
      final names = {for (final s in spells) s.name};
      // Armorer 3: Magic Missile, Thunderwave — 5: Mirror Image, Shatter.
      expect(names, containsAll(['Magic Missile', 'Thunderwave']));
      expect(names, containsAll(['Mirror Image', 'Shatter']));
      // 9. seviye buyuleri henuz gelmemeli.
      expect(names, isNot(contains('Lightning Bolt')));
      expect(spells.every((s) => s.alwaysPrepared), isTrue);
    });

    test('alt sinif degisince eski buyuler kalkar', () async {
      final id = await makeArtificer();
      await repo.setSubclass(
        characterId: id,
        classKey: 'eberron-forge_artificer',
        subclassKey: 'eberron-forge_armorer',
      );
      expect({
        for (final s in await repo.knownSpells(id)) s.name,
      }, contains('Magic Missile'));

      await repo.setSubclass(
        characterId: id,
        classKey: 'eberron-forge_artificer',
        subclassKey: 'eberron-forge_alchemist',
      );

      final names = {for (final s in await repo.knownSpells(id)) s.name};
      expect(names, isNot(contains('Magic Missile')));
      expect(names, contains('Healing Word'));
    });

    /// Armorer'a bakip biraktigimizda geri kalan alt siniflarda ayni eksik
    /// duruyordu; her belgeden bir ornek sabitleniyor.
    test('her kaynaktan alt siniflar buyularini veriyor', () async {
      const cases =
          <({String classKey, String subclassKey, int level, String spell})>[
            // SRD: tablo zaten metinde.
            (
              classKey: 'srd-2024_cleric',
              subclassKey: 'srd-2024_life-domain',
              level: 3,
              spell: 'Cure Wounds',
            ),
            // 2024 PHB: tablo `additionalSpells` yapisindan uretildi.
            (
              classKey: 'srd-2024_druid',
              subclassKey: 'phb-2024_circle-of-the-stars',
              level: 3,
              spell: 'Guiding Bolt',
            ),
            (
              classKey: 'srd-2024_bard',
              subclassKey: 'phb-2024_college-of-glamour',
              level: 3,
              spell: 'Mirror Image',
            ),
            // Kaynak kitaplar.
            (
              classKey: 'srd-2024_fighter',
              subclassKey: 'faerun-heroes_banneret',
              level: 3,
              spell: 'Comprehend Languages',
            ),
            (
              classKey: 'srd-2024_rogue',
              subclassKey: 'ravenloft-horrors_phantom',
              level: 9,
              spell: 'Speak with Dead',
            ),
          ];

      for (final c in cases) {
        final id = 'sub-${c.subclassKey}';
        await repo.createLevelOneCharacter(
          id: id,
          name: id,
          classKey: c.classKey,
          abilities: const AbilityScores(),
          savingThrows: const {},
          skills: const {},
          hitDieSides: 8,
        );
        await repo.setClassLevel(
          characterId: id,
          classKey: c.classKey,
          level: c.level,
        );
        await repo.setSubclass(
          characterId: id,
          classKey: c.classKey,
          subclassKey: c.subclassKey,
        );

        final names = {for (final s in await repo.knownSpells(id)) s.name};
        expect(
          names,
          contains(c.spell),
          reason: '${c.subclassKey} ${c.spell} vermeliydi',
        );
      }
    });

    test('oyuncunun kendi ogrendigi buyu silinmez', () async {
      final id = await makeArtificer();
      await repo.addKnownSpell(
        id,
        'phb-2024_fireball',
        classKey: 'eberron-forge_artificer',
      );

      await repo.syncClassContent(id);

      expect({
        for (final s in await repo.knownSpells(id)) s.spellKey,
      }, contains('phb-2024_fireball'));
    });
  });
}
