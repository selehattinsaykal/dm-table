import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import 'bond_type.dart';
import 'bond_types_settings.dart';
import 'graph_simulation.dart';
import 'location_page.dart';
import 'npc_detail_page.dart';
import 'world_providers.dart';

/// Bir grafik dugumunun goruntu verisi (yer ya da NPC).
class _NodeInfo {
  const _NodeInfo(
    this.kind,
    this.name,
    this.thumbPath, {
    this.nodeRadius,
    this.revealed = false,
  });
  final String kind; // 'location' | 'npc'
  final String name;
  final String? thumbPath;
  final double? nodeRadius;

  /// Yer su an oyunculara acik mi (`Locations.revealed`)? NPC'lerde anlamsiz.
  final bool revealed;
}

/// Dunya sekmesinin ana gorunumu: force-directed BIRLESIK dugum-agi (DM-only).
///
/// Dugumler yerler + NPC'ler; kenarlar tipli [WorldLink]'ler (dostluk/dusmanlik
/// /ticaret... renkli). Sol surukle dugumu yumusak fizik takiple tasir; sag tik
/// (masaustu) / uzun bas (dokunmatik) yeri (klasik harita) ya da NPC'yi (detay)
/// acar. Bos alanda surukle = kaydir, tekerlek = zoom. "Bagla" modunda secili
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

  String? _dragId;
  Offset _dragTargetWorld = Offset.zero;
  bool _dragMoved = false;
  bool _longPressed = false;
  Offset _lastScreen = Offset.zero;
  bool _panning = false;
  Timer? _longPressTimer;

  bool _linkMode = false;
  String? _linkFirst;
  String _bondCode = 'friendship';
  Offset? _hoverScreen;

  var _bonds = <BondType>[];
  final _bondColor = <String, Color>{};
  bool _seeded = false;

  int _seedCounter = 0;
  int _knownSig = 0;

  double _radius(String id) {
    final info = _info[id];
    return info?.nodeRadius ?? (info?.kind == 'npc' ? 21.0 : 30.0);
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

  void _reconcile(List<Location> locs, List<Npc> npcs, List<WorldLink> links) {
    final infos = <String, _NodeInfo>{};
    final stored = <String, Offset?>{};
    for (final l in locs) {
      // Local override varsa onu kullan, yoksa DB'den
      final radius = _localNodeRadius[l.id] ?? l.nodeRadius;
      infos[l.id] = _NodeInfo(
        'location',
        l.name,
        l.mapPreviewPath ?? l.mapImagePath,
        nodeRadius: radius,
        revealed: l.revealed,
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
    final locs = <({String id, double x, double y})>[];
    final npcs = <({String id, double x, double y})>[];
    for (final e in _nodes.entries) {
      final rec = (id: e.key, x: e.value.x, y: e.value.y);
      (_info[e.key]?.kind == 'npc' ? npcs : locs).add(rec);
    }
    final repo = ref.read(worldRepositoryProvider);
    await repo.saveGraphPositions(locs);
    await repo.saveNpcGraphPositions(npcs);
  }

  // --- Koordinat ----------------------------------------------------------

  Offset _toWorld(Offset s) =>
      Offset((s.dx - _pan.dx) / _scale, (s.dy - _pan.dy) / _scale);

  String? _hitNode(Offset world) {
    for (final id in _ordered.reversed) {
      final n = _nodes[id]!;
      if ((world - Offset(n.x, n.y)).distance <= _radius(id)) return id;
    }
    return null;
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

    // Sol tık: sürüklemeye başla veya pan
    if (hitId != null) {
      _dragId = hitId;
      _dragMoved = false;
      _dragTargetWorld = world;
      _nodes[hitId]!.pinned = true;
      _longPressTimer?.cancel();
      _longPressTimer = Timer(const Duration(milliseconds: 500), () {
        if (_dragId == hitId && !_dragMoved) {
          _longPressed = true;
          _releaseDrag(persist: false);
          _showNodeMenu(hitId, e.localPosition);
        }
      });
      _wake();
    } else {
      _panning = true;
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    final delta = e.localPosition - _lastScreen;
    _lastScreen = e.localPosition;
    if (_dragId != null) {
      if (!_dragMoved && delta.distance > 3) {
        _dragMoved = true;
        _longPressTimer?.cancel();
      }
      _dragTargetWorld = _toWorld(e.localPosition);
      _wake();
    } else if (_panning) {
      _pan += delta;
      _repaint.value++;
    }
  }

  void _onPointerUp(PointerUpEvent e) {
    _longPressTimer?.cancel();
    if (_longPressed) {
      _longPressed = false;
      _panning = false;
      return;
    }

    if (_dragId != null) {
      final id = _dragId!;
      if (_dragMoved) {
        _releaseDrag(persist: true);
      } else {
        _releaseDrag(persist: false);
        if (_linkMode) _onLinkTapNode(id);
      }
    } else if (_panning) {
      _panning = false;
      if ((e.localPosition - _lastScreen).distance < 3) {
        final world = _toWorld(e.localPosition);
        final edge = _hitEdge(world);
        if (edge != null) {
          _showEdgeMenu(edge, e.position);
        } else if (_linkMode) {
          setState(() => _linkFirst = null);
        }
      }
    }
    _panning = false;
  }

  void _releaseDrag({required bool persist}) {
    final id = _dragId;
    _dragId = null;
    _dragMoved = false;
    if (id == null) return;
    final n = _nodes[id];
    if (n == null) return;
    n.pinned = false;
    if (persist) {
      final repo = ref.read(worldRepositoryProvider);
      if (_info[id]?.kind == 'npc') {
        repo.setNpcGraphPosition(id, n.x, n.y);
      } else {
        repo.setGraphPosition(id, n.x, n.y);
      }
    }
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

  void _onLinkTapNode(String id) {
    if (_linkFirst == null) {
      setState(() => _linkFirst = id);
    } else if (_linkFirst == id) {
      setState(() => _linkFirst = null);
    } else {
      final firstId = _linkFirst!;
      ref
          .read(worldRepositoryProvider)
          .createLink(
            firstId,
            id,
            xKind: _info[firstId]?.kind ?? 'location',
            yKind: _info[id]?.kind ?? 'location',
            type: _bondCode,
          );
      setState(() => _linkFirst = null);
    }
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
        // 1. Yeri aç (LocationPage / NpcDetailPage)
        PopupMenuItem(
          value: 'open',
          child: Row(
            children: [
              Icon(
                kind == 'npc' ? Icons.person_outline : Icons.map_outlined,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(l10n.worldGraphOpenLocation),
            ],
          ),
        ),
        // 2. Oyunculara goster/gizle (sadece location icin)
        //
        // ASIL gorunurluk anahtari bu: `Locations.revealed`. Menude eskiden
        // yalnizca pinleri ceviren bir secenek vardi, yer oyuncularda acik
        // kalmaya devam ediyordu.
        if (kind == 'location')
          PopupMenuItem(
            value: 'toggle_location_revealed',
            child: Row(
              children: [
                Icon(
                  info.revealed
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  info.revealed
                      ? l10n.worldGraphHideFromPlayers
                      : l10n.worldGraphShowToPlayers,
                ),
              ],
            ),
          ),
        // 3. Düğüm boyutu (her iki tip için)
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
              Text(
                kind == 'npc' ? l10n.worldDeleteNpc : l10n.worldDeleteLocation,
                style: const TextStyle(color: Colors.red),
              ),
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
      case 'toggle_location_revealed':
        await _toggleLocationRevealed(id);
        break;
      case 'set_radius':
        await _setNodeRadius(id);
        break;
      case 'delete':
        await _confirmDelete(kind, id);
        break;
    }
  }

  /// Yeri oyunculara acar/kapatir.
  ///
  /// `setRevealed` yer acilirken pinlerini de acar (alt haritaya girildiginde
  /// bos bir harita gorunmesin); kapatirken pinlere dokunmaz, boylece DM'in
  /// tek tek ayarladigi pin gorunurlugu yer yeniden acildiginda kaybolmaz.
  Future<void> _toggleLocationRevealed(String id) async {
    final info = _info[id];
    if (info == null) return;
    await ref.read(worldRepositoryProvider).setRevealed(id, !info.revealed);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          info.revealed
              ? L10n.of(context).worldGraphHiddenNotice(info.name)
              : L10n.of(context).worldGraphShownNotice(info.name),
        ),
      ),
    );
  }

  /// Düğüm (küre) boyutunu ayarlama dialogu.
  Future<void> _setNodeRadius(String id) async {
    final repo = ref.read(worldRepositoryProvider);
    final info = _info[id];
    if (info == null || !mounted) return;

    final kind = info.kind;
    final currentRadius = info.nodeRadius ?? (kind == 'npc' ? 21.0 : 30.0);
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
      if (kind == 'npc') {
        await repo.updateNpc(id, nodeRadius: result);
      } else {
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
        revealed: info.revealed,
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
      if (kind == 'npc') {
        await repo.deleteNpc(id);
      } else {
        await repo.deleteLocation(id);
      }
    }
  }

  void _openNode(String id) {
    final kind = _info[id]?.kind;
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => kind == 'npc'
            ? NpcDetailPage(npcId: id)
            : LocationPage(locationId: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final locs = ref.watch(allLocationsProvider).value ?? const [];
    final npcs = ref.watch(npcsProvider).value ?? const [];
    final links = ref.watch(worldLinksProvider).value ?? const [];
    _reconcile(locs, npcs, links);

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
          FilterChip(
            avatar: const Icon(Icons.hub_outlined, size: 18),
            label: Text(l10n.worldGraphConnect),
            selected: _linkMode,
            onSelected: (v) => setState(() {
              _linkMode = v;
              _linkFirst = null;
            }),
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
      final isNpc = info?.kind == 'npc';
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
        if (isNpc) {
          _paintPersonGlyph(canvas, c, r);
        } else {
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
