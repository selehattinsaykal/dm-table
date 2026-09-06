import 'dart:math';

import 'package:dm_table/domain/rules/dice.dart';
import 'package:flutter_test/flutter_test.dart';

/// Zar motoru: sinirlar, modifier, avantaj/dezavantaj ve JSON tur atlama.
void main() {
  test('d20 sonucu 1..20 arasinda ve modifier eklenir', () {
    final roller = DiceRoller(Random(42));
    for (var i = 0; i < 200; i++) {
      final r = roller.d20(modifier: 3, label: 'Test');
      expect(r.results.single, inInclusiveRange(1, 20));
      expect(r.total, r.results.single + 3);
      expect(r.sides, 20);
    }
  });

  test('çoklu zar toplanır', () {
    final roller = DiceRoller(Random(1));
    for (var i = 0; i < 100; i++) {
      final r = roller.roll(sides: 6, count: 3, modifier: 2, label: 'Sneak');
      expect(r.results.length, 3);
      expect(r.results.every((d) => d >= 1 && d <= 6), isTrue);
      expect(r.total, r.results.fold(2, (a, b) => a + b));
    }
  });

  test('avantajda yüksek zar sayılır', () {
    // Iki zar atiliyor; sayilan zar digerinden kucuk olmamali.
    final roller = DiceRoller(Random(7));
    for (var i = 0; i < 200; i++) {
      final r = roller.d20(advantage: Advantage.advantage);
      expect(r.results.length, 2);
      final kept = r.results[r.keptIndex!];
      expect(kept, greaterThanOrEqualTo(r.results.reduce(min)));
      expect(kept, r.results.reduce(max));
      expect(r.total, kept);
    }
  });

  test('dezavantajda düşük zar sayılır', () {
    final roller = DiceRoller(Random(9));
    for (var i = 0; i < 200; i++) {
      final r = roller.d20(advantage: Advantage.disadvantage, modifier: 1);
      final kept = r.results[r.keptIndex!];
      expect(kept, r.results.reduce(min));
      expect(r.total, kept + 1);
    }
  });

  test('detay metni okunur biçimde', () {
    final roller = DiceRoller(Random(3));
    final r = roller.d20(modifier: 5, label: 'Perception');
    expect(r.detail, contains('d20'));
    expect(r.detail, contains('+ 5'));
    expect(r.label, 'Perception');
  });

  test('negatif modifier eksi olarak gösterilir', () {
    final r = DiceRoller(Random(3)).d20(modifier: -2);
    expect(r.detail, contains('- 2'));
    expect(r.total, r.results[r.keptIndex!] - 2);
  });

  test('avantajda sayilan zar toplama girer', () {
    final r = DiceRoller(Random(5)).d20(
      modifier: 4,
      label: 'Stealth',
      source: 'Selim',
      advantage: Advantage.advantage,
    );
    expect(r.results, hasLength(2));
    expect(r.keptIndex, isNotNull);
    expect(r.total, r.results[r.keptIndex!] + 4);
    expect(r.source, 'Selim');
    // Sayilan zar detayda koseli parantezle isaretlenir.
    expect(r.detail, contains('['));
  });
}
