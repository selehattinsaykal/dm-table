import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/codex/codex_style.dart';
import '../../l10n/app_localizations.dart';
import 'codex_style_ui.dart';

/// Sure sayaci blogunun govdesi: gercek zamanli geri sayim ya da kronometre.
///
/// Masadaki kullanimi: tur suresi ("30 saniyen var"), mesalenin yanma suresi,
/// bulmaca/kacis sayaci, mola sayaci.
///
/// Gecen sure her saniye KAYDEDILMEZ — yalnizca baslat/duraklat/sifirla gibi
/// kullanici eylemlerinde ve sure dolunca yazilir (bkz. [CodexTimer]). Ekrandaki
/// rakam yerel bir tikla tazelenir.
class CodexTimerView extends StatefulWidget {
  const CodexTimerView({
    required this.title,
    required this.timer,
    required this.interactive,
    required this.onChanged,
    this.tone = CodexTone.neutral,
    super.key,
  });

  final String title;
  final CodexTimer timer;

  /// Duzenleme modunda dugmeler kilitlidir (yerlesim ayarlarken sayac
  /// yanlislikla baslatilmasin).
  final bool interactive;

  /// Kalici olmasi gereken durum degisiklikleri (baslat/duraklat/sifirla/bitis).
  final ValueChanged<CodexTimer> onChanged;

  final CodexTone tone;

  @override
  State<CodexTimerView> createState() => _CodexTimerViewState();
}

class _CodexTimerViewState extends State<CodexTimerView> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(CodexTimerView old) {
    super.didUpdateWidget(old);
    if (old.timer.isRunning != widget.timer.isRunning) _syncTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Yalnizca calisirken tik kurulur; duran sayac kare harcamaz.
  void _syncTicker() {
    _ticker?.cancel();
    _ticker = widget.timer.isRunning
        ? Timer.periodic(const Duration(milliseconds: 500), (_) => _onTick())
        : null;
  }

  /// Tik yalnizca ekrandaki rakami tazeler.
  ///
  /// Sayacin BITISINI bu widget islemez — onu `CodexTimerAlerts` yapar;
  /// boylece blok gorunur olsun olmasin uyari tek bir yerden uretilir
  /// (iki sahip olsaydi sayfa acikken ses iki kez calardi).
  void _onTick() {
    if (!mounted) return;
    if (widget.timer.isFinishedAt(DateTime.now())) {
      _ticker?.cancel();
      _ticker = null;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final tone = codexToneColors(context, widget.tone);
    final timer = widget.timer;
    final now = DateTime.now();
    final finished = timer.isFinishedAt(now);
    final shown = timer.mode == CodexTimerMode.countdown
        ? timer.remainingAt(now)
        : timer.elapsedAt(now);

    // Bitmis geri sayim kirmizi; digerlerinde ton (yoksa birincil) rengi.
    final accent = finished
        ? theme.colorScheme.error
        : (widget.tone == CodexTone.neutral
              ? theme.colorScheme.primary
              : tone.accent);

    final digits = Text(
      formatCodexDuration(shown),
      style: theme.textTheme.displaySmall?.copyWith(
        color: accent,
        fontFeatures: const [FontFeature.tabularFigures()],
        letterSpacing: 1,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(widget.title, style: theme.textTheme.titleSmall),
          ),
        Row(
          children: [
            switch (timer.style) {
              CodexTimerStyle.digits => digits,
              CodexTimerStyle.bar => Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    digits,
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: timer.progressAt(now),
                        minHeight: 7,
                        color: accent,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
              ),
              CodexTimerStyle.ring => SizedBox(
                width: 108,
                height: 108,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: timer.progressAt(now),
                        strokeWidth: 7,
                        color: accent,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    FittedBox(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: digits,
                      ),
                    ),
                  ],
                ),
              ),
            },
            const SizedBox(width: 12),
            if (timer.style != CodexTimerStyle.bar) const Spacer(),
            _TimerControls(
              timer: timer,
              interactive: widget.interactive,
              onStart: () =>
                  widget.onChanged(timer.startedAtTime(DateTime.now())),
              onPause: () => widget.onChanged(timer.pausedAt(DateTime.now())),
              onReset: () => widget.onChanged(timer.reset),
              onBump: (delta) => widget.onChanged(
                timer.copyWith(duration: timer.duration + delta),
              ),
            ),
          ],
        ),
        if (finished)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.codexTimerDone,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}

class _TimerControls extends StatelessWidget {
  const _TimerControls({
    required this.timer,
    required this.interactive,
    required this.onStart,
    required this.onPause,
    required this.onReset,
    required this.onBump,
  });

  final CodexTimer timer;
  final bool interactive;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onReset;
  final ValueChanged<Duration> onBump;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Wrap(
      spacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        IconButton.filledTonal(
          tooltip: timer.isRunning
              ? l10n.codexTimerPause
              : l10n.codexTimerStart,
          icon: Icon(timer.isRunning ? Icons.pause : Icons.play_arrow),
          onPressed: interactive ? (timer.isRunning ? onPause : onStart) : null,
        ),
        IconButton(
          tooltip: l10n.codexTimerReset,
          icon: const Icon(Icons.replay),
          onPressed: interactive ? onReset : null,
        ),
        // Geri sayimda masada en cok gereken sey: "bir dakika daha ver".
        if (timer.mode == CodexTimerMode.countdown)
          IconButton(
            tooltip: l10n.codexTimerAddMinute,
            icon: const Icon(Icons.more_time),
            onPressed: interactive
                ? () => onBump(const Duration(minutes: 1))
                : null,
          ),
      ],
    );
  }
}

/// Sure secimi: dakika/saniye alanlari + sik kullanilan on ayarlar.
class CodexDurationField extends StatelessWidget {
  const CodexDurationField({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final Duration value;
  final ValueChanged<Duration> onChanged;

  static const _presets = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 10),
    Duration(minutes: 30),
    Duration(hours: 1),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _NumberField(
                label: l10n.codexTimerMinutes,
                value: value.inMinutes,
                max: 1440,
                onChanged: (minutes) => onChanged(
                  Duration(
                    minutes: minutes,
                    seconds: value.inSeconds.remainder(60),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _NumberField(
                label: l10n.codexTimerSeconds,
                value: value.inSeconds.remainder(60),
                max: 59,
                onChanged: (seconds) => onChanged(
                  Duration(minutes: value.inMinutes, seconds: seconds),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final preset in _presets)
              ChoiceChip(
                label: Text(formatCodexDuration(preset)),
                selected: preset == value,
                onSelected: (_) => onChanged(preset),
              ),
          ],
        ),
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => TextFormField(
    initialValue: '$value',
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: InputDecoration(
      labelText: label,
      isDense: true,
      border: const OutlineInputBorder(),
    ),
    onChanged: (v) => onChanged(math.min(int.tryParse(v.trim()) ?? 0, max)),
  );
}
