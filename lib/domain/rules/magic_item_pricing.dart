/// Buyulu esya fiyatlandirmasi.
///
/// SRD 5.2 buyulu esyalar icin fiyat yayinlamaz (API'de `cost` alani tumunde
/// "0.00" gelir), ama DM'in magaza kurabilmesi icin bir sayiya ihtiyaci var.
/// Burasi nadirlige gore ONERILEN bir aralik uretir; kesin kural degildir ve
/// DM her esyada ya da magaza bazinda ezebilir.
library;

/// Nadirlik anahtari -> onerilen fiyat araligi (altin cinsinden).
const _rangesGp = <String, ({int min, int max})>{
  'common': (min: 50, max: 100),
  'uncommon': (min: 101, max: 500),
  'rare': (min: 501, max: 5000),
  'very-rare': (min: 5001, max: 50000),
  'legendary': (min: 50001, max: 200000),
  'artifact': (min: 200001, max: 500000),
};

/// Fiyatlar bakir (cp) tamsayisi olarak saklanir: 1 gp = 100 cp.
const copperPerGold = 100;

/// [rarityKey] icin onerilen fiyat araligi (cp).
({int min, int max})? suggestedRangeCp(String? rarityKey) {
  final r = _rangesGp[rarityKey];
  if (r == null) return null;
  return (min: r.min * copperPerGold, max: r.max * copperPerGold);
}

/// Magaza kurarken varsayilan olarak kullanilan tek fiyat: aralik ortasi.
///
/// Attunement gerektiren esyalar biraz daha degerli kabul edilir; bu tamamen
/// bir kolaylik varsayimi, kural degil.
int? suggestedPriceCp(String? rarityKey, {bool requiresAttunement = false}) {
  final range = suggestedRangeCp(rarityKey);
  if (range == null) return null;
  final mid = (range.min + range.max) ~/ 2;
  return requiresAttunement ? (mid * 1.2).round() : mid;
}

/// Bakir tutari oyuncuya gosterilecek metne cevirir: 1234 cp -> "12 gp 3 sp 4 cp".
String formatCoins(int cp) {
  if (cp == 0) return '0 gp';
  final gp = cp ~/ 100;
  final sp = (cp % 100) ~/ 10;
  final rem = cp % 10;
  return [
    if (gp > 0) '$gp gp',
    if (sp > 0) '$sp sp',
    if (rem > 0) '$rem cp',
  ].join(' ');
}

/// Open5e'nin altin cinsinden ondalikli metin fiyatini ("25.00") bakira cevirir.
int? parseCostToCp(String? cost) {
  if (cost == null || cost.isEmpty) return null;
  final gp = double.tryParse(cost);
  if (gp == null) return null;
  final cp = (gp * copperPerGold).round();
  // SRD buyulu esyalarda "0.00" = fiyat yok, bedava degil.
  return cp == 0 ? null : cp;
}
