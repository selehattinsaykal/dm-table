import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'combat_repository.dart';
import 'db/database.dart';

/// Kalibin bir satiri: hangi canavardan kac tane.
typedef TemplateEntry = ({String monsterKey, String name, int count});

/// Kaydedilmis karsilasma kaliplari.
///
/// Kalip yalnizca KADROYU tasiyor. Can ve inisiyatif kurulurken yeniden
/// atiliyor: ayni kalibi iki kez kuran DM ayni can degerlerini almasin,
/// yoksa oyuncular ikinci karsilasmada rakamlari ezberlemis olurdu.
class EncounterTemplateRepository {
  const EncounterTemplateRepository(this.db);

  final AppDatabase db;
  static const _uuid = Uuid();

  Stream<List<EncounterTemplate>> watchAll() => (db.select(
    db.encounterTemplates,
  )..orderBy([(t) => OrderingTerm(expression: t.name)])).watch();

  static List<TemplateEntry> entriesOf(EncounterTemplate template) {
    try {
      final list = jsonDecode(template.entriesJson);
      if (list is! List) return const [];
      return [
        for (final item in list)
          if (item is Map)
            (
              monsterKey: '${item['key'] ?? ''}',
              name: '${item['name'] ?? ''}',
              count: (item['count'] as num?)?.toInt() ?? 1,
            ),
      ];
    } on Object {
      return const [];
    }
  }

  /// Var olan bir karsilasmanin kadrosunu kalip olarak kaydeder.
  ///
  /// Yalnizca CANAVARLAR aliniyor: oyuncu karakterleri kalibin parcasi degil,
  /// kurulusta partiden geliyorlar.
  Future<String> saveFrom({
    required String name,
    required List<Combatant> combatants,
    String note = '',
  }) async {
    final counts = <String, ({String name, int count})>{};
    for (final c in combatants) {
      final key = c.monsterKey;
      if (key == null) continue;
      // "Goblin 3" gibi numarali adlar tek satirda toplansin.
      final label = c.name.replaceFirst(RegExp(r'\s+\d+$'), '');
      final existing = counts[key];
      counts[key] = (
        name: existing?.name ?? label,
        count: (existing?.count ?? 0) + 1,
      );
    }

    final id = _uuid.v4();
    await db
        .into(db.encounterTemplates)
        .insert(
          EncounterTemplatesCompanion.insert(
            id: id,
            name: name.trim(),
            note: Value(note),
            entriesJson: Value(
              jsonEncode([
                for (final entry in counts.entries)
                  {
                    'key': entry.key,
                    'name': entry.value.name,
                    'count': entry.value.count,
                  },
              ]),
            ),
          ),
        );
    return id;
  }

  Future<void> remove(String id) =>
      (db.delete(db.encounterTemplates)..where((t) => t.id.equals(id))).go();

  Future<void> rename(String id, String name) =>
      (db.update(db.encounterTemplates)..where((t) => t.id.equals(id))).write(
        EncounterTemplatesCompanion(name: Value(name.trim())),
      );

  /// Kalibi yeni bir karsilasma olarak kurar; karsilasmanin kimligini doner.
  ///
  /// Kutuphanede bulunamayan canavarlar ATLANIR (kaynak silinmis olabilir);
  /// atlananlarin adlari geri donuyor ki arayuz sessiz kalmasin.
  Future<({String encounterId, List<String> missing})> instantiate(
    EncounterTemplate template, {
    required CombatRepository combat,
    String? encounterName,
    bool rollHitPoints = true,
    bool groupInitiative = true,
  }) async {
    final encounterId = await combat.createEncounter(
      encounterName?.trim().isNotEmpty == true
          ? encounterName!.trim()
          : template.name,
    );

    final missing = <String>[];
    for (final entry in entriesOf(template)) {
      final monster = await (db.select(
        db.monsters,
      )..where((t) => t.key.equals(entry.monsterKey))).getSingleOrNull();
      if (monster == null) {
        missing.add(entry.name.isEmpty ? entry.monsterKey : entry.name);
        continue;
      }
      await combat.addMonsters(
        encounterId: encounterId,
        monster: monster,
        count: entry.count,
        rollHitPoints: rollHitPoints,
        groupInitiative: groupInitiative,
      );
    }
    return (encounterId: encounterId, missing: missing);
  }
}
