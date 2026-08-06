import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Harita/portre/video klasörlerinin kök dizini.
///
/// Uygulamada tek seferde tek kampanya açık olduğu için süreç genelinde tek
/// bir kök yeterli: `CampaignRoot` açılışta ve kampanya değişiminde [current]
/// değerini ayarlar (bkz. `lib/main.dart`). Store'lar (harita/portre/codex)
/// göreli yol yazdığı için veritabanındaki kayıtlar bundan etkilenmez.
///
/// Varsayılan kampanyada `null` kalır → uygulama klasörünün kendisi kullanılır,
/// yani güncellemeden önceki `maps/`, `portraits/`, `codex_media/` dosyaları
/// yerinde çalışmaya devam eder.
class MediaRoot {
  const MediaRoot._();

  static Directory? current;

  static Future<Directory> resolve() async =>
      current ?? await getApplicationDocumentsDirectory();
}
