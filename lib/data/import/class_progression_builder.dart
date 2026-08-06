/// SRD 5.2 sinif kayitlarindan seviye seviye ilerleme tablosu turetir.
///
/// Open5e, her sinifin kitaptaki tablosunu `features` listesinde "sanal"
/// feature'lar olarak tasir: `PROFICIENCY_BONUS` bir sutun, her buyu yuvasi
/// seviyesi ("1st", "2nd", ...) ayri bir `SPELL_SLOTS` sutunu, sinifa ozel
/// sayaclar ise `CLASS_TABLE_DATA`. Gercek yetenekler `CLASS_LEVEL_FEATURE`
/// olarak gelir ve `gained_at` icinde hangi seviyelerde kazanildigini soyler.
///
/// Burasi o dagink yapiyi (sinif, seviye) -> tek satir haline getirir.
library;

import 'dart:convert';

/// Tablo sutunu tasiyan feature tipleri.
const _proficiencyBonus = 'PROFICIENCY_BONUS';
const _spellSlots = 'SPELL_SLOTS';
const _classTableData = 'CLASS_TABLE_DATA';
const _levelFeature = 'CLASS_LEVEL_FEATURE';

/// Buyu yuvasi sutun adlari ("1st", "2nd", ...) -> yuva seviyesi.
const _slotColumnToLevel = <String, int>{
  '1st': 1,
  '2nd': 2,
  '3rd': 3,
  '4th': 4,
  '5th': 5,
  '6th': 6,
  '7th': 7,
  '8th': 8,
  '9th': 9,
};

/// Tek bir sinif seviyesinin ilerleme satiri.
class ProgressionRow {
  const ProgressionRow({
    required this.classKey,
    required this.level,
    required this.proficiencyBonus,
    required this.spellSlots,
    required this.classTable,
    required this.featureKeys,
  });

  final String classKey;
  final int level;
  final int proficiencyBonus;

  /// Yuva seviyesi -> adet. Buyu yapmayan siniflarda bos.
  final Map<int, int> spellSlots;

  /// Sinifa ozel sutunlar, or. `{"Rages": "3", "Rage Damage": "+2"}`.
  final Map<String, String> classTable;

  /// Bu seviyede kazanilan feature anahtarlari.
  final List<String> featureKeys;

  String get spellSlotsJson =>
      jsonEncode(spellSlots.map((k, v) => MapEntry('$k', v)));
  String get classTableJson => jsonEncode(classTable);
  String get featureKeysJson => jsonEncode(featureKeys);
}

/// [classJson] tek bir sinifin (ya da alt sinifin) Open5e kaydidir.
///
/// Alt siniflar kendi tablolarini tasimadigi icin yalnizca `gained_at`
/// bilgisinden feature dagilimi cikarilir; PB ve yuvalar ana siniftan gelir.
List<ProgressionRow> buildProgression(Map<String, dynamic> classJson) {
  final classKey = classJson['key'] as String;
  final features = (classJson['features'] as List? ?? const [])
      .cast<Map<String, dynamic>>();

  final pbByLevel = <int, int>{};
  final slotsByLevel = <int, Map<int, int>>{};
  final tableByLevel = <int, Map<String, String>>{};
  final featuresByLevel = <int, List<String>>{};

  for (final feature in features) {
    final type = feature['feature_type'] as String?;
    final name = feature['name'] as String? ?? '';
    final key = feature['key'] as String? ?? name;
    final columns = (feature['data_for_class_table'] as List? ?? const [])
        .cast<Map<String, dynamic>>();

    switch (type) {
      case _proficiencyBonus:
        for (final c in columns) {
          final level = c['level'] as int;
          // "+2" seklinde geliyor.
          final value = int.tryParse(
            (c['column_value'] as String? ?? '').replaceAll('+', '').trim(),
          );
          if (value != null) pbByLevel[level] = value;
        }

      case _spellSlots:
        final slotLevel = _slotColumnToLevel[name];
        // Tanimadigimiz bir sutun adi cikarsa sessizce atlamak yerine
        // gormezden geliyoruz; Warlock'un Pact Magic tablosu ayri isimlerle
        // gelebiliyor ve o zaten classTable'a dusuyor.
        if (slotLevel == null) {
          _collectTableColumn(tableByLevel, name, columns);
          continue;
        }
        for (final c in columns) {
          final level = c['level'] as int;
          final count = int.tryParse(
            (c['column_value'] as String? ?? '').trim(),
          );
          if (count != null && count > 0) {
            (slotsByLevel[level] ??= <int, int>{})[slotLevel] = count;
          }
        }

      case _classTableData:
        _collectTableColumn(tableByLevel, name, columns);

      case _levelFeature:
      default:
        for (final g
            in (feature['gained_at'] as List? ?? const [])
                .cast<Map<String, dynamic>>()) {
          final level = g['level'] as int?;
          if (level != null) {
            (featuresByLevel[level] ??= <String>[]).add(key);
          }
        }
    }
  }

  // Bir sinifin kac seviyesi oldugunu tablodan degil, gorulen en yuksek
  // seviyeden cikariyoruz; SRD'de hepsi 20 ama alt siniflar 3'ten baslar.
  final maxLevel = [
    ...pbByLevel.keys,
    ...slotsByLevel.keys,
    ...tableByLevel.keys,
    ...featuresByLevel.keys,
  ].fold<int>(0, (a, b) => a > b ? a : b);

  return [
    for (var level = 1; level <= maxLevel; level++)
      ProgressionRow(
        classKey: classKey,
        level: level,
        proficiencyBonus: pbByLevel[level] ?? proficiencyBonusForLevel(level),
        spellSlots: slotsByLevel[level] ?? const {},
        classTable: tableByLevel[level] ?? const {},
        // Kopya uzerinde siralaniyor: feature kazanilmayan seviyelerde
        // sabit bos liste donuyor ve o degistirilemez.
        featureKeys: [...?featuresByLevel[level]]..sort(),
      ),
  ];
}

void _collectTableColumn(
  Map<int, Map<String, String>> target,
  String columnName,
  List<Map<String, dynamic>> columns,
) {
  for (final c in columns) {
    final level = c['level'] as int?;
    final value = c['column_value'] as String?;
    if (level == null || value == null || value.isEmpty) continue;
    (target[level] ??= <String, String>{})[columnName] = value;
  }
}

/// Karakter seviyesine gore proficiency bonus.
///
/// Sinif tablosunda eksik satir olursa geri dusulur; multiclass'ta da toplam
/// karakter seviyesinden hesaplanmasi gerektigi icin ayri bir fonksiyon.
int proficiencyBonusForLevel(int characterLevel) =>
    2 + ((characterLevel - 1) ~/ 4);
