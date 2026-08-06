import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/import/asset_importer.dart';
import 'package:dm_table/data/loot_repository.dart';
import 'package:dm_table/data/providers.dart';
import 'package:dm_table/features/loot/loot_page.dart';
import 'package:dm_table/l10n/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ganimet seti editöründe compendium'dan (esya / buyulu esya) ekleme.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late LootRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await AssetImporter(db).importIfNeeded();
    repo = LootRepository(db);
  });

  tearDown(() => db.close());

  Future<void> pumpEditor(WidgetTester tester, String setId) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          locale: const Locale('en'),
          home: LootSetEditPage(setId: setId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Dialog icindeki arama alanini bulur (editördeki diger alanlardan ayirt
  /// etmek icin AlertDialog ile sinirla).
  Finder dialogSearchField() => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(TextField),
  );

  testWidgets('katalogdan esya eklenir ve listeye girer', (tester) async {
    final setId = await repo.create('Set');
    await pumpEditor(tester, setId);

    // "Add from catalog" acilir.
    await tester.tap(find.text('Add from catalog'));
    await tester.pumpAndSettle();

    // Arama: SRD'deki "Dagger".
    await tester.enterText(dialogSearchField(), 'dag');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dagger').first);
    await tester.pumpAndSettle();

    // Dialog kapatilir; secilen esya set listesinde gorunur.
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Dagger'), findsOneWidget);
  });

  testWidgets('buyulu esya sekmesi buyulu esyalari arar', (tester) async {
    final setId = await repo.create('Set');
    await pumpEditor(tester, setId);

    await tester.tap(find.text('Add from catalog'));
    await tester.pumpAndSettle();

    // Buyulu esyalar sekmesi secilir.
    await tester.tap(find.text('Magic Items'));
    await tester.pumpAndSettle();

    // SRD'de buyulu bir esya ara (orn. "flame tongue").
    await tester.enterText(dialogSearchField(), 'flame');
    await tester.pumpAndSettle();

    // En az bir sonuc cikmis olmali (satirlar var).
    expect(find.byType(ListTile), findsWidgets);

    // Ilk sonucu ekle.
    final firstTile = find.byType(ListTile).first;
    await tester.tap(firstTile);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    // Set listesinde en az bir esya var.
    expect(find.byIcon(Icons.remove_circle_outline), findsOneWidget);
  });
}
