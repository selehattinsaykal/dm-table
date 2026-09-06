import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../data/db/database.dart';
import '../../domain/rules/damage_types.dart';
import '../../domain/rules/death_saves.dart';
import '../../l10n/app_localizations.dart';
import 'combat_providers.dart';

/// Reaksiyon isareti.
///
/// Masada en cok unutulan kaynak. Sira o katilimciya gelince kendiliginden
/// tazeleniyor (bkz. `CombatRepository.advanceTurn`), burada yalnizca elle
/// isaretleniyor.
class ReactionPip extends ConsumerWidget {
  const ReactionPip({required this.combatant, super.key});

  final Combatant combatant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final used = combatant.reactionUsed;

    return Tooltip(
      message: used ? l10n.reactionUsed : l10n.reactionAvailable,
      child: Semantics(
        button: true,
        label:
            '${l10n.reaction}: '
            '${used ? l10n.reactionUsed : l10n.reactionAvailable}',
        child: InkWell(
          onTap: () => ref
              .read(combatRepositoryProvider)
              .setReactionUsed(combatant.id, !used),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  // Renk korlugu icin: durum SEKILDEN de okunuyor (dolu bolt
                  // = harcandi, cerceveli = hazir).
                  used ? Icons.bolt : Icons.bolt_outlined,
                  size: 15,
                  color: used
                      ? theme.colorScheme.outline
                      : theme.colorScheme.tertiary,
                ),
                const SizedBox(width: 2),
                Text(
                  l10n.reaction.substring(0, 1),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: used
                        ? theme.colorScheme.outline
                        : theme.colorScheme.tertiary,
                    decoration: used ? TextDecoration.lineThrough : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Olum kurtarma sayaci.
///
/// Yalnizca can 0 iken gorunuyor: ayakta olan bir yaratigin altinda uc bos
/// daire durmasi ekrani gurultulendiriyordu.
class DeathSaveTrack extends ConsumerWidget {
  const DeathSaveTrack({required this.combatant, super.key});

  final Combatant combatant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final repo = ref.read(combatRepositoryProvider);

    final saves = (
      successes: combatant.deathSaveSuccesses,
      failures: combatant.deathSaveFailures,
    );
    final state = deathSaveState(saves);

    Widget pips({
      required int filled,
      required IconData icon,
      required Color color,
      required void Function(int) onTap,
    }) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 3; i++)
          InkWell(
            // Dolu bir daireye dokunmak onu GERI ALIR: yanlis isaretlenen
            // bir kurtarma masada sik oluyor ve geri almanin yolu olmali.
            onTap: () => onTap(filled >= i ? i - 1 : i),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Icon(
                filled >= i ? icon : Icons.circle_outlined,
                size: 15,
                color: filled >= i ? color : theme.colorScheme.outline,
              ),
            ),
          ),
      ],
    );

    return Row(
      children: [
        Text(l10n.deathSaves, style: theme.textTheme.labelSmall),
        const SizedBox(width: 8),
        pips(
          filled: saves.successes,
          icon: Icons.check_circle,
          color:
              theme.extension<AppFantasyColors>()?.moss ??
              theme.colorScheme.primary,
          onTap: (value) => repo.setDeathSaves(combatant.id, (
            successes: value,
            failures: saves.failures,
          )),
        ),
        const SizedBox(width: 10),
        pips(
          filled: saves.failures,
          icon: Icons.cancel,
          color: theme.colorScheme.error,
          onTap: (value) => repo.setDeathSaves(combatant.id, (
            successes: saves.successes,
            failures: value,
          )),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: l10n.deathSaveRoll,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.casino_outlined, size: 16),
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            final label = switch ((await repo.rollDeathSaveFor(
              combatant.id,
            )).state) {
              DeathSaveState.stable => l10n.deathSaveStable,
              DeathSaveState.dead => l10n.deathSaveDead,
              DeathSaveState.revived => l10n.deathSaveRevived,
              DeathSaveState.pending => null,
            };
            if (label != null) {
              messenger.showSnackBar(
                SnackBar(content: Text('${combatant.name}: $label')),
              );
            }
          },
        ),
        if (state != DeathSaveState.pending)
          Text(
            switch (state) {
              DeathSaveState.stable => l10n.deathSaveStable,
              DeathSaveState.dead => l10n.deathSaveDead,
              DeathSaveState.revived => l10n.deathSaveRevived,
              DeathSaveState.pending => '',
            },
            style: theme.textTheme.labelSmall?.copyWith(
              color: state == DeathSaveState.dead
                  ? theme.colorScheme.error
                  : theme.colorScheme.tertiary,
            ),
          ),
      ],
    );
  }
}

