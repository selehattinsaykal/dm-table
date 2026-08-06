import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Sus ayraci: ince pirinc cizgi + ortada baklava motifi.
///
/// Duz `Divider` "form alani bitti" der; bu "bolum bitti" der. Uzun sayfalarda
/// (Codex, karakter kagidi, ayarlar) bolumleri ayirmak icin.
class OrnamentDivider extends StatelessWidget {
  const OrnamentDivider({this.indent = 0, this.compact = false, super.key});

  /// Iki yandan iceri cekme.
  final double indent;

  /// Dar dikey bosluk (yogun listelerde).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final brass = context.fantasyColors.brass;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: indent,
        vertical: compact ? context.spacing.sm : context.spacing.md,
      ),
      child: CustomPaint(
        painter: _OrnamentDividerPainter(brass),
        size: const Size(double.infinity, 10),
      ),
    );
  }
}

class _OrnamentDividerPainter extends CustomPainter {
  const _OrnamentDividerPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    const gap = 13.0;
    const diamond = 4.5;

    final line = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(0, cy), Offset(size.width / 2 - gap, cy), line);
    canvas.drawLine(
      Offset(size.width / 2 + gap, cy),
      Offset(size.width, cy),
      line,
    );

    // Ortadaki baklava (lozenge) + iki yanda kucuk noktalar.
    final cx = size.width / 2;
    final path = Path()
      ..moveTo(cx, cy - diamond)
      ..lineTo(cx + diamond, cy)
      ..lineTo(cx, cy + diamond)
      ..lineTo(cx - diamond, cy)
      ..close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.85));

    final dot = Paint()..color = color.withValues(alpha: 0.5);
    canvas.drawCircle(Offset(cx - gap + 4, cy), 1.3, dot);
    canvas.drawCircle(Offset(cx + gap - 4, cy), 1.3, dot);
  }

  @override
  bool shouldRepaint(_OrnamentDividerPainter old) => old.color != color;
}

/// Bolum basligi: kucuk-buyuk harf Cinzel etiket + yanindan uzanan pirinc
/// cizgi, istege bagli ikon ve sag aksiyon.
///
/// Ekranlarda `Text('Envanter', style: titleMedium)` yerine bunu kullan:
/// tum uygulamada ayni gorsel ritim olusur ve bolumler taranabilir hale gelir.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.label,
    this.icon,
    this.trailing,
    this.padding,
    super.key,
  });

  final String label;
  final IconData? icon;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brass = context.fantasyColors.brass;
    final space = context.spacing;

    return Padding(
      padding: padding ?? EdgeInsets.only(top: space.lg, bottom: space.sm),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 17, color: brass),
            SizedBox(width: space.sm),
          ],
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 12.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(width: space.sm + 2),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    brass.withValues(alpha: 0.55),
                    brass.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          if (trailing != null) ...[SizedBox(width: space.sm), trailing!],
        ],
      ),
    );
  }
}

/// Mum muhru rozeti: tirtikli kenarli dolgu daire, ustunde acik parsomen
/// ikon/harf.
///
/// Durum vurgusu icin (kabul edildi, muhurlu, DM onayli). Zemin daima
/// [AppFantasyColors.wax] ya da verilen [color]; metin/ikon daima acik —
/// kontrast boyle korunur (bkz. theme.dart `wax` notu).
class WaxSeal extends StatelessWidget {
  const WaxSeal({
    this.icon,
    this.letter,
    this.size = 34,
    this.color,
    this.semanticLabel,
    super.key,
  }) : assert(
         icon != null || letter != null,
         'WaxSeal bir ikon ya da harf ister',
       );

  final IconData? icon;
  final String? letter;
  final double size;
  final Color? color;

  /// Ekran okuyucu etiketi. Muhur tek basina anlam tasidiginda ZORUNLU —
  /// ikon-only bir gosterge etiketsiz birakilmamali.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final seal = color ?? context.fantasyColors.wax;
    const foreground = Color(0xFFF6ECD8);

    final visual = CustomPaint(
      painter: _WaxSealPainter(seal),
      size: Size.square(size),
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: icon != null
              ? Icon(icon, size: size * 0.46, color: foreground)
              : Text(
                  letter!,
                  style: TextStyle(
                    fontFamily: 'Cinzel',
                    fontSize: size * 0.42,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                  ),
                ),
        ),
      ),
    );

    return semanticLabel == null
        ? ExcludeSemantics(child: visual)
        : Semantics(label: semanticLabel, child: visual);
  }
}

