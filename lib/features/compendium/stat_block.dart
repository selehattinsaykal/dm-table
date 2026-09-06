import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../app/ui/ui.dart';
import '../../data/content_tr.dart';
import '../../data/db/database.dart';
import '../../domain/rules/ability_scores.dart';
import '../../domain/rules/challenge_rating.dart';
import '../../domain/rules/dice.dart';
import '../../domain/rules/monster_attacks.dart';
import '../../l10n/app_localizations.dart';
import '../combat/combat_providers.dart';

/// Canavarin tam stat blogu.
///
/// Veriler [Monster.dataJson] icindeki ham Open5e kaydindan okunur; tablo
/// kolonlarina acilmayan her sey (actions, traits, duyular) burada.
class StatBlock extends ConsumerWidget {
  const StatBlock({required this.monster, this.header, super.key});

  final Monster monster;

  /// Stat blogun en ustune eklenen istege bagli widget (or. portre + duzenleme).
  final Widget? header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final tr = contentTrOf(context, ref, 'creatures');
    final names = creatureNamesTrOf(context, ref);
    final glossary = glossaryTrOf(context, ref);
    final data = jsonDecode(monster.dataJson) as Map<String, dynamic>;

    /// Hem `desc` hem `name` cevrilir. Ceviri arama anahtari INGILIZCE ad
    /// oldugu icin once metin bulunur, ad en sonda degistirilir; saldiri
    /// dugmeleri ([attacksFromAction]) cevrilmis kayittan okudugu icin
    /// buton etiketi de Turkce cikar.
    Map<String, dynamic> translated(Map<String, dynamic> e, String section) {
      final name = '${e['name'] ?? ''}';
      final desc = '${e['desc'] ?? ''}';
      final turkish = tr.part(monster.key, section, name, desc);
      final trName = names.of(name);
      if (identical(turkish, desc) && trName == name) return e;
      return {...e, 'desc': turkish, 'name': trName};
    }

