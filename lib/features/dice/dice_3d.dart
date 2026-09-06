import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// Zar atma 3B animasyonu.
///
/// [DiceRoll] tipinden bagimsizdir: cagiran taraf ilkel degerleri (sides,
/// headline, total...) ve yerellestirilmis metinleri (kritik/hüsran/zar)
/// gecirir. Boylece kural katmanini hic tanimadan tek basina test edilebilir.

// ---------------------------------------------------------------------------
// Geometri: her zar tipi icin bir kati cisim.
// ---------------------------------------------------------------------------

/// 3D uzayda tek bir nokta (kati cismin kosesi / donmus hali).
class V3 {
  const V3(this.x, this.y, this.z);
  final double x, y, z;
}

double _dot3(V3 a, V3 b) => a.x * b.x + a.y * b.y + a.z * b.z;
V3 _cross3(V3 a, V3 b) =>
    V3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x);
V3 _norm3(V3 v) {
  final l = sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
  return l == 0 ? v : V3(v.x / l, v.y / l, v.z / l);
}

/// Bir zarin geometrisi: koseler + coklu-kose yuzler (ucgen, kare, besgen,
/// ucurtma). Koseler cevre-yaricapi 1'e olceklenmis ve dinlenme yoneliminde
/// (on yuz kameraya, ucu yukari) sakli tutulur.
class DieSolid {
  const DieSolid(this.verts, this.faces);
  final List<V3> verts;
  final List<List<int>> faces;
}

/// Koseleri cevre-yaricapi 1 olacak sekilde olcekler.
List<V3> _scaleSolid(List<List<double>> raw) {
  var maxr = 0.0;
  for (final p in raw) {
    final r = sqrt(p[0] * p[0] + p[1] * p[1] + p[2] * p[2]);
    if (r > maxr) maxr = r;
  }
  return raw.map((p) => V3(p[0] / maxr, p[1] / maxr, p[2] / maxr)).toList();
}

/// [frontFace]'i kameraya (+z) dondurur ve [upTarget] noktasini yukari (+y)
/// getirir. Boylece dinlenmede o yuz onde, secilen kose/kenar ustte durur.
List<V3> _orientSolid(List<V3> vs, List<int> frontFace, V3 upTarget) {
  var cx = 0.0, cy = 0.0, cz = 0.0;
  for (final i in frontFace) {
    cx += vs[i].x;
    cy += vs[i].y;
    cz += vs[i].z;
  }
  final m = frontFace.length;
  final c = V3(cx / m, cy / m, cz / m);
  final n = _norm3(c); // duzgun cisimde yuz merkezi yonu = dis normal
  final raw = V3(upTarget.x - c.x, upTarget.y - c.y, upTarget.z - c.z);
  final d = _dot3(raw, n);
  final up = _norm3(V3(raw.x - d * n.x, raw.y - d * n.y, raw.z - d * n.z));
  final xa = _norm3(_cross3(up, n));
  return vs.map((p) => V3(_dot3(xa, p), _dot3(up, p), _dot3(n, p))).toList();
}

DieSolid _buildIcosa() {
  final t = (1 + sqrt(5)) / 2;
  final v = _scaleSolid([
    [-1, t, 0],
    [1, t, 0],
    [-1, -t, 0],
    [1, -t, 0],
    [0, -1, t],
    [0, 1, t],
    [0, -1, -t],
    [0, 1, -t],
    [t, 0, -1],
    [t, 0, 1],
    [-t, 0, -1],
    [-t, 0, 1],
  ]);
  const faces = [
    [0, 11, 5],
    [0, 5, 1],
    [0, 1, 7],
    [0, 7, 10],
    [0, 10, 11],
    [1, 5, 9],
    [5, 11, 4],
    [11, 10, 2],
    [10, 7, 6],
    [7, 1, 8],
    [3, 9, 4],
    [3, 4, 2],
    [3, 2, 6],
    [3, 6, 8],
    [3, 8, 9],
    [4, 9, 5],
    [2, 4, 11],
    [6, 2, 10],
    [8, 6, 7],
    [9, 8, 1],
  ];
  return DieSolid(_orientSolid(v, faces[0], v[faces[0][0]]), faces);
}

