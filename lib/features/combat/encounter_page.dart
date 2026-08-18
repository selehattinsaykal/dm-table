import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ui/async_view.dart';
import '../../app/ui/ui.dart';
import '../../data/db/combat_tables.dart';
import '../../data/db/database.dart';
import '../../domain/rules/challenge_rating.dart';
import '../../domain/rules/combat_conditions.dart';
import '../../domain/rules/encounter_budget.dart';
import '../../domain/rules/legendary_actions.dart';
import '../../l10n/app_localizations.dart';
import '../characters/character_providers.dart';
import '../compendium/compendium_providers.dart';
import '../compendium/condition_providers.dart';
import '../compendium/conditions_tab.dart';
import '../compendium/detail_sheets.dart';
import '../session/session_log_providers.dart';
import 'combat_providers.dart';
import 'encounter_panels.dart';

/// Savas ekrani.
///
/// Masada tek elle kullanildigi icin en sik islemler (hasar, sira ilerletme)
/// tek dokunusla erisilebilir; stat blok ayni ekrandan alttan aciliyor ki
/// DM listedeki yerini kaybetmesin.
class EncounterPage extends ConsumerWidget {
  const EncounterPage({required this.encounterId, super.key});

  final String encounterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final encounter = ref.watch(encounterProvider(encounterId)).value;
    final combatants = ref.watch(combatantsProvider(encounterId));
    final l10n = L10n.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(encounter?.name ?? l10n.combatEncounterName),
        actions: [
          // Dar ekranda yan paneller kolona sigmaz; ayni widget'lar burada
          // sheet olarak acilir (bkz. `encounter_panels.dart`).
          if (!_isWide(context)) ...[
            IconButton(
              tooltip: l10n.encPanelBriefing,
              icon: const Icon(Icons.description_outlined),
              onPressed: () => _openPanelSheet(
                context,
                EncounterBriefingPanel(encounterId: encounterId),
              ),
            ),
            IconButton(
              tooltip: l10n.encPanelLoot,
              icon: const Icon(Icons.diamond_outlined),
              onPressed: () => _openPanelSheet(
                context,
                EncounterLootPanel(encounterId: encounterId),
              ),
            ),
          ],
          IconButton(
            tooltip: l10n.combatAwardXp,
            icon: const Icon(Icons.military_tech_outlined),
            onPressed: () => _awardXp(context, ref),
          ),
          IconButton(
            tooltip: l10n.combatAddMonster,
            icon: const Icon(Icons.pest_control),
            onPressed: () => _addMonster(context, ref),
          ),
          IconButton(
            tooltip: l10n.combatAddParty,
            icon: const Icon(Icons.group_add),
            onPressed: () => _addParty(context, ref),
          ),
        ],
      ),
      body: asyncView(
        context,
        combatants,
        loading: const AppLoading(),
        // Ana panel (initiative) her zaman ana alan; yan paneller yalnizca
        // genis ekranda saginda bir kolon olarak durur.
        data: (rows) => _isWide(context)
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _mainPanel(context, ref, encounter, rows)),
                  const VerticalDivider(width: 1),
                  SizedBox(
                    width: _sidePanelWidth,
                    child: ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        EncounterBriefingPanel(encounterId: encounterId),
                        EncounterLootPanel(encounterId: encounterId),
                      ],
                    ),
                  ),
                ],
              )
            : _mainPanel(context, ref, encounter, rows),
      ),
    );
  }

  /// Yan panellerin sigacagi esik. `Breakpoints.rail` (720) yalnizca yan
  /// navigasyon icin; initiative listesi + 340px panel ondan fazlasini ister.
  static const _wideBreakpoint = 1100.0;
  static const _sidePanelWidth = 340.0;

  static bool _isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= _wideBreakpoint;

  static Future<void> _openPanelSheet(BuildContext context, Widget panel) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: panel,
          ),
        ),
      );

  /// Savas takibinin ASIL paneli: tur cubugu, butce ve initiative listesi.
  Widget _mainPanel(
    BuildContext context,
    WidgetRef ref,
    Encounter? encounter,
    List<Combatant> rows,
  ) {
    final repo = ref.read(combatRepositoryProvider);
    final l10n = L10n.of(context);
    return Column(
      children: [
        if (encounter != null)
          _TurnBar(
            encounter: encounter,
            combatants: rows,
            onStart: () {
              repo.start(encounterId);
            },
            onNext: () async {
              final messenger = ScaffoldMessenger.of(context);
              final result = await repo.advanceTurn(encounterId);
              if (result.expired.isNotEmpty) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      l10n.combatConditionsExpired(
                        result.combatantName ?? '',
                        result.expired.join(', '),
                      ),
                    ),
                  ),
                );
              }
            },
            onEnd: () {
              repo.end(encounterId);
            },
          ),
        _BudgetBar(encounterId: encounterId),
        Expanded(
          child: rows.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      l10n.combatAddHint,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: rows.length,
                  itemBuilder: (context, i) => _CombatantTile(
                    combatant: rows[i],
                    isActive:
                        encounter != null &&
                        encounter.started &&
                        encounter.activeIndex == i,
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _addMonster(BuildContext context, WidgetRef ref) async {
    final picked =
        await showModalBottomSheet<({Monster monster, int count, bool roll})>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (context) => const _MonsterPicker(),
        );
    if (picked == null) return;
    await ref
        .read(combatRepositoryProvider)
        .addMonsters(
          encounterId: encounterId,
          monster: picked.monster,
          count: picked.count,
          rollHitPoints: picked.roll,
        );
  }

  Future<void> _addParty(BuildContext context, WidgetRef ref) async {
    final characters = ref.read(charactersProvider).value ?? const [];
    if (characters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.of(context).combatNeedCharacter)),
      );
      return;
    }
    await ref
        .read(combatRepositoryProvider)
        .addCharacters(encounterId: encounterId, characters: characters);
  }

  /// Karsilasmadaki toplam canavar XP'sini partiye esit boler, her oyuncu
  /// karakterine ekler ve oturum gunlugune yazar.
  Future<void> _awardXp(BuildContext context, WidgetRef ref) async {
    final l10n = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final assessment = await ref.read(
      encounterBudgetProvider(encounterId).future,
    );
    final combatants = await ref
        .read(combatRepositoryProvider)
        .combatants(encounterId);
    final pcIds = combatants
        .where((c) => c.kind == CombatantKind.player && c.characterId != null)
        .map((c) => c.characterId!)
        .toList();

    if (assessment.monsterXp <= 0 || pcIds.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.combatAwardXpNone)));
      return;
    }
    final each = assessment.monsterXp ~/ pcIds.length;
    if (!context.mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.combatAwardXp),
        content: Text(
          l10n.combatAwardXpConfirm(assessment.monsterXp, pcIds.length, each),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.combatAwardXp),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final charRepo = ref.read(characterRepositoryProvider);
    for (final id in pcIds) {
      await charRepo.addExperience(id, each);
    }
    await ref
        .read(sessionLogRepositoryProvider)
        .add(l10n.logXpAwarded(assessment.monsterXp, pcIds.length, each));
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.combatAwardXpDone(each))),
    );
  }
}

