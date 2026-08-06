import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/party_inventory_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ortak parti kesesi: uyeler serbestce alir/koyar.
///
/// Kritik davranislar: esya KALICI UUID ile bulunur (yaris korumasi), adet ya
/// hep ya hic alinir, ve bosalan kese SILINMEZ (hazine pininden bilincli
/// sapma).
void main() {
  late AppDatabase db;
  late PartyInventoryRepository party;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    party = PartyInventoryRepository(db);
  });

  tearDown(() => db.close());

  group('CRUD ve uyelik', () {
    test('olusturur, adlandirir, siler', () async {
      final id = await party.create('Parti kesesi');
      expect((await party.find(id))!.name, 'Parti kesesi');

      await party.rename(id, 'At arabası');
      expect((await party.find(id))!.name, 'At arabası');

      await party.delete(id);
      expect(await party.find(id), isNull);
    });

    test('uye listesi round-trip', () async {
      final id = await party.create('Kese');
      await party.setMembers(id, ['char-1', 'char-2']);

      final inv = (await party.find(id))!;
      expect(PartyInventoryRepository.membersOf(inv), ['char-1', 'char-2']);
    });

    test('uyesiz kese bos liste doner', () async {
      final id = await party.create('Kese');
      expect(
        PartyInventoryRepository.membersOf((await party.find(id))!),
        isEmpty,
      );
    });
  });

  group('esya kodlama', () {
    test('itemKey/magicItemKey/desc/quantity round-trip', () async {
      final id = await party.create('Kese');
      await party.setItems(id, [
        PartyInventoryRepository.newItem(
          name: 'Uzun kılıç',
          itemKey: 'longsword',
          desc: 'keskin',
          quantity: 2,
        ),
        PartyInventoryRepository.newItem(
          name: 'Alev Dili',
          magic: true,
          magicItemKey: 'flame-tongue',
        ),
      ]);

      final items = PartyInventoryRepository.itemsOf((await party.find(id))!);
      expect(items, hasLength(2));
      expect(items[0].itemKey, 'longsword');
      expect(items[0].desc, 'keskin');
      expect(items[0].quantity, 2);
      expect(items[1].magicItemKey, 'flame-tongue');
      expect(items[1].magic, isTrue);
    });

    test('bozuk itemsJson bos liste doner, firlatmaz', () {
      expect(PartyInventoryRepository.decodeItems('bu json degil'), isEmpty);
      expect(PartyInventoryRepository.decodeItems('{}'), isEmpty);
      expect(PartyInventoryRepository.decodeItems('[]'), isEmpty);
    });

    test('ID\'siz giris atlanir, adet en az 1', () {
      final items = PartyInventoryRepository.decodeItems(
        '[{"name":"Idsiz"},{"id":"a","name":"Ok","quantity":0}]',
      );
      expect(items, hasLength(1));
      expect(items.single.id, 'a');
      expect(items.single.quantity, 1);
    });

    test('ADI BOS olan giris KORUNUR (esya yok edilmez)', () {
      // `itemDisplayName` katalog satiri yoksa bos ad doner; bunu elemek
      // yatirilan esyayi kalici olarak silerdi.
      final items = PartyInventoryRepository.decodeItems(
        '[{"id":"a","name":"","itemKey":"silinmis-esya","quantity":2}]',
      );
      expect(items, hasLength(1));
      expect(items.single.itemKey, 'silinmis-esya');
      expect(items.single.quantity, 2);
    });

    test('adi cozulemeyen esya yatirilip geri alinabilir', () async {
      // Uctan uca: katalogda olmayan bir anahtarla yatirilan esya kaybolmaz.
      final id = await party.create('Kese');
      final item = PartyInventoryRepository.newItem(
        name: '',
        itemKey: 'katalogda-yok',
      );
      await party.setItems(id, [item]);

      final result = await party.takeItem(id, itemId: item.id);
      expect(result.error, isNull);
      expect(result.itemKey, 'katalogda-yok');
    });
  });

  group('depositItem', () {
    test('ayni katalog anahtari ISTIFLENIR', () async {
      final id = await party.create('Kese');
      await party.depositItem(
        id,
        item: PartyInventoryRepository.newItem(
          name: 'Ok',
          itemKey: 'arrow',
          quantity: 20,
        ),
      );
      await party.depositItem(
        id,
        item: PartyInventoryRepository.newItem(
          name: 'Ok',
          itemKey: 'arrow',
          quantity: 10,
        ),
      );

      final items = PartyInventoryRepository.itemsOf((await party.find(id))!);
      expect(items, hasLength(1));
      expect(items.single.quantity, 30);
    });

    test('farkli anahtar AYRI satir kalir', () async {
      final id = await party.create('Kese');
      await party.depositItem(
        id,
        item: PartyInventoryRepository.newItem(name: 'Ok', itemKey: 'arrow'),
      );
      await party.depositItem(
        id,
        item: PartyInventoryRepository.newItem(name: 'Ok', itemKey: 'bolt'),
      );

      expect(
        PartyInventoryRepository.itemsOf((await party.find(id))!),
        hasLength(2),
      );
    });

    test('anahtarsiz esyalar ada gore istiflenir', () async {
      final id = await party.create('Kese');
      await party.depositItem(
        id,
        item: PartyInventoryRepository.newItem(name: 'Tuhaf taş'),
      );
      await party.depositItem(
        id,
        item: PartyInventoryRepository.newItem(name: 'Tuhaf taş'),
      );

      final items = PartyInventoryRepository.itemsOf((await party.find(id))!);
      expect(items, hasLength(1));
      expect(items.single.quantity, 2);
    });

    test('olmayan keseye koymak noInventory', () async {
      final error = await party.depositItem(
        'yok',
        item: PartyInventoryRepository.newItem(name: 'X'),
      );
      expect(error, 'noInventory');
    });
  });

  group('takeItem', () {
    Future<(String invId, String itemId)> seeded({int quantity = 1}) async {
      final id = await party.create('Kese');
      final item = PartyInventoryRepository.newItem(
        name: 'Uzun kılıç',
        itemKey: 'longsword',
        quantity: quantity,
      );
      await party.setItems(id, [item]);
      return (id, item.id);
    }

    test('esyayi verir ve KATALOG ANAHTARINI korur', () async {
      final (invId, itemId) = await seeded();
      final result = await party.takeItem(invId, itemId: itemId);

      expect(result.error, isNull);
      expect(result.name, 'Uzun kılıç');
      // Regresyon: anahtar dusseydi esya karakterde serbest metne donerdi.
      expect(result.itemKey, 'longsword');
      expect(
        PartyInventoryRepository.itemsOf((await party.find(invId))!),
        isEmpty,
      );
    });

    test(
      'ayni uuid ikinci kez alinamaz -> itemGone (yaris korumasi)',
      () async {
        final (invId, itemId) = await seeded();
        expect((await party.takeItem(invId, itemId: itemId)).error, isNull);

        final second = await party.takeItem(invId, itemId: itemId);
        expect(second.error, 'itemGone');
        expect(second.name, isNull);
      },
    );

    test('adet yetmezse YA HEP YA HIC: havuz degismez', () async {
      final (invId, itemId) = await seeded(quantity: 3);
      final result = await party.takeItem(invId, itemId: itemId, quantity: 5);

      expect(result.error, 'itemGone');
      final items = PartyInventoryRepository.itemsOf(
        (await party.find(invId))!,
      );
      expect(items.single.quantity, 3, reason: 'kısmi alım olmamalı');
    });

    test('kismi alimda kalan adet duser, uuid korunur', () async {
      final (invId, itemId) = await seeded(quantity: 5);
      final result = await party.takeItem(invId, itemId: itemId, quantity: 2);

      expect(result.error, isNull);
      expect(result.quantity, 2);
      final items = PartyInventoryRepository.itemsOf(
        (await party.find(invId))!,
      );
      expect(items.single.quantity, 3);
      expect(items.single.id, itemId, reason: 'uuid sabit kalmalı');
    });

    test('gecersiz adet reddedilir', () async {
      final (invId, itemId) = await seeded();
      expect(
        (await party.takeItem(invId, itemId: itemId, quantity: 0)).error,
        'invalidQuantity',
      );
    });

    test('olmayan kese noInventory', () async {
      final result = await party.takeItem('yok', itemId: 'x');
      expect(result.error, 'noInventory');
    });
  });

  group('para', () {
    test('koyar ve alir', () async {
      final id = await party.create('Kese');
      expect(await party.depositCoins(id, amountCp: 500), isNull);
      expect((await party.find(id))!.coinsCp, 500);

      final taken = await party.takeCoins(id, amountCp: 200);
      expect(taken.error, isNull);
      expect(taken.takenCoinsCp, 200);
      expect((await party.find(id))!.coinsCp, 300);
    });

    test('amountCp null ise KALANIN TAMAMI alinir', () async {
      final id = await party.create('Kese');
      await party.depositCoins(id, amountCp: 750);

      final taken = await party.takeCoins(id);
      expect(taken.takenCoinsCp, 750);
      expect((await party.find(id))!.coinsCp, 0);
    });

    test('asiri cekim notEnoughMoney, kese degismez', () async {
      final id = await party.create('Kese');
      await party.depositCoins(id, amountCp: 100);

      final taken = await party.takeCoins(id, amountCp: 500);
      expect(taken.error, 'notEnoughMoney');
      expect(taken.takenCoinsCp, 0);
      expect((await party.find(id))!.coinsCp, 100);
    });

    test('bos keseden alinca noMoneyLeft', () async {
      final id = await party.create('Kese');
      expect((await party.takeCoins(id)).error, 'noMoneyLeft');
    });

    test('negatif/sifir yatirma reddedilir', () async {
      final id = await party.create('Kese');
      expect(await party.depositCoins(id, amountCp: 0), 'invalidQuantity');
      expect(await party.depositCoins(id, amountCp: -50), 'invalidQuantity');
      expect((await party.find(id))!.coinsCp, 0);
    });
  });

  test('BOSALAN KESE SILINMEZ (hazine pininden bilincli sapma)', () async {
    // Hazine pini son esya alininca silinir; parti kesesi DM'in adlandirdigi
    // kalici bir kap, silmek veri kaybi olurdu.
    final id = await party.create('Parti kesesi');
    final item = PartyInventoryRepository.newItem(name: 'Tek eşya');
    await party.setItems(id, [item]);
    await party.depositCoins(id, amountCp: 10);

    await party.takeItem(id, itemId: item.id);
    await party.takeCoins(id);

    final inv = await party.find(id);
    expect(inv, isNotNull, reason: 'kese boşalsa da durmalı');
    expect(inv!.name, 'Parti kesesi');
    expect(inv.coinsCp, 0);
    expect(PartyInventoryRepository.itemsOf(inv), isEmpty);
  });
}
