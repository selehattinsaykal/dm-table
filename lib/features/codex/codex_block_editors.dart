import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/character_image_store.dart';
import '../../data/codex_media_store.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../domain/codex/codex_block.dart';
import '../../domain/rules/dice.dart';
import '../../l10n/app_localizations.dart';
import '../characters/character_providers.dart';
import '../world/pick_image_file.dart';
import 'codex_autocomplete.dart';
import 'codex_providers.dart';

final _codexImages = CharacterImageStore();
final _codexMedia = CodexMediaStore();

/// Bir blogu tipine gore duzenler ve kaydeder. Divider'in duzenleyicisi yok.
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
      return;
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
      result = await _editCharacterEmbed(context, ref);
  }
  if (result != null) {
    await ref.read(codexRepositoryProvider).updateBlock(block.id, result);
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
      onSave: () =>
          Navigator.pop(context, {'level': _level, 'text': _controller.text}),
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
  Widget build(BuildContext context) => _EditorFrame(
    title: widget.title,
    onSave: () => Navigator.pop(context, {'text': _controller.text}),
    children: [
      CodexInlineField(
        controller: _controller,
        pageTitles: widget.pageTitles,
        autofocus: true,
        maxLines: 8,
        minLines: 3,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          helperText: L10n.of(context).codexTextHint,
          helperMaxLines: 3,
        ),
      ),
    ],
  );
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
      onSave: () => Navigator.pop(context, {
        'emoji': _emoji.text.trim().isEmpty ? '💡' : _emoji.text.trim(),
        'text': _text.text,
      }),
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
      onSave: () {
        final items = <Object>[];
        for (var i = 0; i < _controllers.length; i++) {
          final t = _controllers[i].text.trim();
          if (t.isEmpty) continue;
          items.add(widget.checklist ? {'text': t, 'done': _done[i]} : t);
        }
        Navigator.pop(context, {'items': items});
      },
      children: [
        for (var i = 0; i < _controllers.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
      canSave: valid,
      onSave: () => Navigator.pop(context, {
        'label': _label.text.trim(),
        'expression': _expr.text.trim(),
      }),
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
      ],
    );
  }
}

// --- Tablo ---------------------------------------------------------------

class _TableEditor extends StatefulWidget {
  const _TableEditor({required this.data, required this.pageTitles});
  final Map<String, dynamic> data;
  final List<String> pageTitles;
  @override
  State<_TableEditor> createState() => _TableEditorState();
}

class _TableEditorState extends State<_TableEditor> {
  // CodexInlineField controller gerektirdigi icin her hucre bir controller.
  late List<List<TextEditingController>> _rows;
  late bool _header;

  @override
  void initState() {
    super.initState();
    _header = widget.data['header'] as bool? ?? true;
    final raw = ((widget.data['rows'] as List? ?? const []))
        .map((r) => (r as List).map((c) => '$c').toList())
        .toList();
    if (raw.isEmpty) {
      _rows = [
        [TextEditingController(), TextEditingController()],
        [TextEditingController(), TextEditingController()],
      ];
    } else {
      _rows = [
        for (final row in raw)
          [for (final cell in row) TextEditingController(text: cell)],
      ];
    }
  }

  @override
  void dispose() {
    for (final row in _rows) {
      for (final c in row) {
        c.dispose();
      }
    }
    super.dispose();
  }

  int get _cols => _rows.isEmpty ? 0 : _rows.first.length;

  void _addRow() => setState(() {
    _rows.add([for (var i = 0; i < _cols; i++) TextEditingController()]);
  });

  void _removeRow(int r) => setState(() {
    for (final c in _rows[r]) {
      c.dispose();
    }
    _rows.removeAt(r);
  });

  void _addColumn() => setState(() {
    for (final row in _rows) {
      row.add(TextEditingController());
    }
  });

