import 'package:dm_table/domain/rules/encounter_budget.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2024 XP butcesi (SRD 5.2): parti butcesi = uye butcelerinin toplami;
/// toplam canavar XP'si bu esiklere gore siniflanir.
void main() {
  group('partyBudget', () {
    test('4 kisilik 1. seviye parti butceleri toplanir', () {
      // Seviye 1: (50, 75, 100) -> x4
      expect(EncounterBudget.partyBudget([1, 1, 1, 1]), (200, 300, 400));
    });

    test('karisik seviyeler toplanir', () {
      // Sv1 (50,75,100) + Sv5 (500,750,1100)
      expect(EncounterBudget.partyBudget([1, 5]), (550, 825, 1200));
    });

    test('seviye 1-20 araligina kirpilir', () {
      expect(EncounterBudget.partyBudget([25]), (6400, 13200, 22000)); // sv20
      expect(EncounterBudget.partyBudget([0]), (50, 75, 100)); // sv1
    });
  });

  group('classify', () {
    // 4x sv1 -> (200, 300, 400)
    const party = [1, 1, 1, 1];

    test('butcenin altinda: onemsiz', () {
      expect(EncounterBudget.classify(150, party), EncounterDifficulty.trivial);
    });

    test('dusuk esikte: kolay', () {
      expect(EncounterBudget.classify(200, party), EncounterDifficulty.low);
      expect(EncounterBudget.classify(299, party), EncounterDifficulty.low);
    });

    test('orta esikte: orta', () {
      expect(
        EncounterBudget.classify(300, party),
        EncounterDifficulty.moderate,
      );
    });

    test('yuksek esikte: zor', () {
      expect(EncounterBudget.classify(400, party), EncounterDifficulty.high);
      expect(EncounterBudget.classify(599, party), EncounterDifficulty.high);
    });

    test('olumcul esik ve ustu: cok zor', () {
      // high=400 -> deadlyBudget = 600
      expect(EncounterBudget.classify(600, party), EncounterDifficulty.deadly);
      expect(EncounterBudget.classify(5000, party), EncounterDifficulty.deadly);
    });

    test('parti yoksa onemsiz', () {
      expect(
        EncounterBudget.classify(1000, const []),
        EncounterDifficulty.trivial,
      );
    });
  });

  test('EncounterAssessment difficulty ve budget tutarli', () {
    const a = EncounterAssessment(monsterXp: 320, partyLevels: [1, 1, 1, 1]);
    expect(a.hasParty, isTrue);
    expect(a.budget, (200, 300, 400));
    expect(a.difficulty, EncounterDifficulty.moderate);
  });
}
