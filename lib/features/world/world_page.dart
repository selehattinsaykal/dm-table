import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ui/async_view.dart';
import '../../app/ui/ui.dart';
import '../../l10n/app_localizations.dart';
import 'location_page.dart';
import 'npc_list_page.dart';
import 'world_graph_page.dart';
import 'world_providers.dart';

/// Dunya sekmesi: kitalar/krallıklar/şehirler bir force-directed dugum-agi
/// (grafik) olarak gosterilir. Bir dugume sag tik / uzun bas o yerin klasik
/// gorsel haritasini acar (bkz. [WorldGraph]).
class WorldPage extends ConsumerWidget {
  const WorldPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final locations = ref.watch(allLocationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navWorld),
        actions: [
          IconButton(
            tooltip: l10n.worldNpcs,
            icon: const Icon(Icons.people_alt_outlined),
            onPressed: () => Navigator.of(
              context,
              rootNavigator: true,
            ).push(MaterialPageRoute(builder: (_) => const NpcListPage())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add_location_alt),
        label: Text(l10n.worldNewLocation),
      ),
      body: asyncView(
        context,
        locations,
        loading: const SkeletonList(),
        onRetry: () => ref.invalidate(allLocationsProvider),
        data: (rows) => rows.isEmpty ? const _Empty() : const WorldGraph(),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await askForName(
      context,
      title: L10n.of(context).worldNewLocation,
    );
    if (name == null || !context.mounted) return;

    final id = await ref
        .read(worldRepositoryProvider)
        .createLocation(name: name);
    if (!context.mounted) return;
    await Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute(builder: (_) => LocationPage(locationId: id)));
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
              Icons.hub_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(l10n.worldEmpty, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              l10n.worldEmptyHint,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tek satirlik ad sorma; birkac yerden kullaniliyor.
Future<String?> askForName(
  BuildContext context, {
  required String title,
  String initial = '',
  String? label,
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) {
      final l10n = L10n.of(context);
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: label ?? l10n.worldNameLabel,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (v) =>
              v.trim().isEmpty ? null : Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(context, value);
            },
            child: Text(l10n.ok),
          ),
        ],
      );
    },
  );
}
