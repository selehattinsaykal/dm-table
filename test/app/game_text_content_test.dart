import 'dart:convert';
import 'dart:io';

import 'package:dm_table/app/ui/game_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Paketlenen HER kural metnini [GameText] ile cizer.
///
/// Kutuphane metinleri elle yazilan markdown; bozuk bir tablo satiri ya da
/// beklenmedik bir bicim, kayit acilinca panelin bos/gri kalmasina yol
/// aciyordu. Metin veriden geldigi icin bunu ancak veriyle test edebiliriz.
void main() {
  List<Map<String, dynamic>> bundle(String kind) {
    final bytes = File('assets/data/$kind.json.gz').readAsBytesSync();
    return (jsonDecode(utf8.decode(gzip.decode(bytes))) as List)
        .cast<Map<String, dynamic>>();
  }

  Map<String, dynamic> translations(String kind) =>
      jsonDecode(File('assets/data/tr/${kind}_tr.json').readAsStringSync())
          as Map<String, dynamic>;

  /// Bir kayittan cizilebilecek butun metinleri toplar.
  Iterable<(String, String)> textsOf(String kind) sync* {
    for (final row in bundle(kind)) {
      final key = row['key'] as String;
      final desc = '${row['desc'] ?? ''}';
      if (desc.trim().isNotEmpty) yield ('$kind/$key/desc', desc);
      for (final section in ['benefits', 'traits', 'features', 'actions']) {
        for (final (i, sub) in (row[section] as List? ?? const []).indexed) {
          if (sub is! Map) continue;
          final text = '${sub['desc'] ?? ''}';
          if (text.trim().isNotEmpty) yield ('$kind/$key/$section[$i]', text);
        }
      }
    }
    for (final entry in translations(kind).entries) {
      if (entry.key.startsWith('_') || entry.value is! Map) continue;
      for (final field in (entry.value as Map).entries) {
        yield ('$kind(tr)/${entry.key}/${field.key}', '${field.value}');
      }
    }
  }

  for (final kind in [
    'feats',
    'species',
    'backgrounds',
    'items',
    'magicitems',
    'classes',
    'creatures',
    'spells',
  ]) {
    testWidgets('$kind metinleri cizilebiliyor', (tester) async {
      final broken = <String>[];
      for (final (where, text) in textsOf(kind)) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: SingleChildScrollView(child: GameText(text))),
          ),
        );
        if (tester.takeException() case final error?) {
          broken.add('$where: $error');
        }
      }
      expect(broken, isEmpty, reason: broken.take(10).join('\n'));
    });
  }
}
