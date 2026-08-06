/// Yolculuk mesafesi ve suresi hesabi (SRD 5.2, CC BY 4.0 — uygulamanin
/// icerik kaynagiyla ayni lisans).
///
/// Saf Dart: Drift/Flutter bilmez, dogrudan test edilir. Iki parca var:
///
/// 1. **Mesafe.** Harita pinleri 0..1 NORMALIZE ORAN olarak saklandigi icin
///    (bkz. `MapPins.x/y`), DM haritanin gercek en/boyunu MIL cinsinden
///    girdiginde mesafe dogrudan cikar; piksel olculerine ihtiyac yoktur.
/// 2. **Sure.** Secilen hiz ve gunde kac saat yol alindigi (klasik D&D
///    varsayimi: 8 saat) ile toplam mesafe gune cevrilir.
library;

import 'dart:math';

/// Klasik D&D varsayimi: gunde 8 saat aralisiz yol.
const double kHoursPerTravelDay = 8;

/// Hazir hizin hangi kumeden geldigi (arayuzde gruplamak icin).
enum TravelSpeedKind { pace, mount, vehicle, custom }

/// Bir yol alma hizi.
///
/// [key] bir L10n anahtaridir; goruntulenecek metin domain'de TUTULMAZ
/// (`encounter_budget.dart` ve `bond_type.dart` ile ayni ayrim).
class TravelSpeed {
  const TravelSpeed({
    required this.key,
    required this.kind,
    required this.milesPerHour,
    this.milesPerDayOverride,
    this.walkFeet,
    this.defaultHoursPerDay = kHoursPerTravelDay,
  });

  /// Ozel (kullanici girisi) hiz.
  factory TravelSpeed.custom(double milesPerHour) => TravelSpeed(
    key: 'travelCustomSpeed',
    kind: TravelSpeedKind.custom,
    milesPerHour: milesPerHour,
  );

  final String key;
  final TravelSpeedKind kind;
  final double milesPerHour;

  /// SRD'nin DOGRUDAN verdigi gunluk mesafe.
  ///
  /// Bu alan carpimla turetilemedigi icin var: SRD'de Hizli tempo 4 mil/saat
  /// ama **30 mil/gun** (4x8=32 degil), Yavas 2 mil/saat ama **18 mil/gun**
  /// (2x8=16 degil). Sessizce carpmak yanlis SRD verirdi.
  final double? milesPerDayOverride;

  /// Bineklerin SRD hizi (ft). Yalnizca gosterim icin.
  final int? walkFeet;

  /// Bu hizla gunde kac saat yol alinir. Kara icin 8; deniz araclari SRD'de
  /// gunde 24 saat ilerleyebilir.
  final double defaultHoursPerDay;

  /// Gunluk mesafe. [hoursPerDay] verilmezse ve SRD'nin kendi gunluk degeri
  /// varsa o kullanilir; aksi halde saatlik hizdan hesaplanir.
  double milesPerDay([double? hoursPerDay]) =>
      hoursPerDay == null && milesPerDayOverride != null
      ? milesPerDayOverride!
      : milesPerHour * (hoursPerDay ?? defaultHoursPerDay);
}

