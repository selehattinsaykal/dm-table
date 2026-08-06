import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ui/async_view.dart';
import '../../app/ui/ui.dart';
import '../../data/db/database.dart';
import '../../data/party_inventory_repository.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../characters/character_providers.dart';
import 'loot_page.dart' show CompendiumLootPickerDialog, formatLootCoins;

final partyInventoryRepositoryProvider = Provider<PartyInventoryRepository>(
  (ref) => PartyInventoryRepository(ref.watch(databaseProvider)),
);

final partyInventoriesProvider = StreamProvider<List<PartyInventory>>(
  (ref) => ref.watch(partyInventoryRepositoryProvider).watchAll(),
);

/// Tek bir kesenin canli kaydi.
///
/// Duzenleme sayfasi bunu izliyor: kese ORTAK, yani DM sayfa acikken bir
/// oyuncu icine esya koyabilir/alabilir. Sayfa veriyi yalnizca acilista
/// okudugu surece bu degisiklikler ekranda gorunmuyor, DM'in cikip yeniden
/// girmesi gerekiyordu.
final partyInventoryProvider = StreamProvider.family<PartyInventory?, String>(
  (ref, id) => ref.watch(partyInventoryRepositoryProvider).watchOne(id),
);

/// Ortak parti keseleri listesi (Ganimet sayfasinin ikinci sekmesi).
///
/// Uye oyuncular kendi panellerinden serbestce alir/koyar; DM onayi yoktur.
class PartyInventoriesTab extends ConsumerWidget {
  const PartyInventoriesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final inventories = ref.watch(partyInventoriesProvider);

    return asyncView(
      context,
      inventories,
      loading: const SkeletonList(),
      onRetry: () => ref.invalidate(partyInventoriesProvider),
      data: (rows) => rows.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n.partyInventoryEmpty,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) => _PartyTile(inventory: rows[i]),
            ),
    );
  }
}

class _PartyTile extends ConsumerWidget {
  const _PartyTile({required this.inventory});

  final PartyInventory inventory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final items = PartyInventoryRepository.itemsOf(inventory);
    final members = PartyInventoryRepository.membersOf(inventory);
    final summary = [
      members.isEmpty
          ? l10n.partyInventoryNoMembers
          : l10n.partyInventoryMembersCount(members.length),
      if (items.isNotEmpty) l10n.lootItemCount(items.length),
      if (inventory.coinsCp > 0) formatLootCoins(inventory.coinsCp),
    ].join(' · ');

    return ListTile(
      leading: const Icon(Icons.backpack),
      title: Text(inventory.name),
      subtitle: Text(summary),
      onTap: () => Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => PartyInventoryEditPage(inventoryId: inventory.id),
        ),
      ),
    );
  }
}

/// Bir ortak keseyi duzenler: ad, para, esyalar, uyeler.
class PartyInventoryEditPage extends ConsumerStatefulWidget {
  const PartyInventoryEditPage({required this.inventoryId, super.key});

  final String inventoryId;

  @override
  ConsumerState<PartyInventoryEditPage> createState() =>
      _PartyInventoryEditPageState();
}

