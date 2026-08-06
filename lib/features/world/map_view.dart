import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../data/db/world_tables.dart';
import '../../l10n/app_localizations.dart';
import 'world_providers.dart';

/// Yakinlastirilabilir harita ve uzerindeki pinler.
///
/// Pin konumlari 0..1 oraninda saklandigi icin harita hangi olcude cizilirse
/// cizilsin ayni yerde duruyorlar. Pinler goruntunun icinde degil ustunde
/// ciziliyor ki yakinlastirinca buyuyup okunmaz hale gelmesinler.
class MapView extends ConsumerStatefulWidget {
  const MapView({
    required this.location,
    required this.pins,
    this.onTapEmpty,
    this.onTapPin,
    this.onPinSettings,
    this.onMovePin,
    this.playerView = false,
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

  @override
  void initState() {
    super.initState();
    _load();
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

  Widget _buildPin(MapPin pin, BoxConstraints constraints) {
    final marker = _PinMarker(
      pin: pin,
      onTap: widget.onTapPin == null ? null : () => widget.onTapPin!(pin),
      onSettings: widget.onPinSettings == null
          ? null
          : () => widget.onPinSettings!(pin),
    );
    if (widget.onMovePin == null) return marker;

    // Edit modda pin surukleyerek tasinir; birakinca yeni oran kaydedilir.
    return GestureDetector(
      onPanStart: (_) => setState(() {
        _dragId = pin.id;
        _dragDelta = Offset.zero;
      }),
      onPanUpdate: (d) => setState(() => _dragDelta += d.delta),
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
/// Noktalar 0..1 oraninda geldigi icin boyanan kutunun olcusuyle carpilir;
/// harita yakinlastirildiginda rota da onunla birlikte olceklenir.
class _RoutePainter extends CustomPainter {
  const _RoutePainter({required this.route, required this.color});

  final List<({double x, double y})> route;
  final Color color;

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
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      final line = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
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
        ..drawCircle(p, 11, Paint()..color = Colors.black54)
        ..drawCircle(p, 9, Paint()..color = color);
      final label = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
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
      old.route.length != route.length ||
      // Ayni uzunlukta ama tasinmis rota da yeniden cizilmeli.
      Object.hashAll(old.route) != Object.hashAll(route);
}

class _PinMarker extends StatelessWidget {
  const _PinMarker({required this.pin, this.onTap, this.onSettings});

  static const size = 32.0;

  final MapPin pin;
  final VoidCallback? onTap;

  /// Sag tik (masaustu) / uzun bas (dokunmatik).
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _colorFor(pin.kind, theme.colorScheme);

    return Tooltip(
      message: pin.label,
      child: InkWell(
        onTap: onTap,
        onSecondaryTap: onSettings,
        onLongPress: onSettings,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  // Gizli pinler kesikli degil, soluk cerceveli: DM bir
                  // bakista neyin oyunculara acik oldugunu gorsun.
                  color: pin.revealed ? Colors.white : Colors.white24,
                  width: 2,
                ),
                boxShadow: const [
                  BoxShadow(blurRadius: 4, color: Colors.black54),
                ],
              ),
              child: Icon(_iconFor(pin.kind), size: 18, color: Colors.white),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                pin.label,
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(PinKind kind) => switch (kind) {
    PinKind.location => Icons.place,
    PinKind.note => Icons.sticky_note_2,
    PinKind.npc => Icons.person,
    PinKind.shop => Icons.storefront,
    PinKind.encounter => Icons.shield,
    PinKind.treasure => Icons.diamond,
  };

  static Color _colorFor(PinKind kind, ColorScheme scheme) => switch (kind) {
    PinKind.location => scheme.primary,
    PinKind.note => Colors.blueGrey,
    PinKind.npc => Colors.teal,
    PinKind.shop => Colors.amber.shade800,
    PinKind.encounter => scheme.error,
    PinKind.treasure => Colors.purple,
  };
}
