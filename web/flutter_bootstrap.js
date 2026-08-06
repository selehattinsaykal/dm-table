// Ozel onyukleme: oyuncu paneli yalnizca CanvasKit renderer'ini kullansin.
//
// Neden: Flutter web "auto" modda modern tarayicida Skwasm'i secip skwasm*.wasm
// indiriyordu; bu da pakete ~12 MB skwasm cesidi ekliyordu. CanvasKit TUM
// tarayicilarda (iOS Safari dahil) calisan evrensel renderer'dir. Sabitleyince
// skwasm hic istenmiyor, `tools/build_player_web.dart` o dosyalari buduyor ve
// panel paketi kuculuyor. (Bu dosya yalnizca web derlemesini etkiler; DM
// masaustu/Android uygulamasi web derlenmedigi icin etkilenmez.)
{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    renderer: "canvaskit",
  },
});
