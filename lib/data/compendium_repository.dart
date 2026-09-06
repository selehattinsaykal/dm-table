import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../domain/search_text.dart';
import 'character_image_store.dart';
import 'db/database.dart';
import 'db/tables.dart';

/// Toplu portre ice aktarma sonucu: kac canavara atandi, hangi dosyalar
/// eslesmedi.
class MonsterPortraitImport {
  const MonsterPortraitImport({
    required this.assigned,
    required this.unmatched,
  });

  final int assigned;
  final List<String> unmatched;
}

/// Kutuphane sorgulari.
///
/// Filtreler SQL tarafinda uygulaniyor: masada 3500 canavarin arasindan
/// arama yapilirken tum tabloyu bellege cekmek istemiyoruz.
class CompendiumRepository {
  CompendiumRepository(this.db, {CharacterImageStore? portraits})
    : portraits = portraits ?? CharacterImageStore();

  final AppDatabase db;

  /// Canavar portreleri dosyada saklanir (karakter portreleriyle ayni store;
  /// UUID adlari cakismaz).
  final CharacterImageStore portraits;

  // Liste arti 5000'den fazla kayit gosteremeyecek kadar buyuk; simdilik
  // tum icerik gorunsun diye yuksek tutuluyor. ListView lazy oldugu icin
  // binlerce satir sorun degil.
  static const pageSize = 10000;

  Future<Monster?> monsterByKey(String key) => (db.select(
    db.monsters,
  )..where((t) => t.key.equals(key))).getSingleOrNull();

  /// Canavara portre ekler/degistirir; onceki dosya silinir.
  Future<void> setMonsterPortrait(String key, File source) async {
    final previous = await monsterByKey(key);
    final stored = await portraits.store(source);
    await (db.update(db.monsters)..where((t) => t.key.equals(key))).write(
      MonstersCompanion(portraitPath: Value(stored)),
    );
    await portraits.delete(previous?.portraitPath);
  }

  Future<void> removeMonsterPortrait(String key) async {
    final monster = await monsterByKey(key);
    if (monster == null) return;
    await portraits.delete(monster.portraitPath);
    await (db.update(db.monsters)..where((t) => t.key.equals(key))).write(
      const MonstersCompanion(portraitPath: Value(null)),
    );
  }

  /// Verilen gorsel dosyalarini AD ile canavarlara eslestirip portre atar.
  /// Dosya adi (uzantisiz) canavar adiyla ayni normalize edilip karsilastirilir
  /// (or. "Goblin Warrior.png" -> "Goblin Warrior"). Ayni adli birden fazla
  /// canavar varsa hepsine atanir. Eslesmeyen dosyalarin adlari [unmatched]'te
  /// doner. Kullanicinin kendi sagladigi gorseller; internetten cekme yok.
  Future<MonsterPortraitImport> importMonsterPortraits(List<File> files) async {
    final monsters = await db.select(db.monsters).get();
    final byName = <String, List<String>>{};
    for (final m in monsters) {
      (byName[m.nameLower] ??= []).add(m.key);
    }

    var assigned = 0;
    final unmatched = <String>[];
    for (final file in files) {
      final normalized = searchNormalize(p.basenameWithoutExtension(file.path));
      final keys = byName[normalized];
      if (keys == null || keys.isEmpty) {
        unmatched.add(p.basename(file.path));
        continue;
      }
      for (final key in keys) {
        await setMonsterPortrait(key, file);
        assigned++;
      }
    }
    return MonsterPortraitImport(assigned: assigned, unmatched: unmatched);
  }

  Future<List<Monster>> searchMonsters({
    String query = '',
    double? minCr,
    double? maxCr,
    Set<String> creatureTypes = const {},
    Set<SourceType> sources = const {},
    Set<String> documents = const {},
    int limit = pageSize,
  }) {
    final q = db.select(db.monsters);
    final needle = searchNormalize(query.trim());
    if (needle.isNotEmpty) {
      q.where((t) => t.nameLower.like('%$needle%'));
    }
    if (minCr != null) {
      q.where((t) => t.challengeRating.isBiggerOrEqualValue(minCr));
    }
    if (maxCr != null) {
      q.where((t) => t.challengeRating.isSmallerOrEqualValue(maxCr));
    }
    if (creatureTypes.isNotEmpty) {
      q.where((t) => t.creatureType.isIn(creatureTypes.toList()));
    }
    if (sources.isNotEmpty) {
      q.where((t) => t.sourceType.isInValues(sources.toList()));
    }
    if (documents.isNotEmpty) {
      q.where((t) => t.document.isIn(documents.toList()));
    }
    q
      ..orderBy([
        (t) => OrderingTerm(expression: t.challengeRating),
        (t) => OrderingTerm(expression: t.nameLower),
      ])
      ..limit(limit);
    return q.get();
  }

