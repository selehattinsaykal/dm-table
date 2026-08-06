import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ui/async_view.dart';
import '../../app/ui/ui.dart';
import '../../data/character_repository.dart';
import '../../data/db/database.dart';
import '../../domain/models/ability.dart';
import '../../domain/models/character_build.dart';
import '../../domain/rules/character_math.dart';
import '../../domain/rules/dice.dart';
import '../../domain/rules/experience.dart';
import '../../l10n/app_localizations.dart';
import '../compendium/compendium_providers.dart';
import '../dice/dice_sheet.dart';
import '../world/pick_image_file.dart';
import 'character_avatar.dart';
import 'character_providers.dart';
import 'level_up_sheet.dart';

/// Karakter kagidi.
///
/// Masada en cok dokunulan sey can takibi oldugu icin HP kartini en uste
/// aldik; hesaplanan degerler (AC, kurtarma, beceri) salt okunur ve her
/// zaman kural motorundan geliyor -- elle girilen bir kopyasi tutulmuyor ki
/// tukenmislik ya da zirh degisince kendiliginden guncellensin.
class CharacterSheetPage extends ConsumerWidget {
  const CharacterSheetPage({required this.characterId, super.key});

  final String characterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final character = ref.watch(characterProvider(characterId));
    final build = ref.watch(characterBuildProvider(characterId));
    final l10n = L10n.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(character.value?.name ?? l10n.sheetTitleFallback),
        actions: [
          IconButton(
            tooltip: l10n.sheetRollDice,
            icon: const Icon(Icons.casino_outlined),
            onPressed: () => showDiceSheet(
              context,
              onRolled: (roll) => showRollResult(context, roll),
            ),
          ),
          _RestButton(characterId: characterId),
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LevelUpSheet(characterId: characterId),
              ),
            ),
            icon: const Icon(Icons.arrow_upward, size: 18),
            label: Text(l10n.sheetLevelUp),
          ),
        ],
      ),
      body: switch ((character, build)) {
        (AsyncData(value: final c), AsyncData(value: final b)) => ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
          children: [
            _ClassLine(characterId: characterId),
            const SizedBox(height: 12),
            _PortraitCard(character: c),
            const SizedBox(height: 12),
            _HitPointsCard(character: c),
            const SizedBox(height: 12),
            _ExperienceCard(character: c),
            const SizedBox(height: 12),
            _CoreStatsCard(character: c, stats: b),
            const SizedBox(height: 12),
            _AbilitiesCard(stats: b),
            const SizedBox(height: 12),
            _SavesCard(stats: b),
            const SizedBox(height: 12),
            _SkillsCard(stats: b),
            const SizedBox(height: 12),
            _SpellSlotsCard(characterId: characterId, character: c),
            const SizedBox(height: 12),
            _KnownSpellsCard(characterId: characterId),
            const SizedBox(height: 12),
            _ResourcesCard(characterId: characterId),
            const SizedBox(height: 12),
            _FeaturesCard(characterId: characterId),
            const SizedBox(height: 12),
            _InventoryCard(characterId: characterId),
            const SizedBox(height: 12),
            _ConditionCard(character: c),
            const SizedBox(height: 12),
            _PurseCard(character: c),
            const SizedBox(height: 12),
            _StoryCard(character: c),
          ],
        ),
        (AsyncError(:final error), _) ||
        (_, AsyncError(:final error)) => Center(child: Text('$error')),
        _ => const AppLoading(),
      },
    );
  }
}

/// "Wizard 5 (Evoker) · Goliath · Soldier" seklinde tek satirlik kimlik.
class _ClassLine extends ConsumerWidget {
  const _ClassLine({required this.characterId});

  final String characterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final levels =
        ref.watch(classLevelsProvider(characterId)).value ?? const [];
    final classes = ref.watch(classOptionsProvider).value ?? const [];
    final all = ref.watch(allClassDefinitionsProvider).value ?? const {};

    String nameOf(String key) =>
        all[key]?.name ??
        classes.where((c) => c.key == key).firstOrNull?.name ??
        key;

    final parts = [
      for (final l in levels)
        '${nameOf(l.classKey)} ${l.level}'
            '${l.subclassKey == null ? '' : ' (${nameOf(l.subclassKey!)})'}',
    ];

