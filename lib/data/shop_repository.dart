import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/rules/magic_item_pricing.dart';
import '../net/protocol.dart' show encodeServerMsg;
import 'character_repository.dart';
import 'db/database.dart';

/// Bir magaza satirinin oyuncuya gosterilecek hali: adi, cozulmus fiyati ve
/// kalan adedi bir arada.
class ShopEntry {
  const ShopEntry({
    required this.stock,
    required this.name,
    required this.priceCp,
    this.description = '',
    this.category,
    this.rarity,
    this.requiresAttunement = false,
    this.priceIsSuggested = false,
  });

  final ShopStockData stock;
  final String name;

  /// Carpan ve ozel fiyat uygulanmis nihai fiyat (bakir).
  final int priceCp;
  final String description;
  final String? category;
  final String? rarity;
  final bool requiresAttunement;

  /// Fiyat SRD'den degil, nadirlikten turetildiyse arayuz belirtir.
  final bool priceIsSuggested;

  bool get unlimited => stock.quantity < 0;
  bool get soldOut => !unlimited && stock.quantity <= 0;
}

/// Satin alma sonucu.
sealed class PurchaseResult {
  const PurchaseResult();
}

class PurchaseOk extends PurchaseResult {
  const PurchaseOk({required this.itemName, required this.totalCp});

  final String itemName;
  final int totalCp;
}

class PurchaseFailed extends PurchaseResult {
  const PurchaseFailed(this.reason);

  final String reason;
}

class ShopRepository {
  ShopRepository(this.db);

  final AppDatabase db;

  static const _uuid = Uuid();

  Stream<List<Shop>> watchShops() => (db.select(
    db.shops,
  )..orderBy([(t) => OrderingTerm(expression: t.name)])).watch();

