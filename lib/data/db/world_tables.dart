import 'package:drift/drift.dart';

/// Bir harita pininin neye isaret ettigi.
enum PinKind {
  /// Icine girilebilen alt lokasyon; kendi haritasi olabilir.
  location,

  /// Haritasi OLMAYAN yer: uzerine bilgi/not yazilir, icine GIRILMEZ.
  ///
  /// Yine de gercek bir `Locations` kaydi acar -- amac tam olarak bu: gorev
  /// ureticisinde, seyahat planlayicida ve lokasyon seciclerinde normal bir
  /// yer gibi gozuksun. `location`dan farki, tiklayinca alt haritaya
  /// gecilmemesi; harita gorseli hic yok.
  place,

  /// Serbest not.
  note,

  /// Bir NPC.
  npc,

  /// Kurulmus bir magaza.
  shop,

  /// Hazir bir karsilasma.
  encounter,

  /// Hazine/loot.
  treasure,
}

/// Dunya agacindaki bir yer.
///
/// Kendine referansli: kita -> krallik -> sehir -> han -> bodrum seklinde
/// sinirsiz derinlik. [parentId] bos olanlar kok lokasyondur.
class Locations extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get parentId => text().nullable()();

  TextColumn get description => text().withDefault(const Constant(''))();

  /// DM'e ozel notlar.
  TextColumn get secretNotes => text().withDefault(const Constant(''))();

  /// Harita gorselinin uygulama klasorune gore yolu. Mutlak yol saklanmaz:
  /// Android yeniden kurulumda uygulama klasorunun yolunu degistirebiliyor.
  TextColumn get mapImagePath => text().nullable()();

  /// Haritanin piksel olculeri; pin koordinatlarini en-boy oranina gore
  /// dogru yerlestirmek icin.
  IntColumn get mapWidth => integer().nullable()();
  IntColumn get mapHeight => integer().nullable()();

  /// Haritanin GERCEK DUNYA olculeri (mil). Null = olcek girilmedi, mesafe
  /// hesaplanamaz. Pin x/y zaten 0..1 oran oldugu icin iki pin arasi mesafe
  /// dogrudan bu iki degerden cikar (bkz. `domain/rules/travel.dart`).
  /// Yukseklik bos birakilirsa piksel en-boy oranindan turetilir.
  RealColumn get mapWidthMiles => real().nullable()();
  RealColumn get mapHeightMiles => real().nullable()();

  /// Dunya grafigindeki (DM-only dugum-agi) serbest konum. Null = henuz
  /// yerlestirilmedi; grafik ilk acilista simulasyonla dizer, sonra kalici olur.
  RealColumn get graphX => real().nullable()();
  RealColumn get graphY => real().nullable()();

  /// Dugum (küre) gorsel boyutu (DM-only). Null = varsayilan (yer=30, npc=21).
  RealColumn get nodeRadius => real().nullable()();

  /// Dunya grafiginde alt yerleri KATLANMIS mi?
  ///
  /// Yuz lokasyonlu bir dunyada ag okunmaz hale geliyordu. Katlanmis bir
  /// dugum cocuklarini gizler ve uzerinde kac tane oldugunu yazar; alt yerin
  /// baglantilari da uste tasinir ki ag kopmasin.
  BoolColumn get graphCollapsed =>
      boolean().withDefault(const Constant(false))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Dunya grafigindeki iki dugum arasindaki yonsuz baglanti (kenar).
///
/// Uclar YER, NPC ya da FRAKSIYON olabilir; [aKind]/[bKind] hangisi oldugunu
/// soyler ('location'/'npc'/'faction'). Bu yuzden [aId]/[bId] FK ile bir
/// tabloya baglanmaz (foreign_keys zaten OFF). [type] bagin turudur (bkz.
/// BondType: dostluk, dusmanlik, ticaret, uyelik...). Agac
/// [Locations.parentId]'den bagimsiz, coktan-coga.
class WorldLinks extends Table {
  TextColumn get id => text()();
  TextColumn get aId => text()();
  TextColumn get bId => text()();
  TextColumn get aKind => text().withDefault(const Constant('location'))();
  TextColumn get bKind => text().withDefault(const Constant('location'))();

