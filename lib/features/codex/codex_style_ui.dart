import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/codex/codex_style.dart';

/// `codex_style.dart` jetonlarinin Material karsiliklari + ortak yerlesim
/// widget'lari (genislik/hizalama kutusu ve surukleyerek boyutlandirma).
///
/// Domain katmani saf Dart kaldigi icin renk/hizalama cevrimleri burada durur.

// --- Hizalama -------------------------------------------------------------

extension CodexAlignUi on CodexAlign {
  Alignment get alignment => switch (this) {
    CodexAlign.left => Alignment.centerLeft,
    CodexAlign.center => Alignment.center,
    CodexAlign.right => Alignment.centerRight,
  };

  TextAlign get textAlign => switch (this) {
    CodexAlign.left => TextAlign.start,
    CodexAlign.center => TextAlign.center,
    CodexAlign.right => TextAlign.end,
  };

  CrossAxisAlignment get crossAxis => switch (this) {
    CodexAlign.left => CrossAxisAlignment.start,
    CodexAlign.center => CrossAxisAlignment.center,
    CodexAlign.right => CrossAxisAlignment.end,
  };

  IconData get icon => switch (this) {
    CodexAlign.left => Icons.format_align_left,
    CodexAlign.center => Icons.format_align_center,
    CodexAlign.right => Icons.format_align_right,
  };
}

extension CodexMediaFitUi on CodexMediaFit {
  BoxFit get boxFit => switch (this) {
    CodexMediaFit.contain => BoxFit.contain,
    CodexMediaFit.cover => BoxFit.cover,
    CodexMediaFit.fill => BoxFit.fill,
  };
}

// --- Ton (anlamli renk) ---------------------------------------------------

/// Bir tonun zemin / metin / kenar renkleri. Tema jetonlarindan turetilir.
class CodexToneColors {
  const CodexToneColors({
    required this.background,
    required this.foreground,
    required this.border,
    required this.accent,
  });

  final Color background;
  final Color foreground;
  final Color border;

  /// Ikon/vurgu icin doygun ton (metin olarak zeminle kontrasti dusuk olabilir;
  /// govde metninde [foreground] kullan).
  final Color accent;
}

CodexToneColors codexToneColors(BuildContext context, CodexTone tone) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final fc = context.fantasyColors;

  final accent = switch (tone) {
    CodexTone.neutral => scheme.outline,
    CodexTone.info => fc.verdigris,
    CodexTone.success => fc.moss,
    CodexTone.warning => fc.gold,
    CodexTone.danger => fc.wax,
    CodexTone.arcane => fc.arcane,
    CodexTone.gold => fc.brass,
  };

  if (tone == CodexTone.neutral) {
    return CodexToneColors(
      background: scheme.surfaceContainerHighest,
      foreground: scheme.onSurface,
      border: theme.dividerColor,
      accent: scheme.onSurfaceVariant,
    );
  }

  // Zemin cok hafif tonlanir ki uzun metin okunur kalsin; metin rengi
  // yuzeyin kendi "on" rengidir (kontrast garantisi tema tarafinda).
  return CodexToneColors(
    background: Color.alphaBlend(
      accent.withValues(alpha: 0.14),
      scheme.surfaceContainerHighest,
    ),
    foreground: scheme.onSurface,
    border: accent.withValues(alpha: 0.55),
    accent: accent,
  );
}

// --- Palet ----------------------------------------------------------------

/// [count] kadar ayirt edilebilir seri rengi uretir.
///
/// Palet tohumlari tema jetonlarindan gelir; tohumlar bitince ayni renkler
/// acilip koyulastirilarak devam eder (sabit renk listesi yazilmaz).
List<Color> codexPaletteColors(
  BuildContext context,
  CodexPalette palette,
  int count,
) {
  final scheme = Theme.of(context).colorScheme;
  final fc = context.fantasyColors;

  final seeds = switch (palette) {
    CodexPalette.theme => [
      scheme.primary,
      fc.verdigris,
      fc.gold,
      fc.arcane,
      fc.moss,
      fc.wax,
    ],
    CodexPalette.brass => [fc.brass, fc.gold, fc.parchment, fc.rule, fc.ink],
    CodexPalette.jewel => [
      fc.arcane,
      fc.verdigris,
      fc.gold,
      fc.wax,
      fc.moss,
      scheme.primary,
    ],
    CodexPalette.ember => [fc.wax, fc.gold, fc.brass, scheme.error, fc.arcane],
    CodexPalette.forest => [fc.moss, fc.verdigris, fc.brass, fc.rule, fc.gold],
    CodexPalette.mono => [scheme.primary],
  };

  if (count <= 0) return const [];
  final out = <Color>[];
  for (var i = 0; i < count; i++) {
    final base = seeds[i % seeds.length];
    final cycle = i ~/ seeds.length;
    out.add(
      palette == CodexPalette.mono
          ? _shade(base, i, count)
          : (cycle == 0 ? base : _shift(base, cycle)),
    );
  }
  return out;
}

