import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../data/macro_repository.dart';
import '../../data/providers.dart';
import '../../domain/rules/dice.dart';
import '../../l10n/app_localizations.dart';
import '../dice/roll_log.dart';

/// Sik kullanilan zar kisayollari.
///
/// **Neden var:** "yine 4d6 at", "uzun yay saldirisi", "gizlilik" gibi ayni
/// atislar masada onlarca kez tekrarlaniyor ve her seferinde ifade elle
/// yaziliyordu.
///
/// Makro yeni bir zar dili GETIRMIYOR: ifade `parseDiceExpression` ile
/// cozuluyor, yani makroda gecerli olan her sey elle yazildiginda da gecerli.
class MacrosPage extends ConsumerWidget {
  const MacrosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final macros = ref.watch(macrosProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.macros)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.macroAdd),
      ),
      body: switch (macros) {
        AsyncData(:final value) when value.isEmpty => Center(
          child: Text(l10n.macroEmpty),
        ),
        AsyncData(:final value) => ListView.builder(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: value.length,
          itemBuilder: (context, i) => _MacroTile(macro: value[i]),
        ),
        AsyncError(:final error) => Center(child: Text('$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  /// Makro ekleme/duzenleme. [existing] verilirse duzenleme.
  static Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    Macro? existing,
  }) async {
    final l10n = L10n.of(context);
    final name = TextEditingController(text: existing?.name ?? '');
    final expression = TextEditingController(text: existing?.expression ?? '');
    String? error;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(existing == null ? l10n.macroAdd : l10n.edit),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l10n.contentSourceName,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: expression,
                  decoration: InputDecoration(
                    labelText: l10n.macroExpression,
                    hintText: '2d6+3',
                    errorText: error,
                  ),
                  // Yazarken dogrula: kaydete basinca "olmadi" demek yerine
                  // hata aninda gorunsun.
                  onChanged: (value) => setState(
                    () => error =
                        MacroRepository.validate(value) == null &&
                            value.trim().isNotEmpty
                        ? l10n.macroInvalid
                        : null,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );

    final nameText = name.text.trim();
    final expressionText = expression.text.trim();
    name.dispose();
    expression.dispose();
    if (saved != true || nameText.isEmpty) return;

    final repo = ref.read(macroRepositoryProvider);
    if (existing == null) {
      await repo.add(name: nameText, expression: expressionText);
    } else {
      await repo.update(
        existing.id,
        name: nameText,
        expression: expressionText,
      );
    }
  }
}

class _MacroTile extends ConsumerWidget {
  const _MacroTile({required this.macro});

  final Macro macro;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);

    return ListTile(
      leading: const Icon(Icons.casino_outlined),
      title: Text(macro.name),
      subtitle: Text(macro.expression, style: theme.textTheme.bodySmall),
      onTap: () {
        final roll = MacroRepository.roll(macro, DiceRoller());
        if (roll == null) return;
        // Makro atisi da zar gunlugune duser: "az once kac gelmisti?"
        // sorusunun cevabi tek yerde toplansin (bkz. `rollLogProvider`).
        ref.read(rollLogProvider.notifier).add(roll);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${roll.label}: ${roll.total}  (${roll.detail})'),
          ),
        );
      },
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: l10n.edit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => MacrosPage._edit(context, ref, existing: macro),
          ),
          IconButton(
            tooltip: l10n.delete,
            icon: const Icon(Icons.close),
            onPressed: () => ref.read(macroRepositoryProvider).remove(macro.id),
          ),
        ],
      ),
    );
  }
}
