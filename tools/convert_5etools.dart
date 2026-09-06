// 5etools -> Open5e v2 JSON donusturucu.
//
// Kitap basina bir kez calistirilir; ciktisi `tools/content_sources/` altina
// `{endpoint}_{bookKey}.json` olarak yazilir ve `fetch_open5e.dart` tarafindan
// `assets/data/*.json.gz` paketlerine karistirilir.
//
// Kullanim:
//   dart run tools/convert_5etools.dart --book=eberron-forge --raw=tools/content_sources/raw
//   dart run tools/convert_5etools.dart --book=faerun-heroes --spells=... --feats=...
//
// ONEMLI: Cikti SEMASI, open5e API'sinin `srd-2024` kayitlariyla birebir ayni
// olmak zorunda. Uygulama alan adlarini dogrudan okuyor (`hit_dice`,
// `caster_type`, `subclass_of.key`, `verbal/somatic/material`,
// `saving_throws`, `skill_bonuses`, `benefits[].type` ...). Kendi alan adlarini
// uydurmak (`hd`, `saves`, `components`) veriyi sessizce gorunmez yapiyor.
//
// Ayrica 5etools metinleri `{@spell Fireball|XPHB}` gibi isaretleme tasir;
// hepsi [_markup] ile duz metne cevrilir.

import 'dart:convert';
import 'dart:io';

/// Bir kaynak kitabin 5etools tarafindaki karsiligi.
class _Book {
  const _Book({
    required this.title,
    required this.sources,
    required this.rawCodes,
    this.fileKey,
  });

  final String title;

  /// Cikti dosyasi adinda kullanilan kisaltma. Verilmezse kitap anahtari.
  /// (2024 PHB icerigi depoda `*_phb.json` adiyla duruyor.)
  final String? fileKey;

  /// 5etools `source` kodlari, ONCELIK SIRALI. Ayni isimli kayit birden fazla
  /// kaynakta varsa (Ravenloft'ta RHW 2024 basimi ile VRGR 2014 basimi) listede
  /// once gelen kazanir.
  final List<String> sources;

  /// `--raw` dizinindeki dosya adlarinda gecen kisaltmalar
  /// (`bestiary-efa.json`, `spells-frhof.json`).
  final List<String> rawCodes;
}

const _books = <String, _Book>{
  'eberron-forge': _Book(
    title: 'Eberron: Forge of the Artificer',
    sources: ['EFA'],
    rawCodes: ['efa'],
  ),
  'ravenloft-horrors': _Book(
    title: 'Ravenloft: The Horrors Within',
    sources: ['RHW'],
    rawCodes: ['rhw'],
  ),
  'faerun-heroes': _Book(
    title: 'Forgotten Realms: Heroes of Faerûn',
    sources: ['FRHoF'],
    rawCodes: ['frhof'],
  ),
  // 2024 PHB: SRD'de bulunmayan alt siniflar buradan geliyor
  // (`--subclasses-only` ile calistirilir; temel siniflar API'den zaten tam).
  'phb-2024': _Book(
    title: "Player's Handbook 2024",
    sources: ['XPHB'],
    rawCodes: ['xphb'],
    fileKey: 'phb',
  ),
};

/// 2024 temel siniflarinin uygulama icindeki anahtarlari. Alt siniflarin
/// `subclass_of.key` alani BURAYA baglanmak zorunda; tutmayan anahtar alt
/// sinifi listede bagimsiz bir sinif gibi gosteriyor.
const _srdClasses = <String>{
  'barbarian',
  'bard',
  'cleric',
  'druid',
  'fighter',
  'monk',
  'paladin',
  'ranger',
  'rogue',
  'sorcerer',
  'warlock',
  'wizard',
};

/// SRD disinda kalan temel siniflar hangi kitapta tanimliysa oradan gelir.
/// (Ravenloft'un Reanimator'u Eberron'un Artificer'ina bagli.)
const _bookClasses = <String, String>{'artificer': 'eberron-forge_artificer'};

/// 2024 sinif govdeleri. Alt siniflarin `classSource` alani bunlardan biri
/// degilse kayit 2014 basimidir ve alinmaz.
const _modernClassSources = <String>{'XPHB', 'EFA'};

const _endpoints = <String>[
  'creatures',
  'spells',
  'items',
  'magicitems',
  'classes',
  'backgrounds',
  'species',
  'feats',
];

