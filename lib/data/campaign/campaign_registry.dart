import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'campaign.dart';

/// Kampanya listesi + hangisinin açık olduğu.
///
/// `runApp`'ten ÖNCE okunur, bu yüzden [decode] **asla fırlatmaz**: bozuk ya
/// da eksik veri varsayılan kampanyaya düşer. Burada atılacak bir istisna
/// uygulamayı açılışta tuğlalaştırırdı.
class CampaignRegistry {
  const CampaignRegistry({required this.campaigns, required this.activeId});

  static const prefsList = 'campaigns.list';
  static const prefsActive = 'campaigns.active';

  static const _uuid = Uuid();

  final List<Campaign> campaigns;
  final String activeId;

  /// Açık kampanya. Liste her zaman en az bir kayıt içerir ve [activeId]
  /// her zaman var olan bir kaydı gösterir ([decode] bunu garanti eder).
  Campaign get active => campaigns.firstWhere(
    (c) => c.id == activeId,
    orElse: () => campaigns.first,
  );

  /// Silinmeyi bekleyen kampanyalar (dosya kilitliydi, sonraki açılışta
  /// temizlenecek). Listede görünmezler.
  List<Campaign> get visible => [
    for (final c in campaigns)
      if (!c.pendingDelete) c,
  ];

  static Campaign _seed() => Campaign(
    id: Campaign.defaultId,
    name: '',
    dbName: Campaign.defaultDbName,
    createdAt: DateTime.now(),
  );

  /// Prefs'teki ham metinleri çözer. Her hata yolunda varsayılana düşer.
  static CampaignRegistry decode(String? rawList, String? rawActive) {
    final parsed = <Campaign>[];
    try {
      final decoded = jsonDecode(rawList ?? '[]');
      if (decoded is List) {
        for (final entry in decoded) {
          if (entry is! Map) continue;
          final campaign = Campaign.fromJson(entry.cast<String, dynamic>());
          // Aynı dosyayı iki kayıt gösteremez.
          if (campaign == null ||
              parsed.any(
                (c) => c.id == campaign.id || c.dbName == campaign.dbName,
              )) {
            continue;
          }
          parsed.add(campaign);
        }
      }
    } on Object {
      // Bozuk JSON: liste boş kalır, aşağıda varsayılan tohumlanır.
    }

    if (parsed.where((c) => !c.pendingDelete).isEmpty) {
      parsed.add(_seed());
    }
    final live = [
      for (final c in parsed)
        if (!c.pendingDelete) c,
    ];
    final activeId = live.any((c) => c.id == rawActive)
        ? rawActive!
        : live.first.id;
    return CampaignRegistry(campaigns: parsed, activeId: activeId);
  }

  String encodeList() => jsonEncode([for (final c in campaigns) c.toJson()]);

  static Future<CampaignRegistry> load(SharedPreferences prefs) async =>
      decode(prefs.getString(prefsList), prefs.getString(prefsActive));

  Future<void> save(SharedPreferences prefs) async {
    await prefs.setString(prefsList, encodeList());
    await prefs.setString(prefsActive, activeId);
  }

  CampaignRegistry _copy({List<Campaign>? campaigns, String? activeId}) =>
      CampaignRegistry(
        campaigns: campaigns ?? this.campaigns,
        activeId: activeId ?? this.activeId,
      );

  /// Yeni kampanya kaydı üretir (dosya henüz açılmaz; ilk açılışta drift
  /// oluşturur ve SRD kütüphanesi oraya içe aktarılır).
  (CampaignRegistry, Campaign) created(String name) {
    final id = _uuid.v4().substring(0, 8);
    final campaign = Campaign(
      id: id,
      name: name,
      dbName: '${Campaign.defaultDbName}_$id',
      createdAt: DateTime.now(),
    );
    return (_copy(campaigns: [...campaigns, campaign]), campaign);
  }

  CampaignRegistry renamed(String id, String name) => _copy(
    campaigns: [
      for (final c in campaigns) c.id == id ? c.copyWith(name: name) : c,
    ],
  );

  CampaignRegistry opened(String id) => _copy(
    campaigns: [
      for (final c in campaigns)
        c.id == id ? c.copyWith(lastOpenedAt: DateTime.now()) : c,
    ],
    activeId: id,
  );

  /// Kaydı tamamen kaldırır (dosya silme başarılı olduğunda).
  CampaignRegistry removed(String id) => _copy(
    campaigns: [
      for (final c in campaigns)
        if (c.id != id) c,
    ],
  );

  /// Dosya kilitli kaldıysa: kayıt listede kalır ama gizlenir, bir sonraki
  /// açılışta silinmeye çalışılır.
  CampaignRegistry markedForDelete(String id) => _copy(
    campaigns: [
      for (final c in campaigns)
        c.id == id ? c.copyWith(pendingDelete: true) : c,
    ],
  );
}
