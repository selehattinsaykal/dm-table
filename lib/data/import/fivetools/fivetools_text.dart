/// 5etools metin bicimini duz okunur metne cevirir.
///
/// 5etools iki sey yapiyor ve ikisi de burada cozuluyor:
///
///  * **Etiketler**: `{@damage 2d6}`, `{@dc 15}`, `{@creature goblin|MM}` gibi
///    kume parantezli isaretlemeler. Cozulmezse kural metni okunmaz hale
///    geliyor.
///  * **`entries` agaci**: bir yetenek metni duz bir dize degil; ic ice
///    listeler, tablolar, alintilar ve adli alt bolumlerden olusan bir agac.
///
/// Saf Dart: veritabani ya da arayuz bilmez, bu yuzden tamami test edilebilir.
library;

/// `{@tag ...}` isaretlemelerini duz metne cevirir.
///
/// Etiketlerin cogu `{@tag gorunen|kaynak|alternatifGorunen}` seklinde: son
/// parca varsa gosterilecek metin odur, yoksa ilk parca. Sayi/zar etiketleri
/// ise kendi bicimlerini uretiyor (`{@hit 5}` -> `+5`).
String stripTags(String input) {
  if (!input.contains('{@')) return input;

  final buffer = StringBuffer();
  var i = 0;
  while (i < input.length) {
    final start = input.indexOf('{@', i);
    if (start < 0) {
      buffer.write(input.substring(i));
      break;
    }
    buffer.write(input.substring(i, start));

    // Ic ice etiketler var ({@i metin {@dice 1d6}}); kapanisi SAYARAK bul.
    final end = _matchingBrace(input, start);
    if (end < 0) {
      // Kapanmamis etiket: ham birak, metni yutma.
      buffer.write(input.substring(start));
      break;
    }
    buffer.write(_renderTag(input.substring(start + 2, end)));
    i = end + 1;
  }
  return buffer.toString();
}

