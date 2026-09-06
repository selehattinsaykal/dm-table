/// Editorlerin ORTAK CERCEVESI ve gorunum denetimleri: genislik,
/// hizalama, yukseklik, ton, palet, cip bicimi.
///
/// `codex_block_editors.dart`in bir parcasi; bkz. `codex_editors_data`.
part of 'codex_block_editors.dart';

// --- Ortak editör çerçevesi ---------------------------------------------

/// Tur-ozel gorunum denetimlerini kuran geri cagirim.
///
/// [style] blogun gorunum alanlarini tutan DEGISTIRILEBILIR haritadir;
/// [update] ile degistirilir (setState sarmalayicisi).
typedef _AppearanceBuilder =
    List<Widget> Function(
      BuildContext context,
      Map<String, dynamic> style,
      void Function(VoidCallback) update,
    );

/// Tum blok editorlerinin ortak kabugu: baslik, tur-ozel alanlar, katlanabilir
/// "Gorunum" bolumu (yerlesim + tur-ozel stil) ve Kaydet dugmesi.
class _EditorFrame extends StatefulWidget {
  const _EditorFrame({
    required this.title,
    required this.onSave,
    required this.children,
    this.data = const {},
    this.appearance,
    this.canSave = true,
    this.heightAdjustable = false,
  });

  final String title;

  /// Tur-ozel alanlar. Gorunum alanlari cerceve tarafindan eklenir.
  final Map<String, dynamic> Function() onSave;

  final List<Widget> children;

  /// Blogun mevcut verisi (gorunum alanlarinin baslangic degerleri icin).
  final Map<String, dynamic> data;

  final _AppearanceBuilder? appearance;
  final bool canSave;

  /// Yukseklik ayari gosterilsin mi (gorsel/video/grafik).
  final bool heightAdjustable;

  @override
  State<_EditorFrame> createState() => _EditorFrameState();
}

class _EditorFrameState extends State<_EditorFrame> {
  late final Map<String, dynamic> _style = _styleOf(widget.data);

  CodexLayout get _layout => CodexLayout.fromData(_style);

  void _setLayout(CodexLayout next) => setState(() {
    _style.addAll(next.toData());
    if (next.height == null) _style.remove('height');
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final layout = _layout;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            ...widget.children,
            const SizedBox(height: 8),
            Theme(
              // Bolum kapali dururken cerceve cizgisi gorunmesin.
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                leading: const Icon(Icons.tune, size: 20),
                title: Text(
                  l10n.codexAppearance,
                  style: theme.textTheme.titleSmall,
                ),
                children: [
                  _WidthControl(
                    layout: layout,
                    onChanged: _setLayout,
                    label: l10n.codexWidth,
                  ),
                  const SizedBox(height: 4),
                  _AlignControl(
                    layout: layout,
                    onChanged: _setLayout,
                    label: l10n.codexAlign,
                  ),
                  if (widget.heightAdjustable)
                    _HeightControl(
                      layout: layout,
                      onChanged: _setLayout,
                      label: l10n.codexHeight,
                      autoLabel: l10n.codexHeightAuto,
                    ),
                  ...?widget.appearance?.call(context, _style, (fn) {
                    setState(fn);
                  }),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      l10n.codexResizeHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: widget.canSave
                  // Once gorunum alanlari, sonra tur-ozel alanlar: ayni adi
                  // tasiyan bir alani (ornegin `style`) editorun dondurdugu
                  // deger kazanir.
                  ? () =>
                        Navigator.pop(context, {..._style, ...widget.onSave()})
                  : null,
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Görünüm denetimleri -------------------------------------------------

class _WidthControl extends StatelessWidget {
  const _WidthControl({
    required this.layout,
    required this.onChanged,
    required this.label,
  });

  final CodexLayout layout;
  final ValueChanged<CodexLayout> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: theme.textTheme.bodyMedium),
            const Spacer(),
            Text(
              '%${(layout.width * 100).round()}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        Slider(
          value: layout.width,
          min: CodexLayout.minWidth,
          max: 1,
          divisions: 17,
          onChanged: (v) => onChanged(layout.copyWith(width: v)),
        ),
        Wrap(
          spacing: 6,
          children: [
            for (final preset in const [0.25, 0.33, 0.5, 0.66, 0.75, 1.0])
              ChoiceChip(
                label: Text('%${(preset * 100).round()}'),
                selected: (layout.width - preset).abs() < 0.02,
                onSelected: (_) => onChanged(layout.copyWith(width: preset)),
              ),
          ],
        ),
      ],
    );
  }
}

class _AlignControl extends StatelessWidget {
  const _AlignControl({
    required this.layout,
    required this.onChanged,
    required this.label,
  });

