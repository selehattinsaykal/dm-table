import 'dart:io';

import 'package:dm_table/data/backup_repository.dart';
import 'package:dm_table/data/backup_restore_service.dart';
import 'package:dm_table/data/campaign/campaign.dart';
import 'package:dm_table/data/campaign/campaign_manager.dart';
import 'package:dm_table/data/campaign/campaign_paths.dart';
import 'package:dm_table/data/campaign/campaign_registry.dart';
import 'package:dm_table/data/character_image_store.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/music_repository.dart';
import 'package:dm_table/data/music_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Yedeği **yeni bir kampanya** olarak içe aktarma.
///
/// Kritik olan iki şey: (1) açık kampanyaya hiç dokunulmaması, (2) medya
/// dosyalarının yeni kampanyanın klasörüne yazılması — store'lar varsayılan
/// olarak AKTİF kampanyanın kökünü kullandığı için override verilmezse
/// dosyalar yanlış kampanyaya düşerdi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late CampaignManager manager;

  setUp(() async {
    temp = Directory.systemTemp.createTempSync('dm-restore-test');
    CampaignPaths.rootOverride = temp;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    manager = CampaignManager(
      prefs: prefs,
      registry: CampaignRegistry.decode(null, null),
      // Testte scope yeniden kurulmuyor; acma yalnizca kayda yazilir.
      onOpen: (_) async {},
    );
  });

  tearDown(() {
    CampaignPaths.rootOverride = null;
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  /// `AppDatabase.forCampaign` drift_flutter uzerinden platform kanali
  /// kullaniyor ve duz `flutter test` icinde acilamiyor; ayni DOSYAYI dogrudan
  /// acan bir surum kullaniliyor (kampanya basina ayri dosya korunuyor).
  AppDatabase openCampaignDb(Campaign campaign) => AppDatabase(
    NativeDatabase(File('${temp.path}/${campaign.dbName}.sqlite')),
  );

  BackupRestoreService service() =>
      BackupRestoreService(manager, openDatabase: openCampaignDb);

  /// İçinde bir karakter + bir müzik parçası olan yedek üretir.
  Future<List<int>> buildBackup() async {
    final source = Directory('${temp.path}/kaynak')..createSync();
    final db = AppDatabase(NativeDatabase.memory());
    try {
      await db
          .into(db.characters)
          .insert(CharactersCompanion.insert(id: 'c1', name: 'Vex'));

      final store = MusicStore(directoryOverride: source);
      final music = MusicRepository(db, store: store);
      final file = File('${source.path}/parca.mp3')
        ..writeAsBytesSync(List<int>.filled(32, 3));
      await music.addTrack(file, title: 'Kuşatma');

      // `return await` ŞART: `finally` içindeki `close()` beklenmeyen bir
      // Future döndürülünce export tamamlanmadan çalışır ("Can't re-open a
      // database after closing it").
      return await BackupRepository(
        db,
        portraits: CharacterImageStore(directoryOverride: source),
        music: store,
      ).export();
    } finally {
      await db.close();
    }
  }

  test('yedek AYRI kampanya olarak kurulur, acik kampanya bozulmaz', () async {
    final bytes = await buildBackup();
    final before = manager.active.id;

    final campaign = await service().restoreAsNewCampaign(
      name: 'Arkadaşın Masası',
      bytes: bytes,
    );

    // Acik kampanya DEGISMEDI: gecis ayri bir karar.
    expect(manager.active.id, before);
    expect(campaign.id, isNot(before));
    expect(manager.campaigns.map((c) => c.name), contains('Arkadaşın Masası'));

    // Veri yeni kampanyanin DOSYASINA yazildi.
    final db = openCampaignDb(campaign);
    try {
      final rows = await db.select(db.characters).get();
      expect(rows.map((c) => c.name), ['Vex']);
      final tracks = await db.select(db.musicTracks).get();
      expect(tracks.single.title, 'Kuşatma');
    } finally {
      await db.close();
    }
  });

  test('medya dosyalari YENI kampanyanin klasorune yazilir', () async {
    final bytes = await buildBackup();
    final campaign = await service().restoreAsNewCampaign(
      name: 'Medyalı',
      bytes: bytes,
    );

    final root = await CampaignPaths.mediaRoot(campaign);
    final musicDir = Directory('${root.path}/${MusicStore.folder}');
    expect(musicDir.existsSync(), isTrue);
    expect(musicDir.listSync().whereType<File>(), isNotEmpty);

    // Varsayilan (acik) kampanyanin kokunde muzik OLUSMAMALI.
    expect(
      Directory('${temp.path}/${MusicStore.folder}').existsSync(),
      isFalse,
    );
  });

  test('bozuk arsiv yarim kampanya BIRAKMAZ', () async {
    final before = manager.campaigns.length;

    await expectLater(
      service().restoreAsNewCampaign(
        name: 'Bozuk',
        bytes: List<int>.filled(64, 0),
      ),
      throwsA(anything),
    );

    // Kayit geri alindi: kullanici listede acilmayan bir kampanya gormemeli.
    expect(manager.campaigns.length, before);
    expect(manager.campaigns.map((c) => c.name), isNot(contains('Bozuk')));
  });

  test('yedek ozeti muzik dosyasi sayisini tasir', () async {
    final bytes = await buildBackup();
    final summary = BackupRepository(
      AppDatabase(NativeDatabase.memory()),
    ).inspect(bytes);
    expect(summary.musicCount, 1);
  });

  test('varsayilan kampanya kaydi hep listede kalir', () async {
    final bytes = await buildBackup();
    await service().restoreAsNewCampaign(name: 'İkinci', bytes: bytes);

    expect(manager.campaigns.map((c) => c.id), contains(Campaign.defaultId));
    expect(manager.campaigns.length, 2);
  });
}
