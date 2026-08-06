/// Oyun-içi takvim matematiği.
///
/// Saf Dart: Drift/Flutter bilmez, doğrudan test edilir. Takvimin YAPISI
/// (kaç ay, her ay kaç gün, kaç gün adı, mevsim aralıkları) kampanyaya göre
/// tamamen kullanıcı tanımlıdır; buradaki fonksiyonlar yalnız o yapıyı alıp
/// tarih aritmetiği yapar.
///
/// Artık yıl kavramı bilinçli olarak YOK: her yıl aynı uzunluktadır. Fantastik
/// takvimlerde bu yaygın ve bir gün fazlalığı kampanya kaydını (tarihçe
/// sıralaması) karmaşıklaştırmaktan başka bir şey yapmıyor.
library;

/// Takvimdeki bir ay: adı + kaç gün sürdüğü.
typedef GameMonth = ({String name, int days});

/// Bir mevsim ve hangi ay/gün aralığını kapsadığı.
///
/// Aralık yıl sonunu SARABİLİR (kış: 11. ayın 15'inden 1. ayın 20'sine).
typedef GameSeason = ({
  String name,
  int startMonthIndex,
  int startDay,
  int endMonthIndex,
  int endDay,
});

/// Oyun-içi bir tarih. [monthIndex] 0 tabanlı, [day] 1 tabanlı.
typedef GameDate = ({int year, int monthIndex, int day});

/// Bir yıldaki toplam gün. Ay listesi boşsa 0.
int daysInYear(List<GameMonth> months) =>
    months.fold(0, (sum, m) => sum + (m.days < 1 ? 1 : m.days));

/// Ayın gün sayısı (bozuk veriye karşı en az 1).
int daysInMonth(List<GameMonth> months, int monthIndex) {
  if (months.isEmpty) return 1;
  final i = monthIndex.clamp(0, months.length - 1);
  final days = months[i].days;
  return days < 1 ? 1 : days;
}

/// Tarihi, 0. yılın 1. gününden itibaren sayılan mutlak güne çevirir.
///
/// Tarihçe olayları bu sayıyla sıralanır; DB'de denormalize bir sıralama
/// anahtarı TUTULMAZ, çünkü ayların uzunluğu sonradan değiştirilebiliyor
/// (o durumda kayıtlı anahtar sessizce yanlışa düşerdi).
int absoluteDay(GameDate date, List<GameMonth> months) {
  if (months.isEmpty) return date.year;
  final yearLength = daysInYear(months);
  final monthIndex = date.monthIndex.clamp(0, months.length - 1);
  var offset = 0;
  for (var i = 0; i < monthIndex; i++) {
    offset += daysInMonth(months, i);
  }
  final day = date.day.clamp(1, daysInMonth(months, monthIndex));
  return date.year * yearLength + offset + (day - 1);
}

/// [absoluteDay]'in tersi. Negatif günler (çağ öncesi yıllar) desteklenir.
GameDate fromAbsoluteDay(int absolute, List<GameMonth> months) {
  if (months.isEmpty) return (year: absolute, monthIndex: 0, day: 1);
  final yearLength = daysInYear(months);
  // Negatif yıllarda da doğru çalışsın diye taban bölme (truncating değil).
  var year = absolute ~/ yearLength;
  var rest = absolute - year * yearLength;
  if (rest < 0) {
    year -= 1;
    rest += yearLength;
  }
  var monthIndex = 0;
  while (monthIndex < months.length - 1 &&
      rest >= daysInMonth(months, monthIndex)) {
    rest -= daysInMonth(months, monthIndex);
    monthIndex++;
  }
  return (year: year, monthIndex: monthIndex, day: rest + 1);
}

/// Tarihi [days] gün ileri (negatifse geri) taşır.
GameDate advance(GameDate date, int days, List<GameMonth> months) =>
    fromAbsoluteDay(absoluteDay(date, months) + days, months);

/// Tarihin haftanın kaçıncı gününe denk geldiği (0 tabanlı).
///
/// Takvimin başlangıcı (0. yılın 1. günü) haftanın ilk günü kabul edilir.
int weekdayIndex(GameDate date, List<GameMonth> months, int weekdayCount) {
  if (weekdayCount < 1) return 0;
  final absolute = absoluteDay(date, months);
  final index = absolute % weekdayCount;
  return index < 0 ? index + weekdayCount : index;
}

/// Verilen güne denk gelen mevsim; hiçbiri kapsamıyorsa `null`.
///
/// Yıl sonunu saran aralıklar (kış) desteklenir. Birden fazla mevsim
/// kapsıyorsa listedeki ilki kazanır.
GameSeason? seasonAt(GameDate date, List<GameSeason> seasons) {
  for (final season in seasons) {
    if (_covers(season, date.monthIndex, date.day)) return season;
  }
  return null;
}

bool _covers(GameSeason season, int monthIndex, int day) {
  // Ay/gün çiftini tek bir karşılaştırılabilir sayıya indir (gün sayıları
  // ay uzunluğundan bağımsız karşılaştırılabilsin diye 100'lük taban yeter:
  // hiçbir ay 100 günden uzun olamaz varsayımı değil, sadece sıralama için).
  int key(int m, int d) => m * 100 + d;
  final value = key(monthIndex, day);
  final start = key(season.startMonthIndex, season.startDay);
  final end = key(season.endMonthIndex, season.endDay);
  return start <= end
      ? value >= start && value <= end
      : value >= start || value <= end; // yil sonunu saran aralik
}

/// Yılı milat-mantığında biçimlendirir: "50" (yıl 50) ya da "50 MÖ" (yıl
/// -50, [beforeSuffix] verildiyse). Yıl her zaman MUTLAK değeriyle gösterilir
/// — negatiflik işaretini eke devrediyoruz, "-50" gibi bir metin çıkmaz.
/// 0 ve üzeri yıllar [afterSuffix] alır (boşsa hiçbir ek eklenmez).
String formatEraYear(
  int year, {
  String afterSuffix = '',
  String beforeSuffix = '',
}) {
  final suffix = year < 0 ? beforeSuffix : afterSuffix;
  final absYear = year < 0 ? -year : year;
  return suffix.isEmpty ? '$absYear' : '$absYear $suffix';
}

/// Tarihi okunur metne çevirir: "12 Hasat Ayı 1492 MS".
///
/// [weekdayName] verilirse başa eklenir. [eraLabel] boş bırakılabilir.
/// Yıl [formatEraYear] ile milat-mantığında yazılır: [yearSuffix] = "MS"
/// tarzı (yıl ≥ 0), [beforeYearSuffix] = "MÖ" tarzı (yıl < 0).
String formatGameDate(
  GameDate date,
  List<GameMonth> months, {
  String? weekdayName,
  String eraLabel = '',
  String yearSuffix = '',
  String beforeYearSuffix = '',
}) {
  final monthName = months.isEmpty
      ? ''
      : months[date.monthIndex.clamp(0, months.length - 1)].name;
  return [
    if (weekdayName != null && weekdayName.isNotEmpty) '$weekdayName,',
    '${date.day}',
    if (monthName.isNotEmpty) monthName,
    formatEraYear(
      date.year,
      afterSuffix: yearSuffix,
      beforeSuffix: beforeYearSuffix,
    ),
    if (eraLabel.isNotEmpty) eraLabel,
  ].join(' ');
}
