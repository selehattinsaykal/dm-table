import 'dart:async';

import 'package:dm_table/app/content_gate.dart';
import 'package:dm_table/data/providers.dart';
import 'package:dm_table/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kural kutuphanesi kurulurken kullanicinin ne gordugu.
///
/// Ilk acilista tek bekleme noktasi burasi; sessizce bos ekran gostermek ya
/// da hatayi yutmak en kotu davranis olurdu.
void main() {
  // `Override` tipi flutter_riverpod'dan disa acilmadigi icin override'i
  // adlandirmak yerine iceride kuruyoruz.
  Widget wrap(FutureOr<void> Function(Ref ref) create) => ProviderScope(
    overrides: [contentReadyProvider.overrideWith(create)],
    child: const MaterialApp(
      locale: Locale('tr'),
      localizationsDelegates: [
        L10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: L10n.supportedLocales,
      home: ContentGate(child: Text('hazır')),
    ),
  );

  testWidgets('ice aktarma surerken ilerleme gosterilir', (tester) async {
    await tester.pumpWidget(wrap((ref) => Completer<void>().future));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('İçerik hazırlanıyor'), findsOneWidget);
    expect(find.text('hazır'), findsNothing);
  });

  testWidgets('bitince asil arayuz gosterilir', (tester) async {
    await tester.pumpWidget(wrap((ref) async {}));
    await tester.pump();

    expect(find.text('hazır'), findsOneWidget);
  });

  testWidgets('hata yutulmaz, tekrar denenebilir', (tester) async {
    await tester.pumpWidget(
      wrap((ref) => Future<void>.error(StateError('manifest okunamadı'))),
    );
    await tester.pump();

    expect(find.text('İçerik kurulumu başarısız oldu'), findsOneWidget);
    expect(find.textContaining('manifest okunamadı'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Tekrar dene'), findsOneWidget);
  });
}
