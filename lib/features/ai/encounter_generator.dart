/// Karşılaşma üreteci: parti ölçeğine ve ortama göre bir savaş kurgular.
///
/// İki tasarım kararı bu modülü diğer üreteçlerden ayırıyor:
///
/// 1. **Aday listesi.** Modele serbestçe canavar adı uydurtmak yerine
///    kütüphaneden çekilmiş bir ADAY LİSTESİ verilir ve "yalnız bunlardan seç"
///    denir. Böylece üretilen her ad `searchMonsters` ile çözülebilir ve
///    karşılaşma tek tuşla gerçek savaşa dönüşebilir (uydurma ad = çözülemeyen
///    satır).
/// 2. **XP bütçesi.** Zorluk metinle ("zor yap") değil, 2024 SRD bütçesiyle
///    (`EncounterBudget.partyBudget`) sayısal verilir — görev ödülü bütçesiyle
///    aynı yaklaşım.
library;

import 'dart:convert';

/// Modele sunulan bir aday canavar.
typedef EncounterCandidate = ({String name, String challenge, int xp});

/// Karşılaşmadaki bir canavar grubu.
typedef EncounterGroup = ({String name, int count});

/// Ayrıştırılmış karşılaşma.
typedef EncounterResult = ({
  String name,
  String summary,
  List<EncounterGroup> monsters,
  String tactics,
  String terrain,
  String dm,
});

({String system, String user}) buildEncounterPrompt({
  required int partySize,
  required int partyLevel,
  required String difficultyLabel,
  required int xpBudget,
  required List<EncounterCandidate> candidates,
  required String languageName,
  String environment = '',
}) {
  final system =
      'D&D 5e (2024) Zindan Efendisi yardımcısısın. Bir savaş karşılaşması '
      'tasarla ve yanıtı $languageName yaz. Telifli evren/yer/karakter adı '
      'kullanma. SADECE şu JSON nesnesini döndür, başka hiçbir metin/işaret '
      'ekleme:\n'
      '{"name": "...", "summary": "...", '
      '"monsters": [{"name": "...", "count": 1}], '
      '"tactics": "...", "terrain": "...", "dm": "..."}\n'
      '"name" = karşılaşmanın kısa adı. "summary" = oyunculara okunabilecek '
      'giriş (sahne, ilk izlenim). "monsters" = savaştaki canavarlar; '
      '**"name" alanı AŞAĞIDAKİ ADAY LİSTESİNDEN BİREBİR kopyalanmalı**, '
      'listede olmayan hiçbir canavar kullanma, adı değiştirme/çevirme. '
      '"tactics" = canavarların nasıl savaştığı (açılış, odak, geri çekilme). '
      '"terrain" = arazi/engel/aydınlatma gibi savaşı ilginç kılan unsurlar. '
      '"dm" = yalnız DM\'in bilmesi gerekenler (sürpriz, takviye, kaçış '
      'koşulu). Toplam XP hedefe yakın olmalı; 1-4 farklı canavar türü yeter. '
      'Her alanı kısa ve öz tut.';

  final buffer = StringBuffer(
    'Parti: $partySize kişi, seviye $partyLevel. '
    'Hedef zorluk: $difficultyLabel. '
    'Hedef toplam canavar XP\'si: yaklaşık $xpBudget XP '
    '(±%20 kabul edilir). '
    'Ortam/tema: ${environment.trim().isEmpty ? 'serbest' : environment.trim()}.',
  );
  buffer.write('\nAday canavarlar (ad — meydan okuma — XP):\n');
  for (final c in candidates) {
    buffer.write('- ${c.name} — CR ${c.challenge} — ${c.xp} XP\n');
  }
  return (system: system, user: buffer.toString());
}

/// Modelin JSON yanıtını ayrıştırır. ```json çitlerini ve JSON dışı
/// önek/soneki tolere eder; ayrıştırılamazsa tüm metni [summary]'ye koyar.
EncounterResult parseEncounterResult(String raw) {
  final text = raw.trim();
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start != -1 && end > start) {
    try {
      final map = jsonDecode(text.substring(start, end + 1)) as Map;
      final name = '${map['name'] ?? ''}'.trim();
      final summary = '${map['summary'] ?? ''}'.trim();
      final monsters = _monstersFrom(map['monsters']);
      final tactics = '${map['tactics'] ?? ''}'.trim();
      final terrain = '${map['terrain'] ?? ''}'.trim();
      final dm = '${map['dm'] ?? ''}'.trim();
      if (summary.isNotEmpty || monsters.isNotEmpty || tactics.isNotEmpty) {
        return (
          name: name,
          summary: summary,
          monsters: monsters,
          tactics: tactics,
          terrain: terrain,
          dm: dm,
        );
      }
    } on Object {
      // JSON degilse asagida duz metne duser.
    }
  }
  return (
    name: '',
    summary: text,
    monsters: const [],
    tactics: '',
    terrain: '',
    dm: '',
  );
}

/// `[{"name":"Goblin","count":4}]` → gruplar. Model düz string dizisi verirse
/// ("Goblin") her biri 1 adet sayılır; adet 1'in altına düşmez.
List<EncounterGroup> _monstersFrom(Object? raw) {
  if (raw is! List) return const [];
  final groups = <EncounterGroup>[];
  for (final entry in raw) {
    if (entry is String) {
      final name = entry.trim();
      if (name.isNotEmpty) groups.add((name: name, count: 1));
    } else if (entry is Map) {
      final name = '${entry['name'] ?? ''}'.trim();
      if (name.isEmpty) continue;
      final rawCount = entry['count'];
      final count = rawCount is num
          ? rawCount.round()
          : int.tryParse('$rawCount') ?? 1;
      groups.add((name: name, count: count < 1 ? 1 : count));
    }
  }
  return groups;
}
