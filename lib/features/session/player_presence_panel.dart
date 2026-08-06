import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../net/protocol.dart' show PlayerPresence;
import 'session_page.dart';

/// DM ekraninda sag altta duran, acilir kapanir oyuncu varlik paneli. Her
/// oyuncu icin durumu gosterir: aktif (yesil), arka planda (sari), cevrimdisi
/// (gri + son gorulme). Panel [connectedPlayersProvider]'i izler; kapaliyken
/// sadece kucuk bir dugme + cevrimici sayisi rozeti.
///
/// **Kendi [Positioned]'ini dondurur** — dogrudan bir [Stack] icine konmali.
/// Sabit sag-alt kosede duruyordu ve orada duran dugmeleri (FAB, sayfa
/// eylemleri) kapatiyordu; artik basili tutup surukleyerek tasinabiliyor.
/// Konum yalnizca bellekte tutulur: oturum icinde yeterli, kalici ayar
/// yapmak icin sebep yok.
class PlayerPresencePanel extends ConsumerStatefulWidget {
  const PlayerPresencePanel({super.key});

  @override
  ConsumerState<PlayerPresencePanel> createState() =>
      _PlayerPresencePanelState();
}

class _PlayerPresencePanelState extends ConsumerState<PlayerPresencePanel> {
  static const _margin = 8.0;
  static const _defaultInset = 16.0;

  /// Kapali dugmenin sabit olcusu; konum hesabi buna gore yapiliyor.
  static const _buttonSize = Size(48, 48);

  /// Acik kartin genisligi (asagida `SizedBox`'ta da ayni deger).
  static const _cardWidth = 260.0;

  bool _open = false;

  /// **Kapali dugmenin** sol-ust kosesi; `null` = hic tasinmadi (sag-alt).
  ///
  /// Kart acilinca bu deger DEGISMEZ: panel her zaman dugmenin bulundugu
  /// yerden buyur ve kapaninca dugme tam olarak birakildigi yere doner.
  /// (Onceden acilista konum "sigsin diye" sola cekiliyor, kapaninca da orada
  /// kaliyordu — panel her acis-kapaniste kayiyordu.)
  Offset? _pos;

  /// Basili tutmanin basladigi andaki dugme kosesi (surukleme referansi).
  Offset _dragOrigin = Offset.zero;

  Size _screen = Size.zero;

  /// Kapali dugmenin o anki (ekrana sigdirilmis) sol-ust kosesi.
  Offset get _buttonTopLeft {
    final p =
        _pos ??
        Offset(
          _screen.width - _defaultInset - _buttonSize.width,
          _screen.height - _defaultInset - _buttonSize.height,
        );
    // Pencere kucultulunce ekran disinda kalmasin. Sigdirma yalnizca
    // GORUNTULEME icin: `_pos` kullanicinin biraktigi degerde kalir, pencere
    // tekrar buyuyunce panel eski yerine geri doner.
    final maxX = (_screen.width - _buttonSize.width - _margin).clamp(
      _margin,
      double.infinity,
    );
    final maxY = (_screen.height - _buttonSize.height - _margin).clamp(
      _margin,
      double.infinity,
    );
    return Offset(p.dx.clamp(_margin, maxX), p.dy.clamp(_margin, maxY));
  }

  void _onDragStart(LongPressStartDetails _) {
    _dragOrigin = _buttonTopLeft;
    setState(() => _pos = _dragOrigin);
  }

  void _onDragUpdate(LongPressMoveUpdateDetails d) {
    setState(() => _pos = _dragOrigin + d.offsetFromOrigin);
  }

  void _setOpen(bool open) => setState(() => _open = open);

