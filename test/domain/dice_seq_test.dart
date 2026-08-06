import 'package:dm_table/domain/rules/dice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('seq toJson/fromJson round-trip; yokken null', () {
    final roll = DiceRoll(
      label: 'Gizlilik',
      sides: 20,
      count: 1,
      modifier: 3,
      results: const [14],
      total: 17,
      source: 'Selim',
    );

    // seq yok -> JSON'a yazilmaz, fromJson null okur.
    expect(roll.seq, isNull);
    expect(roll.toJson().containsKey('seq'), isFalse);
    expect(DiceRoll.fromJson(roll.toJson()).seq, isNull);

    // withSeq ile ataninca korunur.
    final seeded = roll.withSeq(42);
    expect(seeded.seq, 42);
    expect(DiceRoll.fromJson(seeded.toJson()).seq, 42);
    // Diger alanlar bozulmaz.
    final back = DiceRoll.fromJson(seeded.toJson());
    expect(back.total, 17);
    expect(back.source, 'Selim');
    expect(back.results, [14]);
  });
}