    return Text(
      parts.isEmpty ? '—' : parts.join(' / '),
      style: Theme.of(context).textTheme.titleMedium,
      textAlign: TextAlign.center,
    );
  }
}

/// Sinif ve alt sinif sayaclari.
///
/// SRD siniflarinda Rage/Rage Damage gibi sutunlar, homebrew alt siniflarda
/// DM'in tanimladigi sayaclar -- ikisi de ayni yerden geliyor.
class _ResourcesCard extends ConsumerWidget {
  const _ResourcesCard({required this.characterId});

  final String characterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resources =
        ref.watch(classResourcesProvider(characterId)).value ?? const {};
    if (resources.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return _ListCard(
      title: L10n.of(context).sheetClassCounters,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final entry in resources.entries)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(entry.value, style: theme.textTheme.titleMedium),
                    Text(entry.key, style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Seviye atladikca biriken sinif yetenekleri.
class _FeaturesCard extends ConsumerWidget {
  const _FeaturesCard({required this.characterId});

  final String characterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final features =
        ref.watch(characterFeaturesProvider(characterId)).value ?? const [];

    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    return _ListCard(
      title: l10n.sheetFeatures,
      trailing: IconButton(
        tooltip: l10n.sheetAddFeature,
        icon: const Icon(Icons.add_circle_outline),
        onPressed: () => _editFeature(context, ref, null),
      ),
      children: [
        if (features.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(l10n.seNoFeatures, style: theme.textTheme.bodySmall),
          ),
        for (final f in features)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 12),
            title: Row(
              children: [
                Expanded(
                  child: Text(f.name, style: theme.textTheme.bodyMedium),
                ),
                if (f.usesMax != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: _FeatureUsesTracker(feature: f),
                  ),
              ],
            ),
            subtitle: Row(
              children: [
                if (f.gainedAtLevel != null)
                  Text(
                    l10n.sheetOrdinalLevel(f.gainedAtLevel!),
                    style: theme.textTheme.labelSmall,
                  ),
                if (f.source == 'manual') ...[
                  if (f.gainedAtLevel != null) const Text('  ·  '),
                  Text(
                    l10n.sheetFeatureCustom,
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ],
            ),
            trailing: f.source != 'manual'
                ? const Icon(Icons.expand_more)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => _editFeature(context, ref, f),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () => _deleteFeature(context, ref, f),
                      ),
                    ],
                  ),
            children: [
              if (f.description.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(f.description, style: theme.textTheme.bodySmall),
                ),
            ],
          ),
      ],
    );
  }

  Future<void> _editFeature(
    BuildContext context,
    WidgetRef ref,
    CharacterFeature? existing,
  ) async {
    final l10n = L10n.of(context);
    final name = TextEditingController(text: existing?.name ?? '');
    final description = TextEditingController(
      text: existing?.description ?? '',
    );
    final uses = TextEditingController(
      text: existing?.usesMax == null ? '' : '${existing!.usesMax}',
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          existing == null ? l10n.sheetAddFeature : l10n.sheetEditFeature,
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l10n.sheetFeatureName,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: description,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: l10n.sheetFeatureDesc,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: uses,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.sheetFeatureUses,
                    helperText: l10n.sheetFeatureUsesHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;

    final repo = ref.read(characterRepositoryProvider);
    final usesMax = int.tryParse(uses.text.trim());
    if (existing == null) {
      await repo.addManualFeature(
        characterId,
        name: name.text.trim(),
        description: description.text.trim(),
        usesMax: usesMax,
      );
    } else {
      await repo.updateManualFeature(
        existing.id,
        name: name.text.trim(),
        description: description.text.trim(),
        usesMax: usesMax,
      );
    }
    ref.invalidate(characterFeaturesProvider(characterId));
  }

  Future<void> _deleteFeature(
    BuildContext context,
    WidgetRef ref,
    CharacterFeature feature,
  ) async {
    final l10n = L10n.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.sheetDeleteFeatureConfirm),
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
    await ref.read(characterRepositoryProvider).deleteFeature(feature.id);
    ref.invalidate(characterFeaturesProvider(characterId));
  }
}

/// Sinirli kullanimli bir yetenegin harcanan/kalan sayaci (ör. "1/2").
/// Dokununca bir kullanim harcar; uzun basinca sifirlar.
class _FeatureUsesTracker extends ConsumerWidget {
  const _FeatureUsesTracker({required this.feature});

