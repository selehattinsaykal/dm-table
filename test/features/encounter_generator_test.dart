import 'package:dm_table/features/ai/encounter_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const candidates = <EncounterCandidate>[
    (name: 'Goblin', challenge: '1/4', xp: 50),
    (name: 'Hobgoblin Warrior', challenge: '1/2', xp: 100),
    (name: 'Bugbear Warrior', challenge: '1', xp: 200),
  ];

  ({String system, String user}) prompt({
    int partySize = 4,
    int partyLevel = 3,
    String environment = '',
  }) => buildEncounterPrompt(
    partySize: partySize,
    partyLevel: partyLevel,
    difficultyLabel: 'Zor',
    xpBudget: 1600,
    candidates: candidates,
    languageName: 'Türkçe',
    environment: environment,
  );

  group('buildEncounterPrompt', () {
    test('user: parti olcegi, zorluk ve XP hedefi', () {
      final p = prompt();
      expect(p.user, contains('4 kişi'));
      expect(p.user, contains('seviye 3'));
      expect(p.user, contains('Zor'));
      expect(p.user, contains('1600 XP'));
    });

    test('aday listesi ad, CR ve XP ile promptta', () {
      final p = prompt();
      for (final c in candidates) {
        expect(p.user, contains(c.name));
        expect(p.user, contains('CR ${c.challenge}'));
        expect(p.user, contains('${c.xp} XP'));
      }
    });

    test('system: yalniz aday listesinden secmeyi SART kosar', () {
      final p = prompt();
      // Bu kural olmazsa model ad uydurur ve savasa donusturme kirilir.
      expect(p.system, contains('ADAY LİSTESİNDEN'));
      expect(p.system, contains('listede olmayan'));
    });

    test('system: JSON semasini dayatir', () {
      final p = prompt();
      for (final key in [
        '"name"',
        '"summary"',
        '"monsters"',
        '"tactics"',
        '"terrain"',
        '"dm"',
      ]) {
        expect(p.system, contains(key));
      }
      expect(p.system, contains('Türkçe'));
      expect(p.system.toLowerCase(), contains('telifli'));
    });

    test('ortam bos birakilirsa serbest yazilir', () {
      expect(prompt().user, contains('serbest'));
      expect(
        prompt(environment: '  buzul magarasi ').user,
        contains('buzul magarasi'),
      );
    });
  });

  group('parseEncounterResult', () {
    test('duz JSON tum alanlari ayirir', () {
      final r = parseEncounterResult(
        '{"name":"Pusu","summary":"Yolda tuzak",'
        '"monsters":[{"name":"Goblin","count":4},'
        '{"name":"Bugbear Warrior","count":1}],'
        '"tactics":"Once okcular","terrain":"Devrik agac","dm":"Kacis yolu"}',
      );
      expect(r.name, 'Pusu');
      expect(r.summary, 'Yolda tuzak');
      expect(r.monsters, [
        (name: 'Goblin', count: 4),
        (name: 'Bugbear Warrior', count: 1),
      ]);
      expect(r.tactics, 'Once okcular');
      expect(r.terrain, 'Devrik agac');
      expect(r.dm, 'Kacis yolu');
    });

    test('```json citi ve onek/sonek toleransi', () {
      final r = parseEncounterResult(
        'Iste:\n```json\n{"summary":"S","monsters":[{"name":"Goblin"}]}\n```\nkolay gelsin',
      );
      expect(r.summary, 'S');
      // Adet verilmezse 1 sayilir.
      expect(r.monsters.single, (name: 'Goblin', count: 1));
    });

    test('duz string dizisi kabul edilir', () {
      final r = parseEncounterResult(
        '{"summary":"S","monsters":["Goblin"," ","Bugbear Warrior"]}',
      );
      expect(r.monsters, [
        (name: 'Goblin', count: 1),
        (name: 'Bugbear Warrior', count: 1),
      ]);
    });

    test('gecersiz adet en az 1 olur, adsiz satir atlanir', () {
      final r = parseEncounterResult(
        '{"summary":"S","monsters":[{"name":"Goblin","count":0},'
        '{"name":"","count":3},{"name":"Bugbear Warrior","count":"2"}]}',
      );
      expect(r.monsters, [
        (name: 'Goblin', count: 1),
        (name: 'Bugbear Warrior', count: 2),
      ]);
    });

    test('JSON degilse tum metin ozete duser', () {
      final r = parseEncounterResult('Sadece duz bir metin.');
      expect(r.summary, 'Sadece duz bir metin.');
      expect(r.monsters, isEmpty);
    });

    test('bozuk monsters alani karsilasmayi bozmaz', () {
      final r = parseEncounterResult('{"summary":"S","monsters":"cok goblin"}');
      expect(r.summary, 'S');
      expect(r.monsters, isEmpty);
    });
  });
}
