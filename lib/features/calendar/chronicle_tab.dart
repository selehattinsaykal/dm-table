import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ui/ui.dart';
import '../../data/calendar_repository.dart';
import '../../data/chronicle_repository.dart';
import '../../data/db/database.dart';
import '../../domain/calendar/game_calendar.dart';
import '../../l10n/app_localizations.dart';
import '../codex/codex_inline.dart';
import 'calendar_providers.dart';
import 'chronicle_event_editor.dart';

/// Tarihçe: çağlara ve yıllara göre gruplanmış zaman çizelgesi.
class ChronicleTab extends ConsumerStatefulWidget {
  const ChronicleTab({super.key});

  @override
  ConsumerState<ChronicleTab> createState() => _ChronicleTabState();
}

class _ChronicleTabState extends ConsumerState<ChronicleTab> {
  final _search = TextEditingController();
  bool _onlySecret = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final monthRows = ref.watch(calendarMonthsProvider).value ?? const [];
    final months = CalendarRepository.monthsOf(monthRows);
    final eras = ref.watch(chronicleErasProvider).value ?? const [];
    final config = ref.watch(calendarConfigProvider).value;
    final all = ref.watch(chronicleEventsProvider).value ?? const [];

    final query = _search.text.trim().toLowerCase();
    final filtered = [
      for (final event in ChronicleRepository.sortEvents(all, months))
        if ((!_onlySecret || event.secret) &&
            (query.isEmpty ||
                event.title.toLowerCase().contains(query) ||
                event.body.toLowerCase().contains(query) ||
                event.category.toLowerCase().contains(query)))
          event,
    ];

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createEvent(config),
        icon: const Icon(Icons.add),
        label: Text(l10n.chronicleNew),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: l10n.chronicleSearch,
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  avatar: const Icon(Icons.visibility_off, size: 16),
                  label: Text(l10n.chronicleOnlySecret),
                  selected: _onlySecret,
                  onSelected: (v) => setState(() => _onlySecret = v),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: l10n.chronicleEras,
                  icon: const Icon(Icons.timeline),
                  onPressed: _openEras,
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        l10n.chronicleEmpty,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: theme.colorScheme.outline),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final event = filtered[i];
                      final era = ChronicleRepository.eraOf(event, eras);
                      final previous = i == 0 ? null : filtered[i - 1];
                      final previousEra = previous == null
                          ? null
                          : ChronicleRepository.eraOf(previous, eras);
                      // Cag degistiginde basliği bir kez goster.
                      final showEra = i == 0 || era?.id != previousEra?.id;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showEra)
                            Padding(
                              padding: EdgeInsets.only(top: i == 0 ? 0 : 16),
                              child: SectionHeader(
                                label: era == null
                                    ? l10n.chronicleNoEra
                                    : '${era.name} '
                                          '(${formatEraYear(era.startYear, afterSuffix: config?.yearSuffix ?? '', beforeSuffix: config?.beforeYearSuffix ?? '')}'
                                          '–${era.endYear == null ? l10n.chronicleOngoing : formatEraYear(era.endYear!, afterSuffix: config?.yearSuffix ?? '', beforeSuffix: config?.beforeYearSuffix ?? '')})',
                              ),
                            ),
                          _EventCard(
                            event: event,
                            months: months,
                            monthRows: monthRows,
                            config: config,
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _createEvent(CalendarConfigData? config) async {
    final id = await ref
        .read(chronicleRepositoryProvider)
        .create(
          title: '',
          year: config?.currentYear ?? 1,
          monthIndex: config?.currentMonthIndex,
          day: config?.currentDay,
        );
    if (mounted) openChronicleEvent(context, ref, id);
  }

  Future<void> _openEras() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _ErasSheet(),
  );
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.months,
    required this.monthRows,
    required this.config,
  });

  final ChronicleEvent event;
  final List<GameMonth> months;
  final List<CalendarMonth> monthRows;
  final CalendarConfigData? config;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final start = ChronicleRepository.startOf(event);
    final label = event.monthIndex == null
        ? formatEraYear(
            event.year,
            afterSuffix: config?.yearSuffix ?? '',
            beforeSuffix: config?.beforeYearSuffix ?? '',
          )
        : formatGameDate(
            start,
            months,
            yearSuffix: config?.yearSuffix ?? '',
            beforeYearSuffix: config?.beforeYearSuffix ?? '',
          );
    final endLabel = event.endYear == null
        ? null
        : (event.endMonthIndex == null
              ? formatEraYear(
                  event.endYear!,
                  afterSuffix: config?.yearSuffix ?? '',
                  beforeSuffix: config?.beforeYearSuffix ?? '',
                )
              : formatGameDate(
                  (
                    year: event.endYear!,
                    monthIndex: event.endMonthIndex!,
                    day: event.endDay ?? 1,
                  ),
                  months,
                  yearSuffix: config?.yearSuffix ?? '',
                  beforeYearSuffix: config?.beforeYearSuffix ?? '',
                ));

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (event.secret)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.visibility_off,
                        size: 16,
                        color: theme.colorScheme.tertiary,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      event.title.isEmpty ? l10n.chronicleNew : event.title,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    endLabel == null ? label : '$label → $endLabel',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              if (event.category.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    event.category,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
              if (event.body.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  // Kayitlar'daki satir ici bicimlendirmenin aynisi.
                  child: buildCodexInline(context, event.body),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) =>
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => ChronicleEventPage(eventId: event.id),
        ),
      );
}

