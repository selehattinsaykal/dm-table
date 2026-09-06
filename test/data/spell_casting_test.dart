import 'package:dm_table/data/character_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/import/asset_importer.dart';
import 'package:dm_table/domain/models/ability.dart';
import 'package:dm_table/domain/rules/spell_casting.dart';
import 'package:dm_table/domain/rules/character_math.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Buyu kullanma: yuvayi harcar, saldiri/kurtarma/hasar sayilarini kurar.
///
/// Buyu verisindeki `attack_roll`, `saving_throw_ability`, `damage_roll`
/// alanlari uzun sure hic okunmuyordu; masada herkes elle hesapliyordu.
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

  Future<String> makeWizard({int level = 5}) async {
    await repo.createLevelOneCharacter(
      id: 'w1',
      name: 'Nym',
      classKey: 'srd-2024_wizard',
      abilities: const AbilityScores(intelligence: 18),
      savingThrows: const {},
      skills: const {},
      hitDieSides: 6,
    );
    await repo.setClassLevel(
      characterId: 'w1',
      classKey: 'srd-2024_wizard',
      level: level,
    );
    await repo.applySpellbook(
      characterId: 'w1',
      classKey: 'srd-2024_wizard',
      spellKeys: {'phb-2024_fireball', 'phb-2024_magic-missile'},
    );
    await repo.applySpellSelection(
      characterId: 'w1',
      classKey: 'srd-2024_wizard',
      cantrips: {'phb-2024_fire-bolt'},
      prepared: {'phb-2024_fireball', 'phb-2024_magic-missile'},
    );
    return 'w1';
  }

  group('kurallar', () {
    test('buyu yetenegi sinifa gore secilir', () {
      expect(spellcastingAbilityFor('srd-2024_wizard'), Ability.intelligence);
      expect(
        spellcastingAbilityFor('eberron-forge_artificer'),
        Ability.intelligence,
      );
      expect(spellcastingAbilityFor('srd-2024_cleric'), Ability.wisdom);
      expect(spellcastingAbilityFor('srd-2024_fighter'), isNull);
    });

    test('cantrip hasari karakter seviyesiyle olceklenir', () {
      const spell = {
        'name': 'Fire Bolt',
        'level': 0,
        'attack_roll': true,
        'damage_roll': '1d10',
      };
      int diceOf(int level) => parseDamageDice(
        planSpellCast(
          spell: spell,
          slotLevel: 0,
          characterLevel: level,
          abilityModifier: 4,
          proficiencyBonus: 3,
        ).damageDice!,
      )!.count;

      expect(diceOf(1), 1);
      expect(diceOf(5), 2);
      expect(diceOf(11), 3);
      expect(diceOf(17), 4);
    });

    test('saldiri bonusu ve kurtarma DC yetenekten gelir', () {
      final attack = planSpellCast(
        spell: const {'name': 'Fire Bolt', 'level': 0, 'attack_roll': true},
        slotLevel: 0,
        characterLevel: 5,
        abilityModifier: 4,
        proficiencyBonus: 3,
      );
      expect(attack.attackBonus, 7);
      expect(attack.hasSave, isFalse);

      final save = planSpellCast(
        spell: const {
          'name': 'Fireball',
          'level': 3,
          'saving_throw_ability': 'dexterity',
          'damage_roll': '8d6',
        },
        slotLevel: 3,
        characterLevel: 5,
        abilityModifier: 4,
        proficiencyBonus: 3,
      );
      expect(save.saveDc, 15);
      expect(save.saveAbility, Ability.dexterity);
      expect(save.damageDice, '8d6');
    });

    test('verideki ust seviye tablosu kullanilir', () {
      final plan = planSpellCast(
        spell: const {
          'name': 'Acid Arrow',
          'level': 2,
          'damage_roll': '4d4',
          'casting_options': [
            {'type': 'slot_level_3', 'damage_roll': '5d4'},
            {'type': 'slot_level_4', 'damage_roll': '6d4'},
          ],
        },
        slotLevel: 4,
        characterLevel: 7,
        abilityModifier: 3,
        proficiencyBonus: 3,
      );
      expect(plan.damageDice, '6d4');
    });

    test('hasar zari ayristirilir', () {
      expect(parseDamageDice('8d6'), (count: 8, sides: 6, modifier: 0));
      expect(parseDamageDice('1d4 + 1'), (count: 1, sides: 4, modifier: 1));
      expect(parseDamageDice('yok'), isNull);
    });
  });

  group('kullanim', () {
    test('yuva harcanir ve plan doner', () async {
      final id = await makeWizard();
      final before = (await repo.find(id))!.spellSlotsUsedJson;
      expect(before, '{}');

      final plan = await repo.castSpell(
        characterId: id,
        spellKey: 'phb-2024_fireball',
        slotLevel: 3,
      );

      expect(plan, isNotNull);
      expect(plan!.spellName, 'Fireball');
      expect(plan.slotLevel, 3);
      // INT 18 (+4), 5. seviyede PB +3 -> DC 15.
      expect(plan.saveDc, 15);
      expect((await repo.find(id))!.spellSlotsUsedJson, contains('"3":1'));
    });

    test('cantrip yuva harcamaz', () async {
      final id = await makeWizard();
      final plan = await repo.castSpell(
        characterId: id,
        spellKey: 'phb-2024_fire-bolt',
        slotLevel: 0,
      );

      expect(plan, isNotNull);
      expect(plan!.attackBonus, 7);
      expect((await repo.find(id))!.spellSlotsUsedJson, '{}');
    });

    test('yuva bittiginde kullanilamaz', () async {
      final id = await makeWizard(level: 1);
      await repo.applySpellbook(
        characterId: id,
        classKey: 'srd-2024_wizard',
        spellKeys: {'phb-2024_magic-missile'},
      );
      await repo.applySpellSelection(
        characterId: id,
        classKey: 'srd-2024_wizard',
        cantrips: const {},
        prepared: {'phb-2024_magic-missile'},
      );

      // 1. seviye Wizard'in iki adet 1. seviye yuvasi var.
      for (var i = 0; i < 2; i++) {
        expect(
          await repo.castSpell(
            characterId: id,
            spellKey: 'phb-2024_magic-missile',
            slotLevel: 1,
          ),
          isNotNull,
        );
      }
      expect(
        await repo.castSpell(
          characterId: id,
          spellKey: 'phb-2024_magic-missile',
          slotLevel: 1,
        ),
        isNull,
        reason: 'bos yuva kalmadi',
      );
    });

    test('bilinmeyen buyu kullanilamaz', () async {
      final id = await makeWizard();
      expect(
        await repo.castSpell(
          characterId: id,
          spellKey: 'phb-2024_cure-wounds',
          slotLevel: 1,
        ),
        isNull,
      );
    });

    test('dusuk yuva secilirse buyunun kendi seviyesine yukseltilir', () async {
      final id = await makeWizard();
      final plan = await repo.castSpell(
        characterId: id,
        spellKey: 'phb-2024_fireball',
        slotLevel: 1,
      );
      expect(plan!.slotLevel, 3);
      expect((await repo.find(id))!.spellSlotsUsedJson, contains('"3":1'));
    });
  });
}
