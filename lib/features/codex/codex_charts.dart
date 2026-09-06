import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/codex/codex_style.dart';
import 'codex_style_ui.dart';

/// Kayitlar grafik blogunun cizim katmani.
///
/// Harici grafik paketi YOK: tum turler `CustomPainter` ile ciziliyor. Bunun
/// nedeni uygulamanin tumuyle cevrimdisi olmasi ve paket agirligindan
/// kacinilmasi; ihtiyacimiz olan sey birkac yuz satirlik geometri.

/// Tek bir seri ogesi.
class CodexChartItem {
  const CodexChartItem({required this.label, required this.value, this.color});

  final String label;
  final double value;

  /// Oge icin elle secilmis renk; null ise paletten atanir.
  final Color? color;
}

/// Grafik blogunun govdesi: baslik + cizim + istege bagli aciklama (legend).
class CodexChartView extends StatelessWidget {
  const CodexChartView({
    required this.title,
    required this.type,
    required this.items,
    this.palette = CodexPalette.theme,
    this.height,
    this.showValues = true,
    this.showLegend = true,
    this.showGrid = true,
    this.emptyHint,
    this.surfaceColor,
    super.key,
  });

  final String title;
  final CodexChartType type;
  final List<CodexChartItem> items;
  final CodexPalette palette;

  /// Cizim alani yuksekligi (px). null ise ture gore makul bir varsayilan.
  final double? height;

  final bool showValues;
  final bool showLegend;
  final bool showGrid;

  /// Veri yokken gosterilecek metin (null ise blok gizlenir).
  final String? emptyHint;

  /// Halka grafigin ortasini kapatan zemin rengi (kart uzerindeyken kartin
  /// rengi verilir); null ise tema yuzeyi.
  final Color? surfaceColor;

  /// Ture gore varsayilan cizim yuksekligi.
  static double defaultHeight(CodexChartType type, int itemCount) =>
      switch (type) {
        CodexChartType.bar => (itemCount.clamp(1, 24) * 26 + 8).toDouble(),
        CodexChartType.stacked => 56,
        CodexChartType.pie || CodexChartType.donut => 220,
        CodexChartType.radar => 260,
        _ => 200,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (items.isEmpty) {
      if (emptyHint == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          emptyHint!,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      );
    }

    final colors = _resolveColors(context);
    final plotHeight = height ?? defaultHeight(type, items.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(title, style: theme.textTheme.titleSmall),
          ),
        switch (type) {
          CodexChartType.bar => _BarList(
            items: items,
            colors: colors,
            showValues: showValues,
          ),
          CodexChartType.stacked => _StackedBar(
            items: items,
            colors: colors,
            showValues: showValues,
          ),
          _ => SizedBox(
            height: plotHeight,
            width: double.infinity,
            child: CustomPaint(
              painter: _ChartPainter(
                type: type,
                items: items,
                colors: colors,
                showValues: showValues,
                showGrid: showGrid,
                gridColor: theme.dividerColor,
                axisColor: theme.colorScheme.outlineVariant,
                labelColor: theme.colorScheme.onSurfaceVariant,
                valueColor: theme.colorScheme.onSurface,
                surfaceColor: surfaceColor ?? theme.colorScheme.surface,
                textDirection: Directionality.of(context),
              ),
            ),
          ),
        },
        if (showLegend && _needsLegend)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _Legend(
              items: items,
              colors: colors,
              showValues: showValues,
            ),
          ),
      ],
    );
  }

  /// Cubuk/sutun turlerinde etiket zaten cizimde; aciklama yalnizca etiketin
  /// gorunmedigi turlerde gerekli.
  bool get _needsLegend => switch (type) {
    CodexChartType.pie ||
    CodexChartType.donut ||
    CodexChartType.stacked => true,
    CodexChartType.line || CodexChartType.area => items.length > 1,
    _ => false,
  };

  List<Color> _resolveColors(BuildContext context) {
    final generated = codexPaletteColors(context, palette, items.length);
    return [for (final (i, item) in items.indexed) item.color ?? generated[i]];
  }
}

/// Sayiyi kisa ve okunur bicimler (12, 12.5, 1.2K).
String formatChartValue(double v) {
  if (v.abs() >= 10000) {
    final k = v / 1000;
    return '${k.toStringAsFixed(k.abs() >= 100 ? 0 : 1)}K';
  }
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(v.abs() < 10 ? 2 : 1);
}

// --- Yatay cubuk (etiket + oran) -----------------------------------------

