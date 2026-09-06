import 'dart:convert';

import 'package:dm_table/data/clock_repository.dart';
import 'package:dm_table/data/codex_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/export_service.dart';
import 'package:dm_table/data/quest_repository.dart';
import 'package:dm_table/data/world_repository.dart';
import 'package:dm_table/domain/codex/codex_block.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Acik bicim disa aktarimi.
///
/// **Neden onemli:** bu ciktilar geri YUKLENMIYOR, yani bozuk bir cikti
/// sessizce kaybolur -- kimse bir daha ice aktarmadigi icin hata da vermez.
/// Tek koruma bu testler.
void main() {
  late AppDatabase db;
  late ExportService export;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    export = ExportService(db);
  });

  tearDown(() async => db.close());

  group('Kayitlar -> Markdown', () {
    late CodexRepository codex;

    setUp(() => codex = CodexRepository(db));

    test('sayfa hiyerarsisi baslik seviyesine donusur', () async {
      final root = await codex.createPage(title: 'Dünya');
      final child = await codex.createPage(title: 'Şehir', parentId: root);
      await codex.createPage(title: 'Han', parentId: child);

      final md = await export.codexToMarkdown();

      expect(md, contains('# Dünya'));
      expect(md, contains('## Şehir'));
      expect(md, contains('### Han'));
    });

    test('metin, madde ve onay kutusu bloklari cevrilir', () async {
      final page = await codex.createPage(title: 'Notlar');
      await codex.addBlock(
        page,
        CodexBlockType.text,
        data: {'text': 'Kervan üç gün gecikti.'},
      );
      await codex.addBlock(
        page,
        CodexBlockType.bulleted,
        data: {
          'items': ['Gundren', 'Sildar'],
        },
      );
      await codex.addBlock(
        page,
        CodexBlockType.checklist,
        data: {
          'items': [
            {'text': 'Haritayı çiz', 'done': true},
            {'text': 'NPC adı bul', 'done': false},
          ],
        },
      );

      final md = await export.codexToMarkdown();

      expect(md, contains('Kervan üç gün gecikti.'));
      expect(md, contains('- Gundren'));
      expect(md, contains('- [x] Haritayı çiz'));
      expect(md, contains('- [ ] NPC adı bul'));
    });

    test('tablo blogu gecerli Markdown tablosu uretir', () async {
      final page = await codex.createPage(title: 'Tablo');
      await codex.addBlock(
        page,
        CodexBlockType.table,
        data: {
          'header': true,
          'rows': [
            ['Zar', 'Sonuç'],
            ['1', 'Goblin'],
          ],
        },
      );

      final md = await export.codexToMarkdown();

      expect(md, contains('| Zar | Sonuç |'));
      // Ayrac satiri OLMADAN Markdown bunu tablo saymaz.
      expect(md, contains('| --- | --- |'));
      expect(md, contains('| 1 | Goblin |'));
    });

    test('bos blok atlanir, belge bosluklarla dolmaz', () async {
      final page = await codex.createPage(title: 'Boş');
      await codex.addBlock(
        page,
        CodexBlockType.pageLink,
        data: {'pageId': 'yok'},
      );

      final md = await export.codexToMarkdown();

      expect(md.trim(), '# Boş');
    });
  });

  group('kampanya -> JSON', () {
    test('kullanicinin yazdigi kayitlar cikar, kutuphane cikmaz', () async {
      final world = WorldRepository(db);
      final faction = await world.createFaction(
        name: 'Kızıl Hançerler',
        kind: 'çete',
      );
      final npc = await world.createNpc(name: 'Gundren', role: 'madenci');
      await world.createLink(
        npc,
        faction,
        xKind: 'npc',
        yKind: 'faction',
        type: 'membership',
      );

      final quests = QuestRepository(db);
      final quest = await quests.create(title: 'Kayıp kervan');
      await quests.setTargets(quest, ['char-1']);

      await ClockRepository(db).create(name: 'Kuşatma', segments: 4);

      final json = await export.campaignToJson();

      expect(json['formatVersion'], ExportService.formatVersion);
      expect((json['factions'] as List).single['name'], 'Kızıl Hançerler');
      expect((json['npcs'] as List).single['role'], 'madenci');
      expect((json['bonds'] as List).single['type'], 'membership');
      expect((json['quests'] as List).single['owners'], ['char-1']);
      expect((json['clocks'] as List).single['segments'], 4);
      // SRD kutuphanesi disa aktarilmiyor: kullanicinin yazdigi sey degil.
      expect(json.containsKey('monsters'), isFalse);
      expect(json.containsKey('spells'), isFalse);
    });

    test('cikti gecerli JSON metnine serilesir', () async {
      await WorldRepository(db).createNpc(name: 'Sildar');

      final text = await export.campaignToJsonString();
      final parsed = jsonDecode(text) as Map<String, dynamic>;

      expect((parsed['npcs'] as List).single['name'], 'Sildar');
    });

    test('bos kampanyada bile butun anahtarlar var', () async {
      final json = await export.campaignToJson();
      for (final key in [
        'characters',
        'locations',
        'npcs',
        'factions',
        'bonds',
        'quests',
        'clocks',
        'sessionLog',
      ]) {
        expect(json[key], isEmpty, reason: '$key eksik ya da bos degil');
      }
    });
  });
}
