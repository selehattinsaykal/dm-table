import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/journey_repository.dart';
import '../../l10n/app_localizations.dart';
import 'journey_providers.dart';
import 'journey_sheet.dart';
import 'travel_planner.dart' show formatMiles;

/// Oturum sayfasindaki "yolculuk suruyor" karti.
///
/// Yolun ortasinda cikan karsilasma DM'i savas ekranina goturuyor; oradan
/// donunce Dunya sekmesine gidip haritayi bulmak zorunda kalmasin diye
/// yolculuk oturum sayfasindan da devam ettirilebiliyor.
///
/// Suren yolculuk yoksa hic yer kaplamaz.
class JourneyCard extends ConsumerWidget {
  const JourneyCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journey = ref.watch(activeJourneyProvider).value;
    if (journey == null) return const SizedBox.shrink();

    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final pending = JourneyRepository.pendingOf(journey);
    final progress = journey.totalMiles <= 0
        ? 0.0
        : (journey.milesTravelled / journey.totalMiles).clamp(0.0, 1.0);

    // Alt bosluk kartin kendisinde: yolculuk yokken listede bosluk kalmasin.
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_walk, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.journeyTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  l10n.journeyBannerProgress(
                    formatMiles(journey.milesTravelled),
                    formatMiles(journey.totalMiles),
                  ),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: progress, minHeight: 6),
            ),
            if (pending != null) ...[
              const SizedBox(height: 10),
              Text(
                l10n.journeyEncounterTitle,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              Text(
                pending.text.isEmpty
                    ? l10n.travelEncounterMissingRow(pending.tableRoll)
                    : pending.text,
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => showJourneySheet(context, ref),
                icon: const Icon(Icons.play_arrow, size: 18),
                label: Text(l10n.journeyOpen),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
