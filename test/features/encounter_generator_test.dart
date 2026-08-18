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
  group('Karsilasma: hedef, kurulus ve yeni bolumler', () {
    test('kazanma kosulu ve kurulus prompta yazilir', () {
      final p = buildEncounterPrompt(
        partySize: 4,
        partyLevel: 3,
        difficultyLabel: 'orta',
        xpBudget: 700,
        candidates: const [(name: 'Goblin', challenge: '1/4', xp: 50)],
        languageName: 'Türkçe',
        objective: EncounterObjective.escape,
        setup: EncounterSetup.ambush,
      );
      expect(p.user, contains(EncounterObjective.escape.promptDescriptor));
      expect(p.user, contains(EncounterSetup.ambush.promptDescriptor));
    });

    test('secili yer sahneye baglanir', () {
      final p = buildEncounterPrompt(
        partySize: 4,
        partyLevel: 3,
        difficultyLabel: 'orta',
        xpBudget: 700,
        candidates: const [(name: 'Goblin', challenge: '1/4', xp: 50)],
        languageName: 'Türkçe',
        locationContext: 'Karga Geçidi — dar bir boğaz',
      );
      expect(p.user, contains('Karga Geçidi'));
      expect(p.user, contains('Sahneyi bu yere oturt'));
    });

    test('yer verilmezse prompta girmez', () {
      final p = buildEncounterPrompt(
        partySize: 4,
        partyLevel: 3,
        difficultyLabel: 'orta',
        xpBudget: 700,
        candidates: const [(name: 'Goblin', challenge: '1/4', xp: 50)],
        languageName: 'Türkçe',
      );
      expect(p.user, isNot(contains('Geçtiği yer')));
    });

    test('system yeni bolumleri semada ister', () {
      final p = buildEncounterPrompt(
        partySize: 4,
        partyLevel: 3,
        difficultyLabel: 'orta',
        xpBudget: 700,
        candidates: const [(name: 'Goblin', challenge: '1/4', xp: 50)],
        languageName: 'Türkçe',
      );
      for (final key in [
        'objective',
        'reinforcements',
        'scaling',
        'treasure',
      ]) {
        expect(p.system, contains('"$key"'));
      }
    });

    test('yeni alanlar ayrisir', () {
      final r = parseEncounterResult(
        '{"name":"Boğazda pusu","summary":"Taşlar yuvarlanıyor",'
        '"monsters":[{"name":"Goblin","count":4}],'
        '"objective":"Boğazdan sağ çıkmak",'
        '"reinforcements":"İki tur sonra iki goblin daha",'
        '"scaling":"Zorlanırlarsa moralleri bozulup kaçar",'
        '"treasure":"Üstlerinde 30 gümüş"}',
      );
      expect(r.parsed, isTrue);
      expect(r.objective, 'Boğazdan sağ çıkmak');
      expect(r.reinforcements, contains('iki goblin'));
      expect(r.scaling, contains('kaçar'));
      expect(r.treasure, contains('30 gümüş'));
    });

    test('kesilen yanit tamamlanan alanlari kurtarir', () {
      final r = parseEncounterResult(
        '{"name":"Pusu","summary":"Taşlar yuvarlanıyor",'
        '"monsters":[{"name":"Goblin","count":4}],'
        '"objective":"Sağ çık","scaling":"Zorlan',
      );
      expect(r.parsed, isTrue);
      expect(r.monsters.single.name, 'Goblin');
      expect(r.objective, 'Sağ çık');
      expect(r.scaling, isEmpty);
    });

    test('duz metin parsed false', () {
      final r = parseEncounterResult('Sadece duz metin.');
      expect(r.parsed, isFalse);
      expect(r.summary, 'Sadece duz metin.');
    });
  });
  group('Karsilasma: yapisal ganimet', () {
    test('system ganimeti makine okunur alanlarda ister', () {
      final p = buildEncounterPrompt(
        partySize: 4,
        partyLevel: 3,
        difficultyLabel: 'orta',
        xpBudget: 700,
        candidates: const [(name: 'Goblin', challenge: '1/4', xp: 50)],
        languageName: 'Türkçe',
      );
      expect(p.system, contains('"treasureCoins"'));
      expect(p.system, contains('"treasureItems"'));
      // Adlarin kutuphanede aranacagi modele soylenmeli, yoksa suslu
      // uydurma adlar cozulemiyor.
      expect(p.system, contains('kütüphanesinde aranacak'));
    });

    test('para dokumu bakira cevrilir, esyalar sihirli bayragiyla gelir', () {
      final r = parseEncounterResult(
        '{"summary":"S","monsters":[{"name":"Goblin","count":2}],'
        '"treasure":"1 platin 20 altin + Ates Kilici",'
        '"treasureCoins":{"pp":1,"gp":20},'
        '"treasureItems":[{"name":"Ates Kilici","magic":true},'
        '{"name":"Halat"}]}',
      );
      expect(r.treasureCoinsCp, 1 * 1000 + 20 * 100);
      expect(r.treasureItems.length, 2);
      expect(r.treasureItems.first.magic, isTrue);
      expect(r.treasureItems.last.magic, isFalse);
    });

    test('tek sayi altin sayilir, duz string esya listesi kabul edilir', () {
      final r = parseEncounterResult(
        '{"summary":"S","treasureCoins":50,"treasureItems":["Halat"]}',
      );
      expect(r.treasureCoinsCp, 5000);
      expect(r.treasureItems.single.name, 'Halat');
    });

    test('ganimet yoksa sifir/bos doner', () {
      final r = parseEncounterResult('{"summary":"S","tactics":"T"}');
      expect(r.treasureCoinsCp, 0);
      expect(r.treasureItems, isEmpty);
    });
  });
}
