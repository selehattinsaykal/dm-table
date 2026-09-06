import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';

/// Sirasi gelen oyuncu icin gorunur bir sayac.
///
/// **Neden var:** "herkes bir dakikada karar versin" masanin temposunu en
/// cok degistiren tek kural, ama sozle soylendiginde kimse takip etmiyor.
///
/// Sayac HICBIR SEYI ZORLAMIYOR: sure dolunca yalnizca kirmiziya donuyor,
/// tur otomatik gecmiyor. Otomatik gecen bir sayac, dusunen oyuncunun
/// turunu elinden alirdi -- karari DM veriyor.
class TurnTimerState {
  const TurnTimerState({
    this.limitSeconds,
    this.elapsed = 0,
    this.running = false,
  });

  /// Sinir (saniye); null = sayac kapali.
  final int? limitSeconds;
  final int elapsed;
  final bool running;

  bool get expired => limitSeconds != null && elapsed >= limitSeconds!;

  /// 0..1 arasi ilerleme; sinir yoksa 0.
  double get progress {
    final limit = limitSeconds;
    if (limit == null || limit <= 0) return 0;
    final value = elapsed / limit;
    return value > 1 ? 1 : value;
  }

  TurnTimerState copyWith({
    int? limitSeconds,
    int? elapsed,
    bool? running,
    bool clearLimit = false,
  }) => TurnTimerState(
    limitSeconds: clearLimit ? null : (limitSeconds ?? this.limitSeconds),
    elapsed: elapsed ?? this.elapsed,
    running: running ?? this.running,
  );
}

/// Tur sayacini suren denetleyici.
///
/// Sayac UYGULAMA DURUMUNDA yasiyor, sayfa durumunda degil: DM savas
/// ekranindan cikip haritaya gecince sayacin sifirlanmasi masada yanlis
/// olurdu.
class TurnTimer extends Notifier<TurnTimerState> {
  Timer? _ticker;

  @override
  TurnTimerState build() {
    ref.onDispose(() => _ticker?.cancel());
    return const TurnTimerState();
  }

  /// Sinir (saniye); null sayaci kapatir.
  void setLimit(int? seconds) {
    if (seconds == null) {
      _ticker?.cancel();
      state = const TurnTimerState();
      return;
    }
    state = state.copyWith(limitSeconds: seconds, elapsed: 0);
  }

  /// Yeni tur: sayaci sifirlayip yeniden baslatir.
  void restart() {
    if (state.limitSeconds == null) return;
    state = state.copyWith(elapsed: 0, running: true);
    _start();
  }

  void pause() {
    _ticker?.cancel();
    _ticker = null;
    state = state.copyWith(running: false);
  }

  void resume() {
    if (state.limitSeconds == null || state.running) return;
    state = state.copyWith(running: true);
    _start();
  }

  void stop() {
    _ticker?.cancel();
    _ticker = null;
    state = state.copyWith(elapsed: 0, running: false);
  }

  void _start() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!state.running) return;
      state = state.copyWith(elapsed: state.elapsed + 1);
    });
  }
}

final turnTimerProvider = NotifierProvider<TurnTimer, TurnTimerState>(
  TurnTimer.new,
);

/// Tur cubugundaki sayac gostergesi.
///
/// [limitSeconds] KARSILASMADAN geliyor; gosterge onu denetleyiciyle
/// esitlemekten de sorumlu. Esitleme burada duruyor cunku sinir kalici
/// (veritabani), sayacin kendisi ise oturumluk (uygulama durumu) -- ikisini
/// birbirine baglayan tek nokta bu.
class TurnTimerIndicator extends ConsumerStatefulWidget {
  const TurnTimerIndicator({this.limitSeconds, super.key});

  final int? limitSeconds;

  @override
  ConsumerState<TurnTimerIndicator> createState() => _TurnTimerIndicatorState();
}

class _TurnTimerIndicatorState extends ConsumerState<TurnTimerIndicator> {
  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(TurnTimerIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.limitSeconds != widget.limitSeconds) _sync();
  }

  /// Denetleyiciyi karsilasmadaki sinira ayarlar.
  ///
  /// Cizim sirasinda durum degistirilemedigi icin kare sonuna birakiliyor.
  void _sync() {
    final limit = widget.limitSeconds;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(turnTimerProvider).limitSeconds == limit) return;
      ref.read(turnTimerProvider.notifier).setLimit(limit);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(turnTimerProvider);
    final controller = ref.read(turnTimerProvider.notifier);
    final theme = Theme.of(context);
    if (state.limitSeconds == null) return const SizedBox.shrink();

    final left = state.limitSeconds! - state.elapsed;
    final color = state.expired
        ? theme.colorScheme.error
        : (state.progress > 0.75
              ? theme.colorScheme.tertiary
              : theme.colorScheme.primary);

    return Semantics(
      // Ekran okuyucu icin: "kalan sure 23 saniye".
      label: '${left < 0 ? 0 : left} sn',
      child: Tooltip(
        message: '${state.limitSeconds} sn',
        child: InkWell(
          onTap: state.running ? controller.pause : controller.resume,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    value: state.progress,
                    strokeWidth: 3,
                    color: color,
                    backgroundColor: theme.colorScheme.outlineVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  state.expired
                      ? L10n.of(context).turnTimerUp
                      : '${left < 0 ? 0 : left}',
                  style: theme.textTheme.titleSmall?.copyWith(color: color),
                ),
                if (!state.running)
                  Icon(Icons.pause, size: 14, color: theme.colorScheme.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
