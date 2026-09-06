import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dm_table/data/backup_repository.dart';
import 'package:dm_table/data/character_image_store.dart';
import 'package:dm_table/data/character_repository.dart';
import 'package:dm_table/data/codex_media_store.dart';
import 'package:dm_table/data/codex_repository.dart';
import 'package:dm_table/data/combat_repository.dart';
import 'package:dm_table/data/custom_content_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/db/tables.dart';
import 'package:dm_table/data/db/world_tables.dart';
import 'package:dm_table/data/import/asset_importer.dart';
import 'package:dm_table/data/map_image_store.dart';
import 'package:dm_table/data/session_log_repository.dart';
import 'package:dm_table/data/shop_repository.dart';
import 'package:dm_table/data/world_repository.dart';
import 'package:dm_table/domain/codex/codex_block.dart';
import 'package:dm_table/domain/models/ability.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// Kampanya yedegi.
///
/// En kritik davranis: geri yukleme SRD kutuphanesine DOKUNMAMALI ve DM'in
/// kendi icerigini kaybetmemeli. Yedek dosyasi masada tek kopya oldugu icin
/// yarim kalan bir geri yukleme kampanyayi bitirir.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late BackupRepository backup;
  late Directory tempDir;
  late MapImageStore imageStore;
  late CharacterImageStore portraitStore;
  late CodexMediaStore mediaStore;

  /// Kampanyayi kuran yardimci; her testte ayni baslangic noktasi.
  Future<void> seed(AppDatabase target) async {
    final characters = CharacterRepository(target);
    await characters.createLevelOneCharacter(
      id: 'vex',
      name: 'Vex',
      classKey: 'srd-2024_wizard',
      abilities: const AbilityScores(constitution: 14),
      savingThrows: {Ability.intelligence},
      skills: {Skill.arcana},
      hitDieSides: 6,
      startingGoldGp: 75,
    );

    final combat = CombatRepository(target);
    final encounterId = await combat.createEncounter('Mağara');
    await combat.addAdhoc(
      encounterId: encounterId,
      name: 'Kobold',
      hitPoints: 7,
    );

    final shops = ShopRepository(target);
    final shopId = await shops.create(name: 'Demirci', ownerName: 'Gundren');
    await shops.addItem(
      shopId: shopId,
      customName: 'Kırık pusula',
      priceCpOverride: 500,
    );

    final world = WorldRepository(target, images: imageStore);
    final locationId = await world.createLocation(name: 'Yıkık Kale');
    final npcId = await world.createNpc(name: 'Gundren', role: 'Demirci');
    await world.addPin(
      locationId: locationId,
      kind: PinKind.npc,
      label: 'Dükkânı',
      x: 0.3,
      y: 0.6,
      targetId: npcId,
    );

    await CustomContentRepository(target).addMonster(
      name: 'Gölge Kurdu',
      challengeRating: 2,
      armorClass: 14,
      hitPoints: 33,
    );
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await AssetImporter(db).importIfNeeded();
    tempDir = await Directory.systemTemp.createTemp('dm_masasi_backup');
    imageStore = MapImageStore(directoryOverride: tempDir);
    portraitStore = CharacterImageStore(directoryOverride: tempDir);
    mediaStore = CodexMediaStore(directoryOverride: tempDir);
    backup = BackupRepository(
      db,
      images: imageStore,
      portraits: portraitStore,
      media: mediaStore,
    );
    await seed(db);
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<int> count(String table, [String? where]) async {
    final row = await db
        .customSelect(
          'SELECT COUNT(*) AS c FROM $table${where == null ? '' : ' WHERE $where'}',
        )
        .getSingle();
    return row.read<int>('c');
  }

  test('arsiv ozeti dogru sayilari tasir', () async {
    final summary = backup.inspect(await backup.export());

    expect(summary.schemaVersion, db.schemaVersion);
    expect(summary.createdAt, isNotEmpty);
    expect(summary.counts['characters'], 1);
    expect(summary.counts['encounters'], 1);
    expect(summary.counts['shops'], 1);
    expect(summary.counts['locations'], 1);
    expect(summary.counts['npcs'], 1);
    expect(summary.counts['map_pins'], 1);
    // Yalnizca homebrew canavar; 331 SRD canavari arsive girmemeli.
    expect(summary.counts['monsters'], 1);
  });

  test('SRD icerigi arsive girmez', () async {
    final bytes = await backup.export();
    final summary = backup.inspect(bytes);

    expect(summary.counts['spells'], isNull, reason: 'SRD büyüleri sızmış');
    expect(summary.counts['items'], isNull);
    // 331 canavarlik SRD arsive girseydi boyut cok daha buyuk olurdu.
    expect(bytes.length, lessThan(100 * 1024));
  });

  test('bos veritabanina geri yukleme kampanyayi aynen kurar', () async {
    final bytes = await backup.export();

    // Taze bir cihaz taklidi: SRD var, kullanici verisi yok.
    final fresh = AppDatabase(NativeDatabase.memory());
    await AssetImporter(fresh).importIfNeeded();
    final restore = BackupRepository(fresh, images: imageStore);

    await restore.import(bytes);

    final characters = CharacterRepository(fresh);
    final restored = (await characters.find('vex'))!;
    expect(restored.name, 'Vex');
    expect(restored.hitPointsMax, 8);
    expect(restored.coinsCp, 7500);

    // Kural motoru geri yuklenen veriyle de calismali.
    final build = await characters.buildFor('vex');
    expect(build.totalLevel, 1);
    expect(build.skillProficiencies, contains(Skill.arcana));

    final world = WorldRepository(fresh, images: imageStore);
    final location = (await fresh.select(fresh.locations).get()).single;
    expect(location.name, 'Yıkık Kale');
    expect((await world.pins(location.id)).single.label, 'Dükkânı');

    // Homebrew canavar da donmus olmali.
    final custom = await (fresh.select(
      fresh.monsters,
    )..where((t) => t.sourceType.equalsValue(SourceType.custom))).get();
    expect(custom.single.name, 'Gölge Kurdu');

    await fresh.close();
  });

  test('geri yukleme SRD kutuphanesine dokunmaz', () async {
    final bytes = await backup.export();

    final srdBefore = await count('monsters', "source_type = 'srd'");
    final spellsBefore = await count('spells');
    expect(srdBefore, 333);

    await backup.import(bytes);

    expect(await count('monsters', "source_type = 'srd'"), srdBefore);
    expect(await count('spells'), spellsBefore);
  });

  test('geri yukleme mevcut kullanici verisinin yerine gecer', () async {
    final bytes = await backup.export();

    // Yedekten sonra baska bir karakter ekle.
    await CharacterRepository(db).createLevelOneCharacter(
      id: 'sonradan',
      name: 'Sonradan Gelen',
      classKey: 'srd-2024_fighter',
      abilities: const AbilityScores(),
      savingThrows: const {},
      skills: const {},
      hitDieSides: 10,
    );
    expect(await count('characters'), 2);

    await backup.import(bytes);

    // Yedekte olmayan kayit gitmeli.
    expect(await count('characters'), 1);
    expect(await CharacterRepository(db).find('sonradan'), isNull);
    expect(await CharacterRepository(db).find('vex'), isNotNull);
  });

  test('iki kez geri yukleme kopya uretmez', () async {
    final bytes = await backup.export();

    await backup.import(bytes);
    final afterFirst = await count('characters');
    await backup.import(bytes);

    expect(await count('characters'), afterFirst);
    expect(await count('map_pins'), 1);
    expect(await count('shop_stock'), 1);
  });

  test('envanter arsive girer', () async {
    await CharacterRepository(db).addItem(
      characterId: 'vex',
      customName: 'Kırık pusula',
      customDesc: 'İbreleri donmuş.',
    );

    final summary = backup.inspect(await backup.export());
    expect(summary.counts['character_items'], 1);
  });

  test('oturum gunlugu arsive girer ve geri yuklenir', () async {
    final log = SessionLogRepository(db);
    await log.add('XP verildi: 300');
    await log.add('Elle not');

    final bytes = await backup.export();
    expect(backup.inspect(bytes).counts['session_log_entries'], 2);

    // Taze cihaz: SRD var, kullanici verisi yok.
    final fresh = AppDatabase(NativeDatabase.memory());
    await AssetImporter(fresh).importIfNeeded();
    await BackupRepository(fresh, images: imageStore).import(bytes);

    final restored = await fresh.select(fresh.sessionLogEntries).get();
    expect(restored, hasLength(2));
    expect(restored.map((e) => e.message), contains('XP verildi: 300'));
    expect(restored.map((e) => e.message), contains('Elle not'));

    await fresh.close();
  });

  test('harita gorselleri arsive girer ve geri yuklenir', () async {
    final world = WorldRepository(db, images: imageStore);
    final location = (await db.select(db.locations).get()).single;

    final source = File(p.join(tempDir.path, 'harita.png'));
    final image = img.Image(width: 800, height: 400);
    img.fill(image, color: img.ColorRgb8(40, 60, 90));
    await source.writeAsBytes(img.encodePng(image));
    await world.setMapImage(location.id, source);

    final stored = (await world.find(location.id))!;
    final bytes = await backup.export();
    expect(backup.inspect(bytes).mapCount, 1);

    // Dosyayi sil, sonra yedekten geri getir.
    await imageStore.delete(stored.mapImagePath);
    expect(
      (await imageStore.resolve(stored.mapImagePath!)).existsSync(),
      isFalse,
    );

    await backup.import(bytes);

    expect(
      (await imageStore.resolve(stored.mapImagePath!)).existsSync(),
      isTrue,
    );
  });

  test('portre gorselleri arsive girer ve geri yuklenir', () async {
    // Karaktere bir portre ver: dosya portraits/ klasorune yazilir.
    final characters = CharacterRepository(db, portraits: portraitStore);
    final source = File(p.join(tempDir.path, 'portre.png'));
    final image = img.Image(width: 200, height: 200);
    img.fill(image, color: img.ColorRgb8(120, 30, 30));
    await source.writeAsBytes(img.encodePng(image));
    await characters.setPortrait('vex', source);

    final stored = (await characters.find('vex'))!;
    expect(stored.portraitPath, isNotNull);

    final bytes = await backup.export();
    expect(backup.inspect(bytes).portraitCount, 1);

    // Dosyayi sil (DB'de yol kaliyor, dosya kayboluyor -- cihaz degisimi gibi).
    await portraitStore.delete(stored.portraitPath);
    expect(
      (await portraitStore.resolve(stored.portraitPath!)).existsSync(),
      isFalse,
    );

    await backup.import(bytes);

    // Portre dosyasi yedekten geri gelmis olmali.
    expect(
      (await portraitStore.resolve(stored.portraitPath!)).existsSync(),
      isTrue,
    );
  });

  test(
    'Kayitlar (Codex) sayfa ve bloklari arsive girer ve geri yuklenir',
    () async {
      final codex = CodexRepository(db);
      final pageId = await codex.createPage(title: 'Gizli Tapinak');
      await codex.addBlock(
        pageId,
        CodexBlockType.text,
        data: {'text': 'Kapida **bir bilmece** var.'},
      );
      final childId = await codex.createPage(
        title: 'Alt Salon',
        parentId: pageId,
      );
      await codex.addBlock(
        childId,
        CodexBlockType.heading,
        data: {'level': 2, 'text': 'Salon'},
      );

      final bytes = await backup.export();
      final summary = backup.inspect(bytes);
      expect(summary.counts['codex_pages'], 2);
      expect(summary.counts['codex_blocks'], 2);

      // Taze cihaz: SRD var, kullanici verisi yok.
      final fresh = AppDatabase(NativeDatabase.memory());
      await AssetImporter(fresh).importIfNeeded();
      await BackupRepository(fresh, images: imageStore).import(bytes);

      final freshCodex = CodexRepository(fresh);
      final pages = await freshCodex.watchPages().first;
      final restoredParent = pages.firstWhere(
        (p) => p.title == 'Gizli Tapinak',
      );
      // Alt sayfa dogru ust sayfaya bagli donmus olmali (agac korunuyor).
      final child = pages.firstWhere((p) => p.title == 'Alt Salon');
      expect(child.parentId, restoredParent.id);
      final restoredBlocks = await freshCodex.blocks(restoredParent.id);
      expect(restoredBlocks.single.dataJson, contains('bir bilmece'));

      await fresh.close();
    },
  );

  test(
    'Kayitlar (Codex) gorsel bloklari arsive girer ve geri yuklenir',
    () async {
      // Codex gorseli portraits/ klasorune yazilir; yolu data_json icinde durur.
      final source = File(p.join(tempDir.path, 'kayit.png'));
      final image = img.Image(width: 150, height: 150);
      img.fill(image, color: img.ColorRgb8(30, 90, 120));
      await source.writeAsBytes(img.encodePng(image));
      final relPath = await portraitStore.store(source);

      final codex = CodexRepository(db);
      final pageId = await codex.createPage(title: 'Harita Notu');
      await codex.addBlock(
        pageId,
        CodexBlockType.image,
        data: {'path': relPath, 'caption': 'Zindan'},
      );

      final bytes = await backup.export();
      // Codex gorseli de portre sayimina dahil.
      expect(backup.inspect(bytes).portraitCount, 1);

      // Dosyayi sil (cihaz degisimi taklidi), sonra geri yukle.
      await portraitStore.delete(relPath);
      expect((await portraitStore.resolve(relPath)).existsSync(), isFalse);

      await backup.import(bytes);

      expect((await portraitStore.resolve(relPath)).existsSync(), isTrue);
    },
  );

  test(
    'Kayitlar (Codex) video dosyalari arsive girer ve geri yuklenir',
    () async {
      // Video codex_media/ klasorune kopyalanir (kod cozme yok, ham kopya).
      final source = File(p.join(tempDir.path, 'sahne.mp4'));
      await source.writeAsBytes(List.filled(2048, 7));
      final relPath = await mediaStore.store(source);

      final codex = CodexRepository(db);
      final pageId = await codex.createPage(title: 'Sinematik');
      await codex.addBlock(
        pageId,
        CodexBlockType.video,
        data: {'path': relPath, 'caption': 'Acilis'},
      );

      final bytes = await backup.export();
      expect(backup.inspect(bytes).mediaCount, 1);

      // Dosyayi sil (cihaz degisimi taklidi), sonra geri yukle.
      await mediaStore.delete(relPath);
      expect((await mediaStore.resolve(relPath)).existsSync(), isFalse);

      await backup.import(bytes);

      expect((await mediaStore.resolve(relPath)).existsSync(), isTrue);
    },
  );

  test('gecersiz dosya anlamli hata verir', () {
    expect(
      () => backup.inspect(utf8.encode('bu bir yedek değil')),
      throwsA(anything),
    );
  });

  test('daha yeni surumlu yedek reddedilir', () async {
    // Ileriden gelen bir yedek sessizce yanlis okunmamali.
    final bytes = await backup.export();
    final tampered = _withManifestVersion(
      bytes,
      BackupRepository.formatVersion + 1,
    );

    expect(
      () => backup.inspect(tampered),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('daha yeni'),
        ),
      ),
    );
  });
}

/// Arsivdeki manifest surumunu degistirir; ileri surum kontrolunu sinamak icin.
List<int> _withManifestVersion(List<int> bytes, int version) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final rebuilt = Archive();

  for (final file in archive.files) {
    if (file.name == 'manifest.json') {
      final manifest =
          jsonDecode(utf8.decode(file.content as List<int>))
              as Map<String, dynamic>;
      manifest['formatVersion'] = version;
      final encoded = utf8.encode(jsonEncode(manifest));
      rebuilt.add(ArchiveFile('manifest.json', encoded.length, encoded));
    } else {
      rebuilt.add(file);
    }
  }
  return ZipEncoder().encode(rebuilt);
}
