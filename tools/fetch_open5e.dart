// Open5e v2 API'sinden acik lisansli kural icerigini indirip
// `assets/data/*.json.gz` olarak yazar. Build-time aracidir, uygulamaya
// derlenmez; ciktisini surum kontrolune alip herkesin ayni veriyi
// kullanmasini sagliyoruz.
//
// Kullanim:
//   dart run tools/fetch_open5e.dart
//   dart run tools/fetch_open5e.dart --docs=srd-2024,tob,ccdx
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

Future<void> main(List<String> args) async {
  final docs = _argValue(args, '--docs')?.split(',') ?? const ['srd-2024'];
  final onlySrd = docs.length == 1 && docs.single == 'srd-2024';

  stdout.writeln('Dokumanlar: ${docs.join(", ")}');
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
        rows.addAll(
          await _fetchAll(client, endpoint, {'document__key__iexact': doc}),
        );
      }
      _validate(endpoint, rows.length, onlySrd: onlySrd);
      if (onlySrd) {
        rows.replaceRange(0, rows.length, _mergeEndpoint(rows, endpoint));
      }
      await _write(endpoint, rows);
      (manifest['endpoints'] as Map<String, int>)[endpoint] = rows.length;
    }

    for (final endpoint in _globalReference) {
      final rows = await _fetchAll(client, endpoint, const {});
      await _write(endpoint, rows);
      (manifest['endpoints'] as Map<String, int>)[endpoint] = rows.length;
    }

    // Lisans metinleri ve yayinci bilgisi: CC-BY atif zorunlulugu icin
    // uygulamanin lisans ekraninda gosterilir.
    final documents = await _fetchAll(client, 'documents', const {});
    await _write(
      'documents',
      documents.where((d) => docs.contains(d['key'])).toList(),
    );

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
  final phbFile = File('$_outDir/spells_phb.json');
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
) {
  // Spells ve creatures ozel islem gerektirir.
  if (endpoint == 'spells') return _mergePhbSpells(srd);
  if (endpoint == 'creatures') return _mergeExtraCreatures(srd);

  // Geriye kalan kategoriler icin genel birlestirme (isim bazli dedup).
  const extras = {
    'items': 'items_extra.json',
    'magicitems': 'magicitems_extra.json',
    'backgrounds': 'backgrounds_extra.json',
    'feats': 'feats_extra.json',
    'species': 'species_extra.json',
  };
  final name = extras[endpoint];
  if (name == null) return srd;
  final file = File('$_outDir/$name');
  if (!file.existsSync()) {
    stderr.writeln('UYARI: $name bulunamadi; extra birlestirme atlandi.');
    return srd;
  }
  final extra = (jsonDecode(file.readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();
  final byName = <String>{
    for (final s in srd) (s['name'] as String).toLowerCase(),
  };
  final result = [...srd];
  for (final e in extra) {
    final n = (e['name'] as String).toLowerCase();
    if (!byName.contains(n)) {
      result.add(e);
      byName.add(n);
    }
  }
  return result;
}

/// API'den gelen SRD canavarlarina `creatures_mm.json` icindeki ek
/// kayitlari ekler. Bu dosya iki tur icerik tasir:
///   * `mm-2024_*` — SRD'de olmayan 2024 Monster Manual canavarlari;
///   * `srd-2024_beholder`/`srd-2024_flind` — open5e API'nin artik donmedigi
///     ancak uygulamada bulunmasi gereken SRD kayitlari.
/// Ayni isimdeki SRD kaydi korunur; ek dosya yalnizca ismi gz'de olmayan
/// kayitlari getirir.
List<Map<String, dynamic>> _mergeExtraCreatures(
  List<Map<String, dynamic>> srd,
) {
  final file = File('$_outDir/creatures_mm.json');
  if (!file.existsSync()) return srd;
  final extra = (jsonDecode(file.readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();
  final byName = <String>{
    for (final s in srd) (s['name'] as String).toLowerCase(),
  };
  return [
    ...srd,
    for (final e in extra)
      if (!byName.contains((e['name'] as String).toLowerCase())) e,
  ];
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
