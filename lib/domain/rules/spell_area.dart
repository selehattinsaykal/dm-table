/// Bir alan buyusunun sekli.
///
/// **Neden kendi enum'u:** bu sekiller eskiden savas haritasinin sablon
/// turleriydi (`TemplateKind`). Harita kaldirilinca sekil bilgisi yetim
/// kalmadi -- masada hala soylenen sey ("15 ft koni") bu; yalnizca
/// cizilecegi yuzey yok. Enum bu yuzden kurala tasindi.
enum SpellAreaKind { circle, cone, line, square }

/// Bir buyunun etki alani.
typedef SpellArea = ({SpellAreaKind kind, double size});

/// Buyu metninden etki alanini cikarir; bulunamazsa null.
///
/// **Neden metinden:** kutuphane verisinde alan SEKLI ayri bir alan olarak
/// YOK (`target_type` yalnizca "AREA" diyor, olcu vermiyor). Sekil ve olcu
/// tarif metninde geciyor: "a 20-foot-radius sphere", "a 60-foot cone",
/// "a 100-foot-long, 5-foot-wide line".
///
/// Bulunamazsa null donuyor ve arayuz sablon onermiyor -- yanlis bir
/// sablon onermek, hic onermemekten kotu.
SpellArea? spellAreaFrom(String description) {
  final text = description.toLowerCase();

  // Sirali taraniyor: bir buyu hem "cone" hem "line" gecirebiliyor
  // (yukseltme metninde), ILK eslesme asil etkiye ait oluyor.
  for (final rule in _rules) {
    final match = rule.pattern.firstMatch(text);
    if (match == null) continue;
    final size = double.tryParse(match.group(1) ?? '');
    if (size == null || size <= 0) continue;
    return (kind: rule.kind, size: size);
  }
  return null;
}

typedef _AreaRule = ({RegExp pattern, SpellAreaKind kind});

/// Once daha OZEL kaliplar: "radius sphere" genel "radius"tan once gelmeli.
final _rules = <_AreaRule>[
  // "20-foot-radius sphere", "20-foot radius sphere", "10-foot-radius"
  (pattern: RegExp(r'(\d+)[-\s]?foot[-\s]?radius'), kind: SpellAreaKind.circle),
  // "60-foot cone"
  (pattern: RegExp(r'(\d+)[-\s]?foot cone'), kind: SpellAreaKind.cone),
  // "100-foot-long ... line", "60-foot line"
  (
    pattern: RegExp(r'(\d+)[-\s]?foot[-\s]?(?:long[,\s-]+)?.{0,24}?line'),
    kind: SpellAreaKind.line,
  ),
  // "15-foot cube", "10-foot square"
  (
    pattern: RegExp(r'(\d+)[-\s]?foot (?:cube|square)'),
    kind: SpellAreaKind.square,
  ),
  // Yaricap sozu gecmeyen kure/silindir: "20-foot sphere".
  (
    pattern: RegExp(r'(\d+)[-\s]?foot (?:sphere|cylinder)'),
    kind: SpellAreaKind.circle,
  ),
];