  Future<List<Spell>> searchSpells({
    String query = '',
    Set<int> levels = const {},
    Set<String> schools = const {},
    String? classKey,
    bool concentrationOnly = false,
    bool ritualOnly = false,
    Set<String> documents = const {},
    int limit = pageSize,
  }) {
    final q = db.select(db.spells);
    final needle = searchNormalize(query.trim());
    if (needle.isNotEmpty) q.where((t) => t.nameLower.like('%$needle%'));
    if (levels.isNotEmpty) q.where((t) => t.level.isIn(levels.toList()));
    if (schools.isNotEmpty) q.where((t) => t.school.isIn(schools.toList()));
    if (classKey != null) q.where((t) => t.classesCsv.like('%$classKey%'));
    if (concentrationOnly) q.where((t) => t.concentration.equals(true));
    if (ritualOnly) q.where((t) => t.ritual.equals(true));
    if (documents.isNotEmpty) {
      q.where((t) => t.document.isIn(documents.toList()));
    }
    q
      ..orderBy([
        (t) => OrderingTerm(expression: t.level),
        (t) => OrderingTerm(expression: t.nameLower),
      ])
      ..limit(limit);
    return q.get();
  }

  Future<List<Item>> searchItems({
    String query = '',
    Set<String> categories = const {},
    Set<String> documents = const {},
    int limit = pageSize,
  }) {
    final q = db.select(db.items);
    final needle = searchNormalize(query.trim());
    if (needle.isNotEmpty) q.where((t) => t.nameLower.like('%$needle%'));
    if (categories.isNotEmpty) {
      q.where((t) => t.category.isIn(categories.toList()));
    }
    if (documents.isNotEmpty) {
      q.where((t) => t.document.isIn(documents.toList()));
    }
    q
      ..orderBy([(t) => OrderingTerm(expression: t.nameLower)])
      ..limit(limit);
    return q.get();
  }

  Future<List<MagicItem>> searchMagicItems({
    String query = '',
    Set<String> rarities = const {},
    bool? requiresAttunement,
    Set<String> documents = const {},
    int limit = pageSize,
  }) {
    final q = db.select(db.magicItems);
    final needle = searchNormalize(query.trim());
    if (needle.isNotEmpty) q.where((t) => t.nameLower.like('%$needle%'));
    if (rarities.isNotEmpty) q.where((t) => t.rarity.isIn(rarities.toList()));
    if (requiresAttunement != null) {
      q.where((t) => t.requiresAttunement.equals(requiresAttunement));
    }
    if (documents.isNotEmpty) {
      q.where((t) => t.document.isIn(documents.toList()));
    }
    q
      ..orderBy([
        (t) => OrderingTerm(expression: t.rarityRank),
        (t) => OrderingTerm(expression: t.nameLower),
      ])
      ..limit(limit);
    return q.get();
  }

  Future<List<Feat>> searchFeats({
    String query = '',
    Set<String> documents = const {},
    int limit = pageSize,
  }) {
    final q = db.select(db.feats);
    final needle = searchNormalize(query.trim());
    if (needle.isNotEmpty) q.where((t) => t.nameLower.like('%$needle%'));
    if (documents.isNotEmpty) {
      q.where((t) => t.document.isIn(documents.toList()));
    }
    q
      ..orderBy([(t) => OrderingTerm(expression: t.nameLower)])
      ..limit(limit);
    return q.get();
  }

  /// Sinif ve alt siniflar. Kagitta yalnizca karakterin sinifi gorunuyordu;
  /// kutuphaneden bakmak icin ayri bir arama gerekiyor.
  Future<List<ClassDefinition>> searchClasses({
    String query = '',
    Set<String> documents = const {},
    int limit = pageSize,
  }) {
    final q = db.select(db.classDefinitions);
    final needle = searchNormalize(query.trim());
    if (needle.isNotEmpty) q.where((t) => t.nameLower.like('%$needle%'));
    if (documents.isNotEmpty) {
      q.where((t) => t.document.isIn(documents.toList()));
    }
    q
      ..orderBy([(t) => OrderingTerm(expression: t.nameLower)])
      ..limit(limit);
    return q.get();
  }

