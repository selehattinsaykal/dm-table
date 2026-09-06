import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'db/database.dart';
import 'loot_repository.dart';

/// Görevleri (Görevler sekmesi) okur/yazar. Kalıcı; görevi hangi karakterlerin
/// üstlendiği JSON sütunda tutulur.
class QuestRepository {
  QuestRepository(this.db);

  final AppDatabase db;
  static const _uuid = Uuid();

  Stream<List<Quest>> watchAll() =>
      (db.select(db.quests)..orderBy([
            (t) => OrderingTerm(expression: t.done),
            (t) => OrderingTerm(expression: t.sortOrder),
          ]))
          .watch();

  Future<List<Quest>> all() => db.select(db.quests).get();

  Future<Quest?> find(String id) =>
      (db.select(db.quests)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<String> create({String title = ''}) async {
    final id = 'quest-${_uuid.v4()}';
    final count = (await db.select(db.quests).get()).length;
    await db
        .into(db.quests)
        .insert(
          QuestsCompanion.insert(
            id: id,
            title: Value(title),
            sortOrder: Value(count),
          ),
        );
    return id;
  }

  Future<void> update(
    String id, {
    String? title,
    String? questText,
    String? reward,
    String? dmNotes,
    int? rewardCoinsCp,
    List<LootItemData>? rewardItems,
  }) async {
    await (db.update(db.quests)..where((t) => t.id.equals(id))).write(
      QuestsCompanion(
        title: title == null ? const Value.absent() : Value(title),
        questText: questText == null ? const Value.absent() : Value(questText),
        reward: reward == null ? const Value.absent() : Value(reward),
        dmNotes: dmNotes == null ? const Value.absent() : Value(dmNotes),
        rewardCoinsCp: rewardCoinsCp == null
            ? const Value.absent()
            : Value(rewardCoinsCp),
        rewardItemsJson: rewardItems == null
            ? const Value.absent()
            : Value(
                jsonEncode([
                  for (final i in rewardItems)
                    {'name': i.name, 'magic': i.magic},
                ]),
              ),
      ),
    );
  }

  /// Görevi tamamlar/geri açar.
  Future<void> setDone(String id, bool done) => (db.update(
    db.quests,
  )..where((t) => t.id.equals(id))).write(QuestsCompanion(done: Value(done)));

  /// Görevi üstlenen karakterleri (characterId) yazar.
  Future<void> setTargets(String id, List<String> targets) =>
      (db.update(db.quests)..where((t) => t.id.equals(id))).write(
        QuestsCompanion(targetsJson: Value(jsonEncode(targets))),
      );

  Future<void> delete(String id) =>
      (db.delete(db.quests)..where((t) => t.id.equals(id))).go();

  /// Görevi üstlenen characterId listesi.
  static List<String> targetsOf(Quest q) => [
    for (final e in (jsonDecode(q.targetsJson) as List)) '$e',
  ];

  /// Görevin ödül eşyaları.
  static List<LootItemData> rewardItemsOf(Quest q) => [
    for (final e in (jsonDecode(q.rewardItemsJson) as List))
      (
        name: (e as Map)['name'] as String? ?? '',
        magic: e['magic'] as bool? ?? false,
      ),
  ];
}
