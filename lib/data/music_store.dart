import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'media_root.dart';

/// Müzik dosyalarını kampanya medya klasöründe saklar.
///
/// `CodexMediaStore` ile aynı desen: dosya olduğu gibi kopyalanır (yeniden
/// kodlanmaz), veritabanında **göreli** yol tutulur. Böylece kampanya klasörü
/// taşınsa da kayıtlar bozulmaz.
class MusicStore {
  MusicStore({this.directoryOverride});

  /// Testlerde gerçek uygulama klasörü yerine geçici klasör vermek için.
  final Directory? directoryOverride;

  static const _uuid = Uuid();
  static const folder = 'music';

  /// Kabul edilen uzantılar. media_kit (libmpv) hepsini çalar.
  static const extensions = ['mp3', 'm4a', 'aac', 'ogg', 'opus', 'wav', 'flac'];

  Future<Directory> _root() async {
    final base = directoryOverride ?? await MediaRoot.resolve();
    final dir = Directory(p.join(base.path, folder));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Seçilen dosyayı kampanya klasörüne kopyalar; göreli yol döner.
  Future<String> store(File source) async {
    final root = await _root();
    final ext = p.extension(source.path);
    final file = File(p.join(root.path, '${_uuid.v4()}$ext'));
    await source.copy(file.path);
    return p.join(folder, p.basename(file.path));
  }

  /// Göreli yolu okunabilir mutlak dosyaya çevirir.
  Future<File> resolve(String relativePath) async {
    final base = directoryOverride ?? await MediaRoot.resolve();
    return File(p.join(base.path, relativePath));
  }

  /// Dosyayı siler. Yoksa sessizce geçer.
  Future<void> delete(String? path) async {
    if (path == null) return;
    final file = await resolve(path);
    if (file.existsSync()) await file.delete();
  }
}
