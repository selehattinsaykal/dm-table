import 'package:drift/drift.dart';

import 'character_tables.dart';

/// Oyuncunun kendi tuttugu notlar (karaktere bagli).
///
/// Notlar oyuncu panelinde yazilir, DM sunucusunda saklanir ve yalnizca o
/// karakteri sahiplenen oyuncuya geri gonderilir -- baska oyunculara sizmaz.
/// Tum belge (basliklar + altindaki notlar) tek bir JSON olarak tutulur:
/// oyuncu belgeyi butunuyle duzenleyip gonderdigi icin normalize etmeye gerek
/// yok, es zamanli yazan ikinci bir taraf da yok.
class CharacterNotes extends Table {
  /// Sahibi karakter; her karakter icin tek satir.
  TextColumn get characterId => text().references(Characters, #id)();

  /// Not belgesi: `[{"id":..,"title":..,"entries":[{"id":..,"title":..,
  /// "body":..}]}]` JSON dizisi.
  TextColumn get documentJson => text().withDefault(const Constant('[]'))();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {characterId};
}
