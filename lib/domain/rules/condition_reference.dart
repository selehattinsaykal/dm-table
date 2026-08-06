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
