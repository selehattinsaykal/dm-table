import 'dart:convert';
import 'dart:io' show gzip;

import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../domain/rules/magic_item_pricing.dart';
import '../../domain/search_text.dart';
import '../db/database.dart';
import '../db/tables.dart';
import 'class_progression_builder.dart';

/// `assets/data/*.json.gz` icerigini veritabanina aktarir.
///
/// Ilk acilista bir kez calisir. Paketlenen veri guncellenirse (manifest'teki
/// `fetchedAt` degisirse) yeniden calisir; DM'in kendi olusturdugu ya da
/// kitapligindan ekledigi kayitlar SILINMEZ — yalnizca SRD/OGL kaynakli
/// satirlar tazelenir.
class AssetImporter {
  AssetImporter(this.db);

  final AppDatabase db;

  /// Bu surum, ice aktarma mantigi degistiginde elle artirilir; boylece
  /// veri ayni kalsa bile kullanicilar yeni donusumu alir.
  /// v2: 2024 PHB/DMG/MM icerikleri (canavar, buyu, esya, irk, gecmis, feat)
  /// kullanicilarin cihazinda aktarilsin diye zorunlu yeniden aktarma.
  /// v3: DMG normal esyalari + buyulu esya nadirlik ranklarinin duzeltilmesi.
  /// v4: Yeni kaynak kitaplari (Eberron: Forge of the Artificer, Ravenloft: The
  /// Horrors Within, Forgotten Realms: Heroes of Faerûn) eklendi.
  static const importerVersion = 4;

  static const _referenceKinds = [
    'conditions',
    'damagetypes',
    'spellschools',
    'sizes',
    'alignments',
    'creaturetypes',
    'itemrarities',
    'itemcategories',
    'environments',
    'languages',
    'abilities',
    // Sinif secenekleri: Eldritch Invocation, Metamagic, Maneuver, Rune.
    'optionalfeatures',
  ];

  /// Ice aktarma gerekiyorsa yapar. [onProgress] arayuzde ilerleme gostermek
  /// icin tablo adiyla cagrilir.
  Future<bool> importIfNeeded({void Function(String table)? onProgress}) async {
    final manifest =
        jsonDecode(await rootBundle.loadString('assets/data/manifest.json'))
            as Map<String, dynamic>;
    final fetchedAt = manifest['fetchedAt'] as String;

    final current = await (db.select(
      db.contentVersions,
    )..where((t) => t.id.equals('bundled'))).getSingleOrNull();

    if (current != null &&
        current.fetchedAt == fetchedAt &&
        current.schemaVersion == importerVersion) {
      return false;
    }

    await _import(onProgress: onProgress);

    await db
        .into(db.contentVersions)
        .insertOnConflictUpdate(
          ContentVersionsCompanion.insert(
            id: 'bundled',
            fetchedAt: fetchedAt,
            schemaVersion: importerVersion,
            manifestJson: jsonEncode(manifest),
          ),
        );
    return true;
  }