  final CharacterFeature feature;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final max = feature.usesMax!;
    final repo = ref.read(characterRepositoryProvider);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: feature.usesSpent >= max
          ? null
          : () => repo
                .setFeatureUsesSpent(feature.id, feature.usesSpent + 1)
                .then(
                  (_) => ref.invalidate(
                    characterFeaturesProvider(feature.characterId),
                  ),
                ),
      onLongPress: feature.usesSpent == 0
          ? null
          : () => repo
                .setFeatureUsesSpent(feature.id, 0)
                .then(
                  (_) => ref.invalidate(
                    characterFeaturesProvider(feature.characterId),
                  ),
                ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${feature.usesSpent}/$max',
          style: theme.textTheme.labelSmall,
        ),
      ),
    );
  }
}

// --- Can puani ------------------------------------------------------------

class _HitPointsCard extends ConsumerStatefulWidget {
  const _HitPointsCard({required this.character});

  final Character character;

  @override
  ConsumerState<_HitPointsCard> createState() => _HitPointsCardState();
}

class _HitPointsCardState extends ConsumerState<_HitPointsCard> {
  int _amount = 1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final c = widget.character;
    final repo = ref.read(characterRepositoryProvider);
    final ratio = c.hitPointsMax == 0
        ? 0.0
        : c.hitPointsCurrent / c.hitPointsMax;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${c.hitPointsCurrent}',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: c.hitPointsCurrent == 0
                        ? theme.colorScheme.error
                        : null,
                  ),
                ),
                Text(
                  ' / ${c.hitPointsMax}',
                  style: theme.textTheme.titleMedium,
                ),
                if (c.temporaryHitPoints > 0) ...[
                  const SizedBox(width: 12),
                  Chip(
                    label: Text(l10n.sheetTempHp(c.temporaryHitPoints)),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
                const Spacer(),
                Text('HP', style: theme.textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 6,
              color: ratio <= 0.25
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => repo.applyDamage(c.id, _amount),
                    icon: const Icon(Icons.remove),
                    label: Text(l10n.sheetDamage),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 92,
                  child: TextFormField(
                    initialValue: '$_amount',
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(isDense: true),
                    onChanged: (v) => _amount = int.tryParse(v) ?? 0,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => repo.applyHealing(c.id, _amount),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.sheetHeal),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => repo.setTemporaryHitPoints(c.id, _amount),
                icon: const Icon(Icons.shield_outlined, size: 18),
                label: Text(l10n.sheetGrantTempHp),
              ),
            ),
            if (c.hitPointsCurrent == 0) ...[
              const Divider(height: 24),
              _DeathSaves(character: c),
            ],
          ],
        ),
      ),
    );
  }
}

/// Deneyim puani (XP) izleme. Seviye atlama elle yapildigi icin bu kart
/// yalnizca toplam XP'yi ve sonraki seviye esigine ilerlemeyi gosterir.
class _ExperienceCard extends StatelessWidget {
  const _ExperienceCard({required this.character});

  final Character character;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final xp = character.experiencePoints;
    final level = Experience.levelForXp(xp);
    final next = Experience.xpToNext(xp);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.military_tech_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(l10n.sheetExperience, style: theme.textTheme.titleMedium),
                const Spacer(),
                Text('$xp XP', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: Experience.progress(xp),
              minHeight: 6,
            ),
            const SizedBox(height: 6),
            Text(
              next == null
                  ? l10n.sheetXpMaxLevel(level)
                  : l10n.sheetXpToNext(next.nextLevel, next.xpNeeded),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeathSaves extends ConsumerWidget {
  const _DeathSaves({required this.character});

  final Character character;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(characterRepositoryProvider);
    final theme = Theme.of(context);
    final l10n = L10n.of(context);

    Widget row(String label, int value, Color color, ValueChanged<int> onSet) =>
        Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(label, style: theme.textTheme.bodySmall),
            ),
            for (var i = 1; i <= 3; i++)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  i <= value ? Icons.circle : Icons.circle_outlined,
                  size: 20,
                  color: i <= value ? color : theme.colorScheme.outline,
                ),
                // Dolu son daireye basmak geri alir.
                onPressed: () => onSet(i == value ? i - 1 : i),
              ),
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.sheetDeathSaves, style: theme.textTheme.titleSmall),
        row(
          l10n.sheetSuccess,
          character.deathSaveSuccesses,
          theme.colorScheme.primary,
          (v) => repo.setDeathSaves(character.id, successes: v),
        ),
        row(
          l10n.sheetFailure,
          character.deathSaveFailures,
          theme.colorScheme.error,
          (v) => repo.setDeathSaves(character.id, failures: v),
        ),
      ],
    );
  }
}

