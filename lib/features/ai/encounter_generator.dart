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

import 'ai_json.dart';

/// Modele sunulan bir aday canavar.
typedef EncounterCandidate = ({String name, String challenge, int xp});

/// Karşılaşmadaki bir canavar grubu.
typedef EncounterGroup = ({String name, int count});

/// Karşılaşmanın KAZANMA KOŞULU.
///
/// 5e savaşlarının en yaygın sorunu her karşılaşmanın "herkesi öldür"e
/// dönüşmesi. Hedefi ayrı bir kol yapmak bunu kırar: aynı canavarlar,
/// tamamen farklı bir sahne.
enum EncounterObjective {
  any('any win condition you choose'),
  defeat('defeat all enemies'),
  survive('survive a set number of rounds until something happens'),
  protect('keep an NPC or object alive/intact'),
  retrieve('grab a specific object and get out'),
  escape('escape the area — winning means leaving, not killing'),
  stop('stop a ritual/machine/countdown before it completes');

  const EncounterObjective(this.promptDescriptor);
  final String promptDescriptor;
}

/// Karşılaşmanın KURULUŞU: savaş nasıl başlıyor.
enum EncounterSetup {
  any('any setup you choose'),
  ambush('the enemies ambush the party'),
  ambushed('the party can spot and ambush the enemies first'),
  patrol('a patrol runs into the party in the open'),
  lair('the enemies are dug into their own lair and know the ground'),
  guardPost('the enemies hold a chokepoint the party must get past'),
  negotiable('a fight that can be avoided entirely by talking');

  const EncounterSetup(this.promptDescriptor);
  final String promptDescriptor;
}

/// Ayrıştırılmış karşılaşma.
///
/// Son alanlar DM'e özel PLANLAMA malzemesi; hepsi boş gelebilir:
///  * [objective] — savaşın kazanma koşulu, açıkça yazılmış.
///  * [reinforcements] — savaş uzarsa/gürültü olursa gelecek takviye.
///  * [scaling] — parti zorlanırsa nasıl hafifletilir, kolay geçerse nasıl
///    sertleştirilir. Masada anında gereken tek şey, hiçbir üreteç vermiyor.
///  * [treasure] — savaş sonrası üstlerinden/mekândan çıkacak şeyin OKUNUR
///    metni. [treasureCoinsCp] ve [treasureItems] AYNI ganimetin makine
///    okunur hâlidir (görev ödülündeki ayrımın aynısı): karşılaşma
///    kaydedilirken bunlar kütüphaneye çözülüp gerçek ganimete dönüşür.
typedef EncounterResult = ({
  /// Yapısal ayrıştırma tuttu mu (bkz. `ai_json.dart`).
  bool parsed,
  String name,
  String summary,
  List<EncounterGroup> monsters,
  String tactics,
  String terrain,
  String dm,
  String objective,
  String reinforcements,
  String scaling,
  String treasure,
  int treasureCoinsCp,
  List<EncounterTreasureItem> treasureItems,
});

/// Ganimetteki bir eşya kalemi. Kütüphaneye çözme işi `LootResolver`'da;
/// bu modül saf kalsın diye burada yalnızca ad + büyülü bayrağı var.
typedef EncounterTreasureItem = ({String name, bool magic});

