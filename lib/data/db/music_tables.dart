import 'package:drift/drift.dart';

/// Muzik listesi (klasor/baslik): "Savas", "Taverna", "Gerilim"...
///
/// Parcalar bir listeye ait OLMAK ZORUNDA DEGIL: liste silinince parcalar
/// silinmez, listesiz duruma duser (dosya kaybi olmaz).
class MusicPlaylists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// Ust kategori; `null` = kok liste.
  ///
  /// Tek kademe derinlik varsayilmiyor ama arayuz kok + bir alt kademe
  /// gosteriyor: "Savas > Boss" yeter, daha derini masada gezinmeyi
  /// zorlastirirdi.
  TextColumn get parentId => text().nullable()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Tek bir ses dosyasi.
///
/// [path] uygulama medya kokune GORELI yoldur (`music/<uuid>.mp3`) —
/// haritalar/portreler ile ayni desen; boylece kampanya klasoru tasinsa ya da
/// yedekten geri yuklense de kayitlar bozulmaz.
class MusicTracks extends Table {
  TextColumn get id => text()();

  /// Bagli oldugu liste; `null` = listesiz.
  TextColumn get playlistId => text().nullable()();

  TextColumn get title => text()();
  TextColumn get path => text()();

  /// Milisaniye. Ice aktarirken cozulebilirse yazilir, cozulemezse 0 kalir
  /// (arayuz 0'i "bilinmiyor" sayar).
  IntColumn get durationMs => integer().withDefault(const Constant(0))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