/// Tur/round durumu ve sira ilerletme.
class _TurnBar extends StatelessWidget {
  const _TurnBar({
    required this.encounter,
    required this.combatants,
    required this.onStart,
    required this.onNext,
    required this.onEnd,
  });

  final Encounter encounter;
  final List<Combatant> combatants;
  final VoidCallback onStart;
  final VoidCallback onNext;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final active =
        encounter.started &&
            encounter.activeIndex < combatants.length &&
            combatants.isNotEmpty
        ? combatants[encounter.activeIndex]
        : null;

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: Row(
          children: [
            if (!encounter.started)
              Expanded(
                child: Text(
                  l10n.combatEditInitiative,
                  style: theme.textTheme.bodyMedium,
                ),
              )
            else ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.combatRoundN(encounter.round),
                    style: theme.textTheme.labelMedium,
                  ),
                  Text(active?.name ?? '—', style: theme.textTheme.titleMedium),
                ],
              ),
              const Spacer(),
            ],
            if (encounter.started) ...[
              TextButton.icon(
                onPressed: onEnd,
                icon: const Icon(Icons.stop_circle_outlined),
                label: Text(l10n.combatEnd),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: onNext,
                icon: const Icon(Icons.skip_next),
                label: Text(l10n.combatNext),
              ),
            ] else
              FilledButton.icon(
                onPressed: combatants.isEmpty ? null : onStart,
                icon: const Icon(Icons.play_arrow),
                label: Text(l10n.combatStart),
              ),
          ],
        ),
      ),
    );
  }
}

