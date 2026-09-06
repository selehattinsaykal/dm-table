import 'package:dm_table/data/character_repository.dart';
import 'package:dm_table/data/db/character_tables.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/import/asset_importer.dart';
import 'package:dm_table/domain/models/ability.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Karakter yaratildiktan SONRA yapilan duzenlemeler.
///
/// Sihirbaz yalnizca 1. seviyeyi kuruyor; ad, yetenek puani, gecmis ve sinif
/// sonradan degisebilmeli. Kritik olan, degisikligin yalnizca kendi satirini
/// degil ona bagli turetilmis her seyi (can, yetenek listesi, kurtarma
/// yeterlilikleri) birlikte guncellemesi.
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

  Future<String> makeWizard({
    AbilityScores abilities = const AbilityScores(),
    String background = 'srd-2024_acolyte',
  }) async {
    await repo.createLevelOneCharacter(
      id: 'c1',
      name: 'Elowen',
      classKey: 'srd-2024_wizard',
      speciesKey: 'srd-2024_elf',
      backgroundKey: background,
      abilities: abilities,
      savingThrows: {Ability.intelligence, Ability.wisdom},
      skills: {Skill.arcana, Skill.insight, Skill.religion},
      hitDieSides: 6,
    );
    return 'c1';
  }

  Future<List<CharacterFeature>> features(String id) => repo.features(id);

  Future<Set<String>> skillsOf(String id) async => {
    for (final p in await repo.proficiencies(id))
      if (p.kind == ProficiencyKind.skill) p.value,
  };

  Future<Set<String>> savesOf(String id) async => {
    for (final p in await repo.proficiencies(id))
      if (p.kind == ProficiencyKind.save) p.value,
  };

  group('kimlik', () {
    test('ad, oyuncu ve hizalama degisir', () async {
      final id = await makeWizard();

      await repo.updateIdentity(
        id,
        name: '  Elowen Duskwhisper ',
        playerName: 'Selin',
        alignment: 'Chaotic Good',
      );

      final c = await repo.find(id);
      expect(c!.name, 'Elowen Duskwhisper');
      expect(c.playerName, 'Selin');
      expect(c.alignment, 'Chaotic Good');
    });

    test('bos oyuncu adi temizlenir', () async {
      final id = await makeWizard();
      await repo.updateIdentity(id, name: 'Elowen', playerName: '   ');
      expect((await repo.find(id))!.playerName, isNull);
    });
  });

  group('yetenek puanlari', () {
    test('CON artisi azami cani her seviye icin buyutur', () async {
      final id = await makeWizard();
      await repo.setClassLevel(
        characterId: id,
        classKey: 'srd-2024_wizard',
        level: 3,
      );
      final before = (await repo.find(id))!.hitPointsMax;

      await repo.setAbilityScores(id, const AbilityScores(constitution: 14));

      // +2 modifier x 3 seviye = +6 can.
      expect((await repo.find(id))!.hitPointsMax, before + 6);
      expect((await repo.find(id))!.constitution, 14);
    });

    test('CON dususunde can geri alinir ve mevcut can tavani asmaz', () async {
      final id = await makeWizard(
        abilities: const AbilityScores(constitution: 16),
      );
      final before = (await repo.find(id))!.hitPointsMax;

      await repo.setAbilityScores(id, const AbilityScores());

      final after = await repo.find(id);
      expect(after!.hitPointsMax, before - 3);
      expect(after.hitPointsCurrent, lessThanOrEqualTo(after.hitPointsMax));
    });

    test('elle azami can mevcut cani kirpar', () async {
      final id = await makeWizard();
      await repo.setHitPointsMax(id, 4);
      final c = await repo.find(id);
      expect(c!.hitPointsMax, 4);
      expect(c.hitPointsCurrent, 4);
    });

    test('AC ve hiz elle verilip geri alinabilir', () async {
      final id = await makeWizard();
      await repo.setOverrides(id, armorClass: 18, speed: 40);
      expect((await repo.find(id))!.armorClassOverride, 18);

      await repo.setOverrides(id, armorClass: null, speed: null);
      final c = await repo.find(id);
      expect(c!.armorClassOverride, isNull);
      expect(c.speedOverride, isNull);
    });
  });

  group('gecmis ve tur', () {
    test('gecmis degisince becerileri de degisir', () async {
      final id = await makeWizard();
      expect(await skillsOf(id), containsAll(['insight', 'religion']));

      await repo.setBackground(id, 'srd-2024_criminal');

      final skills = await skillsOf(id);
      expect(skills, containsAll(['sleightOfHand', 'stealth']));
      // Acolyte'in verdikleri gitti, sinif secimi (Arcana) kaldi.
      expect(skills, isNot(contains('religion')));
      expect(skills, contains('arcana'));
      expect((await repo.find(id))!.backgroundKey, 'srd-2024_criminal');
    });

    test('tur degisir', () async {
      final id = await makeWizard();
      await repo.setSpecies(id, 'srd-2024_dwarf');
      expect((await repo.find(id))!.speciesKey, 'srd-2024_dwarf');
    });
  });

  group('yeterlilikler', () {
    test('elle acilip kapatilir, uzmanlik verilebilir', () async {
      final id = await makeWizard();

      await repo.setProficiency(
        id,
        kind: ProficiencyKind.skill,
        value: Skill.stealth.name,
        proficient: true,
      );
      expect(
        (await repo.buildFor(id)).skillProficiencies,
        contains(Skill.stealth),
      );

      await repo.setProficiency(
        id,
        kind: ProficiencyKind.skill,
        value: Skill.stealth.name,
        proficient: true,
        expertise: true,
      );
      expect((await repo.buildFor(id)).skillExpertise, contains(Skill.stealth));

      await repo.setProficiency(
        id,
        kind: ProficiencyKind.skill,
        value: Skill.stealth.name,
        proficient: false,
      );
      expect(
        (await repo.buildFor(id)).skillProficiencies,
        isNot(contains(Skill.stealth)),
      );
    });

    test('sinifin verdigi kurtarma atisi da kapatilabilir', () async {
      final id = await makeWizard();
      await repo.setProficiency(
        id,
        kind: ProficiencyKind.save,
        value: Ability.wisdom.name,
        proficient: false,
      );
      expect(await savesOf(id), isNot(contains('wisdom')));
    });
  });

  group('sinif degisimi', () {
    test('seviye korunur, yetenekler ve kurtarmalar yenilenir', () async {
      final id = await makeWizard();
      await repo.setClassLevel(
        characterId: id,
        classKey: 'srd-2024_wizard',
        level: 3,
      );
      await repo.setSubclass(
        characterId: id,
        classKey: 'srd-2024_wizard',
        subclassKey: 'srd-2024_evoker',
      );
      await repo.addKnownSpell(
        id,
        'srd-2024_fireball',
        classKey: 'srd-2024_wizard',
      );

      await repo.changeClass(
        characterId: id,
        fromClassKey: 'srd-2024_wizard',
        toClassKey: 'srd-2024_cleric',
      );

      final levels = await repo.classLevels(id);
      expect(levels, hasLength(1));
      expect(levels.single.classKey, 'srd-2024_cleric');
      expect(levels.single.level, 3);
      expect(levels.single.subclassKey, isNull, reason: 'alt sinif dusmeli');

      final sources = {for (final f in await features(id)) f.source};
      expect(sources, contains('srd-2024_cleric'));
      expect(sources, isNot(contains('srd-2024_wizard')));
      expect(sources, isNot(contains('srd-2024_evoker')));

      // Cleric: Bilgelik ve Karizma.
      expect(await savesOf(id), {'wisdom', 'charisma'});

      final spells = await db.select(db.characterSpells).get();
      expect(spells.single.classKey, 'srd-2024_cleric');

      // Atilmis can zarlari korunur (2. ve 3. seviyede 4'er); yalnizca
      // 1. seviyenin sabit degeri yeni hit die'a gecer: d6 6 -> d8 8.
      expect((await repo.find(id))!.hitPointsMax, 8 + 4 + 4);
    });

    test('alt sinif degisince eski alt sinifin yetenekleri gider', () async {
      final id = await makeWizard();
      await repo.changeClass(
        characterId: id,
        fromClassKey: 'srd-2024_wizard',
        toClassKey: 'srd-2024_cleric',
      );
      await repo.setClassLevel(
        characterId: id,
        classKey: 'srd-2024_cleric',
        level: 3,
      );
      await repo.setSubclass(
        characterId: id,
        classKey: 'srd-2024_cleric',
        subclassKey: 'srd-2024_life-domain',
      );
      expect({
        for (final f in await features(id)) f.source,
      }, contains('srd-2024_life-domain'));

      await repo.setSubclass(
        characterId: id,
        classKey: 'srd-2024_cleric',
        subclassKey: 'phb-2024_war-domain',
      );

      final sources = {for (final f in await features(id)) f.source};
      expect(sources, contains('phb-2024_war-domain'));
      expect(sources, isNot(contains('srd-2024_life-domain')));
    });
  });

  group('seviye duzeltme', () {
    test('yukari cikinca yetenek ve can eklenir', () async {
      final id = await makeWizard();
      final before = (await repo.find(id))!.hitPointsMax;

      await repo.setClassLevel(
        characterId: id,
        classKey: 'srd-2024_wizard',
        level: 4,
      );

      expect((await repo.classLevels(id)).single.level, 4);
      // d6 ortalamasi 4; uc yeni seviye.
      expect((await repo.find(id))!.hitPointsMax, before + 12);
      expect(
        (await features(id)).where((f) => (f.gainedAtLevel ?? 0) > 1),
        isNotEmpty,
      );
    });

    test('asagi inince o seviyelerin yetenekleri geri alinir', () async {
      final id = await makeWizard();
      await repo.setClassLevel(
        characterId: id,
        classKey: 'srd-2024_wizard',
        level: 5,
      );
      final atFive = (await repo.find(id))!.hitPointsMax;

      await repo.setClassLevel(
        characterId: id,
        classKey: 'srd-2024_wizard',
        level: 2,
      );

      expect((await repo.classLevels(id)).single.level, 2);
      expect((await repo.find(id))!.hitPointsMax, atFive - 12);
      expect(
        (await features(id)).where((f) => (f.gainedAtLevel ?? 0) > 2),
        isEmpty,
      );
    });

    test('seviye 1-20 araliginda kalir', () async {
      final id = await makeWizard();
      await repo.setClassLevel(
        characterId: id,
        classKey: 'srd-2024_wizard',
        level: 99,
      );
      expect((await repo.classLevels(id)).single.level, 20);
    });
  });

  group('tur degisimi', () {
    test('hiz yeni turden gelir', () async {
      final id = await makeWizard();
      expect((await repo.buildFor(id)).baseSpeed, 30, reason: 'Elf');

      await repo.setSpecies(id, 'srd-2024_goliath');
      expect((await repo.buildFor(id)).baseSpeed, 35, reason: 'Goliath');
    });

    test('tur kaldirilinca varsayilan hiza doner', () async {
      final id = await makeWizard();
      await repo.setSpecies(id, 'srd-2024_goliath');
      await repo.setSpecies(id, null);
      expect((await repo.buildFor(id)).baseSpeed, 30);
    });

    test('kagit satiri dokunuluyor: ekran yenilensin', () async {
      final id = await makeWizard();
      // Damga saniye cozunurlugunde saklandigi icin "biraz bekle" yetmiyor;
      // satir bilerek geriye alinip ileri gittigi dogrulaniyor.
      await db.customStatement(
        'UPDATE characters SET updated_at = 0 WHERE id = ?',
        [id],
      );

      await repo.setSpecies(id, 'srd-2024_dwarf');

      expect(
        (await repo.find(id))!.updatedAt.millisecondsSinceEpoch,
        greaterThan(0),
      );
    });
  });

  test(
    'gecmis degisimi yeterlilikleri yazdiktan SONRA satiri dokunur',
    () async {
      // Yeterlilikler karakter satirini izleyerek okunuyor; satir once
      // dokunulursa ekran degisimden ONCEKI listeyi gosterip oyle kaliyordu.
      final id = await makeWizard(background: 'srd-2024_acolyte');
      await repo.setBackground(id, 'srd-2024_criminal');

      final row = (await repo.find(id))!;
      final derived = (await repo.proficiencies(
        id,
      )).where((p) => p.source != ProficiencySource.manual).toList();
      expect(derived, isNotEmpty);
      // Butun yeterlilik yazimlari bittikten sonra dokunulmus olmali.
      expect(row.updatedAt.isBefore(DateTime.now()), isTrue);
      expect(row.backgroundKey, 'srd-2024_criminal');
    },
  );
}
