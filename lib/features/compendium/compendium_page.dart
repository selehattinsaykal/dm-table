import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../app/ui/async_view.dart';
import '../../app/ui/ui.dart';
import '../../data/providers.dart';
import '../../domain/rules/challenge_rating.dart';
import '../../domain/rules/magic_item_pricing.dart';
import '../../l10n/app_localizations.dart';
import '../shops/custom_item_forms.dart';
import '../world/pick_image_file.dart';
import 'compendium_providers.dart';
import 'conditions_tab.dart';
import 'custom_spell_form.dart';
import 'detail_sheets.dart';
import 'monster_creator_page.dart';

class CompendiumPage extends StatelessWidget {
  const CompendiumPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return DefaultTabController(
      length: 8,
      child: Scaffold(
        // Her sekmenin kendi "ekle" butonu: canavar / buyu / esya / buyulu esya.
        floatingActionButton: Consumer(
          builder: (context, ref, _) {
            final controller = DefaultTabController.of(context);
            return AnimatedBuilder(
              animation: controller,
              builder: (context, _) =>
                  _addButton(context, ref, controller.index) ??
                  const SizedBox.shrink(),
            );
          },
        ),
        appBar: AppBar(
          title: Text(l10n.navCompendium),
          actions: [
            // Yalnizca canavar sekmesinde: toplu portre ice aktarma.
            Consumer(
              builder: (context, ref, _) {
                final controller = DefaultTabController.of(context);
                return AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) => controller.index == 0
                      ? IconButton(
                          tooltip: l10n.compendiumImportImages,
                          icon: const Icon(Icons.photo_library_outlined),
                          onPressed: () => _importMonsterImages(context, ref),
                        )
                      : const SizedBox.shrink(),
                );
              },
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: l10n.compendiumMonsters),
              Tab(text: l10n.compendiumSpells),
              Tab(text: l10n.compendiumItems),
              Tab(text: l10n.compendiumMagicItems),
              Tab(text: l10n.compendiumFeats),
              Tab(text: l10n.compendiumSpecies),
              Tab(text: l10n.compendiumBackgrounds),
              Tab(text: l10n.compendiumConditions),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _MonsterTab(),
            _SpellTab(),
            _ItemTab(),
            _MagicItemTab(),
            _FeatTab(),
            _SpeciesTab(),
            _BackgroundTab(),
            ConditionsTab(),
          ],
        ),
      ),
    );
  }

  /// Aktif sekmeye gore "ekle" butonu; feat/ırk/geçmiş sekmelerinde yok.
  FloatingActionButton? _addButton(
    BuildContext context,
    WidgetRef ref,
    int index,
  ) {
    final l10n = L10n.of(context);
    // Yeni sekmelerde homebrew ekleme buradan degil.
    if (index > 3) {
      return null;
    }
    final (String label, VoidCallback onPressed) = switch (index) {
      0 => (
        l10n.compendiumCreateMonster,
        () => Navigator.of(
          context,
          rootNavigator: true,
        ).push(MaterialPageRoute(builder: (_) => const MonsterCreatorPage())),
      ),
      1 => (
        l10n.compendiumCreateSpell,
        () => showCustomSpellForm(context, ref),
      ),
      2 => (l10n.compendiumCreateItem, () => showCustomItemForm(context, ref)),
      _ => (
        l10n.compendiumCreateMagicItem,
        () => showCustomMagicItemForm(context, ref),
      ),
    };
    return FloatingActionButton.extended(
      onPressed: onPressed,
      icon: const Icon(Icons.add),
      label: Text(label),
    );
  }

  /// Bir klasordeki gorselleri ADIYLA canavarlara eslestirip toplu portre atar.
  /// Kullanicinin kendi gorselleri; dosya adi canavar adiyla eslesmeli.
  Future<void> _importMonsterImages(BuildContext context, WidgetRef ref) async {
    final l10n = L10n.of(context);

    // Once adlandirma kuralini hatirlat, sonra klasor sec.
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.compendiumImportImages),
        content: Text(l10n.compendiumImportHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.compendiumChooseFolder),
          ),
        ],
      ),
    );
    if (proceed != true || !context.mounted) return;

    final dir = await pickDirectoryPath();
    if (dir == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    const exts = {'.png', '.jpg', '.jpeg', '.webp'};
    final files = Directory(dir)
        .listSync()
        .whereType<File>()
        .where((f) => exts.contains(p.extension(f.path).toLowerCase()))
        .toList();
    if (files.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.compendiumNoImagesFound)),
      );
      return;
    }

    final result = await ref
        .read(compendiumRepositoryProvider)
        .importMonsterPortraits(files);
    ref.invalidate(monsterResultsProvider);
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          l10n.compendiumImportResult(result.assigned, result.unmatched.length),
        ),
      ),
    );
  }
}

