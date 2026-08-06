import 'dart:io';

import 'package:dm_table/data/character_image_store.dart';
import 'package:dm_table/data/character_repository.dart';
import 'package:dm_table/data/combat_repository.dart';
import 'package:dm_table/data/db/character_tables.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/import/asset_importer.dart';
import 'package:dm_table/data/map_image_store.dart';
import 'package:dm_table/data/shop_repository.dart';
import 'package:dm_table/data/world_repository.dart';
import 'package:dm_table/domain/models/ability.dart';
import 'package:dm_table/features/session/session_service.dart';
import 'package:dm_table/net/protocol.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// Oyuncu snapshot'i zengin alanlari tasimali: uzmanliklar ture gore gruplu,
/// portre URL'si, bilinen buyuler, bagli buyulu esya; ve portre `/media`'dan
/// cozulebilmeli.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory tempDir;
  late CharacterRepository characters;
  late SessionService session;
  late String charId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await AssetImporter(db).importIfNeeded();
    tempDir = await Directory.systemTemp.createTemp('dm_rich_snap');
    characters = CharacterRepository(
      db,
      portraits: CharacterImageStore(directoryOverride: tempDir),
    );
    session = SessionService(
      db: db,
      characters: characters,
      combat: CombatRepository(db),
      shops: ShopRepository(db),
      world: WorldRepository(
        db,
        images: MapImageStore(directoryOverride: tempDir),
      ),
    );

    final classKey = (await characters.classOptions()).first.key;
    charId = await characters.createLevelOneCharacter(
      id: 'c1',
      name: 'Rohan',
      classKey: classKey,
      abilities: const AbilityScores(),
      savingThrows: const {},
      skills: const {},
      hitDieSides: 8,
    );

    // Uzmanliklar (farkli turler).
    await db.batch((b) {
      for (final (kind, value) in [
        (ProficiencyKind.weapon, 'Simple Weapons'),
        (ProficiencyKind.armor, 'Light Armor'),
        (ProficiencyKind.tool, "Thieves' Tools"),
        (ProficiencyKind.language, 'Common'),
      ]) {
        b.insert(
          db.characterProficiencies,
          CharacterProficienciesCompanion.insert(
            characterId: charId,
            kind: kind,
            value: value,
          ),
        );
      }
    });

    await characters.setStory(charId, personality: 'Cesur');
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<PlayerCharacterView> view() async => (await session.buildSnapshot())
      .characters
      .firstWhere((c) => c.id == charId);

  test('uzmanliklar ture gore gruplanir', () async {
    final v = await view();
    expect(v.weaponProficiencies, contains('Simple Weapons'));
    expect(v.armorProficiencies, contains('Light Armor'));
    expect(v.toolProficiencies, contains("Thieves' Tools"));
    expect(v.languages, contains('Common'));
    // Diller silah listesine sizmamali.
    expect(v.weaponProficiencies, isNot(contains('Common')));
    expect(v.personality, 'Cesur');
  });

  test('bilinen buyu snapshot\'ta gorunur', () async {
    final spell = await (db.select(db.spells)..limit(1)).getSingle();
    await characters.addKnownSpell(charId, spell.key);
    final v = await view();
    expect(v.spells.map((s) => s.name), contains(spell.name));
  });

  test('bagli buyulu esya envanterde attuned/magic isaretli', () async {
    final magic = await (db.select(db.magicItems)..limit(1)).getSingle();
    await db
        .into(db.characterItems)
        .insert(
          CharacterItemsCompanion.insert(
            id: 'it1',
            characterId: charId,
            magicItemKey: Value(magic.key),
            attuned: const Value(true),
          ),
        );
    final v = await view();
    final line = v.inventory.firstWhere((i) => i.id == 'it1');
    expect(line.attuned, isTrue);
    expect(line.magic, isTrue);
  });

  test('portre URL uretilir ve /media\'dan cozulur', () async {
    final source = File(p.join(tempDir.path, 'foto.png'));
    final image = img.Image(width: 128, height: 128);
    img.fill(image, color: img.ColorRgb8(10, 20, 30));
    await source.writeAsBytes(img.encodePng(image));
    await characters.setPortrait(charId, source);

    final v = await view();
    expect(v.portraitUrl, isNotNull);
    expect(v.portraitUrl, startsWith('/media/'));

    final name = v.portraitUrl!.substring('/media/'.length);
    final resolved = await session.resolveMedia(name);
    expect(resolved, isNotNull);
    expect(resolved!.existsSync(), isTrue);
  });
}
