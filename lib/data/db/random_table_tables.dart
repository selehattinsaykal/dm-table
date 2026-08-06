import 'package:drift/drift.dart';

/// DM'in rastgele tablosu ("Meyhane olayları", "Yolda ne olur", "Söylenti").
///
/// `LootSets` ile ayni sekil: duz tablo + JSON yuk kolonu + ince repository.
class RandomTables extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// Serbest kategori ("şehir", "yol", "ganimet"); filtreleme icin.
  TextColumn get category => text().withDefault(const Constant(''))();

  /// Zar yuzu: 4/6/8/10/12/20/100. Sonradan degistirilebilir; aralikar
  /// silinmez, editor uyari gosterip yeniden dagitmayi onerir.
  IntColumn get diceSides => integer().withDefault(const Constant(20))();

  /// Satirlar: `[{"min":1,"max":5,"text":".."}]`. Aralik iki uctan da dahil.
  TextColumn get rowsJson => text().withDefault(const Constant('[]'))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
