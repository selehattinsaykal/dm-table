import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ui/ui.dart';
import '../../data/calendar_repository.dart';
import '../../data/db/database.dart';
import '../../domain/calendar/game_calendar.dart';
import '../../l10n/app_localizations.dart';
import '../codex/codex_autocomplete.dart';
import '../codex/codex_providers.dart';
import 'calendar_providers.dart';

/// Tarihçe olayını düzenler. Gövde metni Kayıtlar'ın satır içi biçimlendirme
/// alanını ([CodexInlineField]) yeniden kullanır: `**kalın**`, `[[sayfa]]`,
/// `/r 2d6`, `/monster(...)` bedava gelir.
void openChronicleEvent(BuildContext context, WidgetRef ref, String eventId) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(builder: (_) => ChronicleEventPage(eventId: eventId)),
  );
}

class ChronicleEventPage extends ConsumerStatefulWidget {
  const ChronicleEventPage({required this.eventId, super.key});

  final String eventId;

  @override
  ConsumerState<ChronicleEventPage> createState() => _ChronicleEventPageState();
}

class _ChronicleEventPageState extends ConsumerState<ChronicleEventPage> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _category = TextEditingController();

  GameDate _start = (year: 1, monthIndex: 0, day: 1);
  GameDate? _end;

  /// Ay/gun bilinmiyorsa yalnizca yil kaydedilir.
  bool _yearOnly = false;
  bool _secret = false;
  String? _eraId;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final event = await ref
        .read(chronicleRepositoryProvider)
        .find(widget.eventId);
    if (event != null) {
      _title.text = event.title;
      _body.text = event.body;
      _category.text = event.category;
      _start = (
        year: event.year,
        monthIndex: event.monthIndex ?? 0,
        day: event.day ?? 1,
      );
      _yearOnly = event.monthIndex == null;
      _secret = event.secret;
      _eraId = event.eraId;
      if (event.endYear != null) {
        _end = (
          year: event.endYear!,
          monthIndex: event.endMonthIndex ?? 0,
          day: event.endDay ?? 1,
        );
      }
    }
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    for (final c in [_title, _body, _category]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    await ref
        .read(chronicleRepositoryProvider)
        .update(
          widget.eventId,
          title: _title.text.trim(),
          body: _body.text.trim(),
          category: _category.text.trim(),
          year: _start.year,
          monthIndex: Value(_yearOnly ? null : _start.monthIndex),
          day: Value(_yearOnly ? null : _start.day),
          endYear: Value(_end?.year),
          endMonthIndex: Value(
            _end == null || _yearOnly ? null : _end!.monthIndex,
          ),
          endDay: Value(_end == null || _yearOnly ? null : _end!.day),
          eraId: Value(_eraId),
          secret: _secret,
        );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final l10n = L10n.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.chronicleDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(chronicleRepositoryProvider).delete(widget.eventId);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final monthRows = ref.watch(calendarMonthsProvider).value ?? const [];
    final months = CalendarRepository.monthsOf(monthRows);
    final eras = ref.watch(chronicleErasProvider).value ?? const [];
    // Wiki tamamlamasi icin Kayitlar sayfa basliklari.
    final pageTitles = [
      for (final p
          in ref.watch(codexPagesProvider).value ?? const <CodexPage>[])
        p.title,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.calendarTabChronicle),
        actions: [
          IconButton(
            onPressed: _loaded ? _delete : null,
            icon: const Icon(Icons.delete_outline),
          ),
          TextButton.icon(
            onPressed: _loaded ? _save : null,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: Text(l10n.save),
          ),
        ],
      ),
      body: !_loaded
          ? const AppLoading()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _title,
                  decoration: InputDecoration(
                    labelText: l10n.chronicleEventTitle,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                _DateRow(
                  label: l10n.calendarDay,
                  date: _start,
                  months: months,
                  yearOnly: _yearOnly,
                  onPick: (date) => setState(() => _start = date),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _yearOnly,
                  title: Text(l10n.chronicleKnownYearOnly),
                  onChanged: (v) => setState(() => _yearOnly = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _end != null,
                  title: Text(l10n.chronicleHasEnd),
                  onChanged: (v) => setState(() => _end = v ? _start : null),
                ),
                if (_end != null)
                  _DateRow(
                    label: l10n.chronicleEnd,
                    date: _end!,
                    months: months,
                    yearOnly: _yearOnly,
                    onPick: (date) => setState(() => _end = date),
                  ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  initialValue: eras.any((e) => e.id == _eraId) ? _eraId : null,
                  decoration: InputDecoration(
                    labelText: l10n.chronicleEras,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(l10n.chronicleNoEra),
                    ),
                    for (final era in eras)
                      DropdownMenuItem(value: era.id, child: Text(era.name)),
                  ],
                  onChanged: (v) => setState(() => _eraId = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _category,
                  decoration: InputDecoration(
                    labelText: l10n.chronicleCategory,
                    helperText: l10n.chronicleCategoryHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Text(l10n.chronicleBody, style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                CodexInlineField(
                  controller: _body,
                  pageTitles: pageTitles,
                  minLines: 6,
                  maxLines: 20,
                  decoration: InputDecoration(
                    hintText: l10n.chronicleBodyHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _secret,
                  title: Text(l10n.chronicleSecret),
                  onChanged: (v) => setState(() => _secret = v),
                ),
              ],
            ),
    );
  }
}

/// Tarih satiri: okunur metin + "degistir".
class _DateRow extends ConsumerWidget {
  const _DateRow({
    required this.label,
    required this.date,
    required this.months,
    required this.yearOnly,
    required this.onPick,
  });

  final String label;
  final GameDate date;
  final List<GameMonth> months;
  final bool yearOnly;
  final ValueChanged<GameDate> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final config = ref.watch(calendarConfigProvider).value;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.calendar_month_outlined),
      title: Text(
        yearOnly
            ? formatEraYear(
                date.year,
                afterSuffix: config?.yearSuffix ?? '',
                beforeSuffix: config?.beforeYearSuffix ?? '',
              )
            : formatGameDate(
                date,
                months,
                yearSuffix: config?.yearSuffix ?? '',
                beforeYearSuffix: config?.beforeYearSuffix ?? '',
              ),
      ),
      subtitle: Text(label),
      trailing: TextButton(
        onPressed: () async {
          final picked = await pickGameDate(
            context,
            ref,
            initial: date,
            title: label,
            yearOnly: yearOnly,
          );
          if (picked != null) onPick(picked);
        },
        child: Text(l10n.edit),
      ),
    );
  }
}

