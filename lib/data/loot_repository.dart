import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'db/database.dart';

/// Ganimet setindeki bir esya.
typedef LootItemData = ({String name, bool magic});

/// Onceden hazirlanan ganimet setlerini okur/yazar.
class LootRepository {
  LootRepository(this.db);

  final AppDatabase db;
  static const _uuid = Uuid();

  Stream<List<LootSet>> watchAll() =>
      (db.select(db.lootSets)..orderBy([
            (t) => OrderingTerm(expression: t.sortOrder),
            (t) => OrderingTerm(expression: t.name),
          ]))
          .watch();

  Future<LootSet?> find(String id) =>
      (db.select(db.lootSets)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<String> create(String name) async {
    final id = 'loot-${_uuid.v4()}';
    final count = (await db.select(db.lootSets).get()).length;
    await db
        .into(db.lootSets)
        .insert(
          LootSetsCompanion.insert(id: id, name: name, sortOrder: Value(count)),
        );
    return id;
  }

  Future<void> update(
    String id, {
    String? name,
    int? coinsCp,
    List<LootItemData>? items,
  }) async {
    await (db.update(db.lootSets)..where((t) => t.id.equals(id))).write(
      LootSetsCompanion(
        name: name == null ? const Value.absent() : Value(name),
        coinsCp: coinsCp == null ? const Value.absent() : Value(coinsCp),
        itemsJson: items == null
            ? const Value.absent()
            : Value(
                jsonEncode([
                  for (final i in items) {'name': i.name, 'magic': i.magic},
                ]),
              ),
      ),
    );
  }

  Future<void> delete(String id) =>
      (db.delete(db.lootSets)..where((t) => t.id.equals(id))).go();

  /// Setin esyalarini cozer.
  static List<LootItemData> itemsOf(LootSet set) => [
    for (final e in (jsonDecode(set.itemsJson) as List))
      (
        name: (e as Map)['name'] as String? ?? '',
        magic: e['magic'] as bool? ?? false,
      ),
  ];

  /// Bir ganimet setini hazine pini icin ilk "kalan ganimet" verisine cevirir.
  ///
  /// Her esyaya kalici bir id atanir: oyuncular bu id ile esyayi alir, esya
  /// alininca digerlerinde de kaybolur (dupelenmez).
  static String initialPinLoot(LootSet set) => jsonEncode({
    'coinsCp': set.coinsCp,
    'items': [
      for (final item in itemsOf(set))
        {'id': _uuid.v4(), 'name': item.name, 'magic': item.magic},
    ],
  });

  /// Pinin kalan ganimetini cozer; hazine pini degilse (lootDataJson yoksa)
  /// `null` doner.
  static ({int coinsCp, List<({String id, String name, bool magic})> items})?
  pinLootOf(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      return (
        coinsCp: data['coinsCp'] as int? ?? 0,
        items: [
          for (final e in (data['items'] as List? ?? const []))
            (
              id: (e as Map)['id'] as String? ?? '',
              name: e['name'] as String? ?? '',
              magic: e['magic'] as bool? ?? false,
            ),
        ],
      );
    } catch (_) {
      return null;
    }
  }
}