// --- Temel degerler -------------------------------------------------------

class _CoreStatsCard extends StatelessWidget {
  const _CoreStatsCard({required this.character, required this.stats});

  final Character character;
  final CharacterBuild stats;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final entries = <(String, String)>[
      ('AC', '${character.armorClassOverride ?? stats.armorClass}'),
      (l10n.sheetInitiative, formatSigned(stats.initiative)),
      (l10n.sheetSpeed, '${character.speedOverride ?? stats.baseSpeed} ft'),
      (l10n.sheetProficiency, formatSigned(stats.proficiencyBonus)),
      (l10n.sheetPassivePerception, '${stats.passivePerception}'),
      (l10n.sheetCarry, '${stats.carryCapacity} lb'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Wrap(
          alignment: WrapAlignment.spaceEvenly,
          runSpacing: 12,
          children: [
            for (final (label, value) in entries)
              SizedBox(
                width: 104,
                child: _Stat(label: label, value: value),
              ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value, style: theme.textTheme.titleLarge),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

// --- Yetenekler -----------------------------------------------------------

class _AbilitiesCard extends StatelessWidget {
  const _AbilitiesCard({required this.stats});

  final CharacterBuild stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            for (final a in Ability.values)
              Expanded(
                // Stat'a dokununca yetenek kontrolu (d20 + modifier) atilir.
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => rollAndShow(
                    context,
                    label: l10n.sheetAbilityCheck(a.label),
                    modifier: stats.abilityModifier(a),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        Text(a.short, style: theme.textTheme.labelSmall),
                        Text(
                          formatSigned(stats.abilityModifier(a)),
                          style: theme.textTheme.titleLarge,
                        ),
                        Text(
                          '${stats.abilities[a]}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --- Kurtarma atislari ----------------------------------------------------

class _SavesCard extends StatelessWidget {
  const _SavesCard({required this.stats});

  final CharacterBuild stats;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return _ListCard(
      title: l10n.sheetSavingThrows,
      children: [
        for (final a in Ability.values)
          _ProficiencyRow(
            proficient: stats.saveProficiencies.contains(a),
            label: a.label,
            value: stats.savingThrow(a),
            rollLabel: l10n.sheetAbilitySave(a.label),
          ),
      ],
    );
  }
}

// --- Beceriler ------------------------------------------------------------

class _SkillsCard extends StatelessWidget {
  const _SkillsCard({required this.stats});

  final CharacterBuild stats;

  @override
  Widget build(BuildContext context) => _ListCard(
    title: L10n.of(context).sheetSkills,
    children: [
      for (final s in Skill.values)
        _ProficiencyRow(
          proficient: stats.skillProficiencies.contains(s),
          expertise: stats.skillExpertise.contains(s),
          label: s.label,
          trailing: s.ability.short,
          value: stats.skillModifier(s),
          rollLabel: s.label,
        ),
    ],
  );
}

class _ProficiencyRow extends StatelessWidget {
  const _ProficiencyRow({
    required this.proficient,
    required this.label,
    required this.value,
    required this.rollLabel,
    this.expertise = false,
    this.trailing,
  });

  final bool proficient;
  final bool expertise;
  final String label;
  final int value;

  /// Zar gunlugunde/bildiriminde gorunecek ad ("Gizlilik", "DEX kurtarma").
  final String rollLabel;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Satira dokununca d20 + bu deger atilir; masada en cok istenen kisayol.
    return InkWell(
      onTap: () => rollAndShow(context, label: rollLabel, modifier: value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              expertise
                  ? Icons.star
                  : (proficient ? Icons.circle : Icons.circle_outlined),
              size: 14,
              color: proficient
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
            if (trailing != null)
              Text(
                trailing!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            const SizedBox(width: 10),
            SizedBox(
              width: 36,
              child: Text(
                formatSigned(value),
                textAlign: TextAlign.end,
                style: theme.textTheme.titleSmall,
              ),
            ),
            const Icon(Icons.casino_outlined, size: 16),
          ],
        ),
      ),
    );
  }
}

/// d20 + [modifier] atar ve sonucu bildirimle gosterir. DM tarafi yerel;
/// avantaj/dezavantaj icin basili tutmak yerine sadelik adina duz atis.
void rollAndShow(
  BuildContext context, {
  required String label,
  required int modifier,
}) {
  final roll = DiceRoller().d20(label: label, modifier: modifier);
  showRollResult(context, roll);
}

// --- Buyu yuvalari --------------------------------------------------------

class _SpellSlotsCard extends ConsumerWidget {
  const _SpellSlotsCard({required this.characterId, required this.character});

  final String characterId;
  final Character character;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots = ref.watch(spellSlotsProvider(characterId)).value ?? const {};
    final pact = ref.watch(pactMagicProvider(characterId)).value;
    if (slots.isEmpty && pact == null) return const SizedBox.shrink();

    final spent = _spentSlots(character);
    final repo = ref.read(characterRepositoryProvider);

    void toggle(int level, int index) {
      final used = spent[level] ?? 0;
      final next = {...spent};
      // Dolu son kutuya basmak yuvayi geri verir.
      next[level] = index + 1 == used ? index : index + 1;
      repo.setSpentSlots(characterId, next);
    }

    final l10n = L10n.of(context);
    return _ListCard(
      title: l10n.sheetSpellSlots,
      children: [
        for (final entry in (slots.keys.toList()..sort()))
          _SlotRow(
            label: l10n.sheetOrdinalLevel(entry),
            total: slots[entry]!,
            used: spent[entry] ?? 0,
            onToggle: (i) => toggle(entry, i),
          ),
        if (pact != null)
          _SlotRow(
            label: l10n.sheetPactMagic(pact.slotLevel),
            total: pact.count,
            // Pact yuvalari ortak havuzdan ayri sayilir; negatif anahtar
            // kullanarak ayni JSON'da cakismadan tutuluyor.
            used: spent[-1] ?? 0,
            onToggle: (i) => toggle(-1, i),
          ),
      ],
    );
  }

  static Map<int, int> _spentSlots(Character character) {
    final raw =
        jsonDecode(character.spellSlotsUsedJson) as Map<String, dynamic>;
    return {
      for (final e in raw.entries)
        if (int.tryParse(e.key) case final level?)
          if (e.value is int) level: e.value as int,
    };
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({
    required this.label,
    required this.total,
    required this.used,
    required this.onToggle,
  });

  final String label;
  final int total;
  final int used;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          for (var i = 0; i < total; i++)
            IconButton(
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              padding: EdgeInsets.zero,
              icon: Icon(
                i < used ? Icons.circle : Icons.circle_outlined,
                size: 18,
                color: i < used
                    ? theme.colorScheme.outlineVariant
                    : theme.colorScheme.primary,
              ),
              onPressed: () => onToggle(i),
            ),
          const Spacer(),
          Text('${total - used}/$total', style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

// --- Durumlar -------------------------------------------------------------

class _ConditionCard extends ConsumerWidget {
  const _ConditionCard({required this.character});

  final Character character;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final repo = ref.read(characterRepositoryProvider);
    final l10n = L10n.of(context);

    return _ListCard(
      title: l10n.sheetStatus,
      children: [
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.sheetInspiration),
          value: character.inspiration,
          onChanged: (v) => repo.setInspiration(character.id, v),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.sheetExhaustion,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: character.exhaustion > 0
                  ? () => repo.setExhaustion(
                      character.id,
                      character.exhaustion - 1,
                    )
                  : null,
            ),
            Text('${character.exhaustion}', style: theme.textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: character.exhaustion < 6
                  ? () => repo.setExhaustion(
                      character.id,
                      character.exhaustion + 1,
                    )
                  : null,
            ),
          ],
        ),
        if (character.exhaustion > 0)
          Text(
            l10n.sheetExhaustionPenalty(character.exhaustion),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
      ],
    );
  }
}

// --- Envanter -------------------------------------------------------------

/// Karakterin esyalari. DM buradan ekler, adet degistirir, giydirir, siler.
class _InventoryCard extends ConsumerWidget {
  const _InventoryCard({required this.characterId});

  final String characterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items =
        ref.watch(characterItemsProvider(characterId)).value ?? const [];
    final repo = ref.read(characterRepositoryProvider);
    final theme = Theme.of(context);
    final l10n = L10n.of(context);

    return _ListCard(
      title: l10n.sheetInventory,
      children: [
        if (items.isEmpty)
          Text(l10n.sheetBagEmpty, style: theme.textTheme.bodySmall)
        else
          for (final item in items) _ItemRow(item: item, repo: repo),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _addItem(context, ref),
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.sheetAddItem),
          ),
        ),
      ],
    );
  }

