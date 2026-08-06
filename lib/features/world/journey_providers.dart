import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../data/journey_repository.dart';
import '../../data/providers.dart';
import '../../data/random_table_repository.dart';
import '../../data/reminder_repository.dart';
import '../../domain/rules/random_table.dart';
import '../../domain/rules/travel.dart';
import '../../domain/rules/travel_encounters.dart';
import '../calendar/calendar_providers.dart';
import '../tables/table_providers.dart';

final journeyRepositoryProvider = Provider<JourneyRepository>(
  (ref) => JourneyRepository(ref.watch(databaseProvider)),
);

/// Su an suren yolculuk (yoksa null).
///
/// Haritadaki serit, seyahat dugmesi ve yolculuk sayfasi bunu izler; boylece
/// DM savas ekranina gidip geri donunce yolculuk oldugu yerde durur.
final activeJourneyProvider = StreamProvider<Journey?>(
  (ref) => ref.watch(journeyRepositoryProvider).watchActive(),
);

/// Bir ilerleme adiminin sonucu.
typedef JourneyProgress = ({
  Journey journey,
  TravelEncounter? encounter,
  bool arrived,

  /// Bu adimda takvimde ilerletilen gun (0 = ilerlemedi).
  int daysAdvanced,

  /// Bu adimda stogu yenilenen magazalar.
  List<String> restockedShops,

  /// Bu adimda tetiklenen takvim hatirlaticilari.
  List<DueReminder> reminders,
});

/// Yolculugu adim adim ilerletir.
///
/// `GameClock` ile ayni gerekce: cagri yerlerinin bir kismi widget
/// (`WidgetRef`), bir kismi provider (`Ref`) ve Riverpod'da ortak ust tip yok.
/// Ayrica sinif dogrudan (widget kurmadan) test edilebiliyor.
class JourneyRunner {
  const JourneyRunner({
    required this.journeys,
    required this.tables,
    required this.clock,
  });

  final JourneyRepository journeys;
  final RandomTableRepository tables;
  final GameClock clock;

  /// Yolculugu bir sonraki karsilasmaya ya da hedefe kadar ilerletir.
  ///
  /// Bekleyen bir karsilasma varsa once o TEMIZLENIR ("Devam et" demek onu
  /// geride birakmak demektir), sonra yol devam eder.
  Future<JourneyProgress?> advance(String journeyId) async {
    final journey = await journeys.find(journeyId);
    if (journey == null || journey.done) return null;

    final speed = travelSpeedByKey(
      journey.speedKey,
      customMph: journey.customMph,
    );
    final perDay = speed.milesPerDay(
      overriddenHoursPerDay(speed, journey.hoursPerDay),
    );

    final rows = await _rowsFor(journey);
    final table = journey.tableId == null
        ? null
        : await tables.find(journey.tableId!);

    final step = advanceJourney(
      totalMiles: journey.totalMiles,
      milesTravelled: journey.milesTravelled,
      checksDone: journey.checksDone,
      milesPerDay: perDay,
      checksPerDay: journey.checksPerDay,
      encountersOn: journey.encountersOn,
      threshold: journey.threshold,
      rows: rows,
      tableSides: table?.diceSides ?? 20,
    );

    // Takvim yalnizca ARADAKI FARK kadar ilerler; duraklayip devam eden
    // yolculukta gunler iki kez sayilmasin.
    final elapsed = daysElapsedFor(step.milesTravelled, perDay);
    final delta = elapsed - journey.daysAdvanced;
    var restocked = const <String>[];
    var reminders = const <DueReminder>[];
    if (journey.advanceCalendar && delta > 0) {
      final advance = await clock.advanceDays(delta);
      restocked = advance.restockedShops;
      reminders = advance.reminders;
    }

    await journeys.saveStep(
      journeyId,
      milesTravelled: step.milesTravelled,
      checksDone: step.checksDone,
      daysAdvanced: journey.advanceCalendar ? elapsed : journey.daysAdvanced,
      encounter: step.encounter,
      clearEncounter: step.encounter == null,
      done: step.arrived ? true : null,
    );

    final updated = await journeys.find(journeyId);
    return (
      journey: updated ?? journey,
      encounter: step.encounter,
      arrived: step.arrived,
      daysAdvanced: journey.advanceCalendar && delta > 0 ? delta : 0,
      restockedShops: restocked,
      reminders: reminders,
    );
  }

  Future<List<RandomTableRow>> _rowsFor(Journey journey) async {
    final id = journey.tableId;
    if (id == null) return const [];
    final table = await tables.find(id);
    // Tablo silinmisse yolculuk yine de yurur: yalnizca "bir sey oldu" denir.
    return table == null ? const [] : RandomTableRepository.rowsOf(table);
  }
}

final journeyRunnerProvider = Provider<JourneyRunner>(
  (ref) => JourneyRunner(
    journeys: ref.watch(journeyRepositoryProvider),
    tables: ref.watch(randomTableRepositoryProvider),
    clock: ref.watch(gameClockProvider),
  ),
);