    final actions = [
      for (final a
          in (data['actions'] as List? ?? const [])
              .cast<Map<String, dynamic>>())
        translated(a, 'actions'),
    ];
    final traits = [
      for (final t
          in (data['traits'] as List? ?? const []).cast<Map<String, dynamic>>())
        translated(t, 'traits'),
    ];

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
    final topLevelLegendary = [
      for (final a
          in (data['legendary_actions'] as List? ?? const [])
              .whereType<Map<String, dynamic>>())
        translated(a, 'actions'),
    ];
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
            glossary.term('sizes', monster.size ?? ''),
            glossary.term('creatureTypes', monster.creatureType ?? ''),
            if (data['alignment'] != null)
              glossary.term('alignments', '${data['alignment']}'),
          ].where((s) => s.isNotEmpty).join(', '),
          style: theme.textTheme.bodySmall?.copyWith(
            fontStyle: FontStyle.italic,
          ),
        ),
        const _Rule(),
        _Line(
          l10n.statAc,
          [
            '${monster.armorClass ?? '—'}',
            if (data['armor_detail'] != null &&
                '${data['armor_detail']}'.isNotEmpty)
              '(${glossary.term('armorDetails', '${data['armor_detail']}')})',
          ].join(' '),
        ),
        _Line(
          l10n.statHp,
          '${monster.hitPoints ?? '—'} (${data['hit_dice'] ?? '—'})',
        ),
        _Line(l10n.statSpeed, _formatSpeed(data['speed'], glossary)),
        _Line(
          l10n.statInitiative,
          formatModifier(data['initiative_bonus'] as int? ?? 0),
        ),
        const _Rule(),
        _AbilityTable(data: data, glossary: glossary),
        const _Rule(),
        if (data['saving_throws'] is Map)
          _Line(
            l10n.statSavingThrows,
            _formatBonuses(data['saving_throws'] as Map, 'abilities', glossary),
          ),
        if (data['skill_bonuses'] is Map &&
            (data['skill_bonuses'] as Map).isNotEmpty)
          _Line(
            l10n.statSkills,
            _formatBonuses(data['skill_bonuses'] as Map, 'skills', glossary),
          ),
        ..._defenses(data, l10n, glossary),
        _Line(l10n.statSenses, _formatSenses(data, l10n, glossary)),
        if (data['languages'] is Map)
          _Line(
            l10n.statLanguages,
            _formatLanguages(
              '${(data['languages'] as Map)['as_string'] ?? ''}',
              l10n,
              glossary,
            ),
          ),
        _Line(
          l10n.statCr,
          '${formatCr(monster.challengeRating)} '
          '(${monster.experiencePoints ?? 0} XP)',
        ),
        if (traits.isNotEmpty) ...[
          const _Rule(),
          for (final t in traits) _Entry(t),
        ],
        for (final entry in _groupTitles(l10n).entries)
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
  static Map<String, String> _groupTitles(L10n l10n) => {
    'ACTION': l10n.statActions,
    'BONUS_ACTION': l10n.statBonusActions,
    'REACTION': l10n.statReactions,
    'LEGENDARY_ACTION': l10n.statLegendaryActions,
  };

  static String _formatSpeed(Object? speed, GlossaryTr glossary) {
    if (speed is! Map) return '—';
    final unit = speed['unit'] ?? 'feet';
    final parts = <String>[];
    for (final e in speed.entries) {
      if (e.key == 'unit' || e.value == null || e.value == 0) continue;
      if (e.value is! num) continue;
      final label = e.key == 'walk'
          ? ''
          : '${glossary.term('speeds', '${e.key}')} ';
      parts.add('$label${e.value} $unit');
    }
    return parts.isEmpty ? '—' : parts.join(', ');
  }

  static String _formatBonuses(
    Map bonuses,
    String section,
    GlossaryTr glossary,
  ) => bonuses.entries
      .where((e) => e.value is num)
      .map((e) {
        final key = e.key as String;
        // Veri hem `sleight_of_hand` hem `sleight of hand` gonderiyor.
        final label = glossary.term(section, key.replaceAll('_', ' '));
        final name = label == key.replaceAll('_', ' ')
            ? _titleCase(key)
            : label;
        return '$name ${formatModifier(e.value as int)}';
      })
      .join(', ');

  static String _formatSenses(
    Map<String, dynamic> data,
    L10n l10n,
    GlossaryTr glossary,
  ) {
    final parts = <String>[];
    for (final (label, key) in [
      ('Darkvision', 'darkvision_range'),
      ('Blindsight', 'blindsight_range'),
      ('Tremorsense', 'tremorsense_range'),
      ('Truesight', 'truesight_range'),
    ]) {
      final v = data[key];
      if (v is num && v > 0) {
        parts.add('${glossary.term('senses', label)} $v ft.');
      }
    }
    parts.add(
      '${l10n.statPassivePerception} ${data['passive_perception'] ?? '—'}',
    );
    return parts.join(', ');
  }

  /// "Common, Draconic; telepathy 120 ft." -> her dil ayri ayri cevrilir;
  /// arada kalan baglaclar ve mesafe oldugu gibi korunur.
  static String _formatLanguages(String value, L10n l10n, GlossaryTr glossary) {
    if (value.trim().isEmpty) return l10n.statNoLanguages;
    return value.splitMapJoin(
      RegExp(r'[A-Za-z][A-Za-z’\x27 ]*[A-Za-z]|[A-Za-z]'),
      onMatch: (m) => glossary.term('languages', m[0]!),
      onNonMatch: (s) => s,
    );
  }

  static List<Widget> _defenses(
    Map<String, dynamic> data,
    L10n l10n,
    GlossaryTr glossary,
  ) {
    final d = data['resistances_and_immunities'];
    if (d is! Map) return const [];
    return [
      for (final (label, key, section) in [
        (l10n.statDamageResistances, 'damage_resistances_display', 'damage'),
        (l10n.statDamageImmunities, 'damage_immunities_display', 'damage'),
        (
          l10n.statDamageVulnerabilities,
          'damage_vulnerabilities_display',
          'damage',
        ),
        (
          l10n.statConditionImmunities,
          'condition_immunities_display',
          'conditions',
        ),
      ])
        if (d[key] != null && '${d[key]}'.isNotEmpty)
          _Line(label, glossary.list(section, '${d[key]}')),
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
  const _AbilityTable({required this.data, required this.glossary});

  final Map<String, dynamic> data;
  final GlossaryTr glossary;

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
                  glossary.term('abilityAbbr', label),
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
    // Yetenek/aksiyon aciklamalari stat blogunun DUZ METIN kismidir — el
    // yazmasi serifi burada dogru. Ustteki etiket/deger satirlari (AC, HP,
    // hiz) yogun veri oldugu icin sans'ta kalir. Aciklamanin icinde tablo
    // olabiliyor (or. sekil listeleri), o yuzden [GameText].
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${entry['name']}',
            style: readingStyle(context, base: theme.textTheme.bodyMedium)
                .copyWith(
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                ),
          ),
          GameText('${entry['desc'] ?? ''}'),
        ],
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