// --- Canavarlar ---------------------------------------------------------

class _MonsterTab extends ConsumerWidget {
  const _MonsterTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final query = ref.watch(monsterQueryProvider);
    final results = ref.watch(monsterResultsProvider);
    final types = ref.watch(creatureTypesProvider).value ?? const [];
    final notifier = ref.read(monsterQueryProvider.notifier);

    return _TabScaffold(
      searchText: query.text,
      onSearch: (v) => notifier.set(query.copyWith(text: v)),
      hasFilters: query.hasFilters,
      onClearFilters: () => notifier.set(MonsterQuery(text: query.text)),
      filters: [
        _CrRangeChip(
          min: query.minCr,
          max: query.maxCr,
          onChanged: (min, max) =>
              notifier.set(query.copyWith(minCr: () => min, maxCr: () => max)),
        ),
        for (final t in types)
          FilterChip(
            label: Text(t),
            selected: query.types.contains(t),
            onSelected: (on) => notifier.set(
              query.copyWith(types: <String>{...query.types}..toggle(t, on)),
            ),
          ),
      ],
      results: results,
      itemBuilder: (context, m) => ListTile(
        title: Text(m.name),
        subtitle: Text([m.size, m.creatureType].whereType<String>().join(' ')),
        trailing: _CrBadge(cr: m.challengeRating),
        onTap: () => showDetailSheet(context, MonsterDetail(monster: m)),
      ),
      l10n: l10n,
    );
  }
}

class _CrBadge extends StatelessWidget {
  const _CrBadge({required this.cr});

  final double cr;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('CR ${formatCr(cr)}', style: theme.textTheme.labelMedium),
    );
  }
}

/// CR araligi secici. Masada "3-7 arasi bir sey lazim" en sik ihtiyac
/// oldugu icin tek bir cipin arkasina alindi.
class _CrRangeChip extends StatelessWidget {
  const _CrRangeChip({
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final double? min;
  final double? max;
  final void Function(double? min, double? max) onChanged;

  @override
  Widget build(BuildContext context) {
    final active = min != null || max != null;
    return FilterChip(
      label: Text(
        active
            ? 'CR ${min == null ? '0' : formatCr(min!)}'
                  '–${max == null ? '30' : formatCr(max!)}'
            : 'CR',
      ),
      selected: active,
      avatar: const Icon(Icons.tune, size: 18),
      onSelected: (_) async {
        final range = await showDialog<(double?, double?)>(
          context: context,
          builder: (context) => _CrRangeDialog(min: min, max: max),
        );
        if (range != null) onChanged(range.$1, range.$2);
      },
    );
  }
}

class _CrRangeDialog extends StatefulWidget {
  const _CrRangeDialog({required this.min, required this.max});

  final double? min;
  final double? max;

  @override
  State<_CrRangeDialog> createState() => _CrRangeDialogState();
}

class _CrRangeDialogState extends State<_CrRangeDialog> {
  late RangeValues _values = RangeValues(
    _indexOf(widget.min ?? crSteps.first).toDouble(),
    _indexOf(widget.max ?? crSteps.last).toDouble(),
  );

  static int _indexOf(double cr) {
    final i = crSteps.indexOf(cr);
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final lo = crSteps[_values.start.round()];
    final hi = crSteps[_values.end.round()];
    return AlertDialog(
      title: Text(L10n.of(context).compendiumCrRange),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('CR ${formatCr(lo)} – ${formatCr(hi)}'),
          RangeSlider(
            values: _values,
            max: (crSteps.length - 1).toDouble(),
            divisions: crSteps.length - 1,
            labels: RangeLabels(formatCr(lo), formatCr(hi)),
            onChanged: (v) => setState(() => _values = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, (null, null)),
          child: Text(L10n.of(context).clearFilters),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (lo, hi)),
          child: Text(L10n.of(context).save),
        ),
      ],
    );
  }
}

// --- Buyuler ------------------------------------------------------------

class _SpellTab extends ConsumerWidget {
  const _SpellTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final query = ref.watch(spellQueryProvider);
    final results = ref.watch(spellResultsProvider);

    final update = ref.read(spellQueryProvider.notifier).set;