  Future<void> _addItem(BuildContext context, WidgetRef ref) async {
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
        );
  }
}

class _ItemRow extends ConsumerWidget {
  const _ItemRow({required this.item, required this.repo});

  final CharacterItem item;
  final CharacterRepository repo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final resolved = ref.watch(itemNameProvider(item)).value ?? '…';
    final name = resolved.isEmpty
        ? L10n.of(context).sheetUnknownItem
        : resolved;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: item.equipped
                ? L10n.of(context).sheetUnequip
                : L10n.of(context).sheetEquip,
            icon: Icon(
              item.equipped ? Icons.check_circle : Icons.circle_outlined,
              size: 18,
              color: item.equipped ? theme.colorScheme.primary : null,
            ),
            onPressed: () => repo.setEquipped(item.id, !item.equipped),
          ),
          Expanded(child: Text(name, style: theme.textTheme.bodyMedium)),
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
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: () => repo.removeItem(item.id),
          ),
        ],
      ),
    );
  }
}

/// Eklenecek esyanin secimi.
class _PickedItem {
  const _PickedItem({this.itemKey, this.magicItemKey, this.customName});

  final String? itemKey;
  final String? magicItemKey;
  final String? customName;
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
                    FilledButton(
                      onPressed: _customName.text.trim().isEmpty
                          ? null
                          : () => Navigator.pop(
                              context,
                              _PickedItem(customName: _customName.text.trim()),
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
    return asyncView(
      context,
      results,
      loading: const AppLoading(),
      onRetry: () => ref.invalidate(itemResultsProvider),
      data: (rows) => ListView.builder(
        controller: scrollController,
        itemCount: rows.length,
        itemBuilder: (context, i) => ListTile(
          dense: true,
          title: Text(rows[i].name),
          subtitle: Text(rows[i].category ?? ''),
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
    return asyncView(
      context,
      results,
      loading: const AppLoading(),
      onRetry: () => ref.invalidate(magicItemResultsProvider),
      data: (rows) => ListView.builder(
        controller: scrollController,
        itemCount: rows.length,
        itemBuilder: (context, i) => ListTile(
          dense: true,
          title: Text(rows[i].name),
          subtitle: Text(rows[i].rarity ?? ''),
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

// --- Ortak -----------------------------------------------------------------

class _ListCard extends StatelessWidget {
  const _ListCard({required this.title, required this.children, this.trailing});

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    ),
  );
}

/// "+3" / "-1" biciminde isaretli sayi.
String formatSigned(int value) => value >= 0 ? '+$value' : '$value';

/// Kisa/uzun dinlenme menusu (karakter kagidi ust cubugu).
class _RestButton extends ConsumerWidget {
  const _RestButton({required this.characterId});

  final String characterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(characterRepositoryProvider);
    final l10n = L10n.of(context);
    return PopupMenuButton<String>(
      tooltip: l10n.sheetRest,
      icon: const Icon(Icons.bedtime_outlined),
      itemBuilder: (_) => [
        PopupMenuItem(value: 'short', child: Text(l10n.sheetShortRest)),
        PopupMenuItem(value: 'long', child: Text(l10n.sheetLongRest)),
      ],
      onSelected: (action) async {
        final messenger = ScaffoldMessenger.of(context);
        if (action == 'long') {
          await repo.longRest(characterId);
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.sheetLongRestDone)),
          );
        } else {
          final spend = await repo.spendHitDie(characterId);
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                spend == null
                    ? l10n.sheetNoHitDice
                    : l10n.sheetHitDieHealed(spend.healed),
              ),
            ),
          );
        }
      },
    );
  }
}

