import 'package:flutter/material.dart';

import '../../domain/rules/dice.dart';
import '../../l10n/app_localizations.dart';
import 'dice_3d.dart';

/// Genel zar atma paneli.
///
/// Sonuc [onRolled] ile geri doner; cagiran taraf onu gostermekle birlikte
/// zar gunlugune de yazar (bkz. `roll_log.dart`).
Future<void> showDiceSheet(
  BuildContext context, {
  required void Function(DiceRoll roll) onRolled,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (context) => _DiceSheet(onRolled: onRolled),
);

class _DiceSheet extends StatefulWidget {
  const _DiceSheet({required this.onRolled});

  final void Function(DiceRoll roll) onRolled;

  @override
  State<_DiceSheet> createState() => _DiceSheetState();
}

class _DiceSheetState extends State<_DiceSheet> {
  final _roller = DiceRoller();
  int _count = 1;
  int _modifier = 0;
  DiceRoll? _last;

  static const _dice = [4, 6, 8, 10, 12, 20, 100];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.diceRollTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          if (_last != null)
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      '${_last!.total}',
                      style: theme.textTheme.displaySmall,
                    ),
                    Text(_last!.detail, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(l10n.diceCount, style: theme.textTheme.bodyMedium),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: _count > 1 ? () => setState(() => _count--) : null,
              ),
              Text('$_count', style: theme.textTheme.titleMedium),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: _count < 20 ? () => setState(() => _count++) : null,
              ),
              const Spacer(),
              Text(l10n.diceModifier, style: theme.textTheme.bodyMedium),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => setState(() => _modifier--),
              ),
              Text(
                _modifier >= 0 ? '+$_modifier' : '$_modifier',
                style: theme.textTheme.titleMedium,
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => setState(() => _modifier++),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final sides in _dice)
                FilledButton.tonal(
                  onPressed: () {
                    final roll = _roller.roll(
                      sides: sides,
                      count: _count,
                      modifier: _modifier,
                      label: '${_count}d$sides',
                    );
                    setState(() => _last = roll);
                    widget.onRolled(roll);
                  },
                  child: Text('d$sides'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bir zar sonucunu 3B animasyonlu pop-up ile gosterir: zar tipine gore model
/// (d20 ikosahedron, d12 dodecahedron, d10 trapezohedron, d8 octahedron, d6
/// kup, d4 tetrahedron), yuvarlanip sonuca oturur. Beceri/kurtarma/saldiri ve
/// codex zar bloklari da bu ortak yoldan gecer.
void showRollResult(BuildContext context, DiceRoll roll) {
  final l10n = L10n.of(context);
  final h = dieHeadline(
    sides: roll.sides,
    count: roll.count,
    total: roll.total,
    results: roll.results,
    keptIndex: roll.keptIndex,
  );
  showDieRoll(
    context,
    sides: roll.sides,
    headline: h.headline,
    naturalD20: h.naturalD20,
    total: roll.total,
    modifier: roll.modifier,
    count: roll.count,
    label: roll.label,
    detail: roll.detail,
    criticalText: l10n.diceCritical,
    fumbleText: l10n.diceFumble,
    diceText: l10n.diceTitle,
  );
}
