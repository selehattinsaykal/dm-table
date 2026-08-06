import 'package:dm_table/data/character_repository.dart';
import 'package:dm_table/data/combat_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/quest_repository.dart';
import 'package:dm_table/data/shop_repository.dart';
import 'package:dm_table/data/world_repository.dart';
import 'package:dm_table/domain/models/ability.dart';
import 'package:dm_table/features/session/session_service.dart';
import 'package:dm_table/net/protocol.dart';
import 'package:dm_table/net/table_server.dart' show ConnectedPlayer;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Görev ödülleri (gerçek eşya + para, ortak havuz) ve oylamalı paylaşım.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SessionService session;
  late CharacterRepository characters;
  late QuestRepository quests;
  late ConnectedPlayer ali; // Rohan (ali-c)
  late ConnectedPlayer veli; // Pike (veli-c)
  late ConnectedPlayer can; // Mira (can-c)

  Future<String?> respond(ConnectedPlayer p, String id, bool accept) =>
      session.handleClientMessage(
        p,
        ClientMessage(
          type: ClientMessageType.respondQuest,
          questId: id,
          accept: accept,
        ),
      );

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
    quests = session.quests;
    for (final (id, name) in [
      ('ali-c', 'Rohan'),
      ('veli-c', 'Pike'),
      ('can-c', 'Mira'),
    ]) {
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
    can = ConnectedPlayer(token: 'c', name: 'Can');
    for (final (p, id) in [(ali, 'ali-c'), (veli, 'veli-c'), (can, 'can-c')]) {
      await session.handleClientMessage(
        p,
        ClientMessage(type: ClientMessageType.claimCharacter, characterId: id),
      );
    }
  });

  tearDown(() async {
    await session.stop();
    await db.close();
  });

  /// Ödüllü görev: 100 cp + iki eşya.
  Future<String> rewardQuest({
    required List<String> targets,
    String mode = QuestRepository.modeIndividual,
  }) async {
    final id = await quests.create(title: 'Kayıp çocuk');
    await quests.update(
      id,
      questText: 'Çocuğu bul',
      rewardCoinsCp: 100,
      rewardItems: const [
        (name: 'Kılıç', magic: false),
        (name: '+1 Kalkan', magic: true),
      ],
    );
    await quests.setShared(id, shared: true, targets: targets, mode: mode);
    return id;
  }

  group('ödül havuzu', () {
    test(
      'görev tamamlanınca havuz açılır, yalnız kabul edenlere gider',
      () async {
        final id = await rewardQuest(targets: ['ali-c', 'veli-c']);
        await respond(ali, id, true);
        await respond(veli, id, false);
        await quests.setDone(id, true);

        final forAli = (await session.questViewsFor('ali-c')).single;
        expect(forAli.rewardReady, isTrue);
        expect(forAli.rewardCoinsCp, 100);
        expect(forAli.rewardItems.length, 2);
        // Reddeden oyuncu ödülü hiç görmez.
        expect(await session.questViewsFor('veli-c'), isEmpty);
      },
    );

    test('ödülsüz görev tamamlanınca kimseye gitmez', () async {
      final id = await quests.create(title: 'Boş');
      await quests.setShared(id, shared: true, targets: ['ali-c']);
      await respond(ali, id, true);
      await quests.setDone(id, true);
      expect((await quests.find(id))!.rewardPoolJson, isNull);
      expect(await session.questViewsFor('ali-c'), isEmpty);
    });

    test('eşya alınınca envantere geçer ve diğerlerinden kaybolur', () async {
      final id = await rewardQuest(targets: ['ali-c', 'veli-c']);
      await respond(ali, id, true);
      await respond(veli, id, true);
      await quests.setDone(id, true);

      final itemId = (await session.questViewsFor(
        'ali-c',
      )).single.rewardItems.firstWhere((i) => i.name == 'Kılıç').id;
      final error = await session.handleClientMessage(
        ali,
        ClientMessage(
          type: ClientMessageType.takeQuestReward,
          questId: id,
          lootItemId: itemId,
        ),
      );
      expect(error, isNull);
      expect(
        (await characters.items('ali-c')).any((i) => i.customName == 'Kılıç'),
        isTrue,
      );
      // Havuz ortak: Veli'de de kalmadı, dupelenmedi.
      final forVeli = (await session.questViewsFor('veli-c')).single;
      expect(forVeli.rewardItems.map((i) => i.name), ['+1 Kalkan']);

      // Ikinci kez ayni esyayi almak bos doner (itemGone).
      final second = await session.handleClientMessage(
        veli,
        ClientMessage(
          type: ClientMessageType.takeQuestReward,
          questId: id,
          lootItemId: itemId,
        ),
      );
      expect(second, isNotNull);
      expect(
        (await characters.items(
          'veli-c',
        )).where((i) => i.customName == 'Kılıç'),
        isEmpty,
      );
    });

    test('para alınınca keseye eklenir', () async {
      final id = await rewardQuest(targets: ['ali-c']);
      await respond(ali, id, true);
      await quests.setDone(id, true);
      final before = (await characters.find('ali-c'))!.coinsCp;

      await session.handleClientMessage(
        ali,
        ClientMessage(type: ClientMessageType.takeQuestReward, questId: id),
      );
      expect((await characters.find('ali-c'))!.coinsCp, before + 100);
      expect((await session.questViewsFor('ali-c')).single.rewardCoinsCp, 0);
    });

    test('havuz boşalınca görev tablodan silinir', () async {
      final id = await rewardQuest(targets: ['ali-c']);
      await respond(ali, id, true);
      await quests.setDone(id, true);

      for (final item in (await session.questViewsFor(
        'ali-c',
      )).single.rewardItems) {
        await session.handleClientMessage(
          ali,
          ClientMessage(
            type: ClientMessageType.takeQuestReward,
            questId: id,
            lootItemId: item.id,
          ),
        );
      }
      await session.handleClientMessage(
        ali,
        ClientMessage(type: ClientMessageType.takeQuestReward, questId: id),
      );
      expect(await quests.find(id), isNull);
      expect(await session.questViewsFor('ali-c'), isEmpty);
    });

    test('tümünü al: hepsi tek oyuncuya geçer, görev silinir', () async {
      final id = await rewardQuest(targets: ['ali-c', 'veli-c']);
      await respond(ali, id, true);
      await respond(veli, id, true);
      await quests.setDone(id, true);

      final error = await session.handleClientMessage(
        veli,
        ClientMessage(type: ClientMessageType.takeAllQuestReward, questId: id),
      );
      expect(error, isNull);
      expect((await characters.items('veli-c')).length, 2);
      expect((await characters.find('veli-c'))!.coinsCp, 100);
      expect(await quests.find(id), isNull);
      expect(await session.questViewsFor('ali-c'), isEmpty);
    });

    test('kabul etmeyen ödüle uzanamaz', () async {
      final id = await rewardQuest(targets: ['ali-c', 'veli-c']);
      await respond(ali, id, true);
      await quests.setDone(id, true);

      final error = await session.handleClientMessage(
        veli,
        ClientMessage(type: ClientMessageType.takeAllQuestReward, questId: id),
      );
      expect(error, isNotNull);
      expect(await quests.find(id), isNotNull);
      expect(await characters.items('veli-c'), isEmpty);
    });
  });

  group('oylama', () {
    test('%50+ kabul: görev hedeflerin HEPSİNE verilir', () async {
      final id = await rewardQuest(
        targets: ['ali-c', 'veli-c'],
        mode: QuestRepository.modeVote,
      );
      await respond(ali, id, true); // 1/2 = %50 → geçer

      final quest = (await quests.find(id))!;
      expect(quest.voteStatus, QuestRepository.votePassed);
      expect(quest.shared, isTrue);
      expect(QuestRepository.acceptancesOf(quest), {
        'ali-c': true,
        'veli-c': true,
      });
      // Ret oyu vermeye kalkan bile görevi almış olur.
      expect(
        (await session.questViewsFor('veli-c')).single.myStatus,
        'accepted',
      );
    });

    test('%50 altı: kimse alamaz, görev oyunculardan kalkar', () async {
      final id = await rewardQuest(
        targets: ['ali-c', 'veli-c', 'can-c'],
        mode: QuestRepository.modeVote,
      );
      await respond(ali, id, false);
      await respond(veli, id, false); // 2/3 ret → düşer

      final quest = (await quests.find(id))!;
      expect(quest.voteStatus, QuestRepository.voteFailed);
      expect(quest.shared, isFalse);
      expect(QuestRepository.acceptancesOf(quest), isEmpty);
      for (final c in ['ali-c', 'veli-c', 'can-c']) {
        expect(await session.questViewsFor(c), isEmpty);
      }
    });

    test(
      'oylama sürerken oy değiştirilebilir, bittikten sonra kilitlenir',
      () async {
        final id = await rewardQuest(
          targets: ['ali-c', 'veli-c', 'can-c'],
          mode: QuestRepository.modeVote,
        );
        await respond(ali, id, false);
        expect(
          (await quests.find(id))!.voteStatus,
          QuestRepository.votePending,
        );
        // Fikir degistirme (henuz sonuclanmadi).
        await respond(ali, id, true);
        expect(
          QuestRepository.acceptancesOf((await quests.find(id))!)['ali-c'],
          isTrue,
        );

        await respond(veli, id, true); // 2/3 kabul → geçer
        expect((await quests.find(id))!.voteStatus, QuestRepository.votePassed);

        // Sonuclandiktan sonra oy degismez.
        await respond(can, id, false);
        expect(
          QuestRepository.acceptancesOf((await quests.find(id))!)['can-c'],
          isTrue,
        );
      },
    );

    test('oylama görünümü oyuncuya mod + durum taşır', () async {
      await rewardQuest(
        targets: ['ali-c', 'veli-c', 'can-c'],
        mode: QuestRepository.modeVote,
      );
      final view = (await session.questViewsFor('ali-c')).single;
      expect(view.mode, QuestRepository.modeVote);
      expect(view.voteStatus, QuestRepository.votePending);
      expect(view.myStatus, isNull);
    });

    test('yeniden paylaşım eski kararları sıfırlar', () async {
      final id = await rewardQuest(targets: ['ali-c', 'veli-c']);
      await respond(ali, id, true);
      await quests.setShared(
        id,
        shared: true,
        targets: ['ali-c', 'veli-c'],
        mode: QuestRepository.modeVote,
      );
      final quest = (await quests.find(id))!;
      expect(QuestRepository.acceptancesOf(quest), isEmpty);
      expect(quest.voteStatus, QuestRepository.votePending);
    });
  });
}
