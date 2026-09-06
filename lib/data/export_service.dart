import 'dart:convert';

import 'package:drift/drift.dart';

import 'codex_repository.dart';
import 'db/database.dart';
import 'quest_repository.dart';

/// Kampanyayi uygulamanin DISINDA okunabilir bicimlere cevirir.
///
/// **Neden var:** yedek arsivi (`BackupRepository`) yalnizca bu uygulamaya
/// geri yuklenebiliyor -- kapali bir bicim. Aylarca yazilmis notlarin tek
/// kopyasinin okumak icin bu uygulamayi gerektirmesi kabul edilebilir degil.
/// Burasi yedegin AYNISI DEGIL, tamamlayicisi: geri YUKLENMEZ, ama her yerde
/// acilir.
///
/// Iki bicim iki farkli soruyu cevapliyor:
///  * **Markdown** — insan icin. Kayitlar sayfalari Obsidian/Notion/herhangi
///    bir editorde okunacak sekilde disari cikar.
///  * **JSON** — makine icin. Kampanyanin yapisal ozeti; baska bir arac ya
///    da betik icin.
///
/// Ikisi de MEDYA TASIMAZ (gorsel, ses, video): dosya yollari metinde
/// gorunur ama ikili icerik yedegin isi. Aksi halde "disa aktar" sessizce
/// yuzlerce megabayt uretirdi.
class ExportService {
  ExportService(this.db) : _codex = CodexRepository(db);

  final AppDatabase db;
  final CodexRepository _codex;

  // --- Markdown -----------------------------------------------------------

  /// Tum Kayitlar agacini tek bir Markdown belgesine cevirir.
  ///
  /// Sayfa hiyerarsisi baslik SEVIYESINE donusuyor: kok sayfa `#`, cocugu
  /// `##`... Boylece agac duz metinde de agac olarak okunuyor. Altinci
  /// seviyeden sonra Markdown'da baslik yok, o yuzden derinlik orada
  /// sabitleniyor.
  Future<String> codexToMarkdown() async {
    final pages = await (db.select(
      db.codexPages,
    )..orderBy([(t) => OrderingTerm(expression: t.sortOrder)])).get();

    final byParent = <String?, List<CodexPage>>{};
    for (final page in pages) {
      (byParent[page.parentId] ??= []).add(page);
    }

    final out = StringBuffer();
    Future<void> writePage(CodexPage page, int depth) async {
      final hashes = '#' * (depth + 1).clamp(1, 6);
      final icon = (page.icon ?? '').isEmpty ? '' : '${page.icon} ';
      out.writeln('$hashes $icon${page.title.isEmpty ? '—' : page.title}');
      out.writeln();

      for (final block in await _codex.blocks(page.id)) {
        final text = blockToMarkdown(block);
        if (text.isEmpty) continue;
        out.writeln(text);
        out.writeln();
      }

      for (final child in byParent[page.id] ?? const <CodexPage>[]) {
        await writePage(child, depth + 1);
      }
    }

    for (final root in byParent[null] ?? const <CodexPage>[]) {
      await writePage(root, 0);
    }
    return out.toString().trimRight();
  }

  /// Tek bir blogun Markdown karsiligi; bos donerse blok atlanir.
  ///
  /// Etkilesimli bloklar (zar, sayac, sure sayaci) STATIK metne dusuyor --
  /// disari cikan bir belgede tiklanacak bir sey yok, ama DM'in ne yazdigi
  /// korunmali.
  static String blockToMarkdown(CodexBlock block) {
    final data = _decode(block.dataJson);
    String s(String key) => '${data[key] ?? ''}';

    switch (block.type) {
      case 'heading':
        final level = (data['level'] as int? ?? 1).clamp(1, 6);
        return '${'#' * level} ${s('text')}';
      case 'text':
        return s('text');
      case 'bulleted':
        return [for (final i in _list(data['items'])) '- $i'].join('\n');
      case 'checklist':
        return [
          for (final i in _list(data['items'], raw: true))
            if (i is Map)
              '- [${i['done'] == true ? 'x' : ' '}] ${i['text'] ?? ''}',
        ].join('\n');
      case 'callout':
        // Markdown'da uyari kutusu yok; alinti blogu en yakin karsiligi.
        final emoji = s('emoji');
        return '> ${emoji.isEmpty ? '' : '$emoji '}${s('text')}';
      case 'divider':
        return '---';
      case 'image':
        return '![${s('caption')}](${s('path')})';
      case 'video':
        final caption = s('caption');
        return '[${caption.isEmpty ? 'video' : caption}](${s('path')})';
      case 'link':
        final label = s('label');
        return '[${label.isEmpty ? s('url') : label}](${s('url')})';
      case 'table':
        return _tableToMarkdown(data);
      case 'dice':
        final label = s('label');
        return '`${s('expression')}`${label.isEmpty ? '' : ' — $label'}';
      case 'chart':
        return _labelledValuesToMarkdown(s('title'), data['items']);
      case 'counter':
        return _labelledValuesToMarkdown(s('title'), data['items']);
      case 'timer':
        final title = s('title');
        final seconds = data['duration'] as int? ?? 0;
        return '**${title.isEmpty ? 'Timer' : title}** — ${seconds}s';
      case 'pageLink':
      case 'entityLink':
        // Hedef bu belgenin ICINDE bir yerde; baglanti yerine adi yaziyoruz.
        final label = s('label');
        return label.isEmpty ? '' : '→ $label';
      case 'characterEmbed':
        final name = s('name');
        return name.isEmpty ? '' : '**$name**';
      default:
        return '';
    }
  }

