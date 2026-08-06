import 'dart:convert';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/db/database.dart';
import '../../domain/rules/ability_scores.dart';
import '../../domain/rules/challenge_rating.dart';
import '../../domain/rules/dice.dart';
import '../../domain/rules/monster_attacks.dart';
import '../../l10n/app_localizations.dart';

/// Canavarin tam stat blogu.
///
/// Veriler [Monster.dataJson] icindeki ham Open5e kaydindan okunur; tablo
/// kolonlarina acilmayan her sey (actions, traits, duyular) burada.
class StatBlock extends StatelessWidget {
  const StatBlock({required this.monster, this.header, super.key});

  final Monster monster;

  /// Stat blogun en ustune eklenen istege bagli widget (or. portre + duzenleme).
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = jsonDecode(monster.dataJson) as Map<String, dynamic>;

    final actions = (data['actions'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final traits = (data['traits'] as List? ?? const [])
        .cast<Map<String, dynamic>>();

    // Aksiyonlar tipe gore ayrilir: efsanevi aksiyonlar masada ayri bir
    // blokta okunur, karisik listede kaybolmamali.
    final byType = <String, List<Map<String, dynamic>>>{};
    for (final a in actions) {
      (byType[a['action_type'] as String? ?? 'ACTION'] ??= []).add(a);
    }
    // Efsanevi eylemler veri setinde IKI ayri sekilde duruyor: srd-2024'te
    // `actions[]` icinde (yukarida toplandi), mm-2024'te ise UST DUZEY
    // `legendary_actions[]` dizisinde. Ikincisi hic okunmadigi icin 12
    // canavarin efsanevi eylemleri gorunmuyordu.
    final topLevelLegendary = (data['legendary_actions'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    if (topLevelLegendary.isNotEmpty) {
      (byType['LEGENDARY_ACTION'] ??= []).addAll(topLevelLegendary);
    }
    for (final list in byType.values) {
      list.sort(
        (a, b) => (a['order_in_statblock'] as int? ?? 0).compareTo(
          b['order_in_statblock'] as int? ?? 0,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        ?header,
        Text(monster.name, style: theme.textTheme.headlineSmall),
        Text(
          [
            monster.size,
            monster.creatureType,
            if (data['alignment'] != null) data['alignment'],
          ].whereType<String>().join(', '),
          style: theme.textTheme.bodySmall?.copyWith(
            fontStyle: FontStyle.italic,
          ),
        ),
        const _Rule(),
        _Line(
          'Armor Class',
          [
            '${monster.armorClass ?? '—'}',
            if (data['armor_detail'] != null &&
                '${data['armor_detail']}'.isNotEmpty)
              '(${data['armor_detail']})',
          ].join(' '),
        ),
        _Line(
          'Hit Points',
          '${monster.hitPoints ?? '—'} (${data['hit_dice'] ?? '—'})',
        ),
        _Line('Speed', _formatSpeed(data['speed'])),
        _Line(
          'Initiative',
          formatModifier(data['initiative_bonus'] as int? ?? 0),
        ),
        const _Rule(),
        _AbilityTable(data: data),
        const _Rule(),
        if (data['saving_throws'] is Map)
          _Line('Saving Throws', _formatBonuses(data['saving_throws'] as Map)),
        if (data['skill_bonuses'] is Map &&
            (data['skill_bonuses'] as Map).isNotEmpty)
          _Line('Skills', _formatBonuses(data['skill_bonuses'] as Map)),
        ..._defenses(data),
        _Line('Senses', _formatSenses(data, monster)),
        if (data['languages'] is Map)
          _Line(
            'Languages',
            '${(data['languages'] as Map)['as_string'] ?? '—'}',
          ),
        _Line(
          'CR',
          '${formatCr(monster.challengeRating)} '
              '(${monster.experiencePoints ?? 0} XP)',
        ),
        if (traits.isNotEmpty) ...[
          const _Rule(),
          for (final t in traits) _Entry(t),
        ],
        for (final entry in _groupOrder.entries)
          _ActionGroup(entry.value, byType.remove(entry.key)),
        // Tanimadigimiz bir aksiyon tipi gelirse sessizce dusmesin: veri
        // setinde LEGENDARY_ACTION'i LEGENDARY sanip 82 aksiyonu kaybettik,
        // bir daha ayni sekilde kaybolmasin.
        for (final entry in byType.entries)
          _ActionGroup(_titleCase(entry.key), entry.value),
      ],
    );
  }

  /// Stat blokta gorunecek sira ve basliklar. Anahtarlar Open5e'nin
  /// `action_type` degerleri.
  static const _groupOrder = <String, String>{
    'ACTION': 'Actions',
    'BONUS_ACTION': 'Bonus Actions',
    'REACTION': 'Reactions',
    'LEGENDARY_ACTION': 'Legendary Actions',
  };

  static String _formatSpeed(Object? speed) {
    if (speed is! Map) return '—';
    final unit = speed['unit'] ?? 'feet';
    final parts = <String>[];
    for (final e in speed.entries) {
      if (e.key == 'unit' || e.value == null || e.value == 0) continue;
      if (e.value is! num) continue;
      final label = e.key == 'walk' ? '' : '${e.key} ';
      parts.add('$label${e.value} $unit');
    }
    return parts.isEmpty ? '—' : parts.join(', ');
  }

  static String _formatBonuses(Map bonuses) => bonuses.entries
      .where((e) => e.value is num)
      .map(
        (e) =>
            '${_titleCase(e.key as String)} ${formatModifier(e.value as int)}',
      )
      .join(', ');

  static String _formatSenses(Map<String, dynamic> data, Monster monster) {
    final parts = <String>[];
    for (final (label, key) in [
      ('Darkvision', 'darkvision_range'),
      ('Blindsight', 'blindsight_range'),
      ('Tremorsense', 'tremorsense_range'),
      ('Truesight', 'truesight_range'),
    ]) {
      final v = data[key];
      if (v is num && v > 0) parts.add('$label $v ft.');
    }
    parts.add('Passive Perception ${data['passive_perception'] ?? '—'}');
    return parts.join(', ');
  }

  static List<Widget> _defenses(Map<String, dynamic> data) {
    final d = data['resistances_and_immunities'];
    if (d is! Map) return const [];
    return [
      for (final (label, key) in [
        ('Damage Resistances', 'damage_resistances_display'),
        ('Damage Immunities', 'damage_immunities_display'),
        ('Damage Vulnerabilities', 'damage_vulnerabilities_display'),
        ('Condition Immunities', 'condition_immunities_display'),
      ])
        if (d[key] != null && '${d[key]}'.isNotEmpty) _Line(label, '${d[key]}'),
    ];
  }

  static String _titleCase(String value) => value
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Container(
      height: 2,
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
    ),
  );
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.bodyMedium,
          children: [
            TextSpan(
              text: '$label  ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _AbilityTable extends StatelessWidget {
  const _AbilityTable({required this.data});

  final Map<String, dynamic> data;

  static const _abilities = [
    ('STR', 'strength'),
    ('DEX', 'dexterity'),
    ('CON', 'constitution'),
    ('INT', 'intelligence'),
    ('WIS', 'wisdom'),
    ('CHA', 'charisma'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scores = data['ability_scores'] as Map? ?? const {};
    final mods = data['modifiers'] as Map? ?? const {};

    return Row(
      children: [
        for (final (label, key) in _abilities)
          Expanded(
            child: Column(
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${scores[key] ?? '—'}',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  mods[key] is int
                      ? formatModifier(mods[key] as int)
                      : formatModifier(
                          abilityModifier(scores[key] as int? ?? 10),
                        ),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry(this.entry);

  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RichText(
        text: TextSpan(
          // Yetenek/aksiyon aciklamalari stat blogunun DUZ METIN kismidir —
          // el yazmasi serifi burada dogru. Ustteki etiket/deger satirlari
          // (AC, HP, hiz) yogun veri oldugu icin sans'ta kalir.
          style: readingStyle(context, base: theme.textTheme.bodyMedium),
          children: [
            TextSpan(
              text: '${entry['name']}. ',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
              ),
            ),
            TextSpan(text: '${entry['desc'] ?? ''}'),
          ],
        ),
      ),
    );
  }
}

class _ActionGroup extends StatelessWidget {
  const _ActionGroup(this.title, this.entries);

  final String title;
  final List<Map<String, dynamic>>? entries;

  @override
  Widget build(BuildContext context) {
    final list = entries;
    if (list == null || list.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Rule(),
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 6),
        // Aksiyonda saldiri varsa metnin altina zar dugmeleri (vur + hasar).
        for (final e in list) _ActionEntry(e),
      ],
    );
  }
}

/// Bir aksiyon: aciklama metni + (varsa) saldiri zar dugmeleri.
class _ActionEntry extends StatelessWidget {
  const _ActionEntry(this.entry);

  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final attacks = attacksFromAction(entry);
    if (attacks.isEmpty) return _Entry(entry);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Entry(entry),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final attack in attacks)
                FilledButton.tonalIcon(
                  onPressed: () => _showAttackSheet(context, attack),
                  icon: const Icon(Icons.casino_outlined, size: 18),
                  label: Text(attack.name),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Saldiri panelini alttan acar: isabet + hasar tek dokunusla, avantaj/kritik
/// secenekleriyle. DM tarafinda yereldir (paylasilan gunluge itilmez).
void _showAttackSheet(BuildContext context, MonsterAttack attack) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => _AttackSheet(attack: attack),
  );
}

class _AttackSheet extends StatefulWidget {
  const _AttackSheet({required this.attack});

  final MonsterAttack attack;

  @override
  State<_AttackSheet> createState() => _AttackSheetState();
}

class _AttackSheetState extends State<_AttackSheet> {
  final _roller = DiceRoller();
  Advantage _advantage = Advantage.none;
  bool _forceCritical = false;

  DiceRoll? _toHit;
  DamageRoll? _damage;

  void _attack() {
    final attack = widget.attack;
    final toHit = attack.rollToHit(_roller, advantage: _advantage);
    // Dogal 20 kritik sayilir; DM ayrica elle de zorlayabilir.
    final natural = toHit != null && toHit.keptIndex != null
        ? toHit.results[toHit.keptIndex!]
        : null;
    final critical = _forceCritical || natural == 20;
    setState(() {
      _toHit = toHit;
      _damage = attack.hasDamage
          ? attack.rollDamage(_roller, critical: critical)
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final attack = widget.attack;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(attack.name, style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          // Avantaj/dezavantaj secimi (yalnizca isabet atisi varsa anlamli).
          if (attack.hasToHit)
            SegmentedButton<Advantage>(
              segments: [
                ButtonSegment(
                  value: Advantage.disadvantage,
                  label: Text(l10n.combatDisadvantage),
                ),
                ButtonSegment(
                  value: Advantage.none,
                  label: Text(l10n.combatNormalRoll),
                ),
                ButtonSegment(
                  value: Advantage.advantage,
                  label: Text(l10n.combatAdvantage),
                ),
              ],
              selected: {_advantage},
              onSelectionChanged: (s) => setState(() => _advantage = s.first),
            ),
          if (attack.hasDamage) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(l10n.combatCritical, style: theme.textTheme.bodyMedium),
                const Spacer(),
                Switch(
                  value: _forceCritical,
                  onChanged: (v) => setState(() => _forceCritical = v),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          if (_toHit != null || _damage != null)
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_toHit != null) ...[
                      Text(
                        '${l10n.combatToHit}: ${_toHit!.total}',
                        style: theme.textTheme.headlineSmall,
                      ),
                      Text(_toHit!.detail, style: theme.textTheme.bodySmall),
                    ],
                    if (_damage != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${l10n.combatDamage}: ${_damage!.total}',
                            style: theme.textTheme.headlineSmall,
                          ),
                          if (_damage!.critical) ...[
                            const SizedBox(width: 8),
                            Text(
                              l10n.combatCriticalHit,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(_damage!.detail, style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _attack,
            icon: const Icon(Icons.casino),
            label: Text(l10n.combatAttackRoll),
          ),
        ],
      ),
    );
  }
}
