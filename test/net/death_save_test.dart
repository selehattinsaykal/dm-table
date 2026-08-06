import 'dart:math';

import 'package:dm_table/data/character_repository.dart';
import 'package:dm_table/data/combat_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/shop_repository.dart';
import 'package:dm_table/data/world_repository.dart';
import 'package:dm_table/data/import/asset_importer.dart';
import 'package:dm_table/domain/models/ability.dart';
import 'package:dm_table/domain/rules/dice.dart';
import 'package:dm_table/features/session/session_service.dart';
import 'package:dm_table/net/protocol.dart';
import 'package:dm_table/net/table_server.dart' show ConnectedPlayer;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Olum kurtarma atislari: sunucu d20 atip 5e kurallarini uygular.
///
/// Zar [_ScriptedRandom] ile sabitleniyor ki her dogal sonuc deterministik
/// test edilebilsin (kuyruga eklenen deger d20'nin dogal sonucudur).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SessionService session;
  late CharacterRepository characters;
  late _ScriptedRandom rng;
  late ConnectedPlayer ali;

  Future<void> claim(ConnectedPlayer p, String id) =>
      session.handleClientMessage(
        p,
        ClientMessage(type: ClientMessageType.claimCharacter, characterId: id),
      );

  Future<String?> rollDeathSave(ConnectedPlayer p) =>
      session.handleClientMessage(
        p,
        const ClientMessage(type: ClientMessageType.rollDeathSave),
      );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await AssetImporter(db).importIfNeeded();
    characters = CharacterRepository(db);
    rng = _ScriptedRandom();
    session = SessionService(
      db: db,
      characters: characters,
      combat: CombatRepository(db),
      shops: ShopRepository(db),
      world: WorldRepository(db),
      dice: DiceRoller(rng),
    );

    await characters.createLevelOneCharacter(
      id: 'ali-c',
      name: 'Rohan',
      classKey: 'srd-2024_fighter',
      abilities: const AbilityScores(),
      savingThrows: const {},
      skills: const {},
      hitDieSides: 10,
    );
    ali = ConnectedPlayer(token: 'a', name: 'Ali');
    await claim(ali, 'ali-c');
  });

  tearDown(() async {
    await session.stop();
    await db.close();
  });

  /// Karakteri 0 HP'ye serer.
  Future<void> knockOut() async {
    final c = await characters.find('ali-c');
    await characters.applyDamage('ali-c', c!.hitPointsCurrent);
    expect((await characters.find('ali-c'))!.hitPointsCurrent, 0);
  }

  test('serilmemis karakter olum kurtarmasi atamaz', () async {
    final err = await rollDeathSave(ali);
    expect(err, isNotNull); // notDying kodu doner
    final c = await characters.find('ali-c');
    expect(c!.deathSaveSuccesses, 0);
    expect(c.deathSaveFailures, 0);
  });

  test('10+ atis bir basari sayilir', () async {
    await knockOut();
    rng.queue.add(15);
    expect(await rollDeathSave(ali), isNull);

    final c = await characters.find('ali-c');
    expect(c!.deathSaveSuccesses, 1);
    expect(c.deathSaveFailures, 0);
    expect(c.hitPointsCurrent, 0); // hala serili
  });

  test('10 altindaki atis bir basarisizlik sayilir', () async {
    await knockOut();
    rng.queue.add(5);
    await rollDeathSave(ali);

    final c = await characters.find('ali-c');
    expect(c!.deathSaveSuccesses, 0);
    expect(c.deathSaveFailures, 1);
  });

  test('dogal 1 iki basarisizlik sayilir', () async {
    await knockOut();
    rng.queue.add(1);
    await rollDeathSave(ali);

    final c = await characters.find('ali-c');
    expect(c!.deathSaveFailures, 2);
  });

  test(
    'dogal 20 karakteri 1 HP ile ayaga kaldirir ve sayaclari sifirlar',
    () async {
      await knockOut();
      // Once bir basari birikmis olsun.
      rng.queue.add(12);
      await rollDeathSave(ali);
      expect((await characters.find('ali-c'))!.deathSaveSuccesses, 1);

      rng.queue.add(20);
      await rollDeathSave(ali);

      final c = await characters.find('ali-c');
      expect(c!.hitPointsCurrent, 1);
      expect(c.deathSaveSuccesses, 0);
      expect(c.deathSaveFailures, 0);
    },
  );

  test('sayaclar 3 ile sinirli', () async {
    await knockOut();
    // Iki dogal 1 = 4 basarisizlik; 3'te kirpilmali.
    rng.queue.addAll([1, 1]);
    await rollDeathSave(ali);
    await rollDeathSave(ali);

    final c = await characters.find('ali-c');
    expect(c!.deathSaveFailures, 3);
  });

  test('atis paylasilan zar gunluguine dogal d20 ile duser', () async {
    await knockOut();
    rng.queue.add(17);
    await rollDeathSave(ali);

    final snapshot = await session.buildSnapshot();
    final last = snapshot.rolls.last;
    expect(last.results.single, 17);
    expect(last.source, 'Ali');
  });
}

/// d20'nin dogal sonucunu deterministik kilan sahte Random.
/// [DiceRoller._rollOne] `nextInt(20) + 1` yaptigindan burada dogal degerden
/// 1 cikariyoruz; kuyruk bosalirsa 10 (basari) doner.
class _ScriptedRandom implements Random {
  final queue = <int>[];

  @override
  int nextInt(int max) => (queue.isEmpty ? 10 : queue.removeAt(0)) - 1;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0.0;
}
