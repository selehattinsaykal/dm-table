import 'ai_json.dart';

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

/// Görevin ARKETIPI. Serbest bırakılırsa üretici kendi seçer; sabitlemek
/// çeşitliliği DM'in eline verir — aksi halde model "git ve öldür" kalıbına
/// kayma eğiliminde.
enum QuestKind {
  any('any archetype you choose'),
  retrieve('retrieve or fetch a specific object'),
  eliminate('eliminate a threat or creature'),
  escort('escort and protect someone on a journey'),
  rescue('rescue a captive or missing person'),
  investigate('investigate a mystery or crime'),
  delivery('deliver a message, package or payment'),
  defend('defend a place against an incoming attack'),
  explore('explore and map an unknown place'),
  diplomacy('negotiate, broker peace or win someone over'),
  heist('infiltrate somewhere and steal something');

  const QuestKind(this.promptDescriptor);
  final String promptDescriptor;
}

/// Görevin KAPSAMI: kaç oturumluk iş. Aşama sayısını ve metnin ayrıntı
/// düzeyini bu belirler.
enum QuestScope {
  oneShot('a single session, roughly 3-4 hours of play', 3, 4096),
  shortArc('a short arc spanning 2-3 sessions', 4, 5120),
  campaignArc('a long campaign arc spanning many sessions', 6, 6144);

  const QuestScope(this.promptDescriptor, this.stageCount, this.maxTokens);
  final String promptDescriptor;

  /// Üreticiden istenecek aşama sayısı.
  final int stageCount;

  /// Bu kapsam için token bütçesi. Kapsam büyüdükçe çıktı da büyüyor; sabit
  /// bütçe kampanya yaylarında yanıtı ORTADAN kesiyordu (bkz.
  /// [parseQuestResult] kurtarma notu).
  final int maxTokens;
}

/// Anlatı TONU. "Ahlaki gri" bilinçli olarak ayrı bir seçenek: en çok
/// istenen ama modelin kendiliğinden en az ürettiği ton.
enum QuestTone {
  any('any tone you choose'),
  heroic('heroic and hopeful'),
  mysterious('mysterious, eerie, full of unanswered questions'),
  grim('grim, dark and costly'),
  comedic('light-hearted and comedic'),
  morallyGrey('morally grey — no clean right answer, both sides have a case');

  const QuestTone(this.promptDescriptor);
  final String promptDescriptor;
}

/// SÜRE BASKISI. Klasik bir görev tasarımı kolu: aciliyet olmadan oyuncular
/// görevi süresiz erteler.
enum QuestUrgency {
  none('no particular time pressure'),
  soft('a soft deadline — every delay makes the situation worse'),
  hard('a hard deadline — if it is missed, the chance is gone for good');

  const QuestUrgency(this.promptDescriptor);
  final String promptDescriptor;

  /// Somut bir süre girilebilir mi (bkz. [QuestDeadline]). "Baskı yok"ta
  /// süre sormak anlamsız.
  bool get takesDeadline => this != QuestUrgency.none;
}

/// Sürenin birimi.
enum QuestTimeUnit {
  hours('hours'),
  days('days'),
  weeks('weeks'),
  months('months');

  const QuestTimeUnit(this.promptDescriptor);
  final String promptDescriptor;
}

/// Görevin SOMUT süresi: "3 gün", "2 hafta".
///
/// Ayrı bir tip: yalnız "acele" demek modele bir şey söylemiyor, üretilen
/// aşamalar da süreye oturmuyordu. Süre verilince üretici her aşamanın ne
/// kadar süreceğini bu bütçeye göre yazar.
typedef QuestDeadline = ({int amount, QuestTimeUnit unit});

/// Süreyi modele verilecek kısa ifadeye çevirir ("3 days").
String questDeadlineText(QuestDeadline deadline) =>
    '${deadline.amount} ${deadline.unit.promptDescriptor}';

/// Üretilen ödülün eşya kalemi. Yapısal olarak `LootItemData` ile aynıdır, bu
/// yüzden doğrudan `QuestRepository.update(rewardItems: ...)`'a verilebilir
/// (bu modül saf kalsın diye veri katmanına bağlanmıyor).
typedef QuestRewardItem = ({String name, bool magic});

/// Görevin bir AŞAMASI: kısa başlık + DM'in o aşamada ne olacağını anlatan
/// birkaç cümlesi.
typedef QuestStage = ({String title, String detail});

/// Görevde geçen yan karakter: ad + tek satırlık rolü.
typedef QuestNpcBrief = ({String name, String role});

