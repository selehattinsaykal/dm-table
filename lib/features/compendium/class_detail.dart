import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ui/ui.dart';
import '../../data/content_tr.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import 'compendium_providers.dart';
import 'detail_sheets.dart';

/// Kutuphanedeki sinif/alt sinif kaydi.
///
/// Kagitta yalnizca karakterin kendi sinifi gorunuyordu; sinif secmeden once
/// bakmak, bir alt sinifin ne verdigini okumak mumkun degildi. Burada cekirdek
/// ozellik tablosu, seviye seviye ilerleme ve butun yetenek metinleri bir
/// arada.
class ClassDetail extends ConsumerWidget {
  const ClassDetail({required this.definition, super.key});

  final ClassDefinition definition;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final tr = contentTrOf(context, ref, 'classes');
    final names = contentNamesTrOf(context, ref);
    final data = jsonDecode(definition.dataJson) as Map<String, dynamic>;
    final features = (data['features'] as List? ?? const [])
        .cast<Map<String, dynamic>>();

    final core = features
        .where((f) => f['feature_type'] == 'CORE_TRAITS_TABLE')
        .firstOrNull;
    // 67 alt sinif tanitim paragrafini HEM `desc` alaninda HEM de kendi adini
    // tasiyan bir seviye ozelligi olarak tasiyor; ikisi de cizilince metin
    // ust uste iki kez gorunuyordu. Ayni metin yukarida varsa eleniyor.
    final intro = _normalize('${data['desc'] ?? ''}');
    final levelFeatures = features.where((f) {
      if (f['feature_type'] != 'CLASS_LEVEL_FEATURE') return false;
      final text = _normalize('${f['desc'] ?? ''}');
      return text.isEmpty || !intro.contains(text);
    }).toList()..sort((a, b) => _firstLevel(a).compareTo(_firstLevel(b)));

    final parent = definition.subclassOf;
    final subclasses = parent == null
        ? ref.watch(compendiumSubclassesProvider(definition.key)).value ??
              const <ClassDefinition>[]
        : const <ClassDefinition>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(definition.name, style: theme.textTheme.headlineSmall),
        Text(
          [
            if (parent != null)
              l10n.compendiumSubclassOf(_parentName(data, parent)),
            if (definition.hitDice != null)
              '${l10n.cwHitDie} ${definition.hitDice}',
            if (definition.casterType != null &&
                definition.casterType != 'NONE')
              _casterLabel(l10n, definition.casterType!),
          ].join(' · '),
          style: theme.textTheme.bodySmall?.copyWith(
            fontStyle: FontStyle.italic,
          ),
        ),
        if ('${data['desc'] ?? ''}'.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          GameText(tr.desc(definition.key, '${data['desc']}')),
        ],
        if (core != null) ...[
          const OrnamentDivider(compact: true),
          // Cekirdek ozellik tablosu markdown; cevirisi gosterim icin, satir
          // etiketlerini ayristiran `parseClassCoreTraits` veritabanindaki
          // Ingilizce metni okumaya devam ediyor.
          GameText(
            tr.part(
              definition.key,
              'features',
              '${core['name'] ?? ''}',
              '${core['desc'] ?? ''}',
            ),
          ),
        ],
        if (parent == null) ...[
          const OrnamentDivider(compact: true),
          Text(l10n.compendiumClassTable, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _ProgressionTable(classKey: definition.key),
        ],
        if (subclasses.isNotEmpty) ...[
          const OrnamentDivider(compact: true),
          Text(l10n.compendiumSubclasses, style: theme.textTheme.titleMedium),
          for (final s in subclasses)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(s.name),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showDetailSheet(context, ClassDetail(definition: s)),
            ),
        ],
        if (levelFeatures.isNotEmpty) ...[
          const OrnamentDivider(compact: true),
          Text(l10n.compendiumFeatures, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          for (final f in levelFeatures)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(names.term('classFeatures', '${f['name']}')),
              subtitle: Text(
                l10n.sheetOrdinalLevel(_firstLevel(f)),
                style: theme.textTheme.labelSmall,
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: GameText(
                    tr.part(
                      definition.key,
                      'features',
                      '${f['name'] ?? ''}',
                      '${f['desc'] ?? ''}',
                    ),
                  ),
                ),
              ],
            ),
        ],
      ],
    );
  }

  /// Karsilastirma icin: bosluk ve vurgu isaretleri onemsiz. Ayni paragraf
  /// `desc` icinde `*egik*`, ozellikte duz metin olarak geliyor.
  static String _normalize(String text) =>
      text.replaceAll(RegExp(r'[\s*]+'), ' ').trim().toLowerCase();

  static int _firstLevel(Map<String, dynamic> feature) {
    final levels = [
      for (final g in (feature['gained_at'] as List? ?? const []))
        if (g is Map && g['level'] is int) g['level'] as int,
    ]..sort();
    return levels.isEmpty ? 1 : levels.first;
  }

  static String _parentName(Map<String, dynamic> data, String key) {
    final parent = data['subclass_of'];
    if (parent is Map && parent['name'] != null) return '${parent['name']}';
    return key.split('_').last;
  }

  static String _casterLabel(L10n l10n, String casterType) =>
      switch (casterType) {
        'FULL' => l10n.compendiumFullCaster,
        'HALF' => l10n.compendiumHalfCaster,
        'THIRD' => l10n.compendiumThirdCaster,
        'PACT' => l10n.compendiumPactCaster,
        _ => '',
      };
}

/// Seviye / yeterlilik bonusu / buyu yuvalari / sinif sayaclari tablosu.
class _ProgressionTable extends ConsumerWidget {
  const _ProgressionTable({required this.classKey});

  final String classKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final rows =
        ref.watch(classProgressionProvider(classKey)).value ?? const [];
    if (rows.isEmpty) return const SizedBox.shrink();

    // Sutunlar veriden geliyor: her sinifin kendi sayaclari var.
    final counters = <String>{};
    var maxSlotLevel = 0;
    for (final row in rows) {
      counters.addAll(
        (jsonDecode(row.classTableJson) as Map).keys.cast<String>(),
      );
      for (final key in (jsonDecode(row.spellSlotsJson) as Map).keys) {
        final level = int.tryParse('$key') ?? 0;
        if (level > maxSlotLevel) maxSlotLevel = level;
      }
    }
    final counterList = counters.toList()..sort();

    final header = [
      l10n.compendiumLevel,
      'PB',
      ...counterList,
      for (var i = 1; i <= maxSlotLevel; i++) '$i',
    ];

    final lines = <String>[
      '| ${header.join(' | ')} |',
      '|${List.filled(header.length, '---').join('|')}|',
    ];
    for (final row in rows) {
      final table = (jsonDecode(row.classTableJson) as Map)
          .cast<String, dynamic>();
      final slots = (jsonDecode(row.spellSlotsJson) as Map)
          .cast<String, dynamic>();
      lines.add(
        '| ${['${row.level}', '+${row.proficiencyBonus}', for (final c in counterList) '${table[c] ?? '—'}', for (var i = 1; i <= maxSlotLevel; i++) '${slots['$i'] ?? '—'}'].join(' | ')} |',
      );
    }
    return GameText(lines.join('\n'));
  }
}
