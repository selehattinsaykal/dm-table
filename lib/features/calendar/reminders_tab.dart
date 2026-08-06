import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../data/calendar_repository.dart';
import '../../data/db/database.dart';
import '../../data/reminder_repository.dart';
import '../../domain/calendar/game_calendar.dart';
import '../../domain/calendar/reminders.dart';
import '../../l10n/app_localizations.dart';
import 'calendar_providers.dart';
import 'chronicle_event_editor.dart' show pickGameDate;

/// Hatırlatıcılar sekmesi: ileriye dönük ve tekrarlayan takvim kayıtları.
///
/// Tarihçeden (geçmiş) ayrı tutuluyor: bunlar gün ilerledikçe DM'e bildirilen
/// **gelecek** olaylar ("her ayın 1'i vergi", "3 gün sonra kervan").
class RemindersTab extends ConsumerWidget {
  const RemindersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final rows = ref.watch(remindersProvider).value ?? const [];
    final months = CalendarRepository.monthsOf(
      ref.watch(calendarMonthsProvider).value ?? const [],
    );
    final config = ref.watch(calendarConfigProvider).value;
    final today = config == null
        ? 0
        : absoluteDay(CalendarRepository.dateOf(config), months);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(Icons.add_alert_outlined),
        label: Text(l10n.reminderNew),
      ),
      body: rows.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n.reminderEmpty,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) => _ReminderRow(
                reminder: rows[i],
                months: months,
                today: today,
                config: config,
                onTap: () => _edit(context, ref, rows[i]),
                onDelete: () =>
                    ref.read(reminderRepositoryProvider).delete(rows[i].id),
                onToggleDone: (v) => ref
                    .read(reminderRepositoryProvider)
                    .update(rows[i].id, done: v),
              ),
            ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    CalendarReminder? existing,
  ) async {
    final config = ref.read(calendarConfigProvider).value;
    if (config == null) return;
    final initial = existing == null
        ? CalendarRepository.dateOf(config)
        : (
            year: existing.startYear,
            monthIndex: existing.startMonthIndex,
            day: existing.startDay,
          );

    final result = await showDialog<_ReminderDraft>(
      context: context,
      builder: (_) => _ReminderDialog(existing: existing, initialDate: initial),
    );
    if (result == null) return;

    final repo = ref.read(reminderRepositoryProvider);
    if (existing == null) {
      await repo.create(
        title: result.title,
        body: result.body,
        start: result.start,
        repeat: result.repeat,
        everyNDays: result.everyNDays,
      );
    } else {
      await repo.update(
        existing.id,
        title: result.title,
        body: result.body,
        start: result.start,
        repeat: result.repeat,
        everyNDays: result.everyNDays,
      );
    }
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({
    required this.reminder,
    required this.months,
    required this.today,
    required this.config,
    required this.onTap,
    required this.onDelete,
    required this.onToggleDone,
  });

  final CalendarReminder reminder;
  final List<GameMonth> months;
  final int today;
  final CalendarConfigData? config;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleDone;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final repeat = ReminderRepeat.fromCode(reminder.repeatKind);
    final next = reminder.done
        ? null
        : nextOccurrence(
            ReminderRepository.specOf(reminder),
            months,
            afterDay: today - 1, // bugun de "siradaki" sayilsin
          );

    final subtitle = [
      reminderRepeatLabel(l10n, repeat, reminder.everyNDays),
      if (next != null)
        l10n.reminderNext(
          formatGameDate(
            fromAbsoluteDay(next, months),
            months,
            eraLabel: config?.eraLabel ?? '',
            yearSuffix: config?.yearSuffix ?? '',
            beforeYearSuffix: config?.beforeYearSuffix ?? '',
          ),
        )
      else if (!reminder.done)
        l10n.reminderNoNext,
    ].join(' · ');

    return ListTile(
      leading: Icon(
        reminder.done
            ? Icons.notifications_off_outlined
            : Icons.notifications_active_outlined,
        color: reminder.done
            ? theme.colorScheme.outline
            : context.fantasyColors.brass,
      ),
      title: Text(
        reminder.title,
        style: TextStyle(
          decoration: reminder.done ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: reminder.done ? l10n.reminderReopen : l10n.reminderClose,
            icon: Icon(reminder.done ? Icons.replay : Icons.check, size: 18),
            onPressed: () => onToggleDone(!reminder.done),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

/// Tekrar türünün okunur adı (listede ve dialogda aynı metin kullanılsın).
String reminderRepeatLabel(L10n l10n, ReminderRepeat repeat, int everyNDays) =>
    switch (repeat) {
      ReminderRepeat.once => l10n.reminderRepeatOnce,
      ReminderRepeat.everyNDays => l10n.reminderRepeatEveryNDays(everyNDays),
      ReminderRepeat.monthly => l10n.reminderRepeatMonthly,
      ReminderRepeat.yearly => l10n.reminderRepeatYearly,
    };

typedef _ReminderDraft = ({
  String title,
  String body,
  GameDate start,
  ReminderRepeat repeat,
  int everyNDays,
});

class _ReminderDialog extends ConsumerStatefulWidget {
  const _ReminderDialog({required this.existing, required this.initialDate});

  final CalendarReminder? existing;
  final GameDate initialDate;

  @override
  ConsumerState<_ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends ConsumerState<_ReminderDialog> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _body = TextEditingController(text: widget.existing?.body ?? '');
  late final _every = TextEditingController(
    text: '${widget.existing?.everyNDays ?? 3}',
  );
  late GameDate _start = widget.initialDate;
  late ReminderRepeat _repeat = widget.existing == null
      ? ReminderRepeat.once
      : ReminderRepeat.fromCode(widget.existing!.repeatKind);

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _every.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final months = CalendarRepository.monthsOf(
      ref.watch(calendarMonthsProvider).value ?? const [],
    );
    final config = ref.watch(calendarConfigProvider).value;

    return AlertDialog(
      title: Text(l10n.reminderNew),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _title,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.reminderTitle,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _body,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: l10n.reminderBody,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text(
                formatGameDate(
                  _start,
                  months,
                  eraLabel: config?.eraLabel ?? '',
                  yearSuffix: config?.yearSuffix ?? '',
                  beforeYearSuffix: config?.beforeYearSuffix ?? '',
                ),
              ),
              onPressed: () async {
                final picked = await pickGameDate(
                  context,
                  ref,
                  initial: _start,
                  title: l10n.reminderStart,
                );
                if (picked != null) setState(() => _start = picked);
              },
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.reminderRepeat,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in ReminderRepeat.values)
                  ChoiceChip(
                    label: Text(
                      r == ReminderRepeat.everyNDays
                          ? l10n.reminderRepeatEveryNDaysShort
                          : reminderRepeatLabel(l10n, r, 0),
                    ),
                    selected: _repeat == r,
                    onSelected: (_) => setState(() => _repeat = r),
                  ),
              ],
            ),
            if (_repeat == ReminderRepeat.everyNDays) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _every,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.reminderEveryNDaysLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
            if (_repeat == ReminderRepeat.monthly) ...[
              const SizedBox(height: 8),
              Text(
                l10n.reminderMonthlyHint,
                style: Theme.of(context).textTheme.bodySmall,
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
            final title = _title.text.trim();
            if (title.isEmpty) return;
            Navigator.pop(context, (
              title: title,
              body: _body.text.trim(),
              start: _start,
              repeat: _repeat,
              everyNDays: int.tryParse(_every.text.trim()) ?? 1,
            ));
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