Future<void> main(List<String> args) async {
  final bookKey = _argValue(args, '--book');
  final book = _books[bookKey];
  if (book == null) {
    stderr.writeln(
      'Kullanim: dart run tools/convert_5etools.dart --book=<key> '
      '[--raw=<dizin>] [--spells=<yol>] [--creatures=<yol>] [--items=<yol>] '
      '[--classes=<yol,yol>] [--backgrounds=<yol>] [--species=<yol>] '
      '[--feats=<yol>] [--objects=<yol>] [--spell-classes=<yol>] '
      '[--optional-features=<yol>] '
      '[--source=EFA,...] [--only=Ad,Ad] '
      '[--subclasses-only] [--out=<dizin>]',
    );
    stderr.writeln('Desteklenen kitaplar: ${_books.keys.join(", ")}');
    exitCode = 1;
    return;
  }

  final rawDir = _argValue(args, '--raw');
  final outDir = _argValue(args, '--out') ?? 'tools/content_sources';
  // 2024 PHB'de temel siniflar open5e API'sinden tam geliyor; yalnizca SRD'de
  // olmayan alt siniflar dosyadan besleniyor.
  final subclassesOnly = args.contains('--subclasses-only');
  // `--only=Crag Cat` — baska bir kitaptan YALNIZCA adi gecen kayitlari alir
  // (sinif ozelliklerinin isaret ettigi tek tuk yaratiklar icin).
  final only = _argValue(args, '--only')
      ?.split(',')
      .map((s) => s.trim().toLowerCase())
      .where((s) => s.isNotEmpty)
      .toSet();
  final fileKey = book.fileKey ?? bookKey!;
  final sources =
      _argValue(
        args,
        '--source',
      )?.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList() ??
      book.sources;

  final inputs = <String, List<String>>{};
  if (rawDir != null) inputs.addAll(_discover(rawDir, book));
  for (final entry in const {
    'creatures': '--creatures',
    'spells': '--spells',
    'items': '--items',
    'magicitems': '--magicitems',
    'backgrounds': '--backgrounds',
    'species': '--species',
    'feats': '--feats',
    'classes': '--classes',
  }.entries) {
    final value = _argValue(args, entry.value);
    if (value == null) continue;
    inputs[entry.key] = value
        .split(RegExp(r'[,\s]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  // 5etools'un buyu->sinif eslemesi (data/spells/sources.json). Kitap
  // siniflarinin (Artificer) buyu listesi open5e verisinde hic yok.
  final spellClassesPath = _argValue(args, '--spell-classes');
  if (spellClassesPath != null) {
    final data = _readJson(spellClassesPath);
    if (data != null) {
      final lists = _spellClassLists(data);
      final file = File('$outDir/spell_classes.json');
      file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(lists));
      stdout.writeln(
        '  -> ${file.path} (${lists.length} sinif, '
        '${lists.values.fold<int>(0, (a, b) => a + b.length)} buyu)',
      );
    }
  }

  // Sinif secenekleri (Eldritch Invocation, Metamagic, Maneuver...). Tek bir
  // referans dosyasi olarak yaziliyor; belge bazli degil.
  final optionalPath = _argValue(args, '--optional-features');
  if (optionalPath != null) {
    final data = _readJson(optionalPath);
    if (data != null) {
      final rows = _optionalFeatures(data, sources);
      final file = File('$outDir/optionalfeatures.json');
      file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(rows));
      stdout.writeln('  -> ${file.path} (${rows.length} secenek)');
    }
  }

  // Nesne dosyasi ayri bir uc nokta degil: canavar cevirisiyle ayni adimda
  // isleniyor (bkz. `_objects`).
  final objectPaths = _argValue(args, '--objects');
  if (objectPaths != null) {
    (inputs['creatures'] ??= []).addAll(
      objectPaths
          .split(RegExp(r'[,\s]+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty),
    );
  }

  if (inputs.isEmpty) {
    stderr.writeln(
      'Girdi yok: --raw=<dizin> ver ya da uc nokta bayraklarini tek tek gec.',
    );
    exitCode = 1;
    return;
  }

  stdout.writeln('${book.title} ($bookKey)');
  stdout.writeln('  kaynak filtresi: ${sources.join(", ")}');

  Directory(outDir).createSync(recursive: true);

  // items/magicitems ayni dosyadan gelir: nadirligi olan kayit buyulu esyadir.
  final split = <String, List<Map<String, dynamic>>>{};

  // Sinif ozellikleri stat bloklarina isim vererek atifta bulunuyor
  // ("Eldritch Cannon yarat"). Canavarlar siniflardan ONCE cevrildigi icin
  // burada biriktirip ozelligin metnine gomuyoruz.
  final statBlocks = <String, Map<String, dynamic>>{};

  for (final endpoint in _endpoints) {
    // magicitems ayri bir girdi dosyasi degil: `items` cevirisi nadirligi olan
    // kayitlari [split] uzerinden buraya birakiyor.
    final paths = endpoint == 'magicitems'
        ? const <String>[]
        : (inputs[endpoint] ?? const <String>[]);
    if (paths.isEmpty && !split.containsKey(endpoint)) {
      // Girdi verilmeyen uc noktaya DOKUNMUYORUZ: `spells_phb.json` gibi elle
      // bakilan dosyalar ayni ada sahip olabiliyor ve bir kez silindiler.
      stdout.writeln('  $endpoint: girdi yok (dosyaya dokunulmadi)');
      continue;
    }

    final rows = <Map<String, dynamic>>[];
    for (final path in paths) {
      final data = _readJson(path);
      if (data == null) continue;
      rows.addAll(
        _convert(
          data,
          endpoint,
          bookKey!,
          sources,
          split,
          subclassesOnly: subclassesOnly,
          only: only,
          statBlocks: statBlocks,
        ),
      );
    }
    rows.addAll(split.remove(endpoint) ?? const []);

    if (endpoint == 'creatures') {
      for (final row in rows) {
        statBlocks['${row['name']}'.toLowerCase()] = row;
      }
    }

    final deduped = _dedupe(rows, sources);
    if (deduped.isEmpty) {
      // Var olan ciktiyi SILMIYORUZ: ayni uc nokta baska bir komutla (farkli
      // bir kaynak dosyadan) uretilmis olabiliyor. Bir kaydi listeden cikarmak
      // gerekirse dosya elle silinir.
      stdout.writeln('  $endpoint: kayit yok (mevcut dosya korundu)');
      continue;
    }
    final file = File('$outDir/${endpoint}_$fileKey.json');
    file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(deduped));
    stdout.writeln('  -> ${file.path} (${deduped.length} kayit)');
  }

  // `--docs` yalnizca API'de olmayan KAYNAK KITAPLARI sayar; 2024 PHB
  // icerigi belge listesine girmeden `classes_phb.json` uzerinden birlesiyor.
  final docKeys = _books.entries
      .where((e) => e.value.fileKey == null)
      .map((e) => e.key);
  stdout.writeln(
    '\nBitti. Paketlere islemek icin: '
    'dart run tools/fetch_open5e.dart --offline '
    '--docs=srd-2024,${docKeys.join(",")}',
  );
}

/// `--raw` dizininden bu kitaba ait standart 5etools dosyalarini bulur.
Map<String, List<String>> _discover(String dir, _Book book) {
  final found = <String, List<String>>{};
  void add(String endpoint, String path) {
    if (!File(path).existsSync()) return;
    (found[endpoint] ??= []).add(path);
  }

  for (final code in book.rawCodes) {
    add('creatures', '$dir/bestiary-$code.json');
    add('spells', '$dir/spells-$code.json');
  }
  // Nesneler canavar paketine giriyor; ayni uc noktadan cevriliyorlar.
  add('creatures', '$dir/objects.json');
  add('items', '$dir/items.json');
  add('items', '$dir/items-base.json');
  add('backgrounds', '$dir/backgrounds.json');
  add('species', '$dir/races.json');
  add('feats', '$dir/feats.json');

  final classDir = Directory(dir);
  if (classDir.existsSync()) {
    final classFiles =
        classDir
            .listSync()
            .whereType<File>()
            .map((f) => f.path.replaceAll(r'\', '/'))
            .where((p) => p.split('/').last.startsWith('class-'))
            .toList()
          ..sort();
    if (classFiles.isNotEmpty) found['classes'] = classFiles;
  }
  return found;
}

/// 5etools indirmeleri arasinda "404: Not Found" govdeli dosyalar oluyor;
/// bunlari sessizce atlamak yerine uyarip geciyoruz.
Map<String, dynamic>? _readJson(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('  UYARI: dosya yok, atlandi: $path');
    return null;
  }
  try {
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is Map<String, dynamic>) return decoded;
    stderr.writeln('  UYARI: beklenen nesne degil, atlandi: $path');
    return null;
  } on FormatException {
    stderr.writeln('  UYARI: gecersiz JSON (indirme bos olabilir): $path');
    return null;
  }
}

/// Ayni isimli kayitlari teke indirir; [sources] sirasi onceligi belirler.
List<Map<String, dynamic>> _dedupe(
  List<Map<String, dynamic>> rows,
  List<String> sources,
) {
  final byName = <String, Map<String, dynamic>>{};
  for (final row in rows) {
    final name = (row['name'] as String).toLowerCase();
    final current = byName[name];
    if (current == null) {
      byName[name] = row;
      continue;
    }
    final a = sources.indexOf('${current['_source']}');
    final b = sources.indexOf('${row['_source']}');
    if (b >= 0 && (a < 0 || b < a)) byName[name] = row;
  }
  return [
    for (final row in byName.values)
      Map<String, dynamic>.from(row)..remove('_source'),
  ];
}

List<Map<String, dynamic>> _convert(
  Map<String, dynamic> data,
  String endpoint,
  String bookKey,
  List<String> sources,
  Map<String, List<Map<String, dynamic>>> split, {
  bool subclassesOnly = false,
  Set<String>? only,
  Map<String, Map<String, dynamic>> statBlocks = const {},
}) {
  switch (endpoint) {
    case 'creatures':
      return [
        ..._creatures(data, bookKey, sources, only: only),
        ..._objects(data, bookKey, sources, only: only),
      ];
    case 'spells':
      return _spells(data, bookKey, sources);
    case 'items':
      return _items(data, bookKey, sources, split);
    case 'magicitems':
      return const [];
    case 'classes':
      return _classes(
        data,
        bookKey,
        sources,
        subclassesOnly: subclassesOnly,
        statBlocks: statBlocks,
      );
    case 'backgrounds':
      return _backgrounds(data, bookKey, sources);
    case 'species':
      return _species(data, bookKey, sources);
    case 'feats':
      return _feats(data, bookKey, sources);
    default:
      return const [];
  }
}

// ---------------------------------------------------------------------------
// Canavarlar
// ---------------------------------------------------------------------------

List<Map<String, dynamic>> _creatures(
  Map<String, dynamic> data,
  String bookKey,
  List<String> sources, {
  Set<String>? only,
}) {
  final out = <Map<String, dynamic>>[];
  for (final m in _rows(data, 'monster', sources)) {
    if (only != null && !only.contains('${m['name']}'.toLowerCase())) continue;
    // CR YOKLUGUNA gore elemek yanlisti: sinif yoldaslarinin (Steel Defender,
    // Homunculus Servant) CR'si olmaz ve tam da onlar sinif ozelliklerinden
    // referansla cagriliyor. Olcut artik stat blogu var mi.
    if (m['ac'] == null && m['hp'] == null) continue;

    final scores = <String, int>{
      'strength': _int(m['str']) ?? 10,
      'dexterity': _int(m['dex']) ?? 10,
      'constitution': _int(m['con']) ?? 10,
      'intelligence': _int(m['int']) ?? 10,
      'wisdom': _int(m['wis']) ?? 10,
      'charisma': _int(m['cha']) ?? 10,
    };
    final mods = scores.map((k, v) => MapEntry(k, _modifier(v)));

    final saves = <String, int>{};
    if (m['save'] is Map) {
      for (final e in (m['save'] as Map).entries) {
        final ability = _abilityKey('${e.key}');
        final value = _bonus('${e.value}');
        if (ability != null && value != null) saves[ability] = value;
      }
    }

    final skills = <String, int>{};
    if (m['skill'] is Map) {
      for (final e in (m['skill'] as Map).entries) {
        if ('${e.key}' == 'other') continue;
        final value = _bonus('${e.value}');
        if (value != null) skills['${e.key}'.replaceAll(' ', '_')] = value;
      }
    }

    final senses = _senses(m['senses']);
    final cr = _cr(m['cr']);
    final ac = _armorClass(m['ac']);
    final speed = _speed(m['speed']);

    out.add({
      '_source': m['source'],
      'key': '${bookKey}_${_slug('${m['name']}')}',
      'name': m['name'],
      'document': bookKey,
      'type': _named(_creatureType(m['type'])),
      'size': _named(_size(m['size'])),
      'challenge_rating': cr,
      'proficiency_bonus': null,
      'speed': speed,
      'speed_all': speed,
      'category': 'Monsters',
      'subcategory': null,
      'alignment': _alignment(m['alignment']),
      'languages': {'as_string': _list(m['languages']), 'data': const []},
      'armor_class': ac.$1,
      'armor_detail': ac.$2,
      'hit_points': _int(m['hp'] is Map ? m['hp']['average'] : m['hp']) ?? 0,
      // Yoldaslarin cani formul yerine serbest metin olabiliyor ("5 + 5 per
      // spell level"); stat blogu bunu hit dice satirinda gosteriyor.
      'hit_dice': m['hp'] is Map
          ? _markup('${m['hp']['formula'] ?? m['hp']['special'] ?? ''}')
          : '',
      'experience_points': _xpForCr(cr),
      'ability_scores': scores,
      'modifiers': mods,
      // `initiative` ya {proficiency: n} (DEX + n x yeterlilik bonusu) ya da
      // dogrudan bonusun kendisi olabiliyor.
      'initiative_bonus': switch (m['initiative']) {
        final num value => value.toInt(),
        final Map<String, dynamic> value =>
          mods['dexterity']! +
              (_int(value['proficiency']) ?? 0) * _crProficiency(cr),
        _ => mods['dexterity'],
      },
      'saving_throws': saves,
      'saving_throws_all': {
        for (final e in mods.entries) e.key: saves[e.key] ?? e.value,
      },
      'skill_bonuses': skills,
      'skill_bonuses_all': const <String, int>{},
      'passive_perception':
          _int(m['passive']) ?? 10 + (skills['perception'] ?? mods['wisdom']!),
      'darkvision_range': senses['darkvision'] ?? 0,
      'blindsight_range': senses['blindsight'] ?? 0,
      'tremorsense_range': senses['tremorsense'] ?? 0,
      'truesight_range': senses['truesight'] ?? 0,
      'normal_sight_range': null,
      'resistances_and_immunities': {
        'damage_resistances_display': _defense(m['resist']),
        'damage_resistances': const [],
        'damage_immunities_display': _defense(m['immune']),
        'damage_immunities': const [],
        'damage_vulnerabilities_display': _defense(m['vulnerable']),
        'damage_vulnerabilities': const [],
        'condition_immunities_display': _defense(m['conditionImmune']),
        'condition_immunities': const [],
      },
      'traits': [
        ..._entryBlocks(m['trait']),
        ..._spellcastingBlocks(m['spellcasting']),
      ],
      'actions': [
        ..._actions(m['action'], 'ACTION'),
        ..._actions(m['bonus'], 'BONUS_ACTION'),
        ..._actions(m['reaction'], 'REACTION'),
        ..._actions(m['legendary'], 'LEGENDARY_ACTION'),
      ],
      'environments': const [],
      'crossreferences': const {'to': []},
    });
  }
  return out;
}

/// Sinif seceneklerinin tipi -> okunur ad ve sahibi sinif.
const _optionalFeatureTypes = <String, ({String name, String classKey})>{
  'EI': (name: 'Eldritch Invocation', classKey: 'srd-2024_warlock'),
  'MM': (name: 'Metamagic', classKey: 'srd-2024_sorcerer'),
  'MV:B': (name: 'Maneuver', classKey: 'srd-2024_fighter'),
  'RP': (name: 'Rune', classKey: 'srd-2024_fighter'),
  'AI': (name: 'Infusion', classKey: 'eberron-forge_artificer'),
  'FS:F': (name: 'Fighting Style', classKey: 'srd-2024_fighter'),
  'FS:P': (name: 'Fighting Style', classKey: 'srd-2024_paladin'),
  'FS:R': (name: 'Fighting Style', classKey: 'srd-2024_ranger'),
};

/// 5etools `optionalfeatures.json` -> sinif secenekleri.
///
/// Fighting Style, Eldritch Invocation, Metamagic, Maneuver gibi "sinifin
/// verdigi ama oyuncunun sectigi" ozellikler. Metinleri veride vardi ama
/// uygulamada hicbir secim yoktu.
List<Map<String, dynamic>> _optionalFeatures(
  Map<String, dynamic> data,
  List<String> sources,
) {
  final out = <Map<String, dynamic>>[];
  for (final row
      in (data['optionalfeature'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()) {
    // 2024 icerigi ve bizim kitaplarimiz.
    if (!['XPHB', 'EFA', 'RHW', 'FRHoF'].contains('${row['source']}')) continue;

    final types = (row['featureType'] as List? ?? const [])
        .map((t) => '$t')
        .where(_optionalFeatureTypes.containsKey)
        .toList();
    if (types.isEmpty) continue;

    for (final type in types) {
      final meta = _optionalFeatureTypes[type]!;
      out.add({
        'key': '${_slug(meta.name)}_${_slug('${row['name']}')}',
        'name': row['name'],
        'type': type,
        'type_name': meta.name,
        'class_key': meta.classKey,
        'prerequisite': _prerequisite(row['prerequisite']),
        'desc': _text(row['entries']),
        'document': '${row['source']}' == 'XPHB' ? 'phb-2024' : 'srd-2024',
      });
    }
  }
  out.sort((a, b) {
    final byType = '${a['type_name']}'.compareTo('${b['type_name']}');
    return byType != 0 ? byType : '${a['name']}'.compareTo('${b['name']}');
  });
  return out;
}

/// 5etools'un buyu->sinif eslemesini (`data/spells/sources.json`) bizim sinif
/// anahtarlarimiza cevirir.
///
/// Yalnizca open5e'nin BILMEDIGI siniflar yaziliyor. SRD'nin 8 buyucu sinifi
/// zaten her buyunun `classes` alaninda geliyor; Artificer gibi kitap
/// siniflarinin listesi ise hicbir yerde yok ve o yuzden buyu secim ekrani
/// bos aciliyordu.
Map<String, List<String>> _spellClassLists(Map<String, dynamic> data) {
  final out = <String, Set<String>>{};
  for (final book in data.values) {
    if (book is! Map) continue;
    for (final entry in book.entries) {
      final spellName = '${entry.key}';
      final value = entry.value;
      if (value is! Map) continue;
      for (final c in (value['class'] as List? ?? const []).whereType<Map>()) {
        final key = _spellClassKey('${c['name']}', '${c['source']}');
        if (key == null) continue;
        (out[key] ??= <String>{}).add(spellName);
      }
    }
  }
  return {for (final e in out.entries) e.key: (e.value.toList()..sort())};
}

/// Sinif adi + 5etools kaynagi -> bizim sinif anahtarimiz. SRD siniflari
/// atlanir (listeleri open5e'den geliyor).
String? _spellClassKey(String name, String source) {
  final slug = _slug(name);
  if (_srdClasses.contains(slug)) return null;
  return _bookClasses[slug];
}

/// 5etools "object" kayitlarini (Eldritch Cannon gibi) canavar semasina
/// cevirir.
///
/// Sinif ozellikleri bunlara yaratik gibi atifta bulunuyor ("Eldritch Cannon
/// yarat"); ayri bir uc nokta acmak yerine ayni stat blogu ekraninda
/// gosterilebilsinler diye canavar paketine giriyorlar.
List<Map<String, dynamic>> _objects(
  Map<String, dynamic> data,
  String bookKey,
  List<String> sources, {
  Set<String>? only,
}) {
  final out = <Map<String, dynamic>>[];
  for (final o in _rows(data, 'object', sources)) {
    if (only != null && !only.contains('${o['name']}'.toLowerCase())) continue;

    final ac = _armorClass(o['ac']);
    final hp = o['hp'];
    final speed = _speed(o['speed']);
    final scores = <String, int>{
      'strength': _int(o['str']) ?? 10,
      'dexterity': _int(o['dex']) ?? 10,
      'constitution': _int(o['con']) ?? 10,
      'intelligence': _int(o['int']) ?? 1,
      'wisdom': _int(o['wis']) ?? 3,
      'charisma': _int(o['cha']) ?? 1,
    };

    out.add({
      '_source': o['source'],
      'key': '${bookKey}_${_slug('${o['name']}')}',
      'name': o['name'],
      'document': bookKey,
      'type': _named('Object'),
      'size': _named(_size(o['size'])),
      'challenge_rating': 0.0,
      'proficiency_bonus': null,
      'speed': speed,
      'speed_all': speed,
      'category': 'Objects',
      'subcategory': null,
      'alignment': '',
      'languages': {'as_string': '', 'data': const []},
      'armor_class': ac.$1,
      'armor_detail': ac.$2,
      'hit_points': _int(hp is Map ? hp['average'] : hp) ?? 0,
      'hit_dice': hp is Map
          ? _markup('${hp['formula'] ?? hp['special'] ?? ''}')
          : '',
      'experience_points': 0,
      'ability_scores': scores,
      'modifiers': scores.map((k, v) => MapEntry(k, _modifier(v))),
      'initiative_bonus': 0,
      'saving_throws': const <String, int>{},
      'saving_throws_all': const <String, int>{},
      'skill_bonuses': const <String, int>{},
      'skill_bonuses_all': const <String, int>{},
      'passive_perception': 10,
      'darkvision_range': 0,
      'blindsight_range': 0,
      'tremorsense_range': 0,
      'truesight_range': 0,
      'normal_sight_range': null,
      'resistances_and_immunities': {
        'damage_resistances_display': _defense(o['resist']),
        'damage_resistances': const [],
        'damage_immunities_display': _defense(o['immune']),
        'damage_immunities': const [],
        'damage_vulnerabilities_display': _defense(o['vulnerable']),
        'damage_vulnerabilities': const [],
        'condition_immunities_display': _defense(o['conditionImmune']),
        'condition_immunities': const [],
      },
      'traits': [
        if (_text(o['entries']).isNotEmpty)
          {'name': 'Description', 'desc': _text(o['entries'])},
      ],
      'actions': [
        for (final (i, a) in (o['actionEntries'] as List? ?? const []).indexed)
          if (a is Map)
            {
              'name': _markup('${a['name'] ?? 'Action'}'),
              'desc': _text(a['entries'] ?? a['entry']),
              'action_type': 'ACTION',
              'order_in_statblock': i,
              'attacks': const [],
            },
      ],
      'environments': const [],
      'crossreferences': const {'to': []},
    });
  }
  return out;
}

(int?, String?) _armorClass(dynamic ac) {
  if (ac is List && ac.isNotEmpty) {
    final first = ac.first;
    if (first is Map) {
      // Yoldaslarin AC'si sayi degil formul olabiliyor ("12 + your
      // Intelligence modifier"); sayiya inecek bir sey yoksa metni ayrinti
      // satirinda gosteriyoruz, yoksa stat blokta bos bir AC kaliyordu.
      if (first['special'] != null) {
        final text = _markup('${first['special']}');
        return (_int(RegExp(r'\d+').firstMatch(text)?.group(0)), text);
      }
      final from = (first['from'] as List? ?? const [])
          .map((f) => _markup('$f'))
          .join(', ');
      return (
        _int(first['ac']),
        from.isEmpty
            ? (first['condition'] == null
                  ? null
                  : _markup('${first['condition']}'))
            : from,
      );
    }
    return (_int(first), null);
  }
  return (_int(ac), null);
}

Map<String, dynamic> _speed(dynamic speed) {
  final out = <String, dynamic>{'unit': 'feet'};
  if (speed is num) {
    out['walk'] = speed.toInt();
    return out;
  }
  if (speed is Map) {
    for (final e in speed.entries) {
      final key = '${e.key}';
      if (key == 'canHover') continue;
      final value = e.value;
      if (value is num) {
        out[key] = value.toInt();
      } else if (value is Map && value['number'] is num) {
        out[key] = (value['number'] as num).toInt();
      }
    }
  }
  return out;
}

Map<String, int> _senses(dynamic senses) {
  final out = <String, int>{};
  if (senses is! List) return out;
  for (final s in senses) {
    final text = _markup('$s').toLowerCase();
    for (final kind in const [
      'darkvision',
      'blindsight',
      'tremorsense',
      'truesight',
    ]) {
      final match = RegExp('$kind\\s+(\\d+)').firstMatch(text);
      if (match != null) out[kind] = int.parse(match.group(1)!);
    }
  }
  return out;
}

String _defense(dynamic value) {
  if (value == null) return '';
  if (value is String) return _markup(value);
  if (value is List) {
    return value
        .map((v) {
          if (v is String) return _markup(v);
          if (v is Map) {
            final inner = [
              ...?(v['resist'] as List?),
              ...?(v['immune'] as List?),
              ...?(v['vulnerable'] as List?),
              ...?(v['conditionImmune'] as List?),
            ].map((e) => _markup('$e')).join(', ');
            final note = v['note'] == null ? '' : ' ${_markup('${v['note']}')}';
            return '$inner$note'.trim();
          }
          return _markup('$v');
        })
        .where((s) => s.isNotEmpty)
        .join(', ');
  }
  return _markup('$value');
}

List<Map<String, dynamic>> _entryBlocks(dynamic list) {
  if (list is! List) return const [];
  return [
    for (final e in list.whereType<Map>())
      {'name': _markup('${e['name'] ?? ''}'), 'desc': _text(e['entries'])},
  ];
}

/// 5etools buyu yapma bloklarini stat blogunda okunabilir tek bir ozellige
/// cevirir (uygulama `traits[]` disinda buyu listesi gostermiyor).
List<Map<String, dynamic>> _spellcastingBlocks(dynamic list) {
  if (list is! List) return const [];
  final out = <Map<String, dynamic>>[];
  for (final block in list.whereType<Map>()) {
    final parts = <String>[_text(block['headerEntries'])];

    void addGroup(String label, dynamic spells) {
      if (spells == null) return;
      final names = <String>[];
      if (spells is List) {
        names.addAll(spells.map((s) => _markup('$s')));
      } else if (spells is Map) {
        for (final e in spells.entries) {
          final inner = e.value;
          final joined = inner is List
              ? inner.map((s) => _markup('$s')).join(', ')
              : _markup('$inner');
          names.add('${_frequency('${e.key}')}: $joined');
        }
      }
      if (names.isNotEmpty) parts.add('$label ${names.join('; ')}'.trim());
    }

    addGroup('At will:', block['will']);
    addGroup('', block['daily']);
    addGroup('', block['rest']);
    for (final e in (block['spells'] as Map? ?? const {}).entries) {
      final level = e.value;
      if (level is! Map) continue;
      final spells = (level['spells'] as List? ?? const [])
          .map((s) => _markup('$s'))
          .join(', ');
      final slots = level['slots'] == null ? '' : ' (${level['slots']} slots)';
      parts.add(
        '${e.key == '0' ? 'Cantrips' : '${_ordinal(int.tryParse('${e.key}') ?? 1)} level'}'
        '$slots: $spells',
      );
    }
    parts.add(_text(block['footerEntries']));

    out.add({
      'name': _markup('${block['name'] ?? 'Spellcasting'}'),
      'desc': parts.where((p) => p.trim().isNotEmpty).join('\n\n'),
    });
  }
  return out;
}

String _frequency(String key) {
  final match = RegExp(r'^(\d+)([e]?)').firstMatch(key);
  if (match == null) return key;
  final count = match.group(1);
  final each = match.group(2) == 'e' ? ' each' : '';
  return '$count/day$each';
}

List<Map<String, dynamic>> _actions(dynamic list, String type) {
  if (list is! List) return const [];
  var order = 0;
  return [
    for (final a in list.whereType<Map>())
      {
        'name': _markup('${a['name'] ?? ''}'),
        'desc': _text(a['entries']),
        'action_type': type,
        'order_in_statblock': order++,
        'attacks': const [],
      },
  ];
}

// ---------------------------------------------------------------------------
// Buyuler
// ---------------------------------------------------------------------------

List<Map<String, dynamic>> _spells(
  Map<String, dynamic> data,
  String bookKey,
  List<String> sources,
) {
  final out = <Map<String, dynamic>>[];
  for (final s in _rows(data, 'spell', sources)) {
    final components = s['components'] as Map? ?? const {};
    final material = components['m'];
    final range = _range(s['range']);
    final duration = _duration(s['duration']);

    out.add({
      '_source': s['source'],
      'key': '${bookKey}_${_slug('${s['name']}')}',
      'name': s['name'],
      'document': bookKey,
      'level': _int(s['level']) ?? 0,
      'school': _named(_school('${s['school']}')),
      'casting_time': _castingTime(s['time']),
      'ritual':
          s['ritual'] == true ||
          (s['meta'] is Map && s['meta']['ritual'] == true),
      'concentration': duration.$2,
      'verbal': components['v'] == true,
      'somatic': components['s'] == true,
      'material': material != null && material != false,
      'material_specified': material is Map
          ? _markup('${material['text'] ?? ''}')
          : (material is String ? _markup(material) : null),
      'material_cost': material is Map && material['cost'] is num
          ? ((material['cost'] as num) / 100).toStringAsFixed(2)
          : null,
      'material_consumed': material is Map && material['consume'] == true,
      'range': range.$1,
      'range_unit': range.$1 == null ? null : 'feet',
      'range_text': range.$2,
      'shape_type': range.$3,
      'shape_size': range.$4,
      'shape_size_unit': range.$4 == null ? null : 'feet',
      'target_type': null,
      'target_count': null,
      'duration': duration.$1,
      'damage_roll': null,
      'damage_types': [
        for (final d in (s['damageInflict'] as List? ?? const []))
          _named(_titleCase('$d')),
      ],
      'attack_roll': (s['spellAttack'] as List?)?.isNotEmpty ?? false,
      'saving_throw_ability': (s['savingThrow'] as List? ?? const [])
          .map((a) => '$a')
          .join(', '),
      'reaction_condition': null,
      'classes': const [],
      'desc': _text(s['entries']),
      'higher_level': _text(s['entriesHigherLevel']),
      'crossreferences': const {'to': []},
    });
  }
  return out;
}

String _castingTime(dynamic time) {
  if (time is! List || time.isEmpty) return 'action';
  return time
      .map((t) {
        if (t is! Map) return _markup('$t');
        final number = _int(t['number']) ?? 1;
        final unit = '${t['unit']}';
        final text = number == 1 ? unit : '$number ${unit}s';
        final condition = t['condition'] == null
            ? ''
            : ', ${_markup('${t['condition']}')}';
        return '$text$condition';
      })
      .join(' or ');
}

/// (mesafe, metin, sekil tipi, sekil boyutu)
(int?, String, String?, int?) _range(dynamic range) {
  if (range is! Map) return (null, 'Self', null, null);
  final type = '${range['type']}';
  final distance = range['distance'];
  final amount = _int(distance is Map ? distance['amount'] : null);
  final unit = distance is Map ? '${distance['type']}' : 'feet';

  switch (type) {
    case 'point':
      if (unit == 'self') return (null, 'Self', null, null);
      if (unit == 'touch') return (null, 'Touch', null, null);
      if (unit == 'sight') return (null, 'Sight', null, null);
      if (unit == 'unlimited') return (null, 'Unlimited', null, null);
      if (amount == null) return (null, _titleCase(unit), null, null);
      return (
        amount,
        '$amount ${unit == 'mile' ? 'miles' : 'feet'}',
        null,
        null,
      );
    case 'special':
      return (null, 'Special', null, null);
    default:
      // emanation / radius / sphere / cone / line / cube ...
      final shape = _titleCase(type);
      if (amount == null) return (null, 'Self', shape, null);
      return (null, 'Self ($amount-foot $shape)', shape, amount);
  }
}

/// (metin, konsantrasyon)
(String, bool) _duration(dynamic duration) {
  if (duration is! List || duration.isEmpty) return ('Instantaneous', false);
  var concentration = false;
  final parts = <String>[];
  for (final d in duration.whereType<Map>()) {
    if (d['concentration'] == true) concentration = true;
    switch ('${d['type']}') {
      case 'instant':
        parts.add('Instantaneous');
      case 'permanent':
        final ends = (d['ends'] as List? ?? const [])
            .map((e) => e == 'dispel' ? 'dispelled' : 'triggered')
            .join(' or ');
        parts.add(ends.isEmpty ? 'Permanent' : 'Until $ends');
      case 'special':
        parts.add('Special');
      case 'timed':
      default:
        final inner = d['duration'];
        if (inner is Map) {
          final amount = _int(inner['amount']) ?? 1;
          final unit = '${inner['type']}';
          parts.add('$amount ${amount == 1 ? unit : '${unit}s'}');
        }
    }
  }
  return (parts.join(' or '), concentration);
}

// ---------------------------------------------------------------------------
// Esyalar (mundane) + buyulu esyalar
// ---------------------------------------------------------------------------

List<Map<String, dynamic>> _items(
  Map<String, dynamic> data,
  String bookKey,
  List<String> sources,
  Map<String, List<Map<String, dynamic>>> split,
) {
  final plain = <Map<String, dynamic>>[];
  final magic = <Map<String, dynamic>>[];

  for (final i in [
    ..._rows(data, 'item', sources),
    ..._rows(data, 'baseitem', sources),
  ]) {
    final rarity = '${i['rarity'] ?? 'none'}'.toLowerCase();
    final isMagic =
        i['wondrous'] == true ||
        i['reqAttune'] != null ||
        (rarity != 'none' && rarity != 'unknown' && rarity != 'varies');
    final category = _itemCategory('${i['type'] ?? ''}');

    final row = <String, dynamic>{
      '_source': i['source'],
      'key': '${bookKey}_${_slug('${i['name']}')}',
      'name': i['name'],
      'document': bookKey,
      'desc': _text(i['entries']),
      'category': _named(category),
      'weapon': null,
      'armor': _armor(i),
      'size': null,
      'weight': i['weight'] == null
          ? null
          : (_num(i['weight']) ?? 0).toStringAsFixed(3),
      'weight_unit': i['weight'] == null ? null : 'lb',
      // SRD `cost` alani duz gp sayisi ("25.00"); 5etools bakir tutar.
      'cost': i['value'] == null
          ? null
          : ((_num(i['value']) ?? 0) / 100).toStringAsFixed(2),
      'crossreferences': const {'to': []},
    };

    if (!isMagic) {
      plain.add(row);
      continue;
    }
    magic.add({
      ...row,
      'rarity': {
        'name': _titleCase(rarity == 'none' ? 'unknown' : rarity),
        'key': _slug(rarity),
        'rank': _rarityRank(rarity),
      },
      'requires_attunement': i['reqAttune'] != null && i['reqAttune'] != false,
      'attunement_detail': i['reqAttune'] is String
          ? _markup('${i['reqAttune']}')
          : null,
    });
  }

  (split['magicitems'] ??= []).addAll(magic);
  return plain;
}

Map<String, dynamic>? _armor(Map<String, dynamic> item) {
  final ac = _int(item['ac']);
  if (ac == null) return null;
  final type = '${item['type'] ?? ''}'.split('|').first;
  final category = switch (type) {
    'LA' => 'light',
    'MA' => 'medium',
    'HA' => 'heavy',
    'S' => 'shield',
    _ => null,
  };
  if (category == null) return null;
  return {
    'name': item['name'],
    'key': _slug('${item['name']}'),
    'category': category,
    'ac_base': ac,
    'ac_display': null,
    'ac_add_dexmod': category == 'light' || category == 'medium',
    'ac_cap_dexmod': category == 'medium' ? 2 : null,
    'grants_stealth_disadvantage': item['stealth'] == true,
    'strength_score_required': _int(item['strength']),
  };
}

// ---------------------------------------------------------------------------
// Siniflar ve alt siniflar
// ---------------------------------------------------------------------------

List<Map<String, dynamic>> _classes(
  Map<String, dynamic> data,
  String bookKey,
  List<String> sources, {
  bool subclassesOnly = false,
  Map<String, Map<String, dynamic>> statBlocks = const {},
}) {
  final classFeatures = (data['classFeature'] as List? ?? const [])
      .whereType<Map<String, dynamic>>()
      .toList();
  final subclassFeatures = (data['subclassFeature'] as List? ?? const [])
      .whereType<Map<String, dynamic>>()
      .toList();

  final out = <Map<String, dynamic>>[];

  if (!subclassesOnly) {
    for (final c in _rows(data, 'class', sources)) {
      out.add(
        _baseClass(c, bookKey, classFeatures, subclassFeatures, statBlocks),
      );
    }
  }

  for (final s in _rows(data, 'subclass', sources)) {
    // 2014 govdesine bagli alt siniflar (classSource: PHB/TCE) 2024 kurallariyla
    // uyusmuyor; ayni alt sinifin modern basimi zaten ayri kayit olarak var.
    if (!_modernClassSources.contains('${s['classSource']}')) continue;
    out.add(_subclass(s, bookKey, subclassFeatures, classFeatures, statBlocks));
  }

  return out;
}

Map<String, dynamic> _baseClass(
  Map<String, dynamic> c,
  String bookKey,
  List<Map<String, dynamic>> allFeatures,
  List<Map<String, dynamic>> subclassFeatures,
  Map<String, Map<String, dynamic>> statBlocks,
) {
  final name = '${c['name']}';
  final slug = _slug(name);
  final die = 'D${_int(c['hd']?['faces']) ?? 8}';

  final features = <Map<String, dynamic>>[
    {
      'key': '${bookKey}_${slug}_core-traits',
      'name': 'Core $name Traits',
      'desc': _coreTraits(c),
      'feature_type': 'CORE_TRAITS_TABLE',
      'gained_at': const [],
      'data_for_class_table': const [],
    },
    {
      'key': '${bookKey}_${slug}_proficiency-bonus',
      'name': 'Proficiency Bonus',
      'desc': '[Column data]',
      'feature_type': 'PROFICIENCY_BONUS',
      'gained_at': const [],
      'data_for_class_table': [
        for (var level = 1; level <= 20; level++)
          {'level': level, 'column_value': '+${2 + (level - 1) ~/ 4}'},
      ],
    },
    ..._tableGroups(c, bookKey, slug),
    ..._withGrantedSpells(
      _classLevelFeatures(
        refs: c['classFeatures'],
        pool: subclassFeatures,
        classPool: allFeatures,
        bookKey: bookKey,
        keyPrefix: '${bookKey}_$slug',
        isSubclass: false,
        statBlocks: statBlocks,
      ),
      source: c,
      name: name,
      className: name,
      keyPrefix: '${bookKey}_$slug',
    ),
  ];

  return {
    '_source': c['source'],
    'key': '${bookKey}_$slug',
    'name': name,
    'document': bookKey,
    'desc': '',
    'subclass_of': null,
    'hit_dice': die,
    'hit_points': {
      'hit_dice': die,
      'hit_dice_name': '1$die per $name level',
      'hit_points_at_1st_level':
          '${_int(c['hd']?['faces']) ?? 8} + your Constitution modifier',
      'hit_points_at_higher_levels':
          '1$die (or ${((_int(c['hd']?['faces']) ?? 8) / 2).floor() + 1}) + '
          'your Constitution modifier per ${name.toLowerCase()} level after 1st',
    },
    'caster_type': _casterType('${c['casterProgression']}'),
    'saving_throws': [
      for (final a in (c['proficiency'] as List? ?? const []))
        {'name': _abilityName('$a')},
    ],
    'primary_abilities': [
      for (final entry in (c['primaryAbility'] as List? ?? const []))
        if (entry is Map)
          for (final e in entry.entries)
            if (e.value == true) {'name': _abilityName('${e.key}')},
    ],
    'features': features,
    'crossreferences': const {'to': []},
  };
}

Map<String, dynamic> _subclass(
  Map<String, dynamic> s,
  String bookKey,
  List<Map<String, dynamic>> allFeatures,
  List<Map<String, dynamic>> classFeatures,
  Map<String, Map<String, dynamic>> statBlocks,
) {
  final name = '${s['name']}';
  final slug = _slug(name);
  final className = '${s['className']}';
  final parentKey = _parentClassKey(className);

  final features = _withGrantedSpells(
    _classLevelFeatures(
      refs: s['subclassFeatures'],
      pool: allFeatures,
      classPool: classFeatures,
      bookKey: bookKey,
      keyPrefix: '${bookKey}_${_slug(className)}_$slug',
      isSubclass: true,
      statBlocks: statBlocks,
    ),
    source: s,
    name: name,
    className: className,
    keyPrefix: '${bookKey}_${_slug(className)}_$slug',
  );

  // Alt sinifin tanitim metni 5etools'ta alt sinifla AYNI ADI tasiyan
  // yetenegin govdesinde duruyor; SRD ise onu `desc` alaninda veriyor.
  // Seviye atlama onizlemesi ve kutuphane `desc`'i okudugu icin ikisini de
  // dolduruyoruz.
  final intro = features
      .where((f) => '${f['name']}'.toLowerCase() == name.toLowerCase())
      .firstOrNull;

  return {
    '_source': s['source'],
    'key': '${bookKey}_$slug',
    'name': name,
    'document': bookKey,
    'desc': '${intro?['desc'] ?? ''}',
    'subclass_of': {'key': parentKey, 'name': className},
    'hit_dice': null,
    'caster_type': 'NONE',
    'saving_throws': const [],
    'primary_abilities': const [],
    'features': features,
    'crossreferences': const {'to': []},
  };
}

/// Alt sinifi ana sinifina baglayan anahtar.
///
/// SRD siniflari `srd-2024_*`, SRD disi temel siniflar tanimlandiklari kitabin
/// anahtarini kullanir. Eslesme tutmazsa alt sinif listede bagimsiz bir sinif
/// gibi gorunur -- bu donusturucudeki en pahaliya patlayan hata buydu.
String _parentClassKey(String className) {
  final slug = _slug(className);
  if (_srdClasses.contains(slug)) return 'srd-2024_$slug';
  final known = _bookClasses[slug];
  if (known != null) return known;
  stderr.writeln(
    '  UYARI: "$className" temel sinifi taninmiyor; alt sinif baglanamadi.',
  );
  return 'srd-2024_$slug';
}

/// 5etools feature referanslarini ("Rage|Barbarian|XPHB|1") govde metniyle
/// eslestirir. Ayni isimli feature birden fazla seviyede kazanilabilir; hepsi
/// tek bir kayitta `gained_at` altinda toplanir.
///
/// Bir feature'in govdesi baska feature'lara `refSubclassFeature` /
/// `refClassFeature` ile isaret edebiliyor: 2024 alt siniflarinda ust seviye
/// girisi ("Path of the Wild Heart") kendi alt yeteneklerini boyle tasiyor.
/// Bu referanslar cozulmezse kagitta yeteneklerin yarisi eksik kaliyordu.
List<Map<String, dynamic>> _classLevelFeatures({
  required dynamic refs,
  required List<Map<String, dynamic>> pool,
  required List<Map<String, dynamic>> classPool,
  required String bookKey,
  required String keyPrefix,
  required bool isSubclass,
  Map<String, Map<String, dynamic>> statBlocks = const {},
}) {
  if (refs is! List) return const [];
  final byName = <String, Map<String, dynamic>>{};
  final seen = <String>{};

  final queue = <({String ref, bool isSubclass})>[
    for (final raw in refs)
      (
        ref: raw is Map
            ? '${raw['classFeature'] ?? raw['subclassFeature']}'
            : '$raw',
        isSubclass: isSubclass,
      ),
  ];

  while (queue.isNotEmpty) {
    final item = queue.removeAt(0);
    final ref = item.ref;
    final isSubclass = item.isSubclass;
    if (!seen.add('$ref|${isSubclass ? 's' : 'c'}')) continue;
    final parts = ref.split('|');
    // "Ad|Sinif|SinifKaynagi|Seviye|Kaynak" ya da alt siniflarda
    // "Ad|Sinif|SinifKaynagi|AltSinif|AltSinifKaynagi|Seviye|Kaynak".
    if (parts.length < (isSubclass ? 6 : 4)) continue;

    final name = parts[0];
    final className = parts[1];
    final classSource = parts[2].isNotEmpty ? parts[2] : 'PHB';
    final level = int.tryParse(parts[isSubclass ? 5 : 3]);
    if (level == null) continue;
    final subclassShort = isSubclass ? parts[3] : null;
    final subclassSource = isSubclass
        ? (parts[4].isNotEmpty ? parts[4] : classSource)
        : null;
    final sourceIndex = isSubclass ? 6 : 4;
    final featureSource =
        parts.length > sourceIndex && parts[sourceIndex].isNotEmpty
        ? parts[sourceIndex]
        : (isSubclass ? subclassSource! : classSource);

    final match = (isSubclass ? pool : classPool).firstWhere(
      (f) =>
          '${f['name']}'.toLowerCase() == name.toLowerCase() &&
          '${f['className']}' == className &&
          _int(f['level']) == level &&
          '${f['source']}' == featureSource &&
          (!isSubclass ||
              ('${f['subclassShortName']}' == subclassShort &&
                  '${f['subclassSource']}' == subclassSource)),
      orElse: () => <String, dynamic>{},
    );
    if (match.isEmpty) {
      stderr.writeln('  UYARI: feature govdesi bulunamadi: $ref');
      continue;
    }

    // Govdenin isaret ettigi alt yetenekler de kagida girer.
    queue.addAll(_nestedFeatureRefs(match['entries']));

    final existing = byName[name.toLowerCase()];
    if (existing != null) {
      (existing['gained_at'] as List).add({'level': level, 'detail': null});
      continue;
    }
    byName[name.toLowerCase()] = {
      'key': '${keyPrefix}_${_slug(name)}',
      'name': _markup(name),
      'desc': _withStatBlocks(_text(match['entries']), match, statBlocks),
      'feature_type': 'CLASS_LEVEL_FEATURE',
      'gained_at': [
        {'level': level, 'detail': null},
      ],
      'data_for_class_table': const [],
    };
  }

  return byName.values.toList();
}

/// Alt sinifin verdigi buyuleri, uygulamanin okudugu markdown tablosu olarak
/// feature listesine ekler.
///
/// 5etools bu bilgiyi metinde degil `additionalSpells` alaninda tutuyor;
/// SRD/PHB alt siniflarinin cogunda tablo zaten feature metninde var ama 17
/// alt sinifta yalnizca bu yapida. Tablo uretilmezse kagitta "alt sinifin
/// verdigi buyuler" hic gorunmuyor.
///
/// Yalnizca ADI BELLI buyuler yaziliyor; "Wizard listesinden iki buyu sec"
/// gibi secim gerektiren girisler atlanir (yanlis buyu eklemektense hic
/// eklememek yeglenir).
List<Map<String, dynamic>> _withGrantedSpells(
  List<Map<String, dynamic>> features, {
  required Map<String, dynamic> source,
  required String name,
  required String className,
  required String keyPrefix,
}) {
  if (features.any((f) => _hasSpellTable('${f['desc'] ?? ''}'))) {
    return features;
  }

  final byLevel = <int, List<String>>{};
  for (final block in (source['additionalSpells'] as List? ?? const [])) {
    if (block is! Map) continue;
    for (final entry in block.entries) {
      final tag = switch (entry.key) {
        'prepared' || 'known' || 'innate' => null,
        _ => 'skip',
      };
      if (tag == 'skip') continue;
      _collectGrantedSpells(entry.value, byLevel, null);
    }
  }
  if (byLevel.isEmpty) return features;

  final levels = byLevel.keys.toList()..sort();
  final table = [
    'Table: $name Spells',
    '| $className Level | Spells |',
    '|---|---|',
    for (final level in levels)
      '| $level | ${(byLevel[level]!..sort()).join(', ')} |',
  ].join('\n');

  return [
    ...features,
    {
      'key': '${keyPrefix}_spells',
      'name': '$name Spells',
      'desc':
          'When you reach a $className level specified in the $name Spells '
          'table, you thereafter always have the listed spells prepared.'
          '\n\n$table',
      'feature_type': 'CLASS_LEVEL_FEATURE',
      'gained_at': [
        {'level': levels.first, 'detail': null},
      ],
      'data_for_class_table': const [],
    },
  ];
}

/// Aciklamada zaten `<Sinif> Level | Spells` tablosu var mi?
bool _hasSpellTable(String desc) {
  for (final line in desc.split('\n')) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('|')) continue;
    final first = trimmed
        .split('|')
        .where((c) => c.trim().isNotEmpty)
        .firstOrNull;
    if (first != null && first.trim().toLowerCase().endsWith('level')) {
      return true;
    }
  }
  return false;
}

/// `additionalSpells` agacindaki adi belli buyuleri seviyeye gore toplar.
void _collectGrantedSpells(
  dynamic node,
  Map<int, List<String>> byLevel,
  int? level, {
  String? tag,
}) {
  if (node is String) {
    if (level == null) return;
    // "speak with animals|xphb#c" -> "Speak with Animals"
    final name = _titleCase(node.split('|').first.split('#').first.trim());
    final label = tag == null ? name : '$name ($tag)';
    final list = byLevel[level] ??= <String>[];
    if (!list.contains(label)) list.add(label);
    return;
  }
  if (node is List) {
    for (final item in node) {
      _collectGrantedSpells(item, byLevel, level, tag: tag);
    }
    return;
  }
  if (node is! Map) return;

  for (final entry in node.entries) {
    final key = '${entry.key}';
    // Secim gerektiren girisler ("choose"/"all"/"filter") atlanir.
    if (key == 'choose' || key == 'all' || key == 'filter') continue;

    final asLevel = int.tryParse(key);
    if (asLevel != null && level == null) {
      _collectGrantedSpells(entry.value, byLevel, asLevel, tag: tag);
      continue;
    }
    final nextTag = switch (key) {
      'ritual' => 'ritual',
      'daily' => '1/day',
      'rest' => '1/rest',
      'resource' => 'resource',
      'will' => 'at will',
      _ => tag,
    };
    _collectGrantedSpells(entry.value, byLevel, level, tag: nextTag);
  }
}

/// Ozelligin isaret ettigi stat bloklarini metnin sonuna tablo olarak ekler.
///
/// "Eldritch Cannon yarat" diyen bir yetenegi okurken topun ne oldugunu
/// gormek gerekiyor; kutuphanede ayri bir kayit olmasi yetmiyordu.
String _withStatBlocks(
  String desc,
  Map<String, dynamic> feature,
  Map<String, Map<String, dynamic>> statBlocks,
) {
  if (statBlocks.isEmpty) return desc;
  final raw = jsonEncode(feature['entries']);
  final names = <String>{};
  for (final match in RegExp(
    r'\{@(?:creature|object) ([^|}]+)\|',
  ).allMatches(raw)) {
    names.add(match.group(1)!.trim().toLowerCase());
  }
  if (names.isEmpty) return desc;

  final blocks = <String>[];
  for (final name in names) {
    final row = statBlocks[name];
    if (row != null) blocks.add(_statBlockText(row));
  }
  if (blocks.isEmpty) return desc;
  return [desc, ...blocks].where((s) => s.trim().isNotEmpty).join('\n\n');
}

/// Bir stat blogunu okunabilir markdown'a cevirir.
String _statBlockText(Map<String, dynamic> row) {
  final scores = (row['ability_scores'] as Map?)?.cast<String, dynamic>() ?? {};
  final mods = (row['modifiers'] as Map?)?.cast<String, dynamic>() ?? {};
  final defenses =
      (row['resistances_and_immunities'] as Map?)?.cast<String, dynamic>() ??
      const {};

  String senses() {
    final parts = <String>[
      for (final (label, key) in const [
        ('Darkvision', 'darkvision_range'),
        ('Blindsight', 'blindsight_range'),
        ('Tremorsense', 'tremorsense_range'),
        ('Truesight', 'truesight_range'),
      ])
        if ((_int(row[key]) ?? 0) > 0) '$label ${row[key]} ft.',
      'Passive Perception ${row['passive_perception'] ?? 10}',
    ];
    return parts.join(', ');
  }

  final summary = <(String, String)>[
    (
      'Type',
      [
        '${(row['size'] as Map?)?['name'] ?? ''}',
        '${(row['type'] as Map?)?['name'] ?? ''}',
      ].where((s) => s.isNotEmpty).join(' '),
    ),
    ('Armor Class', '${row['armor_detail'] ?? row['armor_class'] ?? '—'}'),
    (
      'Hit Points',
      '${row['hit_dice']}'.isNotEmpty
          ? '${row['hit_dice']}'
          : '${row['hit_points'] ?? '—'}',
    ),
    ('Speed', _speedText(row['speed'])),
    ('Senses', senses()),
    if ('${defenses['damage_immunities_display'] ?? ''}'.isNotEmpty)
      ('Immunities', '${defenses['damage_immunities_display']}'),
    if ('${defenses['damage_resistances_display'] ?? ''}'.isNotEmpty)
      ('Resistances', '${defenses['damage_resistances_display']}'),
    if ('${(row['languages'] as Map?)?['as_string'] ?? ''}'.isNotEmpty)
      ('Languages', '${(row['languages'] as Map?)?['as_string']}'),
  ];

  String scoreCell(String key) {
    final value = _int(scores[key]) ?? 10;
    final mod = _int(mods[key]) ?? _modifier(value);
    return '$value (${mod >= 0 ? '+' : ''}$mod)';
  }

  final entries = <String>[
    for (final t in (row['traits'] as List? ?? const []).whereType<Map>())
      '${t['name']}. ${t['desc']}',
    for (final a in (row['actions'] as List? ?? const []).whereType<Map>())
      '${a['name']}. ${a['desc']}',
  ];

  return [
    'Table: ${row['name']}',
    '| | |',
    '|---|---|',
    for (final (label, value) in summary)
      if (value.trim().isNotEmpty && value != '—') '|$label|$value|',
    '',
    '| STR | DEX | CON | INT | WIS | CHA |',
    '|---|---|---|---|---|---|',
    '| ${scoreCell('strength')} | ${scoreCell('dexterity')} | '
        '${scoreCell('constitution')} | ${scoreCell('intelligence')} | '
        '${scoreCell('wisdom')} | ${scoreCell('charisma')} |',
    if (entries.isNotEmpty) '',
    ...entries,
  ].join('\n');
}

/// Bir feature govdesindeki `refClassFeature` / `refSubclassFeature`
/// referanslarini toplar.
List<({String ref, bool isSubclass})> _nestedFeatureRefs(dynamic entries) {
  final out = <({String ref, bool isSubclass})>[];
  void walk(dynamic entry) {
    if (entry is List) {
      for (final e in entry) {
        walk(e);
      }
      return;
    }
    if (entry is! Map) return;
    switch ('${entry['type']}') {
      case 'refSubclassFeature':
        final ref = entry['subclassFeature'];
        if (ref is String) out.add((ref: ref, isSubclass: true));
      case 'refClassFeature':
        final ref = entry['classFeature'];
        if (ref is String) out.add((ref: ref, isSubclass: false));
      default:
        walk(entry['entries'] ?? entry['entry'] ?? entry['items']);
    }
  }

  walk(entries);
  return out;
}

/// Sinif tablosu sutunlari: buyu yuvalari `SPELL_SLOTS`, digerleri
/// `CLASS_TABLE_DATA`.
List<Map<String, dynamic>> _tableGroups(
  Map<String, dynamic> c,
  String bookKey,
  String slug,
) {
  final out = <Map<String, dynamic>>[];
  for (final group
      in (c['classTableGroups'] as List? ?? const []).whereType<Map>()) {
    final labels = (group['colLabels'] as List? ?? const [])
        .map((l) => _markup('$l'))
        .toList();
    final rows =
        (group['rowsSpellProgression'] ?? group['rows']) as List? ?? const [];
    final isSlots = group['rowsSpellProgression'] != null;

    for (var col = 0; col < labels.length; col++) {
      final columns = <Map<String, dynamic>>[];
      for (var level = 1; level <= rows.length; level++) {
        final row = rows[level - 1];
        if (row is! List || col >= row.length) continue;
        final value = row[col];
        final text = value is Map
            ? _markup('${value['value'] ?? ''}')
            : _markup('$value');
        if (text.isEmpty || text == '—' || (isSlots && text == '0')) continue;
        columns.add({'level': level, 'column_value': text});
      }
      if (columns.isEmpty) continue;
      out.add({
        'key': '${bookKey}_${slug}_${_slug(labels[col])}',
        'name': labels[col],
        'desc': '[Column data]',
        'feature_type': isSlots ? 'SPELL_SLOTS' : 'CLASS_TABLE_DATA',
        'gained_at': const [],
        'data_for_class_table': columns,
      });
    }
  }
  return out;
}

/// Karakter olusturma sihirbazi bu markdown tablosunu ayristiriyor
/// (`parseClassCoreTraits`); satir adlari birebir SRD'deki gibi olmali.
String _coreTraits(Map<String, dynamic> c) {
  final name = '${c['name']}';
  final prof = c['startingProficiencies'] as Map? ?? const {};
  final rows = <String, String>{};

  final primary = [
    for (final entry in (c['primaryAbility'] as List? ?? const []))
      if (entry is Map)
        for (final e in entry.entries)
          if (e.value == true) _abilityName('${e.key}'),
  ];
  if (primary.isNotEmpty) rows['Primary Ability'] = _joinAnd(primary);

  rows['Hit Point Die'] = 'D${_int(c['hd']?['faces']) ?? 8} per $name level';

  final saves = [
    for (final a in (c['proficiency'] as List? ?? const [])) _abilityName('$a'),
  ];
  if (saves.isNotEmpty) rows['Saving Throw Proficiencies'] = _joinAnd(saves);

  final skills = _skillChoice(prof['skills']);
  if (skills != null) rows['Skill Proficiencies'] = skills;

  final weapons = (prof['weapons'] as List? ?? const [])
      .map((w) => _titleCase(_markup('$w')))
      .toList();
  if (weapons.isNotEmpty) {
    rows['Weapon Proficiencies'] = '${_joinAnd(weapons)} weapons';
  }

  final tools = (prof['tools'] as List? ?? const [])
      .map((t) => _markup('$t'))
      .toList();
  if (tools.isNotEmpty) rows['Tool Proficiencies'] = _joinAnd(tools);

  final armor = (prof['armor'] as List? ?? const [])
      .map((a) => _titleCase(_markup('$a')))
      .toList();
  if (armor.isNotEmpty) {
    final shields = armor.remove('Shield') || armor.remove('Shields');
    rows['Armor Training'] = [
      if (armor.isNotEmpty) '${_joinAnd(armor)} armor',
      if (shields) 'Shields',
    ].join(' and ');
  }

  final equipment = _text(
    (c['startingEquipment'] as Map? ?? const {})['entries'],
  ).replaceAll('\n', ' ');
  if (equipment.isNotEmpty) rows['Starting Equipment'] = equipment;

  return [
    '|||',
    '|---|---|',
    for (final e in rows.entries) '|${e.key}|${e.value}|',
  ].join('\n');
}

String? _skillChoice(dynamic skills) {
  if (skills is! List || skills.isEmpty) return null;
  final entry = skills.first;
  if (entry is! Map) return null;
  final choose = entry['choose'];
  if (choose is Map) {
    final count = _int(choose['count']) ?? 1;
    final from = (choose['from'] as List? ?? const [])
        .map((s) => _titleCase('$s'))
        .toList();
    if (from.isEmpty) return 'Choose any $count skills';
    return 'Choose $count: ${_joinOr(from)}';
  }
  if (entry['any'] != null) return 'Choose any ${_int(entry['any'])} skills';
  return _joinAnd([for (final k in entry.keys) _titleCase('$k')]);
}

String _casterType(String progression) => switch (progression) {
  'full' => 'FULL',
  'half' || 'artificer' => 'HALF',
  '1/3' || 'third' => 'THIRD',
  'pact' => 'PACT',
  _ => 'NONE',
};

// ---------------------------------------------------------------------------
// Gecmisler (backgrounds)
// ---------------------------------------------------------------------------

List<Map<String, dynamic>> _backgrounds(
  Map<String, dynamic> data,
  String bookKey,
  List<String> sources,
) {
  final out = <Map<String, dynamic>>[];
  for (final b in _rows(data, 'background', sources)) {
    final benefits = <Map<String, dynamic>>[];

    void add(String type, String name, String? desc) {
      if (desc == null || desc.trim().isEmpty) return;
      benefits.add({'name': name, 'desc': desc.trim(), 'type': type});
    }

    add('ability_score', 'Ability Scores', _abilityChoices(b['ability']));
    add(
      'skill_proficiency',
      'Skill Proficiencies',
      _proficiencyNames(b['skillProficiencies']),
    );
    add(
      'tool_proficiency',
      'Tool Proficiency',
      _proficiencyNames(b['toolProficiencies']),
    );
    add('feat', 'Feat', _featName(b['feats']));
    add('equipment', 'Equipment', _startingEquipment(b['startingEquipment']));

    out.add({
      '_source': b['source'],
      'key': '${bookKey}_${_slug('${b['name']}')}',
      'name': b['name'],
      'document': bookKey,
      'desc': _text(b['entries'], skipHangingLists: true),
      'benefits': benefits,
      'crossreferences': const {'to': []},
    });
  }
  return out;
}

String? _abilityChoices(dynamic ability) {
  if (ability is! List) return null;
  final names = <String>[];
  for (final entry in ability.whereType<Map>()) {
    final choose = entry['choose'];
    final from = choose is Map
        ? (choose['weighted'] is Map
              ? (choose['weighted']['from'] as List? ?? const [])
              : (choose['from'] as List? ?? const []))
        : const [];
    for (final a in from) {
      final name = _abilityName('$a');
      if (!names.contains(name)) names.add(name);
    }
    for (final e in entry.entries) {
      if (e.key == 'choose') continue;
      final name = _abilityName('${e.key}');
      if (!names.contains(name)) names.add(name);
    }
  }
  return names.isEmpty ? null : names.join(', ');
}

String? _proficiencyNames(dynamic value) {
  if (value is! List) return null;
  final names = <String>[];
  for (final entry in value.whereType<Map>()) {
    for (final e in entry.entries) {
      if (e.value != true) continue;
      names.add(_titleCase('${e.key}'.split('|').first));
    }
  }
  return names.isEmpty ? null : _joinAnd(names);
}

String? _featName(dynamic feats) {
  if (feats is! List) return null;
  final names = <String>[];
  for (final entry in feats.whereType<Map>()) {
    for (final e in entry.entries) {
      if (e.value != true) continue;
      names.add(_titleCase('${e.key}'.split('|').first));
    }
  }
  return names.isEmpty ? null : _joinAnd(names);
}

/// "*Choose A or B:* (A) Dagger, ..., 38 GP; or (B) 50 GP"
///
/// Sihirbaz bu metni [parseEquipmentOptions] ile ayristiriyor; bicim SRD'deki
/// ile ayni olmak zorunda.
String? _startingEquipment(dynamic equipment) {
  if (equipment is! List || equipment.isEmpty) return null;
  final group = equipment.first;
  if (group is! Map) return null;

  final options = <String>[];
  for (final e in group.entries) {
    final items = e.value;
    if (items is! List) continue;
    final parts = <String>[];
    for (final item in items) {
      if (item is String) {
        parts.add(_titleCase(item.split('|').first));
      } else if (item is Map) {
        if (item['value'] != null) {
          parts.add('${((_num(item['value']) ?? 0) / 100).round()} GP');
        } else if (item['special'] != null) {
          parts.add(_titleCase('${item['special']}'.split('|').first));
        } else if (item['displayName'] != null) {
          parts.add('${item['displayName']}');
        } else if (item['item'] != null) {
          final name = _titleCase('${item['item']}'.split('|').first);
          final quantity = _int(item['quantity']) ?? 1;
          parts.add(quantity > 1 ? '$name ($quantity)' : name);
        }
      }
    }
    if (parts.isNotEmpty) options.add('(${e.key}) ${parts.join(', ')}');
  }
  if (options.isEmpty) return null;
  return '*Choose ${options.length == 2 ? 'A or B' : 'one'}:* '
      '${options.join('; or ')}';
}

// ---------------------------------------------------------------------------
// Turler (species)
// ---------------------------------------------------------------------------

List<Map<String, dynamic>> _species(
  Map<String, dynamic> data,
  String bookKey,
  List<String> sources,
) {
  final out = <Map<String, dynamic>>[];
  for (final r in _rows(data, 'race', sources)) {
    final traits = <Map<String, dynamic>>[];
    var order = 1;

    final creatureType = (r['creatureTypes'] as List? ?? const [])
        .map((t) => _titleCase('$t'))
        .join(', ');
    if (creatureType.isNotEmpty) {
      traits.add({
        'name': 'Creature Type',
        'desc': creatureType,
        'type': 'CREATURE_TYPE',
        'order': order++,
      });
    }

    final sizeEntry = r['sizeEntry'];
    traits.add({
      'name': 'Size',
      'desc': sizeEntry is Map
          ? _text(sizeEntry['entries'] ?? sizeEntry['entry'])
          : _sizeText(r['size']),
      'type': 'SIZE',
      'order': order++,
    });
    traits.add({
      'name': 'Speed',
      'desc': _speedText(r['speed']),
      'type': 'SPEED',
      'order': order++,
    });

    for (final t in (r['entries'] as List? ?? const []).whereType<Map>()) {
      final name = _markup('${t['name'] ?? ''}');
      if (name.isEmpty) continue;
      traits.add({
        'name': name,
        'desc': _text(t['entries'] ?? t['entry']),
        'type': null,
        'order': order++,
      });
    }

    out.add({
      '_source': r['source'],
      'key': '${bookKey}_${_slug('${r['name']}')}',
      'name': r['name'],
      'document': bookKey,
      'desc': '',
      'is_subspecies': false,
      'subspecies_of': null,
      'traits': traits,
      'crossreferences': const {'to': []},
    });
  }
  return out;
}

String _sizeText(dynamic size) {
  final names = (size is List ? size : [size])
      .map((s) => _size('$s'))
      .where((s) => s.isNotEmpty)
      .toList();
  return names.isEmpty ? 'Medium' : names.join(' or ');
}

String _speedText(dynamic speed) {
  if (speed is num) return '${speed.toInt()} feet';
  if (speed is Map) {
    final parts = <String>[];
    for (final e in speed.entries) {
      final value = e.value;
      if (value is num) {
        parts.add(
          e.key == 'walk'
              ? '${value.toInt()} feet'
              : '${e.key} ${value.toInt()} feet',
        );
      } else if (value == true) {
        parts.add('${e.key} equal to your walking speed');
      }
    }
    return parts.join(', ');
  }
  return '30 feet';
}

// ---------------------------------------------------------------------------
// Feat'ler
// ---------------------------------------------------------------------------

const _featCategories = <String, String>{
  'G': 'General',
  'O': 'Origin',
  'EB': 'Epic Boon',
  'FS': 'Fighting Style',
  'FS:P': 'Fighting Style',
  'FS:R': 'Fighting Style',
  'FS:M': 'Fighting Style',
  'D': 'Dragonmark',
  'DG': 'Dark Gift',
};

List<Map<String, dynamic>> _feats(
  Map<String, dynamic> data,
  String bookKey,
  List<String> sources,
) {
  final out = <Map<String, dynamic>>[];
  for (final f in _rows(data, 'feat', sources)) {
    final prerequisite = _prerequisite(f['prerequisite']);
    out.add({
      '_source': f['source'],
      'key': '${bookKey}_${_slug('${f['name']}')}',
      'name': f['name'],
      'document': bookKey,
      'desc': _text(f['entries']),
      'benefits': [
        for (final e in (f['entries'] as List? ?? const []).whereType<Map>())
          if ('${e['name'] ?? ''}'.isNotEmpty)
            {
              'name': _markup('${e['name']}'),
              'desc': _text(e['entries'] ?? e['entry']),
            },
      ],
      'prerequisite': prerequisite,
      'has_prerequisite': prerequisite.isNotEmpty,
      'type': _featCategories['${f['category']}'] ?? 'General',
      'crossreferences': const {'to': []},
    });
  }
  return out;
}

String _prerequisite(dynamic value) {
  if (value is String) return _markup(value);
  if (value is! List) return '';
  final parts = <String>[];
  for (final entry in value.whereType<Map>()) {
    for (final e in entry.entries) {
      switch (e.key) {
        case 'level':
          final level = e.value is Map ? _int(e.value['level']) : _int(e.value);
          if (level != null) parts.add('Level $level+');
        case 'campaign':
          parts.add('${_list(e.value)} campaign');
        case 'ability':
          for (final a in (e.value as List? ?? const []).whereType<Map>()) {
            for (final score in a.entries) {
              parts.add('${_abilityName('${score.key}')} ${score.value}+');
            }
          }
        case 'spellcasting':
        case 'spellcasting2020':
          parts.add('Spellcasting feature');
        case 'race':
          parts.add(
            (e.value as List? ?? const [])
                .map((r) => _titleCase('${r is Map ? r['name'] : r}'))
                .join(' or '),
          );
        case 'proficiency':
          for (final p in (e.value as List? ?? const []).whereType<Map>()) {
            parts.add(
              p.values.map((v) => '${_titleCase('$v')} proficiency').join(', '),
            );
          }
        case 'otherSummary':
          parts.add(_markup('${e.value is Map ? e.value['entry'] : e.value}'));
        case 'other':
          parts.add(_markup('${e.value}'));
        case 'exclusiveFeatCategory':
          break;
        default:
          break;
      }
    }
  }
  return parts.join(', ');
}

// ---------------------------------------------------------------------------
// Ortak yardimcilar
// ---------------------------------------------------------------------------

/// Kitaba ait satirlari secer ve `_source` etiketini korur.
List<Map<String, dynamic>> _rows(
  Map<String, dynamic> data,
  String arrayKey,
  List<String> sources,
) {
  final all = data[arrayKey] as List? ?? const [];
  final rows = all
      .whereType<Map<String, dynamic>>()
      .where((r) => sources.contains('${r['source']}'))
      .toList();

  // Yeni basimi elimizde OLAN eski kayitlari at. Elimizde yoksa eski basim
  // korunur: Ravenloft canavarlari yalnizca VRGR dosyasindan geliyor.
  final present = {for (final r in rows) _uid(r, arrayKey)};
  return rows.where((r) => !_superseded(r, present)).toList();
}

/// 5etools'un `reprintedAs` referanslariyla ayni bicimde kimlik uretir.
String _uid(Map<String, dynamic> row, String arrayKey) => switch (arrayKey) {
  'subclass' =>
    '${row['shortName'] ?? row['name']}|${row['className']}|'
        '${row['classSource']}|${row['source']}',
  _ => '${row['name']}|${row['source']}',
}.toLowerCase();

/// Ayni kitap setinde daha yeni bir basimi olan kaydi eler.
///
/// 5etools eski basimlari `reprintedAs: ["Undead|Warlock|XPHB|RHW"]` ile
/// isaretliyor. Ravenloft'ta VRGR (2021) ile RHW (2024) ayni alt siniflari
/// farkli adlarla tasiyor; bu eleme olmadan liste ikiz kayitlarla doluyor.
bool _superseded(Map<String, dynamic> row, Set<String> present) {
  for (final reprint in (row['reprintedAs'] as List? ?? const [])) {
    final target = reprint is Map ? '${reprint['uid'] ?? ''}' : '$reprint';
    if (present.contains(target.toLowerCase())) return true;
  }
  return false;
}

String _slug(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r"['’]"), '')
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

Map<String, String> _named(String name) => {'name': name, 'key': _slug(name)};

int? _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

num? _num(dynamic value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value.trim());
  return null;
}

