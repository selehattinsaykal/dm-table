import 'dart:math';

import 'package:dm_table/domain/rules/random_table.dart';
import 'package:dm_table/domain/rules/travel_encounters.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sirayla verilen sayilari donduren sahte zar.
///
/// `Random` sinifinin `nextInt`i disindaki uyeleri bu modulde kullanilmadigi
/// icin yalnizca o uygulanir; liste bitince bastan sarar.
class _ScriptedRandom implements Random {
  _ScriptedRandom(this.values);

  final List<int> values;
  int _i = 0;

  /// `nextInt(n)` 0..n-1 doner; senaryolar 1 tabanli zar yazabilsin diye
  /// degerler burada 1 dusurulur.
  @override
  int nextInt(int max) {
    final value = values[_i++ % values.length];
    return (value - 1) % max;
  }

  @override
  bool nextBool() => throw UnimplementedError();

  /// Karsilasmanin dilim ICINDEKI konumu icin kullaniliyor; hep ortayi verir.
  /// Senaryo listesini TUKETMEZ — boylece zar dizileri okunur kalir.
  @override
  double nextDouble() => 0.5;
}

void main() {
  final rows = distributeEvenly(const ['Kurtlar', 'Tüccar', 'Fırtına'], 6);

  test('esigin altindaki atislar donmez', () {
    final result = rollTravelEncounters(
      days: 3,
      checksPerDay: 1,
      threshold: 18,
      rng: _ScriptedRandom([1, 10, 17]),
    );
    expect(result, isEmpty);
  });

  test('esige ULASAN atis tetikler (>=, > degil)', () {
    final result = rollTravelEncounters(
      days: 1,
      checksPerDay: 1,
      threshold: 18,
      rng: _ScriptedRandom([18]),
    );
    expect(result, hasLength(1));
    expect(result.single.check, 18);
  });

  test('gun ve kontrol numaralari 1 tabanli ve sirali', () {
    // Her atis tutuyor: 2 gun x 2 kontrol = 4 karsilasma.
    final result = rollTravelEncounters(
      days: 2,
      checksPerDay: 2,
      threshold: 11,
      rng: _ScriptedRandom([20]),
    );
    expect(
      [for (final e in result) (e.day, e.checkIndex)],
      [(1, 1), (1, 2), (2, 1), (2, 2)],
    );
  });

  test('tetiklenince tabloya ayrica zar atilir', () {
    // Once d20 (tetikleme), sonra tablo zari: 20 tutar, 1 tabloda ilk satir.
    final result = rollTravelEncounters(
      days: 1,
      checksPerDay: 1,
      threshold: 18,
      rows: rows,
      tableSides: 6,
      rng: _ScriptedRandom([20, 1]),
    );
    expect(result.single.tableRoll, 1);
    expect(result.single.text, 'Kurtlar');
  });

  test('tablo verilmezse yalnizca tetikleme bilgisi doner', () {
    final result = rollTravelEncounters(
      days: 1,
      checksPerDay: 1,
      threshold: 11,
      rng: _ScriptedRandom([20]),
    );
    expect(result.single.tableRoll, 0);
    expect(result.single.text, isEmpty);
  });

  test('bosluklu tabloda satir bulunamazsa metin bos, zar korunur', () {
    // Yalnizca 1-2'yi kapsayan tablo; 6 atisi bosluga denk geliyor.
    const partial = [(min: 1, max: 2, text: 'Kurtlar')];
    final result = rollTravelEncounters(
      days: 1,
      checksPerDay: 1,
      threshold: 11,
      rows: partial,
      tableSides: 6,
      rng: _ScriptedRandom([20, 6]),
    );
    expect(result.single.tableRoll, 6);
    expect(result.single.text, isEmpty);
  });

  test('gun ya da kontrol sayisi sifirsa hic zar atilmaz', () {
    expect(
      rollTravelEncounters(days: 0, checksPerDay: 2, threshold: 11),
      isEmpty,
    );
    expect(
      rollTravelEncounters(days: 5, checksPerDay: 0, threshold: 11),
      isEmpty,
    );
  });

  test('esik 21 (imkansiz) hicbir sey tetiklemez', () {
    final result = rollTravelEncounters(
      days: 10,
      checksPerDay: 4,
      threshold: 21,
      rng: _ScriptedRandom([20]),
    );
    expect(result, isEmpty);
  });

  test('yuzde karsiligi', () {
    expect(encounterChancePercent(18), 15);
    expect(encounterChancePercent(20), 5);
    expect(encounterChancePercent(11), 50);
    // Arayuz sinirlarinin disinda da anlamli kalir.
    expect(encounterChancePercent(21), 0);
    expect(encounterChancePercent(1), 100);
  });

  test('gercek Random ile uzun yolculukta makul sayida karsilasma cikar', () {
    // Tohumlu Random: kacinci calistirmada olursa olsun ayni sonuc.
    final result = rollTravelEncounters(
      days: 100,
      checksPerDay: 1,
      threshold: 18,
      rng: Random(42),
    );
    // %15 x 100 gun; genis ama anlamli bir aralik.
    expect(result.length, inInclusiveRange(5, 30));
    expect(result.every((e) => e.check >= 18), isTrue);
  });

  group('advanceJourney', () {
    // 24 mil/gun, gunde 2 kontrol => her dilim 12 mil.
    JourneyStep step({
      double from = 0,
      int checksDone = 0,
      double total = 60,
      bool on = true,
      Random? rng,
      List<RandomTableRow> rows = const [],
    }) => advanceJourney(
      totalMiles: total,
      milesTravelled: from,
      checksDone: checksDone,
      milesPerDay: 24,
      checksPerDay: 2,
      encountersOn: on,
      threshold: 18,
      rows: rows,
      tableSides: 6,
      rng: rng,
    );

    test('karsilasma kapaliyken tek adimda hedefe varilir', () {
      final s = step(on: false);
      expect(s.arrived, isTrue);
      expect(s.milesTravelled, 60);
      expect(s.encounter, isNull);
    });

    test('hicbir atis tutmazsa hedefe varilir', () {
      final s = step(rng: _ScriptedRandom([1]));
      expect(s.arrived, isTrue);
      expect(s.milesTravelled, 60);
      // 60 mil / 12 mil dilim = 5 kontrol.
      expect(s.checksDone, 5);
    });

    test('tetikleyen dilimin ICINDE durulur', () {
      // 1. atis tutmaz, 2. atis tutar => 2. dilim (12..24 mil) icinde durur.
      final s = step(rng: _ScriptedRandom([1, 20, 10]));
      expect(s.arrived, isFalse);
      expect(s.checksDone, 2);
      expect(s.milesTravelled, greaterThanOrEqualTo(12));
      expect(s.milesTravelled, lessThanOrEqualTo(24));
      expect(s.encounter, isNotNull);
    });

    test('duran yolculuk kaldigi yerden devam eder', () {
      // 2 kontrol yapilmis, 18. milde duruluyor; sonraki dilim 24'te biter.
      final s = step(from: 18, checksDone: 2, rng: _ScriptedRandom([1]));
      expect(s.arrived, isTrue);
      expect(s.milesTravelled, 60);
      expect(s.checksDone, 5, reason: 'kalan 3 dilim icin zar atilir');
    });

    test('karsilasma gun ve kontrol numarasini dogru hesaplar', () {
      // 3. kontrol = 2. gunun 1. kontrolu (gunde 2 kontrol).
      final s = step(rng: _ScriptedRandom([1, 1, 20, 3]));
      expect(s.encounter!.day, 2);
      expect(s.encounter!.checkIndex, 1);
    });

    test('tablo bagliysa satir da cekilir', () {
      final s = step(
        rows: distributeEvenly(const ['Kurtlar', 'Tüccar'], 6),
        rng: _ScriptedRandom([20, 1]),
      );
      expect(s.encounter!.text, 'Kurtlar');
    });

    test('son dilimde tetiklenirse durak hedefi asmaz', () {
      // 54. milden devam; kalan 6 mil, atis tutuyor.
      final s = step(from: 54, checksDone: 4, rng: _ScriptedRandom([20, 1]));
      expect(s.milesTravelled, lessThanOrEqualTo(60));
      expect(s.milesTravelled, greaterThanOrEqualTo(54));
      expect(s.arrived, isFalse, reason: 'once karsilasma gosterilir');
    });

    test('hedefe varmis yolculuk bir adim daha atmaz', () {
      final s = step(from: 60, checksDone: 5, rng: _ScriptedRandom([20]));
      expect(s.arrived, isTrue);
      expect(s.encounter, isNull);
    });

    test('bozuk gunluk mesafe sonsuz donguye girmez', () {
      final s = advanceJourney(
        totalMiles: 60,
        milesTravelled: 0,
        checksDone: 0,
        milesPerDay: 0,
        checksPerDay: 2,
        encountersOn: true,
        threshold: 18,
      );
      expect(s.arrived, isTrue);
    });
  });

  group('daysElapsedFor', () {
    test('kismi gun yukari yuvarlanir', () {
      expect(daysElapsedFor(0, 24), 0);
      expect(daysElapsedFor(1, 24), 1);
      expect(daysElapsedFor(24, 24), 1);
      expect(daysElapsedFor(25, 24), 2);
      expect(daysElapsedFor(60, 24), 3);
    });

    test('bozuk girdide 0', () {
      expect(daysElapsedFor(10, 0), 0);
      expect(daysElapsedFor(-5, 24), 0);
    });
  });
}
