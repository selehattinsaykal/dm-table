import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/calendar/game_calendar.dart';
import 'db/database.dart';

/// Takvimin yapısı + güncel tarih + mevsimler, tek okumada.
typedef CalendarSnapshot = ({
  CalendarConfigData config,
  List<CalendarMonth> months,
  List<CalendarWeekday> weekdays,
  List<CalendarSeason> seasons,
});

/// Oyun-içi takvimi ve tarihçeyi okur/yazar.
///
/// Takvim YAPISI tamamen kullanıcı tanımlıdır (kaç ay, her ay kaç gün, gün
/// adları, mevsim aralıkları); aritmetik `domain/calendar/game_calendar.dart`
/// içindeki saf fonksiyonlarda.
class CalendarRepository {
  CalendarRepository(this.db);

  final AppDatabase db;
  static const _uuid = Uuid();
  static const configId = 'default';

  // --- Yapi ----------------------------------------------------------------

  Future<CalendarConfigData> config() async {
    final row = await (db.select(
      db.calendarConfig,
    )..where((t) => t.id.equals(configId))).getSingleOrNull();
    if (row != null) return row;
    await db
        .into(db.calendarConfig)
        .insert(
          CalendarConfigCompanion.insert(id: configId),
          mode: InsertMode.insertOrIgnore,
        );
    return (await (db.select(
      db.calendarConfig,
    )..where((t) => t.id.equals(configId))).getSingle());
  }

  Stream<CalendarConfigData?> watchConfig() => (db.select(
    db.calendarConfig,
  )..where((t) => t.id.equals(configId))).watchSingleOrNull();

  Stream<List<CalendarMonth>> watchMonths() => (db.select(
    db.calendarMonths,
  )..orderBy([(t) => OrderingTerm(expression: t.sortOrder)])).watch();

  Stream<List<CalendarWeekday>> watchWeekdays() => (db.select(
    db.calendarWeekdays,
  )..orderBy([(t) => OrderingTerm(expression: t.sortOrder)])).watch();

  Stream<List<CalendarSeason>> watchSeasons() => (db.select(
    db.calendarSeasons,
  )..orderBy([(t) => OrderingTerm(expression: t.sortOrder)])).watch();

  Future<List<CalendarMonth>> months() => (db.select(
    db.calendarMonths,
  )..orderBy([(t) => OrderingTerm(expression: t.sortOrder)])).get();

  Future<List<CalendarWeekday>> weekdays() => (db.select(
    db.calendarWeekdays,
  )..orderBy([(t) => OrderingTerm(expression: t.sortOrder)])).get();

  Future<List<CalendarSeason>> seasons() => (db.select(
    db.calendarSeasons,
  )..orderBy([(t) => OrderingTerm(expression: t.sortOrder)])).get();

  /// Takvimin tamamını tek seferde okur (oturum yayını ve biçimlendirme için).
  Future<CalendarSnapshot> snapshot() async => (
    config: await config(),
    months: await months(),
    weekdays: await weekdays(),
    seasons: await seasons(),
  );

  /// Ay listesini `game_calendar`'ın anladığı saf biçime çevirir.
  static List<GameMonth> monthsOf(List<CalendarMonth> rows) => [
    for (final m in rows) (name: m.name, days: m.days),
  ];

  static List<GameSeason> seasonsOf(List<CalendarSeason> rows) => [
    for (final s in rows)
      (
        name: s.name,
        startMonthIndex: s.startMonthIndex,
        startDay: s.startDay,
        endMonthIndex: s.endMonthIndex,
        endDay: s.endDay,
      ),
  ];

  static GameDate dateOf(CalendarConfigData config) => (
    year: config.currentYear,
    monthIndex: config.currentMonthIndex,
    day: config.currentDay,
  );

