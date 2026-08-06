import 'package:drift/drift.dart';

/// Kampanyanın takvim yapısı: tek satır (`id = 'default'`).
///
/// Kampanya = ayrı veritabanı dosyası olduğu için burada `campaignId` yok;
/// her kampanya kendi takvimini taşır.
class CalendarConfig extends Table {
  TextColumn get id => text()();

  /// Takvimin adı ("Harptos", "Kanlı Yıllar Takvimi"...).
  TextColumn get calendarName => text().withDefault(const Constant(''))();

  /// DM'in belirlediği "bugün".
  IntColumn get currentYear => integer().withDefault(const Constant(1))();
  IntColumn get currentMonthIndex => integer().withDefault(const Constant(0))();
  IntColumn get currentDay => integer().withDefault(const Constant(1))();

  /// Yılın yanına yazılan etiketler: "1492 YS, Üçüncü Çağ".
  TextColumn get eraLabel => text().withDefault(const Constant(''))();

  /// Milat-mantığı yıl ekleri: yıl 0 veya üzeriyse [yearSuffix] ("MS"),
  /// negatifse (çağ öncesi) [beforeYearSuffix] ("MÖ") kullanılır — yıl her
  /// zaman mutlak değeriyle gösterilir (bkz. `game_calendar.formatGameDate`).
  TextColumn get yearSuffix => text().withDefault(const Constant(''))();
  TextColumn get beforeYearSuffix => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Bir ay ve kaç gün sürdüğü. Sıra [sortOrder] ile; ay indeksleri bu sıraya
/// göre 0'dan başlar.
class CalendarMonths extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withDefault(const Constant(''))();
  IntColumn get days => integer().withDefault(const Constant(30))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Haftanın gün adları. Sayıları serbest: 5 günlük hafta de olur.
class CalendarWeekdays extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withDefault(const Constant(''))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Bir mevsim ve kapsadığı ay/gün aralığı. Aralık yıl sonunu sarabilir
/// (kış: 11. ayın 15'inden 1. ayın 20'sine) — bkz. `game_calendar.seasonAt`.
class CalendarSeasons extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withDefault(const Constant(''))();
  IntColumn get color => integer().withDefault(const Constant(0xFF8D6E63))();
  IntColumn get startMonthIndex => integer().withDefault(const Constant(0))();
  IntColumn get startDay => integer().withDefault(const Constant(1))();
  IntColumn get endMonthIndex => integer().withDefault(const Constant(0))();
  IntColumn get endDay => integer().withDefault(const Constant(1))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tarihçedeki bir çağ: adlandırılmış yıl aralığı ("Ejderha Savaşları Çağı,
/// 100–450"). [endYear] boşsa çağ hâlâ sürüyordur.
class CalendarEras extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withDefault(const Constant(''))();
  IntColumn get startYear => integer().withDefault(const Constant(0))();
  IntColumn get endYear => integer().nullable()();
  IntColumn get color => integer().withDefault(const Constant(0xFF8D6E63))();
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tarihçe olayı: geçmişte (ya da gelecekte) olmuş bir şey.
///
/// Tarih hassasiyeti kademeli: yalnız yıl bilinebilir ([monthIndex]/[day]
/// boş), ya da gün gün. Süren olaylar için bitiş tarihi de verilebilir.
///
/// Sıralama için DENORMALIZE anahtar tutulmaz: ayların uzunluğu sonradan
/// değiştirilebiliyor ve kayıtlı anahtar sessizce yanlışa düşerdi. Sıralama
/// okuma anında `game_calendar.absoluteDay` ile yapılır.
///
/// Not: sütun adı `text` Drift'in `text()` kurucusuyla çakıştığı için olay
/// gövdesi [body] olarak adlandırıldı (aynı gerekçe `Quests.questText`'te de
/// geçerliydi).
class ChronicleEvents extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withDefault(const Constant(''))();

  /// Zengin metin (Kayıtlar'daki satır içi biçimlendirmenin aynısı:
  /// `**kalın**`, `[[wiki]]`, `/r 2d6`, `/monster(...)`).
  TextColumn get body => text().withDefault(const Constant(''))();

  IntColumn get year => integer().withDefault(const Constant(0))();
  IntColumn get monthIndex => integer().nullable()();
  IntColumn get day => integer().nullable()();
  IntColumn get endYear => integer().nullable()();
  IntColumn get endMonthIndex => integer().nullable()();
  IntColumn get endDay => integer().nullable()();

  /// Bağlı çağ (yoksa yıla göre kendiliğinden gruplanır). FK yok — çağ
  /// silinince olay yetim kalmaz, yalnız gruplaması düşer.
  TextColumn get eraId => text().nullable()();

  /// Serbest kategori ("savaş", "antlaşma", "felaket"...). Filtrelemede
  /// kullanılır; sabit bir liste dayatılmaz.
  TextColumn get category => text().withDefault(const Constant(''))();
  IntColumn get color => integer().nullable()();

  /// DM'e özel: oyuncuların bilmediği olay. (Tarihçe zaten oyunculara
  /// gönderilmiyor; bu bayrak DM'in kendi ayrımı ve ileride paylaşım
  /// eklenirse hazır.)
  BoolColumn get secret => boolean().withDefault(const Constant(false))();

  /// Uzun metin için bir Kayıtlar sayfasına bağlanabilir.
  TextColumn get codexPageId => text().nullable()();

  /// İsteğe bağlı dünya bağlantıları.
  TextColumn get locationId => text().nullable()();
  TextColumn get npcId => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Takvim hatırlatıcısı / tekrarlayan olay.
///
/// Tarihçe olaylarından (`ChronicleEvents`) FARKLI: onlar dünyanın GEÇMİŞİ,
/// bunlar DM'e gün ilerledikçe hatırlatılacak İLERİYE dönük kayıtlar
/// ("her ayın 1'i vergi günü", "3 gün sonra kervan gelir").
class CalendarReminders extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get body => text().withDefault(const Constant(''))();

  /// `once` | `everyNDays` | `monthly` | `yearly`.
  ///
  /// Kod olarak saklanıyor (enum indeksi DEĞİL): araya yeni tür eklemek
  /// kayıtlı satırların anlamını kaydırmasın.
  TextColumn get repeatKind => text().withDefault(const Constant('once'))();

  /// `everyNDays` için periyot; diğer türlerde kullanılmaz.
  IntColumn get everyNDays => integer().withDefault(const Constant(1))();

  /// Çapa tarihi: tek seferlik için olayın günü, tekrarlılarda serinin
  /// başlangıcı. [startMonthIndex] 0 tabanlı, [startDay] 1 tabanlı.
  IntColumn get startYear => integer()();
  IntColumn get startMonthIndex => integer()();
  IntColumn get startDay => integer()();

  /// En son hangi mutlak günde tetiklendi. Tekrar tetiklenmeyi engeller
  /// (aynı gün iki kez ilerletilirse ya da tarih elle geri alınırsa).
  IntColumn get lastFiredDay => integer().nullable()();

  /// Kapatıldı mı? Tek seferlikler tetiklenince kapanır; tekrarlılar
  /// yalnızca DM kapatırsa.
  BoolColumn get done => boolean().withDefault(const Constant(false))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
