import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../data/world_repository.dart';

final worldRepositoryProvider = Provider<WorldRepository>(
  (ref) => WorldRepository(ref.watch(databaseProvider)),
);

final rootLocationsProvider = StreamProvider<List<Location>>(
  (ref) => ref.watch(worldRepositoryProvider).watchRoots(),
);

/// Dunya grafigi: tum lokasyon dugumleri.
final allLocationsProvider = StreamProvider<List<Location>>(
  (ref) => ref.watch(worldRepositoryProvider).watchAllLocations(),
);

/// Yalnizca harita ISARETI olan (haritasiz yer pini acmis) lokasyonlar.
///
/// Dunya dugum agi bunlari cizmiyor: gorev/planlayici listelerinde gozuksunler
/// diye acilmis kayitlar, gercek birer yer degil.
final markerLocationIdsProvider = StreamProvider<Set<String>>(
  (ref) => ref.watch(worldRepositoryProvider).watchMarkerLocationIds(),
);

/// Dunya grafigi: dugumler arasi yonsuz baglantilar (kenarlar).
final worldLinksProvider = StreamProvider<List<WorldLink>>(
  (ref) => ref.watch(worldRepositoryProvider).watchLinks(),
);

/// Duzenlenebilir bag turleri (ad + renk).
final bondTypesProvider = StreamProvider<List<BondType>>(
  (ref) => ref.watch(worldRepositoryProvider).watchBondTypes(),
);

final childLocationsProvider = StreamProvider.family<List<Location>, String>(
  (ref, parentId) => ref.watch(worldRepositoryProvider).watchChildren(parentId),
);

final locationProvider = StreamProvider.family<Location?, String>(
  (ref, id) => ref.watch(worldRepositoryProvider).watchLocation(id),
);

final breadcrumbProvider = FutureProvider.family<List<Location>, String>((
  ref,
  id,
) async {
  await ref.watch(locationProvider(id).future);
  return ref.watch(worldRepositoryProvider).breadcrumb(id);
});

final pinsProvider = StreamProvider.family<List<MapPin>, String>(
  (ref, locationId) => ref.watch(worldRepositoryProvider).watchPins(locationId),
);

/// Bir pinin isaret ettigi kaydin ozeti.
final pinTargetProvider = FutureProvider.family<PinTarget?, MapPin>(
  (ref, pin) => ref.watch(worldRepositoryProvider).resolveTarget(pin),
);

final npcsProvider = StreamProvider<List<Npc>>(
  (ref) => ref.watch(worldRepositoryProvider).watchNpcs(),
);

final factionsProvider = StreamProvider<List<Faction>>(
  (ref) => ref.watch(worldRepositoryProvider).watchFactions(),
);

final factionProvider = StreamProvider.family<Faction?, String>(
  (ref, id) => ref.watch(worldRepositoryProvider).watchFaction(id),
);

/// Bir dugumun (yer/NPC/fraksiyon) baglantilari, karsi ucun ADIYLA birlikte.
///
/// Kenarlar `worldLinksProvider`'a bagli: grafikte bir bag kurulunca bu liste
/// de kendiliginden tazelenir.
final nodeBondsProvider = FutureProvider.family<List<ResolvedBond>, String>((
  ref,
  nodeId,
) async {
  ref.watch(worldLinksProvider);
  final repo = ref.watch(worldRepositoryProvider);
  final bonds = await repo.bondsOf(nodeId);
  return [
    for (final bond in bonds)
      (
        linkId: bond.linkId,
        type: bond.type,
        otherId: bond.otherId,
        otherKind: bond.otherKind,
        // Silinmis bir uc null doner; arayuz bagi "kopuk" gosterir.
        otherName: await repo.nodeName(bond.otherKind, bond.otherId),
      ),
  ];
});

/// [nodeBondsProvider] sonucu: bag + karsi ucun cozulmus adi.
typedef ResolvedBond = ({
  String linkId,
  String type,
  String otherId,
  String otherKind,
  String? otherName,
});

/// "Bu kayıt nerelerde geçiyor?" -- bilgi agacinin geri referanslari.
final backlinksProvider = FutureProvider.family<List<Backlink>, String>(
  (ref, targetId) => ref.watch(worldRepositoryProvider).backlinks(targetId),
);
