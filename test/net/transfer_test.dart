import 'package:dm_table/data/character_repository.dart';
import 'package:dm_table/data/combat_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/shop_repository.dart';
import 'package:dm_table/data/world_repository.dart';
import 'package:dm_table/data/import/asset_importer.dart';
import 'package:dm_table/domain/models/ability.dart';
import 'package:dm_table/features/session/session_service.dart';
import 'package:dm_table/net/protocol.dart';
import 'package:dm_table/net/table_server.dart' show ConnectedPlayer;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Oyuncular arasi esya/para gonderme: dogrulama, kabul/ret ve atomik aktarim.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SessionService session;
  late CharacterRepository characters;
  late ConnectedPlayer ali;
  late ConnectedPlayer veli;

  Future<void> claim(ConnectedPlayer p, String id) =>
      session.handleClientMessage(
        p,
        ClientMessage(type: ClientMessageType.claimCharacter, characterId: id),
      );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await AssetImporter(db).importIfNeeded();
    characters = CharacterRepository(db);
    session = SessionService(
      db: db,
      characters: characters,
      combat: CombatRepository(db),
      shops: ShopRepository(db),
      world: WorldRepository(db),
    );

    for (final (id, name) in [('ali-c', 'Rohan'), ('veli-c', 'Pike')]) {
      await characters.createLevelOneCharacter(
        id: id,
        name: name,
        classKey: 'srd-2024_fighter',
        abilities: const AbilityScores(),
        savingThrows: const {},
        skills: const {},
        hitDieSides: 10,
      );
    }
    ali = ConnectedPlayer(token: 'a', name: 'Ali');
    veli = ConnectedPlayer(token: 'v', name: 'Veli');
  });

  tearDown(() async {
    await session.stop();
    await db.close();
  });

  // --- Repository (atomik primitifler) -------------------------------------

  group('repository', () {
    test('transferItem esyayi tasir, anahtari korur, adedi duser', () async {
      await characters.addItem(
        characterId: 'ali-c',
        customName: 'Kılıç',
        quantity: 3,
      );
      final itemId = (await characters.items('ali-c')).single.id;

      final ok = await characters.transferItem(
        itemId: itemId,
        toCharacterId: 'veli-c',
        quantity: 2,
      );
      expect(ok, isTrue);

      final aliItems = await characters.items('ali-c');
      expect(aliItems.single.quantity, 1); // 3 - 2
      final veliItems = await characters.items('veli-c');
      expect(veliItems.single.customName, 'Kılıç');
      expect(veliItems.single.quantity, 2);
    });

    test('transferItem adet yetmezse hicbir sey yapmaz', () async {
      await characters.addItem(characterId: 'ali-c', customName: 'Ok');
      final itemId = (await characters.items('ali-c')).single.id;

      final ok = await characters.transferItem(
        itemId: itemId,
        toCharacterId: 'veli-c',
        quantity: 5,
      );
      expect(ok, isFalse);
      expect((await characters.items('ali-c')).single.quantity, 1);
      expect(await characters.items('veli-c'), isEmpty);
    });

    test('transferCoins parayi tasir', () async {
      await characters.setCoins('ali-c', 500);
      final ok = await characters.transferCoins(
        fromCharacterId: 'ali-c',
        toCharacterId: 'veli-c',
        amountCp: 300,
      );
      expect(ok, isTrue);
      expect((await characters.find('ali-c'))!.coinsCp, 200);
      expect((await characters.find('veli-c'))!.coinsCp, 300);
    });

    test('transferCoins yeterli para yoksa false', () async {
      await characters.setCoins('ali-c', 100);
      final ok = await characters.transferCoins(
        fromCharacterId: 'ali-c',
        toCharacterId: 'veli-c',
        amountCp: 300,
      );
      expect(ok, isFalse);
      expect((await characters.find('ali-c'))!.coinsCp, 100);
      expect((await characters.find('veli-c'))!.coinsCp, 0);
    });
  });

  // --- Teklif akisi --------------------------------------------------------

  group('teklif dogrulama', () {
    test('karakter sahiplenmeden teklif verilemez', () async {
      final error = await session.handleClientMessage(
        ali,
        const ClientMessage(
          type: ClientMessageType.offerTransfer,
          toCharacterId: 'veli-c',
          coinsCp: 10,
        ),
      );
      expect(error, isNotNull);
    });

    test('masada olmayan oyuncuya gonderilemez', () async {
      await claim(ali, 'ali-c'); // veli sahiplenmedi
      await characters.setCoins('ali-c', 100);
      final error = await session.handleClientMessage(
        ali,
        const ClientMessage(
          type: ClientMessageType.offerTransfer,
          toCharacterId: 'veli-c',
          coinsCp: 50,
        ),
      );
      expect(error, contains('recipientNotAtTable'));
      expect(session.pendingTransfers, isEmpty);
    });

    test('kendine gonderilemez', () async {
      await claim(ali, 'ali-c');
      final error = await session.handleClientMessage(
        ali,
        const ClientMessage(
          type: ClientMessageType.offerTransfer,
          toCharacterId: 'ali-c',
          coinsCp: 10,
        ),
      );
      expect(error, isNotNull);
    });

    test('sahip olmadigin esya teklif edilemez', () async {
      await claim(ali, 'ali-c');
      await claim(veli, 'veli-c');
      final error = await session.handleClientMessage(
        ali,
        const ClientMessage(
          type: ClientMessageType.offerTransfer,
          toCharacterId: 'veli-c',
          itemId: 'yok-boyle-esya',
        ),
      );
      expect(error, isNotNull);
    });

    test('yetmeyen para teklif edilemez', () async {
      await claim(ali, 'ali-c');
      await claim(veli, 'veli-c');
      await characters.setCoins('ali-c', 20);
      final error = await session.handleClientMessage(
        ali,
        const ClientMessage(
          type: ClientMessageType.offerTransfer,
          toCharacterId: 'veli-c',
          coinsCp: 100,
        ),
      );
      expect(error, isNotNull);
    });
  });

  group('kabul/ret', () {
    setUp(() async {
      await claim(ali, 'ali-c');
      await claim(veli, 'veli-c');
    });

    test('alici kabul edince esya aktarilir', () async {
      await characters.addItem(
        characterId: 'ali-c',
        customName: 'Yüzük',
        quantity: 1,
      );
      final itemId = (await characters.items('ali-c')).single.id;

      await session.handleClientMessage(
        ali,
        ClientMessage(
          type: ClientMessageType.offerTransfer,
          toCharacterId: 'veli-c',
          itemId: itemId,
        ),
      );
      final pending = session.pendingTransfers.single;
      expect(pending.toCharacterId, 'veli-c');
      expect(pending.itemName, 'Yüzük');

      final error = await session.handleClientMessage(
        veli,
        ClientMessage(
          type: ClientMessageType.respondTransfer,
          transferId: pending.id,
          accept: true,
        ),
      );
      expect(error, isNull);
      expect(session.pendingTransfers, isEmpty);
      expect(await characters.items('ali-c'), isEmpty);
      expect((await characters.items('veli-c')).single.customName, 'Yüzük');
    });

    test('alici reddedince esya kalir', () async {
      await characters.addItem(characterId: 'ali-c', customName: 'Kalkan');
      final itemId = (await characters.items('ali-c')).single.id;
      await session.handleClientMessage(
        ali,
        ClientMessage(
          type: ClientMessageType.offerTransfer,
          toCharacterId: 'veli-c',
          itemId: itemId,
        ),
      );
      final pending = session.pendingTransfers.single;

      await session.handleClientMessage(
        veli,
        ClientMessage(
          type: ClientMessageType.respondTransfer,
          transferId: pending.id,
          accept: false,
        ),
      );
      expect(session.pendingTransfers, isEmpty);
      expect((await characters.items('ali-c')).single.customName, 'Kalkan');
      expect(await characters.items('veli-c'), isEmpty);
    });

    test('yalnizca alici yanitlayabilir', () async {
      await characters.setCoins('ali-c', 100);
      await session.handleClientMessage(
        ali,
        const ClientMessage(
          type: ClientMessageType.offerTransfer,
          toCharacterId: 'veli-c',
          coinsCp: 50,
        ),
      );
      final pending = session.pendingTransfers.single;

      // Gonderen kendi teklifini kabul edemez.
      final error = await session.handleClientMessage(
        ali,
        ClientMessage(
          type: ClientMessageType.respondTransfer,
          transferId: pending.id,
          accept: true,
        ),
      );
      expect(error, isNotNull);
      expect(session.pendingTransfers, hasLength(1)); // duruyor
      expect((await characters.find('ali-c'))!.coinsCp, 100); // aktarilmadi
    });

    test('kabul edilen para aktarilir; ikinci kabul teklifi bulamaz', () async {
      await characters.setCoins('ali-c', 100);
      await session.handleClientMessage(
        ali,
        const ClientMessage(
          type: ClientMessageType.offerTransfer,
          toCharacterId: 'veli-c',
          coinsCp: 60,
        ),
      );
      final id = session.pendingTransfers.single.id;

      await session.handleClientMessage(
        veli,
        ClientMessage(
          type: ClientMessageType.respondTransfer,
          transferId: id,
          accept: true,
        ),
      );
      expect((await characters.find('ali-c'))!.coinsCp, 40);
      expect((await characters.find('veli-c'))!.coinsCp, 60);

      // Ayni teklif tekrar yanitlanirsa sessizce yok sayilir.
      final again = await session.handleClientMessage(
        veli,
        ClientMessage(
          type: ClientMessageType.respondTransfer,
          transferId: id,
          accept: true,
        ),
      );
      expect(again, isNull);
      expect((await characters.find('veli-c'))!.coinsCp, 60); // degismedi
    });
  });
}
