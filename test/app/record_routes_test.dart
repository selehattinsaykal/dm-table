import 'package:dm_table/app/router.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/providers.dart';
import 'package:dm_table/l10n/app_localizations.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kayit rotalari: `/npcs/<id>` gibi bir yol DOGRUDAN o kaydi acmali.
///
/// **Bu dosya neden var:** komut paleti eskiden yalnizca sekmeye
/// goturuyordu ("Gundren" arayip NPC listesinde kaybolmak) cunku kimlikli
/// rota yoktu. Rotalar `app/router.dart` icinde dalin ALT rotasi olarak
/// duruyor; bir dalin `routes:` listesini silmek uygulamayi derlemeye devam
/// eder ve yalnizca palet sessizce eski davranisa doner. Bu test tam olarak
/// onu kilitliyor.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db
        .into(db.npcs)
        .insert(NpcsCompanion.insert(id: 'npc-1', name: 'Gundren Rockseeker'));
    await db
        .into(db.locations)
        .insert(
          LocationsCompanion.insert(id: 'loc-1', name: 'Yeşil Fener Hanı'),
        );
    await db
        .into(db.quests)
        .insert(
          QuestsCompanion.insert(
            id: 'quest-1',
            title: const Value('Kayıp kervan'),
          ),
        );
    await db
        .into(db.shops)
        .insert(ShopsCompanion.insert(id: 'shop-1', name: 'Barthen Deposu'));
    await db
        .into(db.encounters)
        .insert(EncountersCompanion.insert(id: 'enc-1', name: 'Goblin pususu'));
  });

  tearDown(() async => db.close());

  Future<void> pumpAt(WidgetTester tester, String location) async {
    // Kayit sayfalari genis; dar bir tuvalde baslik satiri tasip testi
    // gorunmez kiliyor.
    tester.view.physicalSize = const Size(1400, 1000);
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
          routerConfig: buildRouter(initialLocation: location),
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
  }

  /// Zamanlayici denetimi test GOVDESI biter bitmez calisiyor; sokme
  /// teardown'a birakilamaz (bkz. `shell_nav_test.dart`).
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets('/npcs/<id> NPC detayini acar', (tester) async {
    await pumpAt(tester, '/npcs/npc-1');
    expect(find.text('Gundren Rockseeker'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('/world/<id> yer sayfasini acar', (tester) async {
    await pumpAt(tester, '/world/loc-1');
    expect(find.text('Yeşil Fener Hanı'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('/quests/<id> gorev sayfasini acar', (tester) async {
    await pumpAt(tester, '/quests/quest-1');
    expect(find.text('Kayıp kervan'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('/shops/<id> dukkan sayfasini acar', (tester) async {
    await pumpAt(tester, '/shops/shop-1');
    expect(find.text('Barthen Deposu'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('/combat/<id> karsilasmayi acar', (tester) async {
    await pumpAt(tester, '/combat/enc-1');
    expect(find.text('Goblin pususu'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('kayit rotasi YAN RAYI korur', (tester) async {
    // Kayit dalin kendi navigator'inda aciliyor; kabuk yerinde kalmali,
    // yoksa derin baglantiyla gelen DM baska bir sekmeye gecemez.
    await pumpAt(tester, '/npcs/npc-1');
    expect(find.byType(NavigationRail), findsWidgets);
    await unmount(tester);
  });
}
