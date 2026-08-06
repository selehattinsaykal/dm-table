import 'package:dm_table/data/character_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/domain/models/ability.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// XP eklemesi (karsilasma odulu) toplam XP'yi artirir, negatife dusmez.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CharacterRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = CharacterRepository(db);
    await repo.createLevelOneCharacter(
      id: 'pc1',
      name: 'Rohan',
      classKey: 'srd-2024_fighter',
      abilities: const AbilityScores(),
      savingThrows: const {},
      skills: const {},
      hitDieSides: 10,
    );
  });

  tearDown(() async => db.close());

  test('XP eklenir ve birikir', () async {
    await repo.addExperience('pc1', 100);
    await repo.addExperience('pc1', 50);
    expect((await repo.find('pc1'))!.experiencePoints, 150);
  });

  test('negatif toplam 0 ile sinirli', () async {
    await repo.addExperience('pc1', 30);
    await repo.addExperience('pc1', -100);
    expect((await repo.find('pc1'))!.experiencePoints, 0);
  });

  test('0 eklemesi bir sey yapmaz', () async {
    await repo.addExperience('pc1', 0);
    expect((await repo.find('pc1'))!.experiencePoints, 0);
  });
}
