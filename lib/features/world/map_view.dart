import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../data/db/world_tables.dart';
import '../../data/pin_visibility.dart';
import '../../l10n/app_localizations.dart';
import 'world_providers.dart';

/// Yakinlastirilabilir harita ve uzerindeki pinler.
///
/// Pin konumlari 0..1 oraninda saklandigi icin harita hangi olcude cizilirse
/// cizilsin ayni yerde duruyorlar.
///
/// Ustune cizilen HICBIR SEY haritayla birlikte buyumez: pinler, rota cizgisi
/// ve durak daireleri yakinlastirma oraninin tersiyle olceklenir, boylece
/// ekranda daima ayni boyda kalir (pin 32 px) ve haritaya oranla kuculur.
/// Aksi halde 6x yakinlastirmada tek bir pin ekranin yarisini kaplayip
/// altindaki araziyi gizliyordu.
///
/// Yalnizca KONUMLAR olceklenir: duraklar yakinlastikca birbirinden uzaklasir,
/// isaretcilerin kendisi ayni kalir.
class MapView extends ConsumerStatefulWidget {
  const MapView({
    required this.location,
    required this.pins,
    this.onTapEmpty,
    this.onTapPin,
    this.onPinSettings,
    this.onMovePin,
    this.playerView = false,
    this.editing = false,
    this.accessibleLocations = const {},
    this.accessibleShops = const {},
    this.route = const [],
    super.key,
  });

  final Location location;
  final List<MapPin> pins;

  /// Bos bir noktaya dokunuldugunda (0..1 oraniyla). Null ise pin konmaz.
  final void Function(double x, double y)? onTapEmpty;
  final void Function(MapPin pin)? onTapPin;

  /// Bir pine sag tiklandiginda / uzun basildiginda.
  ///
  /// Dokunmak alt haritaya GIRER; ayarlari (tur, etiket, gorunurluk...)
  /// duzenlemek icin ayri bir jest gerekiyor — dunya grafigindeki dugum
  /// menusuyle ayni kalip.
  final void Function(MapPin pin)? onPinSettings;

  /// Bir pin surukleyip birakilinca yeni konumu (0..1). Null ise pinler sabit.
  final void Function(MapPin pin, double x, double y)? onMovePin;

  /// Oyuncu gorunumunde gizli pinler hic cizilmez.
  final bool playerView;

  /// Oyuncunun girebildigi alt yer id'leri ve harita uzerinden erisilebilir
  /// dukkan id'leri.
  ///
  /// Bir pinin oyunculara gorunup gorunmedigi pinin kendi bayragindan
  /// OKUNAMAZ: yer ve dukkan pinleri hedeflerinin durumuna bakar
  /// (`data/pin_visibility.dart`). Bu iki kume o hesabi burada da
  /// yapabilmek icin geliyor -- boylece haritadaki gosterge, dugum
  /// grafigindeki "oyunculara goster" ile ayni gercegi anlatir.
  final Set<String> accessibleLocations;
  final Set<String> accessibleShops;

  /// DM duzenleme modu acik mi.
  ///
  /// Kapaliyken harita OYUNCU GORUNUMUNE YAKIN durur: oyunculara kapali
  /// pinler soluk (hayalet) cizilir, boylece harita oyuncunun gordugu haliyle
  /// okunur. "Yakin", "ayni" degil: gizli pinler tamamen SILINMEZ, cunku DM
  /// masada kendi notunu kaybetmemeli — yalnizca geri plana duser.
  ///
  /// Jestlerin kendisi bu bayrakla degil, geri cagrilarin null olmasiyla
  /// kapatilir (bkz. [onMovePin], [onPinSettings]); bu yalnizca GORSEL ayrim.
  final bool editing;

  /// Harita uzerine cizilecek rota (0..1 oraninda noktalar).
  ///
  /// Bos degilse noktalar sirali numaralarla ve aralarindaki cizgilerle
  /// gosterilir. Rota SALT GORSEL: duraklarin kaydi cagiran tarafta durur.
  final List<({double x, double y})> route;

