import 'dart:convert';

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ui/async_view.dart';
import '../../app/ui/ui.dart';
import '../../data/character_repository.dart';
import '../../data/content_tr.dart';
import '../../data/db/character_tables.dart';
import '../../data/db/database.dart';
import '../../domain/models/ability.dart';
import '../../domain/models/character_build.dart';
import '../../domain/rules/character_math.dart';
import '../../domain/rules/dice.dart';
import '../../domain/rules/equipment_slots.dart';
import '../../domain/rules/experience.dart';
import '../../domain/rules/proficiency_parsing.dart';
import '../../domain/rules/spell_casting.dart';
import '../../domain/search_text.dart';
import '../../domain/rules/spell_preparation.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/game_terms.dart';
import '../compendium/compendium_providers.dart';
import '../compendium/detail_sheets.dart';
import '../dice/dice_sheet.dart';
import '../dice/roll_log.dart';
import '../world/pick_image_file.dart';
import 'character_avatar.dart';
import 'character_edit_page.dart';
import 'character_pdf.dart';
import 'character_providers.dart';
import 'level_up_sheet.dart';

part 'character_sheet_vitals.dart';
part 'character_sheet_inventory.dart';
part 'character_sheet_spells.dart';

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
              onRolled: (roll) {
                ref.read(rollLogProvider.notifier).add(roll);
                showRollResult(context, roll);
              },
            ),
          ),
          _RestButton(characterId: characterId),
          IconButton(
            tooltip: l10n.exportPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => _exportPdf(context, ref, characterId),
          ),
          IconButton(
            tooltip: l10n.sheetEdit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CharacterEditPage(characterId: characterId),
              ),
            ),
          ),
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
            _SavesCard(characterId: characterId, stats: b),
            const SizedBox(height: 12),
            _SkillsCard(characterId: characterId, stats: b),
            const SizedBox(height: 12),
            _SpellSlotsCard(characterId: characterId, character: c),
            const SizedBox(height: 12),
            _KnownSpellsCard(characterId: characterId),
            const SizedBox(height: 12),
            _ResourcesCard(characterId: characterId),
            const SizedBox(height: 12),
            _ProficienciesCard(characterId: characterId),
            const SizedBox(height: 12),
            _FeaturesCard(characterId: characterId),
            const SizedBox(height: 12),
            _InventoryCard(characterId: characterId),
            const SizedBox(height: 12),
            _ConcentrationCard(character: c),
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
Future<void> _exportPdf(
  BuildContext context,
  WidgetRef ref,
  String characterId,
) async {
  final l10n = L10n.of(context);
  final messenger = ScaffoldMessenger.of(context);

  final character = await ref.read(characterProvider(characterId).future);
  final build = await ref.read(characterBuildProvider(characterId).future);

  final bytes = await buildCharacterPdf(character: character, build: build);

  final location = await getSaveLocation(
    suggestedName: '${character.name}.pdf',
    acceptedTypeGroups: const [
      XTypeGroup(label: 'PDF', extensions: ['pdf']),
    ],
  );
  if (location == null) return;

  await File(location.path).writeAsBytes(bytes);
  messenger.showSnackBar(
    SnackBar(content: Text(l10n.exportPdfDone(location.path))),
  );
}

/// Kullanim sonucunu gosterir: saldiri atisi, hasar zari, kurtarma DC'si.
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

/// Zirh egitimi, silah/alet yeterlilikleri, diller ve silah ustaliklari.
///
/// Satirlarin cogu sinif, gecmis ve feat'lerden TURETILIYOR
/// (`syncDerivedProficiencies`); kagitta gosteriliyor ve yalnizca elle
/// eklenenler yonetiliyor. Turetilmis bir satir silinemez: kaynak degisince
/// zaten kendiliginden gidiyor, elle silinse bir sonraki senkronda geri gelir
/// ve kullaniciya "silinmiyor" gibi gorunurdu.
class _ProficienciesCard extends ConsumerWidget {
  const _ProficienciesCard({required this.characterId});

