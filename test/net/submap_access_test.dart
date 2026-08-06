import 'dart:io';

import 'package:dm_table/data/character_repository.dart';
import 'package:dm_table/data/combat_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/db/world_tables.dart';
import 'package:dm_table/data/map_image_store.dart';
import 'package:dm_table/data/shop_repository.dart';
import 'package:dm_table/data/world_repository.dart';
import 'package:dm_table/features/session/session_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// Gorunurluk artik lokasyon bazli (revealed): oyuncu, DM'in "Oyunculara göster"
/// yaptigi haritali yerleri gorur. Haritadan erisilebilir dukkanlarin
/// shop-pinleri de tiklanabilir gelir.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late WorldRepository world;
  late ShopRepository shops;
  late SessionService session;
  late Directory tempDir;

  late String parentId;
  late String openChildId; // revealed + haritali -> gorunur
  late String hiddenChildId; // revealed degil -> gizli
  late String openShopId; // mapAccessible -> tiklanabilir
  late String closedShopId; // mapAccessible degil -> tiklanamaz

  Future<void> giveMap(String locationId, String tag) async {
    final source = File(p.join(tempDir.path, '$tag.png'));
    final image = img.Image(width: 800, height: 600);
    img.fill(image, color: img.ColorRgb8(30, 40, 50));
    await source.writeAsBytes(img.encodePng(image));
    await world.setMapImage(locationId, source);
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('dm_masasi_submap');
    world = WorldRepository(
      db,
      images: MapImageStore(directoryOverride: tempDir),
    );
    shops = ShopRepository(db);

    session = SessionService(
      db: db,
      characters: CharacterRepository(db),
      combat: CombatRepository(db),
      shops: shops,
      world: world,
    );

    parentId = await world.createLocation(name: 'Kale');
    openChildId = await world.createLocation(
      name: 'Zindan',
      parentId: parentId,
    );
    hiddenChildId = await world.createLocation(
      name: 'Gizli Oda',
      parentId: parentId,
    );

    await giveMap(parentId, 'kale');
    await giveMap(openChildId, 'zindan');
    await giveMap(hiddenChildId, 'gizli');

    // Gorunurluk: Kale + Zindan acik, Gizli Oda kapali.
    await world.updateLocation(parentId, revealed: true);
    await world.updateLocation(openChildId, revealed: true);

    // Dukkanlar.
    openShopId = await shops.create(name: 'Demirci');
    closedShopId = await shops.create(name: 'Gizli Pazar');
    await shops.update(openShopId, mapAccessible: true);

    // Kale haritasindaki acilmis pinler.
    final toChild = await world.addPin(
      locationId: parentId,
      kind: PinKind.location,
      label: 'Zindan girişi',
      x: 0.3,
      y: 0.4,
      targetId: openChildId,
    );
    final toOpenShop = await world.addPin(
      locationId: parentId,
      kind: PinKind.shop,
      label: 'Demirci',
      x: 0.5,
      y: 0.5,
      targetId: openShopId,
    );
    final toClosedShop = await world.addPin(
      locationId: parentId,
      kind: PinKind.shop,
      label: 'Pazar',
      x: 0.6,
      y: 0.6,
      targetId: closedShopId,
    );
    for (final id in [toChild, toOpenShop, toClosedShop]) {
      await world.updatePin(id, revealed: true);
    }
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('gorunur haritalar: Kale + Zindan; Gizli Oda haric', () async {
    final snapshot = await session.buildSnapshot();
    final ids = snapshot.maps.map((m) => m.locationId).toSet();
    expect(ids, contains(parentId));
    expect(ids, contains(openChildId));
    expect(ids, isNot(contains(hiddenChildId)));
  });

  test('parentLocationId ile agac cikarilir', () async {
    final snapshot = await session.buildSnapshot();
    final parent = snapshot.maps.firstWhere((m) => m.locationId == parentId);
    final child = snapshot.maps.firstWhere((m) => m.locationId == openChildId);
    expect(parent.parentLocationId, isNull);
    expect(child.parentLocationId, parentId);
  });

  test('location-pin gorunur cocuga girilebilir', () async {
    final snapshot = await session.buildSnapshot();
    final parent = snapshot.maps.firstWhere((m) => m.locationId == parentId);
    final pin = parent.pins.firstWhere((p) => p.label == 'Zindan girişi');
    expect(pin.targetLocationId, openChildId);
  });

  test('shop-pin yalnizca haritadan erisilebilir dukkani acar', () async {
    final snapshot = await session.buildSnapshot();
    final parent = snapshot.maps.firstWhere((m) => m.locationId == parentId);
    final open = parent.pins.firstWhere((p) => p.label == 'Demirci');
    expect(open.targetShopId, openShopId);
    // Erisilemeyen dukkanin pini HIC gelmez.
    expect(parent.pins.any((p) => p.label == 'Pazar'), isFalse);
    // mapShops yalnizca erisilebilir dukkani tasir.
    expect(snapshot.mapShops.map((s) => s.id), contains(openShopId));
    expect(snapshot.mapShops.map((s) => s.id), isNot(contains(closedShopId)));
  });

  test('gizli haritanin gorseli hicbir yerde referans edilmez', () async {
    final snapshot = await session.buildSnapshot();
    final hidden = await world.find(hiddenChildId);
    final hiddenBasename = p.basename(hidden!.mapPreviewPath!);
    final allUrls = [
      for (final m in snapshot.maps) m.imageUrl,
    ].whereType<String>();
    expect(allUrls.any((u) => u.contains(hiddenBasename)), isFalse);
  });

  test('DM görünürlüğü geri alinca harita listeden cikar', () async {
    await world.updateLocation(openChildId, revealed: false);
    final snapshot = await session.buildSnapshot();
    final ids = snapshot.maps.map((m) => m.locationId).toSet();
    expect(ids, isNot(contains(openChildId)));
    // Parent'taki location-pin artik HIC gelmez (hedef erisilemez).
    final parent = snapshot.maps.firstWhere((m) => m.locationId == parentId);
    expect(parent.pins.any((p) => p.label == 'Zindan girişi'), isFalse);
  });

  test('ust yer gizliyken alt yer gorunur bile olsa gozukmez', () async {
    // Zindan gorunur ama Kale gizli -> zincir kopuk, Zindan da gozukmez.
    await world.updateLocation(parentId, revealed: false);
    final snapshot = await session.buildSnapshot();
    final ids = snapshot.maps.map((m) => m.locationId).toSet();
    expect(ids, isNot(contains(parentId)));
    expect(ids, isNot(contains(openChildId)));
  });

  test('setRevealed yeri acinca pinlerini de gorunur yapar', () async {
    // Kale'ye acilmamis bir not pini ekle.
    await world.addPin(
      locationId: parentId,
      kind: PinKind.note,
      label: 'Uyarı',
      x: 0.1,
      y: 0.1,
      noteText: 'Dikkat.',
    );
    await world.setRevealed(parentId, true);
    final snapshot = await session.buildSnapshot();
    final parent = snapshot.maps.firstWhere((m) => m.locationId == parentId);
    expect(parent.pins.any((p) => p.label == 'Uyarı'), isTrue);
  });
}
