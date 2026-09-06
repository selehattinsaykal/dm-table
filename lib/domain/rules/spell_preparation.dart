/// Oyuncunun kendi buyulerini secmesi icin kurallar.
///
/// 2024 kurallarinda her buyucu sinifin tablosunda iki sutun var: `Cantrips`
/// ve `Prepared Spells`. Kac buyu tasiyabilecegi oradan geliyor; hangilerini
/// secebilecegi ise sinifin buyu listesinden ve acik olan en yuksek yuva
/// seviyesinden.
///
/// Listeyi NE ZAMAN degistirebildigi sinifa gore degisiyor:
///   * Cleric, Druid, Paladin, Wizard, Artificer — her uzun dinlenmede.
///   * Bard, Ranger, Sorcerer, Warlock — seviye atladikca bir buyu.
/// Bu hakki olmayan sinifta secim ekrani hic acilmiyor.
///
/// Hak sayaci ([Character.spellChangesAvailable]) yalnizca DEGISTIRMEDE
/// harcaniyor: sinir buyudugu icin bos kalan yere yeni buyu eklemek (yeni
/// seviyede gelenler) her zaman serbest.
library;

/// Hazir buyu listesinin ne zaman degistirilebildigi.
enum SpellChangePolicy {
  /// Uzun dinlenmede liste bastan kurulabilir.
  longRest,

  /// Seviye atladikca bir buyu degistirilebilir.
  levelUp,

  /// Sinif boyle bir hak vermiyor (buyu yapmayan siniflar).
  none;

  static SpellChangePolicy forClass(String classKey) {
    // Anahtar "srd-2024_wizard" / "eberron-forge_artificer" bicimindedir.
    final slug = classKey.split('_').last;
    return switch (slug) {
      'cleric' ||
      'druid' ||
      'paladin' ||
      'wizard' ||
      'artificer' => SpellChangePolicy.longRest,
      'bard' ||
      'ranger' ||
      'sorcerer' ||
      'warlock' => SpellChangePolicy.levelUp,
      _ => SpellChangePolicy.none,
    };
  }
}

/// Buyu defteri tutan siniflar ve defterin buyuklugu.
///
/// 2024 Wizard'in Spellcasting yetenegi: defter 1. seviyede ALTI buyuyle
/// baslar, her Wizard seviyesinde IKI buyu daha eklenir. Sinif tablosunda
/// boyle bir sutun yok, sayi yetenegin metninde geciyor; bu yuzden kural
/// burada sabit.
///
/// Hazir buyuler defterden secilir -- sinifin tum listesinden degil. Deftere
/// ne konacagi ise sinif listesinden ve hazirlanabilecek seviyeden secilir.
class SpellbookRules {
  const SpellbookRules._();

  /// Defter tutan siniflar (anahtarin son parcasi).
  static const _classes = {'wizard'};

  static bool usesSpellbook(String classKey) =>
      _classes.contains(classKey.split('_').last);

  /// Defterin o seviyedeki buyuklugu; defter tutmayan sinifta 0.
  static int size(String classKey, int level) =>
      usesSpellbook(classKey) ? 6 + 2 * (level - 1) : 0;
}

/// Bir sinifin buyu secim durumu.
class SpellPreparation {
  const SpellPreparation({
    required this.classKey,
    required this.className,
    required this.level,
    required this.cantripLimit,
    required this.preparedLimit,
    required this.maxSpellLevel,
    required this.policy,
    required this.cantrips,
    required this.prepared,
    required this.changesAvailable,
    this.spellbook = const {},
    this.spellbookLimit = 0,
  });

  final String classKey;
  final String className;
  final int level;

  /// Tablodaki `Cantrips` sutunu; sutun yoksa 0 (Paladin, Ranger).
  final int cantripLimit;

  /// Tablodaki `Prepared Spells` sutunu.
  final int preparedLimit;

  /// Acik olan en yuksek buyu yuvasi seviyesi.
  final int maxSpellLevel;

  final SpellChangePolicy policy;

  /// Secili cantrip anahtarlari.
  final Set<String> cantrips;

  /// Secili (daima hazir OLMAYAN) buyu anahtarlari.
  final Set<String> prepared;

  /// Kalan degistirme hakki.
  final int changesAvailable;

  /// Buyu defterindeki buyuler (cantrip'ler defterde tutulmaz).
  final Set<String> spellbook;

  /// Defterin buyuklugu; defter tutmayan sinifta 0.
  final int spellbookLimit;

