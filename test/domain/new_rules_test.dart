import 'package:dm_table/domain/rules/damage_types.dart';
import 'package:dm_table/domain/rules/death_saves.dart';
import 'package:dm_table/domain/rules/downtime.dart';
import 'package:dm_table/domain/rules/spell_area.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('hasar turleri', () {
    const defenses = Defenses(
      resistant: {DamageType.fire},
      immune: {DamageType.poison},
      vulnerable: {DamageType.cold},
    );

    test('direnc hasari yariya iner ve ASAGI yuvarlanir', () {
      expect(applyDefenses(9, DamageType.fire, defenses).amount, 4);
    });

    test('bagisiklik hasari sifirlar', () {
      final result = applyDefenses(30, DamageType.poison, defenses);
      expect(result.amount, 0);
      expect(result.modifier, DamageModifier.immune);
    });

    test('zayiflik hasari ikiye katlar', () {
      expect(applyDefenses(7, DamageType.cold, defenses).amount, 14);
    });

    test('tur verilmezse hasar degismez', () {
      expect(applyDefenses(13, null, defenses).amount, 13);
    });

    test('direnc ve zayiflik birbirini goturur', () {
      const both = Defenses(
        resistant: {DamageType.fire},
        vulnerable: {DamageType.fire},
      );
      expect(applyDefenses(10, DamageType.fire, both).amount, 10);
    });

    test('JSON gidip geliyor', () {
      final restored = Defenses.decode(defenses.encode());
      expect(restored.resistant, {DamageType.fire});
      expect(restored.immune, {DamageType.poison});
      expect(restored.vulnerable, {DamageType.cold});
    });

    test('bozuk JSON bos savunma doner', () {
      expect(Defenses.decode('{bozuk').isEmpty, isTrue);
    });

    test('metinden tur cikarilir', () {
      final parsed = defensesFromText(
        resistances:
            'bludgeoning, piercing and slashing from nonmagical '
            'attacks',
        immunities: 'fire, poison',
      );
      expect(parsed.resistant, contains(DamageType.slashing));
      expect(parsed.immune, {DamageType.fire, DamageType.poison});
    });
  });

  group('olum kurtarmasi', () {
    test('uc basari stabil eder', () {
      var saves = emptyDeathSaves;
      for (var i = 0; i < 3; i++) {
        saves = rollDeathSave(saves, 15).saves;
      }
      expect(deathSaveState(saves), DeathSaveState.stable);
    });

    test('dogal 1 IKI basarisizlik sayar', () {
      final result = rollDeathSave(emptyDeathSaves, 1);
      expect(result.saves.failures, 2);
      expect(result.state, DeathSaveState.pending);
    });

    test('dogal 20 sayaci sifirlar ve ayaga kaldirir', () {
      final result = rollDeathSave((successes: 1, failures: 2), 20);
      expect(result.state, DeathSaveState.revived);
      expect(result.saves, emptyDeathSaves);
    });

    test('uc basarisizlik olum', () {
      final result = rollDeathSave((successes: 0, failures: 2), 5);
      expect(result.state, DeathSaveState.dead);
    });

    test('yerdeyken alinan hasar bir basarisizlik, kritik iki', () {
      expect(damageWhileDown(emptyDeathSaves).saves.failures, 1);
      expect(
        damageWhileDown(emptyDeathSaves, critical: true).saves.failures,
        2,
      );
    });

    test('9 basarisiz, 10 basarili', () {
      expect(rollDeathSave(emptyDeathSaves, 9).saves.failures, 1);
      expect(rollDeathSave(emptyDeathSaves, 10).saves.successes, 1);
    });
  });

  group('buyu etki alani', () {
    test('kure yaricapi', () {
      final area = spellAreaFrom(
        'A bright streak ... a 20-foot-radius sphere of flame.',
      );
      expect(area, isNotNull);
      expect(area!.kind, SpellAreaKind.circle);
      expect(area.size, 20);
    });

    test('koni', () {
      final area = spellAreaFrom('flames in a 15-foot cone.');
      expect(area!.kind, SpellAreaKind.cone);
      expect(area.size, 15);
    });

    test('cizgi', () {
      final area = spellAreaFrom(
        'a line 100 feet long ... a 100-foot-long, 5-foot-wide line',
      );
      expect(area!.kind, SpellAreaKind.line);
      expect(area.size, 100);
    });

    test('kup', () {
      final area = spellAreaFrom('a 15-foot cube of swirling ice.');
      expect(area!.kind, SpellAreaKind.square);
      expect(area.size, 15);
    });

    test('alani olmayan buyu null doner', () {
      expect(spellAreaFrom('You touch one creature and heal it.'), isNull);
    });
  });

  group('bos zaman', () {
    test('zanaat kazanc birakir', () {
      // Gunde 5 gp deger, 2.5 gp malzeme -> 10 gunde 25 gp net.
      expect(downtimeNetCp(DowntimeKind.craft, 10), 2500);
    });

    test('arastirma gider yazar', () {
      expect(downtimeNetCp(DowntimeKind.research, 3), -300);
    });

    test('serbest faaliyet para etkilemez', () {
      expect(downtimeNetCp(DowntimeKind.custom, 30), 0);
    });

    test('kalan gun bitince sifirlanir', () {
      expect(downtimeRemaining(startDay: 10, days: 5, today: 12), 3);
      expect(downtimeRemaining(startDay: 10, days: 5, today: 15), 0);
      expect(downtimeRemaining(startDay: 10, days: 5, today: 99), 0);
    });

    test('sifir gun bir gune yuvarlanir', () {
      expect(downtimeEndDay(5, 0), 6);
    });
  });
}
