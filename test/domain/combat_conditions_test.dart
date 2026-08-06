import 'package:dm_table/domain/rules/combat_conditions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseConditions', () {
    test('eski duz-string bicimini okur (surum uyumu)', () {
      final result = parseConditions('["Prone","Poisoned"]');
      expect(result, [
        const CombatCondition('Prone'),
        const CombatCondition('Poisoned'),
      ]);
      expect(result.every((c) => c.rounds == null), isTrue);
    });

    test('yeni nesne bicimini sureleriyle okur', () {
      final result = parseConditions(
        '[{"name":"Prone"},{"name":"Stunned","rounds":2}]',
      );
      expect(result[0], const CombatCondition('Prone'));
      expect(result[1], const CombatCondition('Stunned', rounds: 2));
    });

    test('karma/bozuk girdiyi guvenle atlar', () {
      expect(parseConditions('"notalist"'), isEmpty);
      expect(parseConditions('[123,{"rounds":2}]'), isEmpty);
    });
  });

  test('encode sonra parse round-trip', () {
    const conditions = [
      CombatCondition('Prone'),
      CombatCondition('Restrained', rounds: 3),
    ];
    expect(parseConditions(encodeConditions(conditions)), conditions);
  });

  group('tickConditions', () {
    test('sureli durumlar bir azalir; suresizler dokunulmaz', () {
      final result = tickConditions(const [
        CombatCondition('Prone'),
        CombatCondition('Stunned', rounds: 3),
      ]);
      expect(result.next, [
        const CombatCondition('Prone'),
        const CombatCondition('Stunned', rounds: 2),
      ]);
      expect(result.expired, isEmpty);
    });

    test('suresi 1 olan durum biter ve expired doner', () {
      final result = tickConditions(const [
        CombatCondition('Poisoned', rounds: 1),
        CombatCondition('Blinded', rounds: 2),
      ]);
      expect(result.expired, ['Poisoned']);
      expect(result.next, [const CombatCondition('Blinded', rounds: 1)]);
    });
  });
}