  /// Bagin turu -- [BondTypes.code]'a isaret eder (dostluk/dusmanlik/...).
  TextColumn get type => text().withDefault(const Constant('road'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Kullanicinin duzenleyebildigi bag turleri (ad + renk). Varsayilanlar ilk
/// acilista tohumlanir; DM koseye eklenen ayarlardan renk/ad degistirir ya da
/// yeni tur olusturur. [code] karali kimliktir; [WorldLinks.type] buna bakar.
class BondTypes extends Table {
  TextColumn get code => text()();
  TextColumn get name => text()();

  /// ARGB renk (int).
  IntColumn get color => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {code};
}

/// Harita uzerindeki isaret.
class MapPins extends Table {
  TextColumn get id => text()();

  /// Pinin uzerinde durdugu lokasyon (haritanin sahibi).
  TextColumn get locationId => text().references(Locations, #id)();

  TextColumn get kind => textEnum<PinKind>()();
  TextColumn get label => text()();

  /// Haritanin sol-ust kosesine gore 0..1 arasi oran.
  ///
  /// Piksel yerine oran saklaniyor: ayni harita telefonda, tablette ve
  /// masaustunde farkli olculerde ciziliyor.
  RealColumn get x => real()();
  RealColumn get y => real()();

  /// Pinin isaret ettigi kayit: alt lokasyon id'si, NPC id'si, magaza id'si
  /// ya da karsilasma id'si. Not pinlerinde bos.
  TextColumn get targetId => text().nullable()();

  /// Not pinlerinin icerigi.
  TextColumn get noteText => text().withDefault(const Constant(''))();

  // --- Ganimet (treasure pinleri icin) ---

  /// Baglanan ganimet seti ID'si. Treasure pini olustururken secilir.
  TextColumn get lootSetId => text().nullable()();

  /// Kalan ganimet: `{"coinsCp": 150, "items": [{"name":"...","magic":false}]}`.
  /// DM dagittikca guncellenir; bossa pin otomatik silinir.
  TextColumn get lootDataJson => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Kampanyadaki ORGUTLER: loncalar, tarikatlar, hanedanlar, sucete...
///
/// **Neden ayri bir varlik:** dunya grafiginde su ana kadar yalnizca YER ve
/// KISI vardi. Oysa masada surekli sorulan uc soru var ve ucuncusunun yeri
/// yoktu: "burasi neresi", "bu kim", **"bunlar kim ve ne istiyor"**. Fraksiyon
/// bir NPC degil (lideri olur ama kendisi olmez), bir yer de degil (merkezi
/// olur ama tasinabilir).
///
/// Uyelik ve dusmanlik AYRI tutulmuyor: ikisi de [WorldLinks] uzerinden tipli
/// bir bag. Boylece grafik tek bir kenar modeliyle calismaya devam ediyor ve
/// "Kizil Hancerler ile Tuccar Loncasi dusman" ile "Gundren, Kizil Hancerler
/// uyesi" ayni ekranda ayni sekilde cizilebiliyor.
class Factions extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// Orgutun turu, serbest metin: "lonca", "tarikat", "hanedan", "cete".
  /// Sabit bir enum DEGIL cunku her masanin kendi sozlugu var.
  TextColumn get kind => text().withDefault(const Constant(''))();

  TextColumn get description => text().withDefault(const Constant(''))();

  /// Orgutun ACIK amaci: masada en cok sorulan sey bu.
  TextColumn get goal => text().withDefault(const Constant(''))();

  /// DM'e ozel notlar (gercek amac, ihanet, sirlar).
  TextColumn get secretNotes => text().withDefault(const Constant(''))();

  /// Arma/sembol gorseli. NPC portreleriyle ayni depoyu paylasir
  /// (`CharacterImageStore`), ayri bir klasore gerek yok.
  TextColumn get portraitPath => text().nullable()();

  /// Dunya grafigindeki serbest konum ve dugum boyutu; yer/NPC ile ayni desen.
  RealColumn get graphX => real().nullable()();
  RealColumn get graphY => real().nullable()();
  RealColumn get nodeRadius => real().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Kampanyadaki NPC'ler (zengin karakterler + dunya grafigi dugumu).
class Npcs extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get role => text().withDefault(const Constant(''))();
  TextColumn get description => text().withDefault(const Constant(''))();

  // Zengin karakter alanlari.
  TextColumn get race => text().withDefault(const Constant(''))();
  TextColumn get gender => text().withDefault(const Constant(''))();
  TextColumn get age => text().withDefault(const Constant(''))();
  TextColumn get alignment => text().withDefault(const Constant(''))();
  TextColumn get appearance => text().withDefault(const Constant(''))();
  TextColumn get personality => text().withDefault(const Constant(''))();
  TextColumn get ideal => text().withDefault(const Constant(''))();
  TextColumn get bond => text().withDefault(const Constant(''))();
  TextColumn get flaw => text().withDefault(const Constant(''))();
  TextColumn get hook => text().withDefault(const Constant(''))();

  /// DM'e ozel notlar.
  TextColumn get secretNotes => text().withDefault(const Constant(''))();

  /// Bagli oldugu canavar stat blogu (varsa) -- savasa dogrudan eklemek icin.
  TextColumn get monsterKey => text().nullable()();

  TextColumn get portraitPath => text().nullable()();

  /// Dunya grafigindeki (DM-only) serbest konum.
  RealColumn get graphX => real().nullable()();
  RealColumn get graphY => real().nullable()();

  /// Dugum (küre) gorsel boyutu (DM-only). Null = varsayilan (yer=30, npc=21).
  RealColumn get nodeRadius => real().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
