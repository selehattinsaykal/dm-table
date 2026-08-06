import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'db/database.dart';
import 'loot_repository.dart';

/// Görevleri (Görevler sekmesi) okur/yazar. Kalıcı; hedefleme + kabul/ret
/// bilgisi JSON sütunlarda tutulur.
class QuestRepository {
  QuestRepository(this.db);

  final AppDatabase db;
  static const _uuid = Uuid();

  /// Paylaşım biçimleri.
  static const modeIndividual = 'individual';
  static const modeVote = 'vote';

  /// Oylama durumları.
  static const votePending = 'pending';
  static const votePassed = 'passed';
  static const voteFailed = 'failed';

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
  ///
  /// Tamamlanınca (ve gerçek bir ödül tanımlıysa) ortak ganimet havuzu açılır:
  /// görevi kabul etmiş oyuncuların hepsi aynı havuzu görür, bir eşyayı kim
  /// önce alırsa diğerlerinden kaybolur. Geri açılınca havuz kapanır.
  Future<void> setDone(String id, bool done) async {
    final quest = await find(id);
    if (quest == null) return;
    final pool = done ? initialRewardPool(quest) : null;
    await (db.update(db.quests)..where((t) => t.id.equals(id))).write(
      QuestsCompanion(done: Value(done), rewardPoolJson: Value(pool)),
    );
  }

  /// Görevi paylaşır/gizler, hedef oyuncuları (characterId) ve paylaşım
  /// biçimini belirler. Yeniden paylaşımda eski kabul/ret kayıtları silinir;
  /// oylama modunda oylama `pending` olarak başlar.
  Future<void> setShared(
    String id, {
    required bool shared,
    List<String>? targets,
    String? mode,
  }) async {
    final effectiveMode = mode ?? modeIndividual;
    await (db.update(db.quests)..where((t) => t.id.equals(id))).write(
      QuestsCompanion(
        shared: Value(shared),
        targetsJson: targets == null
            ? const Value.absent()
            : Value(jsonEncode(targets)),
        shareMode: mode == null ? const Value.absent() : Value(mode),
        // Paylaşımı (yeniden) açmak kararları sıfırlar; kapatmak da öyle.
        acceptancesJson: const Value('{}'),
        voteStatus: Value(
          shared && effectiveMode == modeVote ? votePending : '',
        ),
      ),
    );
  }

  /// Bir oyuncunun (characterId) kabul/ret kaydını yazar.
  Future<void> setAcceptance(String id, String characterId, bool accept) async {
    final quest = await find(id);
    if (quest == null) return;
    final map = acceptancesOf(quest);
    map[characterId] = accept;
    await (db.update(db.quests)..where((t) => t.id.equals(id))).write(
      QuestsCompanion(acceptancesJson: Value(jsonEncode(map))),
    );
  }

  /// Oylamayı sonuçlandırır: [passed] ise görev hedeflerin HEPSİNE verilir
  /// (herkes kabul etmiş sayılır), değilse kimse alamaz ve paylaşım kalkar.
  Future<void> resolveVote(String id, {required bool passed}) async {
    final quest = await find(id);
    if (quest == null) return;
    final targets = targetsOf(quest);
    await (db.update(db.quests)..where((t) => t.id.equals(id))).write(
      QuestsCompanion(
        voteStatus: Value(passed ? votePassed : voteFailed),
        shared: Value(passed),
        acceptancesJson: Value(
          jsonEncode(passed ? {for (final t in targets) t: true} : {}),
        ),
      ),
    );
  }

  Future<void> delete(String id) =>
      (db.delete(db.quests)..where((t) => t.id.equals(id))).go();

  /// Hedef characterId listesi.
  static List<String> targetsOf(Quest q) => [
    for (final e in (jsonDecode(q.targetsJson) as List)) '$e',
  ];

  /// characterId → kabul(true)/ret(false) haritası.
  static Map<String, bool> acceptancesOf(Quest q) => {
    for (final e in (jsonDecode(q.acceptancesJson) as Map).entries)
      '${e.key}': e.value as bool,
  };

  /// Tanımlı ödül eşyaları (havuz değil, şablon).
  static List<LootItemData> rewardItemsOf(Quest q) => [
    for (final e in (jsonDecode(q.rewardItemsJson) as List))
      (
        name: (e as Map)['name'] as String? ?? '',
        magic: e['magic'] as bool? ?? false,
      ),
  ];