class _PartyInventoryEditPageState
    extends ConsumerState<PartyInventoryEditPage> {
  final _name = TextEditingController();
  final _pp = TextEditingController();
  final _gp = TextEditingController();
  final _sp = TextEditingController();
  final _cp = TextEditingController();
  final _newItem = TextEditingController();

  final _items = <PartyItem>[];
  final _members = <String>{};
  bool _newItemMagic = false;
  bool _loaded = false;

  /// DM bu sayfada esya/para alanlarina dokundu mu? Dokunduysa disaridan gelen
  /// degisiklikler artik uzerine yazilmaz (bkz. [_applyExternal]).
  bool _dirty = false;

  /// pp/gp/sp/cp -> bakir. `_PurseCard` ve `LootSetEditPage` ile ayni.
  static const _units = [1000, 100, 10, 1];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final inv = await ref
        .read(partyInventoryRepositoryProvider)
        .find(widget.inventoryId);
    if (inv == null || !mounted) return;
    _name.text = inv.name;
    _fillCoins(inv.coinsCp);
    _items
      ..clear()
      ..addAll(PartyInventoryRepository.itemsOf(inv));
    _members
      ..clear()
      ..addAll(PartyInventoryRepository.membersOf(inv));
    setState(() => _loaded = true);
  }

  void _fillCoins(int coinsCp) {
    var rest = coinsCp;
    final controllers = [_pp, _gp, _sp, _cp];
    for (var i = 0; i < _units.length; i++) {
      controllers[i].text = '${rest ~/ _units[i]}';
      rest %= _units[i];
    }
  }

  /// Oyuncunun keseye disaridan yaptigi degisikligi ekrana yansitir.
  ///
  /// **Yalnizca DM bu alanlara dokunmadiysa** ([_dirty]): aksi halde yarim
  /// kalmis bir duzenleme sessizce silinirdi. DM kaydedip cikinca ya da
  /// sayfayi yeniden acinca zaten taze veri gelir.
  void _applyExternal(PartyInventory inv) {
    if (_dirty || !_loaded) return;
    final incoming = PartyInventoryRepository.itemsOf(inv);
    final sameItems =
        incoming.length == _items.length &&
        [for (final i in incoming) i.id].join() ==
            [for (final i in _items) i.id].join() &&
        [for (final i in incoming) i.quantity].join() ==
            [for (final i in _items) i.quantity].join();
    if (sameItems && inv.coinsCp == _coinTotal()) return;

    setState(() {
      _items
        ..clear()
        ..addAll(incoming);
      _fillCoins(inv.coinsCp);
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _pp, _gp, _sp, _cp, _newItem]) {
      c.dispose();
    }
    super.dispose();
  }

  int _coinTotal() {
    int v(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;
    return v(_pp) * 1000 + v(_gp) * 100 + v(_sp) * 10 + v(_cp);
  }

  Future<void> _save() async {
    final l10n = L10n.of(context);
    final repo = ref.read(partyInventoryRepositoryProvider);
    await repo.rename(
      widget.inventoryId,
      _name.text.trim().isEmpty ? l10n.partyInventoryNew : _name.text.trim(),
    );
    await repo.setCoins(widget.inventoryId, _coinTotal());
    await repo.setItems(widget.inventoryId, _items);
    await repo.setMembers(widget.inventoryId, _members.toList());
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final l10n = L10n.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.partyInventoryDeleteConfirm(_name.text.trim())),
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
    await ref.read(partyInventoryRepositoryProvider).delete(widget.inventoryId);
    if (mounted) Navigator.of(context).pop();
  }

  Widget _coinField(TextEditingController c, String label) => Expanded(
    child: TextField(
      controller: c,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      // DM paraya dokunduysa oyuncudan gelen degisiklik formu ezmesin.
      onChanged: (_) => _dirty = true,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  void _addFreeTextItem() {
    final name = _newItem.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _items.add(
        PartyInventoryRepository.newItem(name: name, magic: _newItemMagic),
      );
      _newItem.clear();
      _newItemMagic = false;
      _dirty = true;
    });
  }

  /// Katalogdan ekleme. Anahtar KORUNUR: esya kese <-> karakter arasinda
  /// gidip geldigi icin anahtar dusseydi kalici olarak serbest metne donerdi.
  Future<void> _openCompendiumPicker() async {
    await showDialog<void>(
      context: context,
      builder: (context) => CompendiumLootPickerDialog(
        onAdd: (key, name, magic) {
          if (!mounted) return;
          setState(() {
            _items.add(
              PartyInventoryRepository.newItem(
                name: name,
                magic: magic,
                itemKey: magic ? null : key,
                magicItemKey: magic ? key : null,
              ),
            );
            _dirty = true;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);

    // Kese ORTAK: sayfa acikken bir oyuncu icine esya koyabilir/alabilir.
    ref.listen(partyInventoryProvider(widget.inventoryId), (_, next) {
      if (next.value case final inv?) _applyExternal(inv);
    });

    if (!_loaded) return const Scaffold(body: AppLoading());

    final characters = ref.watch(charactersProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.partyInventoryTitle),
        actions: [
          IconButton(
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline),
          ),
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: Text(l10n.save),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: l10n.partyInventoryName,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),

          SectionHeader(label: l10n.partyInventoryMembers),
          Text(
            l10n.partyInventoryMembersHint,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          if (characters.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                l10n.partyInventoryNoCharacters,
                style: theme.textTheme.bodySmall,
              ),
            )
          else
            for (final c in characters)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _members.contains(c.id),
                title: Text(c.name),
                onChanged: (v) => setState(() {
                  if (v ?? false) {
                    _members.add(c.id);
                  } else {
                    _members.remove(c.id);
                  }
                }),
              ),
          const SizedBox(height: 20),

          SectionHeader(label: l10n.partyInventoryCoins),
          Row(
            children: [
              _coinField(_pp, 'pp'),
              const SizedBox(width: 8),
              _coinField(_gp, 'gp'),
              const SizedBox(width: 8),
              _coinField(_sp, 'sp'),
              const SizedBox(width: 8),
              _coinField(_cp, 'cp'),
            ],
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(child: SectionHeader(label: l10n.partyInventoryItems)),
              TextButton.icon(
                onPressed: _openCompendiumPicker,
                icon: const Icon(Icons.library_books_outlined, size: 18),
                label: Text(l10n.lootAddFromCompendium),
              ),
            ],
          ),
          for (final (i, item) in _items.indexed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                item.magic ? Icons.auto_awesome : Icons.backpack_outlined,
                color: item.magic ? theme.colorScheme.tertiary : null,
              ),
              title: Text(item.name.isEmpty ? l10n.lootUnknownItem : item.name),
              subtitle: item.quantity > 1 ? Text('×${item.quantity}') : null,
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() {
                  _items.removeAt(i);
                  _dirty = true;
                }),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newItem,
                  onSubmitted: (_) => _addFreeTextItem(),
                  decoration: InputDecoration(
                    labelText: l10n.lootAddItem,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: Text(l10n.lootMagic),
                selected: _newItemMagic,
                onSelected: (v) => setState(() => _newItemMagic = v),
              ),
              IconButton(
                onPressed: _addFreeTextItem,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