int? _bonus(String value) =>
    int.tryParse(value.replaceAll('+', '').replaceAll(' ', ''));

int _modifier(int score) => ((score - 10) / 2).floor();

double _cr(dynamic cr) {
  final value = cr is Map ? cr['cr'] : cr;
  if (value is num) return value.toDouble();
  final text = '$value';
  if (text.contains('/')) {
    final parts = text.split('/');
    final a = double.tryParse(parts[0]) ?? 0;
    final b = double.tryParse(parts[1]) ?? 1;
    return b == 0 ? 0 : a / b;
  }
  return double.tryParse(text) ?? 0;
}

int _crProficiency(double cr) => cr <= 4 ? 2 : 2 + ((cr - 1) ~/ 4);

final _xpByCr = <double, int>{
  0: 10,
  0.125: 25,
  0.25: 50,
  0.5: 100,
  1: 200,
  2: 450,
  3: 700,
  4: 1100,
  5: 1800,
  6: 2300,
  7: 2900,
  8: 3900,
  9: 5000,
  10: 5900,
  11: 7200,
  12: 8400,
  13: 10000,
  14: 11500,
  15: 13000,
  16: 15000,
  17: 18000,
  18: 20000,
  19: 22000,
  20: 25000,
  21: 33000,
  22: 41000,
  23: 50000,
  24: 62000,
  25: 75000,
  26: 90000,
  27: 105000,
  28: 120000,
  29: 135000,
  30: 155000,
};

