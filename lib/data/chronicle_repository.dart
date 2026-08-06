import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/calendar/game_calendar.dart';
import 'db/database.dart';

/// Tarihçe: çağlar + geçmişte (ya da gelecekte) yaşanmış olaylar.
///
/// Olaylar kronolojik sıralanır ama DB'de denormalize bir sıralama anahtarı
/// TUTULMAZ: ayların uzunluğu sonradan değiştirilebiliyor ve kayıtlı anahtar
/// sessizce yanlışa düşerdi. Sıralama okuma anında [sortEvents] ile yapılır
/// (olay sayısı yüzler mertebesinde; maliyeti yok).
class ChronicleRepository {
  ChronicleRepository(this.db);

  final AppDatabase db;
  static const _uuid = Uuid();

  // --- Caglar --------------------------------------------------------------

  Stream<List<CalendarEra>> watchEras() =>
      (db.select(db.calendarEras)..orderBy([
            (t) => OrderingTerm(expression: t.startYear),
            (t) => OrderingTerm(expression: t.sortOrder),
          ]))
          .watch();

  Future<List<CalendarEra>> eras() => (db.select(
    db.calendarEras,
  )..orderBy([(t) => OrderingTerm(expression: t.startYear)])).get();

  Future<String> createEra({
    required String name,
    required int startYear,
    int? endYear,
    int color = 0xFF8D6E63,
    String description = '',
  }) async {
    final id = 'era-${_uuid.v4()}';
    final count = (await eras()).length;
    await db
        .into(db.calendarEras)
        .insert(
          CalendarErasCompanion.insert(
            id: id,
            name: Value(name),
            startYear: Value(startYear),
            endYear: Value(endYear),
            color: Value(color),
            description: Value(description),
            sortOrder: Value(count),
          ),
        );
    return id;
  }

  Future<void> updateEra(
    String id, {
    String? name,
    int? startYear,
    Value<int?> endYear = const Value.absent(),
    int? color,
    String? description,
  }) => (db.update(db.calendarEras)..where((t) => t.id.equals(id))).write(
    CalendarErasCompanion(
      name: name == null ? const Value.absent() : Value(name),
      startYear: startYear == null ? const Value.absent() : Value(startYear),
      endYear: endYear,
      color: color == null ? const Value.absent() : Value(color),
      description: description == null
          ? const Value.absent()
          : Value(description),
    ),
  );

  /// Çağı siler. Olaylar silinmez, yalnız çağ bağı düşer (FK yok — olay
  /// yetim kalmaz, yıla göre gruplanmaya devam eder).
  Future<void> deleteEra(String id) async {
    await (db.update(db.chronicleEvents)..where((t) => t.eraId.equals(id)))
        .write(const ChronicleEventsCompanion(eraId: Value(null)));
    await (db.delete(db.calendarEras)..where((t) => t.id.equals(id))).go();
  }

  // --- Olaylar -------------------------------------------------------------

  Stream<List<ChronicleEvent>> watchEvents() =>
      db.select(db.chronicleEvents).watch();

  Future<List<ChronicleEvent>> events() => db.select(db.chronicleEvents).get();

  Future<ChronicleEvent?> find(String id) => (db.select(
    db.chronicleEvents,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<String> create({
    required String title,
    required int year,
    int? monthIndex,
    int? day,
  }) async {
    final id = 'chr-${_uuid.v4()}';
    await db
        .into(db.chronicleEvents)
        .insert(
          ChronicleEventsCompanion.insert(
            id: id,
            title: Value(title),
            year: Value(year),
            monthIndex: Value(monthIndex),
            day: Value(day),
          ),
        );
    return id;
  }

  Future<void> update(
    String id, {
    String? title,
    String? body,
    int? year,
    Value<int?> monthIndex = const Value.absent(),
    Value<int?> day = const Value.absent(),
    Value<int?> endYear = const Value.absent(),
    Value<int?> endMonthIndex = const Value.absent(),
    Value<int?> endDay = const Value.absent(),
    Value<String?> eraId = const Value.absent(),
    String? category,
    Value<int?> color = const Value.absent(),
    bool? secret,
    Value<String?> codexPageId = const Value.absent(),
    Value<String?> locationId = const Value.absent(),
    Value<String?> npcId = const Value.absent(),
  }) => (db.update(db.chronicleEvents)..where((t) => t.id.equals(id))).write(
    ChronicleEventsCompanion(
      title: title == null ? const Value.absent() : Value(title),
      body: body == null ? const Value.absent() : Value(body),
      year: year == null ? const Value.absent() : Value(year),
      monthIndex: monthIndex,
      day: day,
      endYear: endYear,
      endMonthIndex: endMonthIndex,
      endDay: endDay,
      eraId: eraId,
      category: category == null ? const Value.absent() : Value(category),
      color: color,
      secret: secret == null ? const Value.absent() : Value(secret),
      codexPageId: codexPageId,
      locationId: locationId,
      npcId: npcId,
    ),
  );

  Future<void> delete(String id) =>
      (db.delete(db.chronicleEvents)..where((t) => t.id.equals(id))).go();

  // --- Siralama / sorgular -------------------------------------------------

  /// Olayın başlangıcı; ay/gün bilinmiyorsa yılın ilk gününe düşer.
  static GameDate startOf(ChronicleEvent event) => (
    year: event.year,
    monthIndex: event.monthIndex ?? 0,
    day: event.day ?? 1,
  );

  /// Olayları kronolojik sıralar (eskiden yeniye). Aynı güne düşenler
  /// başlığa göre sıralanır ki liste her okumada aynı çıksın.
  static List<ChronicleEvent> sortEvents(
    List<ChronicleEvent> events,
    List<GameMonth> months,
  ) {
    final sorted = [...events];
    sorted.sort((a, b) {
      final byDay = absoluteDay(
        startOf(a),
        months,
      ).compareTo(absoluteDay(startOf(b), months));
      return byDay != 0 ? byDay : a.title.compareTo(b.title);
    });
    return sorted;
  }

  /// Belirli bir güne denk gelen olaylar (takvim ızgarasındaki işaretler).
  ///
  /// Süren olaylar (bitiş tarihi olanlar) aralığa düşen her günde görünür.
  static List<ChronicleEvent> eventsOn(
    List<ChronicleEvent> events,
    GameDate date,
    List<GameMonth> months,
  ) {
    final target = absoluteDay(date, months);
    return [
      for (final event in events)
        if (_spans(event, target, months)) event,
    ];
  }

  static bool _spans(
    ChronicleEvent event,
    int targetDay,
    List<GameMonth> months,
  ) {
    final start = absoluteDay(startOf(event), months);
    if (event.endYear == null) return start == targetDay;
    final end = absoluteDay((
      year: event.endYear!,
      monthIndex: event.endMonthIndex ?? 0,
      day: event.endDay ?? 1,
    ), months);
    return targetDay >= start && targetDay <= (end < start ? start : end);
  }

  /// Bir olayın hangi çağa düştüğü (yıl aralığına göre); yoksa `null`.
  ///
  /// Elle bağlanmış çağ ([ChronicleEvent.eraId]) önceliklidir.
  static CalendarEra? eraOf(ChronicleEvent event, List<CalendarEra> eras) {
    if (event.eraId != null) {
      final linked = eras.where((e) => e.id == event.eraId).firstOrNull;
      if (linked != null) return linked;
    }
    for (final era in eras) {
      if (event.year >= era.startYear &&
          (era.endYear == null || event.year <= era.endYear!)) {
        return era;
      }
    }
    return null;
  }
}
