import 'dart:io';

import '../../domain/models/ability.dart';
import '../../domain/rules/origin_parsing.dart';
import '../../domain/rules/point_buy.dart';

export '../../domain/rules/point_buy.dart' show AbilityMethod, PointBuy;

/// Sihirbaz boyunca doldurulan taslak.
///
/// Degismez (immutable): her adim `copyWith` ile yeni bir taslak uretir,
/// boylece geri gidip ileri gelince ara degerler bozulmuyor.
class CharacterDraft {
  const CharacterDraft({
    this.name = '',
    this.playerName,
    this.speciesKey,
    this.size,
    this.backgroundKey,
    this.originIncreases = const {},
    this.spread = AbilitySpread.twoOne,
    this.classKey,
    this.method = AbilityMethod.pointBuy,
    this.baseScores = const AbilityScores(
      strength: 8,
      dexterity: 8,
      constitution: 8,
      intelligence: 8,
      wisdom: 8,
      charisma: 8,
    ),
    this.chosenSkills = const {},
    this.equipmentChoice,
    this.portraitFile,
  });

  final String name;
  final String? playerName;

  final String? speciesKey;
  final String? size;

  final String? backgroundKey;

  /// Background'in verdigi 3 puanin dagilimi.
  final Map<Ability, int> originIncreases;
  final AbilitySpread spread;

  final String? classKey;

  final AbilityMethod method;

  /// Koken bonuslari EKLENMEDEN onceki puanlar.
  final AbilityScores baseScores;

  final Set<Skill> chosenSkills;

  /// Baslangic ekipmani icin secilen "A" ya da "B".
  final String? equipmentChoice;

  /// Secilen portre dosyasi (kaydedilince karaktere baglanir). Kalici degil.
  final File? portraitFile;

  /// Karakter kagidina yazilacak nihai puanlar.
  AbilityScores get finalScores => baseScores.plus(originIncreases);

  /// Dagitilan toplam koken puani (3 olmali).
  int get originPointsUsed => originIncreases.values.fold(0, (a, b) => a + b);

  CharacterDraft copyWith({
    String? name,
    String? playerName,
    String? speciesKey,
    String? size,
    String? backgroundKey,
    Map<Ability, int>? originIncreases,
    AbilitySpread? spread,
    String? classKey,
    AbilityMethod? method,
    AbilityScores? baseScores,
    Set<Skill>? chosenSkills,
    String? equipmentChoice,
    File? portraitFile,
  }) => CharacterDraft(
    name: name ?? this.name,
    playerName: playerName ?? this.playerName,
    speciesKey: speciesKey ?? this.speciesKey,
    size: size ?? this.size,
    backgroundKey: backgroundKey ?? this.backgroundKey,
    originIncreases: originIncreases ?? this.originIncreases,
    spread: spread ?? this.spread,
    classKey: classKey ?? this.classKey,
    method: method ?? this.method,
    baseScores: baseScores ?? this.baseScores,
    chosenSkills: chosenSkills ?? this.chosenSkills,
    equipmentChoice: equipmentChoice ?? this.equipmentChoice,
    portraitFile: portraitFile ?? this.portraitFile,
  );
}

/// Puan dagitimi kurallari (2024).

const standardArray = <int>[15, 14, 13, 12, 10, 8];
