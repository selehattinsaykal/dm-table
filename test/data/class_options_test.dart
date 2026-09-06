import 'package:dm_table/data/character_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/import/asset_importer.dart';
import 'package:dm_table/domain/models/ability.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sinif secenekleri: Eldritch Invocation, Metamagic, Maneuver, Rune.
///
/// Metinleri kutuphanede vardi ama karaktere secilemiyordu.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CharacterRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await AssetImporter(db).importIfNeeded();
    repo = CharacterRepository(db);
  });

  tearDown(() async => db.close());

  Future<void> make(String id, String classKey) => repo.createLevelOneCharacter(
    id: id,
    name: id,
    classKey: classKey,
    abilities: const AbilityScores(),
    savingThrows: const {},
    skills: const {},
    hitDieSides: 8,
  );

  test('secenekler pakete girdi', () async {
    final rows = await (db.select(
      db.referenceEntries,
    )..where((t) => t.kind.equals('optionalfeatures'))).get();
    expect(rows, hasLength(62));
  });

  test('Warlock invocation, Sorcerer metamagic gorur', () async {
    await make('w', 'srd-2024_warlock');
    await make('s', 'srd-2024_sorcerer');

    final warlock = await repo.classOptionsFor('w');
    final sorcerer = await repo.classOptionsFor('s');

    expect(warlock, isNotEmpty);
    expect(
      warlock.every((o) => o['type_name'] == 'Eldritch Invocation'),
      isTrue,
    );
    expect(warlock.map((o) => o['name']), contains('Agonizing Blast'));

    expect(sorcerer.every((o) => o['type_name'] == 'Metamagic'), isTrue);
    // Baska sinifin secenegi listeye sizmamali.
    expect(sorcerer.map((o) => o['name']), isNot(contains('Agonizing Blast')));
  });

  test('secenegi olmayan sinifta liste bos', () async {
    await make('c', 'srd-2024_cleric');
    expect(await repo.classOptionsFor('c'), isEmpty);
  });

  test('secilen secenek kagida yazilir ve tekrarlanmaz', () async {
    await make('w', 'srd-2024_warlock');
    final option = (await repo.classOptionsFor(
      'w',
    )).firstWhere((o) => o['name'] == 'Agonizing Blast');

    await repo.addClassOption('w', option);
    await repo.addClassOption('w', option);

    final written = (await repo.features(
      'w',
    )).where((f) => f.source == 'option').toList();
    expect(written, hasLength(1));
    expect(written.single.name, 'Eldritch Invocation: Agonizing Blast');
    expect(written.single.description, isNotEmpty);
  });
}