  @override
  ConsumerState<MapView> createState() => _MapViewState();
}

class _MapViewState extends ConsumerState<MapView> {
  final _controller = TransformationController();
  File? _file;

  // Surukleme durumu: hangi pin ve piksel oteleme (harita ic koordinatinda).
  String? _dragId;
  Offset _dragDelta = Offset.zero;

  /// Guncel yakinlastirma orani. Pinler bunun TERSIYLE olceklenir.
  double _scale = 1;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTransformChanged);
    _load();
  }

  /// Kaydirma da matrisi degistirir ama olcegi degistirmez; pinleri her
  /// kaydirma karesinde yeniden kurmamak icin yalnizca olcek gercekten
  /// degistiginde `setState` cagriliyor.
  void _onTransformChanged() {
    final scale = _controller.value.getMaxScaleOnAxis();
    if ((scale - _scale).abs() < 0.001) return;
    setState(() => _scale = scale);
  }

  @override
  void didUpdateWidget(MapView old) {
    super.didUpdateWidget(old);
    if (old.location.mapImagePath != widget.location.mapImagePath) _load();
  }

  Future<void> _load() async {
    final path = widget.playerView
        ? widget.location.mapPreviewPath
        : widget.location.mapImagePath;
    if (path == null) {
      setState(() => _file = null);
      return;
    }
    final file = await ref.read(worldRepositoryProvider).images.resolve(path);
    if (mounted) setState(() => _file = file);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Pinin oyunculara gercekten gorunup gorunmedigi (pinin kendi bayragi
  /// tek basina yeterli degil -- bkz. [MapView.accessibleLocations]).
  bool _visibleToPlayers(MapPin pin) => pinVisibleToPlayers(
    pin,
    accessibleLocations: widget.accessibleLocations,
    accessibleShops: widget.accessibleShops,
  );

  Widget _buildPin(MapPin pin, BoxConstraints constraints) {
    final visible = _visibleToPlayers(pin);
    final marker = _PinMarker(
      pin: pin,
      visibleToPlayers: visible,
      // Goruntuleme modunda oyunculara kapali pinler geri plana duser.
      ghost: !widget.editing && !visible,
      onTap: widget.onTapPin == null ? null : () => widget.onTapPin!(pin),
      onSettings: widget.onPinSettings == null
          ? null
          : () => widget.onPinSettings!(pin),
    );
    // Yakinlastirma oraninin tersi: pin ekranda sabit boyda kalir. Pivot
    // isaretcinin ALT ORTASI, yani pinin ucunun haritaya degdigi nokta --
    // boylece olcek degisirken pin gosterdigi yerden kaymaz.
    Widget counterScaled(Widget child) => Transform.scale(
      scale: 1 / _scale,
      alignment: Alignment.bottomCenter,
      child: child,
    );

    if (widget.onMovePin == null) return counterScaled(marker);

    // Edit modda pin surukleyerek tasinir; birakinca yeni oran kaydedilir.
    return counterScaled(
      GestureDetector(
        onPanStart: (_) => setState(() {
          _dragId = pin.id;
          _dragDelta = Offset.zero;
        }),
        // Jest algilayici ters olcegin ICINDE oldugu icin gelen delta net
        // olarak EKRAN pikselidir (s * 1/s = 1); harita ic koordinatina
        // cevirmek icin yakinlastirma oranina bolunur.
        onPanUpdate: (d) => setState(() => _dragDelta += d.delta / _scale),
        onPanEnd: (_) {
          final nx =
              (pin.x * constraints.maxWidth + _dragDelta.dx) /
              constraints.maxWidth;
          final ny =
              (pin.y * constraints.maxHeight + _dragDelta.dy) /
              constraints.maxHeight;
          widget.onMovePin!(pin, nx.clamp(0.0, 1.0), ny.clamp(0.0, 1.0));
          setState(() {
            _dragId = null;
            _dragDelta = Offset.zero;
          });
        },
        child: marker,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    if (file == null || !file.existsSync()) {
      return Center(child: Text(L10n.of(context).worldMapNotFound));
    }

    final width = widget.location.mapWidth;
    final height = widget.location.mapHeight;
    final aspect = (width != null && height != null && height > 0)
        ? width / height
        : 1.0;

    final visible = widget.playerView
        ? widget.pins.where((p) => p.revealed).toList()
        : widget.pins;

    return InteractiveViewer(
      transformationController: _controller,
      minScale: 0.5,
      maxScale: 6,
      child: Center(
        child: AspectRatio(
          aspectRatio: aspect,
          child: LayoutBuilder(
            builder: (context, constraints) => GestureDetector(
              // Bos alana dokunus: oraya pin konur.
              onTapUp: widget.onTapEmpty == null
                  ? null
                  : (details) {
                      final x = details.localPosition.dx / constraints.maxWidth;
                      final y =
                          details.localPosition.dy / constraints.maxHeight;
                      if (x < 0 || x > 1 || y < 0 || y > 1) return;
                      widget.onTapEmpty!(x, y);
                    },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(file, fit: BoxFit.contain),
                  if (widget.route.isNotEmpty)
                    // Rota pinlerin ALTINDA cizilir: cizgi pin etiketlerini
                    // kapatmasin.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: _RoutePainter(
                              route: widget.route,
                              color: Theme.of(context).colorScheme.primary,
                              scale: _scale,
                            ),
                          ),
                        ),
                      ),
                    ),
                  for (final pin in visible)
                    Positioned(
                      left:
                          pin.x * constraints.maxWidth -
                          _PinMarker.size / 2 +
                          (pin.id == _dragId ? _dragDelta.dx : 0),
                      top:
                          pin.y * constraints.maxHeight -
                          _PinMarker.size +
                          (pin.id == _dragId ? _dragDelta.dy : 0),
                      child: _buildPin(pin, constraints),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rota cizgisi + sirali durak isaretleri.
///
/// Noktalar 0..1 oraninda geldigi icin boyanan kutunun olcusuyle carpilir:
/// duraklar harita yakinlastikca birbirinden UZAKLASIR (dogru olan bu).
///
/// Ama kalinliklar ve durak daireleri buyumez: her olcu [scale]'e bolunerek
/// cizilir, boylece pinlerle ayni kural gecerli olur -- ekranda sabit boy.
/// Cizim vektorel oldugu icin bolme gorsel kaliteyi dusurmez; tuval donusumu
/// rasterlestirme aninda uygulanir.
class _RoutePainter extends CustomPainter {
  const _RoutePainter({
    required this.route,
    required this.color,
    required this.scale,
  });

  final List<({double x, double y})> route;
  final Color color;

  /// Guncel yakinlastirma orani (bkz. [MapView] sinif notu).
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final points = [
      for (final p in route) Offset(p.x * size.width, p.y * size.height),
    ];

    if (points.length > 1) {
      // Koyu haritada da secilsin diye once koyu bir govde, uzerine renk.
      final shadow = Paint()
        ..color = Colors.black54
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5 / scale
        ..strokeCap = StrokeCap.round;
      final line = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 / scale
        ..strokeCap = StrokeCap.round;
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas
        ..drawPath(path, shadow)
        ..drawPath(path, line);
    }

    for (final (i, p) in points.indexed) {
      canvas
        ..drawCircle(p, 11 / scale, Paint()..color = Colors.black54)
        ..drawCircle(p, 9 / scale, Paint()..color = color);
      final label = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: TextStyle(
            color: Colors.white,
            fontSize: 11 / scale,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, p - Offset(label.width / 2, label.height / 2));
    }
  }

  @override
  bool shouldRepaint(_RoutePainter old) =>
      old.color != color ||
      old.scale != scale ||
      old.route.length != route.length ||
      // Ayni uzunlukta ama tasinmis rota da yeniden cizilmeli.
      Object.hashAll(old.route) != Object.hashAll(route);
}

class _PinMarker extends StatelessWidget {
  const _PinMarker({
    required this.pin,
    required this.visibleToPlayers,
    this.ghost = false,
    this.onTap,
    this.onSettings,
  });

  static const size = 32.0;

  /// Etiketin daireden iki yana tasabilecegi pay (yerlesimi etkilemez).
  static const _captionSpread = 90.0;

  final MapPin pin;
  final VoidCallback? onTap;

  /// Sag tik (masaustu) / uzun bas (dokunmatik).
  final VoidCallback? onSettings;

  /// Soluk cizim: oyunculara kapali bir pin, goruntuleme modunda. Dokunma
  /// hedefi kucultulmez — yalnizca opaklik duser (bkz. [MapView.editing]).
  final bool ghost;

  /// Pin su an oyunculara gorunuyor mu (pinin kendi bayragi DEGIL, gercek
  /// durum: yer/dukkan pinlerinde hedefin acik olmasi).
  final bool visibleToPlayers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final color = pinKindColor(pin.kind, theme.colorScheme);

    final dot = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          // Gizli pinler kesikli degil, soluk cerceveli: DM bir
          // bakista neyin oyunculara acik oldugunu gorsun.
          color: visibleToPlayers ? Colors.white : Colors.white24,
          width: 2,
        ),
        boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black54)],
      ),
      child: Icon(pinKindIcon(pin.kind), size: 18, color: Colors.white),
    );

    final caption = Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        pin.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
    );

    // Isaretcinin kutusu TAM OLARAK daire kadar (size x size); etiket
    // yerlesime katilmadan altinda yuzer.
    //
    // Neden: `Positioned` pini "sol = x*W - size/2, ust = y*H - size" ile
    // koyuyor, yani dairenin alt ortasinin haritadaki noktaya denk gelmesini
    // bekliyor. Etiket kutuyu genisletirse (uzun adli pinlerde) daire bu
    // varsayimdan kayiyordu. Kutu sabit olunca hem konum hem de ters olcegin
    // pivotu (alt orta) tam pinin ucuna oturur.
    final marker = SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: size + 2,
            // Etiket daireden genis olabilir; iki yana tasip ortalanir.
            left: -_captionSpread,
            right: -_captionSpread,
            child: Center(child: caption),
          ),
          Positioned.fill(child: dot),
        ],
      ),
    );

    return Tooltip(
      // Gizli pin renkle/soluklukla ayrisiyor; anlam YALNIZCA renge
      // birakilmasin diye ipucu metne de yazilir.
      message: visibleToPlayers
          ? pin.label
          : '${pin.label} · ${l10n.worldPinHiddenFromPlayers}',
      child: InkWell(
        onTap: onTap,
        onSecondaryTap: onSettings,
        onLongPress: onSettings,
        // Soluk ama okunur: gizli pin geri plana dusmeli, kaybolmamali —
        // DM masada kendi notunu secebilmeli.
        child: ghost ? Opacity(opacity: 0.65, child: marker) : marker,
      ),
    );
  }
}

/// Pin turunun ikonu. Harita disinda da kullanilir (salt-okunur pin ozeti),
/// bu yuzden ust duzey.
IconData pinKindIcon(PinKind kind) => switch (kind) {
  PinKind.location => Icons.place,
  PinKind.place => Icons.signpost,
  PinKind.note => Icons.sticky_note_2,
  PinKind.npc => Icons.person,
  PinKind.shop => Icons.storefront,
  PinKind.encounter => Icons.shield,
  PinKind.treasure => Icons.diamond,
};

/// Pin turunun rengi.
Color pinKindColor(PinKind kind, ColorScheme scheme) => switch (kind) {
  PinKind.location => scheme.primary,
  PinKind.place => Colors.indigo,
  PinKind.note => Colors.blueGrey,
  PinKind.npc => Colors.teal,
  PinKind.shop => Colors.amber.shade800,
  PinKind.encounter => scheme.error,
  PinKind.treasure => Colors.purple,
};
