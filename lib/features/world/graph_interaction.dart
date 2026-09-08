import 'package:flutter/gestures.dart';

/// Dunya grafiginde tek bir isaretci hareketinin ne oldugu.
enum GraphGesture {
  /// Henuz karar verilmedi: parmak/fare basili ama esigi asmadi.
  pending,

  /// Bir dugum surukleniyor.
  dragNode,

  /// Tuval kaydiriliyor.
  panCanvas,
}

/// Bir basma-surukleme-birakma dizisinin durumu.
///
/// **Neden ayri ve saf bir sinif:** karar tek bir yerde ve test edilebilir
/// olmali. Widget icinde dagilmis haliyle iki hata birden vardi ve ikisi de
/// "dugumler baglanmiyor" olarak gorunuyordu:
///
///  1. Surukleme esigi ARDISIK IKI OLAY ARASINDAKI mesafeye bakiyordu, basma
///     noktasina degil. Dokunmatikte bir dokunus neredeyse her zaman tek bir
///     olayda 3 pikselden fazla titriyor; hareket "surukleme" sayilip
///     dokunus geri cagirimi hic calismiyordu. Baglama modunda dugume
///     dokunmak onu seçmek yerine yerinden oynatiyordu.
///  2. Birakmada "bu bir dokunus muydu" sorusu `e.localPosition` ile son
///     hareket konumunu karsilastiriyordu; ikisi ayni oldugu icin cevap HER
///     ZAMAN "evet"ti. Kaydirma sonrasi birakmak da dokunus sayiliyor ve
///     baglama modunda secili ilk dugumu sessizce temizliyordu.
///
/// Esik cihaza gore: fare hassastir (birkac piksel), parmak degildir
/// (`kTouchSlop`). Flutter'in kendi hesabini kullaniyoruz ki uygulama
/// platformun geri kalaniyla ayni his versin.
class GraphPointerSession {
  GraphPointerSession({
    required this.startScreen,
    required PointerDeviceKind kind,
    this.nodeId,
  }) : slop = computeHitSlop(kind, null);

  /// Isaretcinin BASTIGI ekran noktasi. Esik hep buna gore olculur.
  final Offset startScreen;

  /// Basilan dugum; null ise tuval.
  final String? nodeId;

  /// Bu cihazda "kaymis sayilmak" icin gereken piksel.
  final double slop;

  bool _movedBeyondSlop = false;

  /// Isaretci basma noktasindan yeterince uzaklasti mi?
  bool get moved => _movedBeyondSlop;

  /// Yeni bir konum bildirir; esik bir kez asildiginda geri donulmez
  /// (kullanici geri gelse bile hareket bir surukleme olarak baslamistir).
  void update(Offset screen) {
    if (_movedBeyondSlop) return;
    if ((screen - startScreen).distance > slop) _movedBeyondSlop = true;
  }

  /// Hareketin su anki yorumu.
  GraphGesture get gesture {
    if (!_movedBeyondSlop) return GraphGesture.pending;
    return nodeId == null ? GraphGesture.panCanvas : GraphGesture.dragNode;
  }

  /// Birakma bir DOKUNUS muydu? (Esik hic asilmadiysa evet.)
  bool get isTap => !_movedBeyondSlop;
}

/// Bir dugumun EKRANDA tiklanabilir yaricapi.
///
/// Dunya koordinatindaki yaricap yakinlastirma ile kuculuyor: uzaklasmis bir
/// grafikte 25 piksellik bir dugum ekranda 5 piksele dusuyor ve isabet
/// ettirmek neredeyse imkansiz oluyordu. Dokunma hedefi bu yuzden ekran
/// uzayinda bir TABANLA korunuyor -- erisilebilirlik kilavuzlarindaki 44
/// piksellik hedefin yarisi (yaricap), yani capi 44.
double graphHitRadius(double worldRadius, double scale) {
  final onScreen = worldRadius * scale;
  final effective = onScreen < minHitRadius ? minHitRadius : onScreen;
  // Cagiran taraf dunya koordinatinda karsilastiriyor; geri cevir.
  return effective / scale;
}

/// Ekranda en az bu yaricap kadar dokunma hedefi.
const double minHitRadius = 22;

/// Grafikte GORUNECEK dugum kimlikleri.
///
/// Iki ayri suzgec ust uste biniyor ve sirasi onemli:
///
///  * **Odak** ([focusId]) verilmisse yalnizca o dugum ve DOGRUDAN komsulari
///    kalir. Odaklanilan dugumun kendisi tur filtresinden MUAF: once bir
///    orgute odaklanip sonra "orgutleri gizle" demek bos ekran verirdi ve
///    geri donmenin yolu gorunmezdi.
///  * **Tur filtresi** ([visibleKinds]) geri kalanlara uygulanir.
///
/// Kenarlar `(aId, bId)` ciftleri olarak geliyor; bu fonksiyonun grafigin
/// cizim katmanindan haberi yok.
Set<String> visibleGraphNodes({
  required Map<String, String> kindOf,
  required Iterable<({String aId, String bId})> links,
  required Set<String> visibleKinds,
  String? focusId,
}) {
  Set<String>? neighbourhood;
  if (focusId != null && kindOf.containsKey(focusId)) {
    neighbourhood = {focusId};
    for (final link in links) {
      if (link.aId == focusId) neighbourhood.add(link.bId);
      if (link.bId == focusId) neighbourhood.add(link.aId);
    }
  }

  return {
    for (final entry in kindOf.entries)
      if (neighbourhood == null || neighbourhood.contains(entry.key))
        if (entry.key == focusId || visibleKinds.contains(entry.value))
          entry.key,
  };
}
