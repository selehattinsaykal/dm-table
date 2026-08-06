// Tam ekran + yatay yonlendirme icin platforma gore secilen uygulama.
//
// Oyuncu paneli web'e derleniyor; ama `player_app.dart` widget testlerinde
// VM'de de derlenebildigi icin web API'lerini dogrudan import etmiyoruz.
// `dart.library.js_interop` varsa gercek web uygulamasi, yoksa no-op stub
// devreye girer.
export 'web_fullscreen_stub.dart'
    if (dart.library.js_interop) 'web_fullscreen_web.dart';
