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

/// Oyuncu inisiyatifi: sunucu d20 + modifiye atar, katilimciyi siraya oturtur
/// ve sonucu paylasilan gunluge dusurur (zar [_ScriptedRandom] ile sabit).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SessionService session;
  late CharacterRepository characters;
  late CombatRepository combat;
  late _ScriptedRandom rng;
  late ConnectedPlayer ali;
  late String encounterId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await AssetImporter(db).importIfNeeded();
    characters = CharacterRepository(db);
    combat = CombatRepository(db);
    rng = _ScriptedRandom();
    session = SessionService(
      db: db,
      characters: characters,
      combat: combat,
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
    await session.handleClientMessage(
      ali,
      const ClientMessage(
        type: ClientMessageType.claimCharacter,
        characterId: 'ali-c',
      ),
    );

    encounterId = await combat.createEncounter('Test');
    await combat.addCharacters(
      encounterId: encounterId,
      characters: [(await characters.find('ali-c'))!],
    );
    await combat.start(encounterId); // aktif karsilasma; oyuncu atilmamis kalir
  });

  tearDown(() async {
    await session.stop();
    await db.close();
  });

  test('start() sonrasi oyuncu inisiyatifi atilmamis', () async {
    final row = (await combat.combatants(encounterId)).single;
    expect(row.initiativeRolled, isFalse);
    expect(row.initiative, 0);
  });

  test('rollInitiative sunucuda d20+mod atar ve siraya oturtur', () async {
    rng.queue.add(14); // dogal d20; varsayilan yeteneklerde mod 0
    final err = await session.handleClientMessage(
      ali,
      const ClientMessage(type: ClientMessageType.rollInitiative),
    );
    expect(err, isNull);

    final row = (await combat.combatants(encounterId)).single;
    expect(row.initiative, 14);
    expect(row.initiativeRolled, isTrue);
  });

  test('atis paylasilan zar gunluguine kaynagiyla duser', () async {
    rng.queue.add(9);
    await session.handleClientMessage(
      ali,
      const ClientMessage(type: ClientMessageType.rollInitiative),
    );

    final snapshot = await session.buildSnapshot();
    final last = snapshot.rolls.last;
    expect(last.total, 9);
    expect(last.source, 'Ali');
  });

  test('aktif savas yoksa hata doner', () async {
    await combat.end(encounterId);
    final err = await session.handleClientMessage(
      ali,
      const ClientMessage(type: ClientMessageType.rollInitiative),
    );
    expect(err, isNotNull);
  });
}

/// d20'nin dogal sonucunu deterministik kilan sahte Random (natural - 1).
class _ScriptedRandom implements Random {
  final queue = <int>[];

  @override
  int nextInt(int max) => (queue.isEmpty ? 10 : queue.removeAt(0)) - 1;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0.0;
}
