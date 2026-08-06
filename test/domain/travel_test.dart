import 'package:dm_table/domain/rules/travel.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pin koordinatlari 0..1 oran oldugu icin mesafe haritanin MIL olcegiyle
/// carpilarak cikar; sure ise SRD tempo/binek/arac hizlarindan.
void main() {
  TravelPoint p(String id, double x, double y) =>
      (id: id, label: id, x: x, y: y);

  const scale = MapScale(widthMiles: 100, heightMiles: 50);

  TravelSpeed speed(String key) =>
      kTravelSpeeds.firstWhere((s) => s.key == key);

  group('MapScale.distanceMiles', () {
    test('eksen hizali mesafeler en/boy ile olceklenir', () {
      // Yatayda tam genislik = 100 mil, dikeyde tam yukseklik = 50 mil.
      expect(
        scale.distanceMiles(p('a', 0, 0), p('b', 1, 0)),
        closeTo(100, 1e-9),
      );
      expect(
        scale.distanceMiles(p('a', 0, 0), p('b', 0, 1)),
        closeTo(50, 1e-9),
      );
    });

    test('capraz mesafe pisagor', () {
      expect(
        scale.distanceMiles(p('a', 0, 0), p('b', 1, 1)),
        closeTo(111.80339887, 1e-6), // sqrt(100^2 + 50^2)
      );
    });

    test('kare olmayan haritada oran farki dogrudan alinmaz', () {
      // Ayni oran farki (0.5) yatayda 50, dikeyde 25 mil etmeli.
      final yatay = scale.distanceMiles(p('a', 0, 0), p('b', 0.5, 0));
      final dikey = scale.distanceMiles(p('a', 0, 0), p('b', 0, 0.5));
      expect(yatay, closeTo(50, 1e-9));
      expect(dikey, closeTo(25, 1e-9));
    });
  });

  group('MapScale.of', () {
    test('yukseklik girilmezse piksel en-boy oranindan turetilir', () {
      final s = MapScale.of(
        widthMiles: 100,
        heightMiles: null,
        pixelWidth: 2000,
        pixelHeight: 1000,
      );
      expect(s, isNotNull);
      expect(s!.heightMiles, closeTo(50, 1e-9));
    });

    test('piksel olculeri de yoksa kare varsayilir', () {
      final s = MapScale.of(widthMiles: 80);
      expect(s!.heightMiles, closeTo(80, 1e-9));
    });

    test('genislik yoksa/gecersizse null', () {
      expect(MapScale.of(widthMiles: null), isNull);
      expect(MapScale.of(widthMiles: 0), isNull);
      expect(MapScale.of(widthMiles: -5), isNull);
      expect(MapScale.of(widthMiles: double.nan), isNull);
      expect(MapScale.of(widthMiles: double.infinity), isNull);
    });

    test('gecersiz yukseklik verilirse de turetmeye duser', () {
      final s = MapScale.of(
        widthMiles: 100,
        heightMiles: 0,
        pixelWidth: 1000,
        pixelHeight: 500,
      );
      expect(s!.heightMiles, closeTo(50, 1e-9));
    });
  });

  group('planRoute', () {
    test('3 durak -> 2 bacak, toplam = bacaklarin toplami', () {
      final plan = planRoute([
        p('a', 0, 0),
        p('b', 0.5, 0),
        p('c', 1, 0),
      ], scale);
      expect(plan.legs, hasLength(2));
      expect(plan.legs[0].miles, closeTo(50, 1e-9));
      expect(plan.legs[1].miles, closeTo(50, 1e-9));
      expect(plan.totalMiles, closeTo(100, 1e-9));
    });

    test('tek durak -> bacak yok, 0 mil', () {
      final plan = planRoute([p('a', 0, 0)], scale);
      expect(plan.legs, isEmpty);
      expect(plan.totalMiles, 0);
    });

    test('ayni pin iki kez -> 0 mil bacak LISTEDE KALIR', () {
      // Sessizce elenirse DM yanlislikla ayni duragi iki kez sectigini
      // goremez.
      final plan = planRoute([p('a', 0.3, 0.3), p('a', 0.3, 0.3)], scale);
      expect(plan.legs, hasLength(1));
      expect(plan.legs.single.miles, 0);
    });

    test('extraMiles toplama girer', () {
      final plan = planRoute(
        [p('a', 0, 0), p('b', 1, 0)],
        scale,
        extraMiles: 25,
      );
      expect(plan.totalMiles, closeTo(125, 1e-9));
    });
  });

  group('estimateTravel — SRD gunluk degerleri', () {
    // Regresyon: bu iki test override'in kullanildiginin kanitidir. Carpimla
    // hesaplansaydi Hizli 4x8=32 (30 degil), Yavas 2x8=16 (18 degil) olurdu.
    test('30 mil @Hizli = tam 1 gun', () {
      final e = estimateTravel(totalMiles: 30, speed: speed('travelPaceFast'));
      expect(e.wholeDays, 1);
      expect(e.remainderHours, closeTo(0, 1e-9));
      expect(e.daysToAdvance, 1);
    });

    test('18 mil @Yavas = tam 1 gun (16 degil)', () {
      final e = estimateTravel(totalMiles: 18, speed: speed('travelPaceSlow'));
      expect(e.wholeDays, 1);
      expect(e.daysToAdvance, 1);
    });

    test('24 mil @Normal = tam 1 gun', () {
      final e = estimateTravel(
        totalMiles: 24,
        speed: speed('travelPaceNormal'),
      );
      expect(e.daysToAdvance, 1);
    });

    test('kismi gun YUKARI yuvarlanir ama artik saat ayrica raporlanir', () {
      final e = estimateTravel(totalMiles: 31, speed: speed('travelPaceFast'));
      expect(e.wholeDays, 1);
      expect(e.remainderHours, greaterThan(0));
      expect(e.daysToAdvance, 2);
    });

    test('toplam saat saatlik hizdan hesaplanir', () {
      final e = estimateTravel(
        totalMiles: 12,
        speed: speed('travelPaceNormal'), // 3 mil/saat
      );
      expect(e.totalHours, closeTo(4, 1e-9));
    });
  });

  group('estimateTravel — binek ve araclar', () {
    test('kosu ati 6 mil/saat x 8 saat = 48 mil/gun', () {
      final e = estimateTravel(
        totalMiles: 48,
        speed: speed('travelMountRidingHorse'),
      );
      expect(e.daysToAdvance, 1);
    });

    test('kadirga varsayilan 24 saat/gun ile 8 saatten farkli sonuc verir', () {
      final galley = speed('travelVehicleGalley'); // 4 mil/saat, 24 saat/gun
      final varsayilan = estimateTravel(totalMiles: 96, speed: galley);
      final sekizSaat = estimateTravel(
        totalMiles: 96,
        speed: galley,
        hoursPerDay: 8,
      );
      expect(varsayilan.daysToAdvance, 1); // 4x24 = 96
      expect(sekizSaat.daysToAdvance, 3); // 4x8 = 32 -> 3 gun
    });
  });

  group('estimateTravel — bozuk girdi', () {
    test('0 mil -> 0 gun', () {
      final e = estimateTravel(totalMiles: 0, speed: speed('travelPaceFast'));
      expect(e.daysToAdvance, 0);
      expect(e.totalMiles, 0);
    });

    test('ozel hiz 0 ya da negatif -> 0 gun, NaN yok', () {
      for (final mph in [0.0, -3.0]) {
        final e = estimateTravel(
          totalMiles: 100,
          speed: TravelSpeed.custom(mph),
        );
        expect(e.daysToAdvance, 0);
        expect(e.totalHours.isNaN, isFalse);
        expect(e.totalHours.isInfinite, isFalse);
        expect(e.remainderHours.isNaN, isFalse);
      }
    });

    test('NaN mesafe/hiz -> sayisal cop uretmez', () {
      final e = estimateTravel(
        totalMiles: double.nan,
        speed: speed('travelPaceFast'),
      );
      expect(e.daysToAdvance, 0);
      expect(e.totalMiles, 0);
      expect(e.totalHours.isNaN, isFalse);
    });

    test('saat/gun 0 -> 0 gun', () {
      final e = estimateTravel(
        totalMiles: 50,
        speed: speed('travelPaceNormal'),
        hoursPerDay: 0,
      );
      expect(e.daysToAdvance, 0);
    });
  });

  test('ozel hiz saatlik degerden gunluk hesaplar', () {
    final e = estimateTravel(
      totalMiles: 40,
      speed: TravelSpeed.custom(5), // 5 mil/saat x 8 saat = 40 mil/gun
    );
    expect(e.daysToAdvance, 1);
    expect(e.totalHours, closeTo(8, 1e-9));
  });
}
