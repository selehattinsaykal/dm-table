import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/models/ability.dart';
import '../domain/rules/magic_item_pricing.dart';
import '../domain/search_text.dart';
import 'db/database.dart';
import 'db/tables.dart';
import 'import/class_progression_builder.dart';

/// Alt sinifin belirli bir seviyede kazandirdigi yetenek.
typedef SubclassFeature = ({int level, String name, String description});

/// Seviyeye gore degisen bir sayac; or. Superiority Dice: 3->4, 7->5.
///
/// Degerler metin: SRD'de "+2" gibi isaretli ve "1d8" gibi zar iceren
/// sutunlar da var.
typedef SubclassResource = ({String name, Map<int, String> valuesByLevel});

/// DM'in kendi ekledigi icerigi yazar.
///
/// Kayitlar SRD icerigiyle ayni tablolara, [SourceType.custom] etiketiyle
/// girer: kutuphanede yan yana gorunur, filtrelenebilir ve yeniden ice
/// aktarmada silinmez. Open5e'nin sekline uydurulur ki ayristiricilar ve
/// detay ekranlari ayni kodu kullansin.
class CustomContentRepository {
  CustomContentRepository(this.db);

  final AppDatabase db;

  static String keyFor(String prefix, String name) {
    final slug = searchNormalize(
      name,
    ).replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
    return 'custom_${prefix}_${slug.isEmpty ? DateTime.now().millisecondsSinceEpoch : slug}';
  }

  Future<String> addSpecies({
    required String name,
    String size = 'Medium',
    int speed = 30,
    String description = '',
  }) async {
    final key = keyFor('species', name);
    await db
        .into(db.speciesEntries)
        .insertOnConflictUpdate(
          SpeciesEntriesCompanion.insert(
            key: key,
            name: name,
            nameLower: searchNormalize(name),
            sourceType: const Value(SourceType.custom),
            dataJson: jsonEncode({
              'key': key,
              'name': name,
              'desc': description,
              'is_subspecies': false,
              'traits': [
                {'name': 'Size', 'type': 'SIZE', 'desc': size},
                {'name': 'Speed', 'type': 'SPEED', 'desc': '$speed feet'},
                if (description.isNotEmpty)
                  {'name': name, 'type': null, 'desc': description},
              ],
            }),
          ),
        );
    return key;
  }

  /// 2024 background'i: uc yetenek secenegi, iki beceri, bir koken feat'i.
  Future<String> addBackground({
    required String name,
    required List<Ability> abilityOptions,
    required List<Skill> skills,
    String? featName,
    String? toolText,
    int startingGoldGp = 50,
  }) async {
    final key = keyFor('background', name);
    await db
        .into(db.backgrounds)
        .insertOnConflictUpdate(
          BackgroundsCompanion.insert(
            key: key,
            name: name,
            nameLower: searchNormalize(name),
            sourceType: const Value(SourceType.custom),
            dataJson: jsonEncode({
              'key': key,
              'name': name,
              'desc': '',
              'benefits': [
                {
                  'type': 'ability_score',
                  'name': 'Ability Scores',
                  'desc': abilityOptions.map((a) => a.label).join(', '),
                },
                {
                  'type': 'skill_proficiency',
                  'name': 'Skill Proficiencies',
                  'desc': skills.map((s) => s.label).join(' and '),
                },
                if (toolText != null && toolText.isNotEmpty)
                  {
                    'type': 'tool_proficiency',
                    'name': 'Tool Proficiency',
                    'desc': toolText,
                  },
                if (featName != null && featName.isNotEmpty)
                  {'type': 'feat', 'name': 'Feat', 'desc': featName},
                {
                  'type': 'equipment',
                  'name': 'Equipment',
                  'desc': '(A) $startingGoldGp GP',
                },
              ],
            }),
          ),
        );
    return key;
  }

