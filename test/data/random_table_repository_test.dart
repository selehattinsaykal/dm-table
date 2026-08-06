import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/random_table_repository.dart';
import 'package:dm_table/domain/rules/random_table.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late RandomTableRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = RandomTableRepository(db);
  });

  tearDown(() => db.close());

  test('olusturur, gunceller, siler', () async {
    final id = await repo.create('Söylenti', diceSides: 12);
    var table = (await repo.find(id))!;
    expect(table.name, 'Söylenti');
    expect(table.diceSides, 12);

    await repo.update(
      id,
      name: 'Yeni ad',
      category: 'şehir',
      diceSides: 20,
      rows: distributeEvenly(['A', 'B'], 20),
    );
    table = (await repo.find(id))!;
    expect(table.name, 'Yeni ad');
    expect(table.category, 'şehir');
    expect(table.diceSides, 20);
    expect(RandomTableRepository.rowsOf(table), hasLength(2));

    await repo.delete(id);
    expect(await repo.find(id), isNull);
  });

  test('satir round-trip aralik ve metni korur', () async {
    final id = await repo.create('T');
    await repo.update(
      id,
      rows: [(min: 1, max: 5, text: 'İlk'), (min: 6, max: 20, text: 'İkinci')],
    );

    final rows = RandomTableRepository.rowsOf((await repo.find(id))!);
    expect(rows[0].min, 1);
    expect(rows[0].max, 5);
    expect(rows[0].text, 'İlk');
    expect(rows[1].max, 20);
  });

  test('bozuk rowsJson bos liste doner, firlatmaz', () {
    expect(RandomTableRepository.decodeRows('bu json degil'), isEmpty);
    expect(RandomTableRepository.decodeRows('{}'), isEmpty);
    // min/max sayi degilse o satir atlanir.
    expect(
      RandomTableRepository.decodeRows('[{"min":"a","max":2,"text":"X"}]'),
      isEmpty,
    );
  });

  group('ensureStarterTables', () {
    final starters = [
      (name: 'A', category: 'x', diceSides: 6, rows: ['1', '2', '3']),
      (name: 'B', category: 'y', diceSides: 20, rows: ['a', 'b']),
    ];

    test('bos veritabanini tohumlar ve araliklari dagitir', () async {
      await repo.ensureStarterTables(starters);
      final all = await repo.all();
      expect(all, hasLength(2));

      final a = all.firstWhere((t) => t.name == 'A');
      final rows = RandomTableRepository.rowsOf(a);
      expect(rows, hasLength(3));
      // Tohumlanan tablo bosluksuz/cakismasiz olmali.
      expect(validateRows(rows, a.diceSides), isEmpty);
      expect(rows.last.max, 6);
    });

    test('iki kez cagrilinca cogaltmaz', () async {
      await repo.ensureStarterTables(starters);
      await repo.ensureStarterTables(starters);
      expect(await repo.all(), hasLength(2));
    });

    test('kullanicinin tablosu varsa hic tohumlamaz', () async {
      await repo.create('Kendi tablom');
      await repo.ensureStarterTables(starters);

      final all = await repo.all();
      expect(all, hasLength(1));
      expect(all.single.name, 'Kendi tablom');
    });
  });
}