/// Hasar turu secici + hasar/iyilestirme dugmeleri.
///
/// Tur secilince katilimcinin direnc/bagisiklik listesi uygulaniyor ve
/// GERCEKTEN dusen can bildiriliyor: "24 → 12 (direnc)".
class TypedDamageButtons extends ConsumerStatefulWidget {
  const TypedDamageButtons({required this.combatant, super.key});

  final Combatant combatant;

  @override
  ConsumerState<TypedDamageButtons> createState() => _TypedDamageButtonsState();
}

class _TypedDamageButtonsState extends ConsumerState<TypedDamageButtons> {
  int _amount = 1;
  DamageType? _type;
  bool _critical = false;

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(combatRepositoryProvider);
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final defenses = Defenses.decode(widget.combatant.defensesJson);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tur secici yalnizca IKON: satirda yer yok ve tur cogu vurusta
        // degismiyor. Secili turun rengi savunmayi da gosteriyor.
        PopupMenuButton<DamageType?>(
          tooltip: l10n.damageType,
          initialValue: _type,
          onSelected: (value) => setState(() => _type = value),
          itemBuilder: (context) => [
            PopupMenuItem(value: null, child: Text(l10n.damageTypeAny)),
            for (final type in DamageType.values)
              PopupMenuItem(
                value: type,
                child: Row(
                  children: [
                    Icon(_defenseIcon(defenses.modifierFor(type)), size: 15),
                    const SizedBox(width: 8),
                    Text(type.name),
                  ],
                ),
              ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Icon(
              _type == null ? Icons.category_outlined : _typeIcon(_type!),
              size: 18,
              color: _type == null
                  ? theme.colorScheme.outline
                  : theme.colorScheme.primary,
            ),
          ),
        ),
        IconButton(
          tooltip: l10n.combatDamage,
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            final result = await repo.applyDamageTyped(
              widget.combatant.id,
              _amount,
              type: _type,
              critical: _critical,
            );
            final note = switch (result.modifier) {
              DamageModifier.resistant => l10n.damageResisted(result.amount),
              DamageModifier.immune => l10n.damageImmune,
              DamageModifier.vulnerable => l10n.damageVulnerable(result.amount),
              DamageModifier.normal => null,
            };
            if (note != null) {
              messenger.showSnackBar(SnackBar(content: Text(note)));
            }
            // Kritik TEK SEFERLIK: uygulandiktan sonra kendiliginden
            // kapaniyor. Acik kalirsa sonraki hedeflere de iki kat
            // basarisizlik yazdiriyordu ve isaret (kucuk bir yildiz) bunu
            // fark ettirecek kadar gorunur degil.
            if (_critical && mounted) setState(() => _critical = false);
          },
          onLongPress: () => setState(() => _critical = !_critical),
        ),
        SizedBox(
          width: 46,
          child: TextFormField(
            initialValue: '$_amount',
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              // Kritik isareti alan altinda kucuk bir yildizla gorunuyor:
              // ayri bir kutu koymak satiri iyice daraltirdi.
              helperText: _critical ? '*' : null,
              helperStyle: TextStyle(color: theme.colorScheme.error),
            ),
            onChanged: (v) => _amount = int.tryParse(v) ?? 0,
          ),
        ),
        IconButton(
          tooltip: l10n.combatHeal,
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => repo.applyHealing(widget.combatant.id, _amount),
        ),
      ],
    );
  }

  static IconData _defenseIcon(DamageModifier modifier) => switch (modifier) {
    DamageModifier.resistant => Icons.shield_outlined,
    DamageModifier.immune => Icons.block,
    DamageModifier.vulnerable => Icons.warning_amber_outlined,
    DamageModifier.normal => Icons.circle_outlined,
  };

  static IconData _typeIcon(DamageType type) => switch (type) {
    DamageType.fire => Icons.local_fire_department_outlined,
    DamageType.cold => Icons.ac_unit,
    DamageType.lightning => Icons.flash_on_outlined,
    DamageType.thunder => Icons.volume_up_outlined,
    DamageType.acid => Icons.science_outlined,
    DamageType.poison => Icons.coronavirus_outlined,
    DamageType.necrotic => Icons.dark_mode_outlined,
    DamageType.radiant => Icons.light_mode_outlined,
    DamageType.psychic => Icons.psychology_outlined,
    DamageType.force => Icons.blur_on,
    _ => Icons.sports_martial_arts,
  };
}

