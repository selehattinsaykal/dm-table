import 'package:drift/drift.dart';

/// DM'in görevleri (Görevler sekmesi). Kalıcı kampanya malzemesi: başlık,
/// görev metni, serbest ödül açıklaması ve DM'e özel notlar.
///
/// Not: sütun adı `text` Drift'in `text()` kurucusuyla çakıştığı için görev
/// metni `questText` olarak adlandırıldı.
class Quests extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get questText => text().withDefault(const Constant(''))();
  TextColumn get reward => text().withDefault(const Constant(''))();
  TextColumn get dmNotes => text().withDefault(const Constant(''))();

  BoolColumn get done => boolean().withDefault(const Constant(false))();

  /// Gorevi ustlenen karakterler: characterId listesi (JSON dizi).
  ///
  /// Kimin hangi isin pesinde oldugunu DM burada tutar; masada "bu gorev
  /// kimde?" sorusunun tek cevabi.
  TextColumn get targetsJson => text().withDefault(const Constant('[]'))();

  /// Gercek odul: para (bakir cinsinden) + esyalar `[{"name","magic"}]`.
  /// Serbest metin [reward] bunun yaninda aciklama olarak kalir.
  IntColumn get rewardCoinsCp => integer().withDefault(const Constant(0))();
  TextColumn get rewardItemsJson => text().withDefault(const Constant('[]'))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
