import 'package:dm_table/features/ai/npc_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('istem meslek, cinsiyet, tür, isim ve dili içerir', () {
    final p = buildNpcPrompt(
      profession: 'demirci',
      gender: NpcGender.female,
      race: 'cüce',
      name: 'Bruna',
      extra: 'liman kentinde yaşıyor',
      languageName: 'Türkçe',
    );
    expect(p.system, contains('Türkçe'));
    expect(p.system.toLowerCase(), contains('telifli'));
    expect(p.user, contains('demirci'));
    expect(p.user, contains('female'));
    expect(p.user, contains('cüce'));
    expect(p.user, contains('Bruna'));
    expect(p.user, contains('liman kentinde yaşıyor'));
  });

  test('boş alanlarda serbest/üret varsayılanları kullanılır', () {
    final p = buildNpcPrompt(
      profession: '  ',
      gender: NpcGender.random,
      race: '',
      name: '',
      extra: '',
      languageName: 'English',
    );
    expect(p.system, contains('English'));
    expect(p.user, contains('serbest'));
    expect(p.user, contains('sen üret'));
    expect(p.user, contains('any (you choose)'));
  });

  test('JSON yanıtı tüm alanlara ayrıştırılır', () {
    const raw =
        '```json\n{"name":"Bruna","summary":"yaşlı cüce demirci",'
        '"appearance":"kalın kollar","personality":"aksi ama dürüst",'
        '"ideal":"ustalık","bond":"çırağı","flaw":"inatçı",'
        '"hook":"nadir bir cevher arıyor","secret":"kaçak bir prens"}\n```';
    final r = parseNpcResult(raw);
    expect(r.name, 'Bruna');
    expect(r.summary, 'yaşlı cüce demirci');
    expect(r.appearance, 'kalın kollar');
    expect(r.personality, 'aksi ama dürüst');
    expect(r.ideal, 'ustalık');
    expect(r.bond, 'çırağı');
    expect(r.flaw, 'inatçı');
    expect(r.hook, 'nadir bir cevher arıyor');
    expect(r.secret, 'kaçak bir prens');
  });

  test('JSON değilse tüm metin appearance alanına düşer', () {
    final r = parseNpcResult('sadece düz metin');
    expect(r.appearance, 'sadece düz metin');
    expect(r.name, isEmpty);
    expect(r.secret, isEmpty);
  });

  // --- Konum + iliski baglami -------------------------------------------

  test('konum ve iliskiler isteme adlariyla ve tur adlariyla girer', () {
    final p = buildNpcPrompt(
      profession: 'meyhaneci',
      gender: NpcGender.male,
      race: 'insan',
      name: '',
      extra: '',
      languageName: 'Türkçe',
      locationName: 'Karga Geçidi',
      relations: const [
        (targetName: 'Sera', bondName: 'Düşmanlık'),
        (targetName: 'Borin', bondName: 'Ticaret'),
      ],
    );
    expect(p.user, contains('Karga Geçidi'));
    expect(p.user, contains('Sera (Düşmanlık)'));
    expect(p.user, contains('Borin (Ticaret)'));
    // Sistem istemi modele bunlari TUTARLI kullanmasini soylemeli, yoksa
    // baglar metinle iliskisiz kalir.
    expect(p.system, contains('ilişki'));
  });

  test('konum/iliski yoksa sistem istemine ek yonerge girmez', () {
    final p = buildNpcPrompt(
      profession: 'demirci',
      gender: NpcGender.random,
      race: '',
      name: '',
      extra: '',
      languageName: 'Türkçe',
    );
    expect(p.system, isNot(contains('gerçek konumudur')));
    expect(p.user, isNot(contains('Bağlı olduğu yer')));
    expect(p.user, isNot(contains('İlişkileri')));
  });

  test('bos adli/tursuz iliskiler ayiklanir', () {
    final p = buildNpcPrompt(
      profession: '',
      gender: NpcGender.random,
      race: '',
      name: '',
      extra: '',
      languageName: 'Türkçe',
      relations: const [
        (targetName: '  ', bondName: 'Dostluk'),
        (targetName: 'Sera', bondName: '   '),
        (targetName: 'Borin', bondName: 'Aile'),
      ],
    );
    expect(p.user, contains('Borin (Aile)'));
    expect(p.user, isNot(contains('Dostluk')));
    expect(p.user, isNot(contains('Sera')));
  });

  // --- Portre istemi ------------------------------------------------------

  test('portre istemi gorunus, irk, yas ve mizaci tasir', () {
    const r = (
      name: 'Bruna',
      summary: 'yaşlı cüce demirci',
      race: 'cüce',
      gender: 'kadın',
      age: 'yaşlı',
      alignment: 'Yasal İyi',
      appearance: 'kalın kollar, is lekeli önlük',
      personality: 'aksi ama dürüst',
      ideal: 'ustalık',
      bond: 'çırağı',
      flaw: 'inatçı',
      hook: 'cevher arıyor',
      secret: 'kaçak bir prens',
      parsed: true,
      voice: 'boğuk, kısa cümleler',
      mannerism: 'örsü parmağıyla tıklatır',
      wants: 'cevherin kaynağını öğrenmek',
      firstLine: 'Ne istiyorsun?',
    );
    final prompt = buildPortraitPrompt(r);
    expect(prompt, contains('cüce'));
    expect(prompt, contains('yaşlı'));
    expect(prompt, contains('kalın kollar, is lekeli önlük'));
    expect(prompt, contains('aksi ama dürüst'));
    // DM sirri portre istemine ASLA girmemeli.
    expect(prompt, isNot(contains('kaçak bir prens')));
    expect(prompt, isNot(contains('cevher arıyor')));
    // Masa alanlari da gorsele girmemeli: portre neye BENZEDIGINI anlatir,
    // nasil konustugunu/ne istedigini degil.
    expect(prompt, isNot(contains('boğuk')));
    expect(prompt, isNot(contains('Ne istiyorsun?')));
    expect(prompt, isNot(contains('cevherin kaynağını')));
  });

  test('portre isteminde bos alanlar etiketsiz atlanir', () {
    const r = (
      name: '',
      summary: '',
      race: 'elf',
      gender: '',
      age: '',
      alignment: '',
      appearance: '',
      personality: '',
      ideal: '',
      bond: '',
      flaw: '',
      hook: '',
      secret: '',
      parsed: true,
      voice: '',
      mannerism: '',
      wants: '',
      firstLine: '',
    );
    final prompt = buildPortraitPrompt(r);
    expect(prompt, contains('elf'));
    expect(prompt, isNot(contains('Approximate age:')));
    expect(prompt, isNot(contains('Gender:')));
  });
  group('NPC: yeni masa alanlari', () {
    test('tutum ve agirlik prompta yazilir', () {
      final p = buildNpcPrompt(
        profession: 'hancı',
        gender: NpcGender.random,
        race: '',
        name: '',
        extra: '',
        languageName: 'Türkçe',
        disposition: NpcDisposition.deceptive,
        importance: NpcImportance.major,
      );
      expect(p.user, contains(NpcDisposition.deceptive.promptDescriptor));
      expect(p.user, contains(NpcImportance.major.promptDescriptor));
    });

    test('system yeni alanlari semada ister', () {
      final p = buildNpcPrompt(
        profession: '',
        gender: NpcGender.random,
        race: '',
        name: '',
        extra: '',
        languageName: 'Türkçe',
      );
      for (final key in ['voice', 'mannerism', 'wants', 'firstLine']) {
        expect(p.system, contains('"$key"'));
      }
    });

    test('yeni alanlar ayrisir', () {
      final r = parseNpcResult(
        '{"name":"Mira","summary":"hancı","appearance":"kısa boylu",'
        '"voice":"boğuk, kısa cümleler","mannerism":"bardağı siler",'
        '"wants":"kirasını almak","firstLine":"Oda mı, dert mi?"}',
      );
      expect(r.parsed, isTrue);
      expect(r.voice, 'boğuk, kısa cümleler');
      expect(r.mannerism, 'bardağı siler');
      expect(r.wants, 'kirasını almak');
      expect(r.firstLine, 'Oda mı, dert mi?');
    });

    test('kesilen yanit tamamlanan alanlari kurtarir', () {
      final r = parseNpcResult(
        '{"name":"Mira","summary":"hancı","race":"insan",'
        '"appearance":"kısa boylu","voice":"boğ',
      );
      expect(r.parsed, isTrue);
      expect(r.name, 'Mira');
      expect(r.appearance, 'kısa boylu');
      expect(r.voice, isEmpty);
    });

    test('hic tam alan yoksa parsed false', () {
      final r = parseNpcResult('Sadece duz metin.');
      expect(r.parsed, isFalse);
      expect(r.appearance, 'Sadece duz metin.');
    });
  });
}
