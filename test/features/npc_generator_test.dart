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
    );
    final prompt = buildPortraitPrompt(r);
    expect(prompt, contains('cüce'));
    expect(prompt, contains('yaşlı'));
    expect(prompt, contains('kalın kollar, is lekeli önlük'));
    expect(prompt, contains('aksi ama dürüst'));
    // DM sirri portre istemine ASLA girmemeli.
    expect(prompt, isNot(contains('kaçak bir prens')));
    expect(prompt, isNot(contains('cevher arıyor')));
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
    );
    final prompt = buildPortraitPrompt(r);
    expect(prompt, contains('elf'));
    expect(prompt, isNot(contains('Approximate age:')));
    expect(prompt, isNot(contains('Gender:')));
  });
}
