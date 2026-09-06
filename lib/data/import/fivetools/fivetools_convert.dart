/// 5etools kayitlarini uygulamanin ic bicimine cevirir.
///
/// **Neden bir cevirici gerekiyor:** uygulamanin butun ayristiricilari,
/// detay ekranlari ve kural hesaplari Open5e'nin sekline gore yazilmis
/// (`ability_scores`, `challenge_rating`, `actions[].desc`...). 5etools ise
/// bambaska bir sema kullaniyor (`str`, `cr`, `action[].entries`). Ikisini
/// tabloda yan yana tutabilmek icin donusum ICE AKTARIMDA yapiliyor; aksi
/// halde her ekranin iki bicimi birden bilmesi gerekirdi.
///
/// Saf Dart: veritabani bilmez, bu yuzden tamami test edilebilir.
library;

import 'fivetools_text.dart';

/// Cevrilmis tek bir kayit: tablo kolonlari + `dataJson` govdesi.
typedef ConvertedEntry = ({
  String key,
  String name,
  Map<String, dynamic> data,
  double challengeRating,
  int? armorClass,
  int? hitPoints,
  String? size,
  String? creatureType,
  int? level,
  String? school,
  String? rarity,
  String? category,
});

/// 5etools boyut kodlari.
const _sizes = {
  'T': 'Tiny',
  'S': 'Small',
  'M': 'Medium',
  'L': 'Large',
  'H': 'Huge',
  'G': 'Gargantuan',
};

/// 5etools buyu okulu kodlari.
const _schools = {
  'A': 'Abjuration',
  'C': 'Conjuration',
  'D': 'Divination',
  'E': 'Enchantment',
  'V': 'Evocation',
  'I': 'Illusion',
  'N': 'Necromancy',
  'T': 'Transmutation',
};

/// 5etools hizalama kodlari.
const _alignments = {
  'L': 'lawful',
  'N': 'neutral',
  'C': 'chaotic',
  'G': 'good',
  'E': 'evil',
  'U': 'unaligned',
  'A': 'any alignment',
};

/// Ice aktarilan kaydin anahtari.
///
/// Kaynak kodu (PHB, MM...) anahtara GIRIYOR: ayni adli iki kayit farkli
/// kitaplardan gelebiliyor ve biri digerini ezmemeli.
String fiveToolsKey(String kind, String name, String? source) {
  final slug = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  final suffix = (source ?? '').toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9]+'),
    '',
  );
  return 'ft_${kind}_$slug${suffix.isEmpty ? '' : '_$suffix'}';
}

// --- Canavar ---------------------------------------------------------------

/// 5etools canavarini Open5e sekline cevirir.
ConvertedEntry? convertMonster(Map<String, dynamic> raw) {
  final name = _text(raw['name']);
  if (name.isEmpty) return null;
  final source = raw['source'] as String?;

  final scores = {
    'strength': _int(raw['str']) ?? 10,
    'dexterity': _int(raw['dex']) ?? 10,
    'constitution': _int(raw['con']) ?? 10,
    'intelligence': _int(raw['int']) ?? 10,
    'wisdom': _int(raw['wis']) ?? 10,
    'charisma': _int(raw['cha']) ?? 10,
  };
  final cr = _challengeRating(raw['cr']);
  final hp = _hitPoints(raw['hp']);
  final key = fiveToolsKey('monster', name, source);

  final data = <String, dynamic>{
    'key': key,
    'name': name,
    'desc': '',
    'size': {'name': _size(raw['size'])},
    'type': {'name': _creatureType(raw['type'])},
    'alignment': _alignment(raw['alignment']),
    'challenge_rating': cr,
    'armor_class': _armorClass(raw['ac']) ?? 10,
    'hit_points': hp.average,
    'hit_dice': hp.formula,
    'speed': _speed(raw['speed']),
    'ability_scores': scores,
    'modifiers': {
      for (final entry in scores.entries)
        entry.key: ((entry.value - 10) / 2).floor(),
    },
    'actions': [
      ..._namedEntries(raw['action'], 'ACTION'),
      ..._namedEntries(raw['bonus'], 'BONUS'),
      ..._namedEntries(raw['reaction'], 'REACTION'),
    ],
    'traits': _namedEntries(raw['trait'], null),
    'legendary_actions': _namedEntries(raw['legendary'], 'LEGENDARY'),
    'senses': _joinList(raw['senses']),
    'languages': _joinList(raw['languages']),
    'source': source,
  };

  return (
    key: key,
    name: name,
    data: data,
    challengeRating: cr,
    armorClass: _armorClass(raw['ac']),
    hitPoints: hp.average,
    size: _size(raw['size']),
    creatureType: _creatureType(raw['type']),
    level: null,
    school: null,
    rarity: null,
    category: null,
  );
}

