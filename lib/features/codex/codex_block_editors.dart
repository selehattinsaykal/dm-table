import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/character_image_store.dart';
import '../../data/codex_media_store.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../domain/codex/codex_block.dart';
import '../../domain/codex/codex_style.dart';
import '../../domain/rules/dice.dart';
import '../../l10n/app_localizations.dart';
import '../characters/character_providers.dart';
import '../world/pick_image_file.dart';
import 'codex_autocomplete.dart';
import 'codex_charts.dart';
import 'codex_counter.dart';
import 'codex_providers.dart';
import 'codex_style_ui.dart';
import 'codex_timer.dart';

part 'codex_editors_data.dart';
part 'codex_editors_media.dart';
part 'codex_editors_controls.dart';

final _codexImages = CharacterImageStore();
final _codexMedia = CodexMediaStore();

/// Blok verisindeki "gorunum" alanlari. Bir blok duzenlendiginde tur-ozel
/// alanlar yeniden yazilir; bunlar ise korunur (aksi halde her duzenlemede
/// blogun genisligi/hizasi sifirlanirdi).
const _styleKeys = {
  'width',
  'align',
  'height',
  'tone',
  'size',
  'style',
  'thickness',
  'fit',
  'radius',
  'frame',
  'loop',
  'muted',
  'chipStyle',
  'palette',
  'zebra',
  'dense',
  'borders',
  'ordered',
  'marker',
  'strike',
  'progress',
  'rule',
  'dropCap',
  'compact',
  'showValues',
  'showGrid',
  'showLegend',
  'sort',
  'border',
};

Map<String, dynamic> _styleOf(Map<String, dynamic> data) => {
  for (final entry in data.entries)
    if (_styleKeys.contains(entry.key)) entry.key: entry.value,
};

/// Bir blogu tipine gore duzenler ve kaydeder.
Future<void> editCodexBlock(
  BuildContext context,
  WidgetRef ref,
  CodexBlock block,
) async {
  final type = CodexBlockType.fromName(block.type);
  final data = (jsonDecode(block.dataJson) as Map).cast<String, dynamic>();
  final l10n = L10n.of(context);
  // [[wiki]] otomatik tamamlamasi icin mevcut sayfa basliklari.
  final pageTitles = <String>[
    for (final p in ref.read(codexPagesProvider).value ?? const [])
      if (p.title.isNotEmpty) p.title,
  ];

  Map<String, dynamic>? result;
  switch (type) {
    case CodexBlockType.divider:
      result = await _sheet(context, _DividerEditor(data: data));
    case CodexBlockType.heading:
      result = await _sheet(
        context,
        _HeadingEditor(data: data, pageTitles: pageTitles),
      );
    case CodexBlockType.text:
      result = await _sheet(
        context,
        _TextEditor(
          data: data,
          title: l10n.codexBlockText,
          pageTitles: pageTitles,
        ),
      );
    case CodexBlockType.callout:
      result = await _sheet(
        context,
        _CalloutEditor(data: data, pageTitles: pageTitles),
      );
    case CodexBlockType.bulleted:
      result = await _sheet(
        context,
        _ItemsEditor(data: data, checklist: false, pageTitles: pageTitles),
      );
    case CodexBlockType.checklist:
      result = await _sheet(
        context,
        _ItemsEditor(data: data, checklist: true, pageTitles: pageTitles),
      );
    case CodexBlockType.dice:
      result = await _sheet(context, _DiceEditor(data: data));
    case CodexBlockType.table:
      result = await _sheet(
        context,
        _TableEditor(data: data, pageTitles: pageTitles),
      );
    case CodexBlockType.chart:
      result = await _sheet(context, _ChartEditor(data: data));
    case CodexBlockType.counter:
      result = await _sheet(context, _CounterEditor(data: data));
    case CodexBlockType.timer:
      result = await _sheet(context, _TimerEditor(data: data));
    case CodexBlockType.image:
      result = await _editImage(context, data, l10n);
    case CodexBlockType.video:
      result = await _editVideo(context, data, l10n);
    case CodexBlockType.link:
      result = await _sheet(context, _LinkEditor(data: data));
    case CodexBlockType.pageLink:
      result = await _editPageLink(context, ref, data);
    case CodexBlockType.entityLink:
      result = await _editEntityLink(context, ref, data);
    case CodexBlockType.characterEmbed:
      result = await _editCharacterEmbed(context, ref, data);
  }
  if (result != null) {
    // Once eski gorunum alanlari, sonra editorun dondurdukleri: editor bir
    // gorunum alanini degistirdiyse onun degeri kazanir.
    await ref.read(codexRepositoryProvider).updateBlock(block.id, {
      ..._styleOf(data),
      ...result,
    });
  }
}

