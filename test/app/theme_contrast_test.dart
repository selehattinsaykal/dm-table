import 'dart:math' as math;

import 'package:dm_table/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tema renklerinin WCAG kontrast esiklerini tuttugunu OLCEREK dogrular.
///
/// Neden gerekli: `theme.dart` icindeki yorumlar belirli oranlar iddia ediyor
/// ("3:1 icin acildi", "kontrast 4.8:1") ama bunlari hicbir sey dogrulamiyordu.
/// Paletin bir tonu elle degistirildiginde sessizce erisilebilirlik kaybi
/// olusabilirdi; bu test o kapiyi kapatiyor.
///
/// Esikler (WCAG 2.1):
///  * Normal govde metni: 4.5:1
///  * Buyuk metin / arayuz bileseni (kenarlik, ikon, ayrac): 3:1
void main() {
  _motionScale();

  /// WCAG bagil parlaklik (relative luminance).
  double luminance(Color c) {
    double channel(double v) {
      final s = v; // 0..1
      return s <= 0.03928
          ? s / 12.92
          : math.pow((s + 0.055) / 1.055, 2.4) as double;
    }

    return 0.2126 * channel(c.r) +
        0.7152 * channel(c.g) +
        0.0722 * channel(c.b);
  }

  /// Iki opak renk arasindaki WCAG kontrast orani (1..21).
  double contrast(Color a, Color b) {
    final la = luminance(a);
    final lb = luminance(b);
    final hi = math.max(la, lb);
    final lo = math.min(la, lb);
    return (hi + 0.05) / (lo + 0.05);
  }

  /// [ratio] esigi tutmuyorsa olculen degeri yazarak patlar.
  void expectContrast(
    Color fg,
    Color bg, {
    required double min,
    required String label,
  }) {
    final value = contrast(fg, bg);
    expect(
      value,
      greaterThanOrEqualTo(min),
      reason:
          '$label: olculen ${value.toStringAsFixed(2)}:1, beklenen >= $min:1 '
          '(fg=${fg.toARGB32().toRadixString(16)} bg=${bg.toARGB32().toRadixString(16)})',
    );
  }

  for (final brightness in Brightness.values) {
    final name = brightness == Brightness.dark ? 'koyu' : 'acik';
    final theme = brightness == Brightness.dark
        ? AppTheme.dark()
        : AppTheme.light();
    final scheme = theme.colorScheme;
    final fantasy = theme.extension<AppFantasyColors>()!;

    group('$name tema kontrasti', () {
      test('govde metni tum yuzey basamaklarinda 4.5:1', () {
        // Kartlar ve paneller bu basamaklarin herhangi birinde olabiliyor;
        // metin hepsinde okunur kalmali.
        final surfaces = {
          'surface': scheme.surface,
          'surfaceContainerLowest': scheme.surfaceContainerLowest,
          'surfaceContainerLow': scheme.surfaceContainerLow,
          'surfaceContainer': scheme.surfaceContainer,
          'surfaceContainerHigh': scheme.surfaceContainerHigh,
          'surfaceContainerHighest': scheme.surfaceContainerHighest,
        };
        for (final entry in surfaces.entries) {
          expectContrast(
            scheme.onSurface,
            entry.value,
            min: 4.5,
            label: 'onSurface / ${entry.key}',
          );
        }
      });

      test('ikincil metin en az 4.5:1 (govde olarak da kullaniliyor)', () {
        expectContrast(
          scheme.onSurfaceVariant,
          scheme.surface,
          min: 4.5,
          label: 'onSurfaceVariant / surface',
        );
      });

      test('vurgu rengi uzerindeki metin 4.5:1', () {
        expectContrast(
          scheme.onPrimary,
          scheme.primary,
          min: 4.5,
          label: 'onPrimary / primary',
        );
      });

      test('kenarlik ve ayraclar arayuz esigini (3:1) tutar', () {
        expectContrast(
          scheme.outline,
          scheme.surface,
          min: 3,
          label: 'outline / surface',
        );
      });

      test('kimlik tonlari zemin uzerinde secilir (3:1)', () {
        // Bunlar sus/rozet renkleri: ikon ve ince cizgi olarak kullaniliyorlar,
        // yani arayuz bileseni esigine tabiler.
        expectContrast(
          fantasy.gold,
          scheme.surface,
          min: 3,
          label: 'gold / surface',
        );
        expectContrast(
          fantasy.brass,
          scheme.surface,
          min: 3,
          label: 'brass / surface',
        );
        expectContrast(
          fantasy.moss,
          scheme.surface,
          min: 3,
          label: 'moss / surface',
        );
      });

      test('parsomen uzerindeki murekkep govde metni esigini tutar', () {
        expectContrast(
          fantasy.ink,
          fantasy.parchment,
          min: 4.5,
          label: 'ink / parchment',
        );
      });

      test('muhur (wax) ZEMIN olarak kullanilir: uzerine acik metin gelir', () {
        // `wax` bilerek zemin rengi ve uzerine `onWax` biniyor. `parchment`
        // ile olculemez: o jetonun anlami temaya gore TERS donuyor (koyu
        // temada koyu bir yuzey tonu), bu yuzden ayri bir `onWax` var.
        expectContrast(
          fantasy.onWax,
          fantasy.wax,
          min: 4.5,
          label: 'onWax / wax zemini',
        );
      });

      test('yeni renk eksenleri zemin uzerinde secilir (3:1)', () {
        // Patina ve ametist harita pinlerinde ikon/isaret olarak kullaniliyor,
        // yani arayuz bileseni esigine tabiler.
        expectContrast(
          fantasy.verdigris,
          scheme.surface,
          min: 3,
          label: 'verdigris / surface',
        );
        expectContrast(
          fantasy.arcane,
          scheme.surface,
          min: 3,
          label: 'arcane / surface',
        );
      });
    });
  }
}

/// Hareket jetonlarinin UX esiklerini tuttugunu dogrular.
void _motionScale() {
  group('hareket olcegi', () {
    test('sureler kendi bandlarinda kalir', () {
      // `fast` anlik geri bildirim: 150 ms'nin altinda olmali ki "bekleme"
      // hissi vermesin. `normal` mikro etkilesim bandi (150-300). `slow`
      // BUYUK yuzey icin ve bilerek daha uzun -- Material'in genis kap
      // gecisleri de 300-400 bandinda; buraya 300 ust siniri koymak yanlis
      // olurdu.
      expect(AppMotion.fast.inMilliseconds, lessThan(150));
      expect(AppMotion.normal.inMilliseconds, inInclusiveRange(150, 300));
      expect(AppMotion.slow.inMilliseconds, inInclusiveRange(250, 400));
    });

    test('cikis giristen HIZLI degil, sureler artan sirada', () {
      expect(AppMotion.fast, lessThan(AppMotion.normal));
      expect(AppMotion.normal, lessThan(AppMotion.slow));
    });
  });
}
