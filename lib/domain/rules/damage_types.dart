import 'dart:convert';

/// D&D 5e hasar turleri.
///
/// Sirasi arayuzde gorunen sira: once fiziksel uclu, sonra elementler,
/// sonunda ruhsal/isinsal olanlar. Ad `name` uzerinden JSON'a yaziliyor,
/// bu yuzden ISIMLER DEGISTIRILEMEZ (kayitli savunmalar bozulur).
enum DamageType {
  bludgeoning,
  piercing,
  slashing,
  acid,
  cold,
  fire,
  lightning,
  thunder,
  poison,
  necrotic,
  radiant,
  psychic,
  force;

  static DamageType? parse(String? raw) {
    if (raw == null) return null;
    final needle = raw.trim().toLowerCase();
    for (final type in values) {
      if (type.name == needle) return type;
    }
    // 5etools ve Open5e kisaltmalari: "B", "P", "S".
    return switch (needle) {
      'b' => DamageType.bludgeoning,
      'p' => DamageType.piercing,
      's' => DamageType.slashing,
      'a' => DamageType.acid,
      'c' => DamageType.cold,
      'f' => DamageType.fire,
      'l' => DamageType.lightning,
      't' => DamageType.thunder,
      'i' => DamageType.poison,
      'n' => DamageType.necrotic,
      'r' => DamageType.radiant,
      'y' => DamageType.psychic,
      'o' => DamageType.force,
      _ => null,
    };
  }
}

/// Bir yaratigin hasar turlerine karsi durusu.
class Defenses {
  const Defenses({
    this.resistant = const {},
    this.immune = const {},
    this.vulnerable = const {},
  });

  final Set<DamageType> resistant;
  final Set<DamageType> immune;
  final Set<DamageType> vulnerable;

  bool get isEmpty => resistant.isEmpty && immune.isEmpty && vulnerable.isEmpty;

  /// Bir hasar turune uygulanan carpan adi.
  DamageModifier modifierFor(DamageType? type) {
    if (type == null) return DamageModifier.normal;
    // Bagisiklik direnci ve zayifligi EZER: uc listede birden gecen bir tur
    // (homebrew'da olabiliyor) once bagisiklik sayilir.
    if (immune.contains(type)) return DamageModifier.immune;
    if (resistant.contains(type) && vulnerable.contains(type)) {
      // Kural: direnc ve zayiflik birbirini goturur.
      return DamageModifier.normal;
    }
    if (resistant.contains(type)) return DamageModifier.resistant;
    if (vulnerable.contains(type)) return DamageModifier.vulnerable;
    return DamageModifier.normal;
  }

  Map<String, dynamic> toJson() => {
    'resist': [for (final t in resistant) t.name],
    'immune': [for (final t in immune) t.name],
    'vulnerable': [for (final t in vulnerable) t.name],
  };

  String encode() => jsonEncode(toJson());

  static Defenses decode(String? json) {
    if (json == null || json.trim().isEmpty) return const Defenses();
    try {
      final map = jsonDecode(json);
      if (map is! Map) return const Defenses();
      return Defenses(
        resistant: _set(map['resist']),
        immune: _set(map['immune']),
        vulnerable: _set(map['vulnerable']),
      );
    } on Object {
      // Bozuk kayit savas ekranini kilitlemesin.
      return const Defenses();
    }
  }

  static Set<DamageType> _set(Object? node) {
    if (node is! List) return const {};
    return {for (final item in node) ?DamageType.parse('$item')};
  }
}

/// Hasarin nasil degistigi.
enum DamageModifier {
  normal,
  resistant,
  immune,
  vulnerable;

  /// Ham hasari uygular.
  ///
  /// Direncte YUVARLAMA ASAGI (kural: "halve the damage, round down"),
  /// zayiflikta iki kat.
  int apply(int amount) => switch (this) {
    DamageModifier.normal => amount,
    DamageModifier.resistant => amount ~/ 2,
    DamageModifier.immune => 0,
    DamageModifier.vulnerable => amount * 2,
  };
}

/// Hasari savunmalara gore hesaplar.
///
/// [amount] her zaman POZITIF verilir (uygulanan hasar); iyilestirme bu
/// yoldan gecmiyor.
({int amount, DamageModifier modifier}) applyDefenses(
  int amount,
  DamageType? type,
  Defenses defenses,
) {
  final modifier = defenses.modifierFor(type);
  return (amount: modifier.apply(amount), modifier: modifier);
}

/// Kutuphane verisindeki serbest metinden savunmalari cikarir.
///
/// Open5e `damage_resistances` alani "fire, cold; bludgeoning, piercing and
/// slashing from nonmagical attacks" gibi CUMLE olabiliyor. Tanidigimiz tur
/// adlarini tariyoruz; sartli olanlar ("from nonmagical") ayrilamadigi icin
/// yine de listeye giriyor -- DM savas ekranindan cikarabiliyor. Sessizce
/// hic almamak, uygulanmayan direncten daha kotu olurdu.
Defenses defensesFromText({
  String? resistances,
  String? immunities,
  String? vulnerabilities,
}) => Defenses(
  resistant: _scan(resistances),
  immune: _scan(immunities),
  vulnerable: _scan(vulnerabilities),
);

Set<DamageType> _scan(String? text) {
  if (text == null || text.trim().isEmpty) return const {};
  final lower = text.toLowerCase();
  return {
    for (final type in DamageType.values)
      if (RegExp('\\b${type.name}\\b').hasMatch(lower)) type,
  };
}
