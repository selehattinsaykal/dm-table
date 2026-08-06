import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/rules/random_table.dart';
import 'db/database.dart';

/// Rastgele tablolari okur/yazar. `LootRepository` ile ayni sekil.
class RandomTableRepository {
  RandomTableRepository(this.db);

  final AppDatabase db;
  static const _uuid = Uuid();

  Stream<List<RandomTable>> watchAll() =>
      (db.select(db.randomTables)..orderBy([
            (t) => OrderingTerm(expression: t.sortOrder),
            (t) => OrderingTerm(expression: t.name),
          ]))
          .watch();

  Future<List<RandomTable>> all() =>
      (db.select(db.randomTables)..orderBy([
            (t) => OrderingTerm(expression: t.sortOrder),
            (t) => OrderingTerm(expression: t.name),
          ]))
          .get();

  Stream<RandomTable?> watchOne(String id) => (db.select(
    db.randomTables,
  )..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<RandomTable?> find(String id) => (db.select(
    db.randomTables,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<String> create(String name, {int diceSides = 20}) async {
    final id = 'rt-${_uuid.v4()}';
    final count = (await all()).length;
    await db
        .into(db.randomTables)
        .insert(
          RandomTablesCompanion.insert(
            id: id,
            name: name,
            diceSides: Value(diceSides),
            sortOrder: Value(count),
          ),
        );
    return id;
  }

  Future<void> update(
    String id, {
    String? name,
    String? category,
    int? diceSides,
    List<RandomTableRow>? rows,
  }) => (db.update(db.randomTables)..where((t) => t.id.equals(id))).write(
    RandomTablesCompanion(
      name: name == null ? const Value.absent() : Value(name),
      category: category == null ? const Value.absent() : Value(category),
      diceSides: diceSides == null ? const Value.absent() : Value(diceSides),
      rowsJson: rows == null ? const Value.absent() : Value(encodeRows(rows)),
    ),
  );

  Future<void> delete(String id) =>
      (db.delete(db.randomTables)..where((t) => t.id.equals(id))).go();

  /// Tablonun satirlari. Bozuk JSON'da bos liste doner (firlatmaz).
  static List<RandomTableRow> rowsOf(RandomTable table) =>
      decodeRows(table.rowsJson);

  static List<RandomTableRow> decodeRows(String json) {
    try {
      final data = jsonDecode(json);
      if (data is! List) return const [];
      final out = <RandomTableRow>[];
      for (final e in data) {
        if (e is! Map) continue;
        final min = e['min'];
        final max = e['max'];
        if (min is! int || max is! int) continue;
        out.add((min: min, max: max, text: e['text'] as String? ?? ''));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  static String encodeRows(List<RandomTableRow> rows) => jsonEncode([
    for (final r in rows) {'min': r.min, 'max': r.max, 'text': r.text},
  ]);

  /// Ilk acilista hazir tablolari tohumlar (`ensureDefaultCalendar` deseni).
  ///
  /// Zaten tablo varsa hicbir sey yapmaz; iki kez cagrilmasi guvenlidir.
  Future<void> ensureStarterTables(
    List<({String name, String category, int diceSides, List<String> rows})>
    starters,
  ) async {
    if ((await all()).isNotEmpty) return;
    await db.batch((b) {
      for (final (i, starter) in starters.indexed) {
        b.insert(
          db.randomTables,
          RandomTablesCompanion.insert(
            id: 'rt-seed-$i',
            name: starter.name,
            category: Value(starter.category),
            diceSides: Value(starter.diceSides),
            rowsJson: Value(
              encodeRows(distributeEvenly(starter.rows, starter.diceSides)),
            ),
            sortOrder: Value(i),
          ),
        );
      }
    });
  }
}
