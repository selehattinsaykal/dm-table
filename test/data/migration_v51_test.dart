import 'dart:io';

import 'package:dm_table/data/db/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// v46 -> guncel (v51) migration korumasi.
///
/// **Bu dosya neden var:** zincirin son adimlari ayni fixture uzerinde
/// dogrulaniyor -- v47 savas takibine dort sutun EKLIYOR, v48 oyuncu
/// paneline ozel sutunlari DUSURUYOR, v49 karsilasmaya yer bagi ekliyor,
/// v50 fraksiyon tablosunu ve "uyelik" bag turunu, v51 ise saatleri
/// kuruyor. Eklenenler var, dusurulenler yok, satirlar yerinde.
void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('dm_table_migration_v47');
  });

  tearDown(() async {
    try {
      if (tmp.existsSync()) await tmp.delete(recursive: true);
    } on FileSystemException {
      // Gecici dizin; isletim sistemi sonra temizler.
    }
  });

  AppDatabase openOverV46(File file, {List<String> seed = const []}) =>
      AppDatabase(
        NativeDatabase(
          file,
          setup: (raw) {
            for (final statement in [..._v46Combat, ...seed]) {
              raw.execute(statement);
            }
            raw.execute('PRAGMA user_version = 46');
          },
        ),
      );

  test('savas takibi sutunlari eklenir, satirlar korunur', () async {
    final file = File(p.join(tmp.path, 'v47.sqlite'));
    final db = openOverV46(
      file,
      seed: [
        "INSERT INTO encounters (id, name) VALUES ('e1', 'Pusu')",
        "INSERT INTO combatants (id, encounter_id, kind, name, hit_points_max, "
            "hit_points_current) VALUES ('c1', 'e1', 'monster', 'Goblin', 7, 7)",
      ],
    );

    final rows = await db.select(db.combatants).get();
    expect(rows, hasLength(1));
    expect(rows.single.name, 'Goblin');
    expect(rows.single.reactionUsed, isFalse);
    expect(rows.single.defensesJson, '{}');
    expect(rows.single.deathSaveSuccesses, 0);
    expect(rows.single.deathSaveFailures, 0);

    final encounters = await db.select(db.encounters).get();
    expect(encounters.single.turnLimitSeconds, isNull);
    expect(encounters.single.lairActionText, isNull);
    expect(encounters.single.lairInitiative, 20);

    // v49: karsilasma <-> yer bagi eklenmis olmali.
    expect(encounters.single.locationId, isNull);

    // v48: oyuncu paneline ozel sutunlar dusurulmus olmali.
    final columns = await db
        .customSelect('PRAGMA table_info(combatants)')
        .get()
        .then((rows) => {for (final r in rows) r.read<String>('name')});
    expect(columns, isNot(contains('initiative_rolled')));
    expect(columns, isNot(contains('hidden_from_players')));

    final version = await db
        .customSelect('PRAGMA user_version')
        .getSingle()
        .then((r) => r.read<int>('user_version'));
    expect(version, 51);
    await db.close();
  });

  test('yeni tablolar kurulur', () async {
    final file = File(p.join(tmp.path, 'v47b.sqlite'));
    final db = openOverV46(file);

    // Yeni tablolarin hepsi sorgulanabilir olmali; kurulmadiysa burada patlar.
    expect(await db.select(db.encounterTemplates).get(), isEmpty);
    expect(await db.select(db.macros).get(), isEmpty);
    expect(await db.select(db.downtimeActivities).get(), isEmpty);
    expect(await db.select(db.factions).get(), isEmpty);
    expect(await db.select(db.clocks).get(), isEmpty);
    await db.close();
  });

  test('v50 "uyelik" bag turunu ekler', () async {
    // `ensureDefaultBondTypes` yalnizca TAMAMEN bos tabloyu tohumluyor, yani
    // mevcut kampanyalar yeni varsayilani oradan alamaz; migration ekliyor.
    final file = File(p.join(tmp.path, 'v50bond.sqlite'));
    final db = openOverV46(
      file,
      seed: [
        'CREATE TABLE IF NOT EXISTS bond_types (code TEXT NOT NULL, '
            'name TEXT NOT NULL, color INTEGER NOT NULL, '
            'sort_order INTEGER NOT NULL DEFAULT 0, PRIMARY KEY (code))',
        "INSERT INTO bond_types (code, name, color) "
            "VALUES ('friendship', 'Dostluk', 1)",
      ],
    );

    final codes = (await db.select(db.bondTypes).get()).map((b) => b.code);
    expect(codes, contains('membership'));
    // Kullanicinin kendi adlandirmasi EZILMEMELI.
    expect(
      (await db.select(db.bondTypes).get())
          .firstWhere((b) => b.code == 'friendship')
          .name,
      'Dostluk',
    );
    await db.close();
  });

  test('yarim kalmis guncelleme ikinci acilista tamamlanir', () async {
    // Drift `onUpgrade`'i tek islemde kosturmuyor: zincirin ortasinda bir
    // adim patlarsa eklenen sutunlar KALIR ama `user_version` ilerlemez.
    // Ikinci acilista blok bastan kosar ve "duplicate column" ile patmamali.
    final file = File(p.join(tmp.path, 'v47c.sqlite'));
    final half = AppDatabase(
      NativeDatabase(
        file,
        setup: (raw) {
          for (final statement in _v46Combat) {
            raw.execute(statement);
          }
          raw.execute(
            'ALTER TABLE combatants ADD COLUMN reaction_used INTEGER NOT NULL '
            'DEFAULT 0',
          );
          raw.execute('PRAGMA user_version = 46');
        },
      ),
    );

    // Acilis PATLAMAMALI: yariya kadar eklenmis sutun tekrar eklenmeye
    // calisilmamali.
    expect(await half.select(half.combatants).get(), isEmpty);
    final version = await half
        .customSelect('PRAGMA user_version')
        .getSingle()
        .then((r) => r.read<int>('user_version'));
    expect(version, 51);
    await half.close();
  });
}

