/// SRD'nin duz metin olarak verdigi koken (background/tur) faydalarini
/// yapilandirilmis hale getirir.
///
/// Open5e background'lari `benefits` icinde tip etiketiyle ama serbest metin
/// olarak tasiyor ("Insight and Religion", "*Choose A or B:* (A) ...").
/// Sihirbazin bunlari kutu isaretlemeye cevirebilmesi icin ayristiriliyor.
/// Ayristirma basarisiz olursa ham metin korunur ve kullaniciya gosterilir --
/// sessizce bos gecmektense elle secmesi yeglenir.
library;

import '../models/ability.dart';

/// Bir background'in yapilandirilmis hali.
class BackgroundBenefits {
  const BackgroundBenefits({
    this.abilityOptions = const [],
    this.skills = const [],
    this.toolText,
    this.featName,
    this.featNote,
    this.equipmentOptions = const [],
    this.rawByType = const {},
  });

  /// 2024 kurallarinda background 3 puan verir: bu uc yetenege ya +2/+1 ya da
  /// +1/+1/+1 olarak dagitilir.
  final List<Ability> abilityOptions;

  final List<Skill> skills;

  /// Alet yeterliligi serbest metin kalir ("Choose one kind of Gaming Set"
  /// gibi secim iceren ifadeler var).
  final String? toolText;

  /// Koken feat'i, or. "Magic Initiate".
  final String? featName;

  /// Parantez icindeki ayrinti, or. "Cleric".
  final String? featNote;

  final List<EquipmentOption> equipmentOptions;

  /// Ayristirilamayan her sey burada duruyor; arayuz ham metni gosterebilsin.
  final Map<String, String> rawByType;
}

/// "(A) 2 Daggers, Thieves' Tools, ... , 16 GP" secenegi.
class EquipmentOption {
  const EquipmentOption({
    required this.label,
    required this.entries,
    this.goldPieces = 0,
  });

  /// "A" ya da "B".
  final String label;
  final List<EquipmentEntry> entries;
  final int goldPieces;
}

class EquipmentEntry {
  const EquipmentEntry({required this.name, this.quantity = 1});

  final String name;
  final int quantity;
}

/// 2024 background yetenek dagilimi secenekleri.
enum AbilitySpread {
  /// Bir yetenege +2, digerine +1.
  twoOne,

  /// Uc yetenege birer +1.
  oneOneOne,
}

BackgroundBenefits parseBackgroundBenefits(List<dynamic> benefits) {
  final raw = <String, String>{};
  var abilityOptions = <Ability>[];
  var skills = <Skill>[];
  String? toolText;
  String? featName;
  String? featNote;
  var equipment = <EquipmentOption>[];

  for (final entry in benefits) {
    if (entry is! Map) continue;
    final type = '${entry['type'] ?? ''}';
    final desc = '${entry['desc'] ?? ''}'.trim();
    if (desc.isEmpty) continue;
    raw[type] = desc;

    switch (type) {
      case 'ability_score':
        abilityOptions = _splitList(
          desc,
        ).map(Ability.fromName).whereType<Ability>().toList();
      case 'skill_proficiency':
        skills = _splitList(
          desc,
        ).map(Skill.fromName).whereType<Skill>().toList();
      case 'tool_proficiency':
        toolText = desc;
      case 'feat':
        final match = RegExp(r'^(.*?)\s*\((.*)\)\s*$').firstMatch(desc);
        featName = (match?.group(1) ?? desc).trim();
        featNote = match?.group(2)?.trim();
      case 'equipment':
        equipment = parseEquipmentOptions(desc);
    }
  }

  return BackgroundBenefits(
    abilityOptions: abilityOptions,
    skills: skills,
    toolText: toolText,
    featName: featName,
    featNote: featNote,
    equipmentOptions: equipment,
    rawByType: raw,
  );
}

/// "(A) X, Y, and 8 GP; or (B) 50 GP" -> iki secenek.
///
/// Background'lar bu metni "*Choose A or B:*" (markdown vurgulu), siniflar
/// ise "Choose A or B:" seklinde veriyor; ikisi de destekleniyor.
List<EquipmentOption> parseEquipmentOptions(String desc) {
  final options = <EquipmentOption>[];

  for (final chunk in desc.split(RegExp(r';\s*or\s+', caseSensitive: false))) {
    // "(A)" isaretini metnin neresinde olursa olsun bul; onundeki yonerge
    // ("Choose A or B:") atilir.
    final match = RegExp(
      r'\(([A-Z])\)\s*(.*)$',
      dotAll: true,
    ).firstMatch(chunk);
    if (match == null) continue;

    final label = match.group(1)!;
    var gold = 0;
    final entries = <EquipmentEntry>[];

    for (final part in match.group(2)!.split(',')) {
      // Son ogeden once "and" gelebiliyor: "..., and 15 GP".
      final text = part
          .replaceAll(RegExp(r'^\s*and\s+', caseSensitive: false), '')
          .replaceAll('*', '')
          .trim();
      if (text.isEmpty) continue;

      final goldMatch = RegExp(
        r'^(\d+)\s*GP$',
        caseSensitive: false,
      ).firstMatch(text);
      if (goldMatch != null) {
        gold += int.parse(goldMatch.group(1)!);
        continue;
      }

      // "2 Daggers" / "20 Arrows" -> adet ayrilir.
      final qtyMatch = RegExp(r'^(\d+)\s+(.*)$').firstMatch(text);
      entries.add(
        qtyMatch != null
            ? EquipmentEntry(
                name: qtyMatch.group(2)!.trim(),
                quantity: int.parse(qtyMatch.group(1)!),
              )
            : EquipmentEntry(name: text),
      );
    }
    options.add(
      EquipmentOption(label: label, entries: entries, goldPieces: gold),
    );
  }
  return options;
}

