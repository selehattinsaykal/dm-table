import 'package:dm_table/data/character_repository.dart';
import 'package:dm_table/data/db/character_tables.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/import/asset_importer.dart';
import 'package:dm_table/data/providers.dart';
import 'package:dm_table/features/characters/character_sheet_page.dart';
import 'package:dm_table/l10n/app_localizations.dart';
// drift, Flutter widget'lariyla ayni adda tipler disa aciyor (Column) ve
// matcher'larla cakisan yardimcilar (isNull) tanimliyor.
import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Karakter kagidi: hesaplanan degerler kural motorundan mi geliyor ve
/// can takibi 5e kurallarina uyuyor mu?
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CharacterRepository repo;
  const id = 'sheet-test';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await AssetImporter(db).importIfNeeded();
    repo = CharacterRepository(db);

    // Wizard 5: INT 16, DEX 14, CON 12 -> PB 3, AC 12, HP elle 22.
    await db
        .into(db.characters)
        .insert(
          CharactersCompanion.insert(
            id: id,
            name: 'Vex',
            dexterity: const Value(14),
            constitution: const Value(12),
            intelligence: const Value(16),
            hitPointsMax: const Value(22),
            hitPointsCurrent: const Value(22),
          ),
        );
    await db
        .into(db.characterClassLevels)
        .insert(
          CharacterClassLevelsCompanion.insert(
            characterId: id,
            classKey: 'srd-2024_wizard',
            level: const Value(5),
          ),
        );
    await db
        .into(db.characterProficiencies)
        .insert(
          CharacterProficienciesCompanion.insert(
            characterId: id,
            kind: ProficiencyKind.skill,
            value: 'arcana',
          ),
        );
  });

  tearDown(() async => db.close());

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
          home: CharacterSheetPage(characterId: id),
        ),
      ),
    );
    var opened = false;
    for (var i = 0; i < 100 && !opened; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      opened = find.text('Beceriler').evaluate().isNotEmpty;
    }
    if (!opened) fail('Karakter kağıdı açılmadı');

    // Buyu yuvalari ayri bir asenkron sorgudan geliyor; kagit gorunur
    // olduktan sonra da cozulmesi icin birkac kare daha uretiliyor.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  /// Drift stream'i test bitmeden birakilirsa "Pending timers" hatasi verir.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets('hesaplanan degerler kural motorundan gelir', (tester) async {
    await pump(tester);

    expect(find.text('Vex'), findsWidgets);
    // Mevcut can ve azami can ayri Text widget'lari.
    expect(find.text('22'), findsWidgets);
    expect(find.text(' / 22'), findsOneWidget);

    // AC = 10 + DEX(+2) = 12
    expect(find.text('12'), findsWidgets);
    // Yeterlilik bonusu 5. seviyede +3
    expect(find.text('+3'), findsWidgets);
    // Arcana: INT +3, yeterlilik +3 -> +6
    expect(find.text('+6'), findsWidgets);

    await unmount(tester);
  });

  testWidgets('Wizard 5 buyu yuvalari kagitta gorunur', (tester) async {
    await pump(tester);

    expect(find.text('Büyü yuvaları'), findsOneWidget);
    expect(find.text('1. seviye'), findsOneWidget);
    expect(find.text('3. seviye'), findsOneWidget);
    // 5. seviye Wizard: 4/3/2
    expect(find.text('4/4'), findsOneWidget);
    expect(find.text('3/3'), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);

    await unmount(tester);
  });

  group('can takibi', () {
    test('hasar once gecici cani tuketir', () async {
      await repo.setTemporaryHitPoints(id, 5);
      await repo.applyDamage(id, 8);

      final c = (await repo.find(id))!;
      expect(c.temporaryHitPoints, 0);
      expect(c.hitPointsCurrent, 19); // 22 - (8 - 5)
    });

    test('gecici can toplanmaz, yuksek olan gecerli', () async {
      await repo.setTemporaryHitPoints(id, 5);
      await repo.setTemporaryHitPoints(id, 3);
      expect((await repo.find(id))!.temporaryHitPoints, 5);

      await repo.setTemporaryHitPoints(id, 9);
      expect((await repo.find(id))!.temporaryHitPoints, 9);
    });

    test('can sifirin altina inmez', () async {
      await repo.applyDamage(id, 100);
      expect((await repo.find(id))!.hitPointsCurrent, 0);
    });

    test('iyilesme azami cani asmaz ve olum atislarini sifirlar', () async {
      await repo.applyDamage(id, 22);
      await repo.setDeathSaves(id, successes: 2, failures: 1);

      await repo.applyHealing(id, 100);
      final c = (await repo.find(id))!;
      expect(c.hitPointsCurrent, 22);
      expect(c.deathSaveSuccesses, 0);
      expect(c.deathSaveFailures, 0);
    });
  });

  testWidgets('tukenmislik d20 degerlerini dusurur', (tester) async {
    await repo.setExhaustion(id, 2);
    await pump(tester);

    // Arcana +6 iken tukenmislik 2 ile +4 olmali.
    expect(find.text('+6'), findsNothing);
    expect(find.text('+4'), findsWidgets);
    expect(find.textContaining('Tüm d20 testlerine 2 ceza'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('can sifirken olum kurtarma atislari belirir', (tester) async {
    await repo.applyDamage(id, 22);
    await pump(tester);

    expect(find.text('Ölüm kurtarma atışları'), findsOneWidget);
    expect(find.text('Başarılı'), findsOneWidget);

    await unmount(tester);
  });
}
