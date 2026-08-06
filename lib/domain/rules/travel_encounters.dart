/// Yolculuk sirasinda rastgele karsilasma kontrolu ("wandering monster"
/// cizelgesi).
///
/// Saf Dart: Drift/Flutter bilmez, dogrudan test edilir. Iki asamali klasik
/// desen:
///
/// 1. **Tetikleme.** Yolun her dilimi icin bir d20 atilir; atis [threshold]
///    degerine ULASIRSA bir sey olur. Gunde kac dilim oldugunu DM secer
///    (bir kez, sabah/aksam, dort nobet...).
/// 2. **Icerik.** Tetiklenen her karsilasma icin DM'in secitigi rastgele
///    tabloya ayrica zar atilir; satir metni sonucu belirler.
///
/// Sonuclar bilincli olarak SADECE DM'e gosterilir; oyunculara giden bir
/// protokol mesaji yok (surpriz DM'in elinde kalmali).
library;

import 'dart:math';

import 'random_table.dart';

/// Gun icindeki kontrol sayisi icin desteklenen degerler.
///
/// 1 = gunde bir, 2 = gunduz + gece, 3 = sabah/aksam/gece, 4 = dort nobet.
const List<int> kEncounterCheckOptions = [1, 2, 3, 4];

/// Karsilasma esiginin makul araligi.
///
/// Alt sinir 11 (%50) bilincli: daha dusugu "yolculuk = surekli savas" demek
/// olurdu. Ust sinir 20, yani en seyrek ayar %5'tir; kapatmak icin ayri bir
/// esik degeri degil, ozelligin kendisi kapatilir.
const int kEncounterThresholdMin = 11;
const int kEncounterThresholdMax = 20;

/// Varsayilan esik: d20'de 18+ (%15), klasik DMG orani.
const int kEncounterThresholdDefault = 18;

/// Tetiklenmis tek bir karsilasma.
///
/// [day] ve [checkIndex] 1 tabanlidir (arayuzde "3. gun · 2. kontrol").
/// [tableRoll] tabloya atilan zar; tablo secilmemisse 0 olur ve [text] bos
/// kalir. [text] bos + [tableRoll] > 0 ise tabloda o atisi kapsayan satir
/// YOKTUR (bosluklu tablo) — arayuz bunu ayirt edip uyari gosterir.
typedef TravelEncounter = ({
  int day,
  int checkIndex,
  int check,
  int tableRoll,
  String text,
});

/// d20 esiginin yuzde karsiligi ("18+ => %15").
int encounterChancePercent(int threshold) {
  final t = threshold.clamp(1, 21);
  return (21 - t) * 5;
}

/// [days] gun boyunca gunde [checksPerDay] kez zar atar.
///
/// Tetiklenmeyen kontroller DONMEZ: DM'i ilgilendiren yalnizca olan seyler,
/// 12 gunluk bir yolculugun 48 basarisiz atisi degil.
///
/// [rows] verilmezse yalnizca tetikleme bilgisi doner (DM tabloyu kendi
/// secer); verilirse her karsilasma icin [tableSides] yuzlu zar atilip satir
/// cozulur.
///
/// [rng] enjekte edilebilir: testler deterministiktir.
List<TravelEncounter> rollTravelEncounters({
  required int days,
  required int checksPerDay,
  required int threshold,
  List<RandomTableRow> rows = const [],
  int tableSides = 20,
  Random? rng,
}) {
  if (days <= 0 || checksPerDay <= 0) return const [];
  final random = rng ?? Random();
  final limit = threshold.clamp(1, 21);

  final out = <TravelEncounter>[];
  for (var day = 1; day <= days; day++) {
    for (var check = 1; check <= checksPerDay; check++) {
      final roll = random.nextInt(20) + 1;
      if (roll < limit) continue;

      if (rows.isEmpty) {
        out.add((
          day: day,
          checkIndex: check,
          check: roll,
          tableRoll: 0,
          text: '',
        ));
        continue;
      }
      final drawn = rollOn(rows, tableSides, random);
      out.add((
        day: day,
        checkIndex: check,
        check: roll,
        tableRoll: drawn.roll,
        text: drawn.row?.text ?? '',
      ));
    }
  }
  return out;
}

