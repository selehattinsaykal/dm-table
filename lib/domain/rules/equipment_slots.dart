import 'dart:convert';

/// Kusanilan ekipmanin vucutta kapladigi yer.
///
/// 5e'de resmi bir "slot" sistemi yok; masada herkesin kafasindaki kural
/// "ayni anda bir zirh, bir kask, bir cift bot" seklinde isliyor ve yuzuk/
/// kolye gibi ufak takilarda kimse sayi tutmuyor. Bu yuzden burada varsayilan
/// kapasiteler o beklentiyi kuruyor ama hepsi karakter bazinda
/// duzenlenebiliyor (bkz. [SlotCapacities]).
///
/// Yeni deger eklemek migration gerektirmiyor: sutun METIN ve cozumleme
/// [equipSlotFromName] uzerinden yapiliyor; taninmayan eski satirlar
/// [EquipSlot.other] sayilir.
enum EquipSlot {
  head,
  armor,
  cloak,
  gloves,
  boots,
  belt,
  amulet,
  ring,
  mainHand,
  offHand,
  other,
}

/// Kapasitesi bu olan yuvaya sinirsiz esya kusanilabilir.
const int unlimitedSlotCapacity = -1;

/// Yuva basina varsayilan kapasite.
///
/// Yuzuk/kolye ve "diger" bilerek sinirsiz: masada kimse takilari saymiyor,
/// sayan da [SlotCapacities.override] ile kendi sinirini koyabiliyor.
const Map<EquipSlot, int> kDefaultSlotCapacities = {
  EquipSlot.head: 1,
  EquipSlot.armor: 1,
  EquipSlot.cloak: 1,
  EquipSlot.gloves: 1,
  EquipSlot.boots: 1,
  EquipSlot.belt: 1,
  EquipSlot.amulet: unlimitedSlotCapacity,
  EquipSlot.ring: unlimitedSlotCapacity,
  EquipSlot.mainHand: 1,
  EquipSlot.offHand: 1,
  EquipSlot.other: unlimitedSlotCapacity,
};

/// Kagitta gorunecek sira: bastan asagi, sonra eller, sonra takilar.
const List<EquipSlot> kSlotDisplayOrder = [
  EquipSlot.head,
  EquipSlot.armor,
  EquipSlot.cloak,
  EquipSlot.gloves,
  EquipSlot.boots,
  EquipSlot.belt,
  EquipSlot.mainHand,
  EquipSlot.offHand,
  EquipSlot.amulet,
  EquipSlot.ring,
  EquipSlot.other,
];

/// Metinden yuva cozer; taninmazsa [EquipSlot.other].
EquipSlot equipSlotFromName(String? name) {
  if (name == null || name.isEmpty) return EquipSlot.other;
  for (final slot in EquipSlot.values) {
    if (slot.name == name) return slot;
  }
  return EquipSlot.other;
}

/// Karakterin yuva sinirlari: varsayilanlar + elle girilen degisiklikler.
///
/// Degisiklikler karakter satirinda JSON olarak duruyor; yalnizca varsayilandan
/// FARKLI olanlar yaziliyor ki ileride varsayilan degisirse elle
/// dokunulmamis yuvalar yeni degeri alsin.
class SlotCapacities {
  const SlotCapacities(this.overrides);

  const SlotCapacities.defaults() : overrides = const {};

  final Map<EquipSlot, int> overrides;

  factory SlotCapacities.fromJson(String? json) {
    if (json == null || json.trim().isEmpty) return const SlotCapacities({});
    final decoded = jsonDecode(json);
    if (decoded is! Map) return const SlotCapacities({});
    final out = <EquipSlot, int>{};
    for (final entry in decoded.entries) {
      final value = entry.value;
      if (value is! int) continue;
      final slot = equipSlotFromName('${entry.key}');
      // Taninmayan anahtar `other`a duserdi; sessizce yanlis yuvayi
      // ezmesin diye adi birebir eslesmeyen anahtarlar atlaniyor.
      if (slot.name != '${entry.key}') continue;
      out[slot] = value < 0 ? unlimitedSlotCapacity : value;
    }
    return SlotCapacities(out);
  }

  String toJson() =>
      jsonEncode({for (final e in overrides.entries) e.key.name: e.value});

  int operator [](EquipSlot slot) =>
      overrides[slot] ?? kDefaultSlotCapacities[slot] ?? unlimitedSlotCapacity;

  bool isUnlimited(EquipSlot slot) => this[slot] <= unlimitedSlotCapacity;

  /// Yuvada [current] kadar esya varken bir tane daha kusanilabilir mi?
  bool hasRoom(EquipSlot slot, int current) {
    final cap = this[slot];
    if (cap <= unlimitedSlotCapacity) return true;
    return current < cap;
  }

  SlotCapacities withCapacity(EquipSlot slot, int? capacity) {
    final next = Map<EquipSlot, int>.from(overrides);
    if (capacity == null) {
      next.remove(slot);
    } else {
      next[slot] = capacity < 0 ? unlimitedSlotCapacity : capacity;
    }
    return SlotCapacities(next);
  }
}

