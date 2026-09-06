// Open5e v2 API'sinden acik lisansli kural icerigini indirip
// `assets/data/*.json.gz` olarak yazar. Build-time aracidir, uygulamaya
// derlenmez; ciktisini surum kontrolune alip herkesin ayni veriyi
// kullanmasini sagliyoruz.
//
// Kullanim:
//   dart run tools/fetch_open5e.dart
//   dart run tools/fetch_open5e.dart --docs=srd-2024,tob,ccdx
//   dart run tools/fetch_open5e.dart --offline --docs=srd-2024,eberron-forge
//     (API'ye gitmez; mevcut paketleri `tools/content_sources` ile yeniden
//      karistirir. Elle bakilan dosyalari degistirdikten sonra bunu kullanin.)
//
// ONEMLI: Dokuman filtresi olarak `document__key__iexact` kullaniyoruz.
// `document__key` bazi uc noktalarda (items, magicitems) sessizce YOK SAYILIR
// ve filtrelenmemis tum katalogu dondurur; bu da SRD'ye ait olmayan iceriğin
// pakete sizmasina yol acar. Bkz. asagidaki `_expectedMinimums` dogrulamasi.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _apiRoot = 'https://api.open5e.com/v2';
const _outDir = 'assets/data';

/// Elle saglanan ek icerik dosyalari (`*_extra.json`, `spells_phb.json`,
/// `creatures_mm.json`). `assets/data` DISINDA duruyorlar: o klasorun tamami
/// uygulamaya ve oyuncu paneline paketlendigi icin, yalnizca bu aracin okudugu
/// ~4 MB'lik ham JSON her iki pakete de bosuna giriyordu.
const _srcDir = 'tools/content_sources';

/// Belge bazli filtrelenen uc noktalar: her biri secilen dokuman(lar)a ait
/// kayitlari getirir.
const _documentScoped = <String>[
  'creatures',
  'spells',
  'items',
  'magicitems',
  'classes',
  'backgrounds',
  'species',
  'feats',
  'weaponproperties',
  'skills',
];

/// Dokumandan bagimsiz, kucuk referans tablolari. Bunlar `document` alanina
/// gore filtrelenemez (filtre 0 kayit dondurur), bu yuzden tamami cekilir.
const _globalReference = <String>[
  'conditions',
  'damagetypes',
  'spellschools',
  'sizes',
  'alignments',
  'creaturetypes',
  'itemrarities',
  'itemcategories',
  'environments',
  'languages',
  'abilities',
];

/// Yalnizca `srd-2024` cekildiginde beklenen en az kayit sayilari.
/// Bir uc nokta bunun altina duserse API sozlesmesi degismis demektir ve
/// sessizce eksik veri paketlemektense hata verip durmayi tercih ediyoruz.
const _expectedMinimums = <String, int>{
  'creatures': 331,
  'spells': 339,
  'items': 203,
  'magicitems': 757,
  'classes': 24,
  'backgrounds': 4,
  'species': 9,
  'feats': 17,
};

