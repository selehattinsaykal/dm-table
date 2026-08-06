/// Rastgele tablolar: zar at, satiri bul.
///
/// Saf Dart: Drift/Flutter bilmez, dogrudan test edilir. Tablo bir zar yuzune
/// (d4..d100) ve aralikli satirlara dayanir; "01-05: X, 06-20: Y" gibi klasik
/// D&D tablolarinin aynisi.
library;

import 'dart:math';

/// Tablonun bir satiri: [min]-[max] araligina denk gelen [text].
/// Aralik her iki uctan da DAHILDIR.
typedef RandomTableRow = ({int min, int max, String text});

/// Desteklenen zar yuzleri.
const List<int> kDiceSides = [4, 6, 8, 10, 12, 20, 100];

/// Atisa denk gelen satir; hicbiri kapsamiyorsa `null` (tabloda bosluk var).
RandomTableRow? rowFor(int roll, List<RandomTableRow> rows) {
  for (final row in rows) {
    if (roll >= row.min && roll <= row.max) return row;
  }
  return null;
}

/// Tabloya zar atar. [sides] gecersizse d20 varsayilir.
({int roll, RandomTableRow? row}) rollOn(
  List<RandomTableRow> rows,
  int sides, [
  Random? rng,
]) {
  final faces = kDiceSides.contains(sides) ? sides : 20;
  final roll = (rng ?? Random()).nextInt(faces) + 1;
  return (roll: roll, row: rowFor(roll, rows));
}

/// Editorde gosterilecek tutarsizlik uyarilari.
///
/// Kod dondurur, metin degil: cevirisi arayuz katmanina ait
/// (`encounter_budget.dart` ile ayni ayrim). Kodlar:
/// - `emptyRange` — min > max olan satir var.
/// - `outOfRange` — zar yuzunun disina tasan satir var.
/// - `overlap` — ayni sayiyi iki satir kapsiyor.
/// - `gap` — hic satirin kapsamadigi sayi var.
List<String> validateRows(List<RandomTableRow> rows, int sides) {
  final faces = kDiceSides.contains(sides) ? sides : 20;
  final issues = <String>{};
  if (rows.isEmpty) return const [];

  final covered = <int, int>{}; // sayi -> kac satir kapsiyor
  for (final row in rows) {
    if (row.min > row.max) {
      issues.add('emptyRange');
      continue;
    }
    if (row.min < 1 || row.max > faces) issues.add('outOfRange');
    for (var i = max(row.min, 1); i <= min(row.max, faces); i++) {
      covered[i] = (covered[i] ?? 0) + 1;
    }
  }

  if (covered.values.any((c) => c > 1)) issues.add('overlap');
  for (var i = 1; i <= faces; i++) {
    if (!covered.containsKey(i)) {
      issues.add('gap');
      break;
    }
  }
  return issues.toList()..sort();
}

/// Satir metinlerini zar yuzune ESIT dagitir ("Aralıkları dağıt" dugmesi).
///
/// Artik kalan yuzler bastan itibaren birer birer dagitilir; sonuc HER ZAMAN
/// 1..[sides] araligini tam kapsar (bosluk ya da cakisma birakmaz).
List<RandomTableRow> distributeEvenly(List<String> texts, int sides) {
  final faces = kDiceSides.contains(sides) ? sides : 20;
  if (texts.isEmpty) return const [];
  // Yuzden fazla satir varsa fazlasi sigmaz; ilk [faces] tanesi alinir.
  final list = texts.length > faces ? texts.sublist(0, faces) : texts;

  final base = faces ~/ list.length;
  final extra = faces % list.length;

  final out = <RandomTableRow>[];
  var cursor = 1;
  for (var i = 0; i < list.length; i++) {
    final span = base + (i < extra ? 1 : 0);
    out.add((min: cursor, max: cursor + span - 1, text: list[i]));
    cursor += span;
  }
  return out;
}
