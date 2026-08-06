import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/campaign/campaign.dart';
import '../../data/campaign/campaign_manager.dart';
import '../../l10n/app_localizations.dart';
import '../session/session_page.dart';

/// Kampanya adını gösterir; varsayılan kampanyanın adı boş bırakıldığı için
/// (kayıt katmanı dile bağımlı değil) etiketi buradan gelir.
String campaignLabel(L10n l10n, Campaign campaign) =>
    campaign.name.trim().isNotEmpty ? campaign.name : l10n.campaignDefaultName;

/// Kampanyalar: her biri kendi veritabanı dosyası. Karakterler, dünya,
/// görevler, kayıtlar ve takvim kampanyaya özeldir.
class CampaignsPage extends ConsumerWidget {
  const CampaignsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final manager = ref.watch(campaignManagerProvider);
    // Gercek uygulamada `CampaignRoot` her zaman override eder; yalnizca
    // kampanya altyapisi kurmadan pump eden testlerde null olur.
    if (manager == null) {
      return Scaffold(appBar: AppBar(title: Text(l10n.navCampaigns)));
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navCampaigns)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref, manager, l10n),
        icon: const Icon(Icons.add),
        label: Text(l10n.campaignNew),
      ),
      // Liste `ProviderScope`'un ustunde yasadigi icin Riverpod degil
      // ChangeNotifier ile izlenir (bkz. CampaignManager).
      body: ListenableBuilder(
        listenable: manager,
        builder: (context, _) {
          final campaigns = manager.campaigns;
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Text(
                  l10n.campaignExplainer,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              for (final campaign in campaigns)
                _CampaignTile(
                  campaign: campaign,
                  active: campaign.id == manager.active.id,
                  canDelete: campaigns.length > 1,
                  manager: manager,
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _create(
    BuildContext context,
    WidgetRef ref,
    CampaignManager manager,
    L10n l10n,
  ) async {
    final name = await _nameDialog(context, l10n, title: l10n.campaignNew);
    if (name == null || !context.mounted) return;
    if (!await _confirmSwitch(context, ref, l10n)) return;
    await manager.create(name);
  }
}

class _CampaignTile extends ConsumerWidget {
  const _CampaignTile({
    required this.campaign,
    required this.active,
    required this.canDelete,
    required this.manager,
  });

  final Campaign campaign;
  final bool active;
  final bool canDelete;
  final CampaignManager manager;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        leading: Icon(
          active ? Icons.bookmark : Icons.bookmark_border,
          color: active ? theme.colorScheme.primary : null,
        ),
        title: Text(
          campaignLabel(l10n, campaign),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: active ? FontWeight.w600 : null,
          ),
        ),
        subtitle: Text(
          active ? l10n.campaignActive : l10n.campaignInactive,
          style: theme.textTheme.bodySmall?.copyWith(
            color: active
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) async {
            switch (value) {
              case 'open':
                await _open(context, ref, l10n);
              case 'rename':
                await _rename(context, l10n);
              case 'delete':
                await _delete(context, l10n);
            }
          },
          itemBuilder: (_) => [
            if (!active)
              PopupMenuItem(
                value: 'open',
                child: Row(
                  children: [
                    const Icon(Icons.open_in_new, size: 18),
                    const SizedBox(width: 8),
                    Text(l10n.campaignOpen),
                  ],
                ),
              ),
            PopupMenuItem(
              value: 'rename',
              child: Row(
                children: [
                  const Icon(Icons.edit_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text(l10n.campaignRename),
                ],
              ),
            ),
            if (!active && canDelete)
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline, size: 18),
                    const SizedBox(width: 8),
                    Text(l10n.delete),
                  ],
                ),
              ),
          ],
        ),
        onTap: active ? null : () => _open(context, ref, l10n),
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref, L10n l10n) async {
    if (!await _confirmSwitch(context, ref, l10n)) return;
    await manager.open(campaign.id);
  }

  Future<void> _rename(BuildContext context, L10n l10n) async {
    final name = await _nameDialog(
      context,
      l10n,
      title: l10n.campaignRename,
      initial: campaignLabel(l10n, campaign),
    );
    if (name != null) await manager.rename(campaign.id, name);
  }

  Future<void> _delete(BuildContext context, L10n l10n) async {
    final name = campaignLabel(l10n, campaign);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.campaignDeleteTitle(name)),
        content: Text(l10n.campaignDeleteBody),
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
    final removed = await manager.delete(campaign.id);
    if (!context.mounted) return;
    // Dosya kilitliyse kayit gizlenir ve bir sonraki acilista silinir.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          removed ? l10n.campaignDeleted : l10n.campaignDeleteLater,
        ),
      ),
    );
  }
}

Future<String?> _nameDialog(
  BuildContext context,
  L10n l10n, {
  required String title,
  String initial = '',
}) async {
  final controller = TextEditingController(text: initial);
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: l10n.campaignNameLabel,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
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
  return (name == null || name.isEmpty) ? null : name;
}

/// Oturum açıkken kampanya değiştirmek bağlı oyuncuların bağlantısını keser ve
/// yeni bir katılım adresi üretir; DM'e bunu açıkça sorarız.
Future<bool> _confirmSwitch(
  BuildContext context,
  WidgetRef ref,
  L10n l10n,
) async {
  if (!ref.read(sessionControllerProvider).isRunning) return true;
  final players = ref.read(connectedPlayersProvider).value ?? const [];

  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(
        Icons.warning_amber,
        color: Theme.of(context).colorScheme.error,
      ),
      title: Text(l10n.campaignSwitchTitle),
      content: Text(
        players.isEmpty
            ? l10n.campaignSwitchBody
            : '${l10n.campaignSwitchBody}\n\n'
                  '${l10n.campaignSwitchPlayers([for (final p in players) p.name].join(', '))}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.campaignSwitchConfirm),
        ),
      ],
    ),
  );
  return ok ?? false;
}