/// Karsilasma zorluk cubugu: parti seviyelerine gore 2024 XP butcesine karsi
/// toplam canavar XP'sini gosterir (Onemsiz/Kolay/Orta/Zor).
class _BudgetBar extends ConsumerWidget {
  const _BudgetBar({required this.encounterId});

  final String encounterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final assessment = ref.watch(encounterBudgetProvider(encounterId)).value;
    // Parti yoksa ya da hic dusman yoksa gosterme.
    if (assessment == null || !assessment.hasParty) {
      return const SizedBox.shrink();
    }
    if (assessment.monsterXp <= 0 && assessment.uncounted == 0) {
      return const SizedBox.shrink();
    }

    final (low, moderate, high) = assessment.budget;
    final (label, color) = _difficultyStyle(theme, l10n, assessment.difficulty);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Icon(Icons.local_fire_department_outlined, size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${l10n.combatDifficulty}: ',
                        style: theme.textTheme.labelMedium,
                      ),
                      Text(
                        label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    l10n.combatBudgetSummary(
                      assessment.monsterXp,
                      low,
                      moderate,
                      high,
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                  if (assessment.uncounted > 0)
                    Text(
                      l10n.combatUncounted(assessment.uncounted),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  (String, Color) _difficultyStyle(
    ThemeData theme,
    L10n l10n,
    EncounterDifficulty difficulty,
  ) => switch (difficulty) {
    EncounterDifficulty.trivial => (
      l10n.combatDiffTrivial,
      theme.colorScheme.outline,
    ),
    EncounterDifficulty.low => (l10n.combatDiffLow, Colors.green),
    EncounterDifficulty.moderate => (l10n.combatDiffModerate, Colors.orange),
    EncounterDifficulty.high => (l10n.combatDiffHigh, theme.colorScheme.error),
    EncounterDifficulty.deadly => (l10n.combatDiffDeadly, Colors.red.shade900),
  };
}

class _CombatantTile extends ConsumerWidget {
  const _CombatantTile({required this.combatant, required this.isActive});

  final Combatant combatant;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final repo = ref.read(combatRepositoryProvider);
    final l10n = L10n.of(context);
    final conditions = parseConditions(combatant.conditionsJson);

    final ratio = combatant.hitPointsMax == 0
        ? 1.0
        : combatant.hitPointsCurrent / combatant.hitPointsMax;

    return Container(
      decoration: BoxDecoration(
        color: isActive
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
            : null,
        border: Border(
          left: BorderSide(
            width: 4,
            color: isActive ? theme.colorScheme.primary : Colors.transparent,
          ),
          bottom: BorderSide(color: theme.dividerColor, width: 0.5),
        ),
      ),
      child: Opacity(
        opacity: combatant.defeated ? 0.45 : 1,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Column(
            children: [
              Row(
                children: [
                  _InitiativeBadge(combatant: combatant),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                combatant.name,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  decoration: combatant.defeated
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                            if (combatant.concentrating) ...[
                              const SizedBox(width: 6),
                              Tooltip(
                                message:
                                    combatant.concentrationNote ??
                                    l10n.combatConcentration,
                                child: Icon(
                                  Icons.center_focus_strong,
                                  size: 16,
                                  color: theme.colorScheme.tertiary,
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          [
                            '${combatant.hitPointsCurrent}/${combatant.hitPointsMax} HP',
                            if (combatant.temporaryHitPoints > 0)
                              '+${combatant.temporaryHitPoints}',
                            if (combatant.armorClass != null)
                              'AC ${combatant.armorClass}',
                          ].join(' · '),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  _DamageButtons(combatant: combatant),
                  PopupMenuButton<String>(
                    itemBuilder: (context) => [
                      if (combatant.monsterKey != null)
                        PopupMenuItem(
                          value: 'stat',
                          child: Text(l10n.combatStatBlock),
                        ),
                      PopupMenuItem(
                        value: 'conditions',
                        child: Text(l10n.combatEditConditions),
                      ),
                      if (combatant.monsterKey != null)
                        PopupMenuItem(
                          value: 'legendary',
                          child: Text(l10n.combatLegendaryActions),
                        ),
                      PopupMenuItem(
                        value: 'concentration',
                        child: Text(
                          combatant.concentrating
                              ? l10n.combatEndConcentration
                              : l10n.combatStartConcentration,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'defeat',
                        child: Text(
                          combatant.defeated
                              ? l10n.combatRevive
                              : l10n.combatMarkDefeated,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'remove',
                        child: Text(l10n.combatRemove),
                      ),
                    ],
                    onSelected: (action) => _onAction(context, ref, action),
                  ),
                ],
              ),
              if (combatant.hitPointsMax > 0) ...[
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: ratio.clamp(0.0, 1.0),
                  minHeight: 4,
                  color: ratio <= 0.25
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
              ],
              // Efsanevi eylem / direnc sayaclari (yalnizca DM gorur;
              // protokole hic girmez).
              if (combatant.legendaryMax != null ||
                  combatant.legendaryResistMax != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (combatant.legendaryMax != null)
                        _LegendaryPips(
                          label: l10n.combatLegendaryShort,
                          max: combatant.legendaryMax!,
                          spent: combatant.legendarySpent,
                          onChanged: (spent) => ref
                              .read(combatRepositoryProvider)
                              .setLegendarySpent(combatant.id, spent),
                        ),
                      if (combatant.legendaryResistMax != null)
                        _LegendaryPips(
                          label: l10n.combatLegendaryResistShort,
                          max: combatant.legendaryResistMax!,
                          spent: combatant.legendaryResistSpent,
                          resistance: true,
                          onChanged: (spent) => ref
                              .read(combatRepositoryProvider)
                              .setLegendaryResistSpent(combatant.id, spent),
                        ),
                    ],
                  ),
                ),
              ],
              if (conditions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 6,
                    children: [
                      for (final c in conditions)
                        // Uzun bas -> kural metni. Dokunma zaten sure
                        // duzenlemede kullanildigi icin referans buraya bagli.
                        GestureDetector(
                          onLongPress: () =>
                              showConditionByName(context, ref, c.name),
                          child: InputChip(
                            // Sureli durumlar "Ad · n" gosterir; dokununca sure
                            // duzenlenir (tur basinda otomatik azalir).
                            label: Text(
                              c.rounds == null
                                  ? _conditionLabel(ref, l10n, c.name)
                                  : '${_conditionLabel(ref, l10n, c.name)} · ${c.rounds}',
                            ),
                            visualDensity: VisualDensity.compact,
                            tooltip: l10n.combatConditionLongPressHint,
                            onPressed: () => _editConditionDuration(
                              context,
                              ref,
                              combatant,
                              conditions,
                              c,
                            ),
                            onDeleted: () => repo.setConditionsTyped(
                              combatant.id,
                              conditions
                                  .where((x) => x.name != c.name)
                                  .toList(),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Bir durumun tur suresini duzenler (bos = suresiz). Sure girilince durum
  /// her turun basinda bir azalir ve 0'da kalkar.
  Future<void> _editConditionDuration(
    BuildContext context,
    WidgetRef ref,
    Combatant combatant,
    List<CombatCondition> conditions,
    CombatCondition condition,
  ) async {
    final l10n = L10n.of(context);
    final controller = TextEditingController(
      text: condition.rounds?.toString() ?? '',
    );
    final rounds = await showDialog<int?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(condition.name),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l10n.combatDurationRounds,
            hintText: l10n.combatDurationUnlimited,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              // Bos ya da gecersiz -> suresiz (null); pozitif sayi -> sure.
              final n = int.tryParse(text);
              Navigator.pop(context, n != null && n > 0 ? n : null);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    final updated = [
      for (final c in conditions)
        if (c.name == condition.name)
          CombatCondition(c.name, rounds: rounds)
        else
          c,
    ];
    await ref
        .read(combatRepositoryProvider)
        .setConditionsTyped(combatant.id, updated);
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    final repo = ref.read(combatRepositoryProvider);
    switch (action) {
      case 'stat':
        final monster = await ref.read(
          monsterByKeyProvider(combatant.monsterKey!).future,
        );
        if (monster != null && context.mounted) {
          await showDetailSheet(context, MonsterDetail(monster: monster));
        }
      case 'conditions':
        if (!context.mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => _ConditionDialog(combatant: combatant),
        );
      case 'legendary':
        final monster = await ref.read(
          monsterByKeyProvider(combatant.monsterKey!).future,
        );
        if (monster != null && context.mounted) {
          await showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            isScrollControlled: true,
            builder: (_) =>
                _LegendarySheet(combatant: combatant, monster: monster),
          );
        }
      case 'concentration':
        await repo.setConcentration(
          combatant.id,
          value: !combatant.concentrating,
        );
      case 'defeat':
        await repo.setDefeated(combatant.id, !combatant.defeated);
      case 'remove':
        await repo.removeCombatant(combatant.id);
    }
  }
}

/// Durum adının gösterilecek hâli.
///
/// Durumlar `Combatants.conditionsJson` içinde İNGİLİZCE adla saklanır
/// (Türkçeleştirmek mevcut savaş verisini bozardı); yalnızca gösterim çevrilir.
/// Çeviri henüz yüklenmediyse İngilizce ad kullanılır.
String _conditionLabel(WidgetRef ref, L10n l10n, String englishName) {
  final labels = ref
      .watch(conditionLabelProvider(l10n.localeName == 'tr'))
      .value;
  return labels?[englishName] ?? englishName;
}

/// Efsanevi eylem / direnç sayacı: dokun = harca, uzun bas = sıfırla.
///
/// Karakter kâğıdındaki `_FeatureUsesTracker` ile aynı etkileşim düzeni.
class _LegendaryPips extends StatelessWidget {
  const _LegendaryPips({
    required this.label,
    required this.max,
    required this.spent,
    required this.onChanged,
    this.resistance = false,
  });

  final String label;
  final int max;
  final int spent;
  final ValueChanged<int> onChanged;

  /// Direnç sayacı farklı renkte; ikisi yan yana karışmasın.
  final bool resistance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final color = resistance
        ? theme.colorScheme.tertiary
        : theme.colorScheme.primary;
    final remaining = max - spent;

    return Tooltip(
      message: l10n.combatLegendaryTooltip(remaining, max),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: spent >= max ? null : () => onChanged(spent + 1),
        onLongPress: spent == 0 ? null : () => onChanged(0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(color: color),
              ),
              const SizedBox(width: 6),
              // Cok yuksek hakta pip yerine sayi (6 direnc = 6 elmas cok yer
              // kaplar degil ama 10+ olursa tasar).
              if (max > 6)
                Text(
                  '$remaining/$max',
                  style: theme.textTheme.labelSmall?.copyWith(color: color),
                )
              else
                for (var i = 0; i < max; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Icon(
                      i < remaining ? Icons.diamond : Icons.diamond_outlined,
                      size: 12,
                      color: i < remaining
                          ? color
                          : theme.colorScheme.outlineVariant,
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Canavarın efsanevi eylemleri + tur başına hak düzenleme.
class _LegendarySheet extends ConsumerWidget {
  const _LegendarySheet({required this.combatant, required this.monster});

  final Combatant combatant;
  final Monster monster;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final data = jsonDecode(monster.dataJson) as Map<String, dynamic>;
    final actions = legendaryActionsOf(data);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.combatLegendaryActions,
                style: theme.textTheme.titleLarge,
              ),
              Text(combatant.name, style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    l10n.combatLegendaryPerRound,
                    style: theme.textTheme.labelLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: (combatant.legendaryMax ?? 0) <= 0
                        ? null
                        : () => ref
                              .read(combatRepositoryProvider)
                              .setLegendaryMax(
                                combatant.id,
                                combatant.legendaryMax! - 1,
                              ),
                  ),
                  Text(
                    '${combatant.legendaryMax ?? 0}',
                    style: theme.textTheme.titleMedium,
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: (combatant.legendaryMax ?? 0) >= 9
                        ? null
                        : () => ref
                              .read(combatRepositoryProvider)
                              .setLegendaryMax(
                                combatant.id,
                                (combatant.legendaryMax ?? 0) + 1,
                              ),
                  ),
                ],
              ),
              Text(
                l10n.combatLegendaryResetHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const Divider(height: 24),
              Flexible(
                child: actions.isEmpty
                    ? Text(
                        l10n.combatLegendaryNone,
                        style: theme.textTheme.bodySmall,
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          for (final action in actions)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    action.cost > 1
                                        ? '${action.name} '
                                              '(${l10n.combatLegendaryCost(action.cost)})'
                                        : action.name,
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  if (action.desc.isNotEmpty)
                                    Text(
                                      action.desc,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// İnisiyatif rozeti; savas baslamadan once dokununca degistirilebilir.
class _InitiativeBadge extends ConsumerWidget {
  const _InitiativeBadge({required this.combatant});

  final Combatant combatant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    return InkWell(
      onTap: () async {
        final controller = TextEditingController(
          text: '${combatant.initiative}',
        );
        final value = await showDialog<int>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.combatInitiativeTitle(combatant.name)),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(context, int.tryParse(controller.text)),
                child: Text(l10n.save),
              ),
            ],
          ),
        );
        if (value != null) {
          await ref
              .read(combatRepositoryProvider)
              .setInitiative(combatant.id, value);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        // Inisiyatifini atmamis oyuncu: sayi yerine bekleyen zar simgesi
        // (oyuncu kendi panelinden atar; DM yine dokunup elle girebilir).
        child: combatant.initiativeRolled
            ? Text(
                '${combatant.initiative}',
                style: theme.textTheme.titleMedium,
              )
            : Icon(Icons.casino_outlined, color: theme.colorScheme.outline),
      ),
    );
  }
}

/// Hasar/iyilestirme; miktar tek alanda tutulur, iki buton onu uygular.
class _DamageButtons extends ConsumerStatefulWidget {
  const _DamageButtons({required this.combatant});

  final Combatant combatant;

  @override
  ConsumerState<_DamageButtons> createState() => _DamageButtonsState();
}

class _DamageButtonsState extends ConsumerState<_DamageButtons> {
  int _amount = 1;

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(combatRepositoryProvider);
    final l10n = L10n.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: l10n.combatDamage,
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: () {
            repo.applyDamage(widget.combatant.id, _amount);
          },
        ),
        SizedBox(
          width: 46,
          child: TextFormField(
            initialValue: '$_amount',
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
            ),
            onChanged: (v) => _amount = int.tryParse(v) ?? 0,
          ),
        ),
        IconButton(
          tooltip: l10n.combatHeal,
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () {
            repo.applyHealing(widget.combatant.id, _amount);
          },
        ),
      ],
    );
  }
}

class _ConditionDialog extends ConsumerWidget {
  const _ConditionDialog({required this.combatant});

  final Combatant combatant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A5e'ye ozel kayitlar elenmis liste (Ingilizce adlar: saklama bicimi).
    final all = ref.watch(conditionNamesEnProvider).value ?? const [];
    final l10n = L10n.of(context);
    // Mevcut durumlar (sureleriyle); ac/kapa yaparken sureler korunur.
    final current = parseConditions(combatant.conditionsJson);
    final currentNames = current.map((c) => c.name).toSet();

    return AlertDialog(
      title: Text(l10n.combatConditionsTitle(combatant.name)),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.combatConditionLongPressHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in all)
                    // Uzun bas -> kural metni; dokunma zaten sec/birak.
                    GestureDetector(
                      onLongPress: () => showConditionByName(context, ref, c),
                      child: FilterChip(
                        label: Text(_conditionLabel(ref, l10n, c)),
                        selected: currentNames.contains(c),
                        onSelected: (on) {
                          final next = [
                            for (final existing in current)
                              if (existing.name != c) existing,
                            // Saklama ADI HEP INGILIZCE: mevcut savas verisi
                            // ve tickConditions bununla eslesiyor.
                            if (on) CombatCondition(c),
                          ];
                          ref
                              .read(combatRepositoryProvider)
                              .setConditionsTyped(combatant.id, next);
                          Navigator.pop(context);
                        },
                      ),
                    ),
                ],
              ),
            ],
          ),
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

/// Kutuphaneden canavar secip adet ve HP secenegi belirler.
class _MonsterPicker extends ConsumerStatefulWidget {
  const _MonsterPicker();

  @override
  ConsumerState<_MonsterPicker> createState() => _MonsterPickerState();
}

class _MonsterPickerState extends ConsumerState<_MonsterPicker> {
  int _count = 1;
  bool _roll = false;

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(monsterQueryProvider);
    final results = ref.watch(monsterResultsProvider);
    final notifier = ref.read(monsterQueryProvider.notifier);
    final l10n = L10n.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            autofocus: true,
            decoration: InputDecoration(
              hintText: l10n.combatSearchMonster,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => notifier.set(query.copyWith(text: v)),
          ),
        ),
        Row(
          children: [
            const SizedBox(width: 16),
            Text(l10n.combatCount),
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: _count > 1 ? () => setState(() => _count--) : null,
            ),
            Text('$_count'),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => setState(() => _count++),
            ),
            const Spacer(),
            Row(
              children: [
                Text(l10n.combatRollHp),
                Switch(
                  value: _roll,
                  onChanged: (v) => setState(() => _roll = v),
                ),
              ],
            ),
            const SizedBox(width: 8),
          ],
        ),
        const Divider(height: 1),
        Expanded(
          child: asyncView(
            context,
            results,
            loading: const AppLoading(),
            data: (rows) => ListView.builder(
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final m = rows[i];
                return ListTile(
                  dense: true,
                  title: Text(m.name),
                  subtitle: Text(
                    '${[m.size, m.creatureType].whereType<String>().join(' ')}'
                    ' · ${m.hitPoints ?? '—'} HP',
                  ),
                  trailing: Text('CR ${formatCr(m.challengeRating)}'),
                  onTap: () => Navigator.pop(context, (
                    monster: m,
                    count: _count,
                    roll: _roll,
                  )),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
