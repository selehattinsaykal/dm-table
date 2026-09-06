/// VERI bloklarinin editorleri: tablo, grafik, sayac ve sure sayaci.
///
/// `codex_block_editors.dart`in bir parcasi (`part`), ayri kutuphane DEGIL:
/// editorlerin hepsi ozel ve tek bir `editCodexBlock` dagiticisindan
/// cagriliyor. Dosya 2400 satiri gecince yalnizca FIZIKSEL olarak bolundu.
part of 'codex_block_editors.dart';

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
      data: widget.data,
      onSave: () => {
        'header': _header,
        'rows': [
          for (final row in _rows) [for (final c in row) c.text],
        ],
      },
      appearance: (context, style, update) => [
        _StyleSwitch(
          label: l10n.codexTableZebra,
          keyName: 'zebra',
          fallback: false,
          style: style,
          update: update,
        ),
        _StyleSwitch(
          label: l10n.codexTableDense,
          keyName: 'dense',
          fallback: false,
          style: style,
          update: update,
        ),
        _StyleSwitch(
          label: l10n.codexTableBorders,
          keyName: 'borders',
          fallback: true,
          style: style,
          update: update,
        ),
      ],
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
  late CodexChartType _type = CodexChartType.fromName(widget.data['type']);
  late CodexPalette _palette = CodexPalette.fromName(widget.data['palette']);

  @override
  void initState() {
    super.initState();
    _items = [
      for (final e in (widget.data['items'] as List? ?? const []))
        (label: '${(e as Map)['label'] ?? ''}', value: '${e['value'] ?? ''}'),
    ];
    if (_items.isEmpty) _items = [(label: '', value: '')];
  }

  List<CodexChartItem> get _preview => [
    for (final e in _items)
      if (e.label.trim().isNotEmpty)
        CodexChartItem(
          label: e.label.trim(),
          value: double.tryParse(e.value.trim().replaceAll(',', '.')) ?? 0,
        ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return _EditorFrame(
      title: l10n.codexBlockChart,
      data: widget.data,
      heightAdjustable: true,
      onSave: () => {
        'title': _title.text.trim(),
        'type': _type.name,
        'palette': _palette.name,
        'items': [
          for (final e in _items)
            if (e.label.trim().isNotEmpty)
              {
                'label': e.label.trim(),
                'value': num.tryParse(e.value.trim().replaceAll(',', '.')) ?? 0,
              },
        ],
      },
      appearance: (context, style, update) => [
        _StyleSwitch(
          label: l10n.codexChartShowValues,
          keyName: 'showValues',
          fallback: true,
          style: style,
          update: update,
        ),
        _StyleSwitch(
          label: l10n.codexChartShowGrid,
          keyName: 'showGrid',
          fallback: true,
          style: style,
          update: update,
        ),
        _StyleSwitch(
          label: l10n.codexChartShowLegend,
          keyName: 'showLegend',
          fallback: true,
          style: style,
          update: update,
        ),
        _StyleSwitch(
          label: l10n.codexChartSort,
          keyName: 'sort',
          fallback: false,
          style: style,
          update: update,
        ),
      ],
      children: [
        _EnumChips<CodexChartType>(
          label: l10n.codexChartType,
          values: CodexChartType.values,
          selected: _type,
          labelFor: (t) => chartTypeLabel(l10n, t),
          onSelected: (t) => setState(() => _type = t),
        ),
        if (_type == CodexChartType.radar && _preview.length < 3)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.codexChartRadarHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        const SizedBox(height: 8),
        _EnumChips<CodexPalette>(
          label: l10n.codexChartPalette,
          values: CodexPalette.values,
          selected: _palette,
          labelFor: (p) => switch (p) {
            CodexPalette.theme => l10n.codexPaletteTheme,
            CodexPalette.brass => l10n.codexPaletteBrass,
            CodexPalette.jewel => l10n.codexPaletteJewel,
            CodexPalette.ember => l10n.codexPaletteEmber,
            CodexPalette.forest => l10n.codexPaletteForest,
            CodexPalette.mono => l10n.codexPaletteMono,
          },
          onSelected: (p) => setState(() => _palette = p),
        ),
        const SizedBox(height: 12),
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
                    onChanged: (v) => setState(
                      () => _items[i] = (label: v, value: _items[i].value),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  child: TextFormField(
                    initialValue: _items[i].value,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: InputDecoration(
                      labelText: l10n.codexChartValue,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(
                      () => _items[i] = (label: _items[i].label, value: v),
                    ),
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
        // Canli onizleme: tur/palet secimi aninda burada gorunur.
        if (_preview.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: CodexChartView(
                title: _title.text.trim(),
                type: _type,
                items: _preview,
                palette: _palette,
                surfaceColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
      ],
    );
  }
}

String chartTypeLabel(L10n l10n, CodexChartType type) => switch (type) {
  CodexChartType.bar => l10n.codexChartBar,
  CodexChartType.column => l10n.codexChartColumn,
  CodexChartType.line => l10n.codexChartLine,
  CodexChartType.area => l10n.codexChartArea,
  CodexChartType.pie => l10n.codexChartPie,
  CodexChartType.donut => l10n.codexChartDonut,
  CodexChartType.radar => l10n.codexChartRadar,
  CodexChartType.stacked => l10n.codexChartStacked,
};

// --- Sayaç ---------------------------------------------------------------

class _CounterEditor extends StatefulWidget {
  const _CounterEditor({required this.data});
  final Map<String, dynamic> data;
  @override
  State<_CounterEditor> createState() => _CounterEditorState();
}

class _CounterEditorState extends State<_CounterEditor> {
  late final _title = TextEditingController(
    text: '${widget.data['title'] ?? ''}',
  );
  late CodexCounterStyle _style = CodexCounterStyle.fromName(
    widget.data['style'],
  );
  late List<CodexCounter> _items;

  @override
  void initState() {
    super.initState();
    _items = [
      for (final e in (widget.data['items'] as List? ?? const []))
        CodexCounter.fromJson((e as Map).cast<Object?, Object?>()),
    ];
    if (_items.isEmpty) _items = [const CodexCounter(label: '')];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return _EditorFrame(
      title: l10n.codexBlockCounter,
      data: widget.data,
      onSave: () => {
        'title': _title.text.trim(),
        'style': _style.name,
        'items': [
          for (final c in _items)
            if (c.label.trim().isNotEmpty || c.value != 0)
              c.copyWith(label: c.label.trim()).toJson(),
        ],
      },
      appearance: (context, style, update) => [
        _PaletteSelector(style: style, update: update),
      ],
      children: [
        _EnumChips<CodexCounterStyle>(
          label: l10n.codexCounterStyle,
          values: CodexCounterStyle.values,
          selected: _style,
          labelFor: (s) => switch (s) {
            CodexCounterStyle.row => l10n.codexCounterStyleRow,
            CodexCounterStyle.tile => l10n.codexCounterStyleTile,
            CodexCounterStyle.chip => l10n.codexCounterStyleChip,
          },
          onSelected: (s) => setState(() => _style = s),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _title,
          decoration: InputDecoration(
            labelText: l10n.codexTitleOptional,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 4),
        for (var i = 0; i < _items.length; i++)
          _CounterFields(
            key: ValueKey(i),
            counter: _items[i],
            canRemove: _items.length > 1,
            onChanged: (c) => setState(() => _items[i] = c),
            onRemove: () => setState(() => _items.removeAt(i)),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.add),
            label: Text(l10n.codexCounterAdd),
            onPressed: () =>
                setState(() => _items.add(const CodexCounter(label: ''))),
          ),
        ),
        if (_items.any((c) => c.label.trim().isNotEmpty))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: CodexCounterView(
                title: _title.text.trim(),
                style: _style,
                counters: _items,
                interactive: false,
                onChanged: (_, _) {},
              ),
            ),
          ),
      ],
    );
  }
}

/// Tek bir sayacin alanlari: ad, deger, en az/en cok, adim, simge.
class _CounterFields extends StatelessWidget {
  const _CounterFields({
    required this.counter,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
    super.key,
  });

  final CodexCounter counter;
  final bool canRemove;
  final ValueChanged<CodexCounter> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 52,
                child: TextFormField(
                  initialValue: counter.icon ?? '',
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    labelText: '🕯',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => onChanged(counter.copyWith(icon: v.trim())),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: counter.label,
                  decoration: InputDecoration(
                    labelText: l10n.codexChartLabel,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) => onChanged(counter.copyWith(label: v)),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: canRemove ? onRemove : null,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _IntField(
                  label: l10n.codexCounterValue,
                  value: counter.value,
                  onChanged: (v) => onChanged(counter.copyWith(value: v ?? 0)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _IntField(
                  label: l10n.codexCounterMin,
                  value: counter.min,
                  nullable: true,
                  onChanged: (v) => onChanged(
                    v == null
                        ? counter.copyWith(clearMin: true)
                        : counter.copyWith(min: v),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _IntField(
                  label: l10n.codexCounterMax,
                  value: counter.max,
                  nullable: true,
                  onChanged: (v) => onChanged(
                    v == null
                        ? counter.copyWith(clearMax: true)
                        : counter.copyWith(max: v),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _IntField(
                  label: l10n.codexCounterStep,
                  value: counter.step,
                  onChanged: (v) => onChanged(
                    counter.copyWith(step: (v ?? 1).clamp(1, 1000)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IntField extends StatelessWidget {
  const _IntField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.nullable = false,
  });

  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;

  /// Bos birakilabilir mi (sinir alanlari icin: bos = sinirsiz).
  final bool nullable;

  @override
  Widget build(BuildContext context) => TextFormField(
    initialValue: value?.toString() ?? '',
    keyboardType: const TextInputType.numberWithOptions(signed: true),
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'-?\d*'))],
    decoration: InputDecoration(
      labelText: label,
      isDense: true,
      border: const OutlineInputBorder(),
    ),
    onChanged: (v) {
      final parsed = int.tryParse(v.trim());
      if (parsed == null && !nullable && v.trim().isNotEmpty) return;
      onChanged(parsed);
    },
  );
}

// --- Süre sayacı ---------------------------------------------------------

class _TimerEditor extends StatefulWidget {
  const _TimerEditor({required this.data});
  final Map<String, dynamic> data;
  @override
  State<_TimerEditor> createState() => _TimerEditorState();
}

class _TimerEditorState extends State<_TimerEditor> {
  late final _title = TextEditingController(
    text: '${widget.data['title'] ?? ''}',
  );
  late CodexTimer _timer = CodexTimer.fromJson(widget.data);

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return _EditorFrame(
      title: l10n.codexBlockTimer,
      data: widget.data,
      // Sureyi/yonu degistirmek gecmis birikimi anlamsiz kilar: sayac
      // duzenlemeden hep basa sarilmis olarak cikar.
      onSave: () => {'title': _title.text.trim(), ..._timer.reset.toJson()},
      appearance: (context, style, update) => [
        _ToneSelector(style: style, update: update),
      ],
      children: [
        _EnumChips<CodexTimerMode>(
          label: l10n.codexTimerMode,
          values: CodexTimerMode.values,
          selected: _timer.mode,
          labelFor: (m) => switch (m) {
            CodexTimerMode.countdown => l10n.codexTimerCountdown,
            CodexTimerMode.stopwatch => l10n.codexTimerStopwatch,
          },
          onSelected: (m) => setState(() => _timer = _timer.copyWith(mode: m)),
        ),
        _EnumChips<CodexTimerStyle>(
          label: l10n.codexCounterStyle,
          values: CodexTimerStyle.values,
          selected: _timer.style,
          labelFor: (s) => switch (s) {
            CodexTimerStyle.digits => l10n.codexTimerStyleDigits,
            CodexTimerStyle.bar => l10n.codexTimerStyleBar,
            CodexTimerStyle.ring => l10n.codexTimerStyleRing,
          },
          onSelected: (s) => setState(() => _timer = _timer.copyWith(style: s)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _title,
          decoration: InputDecoration(
            labelText: l10n.codexTitleOptional,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.codexTimerDuration,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        CodexDurationField(
          value: _timer.duration,
          onChanged: (d) =>
              setState(() => _timer = _timer.copyWith(duration: d)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(l10n.codexTimerAlarm),
          value: _timer.alarm,
          onChanged: (v) => setState(() => _timer = _timer.copyWith(alarm: v)),
        ),
        if (_timer.mode == CodexTimerMode.countdown)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(l10n.codexTimerLoop),
            value: _timer.loop,
            onChanged: (v) => setState(() => _timer = _timer.copyWith(loop: v)),
          ),
        Text(
          l10n.codexTimerRunningHint,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }
}