/// Karakter portresi: yukle/degistir/kaldir. Oyuncular karakter sekmesinde gorur.
class _PortraitCard extends ConsumerWidget {
  const _PortraitCard({required this.character});

  final Character character;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final repo = ref.read(characterRepositoryProvider);
    final l10n = L10n.of(context);
    final path = character.portraitPath;

    Future<void> upload() async {
      final picked = await pickImageFile();
      if (picked == null) return;
      try {
        await repo.setPortrait(character.id, picked);
      } on FormatException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.message)));
        }
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CharacterAvatar(
              portraitPath: path,
              name: character.name,
              radius: 34,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.sheetPortrait, style: theme.textTheme.titleMedium),
                  Text(
                    l10n.sheetPortraitHint,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: path == null ? l10n.sheetUploadPhoto : l10n.sheetChange,
              icon: const Icon(Icons.upload),
              onPressed: upload,
            ),
            if (path != null)
              IconButton(
                tooltip: l10n.sheetRemove,
                icon: const Icon(Icons.delete_outline),
                onPressed: () => repo.removePortrait(character.id),
              ),
          ],
        ),
      ),
    );
  }
}

/// Bilinen buyuler; yalnizca buyu yapan karakterlerde gorunur.
class _KnownSpellsCard extends ConsumerWidget {
  const _KnownSpellsCard({required this.characterId});

