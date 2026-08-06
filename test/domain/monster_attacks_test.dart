import 'dart:math';

import 'package:dm_table/domain/rules/dice.dart';
import 'package:dm_table/domain/rules/monster_attacks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('attacksFromAction', () {
    test('yapisal saldiri alanlarini cozer', () {
      final attacks = attacksFromAction({
        'name': 'Tentacle',
        'attacks': [
          {
            'name': 'Tentacle attack',
            'to_hit_mod': 9,
            'damage_die_count': 2,
            'damage_die_type': 'D6',
            'damage_bonus': 5,
            'damage_type': {'name': 'Bludgeoning', 'key': 'bludgeoning'},
          },
        ],
      });
      final a = attacks.single;
      expect(a.name, 'Tentacle attack');
      expect(a.toHit, 9);
      expect(a.damageDiceCount, 2);
      expect(a.damageDieSides, 6);
      expect(a.damageBonus, 5);
      expect(a.damageType, 'Bludgeoning');
      expect(a.hasToHit, isTrue);
      expect(a.hasDamage, isTrue);
    });

    test('saldirisiz aksiyon bos liste doner', () {
      expect(
        attacksFromAction({'name': 'Spellcasting', 'attacks': []}),
        isEmpty,
      );
      expect(attacksFromAction({'name': 'Nothing'}), isEmpty);
    });

    test('ek hasar ve bos hasar tipi tolere edilir', () {
      final a = attacksFromAction({
        'attacks': [
          {
            'name': 'Rend',
            'to_hit_mod': 12,
            'damage_die_count': 2,
            'damage_die_type': 'D8',
            'damage_bonus': 7,
            'damage_type': null,
            'extra_damage_die_count': 1,
            'extra_damage_die_type': 'D10',
            'extra_damage_bonus': 0,
            'extra_damage_type': {'name': 'Lightning', 'key': 'lightning'},
          },
        ],
      }).single;
      expect(a.damageType, isNull);
      expect(a.extraDamageDiceCount, 1);
      expect(a.extraDamageDieSides, 10);
      expect(a.extraDamageType, 'Lightning');
    });
  });

  test('dieSidesFromCode "D6"/"d10" -> 6/10, tanimsiz -> 0', () {
    expect(dieSidesFromCode('D6'), 6);
    expect(dieSidesFromCode('d10'), 10);
    expect(dieSidesFromCode(null), 0);
    expect(dieSidesFromCode('melee'), 0);
  });

  group('rollToHit', () {
    test('d20 + mod atar', () {
      final roller = DiceRoller(_Fixed([14])); // dogal 14
      const attack = MonsterAttack(name: 'Bite', toHit: 5);
      final roll = attack.rollToHit(roller);
      expect(roll!.total, 19); // 14 + 5
    });

    test('toHit null ise null doner', () {
      final roller = DiceRoller(_Fixed([10]));
      const attack = MonsterAttack(name: 'Aura');
      expect(attack.rollToHit(roller), isNull);
    });
  });

  group('rollDamage', () {
    test('normal: zar + bonus toplami', () {
      // 2d6 -> [4,3], +5 = 12
      final roller = DiceRoller(_Fixed([4, 3]));
      const attack = MonsterAttack(
        name: 'Tentacle',
        damageDiceCount: 2,
        damageDieSides: 6,
        damageBonus: 5,
      );
      final dmg = attack.rollDamage(roller);
      expect(dmg.total, 12);
      expect(dmg.critical, isFalse);
    });

    test('kritik: zar sayisi ikiye katlanir, bonus katlanmaz', () {
      // Kritikte 4 zar atilir: [1,1,1,1] = 4, +5 = 9
      final roller = DiceRoller(_Fixed([1, 1, 1, 1]));
      const attack = MonsterAttack(
        name: 'Tentacle',
        damageDiceCount: 2,
        damageDieSides: 6,
        damageBonus: 5,
      );
      final dmg = attack.rollDamage(roller, critical: true);
      expect(dmg.total, 9);
      expect(dmg.critical, isTrue);
    });

    test('ek hasar da toplanir', () {
      // 2d8 -> [8,8] +7 = 23, ek 1d10 -> [10] +0 = 10, toplam 33
      final roller = DiceRoller(_Fixed([8, 8, 10]));
      const attack = MonsterAttack(
        name: 'Rend',
        damageDiceCount: 2,
        damageDieSides: 8,
        damageBonus: 7,
        extraDamageDiceCount: 1,
        extraDamageDieSides: 10,
      );
      final dmg = attack.rollDamage(roller);
      expect(dmg.total, 33);
      expect(dmg.parts.length, 2);
    });
  });
}

/// Verilen dogal zar dizisini sirayla dondurur (nextInt(sides) = value - 1).
class _Fixed implements Random {
  _Fixed(this._values);
  final List<int> _values;
  int _i = 0;

  @override
  int nextInt(int max) => _values[_i++ % _values.length] - 1;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0.0;
}