  /// Güncel tarihin okunur hâli ("Orsgün, 12 Hasat 1492 YS Üçüncü Çağ").
  static String formatCurrent(CalendarSnapshot snap) {
    final months = monthsOf(snap.months);
    final date = dateOf(snap.config);
    final weekdayName = snap.weekdays.isEmpty
        ? null
        : snap.weekdays[weekdayIndex(date, months, snap.weekdays.length)].name;
    return formatGameDate(
      date,
      months,
      weekdayName: weekdayName,
      eraLabel: snap.config.eraLabel,
      yearSuffix: snap.config.yearSuffix,
      beforeYearSuffix: snap.config.beforeYearSuffix,
    );
  }

  /// Güncel tarihin mevsimi (yoksa `null`).
  static String? currentSeasonName(CalendarSnapshot snap) =>
      seasonAt(dateOf(snap.config), seasonsOf(snap.seasons))?.name;

  // --- Yapi duzenleme ------------------------------------------------------

  Future<void> updateConfig({
    String? calendarName,
    String? eraLabel,
    String? yearSuffix,
    String? beforeYearSuffix,
  }) async {
    await config(); // satir yoksa olustur
    await (db.update(
      db.calendarConfig,
    )..where((t) => t.id.equals(configId))).write(
      CalendarConfigCompanion(
        calendarName: calendarName == null
            ? const Value.absent()
            : Value(calendarName),
        eraLabel: eraLabel == null ? const Value.absent() : Value(eraLabel),
        yearSuffix: yearSuffix == null
            ? const Value.absent()
            : Value(yearSuffix),
        beforeYearSuffix: beforeYearSuffix == null
            ? const Value.absent()
            : Value(beforeYearSuffix),
      ),
    );
  }

  /// DM "bugünü" belirler. Ay/gün, takvimin yapısına göre kırpılır — kullanıcı
  /// aylar kısaldıktan sonra geçersiz bir güne saplanmasın.
  Future<void> setCurrentDate(GameDate date) async {
    await config();
    final all = await months();
    final list = monthsOf(all);
    final monthIndex = list.isEmpty
        ? 0
        : date.monthIndex.clamp(0, list.length - 1);
    final day = date.day.clamp(1, daysInMonth(list, monthIndex));
    await (db.update(
      db.calendarConfig,
    )..where((t) => t.id.equals(configId))).write(
      CalendarConfigCompanion(
        currentYear: Value(date.year),
        currentMonthIndex: Value(monthIndex),
        currentDay: Value(day),
      ),
    );
  }

  /// Günü [days] kadar ilerletir (negatifse geri alır) ve yeni tarihi döner.
  Future<GameDate> advanceDays(int days) async {
    final snap = await snapshot();
    final next = advance(dateOf(snap.config), days, monthsOf(snap.months));
    await setCurrentDate(next);
    return next;
  }

  Future<String> addMonth(String name, int days) async {
    final id = 'cm-${_uuid.v4()}';
    final count = (await months()).length;
    await db
        .into(db.calendarMonths)
        .insert(
          CalendarMonthsCompanion.insert(
            id: id,
            name: Value(name),
            days: Value(days),
            sortOrder: Value(count),
          ),
        );
    return id;
  }

  Future<void> updateMonth(String id, {String? name, int? days}) =>
      (db.update(db.calendarMonths)..where((t) => t.id.equals(id))).write(
        CalendarMonthsCompanion(
          name: name == null ? const Value.absent() : Value(name),
          days: days == null ? const Value.absent() : Value(days),
        ),
      );

  Future<void> deleteMonth(String id) async {
    await (db.delete(db.calendarMonths)..where((t) => t.id.equals(id))).go();
    await _resequence();
  }

  /// Ayları verilen sıraya göre yeniden numaralar.
  Future<void> reorderMonths(List<String> idsInOrder) async {
    await db.batch((b) {
      for (final (i, id) in idsInOrder.indexed) {
        b.update(
          db.calendarMonths,
          CalendarMonthsCompanion(sortOrder: Value(i)),
          where: (t) => t.id.equals(id),
        );
      }
    });
  }

  Future<void> _resequence() async {
    final rows = await months();
    await reorderMonths([for (final m in rows) m.id]);
  }