/// Yeni kaynak kitaplarin belge anahtarlari (API'de yok, dosyadan gelir).
const _newBookKeys = ['eberron-forge', 'ravenloft-horrors', 'faerun-heroes'];
Future<void> main(List<String> args) async {
  final docs = _argValue(args, '--docs')?.split(',') ?? const ['srd-2024'];
  final onlySrd = docs.length == 1 && docs.single == 'srd-2024';

  // `--offline`: API'ye hic gidilmez, paketlerdeki mevcut `srd-2024` satirlari
  // taban alinip `tools/content_sources` yeniden karistirilir. Elle bakilan
  // dosyalar degistiginde (yeni kitap, duzeltilmis donusturucu) tum katalogu
  // yeniden indirmeye gerek kalmiyor.
  final offline = args.contains('--offline');

  stdout.writeln(
    'Dokumanlar: ${docs.join(", ")}${offline ? ' (offline)' : ''}',
  );
  Directory(_outDir).createSync(recursive: true);

  final client = http.Client();
  final manifest = <String, dynamic>{
    'fetchedAt': DateTime.now().toUtc().toIso8601String(),
    'source': _apiRoot,
    'documents': docs,
    'endpoints': <String, int>{},
  };

  try {
    for (final endpoint in _documentScoped) {
      final rows = <Map<String, dynamic>>[];
      for (final doc in docs) {
        if (doc == 'srd-2024') {
          rows.addAll(
            offline
                ? _apiPortionOf(_readBundled(endpoint))
                : await _fetchAll(client, endpoint, {
                    'document__key__iexact': doc,
                  }),
          );
        }
        // phb-2024/mm-2024/yeni kitaplar API'de yok, dosyadan gelir
      }
      // Minimum dogrulama sadece srd-2024 icin. Offline modda taban zaten
      // birlestirilmis pakettir (ayni isimli SRD kayitlari 2024 surumleriyle
      // degistirilmis olur), sayilar API sozlesmesini yansitmaz.
      if (docs.contains('srd-2024') && !offline) {
        final srdOnly = rows.where((r) => r['document'] == 'srd-2024').length;
        _validate(endpoint, srdOnly, onlySrd: onlySrd);
      }
      // Merge: SRD + phb-2024/mm-2024 extra + yeni kitaplar
      rows.replaceRange(0, rows.length, _mergeEndpoint(rows, endpoint, docs));
      if (endpoint == 'feats') _normalizeFeats(rows);
      _sanitizeMarkup(rows, endpoint);
      _applyDescOverrides(rows, endpoint);
      await _write(endpoint, rows);
      (manifest['endpoints'] as Map<String, int>)[endpoint] = rows.length;
    }

    for (final endpoint in _globalReference) {
      // Referans tablolari elle duzenlenmiyor; offline modda oldugu gibi kalir.
      final rows = offline
          ? _readBundled(endpoint)
          : await _fetchAll(client, endpoint, const {});
      if (!offline) await _write(endpoint, rows);
      (manifest['endpoints'] as Map<String, int>)[endpoint] = rows.length;
    }

    // Lisans metinleri ve yayinci bilgisi: CC-BY atif zorunlulugu icin
    // uygulamanin lisans ekraninda gosterilir.
    if (!offline) {
      final documents = await _fetchAll(client, 'documents', const {});
      await _write(
        'documents',
        documents.where((d) => docs.contains(d['key'])).toList(),
      );
    }

    // Sinif secenekleri (Eldritch Invocation, Metamagic, Maneuver...) API'de
    // yok; donusturucunun yazdigi dosya oldugu gibi paketleniyor.
    final optional = File('$_srcDir/optionalfeatures.json');
    if (optional.existsSync()) {
      final rows = (jsonDecode(optional.readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();
      await _write('optionalfeatures', rows);
      (manifest['endpoints'] as Map<String, int>)['optionalfeatures'] =
          rows.length;
    }

    File(
      '$_outDir/manifest.json',
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(manifest));
    stdout.writeln('\nBitti. manifest.json yazildi.');
  } finally {
    client.close();
  }
}

/// `next` baglantisini takip ederek uc noktanin tamamini toplar.
Future<List<Map<String, dynamic>>> _fetchAll(
  http.Client client,
  String endpoint,
  Map<String, String> query,
) async {
  var url = Uri.parse(
    '$_apiRoot/$endpoint/',
  ).replace(queryParameters: {...query, 'limit': '100'});

  final results = <Map<String, dynamic>>[];
  var page = 0;
  while (true) {
    final response = await client.get(
      url,
      headers: {'Accept': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw HttpException('$url -> HTTP ${response.statusCode}');
    }
    final body =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    for (final row in (body['results'] as List).cast<Map<String, dynamic>>()) {
      results.add(_slim(row));
    }
    page++;
    stdout.write('\r  $endpoint: ${results.length} kayit (sayfa $page)   ');

    final next = body['next'] as String?;
    if (next == null) break;
    url = Uri.parse(next);
  }
  stdout.writeln();
  return results;
}

/// Her kayitta tekrar eden sisman `document` nesnesini anahtarina indirger.
/// 331 canavarda ayni yayinci/oyun sistemi blogu tekrar ettigi icin bu tek
/// basina ciktinin buyuk bolumunu kirpiyor.
Map<String, dynamic> _slim(Map<String, dynamic> row) {
  final doc = row['document'];
  if (doc is Map<String, dynamic> && doc['key'] != null) {
    return {...row, 'document': doc['key']};
  }
  return row;
}

void _validate(String endpoint, int count, {required bool onlySrd}) {
  if (!onlySrd) return;
  final min = _expectedMinimums[endpoint];
  if (min == null) return;
  if (count < min) {
    throw StateError(
      '$endpoint: $count kayit geldi, en az $min bekleniyordu. '
      'Dokuman filtresi yok sayilmis ya da API degismis olabilir.',
    );
  }
  if (endpoint == 'magicitems' && count > 1500) {
    throw StateError(
      'magicitems: $count kayit — filtre uygulanmamis gorunuyor '
      '(srd-2024 icin 757 bekleniyor).',
    );
  }
}

/// API'den gelen SRD buyulerini `spells_phb.json` (2024 PHB) kayitlariyla
/// birlestirir. Ayni isimli SRD kaydi 2024 surumuyle degistirilir; boylece
/// fetch tekrar calistirildiginda PHB eklemesi kaybolmaz.
List<Map<String, dynamic>> _mergePhbSpells(List<Map<String, dynamic>> srd) {
  final phbFile = File('$_srcDir/spells_phb.json');
  if (!phbFile.existsSync()) {
    throw StateError('spells_phb.json bulunamadi: $phbFile');
  }
  final phb = (jsonDecode(phbFile.readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();
  String keyOf(Map<String, dynamic> s) => (s['name'] as String).toLowerCase();

  final merged = <Map<String, dynamic>>[];
  for (final s in srd) {
    if (!phb.any((p) => keyOf(p) == keyOf(s))) merged.add(s);
  }
  for (final p in phb) {
    final row = {...p};
    row['document'] ??= 'phb-2024';
    final classes = row['classes'];
    if (classes is List) {
      for (final c in classes) {
        if (c is Map && c['key'] is String) {
          final k = c['key'] as String;
          if (k.startsWith('phb-2024_')) {
            c['key'] = 'srd-2024_${k.substring('phb-2024_'.length)}';
          }
        }
      }
    }
    merged.add(row);
  }
  return merged;
}

/// Endpoint'e gore dogru extra dosyayi birlestirir.
///
/// Spells: ozel normalizasyon gerekir (document + class key rewrite) =>
/// [_mergePhbSpells] kullanilir. Digerleri basit isim bazli birlestirme.
List<Map<String, dynamic>> _mergeEndpoint(
  List<Map<String, dynamic>> srd,
  String endpoint,
  List<String> docs,
) {
  // Spells ve creatures ozel islem gerektirir.
  if (endpoint == 'spells') {
    var merged = _mergePhbSpells(srd);
    merged = _mergeExtraByName(merged, endpoint, docs);
    return _applySpellClassLists(merged);
  }
  if (endpoint == 'creatures') {
    var merged = _mergeExtraCreatures(srd);
    merged = _mergeExtraByName(merged, endpoint, docs);
    return merged;
  }
  if (endpoint == 'classes') {
    var merged = _mergeClasses(srd);
    merged = _mergeExtraByName(merged, endpoint, docs);
    return merged;
  }

  // Geriye kalan kategoriler icin genel birlestirme (isim bazli dedup).
  // Bir uc noktaya birden fazla ek dosya beslenebilir; sirasiyla ve isim
  // bazli dedup ile ekleniyorlar.
  const extras = {
    'items': ['items_extra.json', 'items_phb.json'],
    'magicitems': ['magicitems_extra.json', 'magicitems_phb.json'],
    'backgrounds': ['backgrounds_extra.json'],
    'feats': ['feats_extra.json'],
    'species': ['species_extra.json'],
  };
  var merged = [...srd];
  final byName = <String>{
    for (final s in srd) (s['name'] as String).toLowerCase(),
  };
  for (final name in extras[endpoint] ?? const <String>[]) {
    final file = File('$_srcDir/$name');
    if (!file.existsSync()) {
      stderr.writeln('UYARI: $name bulunamadi; extra birlestirme atlandi.');
      continue;
    }
    final extra = (jsonDecode(file.readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();
    for (final e in extra) {
      if (byName.add((e['name'] as String).toLowerCase())) merged.add(e);
    }
  }

  // Yeni kaynak kitaplari (isim bazli dedup, document alani korunur)
  return _mergeExtraByName(merged, endpoint, docs);
}

/// API'den gelen sinif kayitlarini `classes_phb.json` ile birlestirir.
///
/// Dosya, SRD'de bulunmayan alt siniflari getiriyor. Isim bazli basit bir
/// dedup YETMIYOR: SRD'de de bulunan bir alt sinifin (Life Domain, Evoker...)
/// dosyadaki surumu, API kaydinda olmayan yetenekler tasiyabiliyor -- ornegin
/// alt sinifin verdigi buyulerin tablosu. Bu yuzden ayni isimli kayitlarda
/// SATIR degil YETENEK bazinda birlestirme yapiyoruz: API kaydi korunur,
/// yalnizca adi orada olmayan yetenekler eklenir.
List<Map<String, dynamic>> _mergeClasses(List<Map<String, dynamic>> srd) {
  final file = File('$_srcDir/classes_phb.json');
  if (!file.existsSync()) {
    stderr.writeln(
      'UYARI: classes_phb.json bulunamadi; PHB alt siniflari yok.',
    );
    return srd;
  }
  final extra = (jsonDecode(file.readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();

  final byName = <String, Map<String, dynamic>>{
    for (final row in srd) (row['name'] as String).toLowerCase(): row,
  };
  final merged = [...srd];
  var addedRows = 0;
  var addedFeatures = 0;

  for (final row in extra) {
    final current = byName[(row['name'] as String).toLowerCase()];
    if (current == null) {
      merged.add(row);
      byName[(row['name'] as String).toLowerCase()] = row;
      addedRows++;
      continue;
    }

    final features = (current['features'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .toList();
    final known = {
      for (final f in features) '${f['name']}'.toLowerCase().trim(),
    };
    for (final f
        in (row['features'] as List? ?? const [])
            .cast<Map<String, dynamic>>()) {
      if (f['feature_type'] != 'CLASS_LEVEL_FEATURE') continue;
      if (!known.add('${f['name']}'.toLowerCase().trim())) continue;
      features.add(f);
      addedFeatures++;
    }
    current['features'] = features;
  }

  stdout.writeln(
    '  classes_phb.json: $addedRows alt sinif, '
    '$addedFeatures ek yetenek birlestirildi',
  );
  return merged;
}

/// Yeni kaynak kitap dosyalarini isim-bazli birlestirir.
/// Dosya adi: `{endpoint}_{bookKey}.json` (or. `spells_eberron-forge.json`)
List<Map<String, dynamic>> _mergeExtraByName(
  List<Map<String, dynamic>> current,
  String endpoint,
  List<String> docs,
) {
  var result = [...current];
  final byName = <String>{
    for (final s in current) (s['name'] as String).toLowerCase(),
  };

  for (final book in _newBookKeys) {
    if (!docs.contains(book)) continue;
    final file = File('$_srcDir/${endpoint}_$book.json');
    if (!file.existsSync()) continue;

    final extra = (jsonDecode(file.readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();

    for (final e in extra) {
      final n = (e['name'] as String).toLowerCase();
      if (!byName.contains(n)) {
        // document alanini koru (zaten convert_5etools.dart koymus olmali)
        result.add(e);
        byName.add(n);
      }
    }
  }
  return result;
}

/// Kitap siniflarinin buyu listesini buyulerin `classes` alanina isler.
///
/// open5e her buyuye yalnizca SRD'nin 8 buyucu sinifini yaziyor; Artificer
/// gibi kitap siniflari hicbir buyunun listesinde gorunmedigi icin oyuncunun
/// buyu secim ekrani bos aciliyordu. Esleme `spell_classes.json` dosyasinda
/// (5etools `data/spells/sources.json` cevirisi) duruyor.
List<Map<String, dynamic>> _applySpellClassLists(
  List<Map<String, dynamic>> spells,
) {
  final file = File('$_srcDir/spell_classes.json');
  if (!file.existsSync()) return spells;

  final lists = (jsonDecode(file.readAsStringSync()) as Map)
      .cast<String, dynamic>();
  // Buyu adi -> eklenecek sinif anahtarlari.
  final byName = <String, List<String>>{};
  for (final entry in lists.entries) {
    for (final name in (entry.value as List).cast<String>()) {
      (byName[name.toLowerCase()] ??= []).add(entry.key);
    }
  }

  var added = 0;
  for (final spell in spells) {
    final keys = byName[(spell['name'] as String).toLowerCase()];
    if (keys == null) continue;
    final classes = (spell['classes'] as List? ?? const []).toList();
    final existing = {
      for (final c in classes)
        if (c is Map) '${c['key']}',
    };
    for (final key in keys) {
      if (existing.contains(key)) continue;
      classes.add({'name': _classNameOf(key), 'key': key});
      added++;
    }
    spell['classes'] = classes;
  }
  stdout.writeln('  spell_classes.json: $added buyu-sinif bagi eklendi');
  return spells;
}

/// "eberron-forge_artificer" -> "Artificer".
String _classNameOf(String classKey) => classKey
    .split('_')
    .last
    .split('-')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

/// API'den gelen SRD canavarlarina elle bakilan dosyalari ekler:
///   * `creatures_mm.json` — SRD'de olmayan 2024 Monster Manual canavarlari,
///     ayrica open5e API'nin artik donmedigi `beholder`/`flind`;
///   * `creatures_phb.json` — 2024 PHB'nin yoldas/cagri stat bloklari
///     (Beast of the Land, Draconic Spirit...). Sinif ve buyu metinleri
///     bunlara isim vererek atifta bulunuyor; kutuphanede karsiligi olmayinca
///     "hangi stat blogu?" diye kaliniyordu.
/// Ayni isimdeki SRD kaydi korunur; dosyalar yalnizca yeni isimleri getirir.
List<Map<String, dynamic>> _mergeExtraCreatures(
  List<Map<String, dynamic>> srd,
) {
  final merged = [...srd];
  final byName = <String>{
    for (final s in srd) (s['name'] as String).toLowerCase(),
  };

  for (final name in const ['creatures_mm.json', 'creatures_phb.json']) {
    final file = File('$_srcDir/$name');
    if (!file.existsSync()) continue;
    final extra = (jsonDecode(file.readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();
    for (final e in extra) {
      final key = (e['name'] as String).toLowerCase();
      if (byName.add(key)) merged.add(e);
    }
  }
  return merged;
}

/// Pakette API'den gelmis olan kismi ayirir.
///
/// Dosyadan gelen belgeler (`phb-2024`, `mm-2024`, kaynak kitaplar) atilir;
/// geri kalan her sey korunur. `document` alanina bakip yalnizca `srd-2024`
/// birakmak YETMEZ: `skills` gibi uc noktalar `core`/`a5e-ag` belgeleriyle
/// donuyor ve o satirlar da API tarafindan uretiliyor.
List<Map<String, dynamic>> _apiPortionOf(List<Map<String, dynamic>> rows) {
  const fileBacked = {'phb-2024', 'mm-2024', ..._newBookKeys};
  return rows.where((r) => !fileBacked.contains(r['document'])).toList();
}

/// Feat kategorisinin ve onkosulunun 5etools bicimini SRD bicimine cevirir.
///
/// SRD kayitlari `type: "General"`, `prerequisite: "Level 4+, Strength or
/// Dexterity 13+"` seklinde DUZ METIN geliyor; donusturulen 2024 PHB kayitlari
/// ise `type: "G"` ve `prerequisite: [{"level": 4, "ability": [{"str": 13}]}]`
/// -- yani ham 5etools nesnesi. Bu iki sekil uygulamada iki ayri hataya yol
/// aciyordu:
///
/// - Kutuphanede feat paneli `prerequisite`'i `String?` diye okudugu icin 54
///   kayit acilinca tip hatasi verip GRI kutu olarak ciziliyordu.
/// - Seviye atlama ekrani `type == 'General'` diye suzdugu icin `G` etiketli
///   41 feat ve `EB` etiketli 5 Epic Boon hic listelenmiyordu.
///
/// Duzeltmenin yeri arayuz degil veri: tek sekil olunca hem panel hem seviye
/// atlama hem de ceviri dosyasi ayni metni gorur.
const _featTypeNames = <String, String>{
  'G': 'General',
  'O': 'Origin',
  'EB': 'Epic Boon',
  'FS': 'Fighting Style',
  // Yalnizca Paladin/Ranger'in alabildigi savas stilleri. Kategori ayni;
  // hangi sinifa ait oldugu zaten onkosul metninde yaziyor.
  'FS:P': 'Fighting Style',
  'FS:R': 'Fighting Style',
};

const _abilityNames = <String, String>{
  'str': 'Strength',
  'dex': 'Dexterity',
  'con': 'Constitution',
  'int': 'Intelligence',
  'wis': 'Wisdom',
  'cha': 'Charisma',
};

void _normalizeFeats(List<Map<String, dynamic>> rows) {
  var types = 0;
  var prerequisites = 0;
  for (final row in rows) {
    final type = _featTypeNames['${row['type']}'];
    if (type != null) {
      row['type'] = type;
      types++;
    }
    final prerequisite = row['prerequisite'];
    if (prerequisite is List) {
      row['prerequisite'] = _prerequisiteText(prerequisite);
      prerequisites++;
    }
  }
  if (types > 0 || prerequisites > 0) {
    stdout.writeln(
      '  feat normalizasyonu: $types kategori, $prerequisites onkosul',
    );
  }
}

/// 5etools onkosul nesnelerini SRD'nin cumlesine cevirir.
String _prerequisiteText(List<dynamic> entries) {
  final maps = entries.whereType<Map>().toList();
  if (maps.isEmpty) return '';

  // Cok girisli liste SECENEK demek: Athlete "Strength 13+" ya da
  // "Dexterity 13+" ister. Girisler yalnizca yetenekte ayrisiyorsa SRD
  // bunlari tek cumlede birlestiriyor ("Strength or Dexterity 13+"), yoksa
  // secenekler "or" ile yan yana yazilir.
  final onlyLevelAndAbility = maps.every(
    (m) => m.keys.every((k) => k == 'level' || k == 'ability'),
  );
  final levels = maps.map((m) => m['level']).toSet();
  if (onlyLevelAndAbility && levels.length == 1) {
    final abilities = <String>[];
    int? score;
    for (final m in maps) {
      for (final a in (m['ability'] as List? ?? const []).whereType<Map>()) {
        for (final e in a.entries) {
          final name = _abilityNames['${e.key}'] ?? '${e.key}';
          if (!abilities.contains(name)) abilities.add(name);
          if (e.value is int) score = e.value as int;
        }
      }
    }
    return [
      if (levels.single is int) 'Level ${levels.single}+',
      if (abilities.isNotEmpty) '${_orList(abilities)} $score+',
    ].join(', ');
  }
  return maps.map(_prerequisiteEntry).where((s) => s.isNotEmpty).join(' or ');
}

/// SRD'nin yazimi: "Strength or Dexterity", "Intelligence, Wisdom, or Charisma".
String _orList(List<String> items) {
  if (items.length <= 2) return items.join(' or ');
  return '${items.sublist(0, items.length - 1).join(', ')}, or ${items.last}';
}

String _prerequisiteEntry(Map<dynamic, dynamic> entry) {
  final parts = <String>[];
  if (entry['level'] case final int level) parts.add('Level $level+');

  final abilities = <String>[];
  int? score;
  for (final a in (entry['ability'] as List? ?? const []).whereType<Map>()) {
    for (final e in a.entries) {
      abilities.add(_abilityNames['${e.key}'] ?? '${e.key}');
      if (e.value is int) score = e.value as int;
    }
  }
  if (abilities.isNotEmpty) parts.add('${_orList(abilities)} $score+');

  for (final p
      in (entry['proficiency'] as List? ?? const []).whereType<Map>()) {
    if (p['armor'] case final String armor) {
      parts.add(
        armor == 'shield'
            ? 'Shield Training'
            : '${armor[0].toUpperCase()}${armor.substring(1)} Armor Training',
      );
    }
  }

  // `spellcasting2020`: "bir buyu kullanma ozelligin olmali".
  if (entry['spellcasting2020'] == true) parts.add('Spellcasting Feature');

  for (final f in (entry['feature'] as List? ?? const []).whereType<String>()) {
    parts.add('$f Feature');
  }

  // Serbest metinli onkosul ("When Gaining the Level 2 Paladin ... Feature").
  if (entry['otherSummary'] case final Map other) {
    if (other['entry'] case final String text) parts.add(text);
  }
  return parts.join(', ');
}

/// 5etools donusturucusunden sizan isaretleme artiklarini temizler.
///
/// `{@variantrule Sphere [Area of Effect]|XPHB|Sphere}` gibi etiketlerde
/// suslu parantezler soyulmus ama boru isaretli parcalar metinde kalmis:
/// oyuncu "20-foot-radius Sphere [Area of Effect]|XPHB|Sphere centered on..."
/// okuyordu. 5etools kuralinda GOSTERILECEK metin son parcadir.
///
/// Kalip tablosu bilerek DAR: genel bir "boru isaretlerini kirp" regex'i
/// markdown tablolarini (`| Level | PB |`) parcalar.
const _markupFixes = <String, String>{
  'Sphere [Area of Effect]|XPHB|Sphere': 'Sphere',
  'Cube [Area of Effect]|XPHB|Cube': 'Cube',
  'Cylinder [Area of Effect]|XPHB|Cylinder': 'Cylinder',
  'Line [Area of Effect]|XPHB|Line': 'Line',
  'Cone [Area of Effect]|XPHB|Cone': 'Cone',
  'Emanation [Area of Effect]|XPHB|Emanation': 'Emanation',
  'Cover|XPHB|Total Cover': 'Total Cover',
  'Short Rest|XPHB|Short': 'Short',
  // Iki ayri "Cover" baglantisi ayni kelimeye indirgenmis: Sharpshooter ve
  // Spell Sniper "ignore Cover and Cover" diyordu.
  'ignore Cover and Cover': 'ignore Half Cover and Three-Quarters Cover',
  // Durum/aksiyon adlari cumlenin dilbilgisini bozacak sekilde yapistirilmis.
  'a creature that is Concentration':
      'a creature that is concentrating on a spell',
  'Advantage on Death Saving Throw.': 'Advantage on Death Saving Throws.',
  'Opportunity Attack have Disadvantage':
      'Opportunity Attacks have Disadvantage',
  'add 3, rather than 2 to your AC': 'add 3, rather than 2, to your AC',
  'drop to 1 Hit Points instead': 'drop to 1 Hit Point instead',
};

/// `{#itemEntry Ioun Stone|XDMG}` -- 5etools'un "ust kaydin metnini buraya
/// kopyala" yonergesi. Donusum sirasinda cozulmedigi icin aciklamanin basinda
/// duruyordu; bazi kayitlarda ACIKLAMANIN TAMAMI buydu (Dragon Scale Mail,
/// Potion of Resistance...). Silinip yerine gercek metin
/// `desc_overrides.json` ile veriliyor.
final _itemEntryDirective = RegExp(r'\{#\w+[^}]*\}\s*');

/// 5etools'un ayirt edici son eki: `Cone [Area of Effect]`, `Friendly
/// [Attitude]`. Baglanti kurmak icin var, okunacak metnin parcasi degil.
final _disambiguationSuffix = RegExp(r' \[(?:Area of Effect|Attitude)\]');

/// Foundry surumunden sizan baglanti isaretlemesi:
/// `@UUID[...]{Dancing Lights}` -> `Dancing Lights`, `@Embed[...]` -> silinir.
final _foundryLink = RegExp(r'@UUID\[[^\]]*\]\{([^}]*)\}');
final _foundryEmbed = RegExp(r'@(?:Embed|UUID)\[[^\]]*\]');
final _foundryReference = RegExp(r'&Reference\[([^\]]*)\]');

/// Donusturucu "DC" kelimesini dusuruyor: "makes a 15 Wisdom saving throw".
/// Zorluk sinifi olmadan kural uygulanamaz.
final _missingDc = RegExp(
  r'\ban? (\d{1,2}) '
  r'(Strength|Dexterity|Constitution|Intelligence|Wisdom|Charisma) '
  r'(saving throw|check)',
);

/// Birlestirme sirasinda olusan cift bosluk ("Handaxe  attack"). Markdown
/// tablolarina dokunmaz: oradaki ayirac ` | `.
final _doubleSpace = RegExp(r'(?<=[a-z,.)])  (?=[a-zA-Z])');

/// Yapistirma sirasinda kaybolan cumle araligi: "obeyed.The sword's...".
final _missingSentenceSpace = RegExp(r'(?<=[a-z])\.(?=[A-Z][a-z])');

/// Silah ozelliklerinin acilmamis kisaltmalari: "the LD property of the Hand
/// Crossbow" okuyan biri hangi ozellikten bahsedildigini bilemez.
final _abbreviatedProperties = <RegExp, String>{
  RegExp(r'\bLD property\b'): 'Loading property',
  RegExp(r'\b2H property\b'): 'Two-Handed property',
  RegExp(r'\bL property\b'): 'Light property',
  RegExp(r'\bH property\b'): 'Heavy property',
  RegExp(r'\bT property\b'): 'Thrown property',
  RegExp(r'\bF property\b'): 'Finesse property',
  RegExp(r'\bV property\b'): 'Versatile property',
};

/// "a Wisdom (Insight) check ... (8 plus your Charisma modifier and
/// Proficiency)" -- kesilmis "Proficiency Bonus".
final _bareProficiency = RegExp(
  r'\b(your|and) Proficiency\b(?! Bonus)(?=[\s.,)])',
);

/// Cozulmemis 5etools etiketi. Kalirsa veri sessizce bozuk gider, bu yuzden
/// uyariyoruz.
final _leftoverTag = RegExp(
  r'\{@\w+[^}]*\}|\|X(?:PHB|DMG|MM)\||@UUID\[|@Embed\[|&Reference\[',
);

/// Tablonun SONUNDAKI bos satiri atar (`|||`).
///
/// Donusturucu bazi tablolara bos bir kapanis satiri ekliyor ve bu, ekranda
/// bos bir tablo hucresi olarak ciziliyor. Tablonun BASINDAKI ayni satir
/// bilerek duruyor: "bu tablonun basligi yok" demek, cekirdek ozellik
/// tablolari o bicimde geliyor.
String _dropTrailingEmptyTableRows(String value) {
  if (!value.contains('|')) return value;
  final lines = value.split('\n');
  bool isRow(int i) =>
      i >= 0 && i < lines.length && lines[i].trim().startsWith('|');
  bool isEmptyRow(int i) =>
      isRow(i) && lines[i].trim().split('|').every((c) => c.trim().isEmpty);

  var changed = false;
  for (var i = lines.length - 1; i >= 0; i--) {
    // Bos satir yalnizca bir tablo blogunun SON satiriysa atilir: ayni satir
    // blogun BASINDA "bu tablonun basligi yok" demek ve cekirdek ozellik
    // tablolari o bicimde geliyor.
    if (isEmptyRow(i) && isRow(i - 1) && !isRow(i + 1)) {
      lines.removeAt(i);
      changed = true;
    }
  }
  return changed ? lines.join('\n') : value;
}

void _sanitizeMarkup(List<Map<String, dynamic>> rows, String endpoint) {
  var cleaned = 0;
  var leftover = 0;

  String fix(String value) {
    var out = value;
    for (final entry in _markupFixes.entries) {
      out = out.replaceAll(entry.key, entry.value);
    }
    out = out
        .replaceAll(_itemEntryDirective, '')
        .replaceAll(_disambiguationSuffix, '')
        .replaceAllMapped(_foundryLink, (m) => m[1]!)
        .replaceAll(_foundryEmbed, '')
        .replaceAllMapped(_foundryReference, (m) => m[1]!)
        .replaceAllMapped(_missingDc, (m) => 'a DC ${m[1]} ${m[2]} ${m[3]}')
        .replaceAll(_doubleSpace, ' ')
        .replaceAll(_missingSentenceSpace, '. ')
        .replaceAllMapped(_bareProficiency, (m) => '${m[1]} Proficiency Bonus');
    for (final e in _abbreviatedProperties.entries) {
      out = out.replaceAll(e.key, e.value);
    }
    out = _dropTrailingEmptyTableRows(out);
    if (out != value) cleaned++;
    if (_leftoverTag.hasMatch(out)) leftover++;
    return out.trim();
  }

  Object? walk(Object? node) => switch (node) {
    final String s => fix(s),
    final List<dynamic> l => [for (final v in l) walk(v)],
    final Map<String, dynamic> m => {
      for (final e in m.entries) e.key: walk(e.value),
    },
    _ => node,
  };

  for (var i = 0; i < rows.length; i++) {
    rows[i] = walk(rows[i])! as Map<String, dynamic>;
  }
  if (cleaned > 0) stdout.writeln('  temizlenen metin: $cleaned ($endpoint)');
  if (leftover > 0) {
    stderr.writeln(
      'UYARI: $endpoint icinde $leftover cozulmemis 5etools etiketi kaldi; '
      '_markupFixes tablosuna eklenmeli.',
    );
  }
}

/// Elle yazilan aciklamalari kayitlarin uzerine yazar.
///
/// Kaynak veride bir suru kaydin `desc` alani BOS: butun turler, siniflar ve
/// gecmislerin cogu tanitim metni olmadan geliyor, [_sanitizeMarkup] sonrasi
/// da bazi buyulu esyalarin aciklamasi tamamen bosaliyor. Isim bazli
/// [_mergeEndpoint] birlestirmesi bunu duzeltemez -- o yalnizca YENI kayit
/// ekler, mevcut kaydin alanina dokunmaz -- bu yuzden ayri bir yama adimi var.
void _applyDescOverrides(List<Map<String, dynamic>> rows, String endpoint) {
  final file = File('$_srcDir/desc_overrides.json');
  if (!file.existsSync()) return;
  final all = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final patches = all[endpoint];
  if (patches is! Map) return;

  final byKey = {
    for (final row in rows)
      if (row['key'] is String) row['key'] as String: row,
  };
  var applied = 0;
  for (final entry in patches.entries) {
    if ('${entry.key}'.startsWith('_')) continue; // dosya ici notlar
    final row = byKey['${entry.key}'];
    if (row == null) {
      stderr.writeln(
        'UYARI: desc_overrides.json -> $endpoint -> ${entry.key} '
        'boyle bir kayit yok (ad degismis olabilir).',
      );
      continue;
    }
    // Kisayol: cogu yama yalnizca `desc` yazdigi icin duz metin de kabul
    // ediliyor. Birden fazla alan gerekince map yazilir.
    final patch = entry.value;
    if (patch is String) {
      row['desc'] = patch;
    } else if (patch is Map) {
      for (final field in patch.entries) {
        final name = '${field.key}';
        if (name.startsWith('_')) continue;
        final existing = row[name];
        final value = field.value;
        // `traits`/`features` gibi diziler: nesne verilirse TEK TEK yama
        // (anahtar ya da ada gore), liste verilirse tamami degistirilir.
        if (existing is List && value is Map) {
          _patchList(existing, value, '$endpoint/${entry.key}/$name');
        } else {
          row[name] = value;
        }
      }
    } else {
      stderr.writeln(
        'UYARI: desc_overrides.json -> $endpoint -> ${entry.key} '
        'metin ya da nesne olmali.',
      );
      continue;
    }
    applied++;
  }
  if (applied > 0) stdout.writeln('  aciklama yamasi: $applied ($endpoint)');
}

/// Dizinin alt kayitlarini `key` ya da `name` ile bulup yamalar.
void _patchList(
  List<dynamic> list,
  Map<dynamic, dynamic> patches,
  String where,
) {
  for (final entry in patches.entries) {
    final id = '${entry.key}';
    if (id.startsWith('_')) continue;
    final target = list.whereType<Map<String, dynamic>>().where(
      (e) => e['key'] == id || e['name'] == id,
    );
    if (target.isEmpty) {
      stderr.writeln('UYARI: desc_overrides.json -> $where -> $id bulunamadi.');
      continue;
    }
    for (final row in target) {
      for (final field in (entry.value as Map).entries) {
        if ('${field.key}'.startsWith('_')) continue;
        row['${field.key}'] = field.value;
      }
    }
  }
}

/// `--offline` icin: paketlenmis `assets/data/{name}.json.gz` dosyasini okur.
List<Map<String, dynamic>> _readBundled(String name) {
  final file = File('$_outDir/$name.json.gz');
  if (!file.existsSync()) {
    throw StateError(
      '$name.json.gz yok; --offline yalnizca mevcut paketlerin uzerine calisir.',
    );
  }
  final json = utf8.decode(gzip.decode(file.readAsBytesSync()));
  return (jsonDecode(json) as List).cast<Map<String, dynamic>>();
}

Future<void> _write(String name, List<Map<String, dynamic>> rows) async {
  final bytes = gzip.encode(utf8.encode(jsonEncode(rows)));
  File('$_outDir/$name.json.gz').writeAsBytesSync(bytes);
  final kb = (bytes.length / 1024).toStringAsFixed(0);
  stdout.writeln('  -> $name.json.gz (${rows.length} kayit, $kb KB)');
}

String? _argValue(List<String> args, String name) {
  for (final a in args) {
    if (a.startsWith('$name=')) return a.substring(name.length + 1);
  }
  return null;
}
