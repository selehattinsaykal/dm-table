// Ikon kaynagini ve ANDROID launcher ikonlarini uretir.
//
// **Neden var:** kaynak logonun 1024'luk tuvalinde genis bir bos kenar payi
// var (icerik yalnizca 614x778). Bu dosya dogrudan ikona cevrilince logo
// gorev cubugunda/sekmede oldugundan kucuk goruunuyordu. Burasi logoyu
// ICERIGINE KIRPIP kare tuvalin [_fill] oranina oturtur.
//
// Uretilenler:
//   * `assets/logo/logo_icon.png` — Windows ikonunun kaynagi
//     (`dart run flutter_launcher_icons`, bkz. pubspec.yaml),
//   * `android/app/src/main/res/mipmap-*/` — Android launcher ikonlari,
//     hem eski kare ikon hem de uyarlanir (adaptive) ikonun on plani.
//
// Android ikonlari icin AYRI bir paket kullanilmiyor: depo zaten bu araci
// tasiyor ve `flutter_launcher_icons` dev_dependency degil.
//
// Kullanim (logo degistiginde):
//   dart run tools/build_icon.dart
//   dart run flutter_launcher_icons   # yalnizca Windows .ico icin
library;

import 'dart:io';

import 'package:image/image.dart' as img;

/// Kare tuvalin ikonun kaplayacagi orani. Tamamen kenara dayanan bir logo
/// sikisik gorunuyor; %92 kucuk bir nefes payi birakir.
const double _fill = 0.92;

const int _side = 1024;

const _source = 'assets/logo/logo.png';
const _output = 'assets/logo/logo_icon.png';

void main() {
  final file = File(_source);
  if (!file.existsSync()) {
    stderr.writeln('Kaynak bulunamadi: $_source');
    exitCode = 1;
    return;
  }

  final source = img.decodePng(file.readAsBytesSync());
  if (source == null) {
    stderr.writeln('PNG cozulemedi: $_source');
    exitCode = 1;
    return;
  }

  final bounds = _contentBounds(source);
  if (bounds == null) {
    stderr.writeln('Logo tamamen saydam; kirpilacak icerik yok.');
    exitCode = 1;
    return;
  }

  final cropped = img.copyCrop(
    source,
    x: bounds.left,
    y: bounds.top,
    width: bounds.width,
    height: bounds.height,
  );

  // En-boy orani KORUNUR: uzun kenar hedefe oturur, kisa kenar ortalanir.
  final target = (_side * _fill).round();
  final scale =
      target /
      (cropped.width > cropped.height ? cropped.width : cropped.height);
  final resized = img.copyResize(
    cropped,
    width: (cropped.width * scale).round().clamp(1, _side),
    height: (cropped.height * scale).round().clamp(1, _side),
    interpolation: img.Interpolation.cubic,
  );

  final canvas = img.Image(width: _side, height: _side, numChannels: 4);
  img.compositeImage(
    canvas,
    resized,
    dstX: (_side - resized.width) ~/ 2,
    dstY: (_side - resized.height) ~/ 2,
  );

  File(_output).writeAsBytesSync(img.encodePng(canvas));
  stdout.writeln(
    '$_output yazildi — icerik ${cropped.width}x${cropped.height} '
    '-> ${resized.width}x${resized.height} (${_side}x$_side tuval).',
  );

  _writeAndroidIcons(cropped);
}

/// Android launcher ikonlari.
///
/// Iki takim yaziliyor cunku Android iki ikon modelini de bekliyor:
///  * `ic_launcher` — API 25 ve oncesi icin duz kare ikon,
///  * `ic_launcher_foreground` — uyarlanir (adaptive) ikonun on plani. Sistem
///    bunu maskeliyor (daire, squircle, kare...) ve KENARLARDAN KIRPIYOR;
///    guvenli alan 108dp tuvalin ortadaki 72dp'si. Logo bu yuzden burada
///    daha kucuk oturtuluyor, aksi halde yuvarlak maskede kulaklari kesilir.
void _writeAndroidIcons(img.Image content) {
  const legacy = <String, int>{
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
  };
  // Uyarlanir on plan 108dp; ayni yogunluk carpanlari.
  const adaptive = <String, int>{
    'mdpi': 108,
    'hdpi': 162,
    'xhdpi': 216,
    'xxhdpi': 324,
    'xxxhdpi': 432,
  };

  for (final entry in legacy.entries) {
    _writeIcon(
      'android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png',
      content,
      entry.value,
      _fill,
    );
  }
  for (final entry in adaptive.entries) {
    // 72/108 = 0.667: guvenli alan. Uzerine biraz daha pay birakiliyor.
    _writeIcon(
      'android/app/src/main/res/mipmap-${entry.key}/ic_launcher_foreground.png',
      content,
      entry.value,
      0.60,
    );
  }
  stdout.writeln('Android mipmap ikonlari yazildi (5 yogunluk x 2 takim).');
}

/// [content]'i [side] piksellik saydam bir tuvale [fill] oraniyla oturtur.
void _writeIcon(String path, img.Image content, int side, double fill) {
  final target = (side * fill).round();
  final scale =
      target /
      (content.width > content.height ? content.width : content.height);
  final resized = img.copyResize(
    content,
    width: (content.width * scale).round().clamp(1, side),
    height: (content.height * scale).round().clamp(1, side),
    interpolation: img.Interpolation.cubic,
  );
  final canvas = img.Image(width: side, height: side, numChannels: 4);
  img.compositeImage(
    canvas,
    resized,
    dstX: (side - resized.width) ~/ 2,
    dstY: (side - resized.height) ~/ 2,
  );
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(img.encodePng(canvas));
}

typedef _Bounds = ({int left, int top, int width, int height});

/// Saydam olmayan piksellerin sinir kutusu.
_Bounds? _contentBounds(img.Image image) {
  var minX = image.width;
  var minY = image.height;
  var maxX = -1;
  var maxY = -1;

  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      if (image.getPixel(x, y).a == 0) continue;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }
  }

  if (maxX < 0) return null;
  return (
    left: minX,
    top: minY,
    width: maxX - minX + 1,
    height: maxY - minY + 1,
  );
}
