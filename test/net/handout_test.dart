import 'dart:io';

import 'package:dm_table/data/character_image_store.dart';
import 'package:dm_table/data/character_repository.dart';
import 'package:dm_table/data/combat_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/shop_repository.dart';
import 'package:dm_table/data/world_repository.dart';
import 'package:dm_table/features/session/session_service.dart';
import 'package:dm_table/net/protocol.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// Handout paylasimi: DM gorsel gosterir, snapshot'a `/media` yolu ile girer,
/// baslik bosluksa null olur, temizleyince kaybolur.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory tempDir;
  late SessionService session;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('dm_handout');
    session = SessionService(
      db: db,
      characters: CharacterRepository(
        db,
        portraits: CharacterImageStore(directoryOverride: tempDir),
      ),
      combat: CombatRepository(db),
      shops: ShopRepository(db),
      world: WorldRepository(db),
    );
  });

  tearDown(() async {
    await session.stop();
    await db.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  File makeImage() {
    final f = File(p.join(tempDir.path, 'mektup.png'));
    final image = img.Image(width: 80, height: 80);
    img.fill(image, color: img.ColorRgb8(200, 180, 120));
    f.writeAsBytesSync(img.encodePng(image));
    return f;
  }

  test('handout snapshot a girer, url /media ve baslik korunur', () async {
    await session.showHandout(image: makeImage(), caption: 'Gizli mektup');

    final snapshot = await session.buildSnapshot();
    expect(snapshot.handout, isNotNull);
    expect(snapshot.handout!.url, startsWith('/media/'));
    expect(snapshot.handout!.caption, 'Gizli mektup');
    // Gorsel gercekten portre klasorune kopyalanmis olmali.
    final portraitDir = Directory(p.join(tempDir.path, 'portraits'));
    expect(portraitDir.listSync().whereType<File>(), isNotEmpty);
  });

  test('bosluk baslik null olur', () async {
    await session.showHandout(image: makeImage(), caption: '   ');
    final snapshot = await session.buildSnapshot();
    expect(snapshot.handout!.caption, isNull);
  });

  test('clearHandout snapshot tan cikarir', () async {
    await session.showHandout(image: makeImage());
    expect((await session.buildSnapshot()).handout, isNotNull);

    await session.clearHandout();
    expect((await session.buildSnapshot()).handout, isNull);
  });

  test('yeni handout id artar', () async {
    await session.showHandout(image: makeImage());
    final first = (await session.buildSnapshot()).handout!.id;
    await session.showHandout(image: makeImage());
    final second = (await session.buildSnapshot()).handout!.id;
    expect(second, isNot(first));
  });

  test('metin handout: text dolu, url null (AI görev metni)', () async {
    await session.showHandoutText(
      text: 'Kayıp çocuğu bul. Ödül: 200 altın.',
      caption: 'Görev',
    );
    final h = (await session.buildSnapshot()).handout!;
    expect(h.text, 'Kayıp çocuğu bul. Ödül: 200 altın.');
    expect(h.url, isNull);
    expect(h.caption, 'Görev');
    // Metin handout görsel kopyalamaz.
    final portraitDir = Directory(p.join(tempDir.path, 'portraits'));
    expect(
      portraitDir.existsSync() ? portraitDir.listSync() : const [],
      isEmpty,
    );
  });

  test('metin handout snapshot JSON tur atlayinca korunur', () async {
    await session.showHandoutText(text: 'Görev metni', caption: '   ');
    final snap = await session.buildSnapshot();
    final round = TableSnapshot.fromJson(snap.toJson());
    expect(round.handout!.text, 'Görev metni');
    expect(round.handout!.url, isNull);
    expect(round.handout!.caption, isNull); // boşluk → null
  });
}
