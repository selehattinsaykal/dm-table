/// Zirh egitimi, silah ve alet yeterlilikleri ile dillerin ayristirilmasi.
///
/// SRD bunlari YAPISAL tutmuyor: sinifin "Core X Traits" tablosunda ve
/// background'un "Tool Proficiency" faydasinda duz metin olarak geciyorlar.
/// Iyi haber, dagarcik kapali: 13 sinif toplam 4 silah, 5 zirh ve 5 alet
/// dizesi kullaniyor. Bu yuzden serbest ayristirma yerine TAM DEGER
/// eslesmesi yapiliyor -- taninmayan bir dize sessizce yanlis yeterlilik
/// uretmek yerine [ProficiencyGrant.unparsed] icinde geri doner ve arayuz
/// onu ham haliyle gosterir.
library;

/// Yeterlilik turu. Veri katmanindaki `ProficiencyKind` ile ayni kavram, ama
/// domain'in veritabanina bagimli olmamasi icin ayri duruyor.
///
/// [weaponMastery] bir yeterlilik DEGIL: 2024 kuralinda secilen silahin
/// mastery ozelligini (Topple, Vex...) kullanma hakki. Ayni tabloda tutuluyor
/// cunku o da "kaynagi olan, seviyeyle degisen bir secim listesi".
enum ProficiencyType { armor, weapon, tool, language, weaponMastery }

/// Kanonik zirh egitimi degerleri.
abstract final class ArmorTraining {
  static const light = 'light';
  static const medium = 'medium';
  static const heavy = 'heavy';
  static const shield = 'shield';

  static const all = [light, medium, heavy, shield];
}

/// Kanonik silah yeterliligi degerleri.
///
/// Rogue ve Monk "Simple weapons and Martial weapons that have the Light
/// property" gibi KOSULLU bir yeterlilik aliyor. Bunu tek tek silah adina
/// acmak yerine kosulun kendisi bir deger olarak saklaniyor; kural kontrolu
/// ([weaponAllowedBy]) silahin ozelliklerine bakarak cozuyor.
abstract final class WeaponProficiency {
  static const simple = 'simple';
  static const martial = 'martial';
  static const martialLight = 'martial-light';
  static const martialFinesseOrLight = 'martial-finesse-or-light';
}

/// Bir alet secimi hangi kumeden yapilacak.
enum ToolGroup { artisansTools, gamingSet, musicalInstrument, any }

/// Kaynaktan gelen, oyuncunun yapmasi gereken secim.
class ProficiencyChoice {
  const ProficiencyChoice({
    required this.type,
    required this.count,
    this.toolGroups = const [],
    this.skillsAllowed = false,
  });

  final ProficiencyType type;

  /// Kac tane secilecek.
  final int count;

  /// [ProficiencyType.tool] icin: secimin yapilacagi kume(ler).
  final List<ToolGroup> toolGroups;

  /// Skilled feat'i "uc beceri YA DA alet" diyor; secim iki havuzdan da
  /// yapilabiliyor.
  final bool skillsAllowed;

  @override
  bool operator ==(Object other) =>
      other is ProficiencyChoice &&
      other.type == type &&
      other.count == count &&
      other.skillsAllowed == skillsAllowed &&
      other.toolGroups.length == toolGroups.length &&
      other.toolGroups.every(toolGroups.contains);

  @override
  int get hashCode =>
      Object.hash(type, count, toolGroups.length, skillsAllowed);

  @override
  String toString() => 'ProficiencyChoice($type x$count, $toolGroups)';
}

/// Bir kaynagin (sinif, background, feat) verdigi yeterlilikler.
class ProficiencyGrant {
  const ProficiencyGrant({
    this.armor = const {},
    this.weapons = const {},
    this.tools = const {},
    this.languages = const {},
    this.choices = const [],
    this.unparsed = const {},
  });

  final Set<String> armor;
  final Set<String> weapons;
  final Set<String> tools;
  final Set<String> languages;
  final List<ProficiencyChoice> choices;

