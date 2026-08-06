import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../data/journey_repository.dart';
import '../../domain/rules/travel.dart';
import '../../domain/rules/travel_encounters.dart';
import '../../l10n/app_localizations.dart';
import '../calendar/calendar_providers.dart';
import '../session/session_log_providers.dart';
import '../tables/table_providers.dart';
import 'journey_providers.dart';
import 'world_providers.dart';

/// Harita olcegi dialogu: haritanin gercek dunyada kac mil oldugu.
///
/// Pin koordinatlari 0..1 oran oldugu icin mesafe yalnizca bu iki sayidan
/// cikar; piksel olculeri gerekmez (bkz. `domain/rules/travel.dart`).
Future<void> showMapScaleDialog(
  BuildContext context,
  WidgetRef ref,
  Location location,
) async {
  final l10n = L10n.of(context);
  final width = TextEditingController(
    text: location.mapWidthMiles == null
        ? ''
        : formatMiles(location.mapWidthMiles!),
  );
  final height = TextEditingController(
    text: location.mapHeightMiles == null
        ? ''
        : formatMiles(location.mapHeightMiles!),
  );
  // Kullanici yuksekligi elle degistirdigi anda otomatik oneri durur.
  var heightEdited = location.mapHeightMiles != null;

  /// Genislik yazilirken yukseklik piksel en-boy oranindan onerilir.
  void suggestHeight() {
    if (heightEdited) return;
    final w = double.tryParse(width.text.trim().replaceAll(',', '.'));
    final pw = location.mapWidth;
    final ph = location.mapHeight;
    if (w == null || w <= 0 || pw == null || ph == null || pw <= 0) {
      height.text = '';
      return;
    }
    height.text = formatMiles(w * (ph / pw));
  }

  final result = await showDialog<_ScaleResult>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.straighten),
      title: Text(l10n.travelScaleTitle),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.travelScaleHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: width,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => suggestHeight(),
                decoration: InputDecoration(
                  labelText: l10n.travelWidthMiles,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: height,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => heightEdited = true,
                decoration: InputDecoration(
                  labelText: l10n.travelHeightMiles,
                  helperText: l10n.travelHeightAuto,
                  helperMaxLines: 2,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (location.mapWidthMiles != null)
          TextButton(
            onPressed: () => Navigator.pop(context, const _ScaleResult.clear()),
            child: Text(l10n.travelScaleClear),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _ScaleResult(
              widthMiles: _parse(width.text),
              heightMiles: _parse(height.text),
            ),
          ),
          child: Text(l10n.save),
        ),
      ],
    ),
  );

  if (result == null) return;
  await ref
      .read(worldRepositoryProvider)
      .setMapScale(
        location.id,
        widthMiles: result.widthMiles,
        heightMiles: result.heightMiles,
      );
}

class _ScaleResult {
  const _ScaleResult({this.widthMiles, this.heightMiles});
  const _ScaleResult.clear() : widthMiles = null, heightMiles = null;
  final double? widthMiles;
  final double? heightMiles;
}

double? _parse(String raw) {
  final value = double.tryParse(raw.trim().replaceAll(',', '.'));
  if (value == null || !value.isFinite || value <= 0) return null;
  return value;
}

/// "12.0" -> "12", "12.5" -> "12.5"
///
/// Seyahat arayuzunun her yerinde (mil, saat, ilerleme) ayni bicim kullanilsin
/// diye public; yolculuk seridi ve sayfasi da bunu cagirir.
String formatMiles(double value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}

