import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app_settings.dart';
import 'auto_backup.dart';
import 'backup_repository.dart';
import 'campaign/campaign.dart';
import 'character_repository.dart';
import 'compendium_repository.dart';
import 'downtime_repository.dart';
import 'encounter_template_repository.dart';
import 'macro_repository.dart';
import 'db/database.dart';
import 'import/asset_importer.dart';
import 'import/fivetools/content_source_repository.dart';
import 'import/fivetools/fivetools_importer.dart';

/// Açık kampanya.
///
/// `CampaignRoot` (bkz. `lib/main.dart`) her `ProviderScope` kurarken bunu
/// override eder; scope içinde SABİTTİR. Kampanya değiştirmek scope'u yeniden
/// kurmak demektir — provider'ı yerinde invalidate ETMEK YANLIŞTIR: Riverpod
/// `invalidateSelf`'te önce kendi `onDispose`'unu (yani `db.close()`) çalıştırıp
/// bağımlıları yalnızca işaretlediği için veritabanı, onu kullanan depolardan
/// ÖNCE kapanır.
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

/// Kaydedilmis karsilasma kaliplari.
final encounterTemplateRepositoryProvider =
    Provider<EncounterTemplateRepository>(
      (ref) => EncounterTemplateRepository(ref.watch(databaseProvider)),
    );

final encounterTemplatesProvider = StreamProvider<List<EncounterTemplate>>(
  (ref) => ref.watch(encounterTemplateRepositoryProvider).watchAll(),
);

/// Zar makrolari.
final macroRepositoryProvider = Provider<MacroRepository>(
  (ref) => MacroRepository(ref.watch(databaseProvider)),
);

final macrosProvider = StreamProvider<List<Macro>>(
  (ref) => ref.watch(macroRepositoryProvider).watchAll(),
);

/// Bos zaman faaliyetleri.
final downtimeRepositoryProvider = Provider<DowntimeRepository>(
  (ref) => DowntimeRepository(ref.watch(databaseProvider)),
);

final downtimeProvider = StreamProvider<List<DowntimeActivity>>(
  (ref) => ref.watch(downtimeRepositoryProvider).watchAll(),
);

/// Kullanicinin tanimladigi icerik kaynaklari.
final contentSourceRepositoryProvider = Provider<ContentSourceRepository>(
  (ref) => ContentSourceRepository(ref.watch(databaseProvider)),
);

final contentSourcesProvider = StreamProvider<List<ContentSource>>(
  (ref) => ref.watch(contentSourceRepositoryProvider).watchAll(),
);

/// 5etools bicimli veriyi kutuphaneye yazan ice aktarici.
final fiveToolsImporterProvider = Provider<FiveToolsImporter>(
  (ref) => FiveToolsImporter(ref.watch(databaseProvider)),
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
  final db = ref.watch(databaseProvider);
  final importer = AssetImporter(db);
  final progress = ref.read(importProgressProvider.notifier);
  final imported = await importer.importIfNeeded(onProgress: progress.report);

  // Kutuphane yenilendiyse var olan karakterlerin sinif yetenekleri ve alt
  // siniftan gelen buyuleri de tazelenir; yoksa duzeltilmis/eklenmis
  // yetenekler yalnizca YENI karakterlerde gorunurdu.
  if (imported) {
    progress.report('characters');
    await CharacterRepository(db).syncAllCharacters();
  }
  progress.report(null);

  // Gunluk sessiz yedek. ICERIK HAZIR OLDUKTAN SONRA ve `await` EDILMEDEN:
  // yedek almak acilisi bekletmemeli, alinamamasi da acilisi engellememeli.
  unawaited(
    AutoBackup(
      BackupRepository(db),
      mirrorDir: ref.read(appSettingsProvider).syncFolder,
    ).runIfDue(),
  );
});
