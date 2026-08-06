import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ui/async_view.dart';
import '../../app/ui/ui.dart';
import '../../l10n/app_localizations.dart';
import 'combat_providers.dart';
import 'encounter_page.dart';

/// Karsilasma listesi. Masada genelde tek bir aktif savas olur ama hazirlikta
/// birden fazla karsilasma kurulabilsin diye liste tutuluyor.
class CombatPage extends ConsumerWidget {
  const CombatPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final encounters = ref.watch(encountersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navCombat)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.combatNewEncounter),
      ),
      body: asyncView(
        context,
        encounters,
        loading: const SkeletonList(),
        onRetry: () => ref.invalidate(encountersProvider),
        data: (rows) => rows.isEmpty
            ? const _Empty()
            : ListView.separated(
                padding: const EdgeInsets.only(bottom: 88),
                itemCount: rows.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final e = rows[i];
                  return ListTile(
                    leading: Icon(
                      e.started ? Icons.play_circle : Icons.pending_outlined,
                      color: e.started
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    title: Text(e.name),
                    subtitle: Text(
                      e.started
                          ? l10n.combatRoundN(e.round)
                          : l10n.combatPreparing,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => ref
                          .read(combatRepositoryProvider)
                          .deleteEncounter(e.id),
                    ),
                    onTap: () =>
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute(
                            builder: (_) => EncounterPage(encounterId: e.id),
                          ),
                        ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final l10n = L10n.of(context);
    final controller = TextEditingController(text: l10n.combatEncounterName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.combatNewEncounter),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.combatNameLabel,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(l10n.combatCreate),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !context.mounted) return;

    final id = await ref.read(combatRepositoryProvider).createEncounter(name);
    if (!context.mounted) return;
    await Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute(builder: (_) => EncounterPage(encounterId: id)));
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shield_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(l10n.combatEmpty, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              l10n.combatEmptyHint,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