/// Yolculugun bir sonraki olaya kadar ilerletilmis hali.
///
/// [encounter] doluysa parti yolun ORTASINDA durmustur ([milesTravelled] o
/// noktadir); bossa [arrived] ile hedefe varilmis demektir.
typedef JourneyStep = ({
  double milesTravelled,
  int checksDone,
  bool arrived,
  TravelEncounter? encounter,
});

/// Yolculugu bir sonraki karsilasmaya ya da hedefe kadar ilerletir.
///
/// Yol, gunluk mesafenin [checksPerDay]'e bolunmesiyle **dilimlere** ayrilir;
/// her dilim icin bir d20 atilir. Tetikleyen dilimde parti dilimin ICINDE
/// RASTGELE bir noktada durur — kontrol sinirlarinda durmak "her seferinde
/// tam gun basinda karsilasma" gibi yapay bir ritim yaratirdi.
///
/// Duraklamis bir yolculuk ayni fonksiyonla devam eder: [milesTravelled] ve
/// [checksDone] nerede kalindigini tasir, fonksiyon durum tutmaz.
///
/// Karsilasma kapaliyken ([encountersOn] false) tek adimda hedefe varilir.
JourneyStep advanceJourney({
  required double totalMiles,
  required double milesTravelled,
  required int checksDone,
  required double milesPerDay,
  required int checksPerDay,
  required bool encountersOn,
  required int threshold,
  List<RandomTableRow> rows = const [],
  int tableSides = 20,
  Random? rng,
}) {
  // Bozuk girdide sonsuz donguye girmemek icin: ilerleme uretemiyorsak
  // dogrudan varis.
  final segment =
      (checksPerDay <= 0 || !milesPerDay.isFinite || milesPerDay <= 0)
      ? 0.0
      : milesPerDay / checksPerDay;
  if (!encountersOn || segment <= 0 || !totalMiles.isFinite) {
    return (
      milesTravelled: totalMiles,
      checksDone: checksDone,
      arrived: true,
      encounter: null,
    );
  }

  final random = rng ?? Random();
  final limit = threshold.clamp(1, 21);
  var position = milesTravelled;
  var checks = checksDone;

  while (position < totalMiles) {
    // Karsilasma dilimin ORTASINDA durdurdugu icin, devam edildiginde o
    // dilimin kalani yeni bir zar ATILMADAN yuruunur — yoksa ayni dilim
    // tekrar tekrar kontrol edilir ve yuksek karsilasma oraninda parti
    // hedefe hic varamazdi.
    final consumed = checks * segment;
    if (position < consumed) {
      position = consumed < totalMiles ? consumed : totalMiles;
      if (position >= totalMiles) break;
    }

    final segmentEnd = (checks + 1) * segment;
    final roll = random.nextInt(20) + 1;
    checks++;

    if (roll >= limit) {
      // Karsilasma dilimin icinde rastgele bir noktada; en fazla hedefe kadar.
      final from = position;
      final to = segmentEnd < totalMiles ? segmentEnd : totalMiles;
      final at = from + random.nextDouble() * (to - from);
      final drawn = rows.isEmpty
          ? (roll: 0, row: null)
          : rollOn(rows, tableSides, random);
      return (
        milesTravelled: at,
        checksDone: checks,
        // Tam hedefte tetiklendiyse bile once karsilasma gosterilir; varis
        // bir sonraki "Devam et"te olur.
        arrived: false,
        encounter: (
          day: (checks - 1) ~/ checksPerDay + 1,
          checkIndex: (checks - 1) % checksPerDay + 1,
          check: roll,
          tableRoll: drawn.roll,
          text: drawn.row?.text ?? '',
        ),
      );
    }
    position = segmentEnd < totalMiles ? segmentEnd : totalMiles;
  }

  return (
    milesTravelled: totalMiles,
    checksDone: checks,
    arrived: true,
    encounter: null,
  );
}

/// Gidilen yola karsilik gelen, takvime islenmesi gereken gun sayisi.
///
/// Kismi gun YUKARI yuvarlanir (`estimateTravel.daysToAdvance` ile ayni kural).
int daysElapsedFor(double milesTravelled, double milesPerDay) {
  if (!milesPerDay.isFinite || milesPerDay <= 0 || milesTravelled <= 0) {
    return 0;
  }
  return (milesTravelled / milesPerDay).ceil();
}
