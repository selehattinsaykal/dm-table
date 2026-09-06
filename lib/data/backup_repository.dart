import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import 'character_image_store.dart';
import 'codex_media_store.dart';
import 'music_store.dart';
import 'db/database.dart';
import 'map_image_store.dart';

/// Arsivin ozeti; disa aktarmadan sonra ve ice aktarmadan once gosterilir.
typedef BackupSummary = ({
  String createdAt,
  int schemaVersion,
  Map<String, int> counts,
  int mapCount,
  int portraitCount,
  int mediaCount,
  int musicCount,
});

/// Kampanya yedegi.
///
/// Arsiv su parcalardan olusur:
///  - `manifest.json`: surum ve sayilar
///  - `data.json`: kullanicinin urettigi tum satirlar -- karakterler,
///    NPC'ler, dunya agi, Kayitlar, oyuncu notlari, envanterler, gorevler,
///    ganimetler, oturum gunlugu vb.
///  - `maps/`: harita gorselleri
///  - `portraits/`: karakter, NPC, canavar ve Kayit gorselleri
///  - `media/`: Kayitlar video dosyalari
///  - `music/`: muzik kutuphanesi dosyalari (ses dosyalari buyuk olabilir;
///    yedek dosyasinin boyutunu en cok bu buyutur)
///
/// Gorseller yalnizca yol olarak DEGIL, dosyanin kendisi olarak gomulur --
/// yedegi baska bir cihaza tasirken gorsellerin de gelmesi icin.
///
/// SRD/OGL icerigi ARSIVE GIRMEZ: paketten her acilista yeniden uretiliyor,
/// dolayisiyla yedegi sismanlatmasi anlamsiz olurdu. Buna karsilik DM'in
/// kendi olusturdugu ya da kitapligindan ekledigi icerik (`custom`,
/// `personal`) arsivin parcasidir -- baska turlu geri getirilemez.
class BackupRepository {
  BackupRepository(
    this.db, {
    MapImageStore? images,
    CharacterImageStore? portraits,
    CodexMediaStore? media,
    MusicStore? music,
  }) : images = images ?? MapImageStore(),
       portraits = portraits ?? CharacterImageStore(),
       media = media ?? CodexMediaStore(),
       music = music ?? MusicStore();

  final AppDatabase db;
  final MapImageStore images;
  final CharacterImageStore portraits;
  final CodexMediaStore media;
  final MusicStore music;

  /// Portre yolu tutan tablolar; hepsi ayni `portraits/` klasorunu paylasir.
  static const _portraitTables = ['characters', 'npcs', 'monsters'];

  /// Arsiv bicimi surumu. Yapı degisirse artirilir ve eski yedekler
  /// okunurken buna bakilir.
  static const formatVersion = 1;

  /// Kullanicinin urettigi kayitlar; tamami yedeklenir.
  static const _userTables = [
    'characters',
    'character_class_levels',
    'character_proficiencies',
    'character_items',
    'character_spells',
    'character_features',
    'encounters',
    'combatants',
    'shops',
    'shop_stock',
    'locations',
    'map_pins',
    'world_links',
    'bond_types',
    'npcs',
    'factions',
    'loot_sets',
    // Ortak parti keseleri ve rastgele tablolar: DM'in elle kurdugu icerik,
    // yedeksiz kalirsa geri yuklemede sessizce KAYBOLUYORDU.
    'party_inventories',
    'random_tables',
    // Suren yolculuk (rota + ilerleme); yarim kalan yolculuk da tasinsin.
    'journeys',
    // Kayitlar (Codex): once sayfalar (ust satirlar), sonra bloklar.
    'codex_pages',
    'codex_blocks',
    // Gorevler.
    'quests',
    // Kalici oturum gunlugu (XP verildi, elle not).
    'session_log_entries',
    // Oyun-ici takvim: once yapi (aylar/gunler/mevsimler), sonra tarihce.
    // Caglar olaylardan once gelmeli (olaylar caga referans veriyor).
    'calendar_config',
    'calendar_months',
    'calendar_weekdays',
    'calendar_seasons',
    'calendar_eras',
    'chronicle_events',
    // Ileriye donuk hatirlaticilar (tekrarlayan olaylar).
    'calendar_reminders',
    // Muzik kutuphanesi: once listeler, sonra parcalar.
    'music_playlists',
    'music_tracks',
    // Kullanicinin tanimladigi icerik kaynaklari (adresler); yeni cihazda
    // elle yeniden girmek zorunda kalmasin.
    'content_sources',
    // Hazirlik araclari: kayitli karsilasma kaliplari, zar makrolari ve
    // bos zaman faaliyetleri. Ucu de elle kurulmus, paketten yeniden
    // uretilemez -- yedege girmezlerse geri yuklemede sessizce kaybolurlar.
    'encounter_templates',
    'macros',
    'downtime_activities',
    // Ilerleme saatleri.
    'clocks',
  ];

