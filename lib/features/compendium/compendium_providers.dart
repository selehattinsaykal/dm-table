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
    this.documents = const {},
  });

  final String text;
  final double? minCr;
  final double? maxCr;
  final Set<String> types;
  final Set<String> documents;

  MonsterQuery copyWith({
    String? text,
    double? Function()? minCr,
    double? Function()? maxCr,
    Set<String>? types,
    Set<String>? documents,
  }) => MonsterQuery(
    text: text ?? this.text,
    minCr: minCr != null ? minCr() : this.minCr,
    maxCr: maxCr != null ? maxCr() : this.maxCr,
    types: types ?? this.types,
    documents: documents ?? this.documents,
  );

  bool get hasFilters =>
      minCr != null ||
      maxCr != null ||
      types.isNotEmpty ||
      documents.isNotEmpty;
}

class SpellQuery {
  const SpellQuery({
    this.text = '',
    this.levels = const {},
    this.schools = const {},
    this.concentrationOnly = false,
    this.ritualOnly = false,
    this.documents = const {},
  });

  final String text;
  final Set<int> levels;
  final Set<String> schools;
  final bool concentrationOnly;
  final bool ritualOnly;
  final Set<String> documents;

  SpellQuery copyWith({
    String? text,
    Set<int>? levels,
    Set<String>? schools,
    bool? concentrationOnly,
    bool? ritualOnly,
    Set<String>? documents,
  }) => SpellQuery(
    text: text ?? this.text,
    levels: levels ?? this.levels,
    schools: schools ?? this.schools,
    concentrationOnly: concentrationOnly ?? this.concentrationOnly,
    ritualOnly: ritualOnly ?? this.ritualOnly,
    documents: documents ?? this.documents,
  );

  bool get hasFilters =>
      levels.isNotEmpty ||
      schools.isNotEmpty ||
      concentrationOnly ||
      ritualOnly ||
      documents.isNotEmpty;
}

class ItemQuery {
  const ItemQuery({
    this.text = '',
    this.categories = const {},
    this.documents = const {},
  });

  final String text;
  final Set<String> categories;
  final Set<String> documents;

  ItemQuery copyWith({
    String? text,
    Set<String>? categories,
    Set<String>? documents,
  }) => ItemQuery(
    text: text ?? this.text,
    categories: categories ?? this.categories,
    documents: documents ?? this.documents,
  );

  bool get hasFilters => categories.isNotEmpty || documents.isNotEmpty;
}

class MagicItemQuery {
  const MagicItemQuery({
    this.text = '',
    this.rarities = const {},
    this.attunementOnly = false,
    this.documents = const {},
  });

  final String text;
  final Set<String> rarities;
  final bool attunementOnly;
  final Set<String> documents;

  MagicItemQuery copyWith({
    String? text,
    Set<String>? rarities,
    bool? attunementOnly,
    Set<String>? documents,
  }) => MagicItemQuery(
    text: text ?? this.text,
    rarities: rarities ?? this.rarities,
    attunementOnly: attunementOnly ?? this.attunementOnly,
    documents: documents ?? this.documents,
  );

  bool get hasFilters =>
      rarities.isNotEmpty || attunementOnly || documents.isNotEmpty;
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
  const TextQuery({this.text = '', this.documents = const {}});
  final String text;
  final Set<String> documents;
  TextQuery copyWith({String? text, Set<String>? documents}) => TextQuery(
    text: text ?? this.text,
    documents: documents ?? this.documents,
  );
}

final featQueryProvider = NotifierProvider<QueryNotifier<TextQuery>, TextQuery>(
  () => QueryNotifier(const TextQuery()),
);
final classQueryProvider =
    NotifierProvider<QueryNotifier<TextQuery>, TextQuery>(
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
        documents: q.documents,
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
        documents: q.documents,
      );
});

