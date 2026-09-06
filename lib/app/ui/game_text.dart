import 'package:flutter/material.dart';

import '../theme.dart';

/// Kural metnini oldugu gibi degil, BICIMLENDIREREK cizer.
///
/// Kutuphane verisi (SRD, 2024 PHB ve 5etools'tan cevrilen kitaplar) tablolari
/// metnin icinde markdown olarak tasiyor:
///
/// ```text
/// Table: Armorer Spells
/// | Artificer Level | Spells |
/// |---|---|
/// | 3 | Magic Missile, Thunderwave |
/// ```
///
/// Bunu duz `Text` ile gostermek boru isaretlerinden bir duvar cikariyordu;
/// alt sinif buyu listeleri, stat bloklari ve zar tablolari okunamiyordu.
/// Burada tablolar gercek `Table` olarak, maddeler girintili, `*vurgu*` ve
/// `**kalin**` isaretleri de bicimlenerek ciziliyor.
class GameText extends StatelessWidget {
  const GameText(this.text, {this.style, this.textAlign, super.key});

  final String text;

  /// Govde stili; verilmezse okuma yazi tipiyle `bodyMedium`.
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base =
        style ?? readingStyle(context, base: theme.textTheme.bodyMedium);
    final blocks = _parse(text);
    if (blocks.isEmpty) return const SizedBox.shrink();
    return _column(context, blocks, base, textAlign);
  }
}

Widget _column(
  BuildContext context,
  List<_Block> blocks,
  TextStyle base,
  TextAlign? textAlign,
) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    for (final (index, block) in blocks.indexed)
      Padding(
        padding: EdgeInsets.only(top: index == 0 ? 0 : 10),
        child: _blockWidget(context, block, base, textAlign),
      ),
  ],
);

Widget _blockWidget(
  BuildContext context,
  _Block block,
  TextStyle base,
  TextAlign? textAlign,
) {
  final theme = Theme.of(context);
  return switch (block) {
    _Paragraph(:final text) => Text.rich(
      _inline(text, base),
      textAlign: textAlign,
    ),
    _Bullet(:final text) => Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•  ', style: base),
          Expanded(child: Text.rich(_inline(text, base))),
        ],
      ),
    ),
    _Heading(:final text) => Text.rich(
      _inline(
        text,
        base.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
      textAlign: textAlign,
    ),
    // Yan kutu: solunda serit, hafif zeminde. Icerigi ayni kurallarla
    // cizilir, boylece kutunun icindeki baslik ve tablolar da calisir.
    _Quote(:final blocks) => Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        border: Border(
          left: BorderSide(color: theme.colorScheme.primary, width: 3),
        ),
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: _column(context, blocks, base, textAlign),
    ),
    _TableBlock(:final caption, :final rows) => _TableView(
      caption: caption,
      rows: rows,
      base: base,
    ),
  };
}

sealed class _Block {
  const _Block();
}

class _Paragraph extends _Block {
  const _Paragraph(this.text);
  final String text;
}

class _Bullet extends _Block {
  const _Bullet(this.text);
  final String text;
}

class _TableBlock extends _Block {
  const _TableBlock(this.caption, this.rows);
  final String? caption;
  final List<List<String>> rows;
}

class _Heading extends _Block {
  const _Heading(this.text);
  final String text;
}

/// Yan kutu: Wizard'in "Expanding and Replacing a Spellbook" kutusu ve
/// Figurine of Wondrous Power'larin icine gomulu stat bloklari.
class _Quote extends _Block {
  const _Quote(this.blocks);
  final List<_Block> blocks;
}

final _heading = RegExp(r'^#{1,6}\s+(.+?)\s*#*$');

