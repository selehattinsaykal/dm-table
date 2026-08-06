import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ui/async_view.dart';
import '../../app/ui/ui.dart';
import '../../data/db/database.dart';
import '../../data/shop_repository.dart';
import '../../domain/rules/magic_item_pricing.dart';
import '../../l10n/app_localizations.dart';
import '../compendium/compendium_providers.dart';
import '../world/npc_detail_page.dart';
import 'custom_item_forms.dart';
import 'shop_owner_field.dart';
import 'shop_providers.dart';

/// Magaza kurucu: stok ekle, fiyat/adet ayarla, oyunculara ac.
class ShopDetailPage extends ConsumerWidget {
  const ShopDetailPage({required this.shopId, super.key});

  final String shopId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shop = ref.watch(shopProvider(shopId)).value;
    final entries = ref.watch(shopEntriesProvider(shopId));

    if (shop == null) {
      return const Scaffold(body: AppLoading());
    }
    final l10n = L10n.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(shop.name),
        actions: [
          IconButton(
            tooltip: l10n.sdAddFromLibrary,
            icon: const Icon(Icons.library_add),
            onPressed: () => _addFromCompendium(context, ref),
          ),
          PopupMenuButton<String>(
            itemBuilder: (context) => [
              PopupMenuItem(value: 'item', child: Text(l10n.sdCreateOwnItem)),
              PopupMenuItem(value: 'magic', child: Text(l10n.sdCreateOwnMagic)),
              PopupMenuItem(value: 'free', child: Text(l10n.sdAddFreeLine)),
            ],
            onSelected: (v) => _addCustom(context, ref, v),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          _SettingsCard(shop: shop),
          const SizedBox(height: 12),
          entries.when(
            loading: () => const AppLoading(),
            error: (e, _) => Text('$e'),
            data: (rows) => rows.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l10n.sdStockEmpty, textAlign: TextAlign.center),
                  )
                : Column(
                    children: [
                      for (final entry in rows)
                        _StockTile(entry: entry, shopId: shopId),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _addFromCompendium(BuildContext context, WidgetRef ref) async {
    final picked =
        await showModalBottomSheet<({String? itemKey, String? magicKey})>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (context) => const _ItemPicker(),
        );
    if (picked == null) return;

    await ref
        .read(shopRepositoryProvider)
        .addItem(
          shopId: shopId,
          itemKey: picked.itemKey,
          magicItemKey: picked.magicKey,
        );
  }

  Future<void> _addCustom(
    BuildContext context,
    WidgetRef ref,
    String kind,
  ) async {
    final repo = ref.read(shopRepositoryProvider);
    switch (kind) {
      case 'item':
        final key = await showCustomItemForm(context, ref);
        if (key != null) await repo.addItem(shopId: shopId, itemKey: key);
      case 'magic':
        final key = await showCustomMagicItemForm(context, ref);
        if (key != null) await repo.addItem(shopId: shopId, magicItemKey: key);
      case 'free':
        if (!context.mounted) return;
        final line = await showFreeStockForm(context);
        if (line != null) {
          await repo.addItem(
            shopId: shopId,
            customName: line.name,
            customDesc: line.description,
            priceCpOverride: line.priceGp * 100,
            quantity: line.quantity,
          );
        }
    }
  }
}

class _SettingsCard extends ConsumerWidget {
  const _SettingsCard({required this.shop});

  final Shop shop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final repo = ref.read(shopRepositoryProvider);
    final l10n = L10n.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Isleten NPC hem burada degistirilebilir hem de bagliysa NPC
            // sayfasina gidilir; yaratma diyalogunda yanlis secilen kisi
            // baska turlu duzeltilemiyordu.
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                shop.ownerNpcId != null ? Icons.person : Icons.person_outline,
                color: shop.ownerNpcId != null
                    ? theme.colorScheme.primary
                    : null,
              ),
              title: Text(
                shop.ownerName != null && shop.ownerName!.isNotEmpty
                    ? l10n.sdOperator(shop.ownerName!)
                    : l10n.sdOperatorNone,
                style: theme.textTheme.bodyMedium,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Bagli NPC varsa kartina gidilebilir: "bu tuccar kimdi"
                  // sorusu mağazadan tek dokunusla cevaplanir.
                  if (shop.ownerNpcId != null)
                    IconButton(
                      tooltip: l10n.sdOpenOwnerNpc,
                      icon: const Icon(Icons.open_in_new, size: 18),
                      onPressed: () =>
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  NpcDetailPage(npcId: shop.ownerNpcId!),
                            ),
                          ),
                    ),
                  const Icon(Icons.edit_outlined, size: 18),
                ],
              ),
              onTap: () => _editOwner(context, ref, shop),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.sdPriceMultiplier,
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        l10n.sdPriceMultiplierHint,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  '×${shop.priceMultiplier.toStringAsFixed(2)}',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            Slider(
              value: shop.priceMultiplier.clamp(0.5, 3),
              min: 0.5,
              max: 3,
              divisions: 25,
              label: '×${shop.priceMultiplier.toStringAsFixed(2)}',
              onChanged: (v) => repo.update(shop.id, priceMultiplier: v),
            ),
            const Divider(height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.sdClosed),
              subtitle: Text(l10n.sdClosedHint),
              value: shop.closed,
              onChanged: (on) => repo.update(shop.id, closed: on),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.sdOpenToPlayers),
              subtitle: Text(l10n.sdOpenHint),
              value: shop.openToPlayers,
              onChanged: (on) => repo.openOnly(on ? shop.id : null),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.sdMapAccessible),
              subtitle: Text(l10n.sdMapAccessibleHint),
              value: shop.mapAccessible,
              onChanged: (on) => repo.update(shop.id, mapAccessible: on),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.sdRequireApproval),
              subtitle: Text(l10n.sdRequireApprovalHint),
              value: shop.requiresApproval,
              onChanged: (on) => repo.update(shop.id, requiresApproval: on),
            ),
            const Divider(height: 24),
            _RestockRow(shop: shop),
          ],
        ),
      ),
    );
  }

  Future<void> _editOwner(
    BuildContext context,
    WidgetRef ref,
    Shop shop,
  ) async {
    var owner = (npcId: shop.ownerNpcId, name: shop.ownerName);
    final l10n = L10n.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.shopsOwnerNpc),
        content: SingleChildScrollView(
          child: ShopOwnerField(initial: owner, onChanged: (v) => owner = v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (ok != true) return;
    await ref
        .read(shopRepositoryProvider)
        .setOwner(shop.id, npcId: owner.npcId, name: owner.name);
  }
}