  /// Taninmayan kaynak dizeleri. Bos degilse veri degismis demektir; arayuz
  /// bunlari ham gosterir, test ise hataya cevirir.
  final Set<String> unparsed;

  bool get isEmpty =>
      armor.isEmpty &&
      weapons.isEmpty &&
      tools.isEmpty &&
      languages.isEmpty &&
      choices.isEmpty;

  ProficiencyGrant merge(ProficiencyGrant other) => ProficiencyGrant(
    armor: {...armor, ...other.armor},
    weapons: {...weapons, ...other.weapons},
    tools: {...tools, ...other.tools},
    languages: {...languages, ...other.languages},
    choices: [...choices, ...other.choices],
    unparsed: {...unparsed, ...other.unparsed},
  );
}

/// Sinifin "Armor Training" satiri. 13 sinif 5 farkli dize kullaniyor.
const _armorTraining = <String, Set<String>>{
  'none': {},
  'light armor': {ArmorTraining.light},
  'light armor and shields': {ArmorTraining.light, ArmorTraining.shield},
  'light and medium armor and shields': {
    ArmorTraining.light,
    ArmorTraining.medium,
    ArmorTraining.shield,
  },
  'light, medium, and heavy armor and shields': {
    ArmorTraining.light,
    ArmorTraining.medium,
    ArmorTraining.heavy,
    ArmorTraining.shield,
  },
};

/// Sinifin "Weapon Proficiencies" satiri. 13 sinif 4 farkli dize kullaniyor.
const _weaponProficiencies = <String, Set<String>>{
  'simple weapons': {WeaponProficiency.simple},
  'simple and martial weapons': {
    WeaponProficiency.simple,
    WeaponProficiency.martial,
  },
  'simple weapons and martial weapons that have the light property': {
    WeaponProficiency.simple,
    WeaponProficiency.martialLight,
  },
  'simple weapons and martial weapons that have the finesse or light property':
      {WeaponProficiency.simple, WeaponProficiency.martialFinesseOrLight},
};

/// Hem sinif hem background alet satirlarinda gecen KAPALI dizeler.
///
/// Anahtarlar kucuk harf; deger ya dogrudan verilen aletler ya da bir secim.
const _toolText = <String, ({Set<String> tools, List<ProficiencyChoice> choices})>{
  "thieves' tools": (tools: {"Thieves' Tools"}, choices: []),
  'herbalism kit': (tools: {'Herbalism Kit'}, choices: []),
  'disguise kit': (tools: {'Disguise Kit'}, choices: []),
  'forgery kit': (tools: {'Forgery Kit'}, choices: []),
  "navigator's tools": (tools: {"Navigator's Tools"}, choices: []),
  "calligrapher's supplies": (tools: {"Calligrapher's Supplies"}, choices: []),
  "cartographer's tools": (tools: {"Cartographer's Tools"}, choices: []),
  "carpenter's tools": (tools: {"Carpenter's Tools"}, choices: []),
  "cook's utensils": (tools: {"Cook's Utensils"}, choices: []),
  "glassblower's tools": (tools: {"Glassblower's Tools"}, choices: []),
  "jeweler's tools": (tools: {"Jeweler's Tools"}, choices: []),
  "leatherworker's tools": (tools: {"Leatherworker's Tools"}, choices: []),
  "mason's tools": (tools: {"Mason's Tools"}, choices: []),
  "painter's supplies": (tools: {"Painter's Supplies"}, choices: []),
  "smith's tools": (tools: {"Smith's Tools"}, choices: []),
  "weaver's tools": (tools: {"Weaver's Tools"}, choices: []),
  "woodcarver's tools": (tools: {"Woodcarver's Tools"}, choices: []),
  'choose 3 musical instruments': (
    tools: {},
    choices: [
      ProficiencyChoice(
        type: ProficiencyType.tool,
        count: 3,
        toolGroups: [ToolGroup.musicalInstrument],
      ),
    ],
  ),
  'choose one kind of gaming set': (
    tools: {},
    choices: [
      ProficiencyChoice(
        type: ProficiencyType.tool,
        count: 1,
        toolGroups: [ToolGroup.gamingSet],
      ),
    ],
  ),
  "choose one kind of artisan's tools": (
    tools: {},
    choices: [
      ProficiencyChoice(
        type: ProficiencyType.tool,
        count: 1,
        toolGroups: [ToolGroup.artisansTools],
      ),
    ],
  ),
  'choose one kind of musical instrument': (
    tools: {},
    choices: [
      ProficiencyChoice(
        type: ProficiencyType.tool,
        count: 1,
        toolGroups: [ToolGroup.musicalInstrument],
      ),
    ],
  ),
  "choose one type of artisan's tools or musical instrument": (
    tools: {},
    choices: [
      ProficiencyChoice(
        type: ProficiencyType.tool,
        count: 1,
        toolGroups: [ToolGroup.artisansTools, ToolGroup.musicalInstrument],
      ),
    ],
  ),
  "thieves' tools, tinker's tools, and one type of artisan's tools of your choice":
      (
        tools: {"Thieves' Tools", "Tinker's Tools"},
        choices: [
          ProficiencyChoice(
            type: ProficiencyType.tool,
            count: 1,
            toolGroups: [ToolGroup.artisansTools],
          ),
        ],
      ),
};

