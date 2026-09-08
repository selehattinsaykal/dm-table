import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/providers.dart';
import 'package:dm_table/features/world/graph_interaction.dart';
import 'package:dm_table/features/world/world_graph_page.dart';
import 'package:dm_table/l10n/app_localizations.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dunya grafiginde IKI DUGUMU BAGLAMA akisi, ucdan uca.
///
/// **Bu dosya neden var:** baglama mantiginin saf parcalari
/// (`graph_interaction_test.dart`) gecerken ozelligin kendisi calismiyordu.
/// Saf mantigi test etmek yetmiyor -- hata isaretci olaylarinin o mantiga
/// BAGLANMA seklindeydi. Burasi gercek widget'i surup gercek dokunuslar
/// gonderiyor ve veritabaninda kenar olusmasini bekliyor.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  /// Dugumler sabit dunya koordinatlarina konuyor ki dokunulacak ekran
  /// noktasi hesaplanabilsin; konum bos birakilsa simulasyon rastgele
  /// dizerdi.
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db
        .into(db.locations)
        .insert(
          LocationsCompanion.insert(
            id: 'loc-a',
            name: 'Kale',
            graphX: const Value(-150),
            graphY: const Value(0),
          ),
        );
    await db
        .into(db.locations)
        .insert(
          LocationsCompanion.insert(
            id: 'loc-b',
            name: 'Köy',
            graphX: const Value(150),
            graphY: const Value(0),
          ),
        );
    await db
        .into(db.locations)
        .insert(
          LocationsCompanion.insert(
            id: 'loc-c',
            name: 'Değirmen',
            graphX: const Value(0),
            graphY: const Value(200),
          ),
        );
  });

  tearDown(() async => db.close());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
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
          home: Scaffold(body: WorldGraph()),
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
  }

  /// Dunya koordinatindaki bir noktanin ekran karsiligi.
  ///
  /// Grafik ilk yerlesimde `_pan`i tuvalin merkezine koyuyor ve `_scale` 1;
  /// yani dunya (0,0) tuvalin ortasi.
  Offset screenOf(WidgetTester tester, Offset world) {
    final box = tester.getRect(find.byType(WorldGraph));
    return box.center + world;
  }

  Future<void> enableLinkMode(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilterChip, 'Bağla'));
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Dokunmatik bir dokunus: basma ve birakma arasinda KUCUK bir titreme
  /// var, tipki gercek bir parmakta oldugu gibi. Hatanin can alici yeri
  /// buydu -- titremesiz bir dokunus sorunu gizliyor.
  Future<void> tapNode(WidgetTester tester, Offset world) async {
    final at = screenOf(tester, world);
    final gesture = await tester.startGesture(
      at,
      kind: PointerDeviceKind.touch,
    );
    await tester.pump(const Duration(milliseconds: 20));
    await gesture.moveTo(at + const Offset(4, 3));
    await tester.pump(const Duration(milliseconds: 20));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 60));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets('baglama modunda iki dugume dokunmak kenar olusturur', (
    tester,
  ) async {
    await pump(tester);
    await enableLinkMode(tester);

    await tapNode(tester, const Offset(-150, 0));
    await tapNode(tester, const Offset(150, 0));
    await tester.pump(const Duration(milliseconds: 200));

    final links = await db.select(db.worldLinks).get();
    expect(links, hasLength(1), reason: 'iki dokunus bir kenar yapmali');
    expect({links.single.aId, links.single.bId}, {'loc-a', 'loc-b'});

    await unmount(tester);
  });

  testWidgets('IKINCI bag da kurulur ve cizilir', (tester) async {
    // GERILEME TESTI. Kenar eleme anahtari her kenar icin ayni sabit metni
    // uretiyordu, yani grafikte YALNIZCA ILK kenar goruluyordu. Ilk bag
    // calistigi icin tek bagli bir test bunu kacirir; hata ancak IKINCI
    // bagda ortaya cikiyor -- kullanicinin gordugu de tam olarak buydu.
    await pump(tester);
    await enableLinkMode(tester);

    await tapNode(tester, const Offset(-150, 0));
    await tapNode(tester, const Offset(150, 0));
    await tester.pump(const Duration(milliseconds: 200));

    await tapNode(tester, const Offset(150, 0));
    await tapNode(tester, const Offset(0, 200));
    await tester.pump(const Duration(milliseconds: 200));

    final links = await db.select(db.worldLinks).get();
    expect(links, hasLength(2), reason: 'iki ayri bag kurulmali');

    // Cizim tarafi da ikisini birden gormeli: veritabaninda olup ekranda
    // gorunmeyen bir bag kullanici icin "baglanmadi" demek.
    final drawn = collapseGraphEdges(
      edges: [for (final l in links) (aId: l.aId, bId: l.bId, type: l.type)],
      representative: const {},
    );
    expect(drawn, hasLength(2));

    await unmount(tester);
  });

  testWidgets('baglama modu KAPALIYKEN dokunmak kenar olusturmaz', (
    tester,
  ) async {
    await pump(tester);

    await tapNode(tester, const Offset(-150, 0));
    await tapNode(tester, const Offset(150, 0));
    await tester.pump(const Duration(milliseconds: 200));

    expect(await db.select(db.worldLinks).get(), isEmpty);
    await unmount(tester);
  });

  testWidgets('ayni dugume iki kez dokunmak secimi birakir', (tester) async {
    await pump(tester);
    await enableLinkMode(tester);

    await tapNode(tester, const Offset(-150, 0));
    await tapNode(tester, const Offset(-150, 0));
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      await db.select(db.worldLinks).get(),
      isEmpty,
      reason: 'dugum kendisiyle baglanamaz',
    );
    await unmount(tester);
  });

  testWidgets('tuvali kaydirmak secili ilk dugumu kaybetmez', (tester) async {
    await pump(tester);
    await enableLinkMode(tester);

    await tapNode(tester, const Offset(-150, 0));

    // Bos alanda gercek bir kaydirma: birakmayi "dokunus" sayan eski hesap
    // burada secimi sessizce temizliyordu.
    final start = screenOf(tester, const Offset(0, 300));
    final drag = await tester.startGesture(
      start,
      kind: PointerDeviceKind.touch,
    );
    await tester.pump(const Duration(milliseconds: 20));
    await drag.moveTo(start + const Offset(0, -60));
    await tester.pump(const Duration(milliseconds: 20));
    await drag.up();
    await tester.pump(const Duration(milliseconds: 60));

    // Secim durduysa ikinci dugume dokunmak kenari tamamlar. Kaydirma
    // dunyayi da kaydirdigi icin hedefi ayni kaydirma kadar dusuruyoruz.
    await tapNode(tester, const Offset(150, -60));
    await tester.pump(const Duration(milliseconds: 200));

    expect(await db.select(db.worldLinks).get(), hasLength(1));
    await unmount(tester);
  });
}
