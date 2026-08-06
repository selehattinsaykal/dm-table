import 'package:dm_table/domain/rules/dice.dart';
import 'package:flutter_test/flutter_test.dart';

/// "2d6+3" gibi zar ifadelerinin cozumlenmesi (Kayitlar zar bloklari icin).
void main() {
  test('gecerli ifadeler', () {
    expect(parseDiceExpression('2d6+3'), (count: 2, sides: 6, modifier: 3));
    expect(parseDiceExpression('1d20'), (count: 1, sides: 20, modifier: 0));
    expect(parseDiceExpression('d8'), (count: 1, sides: 8, modifier: 0));
    expect(parseDiceExpression('3d4 - 1'), (count: 3, sides: 4, modifier: -1));
    expect(parseDiceExpression(' 20d10 + 40 '), (
      count: 20,
      sides: 10,
      modifier: 40,
    ));
    expect(parseDiceExpression('1D12'), (count: 1, sides: 12, modifier: 0));
  });

  test('gecersiz ifadeler null', () {
    expect(parseDiceExpression(''), isNull);
    expect(parseDiceExpression('merhaba'), isNull);
    expect(parseDiceExpression('d'), isNull);
    expect(parseDiceExpression('2x6'), isNull);
    expect(parseDiceExpression('0d6'), isNull); // sayac < 1
    expect(parseDiceExpression('2d6+'), isNull);
  });
}
