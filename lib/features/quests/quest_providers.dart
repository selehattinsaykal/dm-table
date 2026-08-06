import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../data/quest_repository.dart';

final questRepositoryProvider = Provider<QuestRepository>(
  (ref) => QuestRepository(ref.watch(databaseProvider)),
);

final questsProvider = StreamProvider<List<Quest>>(
  (ref) => ref.watch(questRepositoryProvider).watchAll(),
);
