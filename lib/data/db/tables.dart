import 'package:drift/drift.dart';

/// Bir kaydin nereden geldigi. Kutuphane ekraninda filtre, lisans ekraninda
/// atif, disa aktarmada ise neyin paketlenebilecegi buna gore belirlenir.
enum SourceType {
  /// System Reference Document 5.2 — CC-BY 4.0.
  srd,

  /// Open5e uzerinden gelen diger acik lisansli setler.
  ogl,

  /// DM'in kendi kitapligindan ice aktardigi icerik. Cihazda kalir,
  /// disa aktarma paketlerine ASLA dahil edilmez.
  personal,

  /// Uygulama icinde sifirdan olusturulan homebrew.
  custom,
}

/// Ortak kolonlar: her kutuphane kaydi bir anahtar, aranabilir bir ad ve
/// kaynagiyla gelir.
///
/// Nadiren sorgulanan derin alanlar (`actions`, `traits`, `casting_options`...)
/// tek tek kolona acilmak yerine [dataJson] icinde ham haliyle durur. Open5e
/// semasi degistiginde migration yazmak yerine detay gorunumunu guncellemek
/// yetiyor; filtreye giren alanlar ise asagida gercek kolon.
mixin CompendiumEntry on Table {
  TextColumn get key => text()();
  TextColumn get name => text()();

  /// Aksan/buyuk-kucuk harf duyarsiz arama icin onceden normalize edilmis ad.
  TextColumn get nameLower => text()();

  /// Open5e dokuman anahtari (or. `srd-2024`).
  TextColumn get document => text().nullable()();
  TextColumn get sourceType =>
      textEnum<SourceType>().withDefault(const Constant('srd'))();

  /// Kaydin Open5e'den gelen tam JSON govdesi.
  TextColumn get dataJson => text()();

  @override
  Set<Column> get primaryKey => {key};
}

class Monsters extends Table with CompendiumEntry {
  TextColumn get creatureType => text().nullable()();
  TextColumn get size => text().nullable()();

  /// 1/8, 1/4, 1/2 gibi degerler oldugu icin ondalik.
  RealColumn get challengeRating => real().withDefault(const Constant(0))();
  IntColumn get armorClass => integer().nullable()();
  IntColumn get hitPoints => integer().nullable()();
  IntColumn get experiencePoints => integer().nullable()();

  /// Karsilasma kurarken ortama gore filtrelemek icin virgulle ayrilmis liste.
  TextColumn get environmentsCsv => text().withDefault(const Constant(''))();

  /// DM'in ekledigi portre gorseli (uygulama klasorune gore goreli yol);
  /// karakter portreleri gibi dosyada saklanir, veritabanina gomulmez.
  TextColumn get portraitPath => text().nullable()();
}

class Spells extends Table with CompendiumEntry {
  IntColumn get level => integer().withDefault(const Constant(0))();
  TextColumn get school => text().nullable()();
  TextColumn get castingTime => text().nullable()();
  BoolColumn get concentration =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get ritual => boolean().withDefault(const Constant(false))();

  /// Hangi siniflarin listesinde oldugu; karakter kagidinda buyu secerken
  /// filtrelemek icin virgulle ayrilmis sinif anahtarlari.
  TextColumn get classesCsv => text().withDefault(const Constant(''))();
}

/// Buyusuz esyalar. Fiyatlar SRD'de altin cinsinden ondalikli metin geliyor;
/// kurus hatasi birikmesin diye bakir (cp) tamsayisina cevrilip saklanir.
class Items extends Table with CompendiumEntry {
  TextColumn get category => text().nullable()();
  IntColumn get costCp => integer().nullable()();
  RealColumn get weightLb => real().nullable()();
}

/// Buyulu esyalar.
///
/// DIKKAT: SRD 5.2 buyulu esyalar icin fiyat yayinlamaz — API'deki `cost`
/// alani tumunde "0.00" gelir. [costCp] bu yuzden nadirlikten turetilen
/// ONERILEN fiyattir ve DM magaza bazinda ezebilir; [costIsSuggested] bunu
/// arayuzde belirtmek icin tutulur.
class MagicItems extends Table with CompendiumEntry {
  TextColumn get category => text().nullable()();
  TextColumn get rarity => text().nullable()();
  IntColumn get rarityRank => integer().nullable()();
  BoolColumn get requiresAttunement =>
      boolean().withDefault(const Constant(false))();
  IntColumn get costCp => integer().nullable()();
  BoolColumn get costIsSuggested =>
      boolean().withDefault(const Constant(true))();
}

/// Siniflar ve alt siniflar ayni tabloda; [subclassOf] dolu olanlar alt sinif.
///
/// Adi bilerek `ClassDefinitions`: bir karakterin sahip oldugu seviyeleri
/// tutan `character_classes` tablosu Faz 1a'da ayrica gelecek.
@DataClassName('ClassDefinition')
class ClassDefinitions extends Table with CompendiumEntry {
  TextColumn get subclassOf => text().nullable()();
  TextColumn get hitDice => text().nullable()();
  TextColumn get casterType => text().nullable()();
}

@DataClassName('SpeciesEntry')
class SpeciesEntries extends Table with CompendiumEntry {
  BoolColumn get isSubspecies => boolean().withDefault(const Constant(false))();
  TextColumn get subspeciesOf => text().nullable()();
}

/// Sinif ilerleme tablosu: her sinifin her seviyesi icin tek satir.
///
/// Elle yazilmaz — SRD 5.2 sinif kayitlarindaki `data_for_class_table` ve
/// `gained_at` alanlarindan ice aktarma sirasinda turetilir (bkz.
/// `lib/data/import/class_progression_builder.dart`). Level atlama akisinin
/// tek dogruluk kaynagi burasidir.
class ClassProgressions extends Table {
  TextColumn get classKey => text()();
  IntColumn get level => integer()();
  IntColumn get proficiencyBonus => integer()();

  /// Yuva seviyesi -> adet, or. `{"1":4,"2":3,"3":2}`. Buyu yapmayan
  /// siniflarda bos nesne.
  TextColumn get spellSlotsJson => text().withDefault(const Constant('{}'))();

  /// Sinifa ozel tablo sutunlari, or. `{"Rages":3,"Rage Damage":"+2"}`.
  TextColumn get classTableJson => text().withDefault(const Constant('{}'))();

  /// Bu seviyede kazanilan feature anahtarlari.
  TextColumn get featureKeysJson => text().withDefault(const Constant('[]'))();

  @override
  Set<Column> get primaryKey => {classKey, level};
}

class Backgrounds extends Table with CompendiumEntry {}

class Feats extends Table with CompendiumEntry {}

/// Kucuk referans tablolarinin (conditions, damage types, sizes, skills...)
/// tamami tek tabloda; hepsi ayni sekle sahip ve tek tek tablo acmak
/// migration yukunu bosuna artirirdi.
class ReferenceEntries extends Table {
  /// Hangi referans kumesi: `conditions`, `damagetypes`, `skills`, ...
  TextColumn get kind => text()();
  TextColumn get key => text()();
  TextColumn get name => text()();
  TextColumn get dataJson => text()();

  @override
  Set<Column> get primaryKey => {kind, key};
}

/// Paketlenmis veri setinin hangi surumunun ice aktarildigini tutar; acilista
/// asset guncel mi diye buna bakilir.
class ContentVersions extends Table {
  TextColumn get id => text()();
  TextColumn get fetchedAt => text()();
  IntColumn get schemaVersion => integer()();
  TextColumn get manifestJson => text()();

  @override
  Set<Column> get primaryKey => {id};
}