  Future<void> _import({void Function(String table)? onProgress}) async {
    await db.transaction(() async {
      onProgress?.call('monsters');
      await _replaceBundled(db.monsters, await _load('creatures'), (row) {
        final environments = (row['environments'] as List? ?? const [])
            .map((e) => e is Map ? e['key'] : e)
            .whereType<String>()
            .join(',');
        final hp = row['hit_points'];
        final hpValue = hp is Map
            ? (hp['average'] as num?)?.toInt()
            : (hp as num?)?.toInt();

        return MonstersCompanion.insert(
          key: row['key'] as String,
          name: row['name'] as String,
          nameLower: _lower(row['name'] as String),
          document: Value(row['document'] as String?),
          sourceType: Value(_sourceOf(row)),
          dataJson: jsonEncode(row),
          creatureType: Value(_nestedName(row['type'])),
          size: Value(_nestedName(row['size'])),
          challengeRating: Value(
            (row['challenge_rating'] as num?)?.toDouble() ?? 0,
          ),
          armorClass: Value(
            row['armor_class'] is Map
                ? (row['armor_class']['ac'] as num?)?.toInt()
                : (row['armor_class'] as num?)?.toInt(),
          ),
          hitPoints: Value(hpValue),
          experiencePoints: Value(
            (row['experience_points'] as num?)?.toInt() ??
                (row['xp'] as num?)?.toInt(),
          ),
          environmentsCsv: Value(environments),
        );
      });

      onProgress?.call('spells');
      await _replaceBundled(db.spells, await _load('spells'), (row) {
        final classes = (row['classes'] as List? ?? const [])
            .map((e) => e is Map ? e['key'] : null)
            .whereType<String>()
            .join(',');
        return SpellsCompanion.insert(
          key: row['key'] as String,
          name: row['name'] as String,
          nameLower: _lower(row['name'] as String),
          document: Value(row['document'] as String?),
          sourceType: Value(_sourceOf(row)),
          dataJson: jsonEncode(row),
          level: Value(row['level'] as int? ?? 0),
          school: Value(_nestedName(row['school'])),
          castingTime: Value(row['casting_time'] as String?),
          concentration: Value(row['concentration'] as bool? ?? false),
          ritual: Value(row['ritual'] as bool? ?? false),
          classesCsv: Value(classes),
        );
      });

      onProgress?.call('items');
      await _replaceBundled(db.items, await _load('items'), (row) {
        return ItemsCompanion.insert(
          key: row['key'] as String,
          name: row['name'] as String,
          nameLower: _lower(row['name'] as String),
          document: Value(row['document'] as String?),
          sourceType: Value(_sourceOf(row)),
          dataJson: jsonEncode(row),
          category: Value(_nestedName(row['category'])),
          costCp: Value(parseCostToCp(row['cost'] as String?)),
          weightLb: Value(double.tryParse(row['weight'] as String? ?? '')),
        );
      });

      onProgress?.call('magicItems');
      await _replaceBundled(db.magicItems, await _load('magicitems'), (row) {
        final rarity = row['rarity'];
        final rarityKey = rarity is Map ? rarity['key'] as String? : null;
        final attunement = row['requires_attunement'] as bool? ?? false;
        // SRD buyulu esyalarda fiyat yayinlamaz; yoksa nadirlikten uret.
        final listed = parseCostToCp(row['cost'] as String?);
        return MagicItemsCompanion.insert(
          key: row['key'] as String,
          name: row['name'] as String,
          nameLower: _lower(row['name'] as String),
          document: Value(row['document'] as String?),
          sourceType: Value(_sourceOf(row)),
          dataJson: jsonEncode(row),
          category: Value(_nestedName(row['category'])),
          rarity: Value(rarity is Map ? rarity['name'] as String? : null),
          rarityRank: Value(rarity is Map ? rarity['rank'] as int? : null),
          requiresAttunement: Value(attunement),
          costCp: Value(
            listed ??
                suggestedPriceCp(rarityKey, requiresAttunement: attunement),
          ),
          costIsSuggested: Value(listed == null),
        );
      });

      onProgress?.call('classes');
      final classRows = await _load('classes');
      await _replaceBundled(db.classDefinitions, classRows, (row) {
        final parent = row['subclass_of'];
        return ClassDefinitionsCompanion.insert(
          key: row['key'] as String,
          name: row['name'] as String,
          nameLower: _lower(row['name'] as String),
          document: Value(row['document'] as String?),
          sourceType: Value(_sourceOf(row)),
          dataJson: jsonEncode(row),
          subclassOf: Value(parent is Map ? parent['key'] as String? : null),
          hitDice: Value(row['hit_dice'] as String?),
          casterType: Value(row['caster_type'] as String?),
        );
      });

      onProgress?.call('classProgressions');
      await _importProgressions(classRows);

      onProgress?.call('species');
      await _replaceBundled(db.speciesEntries, await _load('species'), (row) {
        final parent = row['subspecies_of'];
        return SpeciesEntriesCompanion.insert(
          key: row['key'] as String,
          name: row['name'] as String,
          nameLower: _lower(row['name'] as String),
          document: Value(row['document'] as String?),
          sourceType: Value(_sourceOf(row)),
          dataJson: jsonEncode(row),
          isSubspecies: Value(row['is_subspecies'] as bool? ?? false),
          subspeciesOf: Value(parent is Map ? parent['key'] as String? : null),
        );
      });

      onProgress?.call('backgrounds');
      await _replaceBundled(
        db.backgrounds,
        await _load('backgrounds'),
        (row) => BackgroundsCompanion.insert(
          key: row['key'] as String,
          name: row['name'] as String,
          nameLower: _lower(row['name'] as String),
          document: Value(row['document'] as String?),
          sourceType: Value(_sourceOf(row)),
          dataJson: jsonEncode(row),
        ),
      );

      onProgress?.call('feats');
      await _replaceBundled(
        db.feats,
        await _load('feats'),
        (row) => FeatsCompanion.insert(
          key: row['key'] as String,
          name: row['name'] as String,
          nameLower: _lower(row['name'] as String),
          document: Value(row['document'] as String?),
          sourceType: Value(_sourceOf(row)),
          dataJson: jsonEncode(row),
        ),
      );

      onProgress?.call('reference');
      await db.delete(db.referenceEntries).go();
      for (final kind in _referenceKinds) {
        final rows = await _load(kind);
        await db.batch((b) {
          b.insertAll(db.referenceEntries, [
            for (final row in rows)
              ReferenceEntriesCompanion.insert(
                kind: kind,
                key: row['key'] as String? ?? row['name'] as String,
                name: row['name'] as String? ?? '',
                dataJson: jsonEncode(row),
              ),
          ]);
        });
      }
    });
  }

