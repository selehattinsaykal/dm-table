import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/campaign/campaign.dart';
import '../../data/campaign/campaign_manager.dart';
import '../../data/campaign_merge_repository.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';

/// Baska bir kampanyadan icerik alma penceresi.
///
/// **Neden var:** iyi bir canavar, NPC ya da harita bir kampanyada kaliyordu;
/// yeni kampanyada yeniden kurmak gerekiyordu.
///
/// **Ne yapmaz:** hicbir seyin uzerine yazmaz. Ayni kimlikle bir kayit
/// hedefte varsa ATLANIR -- iki kampanyada ayni kimlik ayni sey olmak
/// zorunda degil ve yanlis olani ezmek geri alinamaz.
class CampaignMergeDialog extends ConsumerStatefulWidget {
  const CampaignMergeDialog({super.key});

  @override
  ConsumerState<CampaignMergeDialog> createState() =>
      _CampaignMergeDialogState();
}

class _CampaignMergeDialogState extends ConsumerState<CampaignMergeDialog> {
  Campaign? _source;
  final _kinds = <MergeKind>{MergeKind.monsters, MergeKind.npcs};
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final active = ref.watch(activeCampaignProvider);
    // Kampanya listesi `CampaignManager`'da (ChangeNotifier); acik kampanyayi
    // kendinden kopyalamak anlamsiz oldugu icin listeden cikariliyor.
    final manager = ref.watch(campaignManagerProvider);
    final campaigns = (manager?.campaigns ?? const <Campaign>[])
        .where((c) => c.id != active.id && !c.pendingDelete)
        .toList();

    return AlertDialog(
      title: Text(l10n.campaignMerge),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.campaignMergeHint, style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            DropdownButtonFormField<Campaign>(
              initialValue: _source,
              decoration: InputDecoration(labelText: l10n.navCampaigns),
              items: [
                for (final campaign in campaigns)
                  DropdownMenuItem(value: campaign, child: Text(campaign.name)),
              ],
              onChanged: (value) => setState(() => _source = value),
            ),
            const SizedBox(height: 16),
            Text(l10n.campaignMergeWhat, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final kind in MergeKind.values)
                  FilterChip(
                    label: Text(_label(l10n, kind)),
                    selected: _kinds.contains(kind),
                    onSelected: (value) => setState(
                      () => value ? _kinds.add(kind) : _kinds.remove(kind),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _source == null || _kinds.isEmpty || _busy ? null : _run,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.campaignMerge),
        ),
      ],
    );
  }

  Future<void> _run() async {
    final l10n = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      final count = await CampaignMergeRepository(
        ref.read(databaseProvider),
      ).importFrom(_source!, kinds: _kinds);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.campaignMergeDone(count))),
      );
      navigator.pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _label(L10n l10n, MergeKind kind) => switch (kind) {
    MergeKind.monsters => l10n.compendiumMonsters,
    MergeKind.spellsAndItems => l10n.compendiumSpells,
    MergeKind.npcs => l10n.navNpcs,
    MergeKind.factions => l10n.factionsTab,
    MergeKind.locations => l10n.navWorld,
    MergeKind.randomTables => l10n.navTables,
    MergeKind.lootSets => l10n.navLoot,
  };
}