/// `ac` alani sayi, liste ya da `{ac, from}` nesnesi olabiliyor.
int? _armorClass(Object? node) {
  if (node is num) return node.toInt();
  if (node is List && node.isNotEmpty) return _armorClass(node.first);
  if (node is Map) return _int(node['ac']);
  return null;
}

/// `hp` alani `{average, formula}` ya da `{special: "..."}`.
({int average, String formula}) _hitPoints(Object? node) {
  if (node is num) return (average: node.toInt(), formula: '');
  if (node is Map) {
    final map = node.cast<String, dynamic>();
    final average = _int(map['average']);
    if (average != null) {
      return (average: average, formula: _text(map['formula']));
    }
    // `special` serbest metin ("Equal to the summoner's level"); sayiya
    // cevrilemiyorsa 1 birakiliyor -- 0 can savas ekranini bozar.
    return (average: 1, formula: _text(map['special']));
  }
  return (average: 1, formula: '');
}

/// `cr` alani "1/2", "5" ya da `{cr: "5", lair: "6"}`.
double _challengeRating(Object? node) {
  if (node is num) return node.toDouble();
  if (node is Map) return _challengeRating(node['cr']);
  if (node is! String) return 0;
  final text = node.trim();
  if (text.contains('/')) {
    final parts = text.split('/');
    final a = double.tryParse(parts.first) ?? 0;
    final b = double.tryParse(parts.last) ?? 1;
    return b == 0 ? 0 : a / b;
  }
  return double.tryParse(text) ?? 0;
}

String _size(Object? node) {
  if (node is List && node.isNotEmpty) return _size(node.first);
  final code = _text(node).toUpperCase();
  return _sizes[code] ?? (code.isEmpty ? 'Medium' : code);
}

String _creatureType(Object? node) {
  if (node is String) return _capitalize(node);
  if (node is Map) {
    final map = node.cast<String, dynamic>();
    final base = _capitalize(_text(map['type']));
    final tags = map['tags'];
    if (tags is List && tags.isNotEmpty) {
      final rendered = tags
          .map((t) => t is Map ? _text(t['tag']) : _text(t))
          .where((t) => t.isNotEmpty)
          .join(', ');
      if (rendered.isNotEmpty) return '$base ($rendered)';
    }
    return base;
  }
  return 'Humanoid';
}

/// `alignment: ["L","G"]` -> "lawful good".
String _alignment(Object? node) {
  if (node is! List) return _text(node);
  final parts = <String>[];
  for (final item in node) {
    if (item is String) {
      parts.add(_alignments[item.toUpperCase()] ?? item);
    } else if (item is Map) {
      // `{alignment: [...], chance: 50}` -> ic listeyi acar.
      parts.add(_alignment(item['alignment']));
    }
  }
  return parts.where((p) => p.isNotEmpty).join(' ');
}

/// `speed: {walk: 30, fly: {number: 60, condition: "(hover)"}}`.
Map<String, dynamic> _speed(Object? node) {
  final out = <String, dynamic>{'unit': 'feet'};
  if (node is num) {
    out['walk'] = node.toInt();
    return out;
  }
  if (node is! Map) {
    out['walk'] = 30;
    return out;
  }
  for (final entry in node.cast<String, dynamic>().entries) {
    final value = entry.value;
    if (value is num) {
      out[entry.key] = value.toInt();
    } else if (value is Map) {
      final number = _int(value['number']);
      if (number != null) out[entry.key] = number;
    }
  }
  out.putIfAbsent('walk', () => 0);
  return out;
}