  /// Homebrew canavar.
  ///
  /// Kutuphanedeki SRD canavarlariyla ayni sekilde saklanir; boylece savas
  /// takipcisi, stat blok gorunumu ve arama hicbir ozel durum bilmeden
  /// calisir.
  Future<String> addMonster({
    required String name,
    required double challengeRating,
    required int armorClass,
    required int hitPoints,
    String size = 'Medium',
    String creatureType = 'Humanoid',
    String alignment = '',
    String hitDice = '',
    Map<String, int> abilityScores = const {},
    List<({String name, String description})> actions = const [],
    List<({String name, String description})> traits = const [],
    int speed = 30,
    String description = '',
  }) async {
    final key = keyFor('monster', name);
    final scores = {
      'strength': 10,
      'dexterity': 10,
      'constitution': 10,
      'intelligence': 10,
      'wisdom': 10,
      'charisma': 10,
      ...abilityScores,
    };

    await db
        .into(db.monsters)
        .insertOnConflictUpdate(
          MonstersCompanion.insert(
            key: key,
            name: name,
            nameLower: searchNormalize(name),
            sourceType: const Value(SourceType.custom),
            creatureType: Value(creatureType),
            size: Value(size),
            challengeRating: Value(challengeRating),
            armorClass: Value(armorClass),
            hitPoints: Value(hitPoints),
            experiencePoints: Value(_experienceFor(challengeRating)),
            dataJson: jsonEncode({
              'key': key,
              'name': name,
              'desc': description,
              'size': {'name': size},
              'type': {'name': creatureType},
              'alignment': alignment,
              'challenge_rating': challengeRating,
              'armor_class': armorClass,
              'hit_points': hitPoints,
              'hit_dice': hitDice,
              'speed': {'walk': speed, 'unit': 'feet'},
              'ability_scores': scores,
              'modifiers': {
                for (final e in scores.entries)
                  e.key: ((e.value - 10) / 2).floor(),
              },
              'actions': [
                for (final a in actions)
                  {
                    'name': a.name,
                    'desc': a.description,
                    'action_type': 'ACTION',
                    'attacks': <dynamic>[],
                  },
              ],
              'traits': [
                for (final t in traits) {'name': t.name, 'desc': t.description},
              ],
            }),
          ),
        );
    return key;
  }

  /// CR -> deneyim puani. SRD canavarlarindaki degerlerle ayni olcek.
  static int _experienceFor(double cr) => switch (cr) {
    0 => 10,
    0.125 => 25,
    0.25 => 50,
    0.5 => 100,
    1 => 200,
    2 => 450,
    3 => 700,
    4 => 1100,
    5 => 1800,
    6 => 2300,
    7 => 2900,
    8 => 3900,
    9 => 5000,
    10 => 5900,
    11 => 7200,
    12 => 8400,
    13 => 10000,
    14 => 11500,
    15 => 13000,
    16 => 15000,
    17 => 18000,
    18 => 20000,
    19 => 22000,
    20 => 25000,
    21 => 33000,
    22 => 41000,
    23 => 50000,
    24 => 62000,
    25 => 75000,
    26 => 90000,
    27 => 105000,
    28 => 120000,
    29 => 135000,
    30 => 155000,
    _ => 0,
  };

  /// Buyusuz esya. Fiyat altin cinsinden alinir, bakira cevrilir.
  Future<String> addItem({
    required String name,
    required int costGp,
    String category = 'Adventuring Gear',
    double weightLb = 0,
    String description = '',
  }) async {
    final key = keyFor('item', name);
    await db
        .into(db.items)
        .insertOnConflictUpdate(
          ItemsCompanion.insert(
            key: key,
            name: name,
            nameLower: searchNormalize(name),
            sourceType: const Value(SourceType.custom),
            category: Value(category),
            costCp: Value(costGp * copperPerGold),
            weightLb: Value(weightLb),
            dataJson: jsonEncode({
              'key': key,
              'name': name,
              'desc': description,
              'category': {'name': category},
              'cost': '$costGp.00',
              'weight': '$weightLb',
            }),
          ),
        );
    return key;
  }