class _BarList extends StatelessWidget {
  const _BarList({
    required this.items,
    required this.colors,
    required this.showValues,
  });

  final List<CodexChartItem> items;
  final List<Color> colors;
  final bool showValues;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxValue = items
        .map((e) => e.value.abs())
        .fold<double>(0, (a, b) => b > a ? b : a);
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, item) in items.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Text(
                    item.label,
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => Stack(
                      children: [
                        Container(
                          height: 20,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Container(
                          height: 20,
                          width:
                              (constraints.maxWidth *
                                      (item.value.abs() / safeMax))
                                  .clamp(0.0, constraints.maxWidth),
                          decoration: BoxDecoration(
                            color: colors[i],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (showValues) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 48,
                    child: Text(
                      formatChartValue(item.value),
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

// --- Yigilmis oran cubugu -------------------------------------------------

class _StackedBar extends StatelessWidget {
  const _StackedBar({
    required this.items,
    required this.colors,
    required this.showValues,
  });

  final List<CodexChartItem> items;
  final List<Color> colors;
  final bool showValues;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = items.fold<double>(0, (a, e) => a + math.max(0, e.value));
    if (total <= 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 26,
            child: Row(
              children: [
                for (final (i, item) in items.indexed)
                  if (item.value > 0)
                    Expanded(
                      flex: math.max(1, (item.value / total * 1000).round()),
                      child: Tooltip(
                        message:
                            '${item.label}: ${formatChartValue(item.value)}',
                        child: Container(color: colors[i]),
                      ),
                    ),
              ],
            ),
          ),
        ),
        if (showValues)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              formatChartValue(total),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
      ],
    );
  }
}

// --- Aciklama (legend) ----------------------------------------------------

class _Legend extends StatelessWidget {
  const _Legend({
    required this.items,
    required this.colors,
    required this.showValues,
  });

  final List<CodexChartItem> items;
  final List<Color> colors;
  final bool showValues;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final (i, item) in items.indexed)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: colors[i],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                showValues
                    ? '${item.label}  ${formatChartValue(item.value)}'
                    : item.label,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
      ],
    );
  }
}

