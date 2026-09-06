import 'package:dm_table/data/character_repository.dart';
import 'package:dm_table/data/custom_content_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/import/asset_importer.dart';
import 'package:dm_table/data/shop_repository.dart';
import 'package:dm_table/domain/models/ability.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Magaza sistemi: fiyat cozumlemesi, stok ve satin almanin butunlugu.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ShopRepository shops;
  late CharacterRepository characters;
  late CustomContentRepository custom;
  late String shopId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await AssetImporter(db).importIfNeeded();
    shops = ShopRepository(db);
    characters = CharacterRepository(db);
    custom = CustomContentRepository(db);

    shopId = await shops.create(name: 'Demirci', ownerName: 'Gundren');
    await characters.createLevelOneCharacter(
      id: 'vex',
      name: 'Vex',
      classKey: 'srd-2024_wizard',
      abilities: const AbilityScores(),
      savingThrows: const {},
      skills: const {},
      hitDieSides: 6,
      startingGoldGp: 100,
    );
  });

  tearDown(() async => db.close());

  Future<String> itemKeyNamed(String name) async => (await (db.select(
    db.items,
  )..where((t) => t.name.equals(name))).getSingle()).key;

  test('kutuphane fiyati stoktan cozulur', () async {
    await shops.addItem(
      shopId: shopId,
      itemKey: await itemKeyNamed('Longsword'),
    );

    final entry = (await shops.entries(shopId)).single;
    expect(entry.name, 'Longsword');
    // SRD: Longsword 15 gp
    expect(entry.priceCp, 1500);
    expect(entry.unlimited, isTrue);
  });

  test('fiyat carpani uygulanir', () async {
    await shops.addItem(
      shopId: shopId,
      itemKey: await itemKeyNamed('Longsword'),
    );
    await shops.update(shopId, priceMultiplier: 1.5);

    expect((await shops.entries(shopId)).single.priceCp, 2250);
  });

  test('ozel fiyat carpandan etkilenmez', () async {
    await shops.addItem(
      shopId: shopId,
      itemKey: await itemKeyNamed('Longsword'),
      priceCpOverride: 900,
    );
    await shops.update(shopId, priceMultiplier: 3);

    // DM kesin rakami yazmissa carpan ona dokunmamali.
    expect((await shops.entries(shopId)).single.priceCp, 900);
  });

  test('serbest metin esya eklenebilir', () async {
    await shops.addItem(
      shopId: shopId,
      customName: 'Kırık pusula',
      customDesc: 'Kuzeyi değil, en yakın tavernayı gösterir.',
      priceCpOverride: 500,
      quantity: 1,
    );

    final entry = (await shops.entries(shopId)).single;
    expect(entry.name, 'Kırık pusula');
    expect(entry.priceCp, 500);
    expect(entry.unlimited, isFalse);
  });

  test('buyulu esyanin onerilen fiyati isaretlenir', () async {
    final key = (await (db.select(db.magicItems)..limit(1)).getSingle()).key;
    await shops.addItem(shopId: shopId, magicItemKey: key);

    final entry = (await shops.entries(shopId)).single;
    expect(entry.priceIsSuggested, isTrue);
    expect(entry.priceCp, greaterThan(0));
  });

  group('satin alma', () {
    setUp(() async {
      await shops.addItem(
        shopId: shopId,
        itemKey: await itemKeyNamed('Longsword'),
        quantity: 2,
      );
    });

    Future<String> stockId() async =>
        (await shops.entries(shopId)).single.stock.id;

    test('altin duser, esya envantere girer, stok azalir', () async {
      final result = await shops.purchase(
        characterId: 'vex',
        stockId: await stockId(),
      );

      expect(result, isA<PurchaseOk>());
      expect((result as PurchaseOk).totalCp, 1500);

      // 100 gp = 10.000 cp, 15 gp dustu.
      expect((await characters.find('vex'))!.coinsCp, 8500);

      final inventory = await (db.select(
        db.characterItems,
      )..where((t) => t.characterId.equals('vex'))).get();
      expect(inventory.single.itemKey, isNotNull);
      expect(inventory.single.quantity, 1);

      expect((await shops.entries(shopId)).single.stock.quantity, 1);
    });

    test('parasi yetmezse hicbir sey degismez', () async {
      await characters.setCoins('vex', 100); // 1 gp

      final result = await shops.purchase(
        characterId: 'vex',
        stockId: await stockId(),
      );

      expect(result, isA<PurchaseFailed>());
      expect((result as PurchaseFailed).reason, PurchaseFailure.notEnoughGold);

      // Altin ve stok dokunulmamis olmali.
      expect((await characters.find('vex'))!.coinsCp, 100);
      expect((await shops.entries(shopId)).single.stock.quantity, 2);
      expect(
        await (db.select(
          db.characterItems,
        )..where((t) => t.characterId.equals('vex'))).get(),
        isEmpty,
      );
    });

    test('stoktan fazlasi alinamaz', () async {
      final result = await shops.purchase(
        characterId: 'vex',
        stockId: await stockId(),
        quantity: 5,
      );
      expect(result, isA<PurchaseFailed>());
      expect((result as PurchaseFailed).reason, PurchaseFailure.onlyNLeft);
    });

    test('stok bitince tukendi der', () async {
      final id = await stockId();
      await shops.purchase(characterId: 'vex', stockId: id, quantity: 2);

      final result = await shops.purchase(characterId: 'vex', stockId: id);
      expect((result as PurchaseFailed).reason, PurchaseFailure.soldOut);
    });

    test('kapali magazadan alisveris yapilamaz', () async {
      await shops.update(shopId, closed: true);

      final result = await shops.purchase(
        characterId: 'vex',
        stockId: await stockId(),
      );
      expect(result, isA<PurchaseFailed>());
      expect((result as PurchaseFailed).reason, PurchaseFailure.shopClosed);
      expect((await characters.find('vex'))!.coinsCp, 10000);
    });

    test('sinirsiz stok azalmaz', () async {
      await shops.updateStock(await stockId(), quantity: -1);
      await shops.purchase(characterId: 'vex', stockId: await stockId());

      expect((await shops.entries(shopId)).single.stock.quantity, -1);
      expect((await characters.find('vex'))!.coinsCp, 8500);
    });

    test('coklu alimda toplam fiyat carpilir', () async {
      final result = await shops.purchase(
        characterId: 'vex',
        stockId: await stockId(),
        quantity: 2,
      );
      expect((result as PurchaseOk).totalCp, 3000);
      expect((await characters.find('vex'))!.coinsCp, 7000);
    });
  });

  test('kendi esyani yaratip magazaya koyabilirsin', () async {
    final key = await custom.addItem(
      name: 'Cüce Ekmeği',
      costGp: 3,
      description: 'Bir gün boyunca doyurur.',
    );
    await shops.addItem(shopId: shopId, itemKey: key);

    final entry = (await shops.entries(shopId)).single;
    expect(entry.name, 'Cüce Ekmeği');
    expect(entry.priceCp, 300);
  });

  test('kendi buyulu esyan nadirlikten fiyatlanir', () async {
    final key = await custom.addMagicItem(
      name: 'Gundren’in Yüzüğü',
      rarityKey: 'rare',
      requiresAttunement: true,
    );
    await shops.addItem(shopId: shopId, magicItemKey: key);

    final entry = (await shops.entries(shopId)).single;
    expect(entry.rarity, 'Rare');
    expect(entry.requiresAttunement, isTrue);
    expect(entry.priceIsSuggested, isTrue);
    expect(entry.priceCp, greaterThan(0));
  });

  group('isleten NPC', () {
    test('kurarken NPC baglanir, adi da yazilir', () async {
      final id = await shops.create(
        name: 'Simyacı',
        ownerName: 'Yaşlı Meryem',
        ownerNpcId: 'npc-1',
      );
      final shop = (await shops.find(id))!;
      expect(shop.ownerNpcId, 'npc-1');
      expect(shop.ownerName, 'Yaşlı Meryem');
    });

    test('setOwner bagi kurar ve KALDIRIR', () async {
      await shops.setOwner(shopId, npcId: 'npc-7', name: 'Gundren');
      var shop = (await shops.find(shopId))!;
      expect(shop.ownerNpcId, 'npc-7');
      expect(shop.ownerName, 'Gundren');

      // `update`'in "null = degistirme" deseni kolonu bosaltamadigi icin bu
      // ayri metot var; bagi kaldirmak GERCEKTEN null yazmali.
      await shops.setOwner(shopId);
      shop = (await shops.find(shopId))!;
      expect(shop.ownerNpcId, isNull);
      expect(shop.ownerName, isNull);
    });

    test('bos/bosluklu ad null olarak yazilir', () async {
      await shops.setOwner(shopId, name: '   ');
      expect((await shops.find(shopId))!.ownerName, isNull);
    });
  });

  test('magaza silinince stogu da silinir', () async {
    await shops.addItem(
      shopId: shopId,
      itemKey: await itemKeyNamed('Longsword'),
    );
    await shops.delete(shopId);

    expect(await shops.find(shopId), isNull);
    expect(await db.select(db.shopStock).get(), isEmpty);
  });
}
