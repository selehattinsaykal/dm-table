import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:shelf/shelf.dart';

/// Gomulu oyuncu panelini (Flutter web derlemesi) asset paketinden servis eder.
///
/// `shelf_static` kullanilamiyor: web derlemesi APK'nin icinde, dosya
/// sisteminde degil. Bu yuzden istekler dogrudan `rootBundle`'a ceviriliyor.
///
/// Dosyalar bir kez okunup bellekte tutulur; masada birden fazla oyuncu ayni
/// anda baglandiginda 3 MB'lik `main.dart.js` her seferinde asset'ten
/// cozulmesin diye.
Handler createPlayerAppHandler({String assetRoot = 'assets/player_web'}) {
  final cache = <String, List<int>>{};

  return (Request request) async {
    var path = request.url.path;
    // Kok istegi ve istemci tarafi yonlendirmeler index.html'e duser.
    if (path.isEmpty || path == '/') path = 'index.html';

    // Asset paketi disina cikilamasin.
    if (path.contains('..')) return Response.forbidden('Geçersiz yol');

    final key = '$assetRoot/$path';
    var bytes = cache[key];

    if (bytes == null) {
      try {
        final data = await rootBundle.load(key);
        bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        cache[key] = bytes;
      } on Object {
        // `rootBundle` eksik asset icin Exception degil FlutterError (bir
        // Error) firlatiyor; dar yakalama 404 yerine 500 uretiyordu.
        return Response.notFound(
          path == 'index.html'
              ? 'Oyuncu paneli bu sürüme gömülmemiş.'
              : 'Bulunamadı: $path',
        );
      }
    }

    return Response.ok(
      bytes,
      headers: {
        'content-type': _contentTypeFor(path),
        // Panel her derlemede degistigi icin onbellege alinmasin; masada
        // "eski surum acildi" hatasi en can sikici olani olurdu.
        'cache-control': 'no-cache',
      },
    );
  };
}

String _contentTypeFor(String path) {
  final extension = path.contains('.')
      ? path.split('.').last.toLowerCase()
      : '';
  return switch (extension) {
    'html' => 'text/html; charset=utf-8',
    'js' || 'mjs' => 'application/javascript; charset=utf-8',
    'json' => 'application/json; charset=utf-8',
    'css' => 'text/css; charset=utf-8',
    'wasm' => 'application/wasm',
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'svg' => 'image/svg+xml',
    'ico' => 'image/x-icon',
    'ttf' => 'font/ttf',
    'otf' => 'font/otf',
    'woff' => 'font/woff',
    'woff2' => 'font/woff2',
    'bin' || 'symbols' => 'application/octet-stream',
    _ => 'application/octet-stream',
  };
}

/// Panelin gomulu olup olmadigini soyler; oturum ekrani buna gore uyarir.
Future<bool> isPlayerAppBundled({
  String assetRoot = 'assets/player_web',
}) async {
  try {
    await rootBundle.loadString('$assetRoot/index.html');
    return true;
  } on Object {
    return false;
  }
}

/// Pakete gomulu panel dosyasi sayisi; kurulum tanilamasi icin.
Future<int> countBundledPlayerAssets({
  String assetRoot = 'assets/player_web',
}) async {
  try {
    // `AssetManifest.json` Flutter 3.x'te kaldirildi; ikili manifest bu API
    // uzerinden okunuyor.
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    return manifest.listAssets().where((k) => k.startsWith(assetRoot)).length;
  } on Object {
    return 0;
  }
}
