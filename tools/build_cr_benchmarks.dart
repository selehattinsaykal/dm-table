// SRD 5.2 canavarlarindan CR kiyas olcutleri turetir.
//
//   dart run tools/build_cr_benchmarks.dart
//
// Neden turetiliyor: CR hesaplama tablosu Dungeon Master's Guide'da, SRD'de
// degil. O tabloyu kopyalamak yerine, zaten CC-BY lisansiyla elimizde olan
// 331 canavarin gercek istatistiklerinden her CR icin tipik degerleri
// cikariyoruz. Sonuc hem yasal olarak temiz hem de 2024 canavar tasarimina
// birebir uyuyor.
//
// Cikti: assets/rules/cr_benchmarks.json

import 'dart:convert';
import 'dart:io';

void main() {
  final creatures =
      (jsonDecode(
                utf8.decode(
                  gzip.decode(
                    File('assets/data/creatures.json.gz').readAsBytesSync(),
                  ),
                ),
              )
              as List)
          .cast<Map<String, dynamic>>();

  final byCr = <double, List<_Sample>>{};
  for (final creature in creatures) {
    final cr = (creature['challenge_rating'] as num?)?.toDouble();
    final hp = creature['hit_points'] as int?;
    final ac = creature['armor_class'] as int?;
    if (cr == null || hp == null || ac == null) continue;

    final offense = _offenseOf(creature);
    (byCr[cr] ??= []).add(
      _Sample(
        hitPoints: hp,
        armorClass: ac,
        damagePerRound: offense.damagePerRound,
        attackBonus: offense.attackBonus,
      ),
    );
  }

  final benchmarks = <Map<String, dynamic>>[];
  for (final cr in byCr.keys.toList()..sort()) {
    final samples = byCr[cr]!;
    final withOffense = samples.where((s) => s.damagePerRound > 0).toList();

    benchmarks.add({
      'cr': cr,
      'sampleCount': samples.length,
      'hitPoints': _median(samples.map((s) => s.hitPoints.toDouble())),
      'armorClass': _median(samples.map((s) => s.armorClass.toDouble())),
      'damagePerRound': withOffense.isEmpty
          ? 0.0
          : _median(withOffense.map((s) => s.damagePerRound)),
      'attackBonus': withOffense.isEmpty
          ? 0.0
          : _median(withOffense.map((s) => s.attackBonus.toDouble())),
    });
  }

  _enforceMonotonic(benchmarks);

  final output = File('assets/rules/cr_benchmarks.json');
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'generatedFrom': 'srd-2024 creatures (CC-BY 4.0)',
      'creatureCount': creatures.length,
      'benchmarks': benchmarks,
    }),
  );

  stdout.writeln('${benchmarks.length} CR basamagi yazildi -> ${output.path}');
  for (final b in benchmarks.take(8)) {
    stdout.writeln(
      '  CR ${b['cr']}: HP ${b['hitPoints']}, AC ${b['armorClass']}, '
      'DPR ${b['damagePerRound']}, saldiri +${b['attackBonus']} '
      '(${b['sampleCount']} ornek)',
    );
  }
}

/// Olcutleri azalmayan hale getirir.
///
/// Bazi CR basamaklarinda yalnizca birkac canavar var; ornek azligi
/// medyanlari yer yer tersine cevirebiliyor (or. CR 12 medyani CR 11'inkinin
/// altina dusuyor). Tahmin motoru "en yakin can" diye arama yaptigi icin bu
/// tersinme daha canli bir canavara daha dusuk CR verdirirdi. CR tanimi
/// geregi artan oldugundan yurur-azami uygulaniyor.
void _enforceMonotonic(List<Map<String, dynamic>> benchmarks) {
  for (final field in [
    'hitPoints',
    'armorClass',
    'damagePerRound',
    'attackBonus',
  ]) {
    var running = 0.0;
    for (final b in benchmarks) {
      final value = (b[field] as num).toDouble();
      if (value < running) {
        b[field] = running;
      } else {
        running = value;
      }
    }
  }
}

class _Sample {
  const _Sample({
    required this.hitPoints,
    required this.armorClass,
    required this.damagePerRound,
    required this.attackBonus,
  });

  final int hitPoints;
  final int armorClass;
  final double damagePerRound;
  final int attackBonus;
}

/// Bir canavarin tur basina hasarini ve saldiri bonusunu tahmin eder.
///
/// En yuksek hasarli tekil saldiri secilir ve Multiattack metnindeki
/// "makes two Rend attacks" gibi ifadeden cikan katsayiyla carpilir. Nefes
/// silahi/buyu gibi tekil yetenekler goz ardi ediliyor: amac kesin bir DPR
/// degil, CR basamaklari arasinda tutarli bir olcut.
({double damagePerRound, int attackBonus}) _offenseOf(
  Map<String, dynamic> creature,
) {
  final actions = (creature['actions'] as List? ?? const [])
      .cast<Map<String, dynamic>>();

  var bestDamage = 0.0;
  var bestToHit = 0;
  var multiattack = 1;

  for (final action in actions) {
    if ('${action['name']}'.toLowerCase() == 'multiattack') {
      multiattack = _countIn('${action['desc']}');
      continue;
    }
    for (final attack
        in (action['attacks'] as List? ?? const [])
            .cast<Map<String, dynamic>>()) {
      final damage =
          _averageDice(
            attack['damage_die_count'],
            attack['damage_die_type'],
            attack['damage_bonus'],
          ) +
          _averageDice(
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

double _averageDice(Object? count, Object? type, Object? bonus) {
  final dice = count is int ? count : 0;
  final sides = int.tryParse('${type ?? ''}'.replaceAll(RegExp('[^0-9]'), ''));
  final flat = bonus is int ? bonus : 0;
  if (dice == 0 || sides == null || sides == 0) return flat.toDouble();
  return dice * (sides + 1) / 2 + flat;
}

/// "The owlbear makes two Rend attacks." -> 2
const _numberWords = <String, int>{
  'one': 1,
  'two': 2,
  'three': 3,
  'four': 4,
  'five': 5,
  'six': 6,
};

int _countIn(String description) {
  final match = RegExp(
    r'makes (\w+)',
    caseSensitive: false,
  ).firstMatch(description);
  final word = match?.group(1)?.toLowerCase();
  return _numberWords[word] ?? int.tryParse(word ?? '') ?? 1;
}

double _median(Iterable<double> values) {
  final sorted = values.toList()..sort();
  if (sorted.isEmpty) return 0;
  final middle = sorted.length ~/ 2;
  final value = sorted.length.isOdd
      ? sorted[middle]
      : (sorted[middle - 1] + sorted[middle]) / 2;
  return double.parse(value.toStringAsFixed(1));
}
