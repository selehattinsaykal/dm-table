import 'package:dm_table/domain/calendar/game_calendar.dart';
import 'package:dm_table/domain/calendar/reminders.dart';
import 'package:flutter_test/flutter_test.dart';

/// Takvim hatırlatıcılarının saf tekrar matematiği.
///
/// Takvim yapısı kampanyaya göre değiştiği için (ay sayısı ve ay uzunlukları
/// serbest) tekrar hesabı ay uzunluklarına duyarlı olmak zorunda.
void main() {
  // 12 x 30 = 360 günlük düz takvim.
  final flat = [for (var i = 1; i <= 12; i++) (name: 'Ay $i', days: 30)];

  // Değişken uzunluklu takvim: 2. ay 28 gün — "her ayın 30'u" burada
  // ayın son gününe çekilmeli.
  final ragged = [
    (name: 'Bir', days: 31),
    (name: 'İki', days: 28),
    (name: 'Üç', days: 31),
  ];

  ReminderSpec spec(
    ReminderRepeat repeat, {
    int everyNDays = 1,
    int year = 1,
    int month = 0,
    int day = 1,
  }) => (
    repeat: repeat,
    everyNDays: everyNDays,
    start: (year: year, monthIndex: month, day: day),
  );

  group('once', () {
    test('aralikta tek kez doner', () {
      final start = absoluteDay((year: 1, monthIndex: 0, day: 5), flat);
      final hits = occurrencesBetween(
        spec(ReminderRepeat.once, day: 5),
        flat,
        fromDay: start - 3,
        toDay: start + 3,
      );
      expect(hits, [start]);
    });

    test('alt sinir HARIC, ust sinir DAHIL', () {
      final start = absoluteDay((year: 1, monthIndex: 0, day: 5), flat);
      expect(
        occurrencesBetween(
          spec(ReminderRepeat.once, day: 5),
          flat,
          fromDay: start,
          toDay: start + 5,
        ),
        isEmpty,
      );
      expect(
        occurrencesBetween(
          spec(ReminderRepeat.once, day: 5),
          flat,
          fromDay: start - 1,
          toDay: start,
        ),
        [start],
      );
    });
  });

  group('everyNDays', () {
    test('baslangictan itibaren periyotla tekrarlar', () {
      final start = absoluteDay((year: 1, monthIndex: 0, day: 1), flat);
      final hits = occurrencesBetween(
        spec(ReminderRepeat.everyNDays, everyNDays: 7),
        flat,
        fromDay: start,
        toDay: start + 21,
      );
      expect(hits, [start + 7, start + 14, start + 21]);
    });

    test('baslangictan ONCE tetiklenmez', () {
      final start = absoluteDay((year: 1, monthIndex: 5, day: 1), flat);
      final hits = occurrencesBetween(
        spec(ReminderRepeat.everyNDays, everyNDays: 3, month: 5),
        flat,
        fromDay: start - 100,
        toDay: start - 1,
      );
      expect(hits, isEmpty);
    });

    test('uzak gelecege atlama gun gun donmeden hesaplanir', () {
      final start = absoluteDay((year: 1, monthIndex: 0, day: 1), flat);
      final hits = occurrencesBetween(
        spec(ReminderRepeat.everyNDays, everyNDays: 10),
        flat,
        fromDay: start + 100000,
        toDay: start + 100020,
      );
      expect(hits, hasLength(2));
      expect(hits.every((d) => (d - start) % 10 == 0), isTrue);
    });

    test('gecersiz periyot (0) gunluk sayilir', () {
      final start = absoluteDay((year: 1, monthIndex: 0, day: 1), flat);
      final hits = occurrencesBetween(
        spec(ReminderRepeat.everyNDays, everyNDays: 0),
        flat,
        fromDay: start,
        toDay: start + 3,
      );
      expect(hits, [start + 1, start + 2, start + 3]);
    });
  });

  group('monthly', () {
    test('her ayin ayni gunu', () {
      final start = absoluteDay((year: 1, monthIndex: 0, day: 1), flat);
      final hits = occurrencesBetween(
        spec(ReminderRepeat.monthly, day: 1),
        flat,
        fromDay: start,
        toDay: start + 90,
      );
      expect(hits, hasLength(3));
      for (final d in hits) {
        expect(fromAbsoluteDay(d, flat).day, 1);
      }
    });

    test('kisa ayda ayin SON gunune cekilir, atlanmaz', () {
      final start = absoluteDay((year: 1, monthIndex: 0, day: 30), ragged);
      final hits = occurrencesBetween(
        spec(ReminderRepeat.monthly, day: 30),
        ragged,
        fromDay: start,
        toDay: start + 60,
      );
      final dates = [for (final d in hits) fromAbsoluteDay(d, ragged)];
      // 28 gunluk ayda 28'ine dusmeli.
      expect(dates.any((d) => d.monthIndex == 1 && d.day == 28), isTrue);
    });
  });

  group('yearly', () {
    test('yilda bir tekrarlar', () {
      final start = absoluteDay((year: 1, monthIndex: 3, day: 12), flat);
      final hits = occurrencesBetween(
        spec(ReminderRepeat.yearly, month: 3, day: 12),
        flat,
        fromDay: start,
        toDay: start + 360 * 3,
      );
      expect(hits, hasLength(3));
      for (final d in hits) {
        final date = fromAbsoluteDay(d, flat);
        expect(date.monthIndex, 3);
        expect(date.day, 12);
      }
    });

    test('yil sonuna yakin capa sonraki yilda yakalanir', () {
      // Capa 11. ayin 20'si; pencere bir sonraki yilin baslarindan sonrasi.
      final anchor = absoluteDay((year: 1, monthIndex: 11, day: 20), flat);
      final hits = occurrencesBetween(
        spec(ReminderRepeat.yearly, month: 11, day: 20),
        flat,
        fromDay: anchor + 5,
        toDay: anchor + 360,
      );
      expect(hits, [anchor + 360]);
    });
  });

  group('nextOccurrence', () {
    test('siradaki tarihi bulur', () {
      final start = absoluteDay((year: 1, monthIndex: 0, day: 1), flat);
      final next = nextOccurrence(
        spec(ReminderRepeat.monthly, day: 1),
        flat,
        afterDay: start,
      );
      expect(next, absoluteDay((year: 1, monthIndex: 1, day: 1), flat));
    });

    test('gecmis tek seferlik icin null doner', () {
      final start = absoluteDay((year: 1, monthIndex: 0, day: 1), flat);
      expect(
        nextOccurrence(
          spec(ReminderRepeat.once, day: 1),
          flat,
          afterDay: start + 10,
        ),
        isNull,
      );
    });
  });
}
