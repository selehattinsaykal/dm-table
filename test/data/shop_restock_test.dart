import 'package:dm_table/data/calendar_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/reminder_repository.dart';
import 'package:dm_table/data/shop_repository.dart';
import 'package:dm_table/features/calendar/calendar_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Takvime bagli magaza stok yenilemesi.
///
/// `GameClock` bir Riverpod saglayicisiyla sunuluyor ama sinifin kendisi
/// widget/kap gerektirmiyor — burada dogrudan kuruluyor.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ShopRepository shops;
  late CalendarRepository calendar;
  late GameClock clock;
  late String shopId;

  /// Yenilenebilir bir stok satiri kurar ve id'sini doner.
  Future<String> addRestockingLine({
    required int quantity,
    required int restockTo,
  }) async {
    await shops.addItem(
      shopId: shopId,
      customName: 'İksir',
      priceCpOverride: 5000,
      quantity: quantity,
    );
    final rows = await shops.watchStock(shopId).first;
    final line = rows.last;
    await shops.updateStock(line.id, restockQuantity: restockTo);
    return line.id;
  }

  Future<int> quantityOf(String stockId) async {
    final rows = await shops.watchStock(shopId).first;
    return rows.firstWhere((r) => r.id == stockId).quantity;
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    shops = ShopRepository(db);
    calendar = CalendarRepository(db);
    clock = GameClock(
      calendar: calendar,
      shops: shops,
      reminders: ReminderRepository(db),
    );
    // 12 x 30 gunluk varsayilan takvim; ay adlari testte onemsiz.
    await calendar.ensureDefaultCalendar(
      monthNames: [for (var i = 1; i <= 12; i++) 'Ay $i'],
      weekdayNames: [for (var i = 1; i <= 7; i++) 'Gün $i'],
      seasonSpec: const [],
    );
    shopId = await shops.create(name: 'Simyacı');
  });

  tearDown(() async => db.close());

  test('restockDays 0 olan magaza hic yenilenmez', () async {
    final line = await addRestockingLine(quantity: 0, restockTo: 5);

    final result = await clock.advanceDays(100);

    expect(result.restockedShops, isEmpty);
    expect(await quantityOf(line), 0);
  });

  test('ilk gun ilerlemesi yalnizca sayaci baslatir', () async {
    await shops.update(shopId, restockDays: 7);
    final line = await addRestockingLine(quantity: 0, restockTo: 5);

    // lastRestockDay bostu: bu tur yenileme yok, yalnizca baslangic yazilir.
    final first = await clock.advanceDays(30);
    expect(first.restockedShops, isEmpty);
    expect(await quantityOf(line), 0);

    // Sayac basladiktan sonra suresi dolunca yenilenir.
    final second = await clock.advanceDays(7);
    expect(second.restockedShops, ['Simyacı']);
    expect(await quantityOf(line), 5);
  });

  test('sure dolmadan yenileme olmaz', () async {
    await shops.update(shopId, restockDays: 7);
    final line = await addRestockingLine(quantity: 1, restockTo: 5);

    await clock.advanceDays(1); // sayaci baslat
    final result = await clock.advanceDays(6);

    expect(result.restockedShops, isEmpty);
    expect(await quantityOf(line), 1);
  });

  test('restockQuantity verilmemis satir dokunulmadan kalir', () async {
    await shops.update(shopId, restockDays: 1);
    await shops.addItem(
      shopId: shopId,
      customName: 'Benzersiz kılıç',
      quantity: 0,
    );
    final unique = (await shops.watchStock(shopId).first).single;

    await clock.advanceDays(1);
    await clock.advanceDays(1);

    expect(await quantityOf(unique.id), 0);
  });

  test('sinirsiz satir yenilemede sinirliya donusmez', () async {
    await shops.update(shopId, restockDays: 1);
    // -1 = sinirsiz. Hedef verilse bile satir sinirsiz kalmali.
    final line = await addRestockingLine(quantity: -1, restockTo: 5);

    await clock.advanceDays(1);
    await clock.advanceDays(1);

    expect(await quantityOf(line), -1);
  });

  test('zamanda geri gidilirse sayac geri sarilir', () async {
    await shops.update(shopId, restockDays: 5);
    final line = await addRestockingLine(quantity: 0, restockTo: 3);

    await clock.advanceDays(1); // sayaci baslat
    await clock.advanceDays(5); // yenile
    expect(await quantityOf(line), 3);

    await shops.updateStock(line, quantity: 0);
    // Geri gidiste yenileme yok, sayac o gune cekilir...
    final back = await clock.advanceDays(-20);
    expect(back.restockedShops, isEmpty);
    expect(await quantityOf(line), 0);

    // ...ve magaza gelecekte kalmis bir tarihe takilip kilitlenmez.
    final forward = await clock.advanceDays(5);
    expect(forward.restockedShops, ['Simyacı']);
    expect(await quantityOf(line), 3);
  });

  test('gun ilerlemesi okunur tarih etiketi doner', () async {
    final result = await clock.advanceDays(1);
    expect(result.label, isNotEmpty);
    expect(result.date.day, 2);
  });

  test('setDate de yenilemeyi tetikler', () async {
    await shops.update(shopId, restockDays: 3);
    final line = await addRestockingLine(quantity: 0, restockTo: 2);

    await clock.setDate((year: 1, monthIndex: 0, day: 1)); // sayaci baslat
    final result = await clock.setDate((year: 1, monthIndex: 1, day: 1));

    expect(result.restockedShops, ['Simyacı']);
    expect(await quantityOf(line), 2);
  });
}
