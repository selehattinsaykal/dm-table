/// DM bilgi tabani blok turleri. Her blogun verisi `dataJson` icinde tutulur;
/// alan semasi asagida her tur icin acikliktir.
enum CodexBlockType {
  /// {level: 1..3, text}
  heading,

  /// {text}
  text,

  /// {items: [String]}
  bulleted,

  /// {items: [{text, done: bool}]}
  checklist,

  /// {emoji, text}
  callout,

  /// {} — yatay ayrac
  divider,

  /// {path, caption} — path portre klasorune goreli
  image,

  /// {path, caption} — path codex_media klasorune goreli; uygulama ici oynatilir
  video,

  /// {url, label} — harici baglanti; sistem tarayicisinda acilir
  link,

  /// {header: bool, rows: [[String]]}
  table,

  /// {title, items: [{label, value: num}]} — cubuk grafik
  chart,

  /// {label, expression: "2d6+3"} — goruntule modunda tiklaninca atilir
  dice,

  /// {pageId, label} — baska bir Kayitlar sayfasina baglanti
  pageLink,

  /// {kind: CodexEntityKind, key, label} — canavar/buyu/esya/karakter detayi
  entityLink,

  /// {characterId, name} — canli oyuncu karakter kagidi karti (HP/seviye)
  characterEmbed;

  static CodexBlockType fromName(String name) =>
      values.where((t) => t.name == name).firstOrNull ?? CodexBlockType.text;
}

/// entityLink blogunun bagladigi oyun ogesi turu.
enum CodexEntityKind {
  monster,
  spell,
  item,
  magicItem,
  character;

  static CodexEntityKind fromName(String name) =>
      values.where((t) => t.name == name).firstOrNull ??
      CodexEntityKind.monster;
}