/// Takvime bagli stok yenilemesi: kac oyun-ici gunde bir tazelensin.
///
/// Yenileme takvim ilerledikce kendiliginden calisir (bkz. `GameClock`);
/// burada yalnizca periyot ayarlanir. Hangi satirin ne kadara donecegi
/// satir menusundeki "yenileme adedi" ile belirlenir — periyot acik olsa bile
/// `restockQuantity` verilmemis satirlar dokunulmadan kalir.
class _RestockRow extends ConsumerWidget {
  const _RestockRow({required this.shop});

  final Shop shop;

  /// Hazir periyotlar: kapali, gunluk, haftalik, iki haftalik, aylik, mevsimlik.
  static const _options = [0, 1, 7, 14, 30, 90];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final repo = ref.read(shopRepositoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.sdRestock, style: theme.textTheme.bodyMedium),
        Text(l10n.sdRestockHint, style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final days in _options)
              ChoiceChip(
                label: Text(
                  days == 0 ? l10n.sdRestockOff : l10n.sdRestockEvery(days),
                ),
                selected: shop.restockDays == days,
                onSelected: (_) => repo.update(shop.id, restockDays: days),
              ),
            // Hazir periyotlarin disinda bir deger (elle girilmis) kaybolmasin.
            if (!_options.contains(shop.restockDays))
              ChoiceChip(
                label: Text(l10n.sdRestockEvery(shop.restockDays)),
                selected: true,
                onSelected: (_) {},
              ),
          ],
        ),
      ],
    );
  }
}

class _StockTile extends ConsumerWidget {
  const _StockTile({required this.entry, required this.shopId});

