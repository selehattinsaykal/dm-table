import 'package:drift/drift.dart';

/// Savastaki bir katilimcinin ne oldugu.
enum CombatantKind {
  /// Oyuncu karakteri; HP ve durumlar karakter kagidiyla ortak.
  player,

  /// Kutuphaneden ya da homebrew'dan gelen canavar.
  monster,

  /// Isim ve initiative disinda verisi olmayan hizli giris.
  adhoc,
}

class Encounters extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// Suan kimin sirasi: [Combatants.sortOrder] degeri.
  IntColumn get activeIndex => integer().withDefault(const Constant(0))();
  IntColumn get round => integer().withDefault(const Constant(1))();

  /// Savas basladi mi? Baslamadan once initiative duzenlenebiliyor.
  BoolColumn get started => boolean().withDefault(const Constant(false))();

  /// Karsilasmanin DM BRIFINGI: kazanma kosulu, taktikler, arazi, takviye,
  /// zorluk ayari, sahne metni, DM notu.
  ///
  /// Tek JSON sutun, yedi ayri sutun degil: alanlarin hepsi serbest metin,
  /// hicbiri sorgulanmiyor ve AI ureteci hepsini birlikte uretiyor. Ayri
  /// sutunlar sema yuzeyini bes katina cikarip hicbir sey kazandirmazdi.
  /// Bicim: `{"objective":"...","tactics":"...", ...}` (bkz.
  /// `CombatRepository.briefingOf`).
  TextColumn get briefingJson => text().nullable()();

  /// Savastan cikacak GANIMET: para + esyalar.
  ///
  /// Bicim gorev odul havuzuyla ayni (`{"coinsCp":0,"items":[...]}`) ama her
  /// esya ayrica kutuphaneye COZULMUS anahtarini tasir:
  /// `{"id","name","magic","itemKey","magicItemKey"}`. Anahtarlar null ise
  /// esya kutuphanede bulunamamis demektir ve arayuz bunu isaretler — DM
  /// uydurma bir esyayi gercek sanmasin.
  TextColumn get lootJson => text().nullable()();

  /// Tur suresi siniri (saniye); null = sinirsiz.
  ///
  /// Karsilasma basina saklaniyor: bir arena dovusunde 60 saniye, bir kusatma
  /// sahnesinde sinirsiz istenebiliyor.
  IntColumn get turnLimitSeconds => integer().nullable()();

  /// In (lair) eylemi metni; null = bu karsilasmada in eylemi yok.
  TextColumn get lairActionText => text().nullable()();

  /// In eyleminin tetiklendigi inisiyatif degeri (kural: 20).
  IntColumn get lairInitiative => integer().withDefault(const Constant(20))();

  /// Karsilasmanin GECTIGI yer (`Locations.id`); null = bir yere baglanmadi.
  ///
  /// FK TANIMLANMADI, projedeki diger gevsek baglar gibi: yer silinince
  /// karsilasma kaybolmamali, cozumleme okuma aninda yapiliyor ve yer yoksa
  /// arayuz bagi "kopuk" gosteriyor.
  TextColumn get locationId => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Kaydedilmis karsilasma kalibi: "6 goblin + 1 hobgoblin sefi".
///
/// Hazirlik yapan DM ayni grubu defalarca elle kuruyordu. Kalip yalnizca
/// KADROYU tasiyor (kim, kac tane); can/inisiyatif kurulurken yeniden
/// atiliyor -- yoksa ayni kalibi iki kez kuran DM ayni can degerlerini alirdi.
class EncounterTemplates extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// Kadro: `[{"kind":"monster","key":"...","name":"...","count":6}, ...]`.
  TextColumn get entriesJson => text().withDefault(const Constant('[]'))();

  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Combatants extends Table {
  TextColumn get id => text()();
  TextColumn get encounterId => text().references(Encounters, #id)();

  TextColumn get kind => textEnum<CombatantKind>()();
  TextColumn get name => text()();

  /// Oyuncu karakterlerinde karakter kaydi, canavarlarda kutuphane anahtari.
  TextColumn get characterId => text().nullable()();
  TextColumn get monsterKey => text().nullable()();

  IntColumn get initiative => integer().withDefault(const Constant(0))();

  /// Esit initiative'de sirayi sabitlemek icin; ayrica surukleyerek
  /// yeniden siralamada kullanilir.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  IntColumn get hitPointsMax => integer().withDefault(const Constant(0))();
  IntColumn get hitPointsCurrent => integer().withDefault(const Constant(0))();
  IntColumn get temporaryHitPoints =>
      integer().withDefault(const Constant(0))();
  IntColumn get armorClass => integer().nullable()();

  /// Aktif durumlar (JSON dizisi).
  TextColumn get conditionsJson => text().withDefault(const Constant('[]'))();

  /// Tur basina efsanevi eylem hakki; null = bu katilimcinin efsanevi eylemi
  /// yok. Veri setinde hak sayisi YAZMADIGI icin canavar eklenirken
  /// [kDefaultLegendaryActionsPerRound] ile doldurulur, DM degistirebilir.
  IntColumn get legendaryMax => integer().nullable()();

  /// Bu turda harcanan efsanevi eylem; katilimcinin turu BASLAYINCA sifirlanir
  /// (D&D kurali: efsanevi eylemler canavarin turunun basinda tazelenir).
  IntColumn get legendarySpent => integer().withDefault(const Constant(0))();

  /// Gunluk efsanevi direnc (Legendary Resistance N/Day); null = yok.
  /// Tur basinda SIFIRLANMAZ -- gunluk bir kaynak, DM elle yeniler.
  IntColumn get legendaryResistMax => integer().nullable()();
  IntColumn get legendaryResistSpent =>
      integer().withDefault(const Constant(0))();

  /// Konsantrasyon takibi: DM'in en cok unuttugu sey.
  BoolColumn get concentrating =>
      boolean().withDefault(const Constant(false))();
  TextColumn get concentrationNote => text().nullable()();

  /// Bu turda REAKSIYONUNU kullandi mi?
  ///
  /// Masada en cok unutulan kaynak: reaksiyon tur basina bir tanedir ve
  /// katilimcinin SIRASI GELINCE tazelenir (D&D kurali: "tur basinizin
  /// baslangicina kadar"). [CombatRepository.advanceTurn] sifirliyor.
  BoolColumn get reactionUsed => boolean().withDefault(const Constant(false))();

  /// Hasar turu savunmalari: `{"resist":[],"immune":[],"vulnerable":[]}`.
  ///
  /// Canavar eklenirken kutuphane verisinden dolduruluyor; DM elle
  /// duzenleyebiliyor. Tek JSON sutun cunku uc liste de yalnizca hasar
  /// uygulanirken birlikte okunuyor, hicbiri ayri sorgulanmiyor.
  TextColumn get defensesJson => text().withDefault(const Constant('{}'))();

  /// Olum kurtarma atislari.
  ///
  /// Oyuncu karakterlerinde karakter kaydiyla ESITLENIR (orasi ana kayit);
  /// canavar/adhoc katilimcilar icin tek yer burasi. Can 0'a dusunce arayuz
  /// sayaci kendiliginden aciyor.
  IntColumn get deathSaveSuccesses =>
      integer().withDefault(const Constant(0))();
  IntColumn get deathSaveFailures => integer().withDefault(const Constant(0))();

  BoolColumn get defeated => boolean().withDefault(const Constant(false))();
  TextColumn get note => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}
