import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/codex/codex_style.dart';
import '../../l10n/app_localizations.dart';
import 'codex_style_ui.dart';

/// Sayac blogunun govdesi.
///
/// Masa basinda surekli degisen kucuk sayilar icin: mesale turu, erzak,
/// ok sayisi, gecen gun, sarnicin su seviyesi, oyuncu olum kurtarmasi...
/// Goruntule modunda arti/eksi ile ANINDA degisir ve kaydedilir; blogu
/// duzenlemeye girmeye gerek yoktur.
class CodexCounterView extends StatelessWidget {
  const CodexCounterView({
    required this.title,
    required this.style,
    required this.counters,
    required this.interactive,
    required this.onChanged,
    this.palette = CodexPalette.theme,
    super.key,
  });

  final String title;
  final CodexCounterStyle style;
  final List<CodexCounter> counters;

  /// Duzenleme modunda arti/eksi kilitlidir (yanlislikla degistirmemek icin).
  final bool interactive;

  /// Bir sayacin yeni degeri. Cagiran taraf blogu gunceller.
  final void Function(int index, CodexCounter next) onChanged;

  final CodexPalette palette;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    if (counters.isEmpty) {
      return Text(
        l10n.codexCounterEmpty,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      );
    }
    final colors = codexPaletteColors(context, palette, counters.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(title, style: theme.textTheme.titleSmall),
          ),
        switch (style) {
          CodexCounterStyle.row => Column(
            children: [
              for (final (i, counter) in counters.indexed)
                _CounterRow(
                  counter: counter,
                  color: colors[i],
                  interactive: interactive,
                  onChanged: (next) => onChanged(i, next),
                ),
            ],
          ),
          CodexCounterStyle.tile => Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final (i, counter) in counters.indexed)
                _CounterTile(
                  counter: counter,
                  color: colors[i],
                  interactive: interactive,
                  onChanged: (next) => onChanged(i, next),
                ),
            ],
          ),
          CodexCounterStyle.chip => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (i, counter) in counters.indexed)
                _CounterChip(
                  counter: counter,
                  color: colors[i],
                  interactive: interactive,
                  onChanged: (next) => onChanged(i, next),
                ),
            ],
          ),
        },
      ],
    );
  }
}

