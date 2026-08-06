import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ui/ui.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import 'calendar_page.dart' show defaultSeasonSpec;
import 'calendar_providers.dart';

/// Takvimin YAPISI: aylar (ad + gün sayısı), gün adları, mevsimler.
///
/// Buradaki her şey kampanyaya özeldir ve serbestçe değiştirilebilir; 12 ay ×
/// 30 gün gibi bir varsayım yoktur (bkz. `domain/calendar/game_calendar.dart`).
class CalendarSettingsTab extends ConsumerWidget {
  const CalendarSettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final repo = ref.read(calendarRepositoryProvider);
    final config = ref.watch(calendarConfigProvider).value;
    final months = ref.watch(calendarMonthsProvider).value ?? const [];
    final weekdays = ref.watch(calendarWeekdaysProvider).value ?? const [];
    final seasons = ref.watch(calendarSeasonsProvider).value ?? const [];

    if (config == null) return const AppLoading();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
      children: [
        _TextSetting(
          label: l10n.calendarNameLabel,
          value: config.calendarName,
          onSaved: (v) => repo.updateConfig(calendarName: v),
        ),
        _TextSetting(
          label: l10n.calendarEraLabel,
          helper: l10n.calendarEraHint,
          value: config.eraLabel,
          onSaved: (v) => repo.updateConfig(eraLabel: v),
        ),
        _TextSetting(
          label: l10n.calendarYearSuffix,
          helper: l10n.calendarYearSuffixHint,
          value: config.yearSuffix,
          onSaved: (v) => repo.updateConfig(yearSuffix: v),
        ),
        _TextSetting(
          label: l10n.calendarYearSuffixBefore,
          helper: l10n.calendarYearSuffixBeforeHint,
          value: config.beforeYearSuffix,
          onSaved: (v) => repo.updateConfig(beforeYearSuffix: v),
        ),
        const SizedBox(height: 8),

        SectionHeader(label: l10n.calendarMonths),
        if (months.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.calendarNoMonths, style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => repo.ensureDefaultCalendar(
                    monthNames: l10n.calendarDefaultMonths.split(','),
                    weekdayNames: l10n.calendarDefaultWeekdays.split(','),
                    seasonSpec: defaultSeasonSpec(l10n),
                  ),
                  icon: const Icon(Icons.auto_fix_high, size: 18),
                  label: Text(l10n.calendarSeedDefaults),
                ),
              ],
            ),
          ),
        // Suruklemeli siralama: ay indeksleri (ve dolayisiyla tum tarihler)
        // bu siraya bagli.
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorderItem: (oldIndex, newIndex) {
            final ids = [for (final m in months) m.id];
            ids.insert(newIndex, ids.removeAt(oldIndex));
            repo.reorderMonths(ids);
          },
          children: [
            for (final (i, month) in months.indexed)
              _MonthRow(
                key: ValueKey(month.id),
                index: i,
                month: month,
                onEdit: (name, days) =>
                    repo.updateMonth(month.id, name: name, days: days),
                onDelete: () => repo.deleteMonth(month.id),
              ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => repo.addMonth('', 30),
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.calendarAddMonth),
          ),
        ),
        const SizedBox(height: 16),

        SectionHeader(label: l10n.calendarWeekdays),
        Text(l10n.calendarWeekdaysHint, style: theme.textTheme.bodySmall),
        for (final weekday in weekdays)
          _NameRow(
            value: weekday.name,
            onSaved: (v) => repo.updateWeekday(weekday.id, v),
            onDelete: () => repo.deleteWeekday(weekday.id),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => repo.addWeekday(''),
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.calendarAddWeekday),
          ),
        ),
        const SizedBox(height: 16),

        SectionHeader(label: l10n.calendarSeasons),
        Text(l10n.calendarSeasonWrapHint, style: theme.textTheme.bodySmall),
        for (final season in seasons)
          _SeasonRow(season: season, months: months),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => repo.addSeason(
              name: '',
              color: 0xFF8D6E63,
              startMonthIndex: 0,
              startDay: 1,
              endMonthIndex: months.isEmpty ? 0 : months.length - 1,
              endDay: 1,
            ),
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.calendarAddSeason),
          ),
        ),
      ],
    );
  }
}

/// Odak kaybinda kaydeden tek satirlik ayar alani.
class _TextSetting extends StatefulWidget {
  const _TextSetting({
    required this.label,
    required this.value,
    required this.onSaved,
    this.helper,
  });

  final String label;
  final String? helper;
  final String value;
  final ValueChanged<String> onSaved;

  @override
  State<_TextSetting> createState() => _TextSettingState();
}

class _TextSettingState extends State<_TextSetting> {
  late final _controller = TextEditingController(text: widget.value);
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Odak kaybinda kaydet: her tusa basista DB'ye yazmak yayin firtinasi
    // yaratirdi (her yazma tum oyunculara snapshot gonderiyor).
    _focus.addListener(() {
      if (!_focus.hasFocus) widget.onSaved(_controller.text.trim());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: _controller,
      focusNode: _focus,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helper,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onSubmitted: widget.onSaved,
    ),
  );
}

