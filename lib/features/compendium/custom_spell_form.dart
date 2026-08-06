import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../characters/character_providers.dart';
import '../shops/shop_providers.dart' show customContentProvider;
import 'compendium_providers.dart';

/// Kutuphaneye kalici bir buyu ekler. Kullanicinin kendi girdigi icerik;
/// SRD disi bir buyuye ihtiyaci olan DM elle yazip masasinda kullanabilsin.
Future<String?> showCustomSpellForm(BuildContext context, WidgetRef ref) =>
    showDialog<String>(
      context: context,
      builder: (context) => const _SpellForm(),
    );

class _SpellForm extends ConsumerStatefulWidget {
  const _SpellForm();

  @override
  ConsumerState<_SpellForm> createState() => _SpellFormState();
}

class _SpellFormState extends ConsumerState<_SpellForm> {
  final _name = TextEditingController();
  final _castingTime = TextEditingController(text: '1 action');
  final _range = TextEditingController();
  final _duration = TextEditingController();
  final _material = TextEditingController();
  final _desc = TextEditingController();
  final _higher = TextEditingController();

  int _level = 0;
  String? _school;
  bool _verbal = true;
  bool _somatic = true;
  bool _materialComp = false;
  bool _concentration = false;
  bool _ritual = false;
  final _classes = <String>{};

  static const _schools = <String>[
    'Abjuration',
    'Conjuration',
    'Divination',
    'Enchantment',
    'Evocation',
    'Illusion',
    'Necromancy',
    'Transmutation',
  ];

  @override
  void dispose() {
    _name.dispose();
    _castingTime.dispose();
    _range.dispose();
    _duration.dispose();
    _material.dispose();
    _desc.dispose();
    _higher.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final classDefs = ref.watch(allClassDefinitionsProvider).value ?? const {};
    // Yalnizca ust seviye siniflar (alt siniflar degil).
    final topClasses =
        classDefs.values.where((c) => c.subclassOf == null).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final l10n = L10n.of(context);
    return AlertDialog(
      title: Text(l10n.compendiumCreateSpell),
      content: SizedBox(
        width: 460,
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
                    child: DropdownButtonFormField<int>(
                      initialValue: _level,
                      decoration: InputDecoration(
                        labelText: l10n.formLevel,
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 0,
                          child: Text('Cantrip'),
                        ),
                        for (var l = 1; l <= 9; l++)
                          DropdownMenuItem(
                            value: l,
                            child: Text(l10n.sheetOrdinalLevel(l)),
                          ),
                      ],
                      onChanged: (v) => setState(() => _level = v ?? 0),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: _school,
                      decoration: InputDecoration(
                        labelText: l10n.filterSchool,
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('—')),
                        for (final s in _schools)
                          DropdownMenuItem(value: s, child: Text(s)),
                      ],
                      onChanged: (v) => setState(() => _school = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _castingTime,
                decoration: InputDecoration(
                  labelText: 'Casting time',
                  hintText: l10n.formCastingTimeHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _range,
                      decoration: InputDecoration(
                        labelText: l10n.formRange,
                        hintText: l10n.formRangeHint,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _duration,
                      decoration: InputDecoration(
                        labelText: l10n.formDuration,
                        hintText: l10n.formDurationHint,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Bilesenler.
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('V'),
                    selected: _verbal,
                    onSelected: (v) => setState(() => _verbal = v),
                  ),
                  FilterChip(
                    label: const Text('S'),
                    selected: _somatic,
                    onSelected: (v) => setState(() => _somatic = v),
                  ),
                  FilterChip(
                    label: const Text('M'),
                    selected: _materialComp,
                    onSelected: (v) => setState(() => _materialComp = v),
                  ),
                ],
              ),
              if (_materialComp) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _material,
                  decoration: InputDecoration(
                    labelText: l10n.formMaterial,
                    hintText: l10n.formMaterialHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Concentration'),
                value: _concentration,
                onChanged: (v) => setState(() => _concentration = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ritual'),
                value: _ritual,
                onChanged: (v) => setState(() => _ritual = v),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.formClasses,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 4),
              if (topClasses.isEmpty)
                Text(l10n.formClassesFailed)
              else
                Wrap(
                  spacing: 8,
                  children: [
                    for (final c in topClasses)
                      FilterChip(
                        label: Text(c.name),
                        selected: _classes.contains(c.key),
                        onSelected: (on) => setState(() {
                          if (on) {
                            _classes.add(c.key);
                          } else {
                            _classes.remove(c.key);
                          }
                        }),
                      ),
                  ],
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _desc,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: l10n.formDescription,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _higher,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: l10n.formHigherLevel,
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
        .addSpell(
          name: _name.text.trim(),
          level: _level,
          school: _school,
          castingTime: _castingTime.text.trim().isEmpty
              ? '1 action'
              : _castingTime.text.trim(),
          rangeText: _range.text.trim(),
          duration: _duration.text.trim(),
          verbal: _verbal,
          somatic: _somatic,
          material: _materialComp,
          materialSpecified: _materialComp && _material.text.trim().isNotEmpty
              ? _material.text.trim()
              : null,
          concentration: _concentration,
          ritual: _ritual,
          description: _desc.text.trim(),
          higherLevel: _higher.text.trim(),
          classes: _classes.toList(),
        );
    ref.invalidate(spellResultsProvider);
    if (mounted) Navigator.pop(context, key);
  }
}
