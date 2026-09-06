/// Karakter kagidinin ESYA yuzeyi: kusanilan yuvalar, envanter listesi,
/// esya ekleme paneli ve kese.
///
/// `character_sheet_page.dart`in bir parcasi; bkz. `character_sheet_vitals`.
part of 'character_sheet_page.dart';

// --- Ekipman / Envanter ---------------------------------------------------

/// Yuvanin ekranda gorunen adi.
String slotLabel(L10n l10n, EquipSlot slot) => switch (slot) {
  EquipSlot.head => l10n.sheetSlotHead,
  EquipSlot.armor => l10n.sheetSlotArmor,
  EquipSlot.cloak => l10n.sheetSlotCloak,
  EquipSlot.gloves => l10n.sheetSlotGloves,
  EquipSlot.boots => l10n.sheetSlotBoots,
  EquipSlot.belt => l10n.sheetSlotBelt,
  EquipSlot.amulet => l10n.sheetSlotAmulet,
  EquipSlot.ring => l10n.sheetSlotRing,
  EquipSlot.mainHand => l10n.sheetSlotMainHand,
  EquipSlot.offHand => l10n.sheetSlotOffHand,
  EquipSlot.other => l10n.sheetSlotOther,
};

/// Kusanma reddedildiginde nedenini soyler.
void _showEquipOutcome(
  BuildContext context,
  EquipOutcome outcome,
  EquipSlot slot,
  SlotCapacities capacities,
) {
  if (outcome != EquipOutcome.slotFull || !context.mounted) return;
  final l10n = L10n.of(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        l10n.sheetSlotFull(slotLabel(l10n, slot), capacities[slot]),
      ),
    ),
  );
}

/// Karakterin esyalari: "Kusanilan" ve "Canta" olarak iki sekme.
///
/// Ayrim masada iki farkli soruya cevap veriyor -- "uzerimde ne var?" ve
/// "cantamda ne var?". Kusanilanlar yuvalara bolunuyor, yuva sinirlari
/// karakter bazinda duzenlenebiliyor.
class _InventoryCard extends ConsumerStatefulWidget {
  const _InventoryCard({required this.characterId});

  final String characterId;

  @override
  ConsumerState<_InventoryCard> createState() => _InventoryCardState();
}

class _InventoryCardState extends ConsumerState<_InventoryCard> {
  int _tab = 0;

  String get characterId => widget.characterId;

  @override
  Widget build(BuildContext context) {
    final items =
        ref.watch(characterItemsProvider(characterId)).value ?? const [];
    final repo = ref.read(characterRepositoryProvider);
    final theme = Theme.of(context);
    final l10n = L10n.of(context);

    final attuned = ref.watch(attunedCountProvider(characterId)).value ?? 0;
    final bag = items.where((i) => !i.equipped).toList();

    return _ListCard(
      title: _tab == 0 ? l10n.sheetGear : l10n.sheetInventory,
      children: [
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: 0, label: Text(l10n.sheetGearTab)),
            ButtonSegment(value: 1, label: Text(l10n.sheetBagTab)),
          ],
          selected: {_tab},
          onSelectionChanged: (s) => setState(() => _tab = s.first),
        ),
        const SizedBox(height: 8),
        // Baglilik sayaci: kural uc esyayla sinirli.
        if (attuned > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              l10n.sheetAttunedCount(attuned, maxAttunedItems),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        if (_tab == 0)
          _EquippedSlots(characterId: characterId, repo: repo)
        else ...[
          if (items.isEmpty)
            Text(l10n.sheetBagEmpty, style: theme.textTheme.bodySmall)
          else if (bag.isEmpty)
            Text(l10n.sheetBagAllEquipped, style: theme.textTheme.bodySmall)
          else
            for (final item in bag)
              _ItemRow(item: item, repo: repo, characterId: characterId),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.sheetAddItem),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _addItem() async {
    final picked = await showModalBottomSheet<_PickedItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _AddItemSheet(),
    );
    if (picked == null) return;
    await ref
        .read(characterRepositoryProvider)
        .addItem(
          characterId: characterId,
          itemKey: picked.itemKey,
          magicItemKey: picked.magicItemKey,
          customName: picked.customName,
          slot: picked.slot,
        );
  }
}

