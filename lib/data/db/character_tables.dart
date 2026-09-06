import 'package:drift/drift.dart';

/// Karakterin sahip oldugu bir yeterliligin turu.
/// `weaponMastery` bir yeterlilik degil, 2024'un silah ustaligi secimi
/// (secilen silahin Topple/Vex gibi mastery ozelligini kullanma hakki). Ayni
/// tabloda duruyor cunku o da kaynagi ve seviyesi olan bir secim listesi.
///
/// Yeni deger eklemek migration gerektirmiyor: sutun METIN ve `EnumNameConverter`
/// `.values` uzerinden calisiyor; eski satirlar etkilenmez.
enum ProficiencyKind {
  skill,
  save,
  tool,
  language,
  armor,
  weapon,
  weaponMastery,
}

/// Bir yeterliligin nereden geldigi. Level dususte ya da background
/// degistiginde neyin geri alinacagini bilmek icin kaynak saklaniyor.
enum ProficiencySource { species, background, characterClass, feat, manual }

class Characters extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// Bu karakteri masada oynayan kisinin adi; DM listede kimin kagidi
  /// oldugunu gormek icin yaziyor. Serbest metin, bos birakilabilir.
  TextColumn get playerName => text().nullable()();

  TextColumn get speciesKey => text().nullable()();
  TextColumn get backgroundKey => text().nullable()();
  TextColumn get alignment => text().nullable()();

  /// Irk/background/ASI etkileri UYGULANMIS nihai puanlar. Sihirbaz bunlari
  /// hesaplayip yaziyor; kagit uzerinde tek dogruluk kaynagi bu olsun diye
  /// "taban puan + bonuslar" ayrimi tasinmiyor.
  IntColumn get strength => integer().withDefault(const Constant(10))();
  IntColumn get dexterity => integer().withDefault(const Constant(10))();
  IntColumn get constitution => integer().withDefault(const Constant(10))();
  IntColumn get intelligence => integer().withDefault(const Constant(10))();
  IntColumn get wisdom => integer().withDefault(const Constant(10))();
  IntColumn get charisma => integer().withDefault(const Constant(10))();

  IntColumn get experiencePoints => integer().withDefault(const Constant(0))();

  IntColumn get hitPointsMax => integer().withDefault(const Constant(0))();
  IntColumn get hitPointsCurrent => integer().withDefault(const Constant(0))();
  IntColumn get temporaryHitPoints =>
      integer().withDefault(const Constant(0))();

  /// Basarili/basarisiz olum kurtarma atislari (0-3).
  IntColumn get deathSaveSuccesses =>
      integer().withDefault(const Constant(0))();
  IntColumn get deathSaveFailures => integer().withDefault(const Constant(0))();

  /// 2024 kurallarinda her seviye d20 atislarina -1 veriyor.
  IntColumn get exhaustion => integer().withDefault(const Constant(0))();
  BoolColumn get inspiration => boolean().withDefault(const Constant(false))();

  /// Cebindeki para, bakir cinsinden.
  IntColumn get coinsCp => integer().withDefault(const Constant(0))();

  /// Zirh/kalkan disi bir kaynaktan gelen AC (or. sihirli etki). Doluysa
  /// hesaplanan degerin yerine gecer.
  IntColumn get armorClassOverride => integer().nullable()();
  IntColumn get speedOverride => integer().nullable()();

  /// Aktif durum efektleri (JSON dizisi).
  TextColumn get conditionsJson => text().withDefault(const Constant('[]'))();

  /// Harcanmis hit dice: sinif anahtari -> adet.
  TextColumn get hitDiceUsedJson => text().withDefault(const Constant('{}'))();

  /// Oyuncunun hazir buyu listesinde kac degisiklik yapabilecegi.
  ///
  /// Uzun dinlenmede (Cleric/Druid/Paladin/Wizard/Artificer) listenin tamami
  /// kadar, seviye atlayinca (Bard/Ranger/Sorcerer/Warlock) bir tane veriliyor.
  /// Bos yere yeni buyu eklemek hak harcamaz; yalnizca SECILI bir buyuyu
  /// listeden cikarmak harcar.
  IntColumn get spellChangesAvailable =>
      integer().withDefault(const Constant(0))();

  /// Su an konsantrasyon tutulan buyunun adi; yoksa null.
  ///
  /// Hasar alinca CON kurtarmasi gerektigi icin masada takip edilmesi gereken
  /// tek "acik buyu" bilgisi bu.
  TextColumn get concentrationSpell => text().nullable()();

  /// Ekipman yuvasi sinirlarindan VARSAYILANDAN FARKLI olanlar
  /// (`EquipSlot.name` -> adet, -1 sinirsiz). Yalnizca elle degistirilenler
  /// yaziliyor ki varsayilan degisirse dokunulmamis yuvalar onu izlesin.
  TextColumn get slotCapacitiesJson =>
      text().withDefault(const Constant('{}'))();

  /// Harcanmis buyu yuvalari: yuva seviyesi -> adet.
  TextColumn get spellSlotsUsedJson =>
      text().withDefault(const Constant('{}'))();

  TextColumn get portraitPath => text().nullable()();

  /// Serbest hikaye/gecmis metni.
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// 2024 kagidindaki kisilik alanlari ve gorunus tarifi.
  TextColumn get appearance => text().withDefault(const Constant(''))();
  TextColumn get personality => text().withDefault(const Constant(''))();
  TextColumn get ideal => text().withDefault(const Constant(''))();
  TextColumn get bond => text().withDefault(const Constant(''))();
  TextColumn get flaw => text().withDefault(const Constant(''))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Karakterin sinif seviyeleri. Multiclass'ta birden fazla satir olur;
