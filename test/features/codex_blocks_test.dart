import 'package:dm_table/domain/codex/codex_style.dart';
import 'package:dm_table/features/codex/codex_charts.dart';
import 'package:dm_table/features/codex/codex_counter.dart';
import 'package:dm_table/features/codex/codex_style_ui.dart';
import 'package:dm_table/features/codex/codex_timer.dart';
import 'package:dm_table/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kayitlar bloklarinin gorsel katmani: grafik turleri, sayac modulu ve
/// yerlesim kutusu. Cizim kodu `CustomPainter` oldugu icin asil risk
/// gecersiz geometri (bos veri, tek oge, negatif deger) — hepsi burada.
void main() {
  Widget wrap(Widget child, {double width = 600}) => MaterialApp(
    locale: const Locale('tr'),
    localizationsDelegates: const [
      L10n.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: L10n.supportedLocales,
    home: Scaffold(
      body: Center(
        child: SizedBox(width: width, child: child),
      ),
    ),
  );

  group('grafik', () {
    const items = [
      CodexChartItem(label: 'Altın', value: 120),
      CodexChartItem(label: 'Gümüş', value: 60),
      CodexChartItem(label: 'Bakır', value: 15),
    ];

    for (final type in CodexChartType.values) {
      testWidgets('${type.name} cizilir', (tester) async {
        await tester.pumpWidget(
          wrap(
            SizedBox(
              height: 300,
              child: CodexChartView(title: 'Hazine', type: type, items: items),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Hazine'), findsOneWidget);
      });
    }

    testWidgets('tek oge ve negatif deger cokmez', (tester) async {
      for (final type in CodexChartType.values) {
        await tester.pumpWidget(
          wrap(
            SizedBox(
              height: 340,
              child: CodexChartView(
                title: '',
                type: type,
                items: const [CodexChartItem(label: 'Borç', value: -40)],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: type.name);
      }
    });

    testWidgets('veri yokken ipucu gosterir', (tester) async {
      await tester.pumpWidget(
        wrap(
          const CodexChartView(
            title: 'Bos',
            type: CodexChartType.pie,
            items: [],
            emptyHint: 'Henüz veri yok.',
          ),
        ),
      );

      expect(find.text('Henüz veri yok.'), findsOneWidget);
    });

    test('deger bicimlendirme kisa ve okunur', () {
      expect(formatChartValue(12), '12');
      expect(formatChartValue(12.5), '12.5');
      expect(formatChartValue(2.25), '2.25');
      expect(formatChartValue(25000), '25.0K');
    });
  });

  group('sayac', () {
    testWidgets('arti/eksi degeri sinirlar icinde degistirir', (tester) async {
      var current = const CodexCounter(
        label: 'Meşale',
        value: 1,
        min: 0,
        max: 2,
      );

      await tester.pumpWidget(
        wrap(
          StatefulBuilder(
            builder: (context, setState) => CodexCounterView(
              title: 'Kaynaklar',
              style: CodexCounterStyle.row,
              counters: [current],
              interactive: true,
              onChanged: (_, next) => setState(() => current = next),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(current.value, 2);

      // Ust sinirda arti dugmesi kapanir.
      final plus = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.add),
          matching: find.byType(IconButton),
        ),
      );
      expect(plus.onPressed, isNull);

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
      expect(current.value, 1);
    });

    testWidgets('goruntule disinda (duzenleme) kilitli', (tester) async {
      await tester.pumpWidget(
        wrap(
          CodexCounterView(
            title: '',
            style: CodexCounterStyle.row,
            counters: const [CodexCounter(label: 'Ok', value: 5)],
            interactive: false,
            onChanged: (_, _) => fail('duzenleme modunda degismemeli'),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
    });

    testWidgets('her bicim cizilir', (tester) async {
      for (final style in CodexCounterStyle.values) {
        await tester.pumpWidget(
          wrap(
            CodexCounterView(
              title: 'Sayaçlar',
              style: style,
              counters: const [
                CodexCounter(label: 'Gün', value: 3, icon: '📅'),
                CodexCounter(label: 'Erzak', value: 4, min: 0, max: 10),
              ],
              interactive: true,
              onChanged: (_, _) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: style.name);
      }
    });

    testWidgets('sayac yokken bos metni gosterir', (tester) async {
      await tester.pumpWidget(
        wrap(
          CodexCounterView(
            title: '',
            style: CodexCounterStyle.row,
            counters: const [],
            interactive: true,
            onChanged: (_, _) {},
          ),
        ),
      );

      expect(find.textContaining('Sayaç'), findsOneWidget);
    });
  });

  group('yerlesim kutusu', () {
    testWidgets('oran genisligi ve hizalama uygular', (tester) async {
      await tester.pumpWidget(
        wrap(
          const CodexLayoutBox(
            layout: CodexLayout(width: 0.5, align: CodexAlign.right),
            child: SizedBox(height: 40, key: Key('icerik')),
          ),
        ),
      );

      final box = tester.getRect(find.byKey(const Key('icerik')));
      expect(box.width, closeTo(300, 0.5));
      // Saga yasli: sag kenar kapsayicinin sag kenarina degsin.
      final parent = tester.getRect(find.byType(CodexLayoutBox));
      expect(box.right, closeTo(parent.right, 0.5));
    });

    testWidgets('tam genislikte cocugu oldugu gibi birakir', (tester) async {
      await tester.pumpWidget(
        wrap(
          const CodexLayoutBox(
            layout: CodexLayout(),
            child: SizedBox(height: 40, key: Key('icerik')),
          ),
        ),
      );

      expect(
        tester.getRect(find.byKey(const Key('icerik'))).width,
        closeTo(600, 0.5),
      );
    });
  });

  group('sure sayaci', () {
    /// Sayac calisirken periyodik tik kurulur; test bitmeden agac
    /// sokulmezse "pending timer" hatasi verir.
    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    }

    testWidgets('baslat/duraklat durumu disari bildirilir', (tester) async {
      var timer = const CodexTimer(duration: Duration(minutes: 1));

      await tester.pumpWidget(
        wrap(
          StatefulBuilder(
            builder: (context, setState) => CodexTimerView(
              title: 'Tur süresi',
              timer: timer,
              interactive: true,
              onChanged: (next) => setState(() => timer = next),
            ),
          ),
        ),
      );

      expect(find.text('01:00'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();
      expect(timer.isRunning, isTrue);

      await tester.tap(find.byIcon(Icons.pause));
      await tester.pump();
      expect(timer.isRunning, isFalse);
      await unmount(tester);
    });

    testWidgets('bir dakika ekle suresini uzatir', (tester) async {
      var timer = const CodexTimer(duration: Duration(minutes: 1));

      await tester.pumpWidget(
        wrap(
          StatefulBuilder(
            builder: (context, setState) => CodexTimerView(
              title: '',
              timer: timer,
              interactive: true,
              onChanged: (next) => setState(() => timer = next),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.more_time));
      await tester.pump();

      expect(timer.duration, const Duration(minutes: 2));
      expect(find.text('02:00'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('duzenleme modunda dugmeler kilitli', (tester) async {
      await tester.pumpWidget(
        wrap(
          CodexTimerView(
            title: '',
            timer: const CodexTimer(),
            interactive: false,
            onChanged: (_) => fail('duzenleme modunda degismemeli'),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();
      await unmount(tester);
    });

    testWidgets('bitmis geri sayim uyari metni gosterir', (tester) async {
      await tester.pumpWidget(
        wrap(
          CodexTimerView(
            title: '',
            timer: const CodexTimer(
              duration: Duration(seconds: 30),
              accumulated: Duration(seconds: 30),
            ),
            interactive: true,
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('00:00'), findsOneWidget);
      expect(find.textContaining('Süre doldu'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('her bicim cizilir', (tester) async {
      for (final style in CodexTimerStyle.values) {
        await tester.pumpWidget(
          wrap(
            CodexTimerView(
              title: 'Meşale',
              timer: CodexTimer(
                style: style,
                duration: const Duration(minutes: 10),
                accumulated: const Duration(minutes: 4),
              ),
              interactive: true,
              onChanged: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: style.name);
      }
      await unmount(tester);
    });
  });

  group('yeniden boyutlandirma', () {
    testWidgets('sag tutamagi surukleyince oran degisir', (tester) async {
      var layout = const CodexLayout();
      await tester.pumpWidget(
        wrap(
          StatefulBuilder(
            builder: (context, setState) => CodexResizable(
              layout: layout,
              enabled: true,
              onChanged: (next) => setState(() => layout = next),
              child: const SizedBox(height: 80),
            ),
          ),
        ),
      );

      await tester.drag(
        find.byKey(const ValueKey('codexResize-right')),
        const Offset(-300, 0),
      );
      await tester.pumpAndSettle();

      expect(layout.width, lessThan(0.6));
      expect(layout.width, greaterThan(0.4));
    });
  });
}
