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

/// "Bu kayıt nerelerde geçiyor?" -- bilgi agacinin geri referanslari.
final backlinksProvider = FutureProvider.family<List<Backlink>, String>(
  (ref, targetId) => ref.watch(worldRepositoryProvider).backlinks(targetId),
);
