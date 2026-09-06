import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/ability.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/game_terms.dart';
import 'character_providers.dart';
import 'creation_wizard.dart' show customContentRepositoryProvider;

/// SRD'de olmayan bir tur ekler.
///
/// SRD 5.2 yalnizca dokuz tur iceriyor; masada kullanilan digerleri buradan
/// giriliyor ve kutuphaneye kalici olarak yaziliyor.
Future<String?> showCustomSpeciesForm(BuildContext context, WidgetRef ref) =>
    showDialog<String>(
      context: context,
      builder: (context) => const _SpeciesForm(),
    );

class _SpeciesForm extends ConsumerStatefulWidget {
  const _SpeciesForm();

  @override
  ConsumerState<_SpeciesForm> createState() => _SpeciesFormState();
}

class _SpeciesFormState extends ConsumerState<_SpeciesForm> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  String _size = 'Medium';
  int _speed = 30;

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
      title: Text(l10n.ccAddSpecies),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.ccSpeciesName,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _size,
              decoration: InputDecoration(
                labelText: l10n.ccSize,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(value: 'Small', child: Text(l10n.ccSizeSmall)),
                DropdownMenuItem(
                  value: 'Medium',
                  child: Text(l10n.ccSizeMedium),
                ),
                DropdownMenuItem(value: 'Large', child: Text(l10n.ccSizeLarge)),
              ],
              onChanged: (v) => setState(() => _size = v ?? 'Medium'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: '$_speed',
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.ccSpeed,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => _speed = int.tryParse(v) ?? 30,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _desc,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: l10n.ccTraits,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
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
        .read(customContentRepositoryProvider)
        .addSpecies(
          name: _name.text.trim(),
          size: _size,
          speed: _speed,
          description: _desc.text.trim(),
        );
    ref.invalidate(speciesOptionsProvider);
    if (mounted) Navigator.pop(context, key);
  }
}

/// SRD'de olmayan bir alt sinif ekler.
///
/// SRD 5.2 sinif basina yalnizca bir alt sinif iceriyor (Fighter -> Champion,
/// Rogue -> Thief gibi); masada kullanilan digerleri buradan giriliyor.
Future<String?> showCustomSubclassForm(
  BuildContext context,
  WidgetRef ref, {
  required String parentClassKey,
  required String parentClassName,
}) => showDialog<String>(
  context: context,
  builder: (context) => _SubclassForm(
    parentClassKey: parentClassKey,
    parentClassName: parentClassName,
  ),
);

class _SubclassForm extends ConsumerStatefulWidget {
  const _SubclassForm({
    required this.parentClassKey,
    required this.parentClassName,
  });

  final String parentClassKey;
  final String parentClassName;

  @override
  ConsumerState<_SubclassForm> createState() => _SubclassFormState();
}

class _SubclassFormState extends ConsumerState<_SubclassForm> {
  final _name = TextEditingController();
  final _desc = TextEditingController();

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
      title: Text(l10n.ccAddSubclass(widget.parentClassName)),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.ccSubclassName,
                hintText: l10n.ccSubclassNameHint,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _desc,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: l10n.ccTraits,
                hintText: l10n.ccSubclassTraitsHint,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
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
        .read(customContentRepositoryProvider)
        .addSubclass(
          name: _name.text.trim(),
          parentClassKey: widget.parentClassKey,
          parentClassName: widget.parentClassName,
          description: _desc.text.trim(),
        );
    ref.invalidate(subclassesProvider(widget.parentClassKey));
    if (mounted) Navigator.pop(context, key);
  }
}

/// SRD'de olmayan bir koken (background) ekler.
Future<String?> showCustomBackgroundForm(BuildContext context, WidgetRef ref) =>
    showDialog<String>(
      context: context,
      builder: (context) => const _BackgroundForm(),
    );

class _BackgroundForm extends ConsumerStatefulWidget {
  const _BackgroundForm();

  @override
  ConsumerState<_BackgroundForm> createState() => _BackgroundFormState();
}

class _BackgroundFormState extends ConsumerState<_BackgroundForm> {
  final _name = TextEditingController();
  final _feat = TextEditingController();
  final _tool = TextEditingController();
  final _abilities = <Ability>{};
  final _skills = <Skill>{};

  @override
  void dispose() {
    _name.dispose();
    _feat.dispose();
    _tool.dispose();
    super.dispose();
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      _abilities.length == 3 &&
      _skills.length == 2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    return AlertDialog(
      title: Text(l10n.ccAddBackground),
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
                  labelText: l10n.ccBackgroundName,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.ccAbilities3(_abilities.length),
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                children: [
                  for (final a in Ability.values)
                    FilterChip(
                      label: Text(l10n.abilityShort(a)),
                      selected: _abilities.contains(a),
                      onSelected: (on) => setState(() {
                        if (on && _abilities.length < 3) {
                          _abilities.add(a);
                        } else if (!on) {
                          _abilities.remove(a);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                l10n.ccSkills2(_skills.length),
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final s in Skill.values)
                    FilterChip(
                      label: Text(l10n.skillName(s)),
                      selected: _skills.contains(s),
                      onSelected: (on) => setState(() {
                        if (on && _skills.length < 2) {
                          _skills.add(s);
                        } else if (!on) {
                          _skills.remove(s);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _tool,
                decoration: InputDecoration(
                  labelText: l10n.ccToolProf,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _feat,
                decoration: InputDecoration(
                  labelText: l10n.ccBackgroundFeat,
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
        FilledButton(onPressed: _valid ? _save : null, child: Text(l10n.save)),
      ],
    );
  }

  Future<void> _save() async {
    final key = await ref
        .read(customContentRepositoryProvider)
        .addBackground(
          name: _name.text.trim(),
          abilityOptions: _abilities.toList(),
          skills: _skills.toList(),
          featName: _feat.text.trim().isEmpty ? null : _feat.text.trim(),
          toolText: _tool.text.trim().isEmpty ? null : _tool.text.trim(),
        );
    ref.invalidate(backgroundOptionsProvider);
    if (mounted) Navigator.pop(context, key);
  }
}
