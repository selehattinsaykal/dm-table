import 'db/database.dart';
import 'db/world_tables.dart';
import 'shop_repository.dart';
import 'world_repository.dart';

/// Bir harita pininin OYUNCULARA gorunup gorunmedigi — tek kural.
///
/// Hem sunucu (oyuncuya ne gonderilecek, bkz. `SessionService`) hem DM arayuzu
/// (pin nasil cizilir, "Oyunculara goster" anahtari neyi yazar) buradan okur.
///
/// Neden tek yerde: iki taraf ayri ayri yazilmisti ve birbirinden kaymislardi.
/// DM haritada bir YER pinini "gosterdi" saniyordu, ama sunucu pinin kendi
/// [MapPin.revealed] bayragina hic bakmiyor — hedef lokasyonun acik olup
/// olmadigina bakiyor. Sonuc: dugum grafiginde "oyunculara goster" denen bir
/// yer haritada hala gizli gorunuyor, haritadaki anahtar ise hicbir sey
/// yapmiyordu.
///
/// Kural pin turune gore degisir:
///  * YER ve DUKKAN pinleri **aksiyonlu**: hedefi erisilebilir degilse oyuncuya
///    hic cizilmez, erisilebilir olunca kendiliginden cikar. Pinin kendi
///    bayragi kullanilmaz — kapali bir yerin kapisini gostermek anlamsiz.
///  * **Bilgilendirici** pinler (not, NPC, karsilasma, hazine) pinin kendi
///    [MapPin.revealed] bayragina bakar.
bool pinVisibleToPlayers(
  MapPin pin, {

  /// Oyuncunun girebildigi lokasyon id'leri (acik + haritali + ust zinciri
  /// de acik).
  required Set<String> accessibleLocations,

  /// Haritadan erisilebilir dukkan id'leri.
  required Set<String> accessibleShops,
}) => switch (pin.kind) {
  PinKind.location =>
    pin.targetId != null && accessibleLocations.contains(pin.targetId),
  PinKind.shop =>
    pin.targetId != null && accessibleShops.contains(pin.targetId),
  // Haritasiz yer BILGILENDIRICI sayilir: "erisilebilir lokasyon" kurali ona
  // uygulanamaz, cunku erisilebilirlik haritasi olmayi sart kosuyor -- oyle
  // olsa bu pin oyuncuya HIC gorunmezdi.
  PinKind.place ||
  PinKind.note ||
  PinKind.npc ||
  PinKind.encounter ||
  PinKind.treasure => pin.revealed,
};

/// [pinVisibleToPlayers]'in YAZMA tarafi: DM "Oyunculara goster"i cevirince
/// hangi kaydin degismesi gerektigi.
///
/// Okuma kuraliyla ayni ayrimi izlemek zorunda, yoksa anahtar yalan soyler:
/// yer pininde HEDEF LOKASYON acilir/kapanir (dugum grafigindeki menuyle
/// birebir ayni islem), dukkan pininde dukkanin harita erisimi, digerlerinde
/// pinin kendi bayragi.
///
/// [pinId] yalnizca bilgilendirici pinler icin gerekir; yer/dukkan pinlerinde
/// hedef kayit degistigi icin pinin kendisi henuz olusmamis olabilir (yeni pin
/// olusturulurken de cagrilir).
Future<void> setPinPlayerVisibility({
  required PinKind kind,
  required String? targetId,
  required bool visible,
  required WorldRepository world,
  required ShopRepository shops,
  String? pinId,
}) async {
  switch (kind) {
    case PinKind.location:
      // `setRevealed` yeri acarken uzerindeki pinleri de acar; kapatirken
      // pinlere dokunmaz (bkz. WorldRepository).
      if (targetId != null) await world.setRevealed(targetId, visible);
    case PinKind.shop:
      if (targetId != null) {
        await shops.update(targetId, mapAccessible: visible);
      }
    case PinKind.place:
      // IKISI birden: pinin kendi bayragi haritada gorunmesini, bagli
      // lokasyonun bayragi ise seyahat/gorev gibi yer listelerinde
      // gozukmesini saglar. Yalnizca biri yazilsaydi "oyunculara goster"
      // yarim kalirdi.
      if (pinId != null) await world.updatePin(pinId, revealed: visible);
      if (targetId != null) await world.setRevealed(targetId, visible);
    case PinKind.note:
    case PinKind.npc:
    case PinKind.encounter:
    case PinKind.treasure:
      if (pinId != null) await world.updatePin(pinId, revealed: visible);
  }
}
