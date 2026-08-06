import '../models/ability.dart';
import '../models/character_build.dart';

/// Karakter kagidindaki turetilmis degerlerin tamami.
///
/// Hepsi saf fonksiyon: ayni [CharacterBuild] her zaman ayni sonucu verir.
/// Arayuz, oyuncu paneli ve savas takipcisi ayni hesaplari kullansin diye
/// tek yerde toplandi.
extension CharacterMath on CharacterBuild {
  /// Toplam karakter seviyesine gore yeterlilik bonusu.
  int get proficiencyBonus {
    final level = totalLevel < 1 ? 1 : (totalLevel > 20 ? 20 : totalLevel);
    return 2 + ((level - 1) ~/ 4);
  }

  /// 2024 kurallarinda her tukenmislik seviyesi tum d20 testlerine -1 verir.
  int get exhaustionPenalty => -exhaustion;

  int abilityModifier(Ability ability) => abilities.modifier(ability);

  /// Kurtarma atisi modifieri (tukenmislik cezasi dahil).
  int savingThrow(Ability ability) =>
      abilities.modifier(ability) +
      (saveProficiencies.contains(ability) ? proficiencyBonus : 0) +
      exhaustionPenalty;

  /// Beceri modifieri. Uzmanlik varsa yeterlilik bonusu iki katina cikar.
  int skillModifier(Skill skill) {
    var bonus = 0;
    if (skillExpertise.contains(skill)) {
      bonus = proficiencyBonus * 2;
    } else if (skillProficiencies.contains(skill)) {
      bonus = proficiencyBonus;
    }
    return abilities.modifier(skill.ability) + bonus + exhaustionPenalty;
  }

  /// Pasif skor: 10 + ilgili beceri modifieri.
  int passiveSkill(Skill skill) => 10 + skillModifier(skill);

  int get passivePerception => passiveSkill(Skill.perception);

  /// Zirh sinifi.
  ///
  /// Zirh giyiliyse onun kurali gecerli; giyilmiyorsa Unarmored Defense
  /// (varsa) ya da 10 + Dex. Kalkan her iki durumda da eklenir.
  int get armorClass {
    final dex = abilities.modifier(Ability.dexterity);
    final int base;

    final worn = armor;
    if (worn != null) {
      final dexPart = worn.addDexModifier
          ? (worn.maxDexModifier == null
                ? dex
                : (dex < worn.maxDexModifier! ? dex : worn.maxDexModifier!))
          : 0;
      base = worn.baseAc + dexPart;
    } else if (unarmoredDefenseAbility != null) {
      base = 10 + dex + abilities.modifier(unarmoredDefenseAbility!);
    } else {
      base = 10 + dex;
    }

    return base + (hasShield ? shieldBonus : 0) + miscArmorClassBonus;
  }

  int get initiative =>
      abilities.modifier(Ability.dexterity) + exhaustionPenalty;

  /// Tasima kapasitesi (lb): Guc x 15.
  int get carryCapacity => abilities[Ability.strength] * 15;

  /// Azami can puani.
  ///
  /// Ilk sinifin 1. seviyesinde zar atilmaz, hit die'in tam degeri alinir.
  /// Sonraki her seviyede ya kaydedilen atis ya da ortalama (die/2 + 1)
  /// kullanilir. CON modifieri her seviye icin eklenir.
  int get maxHitPoints {
    if (classes.isEmpty) return 0;
    final con = abilities.modifier(Ability.constitution);
    final primary = primaryClass!;

    var total = 0;
    for (final c in classes) {
      final rolls = hitPointRolls[c.classKey] ?? const [];
      // Ilk sinifin ilk seviyesi tam deger, diger siniflarin ilk seviyesi
      // normal bir seviye artisi gibi davranir.
      final freeLevels = c.classKey == primary.classKey ? 1 : 0;
      if (freeLevels == 1) total += c.hitDieSides;

      final rolledLevels = c.level - freeLevels;
      for (var i = 0; i < rolledLevels; i++) {
        total += i < rolls.length ? rolls[i] : averageHitDie(c.hitDieSides);
      }
    }
    // Cok dusuk CON toplami sifira indirmemeli: her seviye icin en az 1 HP.
    final withCon = total + con * totalLevel;
    return withCon < totalLevel ? totalLevel : withCon;
  }

  /// Zar atmak istemeyenler icin standart artis: (yuz / 2) + 1.
  static int averageHitDie(int sides) => sides ~/ 2 + 1;

  /// Ortak buyu yuvasi havuzu icin birlesik buyucu seviyesi.
  ///
  /// Tek siniflilarda sinifin kendi seviyesi; multiclass'ta tam buyuculer
  /// tam, yarim buyuculer yarisi, ucte-bir buyuculer ucte biri (asagi
  /// yuvarlanarak) toplanir. Pact Magic bu havuza girmez.
  int get combinedCasterLevel {
    if (classes.length == 1) {
      final only = classes.single;
      return only.casterType == CasterType.pact
          ? 0
          : only.casterType.casterLevelFor(only.level);
    }
    return classes.fold(
      0,
      (sum, c) => sum + c.casterType.casterLevelFor(c.level),
    );
  }

  /// Warlock seviyesi (Pact Magic ayri havuz).
  int get pactCasterLevel => classes
      .where((c) => c.casterType == CasterType.pact)
      .fold(0, (sum, c) => sum + c.level);

  /// Buyu kaydetme DC'si: 8 + yeterlilik + buyu yetenegi modifieri.
  int spellSaveDc(Ability spellcastingAbility) =>
      8 + proficiencyBonus + abilities.modifier(spellcastingAbility);

  int spellAttackBonus(Ability spellcastingAbility) =>
      proficiencyBonus + abilities.modifier(spellcastingAbility);
}

/// Sinif anahtarindan buyu yetenegini verir.
///
/// SRD verisinde bu alan yok (sinif kaydinda `primary_abilities` bos
/// geliyor), kural olarak sabit oldugu icin burada esleniyor.
Ability? spellcastingAbilityFor(String classKey) {
  final key = classKey.split('_').last;
  return switch (key) {
    'bard' || 'paladin' || 'sorcerer' || 'warlock' => Ability.charisma,
    'cleric' || 'druid' || 'ranger' => Ability.wisdom,
    'wizard' => Ability.intelligence,
    _ => null,
  };
}
