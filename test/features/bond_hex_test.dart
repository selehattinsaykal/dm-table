import 'package:dm_table/features/world/bond_types_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bag turu renk cemberindeki hex <-> Color donusumleri (saf fonksiyonlar).
void main() {
  test('colorToHex 6 haneli buyuk harf uretir', () {
    expect(colorToHex(const Color(0xFF7C2B2B)), '7C2B2B');
    expect(colorToHex(const Color(0xFF000000)), '000000');
    expect(colorToHex(const Color(0xFFFFFFFF)), 'FFFFFF');
  });

  test('hexToColor RRGGBB, kisa RGB ve # onekini kabul eder', () {
    expect(hexToColor('7C2B2B'), const Color(0xFF7C2B2B));
    expect(hexToColor('#7C2B2B'), const Color(0xFF7C2B2B));
    expect(hexToColor('abc'), const Color(0xFFAABBCC));
    expect(hexToColor('#fff'), const Color(0xFFFFFFFF));
  });

  test('hexToColor gecersiz girislerde null doner', () {
    expect(hexToColor(''), isNull);
    expect(hexToColor('12345'), isNull);
    expect(hexToColor('GGGGGG'), isNull);
    expect(hexToColor('1234567'), isNull);
  });

  test('round-trip: colorToHex(hexToColor(x)) == x (normalize edilmis)', () {
    for (final hex in ['112233', 'ABCDEF', '000000', 'FFFFFF']) {
      final c = hexToColor(hex)!;
      expect(colorToHex(c), hex);
    }
  });
}
