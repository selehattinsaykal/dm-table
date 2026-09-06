import 'package:drift/drift.dart';

/// Saatin neye bagli oldugu.
///
/// Bir saat tek basina da anlamli ("Kis yaklasiyor") ama cogu zaman bir seyin
/// sayacidir: bir gorevin suresi, bir orgutun plani, bir yerin cokusu. Bagli
/// oldugu kayit acildiginda saat orada da gorunsun diye tur + kimlik
/// saklaniyor.
enum ClockLinkKind { none, quest, faction, location, npc }

/// Dilimli ilerleme saati ("progress clock").
///
/// **Neden var:** masada surekli "su kadar daha" diye tutulan seyler vardi ve
/// hicbirinin yeri yoktu: kusatma kac gunde gelir, tarikat ayini ne zaman
/// tamamlar, sehir muhafizi partiyi ne zaman fark eder. DM bunlari kagida
/// cizik atarak takip ediyordu.
///
/// Model bilincli olarak MINIMAL: [segments] toplam dilim, [filled] dolu
/// dilim. Yon, hiz, otomatik ilerleme yok -- saat bir kural motoru degil,
/// gorunur bir sayac. Ilerletmeyi her zaman DM yapar.
class Clocks extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// Toplam dilim sayisi. 4/6/8 yaygin, ama serbest.
  IntColumn get segments => integer().withDefault(const Constant(6))();

  /// Dolu dilim sayisi; her zaman `0 <= filled <= segments`.
  IntColumn get filled => integer().withDefault(const Constant(0))();

  /// Saat dolunca NE OLACAK. Dolan bir saatin sonucu yazili degilse saat
  /// masada iş görmüyor: "doldu, e ne olacak?" sorusu kaliyordu.
  TextColumn get outcome => text().withDefault(const Constant(''))();

  /// DM'e ozel notlar.
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// Saat kapatildi mi? Dolan saat kendiliginden kapanmaz: DM sonucu
  /// isledikten sonra elle kapatir, boylece "doldu ama daha oynamadim"
  /// durumu kayboluyor.
  BoolColumn get done => boolean().withDefault(const Constant(false))();

  /// Bagli oldugu kaydin turu ve kimligi (bkz. [ClockLinkKind]).
  TextColumn get linkKind =>
      textEnum<ClockLinkKind>().withDefault(const Constant('none'))();
  TextColumn get linkId => text().nullable()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
