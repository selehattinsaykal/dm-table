import 'package:dm_table/domain/rules/experience.dart';
import 'package:flutter_test/flutter_test.dart';

/// XP -> seviye (SRD Character Advancement tablosu) yardimcilari.
void main() {
  group('levelForXp', () {
    test('esik altinda seviye artmaz', () {
      expect(Experience.levelForXp(0), 1);
      expect(Experience.levelForXp(299), 1);
      expect(Experience.levelForXp(300), 2);
      expect(Experience.levelForXp(899), 2);
      expect(Experience.levelForXp(900), 3);
      expect(Experience.levelForXp(6500), 5);
    });

    test('20. seviyede tavan', () {
      expect(Experience.levelForXp(355000), 20);
      expect(Experience.levelForXp(999999), 20);
    });
  });

  test('xpForLevel esikleri dondurur', () {
    expect(Experience.xpForLevel(1), 0);
    expect(Experience.xpForLevel(2), 300);
    expect(Experience.xpForLevel(5), 6500);
    expect(Experience.xpForLevel(20), 355000);
  });

  group('xpToNext', () {
    test('sonraki seviye ve kalan XP', () {
      expect(Experience.xpToNext(0), (nextLevel: 2, xpNeeded: 300));
      expect(Experience.xpToNext(300), (nextLevel: 3, xpNeeded: 600));
      expect(Experience.xpToNext(100), (nextLevel: 2, xpNeeded: 200));
    });

    test('20. seviyede null', () {
      expect(Experience.xpToNext(355000), isNull);
    });
  });

  group('progress', () {
    test('seviye icinde oran', () {
      expect(Experience.progress(0), 0);
      expect(Experience.progress(150), closeTo(0.5, 0.001)); // 150/300
      expect(Experience.progress(300), 0); // yeni seviyenin basi
    });

    test('20. seviyede 1.0', () {
      expect(Experience.progress(400000), 1);
    });
  });
}