/// `{`'in eslesen `}`'ini bulur; yoksa -1.
int _matchingBrace(String input, int start) {
  var depth = 0;
  for (var i = start; i < input.length; i++) {
    final char = input[i];
    if (char == '{') depth++;
    if (char == '}') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

/// Etiketin govdesini (`@` sonrasi) metne cevirir.
String _renderTag(String body) {
  final space = body.indexOf(' ');
  final name = (space < 0 ? body : body.substring(0, space)).toLowerCase();
  final rest = space < 0 ? '' : body.substring(space + 1);
  // Ic etiketler once cozuluyor: `{@i ... {@dice 1d6}}` gibi durumlar.
  final parts = stripTags(rest).split('|');
  final first = parts.isEmpty ? '' : parts.first;

  switch (name) {
    // --- Bicimlendirme: yalnizca metni birak.
    case 'b' ||
        'bold' ||
        'i' ||
        'italic' ||
        's' ||
        'strike' ||
        'u' ||
        'underline' ||
        'note' ||
        'highlight':
      return first;

    // --- Sayilar.
    case 'hit':
      final value = int.tryParse(first.trim());
      if (value == null) return first;
      return value >= 0 ? '+$value' : '$value';
    case 'dc':
      return 'DC $first';
    case 'chance':
      return '%$first';
    case 'recharge':
      // `{@recharge}` = yalnizca 6; `{@recharge 5}` = 5-6.
      return first.trim().isEmpty ? '(Recharge 6)' : '(Recharge $first-6)';
    case 'h':
      return 'Hit: ';
    case 'm':
      return 'Miss: ';

    // --- Saldiri turu kisaltmalari.
    case 'atk':
      return '${_attackKind(first)}:';
    case 'atkr':
      return '${_attackRange(first)}:';

    // --- Zar/hasar: `{@dice 1d6|gosterim}`.
    case 'dice' ||
        'damage' ||
        'hitYourSpellAttack' ||
        'd20' ||
        'scaledice' ||
        'scaledamage':
      // Olcekli zarlarda GOSTERIM son parcada: `{@scaledice 2d6|1-9|1d6}`.
      return parts.length > 2 ? parts.last : first;

    // --- Basvurular: `{@creature goblin|MM|goblin}`.
    default:
      return parts.length > 2 && parts.last.trim().isNotEmpty
          ? parts.last
          : first;
  }
}

/// `mw` -> "Melee Weapon Attack" gibi.
String _attackKind(String code) {
  final flags = code.toLowerCase().split(',').map((s) => s.trim()).toSet();
  final melee =
      flags.contains('m') || flags.contains('mw') || flags.contains('ms');
  final ranged =
      flags.contains('r') || flags.contains('rw') || flags.contains('rs');
  final spell = flags.contains('ms') || flags.contains('rs');

  final reach = switch ((melee, ranged)) {
    (true, true) => 'Melee or Ranged',
    (false, true) => 'Ranged',
    _ => 'Melee',
  };
  return '$reach ${spell ? 'Spell' : 'Weapon'} Attack';
}

/// 2024 bicimi: `{@atkr m}` -> "Melee Attack Roll".
String _attackRange(String code) {
  final flags = code.toLowerCase().split(',').map((s) => s.trim()).toSet();
  if (flags.contains('m') && flags.contains('r')) {
    return 'Melee or Ranged Attack Roll';
  }
  if (flags.contains('r')) return 'Ranged Attack Roll';
  return 'Melee Attack Roll';
}

/// `entries` agacini duz metne cevirir.
///
/// Agac dize, liste ve `type` alanli nesnelerin karisimi. Taninmayan bir tur
/// gelirse ICI OKUNUR: 5etools yeni turler ekliyor ve taninmayani atmak
/// yetenegin yarisini sessizce siliyordu.
String renderEntries(Object? node, {int depth = 0}) {
  if (node == null) return '';
  if (node is String) return stripTags(node);
  if (node is num || node is bool) return '$node';

  if (node is List) {
    return node
        .map((child) => renderEntries(child, depth: depth))
        .where((text) => text.trim().isNotEmpty)
        .join('\n');
  }

  if (node is! Map) return '';
  final map = node.cast<String, dynamic>();
  final type = '${map['type'] ?? 'entries'}';

  switch (type) {
    case 'list':
      final items = map['items'];
      if (items is! List) return '';
      return items
          .map((item) => renderEntries(item, depth: depth + 1))
          .where((text) => text.trim().isNotEmpty)
          .map((text) => '• $text')
          .join('\n');

    case 'table':
      return _renderTable(map);

    case 'quote':
      final body = renderEntries(map['entries'], depth: depth + 1);
      final by = map['by'];
      return by == null ? body : '$body\n— ${stripTags('$by')}';

    case 'item' || 'itemSub' || 'itemSpell':
      final name = map['name'];
      final body = renderEntries(
        map['entry'] ?? map['entries'],
        depth: depth + 1,
      );
      return name == null ? body : '${stripTags('$name')}: $body';

    case 'abilityDc':
      final attributes = (map['attributes'] as List?)?.join(', ') ?? '';
      return 'Spell save DC ($attributes)';

    case 'abilityAttackMod':
      final attributes = (map['attributes'] as List?)?.join(', ') ?? '';
      return 'Spell attack modifier ($attributes)';

    case 'spellcasting':
      return _renderSpellcasting(map, depth);

    // Sinif/alt sinif ozelliklerine YAPILAN ATIFLAR: govdeleri baska bir
    // dosyada, burada cozulemez. Sessizce atlamak yerine adi birakiyoruz ki
    // metinde bosluk olusmasin.
    case 'refClassFeature' || 'refSubclassFeature' || 'refOptionalfeature':
      final ref =
          map['classFeature'] ??
          map['subclassFeature'] ??
          map['optionalfeature'];
      return ref == null ? '' : stripTags('$ref'.split('|').first);

    default:
      // 'entries', 'inset', 'insetReadaloud', 'section', 'variant'...
      final name = map['name'];
      final body = renderEntries(
        map['entries'] ?? map['entry'] ?? map['items'],
        depth: depth + 1,
      );
      if (name == null) return body;
      final title = stripTags('$name');
      return body.trim().isEmpty ? title : '$title. $body';
  }
}

String _renderTable(Map<String, dynamic> map) {
  final out = StringBuffer();
  final caption = map['caption'];
  if (caption != null) out.writeln(stripTags('$caption'));

  final labels = map['colLabels'];
  if (labels is List) {
    out.writeln(labels.map((l) => stripTags('$l')).join(' | '));
  }
  final rows = map['rows'];
  if (rows is List) {
    for (final row in rows) {
      if (row is! List) continue;
      out.writeln(
        row
            .map((cell) => renderEntries(cell).replaceAll('\n', ' '))
            .join(' | '),
      );
    }
  }
  return out.toString().trimRight();
}

/// Buyu yapma blogu: baslik + seviye seviye buyu listeleri.
String _renderSpellcasting(Map<String, dynamic> map, int depth) {
  final out = StringBuffer();
  final name = map['name'];
  if (name != null) out.writeln(stripTags('$name'));

  final header = renderEntries(map['headerEntries'], depth: depth + 1);
  if (header.trim().isNotEmpty) out.writeln(header);

  void writeGroup(Object? group) {
    if (group is! Map) return;
    for (final entry in group.cast<String, dynamic>().entries) {
      final value = entry.value;
      final spells = value is Map ? value['spells'] : value;
      if (spells is! List) continue;
      final label = entry.key == '0' ? 'Cantrips' : 'Level ${entry.key}';
      final slots = value is Map ? value['slots'] : null;
      final suffix = slots == null ? '' : ' ($slots slots)';
      out.writeln(
        '$label$suffix: ${spells.map((s) => stripTags('$s')).join(', ')}',
      );
    }
  }

  writeGroup(map['spells']);
  for (final key in ['will', 'daily', 'rest', 'ritual']) {
    final group = map[key];
    if (group is List) {
      out.writeln('$key: ${group.map((s) => stripTags('$s')).join(', ')}');
    } else if (group is Map) {
      for (final entry in group.cast<String, dynamic>().entries) {
        final value = entry.value;
        if (value is! List) continue;
        out.writeln(
          '$key ${entry.key}: '
          '${value.map((s) => stripTags('$s')).join(', ')}',
        );
      }
    }
  }

  final footer = renderEntries(map['footerEntries'], depth: depth + 1);
  if (footer.trim().isNotEmpty) out.writeln(footer);
  return out.toString().trimRight();
}
