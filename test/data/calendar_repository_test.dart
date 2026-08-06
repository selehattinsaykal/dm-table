import 'package:dm_table/data/calendar_repository.dart';
import 'package:dm_table/data/chronicle_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late CalendarRepository calendar;
  late ChronicleRepository chronicle;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    calendar = CalendarRepository(db);
    chronicle = ChronicleRepository(db);
  });
  tearDown(() => db.close());

  /// Esit olmayan ay uzunluklariyla kucuk bir takvim.
  Future<void> seedSmall() async {
    await calendar.addMonth('Kis', 10);
    await calendar.addMonth('Bahar', 5);
    await calendar.addMonth('Yaz', 12);
    for (final name in ['Birgun', 'Ikigun', 'Ucgun']) {
      await calendar.addWeekday(name);
    }
  }

  group('yapi', () {
    test('config yoksa kendiliginden olusur', () async {
      final config = await calendar.config();
      expect(config.id, CalendarRepository.configId);
      expect(config.currentYear, 1);
      expect(config.currentDay, 1);
    });

    test('ensureDefaultCalendar bir kez tohumlar', () async {
      await calendar.ensureDefaultCalendar(
        monthNames: ['Ocak', 'Subat'],
        weekdayNames: ['A', 'B'],
        seasonSpec: [(name: 'Yaz', color: 1, startMonth: 0, endMonth: 1)],
      );
      // Ikinci cagri mevcut takvimi EZMEMELI.
      await calendar.ensureDefaultCalendar(
        monthNames: ['Baska', 'Aylar', 'Uc'],
        weekdayNames: ['X'],
        seasonSpec: const [],
      );
      final months = await calendar.months();
      expect(months.map((m) => m.name), ['Ocak', 'Subat']);
      expect((await calendar.weekdays()).length, 2);
      expect((await calendar.seasons()).length, 1);
    });

    test('aylar eklenme sirasini korur, yeniden siralanabilir', () async {
      await seedSmall();
      final ids = [for (final m in await calendar.months()) m.id];
      await calendar.reorderMonths([ids[2], ids[0], ids[1]]);
      expect(
        [for (final m in await calendar.months()) m.name],
        ['Yaz', 'Kis', 'Bahar'],
      );
    });

    test('ay silinince sira yeniden numaralanir', () async {
      await seedSmall();
      final months = await calendar.months();
      await calendar.deleteMonth(months.first.id);
      final rest = await calendar.months();
      expect(rest.map((m) => m.name), ['Bahar', 'Yaz']);
      expect(rest.map((m) => m.sortOrder), [0, 1]);
    });
  });

  group('guncel tarih', () {
    test('setCurrentDate ayin uzunluguna kirpar', () async {
      await seedSmall();
      // Bahar 5 gun; 9. gun diye bir sey yok.
      await calendar.setCurrentDate((year: 3, monthIndex: 1, day: 9));
      final config = await calendar.config();
      expect(config.currentYear, 3);
      expect(config.currentMonthIndex, 1);
      expect(config.currentDay, 5);
    });

    test('gecersiz ay indeksi kirpilir', () async {
      await seedSmall();
      await calendar.setCurrentDate((year: 1, monthIndex: 99, day: 1));
      expect((await calendar.config()).currentMonthIndex, 2);
    });

    test('advanceDays ay ve yil sinirini gecer', () async {
      await seedSmall(); // yil = 10 + 5 + 12 = 27 gun
      await calendar.setCurrentDate((year: 1, monthIndex: 0, day: 10));
      var date = await calendar.advanceDays(1);
      expect(date, (year: 1, monthIndex: 1, day: 1));

      await calendar.setCurrentDate((year: 1, monthIndex: 2, day: 12));
      date = await calendar.advanceDays(1);
      expect(date, (year: 2, monthIndex: 0, day: 1));
    });

    test('advanceDays geri de calisir', () async {
      await seedSmall();
      await calendar.setCurrentDate((year: 2, monthIndex: 0, day: 1));
      expect(await calendar.advanceDays(-1), (year: 1, monthIndex: 2, day: 12));
    });
  });

  group('bicimlendirme', () {
    test('formatCurrent gun adi + ay + yil + son ekleri birlestirir', () async {
      await seedSmall();
      await calendar.updateConfig(eraLabel: 'Ucuncu Cag', yearSuffix: 'YS');
      await calendar.setCurrentDate((year: 1492, monthIndex: 1, day: 3));
      final snap = await calendar.snapshot();
      final text = CalendarRepository.formatCurrent(snap);
      expect(text, contains('3 Bahar 1492'));
      expect(text, contains('YS'));
      expect(text, contains('Ucuncu Cag'));
    });

    test(
      'mevsim adi guncel gune gore cozulur (yil sonunu saran aralik)',
      () async {
        await seedSmall();
        // Kis: son aydan (2) ilk aya (0) sarar.
        await calendar.addSeason(
          name: 'Kis',
          color: 0,
          startMonthIndex: 2,
          startDay: 10,
          endMonthIndex: 0,
          endDay: 5,
        );
        await calendar.setCurrentDate((year: 1, monthIndex: 0, day: 2));
        expect(
          CalendarRepository.currentSeasonName(await calendar.snapshot()),
          'Kis',
        );
        await calendar.setCurrentDate((year: 1, monthIndex: 1, day: 2));
        expect(
          CalendarRepository.currentSeasonName(await calendar.snapshot()),
          isNull,
        );
      },
    );
  });

  group('tarihce', () {
    test('olaylar kronolojik siralanir', () async {
      await seedSmall();
      final months = CalendarRepository.monthsOf(await calendar.months());
      final gec = await chronicle.create(
        title: 'Sonra',
        year: 5,
        monthIndex: 0,
        day: 1,
      );
      final erken = await chronicle.create(
        title: 'Once',
        year: 2,
        monthIndex: 2,
        day: 9,
      );
      final sorted = ChronicleRepository.sortEvents(
        await chronicle.events(),
        months,
      );
      expect(sorted.map((e) => e.id), [erken, gec]);
    });

    test('ay/gun bilinmeyen olay yilin basina duser', () async {
      await seedSmall();
      final months = CalendarRepository.monthsOf(await calendar.months());
      final yalnizYil = await chronicle.create(title: 'Yil', year: 4);
      final ayniYilSonu = await chronicle.create(
        title: 'Yil sonu',
        year: 4,
        monthIndex: 2,
        day: 1,
      );
      final sorted = ChronicleRepository.sortEvents(
        await chronicle.events(),
        months,
      );
      expect(sorted.map((e) => e.id), [yalnizYil, ayniYilSonu]);
    });

    test('eventsOn tek gunluk olayi yalniz o gun gosterir', () async {
      await seedSmall();
      final months = CalendarRepository.monthsOf(await calendar.months());
      await chronicle.create(title: 'Tek gun', year: 1, monthIndex: 0, day: 4);
      final events = await chronicle.events();
      expect(
        ChronicleRepository.eventsOn(events, (
          year: 1,
          monthIndex: 0,
          day: 4,
        ), months),
        hasLength(1),
      );
      expect(
        ChronicleRepository.eventsOn(events, (
          year: 1,
          monthIndex: 0,
          day: 5,
        ), months),
        isEmpty,
      );
    });

    test('suren olay araligindaki HER gunde gorunur', () async {
      await seedSmall();
      final months = CalendarRepository.monthsOf(await calendar.months());
      final id = await chronicle.create(
        title: 'Kusatma',
        year: 1,
        monthIndex: 0,
        day: 2,
      );
      await chronicle.update(
        id,
        endYear: const Value(1),
        endMonthIndex: const Value(1),
        endDay: const Value(3),
      );
      final events = await chronicle.events();
      for (final date in <({int year, int monthIndex, int day})>[
        (year: 1, monthIndex: 0, day: 2),
        (year: 1, monthIndex: 0, day: 9),
        (year: 1, monthIndex: 1, day: 3),
      ]) {
        expect(
          ChronicleRepository.eventsOn(events, date, months),
          hasLength(1),
          reason: '$date araliga dahil olmali',
        );
      }
      expect(
        ChronicleRepository.eventsOn(events, (
          year: 1,
          monthIndex: 1,
          day: 4,
        ), months),
        isEmpty,
      );
    });

    test('eraOf: elle baglanan cag yil araligini yener', () async {
      final dogru = await chronicle.createEra(
        name: 'Yil araligi',
        startYear: 0,
        endYear: 100,
      );
      final elle = await chronicle.createEra(
        name: 'Elle baglanan',
        startYear: 500,
      );
      final id = await chronicle.create(title: 'Olay', year: 50);
      await chronicle.update(id, eraId: Value(elle));

      final eras = await chronicle.eras();
      final event = (await chronicle.find(id))!;
      expect(ChronicleRepository.eraOf(event, eras)?.id, elle);

      await chronicle.update(id, eraId: const Value(null));
      final unlinked = (await chronicle.find(id))!;
      expect(ChronicleRepository.eraOf(unlinked, eras)?.id, dogru);
    });

    test('cag silinince olay yetim kalmaz, yalniz bagi duser', () async {
      final era = await chronicle.createEra(name: 'Silinecek', startYear: 0);
      final id = await chronicle.create(title: 'Olay', year: 5);
      await chronicle.update(id, eraId: Value(era));

      await chronicle.deleteEra(era);
      final event = await chronicle.find(id);
      expect(event, isNotNull);
      expect(event!.eraId, isNull);
    });

    test('sonu acik cag (endYear null) sonraki her yili kapsar', () async {
      final era = await chronicle.createEra(name: 'Suren', startYear: 100);
      final id = await chronicle.create(title: 'Gelecek', year: 9999);
      final eras = await chronicle.eras();
      expect(
        ChronicleRepository.eraOf((await chronicle.find(id))!, eras)?.id,
        era,
      );
    });
  });
}
