import 'dart:convert';

import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/import/fivetools/fivetools_convert.dart';
import 'package:dm_table/data/import/fivetools/fivetools_importer.dart';
import 'package:dm_table/data/import/fivetools/fivetools_text.dart';
import 'package:dm_table/data/db/tables.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('stripTags', () {
    test('bicimlendirme etiketleri metni birakir', () {
      expect(stripTags('{@b kalin} ve {@i egik}'), 'kalin ve egik');
    });

    test('ic ice etiketleri cozer', () {
      expect(stripTags('{@i vurur {@damage 2d6} hasar}'), 'vurur 2d6 hasar');
    });

    test('sayi etiketleri kendi bicimini uretir', () {
      expect(
        stripTags('{@hit 5} isabet, {@dc 15} zorluk'),
        '+5 isabet, DC 15 zorluk',
      );
      expect(stripTags('{@hit -1}'), '-1');
      expect(stripTags('{@recharge 5}'), '(Recharge 5-6)');
      expect(stripTags('{@recharge}'), '(Recharge 6)');
    });

    test('saldiri kisaltmalarini acar', () {
      expect(stripTags('{@atk mw} {@hit 4}'), 'Melee Weapon Attack: +4');
      expect(stripTags('{@atk rs}'), 'Ranged Spell Attack:');
    });

    test('basvurularda gorunen ad son parcadan gelir', () {
      expect(stripTags('{@creature goblin|MM|iblis}'), 'iblis');
      expect(stripTags('{@creature goblin|MM}'), 'goblin');
    });

    test('kapanmamis etiket metni yutmaz', () {
      expect(stripTags('once {@b sonra'), 'once {@b sonra');
    });
  });

  group('renderEntries', () {
    test('adli bolumleri baslikla birlestirir', () {
      final node = {
        'name': 'Kacamak',
        'entries': ['Zarar yarilanir.'],
      };
      expect(renderEntries(node), 'Kacamak. Zarar yarilanir.');
    });

    test('listeleri madde isaretiyle yazar', () {
      final node = {
        'type': 'list',
        'items': ['bir', 'iki'],
      };
      expect(renderEntries(node), '• bir\n• iki');
    });

    test('tabloyu satir satir cevirir', () {
      final node = {
        'type': 'table',
        'colLabels': ['d6', 'Sonuc'],
        'rows': [
          ['1', 'hicbir sey'],
        ],
      };
      expect(renderEntries(node), 'd6 | Sonuc\n1 | hicbir sey');
    });

    test('taninmayan tur icini okur', () {
      final node = {
        'type': 'yepyeniBirTur',
        'name': 'Baslik',
        'entries': ['govde'],
      };
      expect(renderEntries(node), 'Baslik. govde');
    });
  });

  group('resolveCopies', () {
    test('varyant temel kaydin alanlarini miras alir', () {
      final resolved = resolveCopies([
        {
          'name': 'Goblin',
          'source': 'MM',
          'hp': {'average': 7},
          'ac': [15],
        },
        {
          'name': 'Goblin Sefi',
          'source': 'MM',
          '_copy': {'name': 'Goblin', 'source': 'MM'},
          'hp': {'average': 21},
        },
      ]);

      final boss = resolved.firstWhere((e) => e['name'] == 'Goblin Sefi');
      expect((boss['hp'] as Map)['average'], 21, reason: 'kendi alani kazanir');
      expect(boss['ac'], [15], reason: 'temelden miras');
    });

    test('dongu kilitlemez', () {
      final resolved = resolveCopies([
        {
          'name': 'A',
          'source': 'X',
          '_copy': {'name': 'B', 'source': 'X'},
        },
        {
          'name': 'B',
          'source': 'X',
          '_copy': {'name': 'A', 'source': 'X'},
        },
      ]);
      expect(resolved, hasLength(2));
    });
  });

  group('converters', () {
    test('canavar temel alanlari cikarir', () {
      final converted = convertMonster({
        'name': 'Test Canavari',
        'source': 'HB',
        'size': ['L'],
        'type': 'beast',
        'ac': [
          {'ac': 14},
        ],
        'hp': {'average': 45},
        'cr': '3',
      });

      expect(converted, isNotNull);
      expect(converted!.name, 'Test Canavari');
      expect(converted.key, 'ft_monster_test-canavari_hb');
      expect(converted.armorClass, 14);
      expect(converted.hitPoints, 45);
      expect(converted.challengeRating, 3);
      expect(converted.size, 'Large');
    });

    test('kesirli CR sayiya cevrilir', () {
      final converted = convertMonster({
        'name': 'Sican',
        'source': 'HB',
        'cr': '1/8',
      });
      expect(converted!.challengeRating, 0.125);
    });

    test('buyu seviyesi ve okulu cozulur', () {
      final converted = convertSpell({
        'name': 'Atesyumrugu',
        'source': 'HB',
        'level': 3,
        'school': 'V',
      });
      expect(converted!.level, 3);
      expect(converted.school, 'Evocation');
    });

    test('nadirlikli esya buyulu sayilir', () {
      final magic = convertItem({
        'name': 'Yanan Kilic',
        'source': 'HB',
        'rarity': 'rare',
      });
      expect(magic!.rarity, isNotNull);

      final mundane = convertItem({
        'name': 'Halat',
        'source': 'HB',
        'rarity': 'none',
      });
      expect(mundane!.rarity, isNull);
    });
  });

  group('FiveToolsImporter', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('canavarlari kutuphaneye yazar', () async {
      final report = await FiveToolsImporter(db).importJsonBody(
        jsonDecode('''
        {"monster": [
          {"name": "Ates Kurdu", "source": "HB", "cr": "2",
           "hp": {"average": 30}, "ac": [13], "size": ["M"], "type": "beast"}
        ]}
        '''),
      );

      expect(report.monsters, 1);
      final rows = await db.select(db.monsters).get();
      expect(rows, hasLength(1));
      expect(rows.single.name, 'Ates Kurdu');
      expect(rows.single.experiencePoints, 450, reason: 'CR 2 -> 450 XP');
      // Kaynak turu KISISEL: paketlenmis SRD tazelenince silinmemeli.
      expect(rows.single.sourceType, SourceType.personal);
    });

    test('ayni kaydi iki kez aktarmak cogaltmaz', () async {
      const body = '{"spell": [{"name": "Isik", "source": "HB", "level": 0}]}';
      final importer = FiveToolsImporter(db);
      await importer.importJsonBody(jsonDecode(body));
      await importer.importJsonBody(jsonDecode(body));

      expect(await db.select(db.spells).get(), hasLength(1));
    });

    test('esyalari nadirlige gore iki tabloya ayirir', () async {
      await FiveToolsImporter(db).importJsonBody(
        jsonDecode('''
        {"item": [
          {"name": "Yanan Kilic", "source": "HB", "rarity": "rare"},
          {"name": "Halat", "source": "HB", "rarity": "none"}
        ]}
        '''),
      );

      expect(await db.select(db.magicItems).get(), hasLength(1));
      expect(await db.select(db.items).get(), hasLength(1));
    });

    test('silme yalnizca aktarilan kayitlari kaldirir', () async {
      await FiveToolsImporter(db).importJsonBody(
        jsonDecode('{"spell": [{"name": "Isik", "source": "HB", "level": 0}]}'),
      );
      // Kullanicinin uygulama icinde olusturdugu bir kayit.
      await db
          .into(db.spells)
          .insert(
            SpellsCompanion.insert(
              key: 'custom_ev',
              name: 'Ev Buyusu',
              nameLower: 'ev buyusu',
              dataJson: '{}',
            ),
          );

      final removed = await FiveToolsImporter(db).deleteImported();
      expect(removed, 1);
      final left = await db.select(db.spells).get();
      expect(left.single.key, 'custom_ev');
    });
  });
}