  /// Kutuphane tablolari; yalnizca DM'in kendi ekledikleri yedeklenir.
  static const _contentTables = [
    'monsters',
    'spells',
    'items',
    'magic_items',
    'class_definitions',
    'species_entries',
    'backgrounds',
    'feats',
  ];

  static const _ownContent = "source_type IN ('custom', 'personal')";

  /// Yedegi olusturur ve zip baytlarini doner.
  Future<List<int>> export() async {
    final data = <String, List<Map<String, dynamic>>>{};

    for (final table in _userTables) {
      data[table] = await _readTable(table);
    }
    for (final table in _contentTables) {
      data[table] = await _readTable(table, where: _ownContent);
    }

    final archive = Archive();

    final mapFiles = await _collectMapFiles(data['locations'] ?? const []);
    for (final entry in mapFiles.entries) {
      archive.add(
        ArchiveFile('maps/${entry.key}', entry.value.length, entry.value),
      );
    }

    final portraitFiles = await _collectPortraitFiles(data);
    for (final entry in portraitFiles.entries) {
      archive.add(
        ArchiveFile('portraits/${entry.key}', entry.value.length, entry.value),
      );
    }

    final mediaFiles = await _collectMediaFiles(
      data['codex_blocks'] ?? const [],
    );
    for (final entry in mediaFiles.entries) {
      archive.add(
        ArchiveFile('media/${entry.key}', entry.value.length, entry.value),
      );
    }

    final musicFiles = await _collectMusicFiles(
      data['music_tracks'] ?? const [],
    );
    for (final entry in musicFiles.entries) {
      archive.add(
        ArchiveFile('music/${entry.key}', entry.value.length, entry.value),
      );
    }

    final manifest = {
      'formatVersion': formatVersion,
      'schemaVersion': db.schemaVersion,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'counts': {
        for (final e in data.entries)
          if (e.value.isNotEmpty) e.key: e.value.length,
      },
      'mapCount': mapFiles.length,
      'portraitCount': portraitFiles.length,
      'mediaCount': mediaFiles.length,
      'musicCount': musicFiles.length,
    };

    _addJson(archive, 'manifest.json', manifest);
    _addJson(archive, 'data.json', data);

    return ZipEncoder().encode(archive);
  }

  /// Arsivi acmadan icindekileri okur; kullaniciya "neyi geri yükleyeceksin"
  /// diye gosterebilmek icin.
  BackupSummary inspect(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final manifest = _readJson(archive, 'manifest.json');
    if (manifest == null) {
      throw const FormatException('Geçersiz yedek: manifest bulunamadı.');
    }

    final version = manifest['formatVersion'] as int? ?? 0;
    if (version > formatVersion) {
      throw FormatException(
        'Bu yedek daha yeni bir sürümle oluşturulmuş (v$version). '
        'Uygulamayı güncellemen gerekiyor.',
      );
    }

    return (
      createdAt: '${manifest['createdAt'] ?? ''}',
      schemaVersion: manifest['schemaVersion'] as int? ?? 0,
      counts: {
        for (final e in (manifest['counts'] as Map? ?? const {}).entries)
          '${e.key}': e.value as int,
      },
      mapCount: manifest['mapCount'] as int? ?? 0,
      portraitCount: manifest['portraitCount'] as int? ?? 0,
      mediaCount: manifest['mediaCount'] as int? ?? 0,
      // Eski yedeklerde bu alan yok; 0 dogru cevap (muzik ozelligi yoktu).
      musicCount: manifest['musicCount'] as int? ?? 0,
    );
  }