int _xpForCr(double cr) => _xpByCr[cr] ?? 0;

const _abilityNames = <String, String>{
  'str': 'Strength',
  'dex': 'Dexterity',
  'con': 'Constitution',
  'int': 'Intelligence',
  'wis': 'Wisdom',
  'cha': 'Charisma',
};

String _abilityName(String key) =>
    _abilityNames[key.toLowerCase()] ?? _titleCase(key);

String? _abilityKey(String key) {
  final name = _abilityNames[key.toLowerCase()];
  return name?.toLowerCase();
}

const _sizes = <String, String>{
  'T': 'Tiny',
  'S': 'Small',
  'M': 'Medium',
  'L': 'Large',
  'H': 'Huge',
  'G': 'Gargantuan',
};

String _size(dynamic size) {
  final value = size is List && size.isNotEmpty ? size.first : size;
  final text = '$value';
  return _sizes[text] ?? (text == 'null' ? 'Medium' : _titleCase(text));
}

String _creatureType(dynamic type) {
  if (type is Map) {
    final inner = type['type'];
    if (inner is Map) {
      final choices = inner['choose'];
      if (choices is List && choices.isNotEmpty) {
        return _titleCase('${choices.first}');
      }
    }
    return _titleCase('${inner ?? 'Humanoid'}');
  }
  return _titleCase('${type ?? 'Humanoid'}');
}

