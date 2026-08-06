import 'package:dm_table/data/calendar_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/journey_repository.dart';
import 'package:dm_table/data/random_table_repository.dart';
import 'package:dm_table/data/reminder_repository.dart';
import 'package:dm_table/data/shop_repository.dart';
import 'package:dm_table/domain/rules/random_table.dart';
import 'package:dm_table/features/calendar/calendar_providers.dart';
import 'package:dm_table/features/world/journey_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Suren yolculuk: kayit, adim adim ilerleme, takvimin cift saymamasi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late JourneyRepository journeys;
  late RandomTableRepository tables;
  late CalendarRepository calendar;
  late JourneyRunner runner;

  const stops = <JourneyStop>[
    (pinId: 'p1', label: 'Kale', x: 0, y: 0),
    (pinId: null, label: 'Ara nokta 1', x: 0.5, y: 0),
    (pinId: 'p2', label: 'Liman', x: 1, y: 0),
  ];

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    journeys = JourneyRepository(db);
    tables = RandomTableRepository(db);
    calendar = CalendarRepository(db);
    runner = JourneyRunner(
      journeys: journeys,
      tables: tables,
      clock: GameClock(
        calendar: calendar,
        shops: ShopRepository(db),
        reminders: ReminderRepository(db),
      ),
    );
    await calendar.ensureDefaultCalendar(
      monthNames: [for (var i = 1; i <= 12; i++) 'Ay $i'],
      weekdayNames: [for (var i = 1; i <= 7; i++) 'Gün $i'],
      seasonSpec: const [],
    );
  });

  tearDown(() async => db.close());

  /// Normal tempo (24 mil/gun), karsilasmasiz 72 millik bir yolculuk.
  Future<String> startPlain({
    double totalMiles = 72,
    bool encountersOn = false,
    String? tableId,
    int threshold = 18,
    int checksPerDay = 1,
    bool advanceCalendar = true,
  }) => journeys.start(
    locationId: 'loc-1',
    stops: stops,
    totalMiles: totalMiles,
    speedKey: 'travelPaceNormal',
    hoursPerDay: 8,
    encountersOn: encountersOn,
    tableId: tableId,
    threshold: threshold,
    checksPerDay: checksPerDay,
    advanceCalendar: advanceCalendar,
  );

  test('duraklar (ara noktalar dahil) tam olarak geri okunur', () async {
    final id = await startPlain();
    final saved = JourneyRepository.decodeStops(
      (await journeys.find(id))!.stopsJson,
    );

    expect(saved, hasLength(3));
    expect(saved[1].pinId, isNull, reason: 'ara noktanin pini yok');
    expect(saved[1].label, 'Ara nokta 1');
    expect(saved[2].x, 1);
  });

  test('yeni yolculuk oncekini kapatir; aktif olan tek', () async {
    final first = await startPlain();
    final second = await startPlain();

    expect((await journeys.find(first))!.done, isTrue);
    expect((await journeys.active())!.id, second);
  });

  test(
    'karsilasmasiz yolculuk tek adimda varir ve takvimi ilerletir',
    () async {
      final id = await startPlain();

      final result = await runner.advance(id);

      expect(result!.arrived, isTrue);
      expect(result.journey.milesTravelled, 72);
      // 72 mil / 24 mil-gun = 3 gun.
      expect(result.daysAdvanced, 3);
      expect((await calendar.config()).currentDay, 4);
      expect(await journeys.active(), isNull, reason: 'yolculuk kapandi');
    },
  );

  test('takvim ilerletmesi kapaliysa tarih degismez', () async {
    final id = await startPlain(advanceCalendar: false);

    final result = await runner.advance(id);

    expect(result!.arrived, isTrue);
    expect(result.daysAdvanced, 0);
    expect((await calendar.config()).currentDay, 1);
  });

  test('karsilasma yolu boler; devam edilince gunler CIFT sayilmaz', () async {
    // Her kontrol tutsun diye esik 1: ilk dilimde kesin karsilasma cikar.
    final tableId = await tables.create('Yolda', diceSides: 6);
    await tables.update(
      tableId,
      rows: distributeEvenly(const ['Kurtlar', 'Tüccar'], 6),
    );
    final id = await startPlain(
      encountersOn: true,
      tableId: tableId,
      threshold: 1,
      checksPerDay: 1,
    );

    final first = await runner.advance(id);
    expect(first!.arrived, isFalse);
    expect(first.encounter, isNotNull);
    expect(first.journey.milesTravelled, lessThan(72));
    // Bekleyen karsilasma kayitli: sheet kapanip acilsa da durur.
    expect(JourneyRepository.pendingOf(first.journey), isNotNull);

    // Yolculuk boyunca toplam ilerletilen gun 3'u ASMAMALI.
    var total = first.daysAdvanced;
    var guard = 0;
    var current = first;
    while (!current.arrived && guard++ < 20) {
      current = (await runner.advance(id))!;
      total += current.daysAdvanced;
    }

    expect(current.arrived, isTrue);
    expect(current.journey.milesTravelled, 72);
    expect(total, 3, reason: 'duraklamak gunleri tekrar saydirmamali');
    expect((await calendar.config()).currentDay, 4);
  });

  test('"devam et" bekleyen karsilasmayi temizler', () async {
    final id = await startPlain(
      encountersOn: true,
      threshold: 1,
      checksPerDay: 1,
    );

    await runner.advance(id);
    expect(JourneyRepository.pendingOf((await journeys.find(id))!), isNotNull);

    await runner.advance(id);
    final after = (await journeys.find(id))!;
    // Ya yeni bir karsilasma var ya da yol temiz — ama ONCEKI kayit degil.
    expect(after.milesTravelled, greaterThan(0));
    expect(
      JourneyRepository.decodeEncounters(after.encounterLogJson).length,
      greaterThanOrEqualTo(2),
      reason: 'yasanan her karsilasma gunluge eklenir',
    );
  });

  test('silinmis tablo yolculugu kilitlemez', () async {
    final tableId = await tables.create('Silinecek', diceSides: 6);
    final id = await startPlain(
      encountersOn: true,
      tableId: tableId,
      threshold: 1,
    );
    await tables.delete(tableId);

    final result = await runner.advance(id);

    expect(result, isNotNull);
    expect(result!.encounter, isNotNull);
    expect(result.encounter!.text, isEmpty, reason: 'yalnizca "bir sey oldu"');
  });

  test('kapatilmis yolculuk ilerletilemez', () async {
    final id = await startPlain();
    await journeys.finish(id);

    expect(await runner.advance(id), isNull);
  });

  test('bozuk durak JSONu bos liste doner, firlatmaz', () {
    expect(JourneyRepository.decodeStops('bu json degil'), isEmpty);
    expect(JourneyRepository.decodeStops('{"a":1}'), isEmpty);
    // Koordinatsiz giris atilir.
    expect(JourneyRepository.decodeStops('[{"label":"x"}]'), isEmpty);
  });
}