class _AttackSheet extends ConsumerStatefulWidget {
  const _AttackSheet({required this.attack});

  final MonsterAttack attack;

  @override
  ConsumerState<_AttackSheet> createState() => _AttackSheetState();
}

class _AttackSheetState extends ConsumerState<_AttackSheet> {
  final _roller = DiceRoller();
  Advantage _advantage = Advantage.none;
  bool _forceCritical = false;

  DiceRoll? _toHit;
  DamageRoll? _damage;

  /// Bu atisin hasari hedefe UYGULANDI mi? Ayni zar iki kez islenmesin.
  bool _applied = false;

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
      _applied = false;
    });
  }

  /// Hedefe uygulama satiri; hedef secili degilse bos.
  Widget _applyRow(BuildContext context, L10n l10n) {
    final targetId = ref.watch(combatTargetProvider);
    if (targetId == null) return const SizedBox.shrink();
    final target = ref
        .watch(allCombatantsProvider)
        .value
        ?.where((c) => c.id == targetId)
        .firstOrNull;
    if (target == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final damage = _damage?.total ?? 0;
    // Isabet DEGERLENDIRMESI bilgi olarak veriliyor, karar DM'in: buyu
    // etkileri, ortu ve tepki zarlari uygulamanin bilmedigi seyler.
    final ac = target.armorClass;
    final hits = ac == null || _toHit == null || _toHit!.total >= ac;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(target.name, style: theme.textTheme.titleSmall),
                Text(
                  ac == null
                      ? l10n.combatNoArmorClass
                      : (hits ? l10n.combatHits(ac) : l10n.combatMisses(ac)),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: hits
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: _applied || damage <= 0
                ? null
                : () => _applyDamage(target.id, damage),
            icon: const Icon(Icons.favorite_border, size: 18),
            label: Text(
              _applied ? l10n.combatApplied : l10n.combatApplyDamage(damage),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _applyDamage(String combatantId, int damage) async {
    final l10n = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final dc = await ref
        .read(combatRepositoryProvider)
        .applyDamage(combatantId, damage);
    if (!mounted) return;
    setState(() => _applied = true);
    // Konsantrasyon kurtarmasi masada en cok unutulan kural; hasar
    // uygulandigi anda hatirlatiliyor.
    if (dc != null) {
      final name = ref
          .read(allCombatantsProvider)
          .value
          ?.where((c) => c.id == combatantId)
          .firstOrNull
          ?.name;
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.combatConcentrationCheck(name ?? '', dc))),
      );
    }
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
          // HEDEFE UYGULA: savas haritasinda `T` ile hedef isaretlendiyse
          // zar ile can arasindaki elle tasima adimi kalkiyor. Hedef yoksa
          // bolum hic gorunmuyor -- kutuphaneye bakarken bos bir dugme
          // durmasin.
          if (_damage != null) _applyRow(context, l10n),
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