/// [order] hangi sinifin ilk alindigini tutar (baslangic yeterlilikleri
/// yalnizca ilk siniftan gelir).
class CharacterClassLevels extends Table {
  TextColumn get characterId => text().references(Characters, #id)();
  TextColumn get classKey => text()();
  TextColumn get subclassKey => text().nullable()();
  IntColumn get level => integer().withDefault(const Constant(1))();
  IntColumn get order => integer().withDefault(const Constant(0))();

  /// Her seviyede atilan/alinan HP artislari (JSON dizisi). Level dususte
  /// dogru miktari geri alabilmek icin tek tek saklaniyor.
  TextColumn get hitPointRollsJson =>
      text().withDefault(const Constant('[]'))();

  @override
  Set<Column> get primaryKey => {characterId, classKey};
}

class CharacterProficiencies extends Table {
  TextColumn get characterId => text().references(Characters, #id)();
  TextColumn get kind => textEnum<ProficiencyKind>()();

  /// Yetenek/beceri anahtari, or. `perception`, `dexterity`, `thieves-tools`.
  TextColumn get value => text()();

  /// Uzmanlik (expertise): yeterlilik bonusu iki katina cikar.
  BoolColumn get expertise => boolean().withDefault(const Constant(false))();
  TextColumn get source =>
      textEnum<ProficiencySource>().withDefault(const Constant('manual'))();

  @override
  Set<Column> get primaryKey => {characterId, kind, value};
}

class CharacterItems extends Table {
  TextColumn get id => text()();
  TextColumn get characterId => text().references(Characters, #id)();

  /// Kutuphanedeki esyanin anahtari; elle yazilan esyalarda bos olur.
  TextColumn get itemKey => text().nullable()();
  TextColumn get magicItemKey => text().nullable()();

  /// Kutuphanede karsiligi olmayan esyalar icin serbest metin.
  TextColumn get customName => text().nullable()();
  TextColumn get customDesc => text().nullable()();

  IntColumn get quantity => integer().withDefault(const Constant(1))();
  BoolColumn get equipped => boolean().withDefault(const Constant(false))();

  /// Kusanildiginda kapladigi yuva (`EquipSlot.name`); bos ise esyanin
  /// kendisinden tahmin edilir. Elle degistirilebilsin diye saklaniyor:
  /// "Boots of Speed"i kemer yuvasina koymak isteyen DM'e engel yok.
  TextColumn get slot => text().nullable()();
  BoolColumn get attuned => boolean().withDefault(const Constant(false))();

  /// Envanterde el ile siralama.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class CharacterSpells extends Table {
  TextColumn get characterId => text().references(Characters, #id)();
  TextColumn get spellKey => text()();

  /// Hangi sinif uzerinden biliniyor; buyu DC'si ve multiclass yuvalari
  /// icin gerekli.
  TextColumn get classKey => text().nullable()();
  BoolColumn get prepared => boolean().withDefault(const Constant(false))();

  /// Her zaman hazir sayilanlar (domain buyuleri, feat kaynakli vb.);
  /// hazirlanan buyu limitine dahil edilmez.
  BoolColumn get alwaysPrepared =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {characterId, spellKey};
}

/// Karakterin sahip oldugu yetenekler. Cogu sinif/tur verisinden turetilir
/// ama DM elle de ekleyebildigi icin ayri tabloda tutuluyor.
class CharacterFeatures extends Table {
  TextColumn get id => text()();
  TextColumn get characterId => text().references(Characters, #id)();

  /// Kutuphanedeki feature/feat anahtari; homebrew'da bos.
  TextColumn get featureKey => text().nullable()();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();

  /// Nereden geldigi: sinif anahtari, tur anahtari, `feat`, `manual`.
  TextColumn get source => text().withDefault(const Constant('manual'))();
  IntColumn get gainedAtLevel => integer().nullable()();

  /// Sinirli kullanimli yetenekler icin (or. Second Wind 1/kisa dinlenme).
  IntColumn get usesMax => integer().nullable()();
  IntColumn get usesSpent => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
