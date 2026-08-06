import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../data/character_repository.dart';
import '../../data/db/database.dart';
import '../../domain/models/ability.dart';
import '../../domain/rules/origin_parsing.dart';

/// Oyuncunun kendi karakterini kurabilmesi için gereken sunucu tarafı.
///
/// **Neden burada:** oyuncu paneli veritabanını görmez (tarayıcıda çalışır,
/// LAN üzerinden konuşur). Sınıf/tür/geçmiş kataloğu ve kuralların çözümü
/// DM cihazında yapılır; panele yalnızca **seçenekler** gider, geri gelen
/// taslak burada **yeniden doğrulanır**. Böylece istemciden gelen hiçbir
/// sayıya (hit die, kurtarma atışı, beceri) güvenilmez — DM-otorite kuralı
/// karakter oluşturmada da geçerli.
class CharacterCreationService {
  CharacterCreationService(this.db) : characters = CharacterRepository(db);

  final AppDatabase db;
  final CharacterRepository characters;

  /// Panele gönderilen katalog.
  Future<Map<String, dynamic>> options() async {
    final classes = await characters.classOptions();
    final species = await characters.speciesOptions();
    final backgrounds = await characters.backgroundOptions();

    return {
      'classes': [
        for (final row in classes)
          if (_coreOf(row) case final core?)
            {
              'key': row.key,
              'name': row.name,
              'hitDie': core.hitDieSides,
              'saves': [for (final a in core.savingThrows) a.name],
              'skillChoiceCount': core.skillChoiceCount,
              'anySkill': core.anySkill,
              'skillOptions': [for (final s in core.skillOptions) s.name],
              'equipment': _equipmentJson(core.equipmentOptions),
            },
      ],
      'species': [
        for (final row in species)
          {
            'key': row.key,
            'name': row.name,
            'sizes': _speciesOf(row)?.sizes ?? const <String>[],
          },
      ],
      'backgrounds': [
        for (final row in backgrounds)
          if (_benefitsOf(row) case final b?)
            {
              'key': row.key,
              'name': row.name,
              'abilityOptions': [for (final a in b.abilityOptions) a.name],
              'skills': [for (final s in b.skills) s.name],
              'equipment': _equipmentJson(b.equipmentOptions),
            },
      ],
    };
  }

  /// Taslağı doğrulayıp karakteri oluşturur; yeni karakterin id'sini döner.
  ///
  /// Hata durumunda [CreationRejected] fırlatır — çağıran bunu oyuncuya
  /// gösterilecek metne çevirir.
  Future<String> create(Map<String, dynamic> draft) async {
    final name = '${draft['name'] ?? ''}'.trim();
    if (name.isEmpty) throw const CreationRejected('needName');

    final classKey = draft['classKey'] as String?;
    if (classKey == null) throw const CreationRejected('needClass');

    final classRow = (await characters.classOptions())
        .where((c) => c.key == classKey)
        .firstOrNull;
    final core = classRow == null ? null : _coreOf(classRow);
    if (core == null) throw const CreationRejected('needClass');

    final speciesKey = draft['speciesKey'] as String?;
    final backgroundKey = draft['backgroundKey'] as String?;
    final benefits = backgroundKey == null
        ? null
        : _benefitsOf(
            (await characters.backgroundOptions())
                .where((b) => b.key == backgroundKey)
                .firstOrNull,
          );

    // Puanlar 1..20 arasina KISILIYOR: istemciden gelen sayiya guvenilmez.
    final scores = (draft['scores'] as Map?)?.cast<String, dynamic>() ?? {};
    int score(Ability a) =>
        ((scores[a.name] as num?)?.toInt() ?? 10).clamp(1, 20);
    final abilities = AbilityScores(
      strength: score(Ability.strength),
      dexterity: score(Ability.dexterity),
      constitution: score(Ability.constitution),
      intelligence: score(Ability.intelligence),
      wisdom: score(Ability.wisdom),
      charisma: score(Ability.charisma),
    );

    // Beceriler yalnizca sinifin (ya da 'anySkill' ise hepsinin) sundugu
    // secenekler arasindan; sayisi da sinifin izin verdigi kadar.
    final requested = <Skill>{
      for (final raw in (draft['skills'] as List? ?? const []))
        ...Skill.values.where((s) => s.name == raw),
    };
    final allowed = core.anySkill
        ? Skill.values.toSet()
        : core.skillOptions.toSet();
    final chosen = requested.intersection(allowed).take(core.skillChoiceCount);

    // Ekipman secimi: etiket sinif VE gecmis secenekleri icin ortak.
    final label = draft['equipmentChoice'] as String?;
    final options = label == null
        ? const <EquipmentOption>[]
        : [
            ...core.equipmentOptions.where((o) => o.label == label),
            ...?benefits?.equipmentOptions.where((o) => o.label == label),
          ];
    final gold = options.fold(0, (sum, o) => sum + o.goldPieces);
    final items = [
      for (final option in options)
        for (final e in option.entries) (name: e.name, quantity: e.quantity),
    ];

    final id = 'pc-${DateTime.now().microsecondsSinceEpoch}';
    await characters.createLevelOneCharacter(
      id: id,
      name: name,
      playerName: '${draft['playerName'] ?? ''}'.trim().isEmpty
          ? null
          : '${draft['playerName']}'.trim(),
      classKey: classKey,
      speciesKey: speciesKey,
      backgroundKey: backgroundKey,
      abilities: abilities,
      // Kurtarma atislari ve hit die SINIFTAN okunur, istemciden DEGIL.
      savingThrows: core.savingThrows,
      skills: {...chosen, ...?benefits?.skills},
      hitDieSides: core.hitDieSides,
      startingGoldGp: gold,
      startingItems: items,
    );

    await _storePortrait(id, draft['portrait'] as String?);
    return id;
  }

