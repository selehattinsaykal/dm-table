import 'package:dm_table/data/character_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/import/asset_importer.dart';
import 'package:dm_table/data/providers.dart';
import 'package:dm_table/domain/models/ability.dart';
import 'package:dm_table/domain/rules/character_math.dart';
import 'package:dm_table/features/characters/characters_page.dart';
import 'package:dm_table/l10n/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sihirbazi bastan sona surer: bir Barbarian yaratip veritabanina dogru
/// yazildigini dogrular. Adimlarin kilit mantigi (ileri butonunun ne zaman
/// acildigi) de burada sinaniyor.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await AssetImporter(db).importIfNeeded();
  });

  tearDown(() async => db.close());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
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
          home: CharactersPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Widget agacini test govdesi bitmeden soker.
  ///
  /// Karakter listesi bir drift stream'i dinliyor; agac ayakta kalirsa
  /// ProviderScope test sonrasi dispose ediliyor ve drift'in akis temizligi
  /// bekleyen bir zamanlayici birakip testi "Pending timers" ile dusuruyor.
  /// `addTearDown` ise cok gec: Flutter'in zamanlayici denetimi ondan once
  /// kosuyor.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  Finder nextButton() => find.widgetWithText(FilledButton, 'İleri');

  Future<void> tapNext(WidgetTester tester) async {
    await tester.tap(nextButton());
    await tester.pumpAndSettle();
  }

  testWidgets('bos listede yonlendirme gosterilir', (tester) async {
    await pump(tester);
    expect(find.text('Henüz karakter yok'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('sihirbaz bastan sona bir Barbarian yaratir', (tester) async {
    await pump(tester);

    await tester.tap(
      find.widgetWithText(FloatingActionButton, 'Yeni karakter'),
    );
    await tester.pumpAndSettle();

    // --- 1. Kimlik ve tur
    expect(nextButton(), findsOneWidget);
    // Isim ve tur secilmeden ilerlenemez.
    expect(tester.widget<FilledButton>(nextButton()).onPressed, isNull);

    await tester.enterText(find.byType(TextFormField).first, 'Grog');
    await tester.pumpAndSettle();
    // Isim var ama tur yok.
    expect(tester.widget<FilledButton>(nextButton()).onPressed, isNull);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Goliath'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(nextButton()).onPressed, isNotNull);
    // Goliath 35 feet hizinda -- tur verisi gercekten okunuyor mu?
    expect(find.text('35 feet'), findsOneWidget);
    await tapNext(tester);

    // --- 2. Koken
    await tester.tap(find.widgetWithText(ChoiceChip, 'Soldier'));
    await tester.pumpAndSettle();
    // Soldier: Athletics ve Intimidation
    expect(find.textContaining('Athletics'), findsWidgets);
    // Puan dagitilmadan ilerlenemez.
    expect(tester.widget<FilledButton>(nextButton()).onPressed, isNull);

    // +2 STR, +1 CON (Soldier: Strength, Dexterity, Constitution)
    final plusTwoRow = find.byType(ChoiceChip);
    await tester.tap(
      plusTwoRow.at(find.byType(ChoiceChip).evaluate().length - 6),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'CON').last);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(nextButton()).onPressed, isNotNull);
    await tapNext(tester);

    // --- 3. Sinif
    await tester.tap(find.widgetWithText(ChoiceChip, 'Barbarian'));
    await tester.pumpAndSettle();
    expect(find.text('d12'), findsOneWidget);
    await tapNext(tester);

    // --- 4. Yetenek puanlari: standart dizi
    await tester.tap(find.text('Standart dizi'));
    await tester.pumpAndSettle();
    await tapNext(tester);

    // --- 5. Beceriler: Barbarian 2 secer
    expect(tester.widget<FilledButton>(nextButton()).onPressed, isNull);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Perception'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Survival'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(nextButton()).onPressed, isNotNull);
    await tapNext(tester);

    // --- 6. Ekipman
    expect(tester.widget<FilledButton>(nextButton()).onPressed, isNull);
    await tester.tap(find.text('Seçenek B'));
    await tester.pumpAndSettle();
    await tapNext(tester);

    // --- 7. Ozet ve olusturma
    expect(find.text('Grog'), findsWidgets);
    await tester.tap(find.widgetWithText(FilledButton, 'Karakteri oluştur'));
    await tester.pumpAndSettle();

    // Liste ekranina donuldu mu?
    expect(find.text('Henüz karakter yok'), findsNothing);

    // --- Veritabanina dogru yazildi mi?
    final repo = CharacterRepository(db);
    final saved = (await db.select(db.characters).get()).single;
    expect(saved.name, 'Grog');
    expect(saved.speciesKey, contains('goliath'));
    expect(saved.backgroundKey, contains('soldier'));

    final build = await repo.buildFor(saved.id);
    expect(build.totalLevel, 1);
    expect(build.classes.single.hitDieSides, 12);

    // Barbarian kurtarma atislari: STR ve CON
    expect(build.saveProficiencies, {Ability.strength, Ability.constitution});

    // Sinif secimleri + kokenden gelenler birlesmis olmali.
    expect(
      build.skillProficiencies,
      containsAll([
        Skill.perception,
        Skill.survival,
        Skill.athletics,
        Skill.intimidation,
      ]),
    );

    // Standart dizi: STR 15 (+2 koken) = 17, CON 13 (+1) = 14 -> CON mod +2
    expect(saved.strength, 17);
    expect(saved.constitution, 14);
    expect(saved.hitPointsMax, 14); // d12 tam + CON +2
    expect(build.maxHitPoints, 14);

    // Secenek B: 75 gp sinif + 50 gp koken
    expect(saved.coinsCp, (75 + 50) * 100);

    await unmount(tester);
  });
}
