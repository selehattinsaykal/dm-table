import 'package:dm_table/data/character_repository.dart';
import 'package:dm_table/data/db/character_tables.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/import/asset_importer.dart';
import 'package:dm_table/domain/models/ability.dart';
import 'package:dm_table/features/session/character_creation_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Oyuncunun kendi karakterini kurması: katalog + **sunucu tarafı doğrulama**.
///
/// DM-otorite kuralı burada da geçerli — panelden gelen hiçbir kural değerine
/// (hit die, kurtarma atışı, beceri) güvenilmez.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CharacterCreationService service;
  late CharacterRepository characters;

  setUpAll(() async {
    db = AppDatabase(NativeDatabase.memory());
    await AssetImporter(db).importIfNeeded();
  });

  tearDownAll(() async => db.close());

  setUp(() {
    service = CharacterCreationService(db);
    characters = CharacterRepository(db);
  });

  /// Karakterin beceri yeterlilikleri (yalniz `skill` turu satirlar).
  Future<Set<String>> skillNames(String id) async {
    final rows = await characters.proficiencies(id);
    return {
      for (final r in rows)
        if (r.kind == ProficiencyKind.skill) r.value,
    };
  }

  Future<Map<String, dynamic>> firstClass() async {
    final options = await service.options();
    return (options['classes'] as List).first as Map<String, dynamic>;
  }

  test('katalog sinif/tur/gecmis listelerini doldurur', () async {
    final options = await service.options();

    expect(options['classes'], isNotEmpty);
    expect(options['species'], isNotEmpty);
    expect(options['backgrounds'], isNotEmpty);

    final cls = (options['classes'] as List).first as Map<String, dynamic>;
    expect(cls['key'], isNotEmpty);
    expect(cls['hitDie'], greaterThan(0));
    expect(cls['saves'], isA<List>());
  });

  test('gecerli taslak karakteri olusturur', () async {
    final cls = await firstClass();
    final id = await service.create({
      'name': 'Vex',
      'playerName': 'Selo',
      'classKey': cls['key'],
      'scores': {for (final a in Ability.values) a.name: 12},
      'skills': (cls['skillOptions'] as List)
          .take(cls['skillChoiceCount'] as int)
          .toList(),
    });

    final row = await characters.find(id);
    expect(row, isNotNull);
    expect(row!.name, 'Vex');
    // Hit die SINIFTAN geldi: 1. seviyede tam degeri + CON modifieri.
    expect(row.hitPointsMax, (cls['hitDie'] as int) + 1);
  });

  test('ad bos ise reddedilir', () async {
    final cls = await firstClass();
    expect(
      () => service.create({'name': '   ', 'classKey': cls['key']}),
      throwsA(isA<CreationRejected>()),
    );
  });

  test('bilinmeyen sinif reddedilir', () async {
    expect(
      () => service.create({'name': 'X', 'classKey': 'uydurma-sinif'}),
      throwsA(isA<CreationRejected>()),
    );
  });

  test('SISIRILMIS puanlar 20 ile sinirlanir', () async {
    final cls = await firstClass();
    final id = await service.create({
      'name': 'Hilebaz',
      'classKey': cls['key'],
      'scores': {for (final a in Ability.values) a.name: 99},
      'skills': const [],
    });

    final row = await characters.find(id);
    expect(row!.strength, 20);
    expect(row.charisma, 20);
  });

  test('izin verilenden FAZLA beceri gonderilirse kirpilir', () async {
    final options = await service.options();
    // Beceri secimi olan bir sinif bul.
    final cls = (options['classes'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((c) => (c['skillChoiceCount'] as int) > 0);
    final allowed = cls['skillChoiceCount'] as int;

    final id = await service.create({
      'name': 'Açgözlü',
      'classKey': cls['key'],
      'scores': {for (final a in Ability.values) a.name: 10},
      // Sinifin sundugu TUM beceriler + gecerli olmayan bir tane.
      'skills': [...(cls['skillOptions'] as List), 'uydurmaBeceri'],
    });

    final skills = await skillNames(id);
    expect(skills.length, lessThanOrEqualTo(allowed));
  });

  test('sinifin sunmadigi beceri yok sayilir', () async {
    final options = await service.options();
    final cls = (options['classes'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere(
          (c) => (c['skillChoiceCount'] as int) > 0 && !(c['anySkill'] as bool),
        );
    final offered = (cls['skillOptions'] as List).cast<String>().toSet();
    final outsider = Skill.values
        .firstWhere((s) => !offered.contains(s.name))
        .name;

    final id = await service.create({
      'name': 'Sızmacı',
      'classKey': cls['key'],
      'scores': {for (final a in Ability.values) a.name: 10},
      'skills': [outsider],
    });

    expect(await skillNames(id), isNot(contains(outsider)));
  });
}
