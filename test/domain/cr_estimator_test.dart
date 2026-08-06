import 'dart:convert';
import 'dart:io';

import 'package:dm_table/domain/rules/cr_estimator.dart';
import 'package:flutter_test/flutter_test.dart';

/// CR tahmini.
///
/// Olcutler SRD canavarlarindan turetildigi icin ayni canavarlar uzerinde
/// olcmek kismen dairesel; bu yuzden testler once yapisal ozelliklere bakiyor
/// (monotonluk, sinirlar), sonra gercek canavarlarda toplu isabet oranini
/// olcuyor. Amac kesin dogruluk degil, DM'e makul bir baslangic vermek.
void main() {
  late CrEstimator estimator;
  late List<Map<String, dynamic>> creatures;

  setUpAll(() {
    estimator = CrEstimator.fromJson(
      File('assets/rules/cr_benchmarks.json').readAsStringSync(),
    );
    creatures =
        (jsonDecode(
                  utf8.decode(
                    gzip.decode(
                      File('assets/data/creatures.json.gz').readAsBytesSync(),
                    ),
                  ),
                )
                as List)
            .cast<Map<String, dynamic>>();
  });

  test('olcutler yuklendi ve CR\'ye gore artiyor', () {
    expect(estimator.isEmpty, isFalse);
    expect(estimator.benchmarks.length, greaterThan(20));

    // Can ve hasar CR yukseldikce azalmamali.
    var previousHp = -1.0;
    for (final b in estimator.benchmarks) {
      expect(
        b.hitPoints,
        greaterThanOrEqualTo(previousHp),
        reason: 'CR ${b.challengeRating} canı düştü',
      );
      previousHp = b.hitPoints;
    }
  });

  test('zayif canavar dusuk CR verir', () {
    final estimate = estimator.estimate(
      hitPoints: 4,
      armorClass: 11,
      damagePerRound: 2,
      attackBonus: 2,
    );
    expect(estimate.result, lessThanOrEqualTo(0.25));
  });

  test('devasa canavar yuksek CR verir', () {
    final estimate = estimator.estimate(
      hitPoints: 400,
      armorClass: 20,
      damagePerRound: 120,
      attackBonus: 14,
    );
    expect(estimate.result, greaterThanOrEqualTo(15));
  });

  test('can arttikca tahmin dusmez', () {
    double crFor(int hp) => estimator
        .estimate(
          hitPoints: hp,
          armorClass: 14,
          damagePerRound: 20,
          attackBonus: 6,
        )
        .result;

    var previous = -1.0;
    for (final hp in [10, 30, 60, 100, 150, 220, 300]) {
      final cr = crFor(hp);
      expect(cr, greaterThanOrEqualTo(previous), reason: '$hp HP');
      previous = cr;
    }
  });

  test('zirh savunma CR\'sini yukseltir', () {
    CrEstimate withAc(int ac) => estimator.estimate(
      hitPoints: 60,
      armorClass: ac,
      damagePerRound: 15,
      attackBonus: 5,
    );

    expect(withAc(19).defensive, greaterThan(withAc(11).defensive));
  });

  test('hasar saldiri CR\'sini yukseltir', () {
    CrEstimate withDamage(double dpr) => estimator.estimate(
      hitPoints: 60,
      armorClass: 14,
      damagePerRound: dpr,
      attackBonus: 6,
    );

    expect(withDamage(60).offensive, greaterThan(withDamage(8).offensive));
  });

  test('sonuc iki bilesenin arasinda kalir', () {
    final estimate = estimator.estimate(
      hitPoints: 250, // savunmasi cok yuksek
      armorClass: 18,
      damagePerRound: 5, // saldirisi cok dusuk
      attackBonus: 3,
    );

    final low = estimate.offensive;
    final high = estimate.defensive;
    expect(estimate.result, greaterThanOrEqualTo(low));
    expect(estimate.result, lessThanOrEqualTo(high));
  });

  test('gercek canavarlarin cogunda makul yakinlikta', () {
    // Yalnizca yapisal saldiri verisi olan canavarlar olculuyor.
    var measured = 0;
    var close = 0;

    for (final creature in creatures) {
      final actual = (creature['challenge_rating'] as num?)?.toDouble();
      final hp = creature['hit_points'] as int?;
      final ac = creature['armor_class'] as int?;
      if (actual == null || hp == null || ac == null) continue;

      final offense = _offenseOf(creature);
      if (offense.damagePerRound <= 0) continue;

      measured++;
      final estimate = estimator.estimate(
        hitPoints: hp,
        armorClass: ac,
        damagePerRound: offense.damagePerRound,
        attackBonus: offense.attackBonus,
      );

      // "Yakin" = gercek CR'nin iki kati ile yarisi arasinda; CR olcegi
      // ustel oldugu icin mutlak fark anlamli degil.
      final upper = actual <= 1 ? actual + 1 : actual * 2;
      final lower = actual <= 1 ? 0.0 : actual / 2;
      if (estimate.result >= lower && estimate.result <= upper) close++;
    }

    expect(measured, greaterThan(200), reason: 'yeterli örnek yok');
    final ratio = close / measured;
    expect(
      ratio,
      greaterThan(0.75),
      reason: 'yalnızca ${(ratio * 100).round()}% makul aralıkta',
    );
  });
}

/// Test icin canavarin hasarini cikarir; `tools/build_cr_benchmarks.dart`
/// icindeki mantigin aynisi.
({double damagePerRound, int attackBonus}) _offenseOf(
  Map<String, dynamic> creature,
) {
  const numberWords = {'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5};

  var bestDamage = 0.0;
  var bestToHit = 0;
  var multiattack = 1;

  for (final action
      in (creature['actions'] as List? ?? const [])
          .cast<Map<String, dynamic>>()) {
    if ('${action['name']}'.toLowerCase() == 'multiattack') {
      final word = RegExp(
        r'makes (\w+)',
        caseSensitive: false,
      ).firstMatch('${action['desc']}')?.group(1)?.toLowerCase();
      multiattack = numberWords[word] ?? int.tryParse(word ?? '') ?? 1;
      continue;
    }
    for (final attack
        in (action['attacks'] as List? ?? const [])
            .cast<Map<String, dynamic>>()) {
      final damage =
          _avg(
            attack['damage_die_count'],
            attack['damage_die_type'],
            attack['damage_bonus'],
          ) +
          _avg(
            attack['extra_damage_die_count'],
            attack['extra_damage_die_type'],
            attack['extra_damage_bonus'],
          );
      if (damage > bestDamage) {
        bestDamage = damage;
        bestToHit = attack['to_hit_mod'] as int? ?? 0;
      }
    }
  }
  return (damagePerRound: bestDamage * multiattack, attackBonus: bestToHit);
}

double _avg(Object? count, Object? type, Object? bonus) {
  final dice = count is int ? count : 0;
  final sides = int.tryParse('${type ?? ''}'.replaceAll(RegExp('[^0-9]'), ''));
  final flat = bonus is int ? bonus : 0;
  if (dice == 0 || sides == null || sides == 0) return flat.toDouble();
  return dice * (sides + 1) / 2 + flat;
}
