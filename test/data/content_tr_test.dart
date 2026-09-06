import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `assets/data/tr/*.json` ile paketlenmis Ingilizce veri arasindaki
/// tutarliligi dogrular.
///
/// Ceviri, gosterim aninda ad esleslemesiyle uygulaniyor
/// ([lib/data/content_tr.dart]). Veri yeniden uretildiginde bir ozellik ya da
/// kayit adi degisirse ceviri SESSIZCE dusup Ingilizce metin gorunur; bu test
/// o sessiz kaybi hataya cevirir.
void main() {
  /// `desc` -> kaydin kendi aciklamasi, `bolum/Ad` -> alt kaydin aciklamasi.
  const sections = <String, List<String>>{
    'species': ['traits'],
    'backgrounds': ['benefits'],
    'classes': ['features'],
    'creatures': ['traits', 'actions'],
    'items': [],
    'magicitems': [],
    'feats': ['benefits'],
    'spells': [],
    'optionalfeatures': [],
  };

  /// `feats` faydalarinin cogunun adi yok; sirayla numaralaniyorlar.
  const indexedSections = <String, Set<String>>{
    'feats': {'benefits'},
  };

  /// `desc` disinda cevrilen UST DUZEY duz metin alanlari. Buyu karti
  /// "Ust Seviye Buyu Yuvasiyla" paragrafini ayri bir alandan okuyor
  /// (bkz. `SpellDetail`), bu yuzden `bolum/Ad` kalibina uymuyor.
  const scalarFields = <String, Set<String>>{
    'spells': {'higher_level'},
  };

  List<Map<String, dynamic>> bundle(String kind) {
    final bytes = File('assets/data/$kind.json.gz').readAsBytesSync();
    return (jsonDecode(utf8.decode(gzip.decode(bytes))) as List)
        .cast<Map<String, dynamic>>();
  }

  Map<String, dynamic> translations(String kind) =>
      jsonDecode(File('assets/data/tr/${kind}_tr.json').readAsStringSync())
          as Map<String, dynamic>;

  for (final entry in sections.entries) {
    final kind = entry.key;
    final sectionNames = entry.value;

    test('$kind cevirisi paketteki kayitlarla eslesir', () {
      final rows = {
        for (final row in bundle(kind))
          if (row['key'] is String) row['key'] as String: row,
      };
      final tr = translations(kind);

      expect(
        tr['_comment'],
        isA<String>(),
        reason: '$kind: dosyanin ne oldugunu anlatan _comment bekleniyor',
      );

      final problems = <String>[];
      for (final e in tr.entries) {
        if (e.key.startsWith('_')) continue;
        final row = rows[e.key];
        if (row == null) {
          problems.add('${e.key}: pakette boyle bir kayit yok');
          continue;
        }
        for (final path in (e.value as Map).keys) {
          if (path == 'desc') continue;
          if (scalarFields[kind]?.contains(path) ?? false) {
            // Ingilizce kayitta o alan hic yoksa ceviri sessizce dusecekti.
            if ('${row[path] ?? ''}'.trim().isEmpty) {
              problems.add('${e.key} -> $path: pakette bu alan bos');
            }
            continue;
          }
          // Yol yalnizca ILK bolu isaretinden ayrilir: alt kayit adinin kendisi
          // bolu icerebiliyor ("Legendary Resistance (3/Day, or 4/Day in Lair)")
          // ve [ContentTr.field] zaten tam dizeyle arama yapiyor.
          final slash = '$path'.indexOf('/');
          final parts = slash < 0
              ? <String>['$path']
              : <String>[
                  '$path'.substring(0, slash),
                  '$path'.substring(slash + 1),
                ];
          if (parts.length != 2 || !sectionNames.contains(parts.first)) {
            problems.add('${e.key} -> $path: taninmayan yol');
            continue;
          }
          // `creatures` icin `actions` yolu iki listeyi birden kapsar: mm-2024
          // efsanevi eylemleri UST DUZEY `legendary_actions[]` dizisinde geliyor
          // ve [StatBlock] onlari da `actions/Ad` anahtariyla ariyor.
          final list = <Map<String, dynamic>>[
            ...(row[parts.first] as List? ?? const [])
                .whereType<Map<String, dynamic>>(),
            if (kind == 'creatures' && parts.first == 'actions')
              ...(row['legendary_actions'] as List? ?? const [])
                  .whereType<Map<String, dynamic>>(),
          ];
          final indexed = indexedSections[kind]?.contains(parts.first) ?? false;
          final found = indexed
              ? (int.tryParse(parts[1]) ?? -1) < list.length
              : list.any((x) => x['name'] == parts[1]);
          if (!found) {
            problems.add('${e.key} -> $path: pakette boyle bir alt kayit yok');
          }
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  }

  test('canavarlarin butun ozellik ve eylemleri cevrilmis', () {
    // Stat blok bastan sona cevrildi. Yarim cevrilmis bir blok, oyuncuya
    // Turkce ozelliklerin arasinda Ingilizce bir eylem gosterirdi.
    final tr = translations('creatures');
    final missing = <String>[];
    for (final row in bundle('creatures')) {
      final entry = tr[row['key']] as Map<String, dynamic>? ?? const {};
      for (final section in ['traits', 'actions', 'legendary_actions']) {
        for (final sub
            in (row[section] as List? ?? const [])
                .cast<Map<String, dynamic>>()) {
          if ('${sub['desc'] ?? ''}'.trim().isEmpty) continue;
          // Efsanevi eylemler de `actions/Ad` anahtariyla araniyor.
          final path = section == 'traits' ? 'traits' : 'actions';
          if (!entry.containsKey('$path/${sub['name']}')) {
            missing.add('${row['key']} -> $path/${sub['name']}');
          }
        }
      }
    }
    expect(missing, isEmpty, reason: missing.take(15).join('\n'));
  });

  test('canavar ozellik adlarinin tamami cevrilmis', () {
    // Ad sozlugu KAYITTAN BAGIMSIZ: ayni ad ("Bite") yuzlerce canavarda
    // geciyor. Pakete yeni bir ad geldiginde stat blok basligi sessizce
    // Ingilizce kalirdi; bu test onu yakalar.
    final tr =
        jsonDecode(
              File('assets/data/tr/creature_names_tr.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final missing = <String>{};
    for (final row in bundle('creatures')) {
      for (final section in [
        'traits',
        'actions',
        'legendary_actions',
        'bonus_actions',
        'reactions',
      ]) {
        for (final sub
            in (row[section] as List? ?? const [])
                .whereType<Map<String, dynamic>>()) {
          final name = '${sub['name'] ?? ''}';
          if (name.isEmpty || tr.containsKey(name)) continue;
          missing.add(name);
        }
      }
    }
    expect(missing, isEmpty, reason: missing.take(15).join('\n'));
  });

  test('terim sozlugu stat blogun butun alanlarini kapsar', () {
    // `glossary_tr.json` calisma aninda stat blok ALAN degerlerini ceviriyor.
    // Bir bolum adi degisirse ceviri sessizce dusup Ingilizce gorunur.
    final glossary =
        jsonDecode(File('assets/data/tr/glossary_tr.json').readAsStringSync())
            as Map<String, dynamic>;
    for (final section in [
      'damage',
      'conditions',
      'creatureTypes',
      'sizes',
      'skills',
      'abilities',
      'abilityAbbr',
      'speeds',
      'senses',
      'alignments',
      'languages',
    ]) {
      expect(
        glossary[section],
        isA<Map<String, dynamic>>(),
        reason: 'glossary_tr.json: $section bolumu yok',
      );
    }
    // Anahtarlar KUCUK HARF olmali: [GlossaryTr.term] aramayi kucuk harfe
    // indirgeyerek yapiyor, buyuk harfli anahtar hic bulunamazdi.
    final wrongCase = <String>[];
    for (final section in glossary.entries) {
      if (section.value is! Map) continue;
      for (final key in (section.value as Map).keys) {
        if ('$key' != '$key'.toLowerCase()) {
          wrongCase.add('${section.key}/$key');
        }
      }
    }
    expect(wrongCase, isEmpty, reason: wrongCase.join(', '));
  });

  test('buyu ve feat alan degerlerinin tamami sozlukte', () {
    // Bu alanlar SERBEST METIN ama kapali bir sozcuk dagarcigindan geliyor;
    // sozluk tam deger eslesmesiyle ceviriyor. Veri yeniden uretildiginde yeni
    // bir deger cikarsa buyu karti sessizce Ingilizce gosterirdi.
    final glossary =
        jsonDecode(File('assets/data/tr/glossary_tr.json').readAsStringSync())
            as Map<String, dynamic>;
    final missing = <String>{};
    void check(String kind, String field, String section) {
      final known = (glossary[section] as Map).keys.toSet();
      for (final row in bundle(kind)) {
        final value = '${row[field] ?? ''}'.trim();
        if (value.isEmpty) continue;
        if (!known.contains(value.toLowerCase())) {
          missing.add('$section: $value');
        }
      }
    }

    check('spells', 'casting_time', 'castingTimes');
    check('spells', 'range_text', 'spellRanges');
    check('spells', 'duration', 'spellDurations');
    check('feats', 'type', 'featTypes');
    check('feats', 'prerequisite', 'featPrerequisites');
    check('optionalfeatures', 'type_name', 'classOptionTypes');
    check('optionalfeatures', 'prerequisite', 'classOptionPrerequisites');
    check('creatures', 'armor_detail', 'armorDetails');
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  test('feat, sinif secenegi ve esya adlarinin tamami cevrilmis', () {
    // Ad sozlugu kayittan bagimsiz; pakete yeni bir ad geldiginde ekran
    // sessizce Ingilizce kalirdi.
    final names =
        jsonDecode(File('assets/data/tr/names_tr.json').readAsStringSync())
            as Map<String, dynamic>;
    final missing = <String>{};
    Set<String> known(String section) =>
        (names[section] as Map).keys.map((k) => '$k'.toLowerCase()).toSet();

    for (final (kind, section) in [
      ('feats', 'feats'),
      ('optionalfeatures', 'classOptions'),
      // Esya adlari: envanterde yarisi Turkce yarisi Ingilizce bir liste
      // okunmasin diye ikisinin de TAMAMI cevrilmis olmali.
      ('items', 'items'),
      ('magicitems', 'magicItems'),
    ]) {
      final table = known(section);
      for (final row in bundle(kind)) {
        final name = '${row['name'] ?? ''}';
        if (name.isEmpty || table.contains(name.toLowerCase())) continue;
        missing.add('$section: $name');
      }
    }
    // Tur ozelligi ve background fayda BASLIKLARI: govde Turkce, baslik
    // Ingilizce kalirsa panel yari cevrilmis gorunuyor.
    for (final (kind, listField, section) in [
      ('species', 'traits', 'speciesTraits'),
      ('backgrounds', 'benefits', 'backgroundBenefits'),
    ]) {
      final table = known(section);
      for (final row in bundle(kind)) {
        for (final sub
            in (row[listField] as List? ?? const [])
                .whereType<Map<String, dynamic>>()) {
          if ('${sub['desc'] ?? ''}'.trim().isEmpty) continue;
          final name = '${sub['name'] ?? ''}';
          if (name.isEmpty || table.contains(name.toLowerCase())) continue;
          missing.add('$section: $name');
        }
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  test('canavar boyut ve turlerinin tamami sozlukte', () {
    final glossary =
        jsonDecode(File('assets/data/tr/glossary_tr.json').readAsStringSync())
            as Map<String, dynamic>;
    final sizes = (glossary['sizes'] as Map).keys.toSet();
    final types = (glossary['creatureTypes'] as Map).keys.toSet();
    final missing = <String>{};
    for (final row in bundle('creatures')) {
      for (final (field, known) in [('size', sizes), ('type', types)]) {
        final value = row[field];
        // Veri kimi kayitta duz dize, kimi kayitta `{name, key}` gonderiyor.
        final name = value is Map ? '${value['name']}' : '$value';
        if (name.isEmpty || name == 'null') continue;
        // "[object Object]" -- donusturucunun `choose` alanini duzlestirmedigi
        // tek kayit; ceviri beklenmiyor.
        if (name.startsWith('[object')) continue;
        if (!known.contains(name.toLowerCase())) missing.add('$field: $name');
      }
    }
    expect(missing, isEmpty, reason: missing.join(', '));
  });

  test('tamamlanan setlerde eksik ceviri yok', () {
    // Bu setler bastan sona cevrildi; biri eksilirse gerileme demektir.
    // (classes kismi: tablo sutunlari ve alt sinif tanitimlari disarida.)
    for (final kind in [
      'species',
      'backgrounds',
      'items',
      'feats',
      'magicitems',
      'spells',
      'optionalfeatures',
    ]) {
      final tr = translations(kind);
      final missing = <String>[];
      for (final row in bundle(kind)) {
        final key = row['key'] as String;
        // Aciklamasi olmayan kayitlarin (or. degerli taslar, ticari mallar)
        // cevrilecek metni yok.
        final hasText =
            '${row['desc'] ?? ''}'.trim().isNotEmpty ||
            (row['benefits'] as List? ?? const []).any(
              (b) => b is Map && '${b['desc'] ?? ''}'.trim().isNotEmpty,
            );
        if (!hasText) continue;
        if (tr[key] is! Map) missing.add(key);
      }
      expect(missing, isEmpty, reason: '$kind: ${missing.join(", ")}');
    }
  });

  test('siniflarin butun gorunen ozellikleri cevrilmis', () {
    // Sinif ve alt siniflarin tamami cevrildi. Yeni bir ozellik geldiginde bu
    // test onu yakalar; cevirisi olmayan ozellik sessizce Ingilizce gorunurdu.
    const shown = {
      'CLASS_LEVEL_FEATURE',
      'CORE_TRAITS_TABLE',
      'CLASS_FEATURE_OPTION_LIST',
    };
    String normalize(String text) =>
        text.replaceAll(RegExp(r'[\s*]+'), ' ').trim().toLowerCase();

    final tr = translations('classes');
    final missing = <String>[];
    for (final row in bundle('classes')) {
      final key = row['key'] as String;
      final entry = tr[key] as Map<String, dynamic>? ?? const {};
      final intro = normalize('${row['desc'] ?? ''}');
      if (intro.isNotEmpty && !entry.containsKey('desc')) {
        missing.add('$key -> desc');
      }
      for (final f
          in (row['features'] as List? ?? const [])
              .cast<Map<String, dynamic>>()) {
        if (!shown.contains('${f['feature_type']}')) continue;
        final text = normalize('${f['desc'] ?? ''}');
        // Alt sinif tanitimi `desc` icinde zaten var; panelde cizilmiyor.
        if (text.isEmpty || intro.contains(text)) continue;
        if (!entry.containsKey('features/${f['name']}')) {
          missing.add('$key -> ${f['name']}');
        }
      }
    }
    expect(missing, isEmpty, reason: missing.take(15).join('\n'));
  });

  test('turlerin butun ozellikleri cevrilmis', () {
    final tr = translations('species');
    final missing = <String>[];
    for (final row in bundle('species')) {
      final entry = tr[row['key']] as Map<String, dynamic>;
      for (final trait
          in (row['traits'] as List).cast<Map<String, dynamic>>()) {
        if (!entry.containsKey('traits/${trait['name']}')) {
          missing.add('${row['key']} -> ${trait['name']}');
        }
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  test('bir sinifin gorunen ozellikleri benzersiz adlarda', () {
    // Ceviri, alt kayitlari ADIYLA esliyor. Ayni sinifta ayni ada sahip iki
    // GORUNEN ozellik olursa ikisi de tek bir cevirinin metnini alir --
    // Cleric'in cekirdek ozellik tablosu "Cleric Subclasses" adiyla gelip
    // gercek alt sinif ozelligiyle carpisiyordu.
    const shown = {
      'CLASS_LEVEL_FEATURE',
      'CORE_TRAITS_TABLE',
      'CLASS_FEATURE_OPTION_LIST',
    };
    final clashes = <String>[];
    for (final row in bundle('classes')) {
      final seen = <String>{};
      for (final f
          in (row['features'] as List? ?? const [])
              .cast<Map<String, dynamic>>()) {
        if (!shown.contains('${f['feature_type']}')) continue;
        if (!seen.add('${f['name']}')) {
          clashes.add('${row['key']} -> ${f['name']}');
        }
      }
    }
    expect(clashes, isEmpty, reason: clashes.join('\n'));
  });

  test('bir sinifta iki ozellik ayni metni tasimiyor', () {
    // Circle of the Land'de seviye 14 Nature's Sanctuary, seviye 6 Natural
    // Recovery'nin metnini birebir kopyalamisti; oyuncu ayni kurali iki
    // seviyede okuyup gercek ozelligi hic gormuyordu.
    const shown = {
      'CLASS_LEVEL_FEATURE',
      'CORE_TRAITS_TABLE',
      'CLASS_FEATURE_OPTION_LIST',
    };
    final duplicates = <String>[];
    for (final row in bundle('classes')) {
      final seen = <String, String>{};
      for (final f
          in (row['features'] as List? ?? const [])
              .cast<Map<String, dynamic>>()) {
        if (!shown.contains('${f['feature_type']}')) continue;
        final text = '${f['desc'] ?? ''}'.trim();
        // Kisa metinler ("You gain a feature from your subclass.") mesru
        // sekilde tekrar edebilir.
        if (text.length < 120) continue;
        final previous = seen[text];
        if (previous != null) {
          duplicates.add('${row['key']}: ${f['name']} == $previous');
        } else {
          seen[text] = '${f['name']}';
        }
      }
    }
    expect(duplicates, isEmpty, reason: duplicates.join('\n'));
  });

  test('paketlenmis metinde donusturucu artigi kalmamis', () {
    // `tools/fetch_open5e.dart` bunlari temizliyor; geri sizarsa oyuncu
    // "20-foot-radius Sphere [Area of Effect]|XPHB|Sphere" okur.
    final leftovers = RegExp(
      r'\{@\w+|\{#\w+|\|X(?:PHB|DMG|MM)\||@UUID\[|@Embed\[|&Reference\[|'
      r'\[Area of Effect\]|\[Attitude\]',
    );
    for (final kind in sections.keys) {
      final text = jsonEncode(bundle(kind));
      expect(
        leftovers.firstMatch(text)?.group(0),
        isNull,
        reason: '$kind icinde cozulmemis isaretleme var',
      );
    }
  });

  test('okunan metinde kaynak kitap kodu kalmamis', () {
    // Donusturucu bazi adlarin yerine kitabin KODUNU yazmis: Artificer'in alt
    // siniflari "The EFA, EFA, EFA, EFA, and EFA subclasses" olarak, Dead
    // Three'nin tanrilari da "FRHoF" olarak geliyordu.
    final code = RegExp(r'\b(?:EFA|RHW|FRHoF|XPHB|XDMG|XMM)\b');
    for (final kind in sections.keys) {
      for (final row in bundle(kind)) {
        // Kod, kayit ANAHTARINDA gecebilir (`xphbxdmg-...`); sorun yalnizca
        // oyuncunun okudugu metinde.
        final texts = <String>[
          '${row['desc'] ?? ''}',
          for (final section in ['features', 'traits', 'benefits', 'actions'])
            for (final sub in (row[section] as List? ?? const []))
              if (sub is Map) '${sub['desc'] ?? ''}',
        ];
        for (final text in texts) {
          expect(
            code.firstMatch(text)?.group(0),
            isNull,
            reason: '$kind/${row['key']}: metinde kaynak kodu var',
          );
        }
      }
    }
  });
}
