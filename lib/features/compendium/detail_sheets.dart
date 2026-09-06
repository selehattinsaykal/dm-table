import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../app/ui/ui.dart';
import '../../data/character_image_store.dart';
import '../../data/content_tr.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../domain/rules/magic_item_pricing.dart';
import '../../l10n/app_localizations.dart';
import '../world/pick_image_file.dart';
import 'compendium_providers.dart';
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
    final picked = await pickImageFile(
      typeLabel: L10n.of(context).fileTypeImage,
    );
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

class SpellDetail extends ConsumerWidget {
  const SpellDetail({required this.spell, super.key});

  final Spell spell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final tr = contentTrOf(context, ref, 'spells');
    final glossary = glossaryTrOf(context, ref);
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
          // Okul adi veriden Ingilizce geliyor ("Evocation"); sozluk uzerinden
          // ceviriliyor, veritabani Ingilizce kaliyor.
          spell.level == 0
              ? l10n.spellSchoolCantrip(
                  glossary.term('schools', spell.school ?? ''),
                )
              : l10n.spellSchoolLevel(
                      spell.level,
                      glossary
                          .term('schools', spell.school ?? '')
                          .toLowerCase(),
                    ) +
                    (spell.ritual ? l10n.spellRitualSuffix : ''),
          style: theme.textTheme.bodySmall?.copyWith(
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 12),
        // Bu uc alan kapali bir sozcuk dagarcigi ama serbest metin olarak
        // saklaniyor; tam deger eslesmesiyle cevriliyorlar.
        _Row(
          l10n.formCastingTime,
          glossary.term('castingTimes', '${data['casting_time'] ?? '—'}'),
        ),
        _Row(
          l10n.formRange,
          glossary.term('spellRanges', '${data['range_text'] ?? '—'}'),
        ),
        _Row(
          l10n.spellComponents,
          material == null || material.isEmpty
              ? components
              : '$components ($material)',
        ),
        _Row(l10n.formDuration, _durationText(l10n, glossary, spell, data)),
        if ((data['classes'] as List? ?? const []).isNotEmpty)
          _Row(
            l10n.spellClasses,
            (data['classes'] as List)
                .map((c) => c is Map ? c['name'] : null)
                .whereType<String>()
                .join(', '),
          ),
        const OrnamentDivider(compact: true),
        GameText(tr.desc(spell.key, '${data['desc'] ?? ''}')),
        if (data['higher_level'] != null &&
            '${data['higher_level']}'.isNotEmpty) ...[
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              style: readingStyle(context, base: theme.textTheme.bodyMedium),
              children: [
                TextSpan(
                  text: l10n.spellHigherLevelSlot,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                TextSpan(
                  text: tr.field(
                    spell.key,
                    'higher_level',
                    '${data['higher_level']}',
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class ItemDetail extends ConsumerWidget {
  const ItemDetail({required this.item, super.key});

  final Item item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final tr = contentTrOf(context, ref, 'items');
    final glossary = glossaryTrOf(context, ref);
    final names = contentNamesTrOf(context, ref);
    final data = jsonDecode(item.dataJson) as Map<String, dynamic>;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(
          itemNameTr(names, item.name),
          style: theme.textTheme.headlineSmall,
        ),
        Text(
          glossary.term('itemCategories', item.category ?? ''),
          style: theme.textTheme.bodySmall?.copyWith(
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 12),
        if (item.costCp != null)
          _Row(l10n.compendiumPrice, formatCoins(item.costCp!)),
        if (item.weightLb != null)
          _Row(l10n.compendiumWeight, '${item.weightLb} lb'),
        ..._weaponRows(l10n, glossary, data['weapon']),
        ..._armorRows(l10n, data['armor']),
        const OrnamentDivider(compact: true),
        GameText(tr.desc(item.key, '${data['desc'] ?? ''}')),
      ],
    );
  }
}

class MagicItemDetail extends ConsumerWidget {
  const MagicItemDetail({required this.item, super.key});

  final MagicItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final tr = contentTrOf(context, ref, 'magicitems');
    final glossary = glossaryTrOf(context, ref);
    final names = contentNamesTrOf(context, ref);
    final data = jsonDecode(item.dataJson) as Map<String, dynamic>;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(
          itemNameTr(names, item.name),
          style: theme.textTheme.headlineSmall,
        ),
        Text(
          [
            // Kategori ve nadirlik veritabaninda Ingilizce; filtreler ve
            // fiyatlandirma o degerlere bakiyor, ceviri yalnizca etikette.
            if (item.category != null)
              glossary.term('itemCategories', item.category!),
            if (item.rarity != null)
              glossary.term('itemRarities', item.rarity!),
            if (item.requiresAttunement) l10n.ciAttunement,
          ].join(', '),
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
          _Row(l10n.itemAttunementDetail, '${data['attunement_detail']}'),
        ..._weaponRows(l10n, glossary, data['weapon']),
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
        GameText(tr.desc(item.key, '${data['desc'] ?? ''}')),
      ],
    );
  }
}

/// Buyunun sure satiri.
///
/// 185 konsantrasyon buyusunun 162'sinde `duration` alani ZATEN
/// "Concentration, up to ..." diyor; onek her zaman eklenince metin
/// "Konsantrasyon, Konsantrasyon, 1 dakikaya kadar" olarak cikiyordu. Onek
/// yalnizca alanin kendisi konsantrasyondan soz etmiyorsa ekleniyor -- kontrol
/// cevirmeden ONCE, Ingilizce deger uzerinde yapiliyor.
String _durationText(
  L10n l10n,
  GlossaryTr glossary,
  Spell spell,
  Map<String, dynamic> data,
) {
  final english = '${data['duration'] ?? '—'}';
  final prefix =
      spell.concentration && !english.toLowerCase().contains('concentration')
      ? l10n.spellConcentrationPrefix
      : '';
  return '$prefix${glossary.term('spellDurations', english)}';
}

List<Widget> _weaponRows(L10n l10n, GlossaryTr glossary, Object? weapon) {
  if (weapon is! Map) return const [];
  final damageType = weapon['damage_type'];
  // Ozellik adi bir sarmalayicinin icinde: `{"property": {"name": "Topple"}}`.
  // Dogrudan `p['name']` okumak her zaman null donuyordu, dolayisiyla satir
  // butun silahlarda BOS ciziliyordu.
  final properties = [
    for (final p in weapon['properties'] as List? ?? const [])
      if (p is Map)
        if ((p['property'] is Map ? p['property']['name'] : p['name'])
            case final String name)
          glossary.term('weaponProperties', name),
  ];
  return [
    _Row(
      l10n.compendiumDamage,
      '${weapon['damage_dice'] ?? '—'} '
              '${damageType is Map ? glossary.term('damage', '${damageType['name'] ?? ''}') : ''}'
          .trim(),
    ),
    if (properties.isNotEmpty)
      _Row(l10n.compendiumProperties, properties.join(', ')),
  ];
}

List<Widget> _armorRows(L10n l10n, Object? armor) {
  if (armor is! Map) return const [];
  final capDex = armor['ac_cap_dexmod'];
  return [
    _Row(
      'AC',
      '${armor['ac_base'] ?? '—'}'
          '${armor['ac_add_dexmod'] == true ? l10n.compendiumAcPlusDex : ''}'
          '${capDex is int ? l10n.compendiumAcMaxDex(capDex) : ''}',
    ),
    if (armor['strength_score_required'] != null)
      _Row(l10n.compendiumStrengthReq, '${armor['strength_score_required']}'),
    // Veri alaninin adi `grants_stealth_disadvantage`; eski ad hicbir zaman
    // eslesmedigi icin bu satir hic gorunmuyordu.
    if (armor['grants_stealth_disadvantage'] == true)
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

/// Bir feat'in tam kural metni, [tr] varsa Turkcesi.
///
/// Feat metni iki sekilde geliyor: bazi kayitlarda her sey `desc` icinde
/// (parcalar orada da tekrarlanir), bazilarinda `desc` yalnizca "You gain the
/// following benefits." deyip asil kurallari `benefits` tasir. Ikisi
/// birlestirilip `desc` icinde ZATEN gecen parcalar eleniyor; yalnizca `desc`e
/// bakmak 10 featin butun kurallarini gizliyordu.
///
/// Karakter kagidi da ayni metni gosterdigi icin burada, ortak.
String composeFeatText(Feat feat, ContentTr tr) {
  final data = jsonDecode(feat.dataJson) as Map<String, dynamic>;
  final english = data['desc'] is String ? data['desc'] as String : '';
  final parts = <String>[if (english.isNotEmpty) tr.desc(feat.key, english)];
  for (final (i, b) in (data['benefits'] as List? ?? const []).indexed) {
    final text = b is Map ? '${b['desc'] ?? ''}' : '$b';
    // Parcalarin cogunun adi yok; sirayla numaralanip cevriliyorlar.
    if (text.isEmpty || english.contains(text)) continue;
    parts.add(tr.part(feat.key, 'benefits', '$i', text));
  }
  return parts.join('\n\n');
}

/// Bir feat'in kural metni, kutuphane kaydindan kurulup cevrilmis hali.
///
/// Karakter kagidina ve seviye atlama listesine feat metni duz bir birlestirme
/// olarak yaziliyor, ceviri ise parca parca tutuluyor; bu yuzden metin kayittan
/// yeniden kuruluyor. Kayit bulunamazsa [fallback] gosterilir.
class FeatRuleText extends ConsumerWidget {
  const FeatRuleText({
    required this.featKey,
    required this.fallback,
    super.key,
  });

  final String featKey;
  final String fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feat = ref.watch(featByKeyProvider(featKey)).value;
    final tr = contentTrOf(context, ref, 'feats');
    return GameText(feat == null ? fallback : composeFeatText(feat, tr));
  }
}

/// Feat ayrintilari: tip, onkosul ve aciklama.
class FeatDetail extends ConsumerWidget {
  const FeatDetail({required this.feat, super.key});

  final Feat feat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tr = contentTrOf(context, ref, 'feats');
    final glossary = glossaryTrOf(context, ref);
    final names = contentNamesTrOf(context, ref);
    final data = jsonDecode(feat.dataJson) as Map<String, dynamic>;
    final desc = composeFeatText(feat, tr);
    // Kategori ve onkosul `tools/fetch_open5e.dart` tarafindan duz metne
    // normalize ediliyor. Yine de CAST EDILMIYOR: bu alanlar bir zamanlar
    // 54 kayitta ham 5etools nesnesi olarak geliyordu ve `as String?` tip
    // hatasi verip panelin yerine gri kutu ciziyordu.
    final subtitle = [
      glossary.term('featTypes', '${data['type'] ?? ''}'),
      glossary.term('featPrerequisites', '${data['prerequisite'] ?? ''}'),
    ].where((s) => s.isNotEmpty).join(' · ');

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(
          names.term('feats', feat.name),
          style: theme.textTheme.headlineSmall,
        ),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 12),
        GameText(desc),
      ],
    );
  }
}

