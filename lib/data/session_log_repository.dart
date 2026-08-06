import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'db/database.dart';

/// Kalici oturum gunlugu (XP verildi, elle not vb.).
class SessionLogRepository {
  SessionLogRepository(this.db);

  final AppDatabase db;

  static const _uuid = Uuid();

  /// En yeni en ustte; [limit] son kayit.
  Stream<List<SessionLogEntry>> watchRecent({int limit = 100}) =>
      (db.select(db.sessionLogEntries)
            ..orderBy([
              (t) =>
                  OrderingTerm(expression: t.sortKey, mode: OrderingMode.desc),
            ])
            ..limit(limit))
          .watch();

  Future<void> add(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await db
        .into(db.sessionLogEntries)
        .insert(
          SessionLogEntriesCompanion.insert(
            id: _uuid.v4(),
            message: trimmed,
            sortKey: Value(DateTime.now().microsecondsSinceEpoch),
          ),
        );
  }

  Future<void> deleteEntry(String id) async {
    await (db.delete(db.sessionLogEntries)..where((t) => t.id.equals(id))).go();
  }

  Future<void> clear() async {
    await db.delete(db.sessionLogEntries).go();
  }
}