DieSolid _buildTetra() {
  final v = _scaleSolid([
    [1, 1, 1],
    [1, -1, -1],
    [-1, 1, -1],
    [-1, -1, 1],
  ]);
  const faces = [
    [0, 1, 2],
    [0, 3, 1],
    [0, 2, 3],
    [1, 3, 2],
  ];
  return DieSolid(_orientSolid(v, faces[0], v[faces[0][0]]), faces);
}

DieSolid _buildOcta() {
  final v = _scaleSolid([
    [1, 0, 0],
    [-1, 0, 0],
    [0, 1, 0],
    [0, -1, 0],
    [0, 0, 1],
    [0, 0, -1],
  ]);
  const faces = [
    [0, 2, 4],
    [2, 1, 4],
    [1, 3, 4],
    [3, 0, 4],
    [2, 0, 5],
    [1, 2, 5],
    [3, 1, 5],
    [0, 3, 5],
  ];
  return DieSolid(_orientSolid(v, faces[0], v[faces[0][0]]), faces);
}

DieSolid _buildCube() {
  final v = _scaleSolid([
    [-1, -1, -1],
    [1, -1, -1],
    [1, 1, -1],
    [-1, 1, -1],
    [-1, -1, 1],
    [1, -1, 1],
    [1, 1, 1],
    [-1, 1, 1],
  ]);
  const faces = [
    [4, 5, 6, 7],
    [0, 3, 2, 1],
    [1, 2, 6, 5],
    [0, 4, 7, 3],
    [3, 7, 6, 2],
    [0, 1, 5, 4],
  ];
  // On kareyi duz gostermek icin ust kenarin (7-6) ortasini yukari getir.
  final up = V3(
    (v[7].x + v[6].x) / 2,
    (v[7].y + v[6].y) / 2,
    (v[7].z + v[6].z) / 2,
  );
  return DieSolid(_orientSolid(v, faces[0], up), faces);
}

DieSolid _buildDodeca() {
  final t = (1 + sqrt(5)) / 2;
  final h = 1 / t;
  final v = _scaleSolid([
    [1, 1, 1],
    [1, 1, -1],
    [1, -1, 1],
    [1, -1, -1],
    [-1, 1, 1],
    [-1, 1, -1],
    [-1, -1, 1],
    [-1, -1, -1],
    [0, h, t],
    [0, h, -t],
    [0, -h, t],
    [0, -h, -t],
    [h, t, 0],
    [h, -t, 0],
    [-h, t, 0],
    [-h, -t, 0],
    [t, 0, h],
    [t, 0, -h],
    [-t, 0, h],
    [-t, 0, -h],
  ]);
  // 12 yuz merkezi (bu kose kumesinin dogru yuz normalleri): (±φ,±1,0) ve
  // dairesel oteleme. Her yuz o yone en yakin 5 kose (hepsi es-duzlemli).
  final centers = <V3>[
    V3(t, 1, 0),
    V3(t, -1, 0),
    V3(-t, 1, 0),
    V3(-t, -1, 0),
    V3(0, t, 1),
    V3(0, t, -1),
    V3(0, -t, 1),
    V3(0, -t, -1),
    V3(1, 0, t),
    V3(1, 0, -t),
    V3(-1, 0, t),
    V3(-1, 0, -t),
  ].map(_norm3).toList();
  final faces = [for (final c in centers) _pentagonFace(v, c)];
  return DieSolid(_orientSolid(v, faces[0], v[faces[0][0]]), faces);
}

/// [center] yonundeki besgen yuz: o yone en yakin 5 kose, duzlemde aci sirasi.
List<int> _pentagonFace(List<V3> vs, V3 center) {
  final idx = List.generate(vs.length, (i) => i)
    ..sort((a, b) => _dot3(vs[b], center).compareTo(_dot3(vs[a], center)));
  final pick = idx.take(5).toList();
  final ref = center.x.abs() < 0.9 ? const V3(1, 0, 0) : const V3(0, 1, 0);
  final u = _norm3(_cross3(center, ref));
  final w = _cross3(center, u);
  pick.sort(
    (a, b) => atan2(
      _dot3(vs[a], w),
      _dot3(vs[a], u),
    ).compareTo(atan2(_dot3(vs[b], w), _dot3(vs[b], u))),
  );
  return pick;
}