const _alignments = <String, String>{
  'L': 'lawful',
  'N': 'neutral',
  'C': 'chaotic',
  'G': 'good',
  'E': 'evil',
  'U': 'unaligned',
  'A': 'any alignment',
  'NX': 'neutral',
  'NY': 'neutral',
};

String _alignment(dynamic alignment) {
  if (alignment is String) return _alignments[alignment] ?? alignment;
  if (alignment is! List) return '';
  return alignment
      .map(
        (a) => a is Map ? '${a['alignment'] ?? ''}' : _alignments['$a'] ?? '$a',
      )
      .where((a) => a.isNotEmpty)
      .join(' ');
}

const _schools = <String, String>{
  'A': 'Abjuration',
  'C': 'Conjuration',
  'D': 'Divination',
  'E': 'Enchantment',
  'V': 'Evocation',
  'I': 'Illusion',
  'N': 'Necromancy',
  'T': 'Transmutation',
};

String _school(String code) => _schools[code] ?? _titleCase(code);

const _itemCategories = <String, String>{
  'HA': 'Heavy Armor',
  'LA': 'Light Armor',
  'MA': 'Medium Armor',
  'S': 'Shield',
  'M': 'Weapon',
  'R': 'Weapon',
  'A': 'Ammunition',
  'AF': 'Ammunition',
  'AT': "Artisan's Tools",
  'P': 'Potion',
  'SC': 'Scroll',
  'WD': 'Wand',
  'RG': 'Ring',
  'RD': 'Rod',
  'ST': 'Staff',
  'W': 'Wondrous item',
  'G': 'Adventuring Gear',
  'GS': 'Gaming Set',
  'INS': 'Instrument',
  'T': 'Tools',
  'TG': 'Trade Goods',
  'MNT': 'Mount',
  'VEH': 'Vehicle',
  'SHP': 'Vehicle',
  'AIR': 'Vehicle',
  'SPC': 'Vehicle',
  'EXP': 'Explosive',
  'FD': 'Food and Drink',
  'TAH': 'Tack and Harness',
  'OTH': 'Adventuring Gear',
  r'$': 'Treasure',
};