  /// Buyulu esya.
  ///
  /// Fiyat verilmezse nadirlikten onerilir -- SRD'nin kendisi de buyulu
  /// esyalara fiyat yazmadigi icin ayni davranis.
  Future<String> addMagicItem({
    required String name,
    required String rarityKey,
    int? costGp,
    bool requiresAttunement = false,
    String category = 'Wondrous item',
    String description = '',
  }) async {
    final key = keyFor('magicitem', name);
    final rarityName = _rarityNames[rarityKey] ?? rarityKey;
    final rank = _rarityRanks[rarityKey];

    await db
        .into(db.magicItems)
        .insertOnConflictUpdate(
          MagicItemsCompanion.insert(
            key: key,
            name: name,
            nameLower: searchNormalize(name),
            sourceType: const Value(SourceType.custom),
            category: Value(category),
            rarity: Value(rarityName),
            rarityRank: Value(rank),
            requiresAttunement: Value(requiresAttunement),
            costCp: Value(
              costGp != null
                  ? costGp * copperPerGold
                  : suggestedPriceCp(
                      rarityKey,
                      requiresAttunement: requiresAttunement,
                    ),
            ),
            costIsSuggested: Value(costGp == null),
            dataJson: jsonEncode({
              'key': key,
              'name': name,
              'desc': description,
              'category': {'name': category},
              'rarity': {'name': rarityName, 'key': rarityKey, 'rank': rank},
              'requires_attunement': requiresAttunement,
            }),
          ),
        );
    return key;
  }

  /// Homebrew buyu.
  ///
  /// SRD buyulariyla ayni sekilde saklanir: filtreye giren alanlar (seviye,
  /// okul, konsantrasyon, ritual) gercek kolon; geri kalani Open5e seklinde
  /// [dataJson] icinde, boylece arama ve detay ekrani ayni kodu kullanir.
  Future<String> addSpell({
    required String name,
    required int level,
    String? school,
    String castingTime = '1 action',
    String rangeText = '',
    String duration = '',
    bool verbal = false,
    bool somatic = false,
    bool material = false,
    String? materialSpecified,
    bool concentration = false,
    bool ritual = false,
    String description = '',
    String higherLevel = '',
    List<String> classes = const [],
  }) async {
    final key = keyFor('spell', name);
    await db
        .into(db.spells)
        .insertOnConflictUpdate(
          SpellsCompanion.insert(
            key: key,
            name: name,
            nameLower: searchNormalize(name),
            sourceType: const Value(SourceType.custom),
            level: Value(level),
            school: Value(school),
            castingTime: Value(castingTime),
            concentration: Value(concentration),
            ritual: Value(ritual),
            classesCsv: Value(classes.join(',')),
            dataJson: jsonEncode({
              'key': key,
              'name': name,
              'level': level,
              'school': school == null ? null : {'name': school},
              'casting_time': castingTime,
              'range_text': rangeText,
              'duration': duration,
              'verbal': verbal,
              'somatic': somatic,
              'material': material,
              'material_specified': materialSpecified,
              'concentration': concentration,
              'ritual': ritual,
              'desc': description,
              'higher_level': higherLevel,
              'classes': [
                for (final c in classes) {'name': c},
              ],
            }),
          ),
        );
    return key;
  }

  static const _rarityNames = <String, String>{
    'common': 'Common',
    'uncommon': 'Uncommon',
    'rare': 'Rare',
    'very-rare': 'Very Rare',
    'legendary': 'Legendary',
    'artifact': 'Artifact',
  };

  static const _rarityRanks = <String, int>{
    'common': 1,
    'uncommon': 2,
    'rare': 3,
    'very-rare': 4,
    'legendary': 5,
    'artifact': 6,
  };