  final ShopEntry entry;
  final String shopId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final repo = ref.read(shopRepositoryProvider);
    final l10n = L10n.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.name, style: theme.textTheme.titleSmall),
                  Text(
                    [
                      if (entry.category != null) entry.category!,
                      if (entry.rarity != null) entry.rarity!,
                      if (entry.requiresAttunement) 'attunement',
                    ].join(' · '),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        formatCoins(entry.priceCp),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      if (entry.priceIsSuggested)
                        Text(
                          '  (${l10n.compendiumSuggested})',
                          style: theme.textTheme.labelSmall,
                        ),
                      const SizedBox(width: 12),
                      Text(
                        entry.unlimited
                            ? l10n.sdUnlimited
                            : l10n.sdPieces(entry.stock.quantity),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: entry.soldOut
                              ? theme.colorScheme.error
                              : theme.colorScheme.outline,
                        ),
                      ),
                      // Sinirsiz satirda yenileme adedi anlamsiz (hic azalmaz).
                      if (!entry.unlimited &&
                          entry.stock.restockQuantity != null) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.autorenew,
                          size: 13,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          l10n.sdRestockQtyBadge(entry.stock.restockQuantity!),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              itemBuilder: (context) => [
                PopupMenuItem(value: 'price', child: Text(l10n.sdEditPrice)),
                PopupMenuItem(value: 'qty', child: Text(l10n.sdEditQuantity)),
                PopupMenuItem(
                  value: 'unlimited',
                  child: Text(l10n.sdMakeUnlimited),
                ),
                PopupMenuItem(value: 'restock', child: Text(l10n.sdRestockQty)),
                PopupMenuItem(value: 'remove', child: Text(l10n.remove)),
              ],
              onSelected: (action) async {
                switch (action) {
                  case 'price':
                    final gp = await _askNumber(
                      context,
                      title: l10n.sdPriceTitle(entry.name),
                      initial: entry.priceCp ~/ 100,
                      suffix: 'gp',
                    );
                    if (gp != null) {
                      await repo.updateStock(
                        entry.stock.id,
                        priceCpOverride: gp * 100,
                      );
                      ref.invalidate(shopEntriesProvider(shopId));
                    }
                  case 'qty':
                    if (!context.mounted) return;
                    final qty = await _askNumber(
                      context,
                      title: l10n.sdQtyTitle(entry.name),
                      initial: entry.unlimited ? 1 : entry.stock.quantity,
                    );
                    if (qty != null) {
                      await repo.updateStock(entry.stock.id, quantity: qty);
                    }
                  case 'unlimited':
                    await repo.updateStock(entry.stock.id, quantity: -1);
                  case 'restock':
                    if (!context.mounted) return;
                    final target = await _askRestockQuantity(
                      context,
                      title: l10n.sdRestockQtyTitle(entry.name),
                      initial: entry.stock.restockQuantity,
                    );
                    if (target != null) {
                      await repo.updateStock(
                        entry.stock.id,
                        restockQuantity: target.clear ? null : target.quantity,
                        clearRestockQuantity: target.clear,
                      );
                    }
                  case 'remove':
                    await repo.removeStock(entry.stock.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Yenileme adedi sorar. `null` = vazgecildi; `clear` = "bu satiri yenileme".
///
/// Ayri bir fonksiyon olmasinin sebebi [_askNumber]'in "temizle" durumunu
/// tasiyamamasi: burada 0 gecerli bir hedef (yenilemede satir bosalsin) ve
/// "hic yenileme" ondan FARKLI bir durum.
Future<({bool clear, int quantity})?> _askRestockQuantity(
  BuildContext context, {
  required String title,
  required int? initial,
}) {
  final controller = TextEditingController(text: '${initial ?? 1}');
  return showDialog<({bool clear, int quantity})>(
    context: context,
    builder: (context) {
      final l10n = L10n.of(context);
      return AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.sdRestockQtyHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          if (initial != null)
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, (clear: true, quantity: 0)),
              child: Text(l10n.sdRestockQtyClear),
            ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value == null) return;
              Navigator.pop(context, (
                clear: false,
                quantity: value < 0 ? 0 : value,
              ));
            },
            child: Text(l10n.save),
          ),
        ],
      );
    },
  );
}

Future<int?> _askNumber(
  BuildContext context, {
  required String title,
  required int initial,
  String? suffix,
}) {
  final controller = TextEditingController(text: '$initial');
  return showDialog<int>(
    context: context,
    builder: (context) {
      final l10n = L10n.of(context);
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            suffixText: suffix,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(controller.text)),
            child: Text(l10n.save),
          ),
        ],
      );
    },
  );
}

/// Kutuphaneden esya/buyulu esya secici.
class _ItemPicker extends ConsumerStatefulWidget {
  const _ItemPicker();

  @override
  ConsumerState<_ItemPicker> createState() => _ItemPickerState();
}

class _ItemPickerState extends ConsumerState<_ItemPicker> {
  bool _magic = false;

  @override
  Widget build(BuildContext context) {
    final itemQuery = ref.watch(itemQueryProvider);
    final magicQuery = ref.watch(magicItemQueryProvider);
    final l10n = L10n.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SegmentedButton<bool>(
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
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            autofocus: true,
            decoration: InputDecoration(
              hintText: l10n.searchHint,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => _magic
                ? ref
                      .read(magicItemQueryProvider.notifier)
                      .set(magicQuery.copyWith(text: v))
                : ref
                      .read(itemQueryProvider.notifier)
                      .set(itemQuery.copyWith(text: v)),
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        Expanded(child: _magic ? const _MagicList() : const _PlainList()),
      ],
    );
  }
}

class _PlainList extends ConsumerWidget {
  const _PlainList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(itemResultsProvider);
    return asyncView(
      context,
      results,
      loading: const AppLoading(),
      onRetry: () => ref.invalidate(itemResultsProvider),
      data: (rows) => ListView.builder(
        itemCount: rows.length,
        itemBuilder: (context, i) {
          final item = rows[i];
          return ListTile(
            dense: true,
            title: Text(item.name),
            subtitle: Text(item.category ?? ''),
            trailing: Text(
              item.costCp == null ? '—' : formatCoins(item.costCp!),
            ),
            onTap: () =>
                Navigator.pop(context, (itemKey: item.key, magicKey: null)),
          );
        },
      ),
    );
  }
}

class _MagicList extends ConsumerWidget {
  const _MagicList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(magicItemResultsProvider);
    return asyncView(
      context,
      results,
      loading: const AppLoading(),
      onRetry: () => ref.invalidate(magicItemResultsProvider),
      data: (rows) => ListView.builder(
        itemCount: rows.length,
        itemBuilder: (context, i) {
          final item = rows[i];
          return ListTile(
            dense: true,
            title: Text(item.name),
            subtitle: Text(item.rarity ?? ''),
            trailing: Text(
              item.costCp == null ? '—' : formatCoins(item.costCp!),
            ),
            onTap: () =>
                Navigator.pop(context, (itemKey: null, magicKey: item.key)),
          );
        },
      ),
    );
  }
}
