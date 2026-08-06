import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/loot_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ganimet setleri: olustur, duzenle (para + esyalar), oku, sil.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late LootRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = LootRepository(db);
  });

  tearDown(() => db.close());

  test('set olustur, para+esya kaydet, oku', () async {
    final id = await repo.create('Ejderha hazinesi');
    await repo.update(
      id,
      coinsCp: 1234, // 1 pp 2 gp 3 sp 4 cp
      items: const [
        (name: 'Uzun kılıç', magic: false),
        (name: '+1 Kalkan', magic: true),
      ],
    );

    final set = (await repo.find(id))!;
    expect(set.name, 'Ejderha hazinesi');
    expect(set.coinsCp, 1234);

    final items = LootRepository.itemsOf(set);
    expect(items.length, 2);
    expect(items.first.name, 'Uzun kılıç');
    expect(items.last.magic, isTrue);
  });

  test('set silinir', () async {
    final id = await repo.create('Geçici');
    await repo.delete(id);
    expect(await repo.find(id), isNull);
  });

  test('watchAll setleri yayinlar', () async {
    await repo.create('A');
    await repo.create('B');
    final rows = await repo.watchAll().first;
    expect(rows.length, 2);
  });

  test('initialPinLoot her esyaya kalici id atar ve parayi kopyalar', () async {
    final id = await repo.create('Hazine seti');
    await repo.update(
      id,
      coinsCp: 250,
      items: const [
        (name: 'Kılıç', magic: false),
        (name: '+1 Yüzük', magic: true),
      ],
    );
    final set = (await repo.find(id))!;

    final json = LootRepository.initialPinLoot(set);
    final loot = LootRepository.pinLootOf(json)!;
    expect(loot.coinsCp, 250);
    expect(loot.items.length, 2);
    // Her esyanin kendine oz id'si var (oyuncular bununla alir).
    expect(loot.items.first.id, isNotEmpty);
    expect(loot.items.first.id, isNot(loot.items.last.id));
    expect(loot.items.first.name, 'Kılıç');
    expect(loot.items.last.magic, isTrue);
  });

  test('pinLootOf bos/null veride null doner', () {
    expect(LootRepository.pinLootOf(null), isNull);
    expect(LootRepository.pinLootOf(''), isNull);
    expect(LootRepository.pinLootOf('bozuk json'), isNull);
  });

  test('pinLootOf kismen alinmis hazineyi cozer', () {
    final loot = LootRepository.pinLootOf(
      '{"coinsCp": 40, "items": [{"id":"a","name":"Elmas","magic":false}]}',
    )!;
    expect(loot.coinsCp, 40);
    expect(loot.items.single.id, 'a');
    expect(loot.items.single.name, 'Elmas');
  });
}
