import 'package:drift/drift.dart';

import '../../db/database.dart';

/// Kullanicinin tanimladigi icerik kaynaklarini saklar.
///
/// Uygulama HICBIR adresle gelmiyor; bu depo yalnizca kullanicinin girdigi
/// adresleri hatirliyor.
class ContentSourceRepository {
  const ContentSourceRepository(this.db);

  final AppDatabase db;

  Stream<List<ContentSource>> watchAll() => (db.select(
    db.contentSources,
  )..orderBy([(t) => OrderingTerm(expression: t.createdAt)])).watch();

  Future<ContentSource> add({required String name, required String baseUrl}) {
    final row = ContentSourcesCompanion.insert(
      id: 'cs-${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      baseUrl: _normalize(baseUrl),
    );
    return db.into(db.contentSources).insertReturning(row);
  }

  Future<void> rename(String id, String name) =>
      (db.update(db.contentSources)..where((t) => t.id.equals(id))).write(
        ContentSourcesCompanion(name: Value(name.trim())),
      );

  Future<void> markImported(String id) =>
      (db.update(db.contentSources)..where((t) => t.id.equals(id))).write(
        ContentSourcesCompanion(lastImportedAt: Value(DateTime.now())),
      );

  Future<void> remove(String id) =>
      (db.delete(db.contentSources)..where((t) => t.id.equals(id))).go();

  /// Sondaki egik cizgiyi ve bosluklari atar.
  ///
  /// Yol birlestirme tek bir `/` varsayiyor; kullanicinin yapistirdigi adres
  /// cogu zaman egik cizgiyle bitiyor ve `//` ureten adres 404 donuyor.
  static String _normalize(String url) {
    final trimmed = url.trim();
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }
}
