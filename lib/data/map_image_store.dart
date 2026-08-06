import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'media_root.dart';

/// Kaydedilen haritanin sonuclari.
typedef StoredMap = ({
  String imagePath,
  String previewPath,
  int width,
  int height,
});

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

  /// Oyunculara gonderilen surumun en uzun kenari.
  ///
  /// Tam cozunurluklu harita LAN uzerinden telefonlara gitmek zorunda degil;
  /// masada oyuncu ekraninda bu boyut fazlasiyla yeterli ve aktarim aninda
  /// tamamlaniyor.
  static const previewMaxSide = 1600;

  Future<Directory> _root() async {
    final base = directoryOverride ?? await MediaRoot.resolve();
    final dir = Directory(p.join(base.path, _folder));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Secilen gorseli kopyalar ve kucultulmus surumunu uretir.
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

    final longest = decoded.width > decoded.height
        ? decoded.width
        : decoded.height;
    final preview = longest <= previewMaxSide
        ? decoded
        : img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? previewMaxSide : null,
            height: decoded.height > decoded.width ? previewMaxSide : null,
            interpolation: img.Interpolation.average,
          );

    final previewFile = File(p.join(root.path, '$id-preview.jpg'));
    await previewFile.writeAsBytes(img.encodeJpg(preview, quality: 82));

    return (
      imagePath: p.join(_folder, p.basename(imageFile.path)),
      previewPath: p.join(_folder, p.basename(previewFile.path)),
      width: decoded.width,
      height: decoded.height,
    );
  }

  /// Goreli yolu okunabilir mutlak dosyaya cevirir.
  Future<File> resolve(String relativePath) async {
    final base = directoryOverride ?? await MediaRoot.resolve();
    return File(p.join(base.path, relativePath));
  }

  /// Haritayi ve onizlemesini siler. Dosya yoksa sessizce gecer.
  Future<void> delete(String? imagePath, String? previewPath) async {
    for (final path in [imagePath, previewPath]) {
      if (path == null) continue;
      final file = await resolve(path);
      if (file.existsSync()) {
        await file.delete();
      }
    }
  }
}