/// Bir sinifin "Core X Traits" tablosundan cikan baslangic bilgileri.
class ClassCoreTraits {
  const ClassCoreTraits({
    this.primaryAbility,
    this.hitDieSides = 8,
    this.savingThrows = const {},
    this.skillChoiceCount = 0,
    this.skillOptions = const [],
    this.anySkill = false,
    this.toolText,
    this.weaponText,
    this.armorText,
    this.equipmentOptions = const [],
    this.rows = const {},
  });

  final Ability? primaryAbility;
  final int hitDieSides;
  final Set<Ability> savingThrows;

  /// Kac beceri secilecek.
  final int skillChoiceCount;

  /// Secilebilecek beceriler. [anySkill] true ise bu liste bostur ve
  /// oyuncu tum becerilerden secebilir (Bard).
  final List<Skill> skillOptions;
  final bool anySkill;

  final String? toolText;
  final String? weaponText;
  final String? armorText;
  final List<EquipmentOption> equipmentOptions;

  /// Tablonun ham satirlari; arayuz ayristirilamayani gosterebilsin.
  final Map<String, String> rows;
}

/// "Core X Traits" markdown tablosunu ayristirir.
ClassCoreTraits parseClassCoreTraits(String desc) {
  final rows = <String, String>{};
  for (final line in desc.split('\n')) {
    final cells = line.split('|').map((c) => c.trim()).toList();
    // "|Anahtar|Deger|" -> ['', 'Anahtar', 'Deger', '']
    if (cells.length < 4) continue;
    final key = cells[1];
    final value = cells[2];
    if (key.isEmpty || value.isEmpty || key.startsWith('---')) continue;
    rows[key] = value;
  }

  final skillText = rows['Skill Proficiencies'] ?? '';
  final skillCount =
      int.tryParse(
        RegExp(
              r'choose\s+(?:any\s+)?(\d+)',
              caseSensitive: false,
            ).firstMatch(skillText)?.group(1) ??
            '',
      ) ??
      0;
  final anySkill = RegExp(
    r'any\s+\d+\s+skills',
    caseSensitive: false,
  ).hasMatch(skillText);

  // "Choose 2: Arcana, History, ... or Religion" -> iki nokta sonrasi liste.
  final listPart = skillText.contains(':')
      ? skillText.substring(skillText.indexOf(':') + 1)
      : '';
  final skillOptions = anySkill
      ? const <Skill>[]
      : _splitList(
          listPart.replaceAll(RegExp(r'\bor\b', caseSensitive: false), ','),
        ).map(Skill.fromName).whereType<Skill>().toList();

  return ClassCoreTraits(
    primaryAbility: Ability.fromName(rows['Primary Ability'] ?? ''),
    hitDieSides:
        int.tryParse(
          RegExp(
                r'[dD](\d+)',
              ).firstMatch(rows['Hit Point Die'] ?? '')?.group(1) ??
              '',
        ) ??
        8,
    savingThrows: _splitList(
      rows['Saving Throw Proficiencies'] ?? '',
    ).map(Ability.fromName).whereType<Ability>().toSet(),
    skillChoiceCount: skillCount,
    skillOptions: skillOptions,
    anySkill: anySkill,
    toolText: rows['Tool Proficiencies'],
    weaponText: rows['Weapon Proficiencies'],
    armorText: rows['Armor Training'],
    equipmentOptions: parseEquipmentOptions(rows['Starting Equipment'] ?? ''),
    rows: rows,
  );
}

/// Turun boyut ve hiz ozelliklerini sayiya cevirir.
class SpeciesTraits {
  const SpeciesTraits({
    this.sizes = const [],
    this.speed = 30,
    this.sizeText,
    this.speedText,
  });

  /// Birden fazlaysa oyuncu secer (Human ve Tiefling icin gecerli).
  final List<String> sizes;
  final int speed;
  final String? sizeText;
  final String? speedText;
}

SpeciesTraits parseSpeciesTraits(List<dynamic> traits) {
  String? sizeText;
  String? speedText;

  for (final t in traits) {
    if (t is! Map) continue;
    switch ('${t['type'] ?? ''}') {
      case 'SIZE':
        sizeText = '${t['desc'] ?? ''}'.trim();
      case 'SPEED':
        speedText = '${t['desc'] ?? ''}'.trim();
    }
  }

  // "Medium (about 5-7 feet tall) or Small (...), chosen when you select"
  final sizes = <String>[];
  if (sizeText != null) {
    for (final candidate in ['Tiny', 'Small', 'Medium', 'Large', 'Huge']) {
      if (RegExp('\\b$candidate\\b', caseSensitive: false).hasMatch(sizeText)) {
        sizes.add(candidate);
      }
    }
  }

  final speed =
      int.tryParse(
        RegExp(r'(\d+)').firstMatch(speedText ?? '')?.group(1) ?? '',
      ) ??
      30;

  return SpeciesTraits(
    sizes: sizes,
    speed: speed,
    sizeText: sizeText,
    speedText: speedText,
  );
}

/// "Insight and Religion" / "A, B and C" / "A, B, C" -> parcalar.
List<String> _splitList(String value) => value
    .split(RegExp(r',|\band\b', caseSensitive: false))
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .toList();
