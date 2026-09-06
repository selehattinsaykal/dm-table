import 'dart:convert';

import 'package:dm_table/data/codex_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/providers.dart';
import 'package:dm_table/domain/codex/codex_block.dart';
import 'package:dm_table/features/codex/codex_document_page.dart';
import 'package:dm_table/l10n/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kayitlar belgesi: HER blok turu hem goruntule hem duzenle modunda
/// cizilebilmeli. Duzenleme modunda blogun ustunde arac cubugu, kenarlarinda
/// boyutlandirma tutamaklari var — bu testin asil isi oradaki tasma/cokme
/// hatalarini yakalamak.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CodexRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = CodexRepository(db);
  });
  tearDown(() async => db.close());

  /// Hazirlik GERCEK asenkron is (sqlite isolate'i). `testWidgets` sahte
  /// zamanda calistigi icin dogrudan await kilitlenmeye yol acar.
  Future<T> real<T>(WidgetTester tester, Future<T> Function() body) async {
    late T out;
    await tester.runAsync(() async => out = await body());
    return out;
  }

  Future<String> seedPage() async {
    final page = await repo.createPage(title: 'Han');
    await repo.addBlock(
      page,
      CodexBlockType.heading,
      data: {
        'text': 'Yeşil Ejder Hanı',
        'level': 1,
        'rule': true,
        'tone': 'gold',
      },
    );
    await repo.addBlock(
      page,
      CodexBlockType.text,
      data: {
        'text': 'Kapıdan içeri girdiğinde duman ve arpa kokusu çarpar.',
        'dropCap': true,
        'size': 1.2,
        'width': 0.6,
        'align': 'center',
      },
    );
    await repo.addBlock(
      page,
      CodexBlockType.bulleted,
      data: {
        'items': ['Hancı Mira', 'Sarhoş asker'],
        'ordered': true,
      },
    );
    await repo.addBlock(
      page,
      CodexBlockType.checklist,
      data: {
        'items': [
          {'text': 'Odayı tut', 'done': true},
          {'text': 'Atı nallat', 'done': false},
        ],
        'progress': true,
      },
    );
    await repo.addBlock(
      page,
      CodexBlockType.callout,
      data: {'emoji': '⚠', 'text': 'Mahzende bir şey var.', 'tone': 'danger'},
    );
    await repo.addBlock(
      page,
      CodexBlockType.divider,
      data: {'style': 'dashed'},
    );
    await repo.addBlock(
      page,
      CodexBlockType.table,
      data: {
        'header': true,
        'zebra': true,
        'rows': [
          ['Oda', 'Fiyat'],
          ['Ortak', '5 bakır'],
        ],
      },
    );
    await repo.addBlock(
      page,
      CodexBlockType.chart,
      data: {
        'title': 'Kasa',
        'type': 'donut',
        'items': [
          {'label': 'Altın', 'value': 30},
          {'label': 'Gümüş', 'value': 12},
        ],
        'width': 0.5,
        'align': 'right',
        'height': 200,
      },
    );
    await repo.addBlock(
      page,
      CodexBlockType.counter,
      data: {
        'title': 'Kaynaklar',
        'style': 'chip',
        'items': [
          {'label': 'Meşale', 'value': 4, 'min': 0, 'max': 6, 'step': 1},
        ],
      },
    );
    await repo.addBlock(
      page,
      CodexBlockType.timer,
      data: {
        'title': 'Tur süresi',
        'mode': 'countdown',
        'duration': 30,
        'style': 'bar',
      },
    );
    await repo.addBlock(
      page,
      CodexBlockType.dice,
      data: {'label': 'Dedikodu', 'expression': '1d6', 'chipStyle': 'card'},
    );
    await repo.addBlock(
      page,
      CodexBlockType.link,
      data: {'url': 'example.com', 'label': 'Harita', 'chipStyle': 'button'},
    );
    // Yolu olmayan medya: dosya sistemine dokunmadan bos durum cizilir.
    await repo.addBlock(page, CodexBlockType.image, data: {'path': null});
    await repo.addBlock(page, CodexBlockType.video, data: {'path': null});
    return page;
  }

  Future<void> pump(
    WidgetTester tester,
    String pageId, {
    double width = 1280,
  }) async {
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
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
          home: CodexDocumentPage(pageId: pageId),
        ),
      ),
    );
    // Blok akisi birkac kare sonra gelir (drift stream).
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  /// Drift stream'i test bitmeden birakilirsa "Pending timers" hatasi verir.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets('tum blok turleri goruntule modunda cizilir', (tester) async {
    final page = await real(tester, seedPage);
    await pump(tester, page);

    expect(tester.takeException(), isNull);
    expect(find.text('Yeşil Ejder Hanı'), findsOneWidget);
    expect(find.text('Kasa'), findsOneWidget);
    expect(find.text('Kaynaklar'), findsOneWidget);
    // Onay listesi ilerlemesi: 1/2 tamam.
    expect(find.textContaining('1/2'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('sayac goruntule modunda aninda kaydedilir', (tester) async {
    final page = await real(tester, () async {
      final id = await repo.createPage();
      await repo.addBlock(
        id,
        CodexBlockType.counter,
        data: {
          'title': 'Meşaleler',
          'items': [
            {'label': 'Meşale', 'value': 2, 'min': 0, 'max': 5, 'step': 1},
          ],
        },
      );
      return id;
    });
    await pump(tester, page);

    await tester.tap(find.byIcon(Icons.remove));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    final rows = await real(tester, () => repo.blocks(page));
    expect(rows.single.dataJson, contains('"value":1'));
    await unmount(tester);
  });

  testWidgets('sure sayaci baslatilinca baslama ani kaydedilir', (
    tester,
  ) async {
    final page = await real(tester, () async {
      final id = await repo.createPage();
      await repo.addBlock(
        id,
        CodexBlockType.timer,
        data: {'title': 'Tur süresi', 'duration': 60},
      );
      return id;
    });
    await pump(tester, page);

    expect(find.text('01:00'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.play_arrow));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    final running = (await real(tester, () => repo.blocks(page))).single;
    final started =
        (jsonDecode(running.dataJson) as Map<String, dynamic>)['startedAt'];
    expect(started, isNotNull, reason: 'baslama ani kalici olmali');

    // Duraklatinca baslama ani ACIKCA temizlenmeli; kalirsa sayac arka
    // planda islemeye devam ediyormus gibi gorunur.
    await tester.tap(find.byIcon(Icons.pause));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    final paused = (await real(tester, () => repo.blocks(page))).single;
    expect(
      (jsonDecode(paused.dataJson) as Map<String, dynamic>)['startedAt'],
      isNull,
    );
    await unmount(tester);
  });

  testWidgets('duzenleme modunda arac cubugu ve tutamaklar gelir', (
    tester,
  ) async {
    final page = await real(tester, seedPage);
    await pump(tester, page);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(tester.takeException(), isNull);
    // Her blok icin bir suruklu tutamak + hizalama dugmeleri.
    expect(find.byIcon(Icons.drag_indicator), findsWidgets);
    expect(find.byIcon(Icons.format_align_center), findsWidgets);
    await unmount(tester);
  });

  testWidgets('dar pencerede duzenleme arac cubugu tasmaz', (tester) async {
    final page = await real(tester, seedPage);
    await pump(tester, page, width: 620);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('arac cubugundan hizalama degistirmek icerigi bozmaz', (
    tester,
  ) async {
    final page = await real(tester, () async {
      final id = await repo.createPage();
      await repo.addBlock(id, CodexBlockType.text, data: {'text': 'Merhaba'});
      return id;
    });
    await pump(tester, page);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.tap(find.byIcon(Icons.format_align_center));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    final json = (await real(tester, () => repo.blocks(page))).single.dataJson;
    expect(json, contains('"align":"center"'));
    // Icerik korunur (yerlesim degisikligi metni ezmez).
    expect(json, contains('Merhaba'));
    await unmount(tester);
  });

  testWidgets('sag kenari surukleyince genislik kaydedilir', (tester) async {
    final page = await real(tester, () async {
      final id = await repo.createPage();
      await repo.addBlock(id, CodexBlockType.image, data: {'path': null});
      return id;
    });
    await pump(tester, page);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    // Sag kenardan sola surukle: blok daralmali (oran olarak saklanir).
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('codexResize-right'))),
    );
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    final data = (await real(tester, () => repo.blocks(page))).single.dataJson;
    final width = (jsonDecode(data) as Map<String, dynamic>)['width'] as num?;
    expect(width, isNotNull, reason: 'kenar surukleme genisligi yazmali');
    expect(width!.toDouble(), lessThan(0.9));
    expect(width.toDouble(), greaterThan(0.5));
    await unmount(tester);
  });

  testWidgets('editorde secilen tur-ozel bicim kaydedilir', (tester) async {
    // Yerlesim alanlari korunurken tur-ozel alanin (ayrac bicimi) editorde
    // secilen degeri kazanmali; ikisi ayni haritada tasiniyor.
    final page = await real(tester, () async {
      final id = await repo.createPage();
      await repo.addBlock(
        id,
        CodexBlockType.divider,
        data: {'style': 'ornament', 'width': 0.5},
      );
      return id;
    });
    await pump(tester, page);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.tap(find.byIcon(Icons.tune).first);
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.tap(find.text('Kesik'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Kaydet'));
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    final json = (await real(tester, () => repo.blocks(page))).single.dataJson;
    expect(json, contains('"style":"dashed"'));
    // Yerlesim korunur.
    expect(json, contains('"width":0.5'));
    await unmount(tester);
  });

  testWidgets('HER blok turu ekleme secicisinde bulunur', (tester) async {
    // Secicideki gruplar elle yazildigi icin yeni bir tur eklendiginde
    // listeye konmayi unutmak kolay: o zaman blok kodda vardir ama
    // kullanici onu hicbir yerden ekleyemez.
    final page = await real(tester, () => repo.createPage());
    await pump(tester, page);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.tap(find.byType(FloatingActionButton));
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    final l10n = L10n.of(tester.element(find.byType(FloatingActionButton)));
    for (final type in CodexBlockType.values) {
      expect(
        find.descendant(
          of: find.byType(ActionChip),
          matching: find.text(codexBlockLabel(l10n, type)),
        ),
        findsOneWidget,
        reason: '${type.name} secicide yok',
      );
    }
    await unmount(tester);
  });

  testWidgets('blok ekleme secicisi aranabilir', (tester) async {
    final page = await real(tester, () => repo.createPage());
    await pump(tester, page);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.tap(find.byType(FloatingActionButton));
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(find.text('Sayaç'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'graf');
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(find.text('Grafik'), findsOneWidget);
    expect(find.text('Sayaç'), findsNothing);
    await unmount(tester);
  });
}
