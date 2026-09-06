import '../domain/models/ability.dart';
import 'app_localizations.dart';

/// [Ability] ve [Skill] enum'larinin ekranda gorunen adlari.
///
/// Enum'larin kendi `label` alani INGILIZCE kalmali: SRD verisiyle eslesme
/// (`Ability.fromName`, `Skill.fromName`), zar etiketleri ve kural
/// ayristiricilari o metne bakiyor. Gosterim tarafi buradan geciyor.
///
/// Bu ikisi ARB'de, `assets/data/tr/glossary_tr.json` icinde degil: sabit ve
/// kucuk bir kume, veriden gelmiyorlar ve `BuildContext` disinda bir
/// saglayiciya ihtiyac duymadan cozulmeleri gerekiyor. Sozluk ise
/// veritabanindan Ingilizce gelen alan degerleri icin.
extension GameTermsL10n on L10n {
  String abilityName(Ability ability) => switch (ability) {
    Ability.strength => abilityStrength,
    Ability.dexterity => abilityDexterity,
    Ability.constitution => abilityConstitution,
    Ability.intelligence => abilityIntelligence,
    Ability.wisdom => abilityWisdom,
    Ability.charisma => abilityCharisma,
  };

  /// Kagittaki uc harfli kisaltma (GUC, CEV...).
  String abilityShort(Ability ability) => switch (ability) {
    Ability.strength => abilityShortStrength,
    Ability.dexterity => abilityShortDexterity,
    Ability.constitution => abilityShortConstitution,
    Ability.intelligence => abilityShortIntelligence,
    Ability.wisdom => abilityShortWisdom,
    Ability.charisma => abilityShortCharisma,
  };

  String skillName(Skill skill) => switch (skill) {
    Skill.acrobatics => skillAcrobatics,
    Skill.animalHandling => skillAnimalHandling,
    Skill.arcana => skillArcana,
    Skill.athletics => skillAthletics,
    Skill.deception => skillDeception,
    Skill.history => skillHistory,
    Skill.insight => skillInsight,
    Skill.intimidation => skillIntimidation,
    Skill.investigation => skillInvestigation,
    Skill.medicine => skillMedicine,
    Skill.nature => skillNature,
    Skill.perception => skillPerception,
    Skill.performance => skillPerformance,
    Skill.persuasion => skillPersuasion,
    Skill.religion => skillReligion,
    Skill.sleightOfHand => skillSleightOfHand,
    Skill.stealth => skillStealth,
    Skill.survival => skillSurvival,
  };

  /// Adiyla verilen bir yetenek/beceri ("Wisdom", "animal_handling"); veriden
  /// gelen serbest metinler icin. Taninmayan deger oldugu gibi doner.
  String gameTerm(String value) {
    final ability = Ability.fromName(value);
    if (ability != null) return abilityName(ability);
    final skill = Skill.fromName(value);
    if (skill != null) return skillName(skill);
    return value;
  }
}
