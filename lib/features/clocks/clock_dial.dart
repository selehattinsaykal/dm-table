import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Dilimli ilerleme saati kadrani.
///
/// Daire [segments] esit dilime bolunur, ilk [filled] tanesi doludur. Cizim
/// SAAT 12'DEN baslar ve saat yonunde ilerler -- masada herkesin bir saate
/// bakarken bekledigi yon bu.
///
/// Dokunulabilir: bir dilime dokunmak saati o dilime AYARLAR (ileri de geri
/// de). Zaten dolu olan son dilime dokunmak bir dilim geri alir, boylece
/// "yanlislikla ilerlettim" tek dokunusla duzelir ve ayri bir geri dugmesine
/// gerek kalmaz.
class ClockDial extends StatelessWidget {
  const ClockDial({
    required this.segments,
    required this.filled,
    this.size = 44,
    this.onSet,
    super.key,
  });

  final int segments;
  final int filled;
  final double size;

  /// Yeni dolu dilim sayisi. Null ise kadran salt gosterim.
  final void Function(int filled)? onSet;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dial = CustomPaint(
      size: Size.square(size),
      painter: _ClockDialPainter(
        segments: segments,
        filled: filled,
        fill: scheme.primary,
        empty: scheme.surfaceContainerHighest,
        stroke: scheme.outlineVariant,
      ),
    );

    if (onSet == null) {
      return SizedBox.square(dimension: size, child: dial);
    }
    return SizedBox.square(
      dimension: size,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) => _handleTap(details.localPosition),
        child: Semantics(
          value: '$filled / $segments',
          button: true,
          child: dial,
        ),
      ),
    );
  }

  void _handleTap(Offset local) {
    final center = Offset(size / 2, size / 2);
    final v = local - center;
    // Merkeze cok yakin dokunuslar hangi dilime ait belirsiz; yok sayiliyor.
    if (v.distance < size * 0.12) return;

    // atan2 saat 3'ten baslayip saat yonunun TERSINE artiyor; kadran saat
    // 12'den saat yonunde ilerliyor. Ceyrek tur cevirip yonu duzeltiyoruz.
    var angle = math.atan2(v.dx, -v.dy);
    if (angle < 0) angle += 2 * math.pi;
    final index = (angle / (2 * math.pi) * segments).floor().clamp(
      0,
      segments - 1,
    );

    // Son dolu dilime dokunmak geri alir; digerleri o dilime kadar doldurur.
    onSet!(index + 1 == filled ? index : index + 1);
  }
}

class _ClockDialPainter extends CustomPainter {
  const _ClockDialPainter({
    required this.segments,
    required this.filled,
    required this.fill,
    required this.empty,
    required this.stroke,
  });

  final int segments;
  final int filled;
  final Color fill;
  final Color empty;
  final Color stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height).deflate(1.5);
    final sweep = 2 * math.pi / segments;
    // Saat 12 = -pi/2 (Flutter'da 0 radyan saat 3 yonu).
    const start = -math.pi / 2;

    for (var i = 0; i < segments; i++) {
      canvas.drawArc(
        rect,
        start + i * sweep,
        sweep,
        true,
        Paint()..color = i < filled ? fill : empty,
      );
    }
    // Dilim ayraclari EN SONA ciziliyor: dolu/bos gecisinde ustte kalsinlar.
    for (var i = 0; i < segments; i++) {
      canvas.drawArc(
        rect,
        start + i * sweep,
        sweep,
        true,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_ClockDialPainter old) =>
      old.segments != segments ||
      old.filled != filled ||
      old.fill != fill ||
      old.empty != empty ||
      old.stroke != stroke;
}
