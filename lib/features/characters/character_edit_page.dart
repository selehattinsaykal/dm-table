import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ui/async_view.dart';
import '../../app/ui/ui.dart';
import '../../data/db/database.dart';
import '../../domain/models/ability.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/game_terms.dart';
import 'character_providers.dart';

/// Yaratilmis bir karakterin duzeltilmesi.
///
/// Sihirbaz yalnizca 1. seviyeyi kuruyor; masada "adi yanlis yazmisim",
/// "aslinda Cleric olacakti", "CON'u 14 yapalim" gibi duzeltmeler sonradan
/// geliyordu ve kagitta bunlarin hicbiri degistirilemiyordu.
///
/// Hicbir sey yazilmadan once tum degisiklikler burada birikir; "Kaydet"
/// yalnizca GERCEKTEN degisen alanlarin islemini calistirir. Boylece sayfayi
/// acip kapatmak, ya da yalnizca adi degistirmek, sinif yeteneklerini
/// tazelemek gibi agir bir yan etki yaratmiyor.
class CharacterEditPage extends ConsumerStatefulWidget {
  const CharacterEditPage({required this.characterId, super.key});

  final String characterId;

  @override
  ConsumerState<CharacterEditPage> createState() => _CharacterEditPageState();
}

/// Tek bir sinif satirinin duzenlenebilir hali.
class _ClassRow {
  _ClassRow({
    required this.originalClassKey,
    required this.classKey,
    required this.subclassKey,
    required this.level,
    required this.originalSubclassKey,
    required this.originalLevel,
  });

  final String originalClassKey;
  final String? originalSubclassKey;
  final int originalLevel;

  String classKey;
  String? subclassKey;
  int level;

  bool get classChanged => classKey != originalClassKey;
  bool get subclassChanged => subclassKey != originalSubclassKey;
  bool get levelChanged => level != originalLevel;
}

