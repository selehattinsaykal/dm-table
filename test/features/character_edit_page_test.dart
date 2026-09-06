import 'package:dm_table/data/character_repository.dart';
import 'package:dm_table/data/db/character_tables.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/import/asset_importer.dart';
import 'package:dm_table/data/providers.dart';
import 'package:dm_table/domain/models/ability.dart';
import 'package:dm_table/features/characters/character_edit_page.dart';
import 'package:dm_table/features/characters/character_sheet_page.dart';
import 'package:dm_table/l10n/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Karakteri yarattiktan sonra duzenleme ekrani.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CharacterRepository repo;
  const id = 'edit-test';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await AssetImporter(db).importIfNeeded();
    repo = CharacterRepository(db);
    await repo.createLevelOneCharacter(
      id: id,
      name: 'Vex',
      classKey: 'srd-2024_wizard',
      speciesKey: 'srd-2024_elf',
      backgroundKey: 'srd-2024_acolyte',
      abilities: const AbilityScores(intelligence: 16),
      savingThrows: {Ability.intelligence, Ability.wisdom},
      skills: {Skill.arcana},
      hitDieSides: 6,
    );
  });

  tearDown(() async => db.close());

  Widget app(Widget home) => ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: const [
        L10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: L10n.supportedLocales,
      home: home,
    ),
  );

  Future<void> settle(WidgetTester tester, Finder until) async {
    for (var i = 0; i < 100 && until.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    if (until.evaluate().isEmpty) fail('Ekran acilmadi');
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  Future<void> openEditor(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(const CharacterEditPage(characterId: id)));
    await settle(tester, find.text('Kimlik'));
  }

  testWidgets('ad ve yetenek puani degistirilip kaydedilir', (tester) async {
    await openEditor(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ad'),
      'Vex Kararmış',
    );
    // CON satirindaki artir dugmesi: 10 -> 12.
    final conRow = find.ancestor(
      of: find.text('Dayanıklılık'),
      matching: find.byType(Row),
    );
    await tester.tap(
      find.descendant(
        of: conRow.first,
        matching: find.byIcon(Icons.add_circle_outline),
      ),
    );
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: conRow.first,
        matching: find.byIcon(Icons.add_circle_outline),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Kaydet'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    final character = (await repo.find(id))!;
    expect(character.name, 'Vex Kararmış');
    expect(character.constitution, 12);
    // 1. seviye Wizard: d6 (6) + CON modifieri (+1).
    expect(character.hitPointsMax, 7);

    await unmount(tester);
  });

  testWidgets('kaydetmeden cikilinca hicbir sey degismez', (tester) async {
    await openEditor(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'Ad'), 'Yanlış');
    await tester.pump();
    await unmount(tester);

    expect((await repo.find(id))!.name, 'Vex');
  });

  testWidgets('ad bos birakilirsa kaydedilmez', (tester) async {
    await openEditor(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'Ad'), '   ');
    await tester.tap(find.text('Kaydet'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Ad boş olamaz'), findsOneWidget);
    expect((await repo.find(id))!.name, 'Vex');

    await unmount(tester);
  });

  testWidgets('kagittaki isarete dokununca yeterlilik degisir', (tester) async {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app(const CharacterSheetPage(characterId: id)));
    await settle(tester, find.text('Beceriler'));

    // Gizlilik satirindaki bos daire: yok -> yeterli.
    final stealthRow = find.ancestor(
      of: find.text('Gizlilik'),
      matching: find.byType(Row),
    );
    await tester.tap(
      find.descendant(
        of: stealthRow.first,
        matching: find.byIcon(Icons.circle_outlined),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final profs = await repo.proficiencies(id);
    expect(
      profs.where(
        (p) => p.kind == ProficiencyKind.skill && p.value == Skill.stealth.name,
      ),
      hasLength(1),
    );

    await unmount(tester);
  });
}