  Future<Shop?> find(String id) =>
      (db.select(db.shops)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<Shop?> watchShop(String id) =>
      (db.select(db.shops)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<String> create({
    required String name,
    String? ownerName,
    String? ownerNpcId,
  }) async {
    final id = 'shop-${_uuid.v4()}';
    await db
        .into(db.shops)
        .insert(
          ShopsCompanion.insert(
            id: id,
            name: name,
            ownerName: Value(ownerName),
            ownerNpcId: Value(ownerNpcId),
          ),
        );
    return id;
  }

  Future<void> update(
    String id, {
    String? name,
    String? ownerName,
    String? description,
    double? priceMultiplier,
    bool? openToPlayers,
    bool? requiresApproval,
    bool? mapAccessible,
    bool? closed,
    int? restockDays,
  }) async {
    await (db.update(db.shops)..where((t) => t.id.equals(id))).write(
      ShopsCompanion(
        name: name == null ? const Value.absent() : Value(name),
        ownerName: ownerName == null ? const Value.absent() : Value(ownerName),
        description: description == null
            ? const Value.absent()
            : Value(description),
        priceMultiplier: priceMultiplier == null
            ? const Value.absent()
            : Value(priceMultiplier),
        openToPlayers: openToPlayers == null
            ? const Value.absent()
            : Value(openToPlayers),
        requiresApproval: requiresApproval == null
            ? const Value.absent()
            : Value(requiresApproval),
        mapAccessible: mapAccessible == null
            ? const Value.absent()
            : Value(mapAccessible),
        closed: closed == null ? const Value.absent() : Value(closed),
        restockDays: restockDays == null
            ? const Value.absent()
            : Value(restockDays < 0 ? 0 : restockDays),
      ),
    );
  }

  /// Isleten NPC'yi ayarlar ya da bagi kaldirir.
  ///
  /// [update]'in `null = degistirme` deseni bir kolonu NULL'a CEKEMEDIGI icin
  /// ayri metot (`WorldRepository.setMapScale` ile ayni sebep): DM "bagi
  /// kaldir" dediginde hem id hem ad temizlenebilmeli. Bagli NPC'nin adi
  /// [ownerName]'e de yazilir, boylece oyuncuya giden veri ve liste ozeti
  /// tek alandan okunmaya devam eder (NPC sonradan silinse bile ad kalir).
  Future<void> setOwner(String shopId, {String? npcId, String? name}) async {
    await (db.update(db.shops)..where((t) => t.id.equals(shopId))).write(
      ShopsCompanion(
        ownerNpcId: Value(npcId),
        ownerName: Value(
          name == null || name.trim().isEmpty ? null : name.trim(),
        ),
      ),
    );
  }

  /// Haritadan erisilebilir tum magazalar (dukkan pininden acilabilir).
  Future<List<Shop>> mapAccessibleShops() =>
      (db.select(db.shops)..where((t) => t.mapAccessible.equals(true))).get();

  // NOT: Silme/guncellemeler tipli Drift API'siyle yapiliyor, ham
  // customStatement ile DEGIL. Ham SQL calisirken Drift hangi tablonun
  // degistigini cikaramiyor ve `watch...` akislarini yenilemiyor; "silince
  // listede kalmaya devam ediyor / gecikmeli yansiyor" hatasi buydu.
  Future<void> delete(String id) async {
    await db.transaction(() async {
      await (db.delete(db.shopStock)..where((t) => t.shopId.equals(id))).go();
      await (db.delete(db.shops)..where((t) => t.id.equals(id))).go();
    });
  }

  /// Ayni anda yalnizca bir magaza acik olsun: DM "bu mağazayı göster"
  /// dediginde oncekiler kapanir, yoksa oyuncular hangi dukkanda olduklarini
  /// karistiriyor.
  Future<void> openOnly(String? shopId) async {
    await db.transaction(() async {
      await db
          .update(db.shops)
          .write(const ShopsCompanion(openToPlayers: Value(false)));
      if (shopId != null) {
        await (db.update(db.shops)..where((t) => t.id.equals(shopId))).write(
          const ShopsCompanion(openToPlayers: Value(true)),
        );
      }
    });
  }

  Future<Shop?> openShop() async => (db.select(
    db.shops,
  )..where((t) => t.openToPlayers.equals(true))).getSingleOrNull();

  /// Belirli bir stok satirinin ait oldugu magazayi bulur. Satir bir magazaya
  /// bagli degilse null doner.
  Future<Shop?> shopOfStock(String stockId) async {
    final stock = await (db.select(
      db.shopStock,
    )..where((t) => t.id.equals(stockId))).getSingleOrNull();
    if (stock == null) return null;
    return find(stock.shopId);
  }

  Stream<List<ShopStockData>> watchStock(String shopId) =>
      (db.select(db.shopStock)
            ..where((t) => t.shopId.equals(shopId))
            ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
          .watch();

  Future<void> addItem({
    required String shopId,
    String? itemKey,
    String? magicItemKey,
    String? customName,
    String? customDesc,
    int? priceCpOverride,
    int quantity = -1,
  }) async {
    final existing = await _stockOf(shopId);
    await db
        .into(db.shopStock)
        .insert(
          ShopStockCompanion.insert(
            id: _uuid.v4(),
            shopId: shopId,
            itemKey: Value(itemKey),
            magicItemKey: Value(magicItemKey),
            customName: Value(customName),
            customDesc: Value(customDesc),
            priceCpOverride: Value(priceCpOverride),
            quantity: Value(quantity),
            sortOrder: Value(existing.length),
          ),
        );
  }

  Future<void> updateStock(
    String stockId, {
    int? quantity,
    int? priceCpOverride,
    bool clearPriceOverride = false,
    int? restockQuantity,
    bool clearRestockQuantity = false,
  }) async {
    await (db.update(db.shopStock)..where((t) => t.id.equals(stockId))).write(
      ShopStockCompanion(
        quantity: quantity == null ? const Value.absent() : Value(quantity),
        priceCpOverride: clearPriceOverride
            ? const Value(null)
            : (priceCpOverride == null
                  ? const Value.absent()
                  : Value(priceCpOverride)),
        restockQuantity: clearRestockQuantity
            ? const Value(null)
            : (restockQuantity == null
                  ? const Value.absent()
                  : Value(restockQuantity)),
      ),
    );
  }

  // --- Takvime bagli stok yenilemesi ---------------------------------------

  /// Suresi dolan magazalarin stogunu yeniler; yenilenen magaza adlarini doner.
  ///
  /// [absoluteDay] `game_calendar.absoluteDay` ile hesaplanan oyun-ici mutlak
  /// gundur. Takvim her ilerledigin de cagrilir (bkz. `advanceGameDays`).
  ///
  /// Kurallar:
  /// - `restockDays == 0` olan magaza hic yenilenmez.
  /// - `lastRestockDay` bossa yenileme YAPILMAZ, yalnizca sayac baslatilir —
  ///   yoksa ozelligi acan DM'in stogu ilk gun ilerlemesinde beklenmedik
  ///   sekilde sifirlanirdi.
  /// - Zamanda GERI gidilirse (`absoluteDay < lastRestockDay`) sayac o gune
  ///   cekilir; yoksa magaza gelecekte kalmis bir tarihe takilip bir daha
  ///   yenilenmezdi.
  /// - Yalnizca `restockQuantity` tanimli satirlar yenilenir; sinirsiz (-1)
  ///   ve benzersiz esyalar oldugu gibi kalir.
  Future<List<String>> applyRestocks(int absoluteDay) async {
    final shops = await (db.select(
      db.shops,
    )..where((t) => t.restockDays.isBiggerThanValue(0))).get();
    if (shops.isEmpty) return const [];

    final restocked = <String>[];
    for (final shop in shops) {
      final last = shop.lastRestockDay;

      if (last == null || absoluteDay < last) {
        // Sayaci baslat / geri sar; bu turda yenileme yok.
        await (db.update(db.shops)..where((t) => t.id.equals(shop.id))).write(
          ShopsCompanion(lastRestockDay: Value(absoluteDay)),
        );
        continue;
      }
      if (absoluteDay - last < shop.restockDays) continue;

      await db.transaction(() async {
        final rows = await _stockOf(shop.id);
        for (final row in rows) {
          final target = row.restockQuantity;
          // Sinirsiz satir (-1) yenilenmez: hedefi yazmak onu sessizce
          // sinirli bir satira cevirirdi.
          if (target == null || row.quantity < 0 || row.quantity == target) {
            continue;
          }
          await (db.update(db.shopStock)..where((t) => t.id.equals(row.id)))
              .write(ShopStockCompanion(quantity: Value(target)));
        }
        await (db.update(db.shops)..where((t) => t.id.equals(shop.id))).write(
          ShopsCompanion(lastRestockDay: Value(absoluteDay)),
        );
      });
      restocked.add(shop.name);
    }
    return restocked;
  }

  Future<void> removeStock(String stockId) async {
    await (db.delete(db.shopStock)..where((t) => t.id.equals(stockId))).go();
  }

  /// Magazanin gosterilebilir hali: her satirin adi ve nihai fiyati cozulur.
  Future<List<ShopEntry>> entries(String shopId) async {
    final shop = await find(shopId);
    if (shop == null) return const [];

    final stock = await _stockOf(shopId);
    if (stock.isEmpty) return const [];

    final itemKeys = stock.map((s) => s.itemKey).whereType<String>().toList();
    final magicKeys = stock
        .map((s) => s.magicItemKey)
        .whereType<String>()
        .toList();

    final items = itemKeys.isEmpty
        ? <String, Item>{}
        : {
            for (final row in await (db.select(
              db.items,
            )..where((t) => t.key.isIn(itemKeys))).get())
              row.key: row,
          };
    final magicItems = magicKeys.isEmpty
        ? <String, MagicItem>{}
        : {
            for (final row in await (db.select(
              db.magicItems,
            )..where((t) => t.key.isIn(magicKeys))).get())
              row.key: row,
          };

    return [
      for (final s in stock)
        _entryFor(s, shop, items[s.itemKey], magicItems[s.magicItemKey]),
    ];
  }

  ShopEntry _entryFor(
    ShopStockData stock,
    Shop shop,
    Item? item,
    MagicItem? magicItem,
  ) {
    final listPrice =
        stock.priceCpOverride ?? item?.costCp ?? magicItem?.costCp;

    // Ozel fiyat verildiyse carpan uygulanmaz: DM zaten kesin rakami yazmis.
    final price =
        stock.priceCpOverride ??
        (listPrice == null ? 0 : (listPrice * shop.priceMultiplier).round());

    return ShopEntry(
      stock: stock,
      name: stock.customName ?? item?.name ?? magicItem?.name ?? '',
      priceCp: price,
      description:
          stock.customDesc ??
          _descriptionOf(item?.dataJson ?? magicItem?.dataJson),
      category: item?.category ?? magicItem?.category,
      rarity: magicItem?.rarity,
      requiresAttunement: magicItem?.requiresAttunement ?? false,
      priceIsSuggested:
          stock.priceCpOverride == null &&
          (magicItem?.costIsSuggested ?? false),
    );
  }

  /// Bir karakterin magazadan alisverisi.
  ///
  /// Tek islemde: altin kontrolu, altin dusme, envantere ekleme ve stok
  /// azaltma. Herhangi biri basarisizsa hicbiri uygulanmaz -- yarim kalmis
  /// alisveris (parasi gitti, esya gelmedi) en can yakici hata olurdu.
  Future<PurchaseResult> purchase({
    required String characterId,
    required String stockId,
    int quantity = 1,
  }) async {
    if (quantity < 1) return PurchaseFailed(encodeServerMsg('invalidQuantity'));

    return db.transaction(() async {
      final stock = await (db.select(
        db.shopStock,
      )..where((t) => t.id.equals(stockId))).getSingleOrNull();
      if (stock == null) return PurchaseFailed(encodeServerMsg('itemNotFound'));

      final shop = await find(stock.shopId);
      if (shop == null) return PurchaseFailed(encodeServerMsg('shopNotFound'));
      // Kapali magazadan alisveris olmaz; haritadan erisilebilir ama acik
      // bir magaza normal sekilde satis yapar.
      if (shop.closed) {
        return PurchaseFailed(encodeServerMsg('shopClosed'));
      }

      if (stock.quantity >= 0 && stock.quantity < quantity) {
        return PurchaseFailed(
          stock.quantity == 0
              ? encodeServerMsg('soldOut')
              : encodeServerMsg('onlyNLeft', ['${stock.quantity}']),
        );
      }

      final all = await entries(stock.shopId);
      final entry = all.where((e) => e.stock.id == stockId).firstOrNull;
      if (entry == null) return PurchaseFailed(encodeServerMsg('itemNotFound'));

      final character = await (db.select(
        db.characters,
      )..where((t) => t.id.equals(characterId))).getSingleOrNull();
      if (character == null) {
        return PurchaseFailed(encodeServerMsg('characterNotFound'));
      }

      final total = entry.priceCp * quantity;
      if (character.coinsCp < total) {
        return PurchaseFailed(
          encodeServerMsg('notEnoughGold', [
            formatCoins(total),
            formatCoins(character.coinsCp),
          ]),
        );
      }

      await (db.update(
        db.characters,
      )..where((t) => t.id.equals(characterId))).write(
        CharactersCompanion(
          coinsCp: Value(character.coinsCp - total),
          updatedAt: Value(DateTime.now()),
        ),
      );

      // Ayni esya zaten envanterdeyse adedi artar; her alista yeni satir
      // acilip "hancer, hancer, hancer" olmaz.
      await CharacterRepository(db).addItem(
        characterId: characterId,
        itemKey: stock.itemKey,
        magicItemKey: stock.magicItemKey,
        customName: stock.customName,
        customDesc: stock.customDesc,
        quantity: quantity,
      );

      if (stock.quantity >= 0) {
        await (db.update(
          db.shopStock,
        )..where((t) => t.id.equals(stockId))).write(
          ShopStockCompanion(quantity: Value(stock.quantity - quantity)),
        );
      }

      return PurchaseOk(itemName: entry.name, totalCp: total);
    });
  }

  Future<List<ShopStockData>> _stockOf(String shopId) =>
      (db.select(db.shopStock)
            ..where((t) => t.shopId.equals(shopId))
            ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
          .get();

  static String _descriptionOf(String? dataJson) {
    if (dataJson == null) return '';
    try {
      final data = jsonDecode(dataJson) as Map<String, dynamic>;
      return '${data['desc'] ?? ''}';
    } on FormatException {
      return '';
    }
  }
}
