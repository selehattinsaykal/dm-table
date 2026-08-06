import 'dart:async';

import 'package:dm_table/data/combat_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/import/asset_importer.dart';
import 'package:dm_table/data/shop_repository.dart';
import 'package:dm_table/data/world_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Silme/degistirme islemleri canli akislari (watch...) yeniliyor mu?
///
/// Ham `customStatement` ile silinince Drift hangi tablonun degistigini
/// bilemiyor ve akis yeni deger yaymiyordu; "silince listede kaliyor"
/// hatasi buydu. Bu testler akisin gercekten yeni deger yaydigini dogrular.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await AssetImporter(db).importIfNeeded();
  });

  tearDown(() async => db.close());

  /// Akistan ikinci emisyonu (silme sonrasi) bekler.
  Future<List<T>> secondEmission<T>(Stream<List<T>> stream) {
    final completer = Completer<List<T>>();
    var count = 0;
    late final StreamSubscription<List<T>> sub;
    sub = stream.listen((rows) {
      count++;
      if (count == 2) {
        sub.cancel();
        completer.complete(rows);
      }
    });
    return completer.future.timeout(
      const Duration(seconds: 3),
      onTimeout: () => throw StateError('Akış silmeden sonra yenilenmedi'),
    );
  }

  test('mağaza silinince listeden düşer', () async {
    final shops = ShopRepository(db);
    final id = await shops.create(name: 'Demirci');

    final future = secondEmission(shops.watchShops());
    await shops.delete(id);

    expect(await future, isEmpty);
  });

  test('mağaza stoğu silinince listeden düşer', () async {
    final shops = ShopRepository(db);
    final shopId = await shops.create(name: 'Demirci');
    await shops.addItem(
      shopId: shopId,
      customName: 'Fener',
      priceCpOverride: 100,
    );
    final stockId = (await shops.entries(shopId)).single.stock.id;

    final future = secondEmission(shops.watchStock(shopId));
    await shops.removeStock(stockId);

    expect(await future, isEmpty);
  });

  test('mağaza oyunculara açılınca akış yenilenir', () async {
    final shops = ShopRepository(db);
    final id = await shops.create(name: 'Demirci');

    final future = secondEmission(shops.watchShops());
    await shops.openOnly(id);

    expect((await future).single.openToPlayers, isTrue);
  });

  test('karşılaşma silinince listeden düşer', () async {
    final combat = CombatRepository(db);
    final id = await combat.createEncounter('Mağara');

    final future = secondEmission(combat.watchEncounters());
    await combat.deleteEncounter(id);

    expect(await future, isEmpty);
  });

  test('lokasyon silinince kök listesinden düşer', () async {
    final world = WorldRepository(db);
    final id = await world.createLocation(name: 'Şehir');

    final future = secondEmission(world.watchRoots());
    await world.deleteLocation(id);

    expect(await future, isEmpty);
  });

  test('NPC silinince listeden düşer', () async {
    final world = WorldRepository(db);
    final id = await world.createNpc(name: 'Gundren');

    final future = secondEmission(world.watchNpcs());
    await world.deleteNpc(id);

    expect(await future, isEmpty);
  });
}
