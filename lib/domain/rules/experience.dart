/// Karakter ilerlemesi: XP -> seviye (SRD 5.2, Character Advancement tablosu).
///
/// Seviye atlama uygulamada elle yapiliyor; bu tablo yalnizca "kac XP'de
/// sonraki seviye" gostergesi ve karsilasmadan verilen XP'nin izlenmesi icin.
class Experience {
  /// Seviye -> o seviyeye ulasmak icin gereken toplam XP (indeks 0 = sv1).
  static const thresholds = <int>[
    0, // 1
    300, // 2
    900, // 3
    2700, // 4
    6500, // 5
    14000, // 6
    23000, // 7
    34000, // 8
    48000, // 9
    64000, // 10
    85000, // 11
    100000, // 12
    120000, // 13
    140000, // 14
    165000, // 15
    195000, // 16
    225000, // 17
    265000, // 18
    305000, // 19
    355000, // 20
  ];

  /// Verilen toplam XP'nin karsilik geldigi seviye (1-20).
  static int levelForXp(int xp) {
    var level = 1;
    for (var i = 1; i < thresholds.length; i++) {
      if (xp >= thresholds[i]) {
        level = i + 1;
      } else {
        break;
      }
    }
    return level;
  }

  /// Bu seviyenin baslangic XP esigi.
  static int xpForLevel(int level) => thresholds[level.clamp(1, 20) - 1];

  /// Sonraki seviye ve ona kalan XP. 20. seviyede sonraki yoktur (null).
  static ({int nextLevel, int xpNeeded})? xpToNext(int xp) {
    final level = levelForXp(xp);
    if (level >= 20) return null;
    return (nextLevel: level + 1, xpNeeded: thresholds[level] - xp);
  }

  /// Mevcut seviye icindeki ilerleme oranı (0..1). 20. seviyede 1.0.
  static double progress(int xp) {
    final level = levelForXp(xp);
    if (level >= 20) return 1;
    final start = thresholds[level - 1];
    final end = thresholds[level];
    if (end <= start) return 0;
    return ((xp - start) / (end - start)).clamp(0, 1).toDouble();
  }
}
