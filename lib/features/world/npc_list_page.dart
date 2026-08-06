import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ui/async_view.dart';
import '../../app/ui/ui.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import '../characters/character_avatar.dart';
import 'npc_detail_page.dart';
import 'world_page.dart' show askForName;
import 'world_providers.dart';

/// Kampanyadaki NPC'ler. Dokununca zengin detay/duzenleme ekrani acilir;
/// baglantilari dunya grafiginde kurulur.
class NpcListPage extends ConsumerWidget {
  const NpcListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final npcs = ref.watch(npcsProvider);
    final l10n = L10n.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.worldNpcs)),
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
            await ref.read(worldRepositoryProvider).deleteNpc(npc.id);
          }
        },
      ),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => NpcDetailPage(npcId: npc.id))),
    );
  }
}
