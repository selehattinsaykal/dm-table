import 'dart:convert';

import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/db/tables.dart';
import 'package:dm_table/data/compendium_repository.dart';
import 'package:dm_table/data/import/asset_importer.dart';
import 'package:dm_table/domain/models/ability.dart';
import 'package:dm_table/domain/rules/origin_parsing.dart';
// drift, SQL tarafi icin ayni adda matcher'lar da disa aciyor; testte
// matcher paketininkiler gecerli olmali.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Paketlenmis SRD verisinin gercekten ve eksiksiz ice aktarildigini dogrular.
/// Sahte fixture yerine `assets/data` altindaki asil dosyalar kullaniliyor;
/// veri seti degisirse bu testler bunu yakalamali.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late AssetImporter importer;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    importer = AssetImporter(db);
  });

  tearDown(() async => db.close());

  test('paketlenmis veri beklenen sayilarla ice aktarilir', () async {
    expect(await importer.importIfNeeded(), isTrue);

    Future<int> count(TableInfo table) async {
      final row = await db
          .customSelect('SELECT COUNT(*) AS c FROM ${table.actualTableName}')
          .getSingle();
      return row.read<int>('c');
    }

    expect(await count(db.monsters), 619);
    expect(await count(db.spells), 427);
    expect(await count(db.items), 460);
    expect(await count(db.magicItems), 1019);
    expect(await count(db.classDefinitions), 81);
    expect(await count(db.speciesEntries), 26);
    expect(await count(db.backgrounds), 55);
    expect(await count(db.feats), 150);
  });

  test('ikinci calistirmada is yapmaz', () async {
    expect(await importer.importIfNeeded(), isTrue);
    expect(await importer.importIfNeeded(), isFalse);
  });

  /// Kaynak kitaplar (Eberron/Ravenloft/Faerûn) elle donusturulen dosyalardan
  /// geliyor; semasi SRD'den kayarsa uygulama sessizce bos alan gosteriyor.
  /// Bir kez oldu: alt siniflar `subclass_of` bagi tutmadigi icin sinif
  /// listesinde bagimsiz sinif gibi gorunduler.
  group('kaynak kitap kayitlari SRD semasini izler', () {
    const bookDocs = {'eberron-forge', 'ravenloft-horrors', 'faerun-heroes'};

    setUp(() async => importer.importIfNeeded());

    test('alt siniflar var olan bir ana sinifa baglanir', () async {
      final all = await db.select(db.classDefinitions).get();
      final keys = {for (final c in all) c.key};

      expect(all.where((c) => bookDocs.contains(c.document)), isNotEmpty);
      for (final c in all) {
        final data = jsonDecode(c.dataJson) as Map<String, dynamic>;
        if (data['subclass_of'] == null) {
          // Temel siniflar sinif tablosu icin hit_dice/caster_type tasimali.
          expect(c.hitDice, isNotNull, reason: '${c.key} vurus zari yok');
          expect(c.casterType, isNotNull, reason: '${c.key} buyu tipi yok');
          continue;
        }
        expect(
          keys,
          contains(c.subclassOf),
          reason: '${c.key} tanimsiz bir ana sinifa bagli: ${c.subclassOf}',
        );
      }

      // 12 SRD sinifi + Eberron'un Artificer'i; geri kalani alt sinif.
      final baseClasses = all.where((c) => c.subclassOf == null);
      expect(baseClasses, hasLength(13));
      // Her sinifin en az PHB'nin dort alt sinifi olmali.
      final perClass = <String, int>{};
      for (final c in all.where((c) => c.subclassOf != null)) {
        perClass.update(c.subclassOf!, (v) => v + 1, ifAbsent: () => 1);
      }
      for (final base in baseClasses) {
        expect(
          perClass[base.key] ?? 0,
          greaterThanOrEqualTo(4),
          reason: '${base.key} alt siniflari eksik',
        );
      }
    });

    test('canavarlar ve buyuler arayuzun okudugu alanlari tasir', () async {
      final monster =
          await (db.select(db.monsters)
                ..where((t) => t.key.equals('eberron-forge_cannith-artificer')))
              .getSingle();
      final data = jsonDecode(monster.dataJson) as Map<String, dynamic>;
      expect(monster.armorClass, isNotNull);
      expect(monster.experiencePoints, 1100);
      expect((data['ability_scores'] as Map)['strength'], isA<int>());
      expect((data['saving_throws'] as Map)['intelligence'], isA<int>());
      expect(data['passive_perception'], isA<int>());
      expect(data['resistances_and_immunities'], isA<Map>());
      // 5etools isaretlemesi duz metne cevrilmis olmali.
      expect('${data['actions']}', isNot(contains('{@')));

      final spell = await (db.select(
        db.spells,
      )..where((t) => t.document.equals('faerun-heroes'))).get();
      expect(spell, isNotEmpty);
      for (final s in spell) {
        final row = jsonDecode(s.dataJson) as Map<String, dynamic>;
        expect(row['verbal'], isA<bool>());
        expect(row['somatic'], isA<bool>());
        expect(row['material'], isA<bool>());
        expect('${row['desc']}', isNot(contains('{@')));
      }
    });

    test(
      'Artificer temel ozellik tablosu sihirbaz icin ayristirilabilir',
      () async {
        final artificer = await (db.select(
          db.classDefinitions,
        )..where((t) => t.key.equals('eberron-forge_artificer'))).getSingle();
        final features =
            (jsonDecode(artificer.dataJson) as Map<String, dynamic>)['features']
                as List;
        final core = features.firstWhere(
          (f) => (f as Map)['feature_type'] == 'CORE_TRAITS_TABLE',
        );

        final traits = parseClassCoreTraits('${(core as Map)['desc']}');
        expect(traits.hitDieSides, 8);
        expect(traits.skillChoiceCount, 2);
        expect(traits.savingThrows, {
          Ability.constitution,
          Ability.intelligence,
        });
        expect(traits.equipmentOptions, hasLength(2));
        expect(traits.equipmentOptions.last.goldPieces, 150);

        // Buyu yuvasi sutunlari ilerleme tablosuna dusmus olmali.
        final level1 =
            await (db.select(db.classProgressions)..where(
                  (t) =>
                      t.classKey.equals('eberron-forge_artificer') &
                      t.level.equals(1),
                ))
                .getSingle();
        expect(jsonDecode(level1.spellSlotsJson), {'1': 2});
      },
    );

    test('gecmisler ve esyalar ayristirilabilir metin verir', () async {
      final background = await (db.select(
        db.backgrounds,
      )..where((t) => t.document.equals('faerun-heroes'))).get();
      expect(background, isNotEmpty);
      for (final b in background) {
        final benefits =
            (jsonDecode(b.dataJson) as Map<String, dynamic>)['benefits']
                as List;
        final types = {for (final x in benefits) '${(x as Map)['type']}'};
        expect(
          types,
          containsAll(<String>[
            'ability_score',
            'skill_proficiency',
            'equipment',
          ]),
          reason: '${b.key} fayda tipleri eksik',
        );
      }

      // Fiyat "38.00" gibi duz gp sayisi olmali; "38 gp" ayristirilamiyor.
      final item = await (db.select(
        db.items,
      )..where((t) => t.document.equals('faerun-heroes'))).get();
      expect(item.where((i) => i.costCp != null), isNotEmpty);
    });
  });

  test('distinctDocuments yalnizca belgeli kaynaklari dondurur', () async {
    await importer.importIfNeeded();
    final repo = CompendiumRepository(db);

    // SRD verisi 'srd-2024' belgesiyle gelir.
    final docs = await repo.distinctDocuments();
    expect(docs, contains('srd-2024'));
    expect(docs, isNot(contains('')));

    // Yeni kaynak kitap doksan belgeye gore filtrelenir.
    await db
        .into(db.feats)
        .insert(
          FeatsCompanion.insert(
            key: 'eberron_test_feat',
            name: 'Test Feat',
            nameLower: 'test feat',
            document: const Value('eberron-forge'),
            dataJson: '{}',
          ),
        );
    final docs2 = await repo.distinctDocuments();
    expect(docs2, contains('eberron-forge'));
  });

  test('DM\'in kendi icerigi yeniden ice aktarmada silinmez', () async {
    await importer.importIfNeeded();

    await db
        .into(db.monsters)
        .insert(
          MonstersCompanion.insert(
            key: 'custom_kapi-bekcisi',
            name: 'Kapı Bekçisi',
            nameLower: 'kapı bekçisi',
            dataJson: '{}',
            sourceType: const Value(SourceType.custom),
          ),
        );

    // Paketlenmis veri guncellenmis gibi zorla yeniden aktar.
    await db.delete(db.contentVersions).go();
    expect(await importer.importIfNeeded(), isTrue);

    final mine = await (db.select(
      db.monsters,
    )..where((t) => t.key.equals('custom_kapi-bekcisi'))).getSingleOrNull();
    expect(mine, isNotNull, reason: 'homebrew kayit silinmemeli');

    // SRD tarafi da tekrar yazilmis olmali, kopya olusmamali.
    // 619 paketlenmis canavar (333 SRD + 172 MM + 15 PHB yoldasi + 28 Eberron +
    // 70 Ravenloft + 1 Faerun) + 1 homebrew = 620.
    final srdCount = await db
        .customSelect('SELECT COUNT(*) AS c FROM monsters')
        .getSingle();
    expect(srdCount.read<int>('c'), 620);
  });

  group('sinif ilerleme tablosu', () {
    setUp(() async => importer.importIfNeeded());

    Future<ClassProgression> row(String classKey, int level) =>
        (db.select(db.classProgressions)..where(
              (t) => t.classKey.equals(classKey) & t.level.equals(level),
            ))
            .getSingle();

    test('Wizard 5. seviyede 3. seviye yuva acar ve PB 3 olur', () async {
      final r = await row('srd-2024_wizard', 5);
      expect(r.proficiencyBonus, 3);

      final slots = jsonDecode(r.spellSlotsJson) as Map<String, dynamic>;
      expect(slots['1'], 4);
      expect(slots['2'], 3);
      expect(slots['3'], 2);
      expect(slots.containsKey('4'), isFalse);
    });

    test('Wizard 20. seviyede 9. seviye yuvasi var', () async {
      final slots =
          jsonDecode((await row('srd-2024_wizard', 20)).spellSlotsJson)
              as Map<String, dynamic>;
      expect(slots['9'], 1);
    });

    test('Barbarian buyu yapmaz ama sinif sayaclarini tasir', () async {
      final r = await row('srd-2024_barbarian', 1);
      expect(jsonDecode(r.spellSlotsJson), isEmpty);

      final table = jsonDecode(r.classTableJson) as Map<String, dynamic>;
      expect(table['Rages'], '2');
      expect(table['Rage Damage'], '+2');
    });

    test('ASI seviyelerinde feature kazanilir', () async {
      for (final level in [4, 8, 12, 16]) {
        final keys =
            jsonDecode((await row('srd-2024_barbarian', level)).featureKeysJson)
                as List;
        expect(
          keys.any((k) => '$k'.contains('ability-score-improvement')),
          isTrue,
          reason: '$level. seviyede ASI bekleniyordu',
        );
      }
    });

    test('her ana sinif 20 seviye tasir', () async {
      final rows = await db
          .customSelect(
            'SELECT class_key, COUNT(*) AS c FROM class_progressions '
            'GROUP BY class_key HAVING c = 20',
          )
          .get();
      expect(rows.length, greaterThanOrEqualTo(12));
    });
  });

  group('buyulu esya fiyatlandirmasi', () {
    setUp(() async => importer.importIfNeeded());

    test('SRD fiyat vermedigi icin nadirlikten oneri uretilir', () async {
      final all = await db.select(db.magicItems).get();
      expect(all.every((i) => i.costIsSuggested), isTrue);

      final withPrice = all.where((i) => i.costCp != null);
      expect(
        withPrice.length,
        greaterThan(700),
        reason: 'nadirligi olan her esyaya fiyat onerilmeli',
      );
    });

    test('nadirlik arttikca onerilen fiyat artar', () async {
      Future<int> priceOf(String rarity) async {
        final item =
            await (db.select(db.magicItems)
                  ..where((t) => t.rarity.equals(rarity))
                  ..limit(1))
                .getSingle();
        return item.costCp!;
      }

      expect(await priceOf('Common'), lessThan(await priceOf('Uncommon')));
      expect(await priceOf('Uncommon'), lessThan(await priceOf('Rare')));
      expect(await priceOf('Rare'), lessThan(await priceOf('Very Rare')));
    });
  });

  test('buyusuz esyalarin gercek fiyati bakira cevrilir', () async {
    await importer.importIfNeeded();

    final plate = await (db.select(
      db.items,
    )..where((t) => t.nameLower.equals('plate armor'))).getSingleOrNull();

    expect(plate, isNotNull);
    // SRD: Plate Armor 1.500 gp -> 150.000 cp
    expect(plate!.costCp, 150000);
  });
}
