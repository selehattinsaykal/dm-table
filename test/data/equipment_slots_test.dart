import 'package:dm_table/data/character_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/import/asset_importer.dart';
import 'package:dm_table/domain/models/ability.dart';
import 'package:dm_table/domain/rules/equipment_slots.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ekipman yuvalari: hangi esya nereye girer, sinirlar nasil isler ve elle
/// nasil degistirilir.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CharacterRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await AssetImporter(db).importIfNeeded();
    repo = CharacterRepository(db);
    await repo.createLevelOneCharacter(
      id: 'vex',
      name: 'Vex',
      classKey: 'srd-2024_fighter',
      abilities: const AbilityScores(),
      savingThrows: const {},
      skills: const {},
      hitDieSides: 10,
      startingGoldGp: 100,
    );
  });

  tearDown(() async => db.close());

  Future<String> itemKey(String name) async => (await (db.select(
    db.items,
  )..where((t) => t.name.equals(name))).getSingle()).key;

  Future<String> addNamed(String name) async {
    await repo.addItem(characterId: 'vex', customName: name);
    return (await repo.items('vex')).firstWhere((i) => i.customName == name).id;
  }

  Future<String> addFromLibrary(String name) async {
    final key = await itemKey(name);
    await repo.addItem(characterId: 'vex', itemKey: key);
    return (await repo.items('vex')).firstWhere((i) => i.itemKey == key).id;
  }

  group('yuva tahmini', () {
    test('zırh zırh yuvasına, kalkan diğer ele gider', () async {
      final items = await repo.items('vex');
      expect(items, isEmpty);

      final mail = await addFromLibrary('Chain Mail');
      final shield = await addFromLibrary('Shield');

      final rows = await repo.items('vex');
      expect(
        await repo.equipSlotOf(rows.firstWhere((i) => i.id == mail)),
        EquipSlot.armor,
      );
      expect(
        await repo.equipSlotOf(rows.firstWhere((i) => i.id == shield)),
        EquipSlot.offHand,
      );
    });

    test('silah ana ele gider', () async {
      final sword = await addFromLibrary('Longsword');
      final row = (await repo.items('vex')).firstWhere((i) => i.id == sword);
      expect(await repo.equipSlotOf(row), EquipSlot.mainHand);
    });

    test('ad içinde geçen hece yanlış yuvaya atmaz', () async {
      // Duz `contains` "that" icindeki `hat`i kaska, "Horseshoes" icindeki
      // `shoes`u cizmeye ceviriyordu.
      for (final (name, expected) in [
        ('Well-made tapestry that is 10 feet by 10 feet', EquipSlot.other),
        ('Horseshoes of Speed', EquipSlot.other),
        ('Hatchet kutusu', EquipSlot.other),
      ]) {
        expect(inferEquipSlot(name: name), expected, reason: name);
      }
    });

    test('takılabilir büyülü eşyalar doğru yuvaya gider', () async {
      for (final (name, expected) in [
        ('Goggles of Night', EquipSlot.head),
        ('Eyes of the Eagle', EquipSlot.head),
        ('Cap of Water Breathing', EquipSlot.head),
        ('+1 Wraps of Unarmed Power', EquipSlot.gloves),
        ('Cloak of Protection', EquipSlot.cloak),
        ('Belt of Dwarvenkind', EquipSlot.belt),
        ('Winged Boots', EquipSlot.boots),
        ('Amulet of Health', EquipSlot.amulet),
      ]) {
        expect(inferEquipSlot(name: name), expected, reason: name);
      }
    });

    test('elle seçilen tür eklerken kaydedilir', () async {
      await repo.addItem(
        characterId: 'vex',
        customName: 'Gölge Örtüsü',
        slot: EquipSlot.cloak,
      );
      final row = (await repo.items('vex')).single;
      expect(row.slot, 'cloak');
      expect(await repo.equipSlotOf(row), EquipSlot.cloak);
    });

    test('serbest metin eşya adından çözülür (TR ve EN)', () async {
      final helm = await addNamed('Demir miğfer');
      final ring = await addNamed('Ring of Protection');
      final junk = await addNamed('Halat');

      final rows = await repo.items('vex');
      Future<EquipSlot> slotOf(String id) async =>
          repo.equipSlotOf(rows.firstWhere((i) => i.id == id));

      expect(await slotOf(helm), EquipSlot.head);
      expect(await slotOf(ring), EquipSlot.ring);
      expect(await slotOf(junk), EquipSlot.other);
    });
  });

  group('sınırlar', () {
    test('ikinci zırh kuşanılamaz, yuva dolu döner', () async {
      final mail = await addFromLibrary('Chain Mail');
      final leather = await addFromLibrary('Leather Armor');

      expect(await repo.setEquipped(mail, true), EquipOutcome.ok);
      expect(await repo.setEquipped(leather, true), EquipOutcome.slotFull);

      final rows = await repo.items('vex');
      expect(rows.firstWhere((i) => i.id == leather).equipped, isFalse);
    });

    test('zırh çıkarılınca yenisi kuşanılabilir', () async {
      final mail = await addFromLibrary('Chain Mail');
      final leather = await addFromLibrary('Leather Armor');

      await repo.setEquipped(mail, true);
      await repo.setEquipped(mail, false);
      expect(await repo.setEquipped(leather, true), EquipOutcome.ok);
    });

    test('yüzük ve kolyede sınır yok', () async {
      for (var i = 0; i < 5; i++) {
        final id = await addNamed('Yüzük $i');
        expect(await repo.setEquipped(id, true), EquipOutcome.ok);
      }
      final worn = await repo.equippedBySlot('vex');
      expect(worn[EquipSlot.ring]?.length, 5);
    });

    test('sınır artırılınca iki kask birden takılabilir', () async {
      final a = await addNamed('Miğfer A');
      final b = await addNamed('Miğfer B');

      expect(await repo.setEquipped(a, true), EquipOutcome.ok);
      expect(await repo.setEquipped(b, true), EquipOutcome.slotFull);

      await repo.setSlotCapacity('vex', EquipSlot.head, 2);
      expect(await repo.setEquipped(b, true), EquipOutcome.ok);
      expect((await repo.equippedBySlot('vex'))[EquipSlot.head]?.length, 2);
    });

    test('sınır sıfırlanınca varsayilana döner', () async {
      await repo.setSlotCapacity('vex', EquipSlot.head, 3);
      expect((await repo.slotCapacities('vex'))[EquipSlot.head], 3);

      await repo.setSlotCapacity('vex', EquipSlot.head, null);
      expect((await repo.slotCapacities('vex'))[EquipSlot.head], 1);
    });

    test('sınırsıza çekilen yuva dolmaz', () async {
      await repo.setSlotCapacity('vex', EquipSlot.head, unlimitedSlotCapacity);
      for (var i = 0; i < 3; i++) {
        expect(
          await repo.setEquipped(await addNamed('Miğfer $i'), true),
          EquipOutcome.ok,
        );
      }
    });
  });

  group('yuva değiştirme', () {
    test('elle seçilen yuva tahmini ezer ve kalıcıdır', () async {
      final boots = await addNamed('Boots of Speed');
      expect(await repo.setItemSlot(boots, EquipSlot.belt), EquipOutcome.ok);

      final row = (await repo.items('vex')).firstWhere((i) => i.id == boots);
      expect(row.slot, 'belt');
      expect(await repo.equipSlotOf(row), EquipSlot.belt);
    });

    test('dolu yuvaya taşıma reddedilir', () async {
      final mail = await addFromLibrary('Chain Mail');
      final helm = await addNamed('Miğfer');
      await repo.setEquipped(mail, true);
      await repo.setEquipped(helm, true);

      expect(
        await repo.setItemSlot(helm, EquipSlot.armor),
        EquipOutcome.slotFull,
      );
      final row = (await repo.items('vex')).firstWhere((i) => i.id == helm);
      expect(await repo.equipSlotOf(row), EquipSlot.head);
    });

    test('çantadaki eşya dolu yuvaya bile atanabilir', () async {
      final mail = await addFromLibrary('Chain Mail');
      final leather = await addFromLibrary('Leather Armor');
      await repo.setEquipped(mail, true);

      // Kusanili degil: yalnizca "kusaninca nereye gidecegi" isaretleniyor.
      expect(await repo.setItemSlot(leather, EquipSlot.armor), EquipOutcome.ok);
      expect(await repo.setEquipped(leather, true), EquipOutcome.slotFull);
    });
  });

  test('yuva sınırları JSON üzerinden yuvarlanır', () {
    const caps = SlotCapacities.defaults();
    final edited = caps
        .withCapacity(EquipSlot.head, 2)
        .withCapacity(EquipSlot.ring, 4);
    final restored = SlotCapacities.fromJson(edited.toJson());

    expect(restored[EquipSlot.head], 2);
    expect(restored[EquipSlot.ring], 4);
    expect(restored[EquipSlot.armor], 1, reason: 'dokunulmayan varsayılan');
    expect(restored.isUnlimited(EquipSlot.amulet), isTrue);
  });
}
