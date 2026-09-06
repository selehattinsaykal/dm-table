import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/rules/dice.dart';
import 'db/database.dart';

/// Sik kullanilan zar kisayollari.
///
/// Makro yeni bir zar dili GETIRMIYOR: ifade [parseDiceExpression] ile
/// cozuluyor, yani makroda gecerli olan her sey elle yazildiginda da
/// gecerli. Boylece "makro calisiyor ama elle yazinca calismiyor" gibi bir
/// ikilik olusmuyor.
class MacroRepository {
  const MacroRepository(this.db);

  final AppDatabase db;
  static const _uuid = Uuid();

  Stream<List<Macro>> watchAll({String? characterId}) {
    final q = db.select(db.macros)
      ..orderBy([
        (t) => OrderingTerm(expression: t.sortOrder),
        (t) => OrderingTerm(expression: t.name),
      ]);
    if (characterId != null) {
      // Karaktere ozel makrolar + genel makrolar birlikte gorunur.
      q.where(
        (t) => t.characterId.equals(characterId) | t.characterId.isNull(),
      );
    }
    return q.watch();
  }

  /// Ifadeyi dogrular; gecersizse null.
  static ({int count, int sides, int modifier})? validate(String expression) =>
      parseDiceExpression(expression);

  Future<String?> add({
    required String name,
    required String expression,
    String? characterId,
  }) async {
    // Gecersiz ifade KAYDEDILMIYOR: masada calismayan bir dugmeye basmak,
    // dugmenin hic olmamasindan kotu.
    if (validate(expression) == null) return null;

    final count = await db.select(db.macros).get().then((r) => r.length);
    final id = _uuid.v4();
    await db
        .into(db.macros)
        .insert(
          MacrosCompanion.insert(
            id: id,
            name: name.trim(),
            expression: expression.trim(),
            characterId: Value(characterId),
            sortOrder: Value(count),
          ),
        );
    return id;
  }

  Future<void> update(String id, {String? name, String? expression}) async {
    if (expression != null && validate(expression) == null) return;
    await (db.update(db.macros)..where((t) => t.id.equals(id))).write(
      MacrosCompanion(
        name: name == null ? const Value.absent() : Value(name.trim()),
        expression: expression == null
            ? const Value.absent()
            : Value(expression.trim()),
      ),
    );
  }

  Future<void> remove(String id) =>
      (db.delete(db.macros)..where((t) => t.id.equals(id))).go();

  Future<void> reorder(List<String> idsInOrder) async {
    await db.batch((b) {
      for (final (index, id) in idsInOrder.indexed) {
        b.update(
          db.macros,
          MacrosCompanion(sortOrder: Value(index)),
          where: (t) => t.id.equals(id),
        );
      }
    });
  }

  /// Makroyu atar. Ifade bozuksa null.
  static DiceRoll? roll(Macro macro, DiceRoller roller, {String? source}) {
    final parsed = parseDiceExpression(macro.expression);
    if (parsed == null) return null;
    return roller.roll(
      sides: parsed.sides,
      count: parsed.count,
      modifier: parsed.modifier,
      label: macro.name,
      source: source,
    );
  }
}