    return _TabScaffold(
      searchText: query.text,
      onSearch: (v) => update(query.copyWith(text: v)),
      hasFilters: query.hasFilters,
      onClearFilters: () => update(SpellQuery(text: query.text)),
      filters: [
        for (var level = 0; level <= 9; level++)
          FilterChip(
            label: Text(level == 0 ? 'Cantrip' : '$level'),
            selected: query.levels.contains(level),
            onSelected: (on) => update(
              query.copyWith(levels: <int>{...query.levels}..toggle(level, on)),
            ),
          ),
        FilterChip(
          label: const Text('Concentration'),
          selected: query.concentrationOnly,
          onSelected: (on) => update(query.copyWith(concentrationOnly: on)),
        ),
        FilterChip(
          label: const Text('Ritual'),
          selected: query.ritualOnly,
          onSelected: (on) => update(query.copyWith(ritualOnly: on)),
        ),
      ],
      results: results,
      itemBuilder: (context, s) => ListTile(
        title: Text(s.name),
        subtitle: Text(
          [
            s.level == 0 ? 'Cantrip' : 'Level ${s.level}',
            if (s.school != null) s.school!,
            if (s.concentration) 'Conc.',
            if (s.ritual) 'Ritual',
          ].join(' · '),
        ),
        onTap: () => showDetailSheet(context, SpellDetail(spell: s)),
      ),
      l10n: l10n,
    );
  }
}

// --- Esyalar ------------------------------------------------------------

class _ItemTab extends ConsumerWidget {
  const _ItemTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final query = ref.watch(itemQueryProvider);
    final results = ref.watch(itemResultsProvider);
    final categories = ref.watch(itemCategoriesProvider).value ?? const [];
    final update = ref.read(itemQueryProvider.notifier).set;

    return _TabScaffold(
      searchText: query.text,
      onSearch: (v) => update(query.copyWith(text: v)),
      hasFilters: query.hasFilters,
      onClearFilters: () => update(ItemQuery(text: query.text)),
      filters: [
        for (final c in categories)
          FilterChip(
            label: Text(c),
            selected: query.categories.contains(c),
            onSelected: (on) => update(
              query.copyWith(
                categories: <String>{...query.categories}..toggle(c, on),
              ),
            ),
          ),
      ],
      results: results,
      itemBuilder: (context, i) => ListTile(
        title: Text(i.name),
        subtitle: Text(i.category ?? ''),
        trailing: Text(
          i.costCp == null ? '—' : formatCoins(i.costCp!),
          style: Theme.of(context).textTheme.labelMedium,
        ),
        onTap: () => showDetailSheet(context, ItemDetail(item: i)),
      ),
      l10n: l10n,
    );
  }
}

// --- Buyulu esyalar -----------------------------------------------------

class _MagicItemTab extends ConsumerWidget {
  const _MagicItemTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final query = ref.watch(magicItemQueryProvider);
    final results = ref.watch(magicItemResultsProvider);
    final rarities = ref.watch(raritiesProvider).value ?? const [];
    final update = ref.read(magicItemQueryProvider.notifier).set;

    return _TabScaffold(
      searchText: query.text,
      onSearch: (v) => update(query.copyWith(text: v)),
      hasFilters: query.hasFilters,
      onClearFilters: () => update(MagicItemQuery(text: query.text)),
      filters: [
        for (final r in rarities)
          FilterChip(
            label: Text(r),
            selected: query.rarities.contains(r),
            onSelected: (on) => update(
              query.copyWith(
                rarities: <String>{...query.rarities}..toggle(r, on),
              ),
            ),
          ),
        FilterChip(
          label: const Text('Attunement'),
          selected: query.attunementOnly,
          onSelected: (on) => update(query.copyWith(attunementOnly: on)),
        ),
      ],
      results: results,
      itemBuilder: (context, i) => ListTile(
        title: Text(i.name),
        subtitle: Text(
          [
            if (i.rarity != null) i.rarity!,
            if (i.requiresAttunement) 'attunement',
          ].join(' · '),
        ),
        trailing: Text(
          i.costCp == null ? '—' : formatCoins(i.costCp!),
          style: Theme.of(context).textTheme.labelMedium,
        ),
        onTap: () => showDetailSheet(context, MagicItemDetail(item: i)),
      ),
      l10n: l10n,
    );
  }
}

// --- Feat'ler -----------------------------------------------------------

class _FeatTab extends ConsumerWidget {
  const _FeatTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final query = ref.watch(featQueryProvider);
    final results = ref.watch(featResultsProvider);
    final update = ref.read(featQueryProvider.notifier).set;

