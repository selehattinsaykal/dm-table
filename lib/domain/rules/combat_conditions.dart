import 'dart:convert';

/// Savastaki bir durum (condition), istege bagli tur suresiyle.
///
/// [rounds] null ise durum suresizdir (DM elle kaldirir). Bir sayi ise, etkilenen
/// katilimcinin her turunun basinda bir azalir; 0'a inince kalkar ("tur basinda
/// hatirlatma"). Depolamada `Combatants.conditionsJson` icinde tutulur.
class CombatCondition {
  const CombatCondition(this.name, {this.rounds});

  final String name;
  final int? rounds;

  CombatCondition copyWith({int? rounds}) =>
      CombatCondition(name, rounds: rounds ?? this.rounds);

  Map<String, dynamic> toJson() => {
    'name': name,
    if (rounds != null) 'rounds': rounds,
  };

  @override
  bool operator ==(Object other) =>
      other is CombatCondition && other.name == name && other.rounds == rounds;

  @override
  int get hashCode => Object.hash(name, rounds);
}

/// `conditionsJson` metnini cozumler. Eski bicim (duz string dizisi) ile yeni
/// bicimi (`{name, rounds?}` nesneleri) birlikte kabul eder; boylece surum
/// yukseltmede eski savaslar bozulmaz.
List<CombatCondition> parseConditions(String json) {
  final data = jsonDecode(json);
  if (data is! List) return const [];
  final out = <CombatCondition>[];
  for (final e in data) {
    if (e is String) {
      out.add(CombatCondition(e));
    } else if (e is Map) {
      final name = e['name'];
      if (name is String) {
        out.add(CombatCondition(name, rounds: e['rounds'] as int?));
      }
    }
  }
  return out;
}

/// Durum listesini `conditionsJson` bicimine cevirir (her zaman yeni nesne
/// bicimini yazar).
String encodeConditions(List<CombatCondition> conditions) =>
    jsonEncode([for (final c in conditions) c.toJson()]);

/// Etkilenen katilimcinin turu basladiginda sureleri bir azaltir.
///
/// Suresiz (rounds == null) durumlar dokunulmadan kalir. Suresi 1 olanlar bu
/// tur biter ve [expired]'a girer. Sonuc ([next]) yeni durum listesidir.
({List<CombatCondition> next, List<String> expired}) tickConditions(
  List<CombatCondition> conditions,
) {
  final next = <CombatCondition>[];
  final expired = <String>[];
  for (final c in conditions) {
    if (c.rounds == null) {
      next.add(c);
      continue;
    }
    final remaining = c.rounds! - 1;
    if (remaining <= 0) {
      expired.add(c.name);
    } else {
      next.add(CombatCondition(c.name, rounds: remaining));
    }
  }
  return (next: next, expired: expired);
}

/// Konsantrasyon kurtarmasinin DC'si: 10 ya da hasarin YARISI, hangisi
/// buyukse (5e).
///
/// Masada en cok unutulan kural bu; hasar uygulandigi anda hatirlatilmasi
/// icin ayri bir fonksiyon.
int concentrationSaveDc(int damage) {
  final half = damage ~/ 2;
  return half > 10 ? half : 10;
}
