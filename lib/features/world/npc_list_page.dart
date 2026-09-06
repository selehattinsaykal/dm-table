import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ui/async_view.dart';
import '../../app/ui/ui.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../app/undo.dart';
import '../../l10n/app_localizations.dart';
import '../characters/character_avatar.dart';
import 'faction_detail_page.dart';
import 'npc_detail_page.dart';
import 'world_page.dart' show askForName;
import 'world_providers.dart';

/// Kampanyanin KISILERI ve ORGUTLERI.
///
/// Iki sekme, tek dal: NPC ve fraksiyon ayri kayitlar ama masada ayni soruyu
/// cevapliyorlar ("bu kim / bunlar kim"). Fraksiyona ayri bir ust sekme
/// acmadik: kabukta zaten on alti hedef var ve on yedincisi hicbirini
/// kolaylastirmazdi.
class NpcListPage extends ConsumerWidget {
  const NpcListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.worldNpcs),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.worldNpcs),
              Tab(text: l10n.factionsTab),
            ],
          ),
        ),
        body: const TabBarView(children: [_NpcTab(), _FactionTab()]),
      ),
    );
  }
}

class _NpcTab extends ConsumerWidget {
  const _NpcTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final npcs = ref.watch(npcsProvider);
    final l10n = L10n.of(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.person_add_alt),
        label: Text(l10n.worldNpcAdd),
      ),
      body: asyncView(
        context,
        npcs,
        loading: const SkeletonList(),
        onRetry: () => ref.invalidate(npcsProvider),
        data: (rows) => rows.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(l10n.worldNpcEmpty, textAlign: TextAlign.center),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.only(bottom: 88),
                itemCount: rows.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) => _NpcTile(npc: rows[i]),
              ),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await askForName(context, title: L10n.of(context).worldNpcAdd);
    if (name == null || !context.mounted) return;
    final id = await ref.read(worldRepositoryProvider).createNpc(name: name);
    if (!context.mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => NpcDetailPage(npcId: id)));
  }
}

/// Orgut listesi. NPC sekmesiyle ayni kalip: dokun -> detay, FAB -> yeni.
class _FactionTab extends ConsumerWidget {
  const _FactionTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final factions = ref.watch(factionsProvider);
    final l10n = L10n.of(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.group_add_outlined),
        label: Text(l10n.factionAdd),
      ),
      body: asyncView(
        context,
        factions,
        loading: const SkeletonList(),
        onRetry: () => ref.invalidate(factionsProvider),
        data: (rows) => rows.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(l10n.factionEmpty, textAlign: TextAlign.center),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.only(bottom: 88),
                itemCount: rows.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) => _FactionTile(faction: rows[i]),
              ),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await askForName(context, title: L10n.of(context).factionAdd);
    if (name == null || !context.mounted) return;
    final id = await ref
        .read(worldRepositoryProvider)
        .createFaction(name: name);
    if (!context.mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => FactionDetailPage(factionId: id)));
  }
}

class _FactionTile extends ConsumerWidget {
  const _FactionTile({required this.faction});

  final Faction faction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    return ListTile(
      leading: StoredAvatar(
        store: ref.watch(worldRepositoryProvider).portraits,
        portraitPath: faction.portraitPath,
        name: faction.name,
      ),
      title: Text(faction.name),
      subtitle: Text(
        [
          if (faction.kind.isNotEmpty) faction.kind,
          if (faction.goal.isNotEmpty) faction.goal,
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        tooltip: l10n.factionDelete,
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _confirmDelete(context, ref, l10n),
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FactionDetailPage(factionId: faction.id),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    L10n l10n,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.factionDelete),
        content: Text(l10n.factionDeleteConfirm),
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
    final repo = ref.read(worldRepositoryProvider);
    final removed = faction;
    await repo.deleteFaction(removed.id);
    ref.read(undoControllerProvider.notifier).push(removed.name, () async {
      final db = ref.read(databaseProvider);
      await db
          .into(db.factions)
          .insertOnConflictUpdate(removed.toCompanion(false));
    });
  }
}

class _NpcTile extends ConsumerWidget {
  const _NpcTile({required this.npc});

  final Npc npc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);

    return ListTile(
      // NPC portreleri karakterlerden AYRI depoda (WorldRepository.portraits).
      leading: StoredAvatar(
        store: ref.read(worldRepositoryProvider).portraits,
        portraitPath: npc.portraitPath,
        name: npc.name,
      ),
      title: Text(npc.name),
      subtitle: npc.role.isEmpty ? null : Text(npc.role),
      trailing: PopupMenuButton<String>(
        itemBuilder: (context) => [
          PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
        ],
        onSelected: (a) async {
          if (a == 'delete') {
            final undo = await ref
                .read(worldRepositoryProvider)
                .deleteNpcUndoable(npc.id);
            ref.read(undoControllerProvider.notifier).push(npc.name, undo);
          }
        },
      ),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => NpcDetailPage(npcId: npc.id))),
    );
  }
}
