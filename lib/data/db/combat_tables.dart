import 'package:drift/drift.dart';

/// Savastaki bir katilimcinin ne oldugu.
enum CombatantKind {
  /// Oyuncu karakteri; HP ve durumlar karakter kagidiyla ortak.
  player,

  /// Kutuphaneden ya da homebrew'dan gelen canavar.
  monster,

  /// Isim ve initiative disinda verisi olmayan hizli giris.
  adhoc,
}

class Encounters extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// Suan kimin sirasi: [Combatants.sortOrder] degeri.
  IntColumn get activeIndex => integer().withDefault(const Constant(0))();
  IntColumn get round => integer().withDefault(const Constant(1))();

  /// Savas basladi mi? Baslamadan once initiative duzenlenebiliyor.
  BoolColumn get started => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class Combatants extends Table {
  TextColumn get id => text()();
  TextColumn get encounterId => text().references(Encounters, #id)();

  TextColumn get kind => textEnum<CombatantKind>()();
  TextColumn get name => text()();

  /// Oyuncu karakterlerinde karakter kaydi, canavarlarda kutuphane anahtari.
  TextColumn get characterId => text().nullable()();
  TextColumn get monsterKey => text().nullable()();

  IntColumn get initiative => integer().withDefault(const Constant(0))();

  /// Inisiyatif atildi mi? Oyuncu katilimcilar savasa 0 (atilmamis) girer ve
  /// kendi panellerinden atar; canavar/adhoc eklenirken zaten atildigi icin
  /// varsayilan true. Atilmamis oyuncu, savas listesinde sayi yerine zar
  /// dugmesi gosterir.
  BoolColumn get initiativeRolled =>
      boolean().withDefault(const Constant(true))();

  /// Esit initiative'de sirayi sabitlemek icin; ayrica surukleyerek
  /// yeniden siralamada kullanilir.
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  IntColumn get hitPointsMax => integer().withDefault(const Constant(0))();
  IntColumn get hitPointsCurrent => integer().withDefault(const Constant(0))();
  IntColumn get temporaryHitPoints =>
      integer().withDefault(const Constant(0))();
  IntColumn get armorClass => integer().nullable()();

  /// Aktif durumlar (JSON dizisi).
  TextColumn get conditionsJson => text().withDefault(const Constant('[]'))();

  /// Tur basina efsanevi eylem hakki; null = bu katilimcinin efsanevi eylemi
  /// yok. Veri setinde hak sayisi YAZMADIGI icin canavar eklenirken
  /// [kDefaultLegendaryActionsPerRound] ile doldurulur, DM degistirebilir.
  IntColumn get legendaryMax => integer().nullable()();

  /// Bu turda harcanan efsanevi eylem; katilimcinin turu BASLAYINCA sifirlanir
  /// (D&D kurali: efsanevi eylemler canavarin turunun basinda tazelenir).
  IntColumn get legendarySpent => integer().withDefault(const Constant(0))();

  /// Gunluk efsanevi direnc (Legendary Resistance N/Day); null = yok.
  /// Tur basinda SIFIRLANMAZ -- gunluk bir kaynak, DM elle yeniler.
  IntColumn get legendaryResistMax => integer().nullable()();
  IntColumn get legendaryResistSpent =>
      integer().withDefault(const Constant(0))();

  /// Konsantrasyon takibi: DM'in en cok unuttugu sey.
  BoolColumn get concentrating =>
      boolean().withDefault(const Constant(false))();
  TextColumn get concentrationNote => text().nullable()();

  /// Oyunculardan gizli tutulan katilimcilar (surpriz canavarlar).
  BoolColumn get hiddenFromPlayers =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get defeated => boolean().withDefault(const Constant(false))();
  TextColumn get note => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}