/// v46'daki savas tablolarinin (v47 oncesi) semasi.
const _v46Combat = <String>[
  '''
    CREATE TABLE IF NOT EXISTS encounters (
      id TEXT NOT NULL PRIMARY KEY,
      name TEXT NOT NULL,
      active_index INTEGER NOT NULL DEFAULT 0,
      round INTEGER NOT NULL DEFAULT 1,
      started INTEGER NOT NULL DEFAULT 0,
      briefing_json TEXT NULL,
      loot_json TEXT NULL,
      created_at INTEGER NOT NULL DEFAULT (unixepoch())
    )
  ''',
  '''
    CREATE TABLE IF NOT EXISTS combatants (
      id TEXT NOT NULL PRIMARY KEY,
      encounter_id TEXT NOT NULL REFERENCES encounters (id),
      kind TEXT NOT NULL,
      name TEXT NOT NULL,
      character_id TEXT NULL,
      monster_key TEXT NULL,
      initiative INTEGER NOT NULL DEFAULT 0,
      initiative_rolled INTEGER NOT NULL DEFAULT 1,
      sort_order INTEGER NOT NULL DEFAULT 0,
      hit_points_max INTEGER NOT NULL DEFAULT 0,
      hit_points_current INTEGER NOT NULL DEFAULT 0,
      temporary_hit_points INTEGER NOT NULL DEFAULT 0,
      armor_class INTEGER NULL,
      conditions_json TEXT NOT NULL DEFAULT '[]',
      legendary_max INTEGER NULL,
      legendary_spent INTEGER NOT NULL DEFAULT 0,
      legendary_resist_max INTEGER NULL,
      legendary_resist_spent INTEGER NOT NULL DEFAULT 0,
      concentrating INTEGER NOT NULL DEFAULT 0,
      concentration_note TEXT NULL,
      hidden_from_players INTEGER NOT NULL DEFAULT 0,
      defeated INTEGER NOT NULL DEFAULT 0,
      note TEXT NOT NULL DEFAULT ''
    )
  ''',
];