DieSolid _buildD10() {
  // Pentagonal trapezohedron: iki uc + iki besgen halka (36° kaydirmali).
  // Eksen dikey; on ucurtma dogrudan +z'ye bakar, ucu (uc kose) yukari.
  // Ucurtmalarin DUZLEMSEL olmasi icin apex = 9.4722·h olmali (yoksa yuzler
  // carpilir, kirpilma/golge bozulur).
  const h = 0.12, apex = 1.1367;
  final raw = <List<double>>[];
  for (var i = 0; i < 5; i++) {
    final a = (72 * i - 36) * pi / 180; // ust halka
    raw.add([sin(a), h, cos(a)]);
  }
  for (var i = 0; i < 5; i++) {
    final a = (72 * i) * pi / 180; // alt halka
    raw.add([sin(a), -h, cos(a)]);
  }
  raw.add([0, apex, 0]); // 10 = ust uc
  raw.add([0, -apex, 0]); // 11 = alt uc
  final v = _scaleSolid(raw);
  final faces = <List<int>>[];
  for (var i = 0; i < 5; i++) {
    final u0 = i, u1 = (i + 1) % 5, l = 5 + i;
    faces.add([10, u0, l, u1]); // ust ucurtmalar (uc yukari)
  }
  for (var i = 0; i < 5; i++) {
    final l0 = 5 + i, l1 = 5 + (i + 1) % 5, u = (i + 1) % 5;
    faces.add([11, l0, u, l1]); // alt ucurtmalar
  }
  // Hafif one egim (X ekseninde): ust geriye gider, on kite ekranin ortasina
  // oturur (sayi ortalanir) ve zar gorseldeki gibi hafif egik durur.
  const tilt = 0.5;
  final ct = cos(tilt), st = sin(tilt);
  final tv = [
    for (final p in v) V3(p.x, p.y * ct - p.z * st, p.y * st + p.z * ct),
  ];
  return DieSolid(tv, faces);
}

final DieSolid _solidIcosa = _buildIcosa();
final DieSolid _solidDodeca = _buildDodeca();
final DieSolid _solidOcta = _buildOcta();
final DieSolid _solidCube = _buildCube();
final DieSolid _solidTetra = _buildTetra();
final DieSolid _solidD10 = _buildD10();

/// Zar tipine gore kati cisim: d20 ikosahedron, d12 dodecahedron, d10/d100
/// trapezohedron, d8 octahedron, d6 kup, d4 tetrahedron.
DieSolid solidForSides(int sides) => switch (sides) {
  4 => _solidTetra,
  6 => _solidCube,
  8 => _solidOcta,
  10 || 100 => _solidD10,
  12 => _solidDodeca,
  _ => _solidIcosa,
};

/// Zar tipine gore renk (resimdeki gibi). d20'de dogal 20 yesil, 1 kirmizi.
({Color base, Color bright, Color glow}) dieColorsForSides(
  int sides, {
  required bool isCrit,
  required bool isFumble,
}) {
  if (isCrit) {
    return (
      base: const Color(0xFF2E7D32),
      bright: const Color(0xFF66BB6A),
      glow: const Color(0xFF66BB6A),
    );
  }
  if (isFumble) {
    return (
      base: const Color(0xFFB71C1C),
      bright: const Color(0xFFEF5350),
      glow: const Color(0xFFEF5350),
    );
  }
  return switch (sides) {
    10 || 100 => (
      base: const Color(0xFFC2185B),
      bright: const Color(0xFFEC407A),
      glow: const Color(0xFFEC407A),
    ),
    12 => (
      base: const Color(0xFFC62828),
      bright: const Color(0xFFEF5350),
      glow: const Color(0xFFEF5350),
    ),
    8 => (
      base: const Color(0xFF7B1FA2),
      bright: const Color(0xFFAB47BC),
      glow: const Color(0xFFAB47BC),
    ),
    6 => (
      base: const Color(0xFF00838F),
      bright: const Color(0xFF26C6DA),
      glow: const Color(0xFF26C6DA),
    ),
    4 => (
      base: const Color(0xFF2E7D32),
      bright: const Color(0xFF66BB6A),
      glow: const Color(0xFF66BB6A),
    ),
    _ => (
      base: const Color(0xFFD35400),
      bright: const Color(0xFFF39C4A),
      glow: const Color(0xFFF5A030),
    ),
  };
}

