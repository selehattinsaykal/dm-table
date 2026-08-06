import 'package:drift/drift.dart';

/// Suren bir yolculuk.
///
/// Seyahat eskiden tek seferlik bir hesaptı ("uygula" -> takvim ilerler, biter).
/// Rastgele karsilasmalar yolu BOLDUGU icin artik durumu olan bir sey: parti
/// yolun bir yerinde durur, DM masada karsilasmayi oynatir (savas ekranina
/// gider, geri doner), sonra "Devam et" der.
///
/// Bu yuzden veritabaninda duruyor: sheet kapanabilmeli, uygulama baska bir
/// sekmeye gecebilmeli, hatta kapanip acilabilmeli — yolculuk kaybolmamali.
///
/// Ayni anda YALNIZCA BIR aktif yolculuk olur ([done] == false); yeni yolculuk
/// baslatmak oncekini kapatir (bkz. `JourneyRepository.start`).
class Journeys extends Table {
  TextColumn get id => text()();

  /// Rotanin cizildigi harita (yer). Olcek oradan okunur.
  TextColumn get locationId => text()();

  /// Duraklar: `[{"x":0.1,"y":0.2,"label":"Kale","pinId":"..."}]`.
  ///
  /// Pin id'si SAKLANIR ama koordinat da yazilir: durak haritadan serbestce
  /// tiklanmis bir ara nokta olabilir (pini yoktur) ve pin sonradan silinse
  /// bile yolculugun uzunlugu degismemelidir.
  TextColumn get stopsJson => text().withDefault(const Constant('[]'))();

  /// Haritada karsiligi olmayan elle girilen ek mesafe.
  RealColumn get extraMiles => real().withDefault(const Constant(0))();

  // --- Hiz ----------------------------------------------------------------
  /// `TravelSpeed.key`; ozel hizda `travelCustomSpeed`.
  TextColumn get speedKey =>
      text().withDefault(const Constant('travelPaceNormal'))();

  /// Ozel hizin mil/saat degeri (yalnizca ozel hizda anlamli).
  RealColumn get customMph => real().nullable()();
  RealColumn get hoursPerDay => real().withDefault(const Constant(8))();

  // --- Karsilasma ayarlari -------------------------------------------------
  BoolColumn get encountersOn => boolean().withDefault(const Constant(false))();
  TextColumn get tableId => text().nullable()();
  IntColumn get threshold => integer().withDefault(const Constant(18))();
  IntColumn get checksPerDay => integer().withDefault(const Constant(1))();

  // --- Ilerleme ------------------------------------------------------------
  /// Rotanin toplam uzunlugu (mil). Baslangicta hesaplanip DONDURULUR: harita
  /// olcegi ya da pinler yolculuk sirasinda degisse de "kalan yol" tutarsiz
  /// olmasin.
  RealColumn get totalMiles => real().withDefault(const Constant(0))();

  /// Su ana kadar gidilen yol (mil).
  RealColumn get milesTravelled => real().withDefault(const Constant(0))();

  /// Kac karsilasma kontrolu yapildi. Sonraki dilimin nerede basladigini
  /// belirler; [milesTravelled]'dan TURETILEMEZ cunku karsilasma bir dilimin
  /// ORTASINDA olur.
  IntColumn get checksDone => integer().withDefault(const Constant(0))();

  /// Takvime simdiye kadar islenmis gun sayisi. Her adimda yalnizca FARK
  /// ilerletilir; yoksa duraklayip devam eden yolculuk gunleri iki kez sayardi.
  IntColumn get daysAdvanced => integer().withDefault(const Constant(0))();

  /// Ilerledikce takvim de ilerlesin mi?
  BoolColumn get advanceCalendar =>
      boolean().withDefault(const Constant(true))();

  /// Partiyi DURDURAN karsilasma:
  /// `{"day":2,"checkIndex":1,"check":19,"tableRoll":7,"text":"..."}`.
  /// Null = yolda serbest ilerleniyor.
  TextColumn get pendingEncounterJson => text().nullable()();

  /// Yolculuk boyunca yasanan tum karsilasmalar (ayni bicimde bir dizi).
  /// Varista oturum gunlugune bu liste yazilir.
  TextColumn get encounterLogJson => text().withDefault(const Constant('[]'))();

  BoolColumn get done => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
