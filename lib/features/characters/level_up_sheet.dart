import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ui/async_view.dart';
import '../../app/ui/ui.dart';
import '../../data/character_repository.dart';
import '../../data/content_tr.dart';
import '../../data/db/database.dart';
import '../../domain/models/ability.dart';
import '../../domain/rules/multiclassing.dart';
import '../../domain/search_text.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/game_terms.dart';
import '../compendium/detail_sheets.dart';
import 'character_providers.dart';
import 'subclass_editor_page.dart';

/// Seviye atlama akisi.
///
/// Once hangi sinifta ilerlenecegi secilir (multiclass buradan), sonra
/// kazanilanlar gosterilir ve HP/ASI/alt sinif secimleri alinir. Hicbir sey
/// "Onayla" denene kadar yazilmaz.
class LevelUpSheet extends ConsumerStatefulWidget {
  const LevelUpSheet({required this.characterId, super.key});

  final String characterId;

  @override
  ConsumerState<LevelUpSheet> createState() => _LevelUpSheetState();
}

class _LevelUpSheetState extends ConsumerState<LevelUpSheet> {
  String? _classKey;
  String? _subclassKey;
  int? _hitPointRoll;
  final _increases = <Ability, int>{};

  /// ASI seviyesinde puan yerine feat secildiyse anahtari.
  String? _featKey;
  bool _saving = false;