/// Tek renkli palet: acikdan koyuya duzgun dagilim.
Color _shade(Color base, int index, int count) {
  final hsl = HSLColor.fromColor(base);
  if (count <= 1) return base;
  final t = index / (count - 1);
  return hsl.withLightness((0.72 - t * 0.42).clamp(0.05, 0.95)).toColor();
}

/// Tohumlar bittiginde ayni rengi acip koyultarak yeni ton uretir.
Color _shift(Color base, int cycle) {
  final hsl = HSLColor.fromColor(base);
  final delta = 0.13 * cycle * (cycle.isOdd ? 1 : -1);
  return hsl
      .withLightness((hsl.lightness + delta).clamp(0.12, 0.9))
      .withSaturation((hsl.saturation - 0.06 * cycle).clamp(0.15, 1.0))
      .toColor();
}

// --- Yerlesim kutusu ------------------------------------------------------

/// Cocugu [layout] oranina gore daraltip hizalayan kutu.
///
/// Genislik ORAN olarak saklanir: pencere daraldiginda blok da orantili
/// kucululur, sabit piksel gibi tasmaz. Yukseklik burada UYGULANMAZ — onu
/// gorsel/video/grafik bloklari kendi icinde kullanir, boylece aciklama
/// yazisi sabit yuksekligin disinda kalir.
class CodexLayoutBox extends StatelessWidget {
  const CodexLayoutBox({required this.layout, required this.child, super.key});

  final CodexLayout layout;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (layout.isFullWidth) return child;
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        return Align(
          alignment: layout.align.alignment,
          child: SizedBox(
            width: (available * layout.width).clamp(48.0, available),
            child: child,
          ),
        );
      },
    );
  }
}

// --- Surukleyerek boyutlandirma ------------------------------------------

/// Blogu kenarlarindan surukleyerek yeniden boyutlandirilabilir yapar.
///
/// - Sol/sag kenar: genislik orani. Blok ORTALIYSA iki yandan simetrik buyur
///   (kullanicinin gordugu davranis: "ortada duruyor, genisliyor").
/// - Alt kenar / sag-alt kose: yukseklik (yalnizca [resizableHeight]).
///
/// Surukleme sirasinda yerel taslak durum kullanilir; birakildiginda
/// [onChanged] ile kalici hale gelir (her karede veritabanina yazilmaz).
class CodexResizable extends StatefulWidget {
  const CodexResizable({
    required this.layout,
    required this.enabled,
    required this.onChanged,
    required this.child,
    this.resizableHeight = false,
    this.defaultHeight = 240,
    super.key,
  });

  final CodexLayout layout;

  /// Yalnizca duzenleme modunda tutamaklar gorunur.
  final bool enabled;

  final ValueChanged<CodexLayout> onChanged;
  final Widget child;

  /// Alt kenardan yukseklik de ayarlanabilsin mi.
  final bool resizableHeight;

  /// Yukseklik ilk kez suruklendiginde baslangic degeri.
  final double defaultHeight;

  @override
  State<CodexResizable> createState() => _CodexResizableState();
}

class _CodexResizableState extends State<CodexResizable> {
  CodexLayout? _draft;
  bool _dragging = false;

  CodexLayout get _layout => _draft ?? widget.layout;

  void _commit() {
    final draft = _draft;
    setState(() {
      _draft = null;
      _dragging = false;
    });
    if (draft != null && draft != widget.layout) widget.onChanged(draft);
  }

  void _resizeWidth(
    double deltaPixels,
    double available, {
    required bool fromRight,
  }) {
    if (available <= 0) return;
    // Ortalanmis blok iki yandan ayni anda buyur/kucullur: kullanicinin
    // gordugu genislik degisimi surukledigi mesafenin iki katidir.
    final factor = _layout.align == CodexAlign.center ? 2.0 : 1.0;
    final signed = (fromRight ? deltaPixels : -deltaPixels) * factor;
    setState(() {
      _dragging = true;
      _draft = _layout.copyWith(width: _layout.width + signed / available);
    });
  }