  @override
  Widget build(BuildContext context) {
    _screen = MediaQuery.sizeOf(context);
    final anchor = _buttonTopLeft;
    final child = GestureDetector(
      onLongPressStart: _onDragStart,
      onLongPressMoveUpdate: _onDragUpdate,
      child: _panel(context),
    );

    if (!_open) {
      return Positioned(left: anchor.dx, top: anchor.dy, child: child);
    }

    // Acikken kart dugmenin SAG-ALT kosesine sabitlenir ve sola/yukari dogru
    // buyur; boylece sag kenardaki panel disari tasmaz, dugme de yerinden
    // oynamis gibi gorunmez.
    final right = (_screen.width - anchor.dx - _buttonSize.width).clamp(
      _margin,
      (_screen.width - _cardWidth - _margin).clamp(_margin, double.infinity),
    );
    final bottom = (_screen.height - anchor.dy - _buttonSize.height).clamp(
      _margin,
      double.infinity,
    );
    return Positioned(
      right: right.toDouble(),
      bottom: bottom.toDouble(),
      // Yukari dogru buyuyen kart ekranin ustunden tasmasin.
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: (_screen.height - bottom - _margin).clamp(
            120.0,
            double.infinity,
          ),
        ),
        child: child,
      ),
    );
  }

  Widget _panel(BuildContext context) {
    final players = ref.watch(connectedPlayersProvider).value ?? const [];
    final onlineCount = players.where((p) => p.online).length;
    final l = L10n.of(context);

    if (!_open) {
      // Kapali: yuvarlak dugme + cevrimici rozeti. InkWell'in dogru bir
      // Material uzerinde ve daire sekliyle sinirli olmasi gerekir; yoksa
      // tiklamada dikdortgen gri bir ripple beliriyor.
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: Colors.transparent,
            // triggerMode.manual ZORUNLU: Tooltip varsayilan olarak uzun
            // basmayla acilir ve jest arenasinda surukleme jestini yiyor
            // (fare ustune gelince gosterme bundan etkilenmez).
            child: Tooltip(
              message: l.presenceDragHint,
              triggerMode: TooltipTriggerMode.manual,
              child: InkWell(
                onTap: () => _setOpen(true),
                customBorder: const CircleBorder(),
                child: Ink(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2E2E2E),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.people_outline, color: Colors.white),
                ),
              ),
            ),
          ),
          if (onlineCount > 0)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  '$onlineCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    // Acik: temali kart (oyunun diger kartlariyla tutarli).
    return Card(
      elevation: 4,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: _cardWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: Tooltip(
                message: l.presenceDragHint,
                triggerMode: TooltipTriggerMode.manual,
                child: const Icon(Icons.drag_indicator),
              ),
              title: Text(
                l.presenceTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              trailing: IconButton(
                tooltip: l.close,
                icon: const Icon(Icons.close),
                onPressed: () => _setOpen(false),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: players.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        l.presenceNoPlayers,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final p in players) _PlayerRow(view: p, l10n: l),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tek oyuncunun durum satiri: renkli nokta + ad + durum metni.
class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.view, required this.l10n});

  final ConnectedPlayerView view;
  final L10n l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Durum: online+active = yesil, online+away = sari, degilse gri.
    final Color dot;
    final String status;
    if (view.online && view.presence == PlayerPresence.active) {
      dot = const Color(0xFF2E7D32);
      status = l10n.presenceActive;
    } else if (view.online) {
      dot = const Color(0xFFF9A825);
      status = l10n.presenceAway;
    } else {
      dot = theme.colorScheme.outline;
      status = view.lastSeen == null
          ? l10n.presenceOffline
          : '${l10n.presenceOffline} · ${_lastSeen(l10n, view.lastSeen!)}';
    }

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
      ),
      title: Text(view.name, style: theme.textTheme.bodyMedium),
      subtitle: Text(
        status,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
    );
  }

  /// Son gorulme zamani icin kisa goreli metin.
  String _lastSeen(L10n l10n, DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inSeconds < 60) {
      return l10n.lastSeenSeconds(diff.inSeconds < 1 ? 1 : diff.inSeconds);
    }
    if (diff.inMinutes < 60) return l10n.lastSeenMinutes(diff.inMinutes);
    return l10n.lastSeenHours(diff.inHours);
  }
}
