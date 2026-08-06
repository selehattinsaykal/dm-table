import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ui/async_view.dart';
import '../../app/ui/ui.dart';
import '../../data/db/database.dart';
import '../../data/random_table_repository.dart';
import '../../domain/rules/name_generator.dart';
import '../../domain/rules/random_table.dart';
import '../../l10n/app_localizations.dart';
import '../world/world_providers.dart';
import 'table_providers.dart';

/// Rastgele tablolar + isim üreteci.
///
/// Masada anlık ilham aracı: kendi tablolarını kurar, zar atarsın; isim
/// üreteci tamamen offline çalışır (API gerektirmez).
class TablesPage extends ConsumerStatefulWidget {
  const TablesPage({super.key});

  @override
  ConsumerState<TablesPage> createState() => _TablesPageState();
}

class _TablesPageState extends ConsumerState<TablesPage> {
  bool _seeded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    // Ilk acilista hazir tablolari tohumla (ensureDefaultCalendar deseni:
    // adlar/icerik asset'ten, migration dile bagimli olmaz).
    if (!_seeded) {
      _seeded = true;
      loadStarterTables(l10n.localeName).then((starters) {
        if (starters.isEmpty) return;
        ref.read(randomTableRepositoryProvider).ensureStarterTables(starters);
      });
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.navTables),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.tablesTabTables),
              Tab(text: l10n.tablesTabNames),
            ],
          ),
        ),
        body: const TabBarView(children: [_TablesTab(), _NameGeneratorTab()]),
      ),
    );
  }
}

// --- Tablolar ---------------------------------------------------------------

class _TablesTab extends ConsumerWidget {
  const _TablesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final tables = ref.watch(randomTablesProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final id = await ref
              .read(randomTableRepositoryProvider)
              .create(l10n.tablesNew);
          if (!context.mounted) return;
          await Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(builder: (_) => RandomTableEditPage(tableId: id)),
          );
        },
        icon: const Icon(Icons.add),
        label: Text(l10n.tablesNew),
      ),
      body: asyncView(
        context,
        tables,
        loading: const SkeletonList(),
        onRetry: () => ref.invalidate(randomTablesProvider),
        data: (rows) => rows.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(l10n.tablesEmpty, textAlign: TextAlign.center),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.only(bottom: 88),
                itemCount: rows.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) => _TableTile(table: rows[i]),
              ),
      ),
    );
  }
}

class _TableTile extends ConsumerWidget {
  const _TableTile({required this.table});

  final RandomTable table;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final rows = RandomTableRepository.rowsOf(table);
    final issues = validateRows(rows, table.diceSides);

    return ListTile(
      leading: const Icon(Icons.casino_outlined),
      title: Text(table.name),
      subtitle: Text(
        [
          'd${table.diceSides}',
          l10n.tablesRowCount(rows.length),
          if (table.category.isNotEmpty) table.category,
        ].join(' · '),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (issues.isNotEmpty)
            Tooltip(
              message: issues.map((c) => _issueText(l10n, c)).join('\n'),
              child: Icon(
                Icons.warning_amber_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          FilledButton.icon(
            onPressed: rows.isEmpty ? null : () => _roll(context, rows, table),
            icon: const Icon(Icons.casino, size: 18),
            label: Text(l10n.tablesRoll),
          ),
        ],
      ),
      onTap: () => Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => RandomTableEditPage(tableId: table.id),
        ),
      ),
    );
  }
}

String _issueText(L10n l10n, String code) => switch (code) {
  'gap' => l10n.tablesIssueGap,
  'overlap' => l10n.tablesIssueOverlap,
  'outOfRange' => l10n.tablesIssueOutOfRange,
  'emptyRange' => l10n.tablesIssueEmptyRange,
  _ => code,
};

/// Zar atar ve sonucu gosterir.
void _roll(BuildContext context, List<RandomTableRow> rows, RandomTable table) {
  final l10n = L10n.of(context);
  final result = rollOn(rows, table.diceSides);
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.casino),
      title: Text('${table.name} — d${table.diceSides}: ${result.roll}'),
      content: Text(
        result.row?.text ?? l10n.tablesNoRowForRoll,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            _roll(context, rows, table);
          },
          child: Text(l10n.tablesRollAgain),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
      ],
    ),
  );
}

