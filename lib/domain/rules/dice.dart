import 'dart:math';

/// Bir zar atisinin sonucu.
///
/// Tek tek zar sonuclari saklanir ki masada "d20: 17, +5 = 22" gibi seffaf
/// gosterilebilsin; toplamı gizli bir kutudan cikan sayi gibi degil.
class DiceRoll {
  const DiceRoll({
    required this.label,
    required this.sides,
    required this.count,
    required this.modifier,
    required this.results,
    required this.total,
    this.source,
    this.advantage = Advantage.none,
    this.keptIndex,
  });

  /// "Gizlilik", "Perception", "Longsword" gibi ne icin atildigini soyleyen ad.
  final String label;
  final int sides;
  final int count;
  final int modifier;

  /// Atilan her zarin sonucu.
  final List<int> results;

  /// Sonuclarin toplami + modifier (avantaj/dezavantajda secilen zar).
  final int total;

  /// Atisin kimin adina yapildigi ("Kaan", "Kizil Ejder"); serbest atislarda
  /// null. Zar gunlugunde satirin basinda gorunur.
  final String? source;

  final Advantage advantage;

  /// Avantaj/dezavantajda [results] icinde hangi zarin sayildigi.
  final int? keptIndex;

  /// "d20: 17 + 5" gibi okunur ozet.
  String get detail {
    final dice = 'd$sides';
    final rolls = advantage == Advantage.none
        ? results.join(', ')
        // Sayilan zari parantez yerine dogrudan yaziyoruz; markdown '**'
        // yildizlari duz metinde oldugu gibi gorunuyordu (kotu duran kisim).
        : [
            for (final (i, r) in results.indexed)
              i == keptIndex ? '[$r]' : r.toString(),
          ].join(' / ');
    final mod = modifier == 0
        ? ''
        : (modifier > 0 ? ' + $modifier' : ' - ${-modifier}');
    return count > 1 || advantage != Advantage.none
        ? '$count$dice ($rolls)$mod'
        : '$dice ($rolls)$mod';
  }
}

/// d20 atislarinda avantaj/dezavantaj.
enum Advantage { none, advantage, disadvantage }

/// "2d6+3", "1d20 - 1", "d8", "3d4" gibi bir ifadeyi cozer. Tanimazsa null.
/// Sayaci verilmezse 1, modifiye verilmezse 0.
({int count, int sides, int modifier})? parseDiceExpression(String expression) {
  final match = RegExp(
    r'^\s*(\d*)\s*d\s*(\d+)\s*([+-]\s*\d+)?\s*$',
    caseSensitive: false,
  ).firstMatch(expression);
  if (match == null) return null;
  final count = match.group(1)!.isEmpty ? 1 : int.parse(match.group(1)!);
  final sides = int.parse(match.group(2)!);
  final modText = match.group(3)?.replaceAll(RegExp(r'\s'), '');
  final modifier = modText == null ? 0 : int.parse(modText);
  if (count < 1 || count > 100 || sides < 1) return null;
  return (count: count, sides: sides, modifier: modifier);
}

/// Zar atar. [random] test icin disaridan verilebilir (deterministik).
class DiceRoller {
  DiceRoller([Random? random]) : _random = random ?? Random();

  final Random _random;

  int _rollOne(int sides) => _random.nextInt(sides) + 1;

  /// Tek bir [sides]-yuzlu zar atar (1..sides). Hasar bilesenlerini tek tek
  /// atmak icin disari acik.
  int rollOne(int sides) => _rollOne(sides);

  /// Genel atis: [count]d[sides] + [modifier].
  DiceRoll roll({
    required int sides,
    int count = 1,
    int modifier = 0,
    String label = '',
    String? source,
  }) {
    final results = [for (var i = 0; i < count; i++) _rollOne(sides)];
    final total = results.fold(0, (a, b) => a + b) + modifier;
    return DiceRoll(
      label: label,
      sides: sides,
      count: count,
      modifier: modifier,
      results: results,
      total: total,
      source: source,
    );
  }

  /// d20 testi (beceri, kurtarma, saldiri): avantaj/dezavantaj destekli.
  ///
  /// Avantajda iki zar atilir, yuksek olan; dezavantajda dusuk olan sayilir.
  DiceRoll d20({
    int modifier = 0,
    String label = '',
    String? source,
    Advantage advantage = Advantage.none,
  }) {
    if (advantage == Advantage.none) {
      final r = _rollOne(20);
      return DiceRoll(
        label: label,
        sides: 20,
        count: 1,
        modifier: modifier,
        results: [r],
        total: r + modifier,
        source: source,
        keptIndex: 0,
      );
    }

    final a = _rollOne(20);
    final b = _rollOne(20);
    final kept = advantage == Advantage.advantage
        ? (a >= b ? 0 : 1)
        : (a <= b ? 0 : 1);
    final results = [a, b];
    return DiceRoll(
      label: label,
      sides: 20,
      count: 2,
      modifier: modifier,
      results: results,
      total: results[kept] + modifier,
      source: source,
      advantage: advantage,
      keptIndex: kept,
    );
  }
}
