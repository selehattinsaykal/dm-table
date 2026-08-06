import 'dart:io';

import 'package:dm_table/data/character_image_store.dart';
import 'package:dm_table/data/character_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// Zengin karakter kagidi verisi: hikaye/kisilik, portre ve bilinen buyuler
/// kalici yazilmali.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory tempDir;
  late CharacterRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('dm_rich');
    repo = CharacterRepository(
      db,
      portraits: CharacterImageStore(directoryOverride: tempDir),
    );
    await db
        .into(db.characters)
        .insert(CharactersCompanion.insert(id: 'c1', name: 'Rohan'));
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('setStory kisilik alanlarini yazar', () async {
    await repo.setStory(
      'c1',
      notes: 'Geçmiş',
      appearance: 'Uzun boylu',
      personality: 'Cesur',
      ideal: 'Özgürlük',
      bond: 'Köyü',
      flaw: 'Aceleci',
    );
    final c = (await repo.find('c1'))!;
    expect(c.notes, 'Geçmiş');
    expect(c.appearance, 'Uzun boylu');
    expect(c.personality, 'Cesur');
    expect(c.ideal, 'Özgürlük');
    expect(c.bond, 'Köyü');
    expect(c.flaw, 'Aceleci');
  });

  test('portre yuklenip kaldirilir; dosya diskte olusur/silinir', () async {
    final source = File(p.join(tempDir.path, 'kaynak.png'));
    final image = img.Image(width: 200, height: 200);
    img.fill(image, color: img.ColorRgb8(120, 80, 40));
    await source.writeAsBytes(img.encodePng(image));

    await repo.setPortrait('c1', source);
    final withPortrait = (await repo.find('c1'))!;
    expect(withPortrait.portraitPath, isNotNull);
    final file = await repo.portraits.resolve(withPortrait.portraitPath!);
    expect(file.existsSync(), isTrue);

    await repo.removePortrait('c1');
    expect((await repo.find('c1'))!.portraitPath, isNull);
    expect(file.existsSync(), isFalse);
  });

  test('bilinen buyu ekle/hazirla/sil ve kutuphaneyle birlestir', () async {
    // Kutuphaneye bir buyu koy.
    await db
        .into(db.spells)
        .insert(
          SpellsCompanion.insert(
            key: 'srd_fireball',
            name: 'Fireball',
            nameLower: 'fireball',
            dataJson: '{}',
            level: const Value(3),
            school: const Value('Evocation'),
            concentration: const Value(false),
          ),
        );

    await repo.addKnownSpell('c1', 'srd_fireball', classKey: 'wizard');
    var known = await repo.knownSpells('c1');
    expect(known.length, 1);
    expect(known.first.name, 'Fireball');
    expect(known.first.level, 3);
    expect(known.first.prepared, isFalse);

    await repo.togglePrepared('c1', 'srd_fireball', true);
    known = await repo.knownSpells('c1');
    expect(known.first.prepared, isTrue);

    await repo.removeSpell('c1', 'srd_fireball');
    expect(await repo.knownSpells('c1'), isEmpty);
  });
}
