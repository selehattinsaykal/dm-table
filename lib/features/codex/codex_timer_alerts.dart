import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/codex_repository.dart';
import '../../data/db/database.dart';
import '../../domain/codex/codex_block.dart';
import '../../domain/codex/codex_style.dart';
import '../../l10n/app_localizations.dart';
import 'codex_page.dart';
import 'codex_providers.dart';

/// Dolan bir sure sayacinin bildirimi.
class CodexTimerAlert {
  const CodexTimerAlert({
    required this.blockId,
    required this.pageId,
    required this.title,
  });

  final String blockId;

  /// Uyaridan sayfaya gidebilmek icin.
  final String pageId;

  /// Sayacin basligi; bos olabilir.
  final String title;
}

/// Calisan sure sayaclarini uygulama genelinde izler.
///
/// Neden blogun kendi widget'i yetmiyor: sayac bloğu yalnizca o Kayitlar
/// sayfasi acikken agacta durur. DM savas ekranindayken tur suresi dolarsa
/// kimse haber vermezdi. Bu servis kabuğun altinda yasar ve hangi ekranda
/// olunursa olunsun uyariyi uretir.
///
/// Saniyede bir yoklama YAPMAZ: her calisan geri sayim icin kalan sureye
/// tam bir `Timer` kurar. Blok verisi degistiginde (baslat/duraklat/sifirla)
/// akis yeni bir olay verir ve zamanlayicilar yeniden kurulur.
class CodexTimerAlerts {
  CodexTimerAlerts(this._repo);

  final CodexRepository _repo;

  /// Bu kadar once dolmus bir sayac icin uyari verilmez (yalnizca durumu
  /// duzeltilir). Uygulama uc gun kapali kaldiysa acilista "sure doldu"
  /// demek gurultuden ibarettir.
  static const staleAfter = Duration(minutes: 5);

  final _pending = <String, Timer>{};
  final _controller = StreamController<CodexTimerAlert>.broadcast();
  StreamSubscription<List<CodexBlock>>? _subscription;

  Stream<CodexTimerAlert> get alerts => _controller.stream;

  void start() {
    _subscription ??= _repo
        .watchBlocksOfType(CodexBlockType.timer)
        .listen(_reschedule);
  }

  Future<void> dispose() async {
    for (final timer in _pending.values) {
      timer.cancel();
    }
    _pending.clear();
    await _subscription?.cancel();
    await _controller.close();
  }

  void _reschedule(List<CodexBlock> blocks) {
    final running = <String>{};
    final now = DateTime.now();

    for (final block in blocks) {
      final timer = CodexTimer.fromJson(_dataOf(block));
      // Kronometrenin bitisi yok; yalnizca geri sayim uyarir.
      if (!timer.isRunning || timer.mode != CodexTimerMode.countdown) continue;
      running.add(block.id);

      final remaining = timer.remainingAt(now);
      _pending.remove(block.id)?.cancel();
      _pending[block.id] = Timer(
        remaining.isNegative ? Duration.zero : remaining,
        () => _fire(block.id),
      );
    }

    // Durdurulan/silinen sayaclarin bekleyen zamanlayicilari birakilir.
    for (final id in _pending.keys.toList()) {
      if (!running.contains(id)) _pending.remove(id)?.cancel();
    }
  }

  Future<void> _fire(String blockId) async {
    _pending.remove(blockId);
    final block = await _repo.block(blockId);
    if (block == null || _controller.isClosed) return;

    final data = _dataOf(block);
    final timer = CodexTimer.fromJson(data);
    final now = DateTime.now();
    // Zamanlayici kurulduktan sonra durum degismis olabilir (duraklatildi,
    // sifirlandi, suresi uzatildi).
    if (!timer.isRunning || !timer.isFinishedAt(now)) return;

    // Bitis durumu HER halukarda yazilir: sayfa acildiginda sayacin dolmus
    // (ya da donguyse yeniden baslamis) gorunmesi gerekir.
    final overdue = timer.overdueAt(now);
    await _repo.updateBlock(blockId, {
      ...data,
      ...timer.finishedAt(now).toJson(),
    });

    if (timer.alarm && overdue <= staleAfter && !_controller.isClosed) {
      _controller.add(
        CodexTimerAlert(
          blockId: blockId,
          pageId: block.pageId,
          title: '${data['title'] ?? ''}'.trim(),
        ),
      );
    }
  }

  Map<String, dynamic> _dataOf(CodexBlock block) =>
      (jsonDecode(block.dataJson) as Map).cast<String, dynamic>();
}

/// Uygulama acik oldugu surece yasar; kabuk tarafindan dinlenir.
final codexTimerAlertsProvider = Provider<CodexTimerAlerts>((ref) {
  final service = CodexTimerAlerts(ref.watch(codexRepositoryProvider))..start();
  ref.onDispose(service.dispose);
  return service;
});

final codexTimerAlertStreamProvider = StreamProvider<CodexTimerAlert>(
  (ref) => ref.watch(codexTimerAlertsProvider).alerts,
);

/// Dolan sayaci duyurur: ses + her ekranda gorunen bir bildirim.
///
/// `MaterialApp`'in ICINDE kurulmalidir (`builder:` icinde) — hem [L10n] hem
/// `ScaffoldMessenger` oradan cozulur. Uygulamanin kokune (MaterialApp'in
/// USTUNE) konursa `Localizations` bulunamaz ve bildirim hic gorunmez.
class CodexTimerAlertListener extends ConsumerWidget {
  const CodexTimerAlertListener({
    required this.navigatorKey,
    required this.child,
    super.key,
  });

  /// Bildirimden sayfaya gitmek icin; `builder:` context'i Navigator'in
  /// USTUNDE oldugu icin `Navigator.of` burada calismaz.
  final GlobalKey<NavigatorState> navigatorKey;

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(codexTimerAlertStreamProvider, (_, next) {
      final alert = next.value;
      if (alert == null || !context.mounted) return;
      _announce(context, alert);
    });
    return child;
  }

  void _announce(BuildContext context, CodexTimerAlert alert) {
    final l10n = L10n.of(context);
    SystemSound.play(SystemSoundType.alert);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text(
            alert.title.isEmpty
                ? l10n.codexTimerDone
                : l10n.codexTimerFinished(alert.title),
          ),
          action: SnackBarAction(
            label: l10n.codexTimerOpen,
            onPressed: () {
              final navigator = navigatorKey.currentContext;
              if (navigator != null) openCodexPage(navigator, alert.pageId);
            },
          ),
        ),
      );
  }
}
