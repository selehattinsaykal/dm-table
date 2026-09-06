import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/ui/async_view.dart';
import '../../app/ui/ui.dart';
import '../../data/db/database.dart';
import '../../data/loot_repository.dart';
import '../../data/content_tr.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import 'party_inventory_page.dart';

final lootRepositoryProvider = Provider<LootRepository>(
  (ref) => LootRepository(ref.watch(databaseProvider)),
);

final lootSetsProvider = StreamProvider<List<LootSet>>(
  (ref) => ref.watch(lootRepositoryProvider).watchAll(),
);

/// Ganimet setleri: DM önceden eşya + para hazırlar, masada tek dokunuşla
/// ortak parti kesesine aktarır.
///
/// Ortak parti keseleri buradan **Karakterler** sekmesine taşındı: set bir
/// şablon, ortak kese ise masadaki partinin canlı eşyası — ikisi farklı şeyler.
class LootPage extends ConsumerStatefulWidget {
  const LootPage({super.key});

  @override
  ConsumerState<LootPage> createState() => _LootPageState();
}

class _LootPageState extends ConsumerState<LootPage> {
  Future<void> _createLootSet() async {
    final l10n = L10n.of(context);
    final id = await ref.read(lootRepositoryProvider).create(l10n.navLoot);
    if (!mounted) return;
    await Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute(builder: (_) => LootSetEditPage(setId: id)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    // Ortak parti keseleri artik Karakterler sekmesinde: burasi DM'in
    // HAZIRLADIGI ganimet sablonlarina ait, ortak kese ise masadaki partinin
    // canli esyasi.
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navLoot)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createLootSet,
        icon: const Icon(Icons.add),
        label: Text(l10n.lootNewSet),
      ),
      body: const _LootSetsTab(),
    );
  }
}

class _LootSetsTab extends ConsumerWidget {
  const _LootSetsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final sets = ref.watch(lootSetsProvider);

    return asyncView(
      context,
      sets,
      loading: const SkeletonList(),
      onRetry: () => ref.invalidate(lootSetsProvider),
      data: (rows) => rows.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(l10n.lootEmpty, textAlign: TextAlign.center),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) => _LootSetTile(set: rows[i]),
            ),
    );
  }
}

class _LootSetTile extends ConsumerWidget {
  const _LootSetTile({required this.set});

  final LootSet set;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final items = LootRepository.itemsOf(set);
    final summary = [
      if (items.isNotEmpty) l10n.lootItemCount(items.length),
      if (set.coinsCp > 0) formatLootCoins(set.coinsCp),
    ].join(' · ');

