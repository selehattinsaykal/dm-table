import 'dart:io';

import 'package:path/path.dart' as p;
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

  /// Bir kez cozulup saklanan kok.
  ///
  /// Cizim yolunda gorsel yollarini cozmek gerekiyor ve orasi SENKRON:
  /// her jeton icin `await` etmek cizimi bloklardi. Kok uygulama acilirken
  /// bir kez isiniyor (bkz. [warmUp]).
  static Directory? _cached;

  static Future<Directory> resolve() async =>
      _cached = current ?? _cached ?? await getApplicationDocumentsDirectory();

  /// Kokun ONBELLEKTEKI hali; henuz cozulmediyse null.
  static Directory? get cached => current ?? _cached;

  /// Kokü onceden cozer. Acilista bir kez cagriliyor.
  static Future<void> warmUp() => resolve();

  /// Goreli bir medya yolunu MUTLAK hale getirir.
  ///
  /// Yol zaten mutlaksa oldugu gibi doner. Kok henuz cozulmediyse yolu
  /// DEGISTIRMEDEN doner: yanlis bir mutlak yol uretmektense goreli
  /// birakmak daha az zararli.
  static String absolute(String relative) {
    if (relative.isEmpty) return relative;
    if (p.isAbsolute(relative)) return relative;
    final root = cached;
    return root == null ? relative : p.join(root.path, relative);
  }
}
