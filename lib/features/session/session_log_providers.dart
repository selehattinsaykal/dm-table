import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../data/session_log_repository.dart';

final sessionLogRepositoryProvider = Provider<SessionLogRepository>(
  (ref) => SessionLogRepository(ref.watch(databaseProvider)),
);

/// Kalici oturum gunlugu (en yeni ustte).
final sessionLogProvider = StreamProvider<List<SessionLogEntry>>(
  (ref) => ref.watch(sessionLogRepositoryProvider).watchRecent(),
);
