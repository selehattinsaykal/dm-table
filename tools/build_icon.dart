// Ikon kaynagini uretir: `assets/logo/logo.png` -> `assets/logo/logo_icon.png`.
//
// **Neden var:** kaynak logonun 1024'luk tuvalinde genis bir bos kenar payi
// var (icerik yalnizca 614x778). Bu dosya dogrudan ikona cevrilince logo
// gorev cubugunda/sekmede oldugundan kucuk goruunuyordu. Burasi logoyu
// ICERIGINE KIRPIP kare tuvalin [_fill] oranina oturtur; sonucu
// `flutter_launcher_icons` kullanir (bkz. pubspec.yaml).
//
// Kullanim (logo degistiginde):
//   dart run tools/build_icon.dart
//   dart run flutter_launcher_icons
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
