import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/combat_repository.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../calendar/calendar_providers.dart';
import '../calendar/restock_notice.dart';
import '../characters/character_providers.dart';
import 'session_log_providers.dart';

/// Parti molası: DM tüm ekibe (ya da seçtiklerine) kısa/uzun mola verir.
///
/// Tekil karakter molası karakter kâğıdında zaten vardı; masada asıl istenen
/// "herkes dinlensin" işlemi elle tek tek yapılıyordu. Ayrıca burada mola
/// sonrası savaş listesindeki can da senkronlanır
/// ([CombatRepository.syncFromCharacter]) — karakter kâğıdındaki eski mola
/// düğmesi bunu yapmadığı için savaş ekranı bayat can gösteriyordu.
class PartyRestCard extends ConsumerStatefulWidget {
  const PartyRestCard({super.key});

  @override
  ConsumerState<PartyRestCard> createState() => _PartyRestCardState();
}

class _PartyRestCardState extends ConsumerState<PartyRestCard> {
  /// Seçili karakterler; boşsa "hepsi" demektir.
  final _selected = <String>{};
  bool _busy = false;

  List<Character> _targets(List<Character> all) => _selected.isEmpty
      ? all
      : [
          for (final c in all)
            if (_selected.contains(c.id)) c,
        ];

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final characters =
        ref.watch(charactersProvider).value ?? const <Character>[];

    if (characters.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.restPartyTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(l10n.restPartyHint, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                FilterChip(
                  label: Text(l10n.restEveryone),
                  selected: _selected.isEmpty,
                  onSelected: (_) => setState(_selected.clear),
                ),
                for (final c in characters)
                  FilterChip(
                    label: Text(c.name),
                    selected: _selected.contains(c.id),
                    onSelected: (v) => setState(() {
                      if (v) {
                        _selected.add(c.id);
                      } else {
                        _selected.remove(c.id);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _openShortRest(_targets(characters)),
                  icon: const Icon(
                    Icons.local_fire_department_outlined,
                    size: 18,
                  ),
                  label: Text(l10n.restShort),
                ),
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _longRest(_targets(characters)),
                  icon: const Icon(Icons.bedtime_outlined, size: 18),
                  label: Text(l10n.restLong),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Uzun mola: onay + (karar) takvimde bir gün ilerletme.
  Future<void> _longRest(List<Character> targets) async {
    final l10n = L10n.of(context);
    if (targets.isEmpty) return;

    // Takvim kurulmadiysa gun ilerletme secenegi hic gosterilmez.
    final hasCalendar =
        (ref.read(calendarMonthsProvider).value ?? const []).isNotEmpty;
    var advanceDay = hasCalendar;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          icon: const Icon(Icons.bedtime_outlined),
          title: Text(l10n.restLong),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.restLongConfirm(targets.length)),
              if (hasCalendar)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: advanceDay,
                  title: Text(l10n.restAdvanceDay),
                  onChanged: (v) => setLocal(() => advanceDay = v ?? false),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.restLong),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    final repo = ref.read(characterRepositoryProvider);
    final combat = CombatRepository(ref.read(databaseProvider));
    for (final character in targets) {
      await repo.longRest(character.id);
      // Savas listesindeki can da yenilensin.
      await combat.syncFromCharacter(character.id);
    }

    // Gunu ilerletmenin yan etkileri (magaza stok yenilemesi) tek giristen
    // gecsin diye `GameClock` kullaniliyor.
    final advanced = advanceDay
        ? await ref.read(gameClockProvider).advanceDays(1)
        : null;

    await ref
        .read(sessionLogRepositoryProvider)
        .add(
          advanced == null
              ? l10n.restLoggedLong(targets.length)
              : '${l10n.restLoggedLong(targets.length)} — ${advanced.label}',
        );
    if (mounted) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.restLoggedLong(targets.length))),
      );
      // Stok yenilendiyse DM haberdar olsun (mola geceyi atlatir; yenileme
      // sessizce olursa DM dukkanda ne degistigini gormez).
      if (advanced != null) showRestockNotice(context, advanced);
    }
  }

  /// Kısa mola: masadaki her karakter için hit dice harcama paneli açar.
  ///
  /// 5e'de hit die harcamak oyuncunun kararıdır (kaç tane, ne zaman). Masada
  /// kararı oyuncu verir, sayıyı DM işler: panel her karakter için tek tek
  /// "zar harca" düğmesi gösterir, toptan uygulamaz.
  Future<void> _openShortRest(List<Character> targets) async {
    if (targets.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _ShortRestSheet(targets: targets),
    );
  }
}

/// Kısa dinlenme paneli: her karakterin canı, kalan hit dice'ı ve zar harcama
/// düğmesi.
class _ShortRestSheet extends ConsumerStatefulWidget {
  const _ShortRestSheet({required this.targets});

  final List<Character> targets;

  @override
  ConsumerState<_ShortRestSheet> createState() => _ShortRestSheetState();
}

class _ShortRestSheetState extends ConsumerState<_ShortRestSheet> {
  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    // Canli karakter listesi: zar harcandikca can ve kalan zar guncellenir.
    final live = ref.watch(charactersProvider).value ?? const <Character>[];
    final byId = {for (final c in live) c.id: c};

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.restShort, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(l10n.restShortOpenHint, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final target in widget.targets)
                    _HitDiceRow(character: byId[target.id] ?? target),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _close,
              icon: const Icon(Icons.check, size: 18),
              label: Text(l10n.restShortFinish),
            ),
          ],
        ),
      ),
    );
  }

  void _close() => Navigator.pop(context);
}

/// Tek karakterin dinlenme satiri: can, kalan hit dice ve zar harcama.
class _HitDiceRow extends ConsumerWidget {
  const _HitDiceRow({required this.character});

  final Character character;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final status = ref.watch(hitDiceStatusProvider(character.id)).value;
    final left = status == null ? 0 : status.total - status.used;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(character.name),
      subtitle: Text(
        status == null
            ? '${character.hitPointsCurrent}/${character.hitPointsMax} HP'
            : '${character.hitPointsCurrent}/${character.hitPointsMax} HP · '
                  '${l10n.restHitDiceLeft(left, status.total)}',
      ),
      // Zar KARAKTER BASINA ve TEK TEK atiliyor: kac tane harcanacagi
      // oyuncunun karari, DM yalnizca sonucu isliyor.
      trailing: OutlinedButton.icon(
        onPressed: left <= 0 ? null : () => _spend(context, ref, l10n),
        icon: const Icon(Icons.casino_outlined, size: 18),
        label: Text(l10n.restSpendHitDie),
      ),
    );
  }

  Future<void> _spend(BuildContext context, WidgetRef ref, L10n l10n) async {
    final spend = await ref
        .read(characterRepositoryProvider)
        .spendHitDie(character.id);
    if (spend == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.restHitDieSpent(character.name, spend.healed)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
