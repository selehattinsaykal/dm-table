import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'backup_repository.dart';
import 'campaign/campaign_paths.dart';

/// Gunde bir kez, sessizce yedek alir.
///
/// **Neden var:** yedekleme elle yapiliyordu, yani yalnizca aklina gelen kisi
/// icin vardi. Bir kampanya dosyasi tek bir hatali silmeyle ya da bozuk bir
/// gocle gidebiliyor; masada olan bir seyi geri getirmenin baska yolu yok.
///
/// Tasarim kararlari:
///  * **Gunde bir**: her acilista yedek almak diski gereksiz doldururdu.
///  * **En fazla [_keep] kopya**: en eskisi dusuyor, klasor sinirsiz buyumez.
///  * **Sessiz basarisizlik**: yedek alinamamasi uygulamanin acilmasini
///    engellememeli. Yedek bir guvence, bir on kosul degil.
///  * **Ikinci bir klasore kopya**: kullanici bir klasor secerse ([mirrorDir])
///    ayni yedek oraya da yazilir. Bulut istemcisiyle (OneDrive, Drive,
///    Dropbox) esitlenen bir klasor secilirse yedek cihazlar arasinda
///    tasinmis olur. Uygulama KENDI bulut hesabini kullanmiyor: hesap
///    istemek, sunucu tutmak ve kampanya verisini disariya tasimak demekti.
class AutoBackup {
  const AutoBackup(this.backups, {this.mirrorDir});

  final BackupRepository backups;

  /// Yedegin ikinci kopyasinin yazilacagi klasor; null = yalnizca uygulama
  /// klasoru.
  final String? mirrorDir;

  static const _keep = 7;
  static const _key = 'backup.lastAuto';

  /// Yedeklerin durdugu klasor.
  static Future<Directory> directory() async {
    final root = await CampaignPaths.root();
    final dir = Directory(p.join(root.path, 'backups'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  /// Gun degistiyse yedek alir; aldiysa dosyayi doner.
  Future<File?> runIfDue({DateTime? now}) async {
    try {
      final today = (now ?? DateTime.now());
      final stamp = '${today.year}-${_two(today.month)}-${_two(today.day)}';
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_key) == stamp) return null;

      final bytes = await backups.export();
      final dir = await directory();
      final file = File(p.join(dir.path, 'auto-$stamp.dmtable'));
      await file.writeAsBytes(bytes);
      await prefs.setString(_key, stamp);
      await _prune(dir);
      await mirror(bytes, 'auto-$stamp.dmtable');
      return file;
    } on Object {
      // Yedek alinamadi: disk dolu, izin yok, dosya kilitli... Hicbiri
      // uygulamanin acilmasini engellememeli.
      return null;
    }
  }

  /// Yedegi [mirrorDir]'e de yazar.
  ///
  /// Bulut klasoru mevcut OLMAYABILIR (kullanici disk degistirmis, USB
  /// cikarilmis): bu durumda sessizce geciliyor, asil yedek zaten alindi.
  Future<File?> mirror(List<int> bytes, String name) async {
    final target = mirrorDir;
    if (target == null || target.trim().isEmpty) return null;
    try {
      final dir = Directory(target);
      if (!dir.existsSync()) return null;
      final file = File(p.join(dir.path, name));
      await file.writeAsBytes(bytes);
      await _prune(dir);
      return file;
    } on Object {
      return null;
    }
  }

  /// En yeni [_keep] kopyayi birakir.
  ///
  /// Esleme KULLANICININ sectigi klasorde de kosuyor; bu yuzden hem
  /// `auto-` oneki hem `.dmtable` uzantisi araniyor. Yalnizca oneke
  /// bakmak, o klasordeki ilgisiz bir `auto-*` dosyasini silebilirdi.
  Future<void> _prune(Directory dir) async {
    final files = dir.listSync().whereType<File>().where((f) {
      final name = p.basename(f.path);
      return name.startsWith('auto-') && name.endsWith('.dmtable');
    }).toList()..sort((a, b) => b.path.compareTo(a.path));
    for (final file in files.skip(_keep)) {
      try {
        await file.delete();
      } on FileSystemException {
        // Kilitli dosya: bir dahaki acilista silinir.
      }
    }
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