  void _removeColumn() => setState(() {
    for (final row in _rows) {
      row.removeLast().dispose();
    }
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return _EditorFrame(
      title: l10n.codexBlockTable,
      onSave: () => Navigator.pop(context, {
        'header': _header,
        'rows': [
          for (final row in _rows) [for (final c in row) c.text],
        ],
      }),
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.codexTableHeader),
          value: _header,
          onChanged: (v) => setState(() => _header = v),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            l10n.codexTextHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),
        for (var r = 0; r < _rows.length; r++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var c = 0; c < _cols; c++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: CodexInlineField(
                        controller: _rows[r][c],
                        pageTitles: widget.pageTitles,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  onPressed: _rows.length > 1 ? () => _removeRow(r) : null,
                ),
              ],
            ),
          ),
        Row(
          children: [
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: Text(l10n.codexTableAddRow),
              onPressed: _addRow,
            ),
            TextButton.icon(
              icon: const Icon(Icons.view_column_outlined),
              label: Text(l10n.codexTableAddColumn),
              onPressed: _addColumn,
            ),
            if (_cols > 1)
              IconButton(
                tooltip: l10n.codexTableRemoveColumn,
                icon: const Icon(Icons.remove),
                onPressed: _removeColumn,
              ),
          ],
        ),
      ],
    );
  }
}

// --- Grafik --------------------------------------------------------------

class _ChartEditor extends StatefulWidget {
  const _ChartEditor({required this.data});
  final Map<String, dynamic> data;
  @override
  State<_ChartEditor> createState() => _ChartEditorState();
}

class _ChartEditorState extends State<_ChartEditor> {
  late final _title = TextEditingController(
    text: '${widget.data['title'] ?? ''}',
  );
  late List<({String label, String value})> _items;

  @override
  void initState() {
    super.initState();
    _items = [
      for (final e in (widget.data['items'] as List? ?? const []))
        (label: '${(e as Map)['label'] ?? ''}', value: '${e['value'] ?? ''}'),
    ];
    if (_items.isEmpty) _items = [(label: '', value: '')];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return _EditorFrame(
      title: l10n.codexBlockChart,
      onSave: () {
        final items = [
          for (final e in _items)
            if (e.label.trim().isNotEmpty)
              {
                'label': e.label.trim(),
                'value': num.tryParse(e.value.trim()) ?? 0,
              },
        ];
        Navigator.pop(context, {'title': _title.text.trim(), 'items': items});
      },
      children: [
        TextField(
          controller: _title,
          decoration: InputDecoration(
            labelText: l10n.codexChartTitle,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < _items.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: _items[i].label,
                    decoration: InputDecoration(
                      labelText: l10n.codexChartLabel,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (v) =>
                        _items[i] = (label: v, value: _items[i].value),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  child: TextFormField(
                    initialValue: _items[i].value,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.codexChartValue,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (v) =>
                        _items[i] = (label: _items[i].label, value: v),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _items.length > 1
                      ? () => setState(() => _items.removeAt(i))
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
            onPressed: () => setState(() => _items.add((label: '', value: ''))),
          ),
        ),
      ],
    );
  }
}

// --- Görsel --------------------------------------------------------------

Future<Map<String, dynamic>?> _editImage(
  BuildContext context,
  Map<String, dynamic> data,
  L10n l10n,
) async {
  final captionController = TextEditingController(
    text: '${data['caption'] ?? ''}',
  );
  var path = data['path'] as String?;
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => _EditorFrame(
        title: l10n.codexBlockImage,
        onSave: () => Navigator.pop(context, {
          'path': path,
          'caption': captionController.text,
        }),
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.upload),
            label: Text(
              path == null ? l10n.sheetUploadPhoto : l10n.sheetChange,
            ),
            onPressed: () async {
              final file = await pickImageFile();
              if (file == null) return;
              try {
                final stored = await _codexImages.store(file);
                setState(() => path = stored);
              } on FormatException catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(e.message)));
                }
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: captionController,
            decoration: InputDecoration(
              labelText: l10n.codexImageCaption,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
    ),
  );
}

