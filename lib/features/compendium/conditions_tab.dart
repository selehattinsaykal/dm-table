import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ui/async_view.dart';
import '../../app/ui/ui.dart';
import '../../domain/rules/condition_reference.dart';
import '../../l10n/app_localizations.dart';
import 'condition_providers.dart';

/// Durum efektleri referansı (SRD 5.2).
///
/// Veri zaten `ReferenceEntries(kind: 'conditions')` içinde duruyordu; şimdiye
/// kadar yalnızca adı kullanılıyordu. Türkçe arayüzde çeviri gösterilir.
class ConditionsTab extends ConsumerWidget {
  const ConditionsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final entries = ref.watch(
      conditionEntriesProvider(l10n.localeName == 'tr'),
    );

    return asyncView(
      context,
      entries,
      loading: const SkeletonList(),
      onRetry: () =>
          ref.invalidate(conditionEntriesProvider(l10n.localeName == 'tr')),
      data: (rows) => rows.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n.compendiumConditionsEmpty,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) => ListTile(
                leading: const Icon(Icons.bolt_outlined),
                title: Text(rows[i].name),
                onTap: () => showConditionSheet(context, rows[i]),
              ),
            ),
    );
  }
}

/// Tek bir durumun kural metni.
Future<void> showConditionSheet(BuildContext context, ConditionEntry entry) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        final bullets = conditionBullets(entry.desc);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                Text(entry.name, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 12),
                for (final (i, part) in bullets.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    // Ilk parca giris cumlesi, gerisi madde.
                    child: i == 0
                        ? Text(part, style: theme.textTheme.bodyMedium)
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('•  ', style: theme.textTheme.bodyMedium),
                              Expanded(
                                child: Text(
                                  part,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                  ),
              ],
            ),
          ),
        );
      },
    );

/// Verilen İNGİLİZCE durum adı için referans kartını açar.
///
/// Savaş ekranındaki çipler durumu İngilizce adıyla saklıyor
/// (`Combatants.conditionsJson`); bu yardımcı o addan kaydı bulur.
Future<void> showConditionByName(
  BuildContext context,
  WidgetRef ref,
  String englishName,
) async {
  final l10n = L10n.of(context);
  // Turkce modda `name` cevrilmis olur, bu yuzden eslesme ADLA degil ANAHTARLA
  // yapilir: once Ingilizce listeden anahtari bul, sonra gosterilecek listede
  // o anahtari ara.
  final english = await ref.read(conditionEntriesProvider(false).future);
  final key = english
      .where((e) => e.name.toLowerCase() == englishName.toLowerCase())
      .firstOrNull
      ?.key;
  if (key == null) return;

  final entries = await ref.read(
    conditionEntriesProvider(l10n.localeName == 'tr').future,
  );
  final entry = entries.where((e) => e.key == key).firstOrNull;
  if (entry == null || !context.mounted) return;
  await showConditionSheet(context, entry);
}
