import 'dart:io';

import 'package:dm_table/data/character_image_store.dart';
import 'package:dm_table/data/character_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/features/characters/character_avatar.dart';
import 'package:dm_table/features/characters/character_providers.dart';
import 'package:dm_table/features/characters/characters_page.dart';
import 'package:dm_table/l10n/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// Karakterler sekmesi: portreler listede, karakter kagidini ACMADAN gorunur.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory tempDir;
  late CharacterRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('dm_characters_page');
    repo = CharacterRepository(
      db,
      portraits: CharacterImageStore(directoryOverride: tempDir),
    );
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> addCharacter(String id, String name) => db
      .into(db.characters)
      .insert(CharactersCompanion.insert(id: id, name: name));

  /// Gecici bir PNG uretip portre olarak kaydeder.
  Future<void> givePortrait(String id) async {
    final source = File(p.join(tempDir.path, '$id-kaynak.png'));
    final image = img.Image(width: 80, height: 80);
    img.fill(image, color: img.ColorRgb8(120, 40, 40));
    source.writeAsBytesSync(img.encodePng(image));
    await repo.setPortrait(id, source);
  }

  /// Test govdesindeki hazirlik GERCEK asenkron islerden olusuyor (sqlite
  /// isolate'i + diske portre yazma). `testWidgets` sahte zamanda calistigi
  /// icin bunlari dogrudan await etmek kilitlenmeye yol acar; `runAsync`
  /// gercek olay dongusune gecirir.
  Future<void> setUpData(WidgetTester tester, Future<void> Function() body) =>
      tester.runAsync(body).then((_) {});

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [characterRepositoryProvider.overrideWithValue(repo)],
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
    // Liste akisi + portrenin diskten cozulmesi birkac kare suruyor.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  /// Drift stream'i test bitmeden birakilirsa "Pending timers" hatasi verir.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  testWidgets('her satirda portre jetonu var', (tester) async {
    await setUpData(tester, () async {
      await addCharacter('c1', 'Rohan');
      await addCharacter('c2', 'Vex');
    });
    await pump(tester);

    expect(find.byType(CharacterAvatar), findsNWidgets(2));
    await unmount(tester);
  });

  testWidgets('portre yuklenmis karakter listede gorseliyle cikar', (
    tester,
  ) async {
    await setUpData(tester, () async {
      await addCharacter('c1', 'Rohan');
      await givePortrait('c1');
    });
    await pump(tester);

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(
      avatar.backgroundImage,
      isNotNull,
      reason: 'portre listede gorsel olarak cizilmeli',
    );
    // Gorsel varken bas harf yedegi gosterilmez.
    expect(find.text('R'), findsNothing);
    await unmount(tester);
  });

  testWidgets('portresiz karakter adinin bas harfine duser', (tester) async {
    await setUpData(tester, () async => addCharacter('c1', 'Rohan'));
    await pump(tester);

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundImage, isNull);
    expect(find.text('R'), findsOneWidget);
    await unmount(tester);
  });
}
