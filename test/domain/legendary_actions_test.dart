import 'package:dm_table/domain/rules/legendary_actions.dart';
import 'package:flutter_test/flutter_test.dart';

/// Veri setinde efsanevi eylemler iki ayri sekilde duruyor; ikisi de
/// okunmali (12 mm-2024 canavarinin eylemleri bu yuzden gorunmuyordu).
void main() {
  group('legendaryActionsOf', () {
    test('SEKIL A: actions[] icinde action_type == LEGENDARY_ACTION', () {
      final data = {
        'actions': [
          {'name': 'Bite', 'desc': 'Isirir.', 'action_type': 'ACTION'},
          {
            'name': 'Lash',
            'desc': 'Bir Tentacle saldirisi yapar.',
            'action_type': 'LEGENDARY_ACTION',
            'legendary_action_cost': 1,
            'order_in_statblock': 0,
          },
        ],
      };
      final actions = legendaryActionsOf(data);
      expect(actions, hasLength(1));
      expect(actions.single.name, 'Lash');
      expect(actions.single.cost, 1);
    });

    test('SEKIL B: ust duzey legendary_actions[] dizisi', () {
      final data = {
        'actions': [
          {'name': 'Rend', 'desc': 'Parcalar.', 'action_type': 'ACTION'},
        ],
        'legendary_actions': [
          {
            'name': 'Feral Strike',
            'desc': 'Hareket eder ve saldirir.',
            'action_type': 'LEGENDARY_ACTION',
            'order_in_statblock': 0,
          },
        ],
      };
      final actions = legendaryActionsOf(data);
      expect(actions, hasLength(1));
      expect(actions.single.name, 'Feral Strike');
      // Bu sekilde `legendary_action_cost` yok -> 1 kabul edilir.
      expect(actions.single.cost, 1);
    });

    test('normal aksiyonlar listeye girmez', () {
      final data = {
        'actions': [
          {'name': 'Bite', 'action_type': 'ACTION'},
          {'name': 'Dodge', 'action_type': 'REACTION'},
          {'name': 'Dash', 'action_type': 'BONUS_ACTION'},
        ],
      };
      expect(legendaryActionsOf(data), isEmpty);
    });

    test('efsanevi eylemi olmayan canavar bos liste', () {
      expect(legendaryActionsOf({'actions': <dynamic>[]}), isEmpty);
      expect(legendaryActionsOf(<String, dynamic>{}), isEmpty);
    });

    test('order_in_statblock siralamayi belirler', () {
      final data = {
        'legendary_actions': [
          {'name': 'Ucuncu', 'order_in_statblock': 2},
          {'name': 'Birinci', 'order_in_statblock': 0},
          {'name': 'Ikinci', 'order_in_statblock': 1},
        ],
      };
      expect(legendaryActionsOf(data).map((a) => a.name).toList(), [
        'Birinci',
        'Ikinci',
        'Ucuncu',
      ]);
    });

    test('maliyet 1 ve altina dusmez', () {
      final data = {
        'legendary_actions': [
          {'name': 'A', 'legendary_action_cost': 0},
          {'name': 'B', 'legendary_action_cost': 2},
        ],
      };
      final actions = legendaryActionsOf(data);
      expect(actions[0].cost, 1);
      expect(actions[1].cost, 2);
    });

    test('bozuk veri firlatmaz', () {
      expect(legendaryActionsOf({'actions': 'metin'}), isEmpty);
      expect(legendaryActionsOf({'legendary_actions': 42}), isEmpty);
      // Adsiz giris atlanir.
      expect(
        legendaryActionsOf({
          'legendary_actions': [
            {'desc': 'ad yok'},
          ],
        }),
        isEmpty,
      );
    });
  });

  group('legendaryResistanceOf', () {
    test('gunluk hak addan cikarilir', () {
      for (final (name, expected) in [
        ('Legendary Resistance (3/Day, or 4/Day in Lair)', 3),
        ('Legendary Resistance (4/Day, or 5/Day in Lair)', 4),
        ('Legendary Resistance (3/Day)', 3),
        ('Legendary Resistance (6/Day)', 6),
      ]) {
        final data = {
          'traits': [
            {'name': name, 'desc': '...'},
          ],
        };
        expect(legendaryResistanceOf(data), expected, reason: name);
      }
    });

    test('inde artan hak YOK SAYILIR (ilk sayi alinir)', () {
      final data = {
        'traits': [
          {'name': 'Legendary Resistance (3/Day, or 4/Day in Lair)'},
        ],
      };
      expect(legendaryResistanceOf(data), 3);
    });

    test('trait yoksa null', () {
      expect(
        legendaryResistanceOf({
          'traits': [
            {'name': 'Amphibious'},
          ],
        }),
        isNull,
      );
      expect(legendaryResistanceOf(<String, dynamic>{}), isNull);
    });

    test('bozuk veri firlatmaz', () {
      expect(legendaryResistanceOf({'traits': 'metin'}), isNull);
      expect(
        legendaryResistanceOf({
          'traits': [42, null],
        }),
        isNull,
      );
    });
  });
}
