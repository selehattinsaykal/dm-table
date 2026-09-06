import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../domain/search_text.dart';
import '../../db/database.dart';
import '../../db/tables.dart';
import '../../character_image_store.dart';
import 'fivetools_convert.dart';
import 'fivetools_images.dart';
import 'fivetools_source.dart';

/// Bir ice aktarmanin sonucu.
typedef ImportReport = ({int monsters, int spells, int items, int others});

/// 5etools bicimli kayitlari kutuphaneye yazar.
///
/// Kayitlar [SourceType.personal] etiketiyle giriyor. Bunun uc sonucu var ve
/// ucu de bilincli:
///
///  * Paketlenen SRD verisi tazelendiginde SILINMIYOR (`AssetImporter`
///    yalnizca `srd`/`ogl` satirlarina dokunuyor).
///  * Yedege GIRIYOR (`BackupRepository` `custom`/`personal` satirlari
///    aliyor): paketten yeniden uretilemedigi icin baska turlu geri
///    getirilemez.
///  * Kutuphanede SRD icerigiyle yan yana gorunuyor.
class FiveToolsImporter {
  FiveToolsImporter(this.db, {CharacterImageStore? images})
    : images = images ?? CharacterImageStore();

  final AppDatabase db;

  /// Indirilen gorsellerin saklandigi yer; portrelerle AYNI klasor.
  final CharacterImageStore images;

  /// Secilen dosyalari sirayla ice aktarir.
  ///
  /// [onProgress] her dosya oncesi cagriliyor: ice aktarma binlerce kayit
  /// olabiliyor ve arayuzun bir sey soylemesi gerekiyor.
  Future<ImportReport> importFiles(
    FiveToolsSource source,
    List<RemoteFile> files, {
    void Function(RemoteFile file, int index, int total)? onProgress,
    void Function(int done, int total)? onImage,
    bool withImages = true,
  }) async {
    var monsters = 0;
    var spells = 0;
    var items = 0;
    var others = 0;

    for (final (index, file) in files.indexed) {
      onProgress?.call(file, index, files.length);
      final raw = await source.fetchEntries(file);
      if (raw.isEmpty) continue;
      final report = await importEntries(file.kind, raw);
      // Gorseller AYRI bir gecis: kayitlar once yaziliyor, sonra portreler
      // uzerine isleniyor. Boylece gorsel indirme basarisiz olsa bile
      // icerik ice aktarilmis oluyor.
      if (withImages && file.kind == 'monster') {
        await _importImages(source, file, raw, onImage: onImage);
      }
      monsters += report.monsters;
      spells += report.spells;
      items += report.items;
      others += report.others;
    }
    return (monsters: monsters, spells: spells, items: items, others: others);
  }

  /// Kayitlarin gorsellerini indirip portre olarak isler.
  ///
  /// Gorsel iki yerde olabiliyor: kaydin kendi `images` alaninda ya da
  /// ayri bir `fluff-` dosyasinda. Ikisi de deneniyor.
  ///
  /// Sessizce atlanan durumlar: gorseli olmayan kayit, indirilemeyen dosya,
  /// cozulemeyen bicim. Hicbiri ice aktarmayi dusurmemeli -- gorselsiz bir
  /// canavar, canavarsiz bir kutuphaneden iyi.
  Future<void> _importImages(
    FiveToolsSource source,
    RemoteFile file,
    List<Map<String, dynamic>> raw, {
    void Function(int done, int total)? onImage,
  }) async {
    // Ayri fluff dosyasi (varsa) ADLA eslesiyor.
    final fluffPath = fluffPathFor(file.path);
    final fluff = fluffPath == null ? null : await source.fetchBody(fluffPath);
    final fluffIndex = fluff == null
        ? const <String, List<ImageRef>>{}
        : fluffImageIndex(
            fluff,
            (name, src) => fiveToolsKey('monster', name, src),
          );

    // Hangi kayitlarin gorseli var, once toplaniyor: ilerleme bildirimi
    // gercek bir toplam gosterebilsin.
    final wanted = <ImageRef>[];
    for (final entry in raw) {
      final name = entry['name'];
      if (name is! String || name.isEmpty) continue;
      final key = fiveToolsKey('monster', name, entry['source'] as String?);
      final own = imagesOf(entry, key);
      final refs = own.isNotEmpty
          ? own
          : (fluffIndex[name.toLowerCase()] ?? const []);
      if (refs.isEmpty) continue;
      // Yalnizca ILK gorsel portre olarak kullaniliyor; digerleri genelde
      // varyant/harita ve stat blogunda yeri yok.
      wanted.add((
        key: key,
        path: refs.first.path,
        external: refs.first.external,
      ));
    }
    if (wanted.isEmpty) return;

    for (final (index, ref) in wanted.indexed) {
      onImage?.call(index, wanted.length);
      // Zaten portresi olan kayit tekrar indirilmiyor.
      final existing = await (db.select(
        db.monsters,
      )..where((t) => t.key.equals(ref.key))).getSingleOrNull();
      if (existing == null || existing.portraitPath != null) continue;

      final url = resolveImageUrl(source.baseUrl, ref);
      if (url == null) continue;
      final bytes = await source.fetchImage(url);
      if (bytes == null || bytes.isEmpty) continue;

      try {
        final stored = await images.storeBytes(Uint8List.fromList(bytes));
        await (db.update(db.monsters)..where((t) => t.key.equals(ref.key)))
            .write(MonstersCompanion(portraitPath: Value(stored)));
      } on Object {
        // Desteklenmeyen bicim (webp/avif) ya da bozuk dosya: atla.
        continue;
      }
    }
  }

