import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/quest_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late QuestRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = QuestRepository(db);
  });
  tearDown(() => db.close());

  test('create + update alanları yazar', () async {
    final id = await repo.create(title: 'Kayıp çocuk');
    await repo.update(
      id,
      questText: 'Çocuğu bul',
      reward: '200 altın',
      dmNotes: 'Aslında kaçmadı',
    );
    final q = (await repo.find(id))!;
    expect(q.title, 'Kayıp çocuk');
    expect(q.questText, 'Çocuğu bul');
    expect(q.reward, '200 altın');
    expect(q.dmNotes, 'Aslında kaçmadı');
    expect(q.done, isFalse);
    expect(q.shared, isFalse);
  });

  test('setShared hedefleri JSON olarak yazar, setDone', () async {
    final id = await repo.create();
    await repo.setShared(id, shared: true, targets: ['c1', 'c2']);
    var q = (await repo.find(id))!;
    expect(q.shared, isTrue);
    expect(QuestRepository.targetsOf(q), ['c1', 'c2']);

    await repo.setDone(id, true);
    q = (await repo.find(id))!;
    expect(q.done, isTrue);
    expect(q.shared, isTrue); // done shared'ı bozmaz
  });

  test('setAcceptance characterId→bool haritası biriktirir', () async {
    final id = await repo.create();
    await repo.setAcceptance(id, 'c1', true);
    await repo.setAcceptance(id, 'c2', false);
    await repo.setAcceptance(id, 'c1', false); // fikir değiştirme
    final acc = QuestRepository.acceptancesOf((await repo.find(id))!);
    expect(acc, {'c1': false, 'c2': false});
  });

  test('delete kaldırır', () async {
    final id = await repo.create();
    await repo.delete(id);
    expect(await repo.find(id), isNull);
  });

  test('watchAll tamamlanmışları sona sıralar', () async {
    final a = await repo.create(title: 'A');
    await repo.create(title: 'B');
    await repo.setDone(a, true);
    final list = await repo.watchAll().first;
    expect(list.length, 2);
    expect(list.last.title, 'A'); // done en sonda
  });
}
