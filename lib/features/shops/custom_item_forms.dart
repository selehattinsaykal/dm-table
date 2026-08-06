import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../compendium/compendium_providers.dart';
import 'shop_providers.dart';

/// Kutuphaneye kalici bir esya ekler.
Future<String?> showCustomItemForm(BuildContext context, WidgetRef ref) =>
    showDialog<String>(
      context: context,
      builder: (context) => const _ItemForm(),
    );

class _ItemForm extends ConsumerStatefulWidget {
  const _ItemForm();

  @override
  ConsumerState<_ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends ConsumerState<_ItemForm> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  int _costGp = 1;
  double _weight = 0;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return AlertDialog(
      title: Text(l10n.compendiumCreateItem),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _name,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.formName,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: '$_costGp',
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.compendiumPrice,
                        suffixText: 'gp',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (v) => _costGp = int.tryParse(v) ?? 0,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: '$_weight',
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.compendiumWeight,
                        suffixText: 'lb',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (v) => _weight = double.tryParse(v) ?? 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _desc,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: l10n.formDescription,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _name.text.trim().isEmpty ? null : _save,
          child: Text(l10n.save),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final key = await ref
        .read(customContentProvider)
        .addItem(
          name: _name.text.trim(),
          costGp: _costGp,
          weightLb: _weight,
          description: _desc.text.trim(),
        );
    // Kutuphane listesi taze kalsin.
    ref.invalidate(itemResultsProvider);
    if (mounted) Navigator.pop(context, key);
  }
}

/// Kutuphaneye kalici bir buyulu esya ekler.
Future<String?> showCustomMagicItemForm(BuildContext context, WidgetRef ref) =>
    showDialog<String>(
      context: context,
      builder: (context) => const _MagicItemForm(),
    );

class _MagicItemForm extends ConsumerStatefulWidget {
  const _MagicItemForm();

  @override
  ConsumerState<_MagicItemForm> createState() => _MagicItemFormState();
}

class _MagicItemFormState extends ConsumerState<_MagicItemForm> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  String _rarity = 'uncommon';
  bool _attunement = false;

  /// Bos birakilirsa nadirlikten onerilen fiyat kullanilir.
  int? _costGp;

  static const _rarities = <String, String>{
    'common': 'Common',
    'uncommon': 'Uncommon',
    'rare': 'Rare',
    'very-rare': 'Very Rare',
    'legendary': 'Legendary',
    'artifact': 'Artifact',
  };

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return AlertDialog(
      title: Text(l10n.compendiumCreateMagicItem),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _name,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.formName,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _rarity,
                decoration: InputDecoration(
                  labelText: l10n.filterRarity,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final e in _rarities.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setState(() => _rarity = v ?? 'uncommon'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.ciMagicPrice,
                  suffixText: 'gp',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => _costGp = int.tryParse(v),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.ciAttunement),
                value: _attunement,
                onChanged: (v) => setState(() => _attunement = v),
              ),
              TextField(
                controller: _desc,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: l10n.formDescription,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _name.text.trim().isEmpty ? null : _save,
          child: Text(l10n.save),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final key = await ref
        .read(customContentProvider)
        .addMagicItem(
          name: _name.text.trim(),
          rarityKey: _rarity,
          costGp: _costGp,
          requiresAttunement: _attunement,
          description: _desc.text.trim(),
        );
    ref.invalidate(magicItemResultsProvider);
    if (mounted) Navigator.pop(context, key);
  }
}

/// Yalnizca bu magazaya ait, kutuphaneye yazilmayan serbest satir.
///
/// DM masada bir sey uydurdugunda kutuphaneyi kirletmeden ekleyebilsin diye.
typedef FreeStockLine = ({
  String name,
  String description,
  int priceGp,
  int quantity,
});

Future<FreeStockLine?> showFreeStockForm(BuildContext context) {
  final name = TextEditingController();
  final desc = TextEditingController();
  var priceGp = 1;
  var quantity = 1;

  return showDialog<FreeStockLine>(
    context: context,
    builder: (context) {
      final l10n = L10n.of(context);
      return AlertDialog(
        title: Text(l10n.ciFreeStock),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.ciFreeStockHint),
                const SizedBox(height: 12),
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l10n.formName,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: '$priceGp',
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: l10n.compendiumPrice,
                          suffixText: 'gp',
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (v) => priceGp = int.tryParse(v) ?? 0,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        initialValue: '$quantity',
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: l10n.ciQuantity,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (v) => quantity = int.tryParse(v) ?? 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: desc,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.formDescription,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              Navigator.pop(context, (
                name: name.text.trim(),
                description: desc.text.trim(),
                priceGp: priceGp,
                quantity: quantity,
              ));
            },
            child: Text(l10n.add),
          ),
        ],
      );
    },
  );
}
