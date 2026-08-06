import 'dart:convert';

import 'challenge_rating.dart';

/// Bir CR basamagi icin tipik degerler.
class CrBenchmark {
  const CrBenchmark({
    required this.challengeRating,
    required this.hitPoints,
    required this.armorClass,
    required this.damagePerRound,
    required this.attackBonus,
    this.sampleCount = 0,
  });

  final double challengeRating;
  final double hitPoints;
  final double armorClass;
  final double damagePerRound;
  final double attackBonus;
  final int sampleCount;

  static CrBenchmark fromJson(Map<String, dynamic> json) => CrBenchmark(
    challengeRating: (json['cr'] as num).toDouble(),
    hitPoints: (json['hitPoints'] as num).toDouble(),
    armorClass: (json['armorClass'] as num).toDouble(),
    damagePerRound: (json['damagePerRound'] as num).toDouble(),
    attackBonus: (json['attackBonus'] as num).toDouble(),
    sampleCount: json['sampleCount'] as int? ?? 0,
  );
}

/// Tahmin sonucu; DM neyin nasil hesaplandigini gorebilsin diye ara
/// degerler de doner.
class CrEstimate {
  const CrEstimate({
    required this.defensive,
    required this.offensive,
    required this.result,
  });

  /// Cana ve zirha bakarak bulunan CR.
  final double defensive;

  /// Hasara ve isabete bakarak bulunan CR.
  final double offensive;

  /// Ikisinin ortalamasina en yakin gecerli CR basamagi.
  final double result;

  String get label => formatCr(result);
}

/// Homebrew canavarlar icin CR tahmini.
///
/// Olcutler DMG'nin tablosundan degil, SRD 5.2'deki 331 canavarin gercek
/// istatistiklerinden turetiliyor (`tools/build_cr_benchmarks.dart`). Bu hem
/// lisans acisindan temiz hem de 2024 canavar tasarimina birebir uyuyor.
///
/// Tahmin kesin bir kural degil, bir baslangic noktasi: masada canavarin
/// gercek zorlugu ozel yeteneklerine ve karsilasma duzenine gore degisir.
class CrEstimator {
  const CrEstimator(this.benchmarks);

  final List<CrBenchmark> benchmarks;

  static CrEstimator fromJson(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    return CrEstimator([
      for (final b in (json['benchmarks'] as List))
        CrBenchmark.fromJson((b as Map).cast<String, dynamic>()),
    ]);
  }

  bool get isEmpty => benchmarks.isEmpty;

  CrEstimate estimate({
    required int hitPoints,
    required int armorClass,
    required double damagePerRound,
    required int attackBonus,
  }) {
    final defensive = _adjust(
      base: _closestBy(hitPoints.toDouble(), (b) => b.hitPoints),
      actual: armorClass.toDouble(),
      expected: (b) => b.armorClass,
      // Beklenenden 2 puan sapma bir CR basamagi kaydiriyor; SRD verisinde
      // AC araligi dar oldugu icin daha hassas bir esik gurultu uretirdi.
      pointsPerStep: 2,
    );

    final offensive = _adjust(
      base: _closestBy(damagePerRound, (b) => b.damagePerRound),
      actual: attackBonus.toDouble(),
      expected: (b) => b.attackBonus,
      pointsPerStep: 2,
    );

    final average = (_indexOf(defensive) + _indexOf(offensive)) / 2;
    final result = benchmarks[average.round().clamp(0, benchmarks.length - 1)]
        .challengeRating;

    return CrEstimate(
      defensive: defensive,
      offensive: offensive,
      result: result,
    );
  }

  /// Verilen degere en yakin olcutun CR'si.
  double _closestBy(double value, double Function(CrBenchmark) selector) {
    if (benchmarks.isEmpty) return 0;
    var best = benchmarks.first;
    var bestDistance = (selector(best) - value).abs();
    for (final b in benchmarks.skip(1)) {
      // Olcutu olmayan basamaklar (or. hasarsiz CR) atlanir.
      if (selector(b) <= 0) continue;
      final distance = (selector(b) - value).abs();
      if (distance < bestDistance) {
        best = b;
        bestDistance = distance;
      }
    }
    return best.challengeRating;
  }

  /// Ikincil olcut beklenenden saparsa CR'yi basamak basamak kaydirir.
  double _adjust({
    required double base,
    required double actual,
    required double Function(CrBenchmark) expected,
    required double pointsPerStep,
  }) {
    final index = _indexOf(base);
    final benchmark = benchmarks[index];
    final delta = actual - expected(benchmark);
    final steps = (delta / pointsPerStep).round();
    final next = (index + steps).clamp(0, benchmarks.length - 1);
    return benchmarks[next].challengeRating;
  }

  int _indexOf(double challengeRating) {
    final index = benchmarks.indexWhere(
      (b) => b.challengeRating == challengeRating,
    );
    return index < 0 ? 0 : index;
  }
}