  /// Görevin tanımlı ödülünü ilk "kalan ganimet" havuzuna çevirir; ödül boşsa
  /// `null` döner (o zaman görev sadece tamamlanmış olur).
  ///
  /// Her eşyaya kalıcı bir id atanır: oyuncular bu id ile eşyayı alır, alınan
  /// eşya diğerlerinde de kaybolur (dupelenmez).
  static String? initialRewardPool(Quest q) {
    final items = rewardItemsOf(q);
    if (items.isEmpty && q.rewardCoinsCp <= 0) return null;
    return jsonEncode({
      'coinsCp': q.rewardCoinsCp,
      'items': [
        for (final item in items)
          {'id': _uuid.v4(), 'name': item.name, 'magic': item.magic},
      ],
    });
  }

  /// Görevin açık ganimet havuzunu çözer; havuz kapalıysa `null`.
  static ({int coinsCp, List<({String id, String name, bool magic})> items})?
  poolOf(Quest q) => LootRepository.pinLootOf(q.rewardPoolJson);

  /// Havuzdan tek bir eşyayı ([itemId]) ya da parayı alır. Havuz boşalınca
  /// görev tablodan silinir (hazine pini davranışının aynısı).
  Future<({bool deleted, String? error, String? takenName, int takenCoinsCp})>
  takeReward(String questId, {String? itemId}) async {
    final quest = await find(questId);
    if (quest == null) {
      return (
        deleted: false,
        error: 'noQuest',
        takenName: null,
        takenCoinsCp: 0,
      );
    }
    final raw = quest.rewardPoolJson;
    if (raw == null || raw.isEmpty) {
      return (
        deleted: false,
        error: 'noLoot',
        takenName: null,
        takenCoinsCp: 0,
      );
    }

    final data = jsonDecode(raw) as Map<String, dynamic>;
    var coins = data['coinsCp'] as int? ?? 0;
    final items = <Map<String, dynamic>>[
      for (final e in (data['items'] as List? ?? const []))
        (e as Map).cast<String, dynamic>(),
    ];

    String? takenName;
    var takenCoinsCp = 0;
    if (itemId != null) {
      final index = items.indexWhere((i) => i['id'] == itemId);
      if (index == -1) {
        return (
          deleted: false,
          error: 'itemGone',
          takenName: null,
          takenCoinsCp: 0,
        );
      }
      takenName = items[index]['name'] as String? ?? '';
      items.removeAt(index);
    } else {
      if (coins <= 0) {
        return (
          deleted: false,
          error: 'noMoneyLeft',
          takenName: null,
          takenCoinsCp: 0,
        );
      }
      takenCoinsCp = coins;
      coins = 0;
    }

    if (items.isEmpty && coins <= 0) {
      await delete(questId);
      return (
        deleted: true,
        error: null,
        takenName: takenName,
        takenCoinsCp: takenCoinsCp,
      );
    }

    await (db.update(db.quests)..where((t) => t.id.equals(questId))).write(
      QuestsCompanion(
        rewardPoolJson: Value(jsonEncode({'coinsCp': coins, 'items': items})),
      ),
    );
    return (
      deleted: false,
      error: null,
      takenName: takenName,
      takenCoinsCp: takenCoinsCp,
    );
  }

  /// Havuzda kalan HER ŞEYİ tek işlemde alır ve görevi siler.
  Future<
    ({String? error, int coinsCp, List<({String name, bool magic})> items})
  >
  takeAllReward(String questId) async {
    final quest = await find(questId);
    if (quest == null) {
      return (
        error: 'noQuest',
        coinsCp: 0,
        items: const <({String name, bool magic})>[],
      );
    }
    final pool = poolOf(quest);
    if (pool == null || (pool.items.isEmpty && pool.coinsCp <= 0)) {
      return (
        error: 'noLoot',
        coinsCp: 0,
        items: const <({String name, bool magic})>[],
      );
    }
    await delete(questId);
    return (
      error: null,
      coinsCp: pool.coinsCp,
      items: [for (final i in pool.items) (name: i.name, magic: i.magic)],
    );
  }
}
