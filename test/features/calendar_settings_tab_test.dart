import 'package:dm_table/data/calendar_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/providers.dart';
import 'package:dm_table/features/calendar/calendar_settings_tab.dart';
import 'package:dm_table/l10n/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regresyon: alan alandan alana DOĞRUDAN geçildiğinde ("Ocak" günü ->
/// "Era label" gibi) odak-kaybında-kaydet düzeni sessizce veri kaybetmemeli.
///
/// Kök neden buradaydı: `_MonthRow`/`_NameRow` `onTapOutside` ile kaydediyordu;
/// bu callback, dışarıdaki tıklama BAŞKA BİR TextField'a doğrudan odak
/// verdiğinde güvenilir şekilde tetiklenmiyor. `_TextSetting` (takvim adı/çağ/
/// yıl eki) zaten güvenilir olan FocusNode-dinleyici düzenini kullanıyordu;
/// diğer ikisi de aynı düzene geçirildi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppDatabase> seeded() async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = CalendarRepository(db);
    await repo.config();
    await repo.addMonth('Ocak', 30);
    await repo.addMonth('Subat', 28);
    await repo.addSeason(
      name: 'Kis',
      color: 0x11111111,
      startMonthIndex: 0,
      startDay: 1,
      endMonthIndex: 0,
      endDay: 10,
    );
    return db;
  }

  Future<void> pumpTab(WidgetTester tester, AppDatabase db) async {
    tester.view.physicalSize = const Size(1000, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: const [
            L10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: L10n.supportedLocales,
          home: const Scaffold(body: CalendarSettingsTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'ay gun sayisi: baska bir TextField\'a dogrudan gecince de kalici olur',
    (tester) async {
      final db = await seeded();
      final repo = CalendarRepository(db);
      await pumpTab(tester, db);

      // TextField sirasi: takvim adi/cag/yil eki/cag-oncesi eki (4) + Ocak ad/gun + Subat ad/gun.
      final ocakDays = find.byType(TextField).at(5);
      expect(tester.widget<TextField>(ocakDays).controller!.text, '30');

      await tester.enterText(ocakDays, '31');
      // Kritik adim: baska bir NOTR alana degil, DOGRUDAN baska bir
      // TextField'a geciliyor (kullanicinin gercekte yaptigi sey).
      await tester.tap(find.widgetWithText(TextField, 'Era label'));
      await tester.pump();

      expect(
        (await repo.months()).firstWhere((m) => m.name == 'Ocak').days,
        31,
      );
      await db.close();
    },
  );

  testWidgets(
    'hafta gunu adi: baska bir TextField\'a dogrudan gecince de kalici olur',
    (tester) async {
      final db = await seeded();
      final repo = CalendarRepository(db);
      await repo.addWeekday('Birgun');
      await pumpTab(tester, db);

      final weekdayField = find.widgetWithText(TextField, 'Birgun');
      await tester.enterText(weekdayField, 'Ayzegun');
      await tester.tap(find.widgetWithText(TextField, 'Era label'));
      await tester.pump();

      expect((await repo.weekdays()).single.name, 'Ayzegun');
      await db.close();
    },
  );

  testWidgets('mevsim duzenleme: ad + renk + tarih hep birlikte kalici olur', (
    tester,
  ) async {
    final db = await seeded();
    final repo = CalendarRepository(db);
    await pumpTab(tester, db);

    final seasonCard = find.ancestor(
      of: find.text('Kis'),
      matching: find.byType(Card),
    );
    await tester.tap(
      find.descendant(of: seasonCard, matching: find.byType(IconButton)).first,
    );
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);

    await tester.enterText(
      find.descendant(of: dialog, matching: find.byType(TextField)),
      'Kis Mevsimi',
    );
    // Ikinci palet rengine tikla (varsayilandan farkli).
    await tester.tap(
      find.descendant(of: dialog, matching: find.byType(GestureDetector)).at(1),
    );
    await tester.pump();
    await tester.tap(
      find.descendant(of: dialog, matching: find.byType(FilledButton)),
    );
    await tester.pumpAndSettle();

    final season = (await repo.seasons()).single;
    expect(season.name, 'Kis Mevsimi');
    expect(season.color, 0xFFD9A441);
    // Tarih alanlarina dokunulmadi; oldugu gibi kalmali.
    expect(season.startMonthIndex, 0);
    expect(season.startDay, 1);
    expect(season.endMonthIndex, 0);
    expect(season.endDay, 10);

    await db.close();
  });

  testWidgets(
    'birden fazla alan ust uste, birbirine dogrudan gecerek duzenlenince '
    'hicbiri kaybolmaz',
    (tester) async {
      final db = await seeded();
      final repo = CalendarRepository(db);
      await pumpTab(tester, db);

      await tester.enterText(
        find.widgetWithText(TextField, 'Calendar name'),
        'Yeni Takvim',
      );
      await tester.tap(find.widgetWithText(TextField, 'Era label'));
      await tester.pump();

      final ocakDays = find.byType(TextField).at(5);
      await tester.enterText(ocakDays, '31');
      await tester.tap(find.widgetWithText(TextField, 'Era label'));
      await tester.pump();

      final seasonCard = find.ancestor(
        of: find.text('Kis'),
        matching: find.byType(Card),
      );
      await tester.tap(
        find
            .descendant(of: seasonCard, matching: find.byType(IconButton))
            .first,
      );
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      await tester.enterText(
        find.descendant(of: dialog, matching: find.byType(TextField)),
        'Kis Mevsimi',
      );
      await tester.tap(
        find
            .descendant(of: dialog, matching: find.byType(GestureDetector))
            .at(2),
      );
      await tester.pump();
      await tester.tap(
        find.descendant(of: dialog, matching: find.byType(FilledButton)),
      );
      await tester.pumpAndSettle();

      final config = await repo.config();
      final months = await repo.months();
      final season = (await repo.seasons()).single;

      expect(config.calendarName, 'Yeni Takvim');
      expect(months.firstWhere((m) => m.name == 'Ocak').days, 31);
      expect(season.name, 'Kis Mevsimi');

      await db.close();
    },
  );
}
