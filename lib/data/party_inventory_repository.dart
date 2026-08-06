import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'db/database.dart';

/// Ortak kesedeki bir esya.
///
/// [id] yatirma aninda uretilen KALICI uuid'dir; alma islemi yalnizca bununla
/// yapilir (index ya da ad ile DEGIL — bkz. [PartyInventoryRepository.takeItem]).
typedef PartyItem = ({
  String id,
  String name,
  bool magic,
  String? itemKey,
  String? magicItemKey,
  String? desc,
  int quantity,
});

/// Ortak parti keselerini okur/yazar.
///
/// Uyeler serbestce alir/koyar; DM onayi yoktur. Hazine pini havuzundan iki
/// bilincli sapma var, ikisi de asagida ilgili metotta belgelendi:
/// bosalan kese SILINMEZ, ve alma islemi adet bazinda YA HEP YA HIC'tir.
class PartyInventoryRepository {
  PartyInventoryRepository(this.db);

  final AppDatabase db;
  static const _uuid = Uuid();

  // --- Okuma ---------------------------------------------------------------

  Stream<List<PartyInventory>> watchAll() =>
      (db.select(db.partyInventories)..orderBy([
            (t) => OrderingTerm(expression: t.sortOrder),
            (t) => OrderingTerm(expression: t.name),
          ]))
          .watch();

  Future<List<PartyInventory>> all() =>
      (db.select(db.partyInventories)..orderBy([
            (t) => OrderingTerm(expression: t.sortOrder),
            (t) => OrderingTerm(expression: t.name),
          ]))
          .get();

