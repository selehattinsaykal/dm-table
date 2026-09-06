import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ui/ui.dart';
import '../../data/db/database.dart';
import '../../data/db/world_tables.dart';
import '../../data/journey_repository.dart';
import '../../l10n/app_localizations.dart';
import '../combat/combat_providers.dart';
import '../combat/encounter_page.dart';
import 'journey_providers.dart';
import 'journey_sheet.dart';
import 'map_view.dart';
import 'pick_image_file.dart';
import 'pin_editor.dart';
import 'travel_planner.dart';
import 'world_page.dart' show askForName;
import 'world_providers.dart';

/// Tek bir yerin sayfasi: haritasi, pinleri ve alt yerleri.
///
/// Pin yerleştirme modu ayri bir durum: masada yanlislikla pin birakmak
/// yerine DM once "pin ekle" diyor, sonra haritaya dokunuyor.
class LocationPage extends ConsumerStatefulWidget {
  const LocationPage({required this.locationId, super.key});

  final String locationId;

  @override
  ConsumerState<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends ConsumerState<LocationPage> {
  /// Su an bakilan yer. Alt yerlere pinden/serit/ekmek kirintisindan girmek
  /// yeni bir sayfa ACMAZ, yalnizca bunu degistirir; boylece "Geri" tusu daima
  /// bir UST haritaya cikar (gezinme gecmisine degil).
  late String _id = widget.locationId;
  bool _placingPin = false;
  bool _busy = false;

  /// Duzenleme modu. KAPALI baslar.
  ///
  /// Neden kapali: bu sayfa masada oyun SIRASINDA acik duruyor ve pinler
  /// dogrudan surukelenebiliyordu — haritayi kaydirmak isterken bir sehri
  /// yerinden oynatmak sessizce veriyi bozuyor. Artik icerigi degistiren her
  /// jest (pin ekle/tasi/duzenle, harita yukle, yeri sil) bu modun arkasinda;
  /// kapaliyken harita salt-okunur durur.
  ///
  /// Alt yerlere gecerken SIFIRLANMAZ (bkz. [_go]): mod bir "durus"tur --
  /// hazirlik yapan DM birkac harita gezerken her seferinde yeniden acmasin.
  bool _editMode = false;

  /// Rota cizme modu: haritaya dokunmak durak ekler.
  ///
  /// Pin koymaktan ayri bir mod: masada yanlislikla rota kirmak ya da rota
  /// cizerken pin birakmak istemiyoruz, ikisi ayni anda ACIK OLAMAZ.
  bool _drawingRoute = false;
  final _routeStops = <JourneyStop>[];

  void _go(String id) => setState(() {
    _id = id;
    _placingPin = false;
    _drawingRoute = false;
    _routeStops.clear();
  });

  /// Geri: ust yer varsa ona cik; yoksa dunya agacina don.
  void _up(Location location) {
    final parent = location.parentId;
    if (parent != null) {
      _go(parent);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = ref.watch(locationProvider(_id)).value;
    final pins = ref.watch(pinsProvider(_id)).value ?? const [];
    final trail = ref.watch(breadcrumbProvider(_id)).value ?? const [];

    if (location == null) {
      return const Scaffold(body: AppLoading());
    }
    final l10n = L10n.of(context);

    final journey = ref.watch(activeJourneyProvider).value;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: location.parentId != null
              ? l10n.worldParentLocation
              : l10n.worldBack,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _up(location),
        ),
        title: Text(location.name),
        actions: [
          // Olcek girilmisse seyahat her oturum kullanilan bir sey; menude
          // degil arac cubugunda dursun.
          //
          // TEK dugme: eskiden "rota ciz" ve "seyahat" ayri ikonlardi, ama
          // ikisi ayni isin iki yariciydi (duraklari topla / mesafeyi hesapla)
          // ve hangisinin nereye gittigi belirsizdi. Artik tek giris:
          // planlayici acilir, duraklar ya pin listesinden secilir ya da
          // oradaki "haritada ciz" ile haritaya cizilir.
          //
          // Rota cizilirken gizlenir: o sirada akisi serit yonetiyor.
          if (location.mapWidthMiles != null && !_drawingRoute)
            IconButton(
              tooltip: l10n.travelPlanAction,
              icon: const Icon(Icons.directions_walk),
              onPressed: () => _openPlanner(location, pins),
            ),
          if (_editMode && location.mapImagePath != null)
            IconButton(
              tooltip: _placingPin ? l10n.worldStopAddingPin : l10n.worldAddPin,
              icon: Icon(_placingPin ? Icons.close : Icons.add_location_alt),
              onPressed: () => setState(() {
                _placingPin = !_placingPin;
                if (_placingPin) _drawingRoute = false;
              }),
            ),
          // Duzenleme modu anahtari; tum detay sayfalariyla ORTAK
          // (bkz. `app/ui/edit_mode.dart`).
          EditModeButton(editing: _editMode, onToggle: _toggleEditMode),
          // Menudeki her sey icerik degistirir (harita yukle/kaldir, olcek,
          // yeniden adlandir, alt yer ekle, sil); goruntuleme modunda hic
          // gorunmez. Seyahat menude degil arac cubugunda duruyor.
          if (_editMode)
            PopupMenuButton<String>(
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'map',
                  child: Text(
                    location.mapImagePath == null
                        ? l10n.worldUploadMap
                        : l10n.worldChangeMap,
                  ),
                ),
                if (location.mapImagePath != null) ...[
                  PopupMenuItem(
                    value: 'removeMap',
                    child: Text(l10n.worldRemoveMap),
                  ),
                  PopupMenuItem(
                    value: 'scale',
                    child: Text(l10n.travelScaleTitle),
                  ),
                  PopupMenuItem(
                    value: 'travel',
                    child: Text(l10n.travelPlanAction),
                  ),
                ],
                PopupMenuItem(value: 'rename', child: Text(l10n.worldRename)),
                PopupMenuItem(value: 'child', child: Text(l10n.worldAddChild)),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(l10n.worldDeleteLocation),
                ),
              ],
              onSelected: (a) => _onMenu(a, location, pins),
            ),
        ],
        bottom: trail.length > 1
            ? PreferredSize(
                preferredSize: const Size.fromHeight(32),
                child: _Breadcrumb(trail: trail, onOpen: _go),
              )
            : null,
      ),
      body: _busy
          ? const AppLoading()
          : Column(
              children: [
                if (_drawingRoute)
                  _RouteBanner(
                    stops: _routeStops,
                    onUndo: _routeStops.isEmpty
                        ? null
                        : () => setState(_routeStops.removeLast),
                    onCancel: _toggleRouteMode,
                    onPlan: _routeStops.length < 2
                        ? null
                        : () => _planDrawnRoute(location),
                  )
                else if (_placingPin)
                  MaterialBanner(
                    content: Text(l10n.worldTapToPlacePin),
                    actions: [
                      TextButton(
                        onPressed: () => setState(() => _placingPin = false),
                        child: Text(l10n.cancel),
                      ),
                    ],
                  )
                else if (journey != null && journey.locationId == _id)
                  _JourneyBanner(journey: journey)
                // Serit YALNIZCA duzenleme modunda: goruntulerken harita
                // temiz kalmali.
                else if (_editMode && location.mapImagePath != null)
                  MaterialBanner(
                    content: Text(l10n.worldPinDragHint),
                    actions: const [SizedBox.shrink()],
                  ),
                Expanded(
                  child: location.mapImagePath == null
                      ? _NoMap(
                          onUpload: _editMode ? () => _pickMap(location) : null,
                        )
                      : MapView(
                          location: location,
                          pins: pins,
                          editing: _editMode,
                          route: [
                            for (final s in _routeStops) (x: s.x, y: s.y),
                          ],
                          onTapEmpty: _drawingRoute
                              ? _addRouteStop
                              : (_placingPin ? _createPinAt : null),
                          onTapPin: _drawingRoute ? _addPinToRoute : _openPin,
                          // Sag tik / uzun bas: pinin ayarlari. Dokunmak
                          // alt haritaya girdigi icin duzenleyiciye baska
                          // bir yol gerekiyordu.
                          onPinSettings: (_drawingRoute || !_editMode)
                              ? null
                              : _editPin,
                          // Rota cizerken pin surukleme kapali: dokunuslar
                          // rotaya ait. Goruntuleme modunda da kapali --
                          // asil sebep buydu: haritayi kaydirmak isterken
                          // pin yerinden oynuyordu.
                          onMovePin: (_drawingRoute || !_editMode)
                              ? null
                              : (pin, x, y) => ref
                                    .read(worldRepositoryProvider)
                                    .updatePin(pin.id, x: x, y: y),
                        ),
                ),
                _EncountersStrip(locationId: _id),
                _ChildrenStrip(locationId: _id, onOpen: _go),
              ],
            ),
    );
  }

  Future<void> _onMenu(
    String action,
    Location location,
    List<MapPin> pins,
  ) async {
    final repo = ref.read(worldRepositoryProvider);
    final l10n = L10n.of(context);

    switch (action) {
      case 'map':
        await _pickMap(location);
      case 'removeMap':
        await repo.removeMapImage(_id);
      case 'scale':
        await showMapScaleDialog(context, ref, location);
      case 'travel':
        await _openPlanner(location, pins);
      case 'rename':
        if (!mounted) return;
        final name = await askForName(
          context,
          title: l10n.worldRename,
          initial: location.name,
        );
        if (name != null) await repo.updateLocation(_id, name: name);
      case 'child':
        if (!mounted) return;
        final name = await askForName(context, title: l10n.worldAddChild);
        if (name == null) return;
        await repo.createLocation(name: name, parentId: _id);
      case 'delete':
        if (!mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.worldDeleteConfirmTitle(location.name)),
            content: Text(l10n.worldDeleteConfirmBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.delete),
              ),
            ],
          ),
        );
        if (confirmed ?? false) {
          await repo.deleteLocation(_id);
          // Silinen yerden ust yere/agaca cik.
          if (mounted) _up(location);
        }
    }
  }

  Future<void> _pickMap(Location location) async {
    final picked = await pickImageFile(
      typeLabel: L10n.of(context).fileTypeImage,
    );
    if (picked == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(worldRepositoryProvider).setMapImage(_id, picked);
    } on FormatException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Haritada bos bir noktaya dokunulunca yeni pin akisini baslatir.
  Future<void> _createPinAt(double x, double y) async {
    setState(() => _placingPin = false);
    await showPinEditor(context, ref, locationId: _id, x: x, y: y);
  }

  /// Duzenleme modunu ac/kapa. Kapatirken pin yerlestirme modu da duser:
  /// aksi halde "haritaya dokun" seridi acik kalir ama dokunus is yapmaz.
  void _toggleEditMode() => setState(() {
    _editMode = !_editMode;
    if (!_editMode) _placingPin = false;
  });

  void _toggleRouteMode() => setState(() {
    _drawingRoute = !_drawingRoute;
    _placingPin = false;
    _routeStops.clear();
  });

  /// Haritada bos bir noktaya dokunmak ARA NOKTA ekler (pini yoktur).
  void _addRouteStop(double x, double y) => setState(
    () => _routeStops.add((
      pinId: null,
      label: L10n.of(context).travelWaypoint(_routeStops.length + 1),
      x: x,
      y: y,
    )),
  );

  /// Rota modunda pine dokunmak onu adiyla durak yapar (duzenleyici acmaz).
  void _addPinToRoute(MapPin pin) => setState(
    () => _routeStops.add((
      pinId: pin.id,
      label: pin.label.isEmpty
          ? L10n.of(context).travelWaypoint(_routeStops.length + 1)
          : pin.label,
      x: pin.x,
      y: pin.y,
    )),
  );

  /// Cizilen rotayi seyahat planlayicisina tasir.
  Future<void> _planDrawnRoute(Location location) async {
    final stops = List<JourneyStop>.from(_routeStops);
    setState(() {
      _drawingRoute = false;
      _routeStops.clear();
    });
    final pins = ref.read(pinsProvider(_id)).value ?? const <MapPin>[];
    if (!mounted) return;
    await _openPlanner(location, pins, initialStops: stops);
  }

  /// Planlayiciyi acar; yolculuk baslatildiysa yolculuk sayfasini da acar.
  ///
  /// Sayfayi planlayici KENDI acamaz: kapanmakta olan bir sheet'in context'i
  /// uzerinden yeni bir sheet acilamiyor.
  Future<void> _openPlanner(
    Location location,
    List<MapPin> pins, {
    List<JourneyStop> initialStops = const [],
  }) async {
    final started = await showTravelPlanner(
      context,
      ref,
      location: location,
      pins: pins,
      initialStops: initialStops,
      // Planlayicidan haritaya cizmeye gecis: sheet kapanir, sayfa rota
      // moduna girer. Seritteki "Planla" planlayiciyi ciziligi duraklarla
      // geri acar, yani akis kapali bir dongu.
      onDrawOnMap: () => setState(() {
        _drawingRoute = true;
        _placingPin = false;
        _routeStops.clear();
      }),
    );
    if (started == null || !mounted) return;
    await showJourneySheet(context, ref);
  }

  /// Pin ayarlari (tur, etiket, hedef...).
  Future<void> _editPin(MapPin pin) async {
    await showPinEditor(context, ref, locationId: _id, pin: pin);
  }

  Future<void> _openPin(MapPin pin) async {
    // Alt lokasyon pini dogrudan icine girer: gezinme her iki modda da acik,
    // cunku yer degistirmek icerigi degistirmez.
    if (pin.kind == PinKind.location && pin.targetId != null) {
      _go(pin.targetId!);
      return;
    }
    if (!mounted) return;
    // Goruntuleme modunda duzenleyici degil salt-okunur ozet acilir; masada
    // bir nota bakmak bir seyi degistirme riski tasimamali.
    if (_editMode) {
      await _editPin(pin);
    } else {
      await showPinInfo(context, ref, pin: pin);
    }
  }
}

