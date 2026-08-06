import 'backup_repository.dart';
import 'campaign/campaign.dart';
import 'campaign/campaign_manager.dart';
import 'campaign/campaign_paths.dart';
import 'character_image_store.dart';
import 'codex_media_store.dart';
import 'db/database.dart';
import 'map_image_store.dart';
import 'music_store.dart';

/// Bir yedeği **yeni bir kampanyaya** geri yükler.
///
/// Normal geri yükleme açık kampanyanın üzerine yazar; bu ise yedeği ayrı bir
/// kampanya olarak kurar (bir arkadaşın masasını kendi cihazında açmak ya da
/// eski bir kaydı yanına almak için).
///
/// **Neden kampanya açılmadan yapılıyor:** [CampaignManager.create] kampanyaya
/// geçtiği anda `CampaignRoot` `ProviderScope`'u yıkıp yeniden kuruyor ve
/// yedeği yazacak olan widget o sırada dispose ediliyor. Bunun yerine kayıt
/// açılmadan oluşturulur, veritabanı doğrudan açılır, veri yazılır ve kapatılır
/// — aktif kampanyaya hiç dokunulmaz.
///
/// Medya klasörleri de override ile veriliyor: store'lar varsayılan olarak
/// süreç genelindeki [MediaRoot] kökünü kullanır, o da AKTİF kampanyayı
/// gösterir — override verilmezse portreler/haritalar yanlış kampanyanın
/// klasörüne yazılırdı.
class BackupRestoreService {
  const BackupRestoreService(this.manager, {this.openDatabase});

  final CampaignManager manager;

  /// Yeni kampanyanın veritabanını açar. Yalnızca **test** için var:
  /// [AppDatabase.forCampaign] `drift_flutter` üzerinden platform kanalı
  /// kullanıyor ve düz `flutter test` içinde açılamıyor.
  final AppDatabase Function(Campaign campaign)? openDatabase;

  /// Yedeği [name] adıyla yeni bir kampanyaya yükler ve kaydı döner.
  ///
  /// Yazma başarısız olursa yarım kalmış kampanya kaydı ve dosyaları temizlenir
  /// — kullanıcı listede bozuk bir kayıtla kalmamalı.
  Future<Campaign> restoreAsNewCampaign({
    required String name,
    required List<int> bytes,
  }) async {
    final campaign = await manager.createWithoutOpening(name);
    final db =
        openDatabase?.call(campaign) ??
        AppDatabase.forCampaign(campaign.dbName);
    try {
      final mediaRoot = await CampaignPaths.mediaRoot(campaign);
      await BackupRepository(
        db,
        images: MapImageStore(directoryOverride: mediaRoot),
        portraits: CharacterImageStore(directoryOverride: mediaRoot),
        media: CodexMediaStore(directoryOverride: mediaRoot),
        music: MusicStore(directoryOverride: mediaRoot),
      ).import(bytes);
    } on Object {
      // Temizlik SIRASI onemli: dosya silinmeden once veritabani kapanmali,
      // yoksa Windows'ta kilit yuzunden silme basarisiz olur.
      await db.close();
      await manager.delete(campaign.id);
      rethrow;
    }
    await db.close();
    return campaign;
  }
}
