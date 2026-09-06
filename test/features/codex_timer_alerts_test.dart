import 'dart:async';
import 'dart:convert';

import 'package:dm_table/data/codex_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/domain/codex/codex_block.dart';
import 'package:dm_table/domain/codex/codex_style.dart';
import 'package:dm_table/features/codex/codex_timer_alerts.dart';
import 'package:dm_table/l10n/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sure sayaci uyarilari: DM baska bir sekmedeyken de sayacin dolmasi
/// duyurulmali. Bu yuzden uyariyi blogun widget'i degil, uygulama boyunca
/// yasayan bu servis uretir.
///
/// Testler gercek zamanla calisir; sureler bilerek cok kisa tutuldu.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CodexRepository repo;
  late CodexTimerAlerts alerts;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = CodexRepository(db);
    alerts = CodexTimerAlerts(repo)..start();
  });

  tearDown(() async {
    await alerts.dispose();
    await db.close();
  });

  /// Calisan bir geri sayim blogu ekler.
  Future<String> addTimer({
    required Duration duration,
    Duration startedAgo = Duration.zero,
    String title = 'Tur süresi',
    bool alarm = true,
    bool loop = false,
    bool running = true,
    CodexTimerMode mode = CodexTimerMode.countdown,
  }) async {
    final page = await repo.createPage();
    final timer = CodexTimer(
      mode: mode,
      duration: duration,
      alarm: alarm,
      loop: loop,
      startedAt: running ? DateTime.now().subtract(startedAgo) : null,
    );
    return repo.addBlock(
      page,
      CodexBlockType.timer,
      data: {'title': title, ...timer.toJson()},
    );
  }

  Future<Map<String, dynamic>> dataOf(String blockId) async =>
      (jsonDecode((await repo.block(blockId))!.dataJson) as Map)
          .cast<String, dynamic>();

  test('calisan sayac dolunca uyari uretilir', () async {
    final fired = alerts.alerts.first;
    final id = await addTimer(duration: const Duration(seconds: 1));

    final alert = await fired.timeout(const Duration(seconds: 5));

    expect(alert.blockId, id);
    expect(alert.title, 'Tur süresi');
    // Bitis durumu kalici olur: sayfa acildiginda sayac dolmus gorunmeli.
    final data = await dataOf(id);
    expect(data['startedAt'], isNull);
    expect(data['accumulated'], 1000);
  });

  test('duraklatilan sayac uyari vermez', () async {
    var fired = false;
    alerts.alerts.listen((_) => fired = true);
    final id = await addTimer(duration: const Duration(seconds: 1));

    // Zamanlayici dolmadan duraklat.
    final paused = CodexTimer.fromJson(
      await dataOf(id),
    ).pausedAt(DateTime.now());
    await repo.updateBlock(id, {...await dataOf(id), ...paused.toJson()});
    await Future<void>.delayed(const Duration(milliseconds: 1600));

    expect(fired, isFalse);
  });

  test('uyari kapaliyken ses cikmaz ama durum yine de yazilir', () async {
    var fired = false;
    alerts.alerts.listen((_) => fired = true);
    final id = await addTimer(
      duration: const Duration(seconds: 1),
      alarm: false,
    );

    await Future<void>.delayed(const Duration(milliseconds: 1600));

    expect(fired, isFalse);
    expect((await dataOf(id))['startedAt'], isNull);
  });

  test('cok once dolmus sayac acilista uyarmaz, yalnizca duzeltilir', () async {
    var fired = false;
    alerts.alerts.listen((_) => fired = true);
    // Uygulama kapaliyken dolmus gibi: bir saat once baslatilmis 1 dk'lik
    // sayac. Bunu acilista duyurmak gurultuden ibaret olurdu.
    final id = await addTimer(
      duration: const Duration(minutes: 1),
      startedAgo: const Duration(hours: 1),
    );

    await Future<void>.delayed(const Duration(milliseconds: 500));

    expect(fired, isFalse);
    expect((await dataOf(id))['startedAt'], isNull);
  });

  test('dongudeki sayac bitince yeniden baslar', () async {
    final fired = alerts.alerts.first;
    final id = await addTimer(duration: const Duration(seconds: 1), loop: true);

    await fired.timeout(const Duration(seconds: 5));

    final data = await dataOf(id);
    expect(data['startedAt'], isNotNull, reason: 'dongu yeniden baslatmali');
    expect(data['accumulated'], 0);
  });

  test('kronometre uyari uretmez', () async {
    var fired = false;
    alerts.alerts.listen((_) => fired = true);
    await addTimer(
      duration: const Duration(seconds: 1),
      mode: CodexTimerMode.stopwatch,
    );

    await Future<void>.delayed(const Duration(milliseconds: 1600));

    expect(fired, isFalse);
  });

  test('silinen sayac uyari vermez', () async {
    var fired = false;
    alerts.alerts.listen((_) => fired = true);
    final id = await addTimer(duration: const Duration(seconds: 1));
    await repo.deleteBlock(id);

    await Future<void>.delayed(const Duration(milliseconds: 1600));

    expect(fired, isFalse);
  });

  group('bildirim', () {
    late StreamController<CodexTimerAlert> feed;

    setUp(() => feed = StreamController<CodexTimerAlert>.broadcast());
    tearDown(() => feed.close());

    /// Uyari dinleyicisi uretimde oldugu gibi `MaterialApp`'in `builder:`
    /// katmanina kurulur — ceviri ve `ScaffoldMessenger` oradan cozulur.
    /// Kok agaca (MaterialApp'in USTUNE) konursa `Localizations` bulunamaz,
    /// cagri patlar ve bildirim hic gorunmez; bu testin isi tam olarak o.
    Future<void> pumpApp(WidgetTester tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            codexTimerAlertStreamProvider.overrideWith((ref) => feed.stream),
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
            navigatorKey: navigatorKey,
            builder: (context, child) => CodexTimerAlertListener(
              navigatorKey: navigatorKey,
              child: child!,
            ),
            // Kayitlar DISINDA bir ekran: uyari yine de gorunmeli.
            home: const Scaffold(body: Center(child: Text('Savaş'))),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('baska ekrandayken bildirim gosterilir', (tester) async {
      await pumpApp(tester);

      feed.add(
        const CodexTimerAlert(
          blockId: 'bl-1',
          pageId: 'pg-1',
          title: 'Tur süresi',
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Tur süresi'), findsOneWidget);
      // Sayfaya gitme kisayolu.
      expect(find.text('Aç'), findsOneWidget);

      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('basliksiz sayac genel metinle duyurulur', (tester) async {
      await pumpApp(tester);

      feed.add(
        const CodexTimerAlert(blockId: 'bl-1', pageId: 'pg-1', title: ''),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Süre doldu.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
    });
  });
}