  bool get usesSpellbook => spellbookLimit > 0;

  bool get canChoose => policy != SpellChangePolicy.none && preparedLimit > 0;

  int get cantripsFree => cantripLimit - cantrips.length;
  int get preparedFree => preparedLimit - prepared.length;
}

/// Yeni secimin kurallara uygunlugu.
sealed class SpellSelectionResult {
  const SpellSelectionResult();
}

/// Secim gecerli; [changesSpent] kadar degistirme hakki harcanir.
class SpellSelectionAccepted extends SpellSelectionResult {
  const SpellSelectionAccepted({required this.changesSpent});

  final int changesSpent;
}

/// Secim reddedildi.
class SpellSelectionRejected extends SpellSelectionResult {
  const SpellSelectionRejected(this.reason);

  final SpellSelectionError reason;
}

enum SpellSelectionError {
  /// Sinif boyle bir secim yapmiyor.
  notAllowed,

  /// Secilen buyu sinifin listesinde degil.
  unknownSpell,

  /// Karakterin acik yuvasindan yuksek seviyeli buyu.
  spellLevelTooHigh,

  /// Cantrip ya da hazir buyu sayisi sinirin ustunde.
  overLimit,

  /// Degistirme hakki kalmadi (uzun dinlenme / seviye bekleniyor).
  noChangesLeft,
}

/// Deftere yazilacak listeyi dogrular.
///
/// Defter yalnizca sinif listesinden ve HAZIRLANABILECEK seviyeden buyu alir;
/// buyuklugu seviyeye bagli. Defterden buyu cikarmak degistirme hakki
/// harcamaz: defter oyuncunun kendi mulku, kural sinirini `spellbookLimit`
/// zaten koyuyor.
SpellSelectionResult validateSpellbook({
  required SpellPreparation current,
  required Set<String> next,
  required Map<String, int> allowed,
}) {
  if (!current.usesSpellbook) {
    return const SpellSelectionRejected(SpellSelectionError.notAllowed);
  }
  for (final key in next) {
    final level = allowed[key];
    if (level == null || level == 0) {
      return const SpellSelectionRejected(SpellSelectionError.unknownSpell);
    }
    if (level > current.maxSpellLevel) {
      return const SpellSelectionRejected(
        SpellSelectionError.spellLevelTooHigh,
      );
    }
  }
  if (next.length > current.spellbookLimit) {
    return const SpellSelectionRejected(SpellSelectionError.overLimit);
  }
  return const SpellSelectionAccepted(changesSpent: 0);
}

/// Oyuncunun gonderdigi listeyi dogrular.
///
/// [allowed] secilebilecek buyulerin anahtar -> seviye eslemesi. Defter tutan
/// siniflarda (Wizard) bu liste DEFTERIN kendisidir; cantrip'ler her zaman
/// sinif listesinden gelir.
///
/// Bos yeri doldurmak bedava; SECILI bir buyuyu listeden cikarmak bir hak
/// harciyor — kural masasinda "bugun sunu degistiriyorum" demek bu.
SpellSelectionResult validateSpellSelection({
  required SpellPreparation current,
  required Set<String> nextCantrips,
  required Set<String> nextPrepared,
  required Map<String, int> allowed,
}) {
  if (!current.canChoose) {
    return const SpellSelectionRejected(SpellSelectionError.notAllowed);
  }

  for (final key in {...nextCantrips, ...nextPrepared}) {
    final level = allowed[key];
    if (level == null) {
      return const SpellSelectionRejected(SpellSelectionError.unknownSpell);
    }
    if (level == 0 && !nextCantrips.contains(key)) {
      return const SpellSelectionRejected(SpellSelectionError.unknownSpell);
    }
    if (level > 0 && level > current.maxSpellLevel) {
      return const SpellSelectionRejected(
        SpellSelectionError.spellLevelTooHigh,
      );
    }
  }
  if (nextCantrips.any((k) => allowed[k] != 0)) {
    return const SpellSelectionRejected(SpellSelectionError.unknownSpell);
  }

  if (nextCantrips.length > current.cantripLimit ||
      nextPrepared.length > current.preparedLimit) {
    return const SpellSelectionRejected(SpellSelectionError.overLimit);
  }

  final removed =
      current.cantrips.difference(nextCantrips).length +
      current.prepared.difference(nextPrepared).length;
  if (removed > current.changesAvailable) {
    return const SpellSelectionRejected(SpellSelectionError.noChangesLeft);
  }

  return SpellSelectionAccepted(changesSpent: removed);
}
