/// Multiclass ön koşulları (2024).
///
/// Yeni bir sınıfa seviye atlamak için hem *mevcut* sınıfının hem de *yeni*
/// sınıfın yetenek puanı eşiğini karşılamak gerekiyor. Uygulama şimdiye kadar
/// her sınıfa seviye atlamaya izin veriyordu; masada "bunu alabilir miyim?"
/// sorusu her seferinde kural kitabına gidiyordu.
library;

import '../models/ability.dart';

/// Sınıfın multiclass için istediği yetenek puanları.
///
/// Çoğu sınıf tek bir yetenek ister; Fighter (STR **ya da** DEX) ve Monk
/// (DEX **ve** WIS) istisnalar. `any` true ise listeden biri yeterli.
class MulticlassRequirement {
  const MulticlassRequirement({
    required this.abilities,
    this.minimum = 13,
    this.any = false,
  });

  final List<Ability> abilities;
  final int minimum;

  /// true: listeden BİRİ yeterli. false: hepsi gerekli.
  final bool any;
}

/// Sınıf anahtarının (son parçası) multiclass eşiği; bilinmeyen sınıfta null.
MulticlassRequirement? multiclassRequirementFor(String classKey) {
  return switch (classKey.split('_').last) {
    'barbarian' => const MulticlassRequirement(abilities: [Ability.strength]),
    'bard' ||
    'sorcerer' ||
    'warlock' => const MulticlassRequirement(abilities: [Ability.charisma]),
    'cleric' ||
    'druid' => const MulticlassRequirement(abilities: [Ability.wisdom]),
    'fighter' => const MulticlassRequirement(
      abilities: [Ability.strength, Ability.dexterity],
      any: true,
    ),
    'monk' => const MulticlassRequirement(
      abilities: [Ability.dexterity, Ability.wisdom],
    ),
    'paladin' => const MulticlassRequirement(
      abilities: [Ability.strength, Ability.charisma],
    ),
    'ranger' => const MulticlassRequirement(
      abilities: [Ability.dexterity, Ability.wisdom],
    ),
    'rogue' => const MulticlassRequirement(abilities: [Ability.dexterity]),
    'wizard' || 'artificer' => const MulticlassRequirement(
      abilities: [Ability.intelligence],
    ),
    _ => null,
  };
}

/// Bir eşiğin karşılanıp karşılanmadığı.
bool meetsRequirement(
  MulticlassRequirement? requirement,
  AbilityScores scores,
) {
  if (requirement == null) return true;
  bool ok(Ability a) => scores[a] >= requirement.minimum;
  return requirement.any
      ? requirement.abilities.any(ok)
      : requirement.abilities.every(ok);
}

/// [target] sınıfına multiclass yapılabilir mi?
///
/// [currentClasses] karakterin şu anki sınıf anahtarları. Zaten sahip olunan
/// bir sınıfta ilerlemek koşul aramaz; koşul yalnızca YENİ sınıf alırken
/// işler ve o zaman mevcut sınıf(lar)ın eşiği de karşılanmalıdır.
({bool allowed, List<Ability> missing}) canMulticlassInto({
  required String target,
  required List<String> currentClasses,
  required AbilityScores scores,
}) {
  if (currentClasses.contains(target) || currentClasses.isEmpty) {
    return (allowed: true, missing: const []);
  }

  final missing = <Ability>{};
  for (final key in [target, ...currentClasses]) {
    final requirement = multiclassRequirementFor(key);
    if (meetsRequirement(requirement, scores)) continue;
    for (final ability in requirement!.abilities) {
      if (scores[ability] < requirement.minimum) missing.add(ability);
    }
  }
  return (allowed: missing.isEmpty, missing: missing.toList());
}
