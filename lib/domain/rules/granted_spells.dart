/// Alt siniflarin "daima hazir" buyu tablolarini ayristirir.
///
/// SRD, 2024 PHB ve 5etools'tan cevrilen kitaplarin hepsi bu bilgiyi ayni
/// sekilde, feature aciklamasinin icindeki markdown tablosuyla veriyor:
///
/// ```text
/// Table: Life Domain Spells
/// |Cleric Level|Prepared Spells|
/// |---|---|
/// |3|Aid, Bless, Cure Wounds, Lesser Restoration|
/// |5|Mass Healing Word, Revivify|
/// ```
///
/// Yapisal bir alan yok; kagida "hangi buyuler kendiliginden hazir" diye
/// bakabilmek icin metni okumak zorundayiz. Ayristirma tutmazsa bos donuyoruz
/// ve feature metni yine de kagitta duruyor -- yanlis buyu eklemektense hic
/// eklememek yeglenir.
library;

/// Sinif seviyesi -> o seviyede hazir gelen buyu adlari.
Map<int, List<String>> parseGrantedSpellTable(String desc) {
  final result = <int, List<String>>{};
  var inTable = false;

  for (final rawLine in desc.split('\n')) {
    final line = rawLine.trim();
    if (!line.startsWith('|')) {
      // Tablo bittiginde bir sonraki tabloyu beklemeye don.
      if (line.isEmpty) continue;
      inTable = false;
      continue;
    }

    final cells = line
        .split('|')
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();
    if (cells.length < 2) continue;

    // Baslik satiri: ilk sutun "... Level" olmali, yoksa bu bizim tablomuz
    // degil (or. sinif sayaci tablolari).
    if (!inTable) {
      if (cells.first.toLowerCase().endsWith('level')) inTable = true;
      continue;
    }
    if (cells.every((c) => RegExp(r'^-{2,}$').hasMatch(c))) continue;

    final level = int.tryParse(
      RegExp(r'\d+').firstMatch(cells[0])?.group(0) ?? '',
    );
    if (level == null) continue;

    final spells = cells[1]
        .split(',')
        .map(_cleanSpellName)
        .where((s) => s.isNotEmpty)
        .toList();
    if (spells.isEmpty) continue;
    (result[level] ??= <String>[]).addAll(spells);
  }
  return result;
}

/// "Detect Magic*" -> "Detect Magic". Yildiz "bu buyu su listeden" gibi
/// dipnotlari isaretliyor, ada dahil degil.
String _cleanSpellName(String value) => value
    .replaceAll('*', '')
    .replaceAll(RegExp(r'\(.*?\)'), '')
    .replaceAll(RegExp(r'^\s*and\s+', caseSensitive: false), '')
    .trim();
