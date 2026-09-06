import 'ability.dart';

/// Buyu yapma tipi; Open5e `caster_type` alaniyla birebir.
enum CasterType {
  none,
  full,
  half,
  third,
  pact;

  static CasterType parse(String? value) => switch (value?.toUpperCase()) {
    'FULL' => CasterType.full,
    'HALF' => CasterType.half,
    'THIRD' => CasterType.third,
    'PACT' => CasterType.pact,
    _ => CasterType.none,
  };

  /// Multiclass buyu yuvasi hesabinda bu sinifin katkisi.
  ///
  /// Pact Magic ayri bir havuzdur, ortak tabloya girmez.
  int casterLevelFor(int classLevel) => switch (this) {
    CasterType.full => classLevel,
    CasterType.half => classLevel ~/ 2,
    CasterType.third => classLevel ~/ 3,
    CasterType.none || CasterType.pact => 0,
  };
}

/// Giyilen zirhin AC'ye katkisi.
class ArmorPiece {
  const ArmorPiece({
    required this.baseAc,
    this.category,
    this.addDexModifier = false,
    this.maxDexModifier,
    this.stealthDisadvantage = false,
    this.strengthRequired,
  });

  final int baseAc;

  /// `light`, `medium` ya da `heavy`. Zirh egitimi kontrolu buna bakiyor
  /// (bkz. [CharacterBuild.untrainedArmor]).
  final String? category;

  final bool addDexModifier;

  /// Orta zirhta +2 gibi bir tavan var; agir zirhta Dex hic eklenmez.
  final int? maxDexModifier;
  final bool stealthDisadvantage;
  final int? strengthRequired;
}

/// Bir sinifin karakterdeki seviyesi.
class ClassLevel {
  const ClassLevel({
    required this.classKey,
    required this.level,
    required this.casterType,
    required this.hitDieSides,
    this.subclassKey,
    this.isPrimary = false,
  });

  final String classKey;
  final String? subclassKey;
  final int level;
  final CasterType casterType;

  /// 12, 10, 8, 6.
  final int hitDieSides;

  /// Karakterin ilk aldigi sinif; baslangic yeterlilikleri yalnizca buradan
  /// gelir ve HP hesabinda 1. seviye zar yerine tam deger kullanilir.
  final bool isPrimary;
}

/// Kural motorunun uzerinde calistigi anlik goruntusu.
///
/// Veritabanindan bagimsiz: boylece butun hesaplamalar tek basina test
/// edilebiliyor ve arayuz de ayni sonuclari kullaniyor.
class CharacterBuild {
  const CharacterBuild({
    required this.abilities,
    required this.classes,
    this.skillProficiencies = const {},
    this.skillExpertise = const {},
    this.saveProficiencies = const {},
    this.armor,
    this.hasShield = false,
    this.shieldBonus = 2,
    this.unarmoredDefenseAbility,
    this.exhaustion = 0,
    this.baseSpeed = 30,
    this.miscArmorClassBonus = 0,
    this.armorProficiencies = const {},
    this.toolProficiencies = const {},
    this.hitPointRolls = const {},
  });

  final AbilityScores abilities;
  final List<ClassLevel> classes;
  final Set<Skill> skillProficiencies;
  final Set<Skill> skillExpertise;
  final Set<Ability> saveProficiencies;

  final ArmorPiece? armor;
  final bool hasShield;
  final int shieldBonus;

  /// Barbarian (CON) ve Monk (WIS) icin: zirhsizken AC'ye eklenen ikinci
  /// yetenek. Dolu oldugunda zirhsiz AC = 10 + Dex + bu.
  final Ability? unarmoredDefenseAbility;

  final int exhaustion;
  final int baseSpeed;

  /// Yuzuk/kalkan disi kaynaklardan gelen sabit AC bonusu.
  final int miscArmorClassBonus;

  /// Zirh egitimi (`light`/`medium`/`heavy`/`shield`) ve alet yeterlilikleri.
  ///
  /// Sinif, gecmis ve feat'lerden turetilip kagida yaziliyor; kural
  /// kontrolleri buradan okuyor.
  final Set<String> armorProficiencies;
  final Set<String> toolProficiencies;

  /// Sinif anahtari -> 2. seviyeden itibaren alinan HP artislari.
  /// Bos birakilirsa ortalama kullanilir.
  final Map<String, List<int>> hitPointRolls;

  /// Giyilen zirhin egitimi yoksa true.
  ///
  /// 2024 kurali: yeterliligin olmayan zirhi giyersen Guc ve Ceviklik
  /// kontrolleriyle kurtarma atislarinda dezavantaj alirsin ve buyu
  /// yapamazsin. Dezavantaj sayisal bir deger olmadigi icin burada yalnizca
  /// bayrak duruyor; kagit uyariyi gosteriyor, zar atarken DM uyguluyor.
  bool get untrainedArmor {
    final worn = armor;
    if (worn?.category == null) return false;
    return !armorProficiencies.contains(worn!.category!.toLowerCase());
  }

  /// Kalkan tasiniyor ama kalkan egitimi yoksa true.
  bool get untrainedShield =>
      hasShield && !armorProficiencies.contains('shield');

  /// Zirh ya da kalkan cezasi gecerli mi?
  bool get hasArmorPenalty => untrainedArmor || untrainedShield;

  /// Verilen alette yeterli mi?
  bool proficientWithTool(String tool) {
    final needle = tool.trim().toLowerCase();
    return toolProficiencies.any((t) => t.trim().toLowerCase() == needle);
  }

  int get totalLevel => classes.fold(0, (sum, c) => sum + c.level);

  ClassLevel? get primaryClass {
    if (classes.isEmpty) return null;
    return classes.firstWhere((c) => c.isPrimary, orElse: () => classes.first);
  }
}