String _key(String value) => value.trim().toLowerCase();

/// Sinifin cekirdek ozellik tablosundan gelen yeterlilikler.
///
/// [armorText], [weaponText] ve [toolText] `parseClassCoreTraits`'in dondugu
/// ham satirlar.
ProficiencyGrant parseClassProficiencies({
  String? armorText,
  String? weaponText,
  String? toolText,
}) {
  final armor = <String>{};
  final weapons = <String>{};
  final tools = <String>{};
  final choices = <ProficiencyChoice>[];
  final unparsed = <String>{};

  if (armorText != null && armorText.trim().isNotEmpty) {
    final match = _armorTraining[_key(armorText)];
    if (match == null) {
      unparsed.add(armorText.trim());
    } else {
      armor.addAll(match);
    }
  }
  if (weaponText != null && weaponText.trim().isNotEmpty) {
    final match = _weaponProficiencies[_key(weaponText)];
    if (match == null) {
      unparsed.add(weaponText.trim());
    } else {
      weapons.addAll(match);
    }
  }
  if (toolText != null && toolText.trim().isNotEmpty) {
    final match = _toolText[_key(toolText)];
    if (match == null) {
      unparsed.add(toolText.trim());
    } else {
      tools.addAll(match.tools);
      choices.addAll(match.choices);
    }
  }

  return ProficiencyGrant(
    armor: armor,
    weapons: weapons,
    tools: tools,
    choices: choices,
    unparsed: unparsed,
  );
}

/// Background'un "Tool Proficiency" faydasindan gelen yeterlilik.
ProficiencyGrant parseBackgroundProficiencies(String? toolProficiencyText) {
  if (toolProficiencyText == null || toolProficiencyText.trim().isEmpty) {
    return const ProficiencyGrant();
  }
  final match = _toolText[_key(toolProficiencyText)];
  if (match == null) {
    return ProficiencyGrant(unparsed: {toolProficiencyText.trim()});
  }
  return ProficiencyGrant(tools: match.tools, choices: match.choices);
}

/// Adiyla verilen bir FEAT'in getirdigi yeterlilikler.
///
/// 150 feat'in metni taranip yalnizca gercekten zirh/silah/alet/dil veren
/// 12'si burada acikca yazildi. Duzyazi uzerinde regex denemek yerine elle
/// kuratorluk: bir kural aracinda sessizce yanlis yeterlilik uretmek, hic
/// uretmemekten kotudur. Kalan feat'lerin metninde yalnizca "Proficiency
/// Bonus" gectigi icin eslesme YOK.
///
/// Beceri ve kurtarma yeterlilikleri buranin kapsaminda degil; onlari
/// `CharacterRepository` zaten ayri isliyor.
ProficiencyGrant featProficiencies(String featName) =>
    _featGrants[_key(featName)] ?? const ProficiencyGrant();