  final CodexLayout layout;
  final ValueChanged<CodexLayout> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Row(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(width: 12),
        Expanded(
          child: SegmentedButton<CodexAlign>(
            showSelectedIcon: false,
            segments: [
              for (final align in CodexAlign.values)
                ButtonSegment(
                  value: align,
                  icon: Icon(align.icon, size: 18),
                  tooltip: switch (align) {
                    CodexAlign.left => l10n.codexAlignLeft,
                    CodexAlign.center => l10n.codexAlignCenter,
                    CodexAlign.right => l10n.codexAlignRight,
                  },
                ),
            ],
            selected: {layout.align},
            onSelectionChanged: (s) =>
                onChanged(layout.copyWith(align: s.first)),
          ),
        ),
      ],
    );
  }
}

class _HeightControl extends StatelessWidget {
  const _HeightControl({
    required this.layout,
    required this.onChanged,
    required this.label,
    required this.autoLabel,
  });

  final CodexLayout layout;
  final ValueChanged<CodexLayout> onChanged;
  final String label;
  final String autoLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final height = layout.height;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: theme.textTheme.bodyMedium),
            const Spacer(),
            Text(
              height == null ? autoLabel : '${height.round()} px',
              style: theme.textTheme.bodySmall,
            ),
            Switch(
              value: height != null,
              onChanged: (on) => onChanged(
                on
                    ? layout.copyWith(height: 240)
                    : layout.copyWith(clearHeight: true),
              ),
            ),
          ],
        ),
        if (height != null)
          Slider(
            value: height.clamp(CodexLayout.minHeight, 900),
            min: CodexLayout.minHeight,
            max: 900,
            divisions: 41,
            onChanged: (v) => onChanged(layout.copyWith(height: v)),
          ),
      ],
    );
  }
}

/// Anahtarli acma/kapama (gorunum haritasindaki bir bool alan).
class _StyleSwitch extends StatelessWidget {
  const _StyleSwitch({
    required this.label,
    required this.keyName,
    required this.fallback,
    required this.style,
    required this.update,
  });

  final String label;
  final String keyName;
  final bool fallback;
  final Map<String, dynamic> style;
  final void Function(VoidCallback) update;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    dense: true,
    title: Text(label),
    value: style[keyName] as bool? ?? fallback,
    onChanged: (v) => update(() => style[keyName] = v),
  );
}

/// Kaydirmali sayisal alan (kose yuvarlakligi, kalinlik...).
class _StyleSlider extends StatelessWidget {
  const _StyleSlider({
    required this.label,
    required this.keyName,
    required this.fallback,
    required this.min,
    required this.max,
    required this.style,
    required this.update,
    this.format,
  });

  final String label;
  final String keyName;
  final double fallback;
  final double min;
  final double max;
  final Map<String, dynamic> style;
  final void Function(VoidCallback) update;
  final String Function(double)? format;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = ((style[keyName] as num?)?.toDouble() ?? fallback).clamp(
      min,
      max,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: theme.textTheme.bodyMedium),
            const Spacer(),
            Text(
              format?.call(value) ?? '${value.round()}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: (v) => update(() => style[keyName] = v),
        ),
      ],
    );
  }
}

