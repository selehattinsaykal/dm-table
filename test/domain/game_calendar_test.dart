import 'package:dm_table/domain/calendar/game_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Esit olmayan ay uzunluklari: aritmetigin "her ay 30 gun" varsayimina
  // kacmadigini kanitlar.
  const months = <GameMonth>[
    (name: 'Karakis', days: 31),
    (name: 'Cozulme', days: 28),
    (name: 'Tohum', days: 30),
    (name: 'Hasat', days: 33),
  ];
  const yearLength = 31 + 28 + 30 + 33; // 122

  group('temel olcumler', () {
    test('daysInYear aylari toplar', () {
      expect(daysInYear(months), yearLength);
      expect(daysInYear(const []), 0);
    });

    test('bozuk ay uzunlugu en az 1 sayilir', () {
      expect(daysInYear(const [(name: 'Bos', days: 0)]), 1);
      expect(daysInMonth(const [(name: 'Bos', days: -5)], 0), 1);
    });

    test('sinir disi ay indeksi kirpilir', () {
      expect(daysInMonth(months, 99), 33);
      expect(daysInMonth(months, -3), 31);
    });
  });

  group('absoluteDay / fromAbsoluteDay', () {
    test('takvimin ilk gunu sifirdir', () {
      expect(absoluteDay((year: 0, monthIndex: 0, day: 1), months), 0);
    });

    test('ay basi onceki aylarin toplamina esit', () {
      expect(
        absoluteDay((year: 0, monthIndex: 3, day: 1), months),
        31 + 28 + 30,
      );
    });

    test('yil gecisi', () {
      expect(absoluteDay((year: 1, monthIndex: 0, day: 1), months), yearLength);
      expect(
        absoluteDay((year: 3, monthIndex: 0, day: 1), months),
        3 * yearLength,
      );
    });

    test('gidis-donus: her gun kendine geri cozulur', () {
      for (final date in <GameDate>[
        (year: 0, monthIndex: 0, day: 1),
        (year: 1, monthIndex: 2, day: 17),
        (year: 1492, monthIndex: 3, day: 33),
        (year: 7, monthIndex: 1, day: 28),
      ]) {
        expect(fromAbsoluteDay(absoluteDay(date, months), months), date);
      }
    });

    test('negatif yillar (cag oncesi) dogru cozulur', () {
      const date = (year: -3, monthIndex: 2, day: 5);
      final absolute = absoluteDay(date, months);
      expect(absolute, lessThan(0));
      expect(fromAbsoluteDay(absolute, months), date);
      // -1. yilin son gunu, 0. yilin ilk gununden tam bir gun once.
      expect(fromAbsoluteDay(-1, months), (year: -1, monthIndex: 3, day: 33));
    });

    test('ay tasmasi kirpilir (32 Cozulme diye bir gun yok)', () {
      final absolute = absoluteDay((year: 0, monthIndex: 1, day: 99), months);
      expect(fromAbsoluteDay(absolute, months), (
        year: 0,
        monthIndex: 1,
        day: 28,
      ));
    });
  });

  group('advance', () {
    test('ay sinirini gecer', () {
      expect(advance((year: 0, monthIndex: 0, day: 31), 1, months), (
        year: 0,
        monthIndex: 1,
        day: 1,
      ));
    });

    test('yil sinirini gecer', () {
      expect(advance((year: 5, monthIndex: 3, day: 33), 1, months), (
        year: 6,
        monthIndex: 0,
        day: 1,
      ));
    });

    test('geri gitmek de calisir', () {
      expect(advance((year: 6, monthIndex: 0, day: 1), -1, months), (
        year: 5,
        monthIndex: 3,
        day: 33,
      ));
    });

    test('tam bir yil ilerletmek ayni gune getirir', () {
      const date = (year: 100, monthIndex: 2, day: 12);
      expect(advance(date, yearLength, months), (
        year: 101,
        monthIndex: 2,
        day: 12,
      ));
    });
  });

  group('weekdayIndex', () {
    test('takvimin ilk gunu haftanin ilk gunudur', () {
      expect(weekdayIndex((year: 0, monthIndex: 0, day: 1), months, 7), 0);
    });

    test('ardisik gunler ardisik hafta gunleri', () {
      expect(weekdayIndex((year: 0, monthIndex: 0, day: 8), months, 7), 0);
      expect(weekdayIndex((year: 0, monthIndex: 0, day: 4), months, 7), 3);
    });

    test('negatif gunlerde de aralikta kalir', () {
      final index = weekdayIndex((year: -2, monthIndex: 1, day: 3), months, 5);
      expect(index, inInclusiveRange(0, 4));
    });

    test('gun adi yoksa cokmez', () {
      expect(weekdayIndex((year: 1, monthIndex: 0, day: 1), months, 0), 0);
    });
  });

  group('seasonAt', () {
    const seasons = <GameSeason>[
      (
        name: 'Ilkbahar',
        startMonthIndex: 1,
        startDay: 1,
        endMonthIndex: 2,
        endDay: 30,
      ),
      // Yil sonunu SARAN mevsim: Hasat 10'dan Karakis 20'ye.
      (
        name: 'Kis',
        startMonthIndex: 3,
        startDay: 10,
        endMonthIndex: 0,
        endDay: 20,
      ),
    ];

    test('duz aralik', () {
      expect(
        seasonAt((year: 1, monthIndex: 1, day: 15), seasons)?.name,
        'Ilkbahar',
      );
    });

    test('yil sonunu saran aralik iki ucta da tutar', () {
      expect(seasonAt((year: 1, monthIndex: 3, day: 20), seasons)?.name, 'Kis');
      expect(seasonAt((year: 1, monthIndex: 0, day: 5), seasons)?.name, 'Kis');
    });

    test('aralik disi gun mevsimsiz', () {
      expect(seasonAt((year: 1, monthIndex: 0, day: 25), seasons), isNull);
    });

    test('mevsim yoksa null', () {
      expect(seasonAt((year: 1, monthIndex: 0, day: 1), const []), isNull);
    });
  });

  group('formatGameDate', () {
    test('gun, ay adi, yil ve son ekler', () {
      expect(
        formatGameDate(
          (year: 1492, monthIndex: 3, day: 12),
          months,
          yearSuffix: 'YS',
          eraLabel: 'Ucuncu Cag',
        ),
        '12 Hasat 1492 YS Ucuncu Cag',
      );
    });

    test('gun adi verilirse basa gelir', () {
      expect(
        formatGameDate(
          (year: 1, monthIndex: 0, day: 3),
          months,
          weekdayName: 'Orsgun',
        ),
        'Orsgun, 3 Karakis 1',
      );
    });

    test('ay listesi bossa cokmez', () {
      expect(formatGameDate((year: 5, monthIndex: 0, day: 1), const []), '1 5');
    });
  });
}
