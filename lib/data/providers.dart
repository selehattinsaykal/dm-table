import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'campaign/campaign.dart';
import 'compendium_repository.dart';
import 'db/database.dart';
import 'import/asset_importer.dart';

/// Açık kampanya.
///
/// `CampaignRoot` (bkz. `lib/main.dart`) her `ProviderScope` kurarken bunu
/// override eder; scope içinde SABİTTİR. Kampanya değiştirmek scope'u yeniden
/// kurmak demektir — provider'ı yerinde invalidate ETMEK YANLIŞTIR: Riverpod
/// `invalidateSelf`'te önce kendi `onDispose`'unu (yani `db.close()`) çalıştırıp
/// bağımlıları yalnızca işaretlediği için veritabanı, onu kullanan LAN
/// sunucusundan ÖNCE kapanır.
final activeCampaignProvider = Provider<Campaign>(
  (ref) => throw StateError(
    'activeCampaignProvider override edilmeli (bkz. CampaignRoot).',
  ),
);

/// Acik kampanyanin veritabani baglantisi.
final databaseProvider = Provider<AppDatabase>((ref) {
  final campaign = ref.watch(activeCampaignProvider);
  final db = AppDatabase.forCampaign(campaign.dbName);
  ref.onDispose(db.close);
  return db;
});

final compendiumRepositoryProvider = Provider<CompendiumRepository>(
  (ref) => CompendiumRepository(ref.watch(databaseProvider)),
);

/// Ice aktarma sirasinda hangi tablonun yazildigini arayuze bildirir.
class ImportProgress extends Notifier<String?> {
  @override
  String? build() => null;

  void report(String? table) => state = table;
}

final importProgressProvider = NotifierProvider<ImportProgress, String?>(
  ImportProgress.new,
);

/// Paketlenmis SRD verisini gerekiyorsa ice aktarir; uygulama acilirken
/// beklenen tek is budur.
///
/// Her kampanya kendi dosyasini tasidigi icin yeni bir kampanya ilk acildiginda
/// kutuphane oraya bir kez yazilir (ilerleme ekrani `ContentGate`'te).
final contentReadyProvider = FutureProvider<void>((ref) async {
  final importer = AssetImporter(ref.watch(databaseProvider));
  final progress = ref.read(importProgressProvider.notifier);
  await importer.importIfNeeded(onProgress: progress.report);
  progress.report(null);
});
