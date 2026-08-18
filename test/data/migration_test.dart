import 'dart:io';

import 'package:dm_table/data/db/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Migration korumasi.
///
/// **Bu dosya neden var:** normal testler `AppDatabase(NativeDatabase.memory())`
/// ile aciliyor, bu da `onCreate` -> `createAll()` yolunu isletiyor. Yani bir
/// kolon tablo sinifina eklenip `onUpgrade`'e `addColumn` YAZILMAZSA butun
/// testler gecer ve hata yalnizca gercek (eski) bir kampanya dosyasinda
/// "no such column" olarak patlar. Bu tam olarak projede bir kez yasandi
/// (v19'da eklenen `nodeRadius` icin migration yazilmamisti).
///
/// Buradaki testler eski surumde bir veritabani kurar, uzerine `AppDatabase`
/// acar ve yeni kolonlarin/tablolarin GERCEKTEN olustugunu dogrular.
void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('dm_masasi_migration');
  });

  tearDown(() async {
    // Windows'ta sqlite dosyasi kisa sure kilitli kalabiliyor; temizlik
    // basarisiz olursa test sonucunu bozmasin.
    try {
      if (tmp.existsSync()) await tmp.delete(recursive: true);
    } on FileSystemException {
      // Gecici dizin; isletim sistemi sonra temizler.
    }
  });

  /// v23 seklinde bir veritabani kurar ve `user_version`'i 23'e sabitler;
  /// boylece acilista v23 -> guncel migration zinciri calisir.
  ///
  /// **Migration zincirinin `addColumn` yaptigi HER tablo burada bulunmali**
  /// (`createTable` yapanlar gerekmez, migration kendisi kurar). Su an:
  /// `locations` (v24), `combatants` (v27), `shops` + `shop_stock` (v28),
  /// `encounters` (v32).
  /// Yeni bir `addColumn` migration'i eklenirse ilgili tablo buraya da
  /// eklenmeli, yoksa bu test "no such table" ile patlar.
  AppDatabase openOverV23(File file) => AppDatabase(
    NativeDatabase(
      file,
      setup: (raw) {
        raw.execute('''
          CREATE TABLE IF NOT EXISTS locations (
            id TEXT NOT NULL,
            name TEXT NOT NULL,
            parent_id TEXT NULL,
            description TEXT NOT NULL DEFAULT '',
            secret_notes TEXT NOT NULL DEFAULT '',
            map_image_path TEXT NULL,
            map_preview_path TEXT NULL,
            map_width INTEGER NULL,
            map_height INTEGER NULL,
            revealed INTEGER NOT NULL DEFAULT 0,
            graph_x REAL NULL,
            graph_y REAL NULL,
            node_radius REAL NULL,
            sort_order INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (id)
          )
        ''');
        raw.execute('''
          CREATE TABLE IF NOT EXISTS encounters (
            id TEXT NOT NULL,
            name TEXT NOT NULL,
            active_index INTEGER NOT NULL DEFAULT 0,
            round INTEGER NOT NULL DEFAULT 1,
            started INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            PRIMARY KEY (id)
          )
        ''');
        raw.execute('''
          CREATE TABLE IF NOT EXISTS combatants (
            id TEXT NOT NULL,
            encounter_id TEXT NOT NULL,
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
            concentrating INTEGER NOT NULL DEFAULT 0,
            concentration_note TEXT NULL,
            hidden_from_players INTEGER NOT NULL DEFAULT 0,
            defeated INTEGER NOT NULL DEFAULT 0,
            note TEXT NOT NULL DEFAULT '',
            PRIMARY KEY (id)
          )
        ''');
        raw.execute('''
          CREATE TABLE IF NOT EXISTS shops (
            id TEXT NOT NULL,
            name TEXT NOT NULL,
            owner_name TEXT NULL,
            description TEXT NOT NULL DEFAULT '',
            price_multiplier REAL NOT NULL DEFAULT 1,
            open_to_players INTEGER NOT NULL DEFAULT 0,
            map_accessible INTEGER NOT NULL DEFAULT 0,
            closed INTEGER NOT NULL DEFAULT 0,
            requires_approval INTEGER NOT NULL DEFAULT 1,
            created_at INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (id)
          )
        ''');
        raw.execute('''
          CREATE TABLE IF NOT EXISTS shop_stock (
            id TEXT NOT NULL,
            shop_id TEXT NOT NULL,
            item_key TEXT NULL,
            magic_item_key TEXT NULL,
            custom_name TEXT NULL,
            custom_desc TEXT NULL,
            price_cp_override INTEGER NULL,
            quantity INTEGER NOT NULL DEFAULT -1,
            sort_order INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (id)
          )
        ''');
        raw.execute('PRAGMA user_version = 23;');
      },
    ),
  );

  test(
    'v23 -> guncel: locations.map_width_miles olusur ve yazilabilir',
    () async {
      final file = File(p.join(tmp.path, 'v23.sqlite'));
      final db = openOverV23(file);

      // Ilk sorgu migration'i tetikler.
      await db.customStatement(
        "INSERT INTO locations (id, name) VALUES ('loc-1', 'Kale')",
      );
      await db.customStatement(
        'UPDATE locations SET map_width_miles = 120.0, '
        'map_height_miles = 60.0 WHERE id = ?',
        ['loc-1'],
      );

      final row = await db
          .customSelect(
            'SELECT map_width_miles, map_height_miles FROM locations',
          )
          .getSingle();
      expect(row.data['map_width_miles'], 120.0);
      expect(row.data['map_height_miles'], 60.0);

      await db.close();
    },
  );

  test('v23 -> guncel: eski satirlarin verisi korunur', () async {
    final file = File(p.join(tmp.path, 'v23_data.sqlite'));

    // Once v23 semasina veri yaz (AppDatabase acilmadan).
    final seed = openOverV23(file);
    await seed.customStatement(
      "INSERT INTO locations (id, name, description) "
      "VALUES ('loc-eski', 'Eski Sehir', 'migration oncesi')",
    );
    await seed.close();

    // Yeniden ac: migration calismis olmali, veri yerinde durmali.
    final db = AppDatabase(NativeDatabase(file));
    final row = await db
        .customSelect(
          'SELECT name, description, map_width_miles FROM locations '
          "WHERE id = 'loc-eski'",
        )
        .getSingle();
    expect(row.data['name'], 'Eski Sehir');
    expect(row.data['description'], 'migration oncesi');
    // Yeni kolon var ve eski satirda bos.
    expect(row.data['map_width_miles'], isNull);

    await db.close();
  });

  test('v23 -> guncel: party_inventories tablosu olusur', () async {
    final file = File(p.join(tmp.path, 'v23_party.sqlite'));
    final db = openOverV23(file);

    await db.customStatement(
      "INSERT INTO party_inventories (id, name, coins_cp, items_json, "
      "members_json, sort_order, created_at) "
      "VALUES ('p1', 'Parti kesesi', 100, '[]', '[]', 0, 0)",
    );
    final row = await db
        .customSelect('SELECT name, coins_cp FROM party_inventories')
        .getSingle();
    expect(row.data['name'], 'Parti kesesi');
    expect(row.data['coins_cp'], 100);

    await db.close();
  });

  test('v23 -> guncel: combatants efsanevi kolonlari olusur', () async {
    final file = File(p.join(tmp.path, 'v23_legendary.sqlite'));
    final db = openOverV23(file);

    await db.customStatement(
      "INSERT INTO combatants (id, encounter_id, kind, name) "
      "VALUES ('c1', 'e1', 'monster', 'Aboleth')",
    );
    await db.customStatement(
      'UPDATE combatants SET legendary_max = 3, legendary_spent = 1, '
      'legendary_resist_max = 3 WHERE id = ?',
      ['c1'],
    );

    final row = await db
        .customSelect(
          'SELECT legendary_max, legendary_spent, legendary_resist_max, '
          'legendary_resist_spent FROM combatants',
        )
        .getSingle();
    expect(row.data['legendary_max'], 3);
    expect(row.data['legendary_spent'], 1);
    expect(row.data['legendary_resist_max'], 3);
    expect(row.data['legendary_resist_spent'], 0, reason: 'varsayılan 0');

    await db.close();
  });

  test('v23 -> guncel: magaza stok yenileme kolonlari olusur', () async {
    final file = File(p.join(tmp.path, 'v23_restock.sqlite'));
    final db = openOverV23(file);

    await db.customStatement(
      "INSERT INTO shops (id, name) VALUES ('s1', 'Simyacı')",
    );
    await db.customStatement(
      "INSERT INTO shop_stock (id, shop_id, custom_name, quantity) "
      "VALUES ('st1', 's1', 'İksir', 0)",
    );
    await db.customStatement(
      'UPDATE shops SET restock_days = 7, last_restock_day = 40 WHERE id = ?',
      ['s1'],
    );
    await db.customStatement(
      'UPDATE shop_stock SET restock_quantity = 5 WHERE id = ?',
      ['st1'],
    );

    final shop = await db
        .customSelect('SELECT restock_days, last_restock_day FROM shops')
        .getSingle();
    expect(shop.data['restock_days'], 7);
    expect(shop.data['last_restock_day'], 40);

    final stock = await db
        .customSelect('SELECT restock_quantity FROM shop_stock')
        .getSingle();
    expect(stock.data['restock_quantity'], 5);

    await db.close();
  });

  test('v23 -> guncel: journeys tablosu olusur', () async {
    final file = File(p.join(tmp.path, 'v23_journey.sqlite'));
    final db = openOverV23(file);

    await db.customStatement(
      "INSERT INTO journeys (id, location_id, stops_json, extra_miles, "
      "speed_key, hours_per_day, encounters_on, threshold, checks_per_day, "
      "total_miles, miles_travelled, checks_done, days_advanced, "
      "advance_calendar, encounter_log_json, done, created_at) "
      "VALUES ('j1', 'loc-1', '[]', 0, 'travelPaceNormal', 8, 0, 18, 1, "
      "72, 12.5, 1, 1, 1, '[]', 0, 0)",
    );

    final row = await db
        .customSelect(
          'SELECT total_miles, miles_travelled, checks_done FROM journeys',
        )
        .getSingle();
    expect(row.data['total_miles'], 72);
    expect(row.data['miles_travelled'], 12.5);
    expect(row.data['checks_done'], 1);

    await db.close();
  });

  test('v23 -> guncel: magaza isleten NPC kolonu olusur', () async {
    final file = File(p.join(tmp.path, 'v23_shop_owner.sqlite'));
    final db = openOverV23(file);

    await db.customStatement(
      "INSERT INTO shops (id, name, owner_name) "
      "VALUES ('s1', 'Simyacı', 'Eski Kayıt')",
    );
    await db.customStatement('UPDATE shops SET owner_npc_id = ? WHERE id = ?', [
      'npc-1',
      's1',
    ]);

    final row = await db
        .customSelect('SELECT owner_npc_id, owner_name FROM shops')
        .getSingle();
    expect(row.data['owner_npc_id'], 'npc-1');
    // Eski satirlar korunmali: ad alani migration'da silinmiyor.
    expect(row.data['owner_name'], 'Eski Kayıt');

    await db.close();
  });

  test('v23 -> guncel: muzik ve hatirlatici tablolari olusur', () async {
    final file = File(p.join(tmp.path, 'v23_music.sqlite'));
    final db = openOverV23(file);

    await db.customStatement(
      "INSERT INTO music_playlists (id, name) VALUES ('pl1', 'Savaş')",
    );
    await db.customStatement(
      "INSERT INTO music_tracks (id, playlist_id, title, path) "
      "VALUES ('tr1', 'pl1', 'Kuşatma', 'music/a.mp3')",
    );
    await db.customStatement(
      "INSERT INTO calendar_reminders "
      "(id, title, repeat_kind, start_year, start_month_index, start_day) "
      "VALUES ('r1', 'Vergi', 'monthly', 1492, 0, 1)",
    );

    expect(
      (await db.customSelect('SELECT title FROM music_tracks').getSingle())
          .data['title'],
      'Kuşatma',
    );
    expect(
      (await db
              .customSelect('SELECT repeat_kind FROM calendar_reminders')
              .getSingle())
          .data['repeat_kind'],
      'monthly',
    );

    await db.close();
  });

  test('schemaVersion migration bloklariyla tutarli', () async {
    // Temiz bir DB'nin user_version'i schemaVersion ile ayni olmali; biri
    // bumplanip digeri unutulursa buradan yakalanir.
    final db = AppDatabase(NativeDatabase.memory());
    await db.customStatement('SELECT 1'); // acilisi tetikle
    final row = await db.customSelect('PRAGMA user_version').getSingle();
    expect(row.data.values.first, db.schemaVersion);
    await db.close();
  });
  test('v23 -> guncel: encounters brifing/ganimet kolonlari olusur', () async {
    final file = File(p.join(tmp.path, 'v23_encounter_panels.sqlite'));
    final db = openOverV23(file);

    await db.customStatement(
      "INSERT INTO encounters (id, name, created_at) "
      "VALUES ('e1', 'Bogazda pusu', 0)",
    );
    await db.customStatement(
      'UPDATE encounters SET briefing_json = ?, loot_json = ? WHERE id = ?',
      ['{"objective":"Sag cik"}', '{"coinsCp":500,"items":[]}', 'e1'],
    );

    final row = await db
        .customSelect('SELECT briefing_json, loot_json FROM encounters')
        .getSingle();
    expect(row.data['briefing_json'], contains('Sag cik'));
    expect(row.data['loot_json'], contains('500'));

    await db.close();
  });
}
