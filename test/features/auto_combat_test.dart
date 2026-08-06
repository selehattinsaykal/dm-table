import 'package:dm_table/data/character_repository.dart';
import 'package:dm_table/data/combat_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/import/asset_importer.dart';
import 'package:dm_table/data/shop_repository.dart';
import 'package:dm_table/data/world_repository.dart';
import 'package:dm_table/domain/models/ability.dart';
import 'package:dm_table/features/session/session_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Savas OTOMATIK yansitilmali: DM elle secmeden, karsilasma "Başlat"inca
/// oyunculara acilir; "Bitir"ince kapanir.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CombatRepository combat;
  late CharacterRepository characters;
  late SessionService session;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await AssetImporter(db).importIfNeeded();
    combat = CombatRepository(db);
    characters = CharacterRepository(db);
    session = SessionService(
      db: db,
      characters: characters,
      combat: combat,
      shops: ShopRepository(db),
      world: WorldRepository(db),
    );
    await characters.createLevelOneCharacter(
      id: 'vex',
      name: 'Vex',
      classKey: 'srd-2024_wizard',
      abilities: const AbilityScores(),
      savingThrows: const {},
      skills: const {},
      hitDieSides: 6,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('savas baslayinca otomatik gorunur, bitince kapanir', () async {
    final encounterId = await combat.createEncounter('Mağara');
    final all = await characters.watchAll().first;
    await combat.addCharacters(encounterId: encounterId, characters: all);

    // Baslamadan: activeEncounterId elle secilmedi -> savas yok.
    expect((await session.buildSnapshot()).combat, isNull);
    expect(session.activeEncounterId, isNull);

    // Başlat -> otomatik yansir.
    await combat.start(encounterId);
    final started = (await session.buildSnapshot()).combat;
    expect(started, isNotNull);
    expect(started!.started, isTrue);
    expect(started.encounterName, 'Mağara');

    // Bitir -> otomatik kapanir.
    await combat.end(encounterId);
    expect((await session.buildSnapshot()).combat, isNull);
  });
}