/// "Kusanilan" sekmesi: her yuva bir satir, altinda o yuvadaki esyalar.
class _EquippedSlots extends ConsumerWidget {
  const _EquippedSlots({required this.characterId, required this.repo});

  final String characterId;
  final CharacterRepository repo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final bySlot =
        ref.watch(equippedBySlotProvider(characterId)).value ??
        const <EquipSlot, List<CharacterItem>>{};
    final capacities =
        ref.watch(slotCapacitiesProvider(characterId)).value ??
        const SlotCapacities.defaults();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final slot in kSlotDisplayOrder)
          // "Diger" yuvasi bos oldugunda gizleniyor: varsayilan kagitta yer
          // kaplamasin, ama iceri bir sey konulunca gorunsun.
          if (slot != EquipSlot.other || (bySlot[slot]?.isNotEmpty ?? false))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          slotLabel(l10n, slot),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      // Sinir cipine dokununca duzenlenir: "1 kask" kurali
                      // masaya gore degisebilsin.
                      InputChip(
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          l10n.sheetSlotLimit(
                            capacities.isUnlimited(slot)
                                ? '∞'
                                : '${bySlot[slot]?.length ?? 0}/'
                                      '${capacities[slot]}',
                          ),
                          style: theme.textTheme.labelSmall,
                        ),
                        tooltip: l10n.sheetSlotEditLimit,
                        onPressed: () =>
                            _editLimit(context, ref, slot, capacities),
                      ),
                    ],
                  ),
                  if ((bySlot[slot] ?? const []).isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, top: 2),
                      child: Text(
                        l10n.sheetSlotEmpty,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    )
                  else
                    for (final item in bySlot[slot]!)
                      _ItemRow(
                        item: item,
                        repo: repo,
                        characterId: characterId,
                        showQuantity: false,
                      ),
                ],
              ),
            ),
      ],
    );
  }

  Future<void> _editLimit(
    BuildContext context,
    WidgetRef ref,
    EquipSlot slot,
    SlotCapacities capacities,
  ) async {
    final l10n = L10n.of(context);
    final result = await showDialog<({bool reset, int value})>(
      context: context,
      builder: (context) => _SlotLimitDialog(
        slot: slot,
        current: capacities[slot],
        title: l10n.sheetSlotLimitTitle(slotLabel(l10n, slot)),
      ),
    );
    if (result == null) return;
    await ref
        .read(characterRepositoryProvider)
        .setSlotCapacity(characterId, slot, result.reset ? null : result.value);
    ref.invalidate(slotCapacitiesProvider(characterId));
  }
}

/// Yuva sinirini duzenleyen kucuk pencere.
class _SlotLimitDialog extends StatefulWidget {
  const _SlotLimitDialog({
    required this.slot,
    required this.current,
    required this.title,
  });

  final EquipSlot slot;
  final int current;
  final String title;

  @override
  State<_SlotLimitDialog> createState() => _SlotLimitDialogState();
}

class _SlotLimitDialogState extends State<_SlotLimitDialog> {
  late int _value = widget.current;

  bool get _unlimited => _value <= unlimitedSlotCapacity;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.sheetSlotLimitHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                // 0'in altina inmek "sinirsiz" demek; ayri bir anahtar
                // koymak yerine ayni sayacin ucu kullaniliyor.
                onPressed: _unlimited
                    ? null
                    : () => setState(
                        () => _value = _value <= 0
                            ? unlimitedSlotCapacity
                            : _value - 1,
                      ),
              ),
              SizedBox(
                width: 96,
                child: Text(
                  _unlimited ? l10n.sheetSlotUnlimited : '$_value',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () =>
                    setState(() => _value = _unlimited ? 0 : _value + 1),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, (reset: true, value: _value)),
          child: Text(l10n.sheetSlotDefault),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, (reset: false, value: _value)),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

