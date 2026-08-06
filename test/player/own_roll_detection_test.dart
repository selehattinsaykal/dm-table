import 'package:dm_table/domain/rules/dice.dart';
import 'package:dm_table/player/player_app.dart';
import 'package:flutter_test/flutter_test.dart';

DiceRoll _roll(String? source, int seq, {int total = 10}) => DiceRoll(
  label: 'd20',
  sides: 20,
  count: 1,
  modifier: 0,
  results: [total],
  total: total,
  source: source,
).withSeq(seq);

void main() {
  const me = 'Selim';

  test('kendi yeni atisim doner', () {
    final rolls = [_roll('Ayşe', 5), _roll(me, 6)];
    final own = newestOwnRoll(rolls, me, 4);
    expect(own?.seq, 6);
  });

  test('baskasinin atisi pop yapmaz', () {
    final rolls = [_roll('Ayşe', 7)];
    expect(newestOwnRoll(rolls, me, 4), isNull);
  });

  test('gecmis atis (baseline altinda) pop yapmaz', () {
    final rolls = [_roll(me, 3)];
    // lastSeq=5: 3 <= 5 -> yok say.
    expect(newestOwnRoll(rolls, me, 5), isNull);
  });

  test('birden fazla kendi atisimda en yenisi (en yuksek seq) doner', () {
    final rolls = [_roll(me, 6), _roll(me, 9), _roll(me, 8)];
    expect(newestOwnRoll(rolls, me, 5)?.seq, 9);
  });

  test('seq olmayan atis (anlik hesap) pop yapmaz', () {
    final rolls = [
      DiceRoll(
        label: 'd20',
        sides: 20,
        count: 1,
        modifier: 0,
        results: const [10],
        total: 10,
        source: me,
      ),
    ];
    expect(newestOwnRoll(rolls, me, 0), isNull);
  });
}