/// Bir tabloyu düzenler: ad, kategori, zar yüzü, satırlar.
class RandomTableEditPage extends ConsumerStatefulWidget {
  const RandomTableEditPage({required this.tableId, super.key});

  final String tableId;

  @override
  ConsumerState<RandomTableEditPage> createState() =>
      _RandomTableEditPageState();
}

class _RandomTableEditPageState extends ConsumerState<RandomTableEditPage> {
  final _name = TextEditingController();
  final _category = TextEditingController();
  final _newRow = TextEditingController();
  final _rows = <RandomTableRow>[];
  int _diceSides = 20;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final table = await ref
        .read(randomTableRepositoryProvider)
        .find(widget.tableId);
    if (table == null || !mounted) return;
    _name.text = table.name;
    _category.text = table.category;
    _diceSides = table.diceSides;
    _rows
      ..clear()
      ..addAll(RandomTableRepository.rowsOf(table));
    setState(() => _loaded = true);
  }

  @override
  void dispose() {
    for (final c in [_name, _category, _newRow]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = L10n.of(context);
    await ref
        .read(randomTableRepositoryProvider)
        .update(
          widget.tableId,
          name: _name.text.trim().isEmpty ? l10n.tablesNew : _name.text.trim(),
          category: _category.text.trim(),
          diceSides: _diceSides,
          rows: _rows,
        );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final l10n = L10n.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.tablesDeleteConfirm(_name.text.trim())),
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
    await ref.read(randomTableRepositoryProvider).delete(widget.tableId);
    if (mounted) Navigator.of(context).pop();
  }

  void _addRow() {
    final text = _newRow.text.trim();
    if (text.isEmpty) return;
    setState(() {
      // Yeni satir son araligin bir ustune; "Aralıkları dağıt" ile
      // duzeltilebilir.
      final next = _rows.isEmpty ? 1 : _rows.last.max + 1;
      _rows.add((min: next, max: next, text: text));
      _newRow.clear();
    });
  }

  void _redistribute() => setState(() {
    final texts = [for (final r in _rows) r.text];
    _rows
      ..clear()
      ..addAll(distributeEvenly(texts, _diceSides));
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    if (!_loaded) return const Scaffold(body: AppLoading());

    final issues = validateRows(_rows, _diceSides);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tablesEditTitle),
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
              labelText: l10n.tablesName,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _category,
            decoration: InputDecoration(
              labelText: l10n.tablesCategory,
              hintText: l10n.tablesCategoryHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),

          Text(l10n.tablesDice, style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final sides in kDiceSides)
                ChoiceChip(
                  label: Text('d$sides'),
                  selected: _diceSides == sides,
                  onSelected: (_) => setState(() => _diceSides = sides),
                ),
            ],
          ),
          const SizedBox(height: 16),

          if (issues.isNotEmpty)
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final code in issues)
                      Text(
                        '• ${_issueText(l10n, code)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      onPressed: _rows.isEmpty ? null : _redistribute,
                      icon: const Icon(Icons.auto_fix_high, size: 18),
                      label: Text(l10n.tablesRedistribute),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(child: SectionHeader(label: l10n.tablesRows)),
              TextButton.icon(
                onPressed: _rows.isEmpty ? null : _redistribute,
                icon: const Icon(Icons.auto_fix_high, size: 18),
                label: Text(l10n.tablesRedistribute),
              ),
            ],
          ),
          for (final (i, row) in _rows.indexed)
            _RowEditor(
              key: ValueKey('$i-${row.text}'),
              row: row,
              maxSides: _diceSides,
              onChanged: (next) => setState(() => _rows[i] = next),
              onDelete: () => setState(() => _rows.removeAt(i)),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newRow,
                  onSubmitted: (_) => _addRow(),
                  decoration: InputDecoration(
                    labelText: l10n.tablesAddRow,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                onPressed: _addRow,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tek satir: min-max araligi + metin.
class _RowEditor extends StatefulWidget {
  const _RowEditor({
    required this.row,
    required this.maxSides,
    required this.onChanged,
    required this.onDelete,
    super.key,
  });

  final RandomTableRow row;
  final int maxSides;
  final ValueChanged<RandomTableRow> onChanged;
  final VoidCallback onDelete;

  @override
  State<_RowEditor> createState() => _RowEditorState();
}

class _RowEditorState extends State<_RowEditor> {
  late final _min = TextEditingController(text: '${widget.row.min}');
  late final _max = TextEditingController(text: '${widget.row.max}');
  late final _text = TextEditingController(text: widget.row.text);

  // Odak kaybinda kaydet (takvim ayarlarindaki `_MonthRow` ile ayni gerekce:
  // `onTapOutside` baska bir TextField'a dogrudan gecisde guvenilmez).
  final _minFocus = FocusNode();
  final _maxFocus = FocusNode();
  final _textFocus = FocusNode();

  void _push() => widget.onChanged((
    min: int.tryParse(_min.text.trim()) ?? widget.row.min,
    max: int.tryParse(_max.text.trim()) ?? widget.row.max,
    text: _text.text.trim(),
  ));

  @override
  void initState() {
    super.initState();
    for (final node in [_minFocus, _maxFocus, _textFocus]) {
      node.addListener(() {
        if (!node.hasFocus) _push();
      });
    }
  }

  @override
  void dispose() {
    for (final c in [_min, _max, _text]) {
      c.dispose();
    }
    for (final n in [_minFocus, _maxFocus, _textFocus]) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 56,
          child: TextField(
            controller: _min,
            focusNode: _minFocus,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onEditingComplete: _push,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Text('–'),
        ),
        SizedBox(
          width: 56,
          child: TextField(
            controller: _max,
            focusNode: _maxFocus,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onEditingComplete: _push,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _text,
            focusNode: _textFocus,
            maxLines: null,
            onEditingComplete: _push,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        IconButton(
          onPressed: widget.onDelete,
          icon: const Icon(Icons.remove_circle_outline),
        ),
      ],
    ),
  );
}

// --- Isim ureteci -----------------------------------------------------------

class _NameGeneratorTab extends ConsumerStatefulWidget {
  const _NameGeneratorTab();

  @override
  ConsumerState<_NameGeneratorTab> createState() => _NameGeneratorTabState();
}

class _NameGeneratorTabState extends ConsumerState<_NameGeneratorTab> {
  NameCategory _category = NameCategory.person;
  NameCulture _culture = NameCulture.human;
  NameGender _gender = NameGender.any;
  bool _surname = false;
  int _count = 10;
  List<String> _names = const [];
  final _rng = Random();

  String _categoryLabel(L10n l10n, NameCategory c) => switch (c) {
    NameCategory.person => l10n.nameCategoryPerson,
    NameCategory.place => l10n.nameCategoryPlace,
    NameCategory.establishment => l10n.nameCategoryEstablishment,
    NameCategory.group => l10n.nameCategoryGroup,
    NameCategory.thing => l10n.nameCategoryThing,
  };

  String _cultureLabel(L10n l10n, NameCulture c) => switch (c) {
    NameCulture.human => l10n.nameCultureHuman,
    NameCulture.humanNorth => l10n.nameCultureHumanNorth,
    NameCulture.humanDesert => l10n.nameCultureHumanDesert,
    NameCulture.humanEast => l10n.nameCultureHumanEast,
    NameCulture.elf => l10n.nameCultureElf,
    NameCulture.drow => l10n.nameCultureDrow,
    NameCulture.dwarf => l10n.nameCultureDwarf,
    NameCulture.halfling => l10n.nameCultureHalfling,
    NameCulture.gnome => l10n.nameCultureGnome,
    NameCulture.orc => l10n.nameCultureOrc,
    NameCulture.goblin => l10n.nameCultureGoblin,
    NameCulture.tiefling => l10n.nameCultureTiefling,
    NameCulture.dragonborn => l10n.nameCultureDragonborn,
    NameCulture.goliath => l10n.nameCultureGoliath,
    NameCulture.lizardfolk => l10n.nameCultureLizardfolk,
    NameCulture.tabaxi => l10n.nameCultureTabaxi,
    NameCulture.celestial => l10n.nameCultureCelestial,
    NameCulture.undead => l10n.nameCultureUndead,
    NameCulture.place => l10n.nameCulturePlace,
    NameCulture.city => l10n.nameCultureCity,
    NameCulture.fortress => l10n.nameCultureFortress,
    NameCulture.ruin => l10n.nameCultureRuin,
    NameCulture.forest => l10n.nameCultureForest,
    NameCulture.mountain => l10n.nameCultureMountain,
    NameCulture.water => l10n.nameCultureWater,
    NameCulture.island => l10n.nameCultureIsland,
    NameCulture.region => l10n.nameCultureRegion,
    NameCulture.tavern => l10n.nameCultureTavern,
    NameCulture.shop => l10n.nameCultureShop,
    NameCulture.temple => l10n.nameCultureTemple,
    NameCulture.guild => l10n.nameCultureGuild,
    NameCulture.nobleHouse => l10n.nameCultureNobleHouse,
    NameCulture.mercenary => l10n.nameCultureMercenary,
    NameCulture.cult => l10n.nameCultureCult,
    NameCulture.ship => l10n.nameCultureShip,
    NameCulture.magicItem => l10n.nameCultureMagicItem,
    NameCulture.tome => l10n.nameCultureTome,
    NameCulture.festival => l10n.nameCultureFestival,
    NameCulture.epithet => l10n.nameCultureEpithet,
  };

  String _genderLabel(L10n l10n, NameGender g) => switch (g) {
    NameGender.any => l10n.nameGenderAny,
    NameGender.male => l10n.nameGenderMale,
    NameGender.female => l10n.nameGenderFemale,
  };

  void _selectCategory(NameCategory category) => setState(() {
    _category = category;
    // Kategori degisince o gruptaki ilk tur secili gelir; eski secim baska
    // sekmede kalirsa "Uret" yanlis isim uretir.
    _culture = NameCulture.values.firstWhere((c) => c.category == category);
  });

  void _generate(L10n l10n) => setState(() {
    _names = generateNames(
      _culture,
      count: _count,
      turkish: l10n.localeName == 'tr',
      gender: _gender,
      surname: _surname,
      rng: _rng,
    );
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.nameGeneratorHint, style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        // Tur sayisi 39'a cikinca duz Wrap okunmaz oldu: once kategori, sonra
        // o kategorinin turleri.
        SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<NameCategory>(
              segments: [
                for (final c in NameCategory.values)
                  ButtonSegment(value: c, label: Text(_categoryLabel(l10n, c))),
              ],
              selected: {_category},
              showSelectedIcon: false,
              onSelectionChanged: (s) => _selectCategory(s.first),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in NameCulture.values.where(
              (c) => c.category == _category,
            ))
              ChoiceChip(
                label: Text(_cultureLabel(l10n, c)),
                selected: _culture == c,
                onSelected: (_) => setState(() => _culture = c),
              ),
          ],
        ),
        if (_culture.hasGender) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Text(l10n.nameGender, style: theme.textTheme.labelLarge),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final g in NameGender.values)
                      ChoiceChip(
                        label: Text(_genderLabel(l10n, g)),
                        selected: _gender == g,
                        onSelected: (_) => setState(() => _gender = g),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
        if (_culture.hasSurname)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(l10n.nameSurname),
            value: _surname,
            onChanged: (v) => setState(() => _surname = v),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(l10n.nameCount, style: theme.textTheme.labelLarge),
            Expanded(
              child: Slider(
                value: _count.toDouble(),
                min: 5,
                max: 30,
                divisions: 25,
                label: '$_count',
                onChanged: (v) => setState(() => _count = v.round()),
              ),
            ),
            Text('$_count'),
          ],
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => _generate(l10n),
          icon: const Icon(Icons.auto_awesome, size: 18),
          label: Text(l10n.nameGenerate),
        ),
        const SizedBox(height: 16),
        for (final name in _names)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              title: Text(name),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: l10n.nameCopy,
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: name));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.nameCopied(name))),
                      );
                    },
                  ),
                  // Kisi adlari NPC'ye, yer adlari dunya agacina kaydedilir;
                  // isletme/topluluk/nesne adlari ikisine de girmez.
                  if (_culture.category == NameCategory.person)
                    IconButton(
                      tooltip: l10n.nameSaveAsNpc,
                      icon: const Icon(Icons.person_add_alt, size: 18),
                      onPressed: () async {
                        await ref
                            .read(worldRepositoryProvider)
                            .createNpc(name: name);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.nameSavedAsNpc(name))),
                        );
                      },
                    ),
                  if (_culture.category == NameCategory.place)
                    IconButton(
                      tooltip: l10n.nameSaveAsLocation,
                      icon: const Icon(
                        Icons.add_location_alt_outlined,
                        size: 18,
                      ),
                      onPressed: () async {
                        await ref
                            .read(worldRepositoryProvider)
                            .createLocation(name: name);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.nameSavedAsLocation(name)),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
