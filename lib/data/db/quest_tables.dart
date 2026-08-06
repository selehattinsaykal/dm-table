import 'package:drift/drift.dart';

/// DM'in görevleri (Görevler sekmesi). Kalıcı; DM belirli oyunculara gösterir,
/// oyuncular kabul/ret verir. Oyuncuya yalnızca [title]/[questText]/[reward]
/// gider; [dmNotes] DM'e özeldir. [targetsJson] hedef characterId listesi,
/// [acceptancesJson] characterId→bool (kabul/ret) haritası.
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
  BoolColumn get shared => boolean().withDefault(const Constant(false))();

  /// Hedef oyuncular: characterId listesi (JSON dizi).
  TextColumn get targetsJson => text().withDefault(const Constant('[]'))();

  /// Kabul/ret: `{"<characterId>": true/false}` (JSON nesne).
  TextColumn get acceptancesJson => text().withDefault(const Constant('{}'))();

  /// Paylasim bicimi: `individual` (herkes kendi kabul/ret verir) ya da
  /// `vote` (hedefler arasinda oylama; %50+ kabul cikarsa gorev HERKESE
  /// verilir, altinda kalirsa kimse alamaz).
  TextColumn get shareMode =>
      text().withDefault(const Constant('individual'))();

  /// Oylama durumu (`vote` modunda): '' | 'pending' | 'passed' | 'failed'.
  TextColumn get voteStatus => text().withDefault(const Constant(''))();

  /// Gercek odul: para (bakir cinsinden) + esyalar `[{"name","magic"}]`.
  /// Serbest metin [reward] bunun yaninda aciklama olarak kalir.
  IntColumn get rewardCoinsCp => integer().withDefault(const Constant(0))();
  TextColumn get rewardItemsJson => text().withDefault(const Constant('[]'))();

  /// Gorev tamamlanınca acilan ORTAK ganimet havuzu (hazine pini ile ayni
  /// bicim: `{"coinsCp":N,"items":[{"id","name","magic"}]}`). Null ise odul
  /// henuz dagitima acilmadi. Tek havuz: bir esyayi kim once alirsa digerlerinde
  /// kaybolur; havuz bosalinca gorev silinir.
  TextColumn get rewardPoolJson => text().nullable()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
