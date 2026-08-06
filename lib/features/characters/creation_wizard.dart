import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/custom_content_repository.dart';
import '../../data/providers.dart';
import '../../domain/models/ability.dart';
import '../../domain/rules/origin_parsing.dart';
import '../../l10n/app_localizations.dart';
import '../world/pick_image_file.dart';
import 'character_draft.dart';
import 'character_providers.dart';
import 'custom_content_forms.dart';

/// Karakter olusturma sihirbazi (2024 kurallari).
///
/// Adim sirasi kitaptaki sirayla ayni degil: once kimlik/koken, sonra sinif,
/// en son puanlar. Masada karakter yaratirken oyuncular once "ne olacagima"
/// karar veriyor, sayilari sonra dagitiyor.
class CreationWizard extends ConsumerStatefulWidget {
  const CreationWizard({super.key});

  @override
  ConsumerState<CreationWizard> createState() => _CreationWizardState();
}

class _CreationWizardState extends ConsumerState<CreationWizard> {
  int _step = 0;
  bool _saving = false;

  static List<String> _titles(L10n l10n) => [
    l10n.cwStepIdentity,
    l10n.cwStepBackground,
    l10n.cwStepClass,
    l10n.mcAbilityScores,
    l10n.sheetSkills,
    l10n.cwStepEquipment,
    l10n.cwStepSummary,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final titles = _titles(l10n);
    final draft = ref.watch(characterDraftProvider);
    final core = ref.watch(classCoreTraitsProvider(draft.classKey)).value;

    return Scaffold(
      appBar: AppBar(
        title: Text('${_step + 1}/${titles.length} · ${titles[_step]}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_step + 1) / titles.length,
            minHeight: 4,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: switch (_step) {
                  0 => const _IdentityStep(),
                  1 => const _BackgroundStep(),
                  2 => const _ClassStep(),
                  3 => const _AbilitiesStep(),
                  4 => const _SkillsStep(),
                  5 => const _EquipmentStep(),
                  _ => const _SummaryStep(),
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  if (_step > 0)
                    TextButton(
                      onPressed: () => setState(() => _step--),
                      child: Text(l10n.worldBack),
                    ),
                  const Spacer(),
                  if (_step < titles.length - 1)
                    FilledButton(
                      onPressed: _canAdvance(draft, core)
                          ? () => setState(() => _step++)
                          : null,
                      child: Text(l10n.cwNext),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _saving ? null : _create,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text(l10n.cwCreateCharacter),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Her adimin kendi zorunlulugu var; eksikken ileri gidilemez.
  bool _canAdvance(CharacterDraft draft, ClassCoreTraits? core) =>
      switch (_step) {
        0 => draft.name.trim().isNotEmpty && draft.speciesKey != null,
        1 => draft.backgroundKey != null && draft.originPointsUsed == 3,
        2 => draft.classKey != null,
        3 => _abilitiesValid(draft),
        4 => core == null || draft.chosenSkills.length == core.skillChoiceCount,
        5 => draft.equipmentChoice != null,
        _ => true,
      };

  bool _abilitiesValid(CharacterDraft draft) => switch (draft.method) {
    AbilityMethod.pointBuy => PointBuy.remaining(draft.baseScores) == 0,
    // Standart dizi ve elle giriste kisitlama yok; oyuncu ne yazdiysa o.
    _ => true,
  };

  Future<void> _create() async {
    final draft = ref.read(characterDraftProvider);
    final core = ref.read(classCoreTraitsProvider(draft.classKey)).value;
    final benefits = ref
        .read(backgroundBenefitsProvider(draft.backgroundKey))
        .value;
    if (core == null) return;

    setState(() => _saving = true);
    try {
      // Secilen ekipman secenegi (ayni etiket sinif + background icin gecerli):
      // altini VE eşyalarini birlikte topla.
      final chosen = draft.equipmentChoice;
      final chosenOptions = chosen == null
          ? const <EquipmentOption>[]
          : [
              ...core.equipmentOptions.where((o) => o.label == chosen),
              ...?benefits?.equipmentOptions.where((o) => o.label == chosen),
            ];
      final gold = chosenOptions.fold(0, (sum, o) => sum + o.goldPieces);
      final startingItems = [
        for (final option in chosenOptions)
          for (final e in option.entries) (name: e.name, quantity: e.quantity),
      ];

      final id = const Uuid().v4();
      await ref
          .read(characterRepositoryProvider)
          .createLevelOneCharacter(
            id: id,
            name: draft.name.trim(),
            playerName: draft.playerName?.trim(),
            classKey: draft.classKey!,
            speciesKey: draft.speciesKey,
            backgroundKey: draft.backgroundKey,
            abilities: draft.finalScores,
            savingThrows: core.savingThrows,
            // Sinif secimleri + background'in verdigi beceriler birlesir.
            skills: {...draft.chosenSkills, ...?benefits?.skills},
            hitDieSides: core.hitDieSides,
            startingGoldGp: gold,
            startingItems: startingItems,
          );

      // Secilen portre varsa karaktere bagla.
      if (draft.portraitFile != null) {
        try {
          await ref
              .read(characterRepositoryProvider)
              .setPortrait(id, draft.portraitFile!);
        } on FormatException {
          // Portre okunamadiysa karakteri yine de olustur; DM sonra ekler.
        }
      }

      if (!mounted) return;
      ref.read(characterDraftProvider.notifier).reset();
      Navigator.of(context).pop(id);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// --- Adim 1: kimlik ve tur ------------------------------------------------

class _IdentityStep extends ConsumerWidget {
  const _IdentityStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(characterDraftProvider);
    final notifier = ref.read(characterDraftProvider.notifier);
    final species = ref.watch(speciesOptionsProvider);
    final traits = ref.watch(speciesTraitsProvider(draft.speciesKey)).value;
    final l10n = L10n.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          initialValue: draft.name,
          decoration: InputDecoration(
            labelText: l10n.cwCharacterName,
            border: const OutlineInputBorder(),
          ),
          onChanged: (v) => notifier.update(draft.copyWith(name: v)),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: draft.playerName,
          decoration: InputDecoration(
            labelText: l10n.cwPlayerName,
            border: const OutlineInputBorder(),
          ),
          onChanged: (v) => notifier.update(draft.copyWith(playerName: v)),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage: draft.portraitFile != null
                  ? FileImage(draft.portraitFile!)
                  : null,
              child: draft.portraitFile == null
                  ? const Icon(Icons.person, size: 28)
                  : null,
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await pickImageFile();
                if (picked != null) {
                  notifier.update(draft.copyWith(portraitFile: picked));
                }
              },
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(
                draft.portraitFile == null ? l10n.cwAddPhoto : l10n.sheetChange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _SectionTitle(
          l10n.cwSpecies,
          action: _AddCustomButton(
            onPressed: () async {
              final key = await showCustomSpeciesForm(context, ref);
              if (key != null) {
                notifier.update(draft.copyWith(speciesKey: key));
              }
            },
          ),
        ),
        species.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
          data: (rows) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in rows)
                ChoiceChip(
                  label: Text(s.name),
                  selected: draft.speciesKey == s.key,
                  onSelected: (_) => notifier.update(
                    // Tur degisince onceki boyut secimi gecersizlesir.
                    CharacterDraft(
                      name: draft.name,
                      playerName: draft.playerName,
                      speciesKey: s.key,
                      backgroundKey: draft.backgroundKey,
                      originIncreases: draft.originIncreases,
                      spread: draft.spread,
                      classKey: draft.classKey,
                      method: draft.method,
                      baseScores: draft.baseScores,
                      chosenSkills: draft.chosenSkills,
                      equipmentChoice: draft.equipmentChoice,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (traits != null) ...[
          const SizedBox(height: 16),
          _InfoRow(l10n.sheetSpeed, '${traits.speed} feet'),
          if (traits.sizes.length > 1) ...[
            const SizedBox(height: 8),
            Text(l10n.cwChooseSize),
            Wrap(
              spacing: 8,
              children: [
                for (final size in traits.sizes)
                  ChoiceChip(
                    label: Text(size),
                    selected: draft.size == size,
                    onSelected: (_) =>
                        notifier.update(draft.copyWith(size: size)),
                  ),
              ],
            ),
          ] else if (traits.sizes.isNotEmpty)
            _InfoRow(l10n.ccSize, traits.sizes.single),
        ],
      ],
    );
  }
}

// --- Adim 2: background ---------------------------------------------------

class _BackgroundStep extends ConsumerWidget {
  const _BackgroundStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(characterDraftProvider);
    final notifier = ref.read(characterDraftProvider.notifier);
    final backgrounds = ref.watch(backgroundOptionsProvider);
    final benefits = ref
        .watch(backgroundBenefitsProvider(draft.backgroundKey))
        .value;
    final l10n = L10n.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          l10n.cwBackground,
          action: _AddCustomButton(
            onPressed: () async {
              final key = await showCustomBackgroundForm(context, ref);
              if (key != null) {
                notifier.update(
                  draft.copyWith(backgroundKey: key, originIncreases: const {}),
                );
              }
            },
          ),
        ),
        backgrounds.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
          data: (rows) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final b in rows)
                ChoiceChip(
                  label: Text(b.name),
                  selected: draft.backgroundKey == b.key,
                  onSelected: (_) => notifier.update(
                    draft.copyWith(
                      backgroundKey: b.key,
                      originIncreases: const {},
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (benefits != null) ...[
          const SizedBox(height: 20),
          if (benefits.skills.isNotEmpty)
            _InfoRow(
              l10n.sheetSkills,
              benefits.skills.map((s) => s.label).join(', '),
            ),
          if (benefits.toolText != null)
            _InfoRow(l10n.cwTool, benefits.toolText!),
          if (benefits.featName != null)
            _InfoRow(
              l10n.cwBackgroundFeat,
              [
                benefits.featName!,
                if (benefits.featNote != null) '(${benefits.featNote})',
              ].join(' '),
            ),
          const SizedBox(height: 20),
          Text(
            l10n.cwAbilityIncrease3,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.cwOriginPointsHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          SegmentedButton<AbilitySpread>(
            segments: const [
              ButtonSegment(
                value: AbilitySpread.twoOne,
                label: Text('+2 / +1'),
              ),
              ButtonSegment(
                value: AbilitySpread.oneOneOne,
                label: Text('+1 / +1 / +1'),
              ),
            ],
            selected: {draft.spread},
            onSelectionChanged: (s) => notifier.update(
              draft.copyWith(spread: s.first, originIncreases: const {}),
            ),
          ),
          const SizedBox(height: 12),
          _OriginAllocator(options: benefits.abilityOptions),
        ],
      ],
    );
  }
}

/// Koken puanlarini dagitir. Kural disi dagilim uretmemek icin secim
/// mantigi burada: +2/+1 modunda bir yetenege +2, baskasina +1.
class _OriginAllocator extends ConsumerWidget {
  const _OriginAllocator({required this.options});

  final List<Ability> options;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(characterDraftProvider);
    final notifier = ref.read(characterDraftProvider.notifier);
    final current = draft.originIncreases;

    void apply(Map<Ability, int> next) =>
        notifier.update(draft.copyWith(originIncreases: next));

    if (draft.spread == AbilitySpread.oneOneOne) {
      // Tek gecerli dagilim var; secim gerektirmiyor.
      final all = {for (final a in options) a: 1};
      if (current.length != options.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) => apply(all));
      }
      return Wrap(
        spacing: 8,
        children: [for (final a in options) Chip(label: Text('${a.short} +1'))],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final bonus in [2, 1])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(width: 40, child: Text('+$bonus')),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (final a in options)
                        ChoiceChip(
                          label: Text(a.short),
                          selected: current[a] == bonus,
                          onSelected: (_) {
                            final next = {
                              for (final e in current.entries)
                                if (e.value != bonus) e.key: e.value,
                            }..remove(a);
                            next[a] = bonus;
                            apply(next);
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// --- Adim 3: sinif --------------------------------------------------------

class _ClassStep extends ConsumerWidget {
  const _ClassStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(characterDraftProvider);
    final notifier = ref.read(characterDraftProvider.notifier);
    final classes = ref.watch(classOptionsProvider);
    final core = ref.watch(classCoreTraitsProvider(draft.classKey)).value;
    final l10n = L10n.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(l10n.cwStepClass),
        classes.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
          data: (rows) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in rows)
                ChoiceChip(
                  label: Text(c.name),
                  selected: draft.classKey == c.key,
                  // Sinif degisince beceri secimleri gecersiz kalir.
                  onSelected: (_) => notifier.update(
                    draft.copyWith(classKey: c.key, chosenSkills: const {}),
                  ),
                ),
            ],
          ),
        ),
        if (core != null) ...[
          const SizedBox(height: 20),
          _InfoRow(l10n.cwHitDie, 'd${core.hitDieSides}'),
          _InfoRow(
            l10n.sheetSavingThrows,
            core.savingThrows.map((a) => a.label).join(', '),
          ),
          if (core.weaponText != null)
            _InfoRow(l10n.cwWeapons, core.weaponText!),
          if (core.armorText != null) _InfoRow(l10n.cwArmor, core.armorText!),
          if (core.toolText != null) _InfoRow(l10n.cwTools, core.toolText!),
          const SizedBox(height: 12),
          Text(
            l10n.cwSubclassLater,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

// --- Adim 4: yetenek puanlari --------------------------------------------

class _AbilitiesStep extends ConsumerWidget {
  const _AbilitiesStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(characterDraftProvider);
    final notifier = ref.read(characterDraftProvider.notifier);
    final theme = Theme.of(context);
    final l10n = L10n.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<AbilityMethod>(
          segments: [
            for (final m in AbilityMethod.values)
              ButtonSegment(value: m, label: Text(_methodLabel(l10n, m))),
          ],
          selected: {draft.method},
          onSelectionChanged: (s) {
            final method = s.first;
            notifier.update(
              draft.copyWith(
                method: method,
                baseScores: switch (method) {
                  AbilityMethod.pointBuy => const AbilityScores(
                    strength: 8,
                    dexterity: 8,
                    constitution: 8,
                    intelligence: 8,
                    wisdom: 8,
                    charisma: 8,
                  ),
                  AbilityMethod.standardArray => const AbilityScores(
                    strength: 15,
                    dexterity: 14,
                    constitution: 13,
                    intelligence: 12,
                    wisdom: 10,
                    charisma: 8,
                  ),
                  AbilityMethod.manual => draft.baseScores,
                },
              ),
            );
          },
        ),
        if (draft.method == AbilityMethod.pointBuy) ...[
          const SizedBox(height: 12),
          Text(
            L10n.of(
              context,
            ).cwPointsRemaining(PointBuy.remaining(draft.baseScores)),
            style: theme.textTheme.titleMedium?.copyWith(
              color: PointBuy.remaining(draft.baseScores) == 0
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 12),
        for (final ability in Ability.values)
          _AbilityRow(
            ability: ability,
            draft: draft,
            onChanged: (value) => notifier.update(
              draft.copyWith(
                baseScores: draft.baseScores.plus({
                  ability: value - draft.baseScores[ability],
                }),
              ),
            ),
          ),
      ],
    );
  }
}

class _AbilityRow extends StatelessWidget {
  const _AbilityRow({
    required this.ability,
    required this.draft,
    required this.onChanged,
  });

  final Ability ability;
  final CharacterDraft draft;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = draft.baseScores[ability];
    final bonus = draft.originIncreases[ability] ?? 0;
    final total = base + bonus;
    final modifier = draft.finalScores.modifier(ability);

    final pointBuy = draft.method == AbilityMethod.pointBuy;
    final raiseCost = PointBuy.costToRaise(base);
    final canRaise = pointBuy
        ? raiseCost != null && raiseCost <= PointBuy.remaining(draft.baseScores)
        : base < 20;
    final canLower = pointBuy ? base > PointBuy.min : base > 1;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(ability.short, style: theme.textTheme.titleSmall),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: canLower ? () => onChanged(base - 1) : null,
          ),
          SizedBox(
            width: 32,
            child: Text('$base', textAlign: TextAlign.center),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: canRaise ? () => onChanged(base + 1) : null,
          ),
          if (bonus > 0)
            Text(
              '+$bonus',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          const Spacer(),
          Text('$total', style: theme.textTheme.titleMedium),
          SizedBox(
            width: 44,
            child: Text(
              modifier >= 0 ? '(+$modifier)' : '($modifier)',
              textAlign: TextAlign.end,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Adim 5: beceriler ----------------------------------------------------

class _SkillsStep extends ConsumerWidget {
  const _SkillsStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(characterDraftProvider);
    final notifier = ref.read(characterDraftProvider.notifier);
    final core = ref.watch(classCoreTraitsProvider(draft.classKey)).value;
    final benefits = ref
        .watch(backgroundBenefitsProvider(draft.backgroundKey))
        .value;
    final l10n = L10n.of(context);

    if (core == null) return Text(l10n.cwChooseClassFirst);

    final fromBackground = benefits?.skills.toSet() ?? const <Skill>{};
    final options = core.anySkill ? Skill.values : core.skillOptions;
    final remaining = core.skillChoiceCount - draft.chosenSkills.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          remaining > 0
              ? l10n.cwChooseMoreSkills(remaining)
              : l10n.cwSelectionDone,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (fromBackground.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            l10n.cwFromBackground(
              fromBackground.map((s) => s.label).join(', '),
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 12),
        for (final skill in options)
          CheckboxListTile(
            dense: true,
            title: Text(skill.label),
            subtitle: Text(skill.ability.short),
            // Kokenden gelen beceriler zaten var; tekrar secilemez.
            value:
                draft.chosenSkills.contains(skill) ||
                fromBackground.contains(skill),
            onChanged: fromBackground.contains(skill)
                ? null
                : (on) {
                    final next = {...draft.chosenSkills};
                    if (on ?? false) {
                      if (next.length >= core.skillChoiceCount) return;
                      next.add(skill);
                    } else {
                      next.remove(skill);
                    }
                    notifier.update(draft.copyWith(chosenSkills: next));
                  },
          ),
      ],
    );
  }
}

// --- Adim 6: ekipman ------------------------------------------------------

class _EquipmentStep extends ConsumerWidget {
  const _EquipmentStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(characterDraftProvider);
    final notifier = ref.read(characterDraftProvider.notifier);
    final core = ref.watch(classCoreTraitsProvider(draft.classKey)).value;
    final benefits = ref
        .watch(backgroundBenefitsProvider(draft.backgroundKey))
        .value;
    final l10n = L10n.of(context);

    if (core == null) return Text(l10n.cwChooseClassFirst);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.cwEquipmentHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        RadioGroup<String>(
          groupValue: draft.equipmentChoice,
          onChanged: (v) => notifier.update(draft.copyWith(equipmentChoice: v)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final option in core.equipmentOptions)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: RadioListTile<String>(
                    value: option.label,
                    title: Text(l10n.cwOption(option.label)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (option.entries.isNotEmpty)
                          Text(_describeEntries(option)),
                        if (benefits != null)
                          for (final bg in benefits.equipmentOptions.where(
                            (o) => o.label == option.label,
                          ))
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                l10n.cwBackgroundPrefix(_describeEntries(bg)),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.cwEquipmentNote,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Yetenek puani yontemi etiketi (secili dile gore).
String _methodLabel(L10n l10n, AbilityMethod method) => switch (method) {
  AbilityMethod.pointBuy => l10n.cwPointBuy,
  AbilityMethod.standardArray => l10n.cwStandardArray,
  AbilityMethod.manual => l10n.cwManual,
};

/// "2× Dagger, Crowbar + 16 gp" gibi tek satirlik ozet.
String _describeEntries(EquipmentOption option) => [
  for (final e in option.entries)
    e.quantity > 1 ? '${e.quantity}× ${e.name}' : e.name,
  if (option.goldPieces > 0) '${option.goldPieces} gp',
].join(', ');

// --- Adim 7: ozet ---------------------------------------------------------

class _SummaryStep extends ConsumerWidget {
  const _SummaryStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(characterDraftProvider);
    final core = ref.watch(classCoreTraitsProvider(draft.classKey)).value;
    final benefits = ref
        .watch(backgroundBenefitsProvider(draft.backgroundKey))
        .value;
    final species = ref.watch(speciesOptionsProvider).value;
    final classes = ref.watch(classOptionsProvider).value;
    final backgrounds = ref.watch(backgroundOptionsProvider).value;

    String nameOf(List<dynamic>? rows, String? key) {
      if (rows == null || key == null) return '—';
      for (final r in rows) {
        if ((r as dynamic).key == key) return (r as dynamic).name as String;
      }
      return '—';
    }

    final scores = draft.finalScores;
    final hp = (core?.hitDieSides ?? 8) + scores.modifier(Ability.constitution);
    final l10n = L10n.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          draft.name.isEmpty ? l10n.cwUnnamed : draft.name,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        _InfoRow(l10n.cwSpecies, nameOf(species, draft.speciesKey)),
        _InfoRow(l10n.cwBackground, nameOf(backgrounds, draft.backgroundKey)),
        _InfoRow(l10n.cwStepClass, '${nameOf(classes, draft.classKey)} 1'),
        const Divider(height: 24),
        for (final a in Ability.values)
          _InfoRow(
            a.label,
            '${scores[a]}  (${scores.modifier(a) >= 0 ? '+' : ''}${scores.modifier(a)})',
          ),
        const Divider(height: 24),
        _InfoRow(l10n.levelUpHitPoints, '$hp'),
        _InfoRow(
          l10n.sheetSavingThrows,
          core?.savingThrows.map((a) => a.label).join(', ') ?? '—',
        ),
        _InfoRow(
          l10n.sheetSkills,
          {
            ...draft.chosenSkills,
            ...?benefits?.skills,
          }.map((s) => s.label).join(', '),
        ),
        if (benefits?.featName != null)
          _InfoRow(l10n.cwBackgroundFeat, benefits!.featName!),
      ],
    );
  }
}

// --- Ortak parcalar -------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const Spacer(),
        ?action,
      ],
    ),
  );
}

class _AddCustomButton extends StatelessWidget {
  const _AddCustomButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onPressed,
    icon: const Icon(Icons.add, size: 18),
    label: Text(L10n.of(context).levelUpAddCustom),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// Homebrew ekleme formlarinin ihtiyac duydugu repository.
final customContentRepositoryProvider = Provider<CustomContentRepository>(
  (ref) => CustomContentRepository(ref.watch(databaseProvider)),
);
