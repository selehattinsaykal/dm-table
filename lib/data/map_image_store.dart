import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'media_root.dart';

/// Kaydedilen haritanin sonuclari.
typedef StoredMap = ({String imagePath, int width, int height});

/// Harita gorsellerini dosya sisteminde saklar.
///
/// Gorseller veritabanina gomulmuyor: bir harita 10-20 MB olabiliyor ve
/// SQLite'i sismanlatmanin yani sira her sorguda bellege girme riski var.
/// Veritabaninda yalnizca uygulama klasorune gore GORELI yol duruyor --
/// Android yeniden kurulumda mutlak yolu degistirebiliyor.
class MapImageStore {
  MapImageStore({this.directoryOverride});

  /// Testlerde gercek uygulama klasoru yerine gecici klasor vermek icin.
  final Directory? directoryOverride;

  static const _uuid = Uuid();
  static const _folder = 'maps';

  Future<Directory> _root() async {
    final base = directoryOverride ?? await MediaRoot.resolve();
    final dir = Directory(p.join(base.path, _folder));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Secilen gorseli medya klasorune kopyalar.
  ///
  /// Cozulemeyen dosyalarda [FormatException] atar; cagiran kullaniciya
  /// anlamli bir hata gosterebilsin.
  Future<StoredMap> store(File source) async {
    final bytes = await source.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Görsel okunamadı.');
    }

    final root = await _root();
    final id = _uuid.v4();
    final extension = p.extension(source.path).toLowerCase();
    // Bilinmeyen uzantilarda png'ye normalize ediyoruz.
    final safeExtension =
        const {'.png', '.jpg', '.jpeg', '.webp'}.contains(extension)
        ? extension
        : '.png';

    final imageFile = File(p.join(root.path, '$id$safeExtension'));
    await imageFile.writeAsBytes(bytes);

    return (
      imagePath: p.join(_folder, p.basename(imageFile.path)),
      width: decoded.width,
      height: decoded.height,
    );
  }

  /// Goreli yolu okunabilir mutlak dosyaya cevirir.
  Future<File> resolve(String relativePath) async {
    final base = directoryOverride ?? await MediaRoot.resolve();
    return File(p.join(base.path, relativePath));
  }

  /// Harita gorselini siler. Dosya yoksa sessizce gecer.
  Future<void> delete(String? imagePath) async {
    if (imagePath == null) return;
    final file = await resolve(imagePath);
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
