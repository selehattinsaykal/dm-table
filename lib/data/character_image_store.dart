import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'media_root.dart';

/// Karakter portrelerini dosya sisteminde saklar.
///
/// Harita gorselleri gibi veritabanina gomulmez; uygulama klasorune gore GORELI
/// yol veritabaninda tutulur. Portre kucuk oldugu icin tek bir kucultulmus
/// surum yeterli -- oyuncu telefonunda ve karakter kagidinda bu boyut yeter.
class CharacterImageStore {
  CharacterImageStore({this.directoryOverride});

  /// Testlerde gercek uygulama klasoru yerine gecici klasor vermek icin.
  final Directory? directoryOverride;

  static const _uuid = Uuid();
  static const _folder = 'portraits';

  /// Portrenin en uzun kenari.
  static const maxSide = 640;

  Future<Directory> _root() async {
    final base = directoryOverride ?? await MediaRoot.resolve();
    final dir = Directory(p.join(base.path, _folder));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Secilen gorseli kopyalayip kucultur; uygulama klasorune gore goreli yol
  /// doner. Cozulemeyen dosyalarda [FormatException] atar.
  Future<String> store(File source) async =>
      storeBytes(await source.readAsBytes());

  /// Ham gorsel baytlarini kucultup saklar; goreli yol doner.
  ///
  /// [store] ile ayni isi yapar ama diskteki bir kaynak dosya gerektirmez —
  /// AI ile URETILEN portreler dogrudan bellekten gelir, once gecici dosyaya
  /// yazip sonra okumak gereksiz.
  Future<String> storeBytes(Uint8List bytes) async {
    // `decodeImage` bozuk girdide her zaman null donmuyor; bicimi tanidigini
    // sanip cozerken RangeError gibi hatalar da atabiliyor. AI ile uretilen
    // portrelerde govde gorsel yerine bir hata metni olabildigi icin butun
    // cozme hatalari tek bir FormatException'a indirgenir — cagiran tek bir
    // hal ele almali.
    final img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      throw const FormatException('Görsel okunamadı.');
    }
    if (decoded == null) {
      throw const FormatException('Görsel okunamadı.');
    }

    final root = await _root();
    final id = _uuid.v4();
    final longest = decoded.width > decoded.height
        ? decoded.width
        : decoded.height;
    final resized = longest <= maxSide
        ? decoded
        : img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? maxSide : null,
            height: decoded.height > decoded.width ? maxSide : null,
            interpolation: img.Interpolation.average,
          );

    final file = File(p.join(root.path, '$id.jpg'));
    await file.writeAsBytes(img.encodeJpg(resized, quality: 82));
    return p.join(_folder, p.basename(file.path));
  }

  /// Goreli yolu okunabilir mutlak dosyaya cevirir.
  Future<File> resolve(String relativePath) async {
    final base = directoryOverride ?? await MediaRoot.resolve();
    return File(p.join(base.path, relativePath));
  }

  /// Portreyi siler. Dosya yoksa sessizce gecer.
  Future<void> delete(String? path) async {
    if (path == null) return;
    final file = await resolve(path);
    if (file.existsSync()) await file.delete();
  }
}