String _itemCategory(String type) =>
    _itemCategories[type.split('|').first] ?? 'Adventuring Gear';

int _rarityRank(String rarity) => switch (rarity) {
  'common' => 1,
  'uncommon' => 2,
  'rare' => 3,
  'very rare' => 4,
  'legendary' => 5,
  'artifact' => 6,
  _ => 0,
};

String _titleCase(String value) => value
    .split(RegExp(r'\s+'))
    .map(
      (w) => w.isEmpty
          ? w
          : (const {
                  'of',
                  'and',
                  'or',
                  'the',
                  'a',
                  'an',
                  'with',
                  'to',
                  'from',
                  'in',
                  'on',
                }.contains(w)
                ? w
                : '${w[0].toUpperCase()}${w.substring(1)}'),
    )
    .join(' ');

String _joinAnd(List<String> values) => switch (values.length) {
  0 => '',
  1 => values.single,
  2 => '${values[0]} and ${values[1]}',
  _ => '${values.sublist(0, values.length - 1).join(', ')}, and ${values.last}',
};

String _joinOr(List<String> values) => switch (values.length) {
  0 => '',
  1 => values.single,
  2 => '${values[0]} or ${values[1]}',
  _ => '${values.sublist(0, values.length - 1).join(', ')}, or ${values.last}',
};