  /// Alt sinif secme yetenegi ("Ranger Subclass") kutuphanede kendi adiyla
  /// degil, SECILEN alt sinifin tanitim paragrafiyla gosteriliyor (bkz.
  /// `previewLevelUp`); o metnin cevirisi de alt sinif kaydinin `desc` alani.
  /// Kalan yetenekler sinif ya da alt sinif kaydinin `features/` bolumunde.
  String _featureText(
    ContentTr tr,
    LevelUpPreview p,
    ({String key, String name, String description}) f,
  ) {
    final subclassKey = _subclassKey ?? p.currentSubclassKey;
    if (f.key.contains('subclass') && subclassKey != null) {
      return tr.desc(subclassKey, f.description);
    }
    return tr.partAmong(
      [?subclassKey, p.classKey],
      'features',
      f.name,
      f.description,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final levels = ref.watch(classLevelsProvider(widget.characterId));
    final classTr = contentTrOf(context, ref, 'classes');
    final featureNames = contentNamesTrOf(context, ref);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.sheetLevelUp)),
      body: asyncView(
        context,
        levels,
        loading: const AppLoading(),
        onRetry: () => ref.invalidate(classLevelsProvider(widget.characterId)),
        data: (rows) {
          _classKey ??= rows.isEmpty ? null : rows.first.classKey;
          if (_classKey == null) {
            return Center(child: Text(l10n.levelUpNoClass));
          }

          final preview = ref.watch(
            levelUpPreviewProvider((
              characterId: widget.characterId,
              classKey: _classKey!,
              subclassKey: _subclassKey,
            )),
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _ClassPicker(
                characterId: widget.characterId,
                current: _classKey!,
                existing: rows,
                onChanged: (key) => setState(() {
                  _classKey = key;
                  _subclassKey = null;
                  _hitPointRoll = null;
                }),
              ),
              const SizedBox(height: 20),
              preview.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
                data: (p) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${p.className} ${p.newLevel}'
                      '${p.isNewClass ? '  (${l10n.levelUpNewClass})' : ''}',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 20),
                    _HitPointPicker(
                      preview: p,
                      roll: _hitPointRoll,
                      onChanged: (v) => setState(() => _hitPointRoll = v),
                    ),
                    if (p.grantsSubclass) ...[
                      const SizedBox(height: 20),
                      _SubclassPicker(
                        classKey: p.classKey,
                        className: p.className,
                        selected: _subclassKey,
                        onChanged: (v) => setState(() => _subclassKey = v),
                      ),
                    ],
                    if (p.grantsAbilityIncrease) ...[
                      const SizedBox(height: 20),
                      // 2024 kurali: ASI seviyesinde ya iki puan dagitilir
                      // ya da uygun bir feat alinir.
                      SegmentedButton<bool>(
                        segments: [
                          ButtonSegment(
                            value: false,
                            label: Text(l10n.levelUpAbilityOption),
                          ),
                          ButtonSegment(
                            value: true,
                            label: Text(l10n.levelUpFeatOption),
                          ),
                        ],
                        selected: {_featKey != null || _featMode},
                        onSelectionChanged: (v) => setState(() {
                          _featMode = v.first;
                          if (_featMode) {
                            _increases.clear();
                          } else {
                            _featKey = null;
                          }
                        }),
                      ),
                      const SizedBox(height: 12),
                      if (_featMode)
                        _FeatPicker(
                          characterLevel: _totalLevel(rows) + 1,
                          selected: _featKey,
                          onChanged: (key) => setState(() => _featKey = key),
                        )
                      else
                        _AbilityIncreasePicker(
                          increases: _increases,
                          onChanged: (next) => setState(() {
                            _increases
                              ..clear()
                              ..addAll(next);
                          }),
                        ),
                    ],
                    if (p.features.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        l10n.levelUpFeaturesGained,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      // Yetenek metinleri kutuphanedekilerle ayni kayitlardan
                      // geliyor; ayni ceviri katmani burada da uygulaniyor.
                      // Bir yetenek ya sinifin ya da secili alt sinifin
                      // kaydinda duruyor, ikisi de deneniyor.
                      for (final f in p.features)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                featureNames.term('classFeatures', f.name),
                                style: theme.textTheme.titleSmall,
                              ),
                              // Metin artik kirpilmiyor: kazanilan yetenegin
                              // tamami (tablolar dahil) okunabilmeli.
                              if (f.description.isNotEmpty)
                                GameText(_featureText(classTr, p, f)),
                            ],
                          ),
                        ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _saving || !_ready(p) ? null : () => _apply(p),
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_upward),
                      label: Text(l10n.levelUpSaveAs(p.className, p.newLevel)),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Secilen sinifin disindaki seviyeler dahil toplam karakter seviyesi.
  int _totalLevel(List<CharacterClassLevel> rows) =>
      rows.fold(0, (sum, r) => sum + r.level);

  /// ASI seviyesinde feat mi puan mi seciliyor.
  bool _featMode = false;

  /// Zorunlu secimler yapilmadan kaydedilemez.
  bool _ready(LevelUpPreview p) {
    // Multiclass esigi tutmuyorsa bu sinifa seviye atlanamaz.
    final build = ref.read(characterBuildProvider(widget.characterId)).value;
    if (build != null && p.isNewClass) {
      final check = canMulticlassInto(
        target: p.classKey,
        currentClasses: [for (final c in build.classes) c.classKey],
        scores: build.abilities,
      );
      if (!check.allowed) return false;
    }
    if (p.grantsSubclass && _subclassKey == null) return false;
    if (p.grantsAbilityIncrease) {
      // Ya feat secilmis olmali ya da iki puan dagitilmis.
      if (_featMode) return _featKey != null;
      if (_increases.values.fold(0, (a, b) => a + b) != 2) return false;
    }
    return true;
  }

  Future<void> _apply(LevelUpPreview p) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(characterRepositoryProvider)
          .levelUp(
            characterId: widget.characterId,
            classKey: p.classKey,
            hitPointRoll: _hitPointRoll,
            subclassKey: _subclassKey,
            abilityIncreases: Map.of(_increases),
            featKey: _featKey,
          );
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ClassPicker extends ConsumerWidget {
  const _ClassPicker({
    required this.characterId,
    required this.current,
    required this.existing,
    required this.onChanged,
  });

  final String characterId;
  final String current;
  final List<CharacterClassLevel> existing;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final all = ref.watch(classOptionsProvider).value ?? const [];
    final owned = {for (final e in existing) e.classKey: e.level};
    final build = ref.watch(characterBuildProvider(characterId)).value;

    // 2024 kurali: yeni bir sinifa gecmek icin hem mevcut hem yeni sinifin
    // yetenek esigi (13) karsilanmali.
    ({bool allowed, List<Ability> missing}) check(String key) => build == null
        ? (allowed: true, missing: const <Ability>[])
        : canMulticlassInto(
            target: key,
            currentClasses: owned.keys.toList(),
            scores: build.abilities,
          );

    final blocked = current.isEmpty ? null : check(current);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.levelUpWhichClass, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in all)
              ChoiceChip(
                label: Text(
                  owned.containsKey(c.key)
                      ? '${c.name} ${owned[c.key]}'
                      : c.name,
                ),
                selected: current == c.key,
                // Sahip olunanlar once gorunsun diye vurgulaniyor.
                avatar: owned.containsKey(c.key)
                    ? const Icon(Icons.check, size: 16)
                    : (check(c.key).allowed
                          ? null
                          : const Icon(Icons.lock_outline, size: 16)),
                onSelected: (_) => onChanged(c.key),
              ),
          ],
        ),
        if (blocked != null && !blocked.allowed) ...[
          const SizedBox(height: 8),
          Text(
            l10n.levelUpMulticlassBlocked(
              blocked.missing
                  .map((a) => '${l10n.abilityName(a)} 13')
                  .join(', '),
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}

class _HitPointPicker extends StatelessWidget {
  const _HitPointPicker({
    required this.preview,
    required this.roll,
    required this.onChanged,
  });

  final LevelUpPreview preview;
  final int? roll;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.levelUpHitPoints, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          l10n.levelUpHpHint(preview.hitDieSides, preview.averageHitPoints),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: Text(l10n.levelUpFixed(preview.averageHitPoints)),
                selected: roll == null,
                onSelected: (_) => onChanged(null),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                label: Text(
                  roll == null ? l10n.levelUpRoll : l10n.levelUpRolled(roll!),
                ),
                selected: roll != null,
                onSelected: (_) =>
                    onChanged(Random().nextInt(preview.hitDieSides) + 1),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Alt sinif secimi.
///
/// SRD 5.2'de sinif basina yalnizca bir alt sinif var; masada kullanilan
/// digerleri "Kendim ekle" ile giriliyor ve kalici olarak listeye katiliyor.
class _SubclassPicker extends ConsumerWidget {
  const _SubclassPicker({
    required this.classKey,
    required this.className,
    required this.selected,
    required this.onChanged,
  });

  final String classKey;
  final String className;
  final String? selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subclasses = ref.watch(subclassesProvider(classKey));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              L10n.of(context).levelUpSubclass,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () async {
                // Tam editor: seviye seviye yetenek ve sayac girilebiliyor,
                // girilen alt sinif SRD'dekiler gibi davraniyor.
                final key = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (_) => SubclassEditorPage(
                      parentClassKey: classKey,
                      parentClassName: className,
                    ),
                  ),
                );
                if (key != null) onChanged(key);
              },
              icon: const Icon(Icons.add, size: 18),
              label: Text(L10n.of(context).levelUpAddCustom),
            ),
          ],
        ),
        subclasses.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
          data: (rows) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in rows)
                ChoiceChip(
                  label: Text(s.name),
                  selected: selected == s.key,
                  onSelected: (_) => onChanged(s.key),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// ASI: iki puan dagitilir (bir yetenege +2 ya da ikisine +1).
class _AbilityIncreasePicker extends StatelessWidget {
  const _AbilityIncreasePicker({
    required this.increases,
    required this.onChanged,
  });

  final Map<Ability, int> increases;
  final ValueChanged<Map<Ability, int>> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final used = increases.values.fold(0, (a, b) => a + b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.levelUpAbilityIncrease, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          l10n.levelUpAbilityHint(2 - used),
          style: theme.textTheme.bodySmall?.copyWith(
            color: used == 2
                ? theme.colorScheme.primary
                : theme.colorScheme.error,
          ),
        ),
        const SizedBox(height: 8),
        for (final a in Ability.values)
          Row(
            children: [
              SizedBox(width: 48, child: Text(l10n.abilityShort(a))),
              Expanded(
                child: Text(
                  l10n.abilityName(a),
                  style: theme.textTheme.bodySmall,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: (increases[a] ?? 0) > 0
                    ? () {
                        final next = {...increases};
                        final v = (next[a] ?? 0) - 1;
                        if (v <= 0) {
                          next.remove(a);
                        } else {
                          next[a] = v;
                        }
                        onChanged(next);
                      }
                    : null,
              ),
              SizedBox(
                width: 24,
                child: Text(
                  '+${increases[a] ?? 0}',
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: used < 2
                    ? () =>
                          onChanged({...increases, a: (increases[a] ?? 0) + 1})
                    : null,
              ),
            ],
          ),
      ],
    );
  }
}

