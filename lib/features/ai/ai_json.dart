import 'dart:convert';

/// AI yanitlarindaki JSON'u cozmenin ORTAK yolu.
///
/// Dort uretecin (NPC / gorev / karsilasma / tablo) hepsi modelden "SADECE su
/// JSON nesnesini dondur" istiyor ve hepsi ayni iki sorunla karsilasiyordu:
/// modelin JSON'u duzyazi/```json citleri icine sarmasi, ve — asil can
/// sikici olani — uzun yanitlarin token butcesi dolunca ORTADAN KESILMESI.
///
/// Kesilme her uretecte ayni sekilde bozuluyordu: `jsonDecode` firlatiyor,
/// ayristirici yedek yola dusuyor ve ham metnin tamamini tek bir alana
/// dokuyordu. Kullanicinin gordugu sey "garip, tek parca bir yazi" oluyordu.
/// Once yalnizca gorev uretecinde cozulmustu; kural burada toplandi ki dordu
/// de ayni sagLamlikta olsun.

/// Metinden bir JSON nesnesi cozer; kesilmisse kurtarmayi dener.
///
/// Once normal yol: ilk `{` ile son `}` arasi. O tutmazsa yanit buyuk
/// olasilikla ortadan kesilmistir. Kok nesnenin DOGRUDAN icindeki her virgul,
/// o noktaya kadar gelen tum alanlarin TAM oldugu bir yerdir — cunku ic ice
/// yapilar kapanmadan derinlik 1'e donulemez. Bu yuzden sondan baslayarak her
/// boyle virgulde kirpip `}` ile kapatmayi deniyoruz: yarim kalan son alan
/// duser, tamamlananlarin hepsi kurtulur.
///
/// Hicbir sey kurtarilamazsa `null` doner — cagiran bunu "model gecerli JSON
/// dondurmedi" diye BILDIRMELI, sessizce metin gibi davranmamali.
Map<dynamic, dynamic>? decodeAiJsonObject(String text) {
  final start = text.indexOf('{');
  if (start == -1) return null;

  final end = text.lastIndexOf('}');
  if (end > start) {
    try {
      final map = jsonDecode(text.substring(start, end + 1));
      if (map is Map) return map;
    } catch (_) {
      // Kesilmis olabilir; asagida kurtarmayi dene.
    }
  }

  for (final cut in _topLevelCommas(text, start).reversed) {
    try {
      final map = jsonDecode('${text.substring(start, cut)}}');
      if (map is Map) return map;
    } catch (_) {
      // Daha erken bir kesme noktasini dene.
    }
  }
  return null;
}

/// Kok nesnenin dogrudan icindeki (derinlik 1) virgullerin konumlari.
///
/// Metin icindeki virgulleri ve kacisli tirnaklari atlar; aksi halde
/// `"Han \"Yesil Ejder\", bodrum"` gibi bir deger yanlis kesme noktasi
/// uretirdi.
List<int> _topLevelCommas(String text, int start) {
  final cuts = <int>[];
  var depth = 0;
  var inString = false;
  var escaped = false;

  for (var i = start; i < text.length; i++) {
    final c = text[i];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (c == r'\') {
        escaped = true;
      } else if (c == '"') {
        inString = false;
      }
      continue;
    }
    switch (c) {
      case '"':
        inString = true;
      case '{':
      case '[':
        depth++;
      case '}':
      case ']':
        depth--;
      case ',':
        if (depth == 1) cuts.add(i);
    }
  }
  return cuts;
}

/// `["a","b"]` → temizlenmis liste.
///
/// Bos/bosluk kalemler atilir. Model tek bir metin dondurduyse o tek kalem
/// sayilir (kucuk modeller tek elemanli listeleri duz string yaziyor).
List<String> aiStringList(Object? raw) {
  if (raw is String) {
    final v = raw.trim();
    return v.isEmpty ? const [] : [v];
  }
  if (raw is! List) return const [];
  final out = <String>[];
  for (final e in raw) {
    final v = '$e'.trim();
    if (v.isNotEmpty) out.add(v);
  }
  return out;
}

/// Bir haritadan kirpilmis metin alani okur.
String aiField(Map<dynamic, dynamic> map, String key) =>
    '${map[key] ?? ''}'.trim();