  /// Yedegi geri yukler.
  ///
  /// Mevcut kullanici verisi SILINIR ve arsivdekiyle degistirilir; SRD
  /// kutuphanesine dokunulmaz. Tek islemde yapiliyor: yarim kalmis bir geri
  /// yukleme, bozuk bir kampanyadan daha kotu olurdu.
  Future<BackupSummary> import(List<int> bytes) async {
    final summary = inspect(bytes);
    final archive = ZipDecoder().decodeBytes(bytes);

    final data = _readJson(archive, 'data.json');
    if (data == null) {
      throw const FormatException('Geçersiz yedek: veri bulunamadı.');
    }

    await db.transaction(() async {
      // Once bagimli tablolar bosaltilir.
      for (final table in _userTables.reversed) {
        await db.customStatement('DELETE FROM $table');
      }
      for (final table in _contentTables) {
        await db.customStatement('DELETE FROM $table WHERE $_ownContent');
      }

      for (final table in [..._userTables, ..._contentTables]) {
        final rows = data[table];
        if (rows is! List) continue;
        for (final row in rows.cast<Map<String, dynamic>>()) {
          await _insertRow(table, row);
        }
      }
    });

    await _restoreMapFiles(archive);
    await _restorePortraitFiles(archive);
    await _restoreMediaFiles(archive);
    await _restoreMusicFiles(archive);
    return summary;
  }

  Future<List<Map<String, dynamic>>> _readTable(
    String table, {
    String? where,
  }) async {
    final rows = await db
        .customSelect(
          'SELECT * FROM $table${where == null ? '' : ' WHERE $where'}',
        )
        .get();
    return [for (final row in rows) row.data];
  }

  Future<void> _insertRow(String table, Map<String, dynamic> row) async {
    if (row.isEmpty) return;
    final columns = row.keys.toList();
    final placeholders = List.filled(columns.length, '?').join(', ');
    // Sutun adlari tirnaklaniyor: `character_class_levels.order` gibi SQL'de
    // ayrilmis kelimeler var ve tirnaksiz INSERT sozdizimi hatasi veriyor.
    final quoted = columns.map((c) => '"$c"').join(', ');
    await db.customStatement(
      'INSERT OR REPLACE INTO "$table" ($quoted) VALUES ($placeholders)',
      [for (final c in columns) row[c]],
    );
  }

  /// Lokasyonlarin isaret ettigi harita dosyalarini toplar.
  Future<Map<String, List<int>>> _collectMapFiles(
    List<Map<String, dynamic>> locations,
  ) async {
    final files = <String, List<int>>{};
    for (final location in locations) {
      for (final key in ['map_image_path', 'map_preview_path']) {
        final path = location[key] as String?;
        if (path == null) continue;
        final file = await images.resolve(path);
        // Diskte olmayan dosya sessizce atlanir; yedek yine de alinmali.
        if (!file.existsSync()) continue;
        files[p.basename(path)] = await file.readAsBytes();
      }
    }
    return files;
  }

  Future<void> _restoreMapFiles(Archive archive) async {
    for (final file in archive.files) {
      if (!file.isFile || !file.name.startsWith('maps/')) continue;
      final target = await images.resolve(
        p.join('maps', p.basename(file.name)),
      );
      target.parent.createSync(recursive: true);
      await target.writeAsBytes(file.content as List<int>);
    }
  }