/// Metin olcegi (0.7x–2.2x).
class _TextSizeSlider extends StatelessWidget {
  const _TextSizeSlider({required this.style, required this.update});

  final Map<String, dynamic> style;
  final void Function(VoidCallback) update;

  @override
  Widget build(BuildContext context) => _StyleSlider(
    label: L10n.of(context).codexTextSize,
    keyName: 'size',
    fallback: 1,
    min: 0.7,
    max: 2.2,
    style: style,
    update: update,
    format: (v) => '${(v * 100).round()}%',
  );
}

class _ToneSelector extends StatelessWidget {
  const _ToneSelector({required this.style, required this.update});

  final Map<String, dynamic> style;
  final void Function(VoidCallback) update;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return _EnumChips<CodexTone>(
      label: l10n.codexTone,
      values: CodexTone.values,
      selected: CodexTone.fromName(style['tone']),
      labelFor: (t) => switch (t) {
        CodexTone.neutral => l10n.codexToneNeutral,
        CodexTone.info => l10n.codexToneInfo,
        CodexTone.success => l10n.codexToneSuccess,
        CodexTone.warning => l10n.codexToneWarning,
        CodexTone.danger => l10n.codexToneDanger,
        CodexTone.arcane => l10n.codexToneArcane,
        CodexTone.gold => l10n.codexToneGold,
      },
      colorFor: (t) => codexToneColors(context, t).accent,
      onSelected: (t) => update(() => style['tone'] = t.name),
    );
  }
}

class _PaletteSelector extends StatelessWidget {
  const _PaletteSelector({required this.style, required this.update});

  final Map<String, dynamic> style;
  final void Function(VoidCallback) update;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return _EnumChips<CodexPalette>(
      label: l10n.codexChartPalette,
      values: CodexPalette.values,
      selected: CodexPalette.fromName(style['palette']),
      labelFor: (p) => switch (p) {
        CodexPalette.theme => l10n.codexPaletteTheme,
        CodexPalette.brass => l10n.codexPaletteBrass,
        CodexPalette.jewel => l10n.codexPaletteJewel,
        CodexPalette.ember => l10n.codexPaletteEmber,
        CodexPalette.forest => l10n.codexPaletteForest,
        CodexPalette.mono => l10n.codexPaletteMono,
      },
      colorFor: (p) => codexPaletteColors(context, p, 1).first,
      onSelected: (p) => update(() => style['palette'] = p.name),
    );
  }
}

class _ChipStyleSelector extends StatelessWidget {
  const _ChipStyleSelector({required this.style, required this.update});

  final Map<String, dynamic> style;
  final void Function(VoidCallback) update;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return _EnumChips<CodexChipStyle>(
      label: l10n.codexChipStyle,
      values: CodexChipStyle.values,
      selected: CodexChipStyle.fromName(style['chipStyle']),
      labelFor: (s) => switch (s) {
        CodexChipStyle.chip => l10n.codexChipStyleChip,
        CodexChipStyle.button => l10n.codexChipStyleButton,
        CodexChipStyle.card => l10n.codexChipStyleCard,
      },
      onSelected: (s) => update(() => style['chipStyle'] = s.name),
    );
  }
}

/// Etiketli secim cipleri (enum ya da dize degerler icin).
class _EnumChips<T> extends StatelessWidget {
  const _EnumChips({
    required this.label,
    required this.values,
    required this.selected,
    required this.labelFor,
    required this.onSelected,
    this.colorFor,
  });

  final String label;
  final List<T> values;
  final T selected;
  final String Function(T) labelFor;
  final ValueChanged<T> onSelected;
  final Color Function(T)? colorFor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final value in values)
                ChoiceChip(
                  avatar: colorFor == null
                      ? null
                      : CircleAvatar(
                          backgroundColor: colorFor!(value),
                          radius: 7,
                        ),
                  label: Text(labelFor(value)),
                  selected: value == selected,
                  onSelected: (_) => onSelected(value),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