// --- Video ---------------------------------------------------------------

Future<Map<String, dynamic>?> _editVideo(
  BuildContext context,
  Map<String, dynamic> data,
  L10n l10n,
) async {
  final captionController = TextEditingController(
    text: '${data['caption'] ?? ''}',
  );
  var path = data['path'] as String?;
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => _EditorFrame(
        title: l10n.codexBlockVideo,
        onSave: () => Navigator.pop(context, {
          'path': path,
          'caption': captionController.text,
        }),
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.upload),
            label: Text(
              path == null ? l10n.codexVideoUpload : l10n.sheetChange,
            ),
            onPressed: () async {
              final file = await pickVideoFile();
              if (file == null) return;
              final stored = await _codexMedia.store(file);
              setState(() => path = stored);
            },
          ),
          if (path != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(Icons.movie_outlined, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.codexVideoSelected,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: captionController,
            decoration: InputDecoration(
              labelText: l10n.codexImageCaption,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
    ),
  );
}

// --- Harici bağlantı -----------------------------------------------------

class _LinkEditor extends StatefulWidget {
  const _LinkEditor({required this.data});
  final Map<String, dynamic> data;
  @override
  State<_LinkEditor> createState() => _LinkEditorState();
}

class _LinkEditorState extends State<_LinkEditor> {
  late final _url = TextEditingController(text: '${widget.data['url'] ?? ''}');
  late final _label = TextEditingController(
    text: '${widget.data['label'] ?? ''}',
  );
  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return _EditorFrame(
      title: l10n.codexBlockLink,
      onSave: () => Navigator.pop(context, {
        'url': _url.text.trim(),
        'label': _label.text.trim(),
      }),
      children: [
        TextField(
          controller: _url,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: l10n.codexLinkUrl,
            hintText: 'https://…',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _label,
          decoration: InputDecoration(
            labelText: l10n.codexLinkLabel,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}

// --- Sayfa bağlantısı ----------------------------------------------------

Future<Map<String, dynamic>?> _editPageLink(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> data,
) async {
  final l10n = L10n.of(context);
  final pages = ref.read(codexPagesProvider).value ?? const [];
  var targetId = data['pageId'] as String?;
  final labelController = TextEditingController(text: '${data['label'] ?? ''}');
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => _EditorFrame(
        title: l10n.codexBlockPageLink,
        onSave: () => Navigator.pop(context, {
          'pageId': targetId,
          'label': labelController.text.trim().isEmpty
              ? (pages.where((p) => p.id == targetId).firstOrNull?.title ?? '')
              : labelController.text.trim(),
        }),
        children: [
          DropdownButtonFormField<String>(
            initialValue: targetId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.codexLinkTargetPage,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final p in pages)
                DropdownMenuItem(
                  value: p.id,
                  child: Text(
                    p.title.isEmpty ? l10n.codexUntitled : p.title,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) => setState(() => targetId = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: labelController,
            decoration: InputDecoration(
              labelText: l10n.codexLinkLabel,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
    ),
  );
}

// --- Entity bağlantısı (canavar/büyü/eşya/karakter) ----------------------

Future<Map<String, dynamic>?> _editEntityLink(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> data,
) async {
  final result =
      await showDialog<({CodexEntityKind kind, String key, String label})>(
        context: context,
        builder: (context) => _EntityPickerDialog(
          initialKind: CodexEntityKind.fromName('${data['kind'] ?? 'monster'}'),
        ),
      );
  if (result == null) return null;
  return {'kind': result.kind.name, 'key': result.key, 'label': result.label};
}

// --- Karakter gömme ------------------------------------------------------

Future<Map<String, dynamic>?> _editCharacterEmbed(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = L10n.of(context);
  // future'i bekle: Kayitlar sekmesine dogrudan gelindiginde charactersProvider
  // henuz abone olunmamis olabilir; .value o an null doner (liste bos gorunur).
  final all = await ref.read(charactersProvider.future);
  if (!context.mounted) return null;
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.codexBlockCharacter),
      content: SizedBox(
        width: 400,
        height: 360,
        child: all.isEmpty
            ? Center(child: Text(l10n.combatNeedCharacter))
            : ListView(
                children: [
                  for (final c in all)
                    ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(c.name),
                      onTap: () => Navigator.pop(context, {
                        'characterId': c.id,
                        'name': c.name,
                      }),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ],
    ),
  );
}

class _EntityPickerDialog extends ConsumerStatefulWidget {
  const _EntityPickerDialog({required this.initialKind});
  final CodexEntityKind initialKind;
  @override
  ConsumerState<_EntityPickerDialog> createState() =>
      _EntityPickerDialogState();
}

class _EntityPickerDialogState extends ConsumerState<_EntityPickerDialog> {
  late CodexEntityKind _kind = widget.initialKind;
  String _query = '';

  Future<List<({String key, String name})>> _search() async {
    final repo = ref.read(compendiumRepositoryProvider);
    switch (_kind) {
      case CodexEntityKind.monster:
        return [
          for (final m in await repo.searchMonsters(query: _query, limit: 40))
            (key: m.key, name: m.name),
        ];
      case CodexEntityKind.spell:
        return [
          for (final s in await repo.searchSpells(query: _query, limit: 40))
            (key: s.key, name: s.name),
        ];
      case CodexEntityKind.item:
        return [
          for (final i in await repo.searchItems(query: _query, limit: 40))
            (key: i.key, name: i.name),
        ];
      case CodexEntityKind.magicItem:
        return [
          for (final mi in await repo.searchMagicItems(
            query: _query,
            limit: 40,
          ))
            (key: mi.key, name: mi.name),
        ];
      case CodexEntityKind.character:
        final all = await ref.read(charactersProvider.future);
        final q = _query.toLowerCase();
        return [
          for (final c in all)
            if (q.isEmpty || c.name.toLowerCase().contains(q))
              (key: c.id, name: c.name),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return AlertDialog(
      title: Text(l10n.codexBlockEntityLink),
      content: SizedBox(
        width: 420,
        height: 460,
        child: Column(
          children: [
            SegmentedButton<CodexEntityKind>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: CodexEntityKind.monster,
                  label: Text(l10n.compendiumMonsters),
                ),
                ButtonSegment(
                  value: CodexEntityKind.spell,
                  label: Text(l10n.compendiumSpells),
                ),
                ButtonSegment(
                  value: CodexEntityKind.item,
                  label: Text(l10n.compendiumItems),
                ),
                ButtonSegment(
                  value: CodexEntityKind.magicItem,
                  label: Text(l10n.compendiumMagicItems),
                ),
                ButtonSegment(
                  value: CodexEntityKind.character,
                  label: Text(l10n.navCharacters),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: InputDecoration(
                hintText: l10n.searchHint,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<({String key, String name})>>(
                future: _search(),
                builder: (context, snap) {
                  final rows = snap.data ?? const [];
                  return ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (context, i) => ListTile(
                      dense: true,
                      title: Text(rows[i].name),
                      onTap: () => Navigator.pop(context, (
                        kind: _kind,
                        key: rows[i].key,
                        label: rows[i].name,
                      )),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}

// --- Ortak editör çerçevesi ---------------------------------------------

class _EditorFrame extends StatelessWidget {
  const _EditorFrame({
    required this.title,
    required this.onSave,
    required this.children,
    this.canSave = true,
  });

  final String title;
  final VoidCallback onSave;
  final List<Widget> children;
  final bool canSave;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          ...children,
          const SizedBox(height: 16),
          FilledButton(
            onPressed: canSave ? onSave : null,
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}