Future<Map<String, dynamic>?> _sheet(BuildContext context, Widget child) =>
    showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: child,
      ),
    );

// --- Basit metin editörleri ---------------------------------------------

class _HeadingEditor extends StatefulWidget {
  const _HeadingEditor({required this.data, required this.pageTitles});
  final Map<String, dynamic> data;
  final List<String> pageTitles;
  @override
  State<_HeadingEditor> createState() => _HeadingEditorState();
}

class _HeadingEditorState extends State<_HeadingEditor> {
  late final _controller = TextEditingController(
    text: '${widget.data['text'] ?? ''}',
  );
  late int _level = (widget.data['level'] as int? ?? 2).clamp(1, 3);

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return _EditorFrame(
      title: l10n.codexBlockHeading,
      data: widget.data,
      onSave: () => {'level': _level, 'text': _controller.text},
      appearance: (context, style, update) => [
        _ToneSelector(style: style, update: update),
        _TextSizeSlider(style: style, update: update),
        _StyleSwitch(
          label: l10n.codexHeadingRule,
          keyName: 'rule',
          fallback: false,
          style: style,
          update: update,
        ),
      ],
      children: [
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 1, label: Text('H1')),
            ButtonSegment(value: 2, label: Text('H2')),
            ButtonSegment(value: 3, label: Text('H3')),
          ],
          selected: {_level},
          onSelectionChanged: (s) => setState(() => _level = s.first),
        ),
        const SizedBox(height: 12),
        CodexInlineField(
          controller: _controller,
          pageTitles: widget.pageTitles,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
      ],
    );
  }
}

class _TextEditor extends StatefulWidget {
  const _TextEditor({
    required this.data,
    required this.title,
    required this.pageTitles,
  });
  final Map<String, dynamic> data;
  final String title;
  final List<String> pageTitles;
  @override
  State<_TextEditor> createState() => _TextEditorState();
}

class _TextEditorState extends State<_TextEditor> {
  late final _controller = TextEditingController(
    text: '${widget.data['text'] ?? ''}',
  );
  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return _EditorFrame(
      title: widget.title,
      data: widget.data,
      onSave: () => {'text': _controller.text},
      appearance: (context, style, update) => [
        _ToneSelector(style: style, update: update),
        _TextSizeSlider(style: style, update: update),
        _StyleSwitch(
          label: l10n.codexDropCap,
          keyName: 'dropCap',
          fallback: false,
          style: style,
          update: update,
        ),
      ],
      children: [
        CodexInlineField(
          controller: _controller,
          pageTitles: widget.pageTitles,
          autofocus: true,
          maxLines: 8,
          minLines: 3,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            helperText: l10n.codexTextHint,
            helperMaxLines: 3,
          ),
        ),
      ],
    );
  }
}

class _CalloutEditor extends StatefulWidget {
  const _CalloutEditor({required this.data, required this.pageTitles});
  final Map<String, dynamic> data;
  final List<String> pageTitles;
  @override
  State<_CalloutEditor> createState() => _CalloutEditorState();
}