/// Irk ayrintilari: ozellikler listesi.
class SpeciesDetail extends ConsumerWidget {
  const SpeciesDetail({required this.species, super.key});

  final SpeciesEntry species;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tr = contentTrOf(context, ref, 'species');
    final names = contentNamesTrOf(context, ref);
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
                      text:
                          '${names.term('speciesTraits', '${t['name'] ?? ''}')}.\n',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: tr.part(
                        species.key,
                        'traits',
                        '${t['name'] ?? ''}',
                        '${t['desc'] ?? ''}',
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

/// Geçmiş ayrintilari: yetenek/fayda listesi.
class BackgroundDetail extends ConsumerWidget {
  const BackgroundDetail({required this.background, super.key});

  final Background background;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tr = contentTrOf(context, ref, 'backgrounds');
    final names = contentNamesTrOf(context, ref);
    final data = jsonDecode(background.dataJson) as Map<String, dynamic>;
    final benefits = data['benefits'] as List? ?? const [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(background.name, style: theme.textTheme.headlineSmall),
        if ('${data['desc'] ?? ''}'.isNotEmpty) ...[
          const SizedBox(height: 8),
          GameText(tr.desc(background.key, '${data['desc']}')),
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
                      text:
                          '${names.term('backgroundBenefits', '${b['name'] ?? ''}')}.\n',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: tr.part(
                        background.key,
                        'benefits',
                        '${b['name'] ?? ''}',
                        '${b['desc'] ?? ''}',
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}
