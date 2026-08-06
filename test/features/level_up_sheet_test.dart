import 'package:dm_table/data/character_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/import/asset_importer.dart';
import 'package:dm_table/data/providers.dart';
import 'package:dm_table/domain/models/ability.dart';
import 'package:dm_table/features/characters/level_up_sheet.dart';
import 'package:dm_table/l10n/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Seviye atlama ekrani: zorunlu secimler yapilmadan kaydedilemiyor mu ve
/// kaydedince veritabani dogru mu guncelleniyor?
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CharacterRepository repo;
  const id = 'lvl';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await AssetImporter(db).importIfNeeded();
    repo = CharacterRepository(db);
  });

  tearDown(() async => db.close());

  Future<void> seed(String classKey, {int toLevel = 1}) async {
    await repo.createLevelOneCharacter(
      id: id,
      name: 'Vex',
      classKey: classKey,
      abilities: const AbilityScores(constitution: 14),
      savingThrows: const {},
      skills: const {},
      hitDieSides: 6,
    );
    for (var l = 1; l < toLevel; l++) {
      await repo.levelUp(characterId: id, classKey: classKey);
    }
  }

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 4000);
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
          home: LevelUpSheet(characterId: id),
        ),
      ),
    );
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (find.text('Can puanı').evaluate().isNotEmpty) break;
    }
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  Finder saveButton() =>
      find.widgetWithText(FilledButton, 'Wizard 2 olarak kaydet');

  testWidgets('2. seviye: ek secim gerekmez, dogrudan kaydedilir', (
    tester,
  ) async {
    await seed('srd-2024_wizard');
    await pump(tester);

    expect(find.text('Wizard 2'), findsOneWidget);
    // 2. seviyede alt sinif ya da ASI yok.
    expect(find.text('Alt sınıf'), findsNothing);
    expect(find.text('Yetenek artışı'), findsNothing);
    expect(tester.widget<FilledButton>(saveButton()).onPressed, isNotNull);

    await tester.tap(saveButton());
    await tester.pumpAndSettle();

    final levels = await repo.classLevels(id);
    expect(levels.single.level, 2);
    // d6 ortalama 4 + CON 2 -> 8 + 6 = 14
    expect((await repo.find(id))!.hitPointsMax, 14);

    await unmount(tester);
  });

  testWidgets('3. seviyede alt sinif secilmeden kaydedilemez', (tester) async {
    await seed('srd-2024_wizard', toLevel: 2);
    await pump(tester);

    expect(find.text('Wizard 3'), findsOneWidget);
    expect(find.text('Alt sınıf'), findsOneWidget);

    final save = find.widgetWithText(FilledButton, 'Wizard 3 olarak kaydet');
    expect(
      tester.widget<FilledButton>(save).onPressed,
      isNull,
      reason: 'alt sınıf seçilmeden kaydedilebiliyor',
    );

    // SRD'de Wizard'in tek alt sinifi Evoker.
    await tester.tap(find.widgetWithText(ChoiceChip, 'Evoker'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);

    await tester.tap(save);
    await tester.pumpAndSettle();

    expect((await repo.classLevels(id)).single.subclassKey, 'srd-2024_evoker');

    await unmount(tester);
  });

  testWidgets('kendi alt sinifini seviye seviye girip secebilir', (
    tester,
  ) async {
    await seed('srd-2024_wizard', toLevel: 2);
    await pump(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Kendim ekle'));
    await tester.pumpAndSettle();

    // Tam editor acilmali.
    expect(find.text('Wizard alt sınıfı'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Bladesinger');
    await tester.pumpAndSettle();

    // 3. seviyede bir yetenek ekle.
    await tester.tap(find.widgetWithText(TextButton, 'Ekle').first);
    await tester.pumpAndSettle();
    expect(find.text('Yetenek ekle'), findsOneWidget);

    // Bulucu diyaloga daraltiliyor: arkadaki editor sayfasinin alanlari da
    // agacta duruyor ve `.first` onlari yakaliyor.
    await tester.enterText(
      find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          )
          .first,
      'Bladesong',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Ekle'));
    await tester.pumpAndSettle();

    // Eklenen yetenek listede gorunmeli.
    expect(find.text('Bladesong'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
    await tester.pumpAndSettle();

    // Editorden donunce alt sinif secili gelmeli.
    final save = find.widgetWithText(FilledButton, 'Wizard 3 olarak kaydet');
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);

    await tester.tap(save);
    await tester.pumpAndSettle();

    final stored = (await repo.classLevels(id)).single;
    expect(stored.subclassKey, contains('bladesinger'));

    // Kutuphaneye kalici yazildi mi?
    final subclasses = await repo.subclassesOf('srd-2024_wizard');
    expect(subclasses.map((s) => s.name), contains('Bladesinger'));

    // Ve girilen yetenek karakter kagidina islenmis olmali -- alt sinifin
    // SRD'dekiler gibi davranmasinin asil kaniti bu.
    final features = await repo.features(id);
    expect(
      features.map((f) => f.name),
      contains('Bladesong'),
      reason: 'homebrew alt sınıfın yeteneği kağıda işlenmedi',
    );

    await unmount(tester);
  });

  testWidgets('4. seviyede ASI iki puan dagitilmadan kaydedilemez', (
    tester,
  ) async {
    await seed('srd-2024_wizard', toLevel: 3);
    await pump(tester);

    expect(find.text('Yetenek artışı'), findsOneWidget);
    final save = find.widgetWithText(FilledButton, 'Wizard 4 olarak kaydet');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    expect(find.textContaining('Kalan: 2'), findsOneWidget);

    // INT satirindaki arti butonuna iki kez bas.
    final intRow = find.ancestor(
      of: find.text('Intelligence'),
      matching: find.byType(Row),
    );
    final plus = find.descendant(
      of: intRow,
      matching: find.byIcon(Icons.add_circle_outline),
    );
    await tester.tap(plus);
    await tester.pumpAndSettle();
    await tester.tap(plus);
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    await tester.tap(save);
    await tester.pumpAndSettle();

    // Baslangicta INT 10'du, +2 ile 12 olmali.
    expect((await repo.find(id))!.intelligence, 12);

    await unmount(tester);
  });

  testWidgets('multiclass: baska sinif secilebilir', (tester) async {
    await seed('srd-2024_wizard');
    await pump(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Fighter'));
    await tester.pumpAndSettle();

    expect(find.textContaining('(yeni sınıf)'), findsOneWidget);
    await tester.tap(
      find.widgetWithText(FilledButton, 'Fighter 1 olarak kaydet'),
    );
    await tester.pumpAndSettle();

    final levels = await repo.classLevels(id);
    expect(levels.length, 2);
    expect((await repo.buildFor(id)).totalLevel, 2);

    await unmount(tester);
  });
}