/// Kampanyanin kendi takvimine gore tarih secici.
///
/// Flutter'in Gregoryen `showDatePicker`'i burada ise yaramaz: aylar ve gun
/// sayilari kullanici tanimli.
Future<GameDate?> pickGameDate(
  BuildContext context,
  WidgetRef ref, {
  required GameDate initial,
  required String title,
  bool yearOnly = false,
}) async {
  final l10n = L10n.of(context);
  final monthRows = ref.read(calendarMonthsProvider).value ?? const [];
  final months = CalendarRepository.monthsOf(monthRows);
  final yearController = TextEditingController(
    text: '${initial.year < 0 ? -initial.year : initial.year}',
  );
  var isBefore = initial.year < 0;
  var monthIndex = months.isEmpty
      ? 0
      : initial.monthIndex.clamp(0, months.length - 1);
  var day = initial.day;

  return showDialog<GameDate>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final dayCount = daysInMonth(months, monthIndex);
        if (day > dayCount) day = dayCount;
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: yearController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: l10n.calendarYear,
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
                      selected: {isBefore},
                      onSelectionChanged: (v) =>
                          setState(() => isBefore = v.first),
                    ),
                  ],
                ),
                if (!yearOnly && months.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: monthIndex,
                    decoration: InputDecoration(
                      labelText: l10n.calendarMonth,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final (i, m) in months.indexed)
                        DropdownMenuItem(value: i, child: Text(m.name)),
                    ],
                    onChanged: (v) => setState(() => monthIndex = v ?? 0),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: day.clamp(1, dayCount),
                    decoration: InputDecoration(
                      labelText: l10n.calendarDay,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (var d = 1; d <= dayCount; d++)
                        DropdownMenuItem(value: d, child: Text('$d')),
                    ],
                    onChanged: (v) => setState(() => day = v ?? 1),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final magnitude =
                    int.tryParse(yearController.text.trim()) ??
                    (initial.year < 0 ? -initial.year : initial.year);
                Navigator.pop(context, (
                  year: isBefore ? -magnitude : magnitude,
                  monthIndex: monthIndex,
                  day: day,
                ));
              },
              child: Text(l10n.save),
            ),
          ],
        );
      },
    ),
  );
}
