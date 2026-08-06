import 'package:dm_table/domain/ai/ai_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('anahtar bossa devre disi', () {
    expect(const AiSettings().enabled, isFalse);
    expect(const AiSettings(apiKey: '  ').enabled, isFalse);
    expect(const AiSettings(apiKey: 'sk-x').enabled, isTrue);
  });

  test('model bossa saglayicinin varsayilani kullanilir', () {
    expect(
      const AiSettings(provider: AiProvider.gemini).effectiveModel,
      AiProvider.gemini.defaultModel,
    );
    expect(
      const AiSettings(
        provider: AiProvider.openai,
        model: 'gpt-x',
      ).effectiveModel,
      'gpt-x',
    );
  });

  test('fromCode bilinmeyende gemini doner', () {
    expect(AiProvider.fromCode('anthropic'), AiProvider.anthropic);
    expect(AiProvider.fromCode('yok'), AiProvider.gemini);
    expect(AiProvider.fromCode(null), AiProvider.gemini);
  });

  test(
    'gorsel modeli: bossa saglayici varsayilani, doluysa kullanicininki',
    () {
      expect(
        const AiSettings(provider: AiProvider.gemini).effectiveImageModel,
        AiProvider.gemini.defaultImageModel,
      );
      expect(
        const AiSettings(
          provider: AiProvider.openai,
          imageModel: 'yeni-model',
        ).effectiveImageModel,
        'yeni-model',
      );
    },
  );

  test('gorsel uretmeyen saglayicida model yazmak da acmaz', () {
    expect(AiProvider.anthropic.supportsImages, isFalse);
    expect(
      const AiSettings(
        provider: AiProvider.anthropic,
        apiKey: 'K',
        imageModel: 'her-neyse',
      ).effectiveImageModel,
      isNull,
    );
  });

  test('canGenerateImages hem anahtar hem saglayici destegi ister', () {
    // Anahtar yok.
    expect(
      const AiSettings(provider: AiProvider.gemini).canGenerateImages,
      isFalse,
    );
    // Saglayici gorsel uretmiyor.
    expect(
      const AiSettings(
        provider: AiProvider.anthropic,
        apiKey: 'K',
      ).canGenerateImages,
      isFalse,
    );
    // Ikisi de var.
    expect(
      const AiSettings(
        provider: AiProvider.gemini,
        apiKey: 'K',
      ).canGenerateImages,
      isTrue,
    );
  });

  test('copyWith gorsel modelini korur', () {
    const base = AiSettings(apiKey: 'K', imageModel: 'im');
    expect(base.copyWith(model: 'm').imageModel, 'im');
    expect(base.copyWith(imageModel: '').imageModel, isEmpty);
  });
}
