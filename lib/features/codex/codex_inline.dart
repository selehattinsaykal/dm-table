import 'package:flutter/material.dart';

/// Satir-ici parca turu. Bicimlendirme (bold/italic/code), wiki baglantisi ve
/// slash komutlari (/r zar, /character(...), /monster(...), /spell(...),
/// /item(...), /link(url)(kelime), /page(baslik)(kelime)).
enum CodexInlineKind {
  plain,
  bold,
  italic,
  code,
  wiki,
  roll,
  characterRef,
  monsterRef,
  spellRef,
  itemRef,

  /// /link(url)(kelime) — kelimeye tiklaninca url acilir. [text]=url, [label]=kelime
  link,

  /// /page(baslik)(kelime) — kelimeye tiklaninca o Kayitlar sayfasi acilir.
  /// [text]=sayfa basligi, [label]=kelime
  pageRef,
}

class CodexInlineToken {
  const CodexInlineToken(this.kind, this.text, {this.label});
  final CodexInlineKind kind;

  /// wiki/ref icin ad, roll icin zar ifadesi, link icin url, pageRef icin
  /// sayfa basligi, digerleri icin metin.
  final String text;

  /// link/pageRef icin gorunen (tiklanabilir) kelime; digerlerinde null.
  final String? label;

  @override
  bool operator ==(Object other) =>
      other is CodexInlineToken &&
      other.kind == kind &&
      other.text == text &&
      other.label == label;

  @override
  int get hashCode => Object.hash(kind, text, label);

  @override
  String toString() =>
      '${kind.name}:"$text"${label == null ? '' : '(“$label”)'}';
}

// Sira onemli: iki argumanli /link /page ve /r once, sonra tek argumanlilar,
// en sonda **/*/kod. Adlandirilmis gruplar.
final _inlinePattern = RegExp(
  r'\[\[(?<wiki>.+?)\]\]'
  r'|/link\((?<linkUrl>[^)]*)\)\((?<linkLabel>[^)]*)\)'
  r'|/page\((?<pageTitle>[^)]*)\)\((?<pageLabel>[^)]*)\)'
  r'|/r\s*(?<roll>\d*d\d+(?:\s*[+-]\s*\d+)?)'
  r'|/character\((?<char>.+?)\)'
  r'|/monster\((?<monster>.+?)\)'
  r'|/spell\((?<spell>.+?)\)'
  r'|/item\((?<item>.+?)\)'
  r'|\*\*(?<bold>.+?)\*\*'
  r'|\*(?<italic>.+?)\*'
  r'|`(?<code>.+?)`',
  caseSensitive: false,
);

/// Metni parcalarina ayirir. Saf fonksiyon (widget'sız) — test edilebilir.
List<CodexInlineToken> tokenizeCodexInline(String text) {
  final tokens = <CodexInlineToken>[];
  var last = 0;
  for (final m in _inlinePattern.allMatches(text)) {
    if (m.start > last) {
      tokens.add(
        CodexInlineToken(CodexInlineKind.plain, text.substring(last, m.start)),
      );
    }
    tokens.add(_matchToken(m));
    last = m.end;
  }
  if (last < text.length) {
    tokens.add(CodexInlineToken(CodexInlineKind.plain, text.substring(last)));
  }
  return tokens;
}

CodexInlineToken _matchToken(RegExpMatch m) {
  final linkUrl = m.namedGroup('linkUrl');
  if (linkUrl != null) {
    return CodexInlineToken(
      CodexInlineKind.link,
      linkUrl.trim(),
      label: (m.namedGroup('linkLabel') ?? '').trim(),
    );
  }
  final pageTitle = m.namedGroup('pageTitle');
  if (pageTitle != null) {
    return CodexInlineToken(
      CodexInlineKind.pageRef,
      pageTitle.trim(),
      label: (m.namedGroup('pageLabel') ?? '').trim(),
    );
  }
  for (final (name, kind) in const [
    ('wiki', CodexInlineKind.wiki),
    ('roll', CodexInlineKind.roll),
    ('char', CodexInlineKind.characterRef),
    ('monster', CodexInlineKind.monsterRef),
    ('spell', CodexInlineKind.spellRef),
    ('item', CodexInlineKind.itemRef),
    ('bold', CodexInlineKind.bold),
    ('italic', CodexInlineKind.italic),
    ('code', CodexInlineKind.code),
  ]) {
    final g = m.namedGroup(name);
    if (g != null) return CodexInlineToken(kind, g.trim());
  }
  return CodexInlineToken(CodexInlineKind.plain, m.group(0) ?? '');
}

IconData? _refIcon(CodexInlineKind kind) => switch (kind) {
  CodexInlineKind.roll => Icons.casino,
  CodexInlineKind.characterRef => Icons.person,
  CodexInlineKind.monsterRef => Icons.pest_control,
  CodexInlineKind.spellRef => Icons.auto_awesome,
  CodexInlineKind.itemRef => Icons.backpack_outlined,
  _ => null,
};

/// Bicimlendirilmis metni bir widget olarak kurar. Etkilesimli parcalar
/// (wiki/zar/ref) tiklaninca [onTap] cagrilir; [onTap] null ise (duzenleme
/// modu) tiklanamaz.
Widget buildCodexInline(
  BuildContext context,
  String text, {
  void Function(CodexInlineToken token)? onTap,
  TextStyle? style,
  TextAlign? textAlign,
}) {
  final theme = Theme.of(context);

  InlineSpan chip(CodexInlineToken token) {
    final icon = _refIcon(token.kind);
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: InkWell(
        onTap: onTap == null ? null : () => onTap(token),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 3),
              ],
              Text(
                token.text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  final spans = <InlineSpan>[
    for (final token in tokenizeCodexInline(text))
      switch (token.kind) {
        CodexInlineKind.plain => TextSpan(text: token.text),
        CodexInlineKind.bold => TextSpan(
          text: token.text,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        CodexInlineKind.italic => TextSpan(
          text: token.text,
          style: const TextStyle(fontStyle: FontStyle.italic),
        ),
        CodexInlineKind.code => TextSpan(
          text: token.text,
          style: TextStyle(
            fontFamily: 'monospace',
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        CodexInlineKind.wiki ||
        CodexInlineKind.link ||
        CodexInlineKind.pageRef => WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: InkWell(
            onTap: onTap == null ? null : () => onTap(token),
            child: Text(
              // link/pageRef gorunen kelimeyi, wiki sayfa basligini gosterir.
              (token.label != null && token.label!.isNotEmpty)
                  ? token.label!
                  : token.text,
              style: TextStyle(
                color: theme.colorScheme.primary,
                decoration: TextDecoration.underline,
                decorationColor: theme.colorScheme.primary,
                fontSize: style?.fontSize,
              ),
            ),
          ),
        ),
        _ => chip(token),
      },
  ];
  return Text.rich(
    TextSpan(children: spans),
    style: style,
    textAlign: textAlign,
  );
}