class _WaxSealPainter extends CustomPainter {
  const _WaxSealPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;

    // Tirtikli kenar: r(t) = R * (1 + amp * cos(n*t)) kutupsal ornekleme.
    const lobes = 11;
    const amp = 0.055;
    final path = Path();
    const steps = 120;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps * 2 * math.pi;
      final rr = r * (1 - amp) * (1 + amp * math.cos(lobes * t));
      final p = c + Offset(math.cos(t) * rr, math.sin(t) * rr);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();

    // Erimis mum hissi: merkezden hafif acik, kenara dogru koyu.
    canvas.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          radius: 0.95,
          colors: [
            Color.lerp(color, Colors.white, 0.22)!,
            color,
            Color.lerp(color, Colors.black, 0.28)!,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Offset.zero & size),
    );

    // Ic kabartma halkasi (damga izi).
    canvas.drawCircle(
      c,
      r * 0.68,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, r * 0.06)
        ..color = Colors.black.withValues(alpha: 0.22),
    );
  }

  @override
  bool shouldRepaint(_WaxSealPainter old) => old.color != color;
}

/// Kemer tepeli kirpici (romanesk kemer): portre ve el ilani gorsellerini
/// dikdortgen "fotograf" olmaktan cikarip vitray/nis hissine sokar.
class ArchClipper extends CustomClipper<Path> {
  const ArchClipper();

  @override
  Path getClip(Size size) {
    // Kemer yuksekligi genisligin yarisi kadar; daha uzun gorsellerde govde
    // duz devam eder.
    final arch = math.min(size.width / 2, size.height);
    return Path()
      ..moveTo(0, size.height)
      ..lineTo(0, arch)
      ..arcToPoint(
        Offset(size.width, arch),
        radius: Radius.circular(size.width / 2),
        clockwise: true,
      )
      ..lineTo(size.width, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Kemerli cerceve: [ArchClipper] + pirinc kenarlik.
class ArchFrame extends StatelessWidget {
  const ArchFrame({required this.child, this.borderWidth = 1.5, super.key});

  final Widget child;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final brass = context.fantasyColors.brass;
    return CustomPaint(
      foregroundPainter: _ArchBorderPainter(brass, borderWidth),
      child: ClipPath(clipper: const ArchClipper(), child: child),
    );
  }
}

class _ArchBorderPainter extends CustomPainter {
  const _ArchBorderPainter(this.color, this.width);

  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      const ArchClipper().getClip(size),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = color.withValues(alpha: 0.75),
    );
  }

  @override
  bool shouldRepaint(_ArchBorderPainter old) =>
      old.color != color || old.width != width;
}

/// Yukseltilmis tezhipli bas harf (versal) ile uzun metin paragrafi.
///
/// NOT: Bu gercek bir "drop cap" DEGIL — Flutter'da metnin bir kutunun
/// etrafindan akmasi (float) yok. Bunun yerine el yazmalarinin oteki gecerli
/// gelenegi kullanildi: harf buyutulup ilk satirin uzerine oturur (versal).
/// Codex sayfa govdesi, lore ve el ilani metinleri icin.
class IlluminatedParagraph extends StatelessWidget {
  const IlluminatedParagraph(this.text, {this.style, super.key});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final body = readingStyle(context, base: style);
    final trimmed = text.trimLeft();
    if (trimmed.isEmpty) return Text(text, style: body);

    // Ilk harf gercekten harf degilse (rakam, tirnak, madde imi) sus uygulama.
    final first = trimmed[0];
    if (!RegExp(r'\p{L}', unicode: true).hasMatch(first)) {
      return Text(text, style: body);
    }

    return RichText(
      text: TextSpan(
        style: body,
        children: [
          TextSpan(
            text: first.toUpperCase(),
            style: body.copyWith(
              fontFamily: 'Cinzel',
              fontSize: (body.fontSize ?? 16) * 1.9,
              height: 1.0,
              fontWeight: FontWeight.w600,
              color: context.fantasyColors.brass,
            ),
          ),
          TextSpan(text: trimmed.substring(1)),
        ],
      ),
    );
  }
}
