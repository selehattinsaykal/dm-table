import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ui/async_view.dart';
import '../../app/ui/ui.dart';
import '../../l10n/app_localizations.dart';
import '../loot/party_inventory_page.dart';
import '../session/party_rest_card.dart';
import 'character_avatar.dart';
import 'character_providers.dart';
import 'character_sheet_page.dart';
import 'creation_wizard.dart';

/// Karakterler bölümü: karakter listesi + ortak envanter.
///
/// İki alt sekme var çünkü ikisi de "parti" hakkında: kimler var, neleri
/// ortak taşıyorlar. Ortak envanter eskiden Ganimet sekmesindeydi ama orası
/// DM'in hazırladığı ganimet şablonlarına ait; ortak kese masadaki partinin
/// canlı eşyası.
///
/// **Dinlenme ayrı bir sekme DEĞİL:** listenin üstünde bir kart olarak duruyor
/// — küçük bir işlem ve zaten karakterlerin üzerinde çalışıyor.
class CharactersPage extends ConsumerStatefulWidget {
  const CharactersPage({super.key});

  @override
  ConsumerState<CharactersPage> createState() => _CharactersPageState();
}

class _CharactersPageState extends ConsumerState<CharactersPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)
    ..addListener(() => setState(() {}));

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _newCharacter() async {
    ref.read(characterDraftProvider.notifier).reset();
    // Kok navigator: sihirbaz tam ekran acilsin. Sekme yiginina itilirse alt
    // gezinme cubugu ustte kalip akisi bolüyor ve "Ileri" butonu cubuga
    // sikisiyor.
    await Navigator.of(
      context,
      rootNavigator: true,
    ).push<String>(MaterialPageRoute(builder: (_) => const CreationWizard()));
  }

  Future<void> _newPartyInventory() async {
    final l10n = L10n.of(context);
    final id = await ref
        .read(partyInventoryRepositoryProvider)
        .create(l10n.partyInventoryNew);
    if (!mounted) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => PartyInventoryEditPage(inventoryId: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final onParty = _tabs.index == 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navCharacters),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: l10n.charactersTabParty),
            Tab(text: l10n.charactersTabSharedInventory),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onParty ? _newPartyInventory : _newCharacter,
        icon: Icon(onParty ? Icons.add : Icons.person_add_alt),
        label: Text(onParty ? l10n.partyInventoryNew : l10n.charactersNew),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [_CharacterListTab(), PartyInventoriesTab()],
      ),
    );
  }
}

/// Karakter listesi + üstünde parti dinlenmesi.
class _CharacterListTab extends ConsumerWidget {
  const _CharacterListTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final characters = ref.watch(charactersProvider);

    return asyncView(
      context,
      characters,
      loading: const SkeletonList(),
      onRetry: () => ref.invalidate(charactersProvider),
      data: (rows) => rows.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 88),
              // +1: ilk satir dinlenme karti.
              itemCount: rows.length + 1,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return const Padding(
                    padding: EdgeInsets.fromLTRB(12, 12, 12, 4),
                    child: PartyRestCard(),
                  );
                }
                final c = rows[i - 1];
                return ListTile(
                  leading: CharacterAvatar(
                    portraitPath: c.portraitPath,
                    name: c.name,
                  ),
                  title: Text(c.name),
                  subtitle: Text(
                    [
                      if (c.playerName != null && c.playerName!.isNotEmpty)
                        c.playerName!,
                      '${c.hitPointsCurrent}/${c.hitPointsMax} HP',
                    ].join(' · '),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(context, ref, c.id, c.name),
                  ),
                  onTap: () => Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (_) => CharacterSheetPage(characterId: c.id),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String id,
    String name,
  ) async {
    final l10n = L10n.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.charactersDelete),
        content: Text(l10n.charactersDeleteConfirm(name)),
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
    if (confirmed ?? false) {
      await ref.read(characterRepositoryProvider).delete(id);
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return AppEmptyState(
      icon: Icons.people_outline,
      title: l10n.charactersEmpty,
      message: l10n.charactersEmptyHint,
    );
  }
}
