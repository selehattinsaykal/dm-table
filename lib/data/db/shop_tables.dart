import 'package:drift/drift.dart';

/// DM'in kurdugu magaza.
class Shops extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// Magazayi isleten NPC'nin adi.
  ///
  /// [ownerNpcId] ile bagli bir NPC varsa bu alan onun adiyla senkron tutulur
  /// (goruntuleme tek yerden okunsun diye); bagsiz magazalarda serbest
  /// metindir.
  TextColumn get ownerName => text().nullable()();

  /// Isleten NPC kaydi (`Npcs.id`). Istege baglidir: DM isterse yalnizca ad
  /// yazar. FK TANIMLANMADI — projede FK'lar zaten kapali ve NPC silinince
  /// magaza kaybolmamali; cozumleme okuma aninda yapilir, NPC yoksa
  /// [ownerName] metni gosterilmeye devam eder.
  TextColumn get ownerNpcId => text().nullable()();
  TextColumn get description => text().withDefault(const Constant(''))();

  /// Liste fiyatlarina uygulanan carpan: 1.0 normal, 1.2 pahali kasaba,
  /// 0.8 pazarlik sonrasi. Stok satirinda ozel fiyat varsa o gecerli.
  RealColumn get priceMultiplier => real().withDefault(const Constant(1))();

  /// Mağaza şu an kapalı mı? Dünya durumu: kapalı bir dükkânda alışveriş
  /// yapılamaz, listede soluk görünür. DM dükkân ayarlarından açıp kapatır.
  BoolColumn get closed => boolean().withDefault(const Constant(false))();

  /// Stok kac oyun-ici gunde bir yenilensin? 0 = hic yenilenmez.
  ///
  /// Takvim ilerledikce (`advanceGameDays`) suresi dolan magazalarin
  /// stok satirlari [ShopStock.restockQuantity] degerine geri doner.
  IntColumn get restockDays => integer().withDefault(const Constant(0))();

  /// Son yenilemenin oyun-ici MUTLAK gunu (`game_calendar.absoluteDay`).
  /// Null = hic yenilenmedi; ilk gun ilerlemesinde baslangic olarak yazilir.
  IntColumn get lastRestockDay => integer().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Magazadaki bir satir.
///
/// Kutuphanedeki bir esyaya baglanabilir ([itemKey] / [magicItemKey]) ya da
/// tamamen serbest bir kayit olabilir (DM'in o an uydurdugu sey).
class ShopStock extends Table {
  TextColumn get id => text()();
  TextColumn get shopId => text().references(Shops, #id)();

  TextColumn get itemKey => text().nullable()();
  TextColumn get magicItemKey => text().nullable()();
  TextColumn get customName => text().nullable()();
  TextColumn get customDesc => text().nullable()();

  /// Bu satira ozel fiyat (bakir). Bostaysa kutuphane fiyati x carpan.
  IntColumn get priceCpOverride => integer().nullable()();

  /// Kalan adet. -1 = sinirsiz (temel malzeme satan bir dukkan icin).
  IntColumn get quantity => integer().withDefault(const Constant(-1))();

  /// Yenilemede [quantity] bu degere doner. Null = bu satir YENILENMEZ
  /// (tukenince biter — benzersiz bir esya). Sinirsiz satirlarda anlamsiz.
  IntColumn get restockQuantity => integer().nullable()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