/// Cok duraklı seyahat planlayıcısı.
Future<String?> showTravelPlanner(
  BuildContext context,
  WidgetRef ref, {
  required Location location,
  required List<MapPin> pins,
  List<JourneyStop> initialStops = const [],
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _TravelPlanner(
    location: location,
    pins: pins,
    initialStops: initialStops,
  ),
);

class _TravelPlanner extends ConsumerStatefulWidget {
  const _TravelPlanner({
    required this.location,
    required this.pins,
    this.initialStops = const [],
  });

  final Location location;
  final List<MapPin> pins;

  /// Haritaya cizilerek gelen rota (bkz. `LocationPage` rota modu).
  final List<JourneyStop> initialStops;

  @override
  ConsumerState<_TravelPlanner> createState() => _TravelPlannerState();
}

class _TravelPlannerState extends ConsumerState<_TravelPlanner> {
  /// Rotanin duraklari, sirayla.
  ///
  /// Pin id'si degil DURAGIN KENDISI saklaniyor: duraklarin bir kismi
  /// haritaya dogrudan dokunularak konmus, pini olmayan ara noktalar olabilir.
  final _stops = <JourneyStop>[];
  final _extraMiles = TextEditingController();
  final _customMph = TextEditingController(text: '3');
  final _hoursPerDay = TextEditingController();

  /// null = ozel hiz secili.
  TravelSpeed? _speed = kTravelSpeeds.firstWhere(
    (s) => s.key == 'travelPaceNormal',
  );
  bool _busy = false;

  // --- Rastgele karsilasma ayarlari ---------------------------------------
  /// Kapaliyken hic zar atilmaz; DM'in her yolculukta karsilasma istemesi
  /// gerekmiyor (sehirler arasi rutin yolculuk).
  bool _encountersOn = false;

  /// Secili rastgele tablonun id'si; null = tablo secilmedi (yalnizca
  /// "bir sey oldu" bilgisi doner).
  String? _tableId;
  int _threshold = kEncounterThresholdDefault;
  int _checksPerDay = 1;

  @override
  void initState() {
    super.initState();
    _hoursPerDay.text = formatMiles(_speed!.defaultHoursPerDay);
    _stops.addAll(widget.initialStops);
  }

  @override
  void dispose() {
    _extraMiles.dispose();
    _customMph.dispose();
    _hoursPerDay.dispose();
    super.dispose();
  }

  TravelSpeed get _effectiveSpeed =>
      _speed ?? TravelSpeed.custom(_parse(_customMph.text) ?? 0);

  MapScale? get _scale => MapScale.of(
    widthMiles: widget.location.mapWidthMiles,
    heightMiles: widget.location.mapHeightMiles,
    pixelWidth: widget.location.mapWidth,
    pixelHeight: widget.location.mapHeight,
  );

  TravelPlan? _plan() {
    final scale = _scale;
    if (scale == null) return null;
    return planRoute(
      JourneyRepository.pointsOf(_stops),
      scale,
      extraMiles: _parse(_extraMiles.text) ?? 0,
    );
  }

  /// Saat/gun alani hizin varsayilanindaysa SRD'nin kendi gunluk mesafesi
  /// (30/24/18) gecerli olsun diye `null`a cevrilir.
  double? get _hoursOverride =>
      overriddenHoursPerDay(_effectiveSpeed, _parse(_hoursPerDay.text));

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final scale = _scale;

    if (scale == null) return _missingScale(l10n);

    final plan = _plan()!;
    final estimate = estimateTravel(
      totalMiles: plan.totalMiles,
      speed: _effectiveSpeed,
      hoursPerDay: _hoursOverride,
    );
    final ready = _stops.length >= 2 && estimate.daysToAdvance > 0;

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
                      l10n.travelTitle,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  Text(
                    '${formatMiles(scale.widthMiles)} × '
                    '${formatMiles(scale.heightMiles)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    _routeSection(l10n, theme, plan),
                    const SizedBox(height: 16),
                    _speedSection(l10n, theme),
                    const SizedBox(height: 16),
                    _encounterSection(l10n, theme),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _extraMiles,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: l10n.travelExtraMiles,
                        helperText: l10n.travelExtraMilesHint,
                        helperMaxLines: 2,
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 24),
              _summary(l10n, theme, estimate),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: !ready || _busy ? null : () => _start(estimate),
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(l10n.journeyStart),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _missingScale(L10n l10n) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.travelTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(l10n.travelScaleMissing),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await showMapScaleDialog(context, ref, widget.location);
            },
            icon: const Icon(Icons.straighten, size: 18),
            label: Text(l10n.travelScaleSet),
          ),
        ],
      ),
    ),
  );

  Widget _routeSection(L10n l10n, ThemeData theme, TravelPlan plan) {
    // Pin yoksa bile rota kurulabilir: duraklar haritaya dogrudan
    // dokunularak da konabiliyor.
    if (widget.pins.isEmpty && _stops.isEmpty) {
      return Text(l10n.travelNoPins, style: theme.textTheme.bodySmall);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.travelRoute, style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        for (final (i, stop) in _stops.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  child: Text('${i + 1}', style: theme.textTheme.labelSmall),
                ),
                const SizedBox(width: 10),
                // Haritadan cizilen ara noktalar pinlerden ayirt edilsin.
                if (stop.pinId == null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.adjust,
                      size: 14,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                Expanded(
                  child: Text(
                    stop.label.isEmpty ? '—' : stop.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Bu duraga gelis bacaginin uzunlugu.
                if (i > 0 && i - 1 < plan.legs.length)
                  Text(
                    l10n.travelTotalMiles(formatMiles(plan.legs[i - 1].miles)),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _stops.removeAt(i)),
                ),
              ],
            ),
          ),
        if (_stops.length < 2)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Text(
              l10n.travelPickTwoStops,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addStop,
            icon: const Icon(Icons.add_location_alt_outlined, size: 18),
            label: Text(l10n.travelAddStop),
          ),
        ),
      ],
    );
  }

  Future<void> _addStop() async {
    final l10n = L10n.of(context);
    final picked = await showModalBottomSheet<MapPin>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                l10n.travelAddStop,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final pin in widget.pins)
              ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text(pin.label.isEmpty ? '—' : pin.label),
                onTap: () => Navigator.pop(context, pin),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      setState(
        () => _stops.add((
          pinId: picked.id,
          label: picked.label,
          x: picked.x,
          y: picked.y,
        )),
      );
    }
  }

  Widget _speedSection(L10n l10n, ThemeData theme) {
    String labelFor(TravelSpeed s) => switch (s.key) {
      'travelPaceFast' => l10n.travelPaceFast,
      'travelPaceNormal' => l10n.travelPaceNormal,
      'travelPaceSlow' => l10n.travelPaceSlow,
      'travelMountPony' => l10n.travelMountPony,
      'travelMountDraftHorse' => l10n.travelMountDraftHorse,
      'travelMountMastiff' => l10n.travelMountMastiff,
      'travelMountElephant' => l10n.travelMountElephant,
      'travelMountCamel' => l10n.travelMountCamel,
      'travelMountRidingHorse' => l10n.travelMountRidingHorse,
      'travelMountWarhorse' => l10n.travelMountWarhorse,
      'travelVehicleRowboat' => l10n.travelVehicleRowboat,
      'travelVehicleKeelboat' => l10n.travelVehicleKeelboat,
      'travelVehicleSailingShip' => l10n.travelVehicleSailingShip,
      'travelVehicleWarship' => l10n.travelVehicleWarship,
      'travelVehicleLongship' => l10n.travelVehicleLongship,
      'travelVehicleGalley' => l10n.travelVehicleGalley,
      _ => l10n.travelCustomSpeed,
    };

    Widget group(String title, TravelSpeedKind kind) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in kTravelSpeeds.where((s) => s.kind == kind))
              ChoiceChip(
                label: Text(labelFor(s)),
                selected: _speed?.key == s.key,
                onSelected: (_) => setState(() {
                  _speed = s;
                  // Saat/gun secilen hizin varsayilanindan tazelenir
                  // (kara 8, deniz 24).
                  _hoursPerDay.text = formatMiles(s.defaultHoursPerDay);
                }),
              ),
          ],
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.travelSpeed, style: theme.textTheme.titleSmall),
        group(l10n.travelGroupPaces, TravelSpeedKind.pace),
        group(l10n.travelGroupMounts, TravelSpeedKind.mount),
        group(l10n.travelGroupVehicles, TravelSpeedKind.vehicle),
        const SizedBox(height: 8),
        ChoiceChip(
          label: Text(l10n.travelCustomSpeed),
          selected: _speed == null,
          onSelected: (_) => setState(() => _speed = null),
        ),
        if (_speed == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextField(
              controller: _customMph,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n.travelMilesPerHour,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _hoursPerDay,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: l10n.travelHoursPerDay,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  /// Rastgele karsilasma ayarlari: tablo, esik, gunluk kontrol sayisi.
  ///
  /// Tablolar Tablolar sekmesindeki `RandomTables` kayitlari — ayri bir
  /// "karsilasma tablosu" turu ACILMADI; DM hangi tabloyu isterse (yol
  /// olaylari, canavarlar, hava) onu bagliyor.
  Widget _encounterSection(L10n l10n, ThemeData theme) {
    final tables =
        ref.watch(randomTablesProvider).value ?? const <RandomTable>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.travelEncounters),
          subtitle: Text(l10n.travelEncountersHint),
          value: _encountersOn,
          onChanged: (v) => setState(() => _encountersOn = v),
        ),
        if (_encountersOn) ...[
          if (tables.isEmpty)
            Text(
              l10n.travelEncounterNoTables,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: _tableId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.travelEncounterTable,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final t in tables)
                  DropdownMenuItem(
                    value: t.id,
                    child: Text(
                      t.category.isEmpty ? t.name : '${t.name} · ${t.category}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _tableId = v),
            ),
          const SizedBox(height: 8),
          Text(
            l10n.travelEncounterChance(
              _threshold,
              encounterChancePercent(_threshold),
            ),
            style: theme.textTheme.bodySmall,
          ),
          Slider(
            value: _threshold.toDouble(),
            min: kEncounterThresholdMin.toDouble(),
            max: kEncounterThresholdMax.toDouble(),
            divisions: kEncounterThresholdMax - kEncounterThresholdMin,
            label: '$_threshold+',
            onChanged: (v) => setState(() => _threshold = v.round()),
          ),
          const SizedBox(height: 4),
          Text(l10n.travelEncounterChecks, style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final n in kEncounterCheckOptions)
                ChoiceChip(
                  label: Text('$n×'),
                  selected: _checksPerDay == n,
                  onSelected: (_) => setState(() => _checksPerDay = n),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _summary(L10n l10n, ThemeData theme, TravelEstimate e) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        l10n.travelTotalMiles(formatMiles(e.totalMiles)),
        style: theme.textTheme.titleMedium,
      ),
      const SizedBox(height: 2),
      Text(_durationLabel(l10n, e), style: theme.textTheme.bodyMedium),
      if (e.daysToAdvance > 0)
        Text(
          l10n.travelAdvancesDays(e.daysToAdvance),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
    ],
  );

  /// "2 gun 3 saat" — artik saat 0 ise yalnizca gun.
  String _durationLabel(L10n l10n, TravelEstimate e) => e.remainderHours < 0.05
      ? l10n.travelDurationDaysOnly(e.wholeDays)
      : l10n.travelDuration(e.wholeDays, formatMiles(e.remainderHours));

  /// Onay -> yolculugu kaydet -> planlayiciyi kapat.
  ///
  /// Eskiden burada takvim ilerletilip yolculuk ANINDA bitirilirdi. Artik
  /// yolculuk SUREN bir kayit: karsilasmalar yolu boldugu icin ilerleme ve
  /// takvim adim adim `JourneyRunner` tarafindan isleniyor.
  ///
  /// Yolculuk sayfasini burasi ACMAZ; sheet kapandiktan sonra cagiran taraf
  /// acar (kapanan sayfanin `context`/`ref`'i uzerinden yeni bir sheet
  /// acilamaz).
  Future<void> _start(TravelEstimate estimate) async {
    final l10n = L10n.of(context);
    final routeLabel = [
      for (final s in _stops) s.label.isEmpty ? '—' : s.label,
    ].join(' → ');
    final milesLabel = formatMiles(estimate.totalMiles);

    final hasCalendar =
        (ref.read(calendarMonthsProvider).value ?? const []).isNotEmpty;
    var advance = hasCalendar;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          icon: const Icon(Icons.directions_walk),
          title: Text(l10n.travelConfirmTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.travelConfirmBody(
                  routeLabel,
                  milesLabel,
                  _durationLabel(l10n, estimate),
                ),
              ),
              if (hasCalendar)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: advance,
                  title: Text(
                    l10n.travelAdvanceCalendar(estimate.daysToAdvance),
                  ),
                  onChanged: (v) => setLocal(() => advance = v ?? false),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.journeyStart),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    final id = await ref
        .read(journeyRepositoryProvider)
        .start(
          locationId: widget.location.id,
          stops: List.of(_stops),
          totalMiles: estimate.totalMiles,
          speedKey: _speed?.key ?? 'travelCustomSpeed',
          customMph: _speed == null ? _parse(_customMph.text) : null,
          hoursPerDay:
              _parse(_hoursPerDay.text) ?? _effectiveSpeed.defaultHoursPerDay,
          extraMiles: _parse(_extraMiles.text) ?? 0,
          encountersOn: _encountersOn,
          // Karsilasma kapaliyken tablo secimi kaydedilmez: kayit ne ise o.
          tableId: _encountersOn ? _tableId : null,
          threshold: _threshold,
          checksPerDay: _checksPerDay,
          advanceCalendar: advance,
        );

    await ref
        .read(sessionLogRepositoryProvider)
        .add(l10n.journeyStarted(routeLabel, milesLabel));

    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.pop(context, id);
  }
}
