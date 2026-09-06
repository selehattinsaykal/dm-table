import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../data/journey_repository.dart';
import '../../domain/rules/travel.dart';
import '../../domain/rules/travel_encounters.dart';
import '../../l10n/app_localizations.dart';
import '../calendar/calendar_providers.dart';
import '../calendar/restock_notice.dart';
import '../session/session_log_providers.dart';
import 'journey_providers.dart';
import 'travel_planner.dart' show formatMiles;

/// Suren yolculugun sayfasi.
///
/// Kapatilabilir olmasi TASARIM GEREGI: karsilasma cikinca DM masada onu
/// oynatir (savas ekranina gider), sonra buraya donup "Devam et" der. Yolculuk
/// veritabaninda durdugu icin arada ne yapildigi onemli degil.
Future<void> showJourneySheet(BuildContext context, WidgetRef ref) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _JourneySheet(),
    );

class _JourneySheet extends ConsumerStatefulWidget {
  const _JourneySheet();

  @override
  ConsumerState<_JourneySheet> createState() => _JourneySheetState();
}

class _JourneySheetState extends ConsumerState<_JourneySheet> {
  bool _busy = false;

  /// Bu adimda takvimde ilerletilen gun + yenilenen magazalar; ozet satirinda
  /// gosterilir ("Devam et" dendiginde ne oldugunu DM gormeli).
  int _lastDays = 0;
  List<String> _lastRestocked = const [];

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final journey = ref.watch(activeJourneyProvider).value;

    if (journey == null) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l10n.journeyNone, textAlign: TextAlign.center),
        ),
      );
    }

    final pending = JourneyRepository.pendingOf(journey);
    final remaining = (journey.totalMiles - journey.milesTravelled).clamp(
      0.0,
      double.infinity,
    );
    final progress = journey.totalMiles <= 0
        ? 0.0
        : (journey.milesTravelled / journey.totalMiles).clamp(0.0, 1.0);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.directions_walk),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.journeyTitle,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.journeyAbandon,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _busy ? null : () => _abandon(journey),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ProgressCard(
                travelled: journey.milesTravelled,
                total: journey.totalMiles,
                remaining: remaining,
                progress: progress,
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (pending != null) _EncounterCard(encounter: pending),
                    if (_lastDays > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          l10n.journeyDaysPassed(_lastDays),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ),
                    if (_lastRestocked.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          l10n.shopRestocked(_lastRestocked.join(', ')),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ),
                    _RouteSummary(journey: journey),
                  ],
                ),
              ),
              const Divider(height: 24),
              // Takvimi ELLE ilerletme: yolculuk disinda da (dinlenme,
              // arastirma, bekleyis) gun gecirmek gerekiyor ve bunun icin
              // takvim sayfasina gidip geri donmek gereksiz bir yolculuktu.
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _busy ? null : _skipTime,
                  icon: const Icon(Icons.fast_forward, size: 18),
                  label: Text(l10n.journeySkipTime),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.pause, size: 18),
                      label: Text(l10n.journeyPause),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : () => _continue(journey),
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow, size: 18),
                      label: Text(l10n.journeyContinue),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Takvimi elle ilerletir (gun sayisi sorulur).
  Future<void> _skipTime() async {
    final l10n = L10n.of(context);
    final days = await showDialog<int>(
      context: context,
      builder: (context) => _SkipTimeDialog(title: l10n.journeySkipTime),
    );
    if (days == null || days <= 0) return;
    setState(() => _busy = true);
    await ref.read(gameClockProvider).advanceDays(days);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _lastDays = days;
    });
  }

  /// "Devam et": bir sonraki karsilasmaya ya da hedefe kadar yol alinir.
  Future<void> _continue(Journey journey) async {
    final l10n = L10n.of(context);
    setState(() => _busy = true);

    final result = await ref.read(journeyRunnerProvider).advance(journey.id);
    if (result == null) {
      if (mounted) setState(() => _busy = false);
      return;
    }

    final log = ref.read(sessionLogRepositoryProvider);
    if (result.encounter case final e?) {
      await log.add(
        l10n.travelEncounterLogged(
          e.day,
          e.text.isEmpty ? l10n.travelEncounterMissingRow(e.tableRoll) : e.text,
        ),
      );
    }
    if (result.arrived) {
      await log.add(
        l10n.journeyArrivedLog(
          _routeLabelOf(result.journey),
          formatMiles(result.journey.totalMiles),
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      _lastDays = result.daysAdvanced;
      _lastRestocked = result.restockedShops;
    });

    if (result.arrived) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text(l10n.journeyArrived)));
      showRestockNoticeWith(
        messenger,
        l10n,
        result.restockedShops,
        reminders: result.reminders,
      );
    }
  }

  /// Yolculugu yarida birakir. Gidilen yol ve gecen gunler GERI ALINMAZ —
  /// takvim zaten ilerlemistir, geri sarmak baska kayitlari bozardi.
  Future<void> _abandon(Journey journey) async {
    final l10n = L10n.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.journeyAbandon),
        content: Text(l10n.journeyAbandonConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.journeyAbandon),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(journeyRepositoryProvider).finish(journey.id);
    if (mounted) Navigator.pop(context);
  }

  String _routeLabelOf(Journey journey) => [
    for (final s in JourneyRepository.decodeStops(journey.stopsJson))
      s.label.isEmpty ? '—' : s.label,
  ].join(' → ');
}

