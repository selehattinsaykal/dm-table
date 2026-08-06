import 'dice.dart';

/// Bir canavar aksiyonundaki tek bir saldiri (Open5e `attacks` girdisi).
///
/// Masada "tek dokunusla vur + hasar at" icin gereken sayilar: isabet modu ve
/// hasar zar(lar)i. Hasar tipi cogu kayitta bos oldugu icin salt gosterimlik.
class MonsterAttack {
  const MonsterAttack({
    required this.name,
    this.toHit,
    this.damageDiceCount = 0,
    this.damageDieSides = 0,
    this.damageBonus = 0,
    this.damageType,
    this.extraDamageDiceCount = 0,
    this.extraDamageDieSides = 0,
    this.extraDamageBonus = 0,
    this.extraDamageType,
  });

  final String name;

  /// Isabet modifiyesi (d20 + bu). Saldiri yerine kurtarma temelliyse null.
  final int? toHit;

  final int damageDiceCount;
  final int damageDieSides;
  final int damageBonus;
  final String? damageType;

  /// Ikincil hasar (or. "+1d8 acid").
  final int extraDamageDiceCount;
  final int extraDamageDieSides;
  final int extraDamageBonus;
  final String? extraDamageType;

  bool get hasToHit => toHit != null;

  bool get hasDamage =>
      damageDiceCount > 0 ||
      damageBonus > 0 ||
      extraDamageDiceCount > 0 ||
      extraDamageBonus > 0;

  /// Isabet atisi: d20 + [toHit]. [toHit] null ise null doner.
  DiceRoll? rollToHit(
    DiceRoller roller, {
    Advantage advantage = Advantage.none,
  }) {
    final mod = toHit;
    if (mod == null) return null;
    return roller.d20(modifier: mod, label: name, advantage: advantage);
  }

  /// Hasar atisi. [critical] ise (dogal 20 ya da DM secimi) zar SAYISI ikiye
  /// katlanir (5e: modifiye katlanmaz, ek hasar zarlari da katlanir).
  DamageRoll rollDamage(DiceRoller roller, {bool critical = false}) {
    final parts = <DamagePart>[];
    var total = 0;

    void addPart(int count, int sides, int bonus, String? type) {
      if (count <= 0 && bonus == 0) return;
      final rolls = <int>[];
      final n = critical ? count * 2 : count;
      for (var i = 0; i < n; i++) {
        rolls.add(sides > 0 ? roller.rollOne(sides) : 0);
      }
      final sum = rolls.fold(0, (a, b) => a + b) + bonus;
      total += sum;
      parts.add(
        DamagePart(
          count: n,
          sides: sides,
          bonus: bonus,
          rolls: rolls,
          type: type,
          sum: sum,
        ),
      );
    }

    addPart(damageDiceCount, damageDieSides, damageBonus, damageType);
    addPart(
      extraDamageDiceCount,
      extraDamageDieSides,
      extraDamageBonus,
      extraDamageType,
    );

    return DamageRoll(
      total: total < 0 ? 0 : total,
      parts: parts,
      critical: critical,
    );
  }
}

/// Hasar atisinin tek bir bileseni (ana ya da ek hasar).
class DamagePart {
  const DamagePart({
    required this.count,
    required this.sides,
    required this.bonus,
    required this.rolls,
    required this.sum,
    this.type,
  });

  final int count;
  final int sides;
  final int bonus;
  final List<int> rolls;
  final int sum;
  final String? type;

  /// "2d6 (3, 4) + 5 slashing" gibi okunur ozet.
  String get detail {
    final dice = sides > 0 && count > 0
        ? '${count}d$sides (${rolls.join(', ')})'
        : '';
    final mod = bonus == 0
        ? ''
        : (bonus > 0
              ? (dice.isEmpty ? '$bonus' : ' + $bonus')
              : ' - ${-bonus}');
    final typeLabel = type == null ? '' : ' $type';
    return '$dice$mod$typeLabel'.trim();
  }
}

/// Bir saldirinin toplam hasari ve bilesenleri.
class DamageRoll {
  const DamageRoll({
    required this.total,
    required this.parts,
    this.critical = false,
  });

  final int total;
  final List<DamagePart> parts;
  final bool critical;

  String get detail => parts.map((p) => p.detail).join(' + ');
}

/// "D6" / "d10" -> 6 / 10. Tanimazsa 0.
int dieSidesFromCode(Object? code) {
  if (code is! String) return 0;
  final match = RegExp(r'(\d+)').firstMatch(code);
  return match == null ? 0 : int.parse(match.group(1)!);
}

String? _damageTypeName(Object? type) {
  if (type is Map) return type['name'] as String?;
  if (type is String && type.isNotEmpty) return type;
  return null;
}

/// Bir aksiyon kaydindaki (`action['attacks']`) saldirilari cozumler.
List<MonsterAttack> attacksFromAction(Map<String, dynamic> action) {
  final raw = action['attacks'];
  if (raw is! List) return const [];
  final out = <MonsterAttack>[];
  for (final a in raw) {
    if (a is! Map) continue;
    out.add(
      MonsterAttack(
        name: a['name'] as String? ?? action['name'] as String? ?? 'Attack',
        toHit: a['to_hit_mod'] as int?,
        damageDiceCount: a['damage_die_count'] as int? ?? 0,
        damageDieSides: dieSidesFromCode(a['damage_die_type']),
        damageBonus: a['damage_bonus'] as int? ?? 0,
        damageType: _damageTypeName(a['damage_type']),
        extraDamageDiceCount: a['extra_damage_die_count'] as int? ?? 0,
        extraDamageDieSides: dieSidesFromCode(a['extra_damage_die_type']),
        extraDamageBonus: a['extra_damage_bonus'] as int? ?? 0,
        extraDamageType: _damageTypeName(a['extra_damage_type']),
      ),
    );
  }
  return out;
}
