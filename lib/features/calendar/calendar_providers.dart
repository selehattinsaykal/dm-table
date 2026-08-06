import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/calendar_repository.dart';
import '../../data/chronicle_repository.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../data/reminder_repository.dart';
import '../../data/shop_repository.dart';
import '../../domain/calendar/game_calendar.dart';
import '../shops/shop_providers.dart';

final calendarRepositoryProvider = Provider<CalendarRepository>(
  (ref) => CalendarRepository(ref.watch(databaseProvider)),
);

final chronicleRepositoryProvider = Provider<ChronicleRepository>(
  (ref) => ChronicleRepository(ref.watch(databaseProvider)),
);

final calendarConfigProvider = StreamProvider<CalendarConfigData?>(
  (ref) => ref.watch(calendarRepositoryProvider).watchConfig(),
);

final calendarMonthsProvider = StreamProvider<List<CalendarMonth>>(
  (ref) => ref.watch(calendarRepositoryProvider).watchMonths(),
);

final calendarWeekdaysProvider = StreamProvider<List<CalendarWeekday>>(
  (ref) => ref.watch(calendarRepositoryProvider).watchWeekdays(),
);

final calendarSeasonsProvider = StreamProvider<List<CalendarSeason>>(
  (ref) => ref.watch(calendarRepositoryProvider).watchSeasons(),
);

final chronicleErasProvider = StreamProvider<List<CalendarEra>>(
  (ref) => ref.watch(chronicleRepositoryProvider).watchEras(),
);

final chronicleEventsProvider = StreamProvider<List<ChronicleEvent>>(
  (ref) => ref.watch(chronicleRepositoryProvider).watchEvents(),
);

/// Gün ilerledikten sonraki özet: yeni tarih, okunur etiketi, bu sırada stoğu
/// yenilenen mağazalar ve tetiklenen hatırlatıcılar.
typedef GameDayAdvance = ({
  GameDate date,
  String label,
  List<String> restockedShops,
  List<DueReminder> reminders,
});

/// Oyun-içi günü ilerletmenin TEK giriş noktası.
///
/// Takvimi ilerletmenin yan etkileri var (şu an mağaza stok yenilemesi) ve
/// bunlar üç ayrı yerden tetikleniyor: takvim sayfası, parti molası, seyahat
/// planlayıcısı. `CalendarRepository.advanceDays`'i doğrudan çağırmak yerine
/// burası kullanılırsa yan etkiler hiçbir çağrı yerinde unutulmaz.
///
/// `CalendarRepository`'nin kendisi mağazaları BİLMEZ (katman ihlali olurdu);
/// birleştirme burada, özellik katmanında yapılıyor.
///
/// Serbest fonksiyon değil de sınıf olmasının sebebi: çağrı yerlerinin yarısı
/// widget (`WidgetRef`), yarısı provider (`Ref`) ve Riverpod'da bu ikisinin
/// ortak bir üst tipi YOK — `ref.read(gameClockProvider)` her iki taraftan da
/// çalışır. Ayrıca sınıf doğrudan (widget kurmadan) test edilebilir.
class GameClock {
  const GameClock({
    required this.calendar,
    required this.shops,
    required this.reminders,
  });

  final CalendarRepository calendar;
  final ShopRepository shops;
  final ReminderRepository reminders;

  /// Günü [days] kadar ilerletir (negatifse geri alır).
  Future<GameDayAdvance> advanceDays(int days) =>
      _change(() => calendar.advanceDays(days).then((_) {}));

  /// Tarihi doğrudan belirler ("Bugünü ayarla").
  Future<GameDayAdvance> setDate(GameDate date) =>
      _change(() => calendar.setCurrentDate(date));

  /// Değişiklikten ÖNCEKİ günü ölçüp yazma işini yapar, sonra yan etkileri
  /// çalıştırır. Hatırlatıcılar "hangi günler atlandı" bilgisine muhtaç:
  /// 10 gün ilerlendiğinde aradaki her tetiklenme bildirilmeli.
  Future<GameDayAdvance> _change(Future<void> Function() write) async {
    final before = await calendar.snapshot();
    final months = CalendarRepository.monthsOf(before.months);
    final fromDay = absoluteDay(
      CalendarRepository.dateOf(before.config),
      months,
    );

    await write();

    final snap = await calendar.snapshot();
    final today = CalendarRepository.dateOf(snap.config);
    final monthsAfter = CalendarRepository.monthsOf(snap.months);
    final absolute = absoluteDay(today, monthsAfter);

    return (
      date: today,
      label: CalendarRepository.formatCurrent(snap),
      restockedShops: await shops.applyRestocks(absolute),
      reminders: await reminders.fire(
        fromDay: fromDay,
        toDay: absolute,
        months: monthsAfter,
      ),
    );
  }
}

final reminderRepositoryProvider = Provider<ReminderRepository>(
  (ref) => ReminderRepository(ref.watch(databaseProvider)),
);

final remindersProvider = StreamProvider<List<CalendarReminder>>(
  (ref) => ref.watch(reminderRepositoryProvider).watchAll(),
);

final gameClockProvider = Provider<GameClock>(
  (ref) => GameClock(
    calendar: ref.watch(calendarRepositoryProvider),
    shops: ref.watch(shopRepositoryProvider),
    reminders: ref.watch(reminderRepositoryProvider),
  ),
);
