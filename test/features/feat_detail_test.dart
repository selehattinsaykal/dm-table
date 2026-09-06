import 'dart:convert';
import 'dart:io';

import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/db/tables.dart';
import 'package:dm_table/features/compendium/detail_sheets.dart';
import 'package:dm_table/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Paketteki HER feat'in ayrinti paneli hatasiz cizilmeli.
///
/// `type` ve `prerequisite` alanlari veri setinde iki ayri sekilde geliyordu:
/// SRD kayitlarinda duz metin, donusturulen 2024 PHB kayitlarinda ham 5etools
/// nesnesi (`[{"level": 4, "ability": [{"cha": 13}]}]`). Panel bunu
/// `as String?` diye okudugu icin o 54 kayit acilinca tip hatasi verip GRI
/// kutu olarak ciziliyordu. Veri artik normalize ediliyor; bu test hem
/// normalizasyonu hem de panelin dayanikliligini birlikte koruyor.
void main() {
  List<Map<String, dynamic>> feats() {
    final bytes = File('assets/data/feats.json.gz').readAsBytesSync();
    return (jsonDecode(utf8.decode(gzip.decode(bytes))) as List)
        .cast<Map<String, dynamic>>();
  }

  test('feat kategorileri ve onkosullari duz metin', () {
    // Seviye atlama ekrani kategoriyi ADIYLA suzuyor (`type == 'General'`);
    // kisaltilmis kodlar geri sizarsa 2024 PHB featleri listeden dusuyor.
    const known = {
      'General',
      'Origin',
      'Epic Boon',
      'Fighting Style',
      'Dragonmark',
      'Dark Gift',
    };
    final problems = <String>[];
    for (final feat in feats()) {
      final type = feat['type'];
      if (type is! String || !known.contains(type)) {
        problems.add('${feat['key']}: type = $type');
      }
      final prerequisite = feat['prerequisite'];
      if (prerequisite != null && prerequisite is! String) {
        problems.add('${feat['key']}: prerequisite = $prerequisite');
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('her ASI seviyesinde secilebilir General feat var', () {
    // 41 feat `G` etiketiyle geldigi icin seviye atlamada hicbiri gorunmuyordu.
    final general = feats().where((f) => f['type'] == 'General').length;
    expect(general, greaterThan(50), reason: 'General feat sayisi dustu');
  });

  testWidgets('butun feat panelleri hatasiz cizilir', (tester) async {
    final broken = <String>[];
    // Veri normalize edilmis olsa da panel ham sekle karsi da dayanikli
    // olmali: bu kayit tam olarak gri kutuya yol acan sekildir.
    final rows = [
      ...feats(),
      {
        'key': 'test_ham-onkosul',
        'name': 'Ham Onkosul',
        'document': 'srd-2024',
        'type': 'G',
        'prerequisite': [
          {
            'level': 4,
            'ability': [
              {'cha': 13},
            ],
          },
        ],
        'desc': 'You gain the following benefits.',
        'benefits': [
          {'desc': 'Something happens.'},
        ],
      },
    ];
    for (final row in rows) {
      final feat = Feat(
        key: row['key'] as String,
        name: row['name'] as String,
        nameLower: (row['name'] as String).toLowerCase(),
        document: row['document'] as String?,
        sourceType: SourceType.srd,
        dataJson: jsonEncode(row),
      );
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('tr'),
            localizationsDelegates: const [
              L10n.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('tr'), Locale('en')],
            home: Scaffold(body: FeatDetail(feat: feat)),
          ),
        ),
      );
      if (tester.takeException() case final error?) {
        broken.add('${row['key']}: $error');
      }
    }
    expect(broken, isEmpty, reason: broken.take(10).join('\n'));
  });
}
