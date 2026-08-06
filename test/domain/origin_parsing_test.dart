import 'dart:convert';
import 'dart:io';

import 'package:dm_table/domain/models/ability.dart';
import 'package:dm_table/domain/rules/origin_parsing.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ayristirici gercek SRD metinleri uzerinde calisiyor mu?
///
/// Fixture uydurmak yerine paketlenmis veri dogrudan okunuyor: metin bicimi
/// degisirse burasi kirilmali, sessizce bos donmemeli.
void main() {
  List<Map<String, dynamic>> load(String name) =>
      (jsonDecode(
                utf8.decode(
                  gzip.decode(
                    File('assets/data/$name.json.gz').readAsBytesSync(),
                  ),
                ),
              )
              as List)
          .cast<Map<String, dynamic>>();

  late List<Map<String, dynamic>> backgrounds;
  late List<Map<String, dynamic>> species;

  setUpAll(() {
    backgrounds = load('backgrounds');
    species = load('species');
  });

  group('background', () {
    BackgroundBenefits parse(String name) => parseBackgroundBenefits(
      backgrounds.firstWhere((b) => b['name'] == name)['benefits'] as List,
    );

    test('Acolyte tam olarak ayristirilir', () {
      final b = parse('Acolyte');

      expect(b.abilityOptions, [
        Ability.intelligence,
        Ability.wisdom,
        Ability.charisma,
      ]);
      expect(b.skills, [Skill.insight, Skill.religion]);
      expect(b.toolText, "Calligrapher's Supplies");
      expect(b.featName, 'Magic Initiate');
      expect(b.featNote, 'Cleric');
    });

    test('parantezsiz feat notsuz gelir', () {
      final b = parse('Criminal');
      expect(b.featName, 'Alert');
      expect(b.featNote, isNull);
    });

    test('"X and Y" biciminde beceriler bolunur', () {
      expect(parse('Criminal').skills, [Skill.sleightOfHand, Skill.stealth]);
      expect(parse('Sage').skills, [Skill.arcana, Skill.history]);
      expect(parse('Soldier').skills, [Skill.athletics, Skill.intimidation]);
    });

    test('dort background da uc yetenek secenegi verir', () {
      for (final bg in backgrounds) {
        final b = parseBackgroundBenefits(bg['benefits'] as List);
        expect(
          b.abilityOptions.length,
          3,
          reason: '${bg['name']} icin 3 yetenek bekleniyordu',
        );
      }
    });

    test('ekipman A/B secenekleri adet ve altinla ayrilir', () {
      final b = parse('Criminal');
      expect(b.equipmentOptions.length, 2);

      final a = b.equipmentOptions.first;
      expect(a.label, 'A');
      expect(a.goldPieces, 16);
      expect(
        a.entries.map((e) => e.name),
        containsAll(['Daggers', "Thieves' Tools", 'Crowbar']),
      );
      // "2 Daggers" -> adet 2
      expect(a.entries.firstWhere((e) => e.name == 'Daggers').quantity, 2);
      // "2 Pouches"
      expect(a.entries.firstWhere((e) => e.name == 'Pouches').quantity, 2);

      final bOpt = b.equipmentOptions.last;
      expect(bOpt.label, 'B');
      expect(bOpt.goldPieces, 50);
      expect(bOpt.entries, isEmpty);
    });

    test('parantezli esya adlari bolunmez', () {
      final a = parse('Acolyte').equipmentOptions.first;
      expect(a.entries.map((e) => e.name), contains('Book (prayers)'));
      expect(a.entries.map((e) => e.name), contains('Parchment (10 sheets)'));
    });

    test('ham metin her zaman korunur', () {
      final b = parse('Soldier');
      expect(b.rawByType['tool_proficiency'], 'Choose one kind of Gaming Set');
    });
  });

  group('sinif cekirdek ozellikleri', () {
    late List<Map<String, dynamic>> classes;

    setUpAll(() => classes = load('classes'));

    ClassCoreTraits parse(String name) {
      final c = classes.firstWhere((r) => r['name'] == name);
      final core = (c['features'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((f) => '${f['feature_type']}' == 'CORE_TRAITS_TABLE');
      return parseClassCoreTraits('${core['desc']}');
    }

    test('Barbarian tablosu okunur', () {
      final t = parse('Barbarian');
      expect(t.primaryAbility, Ability.strength);
      expect(t.hitDieSides, 12);
      expect(t.savingThrows, {Ability.strength, Ability.constitution});
      expect(t.skillChoiceCount, 2);
      expect(t.anySkill, isFalse);
      expect(t.skillOptions, [
        Skill.animalHandling,
        Skill.athletics,
        Skill.intimidation,
        Skill.nature,
        Skill.perception,
        Skill.survival,
      ]);
    });

    test('Bard "herhangi 3 beceri" olarak isaretlenir', () {
      final t = parse('Bard');
      expect(t.skillChoiceCount, 3);
      expect(t.anySkill, isTrue);
      expect(t.skillOptions, isEmpty);
    });

    test('veri hatasina ragmen Insight eslesir', () {
      // SRD metninde "In sight" yazim hatasi var.
      expect(parse('Wizard').skillOptions, contains(Skill.insight));
    });

    test('sinif baslangic ekipmani "and 15 GP" bicimini de cozer', () {
      final options = parse('Barbarian').equipmentOptions;
      expect(options.length, 2);
      expect(options.first.goldPieces, 15);
      expect(options.first.entries.map((e) => e.name), contains('Greataxe'));
      expect(
        options.first.entries.firstWhere((e) => e.name == 'Handaxes').quantity,
        4,
      );
      expect(options.last.goldPieces, 75);
    });

    test('on iki ana sinifin hepsi cozulur', () {
      for (final c in classes.where((r) => r['subclass_of'] == null)) {
        final core = (c['features'] as List)
            .cast<Map<String, dynamic>>()
            .where((f) => '${f['feature_type']}' == 'CORE_TRAITS_TABLE')
            .firstOrNull;
        expect(core, isNotNull, reason: '${c['name']} cekirdek tablosu yok');

        final t = parseClassCoreTraits('${core!['desc']}');
        expect(t.hitDieSides, greaterThan(0), reason: '${c['name']} hit die');
        expect(
          t.savingThrows.length,
          2,
          reason: '${c['name']} iki kurtarma atisi bekleniyordu',
        );
        expect(
          t.skillChoiceCount,
          greaterThan(0),
          reason: '${c['name']} beceri secim sayisi',
        );
        expect(
          t.equipmentOptions.length,
          2,
          reason: '${c['name']} A/B ekipman secenegi',
        );
      }
    });
  });

  group('tur', () {
    SpeciesTraits parse(String name) => parseSpeciesTraits(
      species.firstWhere((s) => s['name'] == name)['traits'] as List,
    );

    test('tek boyut ve hiz okunur', () {
      final dragonborn = parse('Dragonborn');
      expect(dragonborn.sizes, ['Medium']);
      expect(dragonborn.speed, 30);
    });

    test('Goliath 35 feet hizinda', () {
      expect(parse('Goliath').speed, 35);
    });

    test('secimli boyutta iki secenek dondurulur', () {
      expect(parse('Human').sizes, ['Small', 'Medium']);
      expect(parse('Tiefling').sizes, ['Small', 'Medium']);
    });

    test('dokuz turun hepsinde boyut ve hiz cozulur', () {
      for (final s in species) {
        final t = parseSpeciesTraits(s['traits'] as List);
        expect(t.sizes, isNotEmpty, reason: '${s['name']} boyutu okunamadi');
        expect(t.speed, greaterThan(0), reason: '${s['name']} hizi okunamadi');
      }
    });
  });
}
