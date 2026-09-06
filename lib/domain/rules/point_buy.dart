/// Yetenek puani uretme yontemleri ve puan dagitimi (point buy) matematigi.
///
/// Saf Dart: `dart:io`/Flutter bilmez. Sihirbaz taslagindan
/// (`character_draft.dart`) ayri duruyor ki kural matematigi arayuzsuz test
/// edilebilsin.
library;

import '../models/ability.dart';

/// Yetenek puanlarinin nasil belirlendigi.
enum AbilityMethod {
  pointBuy('Puan dağıtımı'),
  standardArray('Standart dizi'),
  manual('Elle gir');

  const AbilityMethod(this.label);

  final String label;
}

abstract final class PointBuy {
  static const budget = 27;
  static const min = 8;
  static const max = 15;

  /// Puan -> toplam maliyet.
  static const costs = <int, int>{
    8: 0,
    9: 1,
    10: 2,
    11: 3,
    12: 4,
    13: 5,
    14: 7,
    15: 9,
  };

  static int costOf(AbilityScores scores) =>
      Ability.values.fold(0, (sum, a) => sum + (costs[scores[a]] ?? 0));

  static int remaining(AbilityScores scores) => budget - costOf(scores);

  /// Bir puani bir artirmanin maliyeti; artirilamiyorsa null.
  static int? costToRaise(int current) {
    if (current >= max) return null;
    return (costs[current + 1] ?? 0) - (costs[current] ?? 0);
  }
}