  Stream<PartyInventory?> watchOne(String id) => (db.select(
    db.partyInventories,
  )..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<PartyInventory?> find(String id) => (db.select(
    db.partyInventories,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Uye karakter id'leri. Bozuk JSON'da bos liste doner (firlatmaz).
  static List<String> membersOf(PartyInventory inv) {
    try {
      final data = jsonDecode(inv.membersJson);
      if (data is! List) return const [];
      return [for (final e in data) '$e'];
    } catch (_) {
      return const [];
    }
  }

  /// Kesedeki esyalar. Bozuk JSON'da bos liste doner (firlatmaz).
  static List<PartyItem> itemsOf(PartyInventory inv) =>
      decodeItems(inv.itemsJson);

  static List<PartyItem> decodeItems(String json) {
    try {
      final data = jsonDecode(json);
      if (data is! List) return const [];
      final out = <PartyItem>[];
      for (final e in data) {
        if (e is! Map) continue;
        // Kayit yalnizca ID'siz ise atlanir: id alma isleminin TEK tutamagi,
        // idsiz giris zaten alinamaz (ve bos itemId ile yanlis eslesirdi).
        // ADI BOS OLAN ATLANMAZ -- `itemDisplayName` katalog satiri
        // bulunamayinca bos ad doner (silinmis homebrew esya gibi); bunu
        // elemek esyayi yatiran oyuncudan KALICI OLARAK yok ederdi. Bos ad
        // gosterim katmaninda "Bilinmeyen eşya" olarak karsilanir.
        final id = e['id'] as String? ?? '';
        if (id.isEmpty) continue;
        final rawQty = e['quantity'];
        final qty = rawQty is num ? rawQty.round() : 1;
        out.add((
          id: id,
          name: e['name'] as String? ?? '',
          magic: e['magic'] as bool? ?? false,
          itemKey: e['itemKey'] as String?,
          magicItemKey: e['magicItemKey'] as String?,
          desc: e['desc'] as String?,
          quantity: qty < 1 ? 1 : qty,
        ));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  static String encodeItems(List<PartyItem> items) => jsonEncode([
    for (final i in items)
      {
        'id': i.id,
        'name': i.name,
        'magic': i.magic,
        if (i.itemKey != null) 'itemKey': i.itemKey,
        if (i.magicItemKey != null) 'magicItemKey': i.magicItemKey,
        if (i.desc != null && i.desc!.isNotEmpty) 'desc': i.desc,
        'quantity': i.quantity,
      },
  ]);

  /// Yeni bir kese esyasi (kalici uuid atanir).
  static PartyItem newItem({
    required String name,
    bool magic = false,
    String? itemKey,
    String? magicItemKey,
    String? desc,
    int quantity = 1,
  }) => (
    id: _uuid.v4(),
    name: name,
    magic: magic,
    itemKey: itemKey,
    magicItemKey: magicItemKey,
    desc: desc,
    quantity: quantity < 1 ? 1 : quantity,
  );

  // --- DM duzenlemesi ------------------------------------------------------

  Future<String> create(String name) async {
    final id = 'party-${_uuid.v4()}';
    final count = (await all()).length;
    await db
        .into(db.partyInventories)
        .insert(
          PartyInventoriesCompanion.insert(
            id: id,
            name: name,
            sortOrder: Value(count),
          ),
        );
    return id;
  }

  Future<void> rename(String id, String name) =>
      (db.update(db.partyInventories)..where((t) => t.id.equals(id))).write(
        PartyInventoriesCompanion(name: Value(name)),
      );

  Future<void> setMembers(String id, List<String> characterIds) =>
      (db.update(db.partyInventories)..where((t) => t.id.equals(id))).write(
        PartyInventoriesCompanion(membersJson: Value(jsonEncode(characterIds))),
      );

  Future<void> setCoins(String id, int coinsCp) =>
      (db.update(db.partyInventories)..where((t) => t.id.equals(id))).write(
        PartyInventoriesCompanion(coinsCp: Value(coinsCp < 0 ? 0 : coinsCp)),
      );

  Future<void> setItems(String id, List<PartyItem> items) =>
      (db.update(db.partyInventories)..where((t) => t.id.equals(id))).write(
        PartyInventoriesCompanion(itemsJson: Value(encodeItems(items))),
      );

  Future<void> delete(String id) =>
      (db.delete(db.partyInventories)..where((t) => t.id.equals(id))).go();

  // --- Oyuncu tarafi: atomik, yaris-korumali -------------------------------

  /// Keseden tek esya alir.
  ///
  /// Esya KALICI UUID ile bulunur, index ya da adla DEGIL — gercek yaris
  /// korumasi budur: iki oyuncu ayni anda alirsa ikincisinin `indexWhere`'i
  /// -1 doner ve `itemGone` alir, esya tam olarak bir kisiye gider.
  ///
  /// **Adet ya hep ya hic:** 3 kalmisken 5 istenirse `itemGone` doner,
  /// "al sana 3" degil (`CharacterRepository.transferItem` ile ayni kural).
  ///
  /// **Bosalan kese SILINMEZ:** hazine pini tek kullanimlik bir karsilasma
  /// nesnesi, parti kesesi ise DM'in adlandirdigi kalici bir kap; son kurusta
  /// silmek veri kaybi olurdu.
  Future<
    ({
      String? error,
      String? name,
      bool magic,
      String? itemKey,
      String? magicItemKey,
      String? desc,
      int quantity,
    })
  >
  takeItem(
    String inventoryId, {
    required String itemId,
    int quantity = 1,
  }) async {
    const failure = (
      error: 'itemGone',
      name: null,
      magic: false,
      itemKey: null,
      magicItemKey: null,
      desc: null,
      quantity: 0,
    );
    if (quantity < 1) {
      return (
        error: 'invalidQuantity',
        name: null,
        magic: false,
        itemKey: null,
        magicItemKey: null,
        desc: null,
        quantity: 0,
      );
    }

    return db.transaction(() async {
      final inv = await find(inventoryId);
      if (inv == null) {
        return (
          error: 'noInventory',
          name: null,
          magic: false,
          itemKey: null,
          magicItemKey: null,
          desc: null,
          quantity: 0,
        );
      }

      final items = itemsOf(inv);
      final index = items.indexWhere((i) => i.id == itemId);
      if (index == -1) return failure;

      final entry = items[index];
      if (entry.quantity < quantity) return failure;

      if (entry.quantity == quantity) {
        items.removeAt(index);
      } else {
        items[index] = (
          id: entry.id,
          name: entry.name,
          magic: entry.magic,
          itemKey: entry.itemKey,
          magicItemKey: entry.magicItemKey,
          desc: entry.desc,
          quantity: entry.quantity - quantity,
        );
      }
      await setItems(inventoryId, items);

      return (
        error: null,
        name: entry.name,
        magic: entry.magic,
        itemKey: entry.itemKey,
        magicItemKey: entry.magicItemKey,
        desc: entry.desc,
        quantity: quantity,
      );
    });
  }

  /// Keseden para alir. [amountCp] null ise KALANIN TAMAMI alinir.
  Future<({String? error, int takenCoinsCp})> takeCoins(
    String inventoryId, {
    int? amountCp,
  }) => db.transaction(() async {
    final inv = await find(inventoryId);
    if (inv == null) return (error: 'noInventory', takenCoinsCp: 0);
    if (inv.coinsCp <= 0) return (error: 'noMoneyLeft', takenCoinsCp: 0);

    final amount = amountCp ?? inv.coinsCp;
    if (amount <= 0) return (error: 'invalidQuantity', takenCoinsCp: 0);
    // Sessizce kirpma yok: yetmiyorsa hata doner.
    if (amount > inv.coinsCp) return (error: 'notEnoughMoney', takenCoinsCp: 0);

    await setCoins(inventoryId, inv.coinsCp - amount);
    return (error: null, takenCoinsCp: amount);
  });

  /// Keseye esya koyar; ayni katalog anahtarina (anahtar yoksa ayni ada) sahip
  /// bir giris varsa adedi artirilir.
  Future<String?> depositItem(String inventoryId, {required PartyItem item}) =>
      db.transaction(() async {
        final inv = await find(inventoryId);
        if (inv == null) return 'noInventory';
        if (item.quantity < 1) return 'invalidQuantity';

        final items = itemsOf(inv);
        // Istifleme: once anahtar, anahtar yoksa ad. `addItem` ile ayni mantik.
        final index = items.indexWhere(
          (i) =>
              (item.itemKey != null && i.itemKey == item.itemKey) ||
              (item.magicItemKey != null &&
                  i.magicItemKey == item.magicItemKey) ||
              (item.itemKey == null &&
                  item.magicItemKey == null &&
                  i.itemKey == null &&
                  i.magicItemKey == null &&
                  i.name == item.name),
        );

        if (index == -1) {
          items.add(item);
        } else {
          final existing = items[index];
          items[index] = (
            id: existing.id,
            name: existing.name,
            magic: existing.magic,
            itemKey: existing.itemKey,
            magicItemKey: existing.magicItemKey,
            desc: existing.desc ?? item.desc,
            quantity: existing.quantity + item.quantity,
          );
        }
        await setItems(inventoryId, items);
        return null;
      });

  Future<String?> depositCoins(String inventoryId, {required int amountCp}) =>
      db.transaction(() async {
        final inv = await find(inventoryId);
        if (inv == null) return 'noInventory';
        if (amountCp <= 0) return 'invalidQuantity';
        await setCoins(inventoryId, inv.coinsCp + amountCp);
        return null;
      });
}
