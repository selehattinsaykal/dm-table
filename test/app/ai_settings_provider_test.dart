import 'package:dm_table/app/ai_settings_provider.dart';
import 'package:dm_table/domain/ai/ai_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AI ayarları cihazda kalıcı (oturumlar/uygulama açılışları arası).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('kaydedilen anahtar/sağlayıcı/model prefs\'e yazılır', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final c = container.read(aiSettingsProvider.notifier);
    await c.setApiKey('sk-new');
    await c.setProvider(AiProvider.openai);
    await c.setModel('gpt-x');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ai.apiKey'), 'sk-new');
    expect(prefs.getString('ai.provider'), 'openai');
    expect(prefs.getString('ai.model'), 'gpt-x');
  });

  test('save anahtar + modeli tek çağrıda birlikte yazar', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final c = container.read(aiSettingsProvider.notifier);
    await c.save(apiKey: 'sk-both', model: 'gpt-x');

    // Tek atomik state: anahtar ile model hiçbir ara-durumda ayrışmaz.
    final s = container.read(aiSettingsProvider);
    expect(s.apiKey, 'sk-both');
    expect(s.model, 'gpt-x');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ai.apiKey'), 'sk-both');
    expect(prefs.getString('ai.model'), 'gpt-x');
  });

  test('yeni açılışta (yeni container) kayıtlı değer yüklenir', () async {
    // Önceki oturumdan kalmış gibi.
    SharedPreferences.setMockInitialValues({
      'ai.provider': 'anthropic',
      'ai.apiKey': 'sk-persisted',
      'ai.model': 'claude-haiku-4-5',
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // build() önce senkron varsayılan döner; _load asenkron doldurur.
    for (
      var i = 0;
      i < 100 && container.read(aiSettingsProvider).apiKey.isEmpty;
      i++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }

    final s = container.read(aiSettingsProvider);
    expect(s.apiKey, 'sk-persisted');
    expect(s.provider, AiProvider.anthropic);
    expect(s.model, 'claude-haiku-4-5');
    expect(s.enabled, isTrue);
    expect(s.effectiveModel, 'claude-haiku-4-5');
  });
}
