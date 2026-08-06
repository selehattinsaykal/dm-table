import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../data/random_table_repository.dart';

final randomTableRepositoryProvider = Provider<RandomTableRepository>(
  (ref) => RandomTableRepository(ref.watch(databaseProvider)),
);

final randomTablesProvider = StreamProvider<List<RandomTable>>(
  (ref) => ref.watch(randomTableRepositoryProvider).watchAll(),
);

final randomTableProvider = StreamProvider.family<RandomTable?, String>(
  (ref, id) => ref.watch(randomTableRepositoryProvider).watchOne(id),
);

/// `assets/data/starter_tables.json` icindeki hazir tablolar.
///
/// ARB yerine asset: satirlar paragraf uzunlugunda ICERIK, arayuz metni degil
/// (SRD verisiyle ayni yerde durmali).
Future<List<({String name, String category, int diceSides, List<String> rows})>>
loadStarterTables(String localeCode) async {
  final raw = await rootBundle.loadString('assets/data/starter_tables.json');
  final data = jsonDecode(raw) as Map<String, dynamic>;
  final list = (data[localeCode] ?? data['en']) as List? ?? const [];
  return [
    for (final e in list)
      if (e is Map)
        (
          name: e['name'] as String? ?? '',
          category: e['category'] as String? ?? '',
          diceSides: e['diceSides'] as int? ?? 20,
          rows: [for (final r in (e['rows'] as List? ?? const [])) '$r'],
        ),
  ];
}
