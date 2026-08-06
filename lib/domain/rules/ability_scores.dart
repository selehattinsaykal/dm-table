/// Yetenek puanindan modifier.
///
/// Kural asagi yuvarlamadir; Dart'in `~/` operatoru sifira dogru kirptigi
/// icin 10'un altindaki tek sayilarda yanlis sonuc verir (7 -> -1 yerine -2
/// olmali), o yuzden acikca `floor()` kullaniliyor.
int abilityModifier(int score) => ((score - 10) / 2).floor();

/// Modifier'i isaretli metne cevirir: 2 -> "+2", -1 -> "-1".
String formatModifier(int value) => value >= 0 ? '+$value' : '$value';

/// Karakter seviyesine gore proficiency bonus.
int proficiencyBonus(int characterLevel) => 2 + ((characterLevel - 1) ~/ 4);

/// 2024 kurallarinda point buy maliyet tablosu.
const pointBuyCosts = <int, int>{
  8: 0,
  9: 1,
  10: 2,
  11: 3,
  12: 4,
  13: 5,
  14: 7,
  15: 9,
};

/// Point buy icin toplam butce.
const pointBuyBudget = 27;

/// Standart dizi.
const standardArray = <int>[15, 14, 13, 12, 10, 8];
