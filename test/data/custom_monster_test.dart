import 'dart:convert';

import 'package:dm_table/data/combat_repository.dart';
import 'package:dm_table/data/custom_content_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/db/tables.dart';
import 'package:dm_table/data/import/asset_importer.dart';
// `like` drift'in Expression uzantisi; matcher'larla cakisanlar gizleniyor.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Homebrew canavarlar SRD canavarlariyla ayni sekilde saklanmali: kutuphane,
/// arama ve savas takipcisi hicbir ozel durum bilmeden calisabilsin.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CustomContentRepository custom;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await AssetImporter(db).importIfNeeded();
    custom = CustomContentRepository(db);
  });

  tearDown(() async => db.close());

  Future<Monster> created() async => (db.select(
    db.monsters,
  )..where((t) => t.sourceType.equalsValue(SourceType.custom))).getSingle();

  test('canavar kutuphaneye SRD kayitlariyla ayni sekilde yazilir', () async {
    await custom.addMonster(
      name: 'Bataklık Sürüngeni',
      challengeRating: 3,
      armorClass: 15,
      hitPoints: 65,
      size: 'Large',
      creatureType: 'Monstrosity',
      abilityScores: const {'strength': 18, 'dexterity': 8},
      actions: const [
        (name: 'Bite', description: 'Melee Attack Roll: +6, 12 (2d8 + 3).'),
      ],
    );

    final monster = await created();
    expect(monster.name, 'Bataklık Sürüngeni');
    expect(monster.challengeRating, 3);
    expect(monster.armorClass, 15);
    expect(monster.hitPoints, 65);
    expect(monster.size, 'Large');
    expect(monster.creatureType, 'Monstrosity');
    expect(monster.sourceType, SourceType.custom);
    // CR 3 -> 700 XP
    expect(monster.experiencePoints, 700);

    final data = jsonDecode(monster.dataJson) as Map<String, dynamic>;
    expect((data['ability_scores'] as Map)['strength'], 18);
    // Modifier'lar da yazilmali; stat blok bunlari okuyor.
    expect((data['modifiers'] as Map)['strength'], 4);
    expect((data['modifiers'] as Map)['dexterity'], -1);
    expect((data['actions'] as List).single['name'], 'Bite');
  });

  test('turkce adla arama calisir', () async {
    await custom.addMonster(
      name: 'Işık Cini',
      challengeRating: 1,
      armorClass: 13,
      hitPoints: 20,
    );

    // Kucuk harfe cevrimde "I" -> "ı" oldugu icin aramada bulunmali.
    final found = await (db.select(
      db.monsters,
    )..where((t) => t.nameLower.like('%ışık%'))).get();
    expect(found.single.name, 'Işık Cini');
  });

  test('yeniden ice aktarmada silinmez', () async {
    await custom.addMonster(
      name: 'Kapı Bekçisi',
      challengeRating: 2,
      armorClass: 14,
      hitPoints: 40,
    );

    await db.delete(db.contentVersions).go();
    await AssetImporter(db).importIfNeeded();

    expect((await created()).name, 'Kapı Bekçisi');
  });

  test('savas takipcisine SRD canavari gibi eklenebilir', () async {
    await custom.addMonster(
      name: 'Gölge Kurdu',
      challengeRating: 2,
      armorClass: 14,
      hitPoints: 33,
    );

    final combat = CombatRepository(db);
    final encounterId = await combat.createEncounter('Test');
    await combat.addMonsters(
      encounterId: encounterId,
      monster: await created(),
      count: 2,
    );

    final rows = await combat.combatants(encounterId);
    expect(rows.length, 2);
    expect(rows.first.name, startsWith('Gölge Kurdu'));
    expect(rows.first.hitPointsMax, 33);
    expect(rows.first.armorClass, 14);
  });

  test('ayni ad tekrar kaydedilince kopya olusmaz', () async {
    await custom.addMonster(
      name: 'Tekrar',
      challengeRating: 1,
      armorClass: 12,
      hitPoints: 10,
    );
    await custom.addMonster(
      name: 'Tekrar',
      challengeRating: 5,
      armorClass: 17,
      hitPoints: 90,
    );

    final all = await (db.select(
      db.monsters,
    )..where((t) => t.sourceType.equalsValue(SourceType.custom))).get();
    expect(all.length, 1, reason: 'ayni anahtar guncellenmeli');
    expect(all.single.hitPoints, 90);
  });
}
