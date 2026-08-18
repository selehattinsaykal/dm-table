import 'dart:convert';

/// Karsilasmanin DM BRIFINGI: savasi masada yonetmek icin gereken, initiative
/// listesinin disinda kalan her sey.
///
/// Alanlar AI karsilasma uretecinden (`encounter_generator.dart`) birebir
/// gelir ama oraya bagli DEGILDIR: DM elle de doldurabilir. Hepsi serbest
/// metin ve hepsi bos olabilir; panel bos alani hic cizmez.
typedef EncounterBriefing = ({
  /// Oyunculara okunacak giris/sahne.
  String summary,

  /// Savasin KAZANMA KOSULU. "Hepsini oldur" disinda bir hedef varsa savasin
  /// nasil bittigi burada yazar.
  String objective,

  /// Canavarlarin nasil savastigi.
  String tactics,

  /// Arazi, engel, aydinlatma.
  String terrain,

  /// Savas uzarsa/gurultu olursa ne gelir.
  String reinforcements,

  /// Parti zorlanirsa nasil hafifletilir, kolay gecerse nasil sertlestirilir.
  String scaling,

  /// Yalniz DM'in bilecegi diger seyler.
  String dmNotes,
});

/// Tamamen bos brifing (hicbir alan dolu degil).
const EncounterBriefing emptyEncounterBriefing = (
  summary: '',
  objective: '',
  tactics: '',
  terrain: '',
  reinforcements: '',
  scaling: '',
  dmNotes: '',
);

/// Brifingin gosterilecek hicbir alani var mi.
bool briefingIsEmpty(EncounterBriefing b) =>
    b.summary.isEmpty &&
    b.objective.isEmpty &&
    b.tactics.isEmpty &&
    b.terrain.isEmpty &&
    b.reinforcements.isEmpty &&
    b.scaling.isEmpty &&
    b.dmNotes.isEmpty;

EncounterBriefing encounterBriefingFromJson(String? raw) {
  if (raw == null || raw.trim().isEmpty) return emptyEncounterBriefing;
  try {
    final map = jsonDecode(raw);
    if (map is! Map) return emptyEncounterBriefing;
    String f(String k) => '${map[k] ?? ''}'.trim();
    return (
      summary: f('summary'),
      objective: f('objective'),
      tactics: f('tactics'),
      terrain: f('terrain'),
      reinforcements: f('reinforcements'),
      scaling: f('scaling'),
      dmNotes: f('dmNotes'),
    );
  } catch (_) {
    // Bozuk kayit karsilasmayi acilmaz yapmamali.
    return emptyEncounterBriefing;
  }
}

String encounterBriefingToJson(EncounterBriefing b) => jsonEncode({
  'summary': b.summary,
  'objective': b.objective,
  'tactics': b.tactics,
  'terrain': b.terrain,
  'reinforcements': b.reinforcements,
  'scaling': b.scaling,
  'dmNotes': b.dmNotes,
});

/// Ganimetteki tek bir esya.
///
/// [itemKey]/[magicItemKey] KUTUPHANE anahtaridir: doluysa esya SRD/homebrew
/// kataloğunda gercekten var demektir ve keseye konarken tam kaydiyla gider.
/// Ikisi de null ise esya yalnizca bir ISIMDIR (AI uydurmus ya da DM elle
/// yazmis olabilir) — arayuz bunu acikca isaretler.
typedef EncounterLootItem = ({
  String id,
  String name,
  bool magic,
  String? itemKey,
  String? magicItemKey,
});

/// Bir esya kutuphaneye cozuldu mu.
bool lootItemResolved(EncounterLootItem item) =>
    item.itemKey != null || item.magicItemKey != null;

/// Karsilasmadan cikacak ganimet: para + esyalar.
typedef EncounterLoot = ({int coinsCp, List<EncounterLootItem> items});

const EncounterLoot emptyEncounterLoot = (
  coinsCp: 0,
  items: <EncounterLootItem>[],
);

bool lootIsEmpty(EncounterLoot loot) => loot.coinsCp <= 0 && loot.items.isEmpty;

EncounterLoot encounterLootFromJson(String? raw) {
  if (raw == null || raw.trim().isEmpty) return emptyEncounterLoot;
  try {
    final map = jsonDecode(raw);
    if (map is! Map) return emptyEncounterLoot;
    final coins = map['coinsCp'];
    final items = <EncounterLootItem>[];
    for (final e in (map['items'] as List? ?? const [])) {
      if (e is! Map) continue;
      final name = '${e['name'] ?? ''}'.trim();
      if (name.isEmpty) continue;
      String? key(String k) {
        final v = e[k];
        if (v == null) return null;
        final s = '$v'.trim();
        return s.isEmpty ? null : s;
      }

      items.add((
        id: '${e['id'] ?? ''}'.trim(),
        name: name,
        magic: e['magic'] == true,
        itemKey: key('itemKey'),
        magicItemKey: key('magicItemKey'),
      ));
    }
    return (
      coinsCp: coins is num ? coins.round() : int.tryParse('$coins') ?? 0,
      items: items,
    );
  } catch (_) {
    return emptyEncounterLoot;
  }
}

String encounterLootToJson(EncounterLoot loot) => jsonEncode({
  'coinsCp': loot.coinsCp,
  'items': [
    for (final i in loot.items)
      {
        'id': i.id,
        'name': i.name,
        'magic': i.magic,
        'itemKey': i.itemKey,
        'magicItemKey': i.magicItemKey,
      },
  ],
});
