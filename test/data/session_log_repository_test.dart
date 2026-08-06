import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/session_log_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kalici oturum gunlugu: ekle / en-yeni-ustte listele / sil / temizle.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SessionLogRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = SessionLogRepository(db);
  });

  tearDown(() async => db.close());

  test('eklenen kayit en yeni ustte listelenir', () async {
    await repo.add('İlk');
    await repo.add('İkinci');

    final rows = await repo.watchRecent().first;
    expect(rows.length, 2);
    expect(rows.first.message, 'İkinci'); // en yeni ustte
    expect(rows.last.message, 'İlk');
  });

  test('bos/bosluk metin eklenmez', () async {
    await repo.add('   ');
    await repo.add('');
    expect(await repo.watchRecent().first, isEmpty);
  });

  test('tek kayit silinir', () async {
    await repo.add('Kalacak');
    await repo.add('Silinecek');
    final rows = await repo.watchRecent().first;
    final toDelete = rows.firstWhere((r) => r.message == 'Silinecek');

    await repo.deleteEntry(toDelete.id);

    final after = await repo.watchRecent().first;
    expect(after.map((r) => r.message), ['Kalacak']);
  });

  test('temizle hepsini siler', () async {
    await repo.add('a');
    await repo.add('b');
    await repo.clear();
    expect(await repo.watchRecent().first, isEmpty);
  });
}