/// Toplam / gidilen / kalan yol + ilerleme cubugu.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.travelled,
    required this.total,
    required this.remaining,
    required this.progress,
  });

  final double travelled;
  final double total;
  final double remaining;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);

    Widget stat(String label, double miles, {Color? color}) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          Text(
            l10n.travelTotalMiles(formatMiles(miles)),
            style: theme.textTheme.titleMedium?.copyWith(color: color),
          ),
        ],
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                stat(
                  l10n.journeyTravelled,
                  travelled,
                  color: theme.colorScheme.primary,
                ),
                stat(l10n.journeyRemaining, remaining),
                stat(l10n.journeyTotal, total),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: progress, minHeight: 8),
            ),
          ],
        ),
      ),
    );
  }
}

/// Partiyi durduran karsilasma.
class _EncounterCard extends StatelessWidget {
  const _EncounterCard({required this.encounter});

  final TravelEncounter encounter;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber,
                  size: 18,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.journeyEncounterTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              encounter.text.isEmpty
                  ? l10n.travelEncounterMissingRow(encounter.tableRoll)
                  : encounter.text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.travelEncounterWhen(encounter.day, encounter.checkIndex),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rotanin duraklari ve hizi (hatirlatma amacli, duzenlenemez).
class _RouteSummary extends StatelessWidget {
  const _RouteSummary({required this.journey});

  final Journey journey;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final stops = JourneyRepository.decodeStops(journey.stopsJson);
    final speed = travelSpeedByKey(
      journey.speedKey,
      customMph: journey.customMph,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.travelRoute, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            [
              for (final s in stops) s.label.isEmpty ? '—' : s.label,
            ].join(' → '),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          Text(
            l10n.journeySpeedLine(
              formatMiles(speed.milesPerHour),
              formatMiles(journey.hoursPerDay),
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

/// Kac gun ilerlenecegini soran kucuk kutu.
class _SkipTimeDialog extends StatefulWidget {
  const _SkipTimeDialog({required this.title});

  final String title;

  @override
  State<_SkipTimeDialog> createState() => _SkipTimeDialogState();
}

class _SkipTimeDialogState extends State<_SkipTimeDialog> {
  int _days = 1;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: _days > 1 ? () => setState(() => _days--) : null,
          ),
          Text(
            l10n.journeyDaysPassed(_days),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => setState(() => _days++),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _days),
          child: Text(l10n.ok),
        ),
      ],
    );
  }
}
