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

/// Görev paylaşımı + oyuncu kabul/ret: hedefleme, oyuncu-başına süzme, kimlik
/// doğrulama, DM notunun sızmaması.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SessionService session;
  late CharacterRepository characters;
  late QuestRepository quests;
  late ConnectedPlayer ali; // Rohan (ali-c)
  late ConnectedPlayer veli; // Pike (veli-c)

  Future<void> claim(ConnectedPlayer p, String id) =>
      session.handleClientMessage(
        p,
        ClientMessage(type: ClientMessageType.claimCharacter, characterId: id),
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
    await claim(ali, 'ali-c');
    await claim(veli, 'veli-c');
  });

  tearDown(() async {
    await session.stop();
    await db.close();
  });

  Future<String> sharedQuest({List<String> targets = const ['ali-c']}) async {
    final id = await quests.create(title: 'Kayıp çocuk');
    await quests.update(
      id,
      questText: 'Çocuğu bul',
      reward: '200 altın',
      dmNotes: 'Sır: kaçmadı',
    );
    await quests.setShared(id, shared: true, targets: targets);
    return id;
  }

  test('questViewsFor: yalnız hedef oyuncuya, DM notu taşınmaz', () async {
    await sharedQuest(targets: ['ali-c']);
    final forAli = await session.questViewsFor('ali-c');
    final forVeli = await session.questViewsFor('veli-c');
    expect(forAli.single.title, 'Kayıp çocuk');
    expect(forAli.single.text, 'Çocuğu bul');
    expect(forAli.single.reward, '200 altın');
    expect(forAli.single.myStatus, isNull);
    // QuestView'da dmNotes ALANI YOK → sızma imkânsız; hedef-dışı oyuncu görmez.
    expect(forVeli, isEmpty);
  });

  test('paylaşılmamış / tamamlanmış görev süzülür', () async {
    final id = await sharedQuest(targets: ['ali-c']);
    await quests.setShared(id, shared: false);
    expect(await session.questViewsFor('ali-c'), isEmpty);
    await quests.setShared(id, shared: true, targets: ['ali-c']);
    await quests.setDone(id, true);
    expect(await session.questViewsFor('ali-c'), isEmpty);
  });

  test('respondQuest: hedef kabul → acceptancesJson + myStatus', () async {
    final id = await sharedQuest(targets: ['ali-c']);
    final err = await session.handleClientMessage(
      ali,
      ClientMessage(
        type: ClientMessageType.respondQuest,
        questId: id,
        accept: true,
      ),
    );
    expect(err, isNull);
    expect(QuestRepository.acceptancesOf((await quests.find(id))!), {
      'ali-c': true,
    });
    expect((await session.questViewsFor('ali-c')).single.myStatus, 'accepted');
  });

  test('respondQuest: hedef-dışı oyuncu reddedilir, kayıt yok', () async {
    final id = await sharedQuest(targets: ['ali-c']);
    final err = await session.handleClientMessage(
      veli,
      ClientMessage(
        type: ClientMessageType.respondQuest,
        questId: id,
        accept: true,
      ),
    );
    expect(err, isNotNull); // offerNotForYou kodu
    expect(QuestRepository.acceptancesOf((await quests.find(id))!), isEmpty);
  });

  test('ret → myStatus rejected, fikir değiştirilebilir', () async {
    final id = await sharedQuest(targets: ['ali-c']);
    await session.handleClientMessage(
      ali,
      ClientMessage(
        type: ClientMessageType.respondQuest,
        questId: id,
        accept: false,
      ),
    );
    expect((await session.questViewsFor('ali-c')).single.myStatus, 'rejected');
    await session.handleClientMessage(
      ali,
      ClientMessage(
        type: ClientMessageType.respondQuest,
        questId: id,
        accept: true,
      ),
    );
    expect((await session.questViewsFor('ali-c')).single.myStatus, 'accepted');
  });
}
