import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/rules/travel.dart';
import '../domain/rules/travel_encounters.dart';
import 'db/database.dart';

/// Yolculugun bir duragi.
///
/// [pinId] varsa haritadaki bir pinden gelmistir; yoksa DM'in haritaya
/// dogrudan dokunarak koydugu bir ARA NOKTA'dir. Koordinat her iki durumda da
/// saklanir — pin sonradan silinse ya da tasinsa bile yolculugun uzunlugu
/// degismemeli.
typedef JourneyStop = ({String? pinId, String label, double x, double y});

/// Suren yolculugu okur/yazar.
///
/// Ayni anda tek bir aktif yolculuk olur: [start] yeni bir tane acmadan once
/// varsa oncekini kapatir.
class JourneyRepository {
  JourneyRepository(this.db);

  final AppDatabase db;
  static const _uuid = Uuid();

  Stream<Journey?> watchActive() =>
      (db.select(db.journeys)
            ..where((t) => t.done.equals(false))
            ..orderBy([
              (t) => OrderingTerm(
                expression: t.createdAt,
                mode: OrderingMode.desc,
              ),
            ])
            ..limit(1))
          .watchSingleOrNull();

  Future<Journey?> active() async =>
      (await (db.select(db.journeys)
                ..where((t) => t.done.equals(false))
                ..orderBy([
                  (t) => OrderingTerm(
                    expression: t.createdAt,
                    mode: OrderingMode.desc,
                  ),
                ])
                ..limit(1))
              .get())
          .firstOrNull;

  Future<Journey?> find(String id) =>
      (db.select(db.journeys)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Yeni yolculuk baslatir; varsa onceki aktif yolculuk kapatilir.
  Future<String> start({
    required String locationId,
    required List<JourneyStop> stops,
    required double totalMiles,
    required String speedKey,
    double? customMph,
    required double hoursPerDay,
    double extraMiles = 0,
    bool encountersOn = false,
    String? tableId,
    int threshold = kEncounterThresholdDefault,
    int checksPerDay = 1,
    bool advanceCalendar = true,
  }) async {
    final id = 'jrn-${_uuid.v4()}';
    await db.transaction(() async {
      await (db.update(db.journeys)..where((t) => t.done.equals(false))).write(
        const JourneysCompanion(done: Value(true)),
      );
      await db
          .into(db.journeys)
          .insert(
            JourneysCompanion.insert(
              id: id,
              locationId: locationId,
              stopsJson: Value(encodeStops(stops)),
              extraMiles: Value(extraMiles),
              speedKey: Value(speedKey),
              customMph: Value(customMph),
              hoursPerDay: Value(hoursPerDay),
              encountersOn: Value(encountersOn),
              tableId: Value(tableId),
              threshold: Value(threshold),
              checksPerDay: Value(checksPerDay),
              totalMiles: Value(totalMiles),
              advanceCalendar: Value(advanceCalendar),
            ),
          );
    });
    return id;
  }

  /// Bir ilerleme adimini yazar.
  ///
  /// [encounter] null verildiginde bekleyen karsilasma TEMIZLENIR ("Devam et");
  /// doluysa hem bekleyen olarak yazilir hem yolculuk gunlugune eklenir.
  Future<void> saveStep(
    String id, {
    required double milesTravelled,
    required int checksDone,
    required int daysAdvanced,
    TravelEncounter? encounter,
    bool clearEncounter = false,
    bool? done,
  }) async {
    final current = await find(id);
    if (current == null) return;

    final log = decodeEncounters(current.encounterLogJson);
    if (encounter != null) log.add(encounter);

    await (db.update(db.journeys)..where((t) => t.id.equals(id))).write(
      JourneysCompanion(
        milesTravelled: Value(milesTravelled),
        checksDone: Value(checksDone),
        daysAdvanced: Value(daysAdvanced),
        pendingEncounterJson: encounter != null
            ? Value(jsonEncode(_encodeEncounter(encounter)))
            : (clearEncounter ? const Value(null) : const Value.absent()),
        encounterLogJson: encounter != null
            ? Value(encodeEncounters(log))
            : const Value.absent(),
        done: done == null ? const Value.absent() : Value(done),
      ),
    );
  }

  /// Yolculugu kapatir (varis ya da DM'in iptali).
  Future<void> finish(String id) =>
      (db.update(db.journeys)..where((t) => t.id.equals(id))).write(
        const JourneysCompanion(done: Value(true)),
      );

  Future<void> delete(String id) =>
      (db.delete(db.journeys)..where((t) => t.id.equals(id))).go();

  // --- Kodlama -------------------------------------------------------------

  static String encodeStops(List<JourneyStop> stops) => jsonEncode([
    for (final s in stops)
      {'pinId': s.pinId, 'label': s.label, 'x': s.x, 'y': s.y},
  ]);

  /// Bozuk JSON'da bos liste doner (firlatmaz) — yolculuk kaydi bir oturumu
  /// kilitlememeli.
  static List<JourneyStop> decodeStops(String json) {
    try {
      final data = jsonDecode(json);
      if (data is! List) return const [];
      final out = <JourneyStop>[];
      for (final e in data) {
        if (e is! Map) continue;
        final x = e['x'];
        final y = e['y'];
        if (x is! num || y is! num) continue;
        out.add((
          pinId: e['pinId'] as String?,
          label: e['label'] as String? ?? '',
          x: x.toDouble(),
          y: y.toDouble(),
        ));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  /// Duraklari mesafe hesabinin anladigi saf bicime cevirir.
  static List<TravelPoint> pointsOf(List<JourneyStop> stops) => [
    for (final (i, s) in stops.indexed)
      (id: s.pinId ?? 'wp-$i', label: s.label, x: s.x, y: s.y),
  ];

  static Map<String, Object?> _encodeEncounter(TravelEncounter e) => {
    'day': e.day,
    'checkIndex': e.checkIndex,
    'check': e.check,
    'tableRoll': e.tableRoll,
    'text': e.text,
  };

  static String encodeEncounters(List<TravelEncounter> list) =>
      jsonEncode([for (final e in list) _encodeEncounter(e)]);

  static List<TravelEncounter> decodeEncounters(String json) {
    try {
      final data = jsonDecode(json);
      if (data is! List) return [];
      return [
        for (final e in data)
          if (e is Map)
            (
              day: e['day'] as int? ?? 0,
              checkIndex: e['checkIndex'] as int? ?? 0,
              check: e['check'] as int? ?? 0,
              tableRoll: e['tableRoll'] as int? ?? 0,
              text: e['text'] as String? ?? '',
            ),
      ];
    } catch (_) {
      return [];
    }
  }

  /// Bekleyen karsilasma (yoksa null).
  static TravelEncounter? pendingOf(Journey journey) {
    final raw = journey.pendingEncounterJson;
    if (raw == null || raw.isEmpty) return null;
    return decodeEncounters('[$raw]').firstOrNull;
  }
}