/// `[{name, entries}]` -> Open5e'nin `{name, desc, action_type}` listesi.
List<Map<String, dynamic>> _namedEntries(Object? node, String? actionType) {
  if (node is! List) return const [];
  return [
    for (final item in node)
      if (item is Map)
        {
          'name': _text(item['name']),
          'desc': renderEntries(item['entries'] ?? item['entry']),
          'action_type': ?actionType,
          'attacks': <dynamic>[],
        },
  ];
}

String _joinList(Object? node) {
  if (node is String) return stripTags(node);
  if (node is! List) return '';
  return node.map((item) => stripTags('$item')).join(', ');
}

// --- Buyu ------------------------------------------------------------------

ConvertedEntry? convertSpell(Map<String, dynamic> raw) {
  final name = _text(raw['name']);
  if (name.isEmpty) return null;
  final source = raw['source'] as String?;
  final key = fiveToolsKey('spell', name, source);
  final level = _int(raw['level']) ?? 0;
  final school = _schools[_text(raw['school']).toUpperCase()] ?? '';

  final body = renderEntries(raw['entries']);
  final higher = renderEntries(raw['entriesHigherLevel']);

  final data = <String, dynamic>{
    'key': key,
    'name': name,
    'desc': body,
    'higher_level': higher,
    'level': level,
    'school': {'name': school},
    'casting_time': _castingTime(raw['time']),
    'range_text': _range(raw['range']),
    'components': _components(raw['components']),
    'duration': _duration(raw['duration']),
    'concentration': _isConcentration(raw['duration']),
    'ritual': (raw['meta'] as Map?)?['ritual'] == true,
    'classes': _spellClasses(raw),
    'source': source,
  };

  return (
    key: key,
    name: name,
    data: data,
    challengeRating: 0,
    armorClass: null,
    hitPoints: null,
    size: null,
    creatureType: null,
    level: level,
    school: school,
    rarity: null,
    category: null,
  );
}

String _castingTime(Object? node) {
  if (node is List && node.isNotEmpty) return _castingTime(node.first);
  if (node is! Map) return _text(node);
  final map = node.cast<String, dynamic>();
  final number = _int(map['number']) ?? 1;
  final unit = _text(map['unit']);
  final condition = _text(map['condition']);
  final base = number == 1 ? '1 $unit' : '$number ${unit}s';
  return condition.isEmpty ? base : '$base, $condition';
}

String _range(Object? node) {
  if (node is! Map) return _text(node);
  final map = node.cast<String, dynamic>();
  final type = _text(map['type']);
  final distance = map['distance'];
  if (distance is! Map) return _capitalize(type);
  final d = distance.cast<String, dynamic>();
  final unit = _text(d['type']);
  final amount = _int(d['amount']);
  final range = amount == null ? _capitalize(unit) : '$amount $unit';
  // "radius"/"cone" gibi sekiller menzilin ARDINA yaziliyor: "Self (30 ft
  // cone)" 5etools'ta iki ayri alanda duruyor.
  return type == 'point' || type.isEmpty ? range : '$range ($type)';
}

String _components(Object? node) {
  if (node is! Map) return _text(node);
  final map = node.cast<String, dynamic>();
  final parts = <String>[];
  if (map['v'] == true) parts.add('V');
  if (map['s'] == true) parts.add('S');
  final material = map['m'];
  if (material != null) {
    final text = material is Map
        ? _text(material['text'])
        : stripTags('$material');
    parts.add(text.isEmpty ? 'M' : 'M ($text)');
  }
  return parts.join(', ');
}

String _duration(Object? node) {
  if (node is List && node.isNotEmpty) return _duration(node.first);
  if (node is! Map) return _text(node);
  final map = node.cast<String, dynamic>();
  final type = _text(map['type']);
  if (type == 'instant') return 'Instantaneous';
  if (type == 'permanent') return 'Permanent';
  final duration = map['duration'];
  if (duration is! Map) return _capitalize(type);
  final d = duration.cast<String, dynamic>();
  final amount = _int(d['amount']) ?? 1;
  final unit = _text(d['type']);
  final base = amount == 1 ? '1 $unit' : '$amount ${unit}s';
  return map['concentration'] == true ? 'Concentration, up to $base' : base;
}