/// Zar uzerindeki "manset" sayi (tek zarda dogal sonuc, cok zarda toplam) ve
/// d20'de kritik/hüsran vurgusu icin dogal sonuc.
({int headline, int? naturalD20}) dieHeadline({
  required int sides,
  required int count,
  required int total,
  required List<int> results,
  int? keptIndex,
}) {
  final kept = results.isEmpty
      ? 0
      : (keptIndex ?? 0).clamp(0, results.length - 1);
  final headline = (count == 1 && results.isNotEmpty) ? results[kept] : total;
  final nat = (sides == 20 && results.isNotEmpty) ? results[kept] : null;
  return (headline: headline, naturalD20: nat);
}

/// Ekrana yansitilmis, isiklandirilmis tek bir yuz (coklu kose).
class _ProjFace {
  const _ProjFace(this.pts, this.depth, this.shade);
  final List<Offset> pts;
  final double depth; // kamera uzaklik siralamasi
  final double shade; // 0..1 isik
}

/// Bir zari ([solid]) gercek 3B olarak cizer: arkaya bakan yuzler kirpilir,
/// her yuz normaline gore isiklandirilir, [rotX]/[rotY] ile yuvarlanir.
/// [glow] oturunca arkadaki isimayi acar. Sayi hep zarin merkezine yazilir.
class DiePainter extends CustomPainter {
  DiePainter({
    required this.solid,
    required this.rotX,
    required this.rotY,
    required this.base,
    required this.bright,
    required this.glow,
    required this.glowColor,
    required this.number,
    required this.numberOpacity,
  });

  final DieSolid solid;
  final double rotX, rotY, glow;
  final Color base, bright, glowColor;
  final String number;
  final double numberOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide * 0.44;
    final cx = cos(rotX), sx = sin(rotX);
    final cy = cos(rotY), sy = sin(rotY);

    V3 rot(V3 p) {
      final y1 = p.y * cx - p.z * sx;
      final z1 = p.y * sx + p.z * cx;
      final x2 = p.x * cy + z1 * sy;
      final z2 = -p.x * sy + z1 * cy;
      return V3(x2, y1, z2);
    }

    final rv = solid.verts.map(rot).toList();

