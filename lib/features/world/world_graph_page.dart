import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/undo.dart';

import '../../app/theme.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import 'bond_type.dart';
import 'bond_types_settings.dart';
import 'faction_detail_page.dart';
import 'graph_interaction.dart';
import 'graph_simulation.dart';
import 'location_page.dart';
import 'npc_detail_page.dart';
import 'world_providers.dart';

/// Bir grafik dugumunun goruntu verisi (yer, NPC ya da fraksiyon).
class _NodeInfo {
  const _NodeInfo(
    this.kind,
    this.name,
    this.thumbPath, {
    this.nodeRadius,
    this.collapsed = false,
    this.hiddenChildren = 0,
  });
  final String kind; // 'location' | 'npc' | 'faction'
  final String name;
  final String? thumbPath;
  final double? nodeRadius;

  /// Alt yerleri katlanmis mi ve kac tanesi gizli?
  ///
  /// Yuz lokasyonlu bir dunyada ag okunmuyordu; katlanan dugumun uzerinde
  /// "+7" rozeti duruyor, cocuklarinin baglantilari da bu dugume tasiniyor
  /// ki ag kopmasin.
  final bool collapsed;
  final int hiddenChildren;
}

/// Dunya sekmesinin ana gorunumu: force-directed BIRLESIK dugum-agi (DM-only).
///
/// Dugumler yerler + NPC'ler + fraksiyonlar; kenarlar tipli [WorldLink]'ler
/// (dostluk/dusmanlik/ticaret/uyelik... renkli). Sol surukle dugumu yumusak
/// fizik takiple tasir; sag tik (masaustu) / uzun bas (dokunmatik) yeri
/// (klasik harita), NPC'yi ya da orgutu (detay) acar. Bos alanda surukle = kaydir, tekerlek = zoom. "Bagla" modunda secili
/// bag turuyle iki dugumu baglarsin; bir kenara dokunmak menu acar.
class WorldGraph extends ConsumerStatefulWidget {
  const WorldGraph({super.key});

  @override
  ConsumerState<WorldGraph> createState() => _WorldGraphState();
}

