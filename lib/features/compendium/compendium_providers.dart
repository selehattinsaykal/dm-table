import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../data/providers.dart';

/// Canavar sekmesinin filtre durumu.
class MonsterQuery {
  const MonsterQuery({
    this.text = '',
    this.minCr,
    this.maxCr,
    this.types = const {},
  });

  final String text;
  final double? minCr;
  final double? maxCr;
  final Set<String> types;

  MonsterQuery copyWith({
    String? text,
    double? Function()? minCr,
    double? Function()? maxCr,
    Set<String>? types,
  }) => MonsterQuery(
    text: text ?? this.text,
    minCr: minCr != null ? minCr() : this.minCr,
    maxCr: maxCr != null ? maxCr() : this.maxCr,
    types: types ?? this.types,
  );

  bool get hasFilters => minCr != null || maxCr != null || types.isNotEmpty;
}

class SpellQuery {
  const SpellQuery({
    this.text = '',
    this.levels = const {},
    this.schools = const {},
    this.concentrationOnly = false,
    this.ritualOnly = false,
  });

  final String text;
  final Set<int> levels;
  final Set<String> schools;
  final bool concentrationOnly;
  final bool ritualOnly;

  SpellQuery copyWith({
    String? text,
    Set<int>? levels,
    Set<String>? schools,
    bool? concentrationOnly,
    bool? ritualOnly,
  }) => SpellQuery(
    text: text ?? this.text,
    levels: levels ?? this.levels,
    schools: schools ?? this.schools,
    concentrationOnly: concentrationOnly ?? this.concentrationOnly,
    ritualOnly: ritualOnly ?? this.ritualOnly,
  );

  bool get hasFilters =>
      levels.isNotEmpty ||
      schools.isNotEmpty ||
      concentrationOnly ||
      ritualOnly;
}

class ItemQuery {
  const ItemQuery({this.text = '', this.categories = const {}});

  final String text;
  final Set<String> categories;

  ItemQuery copyWith({String? text, Set<String>? categories}) => ItemQuery(
    text: text ?? this.text,
    categories: categories ?? this.categories,
  );

  bool get hasFilters => categories.isNotEmpty;
}

class MagicItemQuery {
  const MagicItemQuery({
    this.text = '',
    this.rarities = const {},
    this.attunementOnly = false,
  });

  final String text;
  final Set<String> rarities;
  final bool attunementOnly;

  MagicItemQuery copyWith({
    String? text,
    Set<String>? rarities,
    bool? attunementOnly,
  }) => MagicItemQuery(
    text: text ?? this.text,
    rarities: rarities ?? this.rarities,
    attunementOnly: attunementOnly ?? this.attunementOnly,
  );

  bool get hasFilters => rarities.isNotEmpty || attunementOnly;
}

/// Filtre durumunu tutan basit notifier'lar.
///
/// Riverpod 3'te `StateProvider` legacy'ye tasindi; dort sekme de ayni
/// "tek deger tut, degistir" davranisini istedigi icin tek bir taban sinif.
class QueryNotifier<T> extends Notifier<T> {
  QueryNotifier(this._initial);

  final T _initial;

  @override
  T build() => _initial;

  void set(T next) => state = next;

  void reset() => state = _initial;
}

final monsterQueryProvider =
    NotifierProvider<QueryNotifier<MonsterQuery>, MonsterQuery>(
      () => QueryNotifier(const MonsterQuery()),
    );
final spellQueryProvider =
    NotifierProvider<QueryNotifier<SpellQuery>, SpellQuery>(
      () => QueryNotifier(const SpellQuery()),
    );
final itemQueryProvider = NotifierProvider<QueryNotifier<ItemQuery>, ItemQuery>(
  () => QueryNotifier(const ItemQuery()),
);
final magicItemQueryProvider =
    NotifierProvider<QueryNotifier<MagicItemQuery>, MagicItemQuery>(
      () => QueryNotifier(const MagicItemQuery()),
    );

/// Sadece metin aramasi yapan sekmeler (feat, irk, geçmiş).
class TextQuery {
  const TextQuery({this.text = ''});
  final String text;
  TextQuery copyWith({String? text}) => TextQuery(text: text ?? this.text);
}

final featQueryProvider = NotifierProvider<QueryNotifier<TextQuery>, TextQuery>(
  () => QueryNotifier(const TextQuery()),
);
final speciesQueryProvider =
    NotifierProvider<QueryNotifier<TextQuery>, TextQuery>(
      () => QueryNotifier(const TextQuery()),
    );
final backgroundQueryProvider =
    NotifierProvider<QueryNotifier<TextQuery>, TextQuery>(
      () => QueryNotifier(const TextQuery()),
    );

final monsterResultsProvider = FutureProvider<List<Monster>>((ref) {
  final q = ref.watch(monsterQueryProvider);
  return ref
      .watch(compendiumRepositoryProvider)
      .searchMonsters(
        query: q.text,
        minCr: q.minCr,
        maxCr: q.maxCr,
        creatureTypes: q.types,
      );
});

final spellResultsProvider = FutureProvider<List<Spell>>((ref) {
  final q = ref.watch(spellQueryProvider);
  return ref
      .watch(compendiumRepositoryProvider)
      .searchSpells(
        query: q.text,
        levels: q.levels,
        schools: q.schools,
        concentrationOnly: q.concentrationOnly,
        ritualOnly: q.ritualOnly,
      );
});

final itemResultsProvider = FutureProvider<List<Item>>((ref) {
  final q = ref.watch(itemQueryProvider);
  return ref
      .watch(compendiumRepositoryProvider)
      .searchItems(query: q.text, categories: q.categories);
});

final magicItemResultsProvider = FutureProvider<List<MagicItem>>((ref) {
  final q = ref.watch(magicItemQueryProvider);
  return ref
      .watch(compendiumRepositoryProvider)
      .searchMagicItems(
        query: q.text,
        rarities: q.rarities,
        requiresAttunement: q.attunementOnly ? true : null,
      );
});

final featResultsProvider = FutureProvider<List<Feat>>((ref) {
  final q = ref.watch(featQueryProvider);
  return ref.watch(compendiumRepositoryProvider).searchFeats(query: q.text);
});
final speciesResultsProvider = FutureProvider<List<SpeciesEntry>>((ref) {
  final q = ref.watch(speciesQueryProvider);
  return ref.watch(compendiumRepositoryProvider).searchSpecies(query: q.text);
});
final backgroundResultsProvider = FutureProvider<List<Background>>((ref) {
  final q = ref.watch(backgroundQueryProvider);
  return ref
      .watch(compendiumRepositoryProvider)
      .searchBackgrounds(query: q.text);
});

/// Filtre ciplerinin secenekleri veriden okunur.
final creatureTypesProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(compendiumRepositoryProvider).distinctCreatureTypes(),
);
final itemCategoriesProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(compendiumRepositoryProvider).distinctItemCategories(),
);
final raritiesProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(compendiumRepositoryProvider).rarityNames(),
);