  /// Karakter, NPC ve canavar satirlarinin isaret ettigi portre dosyalarini
  /// toplar. Hepsi `portraits/` klasorunu paylastigi icin dosya adi anahtar.
  Future<Map<String, List<int>>> _collectPortraitFiles(
    Map<String, List<Map<String, dynamic>>> data,
  ) async {
    final files = <String, List<int>>{};
    for (final table in _portraitTables) {
      for (final row in data[table] ?? const <Map<String, dynamic>>[]) {
        final path = row['portrait_path'] as String?;
        if (path == null) continue;
        final file = await portraits.resolve(path);
        // Diskte olmayan dosya sessizce atlanir; yedek yine de alinmali.
        if (!file.existsSync()) continue;
        files[p.basename(path)] = await file.readAsBytes();
      }
    }

    // Kayitlar (Codex) gorsel bloklari da ayni portraits/ klasorunu kullanir;
    // yollari codex_blocks.data_json icinde gomulu.
    for (final path in _codexImagePaths(data['codex_blocks'] ?? const [])) {
      final file = await portraits.resolve(path);
      if (!file.existsSync()) continue;
      files[p.basename(path)] = await file.readAsBytes();
    }
    return files;
  }

  /// Codex gorsel bloklarinin data_json'undaki portre yollarini cikarir.
  Iterable<String> _codexImagePaths(List<Map<String, dynamic>> blocks) sync* {
    for (final row in blocks) {
      if (row['type'] != 'image') continue;
      final raw = row['data_json'] as String?;
      if (raw == null) continue;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) continue;
      final path = decoded['path'] as String?;
      if (path != null) yield path;
    }
  }

  Future<void> _restorePortraitFiles(Archive archive) async {
    for (final file in archive.files) {
      if (!file.isFile || !file.name.startsWith('portraits/')) continue;
      final target = await portraits.resolve(
        p.join('portraits', p.basename(file.name)),
      );
      target.parent.createSync(recursive: true);
      await target.writeAsBytes(file.content as List<int>);
    }
  }

  /// Kayitlar (Codex) video bloklarinin isaret ettigi dosyalari toplar; yollar
  /// codex_blocks.data_json icinde gomulu (type == 'video').
  Future<Map<String, List<int>>> _collectMediaFiles(
    List<Map<String, dynamic>> blocks,
  ) async {
    final files = <String, List<int>>{};
    for (final row in blocks) {
      if (row['type'] != 'video') continue;
      final raw = row['data_json'] as String?;
      if (raw == null) continue;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) continue;
      final path = decoded['path'] as String?;
      if (path == null) continue;
      final file = await media.resolve(path);
      // Diskte olmayan dosya sessizce atlanir; yedek yine de alinmali.
      if (!file.existsSync()) continue;
      files[p.basename(path)] = await file.readAsBytes();
    }
    return files;
  }

  Future<void> _restoreMediaFiles(Archive archive) async {
    for (final file in archive.files) {
      if (!file.isFile || !file.name.startsWith('media/')) continue;
      final target = await media.resolve(
        p.join(CodexMediaStore.folder, p.basename(file.name)),
      );
      target.parent.createSync(recursive: true);
      await target.writeAsBytes(file.content as List<int>);
    }
  }

  /// Muzik parcalarinin dosyalarini toplar.
  Future<Map<String, List<int>>> _collectMusicFiles(
    List<Map<String, dynamic>> tracks,
  ) async {
    final files = <String, List<int>>{};
    for (final row in tracks) {
      final path = row['path'] as String?;
      if (path == null) continue;
      final file = await music.resolve(path);
      // Diskte olmayan dosya sessizce atlanir; yedek yine de alinmali.
      if (!file.existsSync()) continue;
      files[p.basename(path)] = await file.readAsBytes();
    }
    return files;
  }

  Future<void> _restoreMusicFiles(Archive archive) async {
    for (final file in archive.files) {
      if (!file.isFile || !file.name.startsWith('music/')) continue;
      final target = await music.resolve(
        p.join(MusicStore.folder, p.basename(file.name)),
      );
      target.parent.createSync(recursive: true);
      await target.writeAsBytes(file.content as List<int>);
    }
  }

  static void _addJson(Archive archive, String name, Object value) {
    final bytes = utf8.encode(jsonEncode(value));
    archive.add(ArchiveFile(name, bytes.length, bytes));
  }

  static Map<String, dynamic>? _readJson(Archive archive, String name) {
    for (final file in archive.files) {
      if (file.name != name || !file.isFile) continue;
      return jsonDecode(utf8.decode(file.content as List<int>))
          as Map<String, dynamic>;
    }
    return null;
  }
}