  final String characterId;

  /// Bolum -> degerlerin cevrildigi sozluk bolumu.
  static const _sections = <(ProficiencyKind, String)>[
    (ProficiencyKind.armor, 'armorTraining'),
    (ProficiencyKind.weapon, 'weaponProficiencies'),
    (ProficiencyKind.tool, 'tools'),
    (ProficiencyKind.language, 'languages'),
    (ProficiencyKind.weaponMastery, 'tools'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final glossary = glossaryTrOf(context, ref);
    final rows =
        ref.watch(characterProficienciesProvider(characterId)).value ??
        const <CharacterProficiency>[];
    final pending =
        ref.watch(proficiencyChoicesProvider(characterId)).value ?? const [];

    String title(ProficiencyKind kind) => switch (kind) {
      ProficiencyKind.armor => l10n.sheetArmorTraining,
      ProficiencyKind.weapon => l10n.sheetWeaponProficiencies,
      ProficiencyKind.tool => l10n.sheetToolProficiencies,
      ProficiencyKind.language => l10n.sheetLanguages,
      _ => l10n.sheetWeaponMastery,
    };

    return _ListCard(
      title: l10n.sheetProficiencies,
      trailing: pending.isEmpty
          ? null
          : Tooltip(
              message: l10n.sheetProficiencySourceHint,
              child: Chip(
                visualDensity: VisualDensity.compact,
                label: Text(
                  l10n.sheetProficiencyPending(
                    pending.fold<int>(0, (sum, p) => sum + p.choice.count),
                  ),
                ),
              ),
            ),
      children: [
        for (final (kind, section) in _sections) ...[
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title(kind),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: l10n.sheetAddProficiency,
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  onPressed: () => _add(context, ref, kind),
                ),
              ],
            ),
          ),
          Builder(
            builder: (context) {
              final mine = rows.where((r) => r.kind == kind).toList()
                ..sort(
                  (a, b) => compareTurkish(
                    glossary.term(section, a.value),
                    glossary.term(section, b.value),
                  ),
                );
              if (mine.isEmpty) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.sheetNoProficiencies,
                    style: theme.textTheme.bodySmall,
                  ),
                );
              }
              return Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final row in mine)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(glossary.term(section, row.value)),
                      // Kaynak rozeti: masada en sik sorulan sey "bu nereden
                      // geldi?".
                      avatar: Tooltip(
                        message: glossary.term(
                          'proficiencySources',
                          row.source.name,
                        ),
                        child: Icon(_sourceIcon(row.source), size: 16),
                      ),
                      onDeleted: row.source == ProficiencySource.manual
                          ? () => ref
                                .read(characterRepositoryProvider)
                                .removeProficiency(
                                  characterId,
                                  kind: kind,
                                  value: row.value,
                                )
                          : null,
                    ),
                ],
              );
            },
          ),
        ],
        const SizedBox(height: 10),
        Text(
          l10n.sheetProficiencySourceHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }

  static IconData _sourceIcon(ProficiencySource source) => switch (source) {
    ProficiencySource.characterClass => Icons.shield_outlined,
    ProficiencySource.background => Icons.history_edu_outlined,
    ProficiencySource.feat => Icons.star_outline,
    ProficiencySource.species => Icons.person_outline,
    ProficiencySource.manual => Icons.edit_outlined,
  };

  Future<void> _add(
    BuildContext context,
    WidgetRef ref,
    ProficiencyKind kind,
  ) async {
    final l10n = L10n.of(context);
    // Bir geri cagirim: `ref.watch` kullanilamaz, saglayicilar bekleniyor.
    final glossary = l10n.localeName == 'tr'
        ? await ref.read(glossaryTrProvider.future)
        : GlossaryTr.empty;

    final (String title, String section, List<String> options) = switch (kind) {
      ProficiencyKind.armor => (
        l10n.sheetArmorTraining,
        'armorTraining',
        ArmorTraining.all,
      ),
      ProficiencyKind.weapon => (
        l10n.sheetWeaponProficiencies,
        'weaponProficiencies',
        const [
          WeaponProficiency.simple,
          WeaponProficiency.martial,
          WeaponProficiency.martialLight,
          WeaponProficiency.martialFinesseOrLight,
          'improvised',
        ],
      ),
      ProficiencyKind.language => (
        l10n.sheetPickLanguage,
        'languages',
        await ref.read(languageOptionsProvider.future),
      ),
      ProficiencyKind.weaponMastery => (
        l10n.sheetPickWeapon,
        'tools',
        await ref.read(masteryWeaponsProvider.future),
      ),
      _ => (
        l10n.sheetPickTool,
        'tools',
        await ref.read(toolOptionsProvider(ToolGroup.any).future),
      ),
    };
    if (!context.mounted) return;

    final sorted = [...options]
      ..sort(
        (a, b) => compareTurkish(
          glossary.term(section, a),
          glossary.term(section, b),
        ),
      );
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(title),
        children: [
          for (final option in sorted)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, option),
              child: Text(glossary.term(section, option)),
            ),
        ],
      ),
    );
    if (picked == null) return;
    await ref
        .read(characterRepositoryProvider)
        .addManualProficiency(characterId, kind: kind, value: picked);
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

    // Yetenek adi ve metni kagida INGILIZCE yaziliyor (kural ayristiricilari
    // ve yeniden uretilen veriyle eslesme icin); Turkcesi burada, gosterim
    // aninda uygulaniyor -- kutuphanedeki sinif sayfasiyla ayni katman.
    final classTr = contentTrOf(context, ref, 'classes');
    final optionTr = contentTrOf(context, ref, 'optionalfeatures');
    final names = contentNamesTrOf(context, ref);
    final glossary = glossaryTrOf(context, ref);
    // Alt sinif yetenekleri de `source: <sinif anahtari>` ile kaydediliyor,
    // ama cevirileri alt sinif kaydinda duruyor; ikisi de aranabilsin diye
    // karakterin secili alt siniflari toplaniyor.
    final subclassKeys = <String>[
      for (final row
          in ref.watch(classLevelsProvider(characterId)).value ??
              const <CharacterClassLevel>[])
        ?row.subclassKey,
    ];

    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    return _ListCard(
      title: l10n.sheetFeatures,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sinif secenekleri (Invocation, Metamagic, Maneuver...): kural
          // metinleri vardi ama secim yapilamiyordu.
          IconButton(
            tooltip: l10n.sheetAddClassOption,
            icon: const Icon(Icons.auto_fix_high_outlined),
            onPressed: () => _pickClassOption(context, ref, characterId),
          ),
          IconButton(
            tooltip: l10n.sheetAddFeature,
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _editFeature(context, ref, null),
          ),
        ],
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
                  child: Text(
                    _featureName(names, glossary, f),
                    style: theme.textTheme.bodyMedium,
                  ),
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
                  // Yetenek metinleri tablo tasiyor (alt sinif buyu listesi,
                  // yoldas stat blogu); duz metin olarak okunmuyorlardi.
                  child: f.source == 'feat' && f.featureKey != null
                      ? FeatRuleText(
                          featKey: f.featureKey!,
                          fallback: f.description,
                        )
                      : GameText(
                          _featureText(classTr, optionTr, subclassKeys, f),
                        ),
                ),
            ],
          ),
      ],
    );
  }

  /// Elle eklenen yetenekler (`manual`) kullanicinin kendi metni: dokunulmaz.
  ///
  /// Sinif secenekleri kagida "Metamagic: Careful Spell" gibi BIRLESIK bir adla
  /// yaziliyor; iki parca ayri sozluklerden geliyor.
  static String _featureName(
    GlossaryTr names,
    GlossaryTr glossary,
    CharacterFeature f,
  ) {
    if (f.source == 'manual') return f.name;
    if (f.source == 'option') {
      final colon = f.name.indexOf(': ');
      if (colon < 0) return names.term('classOptions', f.name);
      final type = glossary.term(
        'classOptionTypes',
        f.name.substring(0, colon),
      );
      final name = names.term('classOptions', f.name.substring(colon + 2));
      return '$type: $name';
    }
    if (f.source == 'feat') return names.term('feats', f.name);
    return names.term('classFeatures', f.name);
  }

  /// Metnin cevirisi kaynaga gore farkli dosyada: sinif secenekleri
  /// `optionalfeatures_tr.json` icinde kendi anahtarlariyla, sinif ve alt sinif
  /// yetenekleri `classes_tr.json` icinde ilgili kaydin `features/` bolumunde.
  /// Feat'ler ayri ele aliniyor ([FeatRuleText]).
  static String _featureText(
    ContentTr classTr,
    ContentTr optionTr,
    List<String> subclassKeys,
    CharacterFeature f,
  ) {
    if (f.source == 'manual') return f.description;
    if (f.source == 'option') {
      final key = f.featureKey;
      return key == null ? f.description : optionTr.desc(key, f.description);
    }
    return classTr.partAmong(
      [...subclassKeys, f.source],
      'features',
      f.name,
      f.description,
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

Future<void> _pickClassOption(
  BuildContext context,
  WidgetRef ref,
  String characterId,
) async {
  final l10n = L10n.of(context);
  // Secim listesi kutuphane kayitlarini gosteriyor; ceviri katmani kagitla
  // ayni (bkz. `_FeaturesCard`). Burasi bir build degil bir geri cagirim
  // oldugu icin `contentTrOf` (ve `ref.watch`) kullanilamaz; saglayicilar
  // beklenerek OKUNUYOR.
  final turkish = l10n.localeName == 'tr';
  final tr = turkish
      ? await ref.read(contentTrProvider('optionalfeatures').future)
      : ContentTr.empty;
  final names = turkish
      ? await ref.read(contentNamesTrProvider.future)
      : GlossaryTr.empty;
  final glossary = turkish
      ? await ref.read(glossaryTrProvider.future)
      : GlossaryTr.empty;
  final options = await ref.read(
    classOptionChoicesProvider(characterId).future,
  );
  if (!context.mounted) return;
  if (options.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.sheetNoClassOptions)));
    return;
  }

  final byType = <String, List<Map<String, dynamic>>>{};
  for (final o in options) {
    (byType['${o['type_name']}'] ??= []).add(o);
  }
  // Siralama GORUNEN ada gore: liste Ingilizce ada gore dizilirse Turkce
  // okuyana rastgele siralanmis gorunuyor.
  for (final group in byType.values) {
    group.sort(
      (a, b) => compareTurkish(
        names.term('classOptions', '${a['name']}'),
        names.term('classOptions', '${b['name']}'),
      ),
    );
  }

  final picked = await showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            l10n.sheetAddClassOption,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final entry in byType.entries) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text(
                glossary.term('classOptionTypes', entry.key),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            for (final option in entry.value)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(names.term('classOptions', '${option['name']}')),
                subtitle: '${option['prerequisite'] ?? ''}'.isEmpty
                    ? null
                    : Text(
                        glossary.term(
                          'classOptionPrerequisites',
                          '${option['prerequisite']}',
                        ),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GameText(
                      tr.desc('${option['key']}', '${option['desc'] ?? ''}'),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => Navigator.of(context).pop(option),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(l10n.sheetAddClassOptionAction),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    ),
  );
  if (picked == null) return;
  await ref
      .read(characterRepositoryProvider)
      .addClassOption(characterId, picked);
}

/// Konsantrasyon tutulan buyu; hasar alinca kurtarma DC'sini hatirlatir.
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
      final picked = await pickImageFile(typeLabel: l10n.fileTypeImage);
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
