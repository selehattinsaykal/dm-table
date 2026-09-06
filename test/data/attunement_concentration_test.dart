import 'package:dm_table/data/character_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/import/asset_importer.dart';
import 'package:dm_table/domain/models/ability.dart';
import 'package:dm_table/domain/rules/character_math.dart';
import 'package:dm_table/domain/rules/multiclassing.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Baglilik siniri, multiclass esigi ve konsantrasyon takibi.
///
/// Ucu de veride ya da kuralda vardi ama uygulanmiyordu: istedigin kadar
/// esyaya baglanabiliyor, istedigin sinifa seviye atlayabiliyor, konsantrasyon
/// ise hic tutulmuyordu.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CharacterRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await AssetImporter(db).importIfNeeded();
    repo = CharacterRepository(db);
    await repo.createLevelOneCharacter(
      id: 'c1',
      name: 'Vex',
      classKey: 'srd-2024_wizard',
      abilities: const AbilityScores(intelligence: 16, constitution: 14),
      savingThrows: const {},
      skills: const {},
      hitDieSides: 6,
    );
  });

  tearDown(() async => db.close());

  group('baglilik (attunement)', () {
    Future<String> addItem(String name) async {
      await repo.addItem(characterId: 'c1', customName: name);
      final items = await repo.items('c1');
      return items.firstWhere((i) => i.customName == name).id;
    }

    test('en fazla uc esyaya baglanilir', () async {
      final ids = [
        for (final n in ['A', 'B', 'C', 'D']) await addItem(n),
      ];

      for (var i = 0; i < maxAttunedItems; i++) {
        expect(await repo.setAttuned(ids[i], true), isTrue);
      }
      expect(
        await repo.setAttuned(ids[3], true),
        isFalse,
        reason: 'dorduncu esya baglanmamali',
      );
      expect(await repo.attunedCount('c1'), maxAttunedItems);
    });

    test('bagi cozunce yer acilir', () async {
      final ids = [
        for (final n in ['A', 'B', 'C', 'D']) await addItem(n),
      ];
      for (var i = 0; i < 3; i++) {
        await repo.setAttuned(ids[i], true);
      }

      await repo.setAttuned(ids[0], false);
      expect(await repo.setAttuned(ids[3], true), isTrue);
      expect(await repo.attunedCount('c1'), 3);
    });
  });

  group('multiclass esigi', () {
    test('yetenek puani yetmezse yeni sinif alinamaz', () {
      // INT 16 Wizard; Fighter icin STR ya da DEX 13 gerekiyor.
      final check = canMulticlassInto(
        target: 'srd-2024_fighter',
        currentClasses: const ['srd-2024_wizard'],
        scores: const AbilityScores(intelligence: 16),
      );
      expect(check.allowed, isFalse);
      expect(check.missing, isNotEmpty);
    });

    test('her iki sinifin esigi de aranir', () {
      // DEX 14 Fighter olur ama Wizard icin INT 13 de lazim.
      expect(
        canMulticlassInto(
          target: 'srd-2024_fighter',
          currentClasses: const ['srd-2024_wizard'],
          scores: const AbilityScores(dexterity: 14, intelligence: 10),
        ).allowed,
        isFalse,
      );
      expect(
        canMulticlassInto(
          target: 'srd-2024_fighter',
          currentClasses: const ['srd-2024_wizard'],
          scores: const AbilityScores(dexterity: 14, intelligence: 13),
        ).allowed,
        isTrue,
      );
    });

    test('sahip olunan sinifta ilerlemek kosul aramaz', () {
      expect(
        canMulticlassInto(
          target: 'srd-2024_wizard',
          currentClasses: const ['srd-2024_wizard'],
          scores: const AbilityScores(),
        ).allowed,
        isTrue,
      );
    });

    test('Monk iki yetenegi birden ister', () {
      expect(
        canMulticlassInto(
          target: 'srd-2024_monk',
          currentClasses: const ['srd-2024_rogue'],
          scores: const AbilityScores(dexterity: 16, wisdom: 10),
        ).allowed,
        isFalse,
      );
    });
  });

  group('konsantrasyon', () {
    test('konsantrasyonlu buyu kullaninca isaretlenir', () async {
      await repo.applySpellbook(
        characterId: 'c1',
        classKey: 'srd-2024_wizard',
        spellKeys: {'phb-2024_mage-armor'},
      );
      await repo.applySpellSelection(
        characterId: 'c1',
        classKey: 'srd-2024_wizard',
        cantrips: const {},
        prepared: {'phb-2024_mage-armor'},
      );
      // Konsantrasyon gerektiren bir buyu sec: Wizard listesinden.
      final concentrating = (await db.select(db.spells).get())
          .where((s) => s.concentration && s.level == 1)
          .firstWhere((s) => s.classesCsv.contains('srd-2024_wizard'));
      await repo.applySpellbook(
        characterId: 'c1',
        classKey: 'srd-2024_wizard',
        spellKeys: {concentrating.key},
      );
      await repo.applySpellSelection(
        characterId: 'c1',
        classKey: 'srd-2024_wizard',
        cantrips: const {},
        prepared: {concentrating.key},
      );

      await repo.castSpell(
        characterId: 'c1',
        spellKey: concentrating.key,
        slotLevel: 1,
      );

      expect((await repo.find('c1'))!.concentrationSpell, concentrating.name);
    });

    test('can sifirlaninca konsantrasyon biter', () async {
      await repo.setConcentration('c1', 'Bless');
      await repo.applyDamage('c1', 999);
      expect((await repo.find('c1'))!.concentrationSpell, isNull);
    });

    test('kurtarma DC hasarin yarisi, en az 10', () {
      expect(CharacterRepository.concentrationSaveDc(6), 10);
      expect(CharacterRepository.concentrationSaveDc(30), 15);
      expect(CharacterRepository.concentrationSaveDc(0), isNull);
    });
  });
}
