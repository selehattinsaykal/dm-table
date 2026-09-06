/// Bir buyuyu kullanmanin sayisal karsiligi.
///
/// Buyu verisinde saldiri/kurtarma/hasar alanlari zaten var (`attack_roll`,
/// `saving_throw_ability`, `damage_roll`, `casting_options`) ama hicbiri
/// kullanilmiyordu: masada DM ya da oyuncu buyuyu okuyup zari elle atiyor,
/// yuvayi elle dusuyordu. Burasi o alanlari tek bir "kullanim plani"na
/// ceviriyor; zari atmak ve yuvayi harcamak cagiranin isi.
library;

import '../models/ability.dart';
import 'spell_area.dart';

/// Kullanilan buyunun masaya donen ozeti.
class SpellCastPlan {
  const SpellCastPlan({
    required this.spellName,
    required this.spellLevel,
    required this.slotLevel,
    required this.concentration,
    this.attackBonus,
    this.saveDc,
    this.saveAbility,
    this.damageDice,
    this.damageType,
    this.area,
  });

  final String spellName;

  /// Buyunun kendi seviyesi (0 = cantrip).
  final int spellLevel;

  /// Harcanan yuvanin seviyesi; cantrip'te 0.
  final int slotLevel;

  final bool concentration;

  /// Saldiri atisi gerekiyorsa bonus, yoksa null.
  final int? attackBonus;

  /// Kurtarma atisi gerekiyorsa DC ve yetenek.
  final int? saveDc;
  final Ability? saveAbility;

  /// Yuva/seviye olceklemesi uygulanmis hasar/iyilesme zari ("8d6", "2d8+3").
  final String? damageDice;
  final String? damageType;

  /// Etki alani (sekil + olcu); alan buyusu degilse null.
  ///
  /// Sablonu haritaya koymak icin: DM buyuyu kagittan kullaninca ayni olcu
  /// haritada hazir gelsin, elle "20 ft daire" secmesin.
  final SpellArea? area;

  bool get hasArea => area != null;

  bool get hasAttack => attackBonus != null;
  bool get hasSave => saveDc != null;
  bool get hasDamage => damageDice != null && damageDice!.isNotEmpty;
}

/// Buyu kaydindan kullanim planini cikarir.
///
/// [slotLevel] harcanan yuva (cantrip icin 0), [characterLevel] cantrip
/// olceklemesi icin toplam karakter seviyesi.
SpellCastPlan planSpellCast({
  required Map<String, dynamic> spell,
  required int slotLevel,
  required int characterLevel,
  required int abilityModifier,
  required int proficiencyBonus,
}) {
  final spellLevel = spell['level'] as int? ?? 0;
  final attack = spell['attack_roll'] == true;
  final saveAbility = Ability.fromName(
    '${spell['saving_throw_ability'] ?? ''}',
  );

  return SpellCastPlan(
    spellName: '${spell['name'] ?? ''}',
    spellLevel: spellLevel,
    slotLevel: slotLevel,
    concentration: spell['concentration'] == true,
    attackBonus: attack ? abilityModifier + proficiencyBonus : null,
    saveDc: saveAbility == null ? null : 8 + abilityModifier + proficiencyBonus,
    saveAbility: saveAbility,
    // Sekil/olcu ayri bir alan olarak YOK; tarif metninden cikariliyor.
    area: spellAreaFrom('${spell['desc'] ?? ''}'),
    damageDice: _damageFor(
      spell,
      spellLevel: spellLevel,
      slotLevel: slotLevel,
      characterLevel: characterLevel,
    ),
    damageType: _damageType(spell),
  );
}

String? _damageType(Map<String, dynamic> spell) {
  final types = spell['damage_types'];
  if (types is! List || types.isEmpty) return null;
  final first = types.first;
  if (first is Map) return '${first['name'] ?? first['key'] ?? ''}';
  return '$first';
}

/// Yuva seviyesine ve karakter seviyesine gore hasar zari.
///
/// Once verinin kendi ust-seviye tablosuna bakiyoruz (`casting_options` icinde
/// `slot_level_5` gibi girisler); yoksa cantrip'ler karakter seviyesiyle
/// (5/11/17) olcekleniyor, seviyeli buyuler ise verideki temel zarla kaliyor:
/// "her ust yuvada +1d6" gibi kurallar veride yapisal degil, serbest metin.
String? _damageFor(
  Map<String, dynamic> spell, {
  required int spellLevel,
  required int slotLevel,
  required int characterLevel,
}) {
  final base = spell['damage_roll'] as String?;

  final options = spell['casting_options'];
  if (options is List) {
    for (final option in options.whereType<Map>()) {
      if ('${option['type']}' != 'slot_level_$slotLevel') continue;
      final upcast = option['damage_roll'] as String?;
      if (upcast != null && upcast.isNotEmpty) return upcast;
    }
  }

  if (base == null || base.isEmpty) return null;
  if (spellLevel > 0) return base;
  return _scaleCantrip(base, characterLevel);
}

/// Cantrip hasari 5, 11 ve 17. seviyelerde bir zar artar.
String _scaleCantrip(String dice, int characterLevel) {
  final multiplier = characterLevel >= 17
      ? 4
      : characterLevel >= 11
      ? 3
      : characterLevel >= 5
      ? 2
      : 1;
  if (multiplier == 1) return dice;

  return dice.replaceFirstMapped(RegExp(r'(\d+)d(\d+)'), (m) {
    final count = int.parse(m.group(1)!) * multiplier;
    return '${count}d${m.group(2)}';
  });
}

/// "8d6", "1d4 + 1" -> (zar sayisi, yuz, sabit ekleme).
({int count, int sides, int modifier})? parseDamageDice(String dice) {
  final match = RegExp(r'(\d+)d(\d+)').firstMatch(dice);
  if (match == null) return null;
  final flat = RegExp(r'[+-]\s*(\d+)\s*$').firstMatch(dice);
  final sign = dice.contains('-') && flat != null ? -1 : 1;
  return (
    count: int.parse(match.group(1)!),
    sides: int.parse(match.group(2)!),
    modifier: flat == null ? 0 : sign * int.parse(flat.group(1)!),
  );
}