  Future<void> _importProgressions(List<Map<String, dynamic>> classRows) async {
    await db.delete(db.classProgressions).go();
    final companions = <ClassProgressionsCompanion>[];
    for (final row in classRows) {
      for (final p in buildProgression(row)) {
        companions.add(
          ClassProgressionsCompanion.insert(
            classKey: p.classKey,
            level: p.level,
            proficiencyBonus: p.proficiencyBonus,
            spellSlotsJson: Value(p.spellSlotsJson),
            classTableJson: Value(p.classTableJson),
            featureKeysJson: Value(p.featureKeysJson),
          ),
        );
      }
    }
    await db.batch((b) => b.insertAll(db.classProgressions, companions));
  }

  /// Paketlenmis kaynakli satirlari silip yeniden yazar.
  ///
  /// DM'in kendi icerigi (`personal`/`custom`) ayni tabloda durur ama bu
  /// islemden etkilenmez — surekli yeniden ice aktarma yuzunden homebrew'un
  /// kaybolmasi en can yakici hata olurdu.
  Future<void> _replaceBundled<T extends Table, D>(
    TableInfo<T, D> table,
    List<Map<String, dynamic>> rows,
    Insertable<D> Function(Map<String, dynamic>) toCompanion,
  ) async {
    await db.customStatement(
      'DELETE FROM ${table.actualTableName} '
      "WHERE source_type IN ('srd', 'ogl')",
    );
    await db.batch((b) {
      b.insertAll(table, rows.map(toCompanion).toList());
    });
  }

  Future<List<Map<String, dynamic>>> _load(String name) async {
    final bytes = await rootBundle.load('assets/data/$name.json.gz');
    // offset/length ZORUNLU: ByteData paylasilan bir tampona view olabilir
    // (Flutter test asset bundle'i tum asset'leri tek tampona birlestirir);
    // ciplak buffer.asUint8List() o durumda YANLIS/bitisik veriyi doner.
    final compressed = bytes.buffer.asUint8List(
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );
    final json = utf8.decode(gzip.decode(compressed));
    return (jsonDecode(json) as List).cast<Map<String, dynamic>>();
  }

  /// Yeni kaynak kitaplari (Eberron, Ravenloft, Faerûn) open5e API'sinde yok;
  /// elle hazirlanmis dosyalardan geliyor. Hepsi `SourceType.ogl` olarak
  /// isaretlenir ki yeniden ice aktarmada silinmesin.
  static const _oglDocuments = {
    'phb-2024',
    'mm-2024',
    'eberron-forge',
    'ravenloft-horrors',
    'faerun-heroes',
  };

  static SourceType _sourceOf(Map<String, dynamic> row) {
    final doc = row['document'] as String?;
    if (doc == 'srd-2024') return SourceType.srd;
    if (doc != null && _oglDocuments.contains(doc)) return SourceType.ogl;
    return SourceType.ogl;
  }

  static String? _nestedName(Object? value) {
    if (value is Map) {
      final name = value['name'];
      return name?.toString();
    }
    return null;
  }

  static String _lower(String value) => searchNormalize(value);
}