String _ordinal(int n) => switch (n) {
  1 => '1st',
  2 => '2nd',
  3 => '3rd',
  _ => '${n}th',
};

String _list(dynamic value) {
  if (value == null) return '';
  if (value is List) return value.map((e) => _markup('$e')).join(', ');
  return _markup('$value');
}

// ---------------------------------------------------------------------------
// Metin: 5etools `entries` agaci -> duz metin
// ---------------------------------------------------------------------------

/// [skipHangingLists] gecmislerde kullaniliyor: oradaki "list-hang-notitle"
/// listesi `benefits` ile birebir ayni bilgiyi tasiyor, iki kez gostermiyoruz.
String _text(dynamic entries, {bool skipHangingLists = false}) {
  final parts = <String>[];
  _collect(entries, parts, skipHangingLists);
  return parts
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .join('\n\n')
      .trim();
}

void _collect(dynamic entry, List<String> out, bool skipHangingLists) {
  if (entry == null) return;
  if (entry is String) {
    out.add(_markup(entry));
    return;
  }
  if (entry is num || entry is bool) {
    out.add('$entry');
    return;
  }
  if (entry is List) {
    for (final e in entry) {
      _collect(e, out, skipHangingLists);
    }
    return;
  }
  if (entry is! Map) return;

  switch ('${entry['type']}') {
    case 'list':
      if (skipHangingLists && '${entry['style']}'.startsWith('list-hang')) {
        return;
      }
      for (final item in (entry['items'] as List? ?? const [])) {
        final lines = <String>[];
        _collect(item, lines, skipHangingLists);
        final text = lines.join(' ').trim();
        if (text.isNotEmpty) out.add('- $text');
      }
      return;

    case 'item':
    case 'itemSpell':
    case 'itemSub':
      final name = _markup('${entry['name'] ?? ''}').trim();
      final lines = <String>[];
      _collect(entry['entry'] ?? entry['entries'], lines, skipHangingLists);
      final body = lines.join(' ').trim();
      out.add(
        name.isEmpty
            ? body
            : '${name.endsWith(':') || name.endsWith('.') ? name : '$name.'} $body'
                  .trim(),
      );
      return;

    case 'table':
      out.add(_table(entry));
      return;

    case 'quote':
      final lines = <String>[];
      _collect(entry['entries'], lines, skipHangingLists);
      final by = entry['by'] == null ? '' : ' — ${_markup('${entry['by']}')}';
      out.add('${lines.join(' ')}$by');
      return;

    case 'refClassFeature':
    case 'refSubclassFeature':
    case 'refOptionalfeature':
    case 'image':
      return;

    default:
      final name = _markup('${entry['name'] ?? ''}').trim();
      final lines = <String>[];
      _collect(
        entry['entries'] ?? entry['entry'] ?? entry['items'],
        lines,
        skipHangingLists,
      );
      if (name.isEmpty) {
        out.addAll(lines);
        return;
      }
      if (lines.isEmpty) {
        out.add(name);
        return;
      }
      out.add('$name. ${lines.first}');
      out.addAll(lines.skip(1));
  }
}

