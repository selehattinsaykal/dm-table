import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'campaign.dart';
import 'campaign_paths.dart';
import 'campaign_registry.dart';

/// Kampanya listesini yöneten nesne. `ProviderScope`'un ÜSTÜNDE yaşar
/// (`CampaignRoot`, `lib/main.dart`) çünkü kampanya değiştirmek scope'un
/// kendisini yeniden kurmak demektir.
///
/// [ChangeNotifier] olması bilinçli: liste değişince (oluştur/adlandır/sil)
/// arayüz güncellenmeli, ama bu değişiklikler scope'u yeniden kurmaz —
/// yalnızca [open] kurar.
class CampaignManager extends ChangeNotifier {
  CampaignManager({
    required SharedPreferences prefs,
    required CampaignRegistry registry,
    required Future<void> Function(Campaign) onOpen,
  }) : _prefs = prefs,
       _registry = registry,
       _onOpen = onOpen;

  final SharedPreferences _prefs;
  final Future<void> Function(Campaign) _onOpen;
  CampaignRegistry _registry;

  CampaignRegistry get registry => _registry;
  Campaign get active => _registry.active;
  List<Campaign> get campaigns => _registry.visible;

  Future<void> _commit(CampaignRegistry next) async {
    _registry = next;
    await next.save(_prefs);
    notifyListeners();
  }

  /// Yeni kampanya kaydı açar ve ona geçer. Veritabanı dosyası ilk açılışta
  /// drift tarafından oluşturulur, SRD kütüphanesi oraya içe aktarılır.
  Future<Campaign> create(String name) async {
    final (next, campaign) = _registry.created(name);
    await _commit(next);
    await open(campaign.id);
    return campaign;
  }

  /// Kampanya kaydını **açmadan** oluşturur.
  ///
  /// Yedekten kampanya kurarken şart: [create] açtığı anda `CampaignRoot`
  /// `ProviderScope`'u yıkıp yeniden kuruyor ve çağıran widget (yedeği yazacak
  /// olan) o sırada dispose ediliyor. Kayıt önce açılmadan oluşturulur, veri
  /// doğrudan yeni kampanyanın dosyasına yazılır, kampanyaya geçmek
  /// kullanıcının ayrı kararı olur.
  Future<Campaign> createWithoutOpening(String name) async {
    final (next, campaign) = _registry.created(name);
    await _commit(next);
    return campaign;
  }

  Future<void> rename(String id, String name) =>
      _commit(_registry.renamed(id, name));

  /// Kampanyayı açar: `CampaignRoot` oturumu kapatıp scope'u yeniden kurar.
  Future<void> open(String id) async {
    if (id == _registry.activeId) return;
    await _commit(_registry.opened(id));
    await _onOpen(_registry.active);
  }

  /// Kampanyayı ve dosyalarını siler.
  ///
  /// Açık kampanya silinemez (veritabanı kullanımda) ve son kampanya
  /// silinemez. Dosya kilitliyse (Windows'ta sqlite arka plan isolate'i
  /// tutabilir) kayıt "silinmeyi bekliyor" işaretlenir ve bir sonraki
  /// açılışta, hiçbir veritabanı açılmadan önce temizlenir.
  Future<bool> delete(String id) async {
    if (id == _registry.activeId || _registry.visible.length <= 1) return false;
    final campaign = _registry.campaigns.where((c) => c.id == id).firstOrNull;
    if (campaign == null) return false;

    final deleted = await deleteFiles(campaign);
    await _commit(
      deleted ? _registry.removed(id) : _registry.markedForDelete(id),
    );
    return deleted;
  }

  /// Kampanyanın veritabanı + medya dosyalarını siler. Kilit yüzünden
  /// başarısız olursa `false` döner.
  ///
  /// Windows'ta `close()` sonrası sqlite handle'ı bir süre daha açık
  /// kalabildiği için artan aralıklarla üç kez denenir.
  static Future<bool> deleteFiles(Campaign campaign) async {
    const backoff = [
      Duration(milliseconds: 100),
      Duration(milliseconds: 300),
      Duration(milliseconds: 600),
    ];
    for (var attempt = 0; attempt < backoff.length; attempt++) {
      try {
        for (final file in await CampaignPaths.databaseFiles(campaign.dbName)) {
          if (file.existsSync()) await file.delete();
        }
        // Medyası yalnız kampanyaya aitse (varsayilan kampanya uygulama
        // klasorunun kokunu paylasir, orayi ASLA silmeyiz).
        if (campaign.mediaPrefix != null) {
          final dir = await CampaignPaths.mediaRoot(campaign);
          if (dir.existsSync()) await dir.delete(recursive: true);
        }
        return true;
      } on FileSystemException {
        await Future<void>.delayed(backoff[attempt]);
      }
    }
    return false;
  }

  /// Açılışta, hiçbir veritabanı açılmadan önce çağrılır: önceki oturumda
  /// kilit yüzünden silinemeyen kampanyaları temizler.
  static Future<CampaignRegistry> purgePending(
    SharedPreferences prefs,
    CampaignRegistry registry,
  ) async {
    var next = registry;
    for (final campaign in registry.campaigns.where((c) => c.pendingDelete)) {
      if (await deleteFiles(campaign)) next = next.removed(campaign.id);
    }
    if (!identical(next, registry)) await next.save(prefs);
    return next;
  }
}

/// `CampaignRoot` tarafından override edilir; scope içinden kampanya
/// yönetimine erişmenin tek yolu.
///
/// Bilinçli olarak nullable: widget testleri kabuğu kampanya altyapısı
/// kurmadan pump ediyor. Yöneticiye bağlı arayüz (ray armasındaki kampanya
/// adı) yoksa sessizce düşer, testler kampanya kurulumunu bilmek zorunda
/// kalmaz.
final campaignManagerProvider = Provider<CampaignManager?>((ref) => null);
