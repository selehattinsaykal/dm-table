import 'dart:convert';

import 'package:dm_table/data/custom_content_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/db/tables.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// DM kendi buyusunu kutuphaneye ekleyebilmeli: filtre kolonlari (seviye,
/// okul, konsantrasyon, ritual) ve detay icin dataJson dogru yazilmali.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CustomContentRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = CustomContentRepository(db);
  });

  tearDown(() => db.close());

  test('addSpell filtre kolonlarini ve dataJson\'i dogru yazar', () async {
    final key = await repo.addSpell(
      name: 'Yıldız Oku',
      level: 3,
      school: 'Evocation',
      castingTime: '1 action',
      rangeText: '120 feet',
      duration: 'Instantaneous',
      verbal: true,
      somatic: true,
      concentration: true,
      description: 'Bir ışık oku fırlatır.',
      classes: const ['wizard', 'sorcerer'],
    );

    final row = await (db.select(
      db.spells,
    )..where((t) => t.key.equals(key))).getSingle();

    // Kolonlar (arama/filtre bunlari kullaniyor).
    expect(row.name, 'Yıldız Oku');
    expect(row.level, 3);
    expect(row.school, 'Evocation');
    expect(row.concentration, isTrue);
    expect(row.ritual, isFalse);
    expect(row.sourceType, SourceType.custom);
    expect(row.classesCsv, 'wizard,sorcerer');

    // dataJson (detay ekrani bunlari okuyor).
    final data = jsonDecode(row.dataJson) as Map<String, dynamic>;
    expect(data['casting_time'], '1 action');
    expect(data['range_text'], '120 feet');
    expect(data['duration'], 'Instantaneous');
    expect(data['verbal'], true);
    expect(data['somatic'], true);
    expect(data['concentration'], true);
    expect(data['desc'], 'Bir ışık oku fırlatır.');
  });
}
