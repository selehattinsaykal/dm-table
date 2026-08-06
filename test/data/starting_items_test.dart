import 'package:dm_table/data/character_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/domain/models/ability.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Karakter olustururken secilen baslangic ekipmani envantere KALICI yazilmali.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CharacterRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = CharacterRepository(db);
  });

  tearDown(() => db.close());

  test('baslangic esyalari CharacterItems tablosuna yazilir', () async {
    final id = await repo.createLevelOneCharacter(
      id: 'c1',
      name: 'Rohan',
      classKey: 'rogue',
      abilities: const AbilityScores(),
      savingThrows: const {},
      skills: const {},
      hitDieSides: 8,
      startingGoldGp: 16,
      startingItems: const [
        (name: 'Dagger', quantity: 2),
        (name: "Thieves' Tools", quantity: 1),
      ],
    );

    final items = await repo.items(id);
    expect(items.length, 2);

    final dagger = items.firstWhere((i) => i.customName == 'Dagger');
    expect(dagger.quantity, 2);
    // Kutuphane anahtari degil serbest metin (SRD ekipmani metin geliyor).
    expect(dagger.itemKey, isNull);
    expect(dagger.magicItemKey, isNull);

    final tools = items.firstWhere((i) => i.customName == "Thieves' Tools");
    expect(tools.quantity, 1);

    // Altin da yazilmali.
    final character = await (db.select(
      db.characters,
    )..where((t) => t.id.equals(id))).getSingle();
    expect(character.coinsCp, 1600);
  });

  test('ekipman secilmezse envanter bos kalir', () async {
    final id = await repo.createLevelOneCharacter(
      id: 'c2',
      name: 'Boş',
      classKey: 'fighter',
      abilities: const AbilityScores(),
      savingThrows: const {},
      skills: const {},
      hitDieSides: 10,
    );
    expect(await repo.items(id), isEmpty);
  });
}
