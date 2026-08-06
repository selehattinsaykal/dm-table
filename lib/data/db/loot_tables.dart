import 'package:drift/drift.dart';

/// DM'in onceden hazirladigi ganimet seti (esya + para). Istenildiginde
/// oyunculara sunulur; setin kendisi kalici, sunulan ganimet gecicidir.
class LootSets extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// Toplam para, bakir cinsinden (pp/gp/sp/cp tek toplamda).
  IntColumn get coinsCp => integer().withDefault(const Constant(0))();

  /// Esyalar: `[{"name":"Kılıç","magic":false}, ...]` JSON dizisi.
  TextColumn get itemsJson => text().withDefault(const Constant('[]'))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
