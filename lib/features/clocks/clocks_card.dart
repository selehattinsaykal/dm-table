import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../data/clock_repository.dart';
import '../../data/db/clock_tables.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import 'clock_dial.dart';
import 'clock_providers.dart';

/// Ilerleme saatleri karti.
///
/// Iki yerde kullaniliyor ve ikisinde de AYNI widget:
///  * Oturum sekmesinde [link] verilmeden -- masadaki tum acik saatler,
///  * bir gorev/orgut sayfasinda [link] ile -- yalnizca o kayda bagli olanlar.
///
/// Kapatilmis saatler listenin sonunda soluk durur; silinmiyorlar cunku
/// "gecen ay kusatma doldu mu" sorusu seans ozetinde soruluyor.
class ClocksCard extends ConsumerWidget {
  const ClocksCard({this.link, super.key});

  /// Bagli oldugu kayit; null ise tum saatler listelenir.
  final ({ClockLinkKind kind, String id})? link;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final clocks = link == null
        ? (ref.watch(clocksProvider).value ?? const <Clock>[])
        : (ref.watch(linkedClocksProvider(link!)).value ?? const <Clock>[]);

    return Card(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.spacing.md,
          context.spacing.sm,
          context.spacing.sm,
          context.spacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.incomplete_circle,
                  size: 18,
                  color: context.fantasyColors.brass,
                ),
                SizedBox(width: context.spacing.sm),
                Expanded(
                  child: Text(
                    l10n.clocksTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: l10n.clockAdd,
                  icon: const Icon(Icons.add),
                  onPressed: () => showClockEditor(context, ref, link: link),
                ),
              ],
            ),
            if (clocks.isEmpty)
              Padding(
                padding: EdgeInsets.only(top: context.spacing.xs),
                child: Text(
                  l10n.clocksEmpty,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              )
            else
              for (final clock in clocks) _ClockRow(clock: clock),
          ],
        ),
      ),
    );
  }
}

class _ClockRow extends ConsumerWidget {
  const _ClockRow({required this.clock});

  final Clock clock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final repo = ref.read(clockRepositoryProvider);
    final full = ClockRepository.isFull(clock);

    return Opacity(
      // Kapatilmis saat listede kalir ama one cikmaz.
      opacity: clock.done ? 0.5 : 1,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: context.spacing.xs),
        child: Row(
          children: [
            ClockDial(
              segments: clock.segments,
              filled: clock.filled,
              onSet: clock.done
                  ? null
                  : (filled) => repo.setFilled(clock.id, filled),
            ),
            SizedBox(width: context.spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clock.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      decoration: clock.done
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  Text(
                    // Dolu bir saat sonucunu SOYLUYOR: "doldu, e ne olacak?"
                    // sorusunun cevabi satirin kendisinde olmali.
                    full && clock.outcome.isNotEmpty
                        ? clock.outcome
                        : '${clock.filled} / ${clock.segments}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: full
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: full ? FontWeight.w600 : null,
                    ),
                  ),
                ],
              ),
            ),
            if (!clock.done)
              IconButton(
                tooltip: l10n.clockAdvance,
                icon: const Icon(Icons.add_circle_outline),
                onPressed: full ? null : () => repo.advance(clock.id),
              ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (value) async {
                switch (value) {
                  case 'edit':
                    await showClockEditor(context, ref, existing: clock);
                  case 'done':
                    await repo.setDone(clock.id, !clock.done);
                  case 'delete':
                    await repo.delete(clock.id);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text(l10n.edit)),
                PopupMenuItem(
                  value: 'done',
                  child: Text(clock.done ? l10n.clockReopen : l10n.clockClose),
                ),
                PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Saat olusturma/duzenleme paneli.
///
/// [existing] verilirse duzenler, yoksa [link]'e bagli yeni bir saat acar.
Future<void> showClockEditor(
  BuildContext context,
  WidgetRef ref, {
  Clock? existing,
  ({ClockLinkKind kind, String id})? link,
}) async {
  final result = await showModalBottomSheet<_ClockDraft>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _ClockEditor(existing: existing),
    ),
  );
  if (result == null) return;

  final repo = ref.read(clockRepositoryProvider);
  if (existing == null) {
    await repo.create(
      name: result.name,
      segments: result.segments,
      outcome: result.outcome,
      linkKind: link?.kind ?? ClockLinkKind.none,
      linkId: link?.id,
    );
  } else {
    await repo.update(
      existing.id,
      name: result.name,
      segments: result.segments,
      outcome: result.outcome,
    );
  }
}

typedef _ClockDraft = ({String name, int segments, String outcome});

class _ClockEditor extends StatefulWidget {
  const _ClockEditor({this.existing});

  final Clock? existing;

  @override
  State<_ClockEditor> createState() => _ClockEditorState();
}

class _ClockEditorState extends State<_ClockEditor> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _outcome = TextEditingController(
    text: widget.existing?.outcome ?? '',
  );
  late int _segments =
      widget.existing?.segments ?? ClockRepository.defaultSegments;

  /// Hazir dilim sayilari: masada neredeyse her zaman bunlardan biri
  /// seciliyor, kaydirici koymak gereksiz hassasiyet olurdu.
  static const _presets = [4, 6, 8, 10, 12];

  @override
  void dispose() {
    _name.dispose();
    _outcome.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.spacing.lg,
          0,
          context.spacing.lg,
          context.spacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? l10n.clockAdd : l10n.edit,
              style: theme.textTheme.titleLarge,
            ),
            SizedBox(height: context.spacing.md),
            TextField(
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.clockName,
                hintText: l10n.clockNameHint,
                border: const OutlineInputBorder(),
              ),
            ),
            SizedBox(height: context.spacing.md),
            Row(
              children: [
                ClockDial(segments: _segments, filled: 0, size: 52),
                SizedBox(width: context.spacing.md),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    children: [
                      for (final n in _presets)
                        ChoiceChip(
                          label: Text('$n'),
                          selected: _segments == n,
                          onSelected: (_) => setState(() => _segments = n),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: context.spacing.md),
            TextField(
              controller: _outcome,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: l10n.clockOutcome,
                helperText: l10n.clockOutcomeHint,
                border: const OutlineInputBorder(),
              ),
            ),
            SizedBox(height: context.spacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),
                SizedBox(width: context.spacing.sm),
                FilledButton(
                  onPressed: () {
                    final name = _name.text.trim();
                    if (name.isEmpty) return;
                    Navigator.pop(context, (
                      name: name,
                      segments: _segments,
                      outcome: _outcome.text.trim(),
                    ));
                  },
                  child: Text(l10n.save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
