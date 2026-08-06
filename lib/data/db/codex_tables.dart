import 'package:drift/drift.dart';

/// DM bilgi tabani ("Kayitlar"): ic ice sayfalar + blok tabanli icerik.
///
/// Notion/Obsidian benzeri: her sayfa sirali bloklardan olusur, bloklar
/// baska sayfalara/entity'lere/zarlara baglanabilir. Icerik tumuyle DM'e
/// ozel (oyunculara gitmez).

/// Ic ice sayfa agaci.
class CodexPages extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withDefault(const Constant(''))();

  /// Sayfa simgesi (emoji); listede ve baslikta gorunur.
  TextColumn get icon => text().nullable()();

  /// Ust sayfa; kok sayfalarda null.
  TextColumn get parentId => text().nullable()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Bir sayfanin sirali blogu. [type] blok turu, [dataJson] o ture ozel veri.
class CodexBlocks extends Table {
  TextColumn get id => text()();
  TextColumn get pageId => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// Blok turu (CodexBlockType.name).
  TextColumn get type => text()();

  /// Ture gore degisen icerik (JSON).
  TextColumn get dataJson => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {id};
}