bool _isConcentration(Object? node) {
  if (node is List) return node.any(_isConcentration);
  if (node is Map) return node['concentration'] == true;
  return false;
}

/// Buyunun sinif listesi; 5etools bunu birkac ayri yerde tasiyor.
String _spellClasses(Map<String, dynamic> raw) {
  final classes = raw['classes'];
  if (classes is! Map) return '';
  final out = <String>{};

  void collect(Object? node) {
    if (node is! List) return;
    for (final item in node) {
      if (item is Map) {
        final name = _text(item['name']);
        if (name.isNotEmpty) out.add(name);
      }
    }
  }

  final map = classes.cast<String, dynamic>();
  collect(map['fromClassList']);
  collect(map['fromClassListVariant']);
  final subclasses = map['fromSubclass'];
  if (subclasses is List) {
    for (final item in subclasses) {
      if (item is! Map) continue;
      final parent = item['class'];
      if (parent is Map) {
        final name = _text(parent['name']);
        if (name.isNotEmpty) out.add(name);
      }
    }
  }
  return out.join(', ');
}

// --- Esya ------------------------------------------------------------------

/// 5etools esya turu kodlari (en yaygin olanlar).
const _itemTypes = {
  'M': 'Melee Weapon',
  'R': 'Ranged Weapon',
  'A': 'Ammunition',
  'LA': 'Light Armor',
  'MA': 'Medium Armor',
  'HA': 'Heavy Armor',
  'S': 'Shield',
  'P': 'Potion',
  'SC': 'Scroll',
  'RD': 'Rod',
  'RG': 'Ring',
  'WD': 'Wand',
  'ST': 'Staff',
  'W': 'Wondrous Item',
  'G': 'Adventuring Gear',
  'AT': 'Artisan Tool',
  'T': 'Tool',
  'INS': 'Instrument',
  'GS': 'Gaming Set',
  'MNT': 'Mount',
  'VEH': 'Vehicle',
  'TG': 'Trade Good',
  'FD': 'Food',
  // Ham dize: tek tirnak icinde `$` Dart'ta enterpolasyon baslatiyor.
  r'$': 'Treasure',
};

ConvertedEntry? convertItem(Map<String, dynamic> raw) {
  final name = _text(raw['name']);
  if (name.isEmpty) return null;
  final source = raw['source'] as String?;
  final magic =
      raw['rarity'] != null && _text(raw['rarity']).toLowerCase() != 'none';
  final key = fiveToolsKey(magic ? 'magicitem' : 'item', name, source);

  // Tur kodu "M|XPHB" gibi kaynak ekiyle gelebiliyor.
  final typeCode = _text(raw['type']).split('|').first.toUpperCase();
  final category = _itemTypes[typeCode] ?? (typeCode.isEmpty ? '' : typeCode);
  final rarity = magic ? _capitalize(_text(raw['rarity'])) : null;

  final data = <String, dynamic>{
    'key': key,
    'name': name,
    'desc': renderEntries(raw['entries']),
    'category': category,
    'rarity': rarity,
    'requires_attunement': raw['reqAttune'] != null,
    'cost': _int(raw['value']),
    'weight': raw['weight'],
    'source': source,
  };

  return (
    key: key,
    name: name,
    data: data,
    challengeRating: 0,
    armorClass: null,
    hitPoints: null,
    size: null,
    creatureType: null,
    level: null,
    school: null,
    rarity: rarity,
    category: category,
  );
}

// --- Tur / Gecmis / Feat ---------------------------------------------------

ConvertedEntry? convertRace(Map<String, dynamic> raw) => _simple(
  raw,
  'species',
  extra: {
    'traits': [
      {'type': 'SIZE', 'desc': 'Size: ${_size(raw['size'])}'},
      {'type': 'SPEED', 'desc': 'Speed: ${_speedText(raw['speed'])}'},
      ..._traitEntries(raw['entries']),
    ],
  },
);