  /// Cozulmus bir JSON govdesini ice aktarir (yerel dosya yolu).
  ///
  /// Tur, govdedeki ANAHTARLARDAN okunuyor: 5etools dosyalari
  /// `{"monster": [...]}` seklinde ve tek bir dosya birden fazla tur
  /// tasiyabiliyor (homebrew paketleri genellikle oyle). Dosya adina
  /// bakilmiyor -- kullanicinin dosyayi nasil adlandirdigi bilinmez.
  Future<ImportReport> importJsonBody(Object? decoded) async {
    if (decoded is! Map) return (monsters: 0, spells: 0, items: 0, others: 0);
    final body = decoded.cast<String, dynamic>();
    var monsters = 0;
    var spells = 0;
    var items = 0;
    var others = 0;

    for (final kind in const [
      'monster',
      'spell',
      'item',
      'baseitem',
      'itemGroup',
      'race',
      'background',
      'feat',
    ]) {
      final list = body[kind];
      if (list is! List) continue;
      final raw = [
        for (final entry in list)
          if (entry is Map) entry.cast<String, dynamic>(),
      ];
      // `baseitem`/`itemGroup` de esya: ayni cevirici isliyor.
      final normalized = switch (kind) {
        'baseitem' || 'itemGroup' => 'item',
        _ => kind,
      };
      final report = await importEntries(normalized, raw);
      monsters += report.monsters;
      spells += report.spells;
      items += report.items;
      others += report.others;
    }
    return (monsters: monsters, spells: spells, items: items, others: others);
  }

  /// Ham kayitlari cevirip yazar.
  ///
  /// Disari acik: yerel dosyadan ice aktarma da ayni yolu kullaniyor.
  Future<ImportReport> importEntries(
    String kind,
    List<Map<String, dynamic>> raw,
  ) async {
    // `_copy` kalitimi ONCE cozuluyor: varyantlar (ornegin bir "Goblin Boss")
    // temel kaydin canini ve saldirilarini miras aliyor, cozulmezse bombos
    // geliyorlar.
    final entries = resolveCopies(raw);
    var monsters = 0;
    var spells = 0;
    var items = 0;
    var others = 0;

    await db.transaction(() async {
      for (final entry in entries) {
        switch (kind) {
          case 'monster':
            if (await _writeMonster(entry)) monsters++;
          case 'spell':
            if (await _writeSpell(entry)) spells++;
          case 'item':
            if (await _writeItem(entry)) items++;
          case 'race':
            if (await _writeSimple(entry, convertRace, db.speciesEntries)) {
              others++;
            }
          case 'background':
            if (await _writeSimple(entry, convertBackground, db.backgrounds)) {
              others++;
            }
          case 'feat':
            if (await _writeSimple(entry, convertFeat, db.feats)) others++;
        }
      }
    });

    return (monsters: monsters, spells: spells, items: items, others: others);
  }

  Future<bool> _writeMonster(Map<String, dynamic> raw) async {
    final converted = convertMonster(raw);
    if (converted == null) return false;
    await db
        .into(db.monsters)
        .insertOnConflictUpdate(
          MonstersCompanion.insert(
            key: converted.key,
            name: converted.name,
            nameLower: searchNormalize(converted.name),
            sourceType: const Value(SourceType.personal),
            document: Value(raw['source'] as String?),
            creatureType: Value(converted.creatureType),
            size: Value(converted.size),
            challengeRating: Value(converted.challengeRating),
            armorClass: Value(converted.armorClass),
            hitPoints: Value(converted.hitPoints),
            experiencePoints: Value(_xpFor(converted.challengeRating)),
            dataJson: jsonEncode(converted.data),
          ),
        );
    return true;
  }

