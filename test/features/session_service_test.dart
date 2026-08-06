import 'dart:convert';
import 'dart:io';

import 'package:dm_table/data/character_repository.dart';
import 'package:dm_table/data/combat_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/map_image_store.dart';
import 'package:dm_table/data/shop_repository.dart';
import 'package:dm_table/data/db/world_tables.dart';
import 'package:dm_table/data/world_repository.dart';
import 'package:dm_table/data/import/asset_importer.dart';
import 'package:dm_table/domain/models/ability.dart';
import 'package:dm_table/features/session/session_service.dart';
import 'package:dm_table/net/protocol.dart';
import 'package:dm_table/net/table_server.dart' show ConnectedPlayer;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// Oturum servisi: oyunculara ne gonderildigi ve kimin neyi degistirebildigi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SessionService session;
  late CharacterRepository characters;
  late CombatRepository combat;
  late ShopRepository shops;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await AssetImporter(db).importIfNeeded();
    characters = CharacterRepository(db);
    combat = CombatRepository(db);
    shops = ShopRepository(db);
    session = SessionService(
      db: db,
      characters: characters,
      combat: combat,
      shops: shops,
      world: WorldRepository(db),
    );

    await characters.createLevelOneCharacter(
      id: 'vex',
      name: 'Vex',
      classKey: 'srd-2024_wizard',
      abilities: const AbilityScores(constitution: 14, intelligence: 16),
      savingThrows: {Ability.intelligence, Ability.wisdom},
      skills: {Skill.arcana},
      hitDieSides: 6,
    );
  });

  tearDown(() async {
    await session.stop();
    await db.close();
  });

  test('snapshot karakteri hesaplanmis degerlerle tasir', () async {
    final snap = await session.buildSnapshot();
    final view = snap.characters.single;

    expect(view.name, 'Vex');
    expect(view.hitPointsMax, 8);
    expect(view.classLine, 'Wizard 1');
    // AC = 10 + DEX(0)
    expect(view.armorClass, 10);
    expect(view.abilityModifiers['INT'], 3);
    expect(view.savingThrows['INT'], 5); // +3 INT, +2 yeterlilik
    expect(view.skills['Arcana'], 5);
    expect(view.spellSlots, {1: 2});
  });

  group('kisa dinlenme', () {
    late ConnectedPlayer ali;

    setUp(() async {
      ali = ConnectedPlayer(token: 'a', name: 'Ali');
      await session.handleClientMessage(
        ali,
        const ClientMessage(
          type: ClientMessageType.claimCharacter,
          characterId: 'vex',
        ),
      );
      await characters.applyDamage('vex', 5);
    });

    const spend = ClientMessage(type: ClientMessageType.spendHitDie);

    test('DM acmadan oyuncu hit die harcayamaz', () async {
      final error = await session.handleClientMessage(ali, spend);

      expect(error, isNotNull);
      final status = await characters.hitDiceStatus('vex');
      expect(status.used, 0, reason: 'zar harcanmamali');
    });

    test('dinlenme acikken harcanir ve zar gunluge duser', () async {
      await session.setShortRest({'vex'});

      final error = await session.handleClientMessage(ali, spend);
      expect(error, isNull);

      expect((await characters.hitDiceStatus('vex')).used, 1);

      // Atis paylasilan gunluge oyuncunun adiyla duser: oyuncu panelindeki
      // "kendi atisim" pop-up'i (ve zar animasyonu) buna dayaniyor.
      final snap = await session.buildSnapshot();
      final roll = snap.rolls.last;
      expect(roll.source, 'Ali');
      expect(roll.sides, 6, reason: 'wizard hit die d6');
      expect(roll.results.single, inInclusiveRange(1, 6));
    });

    test('dinlenme kapatilinca yeniden harcanamaz', () async {
      await session.setShortRest({'vex'});
      await session.handleClientMessage(ali, spend);
      await session.setShortRest(const {});

      expect(await session.handleClientMessage(ali, spend), isNotNull);
      expect((await characters.hitDiceStatus('vex')).used, 1);
    });

    test('acik dinlenme snapshot ile oyuncuya bildirilir', () async {
      expect((await session.buildSnapshot()).shortRestCharacterIds, isEmpty);

      await session.setShortRest({'vex'});
      expect((await session.buildSnapshot()).shortRestCharacterIds, ['vex']);
    });

    test('snapshot hit dice sayacini tasir', () async {
      final view = (await session.buildSnapshot()).characters.single;
      expect(view.hitDiceTotal, 1);
      expect(view.hitDiceUsed, 0);
    });
  });

  group('sohbet', () {
    late ConnectedPlayer ali;

    setUp(() async {
      ali = ConnectedPlayer(token: 'a', name: 'Ali');
      // Ali 'vex'i sahiplensin; fısıltı hedefi olsun.
      await session.handleClientMessage(
        ali,
        const ClientMessage(
          type: ClientMessageType.claimCharacter,
          characterId: 'vex',
        ),
      );
    });

    test('DM-e ozel mesaji baska oyuncu GORMEZ', () async {
      final error = await session.handleClientMessage(
        ali,
        const ClientMessage(
          type: ClientMessageType.sendChat,
          chatText: 'DM, gizlice hazineyi ariyorum',
          toDm: true,
        ),
      );
      expect(error, isNull);

      // Gonderen oyuncu kendi mesajini gorur.
      final mine = await session.chatsFor('vex');
      expect(mine.single.text, 'DM, gizlice hazineyi ariyorum');
      expect(mine.single.toDm, isTrue);

      // Baska bir karakterin oyuncusu gormez.
      expect(await session.chatsFor('baska'), isEmpty);

      // DM her seyi gorur.
      expect(await session.chatsFor(null), hasLength(1));
    });

    test(
      'genel mesaj herkesin (ve DM\'in) gorebildigi listeye duser',
      () async {
        final error = await session.handleClientMessage(
          ali,
          const ClientMessage(
            type: ClientMessageType.sendChat,
            chatText: 'Selam',
          ),
        );
        expect(error, isNull);

        final msg = session.chats.single;
        expect(msg.text, 'Selam');
        expect(msg.fromName, 'Ali');
        expect(msg.fromCharacterId, 'vex');
        expect(msg.toCharacterId, isNull); // genel
        // DM (karakteri yok) ve masadaki herkes gorur.
        expect(await session.chatsFor(null), hasLength(1));
        expect(await session.chatsFor('vex'), hasLength(1));
        expect(await session.chatsFor('baska'), hasLength(1));
      },
    );

    test('bos mesaj sessizce yok sayilir', () async {
      final error = await session.handleClientMessage(
        ali,
        const ClientMessage(type: ClientMessageType.sendChat, chatText: '   '),
      );
      expect(error, isNull);
      expect(session.chats, isEmpty);
    });

    test('fisilti yalnizca hedef + gonderen + DM gorur', () async {
      final error = await session.handleClientMessage(
        ali,
        const ClientMessage(
          type: ClientMessageType.sendChat,
          chatText: 'Gizli',
          toCharacterId: 'vex',
        ),
      );
      expect(error, isNull);

      final msg = session.chats.single;
      expect(msg.isWhisper, isTrue);
      expect(msg.toCharacterId, 'vex');
      // Hedef + DM gorur; ilgisiz 'baska' gormez.
      expect(await session.chatsFor('vex'), hasLength(1));
      expect(await session.chatsFor(null), hasLength(1));
      expect(await session.chatsFor('baska'), isEmpty);
    });

    test('DM genel ve fisilti gonderebilir', () async {
      await session.sendChatAsDm('Merhaba', toCharacterId: 'vex');

      final msg = session.chats.single;
      expect(msg.isDm, isTrue);
      expect(msg.fromCharacterId, isNull);
      expect(msg.toCharacterId, 'vex');
      // Fisilti yalniz hedefe + DM'e gider; baska karaktere degil.
      expect(await session.chatsFor('vex'), hasLength(1));
      expect(await session.chatsFor('baska'), isEmpty);
    });
  });

  group('yetkilendirme', () {
    late ConnectedPlayer ali;
    late ConnectedPlayer veli;

    setUp(() {
      ali = ConnectedPlayer(token: 'a', name: 'Ali');
      veli = ConnectedPlayer(token: 'v', name: 'Veli');
    });

    test('karakter sahiplenmeden can degistirilemez', () async {
      final error = await session.handleClientMessage(
        ali,
        const ClientMessage(
          type: ClientMessageType.updateHitPoints,
          amount: -3,
        ),
      );
      expect(error, isNotNull);
      // Can degismemeli.
      expect((await characters.find('vex'))!.hitPointsCurrent, 8);
    });

    test('sahiplendikten sonra kendi canini degistirebilir', () async {
      await session.handleClientMessage(
        ali,
        const ClientMessage(
          type: ClientMessageType.claimCharacter,
          characterId: 'vex',
        ),
      );
      expect(ali.characterId, 'vex');

      final error = await session.handleClientMessage(
        ali,
        const ClientMessage(
          type: ClientMessageType.updateHitPoints,
          amount: -3,
        ),
      );
      expect(error, isNull);
      expect((await characters.find('vex'))!.hitPointsCurrent, 5);
    });

    test('baskasinin karakteri sahiplenilemez', () async {
      await session.handleClientMessage(
        ali,
        const ClientMessage(
          type: ClientMessageType.claimCharacter,
          characterId: 'vex',
        ),
      );

      final error = await session.handleClientMessage(
        veli,
        const ClientMessage(
          type: ClientMessageType.claimCharacter,
          characterId: 'vex',
        ),
      );
      expect(error, isNotNull);
      expect(error, contains('Ali'));
      expect(veli.characterId, isNull);
    });

    test('oyuncu karakter degistirince eskisi serbest kalir', () async {
      await characters.createLevelOneCharacter(
        id: 'pike',
        name: 'Pike',
        classKey: 'srd-2024_cleric',
        abilities: const AbilityScores(),
        savingThrows: const {},
        skills: const {},
        hitDieSides: 8,
      );

      await session.handleClientMessage(
        ali,
        const ClientMessage(
          type: ClientMessageType.claimCharacter,
          characterId: 'vex',
        ),
      );
      await session.handleClientMessage(
        ali,
        const ClientMessage(
          type: ClientMessageType.claimCharacter,
          characterId: 'pike',
        ),
      );

      // Vex artik bos: Veli alabilmeli.
      final error = await session.handleClientMessage(
        veli,
        const ClientMessage(
          type: ClientMessageType.claimCharacter,
          characterId: 'vex',
        ),
      );
      expect(error, isNull);
      expect(veli.characterId, 'vex');
      expect(ali.characterId, 'pike');
    });

    test('aktif savas yokken inisiyatif gonderilemez', () async {
      await session.handleClientMessage(
        ali,
        const ClientMessage(
          type: ClientMessageType.claimCharacter,
          characterId: 'vex',
        ),
      );
      final error = await session.handleClientMessage(
        ali,
        const ClientMessage(type: ClientMessageType.rollInitiative, amount: 15),
      );
      expect(error, isNotNull);
    });
  });

  group('alisveris', () {
    late ConnectedPlayer ali;
    late String shopId;
    late String stockId;

    setUp(() async {
      ali = ConnectedPlayer(token: 'a', name: 'Ali');
      await session.handleClientMessage(
        ali,
        const ClientMessage(
          type: ClientMessageType.claimCharacter,
          characterId: 'vex',
        ),
      );
      await characters.setCoins('vex', 10000); // 100 gp

      shopId = await shops.create(name: 'Demirci');
      final longsword = await (db.select(
        db.items,
      )..where((t) => t.name.equals('Longsword'))).getSingle();
      await shops.addItem(shopId: shopId, itemKey: longsword.key, quantity: 3);
      stockId = (await shops.entries(shopId)).single.stock.id;
    });

    test('kapali magaza snapshot\'a girmez', () async {
      expect((await session.buildSnapshot()).shop, isNull);
    });

    test('acik magaza oyuncuya gonderilir', () async {
      await shops.openOnly(shopId);

      final view = (await session.buildSnapshot()).shop!;
      expect(view.name, 'Demirci');
      expect(view.items.single.name, 'Longsword');
      expect(view.items.single.priceCp, 1500);
      expect(view.items.single.quantity, 3);
    });

    test('onay kapaliyken alim aninda uygulanir', () async {
      await shops.openOnly(shopId);
      await shops.update(shopId, requiresApproval: false);

      final error = await session.handleClientMessage(
        ali,
        ClientMessage(type: ClientMessageType.buyItem, stockId: stockId),
      );
      expect(error, isNull);
      expect((await characters.find('vex'))!.coinsCp, 8500);
      expect(session.pendingPurchases, isEmpty);
    });

    test('onay acikken kuyruga duser, para dokunulmaz', () async {
      await shops.openOnly(shopId);

      final error = await session.handleClientMessage(
        ali,
        ClientMessage(type: ClientMessageType.buyItem, stockId: stockId),
      );
      expect(error, isNull);

      expect(session.pendingPurchases.length, 1);
      final request = session.pendingPurchases.single;
      expect(request.itemName, 'Longsword');
      expect(request.totalCp, 1500);
      expect(request.characterName, 'Vex');

      // DM onaylamadan altin ve stok degismemeli.
      expect((await characters.find('vex'))!.coinsCp, 10000);
      expect((await shops.entries(shopId)).single.stock.quantity, 3);
    });

    test('DM onaylayinca alim tamamlanir', () async {
      await shops.openOnly(shopId);
      await session.handleClientMessage(
        ali,
        ClientMessage(type: ClientMessageType.buyItem, stockId: stockId),
      );

      final result = await session.approvePurchase(
        session.pendingPurchases.single.id,
      );

      expect(result, isA<PurchaseOk>());
      expect(session.pendingPurchases, isEmpty);
      expect((await characters.find('vex'))!.coinsCp, 8500);
      expect((await shops.entries(shopId)).single.stock.quantity, 2);
    });

    test('DM reddedince hicbir sey degismez', () async {
      await shops.openOnly(shopId);
      await session.handleClientMessage(
        ali,
        ClientMessage(type: ClientMessageType.buyItem, stockId: stockId),
      );

      await session.rejectPurchase(session.pendingPurchases.single.id);

      expect(session.pendingPurchases, isEmpty);
      expect((await characters.find('vex'))!.coinsCp, 10000);
      expect((await shops.entries(shopId)).single.stock.quantity, 3);
    });

    test('ayni istek iki kez kuyruga girmez', () async {
      await shops.openOnly(shopId);
      final message = ClientMessage(
        type: ClientMessageType.buyItem,
        stockId: stockId,
      );

      await session.handleClientMessage(ali, message);
      final second = await session.handleClientMessage(ali, message);

      expect(second, contains('alreadyPending'));
      expect(session.pendingPurchases.length, 1);
    });

    test('karakter sahiplenmeden alisveris yapilamaz', () async {
      await shops.openOnly(shopId);
      final veli = ConnectedPlayer(token: 'v', name: 'Veli');

      final error = await session.handleClientMessage(
        veli,
        ClientMessage(type: ClientMessageType.buyItem, stockId: stockId),
      );
      expect(error, isNotNull);
      expect(session.pendingPurchases, isEmpty);
    });

    test('magaza kapaliyken alim reddedilir', () async {
      final error = await session.handleClientMessage(
        ali,
        ClientMessage(type: ClientMessageType.buyItem, stockId: stockId),
      );
      expect(error, contains('noShopOpen'));
    });

    test('satin alinan esya envanterde gorunur', () async {
      await shops.openOnly(shopId);
      await shops.update(shopId, requiresApproval: false);
      await session.handleClientMessage(
        ali,
        ClientMessage(type: ClientMessageType.buyItem, stockId: stockId),
      );

      final view = (await session.buildSnapshot()).characters.single;
      expect(view.inventory.single.name, 'Longsword');
      expect(view.coinsCp, 8500);
    });

    test('haritadan erisilebilir acik magazadan alisveris yapilir', () async {
      // openToPlayers YOK, ama mapAccessible + kapali degil.
      await shops.update(shopId, mapAccessible: true, requiresApproval: false);

      final error = await session.handleClientMessage(
        ali,
        ClientMessage(type: ClientMessageType.buyItem, stockId: stockId),
      );
      expect(error, isNull);
      expect((await characters.find('vex'))!.coinsCp, 8500);
    });

    test('kapali magaza oyuncuya eşyasiyla degil kapalilikla yansir', () async {
      await shops.update(shopId, mapAccessible: true, closed: true);

      final view = (await session.buildSnapshot()).mapShops.single;
      expect(view.closed, isTrue);
      expect(view.name, 'Demirci');

      final error = await session.handleClientMessage(
        ali,
        ClientMessage(type: ClientMessageType.buyItem, stockId: stockId),
      );
      expect(error, contains('shopClosed'));
      expect((await characters.find('vex'))!.coinsCp, 10000);
    });
  });

  group('harita yansitma', () {
    late WorldRepository world;
    late String locationId;
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('dm_map_test');
      world = WorldRepository(
        db,
        images: MapImageStore(directoryOverride: tempDir),
      );
      locationId = await world.createLocation(
        name: 'Yıkık Kale',
        description: 'Tepenin üstünde.',
      );
      // Gorunur olmasi icin haritali + revealed olmali.
      final source = File(p.join(tempDir.path, 'm.png'));
      final image = img.Image(width: 1000, height: 800);
      img.fill(image, color: img.ColorRgb8(10, 20, 30));
      await source.writeAsBytes(img.encodePng(image));
      await world.setMapImage(locationId, source);
      await world.updateLocation(locationId, revealed: true);
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('gorunur yapilmazsa harita gonderilmez', () async {
      await world.updateLocation(locationId, revealed: false);
      expect((await session.buildSnapshot()).maps, isEmpty);
    });

    test('secilen haritanin adi ve aciklamasi gider', () async {
      final view = (await session.buildSnapshot()).maps.single;
      expect(view.locationId, locationId);
      expect(view.locationName, 'Yıkık Kale');
      expect(view.description, 'Tepenin üstünde.');
    });

    test('gizli pinler istemciye HIC gonderilmez', () async {
      await world.addPin(
        locationId: locationId,
        kind: PinKind.note,
        label: 'Gizli geçit',
        x: 0.3,
        y: 0.3,
        noteText: 'Duvarın arkasında tünel var.',
      );
      final openPinId = await world.addPin(
        locationId: locationId,
        kind: PinKind.note,
        label: 'Kapı',
        x: 0.7,
        y: 0.7,
        noteText: 'Kilitli.',
      );
      await world.updatePin(openPinId, revealed: true);

      final view = (await session.buildSnapshot()).maps.single;
      expect(view.pins.length, 1);
      expect(view.pins.single.label, 'Kapı');

      // Gizli pinin ne etiketi ne notu paketin hicbir yerinde olmamali.
      final wire = view.toJson().toString();
      expect(wire, isNot(contains('Gizli geçit')));
      expect(wire, isNot(contains('tünel')));
    });

    test('acilmis not pininin metni gonderilir', () async {
      final id = await world.addPin(
        locationId: locationId,
        kind: PinKind.note,
        label: 'Kuyu',
        x: 0.5,
        y: 0.5,
        noteText: 'Dibinde parıltı var.',
      );
      await world.updatePin(id, revealed: true);

      final view = (await session.buildSnapshot()).maps.single;
      expect(view.pins.single.note, 'Dibinde parıltı var.');
    });

    test('not disi pinlerde metin sizmaz', () async {
      final npcId = await world.createNpc(name: 'Gundren');
      final id = await world.addPin(
        locationId: locationId,
        kind: PinKind.npc,
        label: 'Demirci',
        x: 0.4,
        y: 0.4,
        targetId: npcId,
        noteText: 'Aslında casus.',
      );
      await world.updatePin(id, revealed: true);

      final view = (await session.buildSnapshot()).maps.single;
      expect(view.pins.single.label, 'Demirci');
      expect(
        view.pins.single.note,
        isEmpty,
        reason: 'NPC pininde DM notu gönderilmemeli',
      );
    });

    test('pin koordinatlari oran olarak korunur', () async {
      final id = await world.addPin(
        locationId: locationId,
        kind: PinKind.treasure,
        label: 'Mahzen',
        x: 0.25,
        y: 0.8,
        noteText: 'Gizli hazine.',
      );
      await world.updatePin(id, revealed: true);

      final pin = (await session.buildSnapshot()).maps.single.pins.single;
      expect(pin.x, 0.25);
      expect(pin.y, 0.8);
      expect(pin.kind, 'treasure');
    });

    test('protokol paketi tur atlayinca ayni kalir', () async {
      final id = await world.addPin(
        locationId: locationId,
        kind: PinKind.treasure,
        label: 'Sandık',
        x: 0.6,
        y: 0.2,
        noteText: '200 gp ve bir yüzük.',
      );
      await world.updatePin(id, revealed: true);

      final original = (await session.buildSnapshot()).maps.single;
      final restored = MapView.fromJson(original.toJson());

      expect(restored.locationName, original.locationName);
      expect(restored.pins.single.label, 'Sandık');
      expect(restored.pins.single.note, '200 gp ve bir yüzük.');
      expect(restored.pins.single.x, 0.6);
    });
  });

  group('savas yansitma', () {
    setUp(() async {
      final encounterId = await combat.createEncounter('Mağara');
      session.activeEncounterId = encounterId;

      final goblin = await (db.select(
        db.monsters,
      )..where((t) => t.name.equals('Goblin Warrior'))).getSingle();
      await combat.addMonsters(
        encounterId: encounterId,
        monster: goblin,
        count: 2,
      );
      await combat.addCharacters(
        encounterId: encounterId,
        characters: [(await characters.find('vex'))!],
      );
    });

    test('canavarlarin kesin cani gizlenir, kaba durum gonderilir', () async {
      final combatView = (await session.buildSnapshot()).combat!;
      final monsters = combatView.combatants.where((c) => !c.isPlayer);

      expect(monsters.length, 2);
      for (final m in monsters) {
        expect(m.healthLabel, isNotNull);
        expect(m.healthLabel, 'healthy');
      }

      // Oyuncu satirinda kaba etiket yok; kendi kagidinda kesin cani var.
      final player = combatView.combatants.firstWhere((c) => c.isPlayer);
      expect(player.healthLabel, isNull);
      expect(player.characterId, 'vex');
    });

    test('canavar yaralandikca etiket degisir', () async {
      final rows = await combat.combatants(session.activeEncounterId!);
      final goblin = rows.firstWhere((c) => c.characterId == null);
      await combat.applyDamage(goblin.id, goblin.hitPointsMax - 1);

      final view = (await session.buildSnapshot()).combat!;
      final updated = view.combatants.firstWhere((c) => c.id == goblin.id);
      expect(updated.healthLabel, 'bloodied');
    });

    test('gizlenen katilimci listeye hic girmez', () async {
      final rows = await combat.combatants(session.activeEncounterId!);
      final goblin = rows.firstWhere((c) => c.characterId == null);
      await db.customStatement(
        'UPDATE combatants SET hidden_from_players = 1 WHERE id = ?',
        [goblin.id],
      );

      final view = (await session.buildSnapshot()).combat!;
      expect(view.combatants.any((c) => c.id == goblin.id), isFalse);
      expect(view.combatants.length, 2);
    });

    test('aktif karsilasma secilmezse savas gonderilmez', () async {
      session.activeEncounterId = null;
      expect((await session.buildSnapshot()).combat, isNull);
    });
  });

  group('hazine pini ganimeti', () {
    late ConnectedPlayer ali;
    late String locationId;
    late String pinId;

    setUp(() async {
      final world = WorldRepository(db);
      locationId = await world.createLocation(name: 'Mağara');
      // Lokasyonu oyunculara gorunur yap (haritasi + acik zincir).
      await db.customStatement(
        'UPDATE locations SET revealed = 1, map_preview_path = ? WHERE id = ?',
        ['maps/test.png', locationId],
      );
      pinId = await world.addPin(
        locationId: locationId,
        kind: PinKind.treasure,
        label: 'Hazine',
        x: 0.5,
        y: 0.5,
        lootSetId: 'loot-set-1',
        lootDataJson: jsonEncode({
          'coinsCp': 100,
          'items': [
            {'id': 'it-1', 'name': 'Kılıç', 'magic': false},
            {'id': 'it-2', 'name': '+1 Kalkan', 'magic': true},
          ],
        }),
      );
      await world.updatePin(pinId, revealed: true);

      ali = ConnectedPlayer(token: 'a', name: 'Ali');
      await session.handleClientMessage(
        ali,
        const ClientMessage(
          type: ClientMessageType.claimCharacter,
          characterId: 'vex',
        ),
      );
    });

    test('esya alininca envantere gecer ve kalan azalir', () async {
      final error = await session.handleClientMessage(
        ali,
        ClientMessage(
          type: ClientMessageType.takeTreasureLoot,
          lootPinId: pinId,
          lootItemId: 'it-1',
        ),
      );
      expect(error, isNull);

      // Envanterde esya var.
      final items = await characters.items('vex');
      expect(items.any((i) => i.customName == 'Kılıç'), isTrue);

      // Pinde kalan 1 esya + para hala duruyor.
      final world = WorldRepository(db);
      final pin = (await world.pins(locationId)).single;
      final data = jsonDecode(pin.lootDataJson!) as Map<String, dynamic>;
      expect((data['items'] as List).length, 1);
      expect(data['coinsCp'], 100);
    });

    test('hepsi alininca pin silinir', () async {
      await session.handleClientMessage(
        ali,
        ClientMessage(
          type: ClientMessageType.takeTreasureLoot,
          lootPinId: pinId,
          lootItemId: 'it-1',
        ),
      );
      await session.handleClientMessage(
        ali,
        ClientMessage(
          type: ClientMessageType.takeTreasureLoot,
          lootPinId: pinId,
          lootItemId: 'it-2',
        ),
      );
      await session.handleClientMessage(
        ali,
        ClientMessage(
          type: ClientMessageType.takeTreasureLoot,
          lootPinId: pinId, // kalan para
        ),
      );
      expect(await WorldRepository(db).pins(locationId), isEmpty);
    });

    test('takeAll hepsini alir ve pini siler', () async {
      final error = await session.handleClientMessage(
        ali,
        ClientMessage(
          type: ClientMessageType.takeAllTreasureLoot,
          lootPinId: pinId,
        ),
      );
      expect(error, isNull);

      final items = await characters.items('vex');
      expect(items.length, 2);
      final vex = (await characters.find('vex'))!;
      expect(vex.coinsCp, 100);
      expect(await WorldRepository(db).pins(locationId), isEmpty);
    });

    test('haritaya hazine pini kalan ganimetiyle girer', () async {
      final snap = await session.buildSnapshot();
      final map = snap.maps.firstWhere((m) => m.locationId == locationId);
      final pin = map.pins.single;
      expect(pin.kind, 'treasure');
      expect(pin.lootCoinsCp, 100);
      expect(pin.lootItems!.length, 2);
      expect(pin.lootItems!.first.id, 'it-1');
    });
  });
}