    if (glow > 0) {
      canvas.drawCircle(
        center,
        r * (0.95 + 0.18 * glow),
        Paint()
          ..color = glowColor.withValues(alpha: 0.45 * glow)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 18 * glow + 6),
      );
    }

    const lx = -0.35, ly = 0.72, lz = 0.9;
    final ll = sqrt(lx * lx + ly * ly + lz * lz);

    Offset project(V3 p) {
      final k = 1 / (1 - p.z * 0.18);
      return center + Offset(p.x * r * k, -p.y * r * k);
    }

    final darkC = Color.lerp(base, Colors.black, 0.45)!;
    final faces = <_ProjFace>[];

    for (final f in solid.faces) {
      final a = rv[f[0]], b = rv[f[1]], c = rv[f[2]];
      var nx = (b.y - a.y) * (c.z - a.z) - (b.z - a.z) * (c.y - a.y);
      var ny = (b.z - a.z) * (c.x - a.x) - (b.x - a.x) * (c.z - a.z);
      var nz = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
      final nl = sqrt(nx * nx + ny * ny + nz * nz);
      nx /= nl;
      ny /= nl;
      nz /= nl;
      var mx = 0.0, my = 0.0, mz = 0.0;
      for (final i in f) {
        mx += rv[i].x;
        my += rv[i].y;
        mz += rv[i].z;
      }
      final m = f.length;
      mx /= m;
      my /= m;
      mz /= m;
      if (nx * mx + ny * my + nz * mz < 0) {
        nx = -nx;
        ny = -ny;
        nz = -nz;
      }
      if (nz <= 0.0) continue; // arkaya bakan yuz
      final d = (nx * lx + ny * ly + nz * lz) / ll;
      final shade = (d * 0.5 + 0.5).clamp(0.0, 1.0);
      final pts = [for (final i in f) project(rv[i])];
      faces.add(_ProjFace(pts, mz, shade));
    }

    faces.sort((p, q) => p.depth.compareTo(q.depth));

    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.black.withValues(alpha: 0.16);

    for (final f in faces) {
      final path = Path()..moveTo(f.pts[0].dx, f.pts[0].dy);
      for (var i = 1; i < f.pts.length; i++) {
        path.lineTo(f.pts[i].dx, f.pts[i].dy);
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()..color = Color.lerp(darkC, bright, f.shade)!,
      );
      canvas.drawPath(path, edge);
    }

    // Sayi hep zarin merkezinde. Opaklik silikten (0) tam renge (1) gecer.
    final o = numberOpacity.clamp(0.0, 1.0);
    final fontSize = number.length >= 3 ? 30.0 : 44.0;
    final tp = TextPainter(
      text: TextSpan(
        text: number,
        style: TextStyle(
          color: Colors.white.withValues(alpha: o),
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(color: Colors.black87.withValues(alpha: o), blurRadius: 6),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(DiePainter old) =>
      old.rotX != rotX ||
      old.rotY != rotY ||
      old.glow != glow ||
      old.number != number ||
      old.numberOpacity != numberOpacity ||
      old.base != base ||
      old.bright != bright ||
      old.glowColor != glowColor ||
      !identical(old.solid, solid);
}

// ---------------------------------------------------------------------------
// Overlay + gosterme yardimcisi.
// ---------------------------------------------------------------------------

/// Zar atinca ekranin ortasinda beliren pop-up: zar tipine gore 3B model,
/// dusme + buyuyen golge, sona dogru yavaslayip oturma; sayi yalnizca oturma
/// aninda saydamdan belirir. d20'de dogal 20/1 icin kritik/hüsran vurgusu.
class DieRollOverlay extends StatefulWidget {
  const DieRollOverlay({
    required this.sides,
    required this.headline,
    required this.total,
    required this.modifier,
    required this.count,
    required this.label,
    required this.detail,
    required this.criticalText,
    required this.fumbleText,
    required this.diceText,
    this.naturalD20,
    super.key,
  });

  final int sides;
  final int headline;
  final int total;
  final int modifier;
  final int count;
  final String label;
  final String detail;
  final int? naturalD20;
  final String criticalText;
  final String fumbleText;
  final String diceText;

  @override
  State<DieRollOverlay> createState() => _DieRollOverlayState();
}

class _DieRollOverlayState extends State<DieRollOverlay>
    with SingleTickerProviderStateMixin {
  // Yuvarlanma bu ana kadar surer, sonrasi "oturmus" kabul edilir.
  static const _settleAt = 0.68;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..forward();

  Timer? _autoClose;

  bool get _settled => _c.value >= _settleAt;

  @override
  void initState() {
    super.initState();
    _autoClose = Timer(const Duration(milliseconds: 3200), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    _autoClose?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nat = widget.naturalD20;
    final isCrit = nat == 20;
    final isFumble = nat == 1;

    final palette = dieColorsForSides(
      widget.sides,
      isCrit: isCrit,
      isFumble: isFumble,
    );
    final solid = solidForSides(widget.sides);
    final glow = palette.glow;

    return GestureDetector(
      onTap: () => Navigator.of(context).maybePop(),
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            // Kutu girisi: hafif ustunlemeli buyume.
            final popIn = Curves.easeOutBack.transform(
              (t / 0.4).clamp(0.0, 1.0),
            );
            // Zarin donusu: basta COK HIZLI, sona dogru cok belirgin yavaslayip
            // yumusakca oturur. Kubik egri: hiz 1.6'dan (baslangic) 0.075'e
            // (bitis) duser. Tur sayilari 2π'nin tam kati (6π=3, 10π=5 tur)
            // olmali ki oturunca dogru yonelime (baked) donsun.
            final sx = (t / _settleAt).clamp(0.0, 1.0);
            final spin = sx * (1.6 - 0.275 * sx - 0.325 * sx * sx);
            final rotX = 6 * pi * spin;
            final rotY = 10 * pi * spin;

            // Sayi basta HIC yok; yalnizca zar oturmaya yakin saydamdan tam
            // renge 0.1 sn'de belirir (geçisin tam ortasi oturma anina denk).
            const fadeWin = 100 / 1600;
            final numberOpacity = ((t - (_settleAt - fadeWin / 2)) / fadeWin)
                .clamp(0.0, 1.0);
            // Yukaridan dusus (ilk yarida), hafif zipla.
            final dropT = Curves.easeOutBack.transform(
              (t / 0.5).clamp(0.0, 1.0),
            );
            final dy = -34.0 * (1 - dropT);
            // Golge yere yaklastikca buyur/koyulasir.
            final land = (t / _settleAt).clamp(0.0, 1.0);
            final afterSettle = ((t - _settleAt) / (1 - _settleAt)).clamp(
              0.0,
              1.0,
            );
            final settledPop = _settled
                ? Curves.easeOutBack.transform(afterSettle)
                : 0.0;

            // Kritik gelince zar yere carpinca ekran sarsilir; sonumleyerek durur.
            var shakeX = 0.0;
            var shakeY = 0.0;
            if (isCrit && _settled) {
              final damp = 1 - afterSettle;
              final amp = 14.0 * damp;
              shakeX = sin(afterSettle * pi * 9) * amp;
              shakeY = cos(afterSettle * pi * 7) * amp * 0.55;
            }

            // Zar her karede yeniden ciziliyor; RepaintBoundary onu kendi
            // katmanina alir, cevresindeki kart/metin bosuna boyanmaz.
            final die = Transform.translate(
              offset: Offset(0, dy),
              child: RepaintBoundary(
                child: CustomPaint(
                  size: const Size(120, 120),
                  painter: DiePainter(
                    solid: solid,
                    rotX: rotX,
                    rotY: rotY,
                    base: palette.base,
                    bright: palette.bright,
                    glow: _settled ? settledPop.clamp(0.0, 1.0) : 0.0,
                    glowColor: palette.glow,
                    number: '${widget.headline}',
                    numberOpacity: numberOpacity,
                  ),
                ),
              ),
            );

            return Transform.translate(
              offset: Offset(shakeX, shakeY),
              child: Transform.scale(
                scale: popIn,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 220,
                    maxWidth: 320,
                  ),
                  margin: const EdgeInsets.all(32),
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(color: Colors.black54, blurRadius: 32),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.label.isEmpty ? widget.diceText : widget.label,
                        style: theme.textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      // Zar + altinda yere dusen golge.
                      Column(
                        children: [
                          die,
                          const SizedBox(height: 6),
                          Container(
                            width: 40 + 48 * land,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(
                                alpha: 0.30 * land,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Oturunca kritik/hüsran etiketi ya da toplam.
                      if (_settled && (isCrit || isFumble))
                        Opacity(
                          opacity: settledPop.clamp(0.0, 1.0),
                          child: Text(
                            isCrit ? widget.criticalText : widget.fumbleText,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: glow,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else if (_settled &&
                          (widget.modifier != 0 || widget.count > 1))
                        Opacity(
                          opacity: settledPop.clamp(0.0, 1.0),
                          child: Text(
                            '= ${widget.total}',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        widget.detail,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Zar atma animasyonlu pop-up'ini gosterir. Cagiran taraf ilkel degerleri ve
/// yerellestirilmis metinleri gecirir.
Future<void> showDieRoll(
  BuildContext context, {
  required int sides,
  required int headline,
  required int total,
  required int modifier,
  required int count,
  required String label,
  required String detail,
  required String criticalText,
  required String fumbleText,
  required String diceText,
  int? naturalD20,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: diceText,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, _, _) => DieRollOverlay(
      sides: sides,
      headline: headline,
      total: total,
      modifier: modifier,
      count: count,
      label: label,
      detail: detail,
      naturalD20: naturalD20,
      criticalText: criticalText,
      fumbleText: fumbleText,
      diceText: diceText,
    ),
  );
}
