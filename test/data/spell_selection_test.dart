import 'package:dm_table/data/character_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/import/asset_importer.dart';
import 'package:dm_table/domain/models/ability.dart';
import 'package:dm_table/domain/rules/spell_preparation.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Oyuncunun kendi buyulerini secmesi.
///
/// Sinirlar sinif tablosundan (Cantrips / Prepared Spells) geliyor, degistirme
/// hakki ise sinifin kuralindan: Wizard uzun dinlenmede, Sorcerer seviye
/// basina. Dogrulama sunucu tarafinda -- oyuncu paneli yalnizca ekrani ciziyor.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CharacterRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await AssetImporter(db).importIfNeeded();
    repo = CharacterRepository(db);
  });

  tearDown(() async => db.close());

  Future<String> makeCaster(String classKey, {int level = 3}) async {
    final id = 'c-${classKey.split('_').last}';
    await repo.createLevelOneCharacter(
      id: id,
      name: id,
      classKey: classKey,
      abilities: const AbilityScores(intelligence: 16, charisma: 16),
      savingThrows: const {},
      skills: const {},
      hitDieSides: 6,
    );
    if (level > 1) {
      await repo.setClassLevel(
        characterId: id,
        classKey: classKey,
        level: level,
      );
    }
    return id;
  }

  Future<SpellPreparation> prep(String id, String classKey) async =>
      (await repo.spellPreparations(
        id,
      )).firstWhere((p) => p.classKey == classKey);

  group('kurallar', () {
    test('sinif degistirme hakkini dogru siniflandirir', () {
      expect(
        SpellChangePolicy.forClass('srd-2024_wizard'),
        SpellChangePolicy.longRest,
      );
      expect(
        SpellChangePolicy.forClass('eberron-forge_artificer'),
        SpellChangePolicy.longRest,
      );
      expect(
        SpellChangePolicy.forClass('srd-2024_sorcerer'),
        SpellChangePolicy.levelUp,
      );
      // Boyle bir hakki olmayan sinifta secim ekrani hic acilmaz.
      expect(
        SpellChangePolicy.forClass('srd-2024_fighter'),
        SpellChangePolicy.none,
      );
    });
  });

  group('sinirlar', () {
    test('sinif tablosundan okunur', () async {
      final id = await makeCaster('srd-2024_wizard');
      final p = await prep(id, 'srd-2024_wizard');

      // 3. seviye Wizard: 3 cantrip, 6 hazir buyu, 2. seviye yuvalar.
      expect(p.cantripLimit, 3);
      expect(p.preparedLimit, 6);
      expect(p.maxSpellLevel, 2);
      expect(p.canChoose, isTrue);
    });

    test('buyu yapmayan sinif secim yapmaz', () async {
      final id = await makeCaster('srd-2024_fighter');
      expect((await prep(id, 'srd-2024_fighter')).canChoose, isFalse);
    });

    test(
      'secilebilir buyuler sinif listesi ve yuva seviyesiyle sinirli',
      () async {
        final allowed = await repo.selectableSpells(
          'srd-2024_wizard',
          maxSpellLevel: 2,
        );
        expect(allowed.values.every((level) => level <= 2), isTrue);
        expect(allowed.keys, contains('phb-2024_magic-missile'));
        // 3. seviye buyu bu asamada listede olmamali.
        expect(allowed.keys, isNot(contains('phb-2024_fireball')));
      },
    );
  });

  group('secim', () {
    // Defter tutmayan bir hazirlayici sinif (Cleric) uzerinden: hak sayaci
    // defterden bagimsiz calismali.
    test('bos yeri doldurmak hak harcamaz', () async {
      final id = await makeCaster('srd-2024_cleric');
      final before = await prep(id, 'srd-2024_cleric');
      expect(before.changesAvailable, 0);

      final result = await repo.applySpellSelection(
        characterId: id,
        classKey: 'srd-2024_cleric',
        cantrips: {'phb-2024_guidance', 'phb-2024_sacred-flame'},
        prepared: {'phb-2024_bless', 'phb-2024_cure-wounds'},
      );

      expect(result, isA<SpellSelectionAccepted>());
      expect((result as SpellSelectionAccepted).changesSpent, 0);
      final after = await prep(id, 'srd-2024_cleric');
      expect(after.cantrips, hasLength(2));
      expect(after.prepared, hasLength(2));
      expect(after.changesAvailable, 0, reason: 'ekleme hak harcamaz');
    });

    test('hak yokken buyu degistirilemez', () async {
      final id = await makeCaster('srd-2024_cleric');
      await repo.applySpellSelection(
        characterId: id,
        classKey: 'srd-2024_cleric',
        cantrips: const {},
        prepared: {'phb-2024_bless'},
      );

      final result = await repo.applySpellSelection(
        characterId: id,
        classKey: 'srd-2024_cleric',
        cantrips: const {},
        prepared: {'phb-2024_cure-wounds'},
      );

      expect(
        result,
        isA<SpellSelectionRejected>().having(
          (r) => r.reason,
          'reason',
          SpellSelectionError.noChangesLeft,
        ),
      );
      // Reddedilen istek listeyi bozmamali.
      expect((await prep(id, 'srd-2024_cleric')).prepared, {'phb-2024_bless'});
    });

    test('uzun dinlenme listeyi bastan kurma hakki verir', () async {
      final id = await makeCaster('srd-2024_cleric');
      await repo.applySpellSelection(
        characterId: id,
        classKey: 'srd-2024_cleric',
        cantrips: const {},
        prepared: {'phb-2024_bless'},
      );

      final limit = (await prep(id, 'srd-2024_cleric')).preparedLimit;
      await repo.longRest(id);
      expect((await prep(id, 'srd-2024_cleric')).changesAvailable, limit);

      final result = await repo.applySpellSelection(
        characterId: id,
        classKey: 'srd-2024_cleric',
        cantrips: const {},
        prepared: {'phb-2024_cure-wounds'},
      );

      expect((result as SpellSelectionAccepted).changesSpent, 1);
      final after = await prep(id, 'srd-2024_cleric');
      expect(after.prepared, {'phb-2024_cure-wounds'});
      expect(after.changesAvailable, limit - 1);
    });

    test('seviye atlayan Sorcerer bir buyu degistirebilir', () async {
      final id = await makeCaster('srd-2024_sorcerer', level: 1);
      await repo.applySpellSelection(
        characterId: id,
        classKey: 'srd-2024_sorcerer',
        cantrips: const {},
        prepared: {'phb-2024_burning-hands'},
      );
      expect((await prep(id, 'srd-2024_sorcerer')).changesAvailable, 0);

      await repo.levelUp(characterId: id, classKey: 'srd-2024_sorcerer');
      expect((await prep(id, 'srd-2024_sorcerer')).changesAvailable, 1);

      final swap = await repo.applySpellSelection(
        characterId: id,
        classKey: 'srd-2024_sorcerer',
        cantrips: const {},
        prepared: {'phb-2024_magic-missile'},
      );
      expect(swap, isA<SpellSelectionAccepted>());
      expect((await prep(id, 'srd-2024_sorcerer')).changesAvailable, 0);
    });

    test('sinirin ustunde secim reddedilir', () async {
      final id = await makeCaster('srd-2024_wizard');
      final result = await repo.applySpellSelection(
        characterId: id,
        classKey: 'srd-2024_wizard',
        cantrips: {
          'phb-2024_fire-bolt',
          'phb-2024_light',
          'phb-2024_mage-hand',
          'phb-2024_prestidigitation',
        },
        prepared: const {},
      );
      expect(
        result,
        isA<SpellSelectionRejected>().having(
          (r) => r.reason,
          'reason',
          SpellSelectionError.overLimit,
        ),
      );
    });

    test('acik yuvadan yuksek seviyeli buyu reddedilir', () async {
      final id = await makeCaster('srd-2024_wizard');
      final result = await repo.applySpellSelection(
        characterId: id,
        classKey: 'srd-2024_wizard',
        cantrips: const {},
        prepared: {'phb-2024_fireball'},
      );
      expect(result, isA<SpellSelectionRejected>());
    });

    test('sinif listesinde olmayan buyu reddedilir', () async {
      final id = await makeCaster('srd-2024_wizard');
      final result = await repo.applySpellSelection(
        characterId: id,
        classKey: 'srd-2024_wizard',
        cantrips: const {},
        prepared: {'phb-2024_cure-wounds'},
      );
      expect(
        result,
        isA<SpellSelectionRejected>().having(
          (r) => r.reason,
          'reason',
          SpellSelectionError.unknownSpell,
        ),
      );
    });

    test('alt sinifin verdigi daima hazir buyulere dokunulmaz', () async {
      final id = await makeCaster('srd-2024_wizard');
      await repo.setSubclass(
        characterId: id,
        classKey: 'srd-2024_wizard',
        subclassKey: 'phb-2024_abjurer',
      );
      final granted = {
        for (final s in await repo.knownSpells(id))
          if (s.alwaysPrepared) s.spellKey,
      };

      await repo.applySpellSelection(
        characterId: id,
        classKey: 'srd-2024_wizard',
        cantrips: const {},
        prepared: {'phb-2024_magic-missile'},
      );

      final after = {
        for (final s in await repo.knownSpells(id))
          if (s.alwaysPrepared) s.spellKey,
      };
      expect(after, granted);
    });
  });

  group('buyu defteri', () {
    test('Wizard defter tutar, sinirini seviyeden alir', () async {
      final id = await makeCaster('srd-2024_wizard');
      final p = await prep(id, 'srd-2024_wizard');
      // 1. seviyede alti, her seviyede iki tane daha: 3. seviyede 10.
      expect(p.usesSpellbook, isTrue);
      expect(p.spellbookLimit, 10);
      expect(p.spellbook, isEmpty);
    });

    test('Sorcerer defter tutmaz', () async {
      final id = await makeCaster('srd-2024_sorcerer');
      expect((await prep(id, 'srd-2024_sorcerer')).usesSpellbook, isFalse);
    });

    test('deftere yazilan buyuler hazir sayilmaz', () async {
      final id = await makeCaster('srd-2024_wizard');
      final result = await repo.applySpellbook(
        characterId: id,
        classKey: 'srd-2024_wizard',
        spellKeys: {'phb-2024_magic-missile', 'phb-2024_shield'},
      );

      expect(result, isA<SpellSelectionAccepted>());
      final p = await prep(id, 'srd-2024_wizard');
      expect(p.spellbook, {'phb-2024_magic-missile', 'phb-2024_shield'});
      expect(p.prepared, isEmpty, reason: 'deftere girmek hazirlamak degil');
    });

    test('hazir buyu yalnizca defterden secilebilir', () async {
      final id = await makeCaster('srd-2024_wizard');
      await repo.applySpellbook(
        characterId: id,
        classKey: 'srd-2024_wizard',
        spellKeys: {'phb-2024_magic-missile'},
      );

      final rejected = await repo.applySpellSelection(
        characterId: id,
        classKey: 'srd-2024_wizard',
        cantrips: const {},
        prepared: {'phb-2024_shield'},
      );
      expect(
        rejected,
        isA<SpellSelectionRejected>().having(
          (r) => r.reason,
          'reason',
          SpellSelectionError.unknownSpell,
        ),
      );

      final ok = await repo.applySpellSelection(
        characterId: id,
        classKey: 'srd-2024_wizard',
        cantrips: {'phb-2024_fire-bolt'},
        prepared: {'phb-2024_magic-missile'},
      );
      expect(ok, isA<SpellSelectionAccepted>());
      final p = await prep(id, 'srd-2024_wizard');
      expect(p.prepared, {'phb-2024_magic-missile'});
      // Hazirlamak defteri bozmaz.
      expect(p.spellbook, {'phb-2024_magic-missile'});
      expect(p.cantrips, {'phb-2024_fire-bolt'});
    });

    test('hazir listesi degisince defterdeki buyu defterde kalir', () async {
      final id = await makeCaster('srd-2024_wizard');
      await repo.applySpellbook(
        characterId: id,
        classKey: 'srd-2024_wizard',
        spellKeys: {'phb-2024_magic-missile', 'phb-2024_shield'},
      );
      await repo.applySpellSelection(
        characterId: id,
        classKey: 'srd-2024_wizard',
        cantrips: const {},
        prepared: {'phb-2024_magic-missile'},
      );
      await repo.longRest(id);

      await repo.applySpellSelection(
        characterId: id,
        classKey: 'srd-2024_wizard',
        cantrips: const {},
        prepared: {'phb-2024_shield'},
      );

      final p = await prep(id, 'srd-2024_wizard');
      expect(p.prepared, {'phb-2024_shield'});
      expect(p.spellbook, {'phb-2024_magic-missile', 'phb-2024_shield'});
    });

    test('defter sinirini asan liste reddedilir', () async {
      final id = await makeCaster('srd-2024_wizard', level: 1);
      // 1. seviye defteri alti buyu alir.
      final result = await repo.applySpellbook(
        characterId: id,
        classKey: 'srd-2024_wizard',
        spellKeys: {
          'phb-2024_magic-missile',
          'phb-2024_shield',
          'phb-2024_sleep',
          'phb-2024_thunderwave',
          'phb-2024_detect-magic',
          'phb-2024_mage-armor',
          'phb-2024_burning-hands',
        },
      );
      expect(
        result,
        isA<SpellSelectionRejected>().having(
          (r) => r.reason,
          'reason',
          SpellSelectionError.overLimit,
        ),
      );
    });

    test('deftere cantrip yazilamaz', () async {
      final id = await makeCaster('srd-2024_wizard');
      final result = await repo.applySpellbook(
        characterId: id,
        classKey: 'srd-2024_wizard',
        spellKeys: {'phb-2024_fire-bolt'},
      );
      expect(result, isA<SpellSelectionRejected>());
    });

    test('defterden cikan buyu hazir listesinden de duser', () async {
      final id = await makeCaster('srd-2024_wizard');
      await repo.applySpellbook(
        characterId: id,
        classKey: 'srd-2024_wizard',
        spellKeys: {'phb-2024_magic-missile', 'phb-2024_shield'},
      );
      await repo.applySpellSelection(
        characterId: id,
        classKey: 'srd-2024_wizard',
        cantrips: const {},
        prepared: {'phb-2024_magic-missile', 'phb-2024_shield'},
      );

      await repo.applySpellbook(
        characterId: id,
        classKey: 'srd-2024_wizard',
        spellKeys: {'phb-2024_magic-missile'},
      );

      final p = await prep(id, 'srd-2024_wizard');
      expect(p.spellbook, {'phb-2024_magic-missile'});
      expect(p.prepared, {'phb-2024_magic-missile'});
    });
  });
}
