import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Sayfayi tam ekrana alir ve mumkunse yatay yone kilitler.
///
/// Hepsi en iyi caba: `requestFullscreen` ve `orientation.lock` bazi
/// tarayicilarda (or. iOS Safari) desteklenmez ya da reddedilir; bu durumda
/// tam ekran sayfasi yine viewport'u doldurur, kullanici telefonu elle cevirir.
void enterFullscreenLandscape() {
  final el = web.document.documentElement;
  if (el != null) {
    try {
      el.requestFullscreen();
    } catch (_) {}
  }
  try {
    final orientation = (web.window.screen as JSObject).getProperty<JSObject?>(
      'orientation'.toJS,
    );
    // lock() deneysel; JS interop ile guvenli cagriliyor. Donen Promise
    // reddedilirse (desteklenmeyen tarayici) sessizce yok sayilir.
    orientation?.callMethod('lock'.toJS, 'landscape'.toJS);
  } catch (_) {}
}

/// Tam ekrandan cikar ve yon kilidini birakir.
void exitFullscreen() {
  try {
    web.document.exitFullscreen();
  } catch (_) {}
  try {
    (web.window.screen as JSObject)
        .getProperty<JSObject?>('orientation'.toJS)
        ?.callMethod('unlock'.toJS);
  } catch (_) {}
}
