import 'package:dm_table/data/character_repository.dart';
import 'package:dm_table/data/combat_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/notes_repository.dart';
import 'package:dm_table/data/shop_repository.dart';
import 'package:dm_table/data/world_repository.dart';
import 'package:dm_table/data/import/asset_importer.dart';
import 'package:dm_table/domain/models/ability.dart';
import 'package:dm_table/features/session/session_service.dart';
import 'package:dm_table/net/protocol.dart';
import 'package:dm_table/net/table_server.dart' show ConnectedPlayer;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Oyuncu notlari: kaydetme yetkisi, kaliciligi ve protokol.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SessionService session;
  late CharacterRepository characters;

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

    await characters.createLevelOneCharacter(
      id: 'rohan',
      name: 'Rohan',
      classKey: 'srd-2024_rogue',
      abilities: const AbilityScores(dexterity: 16),
      savingThrows: const {},
      skills: const {},
      hitDieSides: 8,
    );
  });

  tearDown(() async {
    await session.stop();
    await db.close();
  });

  test('yeni karakterin notu bostur', () async {
    expect(await session.notes.getFor('rohan'), isEmpty);
  });

  test('karakter sahiplenmeden not kaydedilemez', () async {
    final player = ConnectedPlayer(token: 't', name: 'Selim');
    final error = await session.handleClientMessage(
      player,
      const ClientMessage(
        type: ClientMessageType.saveNotes,
        notes: [NoteSection(id: 's1', title: 'Görevler')],
      ),
    );

    expect(error, isNotNull);
    expect(await session.notes.getFor('rohan'), isEmpty);
  });

  test('sahiplendikten sonra not kaydedilir ve okunur', () async {
    final player = ConnectedPlayer(token: 't', name: 'Selim');
    await session.handleClientMessage(
      player,
      const ClientMessage(
        type: ClientMessageType.claimCharacter,
        characterId: 'rohan',
      ),
    );

    final error = await session.handleClientMessage(
      player,
      const ClientMessage(
        type: ClientMessageType.saveNotes,
        notes: [
          NoteSection(
            id: 's1',
            title: 'Görevler',
            entries: [NoteEntry(id: 'e1', title: 'Ejderha', body: 'Mağarada')],
          ),
        ],
      ),
    );
    expect(error, isNull);

    final saved = await session.notes.getFor('rohan');
    expect(saved, hasLength(1));
    expect(saved.single.title, 'Görevler');
    expect(saved.single.entries.single.body, 'Mağarada');
  });

  test('kaydetme tum belgeyi degistirir (replace)', () async {
    final player = ConnectedPlayer(token: 't', name: 'Selim');
    await session.handleClientMessage(
      player,
      const ClientMessage(
        type: ClientMessageType.claimCharacter,
        characterId: 'rohan',
      ),
    );

    await session.handleClientMessage(
      player,
      const ClientMessage(
        type: ClientMessageType.saveNotes,
        notes: [NoteSection(id: 's1', title: 'İlk')],
      ),
    );
    await session.handleClientMessage(
      player,
      const ClientMessage(
        type: ClientMessageType.saveNotes,
        notes: [NoteSection(id: 's2', title: 'İkinci')],
      ),
    );

    final saved = await session.notes.getFor('rohan');
    expect(saved.map((s) => s.id), ['s2']);
  });

  test('requestNotes karakter secilmemisken hata vermez', () async {
    final player = ConnectedPlayer(token: 't', name: 'Selim');
    final error = await session.handleClientMessage(
      player,
      const ClientMessage(type: ClientMessageType.requestNotes),
    );
    expect(error, isNull);
  });

  test('ClientMessage notlari kodlayip cozer (round-trip)', () {
    const message = ClientMessage(
      type: ClientMessageType.saveNotes,
      notes: [
        NoteSection(
          id: 's1',
          title: 'Görevler',
          entries: [NoteEntry(id: 'e1', title: 'A', body: 'B')],
        ),
      ],
    );

    final decoded = ClientMessage.decode(message.encode());
    expect(decoded.type, ClientMessageType.saveNotes);
    expect(decoded.notes, hasLength(1));
    expect(decoded.notes!.single.entries.single.title, 'A');
  });

  test('NotesRepository dogrudan upsert eder', () async {
    final repo = NotesRepository(db);
    await repo.setFor('rohan', [const NoteSection(id: 's1', title: 'X')]);
    expect((await repo.getFor('rohan')).single.title, 'X');

    await repo.setFor('rohan', const []);
    expect(await repo.getFor('rohan'), isEmpty);
  });
}