    return ListTile(
      leading: const Icon(Icons.card_giftcard),
      title: Text(set.name),
      subtitle: Text(summary.isEmpty ? l10n.lootEmptyLabel : summary),
      onTap: () => Navigator.of(
        context,
        rootNavigator: true,
      ).push(MaterialPageRoute(builder: (_) => LootSetEditPage(setId: set.id))),
      trailing: FilledButton.icon(
        onPressed: (items.isEmpty && set.coinsCp <= 0)
            ? null
            : () => _grant(context, ref, l10n, items),
        icon: const Icon(Icons.move_down, size: 18),
        label: Text(l10n.lootGrant),
      ),
    );
  }

  /// Seti bir ortak parti kesesine BOSALTIR.
  ///
  /// Eskiden bu dugme seti oyuncu panellerine "sunuyordu"; oyuncular kendi
  /// aralarinda paylasiyordu. Panel kalkinca ayni hareketin masadaki
  /// karsiligi kaldi: ganimet ortak keseye gider, dagitimi DM yapar.
  ///
  /// Set SILINMEZ: bir sablon, tek kullanimlik bir havuz degil -- ayni
  /// "goblin kampi ganimeti" birden fazla kez verilebilir.
  Future<void> _grant(
    BuildContext context,
    WidgetRef ref,
    L10n l10n,
    List<LootItemData> items,
  ) async {
    final inventories =
        ref.read(partyInventoriesProvider).value ?? const <PartyInventory>[];
    if (inventories.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.lootNoPartyBag)));
      return;
    }

    // Tek kese varsa sormuyoruz: masada en sik durum bu ve ek bir dokunus
    // hicbir sey secmiyor.
    final target = inventories.length == 1
        ? inventories.first.id
        : await showModalBottomSheet<String>(
            context: context,
            showDragHandle: true,
            builder: (context) => SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final inv in inventories)
                    ListTile(
                      leading: const Icon(Icons.backpack_outlined),
                      title: Text(inv.name),
                      onTap: () => Navigator.pop(context, inv.id),
                    ),
                ],
              ),
            ),
          );
    if (target == null) return;

    final repo = ref.read(partyInventoryRepositoryProvider);
    if (set.coinsCp > 0) {
      await repo.depositCoins(target, amountCp: set.coinsCp);
    }
    // Her satira YENI bir id: kesedeki `id` alma isleminin tek tutamagi
    // (yaris korumasi, bkz. PartyInventoryRepository). Set bir sablon oldugu
    // icin ayni set iki kez verilse bile satirlar ayrismali.
    const uuid = Uuid();
    for (final item in items) {
      await repo.depositItem(
        target,
        item: (
          id: uuid.v4(),
          name: item.name,
          magic: item.magic,
          itemKey: null,
          magicItemKey: null,
          desc: null,
          quantity: 1,
        ),
      );
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.lootGranted(set.name)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// Bir ganimet setini duzenler: ad, 4 tur para, esya listesi.
class LootSetEditPage extends ConsumerStatefulWidget {
  const LootSetEditPage({required this.setId, super.key});

  final String setId;

  @override
  ConsumerState<LootSetEditPage> createState() => _LootSetEditPageState();
}

class _LootSetEditPageState extends ConsumerState<LootSetEditPage> {
  final _name = TextEditingController();
  final _pp = TextEditingController();
  final _gp = TextEditingController();
  final _sp = TextEditingController();
  final _cp = TextEditingController();
  final _newItem = TextEditingController();

  final List<LootItemData> _items = [];
  bool _newItemMagic = false;
  bool _loaded = false;

  static const _units = [1000, 100, 10, 1];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final set = await ref.read(lootRepositoryProvider).find(widget.setId);
    if (set == null || !mounted) return;
    _name.text = set.name;
    var rest = set.coinsCp;
    final controllers = [_pp, _gp, _sp, _cp];
    for (var i = 0; i < _units.length; i++) {
      controllers[i].text = '${rest ~/ _units[i]}';
      rest %= _units[i];
    }
    _items
      ..clear()
      ..addAll(LootRepository.itemsOf(set));
    setState(() => _loaded = true);
  }

  int _coinTotal() {
    int v(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;
    return v(_pp) * 1000 + v(_gp) * 100 + v(_sp) * 10 + v(_cp);
  }

  Future<void> _save() async {
    final fallback = L10n.of(context).navLoot;
    await ref
        .read(lootRepositoryProvider)
        .update(
          widget.setId,
          name: _name.text.trim().isEmpty ? fallback : _name.text.trim(),
          coinsCp: _coinTotal(),
          items: _items,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    for (final c in [_name, _pp, _gp, _sp, _cp, _newItem]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _coinField(TextEditingController c, String label) => Expanded(
    child: TextField(
      controller: c,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  void _addItem() {
    final name = _newItem.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _items.add((name: name, magic: _newItemMagic));
      _newItem.clear();
      _newItemMagic = false;
    });
  }

  /// Compendium'dan (esya / buyulu esya) hazineye ekleme dialogu. Dialog
  /// acik kaldigi surece tek tikla birden fazla esya eklenebilir.
  Future<void> _openCompendiumPicker() async {
    await showDialog<void>(
      context: context,
      builder: (context) => CompendiumLootPickerDialog(
        // Ganimet setleri ada gore calisir; katalog anahtari kullanilmaz.
        onAdd: (_, name, magic) {
          if (!mounted) return;
          setState(() => _items.add((name: name, magic: magic)));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    if (!_loaded) {
      return const Scaffold(body: AppLoading());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.lootSetTitle),
        actions: [TextButton(onPressed: _save, child: Text(l10n.save))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: l10n.lootSetName,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Text(l10n.lootMoney, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.lootItems, style: theme.textTheme.titleMedium),
              TextButton.icon(
                onPressed: _openCompendiumPicker,
                icon: const Icon(Icons.library_books_outlined, size: 18),
                label: Text(l10n.lootAddFromCompendium),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_items.isEmpty)
            Text(l10n.lootNoItems, style: theme.textTheme.bodySmall),
          for (final (i, item) in _items.indexed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                item.magic ? Icons.auto_awesome : Icons.backpack_outlined,
                color: item.magic ? theme.colorScheme.tertiary : null,
              ),
              title: Text(
                itemNameTr(contentNamesTrOf(context, ref), item.name),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => setState(() => _items.removeAt(i)),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newItem,
                  decoration: InputDecoration(
                    labelText: l10n.lootAddItem,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _addItem(),
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: Text(l10n.lootMagic),
                selected: _newItemMagic,
                onSelected: (v) => setState(() => _newItemMagic = v),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _addItem,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bakiri okunur paraya cevirir (pp/gp/sp/cp).
///
/// Ortak parti kesesi sayfasi da bunu kullanir; ikinci bir kopya yazma.
String formatLootCoins(int cp) {
  if (cp == 0) return '0 gp';
  final pp = cp ~/ 1000;
  final gp = (cp % 1000) ~/ 100;
  final sp = (cp % 100) ~/ 10;
  final rest = cp % 10;
  return [
    if (pp > 0) '$pp pp',
    if (gp > 0) '$gp gp',
    if (sp > 0) '$sp sp',
    if (rest > 0) '$rest cp',
  ].join(' ');
}

/// Compendium'dan esya / buyulu esya arayip ganimete ekleyen dialog. Hem
/// hazine setleri hem gorev odulleri kullanir.
///
/// Dialog acik kaldigi surece her satira tiklamak o esyayi [onAdd] ile ekler
/// ve satirda onay isareti gorunur; "Kapat" ile cikilir. [codex_block_editors]
/// icindeki `_EntityPickerDialog` ile ayni arama pattern'i.
class CompendiumLootPickerDialog extends ConsumerStatefulWidget {
  const CompendiumLootPickerDialog({required this.onAdd, super.key});

  /// Secilen esya. [key] katalog anahtaridir; ganimet setleri kullanmaz ama
  /// ortak parti kesesi buna ihtiyac duyar: esya karakter <-> kese arasinda
  /// gidip geldigi icin anahtar dusseydi kalici olarak serbest metne donerdi.
  final void Function(String key, String name, bool magic) onAdd;

  @override
  ConsumerState<CompendiumLootPickerDialog> createState() =>
      CompendiumLootPickerDialogState();
}

class CompendiumLootPickerDialogState
    extends ConsumerState<CompendiumLootPickerDialog> {
  /// false = esyalar, true = buyulu esyalar.
  bool _magic = false;
  String _query = '';

  /// Bu oturumda eklenmis satirlar (onay isareti gostermek icin).
  final Set<String> _added = {};

  Future<List<({String key, String name, bool magic})>> _search() async {
    final repo = ref.read(compendiumRepositoryProvider);
    if (_magic) {
      return [
        for (final m in await repo.searchMagicItems(query: _query, limit: 40))
          (key: m.key, name: m.name, magic: true),
      ];
    }
    return [
      for (final i in await repo.searchItems(query: _query, limit: 40))
        (key: i.key, name: i.name, magic: false),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l10n.lootAddFromCompendium),
      content: SizedBox(
        width: 420,
        height: 460,
        child: Column(
          children: [
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: false, label: Text(l10n.compendiumItems)),
                ButtonSegment(
                  value: true,
                  label: Text(l10n.compendiumMagicItems),
                ),
              ],
              selected: {_magic},
              onSelectionChanged: (s) => setState(() => _magic = s.first),
            ),
            const SizedBox(height: 8),
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.searchHint,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child:
                  FutureBuilder<List<({String key, String name, bool magic})>>(
                    future: _search(),
                    builder: (context, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final rows = snap.data ?? const [];
                      if (rows.isEmpty) {
                        return Center(
                          child: Text(
                            l10n.lootNoItems,
                            style: theme.textTheme.bodySmall,
                          ),
                        );
                      }
                      return ListView.builder(
                        itemCount: rows.length,
                        itemBuilder: (context, i) {
                          final row = rows[i];
                          final isAdded = _added.contains(row.key);
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              row.magic
                                  ? Icons.auto_awesome
                                  : Icons.backpack_outlined,
                              color: row.magic
                                  ? theme.colorScheme.tertiary
                                  : null,
                            ),
                            title: Text(
                              itemNameTr(
                                contentNamesTrOf(context, ref),
                                row.name,
                              ),
                            ),
                            trailing: isAdded
                                ? Icon(
                                    Icons.check_circle,
                                    color: theme.colorScheme.primary,
                                  )
                                : const Icon(Icons.add_circle_outline),
                            onTap: isAdded
                                ? null
                                : () {
                                    setState(() => _added.add(row.key));
                                    widget.onAdd(row.key, row.name, row.magic);
                                  },
                          );
                        },
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}
