import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/custom_content_repository.dart';
import '../../data/providers.dart';
import '../../domain/models/ability.dart';
import '../../domain/rules/challenge_rating.dart';
import '../../domain/rules/cr_estimator.dart';
import '../../l10n/app_localizations.dart';
import 'compendium_providers.dart';

/// CR olcutleri paketten okunur; `tools/build_cr_benchmarks.dart` uretir.
final crEstimatorProvider = FutureProvider<CrEstimator>((ref) async {
  return CrEstimator.fromJson(
    await rootBundle.loadString('assets/rules/cr_benchmarks.json'),
  );
});

final customContentRepositoryProvider = Provider<CustomContentRepository>(
  (ref) => CustomContentRepository(ref.watch(databaseProvider)),
);

/// Homebrew canavar olusturucu.
///
/// Alanlar doldurulurken CR tahmini canli guncellenir; DM canavarin masaya
/// ne getirecegini kaydetmeden once gorebilsin.
class MonsterCreatorPage extends ConsumerStatefulWidget {
  const MonsterCreatorPage({super.key});

  @override
  ConsumerState<MonsterCreatorPage> createState() => _MonsterCreatorPageState();
}

class _MonsterCreatorPageState extends ConsumerState<MonsterCreatorPage> {
  final _name = TextEditingController();
  final _alignment = TextEditingController();
  final _hitDice = TextEditingController();

  String _size = 'Medium';
  String _type = 'Humanoid';
  int _armorClass = 13;
  int _hitPoints = 20;
  int _speed = 30;
  double _damagePerRound = 8;
  int _attackBonus = 4;

  final _scores = <Ability, int>{for (final a in Ability.values) a: 10};
  final _actions = <({String name, String description})>[];

  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _alignment.dispose();
    _hitDice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final estimator = ref.watch(crEstimatorProvider).value;
    final estimate = estimator?.estimate(
      hitPoints: _hitPoints,
      armorClass: _armorClass,
      damagePerRound: _damagePerRound,
      attackBonus: _attackBonus,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.compendiumCreateMonster)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
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
                child: DropdownButtonFormField<String>(
                  initialValue: _size,
                  decoration: InputDecoration(
                    labelText: l10n.ccSize,
                    border: const OutlineInputBorder(),
                  ),
                  items:
                      const [
                            'Tiny',
                            'Small',
                            'Medium',
                            'Large',
                            'Huge',
                            'Gargantuan',
                          ]
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => _size = v ?? 'Medium'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: InputDecoration(
                    labelText: l10n.mcType,
                    border: const OutlineInputBorder(),
                  ),
                  items:
                      const [
                            'Aberration',
                            'Beast',
                            'Celestial',
                            'Construct',
                            'Dragon',
                            'Elemental',
                            'Fey',
                            'Fiend',
                            'Giant',
                            'Humanoid',
                            'Monstrosity',
                            'Ooze',
                            'Plant',
                            'Undead',
                          ]
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => _type = v ?? 'Humanoid'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _NumberRow(
            label: l10n.mcArmorClass,
            value: _armorClass,
            min: 5,
            max: 25,
            onChanged: (v) => setState(() => _armorClass = v),
          ),
          _NumberRow(
            label: l10n.levelUpHitPoints,
            value: _hitPoints,
            min: 1,
            max: 800,
            step: 5,
            onChanged: (v) => setState(() => _hitPoints = v),
          ),
          _NumberRow(
            label: l10n.mcSpeedFt,
            value: _speed,
            min: 0,
            max: 120,
            step: 5,
            onChanged: (v) => setState(() => _speed = v),
          ),
          const SizedBox(height: 20),
          Text(l10n.mcAbilityScores, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final ability in Ability.values)
            _NumberRow(
              label: ability.label,
              value: _scores[ability]!,
              min: 1,
              max: 30,
              onChanged: (v) => setState(() => _scores[ability] = v),
            ),
          const SizedBox(height: 20),
          Text(l10n.mcAttackPower, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(l10n.mcAttackHint, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          _NumberRow(
            label: l10n.mcDamagePerRound,
            value: _damagePerRound.round(),
            min: 0,
            max: 400,
            step: 2,
            onChanged: (v) => setState(() => _damagePerRound = v.toDouble()),
          ),
          _NumberRow(
            label: l10n.mcAttackBonus,
            value: _attackBonus,
            min: 0,
            max: 20,
            onChanged: (v) => setState(() => _attackBonus = v),
          ),
          const SizedBox(height: 20),
          if (estimate != null) _EstimateCard(estimate: estimate),
          const SizedBox(height: 20),
          _ActionsSection(actions: _actions, onChanged: () => setState(() {})),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _name.text.trim().isEmpty || _saving || estimate == null
                ? null
                : () => _save(estimate.result),
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(l10n.mcSaveToLibrary),
          ),
        ],
      ),
    );
  }

  Future<void> _save(double challengeRating) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(customContentRepositoryProvider)
          .addMonster(
            name: _name.text.trim(),
            challengeRating: challengeRating,
            armorClass: _armorClass,
            hitPoints: _hitPoints,
            size: _size,
            creatureType: _type,
            alignment: _alignment.text.trim(),
            hitDice: _hitDice.text.trim(),
            speed: _speed,
            abilityScores: {
              for (final e in _scores.entries) e.key.name: e.value,
            },
            actions: _actions,
          );
      // Kutuphane listesi taze gelsin.
      ref.invalidate(monsterResultsProvider);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _EstimateCard extends StatelessWidget {
  const _EstimateCard({required this.estimate});

  final CrEstimate estimate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.mcEstimatedCr,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  'CR ${estimate.label}',
                  style: theme.textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.mcCrBreakdown(
                formatCr(estimate.defensive),
                formatCr(estimate.offensive),
              ),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(l10n.mcBenchmarkNote, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _NumberRow extends StatelessWidget {
  const _NumberRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 100,
    this.step = 1,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final int step;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: value > min
              ? () => onChanged((value - step).clamp(min, max))
              : null,
        ),
        SizedBox(
          width: 52,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: value < max
              ? () => onChanged((value + step).clamp(min, max))
              : null,
        ),
      ],
    ),
  );
}

