import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/ai/ai_settings.dart';

/// AI ayarlarını `shared_preferences` ile okur/yazar. Anahtar yalnızca cihazda
/// kalır; LAN senkronuna veya yedeğe DAHİL EDİLMEZ.
class AiSettingsController extends Notifier<AiSettings> {
  static const _kProvider = 'ai.provider';
  static const _kApiKey = 'ai.apiKey';
  static const _kModel = 'ai.model';
  static const _kImageModel = 'ai.imageModel';

  /// Kullanıcı bu oturumda bir ayar değiştirdi mi? Asenkron [_load] tamamlanana
  /// kadar kullanıcı bir şey kaydederse, [_load]'un kalıcı (belki eski/boş)
  /// değerlerle üzerine yazmasını engeller.
  bool _touched = false;

  @override
  AiSettings build() {
    _load();
    return const AiSettings();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (_touched) return; // kullanıcı bu arada değiştirdi; üzerine yazma
    state = AiSettings(
      provider: AiProvider.fromCode(prefs.getString(_kProvider)),
      apiKey: prefs.getString(_kApiKey) ?? '',
      model: prefs.getString(_kModel) ?? '',
      imageModel: prefs.getString(_kImageModel) ?? '',
    );
  }

  Future<void> setProvider(AiProvider provider) async {
    _touched = true;
    state = state.copyWith(provider: provider);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kProvider, provider.code);
  }

  Future<void> setApiKey(String key) async {
    _touched = true;
    state = state.copyWith(apiKey: key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kApiKey, key);
  }

  Future<void> setModel(String model) async {
    _touched = true;
    state = state.copyWith(model: model);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kModel, model);
  }

  /// Anahtar + modeli TEK state güncellemesinde kaydeder. Ayrı ayrı
  /// setApiKey/setModel çağrılırsa aradaki ara-durum (anahtar yeni, model hâlâ
  /// eski) dinleyicileri tetikleyip model alanını eski değere geri yazabiliyor;
  /// atomik kayıt bunu önler.
  Future<void> save({
    required String apiKey,
    required String model,
    String imageModel = '',
  }) async {
    _touched = true;
    state = state.copyWith(
      apiKey: apiKey,
      model: model,
      imageModel: imageModel,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kApiKey, apiKey);
    await prefs.setString(_kModel, model);
    await prefs.setString(_kImageModel, imageModel);
  }
}

final aiSettingsProvider = NotifierProvider<AiSettingsController, AiSettings>(
  AiSettingsController.new,
);
