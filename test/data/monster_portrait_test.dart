import 'dart:io';

import 'package:dm_table/data/character_image_store.dart';
import 'package:dm_table/data/compendium_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/db/tables.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// Canavar portresi: gorsel diske yazilir, goreli yol Monsters.portraitPath'e
/// kaydedilir, kaldirilinca dosya da silinir (karakter portresiyle ayni store).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory tempDir;
  late CompendiumRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('dm_monster_art');
    repo = CompendiumRepository(
      db,
      portraits: CharacterImageStore(directoryOverride: tempDir),
    );
    await db
        .into(db.monsters)
        .insert(
          MonstersCompanion.insert(
            key: 'm1',
            name: 'Goblin',
            nameLower: 'goblin',
            dataJson: '{}',
            sourceType: const Value(SourceType.custom),
          ),
        );
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  File makeNamedImage(String base) {
    final source = File(p.join(tempDir.path, '$base.png'));
    final image = img.Image(width: 120, height: 120);
    img.fill(image, color: img.ColorRgb8(40, 120, 40));
    source.writeAsBytesSync(img.encodePng(image));
    return source;
  }

  File makeImage() => makeNamedImage('kaynak');

  test('portre yuklenir; yol kaydedilir ve dosya diskte olusur', () async {
    await repo.setMonsterPortrait('m1', makeImage());

    final m = (await repo.monsterByKey('m1'))!;
    expect(m.portraitPath, isNotNull);
    final file = await repo.portraits.resolve(m.portraitPath!);
    expect(file.existsSync(), isTrue);
  });

  test('yeni portre eskisini diskten siler', () async {
    await repo.setMonsterPortrait('m1', makeImage());
    final first = (await repo.monsterByKey('m1'))!.portraitPath!;
    final firstFile = await repo.portraits.resolve(first);

    await repo.setMonsterPortrait('m1', makeImage());
    final second = (await repo.monsterByKey('m1'))!.portraitPath!;

    expect(second, isNot(first));
    expect(firstFile.existsSync(), isFalse, reason: 'eski dosya silinmeli');
    expect((await repo.portraits.resolve(second)).existsSync(), isTrue);
  });

  test('portre kaldirilinca yol null olur ve dosya silinir', () async {
    await repo.setMonsterPortrait('m1', makeImage());
    final path = (await repo.monsterByKey('m1'))!.portraitPath!;
    final file = await repo.portraits.resolve(path);

    await repo.removeMonsterPortrait('m1');

    expect((await repo.monsterByKey('m1'))!.portraitPath, isNull);
    expect(file.existsSync(), isFalse);
  });

  group('toplu ice aktarma', () {
    setUp(() async {
      await db
          .into(db.monsters)
          .insert(
            MonstersCompanion.insert(
              key: 'm2',
              name: 'Orc',
              nameLower: 'orc',
              dataJson: '{}',
              sourceType: const Value(SourceType.custom),
            ),
          );
    });

    test('ad ile eslesenlere atar, eslesmeyeni bildirir', () async {
      final result = await repo.importMonsterPortraits([
        makeNamedImage('Goblin'), // m1 (nameLower 'goblin')
        makeNamedImage('Orc'), // m2
        makeNamedImage('Beholder'), // eslesmez
      ]);

      expect(result.assigned, 2);
      expect(result.unmatched, ['Beholder.png']);
      expect((await repo.monsterByKey('m1'))!.portraitPath, isNotNull);
      expect((await repo.monsterByKey('m2'))!.portraitPath, isNotNull);
    });

    test('eslesme buyuk/kucuk harf duyarsiz (normalize)', () async {
      // 'ORC' -> 'orc' (Turkce-duyarli normalize; 'I' iceren adlar ayri konu).
      final result = await repo.importMonsterPortraits([makeNamedImage('ORC')]);
      expect(result.assigned, 1);
      expect((await repo.monsterByKey('m2'))!.portraitPath, isNotNull);
    });
  });
}