class _ActionsSection extends StatelessWidget {
  const _ActionsSection({required this.actions, required this.onChanged});

  final List<({String name, String description})> actions;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(l10n.mcActions, style: theme.textTheme.titleMedium),
            const Spacer(),
            TextButton.icon(
              onPressed: () async {
                final action = await _askAction(context);
                if (action != null) {
                  actions.add(action);
                  onChanged();
                }
              },
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.add),
            ),
          ],
        ),
        if (actions.isEmpty)
          Text(l10n.mcNoActions, style: theme.textTheme.bodySmall)
        else
          for (final (index, action) in actions.indexed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(action.name),
              subtitle: Text(
                action.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  actions.removeAt(index);
                  onChanged();
                },
              ),
            ),
      ],
    );
  }

  Future<({String name, String description})?> _askAction(
    BuildContext context,
  ) {
    final name = TextEditingController();
    final desc = TextEditingController();
    return showDialog<({String name, String description})>(
      context: context,
      builder: (context) {
        final l10n = L10n.of(context);
        return AlertDialog(
          title: Text(l10n.mcAddAction),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l10n.formName,
                    hintText: l10n.mcActionNameHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: desc,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: l10n.formDescription,
                    hintText:
                        'Melee Attack Roll: +5, reach 5 ft. 8 (1d10 + 3) '
                        'Piercing damage.',
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
              onPressed: () {
                if (name.text.trim().isEmpty) return;
                Navigator.pop(context, (
                  name: name.text.trim(),
                  description: desc.text.trim(),
                ));
              },
              child: Text(l10n.add),
            ),
          ],
        );
      },
    );
  }
}
