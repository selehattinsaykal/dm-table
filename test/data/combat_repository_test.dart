import 'package:dm_table/data/character_repository.dart';
import 'package:dm_table/data/combat_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/import/asset_importer.dart';
import 'package:dm_table/domain/models/ability.dart';
import 'package:dm_table/domain/rules/combat_conditions.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Savas takipcisi: initiative sirasi, tur dongusu, hasar kurallari ve
/// oyuncu cani ile karakter kagidinin senkronu.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CombatRepository combat;
  late CharacterRepository characters;
  late String encounterId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await AssetImporter(db).importIfNeeded();
    combat = CombatRepository(db);
    characters = CharacterRepository(db);
    encounterId = await combat.createEncounter('Test');
  });

  tearDown(() async => db.close());

  Future<Monster> monster(String name) async =>
      (db.select(db.monsters)..where((t) => t.name.equals(name))).getSingle();

  test('canavar adet ile eklenir ve numaralanir', () async {
    await combat.addMonsters(
      encounterId: encounterId,
      monster: await monster('Goblin Warrior'),
      count: 3,
    );

    final rows = await combat.combatants(encounterId);
    expect(rows.length, 3);
    expect(
      rows.map((r) => r.name),
      containsAll(['Goblin Warrior 1', 'Goblin Warrior 2', 'Goblin Warrior 3']),
    );
    // Kutuphaneden AC ve HP tasinmali.
    expect(rows.first.armorClass, isNotNull);
    expect(rows.first.hitPointsMax, greaterThan(0));
  });

  test('tek canavarda numara eklenmez', () async {
    await combat.addMonsters(
      encounterId: encounterId,
      monster: await monster('Goblin Warrior'),
    );
    expect(
      (await combat.combatants(encounterId)).single.name,
      'Goblin Warrior',
    );
  });

  test(
    'HP zar atilinca ortalamadan farkli olabilir ama 1 altina inmez',
    () async {
      final goblin = await monster('Goblin Warrior');
      for (var i = 0; i < 10; i++) {
        await combat.addMonsters(
          encounterId: encounterId,
          monster: goblin,
          rollHitPoints: true,
        );
      }
      final rows = await combat.combatants(encounterId);
      expect(rows.every((r) => r.hitPointsMax >= 1), isTrue);
    },
  );

  test('liste initiative’e gore azalan siralanir', () async {
    await combat.addAdhoc(encounterId: encounterId, name: 'A', initiative: 5);
    await combat.addAdhoc(encounterId: encounterId, name: 'B', initiative: 20);
    await combat.addAdhoc(encounterId: encounterId, name: 'C', initiative: 12);

    final rows = await combat.combatants(encounterId);
    expect(rows.map((r) => r.name), ['B', 'C', 'A']);
  });

  group('tur dongusu', () {
    setUp(() async {
      for (final (name, init) in [('A', 20), ('B', 15), ('C', 10)]) {
        await combat.addAdhoc(
          encounterId: encounterId,
          name: name,
          initiative: init,
          hitPoints: 10,
        );
      }
      await combat.start(encounterId);
    });

    Future<Encounter> current() => (db.select(
      db.encounters,
    )..where((t) => t.id.equals(encounterId))).getSingle();

    test('baslayinca 1. turda ve ilk sirada', () async {
      final e = await current();
      expect(e.started, isTrue);
      expect(e.round, 1);
      expect(e.activeIndex, 0);
    });

    test('sira ilerler, basa donunce tur artar', () async {
      await combat.advanceTurn(encounterId);
      expect((await current()).activeIndex, 1);

      await combat.advanceTurn(encounterId);
      expect((await current()).activeIndex, 2);

      await combat.advanceTurn(encounterId);
      final e = await current();
      expect(e.activeIndex, 0);
      expect(e.round, 2, reason: 'liste basa donunce tur artmali');
    });

    test('yenilmis katilimcilar atlanir', () async {
      final rows = await combat.combatants(encounterId);
      await combat.setDefeated(rows[1].id, true); // B

      await combat.advanceTurn(encounterId);
      // B atlanip C'ye gecmeli.
      expect((await current()).activeIndex, 2);
    });
  });

  group('hasar', () {
    test('gecici cani once tuketir', () async {
      await combat.addAdhoc(encounterId: encounterId, name: 'A', hitPoints: 20);
      final id = (await combat.combatants(encounterId)).single.id;

      await (db.update(db.combatants)..where((t) => t.id.equals(id))).write(
        const CombatantsCompanion(temporaryHitPoints: Value(5)),
      );

      await combat.applyDamage(id, 8);
      final row = (await combat.combatants(encounterId)).single;
      expect(row.temporaryHitPoints, 0);
      expect(row.hitPointsCurrent, 17);
    });

    test(
      'can sifirlaninca yenildi isaretlenir ve konsantrasyon kirilir',
      () async {
        await combat.addAdhoc(
          encounterId: encounterId,
          name: 'A',
          hitPoints: 10,
        );
        final id = (await combat.combatants(encounterId)).single.id;
        await combat.setConcentration(id, value: true, note: 'Bless');

        await combat.applyDamage(id, 10);
        final row = (await combat.combatants(encounterId)).single;
        expect(row.hitPointsCurrent, 0);
        expect(row.defeated, isTrue);
        expect(row.concentrating, isFalse);
      },
    );

    test('iyilesme azami cani asmaz', () async {
      await combat.addAdhoc(encounterId: encounterId, name: 'A', hitPoints: 10);
      final id = (await combat.combatants(encounterId)).single.id;
      await combat.applyDamage(id, 6);
      await combat.applyHealing(id, 100);
      expect(
        (await combat.combatants(encounterId)).single.hitPointsCurrent,
        10,
      );
    });
  });

  test('oyuncu hasari karakter kagidina da yansir', () async {
    await characters.createLevelOneCharacter(
      id: 'pc1',
      name: 'Vex',
      classKey: 'srd-2024_wizard',
      abilities: const AbilityScores(constitution: 14),
      savingThrows: const {},
      skills: const {},
      hitDieSides: 6,
    );
    final character = (await characters.find('pc1'))!;
    expect(character.hitPointsMax, 8);

    await combat.addCharacters(
      encounterId: encounterId,
      characters: [character],
    );
    final combatantId = (await combat.combatants(encounterId)).single.id;

    await combat.applyDamage(combatantId, 3);

    // Savas listesi ve karakter kagidi ayni cani gostermeli.
    expect((await combat.combatants(encounterId)).single.hitPointsCurrent, 5);
    expect((await characters.find('pc1'))!.hitPointsCurrent, 5);
  });

  test('ayni karakter iki kez eklenmez', () async {
    await characters.createLevelOneCharacter(
      id: 'pc1',
      name: 'Vex',
      classKey: 'srd-2024_wizard',
      abilities: const AbilityScores(),
      savingThrows: const {},
      skills: const {},
      hitDieSides: 6,
    );
    final character = (await characters.find('pc1'))!;

    await combat.addCharacters(
      encounterId: encounterId,
      characters: [character],
    );
    await combat.addCharacters(
      encounterId: encounterId,
      characters: [character],
    );

    expect((await combat.combatants(encounterId)).length, 1);
  });

  test('durum efektleri saklanir', () async {
    await combat.addAdhoc(encounterId: encounterId, name: 'A');
    final id = (await combat.combatants(encounterId)).single.id;

    await combat.setConditions(id, ['Prone', 'Poisoned']);
    final row = (await combat.combatants(encounterId)).single;
    expect(parseConditions(row.conditionsJson), [
      const CombatCondition('Prone'),
      const CombatCondition('Poisoned'),
    ]);
  });

  group('oyuncu inisiyatifi', () {
    Future<Character> makeCharacter(String id) async {
      await characters.createLevelOneCharacter(
        id: id,
        name: 'PC-$id',
        classKey: 'srd-2024_fighter',
        abilities: const AbilityScores(),
        savingThrows: const {},
        skills: const {},
        hitDieSides: 10,
      );
      return (await characters.find(id))!;
    }

    test('oyuncu katilimci initiative 0 ile girer', () async {
      await combat.addCharacters(
        encounterId: encounterId,
        characters: [await makeCharacter('pc1')],
      );
      final row = (await combat.combatants(encounterId)).single;
      expect(row.initiative, 0);
    });

    test('start() oyuncuyu ROLL etmez ama 0 canavari roll eder', () async {
      await combat.addCharacters(
        encounterId: encounterId,
        characters: [await makeCharacter('pc1')],
      );
      await combat.addAdhoc(encounterId: encounterId, name: 'Goblin');

      await combat.start(encounterId);

      final rows = await combat.combatants(encounterId);
      final pc = rows.firstWhere((r) => r.characterId == 'pc1');
      final goblin = rows.firstWhere((r) => r.name == 'Goblin');
      expect(pc.initiative, 0, reason: 'zari masadaki oyuncu atar');
      expect(goblin.initiative, greaterThan(0));
    });

    test('setInitiative degeri yazar', () async {
      await combat.addCharacters(
        encounterId: encounterId,
        characters: [await makeCharacter('pc1')],
      );
      final id = (await combat.combatants(encounterId)).single.id;

      await combat.setInitiative(id, 17);

      final row = (await combat.combatants(encounterId)).single;
      expect(row.initiative, 17);
    });
  });

  test(
    'advanceTurn sirasi gelenin durum suresini azaltir, biteni bildirir',
    () async {
      await combat.addAdhoc(
        encounterId: encounterId,
        name: 'A',
        initiative: 20,
      );
      await combat.addAdhoc(
        encounterId: encounterId,
        name: 'B',
        initiative: 10,
      );
      await combat.start(encounterId); // aktif = A (index 0)

      final bId = (await combat.combatants(
        encounterId,
      )).firstWhere((r) => r.name == 'B').id;
      await combat.setConditionsTyped(bId, [
        const CombatCondition('Stunned', rounds: 1),
        const CombatCondition('Prone'), // suresiz
      ]);

      // A'dan B'ye gec: B'nin sirasi basladiginda Stunned biter.
      final result = await combat.advanceTurn(encounterId);
      expect(result.combatantName, 'B');
      expect(result.expired, ['Stunned']);

      final b = (await combat.combatants(
        encounterId,
      )).firstWhere((r) => r.name == 'B');
      expect(parseConditions(b.conditionsJson), [
        const CombatCondition('Prone'),
      ]);
    },
  );

  test('karsilasma silinince katilimcilari da silinir', () async {
    await combat.addAdhoc(encounterId: encounterId, name: 'A');
    await combat.deleteEncounter(encounterId);

    expect(await combat.combatants(encounterId), isEmpty);
    final encounters = await db.select(db.encounters).get();
    expect(encounters, isEmpty);
  });

  group('efsanevi eylemler', () {
    test('efsanevi eylemi OLAN canavara sayac kendiliginden gelir', () async {
      // Aboleth: srd-2024, actions[] icinde LEGENDARY_ACTION (sekil A) +
      // "Legendary Resistance (3/Day, or 4/Day in Lair)" trait'i.
      await combat.addMonsters(
        encounterId: encounterId,
        monster: await monster('Aboleth'),
      );
      final row = (await combat.combatants(encounterId)).single;
      expect(row.legendaryMax, 3, reason: 'SRD varsayılanı');
      expect(row.legendarySpent, 0);
      expect(row.legendaryResistMax, 3, reason: 'trait adından çıkarılmalı');
    });

    test(
      'UST DUZEY legendary_actions[] tasiyan canavar da sayac alir',
      () async {
        // Animal Lord: mm-2024, ust duzey dizi (sekil B). Bu sekil uzun sure
        // hic okunmuyordu.
        await combat.addMonsters(
          encounterId: encounterId,
          monster: await monster('Animal Lord'),
        );
        expect((await combat.combatants(encounterId)).single.legendaryMax, 3);
      },
    );

    test('efsanevi eylemi OLMAYAN canavarda sayac yok', () async {
      await combat.addMonsters(
        encounterId: encounterId,
        monster: await monster('Goblin Warrior'),
      );
      final row = (await combat.combatants(encounterId)).single;
      expect(row.legendaryMax, isNull);
      expect(row.legendaryResistMax, isNull);
    });

    test('setLegendarySpent 0..max araligina kirpar', () async {
      await combat.addMonsters(
        encounterId: encounterId,
        monster: await monster('Aboleth'),
      );
      final id = (await combat.combatants(encounterId)).single.id;

      await combat.setLegendarySpent(id, 99);
      expect((await combat.combatants(encounterId)).single.legendarySpent, 3);

      await combat.setLegendarySpent(id, -5);
      expect((await combat.combatants(encounterId)).single.legendarySpent, 0);
    });

    test('sirasi gelenin harcanani sifirlanir, DIGERLERI dokunulmaz', () async {
      await combat.addMonsters(
        encounterId: encounterId,
        monster: await monster('Aboleth'),
        count: 2,
      );
      final rows = await combat.combatants(encounterId);
      // Initiative'i sabitle: sira deterministik olsun.
      await combat.setInitiative(rows[0].id, 20);
      await combat.setInitiative(rows[1].id, 10);
      await combat.start(encounterId);

      final ordered = await combat.combatants(encounterId);
      final first = ordered[0];
      final second = ordered[1];
      await combat.setLegendarySpent(first.id, 3);
      await combat.setLegendarySpent(second.id, 2);

      // Sira ikinciye gecer: YALNIZ onunki tazelenir.
      await combat.advanceTurn(encounterId);

      final after = await combat.combatants(encounterId);
      expect(
        after.firstWhere((r) => r.id == second.id).legendarySpent,
        0,
        reason: 'sırası gelenin hakkı tazelenmeli',
      );
      expect(
        after.firstWhere((r) => r.id == first.id).legendarySpent,
        3,
        reason: 'diğerinin sayacına dokunulmamalı',
      );
    });

    test('efsanevi DIRENC tur basinda sifirlanmaz (gunluk kaynak)', () async {
      await combat.addMonsters(
        encounterId: encounterId,
        monster: await monster('Aboleth'),
      );
      await combat.addAdhoc(encounterId: encounterId, name: 'B');
      final aboleth = (await combat.combatants(
        encounterId,
      )).firstWhere((r) => r.monsterKey != null);
      await combat.setLegendaryResistSpent(aboleth.id, 2);
      await combat.start(encounterId);

      // Tam tur don.
      await combat.advanceTurn(encounterId);
      await combat.advanceTurn(encounterId);

      final after = (await combat.combatants(
        encounterId,
      )).firstWhere((r) => r.id == aboleth.id);
      expect(after.legendaryResistSpent, 2);
    });

    test('setLegendaryMax null sayaci kaldirir', () async {
      await combat.addMonsters(
        encounterId: encounterId,
        monster: await monster('Aboleth'),
      );
      final id = (await combat.combatants(encounterId)).single.id;

      await combat.setLegendaryMax(id, null);
      final row = (await combat.combatants(encounterId)).single;
      expect(row.legendaryMax, isNull);
      expect(row.legendarySpent, 0);
    });

    test('hak azalinca harcanan sifirlanir (uzerinde kalmaz)', () async {
      await combat.addMonsters(
        encounterId: encounterId,
        monster: await monster('Aboleth'),
      );
      final id = (await combat.combatants(encounterId)).single.id;
      await combat.setLegendarySpent(id, 3);

      await combat.setLegendaryMax(id, 1);
      final row = (await combat.combatants(encounterId)).single;
      expect(row.legendaryMax, 1);
      expect(row.legendarySpent, 0);
    });
  });

  group('elle sıralama', () {
    test('sürüklenen satır yeni yerine oturur ve sıra bozulmaz', () async {
      for (final (name, init) in [('A', 20), ('B', 15), ('C', 10)]) {
        await combat.addAdhoc(
          encounterId: encounterId,
          name: name,
          initiative: init,
        );
      }
      expect((await combat.combatants(encounterId)).map((c) => c.name), [
        'A',
        'B',
        'C',
      ]);

      // C'yi en uste tasi.
      await combat.reorderCombatants(encounterId, 2, 0);
      final rows = await combat.combatants(encounterId);
      expect(rows.map((c) => c.name), ['C', 'A', 'B']);
      // Liste azalan initiative kuralini bozmamali.
      for (var i = 1; i < rows.length; i++) {
        expect(
          rows[i].initiative,
          lessThanOrEqualTo(rows[i - 1].initiative),
          reason: 'sıra azalan initiative ile tutarlı kalmalı',
        );
      }
    });

    test('aynı yere bırakmak hiçbir şey değiştirmez', () async {
      await combat.addAdhoc(encounterId: encounterId, name: 'A', initiative: 5);
      await combat.addAdhoc(encounterId: encounterId, name: 'B', initiative: 3);
      await combat.reorderCombatants(encounterId, 1, 1);
      expect((await combat.combatants(encounterId)).map((c) => c.name), [
        'A',
        'B',
      ]);
    });
  });
}