/// SRD metinleri tablolari markdown olarak tasiyor; ayni bicimi uretiyoruz.
String _table(Map entry) {
  final caption = _markup('${entry['caption'] ?? ''}').trim();
  final labels = (entry['colLabels'] as List? ?? const [])
      .map((l) => _markup('$l'))
      .toList();
  final rows = <String>[];
  for (final row in (entry['rows'] as List? ?? const [])) {
    if (row is! List) continue;
    final cells = row.map((c) {
      final lines = <String>[];
      _collect(c, lines, false);
      return lines.join(' ').replaceAll('\n', ' ').trim();
    }).toList();
    rows.add('| ${cells.join(' | ')} |');
  }
  return [
    if (caption.isNotEmpty) 'Table: $caption',
    if (labels.isNotEmpty) '| ${labels.join(' | ')} |',
    if (labels.isNotEmpty) '|${List.filled(labels.length, '---').join('|')}|',
    ...rows,
  ].join('\n');
}

/// `{@spell Fireball|XPHB}` gibi 5etools isaretlemesini duz metne cevirir.
///
/// Bu adim atlanirsa metinler kullaniciya ham etiketlerle gorunuyor.
String _markup(String input) {
  if (!input.contains('{@')) return input;
  final out = StringBuffer();
  var i = 0;
  while (i < input.length) {
    final start = input.indexOf('{@', i);
    if (start < 0) {
      out.write(input.substring(i));
      break;
    }
    out.write(input.substring(i, start));

    var depth = 0;
    var end = -1;
    for (var j = start; j < input.length; j++) {
      if (input[j] == '{') depth++;
      if (input[j] == '}') {
        depth--;
        if (depth == 0) {
          end = j;
          break;
        }
      }
    }
    if (end < 0) {
      out.write(input.substring(start));
      break;
    }
    out.write(_renderTag(input.substring(start + 2, end)));
    i = end + 1;
  }
  return out.toString();
}

String _renderTag(String body) {
  final space = body.indexOf(' ');
  final tag = space < 0 ? body : body.substring(0, space);
  final rest = space < 0 ? '' : body.substring(space + 1);
  final parts = _splitArguments(rest).map(_markup).toList();
  String part(int index) => index < parts.length ? parts[index].trim() : '';

  switch (tag) {
    case 'h':
      return 'Hit: ';
    case 'hitYourSpellAttack':
      return 'your spell attack modifier';
    case 'dcYourSpellSave':
      return 'your spell save DC';
    case 'hom':
      return '';
    case 'actSaveFail':
      return 'Failure:';
    case 'actSaveSuccess':
      return 'Success:';
    case 'actSaveSuccessOrFail':
      return 'Failure or Success:';
    case 'actTrigger':
      return 'Trigger:';
    case 'actResponse':
      return 'Response:';
    case 'actSave':
      return '${_abilityName(part(0))} Saving Throw:';
    case 'hit':
      final value = _int(part(0));
      return value == null ? part(0) : '${value >= 0 ? '+' : ''}$value';
    case 'dc':
      return 'DC ${part(0)}';
    case 'chance':
      return '${part(0)} percent';
    case 'recharge':
      final from = part(0);
      return from.isEmpty ? '(Recharge 6)' : '(Recharge $from-6)';
    case 'atk':
      return _attackKind(part(0), roll: false);
    case 'atkr':
      return _attackKind(part(0), roll: true);
    case 'dice':
    case 'damage':
    case 'autodice':
    case 'd20':
      return part(1).isNotEmpty ? part(1) : part(0);
    case 'scaledice':
    case 'scaledamage':
      return part(2).isNotEmpty ? part(2) : part(0);
    case 'filter':
    case 'footnote':
    case 'link':
    case '5etools':
    case '5etoolsImg':
    case 'book':
    case 'adventure':
    case 'classFeature':
    case 'subclassFeature':
    case 'b':
    case 'bold':
    case 'i':
    case 'italic':
    case 'u':
    case 'underline':
    case 's':
    case 'strike':
    case 'note':
    case 'highlight':
    case 'color':
    case 'tip':
      return part(0);
    case 'quickref':
      return part(3).isNotEmpty ? part(3) : part(0);
    default:
      // {@spell Fireball|XPHB|fire ball} -> ucuncu parca gosterim metnidir.
      return part(2).isNotEmpty ? part(2) : part(0);
  }
}

/// Etiket argumanlarini `|` ile ayirir; IC ICE etiketlerin kendi `|`
/// karakterleri sayilmaz.
///
/// `{@note ... {@subclassFeature Ad|Sinif|Kaynak|...} ...}` gibi yapilarda duz
/// `split('|')` govdeyi ortadan kesip ham etiketi metne sizdiriyordu.
List<String> _splitArguments(String value) {
  final parts = <String>[];
  final buffer = StringBuffer();
  var depth = 0;
  for (var i = 0; i < value.length; i++) {
    final char = value[i];
    if (char == '{') depth++;
    if (char == '}') depth--;
    if (char == '|' && depth == 0) {
      parts.add(buffer.toString());
      buffer.clear();
      continue;
    }
    buffer.write(char);
  }
  parts.add(buffer.toString());
  return parts;
}

String _attackKind(String code, {required bool roll}) {
  final suffix = roll ? 'Attack Roll:' : 'Attack:';
  return switch (code.replaceAll(' ', '')) {
    'mw' => 'Melee Weapon $suffix',
    'rw' => 'Ranged Weapon $suffix',
    'ms' => 'Melee Spell $suffix',
    'rs' => 'Ranged Spell $suffix',
    'm' => 'Melee $suffix',
    'r' => 'Ranged $suffix',
    'm,r' || 'mw,rw' => 'Melee or Ranged $suffix',
    _ => suffix,
  };
}

String? _argValue(List<String> args, String name) {
  for (final a in args) {
    if (a.startsWith('$name=')) return a.substring(name.length + 1);
  }
  return null;
}
