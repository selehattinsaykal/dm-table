import 'package:drift/drift.dart';

/// Ortak parti kesesi ("Parti kesesi", "At arabası"...).
///
/// Uye karakterler serbestce esya/para ALIR ve KOYAR; DM onayi yoktur.
///
/// Kampanya = ayri veritabani dosyasi oldugu icin burada `campaignId` yok.
class PartyInventories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// Kesedeki para, bakir cinsinden (pp/gp/sp/cp tek toplamda).
  IntColumn get coinsCp => integer().withDefault(const Constant(0))();

  /// Esyalar:
  /// `[{"id":uuid,"name":"..","magic":bool,"itemKey":str?,
  ///    "magicItemKey":str?,"desc":str?,"quantity":int}, ...]`
  ///
  /// Hazine pini / gorev odulu havuzlarindan (`LootRepository.pinLootOf`)
  /// FARKLI olarak katalog anahtarlarini ve ADEDI de tasir. Sebep: o havuzlar
  /// TEK YONLU (DM -> oyuncu), bu ise esyanin gidip geldigi TEK havuz. Anahtar
  /// dusseydi katalog esyasi geri donuste kalici olarak serbest metne doner,
  /// detay sayfasini kaybeder ve `CharacterRepository.addItem` once anahtara
  /// baktigi icin mevcut satirla istiflenmezdi (iki ayri "Uzun kılıç" satiri).
  ///
  /// `id` yatirma aninda uretilen kalici uuid'dir ve alma isleminin TEK
  /// tutamagidir (yaris korumasi; bkz. repository).
  TextColumn get itemsJson => text().withDefault(const Constant('[]'))();

  /// Uye karakter id'leri: `["char-1","char-2"]`.
  ///
  /// `Quests.targetsJson` ile ayni desen: uyelik kumesi parti boyutunda (2-6),
  /// hep butun okunuyor, hic JOIN/GROUP BY yok ve `foreign_keys` zaten KAPALI
  /// oldugu icin ayri bir join tablosu butunluk kazandirmazdi.
  TextColumn get membersJson => text().withDefault(const Constant('[]'))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
