import 'package:dm_table/data/character_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/import/asset_importer.dart';
import 'package:dm_table/data/shop_repository.dart';
import 'package:dm_table/domain/models/ability.dart';
import 'package:dm_table/domain/rules/character_math.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Envanter: ekleme/staklama, adet, giyme, silme ve satin almada staklama.
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
      classKey: 'srd-2024_rogue',
      abilities: const AbilityScores(),
      savingThrows: const {},
      skills: const {},
      hitDieSides: 8,
      startingGoldGp: 100,
    );
  });

  tearDown(() async => db.close());

  Future<String> itemKey(String name) async => (await (db.select(
    db.items,
  )..where((t) => t.name.equals(name))).getSingle()).key;

  test('aynı eşya tekrar eklenince adet artar, yeni satır açılmaz', () async {
    final dagger = await itemKey('Dagger');
    await repo.addItem(characterId: 'vex', itemKey: dagger);
    await repo.addItem(characterId: 'vex', itemKey: dagger, quantity: 2);

    final items = await repo.items('vex');
    expect(items.length, 1, reason: 'staklanmalı');
    expect(items.single.quantity, 3);
  });

  test('farklı eşyalar ayrı satır', () async {
    await repo.addItem(characterId: 'vex', itemKey: await itemKey('Dagger'));
    await repo.addItem(characterId: 'vex', itemKey: await itemKey('Longsword'));
    expect((await repo.items('vex')).length, 2);
  });

  test('serbest metin eşya ada göre staklanır', () async {
    await repo.addItem(characterId: 'vex', customName: 'Kırık pusula');
    await repo.addItem(characterId: 'vex', customName: 'Kırık pusula');
    final items = await repo.items('vex');
    expect(items.length, 1);
    expect(items.single.quantity, 2);
  });

  test('adet sıfıra inince satır silinir', () async {
    await repo.addItem(characterId: 'vex', customName: 'Meşale', quantity: 2);
    final id = (await repo.items('vex')).single.id;

    await repo.setItemQuantity(id, 1);
    expect((await repo.items('vex')).single.quantity, 1);

    await repo.setItemQuantity(id, 0);
    expect(await repo.items('vex'), isEmpty);
  });

  test('giyme durumu değişir ve AC hesabına girer', () async {
    // Chain mail giyilince AC 16 olmalı (Dex eklenmez).
    await repo.addItem(
      characterId: 'vex',
      itemKey: await itemKey('Chain Mail'),
    );
    final id = (await repo.items('vex')).single.id;

    // Giyilmeden AC = 10 + Dex(0).
    expect((await repo.buildFor('vex')).armorClass, 10);

    await repo.setEquipped(id, true);
    expect((await repo.items('vex')).single.equipped, isTrue);
    expect((await repo.buildFor('vex')).armorClass, 16);

    await repo.setEquipped(id, false);
    expect((await repo.buildFor('vex')).armorClass, 10);
  });

  test('eşya adı kütüphaneden çözülür', () async {
    await repo.addItem(characterId: 'vex', itemKey: await itemKey('Dagger'));
    final item = (await repo.items('vex')).single;
    expect(await repo.itemDisplayName(item), 'Dagger');
  });

  test('satın alınan eşya envanterde staklanır', () async {
    final shops = ShopRepository(db);
    final shopId = await shops.create(name: 'Demirci');
    await shops.addItem(
      shopId: shopId,
      itemKey: await itemKey('Dagger'),
      quantity: 10,
    );
    final stockId = (await shops.entries(shopId)).single.stock.id;

    await shops.purchase(characterId: 'vex', stockId: stockId, quantity: 2);
    await shops.purchase(characterId: 'vex', stockId: stockId);

    // Iki alis tek satirda birikmeli.
    final items = await repo.items('vex');
    final daggers = items.where((i) => i.itemKey != null).toList();
    expect(daggers.length, 1, reason: 'alışlar staklanmalı');
    expect(daggers.single.quantity, 3);
  });

  test('watchItems canlı güncellenir', () async {
    final future = repo.watchItems('vex').firstWhere((rows) => rows.isNotEmpty);
    await repo.addItem(characterId: 'vex', customName: 'İp');
    expect((await future).single.customName, 'İp');
  });
}