  void _resizeHeight(double deltaPixels, double currentHeight) {
    setState(() {
      _dragging = true;
      _draft = _layout.copyWith(height: currentHeight + deltaPixels);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return CodexLayoutBox(layout: widget.layout, child: widget.child);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final layout = _layout;
        final width = (available * layout.width).clamp(48.0, available);
        final height = layout.height;

        return Align(
          alignment: layout.align.alignment,
          child: SizedBox(
            width: width,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                SizedBox(width: width, child: widget.child),
                _EdgeHandle(
                  axis: Axis.horizontal,
                  side: _HandleSide.left,
                  onDrag: (d) =>
                      _resizeWidth(d.dx, available, fromRight: false),
                  onEnd: _commit,
                ),
                _EdgeHandle(
                  axis: Axis.horizontal,
                  side: _HandleSide.right,
                  onDrag: (d) => _resizeWidth(d.dx, available, fromRight: true),
                  onEnd: _commit,
                ),
                if (widget.resizableHeight) ...[
                  _EdgeHandle(
                    axis: Axis.vertical,
                    side: _HandleSide.bottom,
                    onDrag: (d) =>
                        _resizeHeight(d.dy, height ?? widget.defaultHeight),
                    onEnd: _commit,
                  ),
                  _EdgeHandle(
                    axis: Axis.vertical,
                    side: _HandleSide.corner,
                    onDrag: (d) {
                      _resizeWidth(d.dx, available, fromRight: true);
                      _resizeHeight(d.dy, height ?? widget.defaultHeight);
                    },
                    onEnd: _commit,
                  ),
                ],
                if (_dragging)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: _SizeBadge(
                      widthFraction: layout.width,
                      height: widget.resizableHeight ? layout.height : null,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

enum _HandleSide { left, right, bottom, corner }

/// Kenar tutamagi: fare uzerine gelince belirginlesir, surukleyince boyutlandirir.
class _EdgeHandle extends StatefulWidget {
  const _EdgeHandle({
    required this.axis,
    required this.side,
    required this.onDrag,
    required this.onEnd,
  });

  final Axis axis;
  final _HandleSide side;
  final ValueChanged<Offset> onDrag;
  final VoidCallback onEnd;

  @override
  State<_EdgeHandle> createState() => _EdgeHandleState();
}

class _EdgeHandleState extends State<_EdgeHandle> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cursor = switch (widget.side) {
      _HandleSide.left => SystemMouseCursors.resizeLeftRight,
      _HandleSide.right => SystemMouseCursors.resizeLeftRight,
      _HandleSide.bottom => SystemMouseCursors.resizeUpDown,
      _HandleSide.corner => SystemMouseCursors.resizeDownRight,
    };

    // Tutamak gorseli: dinlenmede sessiz, uzerine gelince birincil renkte.
    final bar = Center(
      child: Container(
        width: widget.axis == Axis.horizontal ? 4 : 44,
        height: widget.axis == Axis.horizontal ? 44 : 4,
        decoration: BoxDecoration(
          color: _hover
              ? scheme.primary
              : scheme.onSurfaceVariant.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(2),
          boxShadow: _hover
              ? [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.3),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
      ),
    );

    final knob = Center(
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: _hover ? scheme.primary : scheme.surfaceContainerHighest,
          border: Border.all(color: scheme.primary, width: 1.5),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );

    final child = MouseRegion(
      // Anahtar testlerde tutamagi bulmak icin (kenar surukleme davranisi).
      key: ValueKey('codexResize-${widget.side.name}'),
      cursor: cursor,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) => widget.onDrag(d.delta),
        onPanEnd: (_) => widget.onEnd(),
        onPanCancel: widget.onEnd,
        child: widget.side == _HandleSide.corner ? knob : bar,
      ),
    );

    // Tutamaklar blogun ICINDE durur: Stack disina tasan bir parca boyanir
    // ama TIKLANAMAZ (isabet testi ana kutunun sinirlariyla kesilir).
    return switch (widget.side) {
      _HandleSide.left => Positioned(
        left: 0,
        top: 0,
        bottom: 0,
        width: 16,
        child: child,
      ),
      _HandleSide.right => Positioned(
        right: 0,
        top: 0,
        bottom: 0,
        width: 16,
        child: child,
      ),
      _HandleSide.bottom => Positioned(
        left: 16,
        right: 16,
        bottom: 0,
        height: 16,
        child: child,
      ),
      _HandleSide.corner => Positioned(
        right: 0,
        bottom: 0,
        width: 18,
        height: 18,
        child: child,
      ),
    };
  }
}

/// Surukleme sirasinda gorunen "%62 · 320 px" rozeti.
class _SizeBadge extends StatelessWidget {
  const _SizeBadge({required this.widthFraction, required this.height});

  final double widthFraction;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final percent = (widthFraction * 100).round();
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: scheme.inverseSurface.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          height == null ? '%$percent' : '%$percent · ${height!.round()} px',
          style: TextStyle(
            color: scheme.onInverseSurface,
            fontSize: 11,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