  Future<String> addWeekday(String name) async {
    final id = 'cw-${_uuid.v4()}';
    final count = (await weekdays()).length;
    await db
        .into(db.calendarWeekdays)
        .insert(
          CalendarWeekdaysCompanion.insert(
            id: id,
            name: Value(name),
            sortOrder: Value(count),
          ),
        );
    return id;
  }

  Future<void> updateWeekday(String id, String name) =>
      (db.update(db.calendarWeekdays)..where((t) => t.id.equals(id))).write(
        CalendarWeekdaysCompanion(name: Value(name)),
      );

  Future<void> deleteWeekday(String id) =>
      (db.delete(db.calendarWeekdays)..where((t) => t.id.equals(id))).go();

  Future<String> addSeason({
    required String name,
    required int color,
    required int startMonthIndex,
    required int startDay,
    required int endMonthIndex,
    required int endDay,
  }) async {
    final id = 'cs-${_uuid.v4()}';
    final count = (await seasons()).length;
    await db
        .into(db.calendarSeasons)
        .insert(
          CalendarSeasonsCompanion.insert(
            id: id,
            name: Value(name),
            color: Value(color),
            startMonthIndex: Value(startMonthIndex),
            startDay: Value(startDay),
            endMonthIndex: Value(endMonthIndex),
            endDay: Value(endDay),
            sortOrder: Value(count),
          ),
        );
    return id;
  }

  Future<void> updateSeason(
    String id, {
    String? name,
    int? color,
    int? startMonthIndex,
    int? startDay,
    int? endMonthIndex,
    int? endDay,
  }) => (db.update(db.calendarSeasons)..where((t) => t.id.equals(id))).write(
    CalendarSeasonsCompanion(
      name: name == null ? const Value.absent() : Value(name),
      color: color == null ? const Value.absent() : Value(color),
      startMonthIndex: startMonthIndex == null
          ? const Value.absent()
          : Value(startMonthIndex),
      startDay: startDay == null ? const Value.absent() : Value(startDay),
      endMonthIndex: endMonthIndex == null
          ? const Value.absent()
          : Value(endMonthIndex),
      endDay: endDay == null ? const Value.absent() : Value(endDay),
    ),
  );

  Future<void> deleteSeason(String id) =>
      (db.delete(db.calendarSeasons)..where((t) => t.id.equals(id))).go();

  /// İlk açılışta makul bir takvim tohumlar (12 ay × 30 gün, 7 gün adı,
  /// 4 mevsim). Zaten ay varsa hiçbir şey yapmaz — `ensureDefaultBondTypes`
  /// ile aynı desen; adlar arayüzden (L10n) gelir.
  Future<void> ensureDefaultCalendar({
    required List<String> monthNames,
    required List<String> weekdayNames,
    required List<({String name, int color, int startMonth, int endMonth})>
    seasonSpec,
  }) async {
    await config();
    if ((await months()).isNotEmpty) return;

    await db.batch((b) {
      for (final (i, name) in monthNames.indexed) {
        b.insert(
          db.calendarMonths,
          CalendarMonthsCompanion.insert(
            id: 'cm-seed-$i',
            name: Value(name),
            days: const Value(30),
            sortOrder: Value(i),
          ),
        );
      }
      for (final (i, name) in weekdayNames.indexed) {
        b.insert(
          db.calendarWeekdays,
          CalendarWeekdaysCompanion.insert(
            id: 'cw-seed-$i',
            name: Value(name),
            sortOrder: Value(i),
          ),
        );
      }
      for (final (i, season) in seasonSpec.indexed) {
        b.insert(
          db.calendarSeasons,
          CalendarSeasonsCompanion.insert(
            id: 'cs-seed-$i',
            name: Value(season.name),
            color: Value(season.color),
            startMonthIndex: Value(season.startMonth),
            startDay: const Value(1),
            endMonthIndex: Value(season.endMonth),
            endDay: const Value(30),
            sortOrder: Value(i),
          ),
        );
      }
    });
  }
}
