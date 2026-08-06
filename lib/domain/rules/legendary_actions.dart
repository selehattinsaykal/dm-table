/// Efsanevi eylemler (legendary actions).
///
/// Saf Dart: ham Open5e canavar kaydini (`Monsters.dataJson`) okur.
///
/// **Veri setinde efsanevi eylemler IKI AYRI SEKILDE duruyor** ve ikisi
/// kesismiyor (dogrulandi: 505 canavarin 31'i A, 12'si B, ortak yok):
///
/// - **A** — `actions[]` icinde `action_type == 'LEGENDARY_ACTION'`
///   (`srd-2024` belgesi, 31 canavar).
/// - **B** — ust duzey `legendary_actions[]` dizisi (`mm-2024` belgesi,
///   12 canavar). `stat_block.dart` uzun sure yalnizca A'yi okudugu icin bu
///   12 canavarin efsanevi eylemleri HIC GORUNMUYORDU.
///
/// Ayrica veride **tur basina kac efsanevi eylem hakki oldugu YAZMIYOR**
/// (`legendary_desc` / "Legendary Action Uses" alanlari yok) — bu yuzden
/// [kDefaultLegendaryActionsPerRound] varsayilani kullanilir, DM degistirebilir.
library;

/// SRD'de veri olmadigi icin varsayilan tur basina hak.
const int kDefaultLegendaryActionsPerRound = 3;

/// Bir efsanevi eylem. [cost] veride yoksa 1 kabul edilir (veri setindeki tum
/// `legendary_action_cost` degerleri zaten 1).
typedef LegendaryAction = ({String name, String desc, int cost});

/// Canavarin efsanevi eylemleri; yoksa bos liste.
///
/// Her iki sekli de okur ve `order_in_statblock`'a gore siralar.
List<LegendaryAction> legendaryActionsOf(Map<String, dynamic> data) {
  final entries = <({LegendaryAction action, int order})>[];

  void add(Object? raw, {required bool requireType}) {
    if (raw is! List) return;
    for (final e in raw) {
      if (e is! Map) continue;
      if (requireType && e['action_type'] != 'LEGENDARY_ACTION') continue;
      final name = '${e['name'] ?? ''}'.trim();
      if (name.isEmpty) continue;
      final rawCost = e['legendary_action_cost'];
      final cost = rawCost is num ? rawCost.round() : 1;
      final rawOrder = e['order_in_statblock'];
      entries.add((
        action: (
          name: name,
          desc: '${e['desc'] ?? ''}'.trim(),
          cost: cost < 1 ? 1 : cost,
        ),
        order: rawOrder is num ? rawOrder.round() : 0,
      ));
    }
  }

  // Sekil A: actions[] icinde tipe gore suzulur.
  add(data['actions'], requireType: true);
  // Sekil B: ust duzey dizi -- burada zaten hepsi efsanevi.
  add(data['legendary_actions'], requireType: false);

  entries.sort((a, b) => a.order.compareTo(b.order));
  return [for (final e in entries) e.action];
}

/// `traits[]` icindeki "Legendary Resistance (3/Day, or 4/Day in Lair)"
/// adindan gunluk hakki (3) cikarir; trait yoksa `null`.
///
/// Veride bu bilgi yapisal DEGIL, yalnizca trait ADININ icinde metin olarak
/// duruyor; bu yuzden regex gerekiyor. "in Lair" varyanti bilincli olarak
/// YOK SAYILIR (masada inde olup olmadigini DM bilir, sayaci elle artirabilir).
int? legendaryResistanceOf(Map<String, dynamic> data) {
  final traits = data['traits'];
  if (traits is! List) return null;
  final pattern = RegExp(
    r'Legendary Resistance\s*\((\d+)\s*/\s*Day',
    caseSensitive: false,
  );
  for (final t in traits) {
    if (t is! Map) continue;
    final match = pattern.firstMatch('${t['name'] ?? ''}');
    if (match != null) return int.tryParse(match.group(1)!);
  }
  return null;
}