  Future<bool> _writeSpell(Map<String, dynamic> raw) async {
    final converted = convertSpell(raw);
    if (converted == null) return false;
    await db
        .into(db.spells)
        .insertOnConflictUpdate(
          SpellsCompanion.insert(
            key: converted.key,
            name: converted.name,
            nameLower: searchNormalize(converted.name),
            sourceType: const Value(SourceType.personal),
            document: Value(raw['source'] as String?),
            level: Value(converted.level ?? 0),
            school: Value(converted.school),
            dataJson: jsonEncode(converted.data),
          ),
        );
    return true;
  }

  /// Esyalar iki tabloya AYRILIYOR: nadirligi olan buyulu esya, olmayan
  /// normal esya. Uygulamanin kutuphanesi ikisini ayri gosteriyor.
  Future<bool> _writeItem(Map<String, dynamic> raw) async {
    final converted = convertItem(raw);
    if (converted == null) return false;

    if (converted.rarity != null) {
      await db
          .into(db.magicItems)
          .insertOnConflictUpdate(
            MagicItemsCompanion.insert(
              key: converted.key,
              name: converted.name,
              nameLower: searchNormalize(converted.name),
              sourceType: const Value(SourceType.personal),
              document: Value(raw['source'] as String?),
              rarity: Value(converted.rarity),
              dataJson: jsonEncode(converted.data),
            ),
          );
      return true;
    }

    await db
        .into(db.items)
        .insertOnConflictUpdate(
          ItemsCompanion.insert(
            key: converted.key,
            name: converted.name,
            nameLower: searchNormalize(converted.name),
            sourceType: const Value(SourceType.personal),
            document: Value(raw['source'] as String?),
            category: Value(converted.category),
            dataJson: jsonEncode(converted.data),
          ),
        );
    return true;
  }

  /// Tur/gecmis/feat: uc tablo da ayni kolonlari paylasiyor
  /// (`CompendiumEntry`), bu yuzden tek bir yazici yetiyor.
  Future<bool> _writeSimple(
    Map<String, dynamic> raw,
    ConvertedEntry? Function(Map<String, dynamic>) convert,
    TableInfo<Table, dynamic> table,
  ) async {
    final converted = convert(raw);
    if (converted == null) return false;
    await db.customInsert(
      'INSERT OR REPLACE INTO ${table.actualTableName} '
      '(key, name, name_lower, source_type, document, data_json) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      variables: [
        Variable(converted.key),
        Variable(converted.name),
        Variable(searchNormalize(converted.name)),
        Variable(SourceType.personal.name),
        Variable(raw['source'] as String?),
        Variable(jsonEncode(converted.data)),
      ],
      updates: {table},
    );
    return true;
  }

  /// Ice aktarilan butun 5etools kayitlarini siler.
  ///
  /// Anahtar onekiyle bulunuyor: kullanicinin uygulama icinde OLUSTURDUGU
  /// homebrew (`custom_*`) bundan etkilenmiyor.
  Future<int> deleteImported() async {
    // `updates` DOLU verilmeli: drift akislari yalnizca bildirilen
    // tablolarda gecersizlestiriyor. Bos gecildiginde silme diske
    // yaziliyor ama kutuphane ekrani eski listeyi gostermeye devam
    // ediyordu.
    final targets = <String, TableInfo<Table, dynamic>>{
      'monsters': db.monsters,
      'spells': db.spells,
      'items': db.items,
      'magic_items': db.magicItems,
      'species_entries': db.speciesEntries,
      'backgrounds': db.backgrounds,
      'feats': db.feats,
    };

    var removed = 0;
    for (final entry in targets.entries) {
      removed += await db.customUpdate(
        "DELETE FROM ${entry.key} WHERE key LIKE 'ft_%'",
        updates: {entry.value},
      );
    }
    return removed;
  }

  /// CR -> XP (DMG tablosu). `AssetImporter` ile ayni degerler.
  static int _xpFor(double cr) => switch (cr) {
    0 => 10,
    0.125 => 25,
    0.25 => 50,
    0.5 => 100,
    1 => 200,
    2 => 450,
    3 => 700,
    4 => 1100,
    5 => 1800,
    6 => 2300,
    7 => 2900,
    8 => 3900,
    9 => 5000,
    10 => 5900,
    11 => 7200,
    12 => 8400,
    13 => 10000,
    14 => 11500,
    15 => 13000,
    16 => 15000,
    17 => 18000,
    18 => 20000,
    19 => 22000,
    20 => 25000,
    21 => 33000,
    22 => 41000,
    23 => 50000,
    24 => 62000,
    25 => 75000,
    26 => 90000,
    27 => 105000,
    28 => 120000,
    29 => 135000,
    30 => 155000,
    _ => 0,
  };
}
