import 'dart:convert';

/// Görev üreteci: ekip sayısı + seviye + zorluğa göre üç net bölüm —
/// oyunculara okunacak **görev metni**, görev vericinin verdiği somut **ödül**
/// ve yalnız DM'in bileceği **açıklamalar**.
///
/// İsteğe bağlı olarak görevi verecek bir **NPC** ve görevin **hedef
/// lokasyonu** da verilebilir; verilirse üretilen görev onlara bağlanır,
/// verilmezse üretici serbestçe seçer.
///
/// Çıktı, minimum token için düz metin yerine sıkı bir JSON nesnesidir; istem
/// SAF ve test edilebilir. Arayüz [AiToolsPage]'in "Görev Üretici" sekmesinde.

/// Beş kademeli zorluk. [promptDescriptor] modele verilen kısa İngilizce ipucu;
/// TR/EN görünen etiketler l10n'dan gelir.
enum QuestDifficulty {
  veryEasy('very easy'),
  easy('easy'),
  medium('medium'),
  hard('hard'),
  veryHard('deadly');

  const QuestDifficulty(this.promptDescriptor);
  final String promptDescriptor;
}

/// Üretilen ödülün eşya kalemi. Yapısal olarak `LootItemData` ile aynıdır, bu
/// yüzden doğrudan `QuestRepository.update(rewardItems: ...)`'a verilebilir
/// (bu modül saf kalsın diye veri katmanına bağlanmıyor).
typedef QuestRewardItem = ({String name, bool magic});

/// Ayrıştırılmış görev: [title] kısa başlık, [quest] oyunculara, [reward] görev
/// vericinin ödülünün okunur metni, [dm] yalnız DM'e.
///
/// [rewardCoinsCp] ve [rewardItems] aynı ödülün MAKİNE OKUNUR hâlidir: görev
/// Görevler listesine kaydedilirken gerçek ganimet havuzuna (para + eşya)
/// dönüşür, oyuncular görev bitince toplar.
typedef QuestResult = ({
  String title,
  String quest,
  String reward,
  String dm,
  int rewardCoinsCp,
  List<QuestRewardItem> rewardItems,
});

({String system, String user}) buildQuestPrompt({
  required int partySize,
  required int partyLevel,
  required QuestDifficulty difficulty,
  required String setting,
  required String languageName,
  String? questGiverNpc,
  String? targetLocation,
}) {
  final theme = setting.trim().isEmpty ? null : setting.trim();
  // Sistem istemi kısa ama net; çıktı SADECE JSON → düşük token, güvenilir
  // ayrıştırma. Ödül görev-verici tarzı somut ve TOPLAM (oyuncu başına değil).
  final system =
      'D&D 5e (2024) Zindan Efendisi yardımcısısın. Bir görev tasarla ve yanıtı '
      '$languageName yaz. Telifli evren/yer/karakter adı kullanma. SADECE şu '
      'JSON nesnesini döndür, başka hiçbir metin/işaret ekleme:\n'
      '{"title": "...", "quest": "...", "reward": "...", '
      '"rewardCoins": {"pp": 0, "gp": 0, "sp": 0, "cp": 0}, '
      '"rewardItems": [{"name": "...", "magic": true}], "dm": "..."}\n'
      '"title" = kısa görev başlığı (birkaç kelime). '
      '"quest" = oyunculara doğrudan okunacak görev metni (görev veren, kanca, '
      'hedef; atmosferik). "reward" = görev vericinin sunduğu SOMUT ve NET ödül, '
      'oyuncu başına değil TOPLAM (ör. "500 altın + Ateş Kılıcı +1 + baronun '
      'gözü"). "rewardCoins" = AYNI ödüldeki paranın sayısal dökümü (yoksa 0). '
      '"rewardItems" = AYNI ödüldeki eşyalar; her biri {"name","magic"} '
      '("magic" büyülü eşya ise true). '
      'ÖDÜLÜN BİLEŞİMİ SERBEST: sadece para, sadece eşya(lar), ikisi birden ya '
      'da hiçbiri olabilir; eşya sayısı sabit DEĞİL — 0, 1 ya da birkaç tane. '
      'Kalıp kurma, göreve ve görev verene uygun olanı seç (ör. fakir bir köylü '
      'para yerine miras bir eşya verir; lonca sadece kese sayar). '
      'Ama TOPLAM DEĞER, kullanıcının verdiği parti ölçeğine göre hesaplanan '
      'bütçeye uymalı; bütçe aşağıda veriliyor. '
      '"reward" metnindeki her para ve eşya bu iki alanda da GEÇMELİ, '
      'fazlası/eksiği olmamalı. '
      '"dm" = yalnız DM\'in bilmesi gerekenler (sırlar, twist, tuzaklar, '
      'partinin boyut/seviye ve zorluğuna göre SRD canavar/karşılaşma notları). '
      'Kaliteden ödün verme ama her alanı kısa ve öz tut. '
      'Kullanıcı görev veren NPC ya da hedef lokasyon verirse görevi MUTLAKA '
      'onlara bağla; vermezse serbestçe seç.';
  final budget = questRewardBudget(
    partySize: partySize,
    partyLevel: partyLevel,
    difficulty: difficulty,
  );
  final user = StringBuffer(
    'Parti: $partySize kişi, seviye $partyLevel. '
    'Zorluk: ${difficulty.promptDescriptor}. '
    'Tema: ${theme ?? 'serbest'}. '
    'Ödül bütçesi (TOPLAM, parti geneli): '
    '${budget.minGp}–${budget.maxGp} altın değerinde. '
    'Bu değeri para ve/veya eşya olarak İSTEDİĞİN GİBİ dağıt; '
    'eşya verirsen değerini bütçeden düş. '
    'Büyülü eşya bu seviyede en fazla ${budget.magicRarity} olmalı '
    '(${budget.magicAdvice}).',
  );
  if (questGiverNpc != null && questGiverNpc.trim().isNotEmpty) {
    user.write(' Görevi veren: ${questGiverNpc.trim()}.');
  }
  if (targetLocation != null && targetLocation.trim().isNotEmpty) {
    user.write(' Hedef lokasyon: ${targetLocation.trim()}.');
  }
  return (system: system, user: user.toString());
}