/// Bir esyanin hangi yuvaya girdigini tahmin eder.
///
/// Once yapisal veriye bakiyor (zirh kaydi, silah kaydi, kutuphane
/// kategorisi), sonra ada. Ad taramasi SART: SRD'de "Cloak of Protection"
/// gibi giyilebilir buyulu esyalarin tamami "Wondrous Item" kategorisinde,
/// yani kategori tek basina kolyeyi cizmeden ayiramiyor.
EquipSlot inferEquipSlot({
  required String name,
  String? categoryKey,
  Map<String, dynamic>? payload,
}) {
  final lower = name.toLowerCase();
  final category = (categoryKey ?? '').toLowerCase();

  final armor = payload?['armor'];
  if (armor is Map && armor['ac_base'] != null) {
    // Kalkan zirh degil, bosta kalan elde tasiniyor.
    if ('${armor['category'] ?? ''}'.toLowerCase() == 'shield' ||
        lower.contains('shield') ||
        lower.contains('kalkan')) {
      return EquipSlot.offHand;
    }
    return EquipSlot.armor;
  }
  if (category == 'shield') return EquipSlot.offHand;

  final weapon = payload?['weapon'];
  if (weapon is Map || category == 'weapon') return EquipSlot.mainHand;

  if (category == 'ring') return EquipSlot.ring;
  if (category == 'wand' || category == 'staff' || category == 'rod') {
    return EquipSlot.mainHand;
  }

  for (final entry in _hintPatterns.entries) {
    for (final pattern in entry.value) {
      if (pattern.hasMatch(lower)) return entry.key;
    }
  }
  return EquipSlot.other;
}

/// Ipuclarinin kelime araniyor haline cevrilmis kopyasi.
///
/// Duz `contains` yanlis esleme uretiyordu: "that" icindeki `hat` kagitta
/// duvar halisini kaska, "Horseshoes" icindeki `shoes` at nalini cizmeye
/// ceviriyordu.
///
/// Ingilizce ipuclari TAM SOZCUK ariyor ("hatchet" kaska gitmesin); Turkce
/// ipuclari yalnizca BASTA sinir ariyor, cunku ad cogu zaman ek tasiyor
/// ("miğferi", "kolyesi", "botları").
final Map<EquipSlot, List<RegExp>> _hintPatterns = {
  for (final slot in EquipSlot.values)
    if (_nameHints[slot] != null || _nameHintsTr[slot] != null)
      slot: [
        for (final needle in _nameHints[slot] ?? const [])
          RegExp('(^|[^a-z0-9])${RegExp.escape(needle)}([^a-z]|\$)'),
        for (final needle in _nameHintsTr[slot] ?? const [])
          RegExp('(^|[^a-zçğıöşü0-9])${RegExp.escape(needle)}'),
      ],
};

/// Kutuphanedeki INGILIZCE adlarda aranan ipuclari (tam sozcuk).
const Map<EquipSlot, List<String>> _nameHints = {
  EquipSlot.head: [
    'helm',
    'helmet',
    'hat',
    'cap of',
    'circlet',
    'crown',
    'headband',
    'mask',
    'goggles',
    'spectacles',
    'lenses',
    // "Eyes of the Eagle", "Eye of Vecna": goze takilan buyulu esyalar.
    'eyes of',
    'eye of',
  ],
  EquipSlot.cloak: ['cloak', 'cape', 'mantle', 'robe'],
  EquipSlot.gloves: [
    'glove',
    'gloves',
    'gauntlet',
    'gauntlets',
    'bracers',
    'wraps of',
  ],
  EquipSlot.boots: ['boots', 'slippers', 'sandals', 'shoes'],
  EquipSlot.belt: ['belt', 'girdle', 'sash'],
  EquipSlot.amulet: [
    'amulet',
    'necklace',
    'periapt',
    'pendant',
    'brooch',
    'medallion',
    'talisman',
  ],
  EquipSlot.ring: ['ring of', 'ring,'],
  EquipSlot.armor: ['armor', 'armour', 'mail'],
  EquipSlot.offHand: ['shield'],
};

/// Masada elle yazilan TURKCE adlarda aranan ipuclari (ek alabilir).
const Map<EquipSlot, List<String>> _nameHintsTr = {
  EquipSlot.head: ['kask', 'miğfer', 'migfer', 'taç', 'gözlük', 'gozluk'],
  EquipSlot.cloak: ['pelerin', 'harmani', 'harmanı', 'kaftan'],
  EquipSlot.gloves: ['eldiven', 'kolluk'],
  EquipSlot.boots: ['çizme', 'cizme', 'bot'],
  EquipSlot.belt: ['kemer', 'kuşak', 'kusak'],
  EquipSlot.amulet: ['kolye', 'muska', 'tılsım', 'tilsim'],
  EquipSlot.ring: ['yüzük', 'yuzuk'],
  EquipSlot.armor: ['zırh', 'zirh'],
  EquipSlot.offHand: ['kalkan'],
};
