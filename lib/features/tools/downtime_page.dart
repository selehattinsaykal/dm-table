import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/calendar_repository.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../domain/calendar/game_calendar.dart';
import '../../domain/rules/downtime.dart';
import '../../l10n/app_localizations.dart';
import '../calendar/calendar_providers.dart';
import '../characters/character_providers.dart';

/// Iki macera arasindaki bos zaman faaliyetleri.
///
/// **Neden var:** downtime masada surekli soz veriliyor ("kilic yaptiriyorum",
/// "kutuphanede arastiriyorum") ve hicbir yerde yazmadigi icin bir sonraki
/// oturumda unutuluyor. Takvimle bagli olmasi da bu yuzden: gun ilerleyince
/// "hazir mi?" sorusunun cevabi ekranda duruyor.
///
/// Uygulama hicbir kurali ZORLAMIYOR: gun dolunca faaliyet kendiliginden
/// bitmiyor, sonucu DM yaziyor (zar atilacak, komplikasyon cikabilecek).
class DowntimePage extends ConsumerWidget {
  const DowntimePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final rows = ref.watch(downtimeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.downtime)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.downtimeAdd),
      ),
      body: switch (rows) {
        AsyncData(:final value) when value.isEmpty => Center(
          child: Text(l10n.downtimeEmpty),
        ),
        AsyncData(:final value) => ListView.builder(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: value.length,
          itemBuilder: (context, i) => _ActivityTile(activity: value[i]),
        ),
        AsyncError(:final error) => Center(child: Text('$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  static Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    DowntimeActivity? existing,
  }) async {
    final l10n = L10n.of(context);
    final characters = ref.read(charactersProvider).value ?? const [];
    final today = _today(ref);

    final title = TextEditingController(text: existing?.title ?? '');
    final notes = TextEditingController(text: existing?.notes ?? '');
    var kind = DowntimeKind.fromName(existing?.kind);
    var days = existing?.days ?? downtimeRule(kind).minimumDays;
    var characterId =
        existing?.characterId ??
        (characters.isEmpty ? null : characters.first.id);

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(existing == null ? l10n.downtimeAdd : l10n.edit),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: title,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: l10n.contentSourceName,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<DowntimeKind>(
                    initialValue: kind,
                    decoration: InputDecoration(labelText: l10n.downtime),
                    items: [
                      for (final value in DowntimeKind.values)
                        DropdownMenuItem(
                          value: value,
                          child: Text(downtimeKindLabel(l10n, value)),
                        ),
                    ],
                    onChanged: (value) => setState(() {
                      kind = value ?? DowntimeKind.custom;
                      // Tur degisince onerilen sureyi getir: egitim 70 gun,
                      // iyilesme 3 gun. Kullanici yine degistirebiliyor.
                      days = downtimeRule(kind).minimumDays;
                    }),
                  ),
                  const SizedBox(height: 12),
                  if (characters.isNotEmpty)
                    DropdownButtonFormField<String?>(
                      initialValue: characterId,
                      decoration: InputDecoration(
                        labelText: l10n.navCharacters,
                      ),
                      items: [
                        for (final character in characters)
                          DropdownMenuItem(
                            value: character.id,
                            child: Text(character.name),
                          ),
                      ],
                      onChanged: (value) => setState(() => characterId = value),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: Text(l10n.downtimeDays)),
                      SizedBox(
                        width: 80,
                        child: TextFormField(
                          key: ValueKey('days-$kind'),
                          initialValue: '$days',
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          onChanged: (value) => days = int.tryParse(value) ?? 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _costHint(kind, days),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notes,
                    maxLines: 3,
                    decoration: InputDecoration(labelText: l10n.worldPinNote),
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

    final titleText = title.text.trim();
    final notesText = notes.text.trim();
    title.dispose();
    notes.dispose();
    if (saved != true || titleText.isEmpty) return;

    final repo = ref.read(downtimeRepositoryProvider);
    if (existing == null) {
      await repo.add(
        title: titleText,
        kind: kind,
        characterId: characterId,
        days: days,
        startDay: today,
        notes: notesText,
      );
    } else {
      await repo.update(
        existing.id,
        title: titleText,
        kind: kind,
        days: days,
        notes: notesText,
      );
    }
  }

  static String _costHint(DowntimeKind kind, int days) {
    final net = downtimeNetCp(kind, days);
    if (net == 0) return '';
    final gp = (net.abs() / 100).toStringAsFixed(net.abs() % 100 == 0 ? 0 : 2);
    return net > 0 ? '+$gp gp' : '-$gp gp';
  }
}

/// Oyun-ici bugun (mutlak gun sayaci); takvim kurulu degilse 0.
///
/// [listen] true ise takvime ABONE olunuyor: gun ilerledikce "kalan gun"
/// etiketi kendiliginden guncelleniyor. Diyalog gibi tek seferlik
/// okumalarda false, cunku orada abonelik gereksiz yeniden cizim demek.
int _today(WidgetRef ref, {bool listen = false}) {
  final config = listen
      ? ref.watch(calendarConfigProvider).value
      : ref.read(calendarConfigProvider).value;
  if (config == null) return 0;
  final rows = listen
      ? ref.watch(calendarMonthsProvider).value
      : ref.read(calendarMonthsProvider).value;
  final months = CalendarRepository.monthsOf(rows ?? const []);
  return absoluteDay(CalendarRepository.dateOf(config), months);
}

String downtimeKindLabel(L10n l10n, DowntimeKind kind) => switch (kind) {
  DowntimeKind.craft => l10n.downtimeKindCraft,
  DowntimeKind.research => l10n.downtimeKindResearch,
  DowntimeKind.work => l10n.downtimeKindWork,
  DowntimeKind.train => l10n.downtimeKindTrain,
  DowntimeKind.recuperate => l10n.downtimeKindRecuperate,
  DowntimeKind.carouse => l10n.downtimeKindCarouse,
  DowntimeKind.custom => l10n.downtimeKindCustom,
};

class _ActivityTile extends ConsumerWidget {
  const _ActivityTile({required this.activity});

  final DowntimeActivity activity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final kind = DowntimeKind.fromName(activity.kind);
    final today = _today(ref, listen: true);

    final remaining = activity.startDay == null
        ? null
        : downtimeRemaining(
            startDay: activity.startDay!,
            days: activity.days,
            today: today,
          );

    final character = activity.characterId == null
        ? null
        : ref.watch(characterProvider(activity.characterId!)).value;

    return ListTile(
      leading: Icon(
        activity.done ? Icons.check_circle_outline : Icons.hourglass_bottom,
        color: activity.done ? theme.colorScheme.outline : null,
      ),
      title: Text(
        activity.title,
        style: activity.done
            ? TextStyle(
                decoration: TextDecoration.lineThrough,
                color: theme.colorScheme.outline,
              )
            : null,
      ),
      subtitle: Text(
        [
          downtimeKindLabel(l10n, kind),
          if (character != null) character.name,
          if (remaining != null && !activity.done)
            l10n.downtimeRemaining(remaining),
          if (activity.outcome.isNotEmpty) activity.outcome,
        ].join('  ·  '),
        style: theme.textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!activity.done)
            IconButton(
              tooltip: l10n.downtimeComplete,
              icon: const Icon(Icons.done_all),
              onPressed: () => _complete(context, ref),
            ),
          IconButton(
            tooltip: l10n.edit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () =>
                DowntimePage._edit(context, ref, existing: activity),
          ),
          IconButton(
            tooltip: l10n.delete,
            icon: const Icon(Icons.close),
            onPressed: () =>
                ref.read(downtimeRepositoryProvider).remove(activity.id),
          ),
        ],
      ),
    );
  }

  Future<void> _complete(BuildContext context, WidgetRef ref) async {
    final l10n = L10n.of(context);
    final outcome = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.downtimeComplete),
        content: TextField(
          controller: outcome,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(labelText: l10n.downtimeOutcome),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.downtimeComplete),
          ),
        ],
      ),
    );
    final text = outcome.text.trim();
    outcome.dispose();
    if (confirmed != true) return;
    await ref
        .read(downtimeRepositoryProvider)
        .complete(activity.id, outcome: text);
  }
}