/// ASI seviyesinde alinabilecek feat'ler.
///
/// 2024 kurallarinda bu seviyelerde YALNIZCA General feat'ler aliniyor;
/// koken (Origin) feat'i gecmisten, Epic Boon 19. seviyeden, Dragonmark/Dark
/// Gift ise kampanyadan geliyor. Seviye onkosulu olanlar da eleniyor.
class _FeatPicker extends ConsumerStatefulWidget {
  const _FeatPicker({
    required this.characterLevel,
    required this.selected,
    required this.onChanged,
  });

  final int characterLevel;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  ConsumerState<_FeatPicker> createState() => _FeatPickerState();
}

class _FeatPickerState extends ConsumerState<_FeatPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final names = contentNamesTrOf(context, ref);
    final glossary = glossaryTrOf(context, ref);
    final feats =
        ref.watch(availableFeatsProvider(widget.characterLevel)).value ??
        const <FeatOption>[];
    // Arama hem Ingilizce hem Turkce ada bakiyor: veri Ingilizce, ekran
    // Turkce. Siralama da GORUNEN ada gore, yoksa liste okuyana rastgele
    // dizilmis gorunuyor.
    String shown(FeatOption f) => names.term('feats', f.name);
    final needle = searchFold(_query);
    final filtered =
        feats
            .where(
              (f) =>
                  needle.isEmpty ||
                  searchFold(shown(f)).contains(needle) ||
                  searchFold(f.name).contains(needle),
            )
            .toList()
          ..sort((a, b) => compareTurkish(shown(a), shown(b)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          decoration: InputDecoration(
            labelText: l10n.levelUpFeatSearch,
            prefixIcon: const Icon(Icons.search),
            isDense: true,
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final f in filtered)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  // Tek secim: kutucuk yerine acik/kapali daire, secilene
                  // dokunmak feat'i degistirir.
                  leading: IconButton(
                    icon: Icon(
                      widget.selected == f.key
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: widget.selected == f.key
                          ? theme.colorScheme.primary
                          : null,
                    ),
                    onPressed: () => widget.onChanged(f.key),
                  ),
                  title: Text(names.term('feats', f.name)),
                  subtitle: f.prerequisite.isEmpty
                      ? null
                      : Text(
                          glossary.term('featPrerequisites', f.prerequisite),
                          style: theme.textTheme.labelSmall,
                        ),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FeatRuleText(
                        featKey: f.key,
                        fallback: f.description,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