/// Bir görevin ödül bütçesi: parti geneli TOPLAM altın aralığı + bu seviyede
/// makul en yüksek büyülü eşya nadirliği.
typedef QuestRewardBudget = ({
  int minGp,
  int maxGp,
  String magicRarity,
  String magicAdvice,
});

/// Ödül bütçesini kullanıcının verdiği ölçeklerden hesaplar: kişi başı kademe
/// değeri × parti sayısı × zorluk katsayısı, ±%25 aralıkla.
///
/// Kademe değerleri 5e hazine kademelerine (1–4 / 5–10 / 11–16 / 17+) dayanır;
/// amaç kuralı birebir taklit etmek değil, üreticinin ödülü partinin boyu,
/// seviyesi ve zorluğa göre TUTARLI ölçeklemesi. Bileşim (para mı, eşya mı,
/// ikisi mi) modele bırakılır — bütçe sadece toplam değeri bağlar.
QuestRewardBudget questRewardBudget({
  required int partySize,
  required int partyLevel,
  required QuestDifficulty difficulty,
}) {
  final size = partySize < 1 ? 1 : partySize;
  final level = partyLevel.clamp(1, 20);

  // Kisi basi temel altin (kademe ortasi).
  final perHead = switch (level) {
    <= 4 => 50,
    <= 10 => 300,
    <= 16 => 1500,
    _ => 6000,
  };
  final multiplier = switch (difficulty) {
    QuestDifficulty.veryEasy => 0.5,
    QuestDifficulty.easy => 0.75,
    QuestDifficulty.medium => 1.0,
    QuestDifficulty.hard => 1.5,
    QuestDifficulty.veryHard => 2.25,
  };
  final center = perHead * size * multiplier;

  // Okunur sayilar: 10/50/100'e yuvarla (bütçe hassas değil, ölçek verir).
  int round(double v) {
    final step = v >= 2000
        ? 100
        : v >= 500
        ? 50
        : 10;
    final r = (v / step).round() * step;
    return r < step ? step : r;
  }

  final (rarity, advice) = switch (level) {
    <= 4 => (
      'yaygın/sıra dışı (common/uncommon)',
      'çoğu görevde büyülü eşya hiç olmaz',
    ),
    <= 10 => ('sıra dışı (uncommon)', 'nadir eşya ancak çok zor görevlerde'),
    <= 16 => ('nadir (rare)', 'çok nadir eşya ancak çok zor görevlerde'),
    _ => (
      'çok nadir (very rare)',
      'efsanevi eşya yalnız kampanya dönümlerinde',
    ),
  };

  return (
    minGp: round(center * 0.75),
    maxGp: round(center * 1.25),
    magicRarity: rarity,
    magicAdvice: advice,
  );
}

/// Modelin JSON yanıtını alanlara ayrıştırır. ```json çitlerini ve JSON dışı
/// önek/soneki tolere eder; ayrıştırılamazsa tüm metni [quest]'e koyar.
///
/// Sayısal ödül alanları eksik ya da bozuksa 0/boş döner — görev yine kaydedilir,
/// DM ödülü elle girer.
QuestResult parseQuestResult(String raw) {
  final text = raw.trim();
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start != -1 && end > start) {
    try {
      final map = jsonDecode(text.substring(start, end + 1)) as Map;
      final title = '${map['title'] ?? ''}'.trim();
      final quest = '${map['quest'] ?? ''}'.trim();
      final reward = '${map['reward'] ?? ''}'.trim();
      final dm = '${map['dm'] ?? ''}'.trim();
      if (quest.isNotEmpty || reward.isNotEmpty || dm.isNotEmpty) {
        return (
          title: title,
          quest: quest,
          reward: reward,
          dm: dm,
          rewardCoinsCp: _coinsFrom(map['rewardCoins']),
          rewardItems: _itemsFrom(map['rewardItems']),
        );
      }
    } catch (_) {
      // JSON değilse aşağıda düz metne düşer.
    }
  }
  return (
    title: '',
    quest: text,
    reward: '',
    dm: '',
    rewardCoinsCp: 0,
    rewardItems: const [],
  );
}

/// `{"pp":1,"gp":20,...}` → bakır. Model tek bir sayı yazarsa ALTIN sayılır
/// (D&D ödülleri neredeyse hep altın cinsinden anılır).
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

/// `[{"name":"...","magic":true}]` → eşya listesi. Model düz string dizisi
/// verirse ("Ateş Kılıcı") o da kabul edilir (sihirli değil sayılır).
List<QuestRewardItem> _itemsFrom(Object? raw) {
  if (raw is! List) return const [];
  final items = <QuestRewardItem>[];
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
