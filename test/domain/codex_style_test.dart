import 'package:dm_table/domain/codex/codex_style.dart';
import 'package:flutter_test/flutter_test.dart';

/// Blok yerlesim/gorunum jetonlari. Bu alanlar semasiz JSON'da tasindigi icin
/// asil risk ESKI KAYITLAR: alan yokken varsayilanlarin eski davranisi
/// (tam genislik, sola yasli, otomatik yukseklik) vermesi sart.
void main() {
  group('CodexLayout', () {
    test('bos veri eski davranisa duser', () {
      const empty = <String, dynamic>{};
      final layout = CodexLayout.fromData(empty);

      expect(layout.width, 1.0);
      expect(layout.align, CodexAlign.left);
      expect(layout.height, isNull);
      expect(layout.isFullWidth, isTrue);
    });

    test('genislik sinirlanir, bilinmeyen hizalama sola duser', () {
      final tooWide = CodexLayout.fromData({'width': 4.2, 'align': 'ortala'});
      final tooNarrow = CodexLayout.fromData({'width': 0.01});

      expect(tooWide.width, 1.0);
      expect(tooWide.align, CodexAlign.left);
      expect(tooNarrow.width, CodexLayout.minWidth);
    });

    test('yukseklik sinirlanir', () {
      expect(
        CodexLayout.fromData({'height': 10}).height,
        CodexLayout.minHeight,
      );
      expect(
        CodexLayout.fromData({'height': 99999}).height,
        CodexLayout.maxHeight,
      );
    });

    test('toData/fromData gidis-donusu degeri korur', () {
      const layout = CodexLayout(
        width: 0.5,
        align: CodexAlign.center,
        height: 320,
      );

      expect(CodexLayout.fromData(layout.toData()), layout);
    });

    test('toData yalnizca yerlesim alanlarini yazar', () {
      const auto = CodexLayout(width: 0.5, align: CodexAlign.right);

      expect(auto.toData().keys, containsAll(<String>['width', 'align']));
      expect(auto.toData().containsKey('height'), isFalse);
    });

    test('copyWith yuksekligi temizleyebilir', () {
      const layout = CodexLayout(height: 300);

      expect(layout.copyWith(clearHeight: true).height, isNull);
      expect(layout.copyWith(height: 500).height, 500);
      // height verilmezse korunur (yanlislikla sifirlanmasin).
      expect(layout.copyWith(width: 0.4).height, 300);
    });
  });

  group('CodexCounter', () {
    test('sinirlar deger degisimini kisitlar', () {
      const counter = CodexCounter(label: 'Meşale', value: 2, min: 0, max: 5);

      expect(counter.bumped(-1).value, 1);
      expect(counter.withValue(-9).value, 0);
      expect(counter.withValue(99).value, 5);
    });

    test('adim birden buyuk olabilir', () {
      const counter = CodexCounter(label: 'Ok', value: 10, step: 5);

      expect(counter.bumped(1).value, 15);
      expect(counter.bumped(-1).value, 5);
    });

    test('oran yalnizca ust sinir varken hesaplanir', () {
      const bounded = CodexCounter(label: 'Su', value: 5, min: 0, max: 10);
      const unbounded = CodexCounter(label: 'Gün', value: 5);

      expect(bounded.ratio, 0.5);
      expect(unbounded.ratio, isNull);
    });

    test('json gidis-donusu alanlari korur', () {
      const counter = CodexCounter(
        label: 'Erzak',
        value: 3,
        min: 0,
        max: 9,
        step: 2,
        icon: '🍖',
      );
      final back = CodexCounter.fromJson(counter.toJson());

      expect(back.label, 'Erzak');
      expect(back.value, 3);
      expect(back.min, 0);
      expect(back.max, 9);
      expect(back.step, 2);
      expect(back.icon, '🍖');
    });

    test('bos simge null olur (bos rozet cizilmesin)', () {
      expect(CodexCounter.fromJson({'label': 'a', 'icon': '  '}).icon, isNull);
    });
  });

  group('CodexTimer', () {
    final t0 = DateTime(2026, 8, 19, 21);

    test('duran sayacta gecen sure birikimden ibaret', () {
      const timer = CodexTimer(accumulated: Duration(seconds: 40));

      expect(timer.isRunning, isFalse);
      expect(timer.elapsedAt(t0), const Duration(seconds: 40));
      // Duran sayac saat ilerleyince de artmaz.
      expect(
        timer.elapsedAt(t0.add(const Duration(minutes: 3))),
        const Duration(seconds: 40),
      );
    });

    test('calisan sayac baslama anindan itibaren sayar', () {
      final timer = const CodexTimer(
        duration: Duration(minutes: 5),
      ).startedAtTime(t0);

      expect(timer.isRunning, isTrue);
      expect(
        timer.elapsedAt(t0.add(const Duration(seconds: 30))),
        const Duration(seconds: 30),
      );
      expect(
        timer.remainingAt(t0.add(const Duration(seconds: 30))),
        const Duration(minutes: 4, seconds: 30),
      );
    });

    test('duraklatinca gecen sure birikime yazilir ve durur', () {
      final paused = const CodexTimer()
          .startedAtTime(t0)
          .pausedAt(t0.add(const Duration(seconds: 20)));

      expect(paused.isRunning, isFalse);
      expect(paused.accumulated, const Duration(seconds: 20));
      // Duraklatildiktan sonra gecen gercek zaman sayilmaz.
      expect(
        paused.elapsedAt(t0.add(const Duration(minutes: 10))),
        const Duration(seconds: 20),
      );
    });

    test('duraklat/devam et birikerek toplanir', () {
      final first = const CodexTimer()
          .startedAtTime(t0)
          .pausedAt(t0.add(const Duration(seconds: 20)));
      final second = first
          .startedAtTime(t0.add(const Duration(minutes: 5)))
          .pausedAt(t0.add(const Duration(minutes: 5, seconds: 10)));

      expect(second.accumulated, const Duration(seconds: 30));
    });

    test('geri sayim hedefte durur, kronometre surer', () {
      final countdown = const CodexTimer(
        duration: Duration(seconds: 10),
      ).startedAtTime(t0);
      final stopwatch = const CodexTimer(
        mode: CodexTimerMode.stopwatch,
        duration: Duration(seconds: 10),
      ).startedAtTime(t0);
      final later = t0.add(const Duration(seconds: 45));

      expect(countdown.elapsedAt(later), const Duration(seconds: 10));
      expect(countdown.remainingAt(later), Duration.zero);
      expect(countdown.isFinishedAt(later), isTrue);
      expect(stopwatch.elapsedAt(later), const Duration(seconds: 45));
      expect(stopwatch.isFinishedAt(later), isFalse);
    });

    test('doluluk geri sayimda azalir, kronometrede artar', () {
      final half = t0.add(const Duration(seconds: 5));
      final countdown = const CodexTimer(
        duration: Duration(seconds: 10),
      ).startedAtTime(t0);
      final stopwatch = const CodexTimer(
        mode: CodexTimerMode.stopwatch,
        duration: Duration(seconds: 10),
      ).startedAtTime(t0);

      expect(countdown.progressAt(half), closeTo(0.5, 0.01));
      expect(stopwatch.progressAt(half), closeTo(0.5, 0.01));
      expect(countdown.progressAt(t0.add(const Duration(minutes: 1))), 0);
    });

    test('bitince: dongu bastan baslar, degilse durur', () {
      final base = const CodexTimer(
        duration: Duration(seconds: 10),
      ).startedAtTime(t0);
      final end = t0.add(const Duration(seconds: 10));

      final stopped = base.finishedAt(end);
      expect(stopped.isRunning, isFalse);
      expect(stopped.elapsedAt(end), const Duration(seconds: 10));

      final looped = base.copyWith(loop: true).finishedAt(end);
      expect(looped.isRunning, isTrue);
      expect(looped.elapsedAt(end), Duration.zero);
    });

    test('gecikme kirpilmaz (ekrandaki kalan sure kirpilsa da)', () {
      // Uygulama kapaliyken dolmus bir sayaci acilista duyurmamak icin
      // hedefin ne kadar once gectigini bilmek gerekiyor; elapsedAt bunu
      // veremez cunku ekranda "-00:12" gostermemek adina hedefte durur.
      final timer = const CodexTimer(
        duration: Duration(minutes: 1),
      ).startedAtTime(t0);
      final late = t0.add(const Duration(hours: 1));

      expect(timer.elapsedAt(late), const Duration(minutes: 1));
      expect(timer.overdueAt(late), const Duration(minutes: 59));
      // Henuz dolmadiysa gecikme yok.
      expect(
        timer.overdueAt(t0.add(const Duration(seconds: 10))),
        Duration.zero,
      );
      // Kronometrenin hedefi yok.
      expect(
        timer.copyWith(mode: CodexTimerMode.stopwatch).overdueAt(late),
        Duration.zero,
      );
    });

    test('sifirlama birikimi ve calisma durumunu temizler', () {
      final reset = const CodexTimer().startedAtTime(t0).reset;

      expect(reset.isRunning, isFalse);
      expect(reset.accumulated, Duration.zero);
    });

    test('sure sinirlanir', () {
      expect(
        const CodexTimer().copyWith(duration: Duration.zero).duration,
        CodexTimer.minDuration,
      );
      expect(
        const CodexTimer().copyWith(duration: const Duration(days: 7)).duration,
        CodexTimer.maxDuration,
      );
    });

    test('json gidis-donusu calisma durumunu korur', () {
      final running = const CodexTimer(
        mode: CodexTimerMode.stopwatch,
        duration: Duration(minutes: 2),
        accumulated: Duration(seconds: 7),
        style: CodexTimerStyle.ring,
        alarm: false,
        loop: true,
      ).startedAtTime(t0);
      final back = CodexTimer.fromJson(running.toJson());

      expect(back.mode, CodexTimerMode.stopwatch);
      expect(back.duration, const Duration(minutes: 2));
      expect(back.accumulated, const Duration(seconds: 7));
      expect(back.startedAt, t0);
      expect(back.style, CodexTimerStyle.ring);
      expect(back.alarm, isFalse);
      expect(back.loop, isTrue);
    });

    test('durmus sayacta startedAt ACIKCA null yazilir', () {
      // Blok verisi yayilarak guncelleniyor; alan atlanirsa duraklatilan
      // sayac eski baslama aniyla kendi kendine islemeye devam ederdi.
      final paused = const CodexTimer().startedAtTime(t0).pausedAt(t0);

      expect(paused.toJson().containsKey('startedAt'), isTrue);
      expect(paused.toJson()['startedAt'], isNull);
    });

    test('bilinmeyen alanlar varsayilana duser', () {
      final timer = CodexTimer.fromJson({'mode': 'yok', 'style': 'yok'});

      expect(timer.mode, CodexTimerMode.countdown);
      expect(timer.style, CodexTimerStyle.digits);
      expect(timer.duration, const Duration(minutes: 5));
    });
  });

  group('sure bicimlendirme', () {
    test('saat gerekmedikce dakika:saniye', () {
      expect(formatCodexDuration(const Duration(seconds: 5)), '00:05');
      expect(
        formatCodexDuration(const Duration(minutes: 4, seconds: 30)),
        '04:30',
      );
      expect(
        formatCodexDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
    });

    test('negatif sure sifir gosterir', () {
      expect(formatCodexDuration(const Duration(seconds: -30)), '00:00');
    });
  });

  group('enum cozumleme', () {
    test('bilinmeyen adlar varsayilana duser', () {
      expect(CodexChartType.fromName('yok'), CodexChartType.bar);
      expect(CodexPalette.fromName(null), CodexPalette.theme);
      expect(CodexDividerStyle.fromName(7), CodexDividerStyle.ornament);
      expect(CodexTone.fromName('yok'), CodexTone.neutral);
      expect(CodexMediaFit.fromName('yok'), CodexMediaFit.contain);
      expect(CodexCounterStyle.fromName('yok'), CodexCounterStyle.row);
      expect(CodexChipStyle.fromName('yok'), CodexChipStyle.chip);
      expect(CodexTimerMode.fromName('yok'), CodexTimerMode.countdown);
      expect(CodexTimerStyle.fromName('yok'), CodexTimerStyle.digits);
    });

    test('gecerli adlar cozulur', () {
      expect(CodexChartType.fromName('donut'), CodexChartType.donut);
      expect(CodexPalette.fromName('ember'), CodexPalette.ember);
      expect(CodexCounterStyle.fromName('tile'), CodexCounterStyle.tile);
    });
  });
}
