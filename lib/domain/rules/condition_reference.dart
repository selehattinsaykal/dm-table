/// Durum efektleri (conditions) referansi.
///
/// Veri ZATEN veritabaninda: `assets/data/conditions.json.gz` ->
/// `ReferenceEntries(kind: 'conditions')`, 21 kayit. Simdiye kadar yalnizca
/// `name` kullaniliyordu; kural metni (`dataJson` icindeki `descriptions[]`)
/// hic okunmuyordu.
///
/// Saf Dart: Drift bilmez, ham JSON haritasi alir.
library;

import 'dart:convert';

/// Cozulmus bir durum kaydi.
typedef ConditionEntry = ({String key, String name, String desc});

/// 21 kaydin 6'si yalnizca A5e'ye ozel (Bloodied, Confused, Doomed,
/// Encumbered, Rattled, Slowed) ve 5e metni tasimaz; bunlar elenir.
const String _gs2024 = '5e-2024';
const String _gs2014 = '5e-2014';

/// Ham `dataJson` haritasindan durumu cozer.
///
/// 2024 metni tercih edilir, yoksa 2014'e duser. Ikisi de yoksa (A5e'ye ozel
/// kayit) `null` doner — bu kayitlar uygulamada hic gosterilmez.
ConditionEntry? conditionFrom(String key, String name, String dataJson) {
  try {
    final data = jsonDecode(dataJson);
    if (data is! Map) return null;
    final descriptions = data['descriptions'];
    if (descriptions is! List) return null;

    String? pick(String gamesystem) {
      for (final d in descriptions) {
        if (d is! Map) continue;
        if (d['gamesystem'] != gamesystem) continue;
        final desc = '${d['desc'] ?? ''}'.trim();
        if (desc.isNotEmpty) return desc;
      }
      return null;
    }

    final desc = pick(_gs2024) ?? pick(_gs2014);
    if (desc == null) return null;
    return (key: key, name: name, desc: desc);
  } catch (_) {
    return null;
  }
}

/// Kural metnini okunur satirlara boler.
///
/// SRD metni madde ayraci olarak `\n * ` ya da `\r\n* ` kullaniyor; ilk parca
/// giris cumlesidir. Kaynakta satir sonu tirelemesi de var ("move- ment"),
/// bu birlestirilir.
List<String> conditionBullets(String desc) {
  final normalized = desc
      .replaceAll('\r\n', '\n')
      // Satir sonu tirelemesi: "move- ment" -> "movement". Grup referansi
      // gerektigi icin replaceAllMapped (replaceAll `$1`'i genisletmez).
      // Tireden SONRA bosluk sarti var; "half-elf" gibi gercek tireli
      // kelimeler etkilenmez.
      .replaceAllMapped(RegExp(r'(\w)-[ \t]+(\w)'), (m) => '${m[1]}${m[2]}');

  final parts = normalized
      .split(RegExp(r'\n\s*[*•]\s*'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  return parts;
}

/// Durumun haritada gosterilecek KISA isareti.
///
/// Jetonun altina "zehirli · sersem · yere serilmis" diye yazi yazmak masanin
/// karsisindan okunmuyordu; Foundry gibi kucuk rozetler cok daha hizli
/// taraniyor. Ikon yerine HARF kullaniliyor cunku Material ikon kumesinde
/// 5e durumlarinin cogunun karsiligi yok ve zorlama ikonlar (or. "sagir" icin
/// kulak) birbirine karisiyor -- harf en azindan belirsiz degil.
///
/// Ad Turkce de olabilir Ingilizce de: iki dilin de bilinen adlari
/// eslestiriliyor, taninmayanda adin ilk harfi kullaniliyor.
({String short, int color}) conditionBadge(String name) {
  final key = name.trim().toLowerCase();
  const table = <String, ({String short, int color})>{
    'blinded': (short: 'KÖ', color: 0xFF6E6E8A),
    'kör': (short: 'KÖ', color: 0xFF6E6E8A),
    'charmed': (short: 'BÜ', color: 0xFFD27FB8),
    'büyülenmiş': (short: 'BÜ', color: 0xFFD27FB8),
    'deafened': (short: 'SA', color: 0xFF6E6E8A),
    'sağır': (short: 'SA', color: 0xFF6E6E8A),
    'frightened': (short: 'KR', color: 0xFFB07FD2),
    'korkmuş': (short: 'KR', color: 0xFFB07FD2),
    'grappled': (short: 'TU', color: 0xFF8A7250),
    'tutulmuş': (short: 'TU', color: 0xFF8A7250),
    'incapacitated': (short: 'ET', color: 0xFF9A5B5B),
    'etkisiz': (short: 'ET', color: 0xFF9A5B5B),
    'invisible': (short: 'GÖ', color: 0xFF5B8A9A),
    'görünmez': (short: 'GÖ', color: 0xFF5B8A9A),
    'paralyzed': (short: 'FE', color: 0xFF9A5B5B),
    'felç': (short: 'FE', color: 0xFF9A5B5B),
    'petrified': (short: 'TA', color: 0xFF7A7A7A),
    'taşlaşmış': (short: 'TA', color: 0xFF7A7A7A),
    'poisoned': (short: 'ZE', color: 0xFF6FA35B),
    'zehirli': (short: 'ZE', color: 0xFF6FA35B),
    'zehirlenmiş': (short: 'ZE', color: 0xFF6FA35B),
    'prone': (short: 'YE', color: 0xFF8A7250),
    'yerde': (short: 'YE', color: 0xFF8A7250),
    'restrained': (short: 'KI', color: 0xFF8A7250),
    'kısıtlı': (short: 'KI', color: 0xFF8A7250),
    'stunned': (short: 'SE', color: 0xFF9A5B5B),
    'sersem': (short: 'SE', color: 0xFF9A5B5B),
    'unconscious': (short: 'BA', color: 0xFF5B5B5B),
    'baygın': (short: 'BA', color: 0xFF5B5B5B),
    'exhaustion': (short: 'YO', color: 0xFF8A6A50),
    'yorgunluk': (short: 'YO', color: 0xFF8A6A50),
    'concentrating': (short: 'KO', color: 0xFF5B8A9A),
    'konsantre': (short: 'KO', color: 0xFF5B8A9A),
  };
  final match = table[key];
  if (match != null) return match;
  // `characters` paketi dogrudan bagimlilik degil; ilk KOD BIRIMI yeterli
  // (durum adlari Latin harfleriyle basliyor).
  final trimmed = name.trim();
  final initial = trimmed.isEmpty ? '?' : trimmed.substring(0, 1);
  return (short: initial.toUpperCase(), color: 0xFF7A7A7A);
}
