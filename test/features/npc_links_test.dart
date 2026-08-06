import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/db/world_tables.dart';
import 'package:dm_table/data/shop_repository.dart';
import 'package:dm_table/data/world_repository.dart';
import 'package:dm_table/features/shops/shop_providers.dart';
import 'package:dm_table/features/world/npc_detail_page.dart';
import 'package:dm_table/features/world/world_providers.dart';
import 'package:dm_table/l10n/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// NPC kartindaki "Geçtiği yerler" bolumu: harita pinleri + islettigi
/// magazalar. `backlinksProvider` uzun sure HIC kullanilmiyordu (veri vardi,
/// yuzeyi yoktu); bu test iki bagin da gorundugunu kilitler.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late WorldRepository world;
  late ShopRepository shops;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    world = WorldRepository(db);
    shops = ShopRepository(db);
  });

  tearDown(() async => db.close());

  Future<void> pump(WidgetTester tester, String npcId) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          worldRepositoryProvider.overrideWithValue(world),
          shopRepositoryProvider.overrideWithValue(shops),
        ],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: const [
            L10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: L10n.supportedLocales,
          home: NpcDetailPage(npcId: npcId),
        ),
      ),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets('bagsiz NPC bos durum metnini gosterir', (tester) async {
    late String npcId;
    await tester.runAsync(() async {
      npcId = await world.createNpc(name: 'Yalnız Adam');
    });

    await pump(tester, npcId);
    expect(find.text(L10nTr.noLinks), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('harita pini ve islettigi magaza listelenir', (tester) async {
    late String npcId;
    await tester.runAsync(() async {
      npcId = await world.createNpc(name: 'Yaşlı Meryem');
      final locId = await world.createLocation(name: 'Kuytu Köy');
      await world.addPin(
        locationId: locId,
        x: 0.4,
        y: 0.5,
        kind: PinKind.npc,
        label: 'Simya dükkânı',
        targetId: npcId,
      );
      await shops.create(
        name: 'Meryem’in İksirleri',
        ownerName: 'Yaşlı Meryem',
        ownerNpcId: npcId,
      );
    });

    await pump(tester, npcId);

    expect(find.text('Kuytu Köy'), findsOneWidget);
    expect(find.text('Meryem’in İksirleri'), findsOneWidget);

    await unmount(tester);
  });
}

/// Testte beklenen Turkce metin (ARB ile ayni kalmali).
abstract final class L10nTr {
  static const noLinks =
      'Henüz bir haritaya bağlı değil. Bir yerin haritasında NPC pini '
      'ekleyerek bağlayabilirsin.';
}
