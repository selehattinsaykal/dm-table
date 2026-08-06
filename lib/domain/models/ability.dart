/// Yetenekler ve beceriler.
///
/// Bu esleme SRD'de sabit ve kucuk oldugu icin kod icinde tutuluyor; veri
/// tabanindaki `reference_entries` tablosunda da bulunur ama kural motorunun
/// veritabanina bagimli olmamasi test edilebilirligi ciddi sekilde
/// kolaylastiriyor.
library;

enum Ability {
  strength('Strength', 'STR'),
  dexterity('Dexterity', 'DEX'),
  constitution('Constitution', 'CON'),
  intelligence('Intelligence', 'INT'),
  wisdom('Wisdom', 'WIS'),
  charisma('Charisma', 'CHA');

  const Ability(this.label, this.short);

  final String label;
  final String short;

  static Ability? fromName(String value) {
    final needle = value.trim().toLowerCase();
    for (final a in Ability.values) {
      if (a.name == needle || a.label.toLowerCase() == needle) return a;
      if (a.short.toLowerCase() == needle) return a;
    }
    return null;
  }
}

enum Skill {
  acrobatics('Acrobatics', Ability.dexterity),
  animalHandling('Animal Handling', Ability.wisdom),
  arcana('Arcana', Ability.intelligence),
  athletics('Athletics', Ability.strength),
  deception('Deception', Ability.charisma),
  history('History', Ability.intelligence),
  insight('Insight', Ability.wisdom),
  intimidation('Intimidation', Ability.charisma),
  investigation('Investigation', Ability.intelligence),
  medicine('Medicine', Ability.wisdom),
  nature('Nature', Ability.intelligence),
  perception('Perception', Ability.wisdom),
  performance('Performance', Ability.charisma),
  persuasion('Persuasion', Ability.charisma),
  religion('Religion', Ability.intelligence),
  sleightOfHand('Sleight of Hand', Ability.dexterity),
  stealth('Stealth', Ability.dexterity),
  survival('Survival', Ability.wisdom);

  const Skill(this.label, this.ability);

  final String label;
  final Ability ability;

  /// Veride `animal_handling` / `Animal Handling` gibi farkli yazimlar
  /// gectigi icin ikisini de kabul eder.
  static Skill? fromName(String value) {
    final needle = value.trim().toLowerCase().replaceAll(RegExp(r'[_\s]+'), '');
    for (final s in Skill.values) {
      if (s.name.toLowerCase() == needle) return s;
      if (s.label.toLowerCase().replaceAll(' ', '') == needle) return s;
    }
    return null;
  }
}

/// Alti yetenek puani.
class AbilityScores {
  const AbilityScores({
    this.strength = 10,
    this.dexterity = 10,
    this.constitution = 10,
    this.intelligence = 10,
    this.wisdom = 10,
    this.charisma = 10,
  });

  final int strength;
  final int dexterity;
  final int constitution;
  final int intelligence;
  final int wisdom;
  final int charisma;

  int operator [](Ability ability) => switch (ability) {
    Ability.strength => strength,
    Ability.dexterity => dexterity,
    Ability.constitution => constitution,
    Ability.intelligence => intelligence,
    Ability.wisdom => wisdom,
    Ability.charisma => charisma,
  };

  /// Kural asagi yuvarlamadir; `~/` sifira dogru kirptigi icin 10 altindaki
  /// tek sayilarda yanlis sonuc verirdi (7 -> -1 yerine -2 olmali).
  int modifier(Ability ability) => ((this[ability] - 10) / 2).floor();

  AbilityScores plus(Map<Ability, int> deltas) => AbilityScores(
    strength: strength + (deltas[Ability.strength] ?? 0),
    dexterity: dexterity + (deltas[Ability.dexterity] ?? 0),
    constitution: constitution + (deltas[Ability.constitution] ?? 0),
    intelligence: intelligence + (deltas[Ability.intelligence] ?? 0),
    wisdom: wisdom + (deltas[Ability.wisdom] ?? 0),
    charisma: charisma + (deltas[Ability.charisma] ?? 0),
  );

  Map<String, int> toJson() => {
    for (final a in Ability.values) a.name: this[a],
  };

  static AbilityScores fromJson(Map<String, dynamic> json) => AbilityScores(
    strength: json['strength'] as int? ?? 10,
    dexterity: json['dexterity'] as int? ?? 10,
    constitution: json['constitution'] as int? ?? 10,
    intelligence: json['intelligence'] as int? ?? 10,
    wisdom: json['wisdom'] as int? ?? 10,
    charisma: json['charisma'] as int? ?? 10,
  );
}
