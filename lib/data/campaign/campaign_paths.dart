import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'campaign.dart';

/// Kampanya dosyalarının TEK yol kaynağı.
///
/// Veritabanını açan kod ile silen kod aynı fonksiyonu kullanmalı; yoksa
/// "açıldı ama silinemedi" sınıfı hatalar çıkar. `driftDatabase(name: x)`
/// varsayılan olarak `<Belgeler>/x.sqlite` açar — [databaseFile] bilinçli
/// olarak aynı yolu üretir, böylece varsayılan kampanya güncellemeden sonra
/// da tam olarak eski dosyasını açar.
class CampaignPaths {
  const CampaignPaths._();

  /// Testlerde gerçek Belgeler klasörü yerine geçici klasör vermek için.
  static Directory? rootOverride;

  static Future<Directory> root() async =>
      rootOverride ?? await getApplicationDocumentsDirectory();

  static Future<File> databaseFile(String dbName) async =>
      File(p.join((await root()).path, '$dbName.sqlite'));

  /// Veritabanının kendisi + sqlite yan dosyaları.
  ///
  /// Proje WAL kullanmıyor (hiçbir yerde `journal_mode` pragma'sı yok), yani
  /// pratikte yalnız ilk dosya var olur; yine de ileride WAL açılırsa silme
  /// eksik kalmasın diye kardeşler de listelenir.
  static Future<List<File>> databaseFiles(String dbName) async {
    final base = await databaseFile(dbName);
    return [
      base,
      for (final suffix in const ['-wal', '-shm', '-journal'])
        File('${base.path}$suffix'),
    ];
  }

  /// Kampanyanın medya kökü. Varsayılan kampanyada uygulama klasörünün
  /// kendisidir (eski dosyalar yerinde kalır); diğerlerinde
  /// `<Belgeler>/campaigns/<id>/`.
  static Future<Directory> mediaRoot(Campaign campaign) async {
    final base = await root();
    final prefix = campaign.mediaPrefix;
    return prefix == null ? base : Directory(p.join(base.path, prefix));
  }
}