ConvertedEntry? convertBackground(Map<String, dynamic> raw) => _simple(
  raw,
  'background',
  extra: {'benefits': _traitEntries(raw['entries'])},
);

ConvertedEntry? convertFeat(Map<String, dynamic> raw) => _simple(
  raw,
  'feat',
  extra: {'prerequisite': _joinList(raw['prerequisite'])},
);

String _speedText(Object? node) {
  final speed = _speed(node);
  final walk = speed['walk'];
  return '$walk feet';
}

/// `entries` agacini `{type, name, desc}` listesine cevirir.
///
/// Tur/gecmis ayristiricisi (`origin_parsing.dart`) `type: SIZE` / `SPEED`
/// gibi etiketlere bakiyor; adli bolumler oraya bu bicimde giriyor.
List<Map<String, dynamic>> _traitEntries(Object? node) {
  if (node is! List) return const [];
  return [
    for (final item in node)
      if (item is Map && item['name'] != null)
        {
          'type': _text(item['name']).toUpperCase(),
          'name': _text(item['name']),
          'desc': renderEntries(item['entries'] ?? item['entry']),
        }
      else
        {'type': 'TEXT', 'name': '', 'desc': renderEntries(item)},
  ];
}

ConvertedEntry? _simple(
  Map<String, dynamic> raw,
  String kind, {
  Map<String, dynamic> extra = const {},
}) {
  final name = _text(raw['name']);
  if (name.isEmpty) return null;
  final source = raw['source'] as String?;
  final key = fiveToolsKey(kind, name, source);
  return (
    key: key,
    name: name,
    data: {
      'key': key,
      'name': name,
      'desc': renderEntries(raw['entries']),
      'source': source,
      ...extra,
    },
    challengeRating: 0,
    armorClass: null,
    hitPoints: null,
    size: null,
    creatureType: null,
    level: null,
    school: null,
    rarity: null,
    category: null,
  );
}

// --- `_copy` cozumleme -----------------------------------------------------

/// 5etools'un `_copy` kalitimini cozer.
///
/// Bir kayit `{"name": "Goblin Boss", "_copy": {"name": "Goblin", ...}}`
/// seklinde baska bir kaydi temel alabiliyor. Cozulmezse varyantlar bombos
/// geliyor (can yok, saldiri yok) -- ice aktarilan bir bestiary'nin gozle
/// gorulur bir kismi bu sekilde.
///
/// YALNIZCA AYNI DOSYA icinde cozuluyor: baska kitaba yapilan atif icin o
/// kitabin da yuklu olmasi gerekir, o zaman ikinci gecişte cozulur.
List<Map<String, dynamic>> resolveCopies(List<Map<String, dynamic>> entries) {
  final byName = <String, Map<String, dynamic>>{
    for (final entry in entries)
      '${_text(entry['name']).toLowerCase()}|'
              '${_text(entry['source']).toLowerCase()}':
          entry,
  };

  Map<String, dynamic> resolve(Map<String, dynamic> entry, Set<String> seen) {
    final copy = entry['_copy'];
    if (copy is! Map) return entry;
    final target =
        '${_text(copy['name']).toLowerCase()}|'
        '${_text(copy['source']).toLowerCase()}';
    // Dongusel atif: kendini kopyalayan bir kayit sonsuz dongu yapardi.
    if (!seen.add(target)) return entry;

    final base = byName[target];
    if (base == null) return entry;
    final resolved = resolve(base, seen);

    final merged = <String, dynamic>{...resolved, ...entry}..remove('_copy');
    // Ad ve kaynak DAIMA kopyalayanin: temel kaydin adini miras almak
    // "Goblin Boss" yerine ikinci bir "Goblin" uretirdi.
    merged['name'] = entry['name'];
    if (entry['source'] != null) merged['source'] = entry['source'];
    return merged;
  }

  return [for (final entry in entries) resolve(entry, <String>{})];
}

// --- yardimcilar -----------------------------------------------------------

String _text(Object? node) => node == null ? '' : '$node'.trim();

int? _int(Object? node) {
  if (node is num) return node.toInt();
  if (node is String) return int.tryParse(node.trim());
  return null;
}

String _capitalize(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1);
}