final _featGrants = <String, ProficiencyGrant>{
  'heavily armored': const ProficiencyGrant(armor: {ArmorTraining.heavy}),
  'moderately armored': const ProficiencyGrant(armor: {ArmorTraining.medium}),
  'lightly armored': const ProficiencyGrant(
    armor: {ArmorTraining.light, ArmorTraining.shield},
  ),
  'martial weapon training': const ProficiencyGrant(
    weapons: {WeaponProficiency.martial},
  ),
  'tavern brawler': const ProficiencyGrant(weapons: {'improvised'}),
  'chef': const ProficiencyGrant(tools: {"Cook's Utensils"}),
  'poisoner': const ProficiencyGrant(tools: {"Poisoner's Kit"}),
  'crafter': const ProficiencyGrant(
    choices: [
      ProficiencyChoice(
        type: ProficiencyType.tool,
        count: 3,
        toolGroups: [ToolGroup.artisansTools],
      ),
    ],
  ),
  'musician': const ProficiencyGrant(
    choices: [
      ProficiencyChoice(
        type: ProficiencyType.tool,
        count: 3,
        toolGroups: [ToolGroup.musicalInstrument],
      ),
    ],
  ),
  // "Thieves' Cant. You know Thieves' Cant." + bir calgi secimi.
  'harper agent': const ProficiencyGrant(
    languages: {"Thieves' Cant"},
    choices: [
      ProficiencyChoice(
        type: ProficiencyType.tool,
        count: 1,
        toolGroups: [ToolGroup.musicalInstrument],
      ),
    ],
  ),
  'skilled': const ProficiencyGrant(
    choices: [
      ProficiencyChoice(
        type: ProficiencyType.tool,
        count: 3,
        toolGroups: [ToolGroup.any],
        skillsAllowed: true,
      ),
    ],
  ),
  'weapon master': const ProficiencyGrant(
    choices: [ProficiencyChoice(type: ProficiencyType.weaponMastery, count: 1)],
  ),
};

/// Adiyla verilen bir SINIF OZELLIGININ getirdigi yeterlilikler.
///
/// Cekirdek ozellik tablosunun disinda kalan, dil veren uc ozellik.
ProficiencyGrant classFeatureProficiencies(String featureName) =>
    _classFeatureGrants[_key(featureName)] ?? const ProficiencyGrant();

final _classFeatureGrants = <String, ProficiencyGrant>{
  'druidic': const ProficiencyGrant(languages: {'Druidic'}),
  "thieves' cant": const ProficiencyGrant(languages: {"Thieves' Cant"}),
  // "**Languages.** You know two languages of your choice."
  'deft explorer': const ProficiencyGrant(
    choices: [ProficiencyChoice(type: ProficiencyType.language, count: 2)],
  ),
};

/// Karakter [proficiencies] kumesiyle, ozellikleri [properties] olan bir
/// silahi kullanmakta yeterli mi?
///
/// [category] silahin "Simple"/"Martial" sinifi, [name] tam adi (tek tek
/// verilen silah yeterlilikleri icin).
bool weaponAllowedBy(
  Set<String> proficiencies, {
  required String category,
  required String name,
  Set<String> properties = const {},
}) {
  if (proficiencies.contains(name)) return true;
  final simple = _key(category) == 'simple';
  if (simple) return proficiencies.contains(WeaponProficiency.simple);

  if (proficiencies.contains(WeaponProficiency.martial)) return true;
  final lower = properties.map(_key).toSet();
  if (proficiencies.contains(WeaponProficiency.martialLight)) {
    if (lower.contains('light')) return true;
  }
  if (proficiencies.contains(WeaponProficiency.martialFinesseOrLight)) {
    if (lower.contains('light') || lower.contains('finesse')) return true;
  }
  return false;
}
