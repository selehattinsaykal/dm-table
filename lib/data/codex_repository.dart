import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/codex/codex_block.dart';
import 'db/database.dart';

/// Kayitlar aramasinda bir sonuc: eslesen sayfa + gosterilecek metin parcasi.
class CodexSearchHit {
  const CodexSearchHit({required this.page, required this.snippet});

  final CodexPage page;
  final String snippet;
}

/// DM bilgi tabaninin ("Kayitlar") veri katmani: sayfa agaci + bloklar.
class CodexRepository {
  CodexRepository(this.db);

  final AppDatabase db;

  static const _uuid = Uuid();

  // --- Sayfalar ------------------------------------------------------------

  /// Tum sayfalar (agac istemci tarafinda kuruluyor).
  Stream<List<CodexPage>> watchPages() =>
      (db.select(db.codexPages)..orderBy([
            (t) => OrderingTerm(expression: t.sortOrder),
            (t) => OrderingTerm(expression: t.title),
          ]))
          .watch();

  Stream<CodexPage?> watchPage(String id) => (db.select(
    db.codexPages,
  )..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<CodexPage?> findPage(String id) => (db.select(
    db.codexPages,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Basligi [title] ile (buyuk/kucuk harf duyarsiz) eslesen ilk sayfa.
  /// Wiki baglantilari ([[Baslik]]) icin.
  Future<CodexPage?> findPageByTitle(String title) async {
    final needle = title.trim().toLowerCase();
    if (needle.isEmpty) return null;
    final pages = await db.select(db.codexPages).get();
    return pages
        .where((p) => p.title.trim().toLowerCase() == needle)
        .firstOrNull;
  }

  Future<String> createPage({String title = '', String? parentId}) async {
    final id = 'pg-${_uuid.v4()}';
    final siblings =
        await (db.select(db.codexPages)..where(
              (t) => parentId == null
                  ? t.parentId.isNull()
                  : t.parentId.equals(parentId),
            ))
            .get();
    await db
        .into(db.codexPages)
        .insert(
          CodexPagesCompanion.insert(
            id: id,
            title: Value(title),
            parentId: Value(parentId),
            sortOrder: Value(siblings.length),
          ),
        );
    return id;
  }

  Future<void> renamePage(String id, String title) =>
      _touch(id, CodexPagesCompanion(title: Value(title)));

  Future<void> setIcon(String id, String? icon) =>
      _touch(id, CodexPagesCompanion(icon: Value(icon)));

  Future<void> _touch(String id, CodexPagesCompanion companion) async {
    await (db.update(db.codexPages)..where((t) => t.id.equals(id))).write(
      companion.copyWith(updatedAt: Value(DateTime.now())),
    );
  }

  /// Sayfayi VE tum alt sayfalarini (bloklariyla) siler.
  Future<void> deletePage(String id) async {
    final all = await db.select(db.codexPages).get();
    final childrenOf = <String, List<String>>{};
    for (final p in all) {
      if (p.parentId != null) {
        (childrenOf[p.parentId!] ??= []).add(p.id);
      }
    }
    final toDelete = <String>[];
    final queue = [id];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      toDelete.add(current);
      queue.addAll(childrenOf[current] ?? const []);
    }
    await db.transaction(() async {
      await (db.delete(
        db.codexBlocks,
      )..where((t) => t.pageId.isIn(toDelete))).go();
      await (db.delete(db.codexPages)..where((t) => t.id.isIn(toDelete))).go();
    });
  }

  // --- Bloklar -------------------------------------------------------------

  Stream<List<CodexBlock>> watchBlocks(String pageId) =>
      (db.select(db.codexBlocks)
            ..where((t) => t.pageId.equals(pageId))
            ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
          .watch();

  Future<List<CodexBlock>> blocks(String pageId) =>
      (db.select(db.codexBlocks)
            ..where((t) => t.pageId.equals(pageId))
            ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
          .get();

  Future<String> addBlock(
    String pageId,
    CodexBlockType type, {
    Map<String, dynamic> data = const {},
  }) async {
    final id = 'bl-${_uuid.v4()}';
    final existing = await blocks(pageId);
    await db
        .into(db.codexBlocks)
        .insert(
          CodexBlocksCompanion.insert(
            id: id,
            pageId: pageId,
            type: type.name,
            sortOrder: Value(existing.length),
            dataJson: Value(jsonEncode(data)),
          ),
        );
    await _touch(pageId, const CodexPagesCompanion());
    return id;
  }

  Future<void> updateBlock(String blockId, Map<String, dynamic> data) async {
    await (db.update(db.codexBlocks)..where((t) => t.id.equals(blockId))).write(
      CodexBlocksCompanion(dataJson: Value(jsonEncode(data))),
    );
  }

  Future<void> deleteBlock(String blockId) async {
    await (db.delete(db.codexBlocks)..where((t) => t.id.equals(blockId))).go();
  }

  /// Bloklari serbestce yeniden siralar (surukle-birak). [newIndex] ogenin
  /// cikarilmasindan SONRAKI hedef indekstir (ReorderableListView.onReorderItem
  /// semantigi). Tum bloklarin sortOrder'i yeni sirayla bastan yazilir.
  Future<void> reorderBlock(String pageId, int oldIndex, int newIndex) async {
    final rows = await blocks(pageId);
    if (oldIndex < 0 || oldIndex >= rows.length) return;
    final item = rows.removeAt(oldIndex);
    rows.insert(newIndex.clamp(0, rows.length), item);
    await db.batch((b) {
      for (var i = 0; i < rows.length; i++) {
        b.update(
          db.codexBlocks,
          CodexBlocksCompanion(sortOrder: Value(i)),
          where: (t) => t.id.equals(rows[i].id),
        );
      }
    });
  }

  /// Metin arama: basligi ya da herhangi bir blok icerigi [query] iceren
  /// sayfalar (buyuk/kucuk harf duyarsiz). Her sonuc bir eslesme parcasi tasir.
  Future<List<CodexSearchHit>> search(String query) async {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const [];
    final pages = await db.select(db.codexPages).get();
    final allBlocks = await db.select(db.codexBlocks).get();
    final blocksByPage = <String, List<CodexBlock>>{};
    for (final b in allBlocks) {
      (blocksByPage[b.pageId] ??= []).add(b);
    }

    final hits = <CodexSearchHit>[];
    for (final page in pages) {
      if (page.title.toLowerCase().contains(needle)) {
        hits.add(CodexSearchHit(page: page, snippet: page.title));
        continue;
      }
      String? snippet;
      for (final b in blocksByPage[page.id] ?? const <CodexBlock>[]) {
        final lower = b.dataJson.toLowerCase();
        if (lower.contains(needle)) {
          snippet = _snippetOf(b.dataJson, needle);
          break;
        }
      }
      if (snippet != null) {
        hits.add(CodexSearchHit(page: page, snippet: snippet));
      }
    }
    return hits;
  }

  /// dataJson icinden okunur bir parca cikarir (JSON kabugu degil, deger metni).
  String _snippetOf(String dataJson, String needle) {
    // JSON'daki tirnakli degerleri toparlayip ilk eslesmeyi gosteriyoruz.
    final matches = RegExp(r'"([^"]*)"').allMatches(dataJson);
    for (final m in matches) {
      final value = m.group(1) ?? '';
      if (value.toLowerCase().contains(needle) && value.length > 1) {
        return value;
      }
    }
    return dataJson;
  }

  /// Blogu bir yukari/asagi tasir (komsuyla sortOrder degistokusu).
  Future<void> moveBlock(
    String pageId,
    String blockId, {
    required bool up,
  }) async {
    final rows = await blocks(pageId);
    final index = rows.indexWhere((b) => b.id == blockId);
    if (index < 0) return;
    final swapIndex = up ? index - 1 : index + 1;
    if (swapIndex < 0 || swapIndex >= rows.length) return;

    final a = rows[index];
    final b = rows[swapIndex];
    await db.transaction(() async {
      await (db.update(db.codexBlocks)..where((t) => t.id.equals(a.id))).write(
        CodexBlocksCompanion(sortOrder: Value(b.sortOrder)),
      );
      await (db.update(db.codexBlocks)..where((t) => t.id.equals(b.id))).write(
        CodexBlocksCompanion(sortOrder: Value(a.sortOrder)),
      );
    });
  }
}
