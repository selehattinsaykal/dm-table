import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Prosedurel parsomen/tas dokusu.
///
/// Neden karo (tile) + shader, neden "ekrani speck speck boya" degil: tam
/// ekran bir yuzeyde tek tek tanecik cizmek binlerce `drawCircle` cagrisi
/// demek. Bunun yerine 192x192'lik TEK bir karo bir kez uretilip
/// (`toImageSync`) statik olarak onbellege alinir, sonra `ImageShader` ile
/// tekrarlanir: butun yuzey tek `drawRect` ile boyanir.
///
/// Karo (renk, yogunluk) ciftine gore onbelleklenir; tema degisiminde
/// yeniden uretilir, her karede degil.
abstract final class ParchmentTexture {
  static const double _tileSize = 192;

  static final Map<int, ui.Image> _cache = {};

  /// Verilen tanecik rengi + yogunluk icin tekrarlanabilir doku karosu.
  static ui.Image tile(Color grain, double intensity) {
    // Yogunlugu 20 kademeye yuvarla: surekli double degerler onbellegi
    // sonsuz buyutmesin.
    final key = Object.hash(grain.toARGB32(), (intensity * 20).round());
    final cached = _cache[key];
    if (cached != null) return cached;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    // Sabit tohum: karo her uretimde AYNI olmali, yoksa tema gecisinde
    // doku "kaynar".
    final rnd = math.Random(0x5EED);
    final speck = Paint();

    // Ince tanecik: kagit lifi hissi.
    final speckCount = (520 * intensity).round();
    for (var i = 0; i < speckCount; i++) {
      final a = (0.012 + rnd.nextDouble() * 0.05) * intensity;
      speck.color = grain.withValues(alpha: a.clamp(0.0, 1.0));
      canvas.drawCircle(
        Offset(rnd.nextDouble() * _tileSize, rnd.nextDouble() * _tileSize),
        0.4 + rnd.nextDouble() * 1.1,
        speck,
      );
    }

    // Birkac uzun lif: dokuyu tamamen "gurultu" olmaktan cikarir, el yapimi
    // kagit hissi verir.
    final fiber = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final fiberCount = (14 * intensity).round();
    for (var i = 0; i < fiberCount; i++) {
      final x = rnd.nextDouble() * _tileSize;
      final y = rnd.nextDouble() * _tileSize;
      final len = 8 + rnd.nextDouble() * 26;
      final ang = rnd.nextDouble() * math.pi;
      fiber
        ..color = grain.withValues(alpha: 0.035 * intensity)
        ..strokeWidth = 0.5 + rnd.nextDouble() * 0.7;
      canvas.drawLine(
        Offset(x, y),
        Offset(x + math.cos(ang) * len, y + math.sin(ang) * len),
        fiber,
      );
    }

    final image = recorder.endRecording().toImageSync(
      _tileSize.round(),
      _tileSize.round(),
    );
    _cache[key] = image;
    return image;
  }

  /// Tekrarlanan karodan bir shader uretir.
  static ui.ImageShader shader(Color grain, double intensity) => ui.ImageShader(
    tile(grain, intensity),
    TileMode.repeated,
    TileMode.repeated,
    Matrix4.identity().storage,
  );
}

/// Dokulu zemin + (istege bagli) kenar vinyeti.
///
/// Duz renk yuzeylerin "dijital" hissini kirar: parsomen kagit, koyu temada
/// islenmis deri/tas gibi durur. Doku tek karodan tekrarlandigi icin maliyeti
/// tek bir `drawRect`; ayrica [RepaintBoundary] ile ust katman animasyonlari
/// dokuyu yeniden boyamaya zorlamaz.
class ParchmentSurface extends StatelessWidget {
  const ParchmentSurface({
    required this.child,
    this.color,
    this.intensity = 1.0,
    this.vignette = false,
    this.borderRadius,
    super.key,
  });

  final Widget child;

  /// Zemin rengi; verilmezse tema yuzeyi kullanilir.
  final Color? color;

  /// 0 = doku yok, 1 = varsayilan. Buyuk yuzeylerde 0.6-0.8 daha zarif.
  final double intensity;

  /// Kenarlari karartan hafif vinyet — sahne/harita gibi tam ekran
  /// yuzeylerde derinlik verir. Liste ekranlarinda KAPALI birak.
  final bool vignette;

  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fantasy = context.fantasyColors;
    final bg = color ?? scheme.surface;

    Widget painted = CustomPaint(
      painter: _GrainPainter(
        background: bg,
        grain: fantasy.grain,
        intensity: intensity,
        vignette: vignette,
      ),
      // Doku degismedigi surece yeniden boyanmaz.
      isComplex: true,
      willChange: false,
      child: child,
    );

    if (borderRadius != null) {
      painted = ClipRRect(borderRadius: borderRadius!, child: painted);
    }
    return RepaintBoundary(child: painted);
  }
}

/// Tum uygulamanin uzerine serilen cok hafif tanecik katmani.
///
/// `MaterialApp.builder` icinde bir kez sarilir; Navigator'in USTUNDE oldugu
/// icin sayfalar, dialoglar ve sheet'ler dahil her sey ayni kagit dokusunu
/// paylasir. Tek tek ekranlari degistirmeye gerek kalmadan butun arayuz
/// "basili sayfa" hissi kazanir.
///
/// Neden bu kadar sonuk (varsayilan alfa ~0.022): katman metnin de UZERINDE
/// durur, dolayisiyla kontrasti dusurur. Bu deger 13:1 gibi bir metin
/// kontrastini olcum hatasi kadar (~0.1) degistirir; gorunur ama okunabilirlik
/// butcesinden pratikte hicbir sey almaz. Yukseltmeden once kontrasti
/// yeniden olc.
///
/// [IgnorePointer] sart: katman dokunmalari yutmamali.
class ParchmentOverlay extends StatelessWidget {
  const ParchmentOverlay({
    required this.child,
    this.intensity = 0.5,
    super.key,
  });

  final Widget child;

  /// Karo taneciklerinin alfasini olcekler. 0.5'te tek tanecikler ~0.006-0.031
  /// alfada kalir — kagit hissi icin yeterli, kontrast icin onemsiz.
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final grain = context.fantasyColors.grain;
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _OverlayGrainPainter(grain, intensity),
                willChange: false,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OverlayGrainPainter extends CustomPainter {
  const _OverlayGrainPainter(this.grain, this.intensity);

  final Color grain;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = ParchmentTexture.shader(grain, intensity),
    );
  }

  @override
  bool shouldRepaint(_OverlayGrainPainter old) =>
      old.grain != grain || old.intensity != intensity;
}

class _GrainPainter extends CustomPainter {
  const _GrainPainter({
    required this.background,
    required this.grain,
    required this.intensity,
    required this.vignette,
  });

  final Color background;
  final Color grain;
  final double intensity;
  final bool vignette;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = background);
    if (intensity > 0) {
      canvas.drawRect(
        rect,
        Paint()..shader = ParchmentTexture.shader(grain, intensity),
      );
    }
    if (vignette) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            center: Alignment.center,
            radius: 0.95,
            colors: [
              const Color(0x00000000),
              Colors.black.withValues(alpha: 0.30),
            ],
            stops: const [0.55, 1.0],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(_GrainPainter old) =>
      old.background != background ||
      old.grain != grain ||
      old.intensity != intensity ||
      old.vignette != vignette;
}
