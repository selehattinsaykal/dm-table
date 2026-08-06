import 'dart:io';
import 'dart:typed_data';

import 'package:dm_table/data/character_image_store.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/map_image_store.dart';
import 'package:dm_table/data/world_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// AI NPC ureteci "NPC'lere kaydet" yolunun veri tarafi: uretilen NPC secilen
/// yere ve diger NPC'lere GERCEK dunya-grafigi kenarlariyla baglanir, uretilen
/// portre de baytlardan dogrudan yazilir.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late WorldRepository world;
  late Directory tempDir;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('dm_ai_npc');
    world = WorldRepository(
      db,
      images: MapImageStore(directoryOverride: tempDir),
      portraits: CharacterImageStore(directoryOverride: tempDir),
    );
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test(
    'NPC yere baglanir: kenar npc/location uclariyla ve secilen turle',
    () async {
      final locId = await world.createLocation(name: 'Karga Geçidi');
      final npcId = await world.createNpc(name: 'Bruna');

      await world.createLink(
        npcId,
        locId,
        xKind: 'npc',
        yKind: 'location',
        type: 'trade',
      );

      final links = await db.select(db.worldLinks).get();
      expect(links, hasLength(1));
      expect(links.single.aId, npcId);
      expect(links.single.bId, locId);
      expect(links.single.aKind, 'npc');
      expect(links.single.bKind, 'location');
      expect(links.single.type, 'trade');
    },
  );

  test('birden fazla NPC iliskisi ayri kenarlar olur', () async {
    final sera = await world.createNpc(name: 'Sera');
    final borin = await world.createNpc(name: 'Borin');
    final yeni = await world.createNpc(name: 'Bruna');

    await world.createLink(
      yeni,
      sera,
      xKind: 'npc',
      yKind: 'npc',
      type: 'enmity',
    );
    await world.createLink(
      yeni,
      borin,
      xKind: 'npc',
      yKind: 'npc',
      type: 'family',
    );

    final links = await db.select(db.worldLinks).get();
    expect(links, hasLength(2));
    expect(links.map((l) => l.type).toSet(), {'enmity', 'family'});
    expect(links.every((l) => l.aKind == 'npc' && l.bKind == 'npc'), isTrue);
  });

  test('ayni cifte ikinci bag eklenmez, turu guncellenir', () async {
    final a = await world.createNpc(name: 'A');
    final b = await world.createNpc(name: 'B');

    await world.createLink(
      a,
      b,
      xKind: 'npc',
      yKind: 'npc',
      type: 'friendship',
    );
    await world.createLink(a, b, xKind: 'npc', yKind: 'npc', type: 'enmity');

    final links = await db.select(db.worldLinks).get();
    expect(links, hasLength(1));
    expect(links.single.type, 'enmity');
  });

  test('kendine bag yok sayilir', () async {
    final a = await world.createNpc(name: 'A');
    await world.createLink(a, a, xKind: 'npc', yKind: 'npc', type: 'family');
    expect(await db.select(db.worldLinks).get(), isEmpty);
  });

  test('uretilen portre baytlardan yazilir ve dosya olusur', () async {
    final npcId = await world.createNpc(name: 'Bruna');
    // Gorsel modelinin dondurecegi turden ham baytlar.
    final bytes = img.encodePng(img.Image(width: 8, height: 8));

    await world.setNpcPortraitFromBytes(npcId, bytes);

    final npc = await world.findNpc(npcId);
    expect(npc?.portraitPath, isNotNull);
    final file = await world.portraits.resolve(npc!.portraitPath!);
    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), greaterThan(0));
  });

  test('portre yenilenince eski dosya silinir', () async {
    final npcId = await world.createNpc(name: 'Bruna');
    await world.setNpcPortraitFromBytes(
      npcId,
      img.encodePng(img.Image(width: 8, height: 8)),
    );
    final first = (await world.findNpc(npcId))!.portraitPath!;
    final firstFile = await world.portraits.resolve(first);

    await world.setNpcPortraitFromBytes(
      npcId,
      img.encodePng(img.Image(width: 16, height: 16)),
    );

    final second = (await world.findNpc(npcId))!.portraitPath!;
    expect(second, isNot(first));
    expect(firstFile.existsSync(), isFalse);
  });

  test('cozulemeyen baytlar FormatException atar (NPC bozulmaz)', () async {
    final npcId = await world.createNpc(name: 'Bruna');
    await expectLater(
      world.setNpcPortraitFromBytes(npcId, Uint8List.fromList([1, 2, 3])),
      throwsA(isA<FormatException>()),
    );
    expect((await world.findNpc(npcId))?.portraitPath, isNull);
  });
}