// --- Boyayici -------------------------------------------------------------

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.type,
    required this.items,
    required this.colors,
    required this.showValues,
    required this.showGrid,
    required this.gridColor,
    required this.axisColor,
    required this.labelColor,
    required this.valueColor,
    required this.surfaceColor,
    required this.textDirection,
  });

  final CodexChartType type;
  final List<CodexChartItem> items;
  final List<Color> colors;
  final bool showValues;
  final bool showGrid;
  final Color gridColor;
  final Color axisColor;
  final Color labelColor;
  final Color valueColor;

  /// Halkanin ortasini kapatmak icin cizim yuzeyinin zemin rengi.
  final Color surfaceColor;

  final TextDirection textDirection;

  static const double _labelBand = 20;
  static const double _valueBand = 16;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || items.isEmpty) return;
    switch (type) {
      case CodexChartType.column:
        _paintColumns(canvas, size);
      case CodexChartType.line:
      case CodexChartType.area:
        _paintLine(canvas, size, filled: type == CodexChartType.area);
      case CodexChartType.pie:
      case CodexChartType.donut:
        _paintPie(canvas, size, hole: type == CodexChartType.donut);
      case CodexChartType.radar:
        _paintRadar(canvas, size);
      case CodexChartType.bar:
      case CodexChartType.stacked:
        break; // widget tarafinda ciziliyor
    }
  }

  /// Deger ekseni: negatif degerler icin sifir cizgisi tabana degil ortaya
  /// kayar (ornegin altin bakiyesi eksiye dusebilir).
  ({double min, double max}) get _range {
    var maxV = double.negativeInfinity;
    var minV = double.infinity;
    for (final item in items) {
      maxV = math.max(maxV, item.value);
      minV = math.min(minV, item.value);
    }
    final top = math.max(maxV, 0.0);
    final bottom = math.min(minV, 0.0);
    return (min: bottom, max: top == bottom ? bottom + 1 : top);
  }

  void _paintColumns(Canvas canvas, Size size) {
    final plot = Rect.fromLTWH(
      0,
      showValues ? _valueBand : 4,
      size.width,
      size.height - _labelBand - (showValues ? _valueBand : 4),
    );
    if (plot.height <= 0) return;
    final range = _range;
    final span = range.max - range.min;
    double y(double v) => plot.bottom - (v - range.min) / span * plot.height;

    if (showGrid) _paintGrid(canvas, plot);

    final slot = plot.width / items.length;
    final barWidth = math.min(slot * 0.62, 56.0);
    final zeroY = y(0);

    for (final (i, item) in items.indexed) {
      final cx = plot.left + slot * (i + 0.5);
      final top = math.min(y(item.value), zeroY);
      final bottom = math.max(y(item.value), zeroY);
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTRB(cx - barWidth / 2, top, cx + barWidth / 2, bottom),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      );
      canvas.drawRRect(rect, Paint()..color = colors[i]);

      _text(
        canvas,
        item.label,
        Offset(cx, plot.bottom + 3),
        maxWidth: slot - 4,
        color: labelColor,
        align: TextAlign.center,
        anchor: _Anchor.topCenter,
      );
      if (showValues) {
        _text(
          canvas,
          formatChartValue(item.value),
          Offset(cx, top - 3),
          maxWidth: slot,
          color: valueColor,
          align: TextAlign.center,
          anchor: _Anchor.bottomCenter,
          size: 11,
        );
      }
    }

    // Sifir cizgisi (negatif deger varsa gorunur olur).
    canvas.drawLine(
      Offset(plot.left, zeroY),
      Offset(plot.right, zeroY),
      Paint()
        ..color = axisColor
        ..strokeWidth = 1,
    );
  }

  void _paintLine(Canvas canvas, Size size, {required bool filled}) {
    final plot = Rect.fromLTWH(
      6,
      showValues ? _valueBand : 6,
      size.width - 12,
      size.height - _labelBand - (showValues ? _valueBand : 6),
    );
    if (plot.height <= 0 || plot.width <= 0) return;
    final range = _range;
    final span = range.max - range.min;
    double y(double v) => plot.bottom - (v - range.min) / span * plot.height;

    if (showGrid) _paintGrid(canvas, plot);

    final stepX = items.length == 1 ? 0.0 : plot.width / (items.length - 1);
    final points = [
      for (final (i, item) in items.indexed)
        Offset(
          items.length == 1 ? plot.center.dx : plot.left + stepX * i,
          y(item.value),
        ),
    ];

    final lineColor = colors.first;
    if (filled && points.length > 1) {
      final area = Path()..moveTo(points.first.dx, y(math.max(range.min, 0)));
      for (final p in points) {
        area.lineTo(p.dx, p.dy);
      }
      area
        ..lineTo(points.last.dx, y(math.max(range.min, 0)))
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              lineColor.withValues(alpha: 0.45),
              lineColor.withValues(alpha: 0.04),
            ],
          ).createShader(plot),
      );
    }

    if (points.length > 1) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = lineColor
          ..strokeWidth = 2.4
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }

    // Etiketler sikisirsa atlanir (her n'inci gosterilir).
    final slot = plot.width / math.max(1, items.length);
    final labelEvery = slot < 44 ? (44 / math.max(slot, 1)).ceil() : 1;

    for (final (i, p) in points.indexed) {
      canvas.drawCircle(p, 3.4, Paint()..color = colors[i]);
      canvas.drawCircle(
        p,
        3.4,
        Paint()
          ..color = gridColor
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke,
      );
      if (i % labelEvery == 0) {
        _text(
          canvas,
          items[i].label,
          Offset(p.dx, plot.bottom + 3),
          maxWidth: math.max(slot * labelEvery - 4, 30),
          color: labelColor,
          align: TextAlign.center,
          anchor: _Anchor.topCenter,
        );
      }
      if (showValues) {
        _text(
          canvas,
          formatChartValue(items[i].value),
          Offset(p.dx, p.dy - 7),
          maxWidth: 60,
          color: valueColor,
          align: TextAlign.center,
          anchor: _Anchor.bottomCenter,
          size: 11,
        );
      }
    }
  }

  void _paintPie(Canvas canvas, Size size, {required bool hole}) {
    final total = items.fold<double>(0, (a, e) => a + math.max(0, e.value));
    if (total <= 0) return;
    final radius = math.min(size.width, size.height) / 2 - 6;
    if (radius <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    var start = -math.pi / 2;
    for (final (i, item) in items.indexed) {
      final value = math.max(0.0, item.value);
      if (value <= 0) continue;
      final sweep = value / total * math.pi * 2;
      canvas.drawArc(rect, start, sweep, true, Paint()..color = colors[i]);

      // Dilim yeterince genisse yuzde etiketi icine yazilir.
      if (showValues && sweep > 0.32) {
        final mid = start + sweep / 2;
        final labelR = hole ? radius * 0.78 : radius * 0.62;
        _text(
          canvas,
          '%${(value / total * 100).round()}',
          center + Offset(math.cos(mid) * labelR, math.sin(mid) * labelR),
          maxWidth: 60,
          color: _readableOn(colors[i]),
          align: TextAlign.center,
          anchor: _Anchor.center,
          size: 11,
        );
      }
      start += sweep;
    }

    if (hole) {
      canvas.drawCircle(center, radius * 0.55, Paint()..color = surfaceColor);
      _text(
        canvas,
        formatChartValue(total),
        center,
        maxWidth: radius * 1.0,
        color: valueColor,
        align: TextAlign.center,
        anchor: _Anchor.center,
        size: 16,
        weight: FontWeight.w600,
      );
    }
  }

  void _paintRadar(Canvas canvas, Size size) {
    final n = items.length;
    if (n < 3) return; // radar en az ucgen ister
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 26;
    if (radius <= 0) return;
    final maxV = items
        .map((e) => math.max(0.0, e.value))
        .fold<double>(0, (a, b) => b > a ? b : a);
    final safeMax = maxV <= 0 ? 1.0 : maxV;

    Offset pointAt(int i, double r) {
      final angle = -math.pi / 2 + i * 2 * math.pi / n;
      return center + Offset(math.cos(angle) * r, math.sin(angle) * r);
    }

    // Agi (rings + spokes)
    if (showGrid) {
      final grid = Paint()
        ..color = gridColor
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      for (var ring = 1; ring <= 4; ring++) {
        final r = radius * ring / 4;
        final path = Path();
        for (var i = 0; i < n; i++) {
          final p = pointAt(i, r);
          i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path..close(), grid);
      }
      for (var i = 0; i < n; i++) {
        canvas.drawLine(center, pointAt(i, radius), grid);
      }
    }

    final shape = Path();
    for (var i = 0; i < n; i++) {
      final r = radius * (math.max(0.0, items[i].value) / safeMax);
      final p = pointAt(i, r);
      i == 0 ? shape.moveTo(p.dx, p.dy) : shape.lineTo(p.dx, p.dy);
    }
    shape.close();

    final fill = colors.first;
    canvas
      ..drawPath(shape, Paint()..color = fill.withValues(alpha: 0.28))
      ..drawPath(
        shape,
        Paint()
          ..color = fill
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );

    for (var i = 0; i < n; i++) {
      final r = radius * (math.max(0.0, items[i].value) / safeMax);
      canvas.drawCircle(pointAt(i, r), 3, Paint()..color = colors[i]);

      final labelPoint = pointAt(i, radius + 12);
      _text(
        canvas,
        showValues
            ? '${items[i].label} ${formatChartValue(items[i].value)}'
            : items[i].label,
        labelPoint,
        maxWidth: 96,
        color: labelColor,
        align: TextAlign.center,
        anchor: _Anchor.center,
      );
    }
  }

  void _paintGrid(Canvas canvas, Rect plot) {
    final grid = Paint()
      ..color = gridColor.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = plot.top + plot.height * i / 4;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
    }
  }

  /// Dilim uzerine yazilan etiket icin okunur (siyah/beyaz) renk.
  Color _readableOn(Color background) =>
      background.computeLuminance() > 0.45 ? Colors.black87 : Colors.white;

  void _text(
    Canvas canvas,
    String text,
    Offset at, {
    required double maxWidth,
    required Color color,
    required TextAlign align,
    required _Anchor anchor,
    double size = 11.5,
    FontWeight weight = FontWeight.w400,
  }) {
    if (text.isEmpty || maxWidth <= 0) return;
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: size, fontWeight: weight),
      ),
      textAlign: align,
      textDirection: textDirection,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);

    final offset = switch (anchor) {
      _Anchor.topCenter => Offset(at.dx - tp.width / 2, at.dy),
      _Anchor.bottomCenter => Offset(at.dx - tp.width / 2, at.dy - tp.height),
      _Anchor.center => Offset(at.dx - tp.width / 2, at.dy - tp.height / 2),
    };
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.type != type ||
      old.items != items ||
      old.colors != colors ||
      old.showValues != showValues ||
      old.showGrid != showGrid ||
      old.gridColor != gridColor;
}

enum _Anchor { topCenter, bottomCenter, center }
