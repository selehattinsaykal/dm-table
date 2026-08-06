/// D&D 2024 karsilasma XP butcesi (SRD 5.2, CC BY 4.0 — uygulamanin icerik
/// kaynagiyla ayni lisans).
///
/// Sistem tek carpmadan ibaret: her karakter icin seviyesine ve secilen
/// zorluga (Dusuk/Orta/Yuksek) gore bir XP butcesi vardir; parti butcesi
/// uyelerin butcelerinin toplamidir. Karsilasmadaki canavarlarin toplam
/// XP'si bu esiklere gore siniflanir. (2014'teki carpan/esik sistemi degil.)
enum EncounterDifficulty { trivial, low, moderate, high, deadly }

/// Bir karsilasmanin degerlendirmesi: toplam canavar XP'si, parti seviyeleri
/// ve XP'si bilinmeyen (or. serbest/adhoc) katilimci sayisi.
class EncounterAssessment {
  const EncounterAssessment({
    required this.monsterXp,
    required this.partyLevels,
    this.uncounted = 0,
  });

  final int monsterXp;
  final List<int> partyLevels;
  final int uncounted;

  bool get hasParty => partyLevels.isNotEmpty;

  /// Partinin (Dusuk, Orta, Yuksek) toplam XP butcesi.
  (int low, int moderate, int high) get budget =>
      EncounterBudget.partyBudget(partyLevels);

  EncounterDifficulty get difficulty =>
      EncounterBudget.classify(monsterXp, partyLevels);
}

class EncounterBudget {
  /// Karakter basina XP butcesi: seviye -> (Dusuk, Orta, Yuksek).
  static const _perCharacter = <int, (int, int, int)>{
    1: (50, 75, 100),
    2: (100, 150, 200),
    3: (150, 225, 400),
    4: (250, 375, 500),
    5: (500, 750, 1100),
    6: (600, 1000, 1400),
    7: (750, 1300, 1700),
    8: (1000, 1700, 2100),
    9: (1300, 2000, 2600),
    10: (1600, 2300, 3100),
    11: (1900, 2900, 4100),
    12: (2200, 3700, 4700),
    13: (2600, 4200, 5400),
    14: (2900, 4900, 6200),
    15: (3300, 5400, 7800),
    16: (3800, 6100, 9800),
    17: (4500, 7200, 11700),
    18: (5000, 8700, 14200),
    19: (5500, 10700, 17200),
    20: (6400, 13200, 22000),
  };

  /// Parti butcesi = her uyenin (seviyesine gore) butcesinin toplami.
  static (int low, int moderate, int high) partyBudget(List<int> levels) {
    var low = 0, moderate = 0, high = 0;
    for (final level in levels) {
      final t = _perCharacter[level.clamp(1, 20)]!;
      low += t.$1;
      moderate += t.$2;
      high += t.$3;
    }
    return (low, moderate, high);
  }

  /// Toplam canavar XP'sini parti butcesine gore siniflar.
  static EncounterDifficulty classify(int monsterXp, List<int> levels) {
    if (levels.isEmpty) return EncounterDifficulty.trivial;
    final (low, moderate, high) = partyBudget(levels);
    if (monsterXp < low) return EncounterDifficulty.trivial;
    if (monsterXp < moderate) return EncounterDifficulty.low;
    if (monsterXp < high) return EncounterDifficulty.moderate;
    if (monsterXp < deadlyBudget(high)) return EncounterDifficulty.high;
    return EncounterDifficulty.deadly;
  }

  /// 2024 SRD'de resmi bir "olumcul" esigi yok; "Yuksek" esiginin 1.5 kati
  /// kaba bir kural-of-thumb olarak kullanilir (2014 DMG'deki oranla tutarli).
  static int deadlyBudget(int high) => (high * 1.5).round();
}