/// Katilimcinin hasar savunmalarini duzenleyen sayfa.
class DefensesDialog extends ConsumerStatefulWidget {
  const DefensesDialog({required this.combatant, super.key});

  final Combatant combatant;

  @override
  ConsumerState<DefensesDialog> createState() => _DefensesDialogState();
}

class _DefensesDialogState extends ConsumerState<DefensesDialog> {
  late Defenses _defenses = Defenses.decode(widget.combatant.defensesJson);

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    // Her tur icin uc durumlu bir dugme: yok -> direnc -> bagisiklik ->
    // zayiflik -> yok. Uc ayri liste gostermek ekrani uce katlardi.
    DamageModifier current(DamageType type) => _defenses.modifierFor(type);

    void cycle(DamageType type) {
      final next = switch (current(type)) {
        DamageModifier.normal => DamageModifier.resistant,
        DamageModifier.resistant => DamageModifier.immune,
        DamageModifier.immune => DamageModifier.vulnerable,
        DamageModifier.vulnerable => DamageModifier.normal,
      };
      setState(() {
        _defenses = Defenses(
          resistant: {..._defenses.resistant}..remove(type),
          immune: {..._defenses.immune}..remove(type),
          vulnerable: {..._defenses.vulnerable}..remove(type),
        );
        _defenses = switch (next) {
          DamageModifier.resistant => Defenses(
            resistant: {..._defenses.resistant, type},
            immune: _defenses.immune,
            vulnerable: _defenses.vulnerable,
          ),
          DamageModifier.immune => Defenses(
            resistant: _defenses.resistant,
            immune: {..._defenses.immune, type},
            vulnerable: _defenses.vulnerable,
          ),
          DamageModifier.vulnerable => Defenses(
            resistant: _defenses.resistant,
            immune: _defenses.immune,
            vulnerable: {..._defenses.vulnerable, type},
          ),
          DamageModifier.normal => _defenses,
        };
      });
    }

    return AlertDialog(
      title: Text(l10n.defensesTitle),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final type in DamageType.values)
                FilterChip(
                  label: Text('${type.name}${_suffix(l10n, current(type))}'),
                  selected: current(type) != DamageModifier.normal,
                  showCheckmark: false,
                  avatar: Icon(
                    _TypedDamageButtonsState._defenseIcon(current(type)),
                    size: 15,
                  ),
                  onSelected: (_) => cycle(type),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () async {
            await ref
                .read(combatRepositoryProvider)
                .setDefenses(widget.combatant.id, _defenses);
            if (context.mounted) Navigator.pop(context);
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }

  static String _suffix(L10n l10n, DamageModifier modifier) =>
      switch (modifier) {
        DamageModifier.resistant => ' ½',
        DamageModifier.immune => ' 0',
        DamageModifier.vulnerable => ' ×2',
        DamageModifier.normal => '',
      };
}
