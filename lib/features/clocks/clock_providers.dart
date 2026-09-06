import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/clock_repository.dart';
import '../../data/db/clock_tables.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';

final clockRepositoryProvider = Provider<ClockRepository>(
  (ref) => ClockRepository(ref.watch(databaseProvider)),
);

final clocksProvider = StreamProvider<List<Clock>>(
  (ref) => ref.watch(clockRepositoryProvider).watchAll(),
);

/// Bir kayda bagli saatler. Aile anahtari `(tur, kimlik)` cifti.
final linkedClocksProvider =
    StreamProvider.family<List<Clock>, ({ClockLinkKind kind, String id})>(
      (ref, key) =>
          ref.watch(clockRepositoryProvider).watchLinked(key.kind, key.id),
    );