List<_Block> _parse(String text) {
  final blocks = <_Block>[];
  final lines = text.split('\n');
  String? pendingCaption;

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;

    if (line.startsWith('|')) {
      final rows = <List<String>>[];
      while (i < lines.length && lines[i].trim().startsWith('|')) {
        final cells = _cells(lines[i]);
        // Markdown ayrac satiri (|---|---|) tabloya girmez.
        if (!cells.every((c) => RegExp(r'^:?-{2,}:?$').hasMatch(c))) {
          rows.add(cells);
        }
        i++;
      }
      i--;
      if (rows.isNotEmpty) blocks.add(_TableBlock(pendingCaption, rows));
      pendingCaption = null;
      continue;
    }

    // "Table: Armorer Spells" satiri bir sonraki tablonun basligi.
    if (line.startsWith('Table:')) {
      pendingCaption = line.substring('Table:'.length).trim();
      continue;
    }
    if (pendingCaption != null) {
      blocks.add(_Paragraph(pendingCaption));
      pendingCaption = null;
    }

    // Blok alinti: isaret soyulup ICERIK ayni kurallarla ayristiriliyor,
    // yoksa kutunun basligi ekranda ham "> ### ..." olarak cikiyordu.
    if (line.startsWith('>')) {
      final inner = <String>[];
      while (i < lines.length && lines[i].trim().startsWith('>')) {
        inner.add(lines[i].trim().substring(1).trim());
        i++;
      }
      i--;
      final quoted = _parse(inner.join('\n'));
      if (quoted.isNotEmpty) blocks.add(_Quote(quoted));
      continue;
    }

    // Markdown basligi: Metamagic secenekleri ve Eldritch Invocation'lar bu
    // sekilde geliyor. Desteklenmedigi surece ekranda ham "### Quickened
    // Spell" yaziyordu.
    if (_heading.firstMatch(line) case final match?) {
      blocks.add(_Heading(match.group(1)!.trim()));
      continue;
    }

    if (line.startsWith('- ') || line.startsWith('• ')) {
      blocks.add(_Bullet(line.substring(2).trim()));
      continue;
    }
    blocks.add(_Paragraph(line));
  }

  if (pendingCaption != null) blocks.add(_Paragraph(pendingCaption));
  return blocks;
}

List<String> _cells(String line) {
  var trimmed = line.trim();
  if (trimmed.startsWith('|')) trimmed = trimmed.substring(1);
  if (trimmed.endsWith('|')) {
    trimmed = trimmed.substring(0, trimmed.length - 1);
  }
  return trimmed.split('|').map((c) => c.trim()).toList();
}

/// `**kalin**` ve `*vurgulu*` isaretlerini bicime cevirir.
InlineSpan _inline(String text, TextStyle base) {
  final spans = <InlineSpan>[];
  final pattern = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*');
  var index = 0;

  for (final match in pattern.allMatches(text)) {
    if (match.start > index) {
      spans.add(TextSpan(text: text.substring(index, match.start)));
    }
    final bold = match.group(1);
    spans.add(
      TextSpan(
        text: bold ?? match.group(2),
        style: bold != null
            ? const TextStyle(fontWeight: FontWeight.bold)
            : const TextStyle(fontStyle: FontStyle.italic),
      ),
    );
    index = match.end;
  }
  if (index < text.length) spans.add(TextSpan(text: text.substring(index)));
  return TextSpan(style: base, children: spans);
}

class _TableView extends StatelessWidget {
  const _TableView({
    required this.caption,
    required this.rows,
    required this.base,
  });

  final String? caption;
  final List<List<String>> rows;
  final TextStyle base;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final columns = rows.fold<int>(0, (a, r) => r.length > a ? r.length : a);
    // Ilk satir tamamen bossa (or. "| | |") baslik yok demektir; stat blok
    // ozetleri bu bicimde geliyor.
    final hasHeader = rows.first.any((c) => c.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (caption != null && caption!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              caption!,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(6),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Table(
              border: TableBorder.symmetric(
                inside: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              defaultColumnWidth: const IntrinsicColumnWidth(flex: 1),
              children: [
                for (final (index, row) in rows.indexed)
                  TableRow(
                    decoration: BoxDecoration(
                      color: index == 0 && hasHeader
                          ? theme.colorScheme.surfaceContainerHighest
                          : (index.isOdd
                                ? theme.colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.35)
                                : null),
                    ),
                    children: [
                      for (var c = 0; c < columns; c++)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: Text.rich(
                            _inline(
                              c < row.length ? row[c] : '',
                              index == 0 && hasHeader
                                  ? base.copyWith(fontWeight: FontWeight.bold)
                                  : base,
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
