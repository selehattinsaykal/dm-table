import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Kayitlar metin editorlerinde yazarken otomatik tamamlama: `[[wiki]]` sayfa
/// baglantilari ve `/` slash komutlari. Alttaki cozumleme SAF (test edilebilir);
/// [CodexInlineField] bunu bir metin alanina sarar.

enum CodexSuggestKind { wiki, slash }

/// Imlecin hemen solunda aktif bir tamamlama tetigi.
class CodexSuggestion {
  const CodexSuggestion({
    required this.kind,
    required this.start,
    required this.query,
  });

  final CodexSuggestKind kind;

  /// Tetigin (dahil) metindeki baslangic indeksi ([[ ya da /).
  final int start;

  /// Tetigin ardindan yazilan kismi metin (wiki: [[ sonrasi; slash: / sonrasi).
  final String query;

  @override
  bool operator ==(Object other) =>
      other is CodexSuggestion &&
      other.kind == kind &&
      other.start == start &&
      other.query == query;

  @override
  int get hashCode => Object.hash(kind, start, query);

  @override
  String toString() => '${kind.name}@$start:"$query"';
}

// Imlece kadar olan metnin sonunda kapanmamis bir tetik ariyoruz.
final _wikiTrigger = RegExp(r'\[\[([^\[\]\n]*)$');
final _slashTrigger = RegExp(r'(?<=^|\s)/([a-zA-Z]*)$');

/// [text] ve [cursor] icin imlecin solundaki aktif tetigi doner; yoksa null.
CodexSuggestion? codexActiveSuggestion(String text, int cursor) {
  if (cursor < 0 || cursor > text.length) return null;
  final prefix = text.substring(0, cursor);

  final wiki = _wikiTrigger.firstMatch(prefix);
  if (wiki != null) {
    return CodexSuggestion(
      kind: CodexSuggestKind.wiki,
      start: wiki.start,
      query: wiki.group(1) ?? '',
    );
  }

  final slash = _slashTrigger.firstMatch(prefix);
  if (slash != null) {
    return CodexSuggestion(
      kind: CodexSuggestKind.slash,
      start: slash.start,
      query: slash.group(1) ?? '',
    );
  }
  return null;
}

/// Bir slash komutu sablonu; secilince [template] eklenir ve imlec
/// [start]+[caretOffset]'e konur (parantezli komutlarda parantez icine).
class CodexSlashOption {
  const CodexSlashOption(this.label, this.template, this.caretOffset);
  final String label;
  final String template;
  final int caretOffset;
}

const codexSlashOptions = <CodexSlashOption>[
  CodexSlashOption('/r  (zar)', '/r', 2),
  CodexSlashOption('/character(…)', '/character()', 11),
  CodexSlashOption('/monster(…)', '/monster()', 9),
  CodexSlashOption('/spell(…)', '/spell()', 7),
  CodexSlashOption('/item(…)', '/item()', 6),
  // Iki argumanli: (hedef)(gorunen kelime); imlec ilk parantez icine gelir.
  CodexSlashOption('/link(url)(kelime)', '/link()()', 6),
  CodexSlashOption('/page(başlık)(kelime)', '/page()()', 6),
];

/// Wiki tamamlamasini uygular: [[start..cursor]] araligina `[[title]]` yazar.
TextEditingValue codexApplyWiki(
  String text,
  int start,
  int cursor,
  String title,
) {
  final insert = '[[$title]]';
  final newText = text.substring(0, start) + insert + text.substring(cursor);
  return TextEditingValue(
    text: newText,
    selection: TextSelection.collapsed(offset: start + insert.length),
  );
}

/// Slash tamamlamasini uygular: [start..cursor] araligina sablonu yazar.
TextEditingValue codexApplySlash(
  String text,
  int start,
  int cursor,
  CodexSlashOption option,
) {
  final newText =
      text.substring(0, start) + option.template + text.substring(cursor);
  return TextEditingValue(
    text: newText,
    selection: TextSelection.collapsed(offset: start + option.caretOffset),
  );
}