class _MonthRow extends StatefulWidget {
  const _MonthRow({
    required this.index,
    required this.month,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final int index;
  final CalendarMonth month;
  final void Function(String name, int days) onEdit;
  final VoidCallback onDelete;

  @override
  State<_MonthRow> createState() => _MonthRowState();
}

class _MonthRowState extends State<_MonthRow> {
  late final _name = TextEditingController(text: widget.month.name);
  late final _days = TextEditingController(text: '${widget.month.days}');

  // Odak kaybinda kaydet, `onTapOutside` DEGIL: `onTapOutside` disaridaki tap
  // baska bir TextField'a (ör. bir sonraki ay/hafta gunu alanina) doğrudan
  // odak verdiginde GUVENILMEZ SekIlde tetiklenmiyor -- kullanici bir alandan
  // digerine gecince yazdigi deger sessizce kaybolabiliyordu. FocusNode
  // dinleyicisi odak GERCEKTEN kaybolunca calisir, hedefi onemsemez.
  final _nameFocus = FocusNode();
  final _daysFocus = FocusNode();

  void _save() => widget.onEdit(
    _name.text.trim(),
    int.tryParse(_days.text.trim())?.clamp(1, 999) ?? widget.month.days,
  );

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus) _save();
    });
    _daysFocus.addListener(() {
      if (!_daysFocus.hasFocus) _save();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _days.dispose();
    _nameFocus.dispose();
    _daysFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: widget.index,
            child: const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.drag_handle),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _name,
              focusNode: _nameFocus,
              onEditingComplete: _save,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 96,
            child: TextField(
              controller: _days,
              focusNode: _daysFocus,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              onEditingComplete: _save,
              decoration: InputDecoration(
                isDense: true,
                suffixText: l10n.calendarMonthDays,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          IconButton(
            onPressed: widget.onDelete,
            icon: const Icon(Icons.remove_circle_outline),
          ),
        ],
      ),
    );
  }
}

class _NameRow extends StatefulWidget {
  const _NameRow({
    required this.value,
    required this.onSaved,
    required this.onDelete,
  });

  final String value;
  final ValueChanged<String> onSaved;
  final VoidCallback onDelete;

  @override
  State<_NameRow> createState() => _NameRowState();
}

class _NameRowState extends State<_NameRow> {
  late final _controller = TextEditingController(text: widget.value);

  // `onTapOutside` yerine odak kaybi dinleyicisi -- gerekce `_MonthRowState`
  // ile ayni: baska bir alana DOGRUDAN gecince guvenilir sekilde tetiklenmiyor.
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) widget.onSaved(_controller.text.trim());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            onEditingComplete: () => widget.onSaved(_controller.text.trim()),
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        IconButton(
          onPressed: widget.onDelete,
          icon: const Icon(Icons.remove_circle_outline),
        ),
      ],
    ),
  );
}

/// Mevsim satiri: ad + renk + baslangic/bitis ay-gun.
class _SeasonRow extends ConsumerWidget {
  const _SeasonRow({required this.season, required this.months});

  final CalendarSeason season;
  final List<CalendarMonth> months;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final repo = ref.read(calendarRepositoryProvider);
    String monthName(int index) =>
        months.isEmpty ? '?' : months[index.clamp(0, months.length - 1)].name;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            CircleAvatar(radius: 10, backgroundColor: Color(season.color)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    season.name.isEmpty ? l10n.calendarSeasons : season.name,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    l10n.calendarSeasonRange(
                      '${season.startDay} ${monthName(season.startMonthIndex)}',
                      '${season.endDay} ${monthName(season.endMonthIndex)}',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _edit(context, ref),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () => repo.deleteSeason(season.id),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final l10n = L10n.of(context);
    final name = TextEditingController(text: season.name);
    var startMonth = season.startMonthIndex;
    var startDay = season.startDay;
    var endMonth = season.endMonthIndex;
    var endDay = season.endDay;
    var color = season.color;

    const palette = [
      0xFF6FA36B,
      0xFFD9A441,
      0xFFB5651D,
      0xFF7FA8C9,
      0xFF9C6BA8,
      0xFF8D6E63,
    ];

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.calendarSeasons),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: name,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: l10n.calendarSeasons,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final option in palette)
                        GestureDetector(
                          onTap: () => setState(() => color = option),
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: Color(option),
                            child: color == option
                                ? const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.calendarSeasonStart),
                  _MonthDayPicker(
                    months: months,
                    monthIndex: startMonth,
                    day: startDay,
                    onChanged: (m, d) => setState(() {
                      startMonth = m;
                      startDay = d;
                    }),
                  ),
                  const SizedBox(height: 12),
                  Text(l10n.calendarSeasonEnd),
                  _MonthDayPicker(
                    months: months,
                    monthIndex: endMonth,
                    day: endDay,
                    onChanged: (m, d) => setState(() {
                      endMonth = m;
                      endDay = d;
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.calendarSeasonWrapHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
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
    await ref
        .read(calendarRepositoryProvider)
        .updateSeason(
          season.id,
          name: name.text.trim(),
          color: color,
          startMonthIndex: startMonth,
          startDay: startDay,
          endMonthIndex: endMonth,
          endDay: endDay,
        );
  }
}

class _MonthDayPicker extends StatelessWidget {
  const _MonthDayPicker({
    required this.months,
    required this.monthIndex,
    required this.day,
    required this.onChanged,
  });

  final List<CalendarMonth> months;
  final int monthIndex;
  final int day;
  final void Function(int monthIndex, int day) onChanged;

  @override
  Widget build(BuildContext context) {
    if (months.isEmpty) return const SizedBox.shrink();
    final index = monthIndex.clamp(0, months.length - 1);
    final dayCount = months[index].days;
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<int>(
            initialValue: index,
            isDense: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: [
              for (final (i, m) in months.indexed)
                DropdownMenuItem(value: i, child: Text(m.name)),
            ],
            onChanged: (v) => onChanged(v ?? 0, day),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonFormField<int>(
            initialValue: day.clamp(1, dayCount),
            isDense: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: [
              for (var d = 1; d <= dayCount; d++)
                DropdownMenuItem(value: d, child: Text('$d')),
            ],
            onChanged: (v) => onChanged(index, v ?? 1),
          ),
        ),
      ],
    );
  }
}
