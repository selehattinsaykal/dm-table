import 'dart:convert';
import 'dart:io';

import 'package:dm_table/domain/rules/origin_parsing.dart';
import 'package:dm_table/domain/rules/proficiency_parsing.dart';
import 'package:flutter_test/flutter_test.dart';

List<Map<String, dynamic>> _bundle(String kind) {
  final bytes = File('assets/data/$kind.json.gz').readAsBytesSync();
  return (jsonDecode(utf8.decode(gzip.decode(bytes))) as List)
      .cast<Map<String, dynamic>>();
}

void main() {
  group('parseClassProficiencies', () {
    test('paketteki 13 sinifin tamami ayristirilabiliyor', () {
      // Ayristirma TAM DEGER eslesmesi; veri yeniden uretilip bir dize
      // degisirse sessizce bos yeterlilik uretmek yerine burada patlamali.
      final problems = <String>[];
      var parsed = 0;
      for (final row in _bundle('classes')) {
        for (final f
            in (row['features'] as List? ?? const [])
                .cast<Map<String, dynamic>>()) {
          if (f['feature_type'] != 'CORE_TRAITS_TABLE') continue;
          final core = parseClassCoreTraits('${f['desc'] ?? ''}');
          final grant = parseClassProficiencies(
            armorText: core.armorText,
            weaponText: core.weaponText,
            toolText: core.toolText,
          );
          parsed++;
          for (final u in grant.unparsed) {
            problems.add('${row['key']}: $u');
          }
        }
      }
      expect(parsed, greaterThanOrEqualTo(13));
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('Fighter tam zirh ve silah egitimi alir', () {
      final grant = parseClassProficiencies(
        armorText: 'Light, Medium, and Heavy armor and Shields',
        weaponText: 'Simple and Martial weapons',
      );
      expect(grant.armor, {
        ArmorTraining.light,
        ArmorTraining.medium,
        ArmorTraining.heavy,
        ArmorTraining.shield,
      });
      expect(grant.weapons, {
        WeaponProficiency.simple,
        WeaponProficiency.martial,
      });
      expect(grant.choices, isEmpty);
    });

    test('"None" zirh egitimi bos kume, ayristirma hatasi degil', () {
      final grant = parseClassProficiencies(armorText: 'None');
      expect(grant.armor, isEmpty);
      expect(grant.unparsed, isEmpty);
    });

    test('Rogue kosullu martial yeterliligi ayri bir deger olarak tutar', () {
      final grant = parseClassProficiencies(
        weaponText:
            'Simple weapons and Martial weapons that have the Finesse or '
            'Light property',
      );
      expect(grant.weapons, {
        WeaponProficiency.simple,
        WeaponProficiency.martialFinesseOrLight,
      });
    });

    test('Artificer hem alet verir hem secim birakir', () {
      final grant = parseClassProficiencies(
        toolText:
            "Thieves' Tools, Tinker's Tools, and one type of Artisan's Tools "
            'of your choice',
      );
      expect(grant.tools, {"Thieves' Tools", "Tinker's Tools"});
      expect(grant.choices, [
        const ProficiencyChoice(
          type: ProficiencyType.tool,
          count: 1,
          toolGroups: [ToolGroup.artisansTools],
        ),
      ]);
    });

    test('Bard uc calgi secimi birakir', () {
      final grant = parseClassProficiencies(
        toolText: 'Choose 3 Musical Instruments',
      );
      expect(grant.tools, isEmpty);
      expect(grant.choices.single.count, 3);
      expect(grant.choices.single.toolGroups, [ToolGroup.musicalInstrument]);
    });

    test('taninmayan dize sessizce dusmez', () {
      final grant = parseClassProficiencies(armorText: 'Powered Exoskeleton');
      expect(grant.armor, isEmpty);
      expect(grant.unparsed, {'Powered Exoskeleton'});
    });
  });

  group('parseBackgroundProficiencies', () {
    test('paketteki 55 background ayristirilabiliyor', () {
      final problems = <String>[];
      var seen = 0;
      for (final row in _bundle('backgrounds')) {
        for (final b
            in (row['benefits'] as List? ?? const [])
                .cast<Map<String, dynamic>>()) {
          if (b['name'] != 'Tool Proficiency') continue;
          seen++;
          final grant = parseBackgroundProficiencies('${b['desc'] ?? ''}');
          for (final u in grant.unparsed) {
            problems.add('${row['key']}: $u');
          }
        }
      }
      expect(seen, greaterThan(0));
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('dogrudan verilen alet secim birakmaz', () {
      final grant = parseBackgroundProficiencies("Calligrapher's Supplies");
      expect(grant.tools, {"Calligrapher's Supplies"});
      expect(grant.choices, isEmpty);
    });

    test('"Choose one kind of Gaming Set" secim birakir', () {
      final grant = parseBackgroundProficiencies(
        'Choose one kind of Gaming Set',
      );
      expect(grant.tools, isEmpty);
      expect(grant.choices.single.toolGroups, [ToolGroup.gamingSet]);
    });
  });

  group('featProficiencies', () {
    test('zirh feat\'leri dogru egitimi verir', () {
      expect(featProficiencies('Heavily Armored').armor, {ArmorTraining.heavy});
      expect(featProficiencies('Moderately Armored').armor, {
        ArmorTraining.medium,
      });
      expect(featProficiencies('Lightly Armored').armor, {
        ArmorTraining.light,
        ArmorTraining.shield,
      });
    });

    test('Martial Weapon Training martial silah yeterliligi verir', () {
      expect(featProficiencies('Martial Weapon Training').weapons, {
        WeaponProficiency.martial,
      });
    });

    test('dogrudan alet veren feat\'ler', () {
      expect(featProficiencies('Chef').tools, {"Cook's Utensils"});
      expect(featProficiencies('Poisoner').tools, {"Poisoner's Kit"});
    });

    test('Crafter uc zanaatkar aleti sectirir', () {
      final choice = featProficiencies('Crafter').choices.single;
      expect(choice.count, 3);
      expect(choice.toolGroups, [ToolGroup.artisansTools]);
    });

    test('Harper Agent hem dil verir hem calgi sectirir', () {
      final grant = featProficiencies('Harper Agent');
      expect(grant.languages, {"Thieves' Cant"});
      expect(grant.choices.single.toolGroups, [ToolGroup.musicalInstrument]);
    });

    test('Skilled secimi becerilere de aciktir', () {
      final choice = featProficiencies('Skilled').choices.single;
      expect(choice.count, 3);
      expect(choice.skillsAllowed, isTrue);
    });

    test('Weapon Master bir silah ustaligi sectirir', () {
      final choice = featProficiencies('Weapon Master').choices.single;
      expect(choice.type, ProficiencyType.weaponMastery);
      expect(choice.count, 1);
    });

    test('yeterlilik vermeyen feat bos doner', () {
      // Metninde "Proficiency Bonus" geciyor ama yeterlilik VERMIYOR.
      expect(featProficiencies('Alert').isEmpty, isTrue);
      expect(featProficiencies('Lucky').isEmpty, isTrue);
    });

    test('tablodaki her feat pakette gercekten var', () {
      // Ad degisirse esleme sessizce duser.
      final names = {
        for (final r in _bundle('feats')) '${r['name']}'.toLowerCase(),
      };
      for (final feat in [
        'Heavily Armored',
        'Moderately Armored',
        'Lightly Armored',
        'Martial Weapon Training',
        'Tavern Brawler',
        'Chef',
        'Poisoner',
        'Crafter',
        'Musician',
        'Harper Agent',
        'Skilled',
        'Weapon Master',
      ]) {
        expect(
          names,
          contains(feat.toLowerCase()),
          reason: '$feat pakette yok; grant tablosu bayat',
        );
      }
    });
  });

  group('classFeatureProficiencies', () {
    test('dil veren sinif ozellikleri', () {
      expect(classFeatureProficiencies('Druidic').languages, {'Druidic'});
      expect(classFeatureProficiencies("Thieves' Cant").languages, {
        "Thieves' Cant",
      });
      expect(
        classFeatureProficiencies('Deft Explorer').choices.single,
        const ProficiencyChoice(type: ProficiencyType.language, count: 2),
      );
    });

    test('tablodaki her ozellik pakette gercekten var', () {
      final names = <String>{};
      for (final row in _bundle('classes')) {
        for (final f
            in (row['features'] as List? ?? const [])
                .cast<Map<String, dynamic>>()) {
          names.add('${f['name']}'.toLowerCase());
        }
      }
      for (final feature in ['Druidic', "Thieves' Cant", 'Deft Explorer']) {
        expect(names, contains(feature.toLowerCase()), reason: feature);
      }
    });
  });

  group('weaponAllowedBy', () {
    test('simple yeterliligi martial silahi kapsamaz', () {
      const prof = {WeaponProficiency.simple};
      expect(weaponAllowedBy(prof, category: 'Simple', name: 'Club'), isTrue);
      expect(
        weaponAllowedBy(prof, category: 'Martial', name: 'Greatsword'),
        isFalse,
      );
    });

    test('kosullu martial yalnizca ozelligi tutan silahi kapsar', () {
      const prof = {
        WeaponProficiency.simple,
        WeaponProficiency.martialFinesseOrLight,
      };
      expect(
        weaponAllowedBy(
          prof,
          category: 'Martial',
          name: 'Rapier',
          properties: {'Finesse'},
        ),
        isTrue,
      );
      expect(
        weaponAllowedBy(
          prof,
          category: 'Martial',
          name: 'Greataxe',
          properties: {'Heavy', 'Two-Handed'},
        ),
        isFalse,
      );
    });

    test('tek tek verilen silah adi yeterlilik sayilir', () {
      expect(
        weaponAllowedBy({'Longsword'}, category: 'Martial', name: 'Longsword'),
        isTrue,
      );
    });
  });
}