/// Ayrıştırılmış görev: [title] kısa başlık, [quest] oyunculara, [reward] görev
/// vericinin ödülünün okunur metni, [dm] yalnız DM'e.
///
/// [rewardCoinsCp] ve [rewardItems] aynı ödülün MAKİNE OKUNUR hâlidir: görev
/// Görevler listesine kaydedilirken gerçek ganimet havuzuna (para + eşya)
/// dönüşür, oyuncular görev bitince toplar.
///
/// Kalan alanlar DM'e özel PLANLAMA malzemesi; hepsi boş gelebilir (eski
/// yanıtlar ya da kısa kesilen üretim) ve arayüz boş olanları hiç çizmez:
///  * [hooks] — görevi masaya sokmanın alternatif yolları. Parti ilkini
///    yutmazsa DM'in elinde yedek kalsın diye; tek kanca üreten araçların en
///    can sıkıcı eksiği bu.
///  * [stages] — görevin 3-6 aşaması (kapsama göre).
///  * [complications] — istendiğinde araya sokulacak komplikasyonlar.
///  * [failure] — parti başarısız olursa ya da görevi hiç almazsa dünyada ne
///    değişir. Nadiren üretilir, masada en çok gereken şeylerden biri.
///  * [keyNpcs] — görevde geçen yan karakterler.
typedef QuestResult = ({
  /// Yapısal ayrıştırma tuttu mu. `false` ise model geçerli JSON döndürmedi
  /// (çoğunlukla yanıt kesilmiştir) ve [quest] ham metnin tamamını taşır —
  /// arayüz bunu görev gibi değil, uyarı olarak göstermeli.
  bool parsed,
  String title,
  String quest,
  String reward,
  String dm,
  int rewardCoinsCp,
  List<QuestRewardItem> rewardItems,
  List<String> hooks,
  List<QuestStage> stages,
  List<String> complications,
  String failure,
  List<QuestNpcBrief> keyNpcs,
});

