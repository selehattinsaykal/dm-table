import 'package:dm_table/data/character_repository.dart';
import 'package:dm_table/data/combat_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/shop_repository.dart';
import 'package:dm_table/data/world_repository.dart';
import 'package:dm_table/domain/rules/dice.dart';
import 'package:dm_table/features/session/session_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Paylasilan gunluge itilen her atis artan bir `seq` almali; istemci "yeni
/// atis"i ve kendi atisini bununla ayirt ediyor.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('pushRoll her atisa artan seq atar', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final session = SessionService(
      db: db,
      characters: CharacterRepository(db),
      combat: CombatRepository(db),
      shops: ShopRepository(db),
      world: WorldRepository(db),
    );

    DiceRoll roll(String source) => DiceRoll(
      label: 'd20',
      sides: 20,
      count: 1,
      modifier: 0,
      results: const [12],
      total: 12,
      source: source,
    );

    // Sunucu yokken de pushRoll calisir (broadcast no-op).
    await session.pushRoll(roll('Selim'));
    await session.pushRoll(roll('Ayşe'));

    final rolls = (await session.buildSnapshot()).rolls;
    expect(rolls.length, 2);
    expect(rolls[0].seq, 1);
    expect(rolls[1].seq, 2);
    // Kaynak korunur.
    expect(rolls[0].source, 'Selim');
    expect(rolls[1].source, 'Ayşe');
  });
}
