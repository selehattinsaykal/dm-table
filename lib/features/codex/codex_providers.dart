import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/codex_repository.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';

final codexRepositoryProvider = Provider<CodexRepository>(
  (ref) => CodexRepository(ref.watch(databaseProvider)),
);

/// Tum sayfalar (agac UI tarafinda kuruluyor).
final codexPagesProvider = StreamProvider<List<CodexPage>>(
  (ref) => ref.watch(codexRepositoryProvider).watchPages(),
);

final codexPageProvider = StreamProvider.family<CodexPage?, String>(
  (ref, id) => ref.watch(codexRepositoryProvider).watchPage(id),
);

final codexBlocksProvider = StreamProvider.family<List<CodexBlock>, String>(
  (ref, pageId) => ref.watch(codexRepositoryProvider).watchBlocks(pageId),
);