    return _TabScaffold(
      searchText: query.text,
      onSearch: (v) => update(query.copyWith(text: v)),
      hasFilters: false,
      onClearFilters: () => update(const TextQuery()),
      filters: const [],
      results: results,
      itemBuilder: (context, f) => ListTile(
        title: Text(f.name),
        onTap: () => showDetailSheet(context, FeatDetail(feat: f)),
      ),
      l10n: l10n,
    );
  }
}

// --- Irklar -------------------------------------------------------------

class _SpeciesTab extends ConsumerWidget {
  const _SpeciesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final query = ref.watch(speciesQueryProvider);
    final results = ref.watch(speciesResultsProvider);
    final update = ref.read(speciesQueryProvider.notifier).set;

    return _TabScaffold(
      searchText: query.text,
      onSearch: (v) => update(query.copyWith(text: v)),
      hasFilters: false,
      onClearFilters: () => update(const TextQuery()),
      filters: const [],
      results: results,
      itemBuilder: (context, s) => ListTile(
        title: Text(s.name),
        onTap: () => showDetailSheet(context, SpeciesDetail(species: s)),
      ),
      l10n: l10n,
    );
  }
}

// --- Geçmişler ----------------------------------------------------------

class _BackgroundTab extends ConsumerWidget {
  const _BackgroundTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final query = ref.watch(backgroundQueryProvider);
    final results = ref.watch(backgroundResultsProvider);
    final update = ref.read(backgroundQueryProvider.notifier).set;

    return _TabScaffold(
      searchText: query.text,
      onSearch: (v) => update(query.copyWith(text: v)),
      hasFilters: false,
      onClearFilters: () => update(const TextQuery()),
      filters: const [],
      results: results,
      itemBuilder: (context, b) => ListTile(
        title: Text(b.name),
        onTap: () => showDetailSheet(context, BackgroundDetail(background: b)),
      ),
      l10n: l10n,
    );
  }
}

// --- Ortak iskelet ------------------------------------------------------

/// Dort sekmenin de ayni duzeni: arama alani, filtre cipleri, sonuc listesi.
class _TabScaffold<T> extends StatelessWidget {
  const _TabScaffold({
    required this.searchText,
    required this.onSearch,
    required this.hasFilters,
    required this.onClearFilters,
    required this.filters,
    required this.results,
    required this.itemBuilder,
    required this.l10n,
  });

  final String searchText;
  final ValueChanged<String> onSearch;
  final bool hasFilters;
  final VoidCallback onClearFilters;
  final List<Widget> filters;
  final AsyncValue<List<T>> results;
  final Widget Function(BuildContext, T) itemBuilder;
  final L10n l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: _SearchField(
            text: searchText,
            hint: l10n.searchHint,
            onChanged: onSearch,
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              if (hasFilters)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    avatar: const Icon(Icons.filter_alt_off, size: 18),
                    label: Text(l10n.clearFilters),
                    onPressed: onClearFilters,
                  ),
                ),
              for (final f in filters)
                Padding(padding: const EdgeInsets.only(right: 6), child: f),
            ],
          ),
        ),
        const Divider(height: 12),
        Expanded(
          child: asyncView(
            context,
            results,
            loading: const AppLoading(),
            data: (rows) => rows.isEmpty
                ? Center(child: Text(l10n.noResults))
                : ListView.builder(
                    // Alttaki "Canavar yarat" butonu son satiri ortmesin.
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: rows.length,
                    itemBuilder: (context, i) => itemBuilder(context, rows[i]),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Arama alani.
///
/// Controller'i kendi tutuyor: `build()` icinde controller uretmek her
/// yeniden cizimde yenisini yaratir, eskisini sizdirir ve imleci basa atar.
class _SearchField extends StatefulWidget {
  const _SearchField({
    required this.text,
    required this.hint,
    required this.onChanged,
  });

  final String text;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final _controller = TextEditingController(text: widget.text);

  @override
  void didUpdateWidget(_SearchField old) {
    super.didUpdateWidget(old);
    // Disaridan (or. "filtreleri temizle") degistiyse yansit; kullanicinin
    // kendi yazdigi metni geri yazmamak icin karsilastirma sart.
    if (widget.text != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.text,
        selection: TextSelection.collapsed(offset: widget.text.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    decoration: InputDecoration(
      hintText: widget.hint,
      prefixIcon: const Icon(Icons.search),
      suffixIcon: widget.text.isEmpty
          ? null
          : IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => widget.onChanged(''),
            ),
    ),
    onChanged: widget.onChanged,
  );
}

extension<T> on Set<T> {
  void toggle(T value, bool on) => on ? add(value) : remove(value);
}