  final String characterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final slots = ref.watch(spellSlotsProvider(characterId)).value ?? const {};
    final pact = ref.watch(pactMagicProvider(characterId)).value;
    // Buyu yuvasi yoksa (buyu yapmayan sinif) karti hic gosterme.
    if (slots.isEmpty && pact == null) return const SizedBox.shrink();

    final spells =
        ref.watch(knownSpellsProvider(characterId)).value ?? const [];
    final repo = ref.read(characterRepositoryProvider);
    final l10n = L10n.of(context);

    Future<void> addSpell() async {
      final classKeys = (await repo.classLevels(
        characterId,
      )).map((l) => l.classKey).toList();
      if (!context.mounted) return;
      final spell = await showDialog<Spell>(
        context: context,
        builder: (context) => _SpellPickerDialog(classKeys: classKeys),
      );
      if (spell == null) return;
      await repo.addKnownSpell(characterId, spell.key);
      ref.invalidate(knownSpellsProvider(characterId));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.sheetSpells,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: addSpell,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l10n.sheetAddSpell),
                ),
              ],
            ),
            if (spells.isEmpty)
              Text(l10n.sheetNoSpellsAdded, style: theme.textTheme.bodySmall)
            else
              for (final s in spells)
                Row(
                  children: [
                    SizedBox(
                      width: 26,
                      child: Text(
                        s.level == 0 ? 'C' : '${s.level}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        s.name,
                        style: TextStyle(
                          fontWeight: s.prepared || s.alwaysPrepared
                              ? FontWeight.bold
                              : null,
                        ),
                      ),
                    ),
                    if (s.alwaysPrepared)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          l10n.sheetAlways,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      )
                    else
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: s.prepared
                            ? l10n.sheetPrepared
                            : l10n.sheetPrepare,
                        icon: Icon(
                          s.prepared
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          size: 18,
                          color: s.prepared ? theme.colorScheme.primary : null,
                        ),
                        onPressed: () async {
                          await repo.togglePrepared(
                            characterId,
                            s.spellKey,
                            !s.prepared,
                          );
                          ref.invalidate(knownSpellsProvider(characterId));
                        },
                      ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: l10n.delete,
                      icon: const Icon(Icons.remove_circle_outline, size: 18),
                      onPressed: () async {
                        await repo.removeSpell(characterId, s.spellKey);
                        ref.invalidate(knownSpellsProvider(characterId));
                      },
                    ),
                  ],
                ),
          ],
        ),
      ),
    );
  }
}

/// Kutuphaneden buyu secme dialogu; secilen [Spell]'i doner. Varsayilan olarak
/// karakterin siniflarina uygun buyulere filtreler.
class _SpellPickerDialog extends ConsumerStatefulWidget {
  const _SpellPickerDialog({required this.classKeys});

  /// Karakterin sinif anahtarlari; filtre bunlara gore.
  final List<String> classKeys;

