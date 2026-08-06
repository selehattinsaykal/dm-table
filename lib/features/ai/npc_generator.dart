import 'dart:convert';

/// NPC üreteci: meslek + cinsiyet + tür/ırk + (opsiyonel) isim + ek bilgilerle
/// oyuna hazır bir yardımcı karakter tasarlar. Çıktı sıkı bir JSON nesnesidir
/// (düşük token, güvenilir ayrıştırma). Arayüz [AiToolsPage]'in "NPC" sekmesinde.

/// NPC cinsiyeti. [promptDescriptor] modele verilen kısa İngilizce ipucu;
/// TR/EN görünen etiketler l10n'dan gelir.
enum NpcGender {
  male('male'),
  female('female'),
  other('nonbinary'),
  random('any (you choose)');

  const NpcGender(this.promptDescriptor);
  final String promptDescriptor;
}

/// Ayrıştırılmış NPC. [secret] yalnız DM'e; diğerleri oyuncuya gösterilebilir.
typedef NpcResult = ({
  String name,
  String summary,
  String race,
  String gender,
  String age,
  String alignment,
  String appearance,
  String personality,
  String ideal,
  String bond,
  String flaw,
  String hook,
  String secret,
});

/// Üretilecek NPC'nin dünyadaki bir başka düğümle ilişkisi. [targetName] karşı
/// tarafın adı (NPC ya da yer), [bondName] harita grafiğindeki bağ türünün
/// görünen adı ("Düşmanlık", "Ticaret"...).
typedef NpcRelationContext = ({String targetName, String bondName});

({String system, String user}) buildNpcPrompt({
  required String profession,
  required NpcGender gender,
  required String race,
  required String name,
  required String extra,
  required String languageName,
  String locationName = '',
  List<NpcRelationContext> relations = const [],
}) {
  final prof = profession.trim();
  final r = race.trim();
  final n = name.trim();
  final e = extra.trim();
  final loc = locationName.trim();
  // Boş adlı ilişkiler modele "X ile dostluk" gibi anlamsız satır olarak
  // gitmesin.
  final rels = [
    for (final rel in relations)
      if (rel.targetName.trim().isNotEmpty && rel.bondName.trim().isNotEmpty)
        rel,
  ];

  final system =
      'D&D 5e (2024) Zindan Efendisi yardımcısısın. Sana verilen bilgilerle '
      'özgün, oyuna hazır bir NPC (yardımcı karakter) tasarla ve yanıtı '
      '$languageName yaz. Telifli evren/yer/karakter adı kullanma. SADECE şu '
      'JSON nesnesini döndür, başka hiçbir metin/işaret ekleme:\n'
      '{"name": "...", "summary": "...", "race": "...", "gender": "...", '
      '"age": "...", "alignment": "...", "appearance": "...", '
      '"personality": "...", "ideal": "...", "bond": "...", "flaw": "...", '
      '"hook": "...", "secret": "..."}\n'
      '"name" = karaktere uygun bir isim (kullanıcı isim verdiyse aynen onu '
      'kullan). "summary" = tek satırlık özet (tür, cinsiyet, yaklaşık yaş, '
      'meslek). "race" = tür/ırk. "gender" = cinsiyet. "age" = yaklaşık yaş '
      '(ör. "yaşlı", "40\'lı"). "alignment" = D&D hizalaması (ör. "Kaotik İyi"). '
      '"appearance" = fiziksel görünüş, kıyafet ve dikkat çeken bir '
      'detay. "personality" = huy, konuşma tarzı ve bir alışkanlık/tik. '
      '"ideal", "bond", "flaw" = birer kısa cümle. "hook" = oyuncuların onunla '
      'nasıl etkileşebileceği ya da bir olay kancası. "secret" = yalnız DM\'in '
      'bileceği gizli bir sır veya gerçek. Kaliteden ödün verme ama her alanı '
      'kısa ve öz tut.'
      // Konum ve iliskiler yalnizca kaydetme aninda bag kurmakla kalmaz,
      // URETIMI de yonlendirir: NPC'nin gecmisi bulundugu yere ve
      // tanidiklarina dokunsun, yoksa baglar sonradan yapistirilmis gibi kalir.
      '${loc.isEmpty && rels.isEmpty ? '' : ' Sana verilen yer ve ilişkiler bu '
                'karakterin dünyadaki gerçek konumudur: geçmişini, kancasını ve '
                'sırrını bunlarla tutarlı kur, ilgili kişileri/yeri metinde adıyla '
                'an. Verilen ilişki türlerini değiştirme.'}';

  final user = StringBuffer()
    ..write('Meslek: ${prof.isEmpty ? 'serbest' : prof}. ')
    ..write('Cinsiyet: ${gender.promptDescriptor}. ')
    ..write('Tür/ırk: ${r.isEmpty ? 'serbest (sen seç)' : r}. ')
    ..write(n.isEmpty ? 'İsim: sen üret. ' : 'İsim: $n. ');
  if (loc.isNotEmpty) user.write('Bağlı olduğu yer: $loc. ');
  if (rels.isNotEmpty) {
    user
      ..write('İlişkileri: ')
      ..write(
        rels
            .map((rel) => '${rel.targetName.trim()} (${rel.bondName.trim()})')
            .join(', '),
      )
      ..write('. ');
  }
  user.write('Ek bilgiler: ${e.isEmpty ? 'yok' : e}.');

  return (system: system, user: user.toString());
}