/// Çağ listesi: adlandırılmış yıl aralıkları.
class _ErasSheet extends ConsumerWidget {
  const _ErasSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final eras = ref.watch(chronicleErasProvider).value ?? const [];
    final config = ref.watch(calendarConfigProvider).value;
    final repo = ref.read(chronicleRepositoryProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(label: l10n.chronicleEras),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final era in eras)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 8,
                        backgroundColor: Color(era.color),
                      ),
                      title: Text(era.name),
                      subtitle: Text(
                        '${formatEraYear(era.startYear, afterSuffix: config?.yearSuffix ?? '', beforeSuffix: config?.beforeYearSuffix ?? '')}'
                        ' – ${era.endYear == null ? l10n.chronicleOngoing : formatEraYear(era.endYear!, afterSuffix: config?.yearSuffix ?? '', beforeSuffix: config?.beforeYearSuffix ?? '')}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => repo.deleteEra(era.id),
                      ),
                      onTap: () => _edit(context, ref, era),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => _edit(context, ref, null),
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.chronicleNewEra),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    CalendarEra? era,
  ) async {
    final l10n = L10n.of(context);
    final name = TextEditingController(text: era?.name ?? '');
    final startYearValue = era?.startYear ?? 0;
    final start = TextEditingController(
      text: '${startYearValue < 0 ? -startYearValue : startYearValue}',
    );
    var startBefore = startYearValue < 0;
    final end = TextEditingController(
      text: era?.endYear == null
          ? ''
          : '${era!.endYear! < 0 ? -era.endYear! : era.endYear}',
    );
    var endBefore = (era?.endYear ?? 0) < 0;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(era == null ? l10n.chronicleNewEra : l10n.chronicleEras),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l10n.chronicleEraName,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: start,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: l10n.chronicleEraStart,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(
                          value: false,
                          label: Text(l10n.calendarYearEraAfter),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text(l10n.calendarYearEraBefore),
                        ),
                      ],
                      selected: {startBefore},
                      onSelectionChanged: (v) =>
                          setState(() => startBefore = v.first),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: end,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: l10n.chronicleEraEnd,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(
                          value: false,
                          label: Text(l10n.calendarYearEraAfter),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text(l10n.calendarYearEraBefore),
                        ),
                      ],
                      selected: {endBefore},
                      onSelectionChanged: (v) =>
                          setState(() => endBefore = v.first),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    final repo = ref.read(chronicleRepositoryProvider);
    final startMagnitude = int.tryParse(start.text.trim()) ?? 0;
    final startYear = startBefore ? -startMagnitude : startMagnitude;
    final endMagnitude = int.tryParse(end.text.trim());
    final endYear = endMagnitude == null
        ? null
        : (endBefore ? -endMagnitude : endMagnitude);
    if (era == null) {
      await repo.createEra(
        name: name.text.trim(),
        startYear: startYear,
        endYear: endYear,
      );
    } else {
      await repo.updateEra(
        era.id,
        name: name.text.trim(),
        startYear: startYear,
        endYear: Value(endYear),
      );
    }
  }
}
