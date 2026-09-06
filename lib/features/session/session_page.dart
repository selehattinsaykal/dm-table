import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/session_log_repository.dart';
import '../../l10n/app_localizations.dart';
import '../clocks/clocks_card.dart';
import '../dice/dice_sheet.dart';
import '../dice/roll_log.dart';
import '../tools/downtime_page.dart';
import '../tools/macros_page.dart';
import '../world/journey_card.dart';
import 'backup_page.dart';
import 'session_log_providers.dart';
import 'session_recap_sheet.dart';

/// Masa basindaki ana ekran: oturum gunlugu, zar kaydi, parti molasi ve
/// suren yolculuk.
///
/// Eskiden bu sekme LAN sunucusunu acan yerdi (QR kodu, bagli oyuncular,
/// satin alma onaylari). Uygulama tek kisilik bir DM aracina donunce o
/// katman kalkti; geriye seansin GERCEKTEN yurudugu yer kaldi.
class SessionPage extends ConsumerWidget {
  const SessionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navSession),
        actions: [
          IconButton(
            tooltip: l10n.macros,
            icon: const Icon(Icons.bolt_outlined),
            onPressed: () => Navigator.of(
              context,
              rootNavigator: true,
            ).push(MaterialPageRoute(builder: (_) => const MacrosPage())),
          ),
          IconButton(
            tooltip: l10n.downtime,
            icon: const Icon(Icons.hourglass_bottom),
            onPressed: () => Navigator.of(
              context,
              rootNavigator: true,
            ).push(MaterialPageRoute(builder: (_) => const DowntimePage())),
          ),
          IconButton(
            tooltip: l10n.sessionRecap,
            icon: const Icon(Icons.auto_stories_outlined),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (_) => const SessionRecapSheet(),
            ),
          ),
          IconButton(
            tooltip: l10n.sessionBackup,
            icon: const Icon(Icons.backup_outlined),
            onPressed: () => Navigator.of(
              context,
              rootNavigator: true,
            ).push(MaterialPageRoute(builder: (_) => const BackupPage())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          // Suren yolculuk yoksa hic yer kaplamaz.
          JourneyCard(),
          SizedBox(height: 16),
          // Saatler zar kaydinin USTUNDE: oyun sirasinda ilerleyen sey bu,
          // zar kaydi ise geriye bakilan yer.
          ClocksCard(),
          SizedBox(height: 16),
          _RollLogCard(),
          SizedBox(height: 16),
          _SessionLogCard(),
        ],
      ),
    );
  }
}

/// Kalici oturum gunlugu: XP odulleri ve elle notlar. En yeni ustte.
class _SessionLogCard extends ConsumerWidget {
  const _SessionLogCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final entries = ref.watch(sessionLogProvider).value ?? const [];
    final repo = ref.read(sessionLogRepositoryProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history_edu_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.sessionLogTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: l10n.sessionLogAdd,
                  icon: const Icon(Icons.add),
                  onPressed: () => _addEntry(context, repo, l10n),
                ),
                if (entries.isNotEmpty)
                  IconButton(
                    tooltip: l10n.sessionLogClear,
                    icon: const Icon(Icons.delete_sweep_outlined),
                    onPressed: () => _confirmClear(context, repo, l10n),
                  ),
              ],
            ),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 8, 4),
                child: Text(
                  l10n.sessionLogEmpty,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              )
            else
              for (final e in entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 44,
                        child: Text(
                          _hhmm(e.createdAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          e.message,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      InkWell(
                        onTap: () => repo.deleteEntry(e.id),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  static String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _addEntry(
    BuildContext context,
    SessionLogRepository repo,
    L10n l10n,
  ) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.sessionLogAdd),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (text != null && text.isNotEmpty) await repo.add(text);
  }

  Future<void> _confirmClear(
    BuildContext context,
    SessionLogRepository repo,
    L10n l10n,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.sessionLogClear),
        content: Text(l10n.sessionLogClearConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.sessionLogClear),
          ),
        ],
      ),
    );
    if (ok == true) await repo.clear();
  }
}

/// Zar gunlugu: bu oturumda atilan son zarlar, en yenisi ustte.
///
/// Masada en cok sorulan sorulardan biri "az once kac gelmisti?" idi ve
/// cevabi hicbir yerde yazmiyordu. Kayit bellekte tutuluyor; bkz.
/// [rollLogProvider].
class _RollLogCard extends ConsumerWidget {
  const _RollLogCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    // En yenisi USTTE: masada bakilan sey son atis.
    final rolls = ref.watch(rollLogProvider).reversed.toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.sessionRolls,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: l10n.diceRollTitle,
                  icon: const Icon(Icons.casino_outlined),
                  onPressed: () => showDiceSheet(
                    context,
                    onRolled: (roll) =>
                        ref.read(rollLogProvider.notifier).add(roll),
                  ),
                ),
                if (rolls.isNotEmpty)
                  IconButton(
                    tooltip: l10n.sessionLogClear,
                    icon: const Icon(Icons.delete_sweep_outlined),
                    onPressed: () => ref.read(rollLogProvider.notifier).clear(),
                  ),
              ],
            ),
            if (rolls.isEmpty)
              Text(l10n.sessionRollsEmpty, style: theme.textTheme.bodySmall)
            else
              for (final roll in rolls.take(12))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        child: Text(
                          '${roll.total}',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              roll.source == null
                                  ? roll.label
                                  : '${roll.source}  ·  ${roll.label}',
                              style: theme.textTheme.bodyMedium,
                            ),
                            Text(
                              roll.detail,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
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