  /// Bir sinifin seviye seviye ilerleme satirlari (tablo icin).
  Future<List<ClassProgression>> progressionOf(String classKey) =>
      (db.select(db.classProgressions)
            ..where((t) => t.classKey.equals(classKey))
            ..orderBy([(t) => OrderingTerm(expression: t.level)]))
          .get();

  Future<List<SpeciesEntry>> searchSpecies({
    String query = '',
    Set<String> documents = const {},
    int limit = pageSize,
  }) {
    final q = db.select(db.speciesEntries);
    final needle = searchNormalize(query.trim());
    if (needle.isNotEmpty) q.where((t) => t.nameLower.like('%$needle%'));
    if (documents.isNotEmpty) {
      q.where((t) => t.document.isIn(documents.toList()));
    }
    q
      ..orderBy([(t) => OrderingTerm(expression: t.nameLower)])
      ..limit(limit);
    return q.get();
  }

  Future<List<Background>> searchBackgrounds({
    String query = '',
    Set<String> documents = const {},
    int limit = pageSize,
  }) {
    final q = db.select(db.backgrounds);
    final needle = searchNormalize(query.trim());
    if (needle.isNotEmpty) q.where((t) => t.nameLower.like('%$needle%'));
    if (documents.isNotEmpty) {
      q.where((t) => t.document.isIn(documents.toList()));
    }
    q
      ..orderBy([(t) => OrderingTerm(expression: t.nameLower)])
      ..limit(limit);
    return q.get();
  }

  /// Filtre cipleri icin tabloda gercekten bulunan degerler; sabit liste
  /// yazmak yerine veriden okunuyor ki yeni kaynak eklendiginde kendiliginden
  /// guncellensin.
  Future<List<String>> distinctCreatureTypes() async {
    final rows = await db
        .customSelect(
          'SELECT DISTINCT creature_type AS v FROM monsters '
          'WHERE v IS NOT NULL ORDER BY v',
        )
        .get();
    return rows.map((r) => r.read<String>('v')).toList();
  }

  Future<List<String>> distinctItemCategories() async {
    final rows = await db
        .customSelect(
          'SELECT DISTINCT category AS v FROM items '
          'WHERE v IS NOT NULL ORDER BY v',
        )
        .get();
    return rows.map((r) => r.read<String>('v')).toList();
  }

  /// Nadirlikler guclerine gore siralanir (Common -> Artifact).
  ///
  /// Ayni nadirlik farkli rank degeriyle kayitlanmissa dahi cift chip
  /// cikmamasi icin rarity'ye gore gruplanir.
  Future<List<String>> rarityNames() async {
    final rows = await db
        .customSelect(
          'SELECT rarity AS v FROM magic_items '
          'WHERE v IS NOT NULL GROUP BY rarity ORDER BY MIN(rarity_rank)',
        )
        .get();
    return rows.map((r) => r.read<String>('v')).toList();
  }

  /// Kutuphanedeki tum kaynak kitaplarin listesi (filtre cipi icin).
  ///
  /// `srd-2024`, `phb-2024`, `mm-2024`, `eberron-forge`, `ravenloft-horrors`,
  /// `faerun-heroes` gibi belge anahtarlari. NULL olanlar atlanir.
  Future<List<String>> distinctDocuments() async {
    final rows = await db
        .customSelect(
          'SELECT DISTINCT document AS v FROM monsters '
          'WHERE v IS NOT NULL '
          'UNION '
          'SELECT DISTINCT document AS v FROM spells WHERE v IS NOT NULL '
          'UNION '
          'SELECT DISTINCT document AS v FROM items WHERE v IS NOT NULL '
          'UNION '
          'SELECT DISTINCT document AS v FROM magic_items WHERE v IS NOT NULL '
          'UNION '
          'SELECT DISTINCT document AS v FROM feats WHERE v IS NOT NULL '
          'UNION '
          'SELECT DISTINCT document AS v FROM species_entries WHERE v IS NOT NULL '
          'UNION '
          'SELECT DISTINCT document AS v FROM backgrounds WHERE v IS NOT NULL '
          'ORDER BY v',
        )
        .get();
    return rows.map((r) => r.read<String>('v')).toList();
  }
}