class _ItemRow extends ConsumerWidget {
  const _ItemRow({
    required this.item,
    required this.repo,
    required this.characterId,
    this.showQuantity = true,
  });

  final CharacterItem item;
  final CharacterRepository repo;
  final String characterId;

  /// Kusanilan esyalarda adet sayaci gizleniyor: yuvada duran tek bir parca.
  final bool showQuantity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final resolved = ref.watch(itemNameProvider(item)).value ?? '…';
    final name = resolved.isEmpty
        ? l10n.sheetUnknownItem
        : itemNameTr(contentNamesTrOf(context, ref), resolved);
    final slot = ref.watch(itemSlotProvider(item)).value ?? EquipSlot.other;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: item.equipped ? l10n.sheetUnequip : l10n.sheetEquip,
            icon: Icon(
              item.equipped ? Icons.check_circle : Icons.circle_outlined,
              size: 18,
              color: item.equipped ? theme.colorScheme.primary : null,
            ),
            onPressed: () => _toggleEquipped(context, ref, slot),
          ),
          Expanded(child: Text(name, style: theme.textTheme.bodyMedium)),
          // Cantada esyanin hangi yuvaya gidecegi onceden gorunsun; ayni
          // menuden baska bir yuvaya da tasinabilir.
          if (slot != EquipSlot.other || item.equipped)
            PopupMenuButton<EquipSlot>(
              tooltip: l10n.sheetSlotChange,
              itemBuilder: (context) => [
                for (final option in kSlotDisplayOrder)
                  CheckedPopupMenuItem(
                    value: option,
                    checked: option == slot,
                    child: Text(slotLabel(l10n, option)),
                  ),
              ],
              onSelected: (option) => _moveSlot(context, ref, option),
              child: Chip(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                label: Text(
                  slotLabel(l10n, slot),
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ),
          // Baglilik yalnizca gerektiren buyulu esyalarda gorunur; sinir
          // dolmussa dokunulunca uyari verilir.
          if (ref.watch(itemNeedsAttunementProvider(item)).value ?? false)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: l10n.sheetAttune,
              icon: Icon(
                item.attuned ? Icons.link : Icons.link_off,
                size: 18,
                color: item.attuned ? theme.colorScheme.primary : null,
              ),
              onPressed: () async {
                final ok = await repo.setAttuned(item.id, !item.attuned);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        L10n.of(context).sheetAttunementFull(maxAttunedItems),
                      ),
                    ),
                  );
                }
              },
            ),
          if (showQuantity) ...[
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.remove, size: 18),
              onPressed: () => repo.setItemQuantity(item.id, item.quantity - 1),
            ),
            Text('${item.quantity}', style: theme.textTheme.titleSmall),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.add, size: 18),
              onPressed: () => repo.setItemQuantity(item.id, item.quantity + 1),
            ),
          ] else if (item.quantity > 1)
            Text('x${item.quantity}', style: theme.textTheme.labelSmall),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: () => repo.removeItem(item.id),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleEquipped(
    BuildContext context,
    WidgetRef ref,
    EquipSlot slot,
  ) async {
    final outcome = await repo.setEquipped(item.id, !item.equipped);
    if (!context.mounted) return;
    _afterSlotWrite(context, ref, outcome, slot);
  }

  Future<void> _moveSlot(
    BuildContext context,
    WidgetRef ref,
    EquipSlot slot,
  ) async {
    final outcome = await repo.setItemSlot(item.id, slot);
    if (!context.mounted) return;
    _afterSlotWrite(context, ref, outcome, slot);
  }

  void _afterSlotWrite(
    BuildContext context,
    WidgetRef ref,
    EquipOutcome outcome,
    EquipSlot slot,
  ) {
    final capacities =
        ref.read(slotCapacitiesProvider(characterId)).value ??
        const SlotCapacities.defaults();
    ref.invalidate(itemSlotProvider(item));
    ref.invalidate(equippedBySlotProvider(characterId));
    _showEquipOutcome(context, outcome, slot, capacities);
  }
}