class _CharacterEditPageState extends ConsumerState<CharacterEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _playerName = TextEditingController();
  final _alignment = TextEditingController();
  final _hitPointsMax = TextEditingController();
  final _armorClass = TextEditingController();
  final _speed = TextEditingController();

  /// Kaynak satirdan okunan ilk degerler; neyin degistigini bunlarla
  /// karsilastiriyoruz.
  Character? _initial;
  List<_ClassRow>? _classes;
  final _scores = <Ability, int>{};
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _playerName.dispose();
    _alignment.dispose();
    _hitPointsMax.dispose();
    _armorClass.dispose();
    _speed.dispose();
    super.dispose();
  }

  void _seed(Character c, List<CharacterClassLevel> levels) {
    if (_initial != null) return;
    _initial = c;
    _name.text = c.name;
    _playerName.text = c.playerName ?? '';
    _alignment.text = c.alignment ?? '';
    _hitPointsMax.text = '${c.hitPointsMax}';
    _armorClass.text = c.armorClassOverride?.toString() ?? '';
    _speed.text = c.speedOverride?.toString() ?? '';
    _scores
      ..[Ability.strength] = c.strength
      ..[Ability.dexterity] = c.dexterity
      ..[Ability.constitution] = c.constitution
      ..[Ability.intelligence] = c.intelligence
      ..[Ability.wisdom] = c.wisdom
      ..[Ability.charisma] = c.charisma;
    _speciesKey = c.speciesKey;
    _backgroundKey = c.backgroundKey;
    _classes = [
      for (final l in levels)
        _ClassRow(
          originalClassKey: l.classKey,
          classKey: l.classKey,
          originalSubclassKey: l.subclassKey,
          subclassKey: l.subclassKey,
          originalLevel: l.level,
          level: l.level,
        ),
    ];
  }

  String? _speciesKey;
  String? _backgroundKey;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final character = ref.watch(characterProvider(widget.characterId));
    final levels = ref.watch(classLevelsProvider(widget.characterId));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.editCharacterTitle),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check, size: 18),
            label: Text(l10n.editSave),
          ),
        ],
      ),
      body: asyncView(
        context,
        character,
        loading: const AppLoading(),
        onRetry: () => ref.invalidate(characterProvider(widget.characterId)),
        data: (c) => asyncView(
          context,
          levels,
          loading: const AppLoading(),
          onRetry: () =>
              ref.invalidate(classLevelsProvider(widget.characterId)),
          data: (rows) {
            _seed(c, rows);
            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [
                  _Section(
                    title: l10n.editSectionIdentity,
                    children: [
                      TextFormField(
                        controller: _name,
                        decoration: InputDecoration(labelText: l10n.editName),
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? l10n.editNameRequired
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _playerName,
                        decoration: InputDecoration(
                          labelText: l10n.editPlayerName,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _alignment,
                        decoration: InputDecoration(
                          labelText: l10n.editAlignment,
                        ),
                      ),
                    ],
                  ),
                  _Section(
                    title: l10n.editSectionOrigin,
                    hint: l10n.editBackgroundHint,
                    children: [
                      _KeyDropdown(
                        label: l10n.editSpecies,
                        value: _speciesKey,
                        entries: [
                          for (final s
                              in ref.watch(speciesOptionsProvider).value ??
                                  const <SpeciesEntry>[])
                            (key: s.key, name: s.name),
                        ],
                        onChanged: (v) => setState(() => _speciesKey = v),
                      ),
                      const SizedBox(height: 12),
                      _KeyDropdown(
                        label: l10n.editBackground,
                        value: _backgroundKey,
                        entries: [
                          for (final b
                              in ref.watch(backgroundOptionsProvider).value ??
                                  const <Background>[])
                            (key: b.key, name: b.name),
                        ],
                        onChanged: (v) => setState(() => _backgroundKey = v),
                      ),
                    ],
                  ),
                  _Section(
                    title: l10n.editSectionAbilities,
                    hint: l10n.editAbilityHint,
                    children: [
                      for (final a in Ability.values)
                        _AbilityRow(
                          ability: a,
                          value: _scores[a] ?? 10,
                          onChanged: (v) => setState(() => _scores[a] = v),
                        ),
                    ],
                  ),
                  _Section(
                    title: l10n.editSectionVitals,
                    hint: l10n.editOverrideHint,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _NumberField(
                              controller: _hitPointsMax,
                              label: l10n.editHitPointsMax,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _NumberField(
                              controller: _armorClass,
                              label: l10n.editArmorClassOverride,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _NumberField(
                              controller: _speed,
                              label: l10n.editSpeedOverride,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  _Section(
                    title: l10n.editSectionClasses,
                    children: [
                      for (final row in _classes ?? const <_ClassRow>[])
                        _ClassEditor(
                          row: row,
                          onChanged: () => setState(() {}),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final initial = _initial;
    final classes = _classes;
    if (initial == null || classes == null) return;

    final l10n = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // Sinif degisimi kagittaki yetenekleri siliyor; once onay.
    final definitions =
        ref.read(allClassDefinitionsProvider).value ??
        const <String, ClassDefinition>{};
    String nameOf(String key) => definitions[key]?.name ?? key;
    for (final row in classes.where((r) => r.classChanged)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.editClassChangeTitle),
          content: Text(
            l10n.editClassChangeBody(
              nameOf(row.originalClassKey),
              nameOf(row.classKey),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.editCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.editClassChangeConfirm),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(characterRepositoryProvider);
      final id = widget.characterId;

      if (_name.text.trim() != initial.name ||
          _text(_playerName) != initial.playerName ||
          _text(_alignment) != initial.alignment) {
        await repo.updateIdentity(
          id,
          name: _name.text,
          playerName: _playerName.text,
          alignment: _alignment.text,
        );
      }

      if (_speciesKey != initial.speciesKey) {
        await repo.setSpecies(id, _speciesKey);
      }
      if (_backgroundKey != initial.backgroundKey) {
        await repo.setBackground(id, _backgroundKey);
      }

      final scores = AbilityScores(
        strength: _scores[Ability.strength] ?? initial.strength,
        dexterity: _scores[Ability.dexterity] ?? initial.dexterity,
        constitution: _scores[Ability.constitution] ?? initial.constitution,
        intelligence: _scores[Ability.intelligence] ?? initial.intelligence,
        wisdom: _scores[Ability.wisdom] ?? initial.wisdom,
        charisma: _scores[Ability.charisma] ?? initial.charisma,
      );
      if (scores.strength != initial.strength ||
          scores.dexterity != initial.dexterity ||
          scores.constitution != initial.constitution ||
          scores.intelligence != initial.intelligence ||
          scores.wisdom != initial.wisdom ||
          scores.charisma != initial.charisma) {
        await repo.setAbilityScores(id, scores);
      }

      // Sinif islemleri: once sinif, sonra seviye, en son alt sinif. Sirasi
      // onemli -- alt sinif yetenekleri mevcut seviyeye kadar isleniyor.
      for (final row in classes) {
        if (row.classChanged) {
          await repo.changeClass(
            characterId: id,
            fromClassKey: row.originalClassKey,
            toClassKey: row.classKey,
          );
        }
        if (row.levelChanged) {
          await repo.setClassLevel(
            characterId: id,
            classKey: row.classKey,
            level: row.level,
          );
        }
        if (row.classChanged || row.subclassChanged) {
          await repo.setSubclass(
            characterId: id,
            classKey: row.classKey,
            subclassKey: row.subclassKey,
          );
        }
      }

      // Can, sinif/seviye islemlerinin kendiliginden yaptigi duzeltmeden
      // SONRA yaziliyor: DM burada bir sayi girdiyse son soz onun.
      final typedMax = int.tryParse(_hitPointsMax.text.trim());
      if (typedMax != null && typedMax != initial.hitPointsMax) {
        await repo.setHitPointsMax(id, typedMax);
      }

      final ac = int.tryParse(_armorClass.text.trim());
      final speed = int.tryParse(_speed.text.trim());
      if (ac != initial.armorClassOverride || speed != initial.speedOverride) {
        await repo.setOverrides(id, armorClass: ac, speed: speed);
      }

      messenger.showSnackBar(SnackBar(content: Text(l10n.editSaved)));
      navigator.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static String? _text(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.hint});

  final String title;
  final String? hint;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            if (hint != null) ...[
              const SizedBox(height: 4),
              Text(
                hint!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Kutuphane anahtari secen acilir liste; "Yok" secenegi her zaman var.
class _KeyDropdown extends StatelessWidget {
  const _KeyDropdown({
    required this.label,
    required this.value,
    required this.entries,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<({String key, String name})> entries;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    // Liste henuz yuklenmediyse secili anahtar item olarak bulunmayabilir;
    // Dropdown bu durumda assert atiyor.
    final known = entries.any((e) => e.key == value);
    return DropdownButtonFormField<String?>(
      initialValue: known ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        DropdownMenuItem(value: null, child: Text(l10n.editNone)),
        for (final e in entries)
          DropdownMenuItem(value: e.key, child: Text(e.name)),
      ],
      onChanged: onChanged,
    );
  }
}

class _AbilityRow extends StatelessWidget {
  const _AbilityRow({
    required this.ability,
    required this.value,
    required this.onChanged,
  });

  final Ability ability;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final modifier = (value - 10) >= 0
        ? '+${(value - 10) ~/ 2}'
        : '${((value - 10) / 2).floor()}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              L10n.of(context).abilityName(ability),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          IconButton(
            onPressed: value <= 1 ? null : () => onChanged(value - 1),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ),
          IconButton(
            onPressed: value >= 30 ? null : () => onChanged(value + 1),
            icon: const Icon(Icons.add_circle_outline),
          ),
          const Spacer(),
          Text(
            modifier,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    decoration: InputDecoration(labelText: label),
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
  );
}

/// Bir sinif satiri: sinif, alt sinif ve seviye.
class _ClassEditor extends ConsumerWidget {
  const _ClassEditor({required this.row, required this.onChanged});

  final _ClassRow row;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final classes = ref.watch(classOptionsProvider).value ?? const [];
    final subclasses =
        ref.watch(subclassesProvider(row.classKey)).value ??
        const <ClassDefinition>[];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _KeyDropdown(
            label: l10n.editClass,
            value: row.classKey,
            entries: [for (final c in classes) (key: c.key, name: c.name)],
            onChanged: (v) {
              if (v == null) return;
              row.classKey = v;
              // Alt sinif yeni sinifin degil; secim sifirlanir.
              if (v != row.originalClassKey) row.subclassKey = null;
              onChanged();
            },
          ),
          const SizedBox(height: 12),
          _KeyDropdown(
            label: l10n.editSubclass,
            value: row.subclassKey,
            entries: [for (final s in subclasses) (key: s.key, name: s.name)],
            onChanged: (v) {
              row.subclassKey = v;
              onChanged();
            },
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(l10n.editLevel),
              const Spacer(),
              IconButton(
                onPressed: row.level <= 1
                    ? null
                    : () {
                        row.level--;
                        onChanged();
                      },
                icon: const Icon(Icons.remove_circle_outline),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  '${row.level}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                onPressed: row.level >= 20
                    ? null
                    : () {
                        row.level++;
                        onChanged();
                      },
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
