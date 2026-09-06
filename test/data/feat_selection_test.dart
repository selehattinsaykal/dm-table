import 'package:dm_table/data/character_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/import/asset_importer.dart';
import 'package:dm_table/domain/models/ability.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Seviye atlamada feat secimi.
///
/// 2024 kuralinda ASI seviyelerinde "iki puan ya da bir feat" seciliyor;
/// pakette 150 feat vardi ama hicbiri karaktere verilemiyordu.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CharacterRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await AssetImporter(db).importIfNeeded();
    repo = CharacterRepository(db);
    await repo.createLevelOneCharacter(
      id: 'f1',
      name: 'Bryn',
      classKey: 'srd-2024_fighter',
      abilities: const AbilityScores(strength: 16),
      savingThrows: const {},
      skills: const {},
      hitDieSides: 10,
    );
  });

  tearDown(() async => db.close());

  test('seviye atlarken secilen feat kagida yazilir', () async {
    final feat = (await db.select(db.feats).get()).firstWhere(
      (f) => f.name == 'Tough',
    );

    await repo.levelUp(
      characterId: 'f1',
      classKey: 'srd-2024_fighter',
      featKey: feat.key,
    );

    final written = (await repo.features(
      'f1',
    )).where((f) => f.source == 'feat').toList();
    expect(written, hasLength(1));
    expect(written.single.name, 'Tough');
    expect(written.single.description, isNotEmpty);
    expect(written.single.featureKey, feat.key);
  });

  test('feat verilmezse kagitta feat satiri olusmaz', () async {
    await repo.levelUp(characterId: 'f1', classKey: 'srd-2024_fighter');
    expect(
      (await repo.features('f1')).where((f) => f.source == 'feat'),
      isEmpty,
    );
  });

  test('gecmisin verdigi koken feat kagida yazilir', () async {
    await repo.createLevelOneCharacter(
      id: 'f2',
      name: 'Acolyte',
      classKey: 'srd-2024_cleric',
      backgroundKey: 'srd-2024_acolyte',
      abilities: const AbilityScores(),
      savingThrows: const {},
      skills: const {},
      hitDieSides: 8,
      // Sihirbaz bunu gosteriyordu ama kagida yazmiyordu.
      originFeatName: 'Magic Initiate (Cleric)',
    );

    final feats = (await repo.features(
      'f2',
    )).where((f) => f.source == 'feat').toList();
    expect(feats, hasLength(1));
    expect(feats.single.name, 'Magic Initiate');
  });

  test('parantezli feat adi da bulunur', () async {
    expect(await repo.featKeyByName('Magic Initiate (Wizard)'), isNotNull);
    expect(await repo.featKeyByName('Boyle Bir Feat Yok'), isNull);
  });

  test('ayni feat iki kez yazilmaz', () async {
    final feat = (await db.select(db.feats).get()).firstWhere(
      (f) => f.name == 'Tough',
    );

    await repo.grantFeat('f1', feat.key);
    await repo.grantFeat('f1', feat.key);

    expect(
      (await repo.features('f1')).where((f) => f.source == 'feat'),
      hasLength(1),
    );
  });
}
