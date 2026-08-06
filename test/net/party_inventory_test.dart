import 'package:dm_table/data/character_repository.dart';
import 'package:dm_table/data/combat_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/party_inventory_repository.dart';
import 'package:dm_table/data/shop_repository.dart';
import 'package:dm_table/data/world_repository.dart';
import 'package:dm_table/domain/models/ability.dart';
import 'package:dm_table/features/session/session_service.dart';
import 'package:dm_table/net/protocol.dart';
import 'package:dm_table/net/table_server.dart' show ConnectedPlayer;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ortak parti kesesi: protokol tasimasi, oyuncu-basina suzme ve al/koy
/// islemleri.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('protokol', () {
    test('snapshot JSON round-trip partyInventories tasir', () {
      const snap = TableSnapshot(
        partyInventories: [
          PartyInventoryView(
            id: 'p1',
            name: 'Parti kesesi',
            coinsCp: 250,
            items: [
              PartyItemView(id: 'i1', name: 'Ok', quantity: 20),
              PartyItemView(id: 'i2', name: 'Alev Dili', magic: true),
            ],
          ),
        ],
      );

      final decoded = TableSnapshot.fromJson(snap.toJson());
      expect(decoded.partyInventories, hasLength(1));
      final inv = decoded.partyInventories.single;
      expect(inv.name, 'Parti kesesi');
      expect(inv.coinsCp, 250);
      expect(inv.items, hasLength(2));
      expect(inv.items[0].quantity, 20);
      expect(inv.items[1].magic, isTrue);
    });

    test('eski istemci alani yoksa bos liste (geriye donuk uyum)', () {
      // Alan hic gonderilmemis bir snapshot cozulebilmeli.
      final decoded = TableSnapshot.fromJson({'characters': <dynamic>[]});
      expect(decoded.partyInventories, isEmpty);
    });

    test('copyWith(quests:) partyInventories\'i KORUR', () {
      // Regresyon: `questsFor` her zaman bagli oldugu icin HER snapshot
      // copyWith'ten geciyor. Iletim satiri unutulursa hicbir hata cikmadan
      // tum oyuncular kesesiz kalirdi.
      const snap = TableSnapshot(
        partyInventories: [PartyInventoryView(id: 'p1', name: 'Kese')],
      );

      final copy = snap.copyWith(quests: const []);
      expect(copy.partyInventories, hasLength(1));
      expect(copy.partyInventories.single.id, 'p1');
    });

    test('copyWith(partyInventories:) diger alanlari KORUR', () {
      const snap = TableSnapshot(
        inGameDate: '12 Hasat 1492',
        chats: [],
        quests: [
          QuestView(id: 'q1', title: 'Görev', text: 'gövde', reward: ''),
        ],
      );

      final copy = snap.copyWith(
        partyInventories: const [PartyInventoryView(id: 'p1', name: 'Kese')],
      );
      expect(copy.inGameDate, '12 Hasat 1492');
      expect(copy.quests, hasLength(1));
      expect(copy.partyInventories, hasLength(1));
    });
  });

  group('oyuncu-basina suzme ve islemler', () {
    late AppDatabase db;
    late SessionService session;
    late CharacterRepository characters;
    late PartyInventoryRepository party;
    late ConnectedPlayer ali; // ali-c
    late ConnectedPlayer veli; // veli-c
    late ConnectedPlayer bos; // karakter sahiplenmemis

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      characters = CharacterRepository(db);
      session = SessionService(
        db: db,
        characters: characters,
        combat: CombatRepository(db),
        shops: ShopRepository(db),
        world: WorldRepository(db),
      );
      party = session.party;

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
      bos = ConnectedPlayer(token: 'b', name: 'Boş');
      for (final (p, id) in [(ali, 'ali-c'), (veli, 'veli-c')]) {
        await session.handleClientMessage(
          p,
          ClientMessage(
            type: ClientMessageType.claimCharacter,
            characterId: id,
          ),
        );
      }
    });

    tearDown(() async {
      await session.stop();
      await db.close();
    });

    test('yalnizca UYE olunan keseler gonderilir', () async {
      final mine = await party.create('Ali kesesi');
      await party.setMembers(mine, ['ali-c']);
      final theirs = await party.create('Veli kesesi');
      await party.setMembers(theirs, ['veli-c']);

      final forAli = await session.partyInventoryViewsFor('ali-c');
      expect(forAli, hasLength(1));
      expect(forAli.single.name, 'Ali kesesi');

      final forVeli = await session.partyInventoryViewsFor('veli-c');
      expect(forVeli.single.name, 'Veli kesesi');
    });

    test('karakter sahiplenmemis sokete bos liste gider', () async {
      final id = await party.create('Kese');
      await party.setMembers(id, ['ali-c']);
      expect(await session.partyInventoryViewsFor(null), isEmpty);
    });

    test('esya alinca KATALOG ANAHTARI karaktere tasinir', () async {
      final invId = await party.create('Kese');
      await party.setMembers(invId, ['ali-c']);
      final item = PartyInventoryRepository.newItem(
        name: 'Uzun kılıç',
        itemKey: 'longsword',
      );
      await party.setItems(invId, [item]);

      final error = await session.handleClientMessage(
        ali,
        ClientMessage(
          type: ClientMessageType.takePartyItem,
          partyInventoryId: invId,
          itemId: item.id,
        ),
      );
      expect(error, isNull);

      final rows = await characters.items('ali-c');
      final added = rows.singleWhere((r) => r.itemKey == 'longsword');
      // Regresyon: anahtar dusseydi esya serbest metne doner, katalog
      // detayini ve istiflenmeyi kaybederdi.
      expect(added.itemKey, 'longsword');
      expect(added.customName, isNull);
    });

    test('UYE OLMAYAN alamaz', () async {
      final invId = await party.create('Kese');
      await party.setMembers(invId, ['ali-c']);
      final item = PartyInventoryRepository.newItem(name: 'Kılıç');
      await party.setItems(invId, [item]);

      final error = await session.handleClientMessage(
        veli,
        ClientMessage(
          type: ClientMessageType.takePartyItem,
          partyInventoryId: invId,
          itemId: item.id,
        ),
      );
      expect(error, isNotNull);
      // Esya yerinde durmali.
      expect(
        PartyInventoryRepository.itemsOf((await party.find(invId))!),
        hasLength(1),
      );
    });

    test('karakter sahiplenmeden alinamaz', () async {
      final invId = await party.create('Kese');
      final error = await session.handleClientMessage(
        bos,
        ClientMessage(
          type: ClientMessageType.takePartyItem,
          partyInventoryId: invId,
          itemId: 'x',
        ),
      );
      expect(error, isNotNull);
    });

    test('ayni esyayi iki oyuncu alamaz (yaris)', () async {
      final invId = await party.create('Kese');
      await party.setMembers(invId, ['ali-c', 'veli-c']);
      final item = PartyInventoryRepository.newItem(name: 'Tek kılıç');
      await party.setItems(invId, [item]);

      final first = await session.handleClientMessage(
        ali,
        ClientMessage(
          type: ClientMessageType.takePartyItem,
          partyInventoryId: invId,
          itemId: item.id,
        ),
      );
      final second = await session.handleClientMessage(
        veli,
        ClientMessage(
          type: ClientMessageType.takePartyItem,
          partyInventoryId: invId,
          itemId: item.id,
        ),
      );

      expect(first, isNull);
      expect(second, isNotNull, reason: 'ikinci alan itemGone almalı');
      expect((await characters.items('ali-c')).length, 1);
      expect((await characters.items('veli-c')), isEmpty);
    });

    test('para al/koy karakterin kesesini gunceller', () async {
      final invId = await party.create('Kese');
      await party.setMembers(invId, ['ali-c']);
      await party.depositCoins(invId, amountCp: 500);
      await characters.setCoins('ali-c', 100);

      await session.handleClientMessage(
        ali,
        ClientMessage(
          type: ClientMessageType.takePartyCoins,
          partyInventoryId: invId,
          coinsCp: 300,
        ),
      );
      expect((await characters.find('ali-c'))!.coinsCp, 400);
      expect((await party.find(invId))!.coinsCp, 200);

      await session.handleClientMessage(
        ali,
        ClientMessage(
          type: ClientMessageType.depositPartyCoins,
          partyInventoryId: invId,
          coinsCp: 150,
        ),
      );
      expect((await characters.find('ali-c'))!.coinsCp, 250);
      expect((await party.find(invId))!.coinsCp, 350);
    });

    test('yetmeyen para yatirilamaz', () async {
      final invId = await party.create('Kese');
      await party.setMembers(invId, ['ali-c']);
      await characters.setCoins('ali-c', 50);

      final error = await session.handleClientMessage(
        ali,
        ClientMessage(
          type: ClientMessageType.depositPartyCoins,
          partyInventoryId: invId,
          coinsCp: 500,
        ),
      );
      expect(error, isNotNull);
      expect((await characters.find('ali-c'))!.coinsCp, 50);
      expect((await party.find(invId))!.coinsCp, 0);
    });

    test('sahip OLMADIGI esya yatirilamaz', () async {
      final invId = await party.create('Kese');
      await party.setMembers(invId, ['ali-c', 'veli-c']);
      await characters.addItem(
        characterId: 'veli-c',
        customName: 'Veli kılıcı',
      );
      final veliItem = (await characters.items('veli-c')).single;

      final error = await session.handleClientMessage(
        ali, // Ali, Veli'nin esyasini koymaya calisiyor
        ClientMessage(
          type: ClientMessageType.depositPartyItem,
          partyInventoryId: invId,
          itemId: veliItem.id,
        ),
      );
      expect(error, isNotNull);
      expect((await characters.items('veli-c')), hasLength(1));
      expect(
        PartyInventoryRepository.itemsOf((await party.find(invId))!),
        isEmpty,
      );
    });

    test('esya yatirinca envanterden duser ve anahtari korunur', () async {
      final invId = await party.create('Kese');
      await party.setMembers(invId, ['ali-c']);
      await characters.addItem(
        characterId: 'ali-c',
        itemKey: 'longsword',
        quantity: 3,
      );
      final row = (await characters.items('ali-c')).single;

      final error = await session.handleClientMessage(
        ali,
        ClientMessage(
          type: ClientMessageType.depositPartyItem,
          partyInventoryId: invId,
          itemId: row.id,
          quantity: 2,
        ),
      );
      expect(error, isNull);

      expect((await characters.items('ali-c')).single.quantity, 1);
      final pooled = PartyInventoryRepository.itemsOf(
        (await party.find(invId))!,
      ).single;
      expect(pooled.itemKey, 'longsword');
      expect(pooled.quantity, 2);
    });

    test('sahip olunandan fazlasi yatirilamaz', () async {
      final invId = await party.create('Kese');
      await party.setMembers(invId, ['ali-c']);
      await characters.addItem(
        characterId: 'ali-c',
        customName: 'Ok',
        quantity: 2,
      );
      final row = (await characters.items('ali-c')).single;

      final error = await session.handleClientMessage(
        ali,
        ClientMessage(
          type: ClientMessageType.depositPartyItem,
          partyInventoryId: invId,
          itemId: row.id,
          quantity: 5,
        ),
      );
      expect(error, isNotNull);
      expect((await characters.items('ali-c')).single.quantity, 2);
    });

    test('esya yatir-al turu anahtari kaybetmez', () async {
      // Bu ozelligin varlik sebebi: esya karakter -> kese -> karakter gidip
      // geliyor; anahtar bir kez dusserse kalici olarak serbest metne doner.
      final invId = await party.create('Kese');
      await party.setMembers(invId, ['ali-c']);
      await characters.addItem(characterId: 'ali-c', itemKey: 'longsword');
      final row = (await characters.items('ali-c')).single;

      await session.handleClientMessage(
        ali,
        ClientMessage(
          type: ClientMessageType.depositPartyItem,
          partyInventoryId: invId,
          itemId: row.id,
        ),
      );
      final pooled = PartyInventoryRepository.itemsOf(
        (await party.find(invId))!,
      ).single;
      await session.handleClientMessage(
        ali,
        ClientMessage(
          type: ClientMessageType.takePartyItem,
          partyInventoryId: invId,
          itemId: pooled.id,
        ),
      );

      final back = (await characters.items('ali-c')).single;
      expect(back.itemKey, 'longsword');
      expect(back.customName, isNull);
    });
  });
}