/// Eklenecek esyanin secimi.
class _PickedItem {
  const _PickedItem({
    this.itemKey,
    this.magicItemKey,
    this.customName,
    this.slot,
  });

  final String? itemKey;
  final String? magicItemKey;
  final String? customName;

  /// Elle secilen tur; null ise esyadan tahmin edilir.
  final EquipSlot? slot;
}

/// Kutuphaneden esya/buyulu esya arayip ekler, ya da serbest bir satir yazar.
class _AddItemSheet extends ConsumerStatefulWidget {
  const _AddItemSheet();

  @override
  ConsumerState<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends ConsumerState<_AddItemSheet> {
  int _tab = 0; // 0 esya, 1 buyulu esya, 2 serbest
  final _customName = TextEditingController();

  /// Serbest esyanin secilen turu; null ise addan tahmin edilir.
  EquipSlot? _customSlot;

  @override
  void dispose() {
    _customName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemQuery = ref.watch(itemQueryProvider);
    final magicQuery = ref.watch(magicItemQueryProvider);
    final l10n = L10n.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 0, label: Text(l10n.sheetItemTab)),
                ButtonSegment(value: 1, label: Text(l10n.sheetMagicTab)),
                ButtonSegment(value: 2, label: Text(l10n.sheetCustomTab)),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
          ),
          if (_tab == 2)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _customName,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: l10n.sheetItemName,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    // Serbest esyanin turu: bos birakilirsa addan tahmin
                    // edilir, secilirse tahmin hic denenmez.
                    DropdownButtonFormField<EquipSlot?>(
                      initialValue: _customSlot,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l10n.sheetItemType,
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text(l10n.sheetItemTypeAuto),
                        ),
                        for (final slot in kSlotDisplayOrder)
                          DropdownMenuItem(
                            value: slot,
                            child: Text(slotLabel(l10n, slot)),
                          ),
                      ],
                      onChanged: (v) => setState(() => _customSlot = v),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _customName.text.trim().isEmpty
                          ? null
                          : () => Navigator.pop(
                              context,
                              _PickedItem(
                                customName: _customName.text.trim(),
                                slot: _customSlot,
                              ),
                            ),
                      child: Text(l10n.add),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: l10n.searchHint,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => _tab == 0
                    ? ref
                          .read(itemQueryProvider.notifier)
                          .set(itemQuery.copyWith(text: v))
                    : ref
                          .read(magicItemQueryProvider.notifier)
                          .set(magicQuery.copyWith(text: v)),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _tab == 0
                  ? _ItemResults(scrollController: scrollController)
                  : _MagicResults(scrollController: scrollController),
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemResults extends ConsumerWidget {
  const _ItemResults({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(itemResultsProvider);
    final glossary = glossaryTrOf(context, ref);
    final names = contentNamesTrOf(context, ref);
    // Metin aramasi SQL'de degil burada: ad ekranda Turkce (bkz.
    // `itemResultsProvider`).
    final visible = results.whenData(
      (rows) => filterByShownName(
        rows,
        ref.watch(itemQueryProvider).text,
        shown: (i) => itemNameTr(names, i.name),
        original: (i) => i.name,
      ),
    );
    return asyncView(
      context,
      visible,
      loading: const AppLoading(),
      onRetry: () => ref.invalidate(itemResultsProvider),
      data: (rows) => ListView.builder(
        controller: scrollController,
        itemCount: rows.length,
        itemBuilder: (context, i) => ListTile(
          dense: true,
          title: Text(itemNameTr(names, rows[i].name)),
          subtitle: Text(
            glossary.term('itemCategories', rows[i].category ?? ''),
          ),
          onTap: () =>
              Navigator.pop(context, _PickedItem(itemKey: rows[i].key)),
        ),
      ),
    );
  }
}

class _MagicResults extends ConsumerWidget {
  const _MagicResults({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(magicItemResultsProvider);
    final glossary = glossaryTrOf(context, ref);
    final names = contentNamesTrOf(context, ref);
    final visible = results.whenData(
      (rows) => filterByShownName(
        rows,
        ref.watch(magicItemQueryProvider).text,
        shown: (i) => itemNameTr(names, i.name),
        original: (i) => i.name,
        sortKey: (a, b) => (a.rarityRank ?? 99).compareTo(b.rarityRank ?? 99),
      ),
    );
    return asyncView(
      context,
      visible,
      loading: const AppLoading(),
      onRetry: () => ref.invalidate(magicItemResultsProvider),
      data: (rows) => ListView.builder(
        controller: scrollController,
        itemCount: rows.length,
        itemBuilder: (context, i) => ListTile(
          dense: true,
          title: Text(itemNameTr(names, rows[i].name)),
          subtitle: Text(glossary.term('itemRarities', rows[i].rarity ?? '')),
          onTap: () =>
              Navigator.pop(context, _PickedItem(magicItemKey: rows[i].key)),
        ),
      ),
    );
  }
}

// --- Kese -----------------------------------------------------------------

/// Kese: her para birimi (pp/gp/sp/cp) icin ayri mini alan. Toplam bakir
/// olarak saklanir (1 pp = 1000, 1 gp = 100, 1 sp = 10 cp).
class _PurseCard extends ConsumerStatefulWidget {
  const _PurseCard({required this.character});

  final Character character;

  @override
  ConsumerState<_PurseCard> createState() => _PurseCardState();
}

class _PurseCardState extends ConsumerState<_PurseCard> {
  late final _pp = TextEditingController();
  late final _gp = TextEditingController();
  late final _sp = TextEditingController();
  late final _cp = TextEditingController();
  bool _dirty = false;

  static const _units = [1000, 100, 10, 1];

  @override
  void initState() {
    super.initState();
    _fill(widget.character.coinsCp);
  }

  @override
  void didUpdateWidget(_PurseCard old) {
    super.didUpdateWidget(old);
    // Disaridan (satin alma, DM) degistiyse ve kullanici duzenlemiyorsa yansit.
    if (!_dirty && widget.character.coinsCp != old.character.coinsCp) {
      _fill(widget.character.coinsCp);
    }
  }

  void _fill(int cp) {
    var rest = cp;
    final controllers = [_pp, _gp, _sp, _cp];
    for (var i = 0; i < _units.length; i++) {
      controllers[i].text = '${rest ~/ _units[i]}';
      rest %= _units[i];
    }
  }

  int _valueOf(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  Future<void> _save() async {
    final total =
        _valueOf(_pp) * 1000 +
        _valueOf(_gp) * 100 +
        _valueOf(_sp) * 10 +
        _valueOf(_cp);
    await ref
        .read(characterRepositoryProvider)
        .setCoins(widget.character.id, total);
    if (mounted) setState(() => _dirty = false);
  }

  @override
  void dispose() {
    for (final c in [_pp, _gp, _sp, _cp]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _coinField(TextEditingController controller, String label) => Expanded(
    child: TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      onChanged: (_) {
        if (!_dirty) setState(() => _dirty = true);
      },
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => _ListCard(
    title: L10n.of(context).sheetPurse,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _coinField(_pp, 'pp'),
          const SizedBox(width: 6),
          _coinField(_gp, 'gp'),
          const SizedBox(width: 6),
          _coinField(_sp, 'sp'),
          const SizedBox(width: 6),
          _coinField(_cp, 'cp'),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: L10n.of(context).save,
            onPressed: _dirty ? _save : null,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
    ],
  );
}