  static String _tableToMarkdown(Map<String, dynamic> data) {
    final rows = <List<String>>[
      for (final row in _list(data['rows'], raw: true))
        [for (final cell in _list(row)) '$cell'],
    ];
    if (rows.isEmpty) return '';

    final width = rows.fold(0, (max, r) => r.length > max ? r.length : max);
    List<String> pad(List<String> row) => [
      ...row,
      for (var i = row.length; i < width; i++) '',
    ];

    final out = <String>[];
    final hasHeader = data['header'] == true;
    // Markdown tablosu ayrac satiri OLMADAN tablo sayilmiyor; baslik
    // isaretlenmemisse bos bir baslik satiri uyduruluyor.
    out.add(
      '| ${pad(hasHeader ? rows.first : List.filled(width, '')).join(' | ')} |',
    );
    out.add('|${' --- |' * width}');
    for (final row in hasHeader ? rows.skip(1) : rows) {
      out.add('| ${pad(row).join(' | ')} |');
    }
    return out.join('\n');
  }

  /// Grafik ve sayac bloklarinin ortak sekli: "etiket: deger" listesi.
  static String _labelledValuesToMarkdown(String title, Object? items) {
    final lines = [
      for (final item in _list(items, raw: true))
        if (item is Map) '- ${item['label'] ?? ''}: ${item['value'] ?? ''}',
    ];
    if (lines.isEmpty) return title.isEmpty ? '' : '**$title**';
    return [if (title.isNotEmpty) '**$title**', ...lines].join('\n');
  }

  // --- JSON ---------------------------------------------------------------

  /// Kampanyanin yapisal ozeti.
  ///
  /// KUTUPHANE (SRD canavarlari, buyuleri) DISARIDA: paketle birlikte gelen
  /// ve kullanicinin yazmadigi veri. Disa aktarim "benim yazdiklarim"
  /// demek; SRD'yi kopyalamak dosyayi on kat buyutup hicbir sey eklemezdi.
  Future<Map<String, dynamic>> campaignToJson() async {
    final quests = await db.select(db.quests).get();
    final locations = await db.select(db.locations).get();

    return {
      'formatVersion': formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'characters': [
        for (final c in await db.select(db.characters).get())
          {
            'id': c.id,
            'name': c.name,
            'player': c.playerName,
            'species': c.speciesKey,
            'background': c.backgroundKey,
            'alignment': c.alignment,
            'hitPoints': {'current': c.hitPointsCurrent, 'max': c.hitPointsMax},
            'experience': c.experiencePoints,
          },
      ],
      'locations': [
        for (final l in locations)
          {
            'id': l.id,
            'name': l.name,
            'parentId': l.parentId,
            'description': l.description,
            'dmNotes': l.secretNotes,
          },
      ],
      'npcs': [
        for (final n in await db.select(db.npcs).get())
          {
            'id': n.id,
            'name': n.name,
            'role': n.role,
            'race': n.race,
            'description': n.description,
            'hook': n.hook,
            'dmNotes': n.secretNotes,
          },
      ],
      'factions': [
        for (final f in await db.select(db.factions).get())
          {
            'id': f.id,
            'name': f.name,
            'kind': f.kind,
            'goal': f.goal,
            'description': f.description,
            'dmNotes': f.secretNotes,
          },
      ],
      'bonds': [
        for (final link in await db.select(db.worldLinks).get())
          {
            'from': {'kind': link.aKind, 'id': link.aId},
            'to': {'kind': link.bKind, 'id': link.bId},
            'type': link.type,
          },
      ],
      'quests': [
        for (final q in quests)
          {
            'id': q.id,
            'title': q.title,
            'text': q.questText,
            'reward': q.reward,
            'rewardCoinsCp': q.rewardCoinsCp,
            'dmNotes': q.dmNotes,
            'done': q.done,
            'owners': QuestRepository.targetsOf(q),
          },
      ],
      'clocks': [
        for (final c in await db.select(db.clocks).get())
          {
            'id': c.id,
            'name': c.name,
            'segments': c.segments,
            'filled': c.filled,
            'outcome': c.outcome,
            'done': c.done,
            'linkKind': c.linkKind.name,
            'linkId': c.linkId,
          },
      ],
      'sessionLog': [
        for (final e in await db.select(db.sessionLogEntries).get())
          {'at': e.createdAt.toIso8601String(), 'message': e.message},
      ],
    };
  }

  Future<String> campaignToJsonString() async =>
      const JsonEncoder.withIndent('  ').convert(await campaignToJson());

  /// Bicim surumu; yapı degisirse artirilir.
  static const formatVersion = 1;

  static Map<String, dynamic> _decode(String json) {
    try {
      return (jsonDecode(json) as Map).cast<String, dynamic>();
    } on FormatException {
      return const {};
    }
  }

  /// JSON listesini guvenli okur. [raw] ise elemanlar oldugu gibi doner,
  /// aksi halde metne cevrilir.
  static List<dynamic> _list(Object? value, {bool raw = false}) {
    if (value is! List) return const [];
    return raw ? value : [for (final v in value) '$v'];
  }
}