  /// Oyuncunun yolladigi portreyi (base64) karaktere baglar.
  ///
  /// Gecici dosyaya yazilip `setPortrait`'e veriliyor: portre deposu dosya
  /// bekliyor ve orada yeniden kodlanip kucultuluyor. Bozuk/desteklenmeyen
  /// gorsel karakteri OLUSTURMAYI ENGELLEMEZ — DM sonradan ekleyebilir.
  Future<void> _storePortrait(String characterId, String? base64Data) async {
    if (base64Data == null || base64Data.isEmpty) return;
    File? temp;
    try {
      final bytes = base64Decode(base64Data);
      temp = File(
        p.join(Directory.systemTemp.path, 'dm-portrait-$characterId.png'),
      );
      await temp.writeAsBytes(bytes);
      await characters.setPortrait(characterId, temp);
    } on Object {
      // Portre yazilamadi; karakter yine de kuruldu.
    } finally {
      if (temp != null && temp.existsSync()) {
        try {
          await temp.delete();
        } on FileSystemException {
          // Gecici dosya kalabilir; onemsiz.
        }
      }
    }
  }

  static List<Map<String, dynamic>> _equipmentJson(
    List<EquipmentOption> options,
  ) => [
    for (final o in options)
      {
        'label': o.label,
        'gold': o.goldPieces,
        'items': [
          for (final e in o.entries) {'name': e.name, 'quantity': e.quantity},
        ],
      },
  ];

  ClassCoreTraits? _coreOf(ClassDefinition row) {
    final data = jsonDecode(row.dataJson) as Map<String, dynamic>;
    final core = (data['features'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .where((f) => '${f['feature_type']}' == 'CORE_TRAITS_TABLE')
        .firstOrNull;
    if (core == null) return null;
    return parseClassCoreTraits('${core['desc'] ?? ''}');
  }

  BackgroundBenefits? _benefitsOf(Background? row) {
    if (row == null) return null;
    final data = jsonDecode(row.dataJson) as Map<String, dynamic>;
    return parseBackgroundBenefits(data['benefits'] as List? ?? const []);
  }

  SpeciesTraits? _speciesOf(SpeciesEntry row) {
    final data = jsonDecode(row.dataJson) as Map<String, dynamic>;
    return parseSpeciesTraits(data['traits'] as List? ?? const []);
  }
}

/// Oyuncuya gösterilecek koda çevrilebilen ret sebebi.
class CreationRejected implements Exception {
  const CreationRejected(this.code);

  /// `encodeServerMsg` ile çevrilecek kod ('needName', 'needClass'...).
  final String code;
}
