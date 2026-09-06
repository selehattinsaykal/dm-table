import 'package:dm_table/data/codex_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/domain/codex/codex_block.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// DM bilgi tabani: sayfa agaci + blok CRUD/siralama.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CodexRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = CodexRepository(db);
  });

  tearDown(() async => db.close());

  group('sayfalar', () {
    test('kok sayfa olusur, alt sayfa parentId alir', () async {
      final root = await repo.createPage(title: 'Dünya');
      final child = await repo.createPage(title: 'Şehir', parentId: root);

      expect((await repo.findPage(root))!.parentId, isNull);
      expect((await repo.findPage(child))!.parentId, root);
    });

    test('findPageByTitle buyuk/kucuk harf duyarsiz', () async {
      final id = await repo.createPage(title: 'Ejderha');
      expect((await repo.findPageByTitle('ejderha'))?.id, id);
      expect((await repo.findPageByTitle('EJDERHA'))?.id, id);
      expect(await repo.findPageByTitle('yok'), isNull);
    });

    test('yeniden adlandirma ve simge', () async {
      final id = await repo.createPage();
      await repo.renamePage(id, 'Yeni');
      await repo.setIcon(id, '🏰');
      final p = (await repo.findPage(id))!;
      expect(p.title, 'Yeni');
      expect(p.icon, '🏰');
    });

    test('silme alt sayfalari ve bloklari da siler', () async {
      final root = await repo.createPage(title: 'Kök');
      final child = await repo.createPage(parentId: root);
      await repo.addBlock(root, CodexBlockType.text, data: {'text': 'a'});
      await repo.addBlock(child, CodexBlockType.text, data: {'text': 'b'});

      await repo.deletePage(root);

      expect(await repo.findPage(root), isNull);
      expect(await repo.findPage(child), isNull);
      expect(await repo.blocks(root), isEmpty);
      expect(await repo.blocks(child), isEmpty);
    });
  });

  group('bloklar', () {
    test('eklenen bloklar sirali', () async {
      final page = await repo.createPage();
      await repo.addBlock(page, CodexBlockType.heading, data: {'text': 'A'});
      await repo.addBlock(page, CodexBlockType.text, data: {'text': 'B'});
      await repo.addBlock(page, CodexBlockType.divider);

      final rows = await repo.blocks(page);
      expect(rows.map((b) => b.type), ['heading', 'text', 'divider']);
      expect(rows.map((b) => b.sortOrder), [0, 1, 2]);
    });

    test('updateBlock veriyi degistirir', () async {
      final page = await repo.createPage();
      final id = await repo.addBlock(
        page,
        CodexBlockType.text,
        data: {'text': 'eski'},
      );
      await repo.updateBlock(id, {'text': 'yeni'});
      expect((await repo.blocks(page)).single.dataJson, contains('yeni'));
    });

    test('duplicateBlock kopyayi hemen ardina koyar', () async {
      final page = await repo.createPage();
      await repo.addBlock(page, CodexBlockType.text, data: {'text': 'A'});
      final b = await repo.addBlock(
        page,
        CodexBlockType.text,
        data: {'text': 'B', 'width': 0.5},
      );
      await repo.addBlock(page, CodexBlockType.text, data: {'text': 'C'});

      final copyId = await repo.duplicateBlock(b);

      final rows = await repo.blocks(page);
      expect(rows.map((r) => r.id).toList()[2], copyId);
      // Kopya kaynagin verisini (yerlesim dahil) aynen tasir.
      expect(rows[2].dataJson, rows[1].dataJson);
      expect(rows.map((r) => r.sortOrder), [0, 1, 2, 3]);
      expect(rows.last.dataJson, contains('C'));
    });

    test('duplicateBlock olmayan blok icin null doner', () async {
      expect(await repo.duplicateBlock('bl-yok'), isNull);
    });

    test('moveBlock komsuyla yer degistirir', () async {
      final page = await repo.createPage();
      final a = await repo.addBlock(
        page,
        CodexBlockType.text,
        data: {'text': 'A'},
      );
      await repo.addBlock(page, CodexBlockType.text, data: {'text': 'B'});

      await repo.moveBlock(page, a, up: false); // A asagi

      final rows = await repo.blocks(page);
      expect(rows.first.dataJson, contains('B'));
      expect(rows.last.dataJson, contains('A'));
    });

    test('sinirdaki blok tasinmaz', () async {
      final page = await repo.createPage();
      final a = await repo.addBlock(page, CodexBlockType.text);
      await repo.moveBlock(page, a, up: true); // zaten en ustte
      expect((await repo.blocks(page)).first.id, a);
    });

    test('deleteBlock siler', () async {
      final page = await repo.createPage();
      final id = await repo.addBlock(page, CodexBlockType.text);
      await repo.deleteBlock(id);
      expect(await repo.blocks(page), isEmpty);
    });

    test('reorderBlock ilki sona tasir (onReorderItem semantigi)', () async {
      final page = await repo.createPage();
      await repo.addBlock(page, CodexBlockType.text, data: {'text': 'A'});
      await repo.addBlock(page, CodexBlockType.text, data: {'text': 'B'});
      await repo.addBlock(page, CodexBlockType.text, data: {'text': 'C'});

      await repo.reorderBlock(page, 0, 2); // A -> sona

      final rows = await repo.blocks(page);
      expect(rows.map((b) => b.dataJson.contains('A')), [false, false, true]);
      expect(rows.map((b) => b.sortOrder), [
        0,
        1,
        2,
      ]); // sortOrder yeniden yazilir
    });

    test('reorderBlock sonuncuyu basa tasir', () async {
      final page = await repo.createPage();
      await repo.addBlock(page, CodexBlockType.text, data: {'text': 'A'});
      await repo.addBlock(page, CodexBlockType.text, data: {'text': 'B'});
      await repo.addBlock(page, CodexBlockType.text, data: {'text': 'C'});

      await repo.reorderBlock(page, 2, 0); // C -> basa

      final rows = await repo.blocks(page);
      expect(rows.first.dataJson, contains('C'));
    });
  });

  group('arama', () {
    test('baslikla eslesir', () async {
      final id = await repo.createPage(title: 'Ejderha Yuvası');
      final hits = await repo.search('ejder');
      expect(hits.map((h) => h.page.id), contains(id));
    });

    test('blok icerigiyle eslesir ve parca doner', () async {
      final id = await repo.createPage(title: 'Notlar');
      await repo.addBlock(
        id,
        CodexBlockType.text,
        data: {'text': 'gizli hazine odası'},
      );
      final hits = await repo.search('hazine');
      final hit = hits.firstWhere((h) => h.page.id == id);
      expect(hit.snippet, 'gizli hazine odası');
    });

    test('eslesme yoksa bos', () async {
      await repo.createPage(title: 'Bir şey');
      expect(await repo.search('bulunmayan'), isEmpty);
    });

    test('bos sorgu bos doner', () async {
      await repo.createPage(title: 'X');
      expect(await repo.search('   '), isEmpty);
    });
  });
}
