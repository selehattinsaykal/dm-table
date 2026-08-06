import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../app/ui/ui.dart';
import '../../data/calendar_repository.dart';
import '../../data/chronicle_repository.dart';
import '../../data/db/database.dart';
import '../../domain/calendar/game_calendar.dart';
import '../../l10n/app_localizations.dart';
import 'calendar_providers.dart';
import 'reminders_tab.dart';
import 'calendar_settings_tab.dart';
import 'chronicle_event_editor.dart';
import 'chronicle_tab.dart';
import 'restock_notice.dart';

/// Oyun-içi takvim + tarihçe. Kampanyaya özeldir (her kampanya kendi
/// veritabanı dosyası olduğu için tablolarda `campaignId` yok).
class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  bool _seeded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    // Ilk acilista makul bir takvim tohumla (bag turlerindeki desenin ayni:
    // adlar L10n'dan gelir, migration dile bagimli olmaz).
    if (!_seeded) {
      _seeded = true;
      ref
          .read(calendarRepositoryProvider)
          .ensureDefaultCalendar(
            monthNames: l10n.calendarDefaultMonths.split(','),
            weekdayNames: l10n.calendarDefaultWeekdays.split(','),
            seasonSpec: defaultSeasonSpec(l10n),
          );
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.navCalendar),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: l10n.calendarTabCalendar),
              Tab(text: l10n.calendarTabChronicle),
              Tab(text: l10n.calendarTabReminders),
              Tab(text: l10n.calendarTabSettings),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _CalendarTab(),
            ChronicleTab(),
            RemindersTab(),
            CalendarSettingsTab(),
          ],
        ),
      ),
    );
  }
}

/// Varsayilan dort mevsim: adlar L10n'dan, ay araliklari sabit (12 aylik
/// varsayilan takvime gore; kis yil sonunu sarar).
List<({String name, int color, int startMonth, int endMonth})>
defaultSeasonSpec(L10n l10n) {
  final names = l10n.calendarDefaultSeasons.split(',');
  String at(int i) => i < names.length ? names[i].trim() : '';
  return [
    (name: at(0), color: 0xFF6FA36B, startMonth: 2, endMonth: 4),
    (name: at(1), color: 0xFFD9A441, startMonth: 5, endMonth: 7),
    (name: at(2), color: 0xFFB5651D, startMonth: 8, endMonth: 10),
    // Kis: 11. aydan 1. aya -- yil sonunu saran aralik.
    (name: at(3), color: 0xFF7FA8C9, startMonth: 11, endMonth: 1),
  ];
}

/// Ay ızgarası: gün adları sütun başlığı, hücreler ayın günleri, olaylı
/// günler işaretli, güncel gün vurgulu.
class _CalendarTab extends ConsumerStatefulWidget {
  const _CalendarTab();

  @override
  ConsumerState<_CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends ConsumerState<_CalendarTab> {
  /// Goruntulenen ay (guncel tarihten bagimsiz gezinme).
  GameDate? _viewing;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final config = ref.watch(calendarConfigProvider).value;
    final monthRows = ref.watch(calendarMonthsProvider).value ?? const [];
    final weekdayRows = ref.watch(calendarWeekdaysProvider).value ?? const [];
    final seasonRows = ref.watch(calendarSeasonsProvider).value ?? const [];
    final events = ref.watch(chronicleEventsProvider).value ?? const [];

    if (config == null) return const AppLoading();
    if (monthRows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(l10n.calendarNoMonths, textAlign: TextAlign.center),
        ),
      );
    }

    final months = CalendarRepository.monthsOf(monthRows);
    final seasons = CalendarRepository.seasonsOf(seasonRows);
    final today = CalendarRepository.dateOf(config);
    final viewing = _viewing ?? today;
    final monthIndex = viewing.monthIndex.clamp(0, months.length - 1);
    final dayCount = daysInMonth(months, monthIndex);
    final weekLength = weekdayRows.isEmpty ? 7 : weekdayRows.length;

    // Ayin ilk gunu haftanin kacinci gunu -> izgaranin bas bosluğu.
    final firstWeekday = weekdayIndex(
      (year: viewing.year, monthIndex: monthIndex, day: 1),
      months,
      weekLength,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _TodayCard(
          config: config,
          months: months,
          weekdays: weekdayRows,
          seasons: seasons,
          onJumpToToday: () => setState(() => _viewing = null),
        ),
        SizedBox(height: context.spacing.md),
        _MonthHeader(
          label:
              '${months[monthIndex].name} '
              '${formatEraYear(viewing.year, afterSuffix: config.yearSuffix, beforeSuffix: config.beforeYearSuffix)}',
          onPrev: () =>
              setState(() => _viewing = _shiftMonth(viewing, months, -1)),
          onNext: () =>
              setState(() => _viewing = _shiftMonth(viewing, months, 1)),
        ),
        const SizedBox(height: 8),
        if (weekdayRows.isNotEmpty)
          Row(
            children: [
              for (final w in weekdayRows)
                Expanded(
                  child: Text(
                    w.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: weekLength,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: [
            for (var i = 0; i < firstWeekday; i++) const SizedBox.shrink(),
            for (var day = 1; day <= dayCount; day++)
              _DayCell(
                date: (year: viewing.year, monthIndex: monthIndex, day: day),
                isToday:
                    viewing.year == today.year &&
                    monthIndex == today.monthIndex &&
                    day == today.day,
                season: seasonAt((
                  year: viewing.year,
                  monthIndex: monthIndex,
                  day: day,
                ), seasons),
                seasonRows: seasonRows,
                eventCount: ChronicleRepository.eventsOn(events, (
                  year: viewing.year,
                  monthIndex: monthIndex,
                  day: day,
                ), months).length,
                onTap: () => _openDay(
                  (year: viewing.year, monthIndex: monthIndex, day: day),
                  months,
                  events,
                ),
              ),
          ],
        ),
      ],
    );
  }

  GameDate _shiftMonth(GameDate from, List<GameMonth> months, int delta) {
    final total = months.length;
    var index = from.monthIndex + delta;
    var year = from.year;
    while (index < 0) {
      index += total;
      year -= 1;
    }
    while (index >= total) {
      index -= total;
      year += 1;
    }
    return (year: year, monthIndex: index, day: 1);
  }

  /// Bir gune dokununca o gunun olaylari + "olay ekle".
  Future<void> _openDay(
    GameDate date,
    List<GameMonth> months,
    List<ChronicleEvent> events,
  ) async {
    final l10n = L10n.of(context);
    final onDay = ChronicleRepository.eventsOn(events, date, months);
    final label = formatGameDate(date, months);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(label: l10n.chronicleEventsOnDay(label)),
              if (onDay.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(l10n.chronicleNoEventsOnDay),
                ),
              for (final event in onDay)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    event.secret ? Icons.visibility_off : Icons.event_note,
                  ),
                  title: Text(
                    event.title.isEmpty ? l10n.chronicleNew : event.title,
                  ),
                  subtitle: event.category.isEmpty
                      ? null
                      : Text(event.category),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    openChronicleEvent(context, ref, event.id);
                  },
                ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(sheetContext);
                  final id = await ref
                      .read(chronicleRepositoryProvider)
                      .create(
                        title: '',
                        year: date.year,
                        monthIndex: date.monthIndex,
                        day: date.day,
                      );
                  if (mounted) openChronicleEvent(context, ref, id);
                },
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.chronicleAddHere),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Guncel tarih + mevsim + gunu ilerletme.
class _TodayCard extends ConsumerWidget {
  const _TodayCard({
    required this.config,
    required this.months,
    required this.weekdays,
    required this.seasons,
    required this.onJumpToToday,
  });