class _CalloutEditorState extends State<_CalloutEditor> {
  late final _emoji = TextEditingController(
    text: '${widget.data['emoji'] ?? '💡'}',
  );
  late final _text = TextEditingController(
    text: '${widget.data['text'] ?? ''}',
  );
  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return _EditorFrame(
      title: l10n.codexBlockCallout,
      data: widget.data,
      onSave: () => {
        'emoji': _emoji.text.trim().isEmpty ? '💡' : _emoji.text.trim(),
        'text': _text.text,
      },
      appearance: (context, style, update) => [
        _ToneSelector(style: style, update: update),
        _TextSizeSlider(style: style, update: update),
        _StyleSwitch(
          label: l10n.codexCalloutBorder,
          keyName: 'border',
          fallback: true,
          style: style,
          update: update,
        ),
      ],
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 64,
              child: TextField(
                controller: _emoji,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  labelText: '😀',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: CodexInlineField(
                controller: _text,
                pageTitles: widget.pageTitles,
                autofocus: true,
                maxLines: 4,
                minLines: 2,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// --- Ayraç ---------------------------------------------------------------

class _DividerEditor extends StatefulWidget {
  const _DividerEditor({required this.data});
  final Map<String, dynamic> data;
  @override
  State<_DividerEditor> createState() => _DividerEditorState();
}

class _DividerEditorState extends State<_DividerEditor> {
  late CodexDividerStyle _style = CodexDividerStyle.fromName(
    widget.data['style'],
  );

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return _EditorFrame(
      title: l10n.codexBlockDivider,
      data: widget.data,
      onSave: () => {'style': _style.name},
      children: [
        _EnumChips<CodexDividerStyle>(
          label: l10n.codexDividerStyle,
          values: CodexDividerStyle.values,
          selected: _style,
          labelFor: (s) => switch (s) {
            CodexDividerStyle.ornament => l10n.codexDividerOrnament,
            CodexDividerStyle.line => l10n.codexDividerLine,
            CodexDividerStyle.dashed => l10n.codexDividerDashed,
            CodexDividerStyle.thick => l10n.codexDividerThick,
            CodexDividerStyle.dots => l10n.codexDividerDots,
            CodexDividerStyle.space => l10n.codexDividerSpace,
          },
          onSelected: (s) => setState(() => _style = s),
        ),
      ],
      appearance: (context, style, update) => [
        _ToneSelector(style: style, update: update),
        _StyleSlider(
          label: l10n.codexDividerThick,
          keyName: 'thickness',
          fallback: 1,
          min: 0.5,
          max: 6,
          style: style,
          update: update,
          format: (v) => v.toStringAsFixed(1),
        ),
      ],
    );
  }
}

// --- Liste (madde / onay) ------------------------------------------------

class _ItemsEditor extends StatefulWidget {
  const _ItemsEditor({
    required this.data,
    required this.checklist,
    required this.pageTitles,
  });
  final Map<String, dynamic> data;
  final bool checklist;
  final List<String> pageTitles;
  @override
  State<_ItemsEditor> createState() => _ItemsEditorState();
}

class _ItemsEditorState extends State<_ItemsEditor> {
  // CodexInlineField controller gerektirdigi icin her satir bir controller.
  late List<TextEditingController> _controllers;
  // Checklist'te "yapildi" durumu; duzenlerken korunur (sifirlanmaz).
  late List<bool> _done;

  @override
  void initState() {
    super.initState();
    _controllers = [];
    _done = [];
    for (final e in (widget.data['items'] as List? ?? const [])) {
      if (widget.checklist) {
        _controllers.add(
          TextEditingController(text: '${(e as Map)['text'] ?? ''}'),
        );
        _done.add(e['done'] as bool? ?? false);
      } else {
        _controllers.add(TextEditingController(text: '$e'));
        _done.add(false);
      }
    }
    if (_controllers.isEmpty) {
      _controllers.add(TextEditingController());
      _done.add(false);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addRow() => setState(() {
    _controllers.add(TextEditingController());
    _done.add(false);
  });

  void _removeRow(int i) => setState(() {
    _controllers.removeAt(i).dispose();
    _done.removeAt(i);
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return _EditorFrame(
      title: widget.checklist
          ? l10n.codexBlockChecklist
          : l10n.codexBlockBulleted,
      data: widget.data,
      onSave: () {
        final items = <Object>[];
        for (var i = 0; i < _controllers.length; i++) {
          final t = _controllers[i].text.trim();
          if (t.isEmpty) continue;
          items.add(widget.checklist ? {'text': t, 'done': _done[i]} : t);
        }
        return {'items': items};
      },
      appearance: (context, style, update) => [
        _TextSizeSlider(style: style, update: update),
        if (widget.checklist) ...[
          _StyleSwitch(
            label: l10n.codexChecklistProgress,
            keyName: 'progress',
            fallback: false,
            style: style,
            update: update,
          ),
          _StyleSwitch(
            label: l10n.codexChecklistStrike,
            keyName: 'strike',
            fallback: true,
            style: style,
            update: update,
          ),
        ] else ...[
          _StyleSwitch(
            label: l10n.codexListOrdered,
            keyName: 'ordered',
            fallback: false,
            style: style,
            update: update,
          ),
          if (style['ordered'] != true)
            _EnumChips<String>(
              label: l10n.codexListMarker,
              values: const ['•', '–', '◆', '›', '★', '⚔'],
              selected: '${style['marker'] ?? '•'}',
              labelFor: (m) => m,
              onSelected: (m) => update(() => style['marker'] = m),
            ),
        ],
        _StyleSwitch(
          label: l10n.codexListDense,
          keyName: 'dense',
          fallback: false,
          style: style,
          update: update,
        ),
      ],
      children: [
        for (var i = 0; i < _controllers.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.checklist)
                  Checkbox(
                    value: _done[i],
                    onChanged: (v) => setState(() => _done[i] = v ?? false),
                  ),
                Expanded(
                  child: CodexInlineField(
                    controller: _controllers[i],
                    pageTitles: widget.pageTitles,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _controllers.length > 1
                      ? () => _removeRow(i)
                      : null,
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.add),
            label: Text(l10n.codexAddItem),
            onPressed: _addRow,
          ),
        ),
      ],
    );
  }
}

// --- Zar -----------------------------------------------------------------

class _DiceEditor extends StatefulWidget {
  const _DiceEditor({required this.data});
  final Map<String, dynamic> data;
  @override
  State<_DiceEditor> createState() => _DiceEditorState();
}

class _DiceEditorState extends State<_DiceEditor> {
  late final _label = TextEditingController(
    text: '${widget.data['label'] ?? ''}',
  );
  late final _expr = TextEditingController(
    text: '${widget.data['expression'] ?? '1d20'}',
  );
  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final valid = parseDiceExpression(_expr.text) != null;
    return _EditorFrame(
      title: l10n.codexBlockDice,
      data: widget.data,
      canSave: valid,
      onSave: () => {
        'label': _label.text.trim(),
        'expression': _expr.text.trim(),
      },
      appearance: (context, style, update) => [
        _ChipStyleSelector(style: style, update: update),
        _ToneSelector(style: style, update: update),
      ],
      children: [
        TextField(
          controller: _label,
          decoration: InputDecoration(
            labelText: l10n.codexDiceLabel,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _expr,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: l10n.codexDiceExpression,
            hintText: '2d6+3',
            errorText: valid ? null : l10n.codexBadExpression,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: [
            for (final preset in const [
              '1d20',
              '1d20+5',
              '2d6+3',
              '1d4',
              '1d8',
              '1d100',
            ])
              ActionChip(
                label: Text(preset),
                onPressed: () => setState(() => _expr.text = preset),
              ),
          ],
        ),
      ],
    );
  }
}
