import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/calendar/game_calendar.dart';
import '../domain/calendar/reminders.dart';
import 'db/database.dart';

/// Tetiklenmiş bir hatırlatıcı: kayıt + hangi mutlak günde çalıştığı.
typedef DueReminder = ({CalendarReminder reminder, int day});

/// Takvim hatırlatıcıları: kayıt + "gün ilerledi, ne tetiklendi" hesabı.
///
/// Tekrar matematiği burada DEĞİL, `domain/calendar/reminders.dart`'ta (saf ve
/// doğrudan test edilir); burası yalnızca veriyi okur/yazar.
class ReminderRepository {
  ReminderRepository(this.db);

  final AppDatabase db;
  static const _uuid = Uuid();

  Stream<List<CalendarReminder>> watchAll() =>
      (db.select(db.calendarReminders)..orderBy([
            (t) => OrderingTerm(expression: t.sortOrder),
            (t) => OrderingTerm(expression: t.createdAt),
          ]))
          .watch();

  Future<List<CalendarReminder>> all() => (db.select(
    db.calendarReminders,
  )..orderBy([(t) => OrderingTerm(expression: t.sortOrder)])).get();

  static ReminderSpec specOf(CalendarReminder r) => (
    repeat: ReminderRepeat.fromCode(r.repeatKind),
    everyNDays: r.everyNDays,
    start: (year: r.startYear, monthIndex: r.startMonthIndex, day: r.startDay),
  );

  Future<String> create({
    required String title,
    required GameDate start,
    String body = '',
    ReminderRepeat repeat = ReminderRepeat.once,
    int everyNDays = 1,
  }) async {
    final id = 'rem-${_uuid.v4()}';
    final count = (await all()).length;
    await db
        .into(db.calendarReminders)
        .insert(
          CalendarRemindersCompanion.insert(
            id: id,
            title: title,
            startYear: start.year,
            startMonthIndex: start.monthIndex,
            startDay: start.day,
            body: Value(body),
            repeatKind: Value(repeat.code),
            everyNDays: Value(everyNDays < 1 ? 1 : everyNDays),
            sortOrder: Value(count),
          ),
        );
    return id;
  }

  Future<void> update(
    String id, {
    String? title,
    String? body,
    ReminderRepeat? repeat,
    int? everyNDays,
    GameDate? start,
    bool? done,
  }) async {
    await (db.update(
      db.calendarReminders,
    )..where((t) => t.id.equals(id))).write(
      CalendarRemindersCompanion(
        title: title == null ? const Value.absent() : Value(title),
        body: body == null ? const Value.absent() : Value(body),
        repeatKind: repeat == null ? const Value.absent() : Value(repeat.code),
        everyNDays: everyNDays == null
            ? const Value.absent()
            : Value(everyNDays < 1 ? 1 : everyNDays),
        startYear: start == null ? const Value.absent() : Value(start.year),
        startMonthIndex: start == null
            ? const Value.absent()
            : Value(start.monthIndex),
        startDay: start == null ? const Value.absent() : Value(start.day),
        done: done == null ? const Value.absent() : Value(done),
      ),
    );
  }

  Future<void> delete(String id) =>
      (db.delete(db.calendarReminders)..where((t) => t.id.equals(id))).go();

  /// `(fromDay, toDay]` aralığında tetiklenen hatırlatıcılar.
  ///
  /// Yan etkilidir: tetiklenenlerin `lastFiredDay`'i yazılır, tek seferlikler
  /// kapatılır. **`lastFiredDay` aynı günü iki kez bildirmeyi engeller** —
  /// DM tarihi elle geri alıp tekrar ilerletirse ya da aynı gün iki kez
  /// "1 gün ilerlet" derse hatırlatıcı yağmuru olmasın.
  Future<List<DueReminder>> fire({
    required int fromDay,
    required int toDay,
    required List<GameMonth> months,
  }) async {
    if (toDay <= fromDay) return const [];
    final rows = await all();
    final due = <DueReminder>[];

    for (final r in rows) {
      if (r.done) continue;
      final hits = occurrencesBetween(
        specOf(r),
        months,
        fromDay: fromDay,
        toDay: toDay,
      );
      final fresh = [
        for (final day in hits)
          if (r.lastFiredDay == null || day > r.lastFiredDay!) day,
      ];
      if (fresh.isEmpty) continue;

      for (final day in fresh) {
        due.add((reminder: r, day: day));
      }
      final isOnce =
          ReminderRepeat.fromCode(r.repeatKind) == ReminderRepeat.once;
      await (db.update(
        db.calendarReminders,
      )..where((t) => t.id.equals(r.id))).write(
        CalendarRemindersCompanion(
          lastFiredDay: Value(fresh.last),
          done: isOnce ? const Value(true) : const Value.absent(),
        ),
      );
    }

    due.sort((a, b) => a.day.compareTo(b.day));
    return due;
  }
}