({String system, String user}) buildQuestPrompt({
  required int partySize,
  required int partyLevel,
  required QuestDifficulty difficulty,
  required String setting,
  required String languageName,
  String? questGiverNpc,
  String? targetLocation,

  /// Görevin ALINDIĞI yer (hedef lokasyondan ayrı): parti görevi handa alır,
  /// görev dağdaki harabededir. İkisi karıştırılınca üretici görev vericiyi
  /// hedefin içine koyuyordu.
  String? giverLocation,

  /// Görevin karşısındaki güç. Verilirse görev ona bağlanır.
  String? antagonistNpc,
  QuestKind kind = QuestKind.any,
  QuestScope scope = QuestScope.oneShot,
  QuestTone tone = QuestTone.any,
  QuestUrgency urgency = QuestUrgency.none,

  /// Görevin somut süresi. Yalnız [QuestUrgency.takesDeadline] doğruyken
  /// anlamlı; null ise üretici süreyi kendi belirler.
  QuestDeadline? deadline,

  /// Devamı olduğu görev (varsa): üretici buna bağlanan bir devam görevi yazar.
  String? followsUpQuest,
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
      '"rewardItems": [{"name": "...", "magic": true}], "dm": "...", '
      '"hooks": ["...", "..."], '
      '"stages": [{"title": "...", "detail": "..."}], '
      '"complications": ["...", "..."], "failure": "...", '
      '"keyNpcs": [{"name": "...", "role": "..."}]}\n'
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
      '"hooks" = görevi masaya sokmanın 2-3 FARKLI yolu; parti ilkini yutmazsa '
      'DM yedeğini kullansın (her biri tek cümle, birbirinin kopyası olmasın). '
      '"stages" = görevin sırayla oynanacak aşamaları; her biri kısa bir '
      '"title" ve DM\'e o aşamada ne olacağını anlatan birkaç cümlelik '
      '"detail". "complications" = DM isterse araya sokacağı 2-3 komplikasyon '
      '(zorunlu değil, tek cümle). "failure" = parti başarısız olursa YA DA '
      'görevi hiç almazsa dünyada ne değişir; bunu somut yaz, "kötü şeyler '
      'olur" deme. "keyNpcs" = görevde geçen yan karakterler; her biri ad + '
      'tek satırlık rol. Görev veren ve düşman kullanıcı tarafından verildiyse '
      'onları buraya TEKRAR yazma, yalnızca YENİ karakterleri say. '
      'Kaliteden ödün verme ama her alanı kısa ve öz tut. '
      'Kullanıcı görev veren NPC, lokasyon, karşı taraf ya da devamı olduğu '
      'görev verirse üretilen görevi MUTLAKA onlara bağla; vermediklerini '
      'serbestçe seç.';

  final budget = questRewardBudget(
    partySize: partySize,
    partyLevel: partyLevel,
    difficulty: difficulty,
  );
  final user = StringBuffer(
    'Parti: $partySize kişi, seviye $partyLevel. '
    'Zorluk: ${difficulty.promptDescriptor}. '
    'Görev türü: ${kind.promptDescriptor}. '
    'Kapsam: ${scope.promptDescriptor} — tam olarak ${scope.stageCount} aşama '
    'yaz. '
    'Ton: ${tone.promptDescriptor}. '
    'Süre baskısı: ${urgency.promptDescriptor}'
    '${urgency.takesDeadline && deadline != null ? ' — parti bu işi tam olarak '
              '${questDeadlineText(deadline)} içinde bitirmeli; bu süreyi '
              'görev metninde AÇIKÇA söyle ve aşamaları bu bütçeye sığacak '
              'şekilde tasarla' : ''}. '
    'Tema: ${theme ?? 'serbest'}. '
    'Ödül bütçesi (TOPLAM, parti geneli): '
    '${budget.minGp}–${budget.maxGp} altın değerinde. '
    'Bu değeri para ve/veya eşya olarak İSTEDİĞİN GİBİ dağıt; '
    'eşya verirsen değerini bütçeden düş. '
    'Büyülü eşya bu seviyede en fazla ${budget.magicRarity} olmalı '
    '(${budget.magicAdvice}).',
  );

  // Kullanicinin verdigi baglar. Her biri AYRI etiketli cumle: tek satirda
  // birlestirilince model gorev vericiyi hedefin icine koyuyordu. Baglara
  // uyma talimati sistem isteminde (statik), veri burada.
  void bind(String? value, String label) {
    final v = value?.trim();
    if (v == null || v.isEmpty) return;
    user.write(' $label: $v.');
  }

  bind(questGiverNpc, ' Görevi veren');
  bind(giverLocation, ' Görevin alındığı yer (görev burada teklif edilir)');
  bind(targetLocation, ' Hedef lokasyon');
  bind(antagonistNpc, ' Karşı taraf');
  bind(followsUpQuest, ' Bu görev şunun devamı');
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
/// önek/soneki tolere eder.
///
/// KESİLMİŞ yanıtı da kurtarır (bkz. [_decodeLenient]): uzun görevlerde model
/// token bütçesini doldurup JSON'ın ortasında kesilebiliyor. Eskiden bu durumda
/// tüm ham metin tek parça hâlinde [quest]'e düşüyordu — DM'in gördüğü "garip
/// tek bir yazı" tam olarak buydu. Artık tamamlanmış alanlar kurtarılıyor,
/// kurtarılamazsa [parsed] `false` dönüyor ve arayüz bunu bir hata olarak
/// gösteriyor (sessizce görev gibi davranmıyor).
///
/// Sayısal ödül alanları eksik ya da bozuksa 0/boş döner — görev yine kaydedilir,
/// DM ödülü elle girer.
QuestResult parseQuestResult(String raw) {
  final text = raw.trim();
  final map = decodeAiJsonObject(text);
  if (map != null) {
    final title = '${map['title'] ?? ''}'.trim();
    final quest = '${map['quest'] ?? ''}'.trim();
    final reward = '${map['reward'] ?? ''}'.trim();
    final dm = '${map['dm'] ?? ''}'.trim();
    if (quest.isNotEmpty || reward.isNotEmpty || dm.isNotEmpty) {
      return (
        parsed: true,
        title: title,
        quest: quest,
        reward: reward,
        dm: dm,
        rewardCoinsCp: _coinsFrom(map['rewardCoins']),
        rewardItems: _itemsFrom(map['rewardItems']),
        hooks: aiStringList(map['hooks']),
        stages: _stagesFrom(map['stages']),
        complications: aiStringList(map['complications']),
        failure: '${map['failure'] ?? ''}'.trim(),
        keyNpcs: _npcsFrom(map['keyNpcs']),
      );
    }
  }
  return (
    parsed: false,
    title: '',
    quest: text,
    reward: '',
    dm: '',
    rewardCoinsCp: 0,
    rewardItems: const [],
    hooks: const [],
    stages: const [],
    complications: const [],
    failure: '',
    keyNpcs: const [],
  );
}

// Kesilmis JSON kurtarmasi artik ORTAK: bkz. `ai_json.dart`.

/// `[{"title":"...","detail":"..."}]` → aşamalar. Model düz string dizisi
/// verirse (yalnız başlık) o da kabul edilir, açıklaması boş kalır.
List<QuestStage> _stagesFrom(Object? raw) {
  if (raw is! List) return const [];
  final out = <QuestStage>[];
  for (final e in raw) {
    if (e is String) {
      final t = e.trim();
      if (t.isNotEmpty) out.add((title: t, detail: ''));
    } else if (e is Map) {
      final t = '${e['title'] ?? ''}'.trim();
      final d = '${e['detail'] ?? ''}'.trim();
      // Basligi bos ama govdesi dolu bir asama yine ise yarar.
      if (t.isNotEmpty || d.isNotEmpty) out.add((title: t, detail: d));
    }
  }
  return out;
}

/// `[{"name":"...","role":"..."}]` → yan karakterler. Düz string dizisi de
/// kabul edilir (rol boş kalır).
List<QuestNpcBrief> _npcsFrom(Object? raw) {
  if (raw is! List) return const [];
  final out = <QuestNpcBrief>[];
  for (final e in raw) {
    if (e is String) {
      final n = e.trim();
      if (n.isNotEmpty) out.add((name: n, role: ''));
    } else if (e is Map) {
      final n = '${e['name'] ?? ''}'.trim();
      if (n.isEmpty) continue;
      out.add((name: n, role: '${e['role'] ?? ''}'.trim()));
    }
  }
  return out;
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
