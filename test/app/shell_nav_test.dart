import 'package:dm_table/app/router.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/providers.dart';
import 'package:dm_table/l10n/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kabuk navigasyonu: genis ekranda gruplu ray, dar ekranda bes sekme +
/// "Daha fazla". Sira DM'in is akisina gore kuruldu (once masa, sonra dunya,
/// sonra araclar); bu test hem gruplarin gorundugunu hem de HICBIR bolumun
/// erisilemez kalmadigini kilitler.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<void> pumpApp(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          contentReadyProvider.overrideWith((ref) async {}),
        ],
        child: MaterialApp.router(
          locale: const Locale('tr'),
          localizationsDelegates: const [
            L10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: L10n.supportedLocales,
          routerConfig: buildRouter(),
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
  }

  /// Drift akislari/zamanlayicilari test bitmeden birakilirsa "Pending timers"
  /// hatasi verir. **`addTearDown` ise ise yaramaz**: zamanlayici denetimi test
  /// GOVDESI biter bitmez, teardown'lardan ONCE calisiyor — sokme islemi
  /// govdenin icinde yapilmali.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets('genis ekran rayi uc grup basligiyla ciziliyor', (tester) async {
    await pumpApp(tester, const Size(1400, 2000));

    expect(find.text('MASADA'), findsOneWidget);
    expect(find.text('DÜNYA & ÖYKÜ'), findsOneWidget);
    expect(find.text('ARAÇLAR'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('rayda tum bolumler var ve sirasi is akisina gore', (
    tester,
  ) async {
    await pumpApp(tester, const Size(1400, 2000));

    // Sayfa basliklari da ayni metni tasiyabiliyor; yalnizca raydakine bak.
    double railY(String label) => tester
        .getTopLeft(
          find.descendant(
            of: find.byType(NavigationRail),
            matching: find.text(label),
          ),
        )
        .dy;

    // Masada grubu once, Ayarlar en sonda.
    expect(railY('Oturum'), lessThan(railY('Savaş')));
    expect(railY('Savaş'), lessThan(railY('Dünya')));
    expect(railY('Dünya'), lessThan(railY('Kütüphane')));
    expect(railY('Kütüphane'), lessThan(railY('Ayarlar')));

    await unmount(tester);
  });

  testWidgets('dar ekranda bes sekme + Daha fazla', (tester) async {
    await pumpApp(tester, const Size(420, 900));

    final bar = find.byType(NavigationBar);
    expect(bar, findsOneWidget);
    expect(
      tester.widget<NavigationBar>(bar).destinations,
      hasLength(6), // 5 birincil + "Daha fazla"
    );
    // Ilk sekme Oturum: seans oradan baslar.
    expect(find.text('Oturum'), findsWidgets);

    await unmount(tester);
  });
}