class _WorldGraphState extends ConsumerState<WorldGraph>
    with SingleTickerProviderStateMixin {
  static const _sim = GraphSimulation();
  static const _settleEnergy = 0.4;

  final _nodes = <String, SimNode>{};
  final _info = <String, _NodeInfo>{};
  final _thumbs = <String, ui.Image>{};
  final _thumbLoading = <String>{};
  var _links = <WorldLink>[];

  /// Local nodeRadius override'ları (DB güncellenince cache'e yansır ama reconcile ezmesin).
  final _localNodeRadius = <String, double>{};

  var _ordered = <String>[];
  var _simNodes = <SimNode>[];
  var _edges = <(int, int)>[];

  final _repaint = ValueNotifier<int>(0);
  late final Ticker _ticker = createTicker(_tick);

  Offset _pan = Offset.zero;
  double _scale = 1;
  bool _centered = false;

  /// Ekranda o an basili olan isaretciler (dokunmatik parmaklar).
  ///
  /// Ikiden fazlasini izlemiyoruz: iki parmak sikistirma (zoom), biri
  /// surukleme. Ucuncu parmak yok sayilir.
  final _pointers = <int, Offset>{};

  /// Sikistirma baslangici; null ise sikistirma yok.
  double? _pinchStartSpan;
  double _pinchStartScale = 1;
  Offset _pinchStartWorld = Offset.zero;

  /// Suren basma-surukleme-birakma dizisi; bosta null.
  ///
  /// Dokunus/surukleme karari BURADA degil, `graph_interaction.dart` icinde
  /// -- saf ve test edilebilir olmasi icin (bkz. o dosyanin basligi).
  GraphPointerSession? _session;

  String? _dragId;
  Offset _dragTargetWorld = Offset.zero;
  bool _longPressed = false;
  Offset _lastScreen = Offset.zero;
  Timer? _longPressTimer;

  bool _linkMode = false;
  String? _linkFirst;
  String _bondCode = 'friendship';
  Offset? _hoverScreen;

  /// Grafikte gorunen dugum turleri.
  ///
  /// Uc tur birden cizilince (yer + NPC + orgut) orta buyuklukte bir
  /// kampanyada ag okunmaz hale geliyor. Filtre bir GORUNUM ayari: hicbir sey
  /// silmiyor, yalnizca o anda bakilan katmani secmeye yariyor.
  final Set<String> _visibleKinds = {'location', 'npc', 'faction'};

  /// Odaklanilan dugum; null ise butun ag.
  ///
  /// Odakta yalnizca bu dugum ve DOGRUDAN komsulari cizilir. "Bu orgutun
  /// eli nerelere uzaniyor" sorusu yuz dugumluk bir agda gozle
  /// cevaplanamiyordu.
  String? _focusId;

  var _bonds = <BondType>[];
  final _bondColor = <String, Color>{};
  bool _seeded = false;

  int _seedCounter = 0;
  int _knownSig = 0;

  /// Varsayilan dugum yaricapi: yer en buyuk (dunyanin iskeleti), fraksiyon
  /// ortada (bir kisiden buyuk, bir yerden kucuk), NPC en kucuk.
  static double _defaultRadius(String? kind) => switch (kind) {
    'npc' => 21.0,
    'faction' => 25.0,
    _ => 30.0,
  };

  double _radius(String id) {
    final info = _info[id];
    return info?.nodeRadius ?? _defaultRadius(info?.kind);
  }

  Color _bondColorOf(String code) =>
      _bondColor[code] ?? const Color(kBondFallbackColor);

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _ticker.dispose();
    _repaint.dispose();
    for (final img in _thumbs.values) {
      img.dispose();
    }
    super.dispose();
  }

  // --- Reconcile ----------------------------------------------------------

  /// Katlama sonucu: gizlenen yerler, her gizli yerin gorunur atasi ve
  /// katlanmis dugumlerin kac cocugu gizledigi.
  ({
    Set<String> hidden,
    Map<String, String> representative,
    Map<String, int> counts,
  })
  _collapse(List<Location> all) {
    final byParent = <String, List<Location>>{};
    for (final location in all) {
      final parent = location.parentId;
      if (parent != null) (byParent[parent] ??= []).add(location);
    }
    final hidden = <String>{};
    final representative = <String, String>{};
    final counts = <String, int>{};

    void hide(String rootId, String id) {
      for (final child in byParent[id] ?? const <Location>[]) {
        if (!hidden.add(child.id)) continue;
        representative[child.id] = rootId;
        counts[rootId] = (counts[rootId] ?? 0) + 1;
        hide(rootId, child.id);
      }
    }

    for (final location in all) {
      if (location.graphCollapsed) hide(location.id, location.id);
    }
    return (hidden: hidden, representative: representative, counts: counts);
  }

  void _reconcile(
    List<Location> locs,
    List<Npc> npcs,
    List<Faction> factions,
    List<WorldLink> links,
    Map<String, int> collapsedCounts,
  ) {
    final infos = <String, _NodeInfo>{};
    final stored = <String, Offset?>{};
    for (final l in locs) {
      // Local override varsa onu kullan, yoksa DB'den
      final radius = _localNodeRadius[l.id] ?? l.nodeRadius;
      infos[l.id] = _NodeInfo(
        'location',
        l.name,
        l.mapImagePath,
        nodeRadius: radius,
        collapsed: l.graphCollapsed,
        hiddenChildren: collapsedCounts[l.id] ?? 0,
      );
      stored[l.id] = (l.graphX != null && l.graphY != null)
          ? Offset(l.graphX!, l.graphY!)
          : null;
    }
    for (final n in npcs) {
      final radius = _localNodeRadius[n.id] ?? n.nodeRadius;
      infos[n.id] = _NodeInfo(
        'npc',
        n.name,
        n.portraitPath,
        nodeRadius: radius,
      );
      stored[n.id] = (n.graphX != null && n.graphY != null)
          ? Offset(n.graphX!, n.graphY!)
          : null;
    }
    for (final f in factions) {
      final radius = _localNodeRadius[f.id] ?? f.nodeRadius;
      infos[f.id] = _NodeInfo(
        'faction',
        f.name,
        f.portraitPath,
        nodeRadius: radius,
      );
      stored[f.id] = (f.graphX != null && f.graphY != null)
          ? Offset(f.graphX!, f.graphY!)
          : null;
    }

    final ids = infos.keys.toSet();
    _nodes.removeWhere((id, _) => !ids.contains(id));
    _info
      ..clear()
      ..addAll(infos);

    var changed = false;
    for (final id in ids) {
      if (!_nodes.containsKey(id)) {
        final p = stored[id] ?? _seed();
        _nodes[id] = SimNode(p.dx, p.dy);
        changed = true;
      }
      _loadThumb(id, infos[id]!);
    }

    _links = links;
    final sig = Object.hashAll([
      ids.length,
      for (final l in links) '${l.aId}|${l.bId}|${l.type}',
    ]);
    if (sig != _knownSig) {
      _knownSig = sig;
      changed = true;
    }

    _ordered = _nodes.keys.toList();
    final indexOf = {for (var i = 0; i < _ordered.length; i++) _ordered[i]: i};
    _simNodes = [for (final id in _ordered) _nodes[id]!];
    _edges = [
      for (final l in _links)
        if (indexOf[l.aId] != null && indexOf[l.bId] != null)
          (indexOf[l.aId]!, indexOf[l.bId]!),
    ];

    if (changed) _wake();
  }

  Offset _seed() {
    final i = _seedCounter++;
    final r = 34 * sqrt(i + 1);
    final a = i * 2.399963;
    return Offset(r * cos(a), r * sin(a));
  }

  Future<void> _loadThumb(String id, _NodeInfo info) async {
    final path = info.thumbPath;
    if (path == null) return;
    if (_thumbs.containsKey(id) || _thumbLoading.contains(id)) return;
    _thumbLoading.add(id);
    try {
      final repo = ref.read(worldRepositoryProvider);
      final file = info.kind == 'npc'
          ? await repo.portraits.resolve(path)
          : await repo.images.resolve(path);
      if (!file.existsSync()) return;
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 120);
      final frame = await codec.getNextFrame();
      if (mounted) {
        _thumbs[id] = frame.image;
        _repaint.value++;
      }
    } catch (_) {
      // yer-tutucu
    } finally {
      _thumbLoading.remove(id);
    }
  }

  // --- Simulasyon ---------------------------------------------------------

  void _wake() {
    if (!_ticker.isActive) _ticker.start();
  }

  void _tick(Duration _) {
    var active = false;
    if (_dragId != null) {
      final node = _nodes[_dragId];
      if (node != null) {
        node.pinned = true;
        node.x += (_dragTargetWorld.dx - node.x) * 0.25;
        node.y += (_dragTargetWorld.dy - node.y) * 0.25;
      }
      active = true;
    }

    var cx = 0.0, cy = 0.0;
    if (_simNodes.isNotEmpty) {
      for (final n in _simNodes) {
        cx += n.x;
        cy += n.y;
      }
      cx /= _simNodes.length;
      cy /= _simNodes.length;
    }

    final energy = _sim.step(_simNodes, _edges, centerX: cx, centerY: cy);
    if (energy > _settleEnergy) active = true;

    _repaint.value++;
    if (!active) {
      _ticker.stop();
      _persistPositions();
    }
  }

  Future<void> _persistPositions() async {
    final byKind = <String, List<({String id, double x, double y})>>{
      'location': [],
      'npc': [],
      'faction': [],
    };
    for (final e in _nodes.entries) {
      final kind = _info[e.key]?.kind ?? 'location';
      byKind[byKind.containsKey(kind) ? kind : 'location']!.add((
        id: e.key,
        x: e.value.x,
        y: e.value.y,
      ));
    }
    final repo = ref.read(worldRepositoryProvider);
    await repo.saveGraphPositions(byKind['location']!);
    await repo.saveNpcGraphPositions(byKind['npc']!);
    await repo.saveFactionGraphPositions(byKind['faction']!);
  }

  // --- Koordinat ----------------------------------------------------------

  Offset _toWorld(Offset s) =>
      Offset((s.dx - _pan.dx) / _scale, (s.dy - _pan.dy) / _scale);

  String? _hitNode(Offset world) {
    // EN YAKIN dugum seciliyor, ilk isabet eden degil: dokunma hedefleri
    // uzaklasmis bir grafikte cakisabiliyor ve o zaman cizim sirasi
    // "hangisine dokundum" sorusunu belirliyordu.
    String? best;
    var bestDistance = double.infinity;
    for (final id in _ordered) {
      final n = _nodes[id]!;
      final distance = (world - Offset(n.x, n.y)).distance;
      if (distance > graphHitRadius(_radius(id), _scale)) continue;
      if (distance >= bestDistance) continue;
      bestDistance = distance;
      best = id;
    }
    return best;
  }

  WorldLink? _hitEdge(Offset world) {
    for (final l in _links) {
      final a = _nodes[l.aId], b = _nodes[l.bId];
      if (a == null || b == null) continue;
      final d = _distToSegment(world, Offset(a.x, a.y), Offset(b.x, b.y));
      if (d <= 8 / _scale + 3) return l;
    }
    return null;
  }

  static double _distToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 < 1e-6) return (p - a).distance;
    var t = ((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2;
    t = t.clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  // --- Isaretci -----------------------------------------------------------

  void _onPointerDown(PointerDownEvent e) {
    _pointers[e.pointer] = e.localPosition;

    // Ikinci parmak: sikistirma baslar, suren surukleme/dokunus IPTAL olur.
    // Iptal sart -- yoksa iki parmakla yakinlastirmak once bir dugumu
    // suruklemis olurdu ve parmagini kaldirinca dugum orada kalirdi.
    if (_pointers.length == 2) {
      _cancelSession();
      _beginPinch();
      return;
    }
    if (_pointers.length > 2) return;

    final world = _toWorld(e.localPosition);
    _lastScreen = e.localPosition;
    _longPressed = false;
    final hitId = _hitNode(world);

    // Sağ tık: context menu aç (eğer düğüm varsa)
    if (e.buttons == kSecondaryButton) {
      if (hitId != null) {
        _showNodeMenu(hitId, e.localPosition);
      }
      return;
    }

    _session = GraphPointerSession(
      startScreen: e.localPosition,
      kind: e.kind,
      nodeId: hitId,
    );

    if (hitId == null) return;

    _dragId = hitId;
    _dragTargetWorld = world;
    _nodes[hitId]!.pinned = true;
    _longPressTimer?.cancel();
    // BAGLAMA MODUNDA uzun basma menusu YOK: orada basili tutmak "dikkatli
    // nisan aliyorum" demek, "menu ac" demek degil. Menu aciliverince
    // secim de kayboluyordu.
    if (!_linkMode) {
      _longPressTimer = Timer(const Duration(milliseconds: 500), () {
        if (_dragId == hitId && !(_session?.moved ?? true)) {
          _longPressed = true;
          _releaseDrag(persist: false);
          _showNodeMenu(hitId, e.localPosition);
        }
      });
    }
    _wake();
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (_pointers.containsKey(e.pointer)) {
      _pointers[e.pointer] = e.localPosition;
    }
    if (_pinchStartSpan != null) {
      _updatePinch();
      return;
    }

    final delta = e.localPosition - _lastScreen;
    _lastScreen = e.localPosition;

    final session = _session;
    if (session == null) return;
    session.update(e.localPosition);
    if (session.moved) _longPressTimer?.cancel();

    switch (session.gesture) {
      case GraphGesture.dragNode:
        _dragTargetWorld = _toWorld(e.localPosition);
        _wake();
      case GraphGesture.panCanvas:
        _pan += delta;
        _repaint.value++;
      case GraphGesture.pending:
        // Esik asilmadi: hicbir sey yapma. Baglama modunda lastik bandin
        // parmagi izlemesi icin yine de yeniden ciziyoruz (dokunmatikte
        // `onHover` hic gelmiyor).
        if (_linkMode && _linkFirst != null) {
          _hoverScreen = e.localPosition;
          _repaint.value++;
        }
    }
  }

  void _onPointerUp(PointerUpEvent e) {
    _pointers.remove(e.pointer);
    if (_pinchStartSpan != null) {
      // Bir parmak kalkti: sikistirma biter. Kalan parmak YENI bir surukleme
      // baslatmaz; kullanici parmagini kaldirip yeniden koymali. Aksi halde
      // zoom'dan cikarken ag kayiyordu.
      if (_pointers.length < 2) _pinchStartSpan = null;
      return;
    }

    _longPressTimer?.cancel();
    final session = _session;
    _session = null;

    if (_longPressed) {
      _longPressed = false;
      return;
    }
    if (session == null) return;

    if (session.nodeId != null) {
      // Surukleme yalnizca esik ASILDIYSA kaydedilir; aksi halde dokunus.
      _releaseDrag(persist: !session.isTap);
      if (session.isTap && _linkMode) _onLinkTapNode(session.nodeId!);
      return;
    }

    // Tuvale dokunus (kaydirma DEGIL): once kenar menusu, sonra secimi iptal.
    if (!session.isTap) return;
    final world = _toWorld(e.localPosition);
    final edge = _hitEdge(world);
    if (edge != null) {
      _showEdgeMenu(edge, e.position);
    } else if (_linkMode && _linkFirst != null) {
      setState(() => _linkFirst = null);
    }
  }

  void _releaseDrag({required bool persist}) {
    final id = _dragId;
    _dragId = null;
    if (id == null) return;
    final n = _nodes[id];
    if (n == null) return;
    n.pinned = false;
    if (persist) {
      final repo = ref.read(worldRepositoryProvider);
      switch (_info[id]?.kind) {
        case 'npc':
          repo.setNpcGraphPosition(id, n.x, n.y);
        case 'faction':
          repo.setFactionGraphPosition(id, n.x, n.y);
        case _:
          repo.setGraphPosition(id, n.x, n.y);
      }
    }
  }

  void _onPointerCancel(PointerCancelEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.length < 2) _pinchStartSpan = null;
    _cancelSession();
  }

  /// Suren dokunus/surukleme dizisini iz birakmadan iptal eder.
  void _cancelSession() {
    _longPressTimer?.cancel();
    _session = null;
    _longPressed = false;
    _releaseDrag(persist: false);
  }

  /// Iki parmak arasindaki uzaklik ve orta nokta.
  ({double span, Offset focal})? _pinchGeometry() {
    if (_pointers.length < 2) return null;
    final points = _pointers.values.take(2).toList();
    return (
      span: (points[0] - points[1]).distance,
      focal: (points[0] + points[1]) / 2,
    );
  }

  void _beginPinch() {
    final g = _pinchGeometry();
    if (g == null || g.span < 1) return;
    _pinchStartSpan = g.span;
    _pinchStartScale = _scale;
    // Iki parmagin ortasindaki DUNYA noktasi sabit kalmali: yakinlastirirken
    // baktigin yer kaymamali.
    _pinchStartWorld = _toWorld(g.focal);
  }

  void _updatePinch() {
    final start = _pinchStartSpan;
    final g = _pinchGeometry();
    if (start == null || g == null || start < 1) return;
    _scale = (_pinchStartScale * (g.span / start)).clamp(0.2, 3.0);
    _pan = g.focal - _pinchStartWorld * _scale;
    _repaint.value++;
  }

  void _onSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    final s = e.localPosition;
    final worldBefore = _toWorld(s);
    final factor = e.scrollDelta.dy < 0 ? 1.12 : 1 / 1.12;
    _scale = (_scale * factor).clamp(0.2, 3.0);
    _pan = s - Offset(worldBefore.dx, worldBefore.dy) * _scale;
    _repaint.value++;
  }

  Future<void> _onLinkTapNode(String id) async {
    final firstId = _linkFirst;
    if (firstId == null) {
      setState(() => _linkFirst = id);
      return;
    }
    if (firstId == id) {
      setState(() => _linkFirst = null);
      return;
    }

    final l10n = L10n.of(context);
    final repo = ref.read(worldRepositoryProvider);
    // Ayni cift zaten bagliysa `createLink` TUR DEGISTIRIR, yeni kenar
    // acmaz. Kullaniciya hangisinin oldugunu soylemek gerekiyor: aksi halde
    // "bagladim ama bir sey olmadi" hissi veriyordu.
    final existing = await repo.findLink(firstId, id);
    await repo.createLink(
      firstId,
      id,
      xKind: _info[firstId]?.kind ?? 'location',
      yKind: _info[id]?.kind ?? 'location',
      type: _bondCode,
    );
    if (!mounted) return;
    setState(() => _linkFirst = null);

    final a = _info[firstId]?.name ?? '';
    final b = _info[id]?.name ?? '';
    // Geri alma: bag yeniyse silinir, var olan bir bagin turu degistiyse
    // eski turune donulur. Ctrl+Z zaten uygulama geneli.
    ref
        .read(undoControllerProvider.notifier)
        .push(
          existing == null
              ? l10n.worldGraphLinked(a, b)
              : l10n.worldGraphRetyped(a, b),
          () async => existing == null
              ? repo.deleteLinkBetween(firstId, id)
              : repo.updateLinkType(existing.id, existing.type),
        );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            existing == null
                ? l10n.worldGraphLinked(a, b)
                : l10n.worldGraphRetyped(a, b),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _showEdgeMenu(WorldLink link, Offset globalPos) async {
    final l10n = L10n.of(context);
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPos.dx,
        globalPos.dy,
        globalPos.dx,
        globalPos.dy,
      ),
      items: [
        for (final b in _bonds)
          PopupMenuItem(
            value: 'type:${b.code}',
            child: Row(
              children: [
                _dot(Color(b.color)),
                const SizedBox(width: 8),
                Text(b.name),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(value: 'delete', child: Text(l10n.worldGraphDeleteLink)),
      ],
    );
    if (selected == null) return;
    final repo = ref.read(worldRepositoryProvider);
    if (selected == 'delete') {
      await repo.deleteLink(link.id);
    } else if (selected.startsWith('type:')) {
      await repo.updateLinkType(link.id, selected.substring(5));
    }
  }

  static IconData _kindIcon(String kind) => switch (kind) {
    'npc' => Icons.face,
    'faction' => Icons.groups_2_outlined,
    _ => Icons.place_outlined,
  };

  static String _kindLabel(L10n l10n, String kind) => switch (kind) {
    'npc' => l10n.worldGraphKindNpcs,
    'faction' => l10n.worldGraphKindFactions,
    _ => l10n.worldGraphKindLocations,
  };

  Widget _dot(Color c) => Container(
    width: 12,
    height: 12,
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
  );

  /// Sağ tık / uzun bas ile açılan düğüm menüsü.
  Future<void> _showNodeMenu(String id, Offset localPos) async {
    final l10n = L10n.of(context);
    final info = _info[id];
    // Dugum bilgisi yoksa menu anlamsiz (grafik henuz uzlasmamis).
    if (info == null) return;
    final kind = info.kind;

    // Menüyü tıklanan yerin TAM ÜSTÜNDE aç (localPos = e.localPosition)
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        localPos.dx,
        localPos.dy,
        localPos.dx,
        localPos.dy,
      ),
      items: [
        // 1. Kaydi ac (yer haritasi / NPC / fraksiyon sayfasi)
        PopupMenuItem(
          value: 'open',
          child: Row(
            children: [
              Icon(switch (kind) {
                'npc' => Icons.person_outline,
                'faction' => Icons.groups_2_outlined,
                _ => Icons.map_outlined,
              }, size: 18),
              const SizedBox(width: 8),
              Text(l10n.worldGraphOpenLocation),
            ],
          ),
        ),
        // 2. Alt yerleri katla/ac (yalnizca yer)
        if (kind == 'location')
          PopupMenuItem(
            value: 'toggle_collapse',
            child: Row(
              children: [
                Icon(
                  info.collapsed ? Icons.unfold_more : Icons.unfold_less,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  info.collapsed
                      ? l10n.worldExpandChildren
                      : l10n.worldCollapseChildren,
                ),
              ],
            ),
          ),
        // 3. Odak: bu dugum + dogrudan komsulari
        PopupMenuItem(
          value: 'focus',
          child: Row(
            children: [
              Icon(
                _focusId == id
                    ? Icons.center_focus_weak
                    : Icons.center_focus_strong,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                _focusId == id
                    ? l10n.worldGraphFocusClear
                    : l10n.worldGraphFocus,
              ),
            ],
          ),
        ),
        // 4. Düğüm boyutu (her tip için)
        PopupMenuItem(
          value: 'set_radius',
          child: Row(
            children: [
              const Icon(Icons.aspect_ratio_outlined, size: 18),
              const SizedBox(width: 8),
              Text(l10n.worldGraphSetSize),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete_outline, size: 18, color: Colors.red),
              const SizedBox(width: 8),
              Text(switch (kind) {
                'npc' => l10n.worldDeleteNpc,
                'faction' => l10n.factionDelete,
                _ => l10n.worldDeleteLocation,
              }, style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );

    if (selected == null || !mounted) return;

    switch (selected) {
      case 'open':
        _openNode(id);
        break;
      case 'toggle_collapse':
        await ref
            .read(worldRepositoryProvider)
            .updateLocation(id, graphCollapsed: !(info.collapsed));
        break;
      case 'focus':
        setState(() => _focusId = _focusId == id ? null : id);
        break;
      case 'set_radius':
        await _setNodeRadius(id);
        break;
      case 'delete':
        await _confirmDelete(kind, id);
        break;
    }
  }

  /// Düğüm (küre) boyutunu ayarlama dialogu.
  Future<void> _setNodeRadius(String id) async {
    final repo = ref.read(worldRepositoryProvider);
    final info = _info[id];
    if (info == null || !mounted) return;

    final kind = info.kind;
    final currentRadius = info.nodeRadius ?? _defaultRadius(kind);
    final ctrl = TextEditingController(text: currentRadius.toStringAsFixed(1));
    final l10n = L10n.of(context);

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.worldGraphSetSize),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.worldGraphSizeHint),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.worldGraphNodeRadiusLabel,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final r = double.tryParse(ctrl.text.trim());
              if (r != null && r > 0) {
                Navigator.pop(context, r);
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (result != null) {
      switch (kind) {
        case 'npc':
          await repo.updateNpc(id, nodeRadius: result);
        case 'faction':
          await repo.updateFaction(id, nodeRadius: result);
        case _:
          await repo.updateLocation(id, nodeRadius: result);
      }
      // Local override kaydet (reconcile bunu DB'den gelene tercih edecek)
      _localNodeRadius[id] = result;
      // Cache'i ve grafiği yenile
      _info[id] = _NodeInfo(
        kind,
        info.name,
        info.thumbPath,
        nodeRadius: result,
      );
      _repaint.value++;
    }
  }

  /// Silme onayı.
  Future<void> _confirmDelete(String kind, String id) async {
    final l10n = L10n.of(context);
    final name = _info[id]?.name ?? id;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.worldDeleteConfirmTitle(name)),
        content: Text(l10n.worldDeleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      final repo = ref.read(worldRepositoryProvider);
      switch (kind) {
        case 'npc':
          await repo.deleteNpc(id);
        case 'faction':
          await repo.deleteFaction(id);
        case _:
          await repo.deleteLocation(id);
      }
    }
  }

  /// Tur filtresi + odak uygulanmis gorunum.
  ///
  /// Odak varsa yalnizca odaklanilan dugum ve DOGRUDAN komsulari kalir;
  /// odaktaki dugum turu filtreden bagimsiz her zaman gorunur (aksi halde
  /// odaklanip sonra turunu kapatmak bos bir ekran verirdi).
  ({
    List<Location> locations,
    List<Npc> npcs,
    List<Faction> factions,
    List<WorldLink> links,
  })
  _applyView(
    List<Location> locs,
    List<Npc> npcs,
    List<Faction> factions,
    List<WorldLink> links,
  ) {
    final ids = visibleGraphNodes(
      kindOf: {
        for (final l in locs) l.id: 'location',
        for (final n in npcs) n.id: 'npc',
        for (final f in factions) f.id: 'faction',
      },
      links: [for (final l in links) (aId: l.aId, bId: l.bId)],
      visibleKinds: _visibleKinds,
      focusId: _focusId,
    );

    return (
      locations: [
        for (final l in locs)
          if (ids.contains(l.id)) l,
      ],
      npcs: [
        for (final n in npcs)
          if (ids.contains(n.id)) n,
      ],
      factions: [
        for (final f in factions)
          if (ids.contains(f.id)) f,
      ],
      // Bir ucu elenen kenar cizilemez; `_reconcile` zaten atliyor ama
      // listeyi burada temizlemek kenar isabet testini de dogru tutuyor.
      links: [
        for (final link in links)
          if (ids.contains(link.aId) && ids.contains(link.bId)) link,
      ],
    );
  }

  void _openNode(String id) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => switch (_info[id]?.kind) {
          'npc' => NpcDetailPage(npcId: id),
          'faction' => FactionDetailPage(factionId: id),
          _ => LocationPage(locationId: id),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    // Haritasiz yer pinlerinin arkasindaki kayitlar dugum OLMAZ: onlar gorev
    // ve planlayici listelerinde gozuksun diye acilmis isaretler, gercek yer
    // degil. Agda gozukunce her sehrin her tabelasi bir dugum oluyor ve asil
    // yerler kayboluyordu.
    final markers = ref.watch(markerLocationIdsProvider).value ?? const {};
    final visibleLocations = <Location>[
      for (final l
          in ref.watch(allLocationsProvider).value ?? const <Location>[])
        if (!markers.contains(l.id)) l,
    ];
    // Katlanmis bir yerin BUTUN soyu gizlenir; baglantilari ise gorunur en
    // yakin atasina tasinir (bkz. [_collapse]).
    final collapse = _collapse(visibleLocations);
    final locs = <Location>[
      for (final l in visibleLocations)
        if (!collapse.hidden.contains(l.id)) l,
    ];
    final npcs = ref.watch(npcsProvider).value ?? const [];
    final factions = ref.watch(factionsProvider).value ?? const [];
    final rawLinks = ref.watch(worldLinksProvider).value ?? const <WorldLink>[];
    // Gizli uclar atalarina baglaniyor; ayni ata cifti birden fazla kez
    // cikarsa kenar bir kez cizilir.
    final seen = <String>{};
    final links = <WorldLink>[
      for (final link in rawLinks)
        if (() {
          final a = collapse.representative[link.aId] ?? link.aId;
          final b = collapse.representative[link.bId] ?? link.bId;
          return a != b && seen.add('\$a|\$b|\${link.type}');
        }())
          link.copyWith(
            aId: collapse.representative[link.aId] ?? link.aId,
            bId: collapse.representative[link.bId] ?? link.bId,
          ),
    ];
    // Tur filtresi ve odak, `_reconcile`den ONCE uygulaniyor: gizlenen bir
    // dugum simulasyona hic girmemeli, yoksa gorunmeyen kutleler gorunen
    // dugumleri iter ve ag "kendiliginden kayiyor" gibi durur.
    final view = _applyView(locs, npcs, factions, links);
    _reconcile(
      view.locations,
      view.npcs,
      view.factions,
      view.links,
      collapse.counts,
    );

    // Bag turleri (duzenlenebilir); ilk acilista varsayilanlari tohumla.
    if (!_seeded) {
      _seeded = true;
      ref
          .read(worldRepositoryProvider)
          .ensureDefaultBondTypes(defaultBondTypes(l10n));
    }
    _bonds = ref.watch(bondTypesProvider).value ?? const [];
    _bondColor
      ..clear()
      ..addEntries(_bonds.map((b) => MapEntry(b.code, Color(b.color))));
    if (_bonds.isNotEmpty && !_bonds.any((b) => b.code == _bondCode)) {
      _bondCode = _bonds.first.code;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!_centered && constraints.biggest.isFinite) {
          _pan = constraints.biggest.center(Offset.zero);
          _centered = true;
        }
        return Stack(
          children: [
            Positioned.fill(
              child: Listener(
                onPointerDown: _onPointerDown,
                onPointerMove: _onPointerMove,
                onPointerUp: _onPointerUp,
                // Iptal edilen isaretci (sistem jesti, pencere kaybi)
                // temizlenmezse sikistirma kilitli kalir ve grafik bir daha
                // suruklenemez.
                onPointerCancel: _onPointerCancel,
                onPointerSignal: _onSignal,
                child: MouseRegion(
                  cursor: _linkMode
                      ? SystemMouseCursors.precise
                      : SystemMouseCursors.grab,
                  onHover: (e) {
                    _hoverScreen = e.localPosition;
                    if (_linkMode && _linkFirst != null) _repaint.value++;
                  },
                  // Grafik her karede yeniden ciziliyor; RepaintBoundary onu
                  // kendi katmanina alir, ustteki arac cubugu/cipler bosuna
                  // yeniden boyanmaz.
                  child: RepaintBoundary(
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: _GraphPainter(this, theme, repaint: _repaint),
                    ),
                  ),
                ),
              ),
            ),
            _toolbar(theme, l10n),
            // Kosede bag turu ayarlari.
            Positioned(
              right: 12,
              top: 12,
              child: Material(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.9,
                ),
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: l10n.bondSettingsTitle,
                  icon: const Icon(Icons.tune),
                  onPressed: () => showBondTypeSettings(context, ref),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _toolbar(ThemeData theme, L10n l10n) {
    return Positioned(
      left: 12,
      top: 12,
      right: 64,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterChip(
                avatar: const Icon(Icons.hub_outlined, size: 18),
                label: Text(l10n.worldGraphConnect),
                selected: _linkMode,
                onSelected: (v) => setState(() {
                  _linkMode = v;
                  _linkFirst = null;
                }),
              ),
              // Tur filtresi: hangi katmana bakiyoruz. Kapali bir tur
              // SILINMIYOR, yalnizca cizilmiyor.
              for (final kind in const ['location', 'npc', 'faction'])
                FilterChip(
                  avatar: Icon(_kindIcon(kind), size: 18),
                  label: Text(_kindLabel(l10n, kind)),
                  selected: _visibleKinds.contains(kind),
                  onSelected: (on) => setState(() {
                    // Son acik tur kapatilamaz: bos bir grafik hicbir sey
                    // anlatmiyor ve geri acmanin yolu da gorunmuyor.
                    if (!on && _visibleKinds.length == 1) return;
                    on ? _visibleKinds.add(kind) : _visibleKinds.remove(kind);
                  }),
                ),
              if (_focusId != null)
                InputChip(
                  avatar: const Icon(Icons.center_focus_strong, size: 18),
                  label: Text(
                    l10n.worldGraphFocusOn(_info[_focusId]?.name ?? ''),
                  ),
                  onDeleted: () => setState(() => _focusId = null),
                  deleteIcon: const Icon(Icons.close, size: 16),
                ),
            ],
          ),
          if (_linkMode) ...[
            const SizedBox(height: 8),
            // Bag turu fircasi (secili tip yeni baglara uygulanir).
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final b in _bonds)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        avatar: _dot(Color(b.color)),
                        label: Text(b.name),
                        selected: _bondCode == b.code,
                        onSelected: (_) => setState(() => _bondCode = b.code),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                l10n.worldGraphConnectHint,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  _GraphPainter(this.state, this.theme, {required Listenable repaint})
    : super(repaint: repaint);

  final _WorldGraphState state;
  final ThemeData theme;

  /// Tuval bilincli olarak koyu kalir (gece haritasi / mum isigi), ama TONU
  /// uygulamanin geri kalaniyla ayni ailedendir. Onceden soguk mavi
  /// (0xFF141A2B / 0xFF6D8BFF) idi ve sicak parsomen temasinin ortasinda
  /// baska bir uygulamadan kopyalanmis gibi duruyordu.
  static const _bgTop = Color(0xFF241A13);
  static const _bgBottom = Color(0xFF120D09);

  /// Secili dugum vurgusu tema jetonundan gelir (kor kirmizisi / altin),
  /// boylece palet degisirse grafik de birlikte doner.
  Color get _accent =>
      theme.extension<AppFantasyColors>()?.gold ?? theme.colorScheme.primary;

  /// Izgara ve dugum uzerindeki acik tonlar icin sicak parsomen beyazi;
  /// duz `Colors.white` koyu kahve zeminde mavimsi duruyordu.
  static const _light = Color(0xFFF3E7CE);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = state._scale;
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_bgTop, _bgBottom],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.95,
          colors: [
            const Color(0x00000000),
            Colors.black.withValues(alpha: 0.45),
          ],
          stops: const [0.6, 1.0],
        ).createShader(rect),
    );

    canvas.save();
    canvas.translate(state._pan.dx, state._pan.dy);
    canvas.scale(scale);

    _drawGrid(canvas, size, scale);
    _drawEdges(canvas, scale);
    _drawRubberBand(canvas, scale);
    _drawNodes(canvas, scale);

    canvas.restore();
  }

  void _drawGrid(Canvas canvas, Size size, double scale) {
    const step = 84.0;
    if (step * scale < 7) return;
    final left = -state._pan.dx / scale;
    final top = -state._pan.dy / scale;
    final right = (size.width - state._pan.dx) / scale;
    final bottom = (size.height - state._pan.dy) / scale;
    final dot = Paint()..color = _light.withValues(alpha: 0.06);
    final r = 1.3 / scale;
    final x0 = (left / step).floor() * step;
    final y0 = (top / step).floor() * step;
    var count = 0;
    for (var x = x0; x <= right && count < 6000; x += step) {
      for (var y = y0; y <= bottom && count < 6000; y += step) {
        canvas.drawCircle(Offset(x, y), r, dot);
        count++;
      }
    }
  }

  void _drawEdges(Canvas canvas, double scale) {
    for (final l in state._links) {
      final a = state._nodes[l.aId], b = state._nodes[l.bId];
      if (a == null || b == null) continue;
      final color = state._bondColorOf(l.type);
      final pa = Offset(a.x, a.y), pb = Offset(b.x, b.y);
      canvas.drawLine(
        pa,
        pb,
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 5 / scale
          ..color = color.withValues(alpha: 0.18)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 / scale),
      );
      canvas.drawLine(
        pa,
        pb,
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.8 / scale
          ..color = color.withValues(alpha: 0.85),
      );
    }
  }

  void _drawRubberBand(Canvas canvas, double scale) {
    final firstId = state._linkFirst;
    final hover = state._hoverScreen;
    if (firstId == null || hover == null) return;
    final n = state._nodes[firstId];
    if (n == null) return;
    final world = state._toWorld(hover);
    canvas.drawLine(
      Offset(n.x, n.y),
      world,
      Paint()
        ..strokeWidth = 1.8 / scale
        ..strokeCap = StrokeCap.round
        ..color = state._bondColorOf(state._bondCode).withValues(alpha: 0.8),
    );
  }

  void _drawNodes(Canvas canvas, double scale) {
    for (final id in state._ordered) {
      final n = state._nodes[id]!;
      final info = state._info[id];
      final r = state._radius(id);
      final c = Offset(n.x, n.y);
      final img = state._thumbs[id];
      final selected = id == state._linkFirst;
      final kind = info?.kind;
      final tint = _nodeColor(id);

      canvas.drawCircle(
        c,
        r + 5,
        Paint()
          ..color = (selected ? _accent : tint).withValues(alpha: 0.35)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 7 / scale),
      );
      canvas.drawCircle(
        c.translate(0, 2 / scale),
        r,
        Paint()..color = Colors.black.withValues(alpha: 0.35),
      );

      if (img != null) {
        canvas.save();
        canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
        final circleRect = Rect.fromCircle(center: c, radius: r);
        canvas.drawImageRect(
          img,
          Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
          circleRect,
          Paint()..filterQuality = FilterQuality.medium,
        );
        canvas.drawRect(
          circleRect,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_light.withValues(alpha: 0.20), const Color(0x00000000)],
            ).createShader(circleRect),
        );
        canvas.restore();
      } else {
        final light = _lighten(tint, 0.16);
        final dark = _darken(tint, 0.14);
        canvas.drawCircle(
          c,
          r,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [light, dark],
            ).createShader(Rect.fromCircle(center: c, radius: r)),
        );
        switch (kind) {
          case 'npc':
            _paintPersonGlyph(canvas, c, r);
          case 'faction':
            _paintShieldGlyph(canvas, c, r);
          case _:
            _paintText(
              canvas,
              (info?.name.isNotEmpty ?? false)
                  ? info!.name[0].toUpperCase()
                  : '?',
              c,
              20,
              _light,
            );
        }
      }

      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (selected ? 3.5 : 2.5) / scale
          ..color = selected ? _accent : _light.withValues(alpha: 0.85),
      );

      // Katlanmis dugumun uzerinde kac cocuk gizledigi yaziyor: ag
      // sadelesirken bilgi kaybolmuyor.
      if ((info?.hiddenChildren ?? 0) > 0) {
        final badge = c.translate(r * 0.72, -r * 0.72);
        final label = '+\${info!.hiddenChildren}';
        final radius = 10.0 + label.length * 1.6;
        canvas
          ..drawCircle(badge, radius, Paint()..color = _accent)
          ..drawCircle(
            badge,
            radius,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6 / scale
              ..color = _light.withValues(alpha: 0.9),
          );
        _paintText(canvas, label, badge, 12, _light);
      }

      if (info != null) _paintLabel(canvas, info.name, c.dy + r + 7, c.dx);
    }
  }

  // Basit kisi silueti (portresi olmayan NPC dugumleri icin).
  void _paintPersonGlyph(Canvas canvas, Offset c, double r) {
    final p = Paint()..color = _light.withValues(alpha: 0.92);
    canvas.drawCircle(c.translate(0, -r * 0.22), r * 0.28, p);
    final body = Path()
      ..addArc(
        Rect.fromCircle(center: c.translate(0, r * 0.52), radius: r * 0.55),
        pi,
        pi,
      );
    canvas.drawPath(body, p);
  }

  /// Fraksiyon dugumunun armasi: basit bir kalkan silueti.
  ///
  /// Yer dugumu adin bas harfini, NPC dugumu bir insan siluetini gosteriyor;
  /// orgutun de bir bakista ayrisan kendi isareti olmali. Kalkan secildi
  /// cunku hem heraldik hem de daire icinde 20 pikselde bile okunuyor.
  void _paintShieldGlyph(Canvas canvas, Offset c, double r) {
    final w = r * 0.62, h = r * 0.78;
    final top = c.translate(0, -h * 0.55);
    final path = Path()
      ..moveTo(top.dx - w / 2, top.dy)
      ..lineTo(top.dx + w / 2, top.dy)
      ..lineTo(top.dx + w / 2, top.dy + h * 0.52)
      // Alt uc: iki yandan ortada bir noktaya inen egri.
      ..quadraticBezierTo(top.dx + w / 2, top.dy + h, top.dx, top.dy + h * 1.05)
      ..quadraticBezierTo(
        top.dx - w / 2,
        top.dy + h,
        top.dx - w / 2,
        top.dy + h * 0.52,
      )
      ..close();
    canvas.drawPath(path, Paint()..color = _light.withValues(alpha: 0.92));
  }

  void _paintLabel(Canvas canvas, String text, double topY, double centerX) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: _light,
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: 128);
    const padX = 7.0, padY = 3.0;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        centerX - tp.width / 2 - padX,
        topY - padY,
        tp.width + padX * 2,
        tp.height + padY * 2,
      ),
      const Radius.circular(7),
    );
    canvas.drawRRect(
      rrect,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
    tp.paint(canvas, Offset(centerX - tp.width / 2, topY));
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset at,
    double fontSize,
    Color color,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          shadows: const [Shadow(color: Colors.black54, blurRadius: 2)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(at.dx - tp.width / 2, at.dy - tp.height / 2));
  }

  Color _nodeColor(String id) {
    final hue = (id.hashCode % 360).abs().toDouble();
    return HSLColor.fromAHSL(1, hue, 0.42, 0.52).toColor();
  }

  Color _lighten(Color c, double amt) {
    final h = HSLColor.fromColor(c);
    return h.withLightness((h.lightness + amt).clamp(0.0, 1.0)).toColor();
  }

  Color _darken(Color c, double amt) {
    final h = HSLColor.fromColor(c);
    return h.withLightness((h.lightness - amt).clamp(0.0, 1.0)).toColor();
  }

  @override
  bool shouldRepaint(_GraphPainter old) => false;
}
