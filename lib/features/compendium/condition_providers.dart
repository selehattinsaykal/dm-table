import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/rules/condition_reference.dart';

/// Türkçe çeviriler: `assets/data/conditions_tr.json`.
///
/// Kural metni İÇERİK olduğu için ARB'de değil asset'te (SRD verisiyle aynı
/// yerde). Yalnızca bir kez okunur.
final _conditionTranslationsProvider =
    FutureProvider<Map<String, ({String name, String desc})>>((ref) async {
      final raw = await rootBundle.loadString('assets/data/conditions_tr.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in data.entries)
          if (e.value is Map && !e.key.startsWith('_'))
            e.key: (
              name: (e.value as Map)['name'] as String? ?? '',
              desc: (e.value as Map)['desc'] as String? ?? '',
            ),
      };
    });

/// Gösterilebilir durum kayıtları (A5e'ye özel olanlar elenir).
///
/// [turkish] ise çeviri uygulanır; çevirisi olmayan kayıt İngilizce kalır.
final conditionEntriesProvider =
    FutureProvider.family<List<ConditionEntry>, bool>((ref, turkish) async {
      final db = ref.watch(databaseProvider);
      final rows = await (db.select(
        db.referenceEntries,
      )..where((t) => t.kind.equals('conditions'))).get();
      final translations = turkish
          ? await ref.watch(_conditionTranslationsProvider.future)
          : const <String, ({String name, String desc})>{};

      final out = <ConditionEntry>[];
      for (final row in rows) {
        final entry = conditionFrom(row.key, row.name, row.dataJson);
        // conditionFrom, 5e metni olmayan (A5e'ye özel) kayıtlara null döner.
        if (entry == null) continue;
        final tr = translations[row.key];
        out.add(
          tr == null ? entry : (key: entry.key, name: tr.name, desc: tr.desc),
        );
      }
      out.sort((a, b) => a.name.compareTo(b.name));
      return out;
    });

/// Savaş ekranında kullanılan durum ADLARI.
///
/// ⚠️ `Combatants.conditionsJson` durumu ADIYLA sakladığı için burada
/// İNGİLİZCE ad döner — Türkçeleştirmek mevcut savaş verisini bozardı.
/// Görüntüleme tarafında [conditionLabelProvider] ile çevrilir.
final conditionNamesEnProvider = FutureProvider<List<String>>((ref) async {
  final entries = await ref.watch(conditionEntriesProvider(false).future);
  return [for (final e in entries) e.name];
});

/// İngilizce ad -> gösterilecek ad eşlemesi (Türkçe arayüzde çeviri).
final conditionLabelProvider = FutureProvider.family<Map<String, String>, bool>(
  (ref, turkish) async {
    if (!turkish) return const {};
    final db = ref.watch(databaseProvider);
    final rows = await (db.select(
      db.referenceEntries,
    )..where((t) => t.kind.equals('conditions'))).get();
    final translations = await ref.watch(_conditionTranslationsProvider.future);
    return {
      for (final row in rows)
        if (translations[row.key] case final tr?) row.name: tr.name,
    };
  },
);
