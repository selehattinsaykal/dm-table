import 'package:drift/drift.dart';

import 'campaign/campaign.dart';
import 'db/database.dart';

/// Baska bir kampanyadan neyin alinacagi.
enum MergeKind {
  /// Kutuphaneye eklenmis kendi canavarlarin (`custom`/`personal`).
  monsters,

  /// Kendi buyulerin ve buyulu esyalarin.
  spellsAndItems,

  /// NPC'ler ve baglari.
  npcs,

  /// Orgutler (loncalar, tarikatlar, hanedanlar).
  factions,

  /// Yerler ve harita pinleri.
  locations,

  /// Rastgele tablolar.
  randomTables,

  /// Ganimet setleri.
  lootSets,
}

/// Iki kampanya arasinda icerik kopyalar.
///
/// **Ne yapmaz:** birlestirmez, cakismayi cozmez, hicbir seyin uzerine
/// YAZMAZ. Ayni birincil anahtar hedefte varsa satir ATLANIR. Sebep: iki
/// kampanyada ayni kimlikle duran iki kayit ayni sey olmak zorunda degil ve
/// yanlis olani ezmek geri alinamaz.
///
/// SRD/paketlenmis icerik kopyalanmaz: her kampanya onu zaten kendi
/// dosyasina kuruyor, tasimak yalnizca dosyayi sisirirdi.
class CampaignMergeRepository {
  const CampaignMergeRepository(this.target);

  /// Icerigin YAZILACAGI (acik) veritabani.
  final AppDatabase target;

  /// Bir kampanyadan secilen icerigi kopyalar; alinan satir sayisini doner.
  ///
  /// Kaynak dosya ACILIP kapatiliyor; icine hicbir sey yazilmiyor.
  Future<int> importFrom(
    Campaign source, {
    required Set<MergeKind> kinds,
  }) async {
    if (kinds.isEmpty) return 0;
    // Ayni dosyayi iki kez acmak yerine ayri bir baglanti kuruluyor cunku
    // drift tek baglantida iki semayi birlikte sorgulayamiyor.
    final from = AppDatabase.forCampaign(source.dbName);
    try {
      return await importFromDatabase(from, kinds: kinds);
    } finally {
      await from.close();
    }
  }

  /// ACIK bir kaynak veritabanindan kopyalar.
  ///
  /// [importFrom]'dan ayri duruyor cunku kaynagi ACMA isi platforma bagli
  /// (uygulama klasoru, path_provider); kopyalama mantiginin kendisi degil.
  /// Boylece mantik dosya sistemi olmadan da test edilebiliyor.
  Future<int> importFromDatabase(
    AppDatabase from, {
    required Set<MergeKind> kinds,
  }) async {
    var copied = 0;
    for (final kind in kinds) {
      for (final table in _tablesFor(kind)) {
        copied += await _copyTable(from, table);
      }
    }
    return copied;
  }

  /// Her tur icin hangi tablolar, HANGI SIRAYLA.
  ///
  /// Sira onemli: yabanci anahtar tasiyan tablolar isaret ettikleri
  /// tablodan SONRA geliyor (pinler yerden sonra), yoksa kopyalama
  /// kisitlamaya takilirdi.
  static List<String> _tablesFor(MergeKind kind) => switch (kind) {
    MergeKind.monsters => const ['monsters'],
    MergeKind.spellsAndItems => const ['spells', 'items', 'magic_items'],
    MergeKind.npcs => const ['npcs'],
    MergeKind.factions => const ['factions'],
    MergeKind.locations => const ['locations', 'map_pins'],
    MergeKind.randomTables => const ['random_tables'],
    MergeKind.lootSets => const ['loot_sets'],
  };

  /// Kutuphane tablolarinda YALNIZCA kullanicinin kendi kayitlari alinir.
  static const _ownContentOnly = {'monsters', 'spells', 'items', 'magic_items'};

  Future<int> _copyTable(AppDatabase from, String table) async {
    // Hedefte var olan anahtarlar: cakisani atlamak icin.
    final keyColumn = _ownContentOnly.contains(table) ? 'key' : 'id';
    final existing = await target
        .customSelect('SELECT $keyColumn FROM $table')
        .get()
        .then((rows) => {for (final r in rows) r.read<String>(keyColumn)});

    final where = _ownContentOnly.contains(table)
        ? " WHERE source_type IN ('custom', 'personal')"
        : '';
    final rows = await from.customSelect('SELECT * FROM $table$where').get();
    if (rows.isEmpty) return 0;

    var copied = 0;
    await target.transaction(() async {
      for (final row in rows) {
        final data = row.data;
        final key = data[keyColumn];
        if (key is! String || existing.contains(key)) continue;

        final columns = data.keys.toList();
        final placeholders = List.filled(columns.length, '?').join(', ');
        await target.customInsert(
          'INSERT OR IGNORE INTO $table (${columns.join(', ')}) '
          'VALUES ($placeholders)',
          variables: [for (final column in columns) Variable(data[column])],
        );
        copied++;
      }
    });
    return copied;
  }
}
