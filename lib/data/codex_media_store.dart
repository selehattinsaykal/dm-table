import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'media_root.dart';

/// Kayitlar (Codex) video dosyalarini dosya sisteminde saklar.
///
/// Portrelerin aksine yeniden kodlanmaz/kucultulmez: video oldugu gibi
/// kopyalanir (uzantisi korunur). Uygulama klasorune gore GORELI yol
/// veritabaninda (blok data_json) tutulur.
class CodexMediaStore {
  CodexMediaStore({this.directoryOverride});

  /// Testlerde gercek uygulama klasoru yerine gecici klasor vermek icin.
  final Directory? directoryOverride;

  static const _uuid = Uuid();
  static const folder = 'codex_media';

  Future<Directory> _root() async {
    final base = directoryOverride ?? await MediaRoot.resolve();
    final dir = Directory(p.join(base.path, folder));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Secilen videoyu uygulama klasorune kopyalar; goreli yol doner.
  Future<String> store(File source) async {
    final root = await _root();
    final ext = p.extension(source.path);
    final file = File(p.join(root.path, '${_uuid.v4()}$ext'));
    await source.copy(file.path);
    return p.join(folder, p.basename(file.path));
  }

  /// Goreli yolu okunabilir mutlak dosyaya cevirir.
  Future<File> resolve(String relativePath) async {
    final base = directoryOverride ?? await MediaRoot.resolve();
    return File(p.join(base.path, relativePath));
  }

  /// Videoyu siler. Dosya yoksa sessizce gecer.
  Future<void> delete(String? path) async {
    if (path == null) return;
    final file = await resolve(path);
    if (file.existsSync()) await file.delete();
  }
}
