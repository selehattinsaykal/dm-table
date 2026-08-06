import 'package:path/path.dart' as p;

/// Bir kampanya = kendi SQLite dosyası.
///
/// Uygulamada tek seferde tek kampanya açıktır: karakterler, dünya, görevler,
/// kayıtlar, takvim — hepsi o dosyanın içinde yaşar. Kampanya değiştirmek
/// veritabanını değiştirmek demektir (bkz. `CampaignRoot`, `lib/main.dart`).
///
/// Kayıt listesi veritabanında DEĞİL `shared_preferences`'ta durur: hangi
/// veritabanının açılacağını bilmek için önce bir veritabanı açmak gerekirdi.
class Campaign {
  const Campaign({
    required this.id,
    required this.name,
    required this.dbName,
    required this.createdAt,
    this.lastOpenedAt,
    this.pendingDelete = false,
  });

  /// Güncellemeden önceki tek veritabanı bu kimlikle devralınır; kullanıcının
  /// mevcut verisi olduğu yerde kalır, hiçbir dosya taşınmaz.
  static const defaultId = 'default';

  /// DİKKAT: uygulama `dm_table` olarak yeniden adlandırıldıktan sonra da bu
  /// eski ad korunuyor — `<Belgeler>/dm_masasi.sqlite` mevcut kurulumlardaki
  /// gerçek dosya adı. Değiştirmek eski kampanyaları erişilemez kılar.
  static const defaultDbName = 'dm_masasi';

  final String id;
  final String name;

  /// Uzantısız dosya adı: `<Belgeler>/<dbName>.sqlite`.
  final String dbName;

  final DateTime createdAt;
  final DateTime? lastOpenedAt;

  /// Silinmek istendi ama dosya kilitliydi (Windows). Bir sonraki açılışta,
  /// hiçbir veritabanı açılmadan önce temizlenir.
  final bool pendingDelete;

  bool get isDefault => id == defaultId;

  /// Medya (harita/portre/video) klasörünün uygulama klasörüne göre öneki.
  ///
  /// Varsayılan kampanya `null` döner: dosyaları güncellemeden önce olduğu
  /// gibi `maps/`, `portraits/`, `codex_media/` altında kalır. Yeni
  /// kampanyalar `campaigns/<id>/` altına yazar, böylece kampanya silinince
  /// medyası da birlikte gider (yetim dosya kalmaz).
  String? get mediaPrefix => isDefault ? null : p.join('campaigns', id);

  Campaign copyWith({
    String? name,
    DateTime? lastOpenedAt,
    bool? pendingDelete,
  }) => Campaign(
    id: id,
    name: name ?? this.name,
    dbName: dbName,
    createdAt: createdAt,
    lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
    pendingDelete: pendingDelete ?? this.pendingDelete,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'dbName': dbName,
    'createdAt': createdAt.toIso8601String(),
    if (lastOpenedAt != null) 'lastOpenedAt': lastOpenedAt!.toIso8601String(),
    if (pendingDelete) 'pendingDelete': true,
  };

  /// Eksik/bozuk alanlara dayanıklı: kimlik ya da dosya adı yoksa `null`
  /// döner, çağıran o kaydı atlar (bkz. [CampaignRegistry.decode]).
  static Campaign? fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final dbName = json['dbName'] as String?;
    if (id == null || id.isEmpty || dbName == null || dbName.isEmpty) {
      return null;
    }
    return Campaign(
      id: id,
      // Ad bilincli olarak bos kalabilir: varsayilan kampanyanin adi
      // arayuzde L10n'dan gelir (kayit katmani dile bagimli degil).
      name: json['name'] as String? ?? '',
      dbName: dbName,
      createdAt: DateTime.tryParse('${json['createdAt']}') ?? DateTime(2026),
      lastOpenedAt: DateTime.tryParse('${json['lastOpenedAt']}'),
      pendingDelete: json['pendingDelete'] as bool? ?? false,
    );
  }
}