/// Sayac degerini elle girme kutusu (rakama dokununca acilir).
Future<int?> promptCounterValue(
  BuildContext context,
  CodexCounter counter,
) async {
  final l10n = L10n.of(context);
  final controller = TextEditingController(text: '${counter.value}');
  final result = await showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        counter.label.isEmpty ? l10n.codexBlockCounter : counter.label,
      ),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'-?\d*'))],
        decoration: InputDecoration(
          labelText: l10n.codexCounterValue,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (v) => Navigator.pop(context, int.tryParse(v)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, int.tryParse(controller.text.trim())),
          child: Text(l10n.save),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

// --- Satir bicimi ---------------------------------------------------------

class _CounterRow extends StatelessWidget {
  const _CounterRow({
    required this.counter,
    required this.color,
    required this.interactive,
    required this.onChanged,
  });

  final CodexCounter counter;
  final Color color;
  final bool interactive;
  final ValueChanged<CodexCounter> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = counter.ratio;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (counter.icon != null) ...[
                Text(counter.icon!, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  counter.label,
                  style: theme.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _StepButton(
                icon: Icons.remove,
                enabled: interactive && !_atMin,
                onTap: () => onChanged(counter.bumped(-1)),
              ),
              _ValueLabel(
                counter: counter,
                color: color,
                interactive: interactive,
                onChanged: onChanged,
              ),
              _StepButton(
                icon: Icons.add,
                enabled: interactive && !_atMax,
                onTap: () => onChanged(counter.bumped(1)),
              ),
            ],
          ),
          if (ratio != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 5,
                  color: color,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool get _atMin => counter.min != null && counter.value <= counter.min!;
  bool get _atMax => counter.max != null && counter.value >= counter.max!;
}

// --- Kart bicimi ----------------------------------------------------------

class _CounterTile extends StatelessWidget {
  const _CounterTile({
    required this.counter,
    required this.color,
    required this.interactive,
    required this.onChanged,
  });

  final CodexCounter counter;
  final Color color;
  final bool interactive;
  final ValueChanged<CodexCounter> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 148,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (counter.icon != null) ...[
                Text(counter.icon!, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  counter.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StepButton(
                icon: Icons.remove,
                enabled:
                    interactive &&
                    !(counter.min != null && counter.value <= counter.min!),
                onTap: () => onChanged(counter.bumped(-1)),
              ),
              Flexible(
                child: InkWell(
                  onTap: interactive
                      ? () async {
                          final v = await promptCounterValue(context, counter);
                          if (v != null) onChanged(counter.withValue(v));
                        }
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '${counter.value}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: color,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ),
              _StepButton(
                icon: Icons.add,
                enabled:
                    interactive &&
                    !(counter.max != null && counter.value >= counter.max!),
                onTap: () => onChanged(counter.bumped(1)),
              ),
            ],
          ),
          if (counter.max != null)
            Text(
              '/ ${counter.max}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
        ],
      ),
    );
  }
}

// --- Cip bicimi -----------------------------------------------------------

class _CounterChip extends StatelessWidget {
  const _CounterChip({
    required this.counter,
    required this.color,
    required this.interactive,
    required this.onChanged,
  });

  final CodexCounter counter;
  final Color color;
  final bool interactive;
  final ValueChanged<CodexCounter> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (counter.icon != null) ...[
            Text(counter.icon!, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
          ],
          Text(counter.label, style: theme.textTheme.bodySmall),
          const SizedBox(width: 6),
          _StepButton(
            icon: Icons.remove,
            dense: true,
            enabled:
                interactive &&
                !(counter.min != null && counter.value <= counter.min!),
            onTap: () => onChanged(counter.bumped(-1)),
          ),
          _ValueLabel(
            counter: counter,
            color: color,
            interactive: interactive,
            onChanged: onChanged,
            dense: true,
          ),
          _StepButton(
            icon: Icons.add,
            dense: true,
            enabled:
                interactive &&
                !(counter.max != null && counter.value >= counter.max!),
            onTap: () => onChanged(counter.bumped(1)),
          ),
        ],
      ),
    );
  }
}

// --- Ortak parcalar -------------------------------------------------------

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.dense = false,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final size = dense ? 24.0 : 32.0;
    return IconButton(
      icon: Icon(icon, size: dense ? 14 : 18),
      onPressed: enabled ? onTap : null,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(width: size, height: size),
    );
  }
}

/// Sayi: dokununca elle deger girme kutusu acilir, uzun basinca sifirlanir.
class _ValueLabel extends StatelessWidget {
  const _ValueLabel({
    required this.counter,
    required this.color,
    required this.interactive,
    required this.onChanged,
    this.dense = false,
  });

  final CodexCounter counter;
  final Color color;
  final bool interactive;
  final ValueChanged<CodexCounter> onChanged;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final text = counter.max == null
        ? '${counter.value}'
        : '${counter.value}/${counter.max}';

    return Tooltip(
      message: interactive ? l10n.codexCounterHint : '',
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: interactive
            ? () async {
                final v = await promptCounterValue(context, counter);
                if (v != null) onChanged(counter.withValue(v));
              }
            : null,
        onLongPress: interactive
            ? () => onChanged(counter.withValue(counter.min ?? 0))
            : null,
        child: Container(
          constraints: BoxConstraints(minWidth: dense ? 26 : 46),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          alignment: Alignment.center,
          child: Text(
            text,
            style:
                (dense
                        ? theme.textTheme.bodySmall
                        : theme.textTheme.titleMedium)
                    ?.copyWith(
                      color: color,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
          ),
        ),
      ),
    );
  }
}
