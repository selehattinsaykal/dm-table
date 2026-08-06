import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../app/ui/ui.dart';
import '../../data/character_image_store.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../domain/rules/magic_item_pricing.dart';
import '../../l10n/app_localizations.dart';
import '../world/pick_image_file.dart';
import 'stat_block.dart';

/// Kutuphane kayitlarini alttan acilan bir panelde gosterir.
///
/// Masada tek elle kullanildigi icin tam sayfa yerine sheet: DM listedeki
/// yerini kaybetmeden bakip kapatabiliyor.
Future<void> showDetailSheet(BuildContext context, Widget child) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (context, controller) =>
            PrimaryScrollController(controller: controller, child: child),
      ),
    );

/// Canavarin stat blogu + en ustte DM'in ekleyebilecegi portre gorseli.
class MonsterDetail extends ConsumerStatefulWidget {
  const MonsterDetail({required this.monster, super.key});

  final Monster monster;

  @override
  ConsumerState<MonsterDetail> createState() => _MonsterDetailState();
}

class _MonsterDetailState extends ConsumerState<MonsterDetail> {
  late Monster _monster = widget.monster;

  Future<void> _refresh() async {
    final fresh = await ref
        .read(compendiumRepositoryProvider)
        .monsterByKey(_monster.key);
    if (fresh != null && mounted) setState(() => _monster = fresh);
  }

  Future<void> _upload() async {
    final picked = await pickImageFile();
    if (picked == null) return;
    try {
      await ref
          .read(compendiumRepositoryProvider)
          .setMonsterPortrait(_monster.key, picked);
      await _refresh();
    } on FormatException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _remove() async {
    await ref
        .read(compendiumRepositoryProvider)
        .removeMonsterPortrait(_monster.key);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) => StatBlock(
    monster: _monster,
    header: _MonsterPortraitHeader(
      path: _monster.portraitPath,
      store: ref.read(compendiumRepositoryProvider).portraits,
      onUpload: _upload,
      onRemove: _monster.portraitPath == null ? null : _remove,
    ),
  );
}

/// Stat blogun ustundeki portre; yoksa "Görsel ekle" dugmesi, varsa gorsel +
/// degistir/sil.
class _MonsterPortraitHeader extends StatelessWidget {
  const _MonsterPortraitHeader({
    required this.path,
    required this.store,
    required this.onUpload,
    this.onRemove,
  });