({String system, String user}) buildEncounterPrompt({
  required int partySize,
  required int partyLevel,
  required String difficultyLabel,
  required int xpBudget,
  required List<EncounterCandidate> candidates,
  required String languageName,
  String environment = '',
  EncounterObjective objective = EncounterObjective.any,
  EncounterSetup setup = EncounterSetup.any,

  /// Karşılaşmanın geçtiği yer (kampanyadan seçilmişse adı + özeti).
  String? locationContext,
}) {
  final system =
      'D&D 5e (2024) Zindan Efendisi yardımcısısın. Bir savaş karşılaşması '
      'tasarla ve yanıtı $languageName yaz. Telifli evren/yer/karakter adı '
      'kullanma. SADECE şu JSON nesnesini döndür, başka hiçbir metin/işaret '
      'ekleme:\n'
      '{"name": "...", "summary": "...", '
      '"monsters": [{"name": "...", "count": 1}], '
      '"objective": "...", "tactics": "...", "terrain": "...", '
      '"reinforcements": "...", "scaling": "...", "treasure": "...", '
      '"treasureCoins": {"pp": 0, "gp": 0, "sp": 0, "cp": 0}, '
      '"treasureItems": [{"name": "...", "magic": true}], '
      '"dm": "..."}\n'
      '"name" = karşılaşmanın kısa adı. "summary" = oyunculara okunabilecek '
      'giriş (sahne, ilk izlenim). "monsters" = savaştaki canavarlar; '
      '**"name" alanı AŞAĞIDAKİ ADAY LİSTESİNDEN BİREBİR kopyalanmalı**, '
      'listede olmayan hiçbir canavar kullanma, adı değiştirme/çevirme. '
      '"objective" = savaşın KAZANMA KOŞULU tek cümlede; hedef "hepsini '
      'öldür" değilse bunu açıkça yaz ve savaşın nasıl BİTTİĞİNİ söyle. '
      '"tactics" = canavarların nasıl savaştığı (açılış, odak, geri çekilme). '
      '"terrain" = arazi/engel/aydınlatma gibi savaşı ilginç kılan unsurlar. '
      '"reinforcements" = savaş uzarsa ya da gürültü çıkarsa ne gelir '
      '(yoksa boş bırak). '
      // Masada en cok gereken, hicbir uretecin vermedigi sey: savas ters
      // giderse DM'in elinde ANINDA kullanabilecegi bir kol olmali.
      '"scaling" = parti zorlanırsa savaşı nasıl HAFİFLETİRSİN ve kolay '
      'geçerse nasıl SERTLEŞTİRİRSİN; ikisini de somut yaz (canavar '
      'ekle/çıkar, moral bozup kaçır, takviye çağır gibi). '
      '"treasure" = savaştan sonra üstlerinden ya da mekândan ne çıkar '
      '(yoksa boş bırak). '
      '"treasureCoins" = AYNI ganimetteki paranın sayısal dökümü (yoksa 0). '
      '"treasureItems" = AYNI ganimetteki eşyalar; her biri {"name","magic"}. '
      // Cozulebilir adlar sart: bu adlar kutuphaneye eslestirilip gercek
      // esyaya donusturuluyor, uydurma ad "kutuphanede yok" olarak kaliyor.
      'Eşya adlarını D&D 5e SRD\'deki STANDART adlarıyla yaz (uydurma ya da '
      'süslü ad verme) — bu adlar eşya kütüphanesinde aranacak. '
      '"treasure" metnindeki her para ve eşya bu iki alanda da GEÇMELİ. '
      'Ganimet bu seviyedeki bir savaş için makul olsun; her savaştan büyülü '
      'eşya çıkmak zorunda DEĞİL. '
      '"dm" = yalnız DM\'in bilmesi gereken diğer şeyler (sürpriz, kaçış '
      'koşulu). Toplam XP hedefe yakın olmalı; 1-4 farklı canavar türü yeter. '
      'Her alanı kısa ve öz tut.';

  final buffer = StringBuffer(
    'Parti: $partySize kişi, seviye $partyLevel. '
    'Hedef zorluk: $difficultyLabel. '
    'Hedef toplam canavar XP\'si: yaklaşık $xpBudget XP '
    '(±%20 kabul edilir). '
    'Kazanma koşulu: ${objective.promptDescriptor}. '
    'Savaşın kuruluşu: ${setup.promptDescriptor}. '
    'Ortam/tema: ${environment.trim().isEmpty ? 'serbest' : environment.trim()}.',
  );
  final loc = locationContext?.trim() ?? '';
  if (loc.isNotEmpty) {
    buffer.write(' Geçtiği yer: $loc. Sahneyi bu yere oturt.');
  }
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
  final map = decodeAiJsonObject(text);
  if (map != null) {
    final monsters = _monstersFrom(map['monsters']);
    final summary = aiField(map, 'summary');
    final tactics = aiField(map, 'tactics');
    if (summary.isNotEmpty || monsters.isNotEmpty || tactics.isNotEmpty) {
      return (
        parsed: true,
        name: aiField(map, 'name'),
        summary: summary,
        monsters: monsters,
        tactics: tactics,
        terrain: aiField(map, 'terrain'),
        dm: aiField(map, 'dm'),
        objective: aiField(map, 'objective'),
        reinforcements: aiField(map, 'reinforcements'),
        scaling: aiField(map, 'scaling'),
        treasure: aiField(map, 'treasure'),
        treasureCoinsCp: _coinsFrom(map['treasureCoins']),
        treasureItems: _treasureItemsFrom(map['treasureItems']),
      );
    }
  }
  return (
    parsed: false,
    name: '',
    summary: text,
    monsters: const [],
    tactics: '',
    terrain: '',
    dm: '',
    objective: '',
    reinforcements: '',
    scaling: '',
    treasure: '',
    treasureCoinsCp: 0,
    treasureItems: const [],
  );
}

/// `{"pp":1,"gp":20,...}` → bakır. Model tek bir sayı yazarsa ALTIN sayılır
/// (görev ödülüyle aynı kural).
int _coinsFrom(Object? raw) {
  if (raw is num) return (raw * 100).round();
  if (raw is! Map) return 0;
  int unit(String key) {
    final v = raw[key];
    if (v is num) return v.round();
    if (v is String) return int.tryParse(v.trim()) ?? 0;
    return 0;
  }

  final total =
      unit('pp') * 1000 + unit('gp') * 100 + unit('sp') * 10 + unit('cp');
  return total < 0 ? 0 : total;
}

/// `[{"name":"...","magic":true}]` → eşyalar. Düz string dizisi de kabul
/// edilir (sihirli değil sayılır).
List<EncounterTreasureItem> _treasureItemsFrom(Object? raw) {
  if (raw is! List) return const [];
  final items = <EncounterTreasureItem>[];
  for (final e in raw) {
    if (e is String) {
      final name = e.trim();
      if (name.isNotEmpty) items.add((name: name, magic: false));
    } else if (e is Map) {
      final name = '${e['name'] ?? ''}'.trim();
      if (name.isEmpty) continue;
      final magic = e['magic'];
      items.add((
        name: name,
        magic: magic is bool ? magic : '$magic'.toLowerCase() == 'true',
      ));
    }
  }
  return items;
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