/// Üretilen NPC'den portre istemi kurar.
///
/// Yönerge bilinçli olarak İngilizce: görsel modelleri İngilizce istemlerde
/// belirgin biçimde daha isabetli. NPC'nin kendi alanları kullanıcının dilinde
/// kaldığı için oldukları gibi aktarılır — model ikisini birlikte yorumlar.
String buildPortraitPrompt(NpcResult r) {
  final b = StringBuffer()
    ..write(
      'A painted fantasy character portrait for a tabletop RPG: head and '
      'shoulders, three-quarter view, plain neutral background, warm '
      'candlelit palette, oil-painting texture, medieval fantasy setting. ',
    );

  void detail(String label, String value) {
    final v = value.trim();
    if (v.isEmpty) return;
    b.write('$label: $v. ');
  }

  detail('Species/race', r.race);
  detail('Gender', r.gender);
  detail('Approximate age', r.age);
  detail('Physical appearance and clothing', r.appearance);
  detail('Temperament to convey in the expression', r.personality);

  b.write('Single character only. No text, no watermark, no border, no frame.');
  return b.toString();
}

/// Modelin JSON yanıtını NPC alanlarına ayrıştırır. ```json çitlerini ve JSON
/// dışı önek/soneki tolere eder; ayrıştırılamazsa tüm metni [appearance]'e koyar.
NpcResult parseNpcResult(String raw) {
  final text = raw.trim();
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start != -1 && end > start) {
    try {
      final map = jsonDecode(text.substring(start, end + 1)) as Map;
      String f(String k) => '${map[k] ?? ''}'.trim();
      final result = (
        name: f('name'),
        summary: f('summary'),
        race: f('race'),
        gender: f('gender'),
        age: f('age'),
        alignment: f('alignment'),
        appearance: f('appearance'),
        personality: f('personality'),
        ideal: f('ideal'),
        bond: f('bond'),
        flaw: f('flaw'),
        hook: f('hook'),
        secret: f('secret'),
      );
      final anyField = [
        result.name,
        result.summary,
        result.appearance,
        result.personality,
        result.hook,
      ].any((s) => s.isNotEmpty);
      if (anyField) return result;
    } catch (_) {
      // JSON değilse aşağıda düz metne düşer.
    }
  }
  return (
    name: '',
    summary: '',
    race: '',
    gender: '',
    age: '',
    alignment: '',
    appearance: text,
    personality: '',
    ideal: '',
    bond: '',
    flaw: '',
    hook: '',
    secret: '',
  );
}
