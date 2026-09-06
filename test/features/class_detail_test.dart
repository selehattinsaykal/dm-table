import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/import/asset_importer.dart';
import 'package:dm_table/data/providers.dart';
import 'package:dm_table/features/compendium/compendium_page.dart';
import 'package:dm_table/l10n/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kutuphanedeki sinif sekmesi.
///
/// 81 sinif kaydinin tablolari ve yetenek metinleri karakter kagidi disindan
/// gorulemiyordu.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await AssetImporter(db).importIfNeeded();
  });

  tearDown(() async => db.close());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(
          locale: Locale('tr'),
          localizationsDelegates: [
            L10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: L10n.supportedLocales,
          home: CompendiumPage(),
        ),
      ),
    );
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets('sinif sekmesi siniflari ve alt siniflari listeler', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text('Sınıflar'));
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    // Alt sinif satirlarinin altinda ana sinifin adi yazdigi icin "Artificer"
    // birden fazla kez gorunur: bir baslik, bes alt sinif alt basligi.
    expect(find.text('Artificer'), findsWidgets);
    expect(find.text('Alchemist'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('sinif detayi tablo ve yetenekleri gosterir', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Sınıflar'));
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    // Alt basligi olmayan satir ANA sinif; alt sinif satirlarinin alt
    // basliginda da "Artificer" yaziyor.
    await tester.tap(
      find.byWidgetPredicate(
        (w) =>
            w is ListTile &&
            w.subtitle == null &&
            w.title is Text &&
            (w.title! as Text).data == 'Artificer',
      ),
    );
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    // Cekirdek ozellik tablosu markdown tablosu olarak ciziliyor.
    expect(find.byType(Table), findsWidgets);
    expect(find.text('Sınıf tablosu'), findsOneWidget);
    expect(find.text('Alt sınıflar'), findsOneWidget);

    await unmount(tester);
  });
}
