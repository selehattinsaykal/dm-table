import 'dart:convert';

import 'package:dm_table/data/combat_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/downtime_repository.dart';
import 'package:dm_table/data/encounter_template_repository.dart';
import 'package:dm_table/data/macro_repository.dart';
import 'package:dm_table/domain/rules/damage_types.dart';
import 'package:dm_table/domain/rules/death_saves.dart';
import 'package:dm_table/domain/rules/dice.dart';
import 'package:dm_table/domain/rules/downtime.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Kutuphaneye tek bir canavar yazar.
  Future<Monster> seedMonster({
    String key = 'goblin',
    String name = 'Goblin',
    Map<String, dynamic> extra = const {},
  }) async {
    await db
        .into(db.monsters)
        .insert(
          MonstersCompanion.insert(
            key: key,
            name: name,
            nameLower: name.toLowerCase(),
            hitPoints: const Value(7),
            armorClass: const Value(15),
            dataJson: jsonEncode({'name': name, ...extra}),
          ),
        );
    return (db.select(
      db.monsters,
    )..where((t) => t.key.equals(key))).getSingle();
  }

  group('hasar turu ve savunmalar', () {
    test('direnc gercekten dusen cani azaltir', () async {
      final repo = CombatRepository(db);
      final encounterId = await repo.createEncounter('Test');
      final monster = await seedMonster();
      await repo.addMonsters(encounterId: encounterId, monster: monster);

      final combatant = (await repo.combatants(encounterId)).single;
      await repo.setDefenses(
        combatant.id,
        const Defenses(resistant: {DamageType.fire}),
      );

      final result = await repo.applyDamageTyped(
        combatant.id,
        4,
        type: DamageType.fire,
      );
      expect(result.amount, 2);
      expect(result.modifier, DamageModifier.resistant);

      final after = (await repo.combatants(encounterId)).single;
      expect(after.hitPointsCurrent, 5, reason: '7 - 2');
    });

    test('kutuphane verisinden savunmalar dolar', () async {
      final repo = CombatRepository(db);
      final encounterId = await repo.createEncounter('Test');
      final monster = await seedMonster(
        key: 'dragon',
        name: 'Ejderha',
        extra: {
          'resistances_and_immunities': {
            'damage_immunities': [
              {'key': 'acid', 'name': 'Acid'},
            ],
            'damage_resistances': [
              {'key': 'fire', 'name': 'Fire'},
            ],
          },
        },
      );
      await repo.addMonsters(encounterId: encounterId, monster: monster);

      final combatant = (await repo.combatants(encounterId)).single;
      final defenses = Defenses.decode(combatant.defensesJson);
      expect(defenses.immune, {DamageType.acid});
      expect(defenses.resistant, {DamageType.fire});
    });

    test('bagisik yaratik hic can kaybetmez', () async {
      final repo = CombatRepository(db);
      final encounterId = await repo.createEncounter('Test');
      final monster = await seedMonster();
      await repo.addMonsters(encounterId: encounterId, monster: monster);

      final combatant = (await repo.combatants(encounterId)).single;
      await repo.setDefenses(
        combatant.id,
        const Defenses(immune: {DamageType.poison}),
      );
      await repo.applyDamageTyped(combatant.id, 99, type: DamageType.poison);

      expect((await repo.combatants(encounterId)).single.hitPointsCurrent, 7);
    });
  });

  group('olum kurtarmasi', () {
    Future<Combatant> downed(CombatRepository repo, String encounterId) async {
      final monster = await seedMonster();
      await repo.addMonsters(encounterId: encounterId, monster: monster);
      final combatant = (await repo.combatants(encounterId)).single;
      await repo.applyDamageTyped(combatant.id, 7);
      return (await repo.combatants(encounterId)).single;
    }

    test('0 candayken alinan hasar basarisizlik yazar', () async {
      final repo = CombatRepository(db);
      final encounterId = await repo.createEncounter('Test');
      final combatant = await downed(repo, encounterId);
      expect(combatant.hitPointsCurrent, 0);

      await repo.applyDamageTyped(combatant.id, 3);
      final after = (await repo.combatants(encounterId)).single;
      expect(after.deathSaveFailures, 1);

      await repo.applyDamageTyped(combatant.id, 3, critical: true);
      final third = (await repo.combatants(encounterId)).single;
      expect(third.deathSaveFailures, 3);
      expect(third.defeated, isTrue);
    });

    test('iyilesme sayaci sifirlar', () async {
      final repo = CombatRepository(db);
      final encounterId = await repo.createEncounter('Test');
      final combatant = await downed(repo, encounterId);
      await repo.setDeathSaves(combatant.id, (successes: 1, failures: 2));

      await repo.applyHealing(combatant.id, 4);
      final after = (await repo.combatants(encounterId)).single;
      expect(after.deathSaveFailures, 0);
      expect(after.deathSaveSuccesses, 0);
      expect(after.hitPointsCurrent, 4);
    });

    test('dogal 20 ayaga kaldirir', () async {
      final repo = CombatRepository(db);
      final encounterId = await repo.createEncounter('Test');
      final combatant = await downed(repo, encounterId);

      final result = await repo.rollDeathSaveFor(combatant.id, roll: 20);
      expect(result.state, DeathSaveState.revived);

      final after = (await repo.combatants(encounterId)).single;
      expect(after.hitPointsCurrent, 1);
      expect(after.defeated, isFalse);
    });
  });

  group('reaksiyon ve in eylemi', () {
    test('sira gelince reaksiyon tazelenir', () async {
      final repo = CombatRepository(db);
      final encounterId = await repo.createEncounter('Test');
      final monster = await seedMonster();
      await repo.addMonsters(
        encounterId: encounterId,
        monster: monster,
        count: 2,
      );
      await repo.start(encounterId);

      final rows = await repo.combatants(encounterId);
      // Ikinci katilimci reaksiyonunu harcadi; sira ONA gelince tazelenmeli.
      await repo.setReactionUsed(rows[1].id, true);
      await repo.advanceTurn(encounterId);

      final after = await repo.combatants(encounterId);
      final target = after.firstWhere((c) => c.id == rows[1].id);
      expect(target.reactionUsed, isFalse);
    });

    test('in eylemi esikten gecince tetiklenir', () async {
      final repo = CombatRepository(db);
      final encounterId = await repo.createEncounter('Test');
      final monster = await seedMonster();
      await repo.addMonsters(
        encounterId: encounterId,
        monster: monster,
        count: 2,
      );

      // Inisiyatifleri sabitle: 25 ve 10. Esik 20; aralarindan GECILIYOR.
      final rows = await repo.combatants(encounterId);
      await repo.setInitiative(rows[0].id, 25);
      await repo.setInitiative(rows[1].id, 10);
      await repo.setLairAction(encounterId, text: 'Zemin sarsiliyor.');
      await repo.start(encounterId);

      final result = await repo.advanceTurn(encounterId);
      expect(result.lairAction, 'Zemin sarsiliyor.');
    });

    test('in eylemi tanimli degilse tetiklenmez', () async {
      final repo = CombatRepository(db);
      final encounterId = await repo.createEncounter('Test');
      final monster = await seedMonster();
      await repo.addMonsters(
        encounterId: encounterId,
        monster: monster,
        count: 2,
      );
      await repo.start(encounterId);

      expect((await repo.advanceTurn(encounterId)).lairAction, isNull);
    });
  });

  group('karsilasma kaliplari', () {
    test('kadro toplanip yeniden kurulur', () async {
      final combat = CombatRepository(db);
      final templates = EncounterTemplateRepository(db);
      final encounterId = await combat.createEncounter('Pusu');
      final monster = await seedMonster();
      await combat.addMonsters(
        encounterId: encounterId,
        monster: monster,
        count: 3,
      );

      final id = await templates.saveFrom(
        name: 'Goblin pususu',
        combatants: await combat.combatants(encounterId),
      );
      final template = await (db.select(
        db.encounterTemplates,
      )..where((t) => t.id.equals(id))).getSingle();

      // "Goblin 1/2/3" tek satirda toplanmali.
      final entries = EncounterTemplateRepository.entriesOf(template);
      expect(entries, hasLength(1));
      expect(entries.single.count, 3);
      expect(entries.single.name, 'Goblin');

      final result = await templates.instantiate(template, combat: combat);
      expect(result.missing, isEmpty);
      expect(await combat.combatants(result.encounterId), hasLength(3));
    });

    test('kutuphanede olmayan canavar bildirilir', () async {
      final combat = CombatRepository(db);
      final templates = EncounterTemplateRepository(db);
      await db
          .into(db.encounterTemplates)
          .insert(
            EncounterTemplatesCompanion.insert(
              id: 't1',
              name: 'Hayalet kadro',
              entriesJson: const Value(
                '[{"key":"yok","name":"Silinmis","count":2}]',
              ),
            ),
          );
      final template = await db.select(db.encounterTemplates).getSingle();

      final result = await templates.instantiate(template, combat: combat);
      expect(result.missing, ['Silinmis']);
      expect(await combat.combatants(result.encounterId), isEmpty);
    });
  });

  group('makrolar', () {
    test('gecersiz ifade kaydedilmez', () async {
      final repo = MacroRepository(db);
      expect(await repo.add(name: 'Bozuk', expression: 'merhaba'), isNull);
      expect(await db.select(db.macros).get(), isEmpty);
    });

    test('gecerli ifade kaydedilir ve atilir', () async {
      final repo = MacroRepository(db);
      await repo.add(name: 'Uzun yay', expression: '1d8+3');
      final macro = await db.select(db.macros).getSingle();

      // Sabit tohum gerekmiyor: test yalnizca ARALIK kontrol ediyor.
      final roll = MacroRepository.roll(macro, DiceRoller());
      expect(roll, isNotNull);
      expect(roll!.label, 'Uzun yay');
      expect(roll.total, inInclusiveRange(4, 11));
    });
  });

  group('bos zaman', () {
    test('tamamlama kazanci keseye yazar', () async {
      await db
          .into(db.characters)
          .insert(
            CharactersCompanion.insert(
              id: 'c1',
              name: 'Mira',
              coinsCp: const Value(100),
            ),
          );
      final repo = DowntimeRepository(db);
      final id = await repo.add(
        title: 'Kilic doverim',
        kind: DowntimeKind.craft,
        characterId: 'c1',
        days: 4,
      );

      await repo.complete(id, outcome: 'Kilic hazir');

      final character = await db.select(db.characters).getSingle();
      // 4 gun x (500 - 250) = 1000 cp kazanc.
      expect(character.coinsCp, 1100);
      final activity = await db.select(db.downtimeActivities).getSingle();
      expect(activity.done, isTrue);
      expect(activity.outcome, 'Kilic hazir');
    });

    test('kese eksiye dusmez', () async {
      await db
          .into(db.characters)
          .insert(
            CharactersCompanion.insert(
              id: 'c1',
              name: 'Mira',
              coinsCp: const Value(50),
            ),
          );
      final repo = DowntimeRepository(db);
      final id = await repo.add(
        title: 'Kutuphane',
        kind: DowntimeKind.research,
        characterId: 'c1',
        days: 10,
      );

      await repo.complete(id);
      expect((await db.select(db.characters).getSingle()).coinsCp, 0);
    });

    test('iki kez tamamlamak parayi iki kez yazmaz', () async {
      await db
          .into(db.characters)
          .insert(
            CharactersCompanion.insert(
              id: 'c1',
              name: 'Mira',
              coinsCp: const Value(0),
            ),
          );
      final repo = DowntimeRepository(db);
      final id = await repo.add(
        title: 'Is',
        kind: DowntimeKind.work,
        characterId: 'c1',
        days: 5,
      );

      await repo.complete(id);
      await repo.complete(id);
      expect((await db.select(db.characters).getSingle()).coinsCp, 500);
    });
  });

  group('geri alma', () {
    test('silinen katilimci aynen geri gelir', () async {
      final repo = CombatRepository(db);
      final encounterId = await repo.createEncounter('Test');
      final monster = await seedMonster();
      await repo.addMonsters(encounterId: encounterId, monster: monster);

      final before = (await repo.combatants(encounterId)).single;
      await repo.applyDamageTyped(before.id, 3);
      final wounded = (await repo.combatants(encounterId)).single;

      await repo.removeCombatant(wounded.id);
      expect(await repo.combatants(encounterId), isEmpty);

      await repo.restoreCombatant(wounded);
      final restored = (await repo.combatants(encounterId)).single;
      expect(restored.id, wounded.id);
      // Can dahil TAM hali geri gelmeli, sifirdan kurulmus bir satir degil.
      expect(restored.hitPointsCurrent, 4);
    });
  });
}
