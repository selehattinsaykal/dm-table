import 'dart:convert';

import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/db/tables.dart';
import 'package:dm_table/data/import/asset_importer.dart';
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

    expect(await count(db.monsters), 505);
    expect(await count(db.spells), 407);
    expect(await count(db.items), 352);
    expect(await count(db.magicItems), 1009);
    expect(await count(db.classDefinitions), 60);
    expect(await count(db.speciesEntries), 17);
    expect(await count(db.backgrounds), 16);
    expect(await count(db.feats), 81);
  });

  test('ikinci calistirmada is yapmaz', () async {
    expect(await importer.importIfNeeded(), isTrue);
    expect(await importer.importIfNeeded(), isFalse);
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
    // 505 SRD/MM canavari + 1 homebrew = 506.
    final srdCount = await db
        .customSelect('SELECT COUNT(*) AS c FROM monsters')
        .getSingle();
    expect(srdCount.read<int>('c'), 506);
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
