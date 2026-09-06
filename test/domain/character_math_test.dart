import 'package:dm_table/domain/models/ability.dart';
import 'package:dm_table/domain/models/character_build.dart';
import 'package:dm_table/domain/rules/character_math.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kural motorunun altin standardi: elle hesaplanmis, bilinen karakterler.
void main() {
  ClassLevel fighter(int level) => ClassLevel(
    classKey: 'srd-2024_fighter',
    level: level,
    casterType: CasterType.none,
    hitDieSides: 10,
    isPrimary: true,
  );

  group('yetenek modifieri', () {
    test('asagi yuvarlar, 10 altinda da dogru', () {
      const s = AbilityScores(
        strength: 20,
        dexterity: 15,
        constitution: 10,
        intelligence: 9,
        wisdom: 8,
        charisma: 7,
      );
      expect(s.modifier(Ability.strength), 5);
      expect(s.modifier(Ability.dexterity), 2);
      expect(s.modifier(Ability.constitution), 0);
      // Bunlar `~/` ile hesaplansa 0 / -1 / -1 cikardi.
      expect(s.modifier(Ability.intelligence), -1);
      expect(s.modifier(Ability.wisdom), -1);
      expect(s.modifier(Ability.charisma), -2);
    });
  });

  group('yeterlilik bonusu', () {
    test('4 seviyede bir artar', () {
      for (final (level, expected) in [
        (1, 2),
        (4, 2),
        (5, 3),
        (8, 3),
        (9, 4),
        (12, 4),
        (13, 5),
        (16, 5),
        (17, 6),
        (20, 6),
      ]) {
        final build = CharacterBuild(
          abilities: const AbilityScores(),
          classes: [fighter(level)],
        );
        expect(build.proficiencyBonus, expected, reason: '$level. seviye');
      }
    });
  });

  group('zirh sinifi', () {
    test('agir zirh Dex eklemez', () {
      final build = CharacterBuild(
        abilities: const AbilityScores(dexterity: 16),
        classes: [fighter(1)],
        // Chain Mail
        armor: const ArmorPiece(baseAc: 16),
      );
      expect(build.armorClass, 16);
    });

    test('orta zirhta Dex +2 ile sinirli', () {
      final build = CharacterBuild(
        abilities: const AbilityScores(dexterity: 18), // +4
        classes: [fighter(1)],
        // Half Plate
        armor: const ArmorPiece(
          baseAc: 15,
          addDexModifier: true,
          maxDexModifier: 2,
        ),
      );
      expect(build.armorClass, 17);
    });

    test('hafif zirhta Dex tam eklenir, kalkan +2', () {
      final build = CharacterBuild(
        abilities: const AbilityScores(dexterity: 16), // +3
        classes: [fighter(1)],
        // Studded Leather
        armor: const ArmorPiece(baseAc: 12, addDexModifier: true),
        hasShield: true,
      );
      expect(build.armorClass, 17);
    });

    test('Monk: Unarmored Defense WIS ekler', () {
      final build = CharacterBuild(
        abilities: const AbilityScores(dexterity: 16, wisdom: 14),
        classes: [
          const ClassLevel(
            classKey: 'srd-2024_monk',
            level: 5,
            casterType: CasterType.none,
            hitDieSides: 8,
            isPrimary: true,
          ),
        ],
        unarmoredDefenseAbility: Ability.wisdom,
      );
      expect(build.armorClass, 15); // 10 + 3 + 2
    });

    test('zirhsiz ve ozel yetenek yoksa 10 + Dex', () {
      final build = CharacterBuild(
        abilities: const AbilityScores(dexterity: 12),
        classes: [fighter(1)],
      );
      expect(build.armorClass, 11);
    });
  });

  group('beceri ve kurtarma', () {
    final build = CharacterBuild(
      abilities: const AbilityScores(dexterity: 16, wisdom: 14),
      classes: [fighter(5)], // PB 3
      skillProficiencies: {Skill.perception, Skill.stealth},
      skillExpertise: {Skill.stealth},
      saveProficiencies: {Ability.strength},
    );

    test('yeterlilik bonusu eklenir', () {
      expect(build.skillModifier(Skill.perception), 5); // +2 WIS +3 PB
    });

    test('uzmanlik yeterlilik bonusunu ikiye katlar', () {
      expect(build.skillModifier(Skill.stealth), 9); // +3 DEX +6
    });

    test('yeterlilik yoksa sadece yetenek modifieri', () {
      expect(build.skillModifier(Skill.acrobatics), 3);
    });

    test('pasif algi 10 + beceri modifieri', () {
      expect(build.passivePerception, 15);
    });

    test('kurtarma atisinda yeterlilik', () {
      expect(build.savingThrow(Ability.strength), 3); // 0 + 3
      expect(build.savingThrow(Ability.dexterity), 3); // +3, yeterlilik yok
    });
  });

  test('tukenmislik tum d20 testlerine seviye basina -1 verir', () {
    final build = CharacterBuild(
      abilities: const AbilityScores(dexterity: 16, wisdom: 14),
      classes: [fighter(5)],
      skillProficiencies: {Skill.perception},
      saveProficiencies: {Ability.strength},
      exhaustion: 2,
    );
    expect(build.skillModifier(Skill.perception), 3); // 5 - 2
    expect(build.savingThrow(Ability.strength), 1); // 3 - 2
    expect(build.initiative, 1); // 3 - 2
    // AC bir d20 testi degil, etkilenmemeli.
    expect(build.armorClass, 13);
  });

  group('can puani', () {
    test('1. seviyede hit die tam alinir', () {
      final build = CharacterBuild(
        abilities: const AbilityScores(constitution: 14), // +2
        classes: [fighter(1)],
      );
      expect(build.maxHitPoints, 12); // 10 + 2
    });

    test('sonraki seviyelerde ortalama kullanilir', () {
      final build = CharacterBuild(
        abilities: const AbilityScores(constitution: 14),
        classes: [fighter(3)],
      );
      // 10 + (6 + 6) = 22, + 2 CON x 3 seviye = 28
      expect(build.maxHitPoints, 28);
    });

    test('atilan zarlar varsa onlar kullanilir', () {
      final build = CharacterBuild(
        abilities: const AbilityScores(constitution: 14),
        classes: [fighter(3)],
        hitPointRolls: const {
          'srd-2024_fighter': [9, 3],
        },
      );
      expect(build.maxHitPoints, 10 + 9 + 3 + 6);
    });

    test('multiclass: yalnizca ilk sinifin 1. seviyesi tam', () {
      final build = CharacterBuild(
        abilities: const AbilityScores(constitution: 12), // +1
        classes: [
          fighter(2),
          const ClassLevel(
            classKey: 'srd-2024_wizard',
            level: 2,
            casterType: CasterType.full,
            hitDieSides: 6,
          ),
        ],
      );
      // Fighter: 10 + 6 = 16. Wizard: 4 + 4 = 8. CON: +1 x 4 seviye = 4.
      expect(build.maxHitPoints, 28);
    });

    test('cok dusuk CON toplami seviye basina 1 HP altina indirmez', () {
      final build = CharacterBuild(
        abilities: const AbilityScores(constitution: 1), // -5
        classes: [
          const ClassLevel(
            classKey: 'srd-2024_wizard',
            level: 3,
            casterType: CasterType.full,
            hitDieSides: 6,
            isPrimary: true,
          ),
        ],
      );
      // 6 + 4 + 4 = 14, CON -5 x 3 = -15 -> -1 olurdu.
      expect(build.maxHitPoints, 3);
    });
  });

  group('multiclass buyucu seviyesi', () {
    test('tek sinif kendi seviyesini kullanir', () {
      final build = CharacterBuild(
        abilities: const AbilityScores(),
        classes: const [
          ClassLevel(
            classKey: 'srd-2024_wizard',
            level: 7,
            casterType: CasterType.full,
            hitDieSides: 6,
            isPrimary: true,
          ),
        ],
      );
      expect(build.combinedCasterLevel, 7);
    });

    test('yarim buyucu asagi yuvarlanir', () {
      final build = CharacterBuild(
        abilities: const AbilityScores(),
        classes: const [
          ClassLevel(
            classKey: 'srd-2024_paladin',
            level: 5,
            casterType: CasterType.half,
            hitDieSides: 10,
            isPrimary: true,
          ),
        ],
      );
      expect(build.combinedCasterLevel, 2);
    });

    test('Paladin 6 / Sorcerer 4 -> 7', () {
      final build = CharacterBuild(
        abilities: const AbilityScores(),
        classes: const [
          ClassLevel(
            classKey: 'srd-2024_paladin',
            level: 6,
            casterType: CasterType.half,
            hitDieSides: 10,
            isPrimary: true,
          ),
          ClassLevel(
            classKey: 'srd-2024_sorcerer',
            level: 4,
            casterType: CasterType.full,
            hitDieSides: 6,
          ),
        ],
      );
      expect(build.combinedCasterLevel, 7);
    });

    test('Warlock ortak havuza girmez, ayri sayilir', () {
      final build = CharacterBuild(
        abilities: const AbilityScores(),
        classes: const [
          ClassLevel(
            classKey: 'srd-2024_warlock',
            level: 5,
            casterType: CasterType.pact,
            hitDieSides: 8,
            isPrimary: true,
          ),
          ClassLevel(
            classKey: 'srd-2024_wizard',
            level: 3,
            casterType: CasterType.full,
            hitDieSides: 6,
          ),
        ],
      );
      expect(build.combinedCasterLevel, 3);
      expect(build.pactCasterLevel, 5);
    });
  });

  test('buyu DC ve saldiri bonusu', () {
    final build = CharacterBuild(
      abilities: const AbilityScores(intelligence: 16), // +3
      classes: const [
        ClassLevel(
          classKey: 'srd-2024_wizard',
          level: 5, // PB 3
          casterType: CasterType.full,
          hitDieSides: 6,
          isPrimary: true,
        ),
      ],
    );
    expect(build.spellSaveDc(Ability.intelligence), 14);
    expect(build.spellAttackBonus(Ability.intelligence), 6);
  });

  test('sinif anahtarindan buyu yetenegi', () {
    expect(spellcastingAbilityFor('srd-2024_wizard'), Ability.intelligence);
    expect(spellcastingAbilityFor('srd-2024_cleric'), Ability.wisdom);
    expect(spellcastingAbilityFor('srd-2024_warlock'), Ability.charisma);
    expect(spellcastingAbilityFor('srd-2024_fighter'), isNull);
  });

  test('tasima kapasitesi Guc x 15', () {
    final build = CharacterBuild(
      abilities: const AbilityScores(strength: 15),
      classes: [fighter(1)],
    );
    expect(build.carryCapacity, 225);
  });

  group('zirh egitimi ve alet yeterliligi', () {
    CharacterBuild build({
      String? armorCategory,
      bool shield = false,
      Set<String> armorProficiencies = const {},
      Set<String> tools = const {},
    }) => CharacterBuild(
      abilities: const AbilityScores(),
      classes: [fighter(5)],
      armor: armorCategory == null
          ? null
          : ArmorPiece(baseAc: 14, category: armorCategory),
      hasShield: shield,
      armorProficiencies: armorProficiencies,
      toolProficiencies: tools,
    );

    test('egitimi olan zirhta ceza yok', () {
      final b = build(armorCategory: 'medium', armorProficiencies: {'medium'});
      expect(b.untrainedArmor, isFalse);
      expect(b.hasArmorPenalty, isFalse);
    });

    test('egitimi olmayan zirhta ceza var', () {
      final b = build(armorCategory: 'heavy', armorProficiencies: {'light'});
      expect(b.untrainedArmor, isTrue);
      expect(b.hasArmorPenalty, isTrue);
    });

    test('zirh giyilmiyorsa ceza yok', () {
      expect(build().hasArmorPenalty, isFalse);
    });

    test('kalkan egitimi ayri kontrol edilir', () {
      final b = build(shield: true, armorProficiencies: {'light'});
      expect(b.untrainedShield, isTrue);
      expect(b.untrainedArmor, isFalse);
      expect(b.hasArmorPenalty, isTrue);
    });

    test('alet yeterliligi yeterlilik bonusu ekler', () {
      final b = build(tools: {"Thieves' Tools"});
      // 5. seviyede yeterlilik bonusu +3.
      expect(b.toolModifier("Thieves' Tools"), 3);
      expect(b.toolModifier("Smith's Tools"), 0);
    });

    test('alet eslesmesi buyuk/kucuk harfe duyarsiz', () {
      final b = build(tools: {"Thieves' Tools"});
      expect(b.toolModifier("thieves' tools"), 3);
    });
  });
}
