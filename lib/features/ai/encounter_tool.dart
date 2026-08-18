import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ai_settings_provider.dart';
import '../../data/combat_repository.dart';
import '../../data/db/database.dart';
import '../../data/loot_resolver.dart';
import '../../data/providers.dart';
import '../../domain/rules/challenge_rating.dart';
import '../../domain/rules/encounter_budget.dart';
import '../../l10n/app_localizations.dart';
import '../characters/character_providers.dart';
import '../combat/combat_providers.dart';
import '../world/world_providers.dart';
import 'ai_tools_shared.dart';
import 'encounter_generator.dart';

/// AI Karşılaşma Üreteci.
///
/// Üretilen canavar adları GERÇEK savaşa dönüştürülebilsin diye modele
/// kütüphaneden çekilmiş bir aday listesi verilir (bkz. [buildEncounterPrompt]);
/// XP hedefi ise 2024 SRD bütçesinden ([EncounterBudget.partyBudget]) gelir.
class EncounterTool extends ConsumerStatefulWidget {
  const EncounterTool({super.key});

  @override
  ConsumerState<EncounterTool> createState() => _EncounterToolState();
}

class _EncounterToolState extends ConsumerState<EncounterTool> {
  final _environment = TextEditingController();
  final _run = AiRunState();

  int _partySize = 4;
  int _partyLevel = 3;

  /// Hedef zorluk: bütçenin hangi eşiği alınacak.
  EncounterDifficulty _difficulty = EncounterDifficulty.moderate;
  EncounterObjective _objective = EncounterObjective.any;
  EncounterSetup _setup = EncounterSetup.any;

  /// Karşılaşmanın geçtiği yer (kampanyadan, isteğe bağlı).
  String? _locationId;

  /// Seçili yeri isteme kısa bağlam olarak biçimlendirir.
  String? _locationContext() {
    final id = _locationId;
    if (id == null) return null;
    final locations =
        ref.read(allLocationsProvider).value ?? const <Location>[];
    final loc = locations.where((l) => l.id == id).firstOrNull;
    if (loc == null) return null;
    final desc = loc.description.trim();
    if (desc.isEmpty) return loc.name;
    final clipped = desc.length <= 160
        ? desc
        : '${desc.substring(0, 160).trimRight()}…';
    return '${loc.name} — $clipped';
  }

  @override
  void initState() {
    super.initState();
    // Masadaki gercek parti varsa varsayilanlari ondan al.
    final characters = ref.read(charactersProvider).value;
    if (characters != null && characters.isNotEmpty) {
      _partySize = characters.length;
    }
  }

  @override
  void dispose() {
    _environment.dispose();
    super.dispose();
  }

  String _objectiveLabel(L10n l10n, EncounterObjective o) => switch (o) {
    EncounterObjective.any => l10n.encObjAny,
    EncounterObjective.defeat => l10n.encObjDefeat,
    EncounterObjective.survive => l10n.encObjSurvive,
    EncounterObjective.protect => l10n.encObjProtect,
    EncounterObjective.retrieve => l10n.encObjRetrieve,
    EncounterObjective.escape => l10n.encObjEscape,
    EncounterObjective.stop => l10n.encObjStop,
  };

  String _setupLabel(L10n l10n, EncounterSetup s) => switch (s) {
    EncounterSetup.any => l10n.encSetupAny,
    EncounterSetup.ambush => l10n.encSetupAmbush,
    EncounterSetup.ambushed => l10n.encSetupAmbushed,
    EncounterSetup.patrol => l10n.encSetupPatrol,
    EncounterSetup.lair => l10n.encSetupLair,
    EncounterSetup.guardPost => l10n.encSetupGuard,
    EncounterSetup.negotiable => l10n.encSetupNegotiable,
  };

  String _difficultyLabel(L10n l10n, EncounterDifficulty d) => switch (d) {
    EncounterDifficulty.trivial => l10n.questDiffVeryEasy,
    EncounterDifficulty.low => l10n.questDiffEasy,
    EncounterDifficulty.moderate => l10n.questDiffMedium,
    EncounterDifficulty.high => l10n.questDiffHard,
    EncounterDifficulty.deadly => l10n.questDiffVeryHard,
  };

  /// Secili zorluga karsilik gelen parti XP butcesi.
  int _xpBudget() {
    final levels = List.filled(_partySize, _partyLevel);
    final (low, moderate, high) = EncounterBudget.partyBudget(levels);
    return switch (_difficulty) {
      // "Onemsiz" icin dusuk esigin altini hedefle.
      EncounterDifficulty.trivial => (low * 0.6).round(),
      EncounterDifficulty.low => low,
      EncounterDifficulty.moderate => moderate,
      EncounterDifficulty.high => high,
      EncounterDifficulty.deadly => EncounterBudget.deadlyBudget(high),
    };
  }

