import 'package:dm_table/data/calendar_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/reminder_repository.dart';
import 'package:dm_table/data/shop_repository.dart';
import 'package:dm_table/domain/calendar/reminders.dart';
import 'package:dm_table/features/calendar/calendar_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hatırlatıcıların gün ilerletmeye bağlanması: `GameClock` günü değiştirince
/// aradaki tetiklenmeler bildirilmeli, aynı gün İKİ KEZ bildirilmemeli.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CalendarRepository calendar;
  late ReminderRepository reminders;
  late GameClock clock;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    calendar = CalendarRepository(db);
    reminders = ReminderRepository(db);
    clock = GameClock(
      calendar: calendar,
      shops: ShopRepository(db),
      reminders: reminders,
    );
    await calendar.ensureDefaultCalendar(
      monthNames: [for (var i = 1; i <= 12; i++) 'Ay $i'],
      weekdayNames: [for (var i = 1; i <= 7; i++) 'Gün $i'],
      seasonSpec: const [],
    );
  });

  tearDown(() async => db.close());

  Future<void> setToday(int year, int month, int day) =>
      calendar.setCurrentDate((year: year, monthIndex: month, day: day));

  test('tek seferlik hatirlatici gunu gelince tetiklenir ve kapanir', () async {
    await setToday(1, 0, 1);
    await reminders.create(
      title: 'Kervan gelir',
      start: (year: 1, monthIndex: 0, day: 4),
    );

    final quiet = await clock.advanceDays(2); // 1 -> 3
    expect(quiet.reminders, isEmpty);

    final hit = await clock.advanceDays(2); // 3 -> 5, 4'u atladik
    expect(hit.reminders, hasLength(1));
    expect(hit.reminders.single.reminder.title, 'Kervan gelir');

    // Tek seferlik: kapanir, bir daha tetiklenmez.
    expect((await reminders.all()).single.done, isTrue);
    final again = await clock.advanceDays(30);
    expect(again.reminders, isEmpty);
  });

  test('aylik hatirlatici her ay tetiklenir', () async {
    await setToday(1, 0, 1);
    await reminders.create(
      title: 'Vergi günü',
      start: (year: 1, monthIndex: 0, day: 1),
      repeat: ReminderRepeat.monthly,
    );

    final first = await clock.advanceDays(30); // 1. ayin 1'inden 2. ayin 1'ine
    expect(first.reminders, hasLength(1));

    final second = await clock.advanceDays(30);
    expect(second.reminders, hasLength(1));
    // Tekrarli olan KAPANMAZ.
    expect((await reminders.all()).single.done, isFalse);
  });

  test('tek adimda birden fazla tetiklenme hepsi bildirilir', () async {
    await setToday(1, 0, 1);
    await reminders.create(
      title: 'Nöbet değişimi',
      start: (year: 1, monthIndex: 0, day: 1),
      repeat: ReminderRepeat.everyNDays,
      everyNDays: 2,
    );

    final result = await clock.advanceDays(10);
    expect(result.reminders, hasLength(5)); // 3,5,7,9,11
  });

  test(
    'tarih geri alinip tekrar ilerletilince AYNI gun iki kez bildirilmez',
    () async {
      await setToday(1, 0, 1);
      await reminders.create(
        title: 'Ay tutulması',
        start: (year: 1, monthIndex: 0, day: 5),
        repeat: ReminderRepeat.yearly,
      );

      final first = await clock.advanceDays(10);
      expect(first.reminders, hasLength(1));

      // DM yanlislikla ilerletti, geri aldi, tekrar ilerletti.
      await clock.setDate((year: 1, monthIndex: 0, day: 1));
      final repeat = await clock.advanceDays(10);
      expect(repeat.reminders, isEmpty);
    },
  );

  test('kapatilmis hatirlatici tetiklenmez', () async {
    await setToday(1, 0, 1);
    final id = await reminders.create(
      title: 'Kapalı',
      start: (year: 1, monthIndex: 0, day: 1),
      repeat: ReminderRepeat.monthly,
    );
    await reminders.update(id, done: true);

    final result = await clock.advanceDays(60);
    expect(result.reminders, isEmpty);
  });

  test('gunu geri almak hicbir sey tetiklemez', () async {
    await setToday(1, 5, 10);
    await reminders.create(
      title: 'Geçmiş',
      start: (year: 1, monthIndex: 0, day: 1),
      repeat: ReminderRepeat.monthly,
    );

    final result = await clock.advanceDays(-30);
    expect(result.reminders, isEmpty);
  });
}