  @override
  ConsumerState<_SpellPickerDialog> createState() => _SpellPickerDialogState();
}

class _SpellPickerDialogState extends ConsumerState<_SpellPickerDialog> {
  final _search = TextEditingController();
  late bool _onlyClass = widget.classKeys.isNotEmpty;

  /// Anahtarin son parcasi ('srd-2024_wizard' -> 'wizard'); farkli onekleri
  /// eslestirmek icin.
  static String _tail(String key) =>
      key.contains('_') ? key.substring(key.lastIndexOf('_') + 1) : key;

  bool _matchesClass(Spell s) {
    final want = widget.classKeys.map(_tail).toSet();
    final has = s.classesCsv
        .split(',')
        .where((e) => e.isNotEmpty)
        .map(_tail)
        .toSet();
    return want.intersection(has).isNotEmpty;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(spellQueryProvider);
    final results = ref.watch(spellResultsProvider);
    final l10n = L10n.of(context);

    return AlertDialog(
      title: Text(l10n.sheetAddSpell),
      content: SizedBox(
        width: 460,
        height: 520,
        child: Column(
          children: [
            TextField(
              controller: _search,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.sheetSearchSpell,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => ref
                  .read(spellQueryProvider.notifier)
                  .set(query.copyWith(text: v)),
            ),
            if (widget.classKeys.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: FilterChip(
                    label: Text(l10n.sheetOnlyClassSpells),
                    selected: _onlyClass,
                    onSelected: (v) => setState(() => _onlyClass = v),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: asyncView(
                context,
                results,
                loading: const AppLoading(),
                data: (all) {
                  final rows = _onlyClass && widget.classKeys.isNotEmpty
                      ? all.where(_matchesClass).toList()
                      : all;
                  return rows.isEmpty
                      ? Center(child: Text(l10n.noResults))
                      : ListView.builder(
                          itemCount: rows.length,
                          itemBuilder: (context, i) {
                            final s = rows[i];
                            return ListTile(
                              dense: true,
                              title: Text(s.name),
                              subtitle: Text(
                                s.level == 0 ? 'Cantrip' : 'Level ${s.level}',
                              ),
                              onTap: () => Navigator.pop(context, s),
                            );
                          },
                        );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}

/// Hikaye ve kisilik alanlari (2024 kagidi): serbest metin, DM duzenler.
class _StoryCard extends ConsumerStatefulWidget {
  const _StoryCard({required this.character});

  final Character character;

  @override
  ConsumerState<_StoryCard> createState() => _StoryCardState();
}

class _StoryCardState extends ConsumerState<_StoryCard> {
  late final _notes = TextEditingController(text: widget.character.notes);
  late final _appearance = TextEditingController(
    text: widget.character.appearance,
  );
  late final _personality = TextEditingController(
    text: widget.character.personality,
  );
  late final _ideal = TextEditingController(text: widget.character.ideal);
  late final _bond = TextEditingController(text: widget.character.bond);
  late final _flaw = TextEditingController(text: widget.character.flaw);
  bool _dirty = false;

  @override
  void dispose() {
    for (final c in [_notes, _appearance, _personality, _ideal, _bond, _flaw]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    await ref
        .read(characterRepositoryProvider)
        .setStory(
          widget.character.id,
          notes: _notes.text,
          appearance: _appearance.text,
          personality: _personality.text,
          ideal: _ideal.text,
          bond: _bond.text,
          flaw: _flaw.text,
        );
    if (mounted) setState(() => _dirty = false);
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int lines = 2,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TextField(
        controller: controller,
        maxLines: lines,
        onChanged: (_) {
          if (!_dirty) setState(() => _dirty = true);
        },
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.sheetStory,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (_dirty)
                  FilledButton(onPressed: _save, child: Text(l10n.save)),
              ],
            ),
            _field(l10n.sheetBackstory, _notes, lines: 4),
            _field(l10n.sheetAppearance, _appearance),
            _field(l10n.sheetPersonality, _personality),
            _field(l10n.sheetIdeal, _ideal, lines: 1),
            _field(l10n.sheetBond, _bond, lines: 1),
            _field(l10n.sheetFlaw, _flaw, lines: 1),
          ],
        ),
      ),
    );
  }
}
