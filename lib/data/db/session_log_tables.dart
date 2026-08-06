import 'package:drift/drift.dart';

/// Oturum gunlugu: DM'in seans boyunca biriken kalici olay kaydi (XP verildi,
/// elle not vb.). Paylasilan zar gunlugunden farkli — o anlik/ephemeral, bu
/// diskte kalir.
class SessionLogEntries extends Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Siralama anahtari (mikrosaniye). Drift DateTime'i saniye hassasiyetiyle
  /// sakladigi icin ayni saniyede eklenen kayitlar bununla kesin siralanir.
  IntColumn get sortKey => integer().withDefault(const Constant(0))();

  /// Kayit metni. ("text" adi Drift'in text() olusturucusuyla cakistigi icin
  /// kolon "message" olarak adlandirildi.)
  TextColumn get message => text()();

  @override
  Set<Column> get primaryKey => {id};
}