/// Rota cizerken gorunen serit: kac durak var, geri al / vazgec / planla.
class _RouteBanner extends StatelessWidget {
  const _RouteBanner({
    required this.stops,
    required this.onUndo,
    required this.onCancel,
    required this.onPlan,
  });

  final List<JourneyStop> stops;
  final VoidCallback? onUndo;
  final VoidCallback onCancel;
  final VoidCallback? onPlan;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return MaterialBanner(
      content: Text(
        stops.length < 2
            ? l10n.travelDrawRouteHint
            : l10n.travelDrawRouteStops(stops.length),
      ),
      actions: [
        TextButton(onPressed: onUndo, child: Text(l10n.travelRouteUndo)),
        TextButton(onPressed: onCancel, child: Text(l10n.cancel)),
        FilledButton(onPressed: onPlan, child: Text(l10n.travelRoutePlan)),
      ],
    );
  }
}

/// Suren yolculugun serit ozeti: ne kadar gidildi, devam et.
class _JourneyBanner extends ConsumerWidget {
  const _JourneyBanner({required this.journey});

  final Journey journey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    return MaterialBanner(
      leading: const Icon(Icons.directions_walk),
      content: Text(
        l10n.journeyBannerProgress(
          formatMiles(journey.milesTravelled),
          formatMiles(journey.totalMiles),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => showJourneySheet(context, ref),
          child: Text(l10n.journeyOpen),
        ),
      ],
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.trail, required this.onOpen});

  final List<Location> trail;
  final void Function(String id) onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: trail.length,
        separatorBuilder: (_, _) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Center(
            child: Icon(
              Icons.chevron_right,
              size: 14,
              color: theme.colorScheme.outline,
            ),
          ),
        ),
        itemBuilder: (context, i) {
          final isLast = i == trail.length - 1;
          return Center(
            child: InkWell(
              // Son halka zaten acik olan sayfa.
              onTap: isLast ? null : () => onOpen(trail[i].id),
              child: Text(
                trail[i].name,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isLast
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.primary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NoMap extends StatelessWidget {
  const _NoMap({required this.onUpload});

  /// Null = goruntuleme modu: yukleme bir duzenleme islemi oldugu icin dugme
  /// yerine modu acmayi soyleyen bir ipucu gosterilir (dugmeyi gosterip
  /// calismamasindan iyi).
  final VoidCallback? onUpload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(l10n.worldNoMap, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              onUpload == null
                  ? l10n.worldNoMapViewModeHint
                  : l10n.worldNoMapHint,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (onUpload != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onUpload,
                icon: const Icon(Icons.upload),
                label: Text(l10n.worldUploadMap),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Haritada pini olmayan alt yerler de erisilebilir kalsin diye alt serit.
/// Bu yerde gecen karsilasmalar; yoksa hic yer kaplamaz.
///
/// Bagin OKUMA ucu: karsilasma sayfasinda "nerede geciyor" secilir, burada
/// "burada ne oluyor" okunur. Hazirlik yaparken DM'in en cok sordugu sey bu.
class _EncountersStrip extends ConsumerWidget {
  const _EncountersStrip({required this.locationId});

  final String locationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final encounters =
        ref.watch(encountersAtProvider(locationId)).value ?? const [];
    if (encounters.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return SizedBox(
      height: 56,
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: encounters.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) => ActionChip(
            avatar: Icon(
              encounters[i].started ? Icons.shield : Icons.shield_outlined,
              size: 18,
              color: encounters[i].started ? theme.colorScheme.primary : null,
            ),
            label: Text(encounters[i].name),
            onPressed: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                builder: (_) => EncounterPage(encounterId: encounters[i].id),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChildrenStrip extends ConsumerWidget {
  const _ChildrenStrip({required this.locationId, required this.onOpen});

  final String locationId;
  final void Function(String id) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(childLocationsProvider(locationId)).value ?? const [];

    // Haritasiz YER pinlerinin arkasindaki lokasyonlar buraya GIRMEZ: bu serit
    // "icine girilebilecek alt yerler" icin. Onlara girilse bos bir harita
    // yukleme ekrani acilirdi -- oysa haritalari hic olmayacak.
    final placeTargets = {
      for (final pin in ref.watch(pinsProvider(locationId)).value ?? const [])
        if (pin.kind == PinKind.place && pin.targetId != null) pin.targetId!,
    };
    final children = [
      for (final c in all)
        if (!placeTargets.contains(c.id)) c,
    ];
    if (children.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 56,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: children.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) => ActionChip(
            avatar: Icon(
              children[i].mapImagePath != null
                  ? Icons.map
                  : Icons.place_outlined,
              size: 18,
            ),
            label: Text(children[i].name),
            onPressed: () => onOpen(children[i].id),
          ),
        ),
      ),
    );
  }
}
