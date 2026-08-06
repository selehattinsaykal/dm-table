import 'dart:convert';

import 'package:dm_table/data/character_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/import/asset_importer.dart';
import 'package:dm_table/domain/models/ability.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dinlenme: uzun dinlenme HP/yuva/hit dice yeniler; kisa dinlenme bir hit die
/// harcayip iyilestirir ve kullanilanlari artirir.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CharacterRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await AssetImporter(db).importIfNeeded();
    repo = CharacterRepository(db);
    await repo.createLevelOneCharacter(
      id: 'c1',
      name: 'Grog',
      classKey: 'srd-2024_fighter',
      abilities: const AbilityScores(constitution: 14),
      savingThrows: const {},
      skills: const {},
      hitDieSides: 10,
    );
  });

  tearDown(() => db.close());

  test('uzun dinlenme HP, yuva ve hit dice yeniler', () async {
    await repo.applyDamage('c1', 5);
    await repo.setSpentSlots('c1', {1: 2});
    // Bir hit die harca (kullanilanlar artsin).
    await repo.spendHitDie('c1');

    await repo.longRest('c1');
    final c = (await repo.find('c1'))!;
    expect(c.hitPointsCurrent, c.hitPointsMax);
    expect(c.spellSlotsUsedJson, '{}');
    expect(c.hitDiceUsedJson, '{}');
    expect(c.temporaryHitPoints, 0);
  });

  test('uzun dinlenme hit dice\'in YARISINI geri verir (2024)', () async {
    // 6. seviye: 6 hit die. Hepsini harca -> molada yalnizca 3'u geri gelmeli.
    await db.customStatement(
      'UPDATE character_class_levels SET level = 6 WHERE character_id = ?',
      ['c1'],
    );
    for (var i = 0; i < 6; i++) {
      await repo.spendHitDie('c1');
    }
    expect((await repo.hitDiceStatus('c1')).used, 6);

    await repo.longRest('c1');
    final status = await repo.hitDiceStatus('c1');
    expect(status.total, 6);
    expect(status.used, 3, reason: 'yarisi geri gelmeli, hepsi degil');

    // Ikinci uzun mola kalanin yarisini daha verir (3 -> 0'a dogru).
    await repo.longRest('c1');
    expect((await repo.hitDiceStatus('c1')).used, 0);
  });

  test('kisa dinlenme bir hit die harcar ve iyilestirir', () async {
    await repo.applyDamage('c1', 8);
    final before = (await repo.find('c1'))!.hitPointsCurrent;

    final spend = await repo.spendHitDie('c1');
    expect(spend, isNotNull);
    expect(spend!.healed >= 1, isTrue);
    // Zarin kendisi de doner: oyuncu panelindeki animasyon buna dayaniyor.
    expect(spend.roll, inInclusiveRange(1, spend.sides));

    final after = (await repo.find('c1'))!;
    expect(after.hitPointsCurrent, before + spend.healed);
    // 1. seviye tek hit die -> kullanilanlar 1.
    final used = jsonDecode(after.hitDiceUsedJson) as Map;
    expect(used.values.fold(0, (s, v) => s + (v as int)), 1);

    // Ikinci deneme: hit die kalmadi.
    expect(await repo.spendHitDie('c1'), isNull);
  });
}