/// SRD 5.2 kaynakli hazir hizlar.
///
/// Bineklerde ve araclarda donusum: `hiz_ft / 10 = mil/saat`.
const List<TravelSpeed> kTravelSpeeds = <TravelSpeed>[
  // --- Travel Pace ---------------------------------------------------------
  TravelSpeed(
    key: 'travelPaceFast',
    kind: TravelSpeedKind.pace,
    milesPerHour: 4,
    milesPerDayOverride: 30,
  ),
  TravelSpeed(
    key: 'travelPaceNormal',
    kind: TravelSpeedKind.pace,
    milesPerHour: 3,
    milesPerDayOverride: 24,
  ),
  TravelSpeed(
    key: 'travelPaceSlow',
    kind: TravelSpeedKind.pace,
    milesPerHour: 2,
    milesPerDayOverride: 18,
  ),
  // --- Mounts and Other Animals -------------------------------------------
  TravelSpeed(
    key: 'travelMountPony',
    kind: TravelSpeedKind.mount,
    milesPerHour: 4,
    walkFeet: 40,
  ),
  TravelSpeed(
    key: 'travelMountDraftHorse',
    kind: TravelSpeedKind.mount,
    milesPerHour: 4,
    walkFeet: 40,
  ),
  TravelSpeed(
    key: 'travelMountMastiff',
    kind: TravelSpeedKind.mount,
    milesPerHour: 4,
    walkFeet: 40,
  ),
  TravelSpeed(
    key: 'travelMountElephant',
    kind: TravelSpeedKind.mount,
    milesPerHour: 4,
    walkFeet: 40,
  ),
  TravelSpeed(
    key: 'travelMountCamel',
    kind: TravelSpeedKind.mount,
    milesPerHour: 5,
    walkFeet: 50,
  ),
  TravelSpeed(
    key: 'travelMountRidingHorse',
    kind: TravelSpeedKind.mount,
    milesPerHour: 6,
    walkFeet: 60,
  ),
  TravelSpeed(
    key: 'travelMountWarhorse',
    kind: TravelSpeedKind.mount,
    milesPerHour: 6,
    walkFeet: 60,
  ),
  // --- Waterborne Vehicles (gunde 24 saat) --------------------------------
  TravelSpeed(
    key: 'travelVehicleRowboat',
    kind: TravelSpeedKind.vehicle,
    milesPerHour: 1.5,
    defaultHoursPerDay: 24,
  ),
  TravelSpeed(
    key: 'travelVehicleKeelboat',
    kind: TravelSpeedKind.vehicle,
    milesPerHour: 1,
    defaultHoursPerDay: 24,
  ),
  TravelSpeed(
    key: 'travelVehicleSailingShip',
    kind: TravelSpeedKind.vehicle,
    milesPerHour: 2,
    defaultHoursPerDay: 24,
  ),
  TravelSpeed(
    key: 'travelVehicleWarship',
    kind: TravelSpeedKind.vehicle,
    milesPerHour: 2.5,
    defaultHoursPerDay: 24,
  ),
  TravelSpeed(
    key: 'travelVehicleLongship',
    kind: TravelSpeedKind.vehicle,
    milesPerHour: 3,
    defaultHoursPerDay: 24,
  ),
  TravelSpeed(
    key: 'travelVehicleGalley',
    kind: TravelSpeedKind.vehicle,
    milesPerHour: 4,
    defaultHoursPerDay: 24,
  ),
];

/// Anahtarindan hazir hizi bulur; bulunamazsa ozel hiz kurar.
///
/// Suren yolculuk veritabaninda yalnizca anahtari sakliyor (hiz tanimi kodda
/// duruyor, kopyalanmiyor); bu, kaydi tekrar canli nesneye cevirir.
TravelSpeed travelSpeedByKey(String key, {double? customMph}) {
  for (final speed in kTravelSpeeds) {
    if (speed.key == key) return speed;
  }
  return TravelSpeed.custom(customMph ?? 0);
}

/// Saat/gun degeri hizin varsayilaniyla AYNIYSA `null` doner.
///
/// Bunun icin var: arayuzdeki "saat/gun" alani secilen hizin varsayilaniyla
/// dolduruluyor ve o degeri [estimateTravel]'a gecirmek SRD'nin kendi gunluk
/// mesafesini (Hizli 30, Normal 24, Yavas 18) devre disi birakip carpimla
/// hesaplatiyordu (4x8=32 gibi). DM degeri gercekten degistirdiyse elbette
/// onunki gecerli olur.
double? overriddenHoursPerDay(TravelSpeed speed, double? hoursPerDay) {
  if (hoursPerDay == null) return null;
  return (hoursPerDay - speed.defaultHoursPerDay).abs() < 1e-9
      ? null
      : hoursPerDay;
}

/// Rotadaki bir durak. [x]/[y] pin koordinati: harita kutusuna gore 0..1 oran.
typedef TravelPoint = ({String id, String label, double x, double y});

/// Iki durak arasindaki bir bacak.
typedef TravelLeg = ({TravelPoint from, TravelPoint to, double miles});

/// Haritanin gercek dunya olcegi; pin oranlarini mile cevirir.
class MapScale {
  const MapScale({required this.widthMiles, required this.heightMiles});

  final double widthMiles;
  final double heightMiles;

  /// Iki pin arasi kus ucusu mesafe (mil).
  ///
  /// Oranlar goruntunun kendi cercevesine gore oldugu icin once en/boy ile
  /// carpilir; kare olmayan haritalarda dogrudan oran farki alinsa mesafe
  /// carpik cikardi.
  double distanceMiles(TravelPoint a, TravelPoint b) {
    final dx = (a.x - b.x) * widthMiles;
    final dy = (a.y - b.y) * heightMiles;
    return sqrt(dx * dx + dy * dy);
  }

