import 'package:dm_table/features/ai/quest_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildQuestPrompt', () {
    test('user ekip sayısı, seviye, zorluk, temayı içerir', () {
      final p = buildQuestPrompt(
        partySize: 5,
        partyLevel: 8,
        difficulty: QuestDifficulty.hard,
        setting: 'buzul mağarası',
        languageName: 'Türkçe',
      );
      expect(p.user, contains('5 kişi'));
      expect(p.user, contains('seviye 8'));
      expect(p.user, contains('hard'));
      expect(p.user, contains('buzul mağarası'));
    });

    test('system: dil + JSON şeması + toplam ödül + DM alanı', () {
      final p = buildQuestPrompt(
        partySize: 3,
        partyLevel: 1,
        difficulty: QuestDifficulty.medium,
        setting: '',
        languageName: 'English',
      );
      expect(p.system, contains('English'));
      expect(p.system, contains('"title"'));
      expect(p.system, contains('"quest"'));
      expect(p.system, contains('"reward"'));
      expect(p.system, contains('"dm"'));
      expect(p.system, contains('TOPLAM')); // ödül oyuncu başına değil
      expect(p.system.toLowerCase(), contains('telifli'));
      expect(p.user, contains('serbest')); // tema boş
    });

    test('beş zorluk kademesi vardır', () {
      expect(QuestDifficulty.values.length, 5);
    });

    test('görev veren NPC ve hedef lokasyon verilirse prompta eklenir', () {
      final p = buildQuestPrompt(
        partySize: 4,
        partyLevel: 3,
        difficulty: QuestDifficulty.medium,
        setting: '',
        languageName: 'Türkçe',
        questGiverNpc: 'Gundren — cüce demirci',
        targetLocation: 'Yıkık Kale — harabe bir kule',
      );
      expect(p.user, contains('Görevi veren: Gundren — cüce demirci.'));
      expect(p.user, contains('Hedef lokasyon: Yıkık Kale — harabe bir kule.'));
    });

    test('görev veren/hedef verilmezse prompta girmez', () {
      final p = buildQuestPrompt(
        partySize: 4,
        partyLevel: 3,
        difficulty: QuestDifficulty.medium,
        setting: '',
        languageName: 'Türkçe',
      );
      expect(p.user, isNot(contains('Görevi veren')));
      expect(p.user, isNot(contains('Hedef lokasyon')));
    });

    test('boş metin görev veren/hedef yok sayılır', () {
      final p = buildQuestPrompt(
        partySize: 4,
        partyLevel: 3,
        difficulty: QuestDifficulty.medium,
        setting: '',
        languageName: 'Türkçe',
        questGiverNpc: '   ',
        targetLocation: '',
      );
      expect(p.user, isNot(contains('Görevi veren')));
      expect(p.user, isNot(contains('Hedef lokasyon')));
    });

    test('system: görev veren/hedef verilirse bağlama talimatı içerir', () {
      final p = buildQuestPrompt(
        partySize: 4,
        partyLevel: 3,
        difficulty: QuestDifficulty.medium,
        setting: '',
        languageName: 'Türkçe',
      );
      expect(p.system, contains('bağla'));
    });
  });

  group('parseQuestResult', () {
    test('düz JSON dört alanı ayırır', () {
      final r = parseQuestResult(
        '{"title":"Kayıp Çocuk","quest":"Kayıp çocuğu bul",'
        '"reward":"200 altın + gümüş kolye","dm":"Çocuk aslında kaçırılmadı"}',
      );
      expect(r.title, 'Kayıp Çocuk');
      expect(r.quest, 'Kayıp çocuğu bul');
      expect(r.reward, '200 altın + gümüş kolye');
      expect(r.dm, 'Çocuk aslında kaçırılmadı');
    });

    test('```json çiti ve önek/sonek toleransı', () {
      final r = parseQuestResult(
        'İşte görev:\n```json\n{"quest":"Q","reward":"R","dm":"D"}\n```\nkolay gelsin',
      );
      expect(r.quest, 'Q');
      expect(r.reward, 'R');
      expect(r.dm, 'D');
    });

    test('JSON değilse tüm metin göreve düşer', () {
      final r = parseQuestResult('Sadece düz bir görev metni.');
      expect(r.quest, 'Sadece düz bir görev metni.');
      expect(r.reward, isEmpty);
      expect(r.dm, isEmpty);
    });

    test('eksik alanlar boş döner', () {
      final r = parseQuestResult('{"quest":"Q"}');
      expect(r.quest, 'Q');
      expect(r.reward, isEmpty);
      expect(r.dm, isEmpty);
      expect(r.rewardCoinsCp, 0);
      expect(r.rewardItems, isEmpty);
      // Planlama alanlari da bos gelmeli, null degil: arayuz bos olani cizmez.
      expect(r.hooks, isEmpty);
      expect(r.stages, isEmpty);
      expect(r.complications, isEmpty);
      expect(r.failure, isEmpty);
      expect(r.keyNpcs, isEmpty);
    });
  });

  group('parseQuestResult: planlama alanları', () {
    test('kancalar, aşamalar, komplikasyonlar ve karakterler ayrışır', () {
      final r = parseQuestResult(
        '{"quest":"Q",'
        '"hooks":["Handa bir ilan","Kanlı bir at döner"],'
        '"stages":[{"title":"Yola çık","detail":"Orman kenarı"},'
        '{"title":"Harabe","detail":"Kule çöküyor"}],'
        '"complications":["Köprü yıkılmış"],'
        '"failure":"Köy kışı çıkaramaz",'
        '"keyNpcs":[{"name":"Mira","role":"hancı"}]}',
      );
      expect(r.hooks, ['Handa bir ilan', 'Kanlı bir at döner']);
      expect(r.stages.length, 2);
      expect(r.stages.first.title, 'Yola çık');
      expect(r.stages.first.detail, 'Orman kenarı');
      expect(r.complications, ['Köprü yıkılmış']);
      expect(r.failure, 'Köy kışı çıkaramaz');
      expect(r.keyNpcs.single.name, 'Mira');
      expect(r.keyNpcs.single.role, 'hancı');
    });

    test('düz string dizileri de kabul edilir', () {
      final r = parseQuestResult(
        '{"quest":"Q","stages":["Yola çık","Harabe"],'
        '"keyNpcs":["Mira"]}',
      );
      expect(r.stages.map((s) => s.title), ['Yola çık', 'Harabe']);
      expect(r.stages.first.detail, isEmpty);
      expect(r.keyNpcs.single.name, 'Mira');
      expect(r.keyNpcs.single.role, isEmpty);
    });

    test('boş/bozuk kalemler atılır', () {
      final r = parseQuestResult(
        '{"quest":"Q","hooks":["  ","Gerçek kanca"],'
        '"stages":[{"title":"","detail":""},{"title":"Var"}],'
        '"keyNpcs":[{"role":"adsız"},{"name":"Mira"}]}',
      );
      expect(r.hooks, ['Gerçek kanca']);
      expect(r.stages.single.title, 'Var');
      expect(r.keyNpcs.single.name, 'Mira');
    });
  });

  group('parseQuestResult: kesilmiş yanıt kurtarma', () {
    test('ortadan kesilen JSON tamamlanan alanları kurtarır', () {
      // Model token butcesini doldurup "stages" ortasinda kesilmis.
      final r = parseQuestResult(
        '{"title":"Kayıp Kervan","quest":"Kervanı bul","reward":"200 altın",'
        '"dm":"Kervancı yalan söylüyor",'
        '"hooks":["Handa bir ilan"],'
        '"stages":[{"title":"Yola çık","detail":"Orman ke',
      );
      expect(r.parsed, isTrue);
      expect(r.title, 'Kayıp Kervan');
      expect(r.quest, 'Kervanı bul');
      expect(r.reward, '200 altın');
      expect(r.dm, 'Kervancı yalan söylüyor');
      expect(r.hooks, ['Handa bir ilan']);
      // Yarim kalan alan dusdu, tamamlananlar durdu.
      expect(r.stages, isEmpty);
    });

    test('kaçışlı tırnak kesme noktasını şaşırtmaz', () {
      final r = parseQuestResult(
        r'{"title":"Han \"Yeşil Ejder\"","quest":"Q","reward":"R",'
        r'"dm":"D","complications":["yarım',
      );
      expect(r.parsed, isTrue);
      expect(r.title, 'Han "Yeşil Ejder"');
      expect(r.complications, isEmpty);
    });

    test('hiç tam alan yoksa parsed false ve ham metin döner', () {
      const raw = '{"title":"Yarım kalan başlı';
      final r = parseQuestResult(raw);
      expect(r.parsed, isFalse);
      expect(r.quest, raw);
    });

    test('sağlam JSON hâlâ parsed true', () {
      final r = parseQuestResult('{"quest":"Q","reward":"R","dm":"D"}');
      expect(r.parsed, isTrue);
      expect(r.quest, 'Q');
    });

    test('JSON olmayan düz metin parsed false', () {
      final r = parseQuestResult('Sadece düz bir görev metni.');
      expect(r.parsed, isFalse);
    });
  });

  group('buildQuestPrompt: süre sınırı', () {
    test('süre verilince prompta somut olarak yazılır', () {
      final p = buildQuestPrompt(
        partySize: 4,
        partyLevel: 3,
        difficulty: QuestDifficulty.medium,
        setting: '',
        languageName: 'Türkçe',
        urgency: QuestUrgency.hard,
        deadline: (amount: 3, unit: QuestTimeUnit.days),
      );
      expect(p.user, contains('3 days'));
      expect(p.user, contains('AÇIKÇA'));
    });

    test('baskı yokken süre yok sayılır', () {
      final p = buildQuestPrompt(
        partySize: 4,
        partyLevel: 3,
        difficulty: QuestDifficulty.medium,
        setting: '',
        languageName: 'Türkçe',
        deadline: (amount: 3, unit: QuestTimeUnit.days),
      );
      expect(p.user, isNot(contains('3 days')));
    });

    test('kapsam büyüdükçe token bütçesi büyür', () {
      expect(
        QuestScope.oneShot.maxTokens,
        lessThan(QuestScope.shortArc.maxTokens),
      );
      expect(
        QuestScope.shortArc.maxTokens,
        lessThan(QuestScope.campaignArc.maxTokens),
      );
    });
  });

  group('buildQuestPrompt: yeni girdiler', () {
    test('alınan yer, karşı taraf ve devamı ayrı etiketlerle girer', () {
      final p = buildQuestPrompt(
        partySize: 4,
        partyLevel: 3,
        difficulty: QuestDifficulty.medium,
        setting: '',
        languageName: 'Türkçe',
        giverLocation: 'Yeşil Ejder Hanı',
        antagonistNpc: 'Kara Baron',
        followsUpQuest: 'Kayıp Çocuk',
      );
      expect(p.user, contains('Görevin alındığı yer'));
      expect(p.user, contains('Yeşil Ejder Hanı'));
      expect(p.user, contains('Karşı taraf: Kara Baron.'));
      expect(p.user, contains('Bu görev şunun devamı: Kayıp Çocuk.'));
    });

    test('tür/kapsam/ton/aciliyet prompta yazılır, aşama sayısı kapsamdan', () {
      final p = buildQuestPrompt(
        partySize: 4,
        partyLevel: 3,
        difficulty: QuestDifficulty.medium,
        setting: '',
        languageName: 'Türkçe',
        kind: QuestKind.heist,
        scope: QuestScope.campaignArc,
        tone: QuestTone.morallyGrey,
        urgency: QuestUrgency.hard,
      );
      expect(p.user, contains(QuestKind.heist.promptDescriptor));
      expect(p.user, contains(QuestTone.morallyGrey.promptDescriptor));
      expect(p.user, contains(QuestUrgency.hard.promptDescriptor));
      expect(p.user, contains('${QuestScope.campaignArc.stageCount} aşama'));
    });

    test('system: yeni bölümleri şemada ister', () {
      final p = buildQuestPrompt(
        partySize: 4,
        partyLevel: 3,
        difficulty: QuestDifficulty.medium,
        setting: '',
        languageName: 'Türkçe',
      );
      for (final key in ['hooks', 'stages', 'complications', 'failure']) {
        expect(p.system, contains('"$key"'));
      }
    });
  });

  group('parseQuestResult: sayısal ödül', () {
    test('para dökümü bakıra çevrilir, eşyalar sihirli bayrağıyla gelir', () {
      final r = parseQuestResult(
        '{"quest":"Q","reward":"1 platin 20 altın + Ateş Kılıcı",'
        '"rewardCoins":{"pp":1,"gp":20,"sp":5,"cp":3},'
        '"rewardItems":[{"name":"Ateş Kılıcı","magic":true},'
        '{"name":"İpek çadır","magic":false}]}',
      );
      expect(r.rewardCoinsCp, 1000 + 2000 + 50 + 3);
      expect(r.rewardItems, [
        (name: 'Ateş Kılıcı', magic: true),
        (name: 'İpek çadır', magic: false),
      ]);
    });

    test('tek sayı altın sayılır', () {
      final r = parseQuestResult('{"quest":"Q","rewardCoins":500}');
      expect(r.rewardCoinsCp, 50000);
    });

    test('düz string eşya listesi kabul edilir', () {
      final r = parseQuestResult('{"quest":"Q","rewardItems":["Halat"," "]}');
      expect(r.rewardItems, [(name: 'Halat', magic: false)]);
    });

    test('bozuk/eksik sayısal ödül görevi bozmaz', () {
      final r = parseQuestResult(
        '{"quest":"Q","rewardCoins":"çok para","rewardItems":{"name":"x"}}',
      );
      expect(r.quest, 'Q');
      expect(r.rewardCoinsCp, 0);
      expect(r.rewardItems, isEmpty);
    });

    test('adsız eşya atlanır, magic metin olarak gelse de çözülür', () {
      final r = parseQuestResult(
        '{"quest":"Q","rewardItems":[{"name":"","magic":true},'
        '{"name":"Asa","magic":"true"}]}',
      );
      expect(r.rewardItems, [(name: 'Asa', magic: true)]);
    });

    test('birden çok eşya + sıfır para ayrıştırılır', () {
      final r = parseQuestResult(
        '{"quest":"Q","reward":"üç eşya, para yok",'
        '"rewardCoins":{"pp":0,"gp":0,"sp":0,"cp":0},'
        '"rewardItems":[{"name":"Asa","magic":true},'
        '{"name":"Halat","magic":false},{"name":"Fener","magic":false}]}',
      );
      expect(r.rewardCoinsCp, 0);
      expect(r.rewardItems.length, 3);
    });

    test('yalnız para (eşyasız) ödül ayrıştırılır', () {
      final r = parseQuestResult(
        '{"quest":"Q","rewardCoins":{"gp":250},"rewardItems":[]}',
      );
      expect(r.rewardCoinsCp, 25000);
      expect(r.rewardItems, isEmpty);
    });

    test('system istemi sayısal ödül alanlarını şart koşar', () {
      final p = buildQuestPrompt(
        partySize: 4,
        partyLevel: 3,
        difficulty: QuestDifficulty.medium,
        setting: '',
        languageName: 'Türkçe',
      );
      expect(p.system, contains('"rewardCoins"'));
      expect(p.system, contains('"rewardItems"'));
      expect(p.system, contains('"magic"'));
    });

    test('system istemi ödül bileşimini serbest bırakır', () {
      final p = buildQuestPrompt(
        partySize: 4,
        partyLevel: 3,
        difficulty: QuestDifficulty.medium,
        setting: '',
        languageName: 'Türkçe',
      );
      expect(p.system, contains('SERBEST'));
      expect(p.system, contains('sadece para'));
      expect(p.system, contains('sadece eşya'));
    });
  });

  group('questRewardBudget', () {
    QuestRewardBudget budget({
      int size = 4,
      int level = 1,
      QuestDifficulty difficulty = QuestDifficulty.medium,
    }) => questRewardBudget(
      partySize: size,
      partyLevel: level,
      difficulty: difficulty,
    );

    test('aralık merkezin etrafında ve artan', () {
      final b = budget();
      expect(b.minGp, lessThan(b.maxGp));
      expect(b.minGp, greaterThan(0));
    });

    test('parti büyüdükçe bütçe büyür', () {
      expect(budget(size: 6).maxGp, greaterThan(budget(size: 3).maxGp));
    });

    test('seviye kademesi atlayınca bütçe sıçrar', () {
      expect(budget(level: 5).maxGp, greaterThan(budget(level: 4).maxGp));
      expect(budget(level: 11).maxGp, greaterThan(budget(level: 10).maxGp));
      expect(budget(level: 17).maxGp, greaterThan(budget(level: 16).maxGp));
    });

    test('zorluk arttıkça bütçe artar', () {
      final easy = budget(difficulty: QuestDifficulty.veryEasy).maxGp;
      final medium = budget(difficulty: QuestDifficulty.medium).maxGp;
      final deadly = budget(difficulty: QuestDifficulty.veryHard).maxGp;
      expect(easy, lessThan(medium));
      expect(medium, lessThan(deadly));
    });

    test('nadirlik tavanı seviyeyle yükselir', () {
      expect(budget(level: 2).magicRarity, contains('common'));
      expect(budget(level: 8).magicRarity, contains('uncommon'));
      expect(budget(level: 13).magicRarity, contains('rare'));
      expect(budget(level: 19).magicRarity, contains('very rare'));
    });

    test('uç değerler kırılmaz (0 kişi, seviye sınırları)', () {
      expect(budget(size: 0).minGp, greaterThan(0));
      expect(budget(level: 0).minGp, greaterThan(0));
      expect(budget(level: 99).minGp, greaterThan(0));
    });

    test('bütçe kullanıcı istemine yazılır', () {
      final p = buildQuestPrompt(
        partySize: 4,
        partyLevel: 7,
        difficulty: QuestDifficulty.hard,
        setting: '',
        languageName: 'Türkçe',
      );
      final b = budget(size: 4, level: 7, difficulty: QuestDifficulty.hard);
      expect(p.user, contains('${b.minGp}–${b.maxGp} altın'));
      expect(p.user, contains(b.magicRarity));
    });
  });
}