  final CalendarConfigData config;
  final List<GameMonth> months;
  final List<CalendarWeekday> weekdays;
  final List<GameSeason> seasons;
  final VoidCallback onJumpToToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final date = CalendarRepository.dateOf(config);
    final weekdayName = weekdays.isEmpty
        ? null
        : weekdays[weekdayIndex(date, months, weekdays.length)].name;
    final season = seasonAt(date, seasons);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formatGameDate(
                date,
                months,
                weekdayName: weekdayName,
                eraLabel: config.eraLabel,
                yearSuffix: config.yearSuffix,
                beforeYearSuffix: config.beforeYearSuffix,
              ),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.eco_outlined,
                  size: 16,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(width: 6),
                Text(
                  season?.name ?? l10n.calendarNoSeason,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _advance(context, ref, -1),
                  child: Text(l10n.calendarBackDay),
                ),
                FilledButton(
                  onPressed: () => _advance(context, ref, 1),
                  child: Text(l10n.calendarAdvanceDay),
                ),
                OutlinedButton(
                  onPressed: () => _advance(
                    context,
                    ref,
                    weekdays.isEmpty ? 7 : weekdays.length,
                  ),
                  child: Text(l10n.calendarAdvanceWeek),
                ),
                TextButton.icon(
                  onPressed: () => _setToday(context, ref, date),
                  icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                  label: Text(l10n.calendarSetToday),
                ),
                TextButton(
                  onPressed: onJumpToToday,
                  child: Text(l10n.calendarGoToday),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setToday(
    BuildContext context,
    WidgetRef ref,
    GameDate current,
  ) async {
    final picked = await pickGameDate(
      context,
      ref,
      initial: current,
      title: L10n.of(context).calendarSetToday,
    );
    if (picked == null || !context.mounted) return;
    final result = await ref.read(gameClockProvider).setDate(picked);
    if (context.mounted) showRestockNotice(context, result);
  }

  /// Gunu ilerletir ve stogu yenilenen magaza olduysa DM'e bildirir.
  Future<void> _advance(BuildContext context, WidgetRef ref, int days) async {
    final result = await ref.read(gameClockProvider).advanceDays(days);
    if (context.mounted) showRestockNotice(context, result);
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.label,
    required this.onPrev,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
      Text(label, style: Theme.of(context).textTheme.titleMedium),
      IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
    ],
  );
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.isToday,
    required this.season,
    required this.seasonRows,
    required this.eventCount,
    required this.onTap,
  });

  final GameDate date;
  final bool isToday;
  final GameSeason? season;
  final List<CalendarSeason> seasonRows;
  final int eventCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Mevsim rengi adla eslesir: saf model renk tasimaz (goruntu katmanina
    // ait), satirdan cozulur.
    final tint = season == null
        ? null
        : Color(
            seasonRows
                    .where((s) => s.name == season!.name)
                    .firstOrNull
                    ?.color ??
                0xFF8D6E63,
          );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        decoration: BoxDecoration(
          color: tint?.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isToday
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: isToday ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isToday ? FontWeight.w700 : null,
                color: isToday ? theme.colorScheme.primary : null,
              ),
            ),
            if (eventCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < (eventCount > 3 ? 3 : eventCount); i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: CircleAvatar(
                          radius: 2,
                          backgroundColor: theme.colorScheme.tertiary,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
