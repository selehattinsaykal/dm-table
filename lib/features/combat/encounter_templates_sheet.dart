import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../data/encounter_template_repository.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import 'combat_providers.dart';
import 'encounter_page.dart';

/// Kayitli karsilasma kaliplari.
///
/// **Neden var:** hazirlik yapan DM ayni kadroyu ("6 goblin + 1 hobgoblin
/// sefi") her seferinde elle kuruyordu. Kalip yalnizca kadroyu tasiyor; can
/// ve inisiyatif kurulusta yeniden atiliyor.
class EncounterTemplatesSheet extends ConsumerWidget {
  const EncounterTemplatesSheet({this.sourceEncounterId, super.key});

  /// Verilirse "kalip olarak kaydet" dugmesi bu karsilasmayi kaydeder.
  final String? sourceEncounterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final templates = ref.watch(encounterTemplatesProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.encounterTemplates, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (sourceEncounterId != null) ...[
              OutlinedButton.icon(
                onPressed: () => _saveCurrent(context, ref),
                icon: const Icon(Icons.bookmark_add_outlined),
                label: Text(l10n.encounterTemplateSave),
              ),
              const SizedBox(height: 12),
            ],
            Flexible(
              child: switch (templates) {
                AsyncData(:final value) when value.isEmpty => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(child: Text(l10n.encounterTemplateEmpty)),
                ),
                AsyncData(:final value) => ListView.builder(
                  shrinkWrap: true,
                  itemCount: value.length,
                  itemBuilder: (context, i) =>
                      _TemplateTile(template: value[i]),
                ),
                _ => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveCurrent(BuildContext context, WidgetRef ref) async {
    final l10n = L10n.of(context);
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.encounterTemplateSave),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.combatEncounterName),
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
    );
    final name = controller.text.trim();
    controller.dispose();
    if (confirmed != true || name.isEmpty) return;

    final rows = await ref
        .read(combatRepositoryProvider)
        .combatants(sourceEncounterId!);
    await ref
        .read(encounterTemplateRepositoryProvider)
        .saveFrom(name: name, combatants: rows);
  }
}

class _TemplateTile extends ConsumerWidget {
  const _TemplateTile({required this.template});

  final EncounterTemplate template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final entries = EncounterTemplateRepository.entriesOf(template);

    return ListTile(
      title: Text(template.name),
      subtitle: Text(
        entries.map((e) => '${e.count}× ${e.name}').join(', '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: l10n.encounterTemplateUse,
            icon: const Icon(Icons.play_circle_outline),
            onPressed: () => _instantiate(context, ref),
          ),
          IconButton(
            tooltip: l10n.delete,
            icon: const Icon(Icons.close),
            onPressed: () => ref
                .read(encounterTemplateRepositoryProvider)
                .remove(template.id),
          ),
        ],
      ),
    );
  }

  Future<void> _instantiate(BuildContext context, WidgetRef ref) async {
    final l10n = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    // Kok gezgin await'lerden ONCE yakalaniyor: sheet kapandiktan sonra bu
    // widget'in `context`'i artik gecerli degil.
    final root = Navigator.of(context, rootNavigator: true);

    final result = await ref
        .read(encounterTemplateRepositoryProvider)
        .instantiate(template, combat: ref.read(combatRepositoryProvider));

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.missing.isEmpty
              ? l10n.encounterTemplateCreated(template.name)
              // Bulunamayanlar SESSIZCE atlanmiyor: DM eksik kadroyla
              // savasa girmesin.
              : l10n.encounterTemplateMissing(result.missing.join(', ')),
        ),
      ),
    );

    // Once sheet kapaniyor, sonra kurulan karsilasma ACILIYOR. Eskiden
    // yalnizca bildirim cikiyordu ve DM kurdugu karsilasmayi listeden elle
    // bulmak zorunda kaliyordu -- kalibin amaci tam olarak o adimdan
    // kurtarmakti.
    if (navigator.canPop()) navigator.pop();
    await root.push(
      MaterialPageRoute<void>(
        builder: (_) => EncounterPage(encounterId: result.encounterId),
      ),
    );
  }
}
