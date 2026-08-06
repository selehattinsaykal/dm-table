import 'dart:convert';
import 'dart:io';

import 'package:dm_table/data/campaign/campaign.dart';
import 'package:dm_table/data/campaign/campaign_manager.dart';
import 'package:dm_table/data/campaign/campaign_paths.dart';
import 'package:dm_table/data/campaign/campaign_registry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kampanya kaydi + dosya yasam dongusu.
///
/// Kayit `runApp`'ten ONCE okundugu icin en kritik ozellik "asla firlatmaz":
/// buradaki bir istisna uygulamayi acilista tuglalastirirdi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CampaignRegistry.decode', () {
    test('bos kayit varsayilan kampanyayi tohumlar', () {
      final registry = CampaignRegistry.decode(null, null);
      expect(registry.campaigns.single.id, Campaign.defaultId);
      expect(registry.campaigns.single.dbName, Campaign.defaultDbName);
      expect(registry.activeId, Campaign.defaultId);
    });

    test('bozuk JSON firlatmaz, varsayilana duser', () {
      for (final raw in ['{ bu json degil', '"metin"', '[1, 2, 3]', '']) {
        final registry = CampaignRegistry.decode(raw, 'yok');
        expect(registry.campaigns.single.id, Campaign.defaultId);
        expect(registry.activeId, Campaign.defaultId);
      }
    });

    test('eksik alanli kayitlar atlanir, saglamlar kalir', () {
      final raw = jsonEncode([
        {'id': 'a', 'dbName': 'db_a', 'name': 'Kayip Madenler'},
        {'name': 'kimliksiz'}, // atlanir
        {'id': 'b'}, // dosya adi yok, atlanir
      ]);
      final registry = CampaignRegistry.decode(raw, 'a');
      expect(registry.campaigns.map((c) => c.id), ['a']);
      expect(registry.active.name, 'Kayip Madenler');
    });

    test('ayni kimlik/dosya iki kez sayilmaz', () {
      final raw = jsonEncode([
        {'id': 'a', 'dbName': 'db_a'},
        {'id': 'a', 'dbName': 'db_baska'},
        {'id': 'c', 'dbName': 'db_a'},
      ]);
      expect(CampaignRegistry.decode(raw, 'a').campaigns.length, 1);
    });

    test('gecersiz activeId var olan bir kampanyaya duser', () {
      final raw = jsonEncode([
        {'id': 'a', 'dbName': 'db_a'},
      ]);
      expect(CampaignRegistry.decode(raw, 'silinmis').activeId, 'a');
    });

    test('yalnizca silinmeyi bekleyen kayit varsa varsayilan tohumlanir', () {
      final raw = jsonEncode([
        {'id': 'a', 'dbName': 'db_a', 'pendingDelete': true},
      ]);
      final registry = CampaignRegistry.decode(raw, 'a');
      expect(registry.visible.single.id, Campaign.defaultId);
      expect(registry.activeId, Campaign.defaultId);
    });

    test('gidis-donus: kaydedilen liste aynen geri okunur', () {
      final (created, campaign) = CampaignRegistry.decode(
        null,
        null,
      ).created('Ejderha Kuyusu');
      final round = CampaignRegistry.decode(created.encodeList(), campaign.id);
      expect(round.campaigns.length, 2);
      expect(round.active.name, 'Ejderha Kuyusu');
      expect(round.active.dbName, campaign.dbName);
      // Yeni kampanya varsayilandan AYRI bir dosya kullanmali.
      expect(campaign.dbName, isNot(Campaign.defaultDbName));
    });
  });

  group('Campaign', () {
    test('varsayilan kampanya medyayi uygulama kokunde tutar', () {
      // Guncellemeden onceki maps/portraits/codex_media dosyalari tasinmaz.
      final registry = CampaignRegistry.decode(null, null);
      expect(registry.active.mediaPrefix, isNull);
    });

    test('yeni kampanya medyasi kendi klasorunde', () {
      final (_, campaign) = CampaignRegistry.decode(
        null,
        null,
      ).created('Ikinci');
      expect(campaign.mediaPrefix, contains(campaign.id));
    });
  });

  group('dosya yasam dongusu', () {
    late Directory temp;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('dm-campaign-test');
      CampaignPaths.rootOverride = temp;
    });

    tearDown(() {
      CampaignPaths.rootOverride = null;
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    test('databaseFile acilan yolla ayni yeri gosterir', () async {
      final file = await CampaignPaths.databaseFile('dm_masasi_abc');
      expect(file.path, endsWith('dm_masasi_abc.sqlite'));
      expect(file.parent.path, temp.path);
    });

    test('silme veritabanini ve medya klasorunu goturur', () async {
      final (registry, campaign) = CampaignRegistry.decode(
        null,
        null,
      ).created('Silinecek');
      final db = await CampaignPaths.databaseFile(campaign.dbName);
      db.writeAsStringSync('sqlite');
      final media = await CampaignPaths.mediaRoot(campaign);
      media.createSync(recursive: true);
      File('${media.path}/harita.png').writeAsStringSync('x');

      expect(await CampaignManager.deleteFiles(campaign), isTrue);
      expect(db.existsSync(), isFalse);
      expect(media.existsSync(), isFalse);
      expect(registry.removed(campaign.id).visible.length, 1);
    });

    test('olmayan dosyada silme yine de basarili sayilir', () async {
      final (_, campaign) = CampaignRegistry.decode(null, null).created('Yok');
      expect(await CampaignManager.deleteFiles(campaign), isTrue);
    });

    test('varsayilan kampanyanin medya kokune DOKUNULMAZ', () async {
      // Varsayilan kampanya uygulama klasorunun kokunu paylasir; silme
      // rutini burayi silseydi tum kullanicinin belgeleri giderdi.
      final marker = File('${temp.path}/dokunma.txt')..writeAsStringSync('!');
      final registry = CampaignRegistry.decode(null, null);
      await CampaignManager.deleteFiles(registry.active);
      expect(marker.existsSync(), isTrue);
    });

    test(
      'purgePending bekleyen kampanyayi temizler ve kayittan dusurur',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final (created, campaign) = CampaignRegistry.decode(
          null,
          null,
        ).created('Bekleyen');
        final db = await CampaignPaths.databaseFile(campaign.dbName);
        db.writeAsStringSync('sqlite');

        final purged = await CampaignManager.purgePending(
          prefs,
          created.markedForDelete(campaign.id),
        );
        expect(db.existsSync(), isFalse);
        expect(purged.campaigns.any((c) => c.id == campaign.id), isFalse);
        // Kalicilastirildi mi?
        expect(prefs.getString(CampaignRegistry.prefsList), isNotNull);
      },
    );
  });

  test('kap dispose sirasi: bagimli ONCE, veritabani SONRA', () {
    // `CampaignRoot` bu garantiye dayaniyor: kampanya degistirirken LAN
    // sunucusu, kullandigi veritabanindan once kapanmali. Provider'i yerinde
    // invalidate etmek bunu TERSINE cevirir (invalidateSelf once kendi
    // onDispose'unu calistirir), bu yuzden kabin tamami yenileniyor.
    final order = <String>[];
    final dbProvider = Provider<String>((ref) {
      ref.onDispose(() => order.add('close'));
      return 'db';
    });
    final serviceProvider = Provider<String>((ref) {
      ref.watch(dbProvider);
      ref.onDispose(() => order.add('stop'));
      return 'service';
    });

    final container = ProviderContainer();
    container.read(serviceProvider);
    container.dispose();

    expect(order, ['stop', 'close']);
  });
}