  Future<void> _generate() async {
    final l10n = L10n.of(context);
    final budget = _xpBudget();

    // Aday listesi: parti seviyesine gore makul CR araligi. Model yalniz
    // bunlardan secebildigi icin uretilen her ad kutuphanede COZULUR.
    final compendium = ref.read(compendiumRepositoryProvider);
    final monsters = await compendium.searchMonsters(
      maxCr: (_partyLevel + 3).toDouble(),
      limit: 90,
    );
    final candidates = <EncounterCandidate>[
      for (final m in monsters)
        if ((m.experiencePoints ?? 0) > 0)
          (
            name: m.name,
            challenge: formatCr(m.challengeRating),
            xp: m.experiencePoints!,
          ),
    ];

    if (candidates.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.encounterNoCandidates)));
      }
      return;
    }

    final built = buildEncounterPrompt(
      partySize: _partySize,
      partyLevel: _partyLevel,
      difficultyLabel: _difficultyLabel(l10n, _difficulty),
      xpBudget: budget,
      candidates: candidates,
      languageName: l10n.localeName == 'tr' ? 'Türkçe' : 'English',
      environment: _environment.text,
      objective: _objective,
      setup: _setup,
      locationContext: _locationContext(),
    );
    if (!mounted) return;
    await _run.generate(
      context,
      ref,
      built.system,
      built.user,
      () => setState(() {}),
      // Hedef + takviye + olcekleme + hazine ek bolumler; varsayilan butce
      // JSON'i kesebiliyordu.
      maxTokens: 3072,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    if (!ref.watch(aiSettingsProvider).enabled) return const AiNotConfigured();

    final result = _run.result == null
        ? null
        : parseEncounterResult(_run.result!);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AiSliderRow(
          label: l10n.questPartySize,
          value: _partySize,
          min: 1,
          max: 8,
          enabled: !_run.loading,
          onChanged: (v) => setState(() => _partySize = v),
        ),
        const SizedBox(height: 8),
        AiSliderRow(
          label: l10n.questPartyLevel,
          value: _partyLevel,
          min: 1,
          max: 20,
          enabled: !_run.loading,
          onChanged: (v) => setState(() => _partyLevel = v),
        ),
        const SizedBox(height: 12),
        Text(l10n.questDifficulty, style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            for (final d in EncounterDifficulty.values)
              ChoiceChip(
                label: Text(_difficultyLabel(l10n, d)),
                selected: _difficulty == d,
                onSelected: _run.loading
                    ? null
                    : (_) => setState(() => _difficulty = d),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          l10n.encounterBudgetHint(_xpBudget()),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        // Kazanma kosulu: 5e savaslarinin hepsinin "herkesi oldur"e
        // donmesini kiran tek kol.
        AiEnumChips<EncounterObjective>(
          label: l10n.encounterObjective,
          values: EncounterObjective.values,
          selected: _objective,
          enabled: !_run.loading,
          labelOf: (o) => _objectiveLabel(l10n, o),
          onSelected: (v) => setState(() => _objective = v),
        ),
        const SizedBox(height: 12),
        AiEnumChips<EncounterSetup>(
          label: l10n.encounterSetup,
          values: EncounterSetup.values,
          selected: _setup,
          enabled: !_run.loading,
          labelOf: (s) => _setupLabel(l10n, s),
          onSelected: (v) => setState(() => _setup = v),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _environment,
          decoration: InputDecoration(
            labelText: l10n.encounterEnvironment,
            helperText: l10n.encounterEnvironmentHint,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        AiOptionalPicker(
          label: l10n.encounterLocation,
          noneLabel: l10n.questTargetNone,
          hint: l10n.encounterLocationHint,
          entries: [
            for (final l in ref.watch(allLocationsProvider).value ?? const [])
              (l.id, l.name),
          ],
          value: _locationId,
          enabled: !_run.loading,
          onChanged: (v) => setState(() => _locationId = v),
        ),
        const SizedBox(height: 16),
        if (result == null)
          FilledButton.icon(
            onPressed: _run.loading ? null : _generate,
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: Text(l10n.codexAiGenerate),
          ),
        if (_run.error != null)
          AiErrorBox(message: _run.error!, detail: _run.errorDetail),
        if (_run.loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (result != null) ..._resultSections(l10n, theme, result),
      ],
    );
  }

  List<Widget> _resultSections(
    L10n l10n,
    ThemeData theme,
    EncounterResult r,
  ) => [
    // Gecerli JSON gelmediyse (cogunlukla yanit kesilmis) elimizdeki tek sey
    // ham metin; bunu karsilasma gibi gostermek yaniltici olur.
    if (!r.parsed) ...[
      AiErrorBox(message: l10n.encounterParseFailed, detail: r.summary),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: () => setState(() {
          _run.result = null;
          _run.error = null;
        }),
        icon: const Icon(Icons.refresh, size: 18),
        label: Text(l10n.aiRegenerate),
      ),
    ] else ...[
      if (r.name.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(r.name, style: theme.textTheme.titleLarge),
        ),
      if (r.summary.isNotEmpty)
        AiSection(title: l10n.encounterSummary, body: r.summary),
      if (r.monsters.isNotEmpty)
        AiSection(
          title: l10n.encounterMonsters,
          body: [
            for (final m in r.monsters) '${m.count}× ${m.name}',
          ].join('\n'),
        ),
      // Kazanma kosulu canavarlardan HEMEN sonra: savasin nasil bittigini
      // bilmeden taktik okumanin anlami yok.
      if (r.objective.isNotEmpty)
        AiSection(title: l10n.encounterObjectiveSection, body: r.objective),
      if (r.terrain.isNotEmpty)
        AiSection(title: l10n.encounterTerrain, body: r.terrain),
      if (r.tactics.isNotEmpty)
        AiSection(title: l10n.encounterTactics, body: r.tactics),
      if (r.reinforcements.isNotEmpty)
        AiSection(
          title: l10n.encounterReinforcements,
          body: r.reinforcements,
          dmOnly: true,
        ),
      if (r.scaling.isNotEmpty)
        AiSection(title: l10n.encounterScaling, body: r.scaling, dmOnly: true),
      if (r.treasure.isNotEmpty)
        AiSection(title: l10n.encounterTreasure, body: r.treasure),
      if (r.dm.isNotEmpty)
        AiSection(
          title: l10n.questSectionDm,
          body: r.dm,
          dmOnly: true,
          note: l10n.questDmOnly,
        ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: r.monsters.isEmpty
                ? null
                : () => _createEncounter(l10n, r),
            icon: const Icon(Icons.shield_outlined, size: 18),
            label: Text(l10n.encounterCreate),
          ),
          TextButton(
            onPressed: () => setState(() {
              _run.result = null;
              _run.error = null;
            }),
            child: Text(l10n.aiRegenerate),
          ),
        ],
      ),
    ],
  ];

  /// Üretilen karşılaşmayı gerçek savaşa çevirir: adlar kütüphanede aranır,
  /// bulunanlar eklenir, bulunamayanlar DM'e bildirilir (sessizce yutulmaz).
  Future<void> _createEncounter(L10n l10n, EncounterResult r) async {
    final compendium = ref.read(compendiumRepositoryProvider);
    final combat = CombatRepository(ref.read(databaseProvider));
    final name = r.name.isEmpty ? l10n.encounterFallbackName : r.name;
    final encounterId = await combat.createEncounter(name);

    final missing = <String>[];
    for (final group in r.monsters) {
      final matches = await compendium.searchMonsters(
        query: group.name,
        limit: 1,
      );
      final monster = matches.firstOrNull;
      if (monster == null) {
        missing.add(group.name);
        continue;
      }
      await combat.addMonsters(
        encounterId: encounterId,
        monster: monster,
        count: group.count,
        rollHitPoints: true,
      );
    }

    // Brifing: uretilen her sey savas ekraninin yan panellerinde durur.
    // Eskiden bu metinler yalnizca AI sekmesinde kaliyordu ve DM savasi
    // yonetirken taktikleri/kazanma kosulunu gorememis oluyordu.
    await combat.setBriefing(encounterId, (
      summary: r.summary,
      objective: r.objective,
      tactics: r.tactics,
      terrain: r.terrain,
      reinforcements: r.reinforcements,
      scaling: r.scaling,
      dmNotes: r.dm,
    ));

    // Ganimet: uretilen ADLAR kutuphaneye cozulur. Cozulemeyenler SILINMEZ,
    // "kutuphanede yok" isaretiyle kalir (bkz. LootResolver).
    if (r.treasureCoinsCp > 0 || r.treasureItems.isNotEmpty) {
      final resolved = await LootResolver(
        compendium,
      ).resolveAll(r.treasureItems);
      await combat.setLoot(encounterId, (
        coinsCp: r.treasureCoinsCp,
        items: resolved,
      ));
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          missing.isEmpty
              ? l10n.encounterCreated(name)
              : l10n.encounterCreatedPartial(name, missing.join(', ')),
        ),
        duration: const Duration(seconds: 5),
      ),
    );
    // Savas listesi yenilensin.
    ref.invalidate(encountersProvider);
  }
}