/// `[[wiki]]` ve `/slash` yazarken oneri listesi acan metin alani. Oneriler
/// alanin hemen altinda gosterilir (imlece sabitlenmis kaplama yerine, alt
/// panel editorlerinde guvenilir calisir).
class CodexInlineField extends StatefulWidget {
  const CodexInlineField({
    required this.controller,
    required this.pageTitles,
    this.decoration,
    this.minLines,
    this.maxLines = 1,
    this.autofocus = false,
    super.key,
  });

  final TextEditingController controller;

  /// Wiki tamamlamasi icin mevcut sayfa basliklari.
  final List<String> pageTitles;

  final InputDecoration? decoration;
  final int? minLines;
  final int? maxLines;
  final bool autofocus;

  @override
  State<CodexInlineField> createState() => _CodexInlineFieldState();
}

class _CodexInlineFieldState extends State<CodexInlineField> {
  final _focus = FocusNode();
  CodexSuggestion? _active;
  List<_Entry> _entries = const [];

  /// Klavyeyle secili oneri; Tab bunu ekler. Ok tuslariyla degisir.
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_update);
    _focus.addListener(() => setState(() {}));
    // Tab/ok/Esc'i metin alanindan ONCE yakala (odak gezinmesi/imlec yerine).
    _focus.onKeyEvent = _onKey;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_update);
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (_entries.isEmpty) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.tab) {
      _entries[_selected.clamp(0, _entries.length - 1)].onTap();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() => _selected = (_selected + 1) % _entries.length);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      setState(
        () => _selected = (_selected - 1 + _entries.length) % _entries.length,
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      setState(() {
        _active = null;
        _entries = const [];
      });
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _update() {
    final sel = widget.controller.selection;
    if (!sel.isValid || !sel.isCollapsed) {
      _set(null, const []);
      return;
    }
    final active = codexActiveSuggestion(
      widget.controller.text,
      sel.baseOffset,
    );
    _set(active, active == null ? const [] : _entriesFor(active));
  }

  void _set(CodexSuggestion? active, List<_Entry> entries) {
    if (active == _active && entries.length == _entries.length) return;
    setState(() {
      _active = active;
      _entries = entries;
      _selected = 0; // liste degistiginde secimi basa al
    });
  }

  List<_Entry> _entriesFor(CodexSuggestion active) {
    switch (active.kind) {
      case CodexSuggestKind.wiki:
        final q = active.query.toLowerCase();
        return [
          for (final t in widget.pageTitles)
            if (t.isNotEmpty && (q.isEmpty || t.toLowerCase().contains(q)))
              _Entry(
                t,
                () => _apply(
                  codexApplyWiki(
                    widget.controller.text,
                    active.start,
                    widget.controller.selection.baseOffset,
                    t,
                  ),
                ),
              ),
        ].take(6).toList();
      case CodexSuggestKind.slash:
        final prefix = '/${active.query}';
        return [
          for (final o in codexSlashOptions)
            if (o.template.startsWith(prefix))
              _Entry(
                o.label,
                () => _apply(
                  codexApplySlash(
                    widget.controller.text,
                    active.start,
                    widget.controller.selection.baseOffset,
                    o,
                  ),
                ),
              ),
        ];
    }
  }

  void _apply(TextEditingValue value) {
    widget.controller.value = value;
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final show = _focus.hasFocus && _entries.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focus,
          autofocus: widget.autofocus,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          decoration: widget.decoration,
        ),
        if (show)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Material(
              color: theme.colorScheme.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: theme.dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    for (final (i, e) in _entries.indexed)
                      ListTile(
                        dense: true,
                        selected: i == _selected,
                        selectedTileColor: theme.colorScheme.primaryContainer,
                        leading: Icon(
                          _active?.kind == CodexSuggestKind.wiki
                              ? Icons.link
                              : Icons.bolt,
                          size: 18,
                        ),
                        title: Text(e.label),
                        trailing: i == _selected
                            ? Text(
                                'Tab',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              )
                            : null,
                        onTap: e.onTap,
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Entry {
  const _Entry(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;
}
