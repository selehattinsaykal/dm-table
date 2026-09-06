/// Taverna AI üreteci ayarları (opt-in, "kendi anahtarını getir").
///
/// Anahtar YALNIZCA cihazda `shared_preferences` ile saklanır; kaynağa gömülü
/// hiçbir anahtar yoktur; yalnızca DM cihazı kendi anahtarıyla çağrı yapar.
library;

/// Desteklenen sağlayıcılar. Her biri kendi API biçimi + varsayılan modeli.
enum AiProvider {
  gemini(
    'gemini',
    'Google Gemini',
    'gemini-2.0-flash',
    defaultImageModel: 'gemini-2.5-flash-image',
  ),
  openai('openai', 'OpenAI', 'gpt-4o-mini', defaultImageModel: 'gpt-image-1'),
  // Anthropic'in görsel ÜRETME API'si yok (görsel okuyabilir, üretemez);
  // bu yüzden portre üretimi Claude seçiliyken kapalıdır.
  anthropic('anthropic', 'Anthropic (Claude)', 'claude-opus-5');

  const AiProvider(
    this.code,
    this.label,
    this.defaultModel, {
    this.defaultImageModel,
  });

  final String code;
  final String label;
  final String defaultModel;

  /// Portre üretiminde kullanılacak varsayılan görsel modeli; `null` ise bu
  /// sağlayıcı görsel üretmez.
  final String? defaultImageModel;

  /// Bu sağlayıcıyla NPC portresi üretilebilir mi?
  bool get supportsImages => defaultImageModel != null;

  static AiProvider fromCode(String? code) => AiProvider.values.firstWhere(
    (p) => p.code == code,
    orElse: () => AiProvider.gemini,
  );
}

/// Cihaza yerel AI yapılandırması. [apiKey] boşsa AI özellikleri kapalıdır.
class AiSettings {
  const AiSettings({
    this.provider = AiProvider.gemini,
    this.apiKey = '',
    this.model = '',
    this.imageModel = '',
  });

  final AiProvider provider;
  final String apiKey;

  /// Boşsa sağlayıcının varsayılan modeli kullanılır.
  final String model;

  /// NPC portresi üretiminde kullanılacak görsel modeli. Boşsa sağlayıcının
  /// varsayılanı kullanılır. Ayrı bir alan olmasının nedeni: görsel modelleri
  /// metin modellerinden bağımsız ve daha hızlı değişiyor — model adı
  /// eskidiğinde kullanıcı kaynağı düzenlemeden buradan güncelleyebilmeli.
  final String imageModel;

  /// Anahtar girilmişse AI kullanılabilir.
  bool get enabled => apiKey.trim().isNotEmpty;

  /// Kullanılacak model (kullanıcı boş bıraktıysa varsayılan).
  String get effectiveModel =>
      model.trim().isEmpty ? provider.defaultModel : model.trim();

  /// Portre üretiminde kullanılacak model; sağlayıcı görsel üretiyorsa `null`.
  ///
  /// Sağlayıcı desteği kullanıcının yazdığı model adını EZER: eksik olan şey
  /// model adı değil, sağlayıcının görsel üretim uç noktası. Claude seçiliyken
  /// alana bir model adı yazmak portre üretimini çalışır hale getirmez.
  String? get effectiveImageModel {
    if (!provider.supportsImages) return null;
    return imageModel.trim().isNotEmpty
        ? imageModel.trim()
        : provider.defaultImageModel;
  }

  /// Portre üretimi şu an mümkün mü (anahtar var + sağlayıcı görsel üretiyor).
  bool get canGenerateImages => enabled && effectiveImageModel != null;

  AiSettings copyWith({
    AiProvider? provider,
    String? apiKey,
    String? model,
    String? imageModel,
  }) => AiSettings(
    provider: provider ?? this.provider,
    apiKey: apiKey ?? this.apiKey,
    model: model ?? this.model,
    imageModel: imageModel ?? this.imageModel,
  );
}