  final String? path;
  final CharacterImageStore store;
  final VoidCallback onUpload;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    if (path == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: OutlinedButton.icon(
            onPressed: onUpload,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: Text(l10n.sheetUploadPhoto),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FutureBuilder<File>(
              future: store.resolve(path!),
              builder: (context, snap) {
                final f = snap.data;
                if (f == null || !f.existsSync()) {
                  return const SizedBox(
                    height: 160,
                    child: Center(
                      child: Icon(Icons.image_not_supported_outlined),
                    ),
                  );
                }
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: Image.file(
                    f,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onUpload,
                icon: const Icon(Icons.upload, size: 18),
                label: Text(l10n.sheetChange),
              ),
              if (onRemove != null)
                TextButton.icon(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(l10n.sheetRemove),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class SpellDetail extends StatelessWidget {
  const SpellDetail({required this.spell, super.key});

  final Spell spell;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = jsonDecode(spell.dataJson) as Map<String, dynamic>;

    final components = [
      if (data['verbal'] == true) 'V',
      if (data['somatic'] == true) 'S',
      if (data['material'] == true) 'M',
    ].join(', ');
    final material = data['material_specified'] as String?;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(spell.name, style: theme.textTheme.headlineSmall),
        Text(
          spell.level == 0
              ? '${spell.school} cantrip'
              : 'Level ${spell.level} ${spell.school?.toLowerCase()}'
                    '${spell.ritual ? ' (ritual)' : ''}',
          style: theme.textTheme.bodySmall?.copyWith(
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 12),
        _Row('Casting Time', '${data['casting_time'] ?? '—'}'),
        _Row('Range', '${data['range_text'] ?? '—'}'),
        _Row(
          'Components',
          material == null || material.isEmpty
              ? components
              : '$components ($material)',
        ),
        _Row(
          'Duration',
          '${spell.concentration ? 'Concentration, ' : ''}'
              '${data['duration'] ?? '—'}',
        ),
        if ((data['classes'] as List? ?? const []).isNotEmpty)
          _Row(
            'Classes',
            (data['classes'] as List)
                .map((c) => c is Map ? c['name'] : null)
                .whereType<String>()
                .join(', '),
          ),
        const OrnamentDivider(compact: true),
        Text(
          '${data['desc'] ?? ''}',
          style: readingStyle(context, base: theme.textTheme.bodyMedium),
        ),
        if (data['higher_level'] != null &&
            '${data['higher_level']}'.isNotEmpty) ...[
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              style: readingStyle(context, base: theme.textTheme.bodyMedium),
              children: [
                const TextSpan(
                  text: 'Using a Higher-Level Spell Slot. ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                TextSpan(text: '${data['higher_level']}'),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class ItemDetail extends StatelessWidget {
  const ItemDetail({required this.item, super.key});

  final Item item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final data = jsonDecode(item.dataJson) as Map<String, dynamic>;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(item.name, style: theme.textTheme.headlineSmall),
        Text(
          item.category ?? '',
          style: theme.textTheme.bodySmall?.copyWith(
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 12),
        if (item.costCp != null)
          _Row(l10n.compendiumPrice, formatCoins(item.costCp!)),
        if (item.weightLb != null)
          _Row(l10n.compendiumWeight, '${item.weightLb} lb'),
        ..._weaponRows(l10n, data['weapon']),
        ..._armorRows(l10n, data['armor']),
        const OrnamentDivider(compact: true),
        Text(
          '${data['desc'] ?? ''}',
          style: readingStyle(context, base: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }
}

class MagicItemDetail extends StatelessWidget {
  const MagicItemDetail({required this.item, super.key});

  final MagicItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final data = jsonDecode(item.dataJson) as Map<String, dynamic>;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(item.name, style: theme.textTheme.headlineSmall),
        Text(
          [
            item.category,
            item.rarity,
            if (item.requiresAttunement) 'requires attunement',
          ].whereType<String>().join(', '),
          style: theme.textTheme.bodySmall?.copyWith(
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 12),
        if (item.costCp != null)
          _Row(
            l10n.compendiumPrice,
            '${formatCoins(item.costCp!)}'
            '${item.costIsSuggested ? '  (${l10n.compendiumSuggested})' : ''}',
          ),
        if (data['attunement_detail'] != null)
          _Row('Attunement', '${data['attunement_detail']}'),
        ..._weaponRows(l10n, data['weapon']),
        ..._armorRows(l10n, data['armor']),
        if (item.costIsSuggested) ...[
          const SizedBox(height: 8),
          Text(
            l10n.compendiumMagicPriceHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
        const OrnamentDivider(compact: true),
        Text(
          '${data['desc'] ?? ''}',
          style: readingStyle(context, base: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }
}

List<Widget> _weaponRows(L10n l10n, Object? weapon) {
  if (weapon is! Map) return const [];
  final damageType = weapon['damage_type'];
  return [
    _Row(
      l10n.compendiumDamage,
      '${weapon['damage_dice'] ?? '—'} '
              '${damageType is Map ? damageType['name'] ?? '' : ''}'
          .trim(),
    ),
    if (weapon['properties'] is List &&
        (weapon['properties'] as List).isNotEmpty)
      _Row(
        l10n.compendiumProperties,
        (weapon['properties'] as List)
            .map((p) => p is Map ? p['name'] : p)
            .whereType<String>()
            .join(', '),
      ),
  ];
}

List<Widget> _armorRows(L10n l10n, Object? armor) {
  if (armor is! Map) return const [];
  return [
    _Row(
      'AC',
      '${armor['ac_base'] ?? '—'}'
          '${armor['ac_add_dexmod'] == true ? ' + Dex' : ''}'
          '${armor['ac_cap_dexmod'] != null ? ' (max ${armor['ac_cap_dexmod']})' : ''}',
    ),
    if (armor['strength_score_required'] != null)
      _Row(l10n.compendiumStrengthReq, '${armor['strength_score_required']}'),
    if (armor['stealth_disadvantage'] == true)
      _Row(l10n.compendiumStealth, l10n.compendiumDisadvantage),
  ];
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.bodyMedium,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

/// Feat ayrintilari: tip, onkosul ve aciklama.
class FeatDetail extends StatelessWidget {
  const FeatDetail({required this.feat, super.key});

  final Feat feat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = jsonDecode(feat.dataJson) as Map<String, dynamic>;
    final benefits = (data['benefits'] as List? ?? const [])
        .map((b) => b is Map ? '${b['desc'] ?? ''}' : '$b')
        .where((s) => s.isNotEmpty)
        .toList();
    final desc = data['desc'] is String && (data['desc'] as String).isNotEmpty
        ? data['desc'] as String
        : benefits.join('\n\n');
    final type = data['type'] as String?;
    final prereq = data['prerequisite'] as String?;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(feat.name, style: theme.textTheme.headlineSmall),
        Text(
          [type, ?prereq].whereType<String>().join(' · '),
          style: theme.textTheme.bodySmall?.copyWith(
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          desc,
          style: readingStyle(context, base: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }
}

/// Irk ayrintilari: ozellikler listesi.
class SpeciesDetail extends StatelessWidget {
  const SpeciesDetail({required this.species, super.key});

  final SpeciesEntry species;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = jsonDecode(species.dataJson) as Map<String, dynamic>;
    final traits = data['traits'] as List? ?? const [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(species.name, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        for (final t in traits)
          if (t is Map && '${t['desc'] ?? ''}'.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RichText(
                text: TextSpan(
                  style: readingStyle(
                    context,
                    base: theme.textTheme.bodyMedium,
                  ),
                  children: [
                    TextSpan(
                      text: '${t['name'] ?? ''}.\n',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: '${t['desc'] ?? ''}'),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

/// Geçmiş ayrintilari: yetenek/fayda listesi.
class BackgroundDetail extends StatelessWidget {
  const BackgroundDetail({required this.background, super.key});

  final Background background;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = jsonDecode(background.dataJson) as Map<String, dynamic>;
    final benefits = data['benefits'] as List? ?? const [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(background.name, style: theme.textTheme.headlineSmall),
        if ('${data['desc'] ?? ''}'.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '${data['desc']}',
            style: readingStyle(context, base: theme.textTheme.bodyMedium),
          ),
        ],
        const SizedBox(height: 8),
        for (final b in benefits)
          if (b is Map && '${b['desc'] ?? ''}'.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RichText(
                text: TextSpan(
                  style: readingStyle(
                    context,
                    base: theme.textTheme.bodyMedium,
                  ),
                  children: [
                    TextSpan(
                      text: '${b['name'] ?? ''}.\n',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: '${b['desc'] ?? ''}'),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