  /// Alt sinif.
  ///
  /// SRD alt siniflariyla BIREBIR ayni sekilde saklanir: yetenekler
  /// `features[].gained_at`, sayaclar `data_for_class_table` icinde. Boylece
  /// ilerleme tablosu, level atlama akisi ve karakter kagidi bunun homebrew
  /// oldugunu hic bilmeden calisir.
  Future<String> addSubclass({
    required String name,
    required String parentClassKey,
    required String parentClassName,
    String description = '',
    List<SubclassFeature> features = const [],
    List<SubclassResource> resources = const [],
  }) async {
    final key = keyFor('subclass', name);

    final payload = {
      'key': key,
      'name': name,
      'desc': description,
      'subclass_of': {'key': parentClassKey, 'name': parentClassName},
      'features': [
        for (final (index, feature) in features.indexed)
          {
            'key': '${key}_feature_$index',
            'name': feature.name,
            'desc': feature.description,
            'feature_type': 'CLASS_LEVEL_FEATURE',
            'gained_at': [
              {'level': feature.level, 'detail': null},
            ],
            'data_for_class_table': <dynamic>[],
          },
        for (final resource in resources)
          {
            'key': '${key}_resource_${searchNormalize(resource.name)}',
            'name': resource.name,
            'desc': '',
            'feature_type': 'CLASS_TABLE_DATA',
            'gained_at': <dynamic>[],
            'data_for_class_table': _expandResource(resource),
          },
      ],
    };

    await db.transaction(() async {
      await db
          .into(db.classDefinitions)
          .insertOnConflictUpdate(
            ClassDefinitionsCompanion.insert(
              key: key,
              name: name,
              nameLower: searchNormalize(name),
              sourceType: const Value(SourceType.custom),
              subclassOf: Value(parentClassKey),
              dataJson: jsonEncode(payload),
            ),
          );
      await _writeProgression(key, payload);
    });

    return key;
  }

  /// Alt sinifin ilerleme satirlarini yazar.
  ///
  /// SRD icerigi ice aktarma sirasinda uretiliyor; homebrew icin ayni islem
  /// kaydetme aninda yapiliyor ki level atlama akisi ikisini ayirt etmesin.
  Future<void> _writeProgression(
    String classKey,
    Map<String, dynamic> payload,
  ) async {
    await (db.delete(
      db.classProgressions,
    )..where((t) => t.classKey.equals(classKey))).go();

    final rows = buildProgression(payload);
    if (rows.isEmpty) return;

    await db.batch(
      (b) => b.insertAll(db.classProgressions, [
        for (final row in rows)
          ClassProgressionsCompanion.insert(
            classKey: row.classKey,
            level: row.level,
            proficiencyBonus: row.proficiencyBonus,
            spellSlotsJson: Value(row.spellSlotsJson),
            classTableJson: Value(row.classTableJson),
            featureKeysJson: Value(row.featureKeysJson),
          ),
      ]),
    );
  }

  /// Sayac esiklerini her seviyeye yayar.
  ///
  /// Kullanici "3. seviyede 4, 7. seviyede 5" giriyor; SRD verisi ise her
  /// seviye icin bir satir tutuyor. Esikler ileriye dogru dolduruluyor ki
  /// ayni sekle otursun.
  static List<Map<String, dynamic>> _expandResource(SubclassResource resource) {
    final thresholds = resource.valuesByLevel.keys.toList()..sort();
    if (thresholds.isEmpty) return const [];

    final rows = <Map<String, dynamic>>[];
    String? current;
    for (var level = 1; level <= 20; level++) {
      if (resource.valuesByLevel.containsKey(level)) {
        current = resource.valuesByLevel[level];
      }
      // Ilk esikten once sayac henuz yok.
      if (current == null) continue;
      rows.add({'level': level, 'column_value': current});
    }
    return rows;
  }
}