/// Esya listesi -- METIN ARAMASI YAPILMAZ.
///
/// Feat listesiyle ayni gerekce (bkz. [featResultsProvider]): esya ADLARI
/// ekranda Turkce (`names_tr.json`), veritabani Ingilizce tutuyor. SQL'de
/// aramak "hançer" yazan kullaniciya hicbir sey bulmazdi. 460 kayit oldugu
/// icin tamami okunup suzme ve siralama gorunen ada gore ekranda yapiliyor.
final itemResultsProvider = FutureProvider<List<Item>>((ref) {
  final q = ref.watch(itemQueryProvider);
  return ref
      .watch(compendiumRepositoryProvider)
      .searchItems(
        categories: q.categories,
        documents: q.documents,
        limit: 1000,
      );
});

/// Buyulu esya listesi -- METIN ARAMASI YAPILMAZ ([itemResultsProvider] ile
/// ayni gerekce). Siralama nadirlige gore SQL'de kaliyor; ad siralamasi
/// ekranda Turkceye gore yapiliyor.
final magicItemResultsProvider = FutureProvider<List<MagicItem>>((ref) {
  final q = ref.watch(magicItemQueryProvider);
  return ref
      .watch(compendiumRepositoryProvider)
      .searchMagicItems(
        rarities: q.rarities,
        requiresAttunement: q.attunementOnly ? true : null,
        documents: q.documents,
        limit: 2000,
      );
});

/// Feat listesi -- METIN ARAMASI YAPILMAZ.
///
/// Feat ADLARI ekranda Turkce gosteriliyor (`names_tr.json`), ama veritabani
/// Ingilizce adi tutuyor; SQL'de aramak "Silah Ustası" yazan kullaniciya hicbir
/// sey bulmazdi. 150 kayitlik bir set oldugu icin tamami okunup suzme ve
/// siralama GORUNEN ada gore ekran tarafinda yapiliyor (bkz. `_FeatTab`).
final featResultsProvider = FutureProvider<List<Feat>>((ref) {
  final q = ref.watch(featQueryProvider);
  return ref
      .watch(compendiumRepositoryProvider)
      .searchFeats(documents: q.documents, limit: 1000);
});

/// Anahtariyla tek bir feat kaydi; karakter kagidi, uzerine yazilmis
/// Ingilizce metin yerine kutuphanedeki (cevrilebilen) kaydi gostersin diye.
final featByKeyProvider = FutureProvider.family<Feat?, String>((
  ref,
  key,
) async {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.feats,
  )..where((t) => t.key.equals(key))).getSingleOrNull();
});

final classResultsProvider = FutureProvider<List<ClassDefinition>>((ref) {
  final q = ref.watch(classQueryProvider);
  return ref
      .watch(compendiumRepositoryProvider)
      .searchClasses(query: q.text, documents: q.documents);
});

/// Bir sinifin ilerleme tablosu (kutuphane detayinda gosteriliyor).
final classProgressionProvider =
    FutureProvider.family<List<ClassProgression>, String>(
      (ref, classKey) =>
          ref.watch(compendiumRepositoryProvider).progressionOf(classKey),
    );

/// Bir sinifin alt siniflari (kutuphane detayinda listeleniyor).
final compendiumSubclassesProvider =
    FutureProvider.family<List<ClassDefinition>, String>((ref, classKey) async {
      final all = await ref
          .watch(compendiumRepositoryProvider)
          .searchClasses(limit: 500);
      return all.where((c) => c.subclassOf == classKey).toList();
    });

final speciesResultsProvider = FutureProvider<List<SpeciesEntry>>((ref) {
  final q = ref.watch(speciesQueryProvider);
  return ref
      .watch(compendiumRepositoryProvider)
      .searchSpecies(query: q.text, documents: q.documents);
});
final backgroundResultsProvider = FutureProvider<List<Background>>((ref) {
  final q = ref.watch(backgroundQueryProvider);
  return ref
      .watch(compendiumRepositoryProvider)
      .searchBackgrounds(query: q.text, documents: q.documents);
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
final documentsProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(compendiumRepositoryProvider).distinctDocuments(),
);
