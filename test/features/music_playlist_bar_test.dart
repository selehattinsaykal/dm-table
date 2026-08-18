import 'dart:io';

import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/music_repository.dart';
import 'package:dm_table/data/music_store.dart';
import 'package:dm_table/features/music/music_controller.dart';
import 'package:dm_table/features/music/music_page.dart';
import 'package:dm_table/l10n/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Liste cubugu: bos alana sag tiklayinca "liste olustur" menusu cikmali.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory tmp;
  late MusicRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('dm_music_bar');
    repo = MusicRepository(db, store: MusicStore(directoryOverride: tmp));
  });

  tearDown(() async {
    await db.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<void> setUpData(WidgetTester tester, Future<void> Function() body) =>
      tester.runAsync(body).then((_) {});

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [musicRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: const [
            L10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: L10n.supportedLocales,
          // GERCEK yapiyi taklit ediyor: uygulama `StatefulShellRoute` ile
          // her sekmeye AYRI Navigator (dolayisiyla ayri Overlay) veriyor ve
          // solda gezinme menusu var. Overlay bu yuzden saga kaymis oluyor;
          // menuyu ekran koordinatiyla konumlandirmak tam o kadar kaydirir.
          // Duz `home: MusicPage()` bu hatayi HIC yakalayamazdi.
          home: Row(
            children: [
              const SizedBox(width: 250, child: ColoredBox(color: Colors.grey)),
              Expanded(
                child: Navigator(
                  onGenerateRoute: (_) => MaterialPageRoute<void>(
                    builder: (_) => const MusicPage(),
                  ),
                ),
              ),
            ],
          ),
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

  /// Verilen noktaya SAG tik gonderir (fare, ikincil dugme).
  Future<void> rightClick(WidgetTester tester, Offset position) async {
    final gesture = await tester.startGesture(
      position,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    // `pumpAndSettle` KULLANILMIYOR: sayfada surekli donen animasyonlar
    // (calar cubugu vb.) oldugunda hic durulmayip testi kilitliyor.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  testWidgets('kok satirin bos alanina sag tik "Yeni liste" cikarir', (
    tester,
  ) async {
    await setUpData(tester, () async {
      await repo.createPlaylist('Savas');
    });
    await pump(tester);

    // "Savas" cipinin SAGINDAKI bos alan: cipin sag kenarindan epey oteye.
    final chip = tester.getTopRight(find.text('Savas'));
    await rightClick(tester, Offset(chip.dx + 300, chip.dy + 8));

    expect(find.text('Yeni liste'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets(
    'cipin uzerine sag tik liste menusunu acar, ekleme menusunu degil',
    (tester) async {
      await setUpData(tester, () async {
        await repo.createPlaylist('Savas');
      });
      await pump(tester);

      await rightClick(tester, tester.getCenter(find.text('Savas')));

      // Cipin kendi menusu: yeniden adlandir + alt liste + sil.
      expect(find.text('Listeyi yeniden adlandır'), findsOneWidget);
      await unmount(tester);
    },
  );

  testWidgets('menu tiklanan noktanin YANINDA acilir, uzagina degil', (
    tester,
  ) async {
    await setUpData(tester, () async {
      await repo.createPlaylist('Savas');
    });
    await pump(tester);

    // Nokta cipten TURETILIYOR: sabit bir koordinat AppBar'a denk gelebilir.
    final chip = tester.getTopRight(find.text('Savas'));
    final tap = Offset(chip.dx + 60, chip.dy + 8);
    await rightClick(tester, tap);

    // Menu kutusunun sol ust kosesi tiklanan noktaya yakin olmali.
    // `RelativeRect.fromLTRB(dx,dy,dx,dy)` hatasi menuyu yuzlerce piksel
    // saga kaydiriyordu; bu test onu yakalar.
    final menu = tester.getTopLeft(find.text('Yeni liste'));
    expect(
      (menu.dx - tap.dx).abs(),
      // Duzeltmeyle sapma ~38px, `globalToLocal` olmadan 64px+ olcüldü;
      // esik ikisini ayiracak sekilde secildi.
      lessThan(50),
      reason: 'menu yatayda imlecten uzak: $menu vs $tap',
    );
    expect((menu.dy - tap.dy).abs(), lessThan(50), reason: 'dikeyde uzak');
    await unmount(tester);
  });

  testWidgets('secili kok liste varken kok satirdan alt liste eklenebilir', (
    tester,
  ) async {
    await setUpData(tester, () async {
      await repo.createPlaylist('Savas');
    });
    await pump(tester);

    // Kok listeyi sec, sonra bos alana sag tikla.
    await tester.tap(find.text('Savas'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    final chip = tester.getTopRight(find.text('Savas'));
    await rightClick(tester, Offset(chip.dx + 300, chip.dy + 8));

    // Alt satir henuz YOK (hic alt liste yok) ama yine de eklenebilmeli.
    expect(find.textContaining('Yeni alt liste'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('kategori secilince alt listeler dikey bolum olarak cikar', (
    tester,
  ) async {
    await setUpData(tester, () async {
      final savas = await repo.createPlaylist('Savas');
      await repo.createPlaylist('Boss', parentId: savas);
      await repo.createPlaylist('Normal Savas', parentId: savas);
    });
    await pump(tester);

    await tester.tap(find.text('Savas'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    // Iki alt liste de bolum basligi olarak gorunmeli (cip DEGIL).
    expect(find.text('Boss'), findsOneWidget);
    expect(find.text('Normal Savas'), findsOneWidget);
    // Kapaliyken sag ok, acikken asagi ok.
    expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));
    await unmount(tester);
  });

  testWidgets('kategori govdesinde parcalarin ALTINDAKI bosluga sag tik', (
    tester,
  ) async {
    await setUpData(tester, () async {
      final savas = await repo.createPlaylist('Savas');
      await repo.createPlaylist('Boss', parentId: savas);
    });
    await pump(tester);

    await tester.tap(find.text('Savas'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    // "Boss" bolumunun EPEY altindaki bos alan. `ListView` kaydirilabilir
    // alani olaylari yutar; `SliverFillRemaining` olmadan bu test kalirdi.
    final section = tester.getBottomLeft(find.text('Boss'));
    await rightClick(tester, Offset(section.dx + 120, section.dy + 200));

    expect(find.text('Yeni alt liste'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets(
    'kategori adi govdede TEKRAR yazmiyor (cip cubugunda zaten var)',
    (tester) async {
      await setUpData(tester, () async {
        final savas = await repo.createPlaylist('Savas');
        await repo.createPlaylist('Boss', parentId: savas);
      });
      await pump(tester);

      await tester.tap(find.text('Savas'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      // Yalnizca cip; govdede ikinci bir "Savas" basligi olmamali.
      expect(find.text('Savas'), findsOneWidget);
      await unmount(tester);
    },
  );

  testWidgets('alt liste basligina basinca parcalari asagi acilir', (
    tester,
  ) async {
    await setUpData(tester, () async {
      final savas = await repo.createPlaylist('Savas');
      final boss = await repo.createPlaylist('Boss', parentId: savas);
      final source = File(p.join(tmp.path, 'kaynak.mp3'))
        ..writeAsBytesSync([1, 2, 3]);
      await repo.addTrack(source, title: 'Epic Boss Battle', playlistId: boss);
    });
    await pump(tester);

    await tester.tap(find.text('Savas'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    // Kapaliyken parca gorunmuyor.
    expect(find.text('Epic Boss Battle'), findsNothing);

    await tester.tap(find.text('Boss'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(find.text('Epic Boss Battle'), findsOneWidget);
    await unmount(tester);
  });
}
