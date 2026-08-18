import 'dart:convert';
import 'dart:io';

import 'package:dm_table/data/character_image_store.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/db/world_tables.dart';
import 'package:dm_table/data/loot_repository.dart';
import 'package:dm_table/data/map_image_store.dart';
import 'package:dm_table/data/shop_repository.dart';
import 'package:dm_table/data/world_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// Dunya agaci: ic ice lokasyonlar, pinler, harita gorselleri ve bilgi
/// agacinin geri referanslari.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late WorldRepository world;
  late Directory tempDir;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('dm_masasi_maps');
    world = WorldRepository(
      db,
      images: MapImageStore(directoryOverride: tempDir),
      portraits: CharacterImageStore(directoryOverride: tempDir),
    );
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('lokasyon agaci', () {
    test('ic ice lokasyon kurulabilir', () async {
      final kingdom = await world.createLocation(name: 'Krallık');
      final city = await world.createLocation(name: 'Şehir', parentId: kingdom);
      final inn = await world.createLocation(name: 'Han', parentId: city);

      expect((await world.children(kingdom)).single.id, city);
      expect((await world.children(city)).single.id, inn);
      expect((await world.find(inn))!.parentId, city);
    });

    test('ekmek kirintisi kokten yaprak dogru siralanir', () async {
      final kingdom = await world.createLocation(name: 'Krallık');
      final city = await world.createLocation(name: 'Şehir', parentId: kingdom);
      final inn = await world.createLocation(name: 'Han', parentId: city);

      final trail = await world.breadcrumb(inn);
      expect(trail.map((l) => l.name), ['Krallık', 'Şehir', 'Han']);
    });

    test('silinen lokasyonun tum alt agaci gider', () async {
      final kingdom = await world.createLocation(name: 'Krallık');
      final city = await world.createLocation(name: 'Şehir', parentId: kingdom);
      await world.createLocation(name: 'Han', parentId: city);
      await world.createLocation(name: 'Bodrum', parentId: city);

      await world.deleteLocation(city);

      expect(await world.find(city), isNull);
      expect(await world.children(kingdom), isEmpty);
      // Kok ayakta kalmali.
      expect(await world.find(kingdom), isNotNull);
      expect((await db.select(db.locations).get()).length, 1);
    });

    test('silinen lokasyona isaret eden pinler de temizlenir', () async {
      final region = await world.createLocation(name: 'Bölge');
      final cave = await world.createLocation(name: 'Mağara', parentId: region);
      await world.addPin(
        locationId: region,
        kind: PinKind.location,
        label: 'Mağara girişi',
        x: 0.5,
        y: 0.5,
        targetId: cave,
      );

      await world.deleteLocation(cave);

      expect(await world.pins(region), isEmpty);
    });
  });

  group('pinler', () {
    late String locationId;

    setUp(() async {
      locationId = await world.createLocation(name: 'Şehir');
    });

    test('oran olarak saklanir', () async {
      await world.addPin(
        locationId: locationId,
        kind: PinKind.note,
        label: 'Kuyu',
        x: 0.25,
        y: 0.75,
        noteText: 'Dibinde bir şey var.',
      );

      final pin = (await world.pins(locationId)).single;
      expect(pin.x, 0.25);
      expect(pin.y, 0.75);
      expect(pin.noteText, 'Dibinde bir şey var.');
      // Pinler varsayilan olarak oyunculara kapali.
      expect(pin.revealed, isFalse);
    });

    test('tasinabilir ve acilabilir', () async {
      final id = await world.addPin(
        locationId: locationId,
        kind: PinKind.note,
        label: 'Kuyu',
        x: 0.1,
        y: 0.1,
      );

      await world.updatePin(id, x: 0.6, y: 0.4, revealed: true);
      final pin = (await world.pins(locationId)).single;
      expect(pin.x, 0.6);
      expect(pin.y, 0.4);
      expect(pin.revealed, isTrue);
    });

    test('alt lokasyon pini hedefini cozer', () async {
      final cave = await world.createLocation(
        name: 'Mağara',
        parentId: locationId,
        description: 'Karanlık',
      );
      await world.addPin(
        locationId: locationId,
        kind: PinKind.location,
        label: 'Giriş',
        x: 0.5,
        y: 0.5,
        targetId: cave,
      );

      final target = await world.resolveTarget(
        (await world.pins(locationId)).single,
      );
      expect(target!.label, 'Mağara');
      expect(target.subtitle, 'Karanlık');
    });

    test('magaza pini hedefini cozer', () async {
      final shops = ShopRepository(db);
      final shopId = await shops.create(name: 'Demirci', ownerName: 'Gundren');
      await world.addPin(
        locationId: locationId,
        kind: PinKind.shop,
        label: 'Demirci',
        x: 0.3,
        y: 0.3,
        targetId: shopId,
      );

      final target = await world.resolveTarget(
        (await world.pins(locationId)).single,
      );
      expect(target!.label, 'Demirci');
      expect(target.subtitle, 'Gundren');
    });

    test('hedefi silinmis pin null doner, cokmez', () async {
      await world.addPin(
        locationId: locationId,
        kind: PinKind.npc,
        label: 'Kayıp NPC',
        x: 0.2,
        y: 0.2,
        targetId: 'npc-yok',
      );

      expect(
        await world.resolveTarget((await world.pins(locationId)).single),
        isNull,
      );
    });
  });

  group('hazine pini ganimeti', () {
    late String locationId;

    setUp(() async {
      locationId = await world.createLocation(name: 'Mağara');
    });

    /// Hazinenin lootDataJson'unu elle kurgular ve hazine pini yaratir.
    Future<String> addTreasurePin({
      int coinsCp = 100,
      List<Map<String, dynamic>> items = const [
        {'id': 'it-1', 'name': 'Kılıç', 'magic': false},
        {'id': 'it-2', 'name': '+1 Kalkan', 'magic': true},
      ],
    }) => world.addPin(
      locationId: locationId,
      kind: PinKind.treasure,
      label: 'Hazine',
      x: 0.5,
      y: 0.5,
      lootSetId: 'loot-set-1',
      lootDataJson: jsonEncode({'coinsCp': coinsCp, 'items': items}),
    );

    test('esya alininca kalan veri guncellenir', () async {
      final id = await addTreasurePin();
      final result = await world.takeTreasureLoot(id, itemId: 'it-1');
      expect(result.error, isNull);
      expect(result.deleted, isFalse);
      expect(result.takenName, 'Kılıç');

      final pin = (await world.pins(locationId)).single;
      final data = jsonDecode(pin.lootDataJson!) as Map<String, dynamic>;
      expect(data['coinsCp'], 100);
      final items = data['items'] as List;
      expect(items.length, 1);
      expect((items.single as Map)['id'], 'it-2');
    });

    test('son esya alininca pin silinir', () async {
      final id = await addTreasurePin(
        coinsCp: 0,
        items: const [
          {'id': 'it-1', 'name': 'Tek eşya', 'magic': false},
        ],
      );
      final result = await world.takeTreasureLoot(id, itemId: 'it-1');
      expect(result.error, isNull);
      expect(result.deleted, isTrue);
      expect(await world.pins(locationId), isEmpty);
    });

    test('alinmis esya tekrar alinamaz (dupelenmez)', () async {
      final id = await addTreasurePin();
      await world.takeTreasureLoot(id, itemId: 'it-1');
      final again = await world.takeTreasureLoot(id, itemId: 'it-1');
      expect(again.error, 'itemGone');
      // Pin hala duruyor, ikinci esya yerinde.
      final pin = (await world.pins(locationId)).single;
      final items = (jsonDecode(pin.lootDataJson!) as Map)['items'] as List;
      expect(items.length, 1);
    });

    test('para alininca sifirlanir; kalan esya varsa pin durur', () async {
      final id = await addTreasurePin();
      final result = await world.takeTreasureLoot(id);
      expect(result.error, isNull);
      expect(result.takenCoinsCp, 100);
      expect(result.deleted, isFalse);

      final pin = (await world.pins(locationId)).single;
      final data = jsonDecode(pin.lootDataJson!) as Map<String, dynamic>;
      expect(data['coinsCp'], 0);
      expect((data['items'] as List).length, 2);
    });

    test('para yoksa noMoneyLeft', () async {
      final id = await addTreasurePin(coinsCp: 0);
      final result = await world.takeTreasureLoot(id);
      expect(result.error, 'noMoneyLeft');
    });

    test('var olmayan pin icin noPin', () async {
      final result = await world.takeTreasureLoot('pin-yok', itemId: 'it-1');
      expect(result.error, 'noPin');
    });

    test('takeAll hepsini alir ve pini siler', () async {
      final id = await addTreasurePin(coinsCp: 50);
      final result = await world.takeAllTreasureLoot(id);
      expect(result.error, isNull);
      expect(result.coinsCp, 50);
      expect(result.items.length, 2);
      expect(result.items.first.name, 'Kılıç');
      expect(await world.pins(locationId), isEmpty);
    });

    test('treasure pinin hedefi loot setinin adini cozer', () async {
      final repo = LootRepository(db);
      final setId = await repo.create('Ejderha inine hazine');
      await repo.update(
        setId,
        coinsCp: 10,
        items: const [(name: 'Altın kupa', magic: false)],
      );
      final set = (await repo.find(setId))!;
      await world.addPin(
        locationId: locationId,
        kind: PinKind.treasure,
        label: 'Hazine',
        x: 0.5,
        y: 0.5,
        lootSetId: setId,
        lootDataJson: LootRepository.initialPinLoot(set),
      );

      final target = await world.resolveTarget(
        (await world.pins(locationId)).single,
      );
      expect(target!.label, 'Ejderha inine hazine');
    });
  });

  group('bilgi agaci', () {
    test('bir NPC birden fazla yerde geciyorsa hepsi listelenir', () async {
      final npcId = await world.createNpc(name: 'Gundren', role: 'Demirci');
      final city = await world.createLocation(name: 'Şehir');
      final village = await world.createLocation(name: 'Köy');

      await world.addPin(
        locationId: city,
        kind: PinKind.npc,
        label: 'Dükkânı',
        x: 0.4,
        y: 0.4,
        targetId: npcId,
      );
      await world.addPin(
        locationId: village,
        kind: PinKind.npc,
        label: 'Evi',
        x: 0.2,
        y: 0.8,
        targetId: npcId,
      );

      final links = await world.backlinks(npcId);
      expect(links.length, 2);
      expect(links.map((l) => l.locationName), containsAll(['Şehir', 'Köy']));
      expect(links.map((l) => l.pinLabel), containsAll(['Dükkânı', 'Evi']));
    });

    test('NPC silinince ona isaret eden pinler de silinir', () async {
      final npcId = await world.createNpc(name: 'Gundren');
      final city = await world.createLocation(name: 'Şehir');
      await world.addPin(
        locationId: city,
        kind: PinKind.npc,
        label: 'Dükkânı',
        x: 0.4,
        y: 0.4,
        targetId: npcId,
      );

      await world.deleteNpc(npcId);

      expect(await world.pins(city), isEmpty);
      expect(await world.backlinks(npcId), isEmpty);
    });
  });

  group('harita gorseli', () {
    /// Gecici bir PNG uretir.
    Future<File> makeImage(int width, int height) async {
      final image = img.Image(width: width, height: height);
      img.fill(image, color: img.ColorRgb8(120, 90, 60));
      final file = File(p.join(tempDir.path, 'source-$width-$height.png'));
      await file.writeAsBytes(img.encodePng(image));
      return file;
    }

    test('kaydedilir, olculeri ve onizlemesi uretilir', () async {
      final locationId = await world.createLocation(name: 'Şehir');
      await world.setMapImage(locationId, await makeImage(2400, 1200));

      final location = (await world.find(locationId))!;
      expect(location.mapWidth, 2400);
      expect(location.mapHeight, 1200);
      expect(location.mapImagePath, isNotNull);
      expect(location.mapPreviewPath, isNotNull);

      // Yollar goreli olmali; mutlak yol Android'de kurulumdan sonra bozulur.
      expect(p.isAbsolute(location.mapImagePath!), isFalse);

      final preview = await world.images.resolve(location.mapPreviewPath!);
      expect(preview.existsSync(), isTrue);

      final decoded = img.decodeImage(await preview.readAsBytes())!;
      expect(decoded.width, MapImageStore.previewMaxSide);
      expect(decoded.height, 800, reason: 'en-boy oranı korunmalı');
    });

    test('kucuk gorsel buyutulmez', () async {
      final locationId = await world.createLocation(name: 'Oda');
      await world.setMapImage(locationId, await makeImage(400, 300));

      final location = (await world.find(locationId))!;
      final preview = await world.images.resolve(location.mapPreviewPath!);
      final decoded = img.decodeImage(await preview.readAsBytes())!;
      expect(decoded.width, 400);
    });

    test('harita degistirilince eski dosyalar silinir', () async {
      final locationId = await world.createLocation(name: 'Şehir');
      await world.setMapImage(locationId, await makeImage(800, 600));
      final first = (await world.find(locationId))!;
      final oldFile = await world.images.resolve(first.mapImagePath!);

      await world.setMapImage(locationId, await makeImage(1000, 800));

      expect(oldFile.existsSync(), isFalse, reason: 'eski harita kalmamalı');
      final second = (await world.find(locationId))!;
      expect(second.mapWidth, 1000);
      expect(
        (await world.images.resolve(second.mapImagePath!)).existsSync(),
        isTrue,
      );
    });

    test('lokasyon silinince harita dosyalari da gider', () async {
      final locationId = await world.createLocation(name: 'Şehir');
      await world.setMapImage(locationId, await makeImage(600, 400));
      final location = (await world.find(locationId))!;
      final file = await world.images.resolve(location.mapImagePath!);

      await world.deleteLocation(locationId);

      expect(file.existsSync(), isFalse);
    });

    test('bozuk dosya anlamli hata verir', () async {
      final locationId = await world.createLocation(name: 'Şehir');
      final broken = File(p.join(tempDir.path, 'broken.png'));
      await broken.writeAsString('bu bir görsel değil');

      expect(
        () => world.setMapImage(locationId, broken),
        throwsA(isA<FormatException>()),
      );
    });

    group('mil olcegi', () {
      test('setMapScale iki degeri de yazar', () async {
        final id = await world.createLocation(name: 'Kıta');
        await world.setMapScale(id, widthMiles: 1200, heightMiles: 600);

        final row = (await world.find(id))!;
        expect(row.mapWidthMiles, 1200);
        expect(row.mapHeightMiles, 600);
      });

      test('setMapScale null ile olcegi TEMIZLER', () async {
        // updateLocation'in null'i "degistirme" saydigi icin ayri metot var;
        // burada temizlemenin gercekten calistigi kilitleniyor.
        final id = await world.createLocation(name: 'Kıta');
        await world.setMapScale(id, widthMiles: 1200, heightMiles: 600);
        await world.setMapScale(id, widthMiles: null, heightMiles: null);

        final row = (await world.find(id))!;
        expect(row.mapWidthMiles, isNull);
        expect(row.mapHeightMiles, isNull);
      });

      test('yalnizca genislik yazilabilir (yukseklik turetilecek)', () async {
        final id = await world.createLocation(name: 'Kıta');
        await world.setMapScale(id, widthMiles: 500, heightMiles: null);

        final row = (await world.find(id))!;
        expect(row.mapWidthMiles, 500);
        expect(row.mapHeightMiles, isNull);
      });

      test('harita gorseli kaldirilinca olcek de gider', () async {
        final id = await world.createLocation(name: 'Şehir');
        await world.setMapImage(id, await makeImage(800, 400));
        await world.setMapScale(id, widthMiles: 100, heightMiles: 50);

        await world.removeMapImage(id);

        final row = (await world.find(id))!;
        expect(row.mapWidthMiles, isNull, reason: 'haritasız ölçek erişilemez');
        expect(row.mapHeightMiles, isNull);
      });

      test('harita gorseli degisince olcek KORUNUR', () async {
        // Ayni bolgenin daha iyi bir taramasi yuklenebilir; olcek degismez.
        final id = await world.createLocation(name: 'Şehir');
        await world.setMapImage(id, await makeImage(800, 400));
        await world.setMapScale(id, widthMiles: 100, heightMiles: 50);

        await world.setMapImage(id, await makeImage(1600, 800));

        final row = (await world.find(id))!;
        expect(row.mapWidthMiles, 100);
        expect(row.mapHeightMiles, 50);
      });
    });
  });

  group('dunya grafigi', () {
    test('createLink cift yonlu ve tekrarli eklemez', () async {
      final a = await world.createLocation(name: 'A');
      final b = await world.createLocation(name: 'B');
      await world.createLink(a, b);
      await world.createLink(a, b); // ayni
      await world.createLink(b, a); // ters
      expect((await world.watchLinks().first).length, 1);
    });

    test('createLink kendine baglanmaz', () async {
      final a = await world.createLocation(name: 'A');
      await world.createLink(a, a);
      expect(await world.watchLinks().first, isEmpty);
    });

    test('deleteLink baglantiyi siler', () async {
      final a = await world.createLocation(name: 'A');
      final b = await world.createLocation(name: 'B');
      await world.createLink(a, b);
      final link = (await world.watchLinks().first).single;
      await world.deleteLink(link.id);
      expect(await world.watchLinks().first, isEmpty);
    });

    test('lokasyon silinince baglantilari da kalkar', () async {
      final a = await world.createLocation(name: 'A');
      final b = await world.createLocation(name: 'B');
      await world.createLink(a, b);
      await world.deleteLocation(a);
      expect(await world.watchLinks().first, isEmpty);
    });

    test('setGraphPosition ve saveGraphPositions konumu yazar', () async {
      final a = await world.createLocation(name: 'A');
      await world.setGraphPosition(a, 12.5, -7.0);
      var loc = await world.find(a);
      expect(loc!.graphX, 12.5);
      expect(loc.graphY, -7.0);

      final b = await world.createLocation(name: 'B');
      await world.saveGraphPositions([
        (id: a, x: 1.0, y: 2.0),
        (id: b, x: 3.0, y: 4.0),
      ]);
      expect((await world.find(a))!.graphX, 1.0);
      expect((await world.find(b))!.graphY, 4.0);
    });

    test('createLink kind + tip yazar, tekrar cift tipi gunceller', () async {
      final loc = await world.createLocation(name: 'Şehir');
      final npc = await world.createNpc(name: 'Bruna');
      await world.createLink(
        loc,
        npc,
        xKind: 'location',
        yKind: 'npc',
        type: 'trade',
      );
      var link = (await world.watchLinks().first).single;
      expect(link.aKind, 'location');
      expect(link.bKind, 'npc');
      expect(link.type, 'trade');

      // Ayni cift (ters sirada) → yeni satir degil, tip guncellenir.
      await world.createLink(npc, loc, type: 'enmity');
      final links = await world.watchLinks().first;
      expect(links.length, 1);
      expect(links.single.type, 'enmity');
    });

    test('updateLinkType tipi degistirir', () async {
      final a = await world.createLocation(name: 'A');
      final b = await world.createLocation(name: 'B');
      await world.createLink(a, b, type: 'road');
      final link = (await world.watchLinks().first).single;
      await world.updateLinkType(link.id, 'alliance');
      expect((await world.watchLinks().first).single.type, 'alliance');
    });

    test('NPC silinince baglantilari da kalkar', () async {
      final loc = await world.createLocation(name: 'Şehir');
      final npc = await world.createNpc(name: 'Bruna');
      await world.createLink(loc, npc, yKind: 'npc');
      await world.deleteNpc(npc);
      expect(await world.watchLinks().first, isEmpty);
    });
  });

  group('zengin NPC', () {
    test('tum alanlar kaydedilir ve okunur', () async {
      final id = await world.createNpc(
        name: 'Bruna',
        role: 'demirci',
        race: 'cüce',
        gender: 'kadın',
        age: 'yaşlı',
        alignment: 'Yasal İyi',
        appearance: 'kalın kollar',
        personality: 'aksi',
        ideal: 'ustalık',
        bond: 'çırağı',
        flaw: 'inatçı',
        hook: 'nadir cevher',
        secretNotes: 'kaçak prens',
      );
      final npc = await world.findNpc(id);
      expect(npc!.race, 'cüce');
      expect(npc.alignment, 'Yasal İyi');
      expect(npc.ideal, 'ustalık');
      expect(npc.hook, 'nadir cevher');
      expect(npc.secretNotes, 'kaçak prens');

      await world.updateNpc(id, flaw: 'çok gururlu');
      expect((await world.findNpc(id))!.flaw, 'çok gururlu');
      // Dokunulmayan alan korunur.
      expect((await world.findNpc(id))!.ideal, 'ustalık');
    });

    test('NPC grafik konumu yazilir', () async {
      final id = await world.createNpc(name: 'X');
      await world.setNpcGraphPosition(id, 5.0, 6.0);
      expect((await world.findNpc(id))!.graphX, 5.0);
      await world.saveNpcGraphPositions([(id: id, x: 9.0, y: 8.0)]);
      expect((await world.findNpc(id))!.graphY, 8.0);
    });

    test('portre yuklenir, kaldirilinca dosya silinir', () async {
      final id = await world.createNpc(name: 'Portreli');
      final image = img.Image(width: 200, height: 200);
      img.fill(image, color: img.ColorRgb8(30, 120, 180));
      final src = File(p.join(tempDir.path, 'npc.png'));
      await src.writeAsBytes(img.encodePng(image));

      await world.setNpcPortrait(id, src);
      final stored = (await world.findNpc(id))!.portraitPath;
      expect(stored, isNotNull);
      final file = await world.portraits.resolve(stored!);
      expect(file.existsSync(), isTrue);

      await world.removeNpcPortrait(id);
      expect((await world.findNpc(id))!.portraitPath, isNull);
      expect(file.existsSync(), isFalse);
    });
  });

  group('bag turleri', () {
    test('ensureDefaults tohumlar, ikinci cagri tekrar eklemez', () async {
      const defaults = [
        (code: 'road', name: 'Yol', color: 0xFF9DB0DA, sort: 0),
        (code: 'enmity', name: 'Düşmanlık', color: 0xFFEF5350, sort: 1),
      ];
      await world.ensureDefaultBondTypes(defaults);
      expect((await world.watchBondTypes().first).length, 2);
      // Kullanici birini yeniden adlandirsa bile tekrar tohumlanmaz.
      await world.upsertBondType(
        code: 'road',
        name: 'Patika',
        color: 0xFF111111,
      );
      await world.ensureDefaultBondTypes(defaults);
      final rows = await world.watchBondTypes().first;
      expect(rows.length, 2);
      expect(rows.firstWhere((b) => b.code == 'road').name, 'Patika');
    });

    test('silinen varsayilan tur bir daha tohumlanmaz', () async {
      const defaults = [
        (code: 'road', name: 'Yol', color: 0xFF9DB0DA, sort: 0),
        (code: 'enmity', name: 'Düşmanlık', color: 0xFFEF5350, sort: 1),
      ];
      await world.ensureDefaultBondTypes(defaults);
      await world.deleteBondType('road');

      // Dunya grafigi sayfasi her acildiginda bunu tekrar cagiriyor; silinen
      // tur "eksik" sayilip geri gelmemeli.
      await world.ensureDefaultBondTypes(defaults);
      await world.ensureDefaultBondTypes(defaults);

      final rows = await world.watchBondTypes().first;
      expect(rows.map((b) => b.code), ['enmity']);
    });

    test('upsert ekler ve gunceller, delete siler', () async {
      await world.upsertBondType(code: 'x', name: 'Yeni', color: 0xFF00FF00);
      var row = (await world.watchBondTypes().first).single;
      expect(row.name, 'Yeni');
      expect(row.color, 0xFF00FF00);

      await world.upsertBondType(code: 'x', name: 'Değişti', color: 0xFF0000FF);
      row = (await world.watchBondTypes().first).single;
      expect(row.name, 'Değişti');
      expect(row.color, 0xFF0000FF);

      await world.deleteBondType('x');
      expect(await world.watchBondTypes().first, isEmpty);
    });
  });

  group('haritasiz yer (place) pini', () {
    test('arkasindaki lokasyon TUM lokasyon listesinde gozukur', () async {
      final bolge = await world.createLocation(name: 'Bölge');
      // Haritasiz yer: kendi Locations kaydi var ama harita gorseli yok.
      final harabe = await world.createLocation(
        name: 'Yıkık Değirmen',
        parentId: bolge,
        description: 'Görev için işaret',
      );
      await world.addPin(
        locationId: bolge,
        kind: PinKind.place,
        label: 'Yıkık Değirmen',
        x: 0.4,
        y: 0.6,
        targetId: harabe,
        noteText: 'Görev için işaret',
      );

      // Gorev/seyahat seciciler bu akisi okuyor.
      final all = await world.watchAllLocations().first;
      final found = all.firstWhere((l) => l.id == harabe);
      expect(found.name, 'Yıkık Değirmen');
      expect(found.mapImagePath, isNull, reason: 'haritasi olmamali');
    });

    test('resolveTarget yerin adini ve aciklamasini doner', () async {
      final bolge = await world.createLocation(name: 'Bölge');
      final harabe = await world.createLocation(
        name: 'Yıkık Değirmen',
        parentId: bolge,
        description: 'Kurtlar burada toplanıyor',
      );
      await world.addPin(
        locationId: bolge,
        kind: PinKind.place,
        label: 'Yıkık Değirmen',
        x: 0.4,
        y: 0.6,
        targetId: harabe,
      );

      final pin = (await world.pins(bolge)).single;
      final target = await world.resolveTarget(pin);
      expect(target?.label, 'Yıkık Değirmen');
      expect(target?.subtitle, 'Kurtlar burada toplanıyor');
    });

    test('pin silinince arkasindaki lokasyon DA silinir', () async {
      final bolge = await world.createLocation(name: 'Bölge');
      final harabe = await world.createLocation(
        name: 'Yıkık Değirmen',
        parentId: bolge,
      );
      await world.addPin(
        locationId: bolge,
        kind: PinKind.place,
        label: 'Yıkık Değirmen',
        x: 0.4,
        y: 0.6,
        targetId: harabe,
      );

      await world.deletePin((await world.pins(bolge)).single.id);

      expect(
        await world.find(harabe),
        isNull,
        reason: 'yer kaydi pine ait; pin gidince o da gitmeli',
      );
    });

    test('alt yer pini silinince hedef lokasyon KALIR', () async {
      // Karsit durum: `location` pini VAR OLAN bir yeri isaret eder, o yer
      // pinden bagimsiz yasar. Silme mantigi yalnizca `place`e ozel olmali.
      final bolge = await world.createLocation(name: 'Bölge');
      final sehir = await world.createLocation(name: 'Şehir', parentId: bolge);
      await world.addPin(
        locationId: bolge,
        kind: PinKind.location,
        label: 'Şehir',
        x: 0.2,
        y: 0.2,
        targetId: sehir,
      );

      await world.deletePin((await world.pins(bolge)).single.id);

      expect(await world.find(sehir), isNotNull);
    });

    test(
      'lokasyon silinince place pini de silinir (sarkitta kalmaz)',
      () async {
        final bolge = await world.createLocation(name: 'Bölge');
        final harabe = await world.createLocation(
          name: 'Yıkık Değirmen',
          parentId: bolge,
        );
        await world.addPin(
          locationId: bolge,
          kind: PinKind.place,
          label: 'Yıkık Değirmen',
          x: 0.4,
          y: 0.6,
          targetId: harabe,
        );
        expect(await world.pins(bolge), hasLength(1));

        await world.deleteLocation(harabe);

        expect(
          await world.pins(bolge),
          isEmpty,
          reason: 'hedefi silinen place pini kalmamali',
        );
      },
    );
  });
}
