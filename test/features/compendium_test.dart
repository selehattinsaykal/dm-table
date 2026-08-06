import 'package:dm_table/app/router.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/import/asset_importer.dart';
import 'package:dm_table/data/providers.dart';
import 'package:dm_table/l10n/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kutuphane ekranini gercek SRD verisiyle surer: ice aktarma -> liste ->
/// arama -> filtre -> detay. Veri katmani ile arayuz arasindaki bagin
/// koptugunu en hizli burasi yakalar.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Ice aktarma gercek dosya okuma + binlerce insert; her testte tekrar
  // calistirmak hem yavas hem de pump donguleriyle yaris kosuluna yol aciyor.
  // Bir kez hazirlanip paylasiliyor (testler yalnizca okuyor).
  late AppDatabase db;

  setUpAll(() async {
    db = AppDatabase(NativeDatabase.memory());
    await AssetImporter(db).importIfNeeded();
  });

  tearDownAll(() async => db.close());

  Future<void> pumpApp(WidgetTester tester) async {
    // Uzun bir gorunum penceresi: stat blogun tamami tek ekrana sigsin.
    // Aksi halde ListView yalnizca gorunenleri kurdugu icin her iddia
    // once kaydirma gerektirir ve testler kirilgan olur.
    tester.view.physicalSize = const Size(1000, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          // Veri setUpAll'da zaten yuklendi. Gercek ice aktarma rootBundle
          // uzerinden dosya okur; widget testinin sahte saatinde bu G/C hic
          // tamamlanmaz ve kapi sonsuza kadar yukleniyor kalirdi.
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
          routerConfig: buildRouter(initialLocation: '/compendium'),
        ),
      ),
    );
    // `pumpAndSettle` burada kullanilamaz: yukleme gostergesi sonsuz
    // animasyon oldugu icin hicbir zaman oturmaz. Bunun yerine hedef
    // arayuz belirene kadar cerceve uretiyoruz -- "gosterge yok" kontrolu
    // ilk kare cizilmeden de dogru oldugu icin yaniltici.
    for (var i = 0; i < 300; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      final ready =
          find.byType(TextField).evaluate().isNotEmpty &&
          find.byType(ListTile).evaluate().isNotEmpty;
      if (ready) return;
    }
    fail('Kütüphane ekranı açılmadı (içe aktarma tamamlanmadı?)');
  }

  testWidgets('acilista canavarlar CR sirasiyla listelenir', (tester) async {
    await pumpApp(tester);

    expect(find.text('Kütüphane'), findsWidgets);
    expect(find.text('Canavarlar'), findsOneWidget);
    // CR 0 canavarlar once gelir.
    expect(find.textContaining('CR 0'), findsWidgets);
  });

  testWidgets('arama listeyi daraltir ve detay acilir', (tester) async {
    await pumpApp(tester);

    await tester.enterText(find.byType(TextField).first, 'aboleth');
    await tester.pumpAndSettle();

    expect(find.text('Aboleth'), findsOneWidget);

    await tester.tap(find.text('Aboleth'));
    await tester.pumpAndSettle();

    // Stat blogun ayirt edici satirlari. `Armor Class` satiri RichText ile
    // ciziliyor (etiket kalin, deger normal), o yuzden findRichText gerekli.
    expect(
      find.textContaining('Armor Class', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('STR'), findsOneWidget);
    // Efsanevi aksiyonlar karisik listede kaybolmayip kendi bloguna ayrilmali.
    expect(find.text('Legendary Actions'), findsOneWidget);
  });

  testWidgets('buyu sekmesinde seviye filtresi calisir', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Büyüler'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Cantrip'));
    await tester.pumpAndSettle();

    // Cantrip filtresi acikken hicbir satirda "Level 3" yazmamali.
    expect(find.textContaining('Level 3'), findsNothing);
    expect(find.textContaining('Cantrip'), findsWidgets);
  });

  testWidgets('buyulu esyada onerilen fiyat isaretlenir', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Büyülü Eşyalar'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'adamantine armor');
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Adamantine Armor').first);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('(önerilen)', findRichText: true),
      findsOneWidget,
    );
  });
}