  /// DB alanlarindan olcek kurar; kurulamazsa `null` (mesafe hesaplanamaz).
  ///
  /// Yukseklik girilmemisse piksel en-boy oranindan turetilir — boylece
  /// "yalnizca genislik girildi" tam desteklenen bir durum olur, bozuk bir
  /// durum degil. Piksel olculeri de yoksa kare varsayilir.
  static MapScale? of({
    double? widthMiles,
    double? heightMiles,
    int? pixelWidth,
    int? pixelHeight,
  }) {
    if (widthMiles == null || !widthMiles.isFinite || widthMiles <= 0) {
      return null;
    }
    var h = heightMiles;
    if (h == null || !h.isFinite || h <= 0) {
      h = (pixelWidth != null && pixelHeight != null && pixelWidth > 0)
          ? widthMiles * (pixelHeight / pixelWidth)
          : widthMiles;
    }
    return MapScale(widthMiles: widthMiles, heightMiles: h);
  }
}

/// Coklu duraktan olusan rota.
class TravelPlan {
  const TravelPlan({required this.legs, this.extraMiles = 0});

  final List<TravelLeg> legs;

  /// Haritada karsiligi olmayan elle girilen ek mesafe.
  ///
  /// Farkli haritalardaki pinler arasinda ORTAK KOORDINAT SISTEMI YOK
  /// (ana harita ile sehir haritasi arasinda offset/olcek kaydi tutulmuyor),
  /// yani boyle bir bacagin uzunlugu tanimsizdir. "Obur kitaya yelken, sonra
  /// baskente at" senaryosu bu alanla cozulur.
  final double extraMiles;

  double get totalMiles =>
      legs.fold<double>(0, (sum, l) => sum + l.miles) + extraMiles;
}

/// Duraklari ardisik bacaklara cevirir.
///
/// Sifir uzunluklu bacak ELENMEZ: DM ayni pini iki kez sectiyse bunu 0 mil
/// olarak GORMELI, sessizce yutulmamali.
TravelPlan planRoute(
  List<TravelPoint> stops,
  MapScale scale, {
  double extraMiles = 0,
}) => TravelPlan(
  legs: [
    for (var i = 0; i + 1 < stops.length; i++)
      (
        from: stops[i],
        to: stops[i + 1],
        miles: scale.distanceMiles(stops[i], stops[i + 1]),
      ),
  ],
  extraMiles: extraMiles,
);

/// Yolculuk suresi tahmini.
///
/// [wholeDays] + [remainderHours] arayuzde okunur ("2 gun 3 saat");
/// [daysToAdvance] takvime islenecek gun sayisidir ve kismi gunu YUKARI
/// yuvarlar (yarim gun de bir gun harcar).
typedef TravelEstimate = ({
  double totalMiles,
  double totalHours,
  int wholeDays,
  double remainderHours,
  int daysToAdvance,
});

TravelEstimate estimateTravel({
  required double totalMiles,
  required TravelSpeed speed,
  double? hoursPerDay,
}) {
  final hpd = hoursPerDay ?? speed.defaultHoursPerDay;
  // Bozuk girdide NaN/Infinity uretmemek icin erken cikis: ozel hiz alani
  // serbest metin, 0 ya da negatif gelebilir.
  if (!totalMiles.isFinite ||
      totalMiles <= 0 ||
      !speed.milesPerHour.isFinite ||
      speed.milesPerHour <= 0 ||
      !hpd.isFinite ||
      hpd <= 0) {
    return (
      totalMiles: (totalMiles.isFinite && totalMiles > 0) ? totalMiles : 0,
      totalHours: 0,
      wholeDays: 0,
      remainderHours: 0,
      daysToAdvance: 0,
    );
  }

  // Hazir tempolarda SRD'nin gunluk degeri esas alinir (30/24/18); saat/gun
  // elle degistirildiyse saatlik hizdan hesaplanir.
  final perDay = speed.milesPerDay(hoursPerDay);
  final totalHours = totalMiles / speed.milesPerHour;
  final days = totalMiles / perDay;
  final whole = days.floor();
  final remainder = (days - whole) * hpd;
  return (
    totalMiles: totalMiles,
    totalHours: totalHours,
    wholeDays: whole,
    remainderHours: remainder,
    daysToAdvance: remainder > 1e-9 ? whole + 1 : whole,
  );
}
