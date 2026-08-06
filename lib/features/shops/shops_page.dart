import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ui/async_view.dart';
import '../../app/ui/ui.dart';
import '../../l10n/app_localizations.dart';
import 'shop_detail_page.dart';
import 'shop_owner_field.dart';
import 'shop_providers.dart';

/// Magaza listesi.
///
/// Oyunculara acik olan magaza listede vurgulanir; ayni anda yalnizca biri
/// acik olabilir, cunku masada oyuncular "hangi dukkandayiz" diye sormasin.
class ShopsPage extends ConsumerWidget {
  const ShopsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final shops = ref.watch(shopsProvider);
    final repo = ref.read(shopRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navShops)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add_business),
        label: Text(l10n.shopsNew),
      ),
      body: asyncView(
        context,
        shops,
        loading: const SkeletonList(),
        onRetry: () => ref.invalidate(shopsProvider),
        data: (rows) => rows.isEmpty
            ? const _Empty()
            : ListView.separated(
                padding: const EdgeInsets.only(bottom: 88),
                itemCount: rows.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final shop = rows[i];
                  return ListTile(
                    leading: Icon(
                      shop.openToPlayers
                          ? Icons.storefront
                          : Icons.storefront_outlined,
                      color: shop.openToPlayers
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    title: Text(shop.name),
                    subtitle: Text(
                      [
                        if (shop.ownerName != null &&
                            shop.ownerName!.isNotEmpty)
                          shop.ownerName!,
                        if (shop.openToPlayers)
                          l10n.shopsOpen
                        else
                          l10n.shopsClosed,
                        if ((shop.priceMultiplier - 1).abs() > 0.001)
                          'fiyat ×${shop.priceMultiplier.toStringAsFixed(2)}',
                      ].join(' · '),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => repo.delete(shop.id),
                    ),
                    onTap: () =>
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute(
                            builder: (_) => ShopDetailPage(shopId: shop.id),
                          ),
                        ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    var owner = noShopOwner;

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = L10n.of(context);
        return AlertDialog(
          title: Text(l10n.shopsNew),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l10n.shopsName,
                    hintText: l10n.shopsNameHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                ShopOwnerField(onChanged: (v) => owner = v),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.create),
            ),
          ],
        );
      },
    );

    if (created != true || nameController.text.trim().isEmpty) return;
    if (!context.mounted) return;

    final id = await ref
        .read(shopRepositoryProvider)
        .create(
          name: nameController.text.trim(),
          ownerName: owner.name,
          ownerNpcId: owner.npcId,
        );
    if (!context.mounted) return;
    await Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute(builder: (_) => ShopDetailPage(shopId: id)));
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
              Icons.storefront_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(l10n.shopsEmpty, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              l10n.shopsEmptyHint,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
