import 'dart:convert';

import 'package:dm_table/data/ai/ai_service.dart';
import 'package:dm_table/domain/ai/ai_settings.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';

// Gercek API'ler charset=utf-8 gonderir; sahte yanitta da belirtmezsek
// http varsayilan latin1 ile kodlayip Turkce karakterlerde patlar.
http.Response _ok(Map<String, dynamic> body) => http.Response(
  jsonEncode(body),
  200,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  test('anahtar yoksa AiException(no-key)', () async {
    final service = AiService(const AiSettings());
    expect(
      () => service.generate(systemPrompt: 's', userPrompt: 'u'),
      throwsA(isA<AiException>().having((e) => e.message, 'msg', 'no-key')),
    );
  });

  test('Gemini: dogru URL + govde, yaniti cozer', () async {
    late http.Request captured;
    final client = MockClient((req) async {
      captured = req;
      return _ok({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'Han sahibi Borin '},
                {'text': 've ejderha.'},
              ],
            },
          },
        ],
      });
    });
    final service = AiService(
      const AiSettings(provider: AiProvider.gemini, apiKey: 'K'),
      client: client,
    );
    final out = await service.generate(systemPrompt: 'sys', userPrompt: 'usr');
    expect(out, 'Han sahibi Borin ve ejderha.');
    expect(captured.url.host, 'generativelanguage.googleapis.com');
    expect(captured.url.query, contains('key=K'));
    expect(captured.url.path, contains('gemini-2.0-flash:generateContent'));
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['system_instruction']['parts'][0]['text'], 'sys');
    expect(body['contents'][0]['parts'][0]['text'], 'usr');
  });

  test('OpenAI: Bearer header + chat/completions, yaniti cozer', () async {
    late http.Request captured;
    final client = MockClient((req) async {
      captured = req;
      return _ok({
        'choices': [
          {
            'message': {'content': 'Görev: kayıp yüzük.'},
          },
        ],
      });
    });
    final service = AiService(
      const AiSettings(provider: AiProvider.openai, apiKey: 'sk-1'),
      client: client,
    );
    final out = await service.generate(systemPrompt: 'sys', userPrompt: 'usr');
    expect(out, 'Görev: kayıp yüzük.');
    expect(
      captured.url.toString(),
      'https://api.openai.com/v1/chat/completions',
    );
    expect(captured.headers['authorization'], 'Bearer sk-1');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['model'], 'gpt-4o-mini');
    expect(body['messages'][0], {'role': 'system', 'content': 'sys'});
    expect(body['messages'][1], {'role': 'user', 'content': 'usr'});
  });

  test(
    'Anthropic: x-api-key + version header, content[].text birlestirir',
    () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return _ok({
          'stop_reason': 'end_turn',
          'content': [
            {'type': 'text', 'text': 'Söylenti: '},
            {'type': 'text', 'text': 'kuyuda ışık var.'},
          ],
        });
      });
      final service = AiService(
        const AiSettings(provider: AiProvider.anthropic, apiKey: 'ak'),
        client: client,
      );
      final out = await service.generate(
        systemPrompt: 'sys',
        userPrompt: 'usr',
      );
      expect(out, 'Söylenti: kuyuda ışık var.');
      expect(captured.url.toString(), 'https://api.anthropic.com/v1/messages');
      expect(captured.headers['x-api-key'], 'ak');
      expect(captured.headers['anthropic-version'], '2023-06-01');
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['model'], 'claude-opus-5');
      expect(body['system'], 'sys');
    },
  );

  test('Anthropic refusal → AiException(refused)', () async {
    final client = MockClient(
      (req) async => http.Response(
        jsonEncode({'stop_reason': 'refusal', 'content': <dynamic>[]}),
        200,
      ),
    );
    final service = AiService(
      const AiSettings(provider: AiProvider.anthropic, apiKey: 'ak'),
      client: client,
    );
    expect(
      () => service.generate(systemPrompt: 's', userPrompt: 'u'),
      throwsA(isA<AiException>().having((e) => e.message, 'msg', 'refused')),
    );
  });

  test('401 → auth, 429 → rate', () async {
    final auth = AiService(
      const AiSettings(provider: AiProvider.openai, apiKey: 'x'),
      client: MockClient((_) async => http.Response('no', 401)),
    );
    await expectLater(
      auth.generate(systemPrompt: 's', userPrompt: 'u'),
      throwsA(isA<AiException>().having((e) => e.message, 'm', 'auth')),
    );
    final rate = AiService(
      const AiSettings(provider: AiProvider.openai, apiKey: 'x'),
      client: MockClient((_) async => http.Response('no', 429)),
    );
    await expectLater(
      rate.generate(systemPrompt: 's', userPrompt: 'u'),
      throwsA(isA<AiException>().having((e) => e.message, 'm', 'rate')),
    );
  });

  // --- Gorsel uretimi (NPC portresi) --------------------------------------

  group('generateImage', () {
    // 1x1 PNG — gercek baytlar; base64 cozumunun dogrulugu de sinanmis olur.
    const pngB64 =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

    test('anahtar yoksa no-key', () {
      expect(
        () => AiService(const AiSettings()).generateImage(prompt: 'p'),
        throwsA(isA<AiException>().having((e) => e.message, 'msg', 'no-key')),
      );
    });

    test('Anthropic gorsel uretmez -> no-image', () {
      final service = AiService(
        const AiSettings(provider: AiProvider.anthropic, apiKey: 'K'),
      );
      expect(
        () => service.generateImage(prompt: 'p'),
        throwsA(isA<AiException>().having((e) => e.message, 'msg', 'no-image')),
      );
    });

    test('Anthropic secilliyken elle model yazmak da acmaz', () {
      // Eksik olan model adi degil, saglayicinin ucu; kullanici alana bir sey
      // yazarak bunu asamamali.
      const settings = AiSettings(
        provider: AiProvider.anthropic,
        apiKey: 'K',
        imageModel: 'her-neyse',
      );
      expect(settings.effectiveImageModel, isNull);
      expect(settings.canGenerateImages, isFalse);
    });

    test(
      'Gemini: inlineData baytlari cozulur, metin parcalari atlanir',
      () async {
        late http.Request captured;
        final client = MockClient((req) async {
          captured = req;
          return _ok({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'Iste portre:'},
                    {
                      'inlineData': {'mimeType': 'image/png', 'data': pngB64},
                    },
                  ],
                },
              },
            ],
          });
        });
        final bytes = await AiService(
          const AiSettings(provider: AiProvider.gemini, apiKey: 'K'),
          client: client,
        ).generateImage(prompt: 'bir cuce demirci');

        expect(bytes, base64Decode(pngB64));
        expect(captured.url.path, contains('gemini-2.5-flash-image'));
        final body = jsonDecode(captured.body) as Map<String, dynamic>;
        expect(
          body['generationConfig']['responseModalities'],
          containsAll(<String>['TEXT', 'IMAGE']),
        );
      },
    );

    test('Gemini: snake_case inline_data da kabul edilir', () async {
      final client = MockClient(
        (_) async => _ok({
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'inline_data': {'data': pngB64},
                  },
                ],
              },
            },
          ],
        }),
      );
      final bytes = await AiService(
        const AiSettings(provider: AiProvider.gemini, apiKey: 'K'),
        client: client,
      ).generateImage(prompt: 'p');
      expect(bytes, base64Decode(pngB64));
    });

    test('Gemini: gorsel parcasi yoksa empty', () {
      final client = MockClient(
        (_) async => _ok({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'uzgunum, ciziemem'},
                ],
              },
            },
          ],
        }),
      );
      expect(
        () => AiService(
          const AiSettings(provider: AiProvider.gemini, apiKey: 'K'),
          client: client,
        ).generateImage(prompt: 'p'),
        throwsA(isA<AiException>().having((e) => e.message, 'msg', 'empty')),
      );
    });

    test('OpenAI: b64_json dogrudan cozulur', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return _ok({
          'data': [
            {'b64_json': pngB64},
          ],
        });
      });
      final bytes = await AiService(
        const AiSettings(provider: AiProvider.openai, apiKey: 'K'),
        client: client,
      ).generateImage(prompt: 'p');

      expect(bytes, base64Decode(pngB64));
      expect(captured.url.path, '/v1/images/generations');
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['model'], 'gpt-image-1');
      // gpt-image-1 bu parametreyi reddediyor; gonderilmemeli.
      expect(body.containsKey('response_format'), isFalse);
    });

    test('OpenAI: url donerse gorsel indirilir (dall-e-3 yolu)', () async {
      final client = MockClient((req) async {
        if (req.url.host == 'cdn.example') {
          return http.Response.bytes(base64Decode(pngB64), 200);
        }
        return _ok({
          'data': [
            {'url': 'https://cdn.example/portre.png'},
          ],
        });
      });
      final bytes = await AiService(
        const AiSettings(
          provider: AiProvider.openai,
          apiKey: 'K',
          imageModel: 'dall-e-3',
        ),
        client: client,
      ).generateImage(prompt: 'p');
      expect(bytes, base64Decode(pngB64));
    });

    test('gorsel modeli kullanici tarafindan ezilebilir', () async {
      late http.Request captured;
      final client = MockClient((req) async {
        captured = req;
        return _ok({
          'data': [
            {'b64_json': pngB64},
          ],
        });
      });
      await AiService(
        const AiSettings(
          provider: AiProvider.openai,
          apiKey: 'K',
          imageModel: 'yeni-gorsel-modeli',
        ),
        client: client,
      ).generateImage(prompt: 'p');
      expect(jsonDecode(captured.body)['model'], 'yeni-gorsel-modeli');
    });

    test('401 -> auth, 429 -> rate', () async {
      Future<void> expectCode(int status, String code) async {
        final client = MockClient((_) async => http.Response('{}', status));
        await expectLater(
          AiService(
            const AiSettings(provider: AiProvider.gemini, apiKey: 'K'),
            client: client,
          ).generateImage(prompt: 'p'),
          throwsA(isA<AiException>().having((e) => e.message, 'msg', code)),
        );
      }

      await expectCode(401, 'auth');
      await expectCode(429, 'rate');
    });
  });

  // --- Saglayicinin hata metni korunur -----------------------------------
  //
  // Gemini, bir model hesabin planinda kullanilamadiginda da 429 donuyor.
  // "Istek sinirina ulasildi, birazdan dene" demek yaniltici; asil cumle
  // govdede. AiException.detail bunu tasimali.

  group('hata ayrintisi', () {
    http.Response err(int status, Map<String, dynamic> body) => http.Response(
      jsonEncode(body),
      status,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );

    test('Gemini 429: status + mesaj + kota kimligi tasinir', () async {
      final client = MockClient(
        (_) async => err(429, {
          'error': {
            'code': 429,
            'status': 'RESOURCE_EXHAUSTED',
            'message': 'You exceeded your current quota.',
            'details': [
              {
                'violations': [
                  {
                    'quotaId': 'GenerateRequestsPerDayPerProjectPerModel',
                    'quotaValue': '0',
                  },
                ],
              },
            ],
          },
        }),
      );

      try {
        await AiService(
          const AiSettings(provider: AiProvider.gemini, apiKey: 'K'),
          client: client,
        ).generateImage(prompt: 'p');
        fail('AiException bekleniyordu');
      } on AiException catch (e) {
        expect(e.message, 'rate');
        expect(e.detail, contains('RESOURCE_EXHAUSTED'));
        expect(e.detail, contains('exceeded your current quota'));
        // Limitin 0 olmasi "bekle" degil "bu model planinda yok" demek;
        // kullanici bunu gorebilmeli.
        expect(e.detail, contains('GenerateRequestsPerDayPerProjectPerModel'));
        expect(e.detail, contains('limit 0'));
      }
    });

    test('OpenAI 400: error.message tasinir', () async {
      final client = MockClient(
        (_) async => err(400, {
          'error': {'message': 'Unknown model: gpt-image-9'},
        }),
      );
      try {
        await AiService(
          const AiSettings(provider: AiProvider.openai, apiKey: 'K'),
          client: client,
        ).generateImage(prompt: 'p');
        fail('AiException bekleniyordu');
      } on AiException catch (e) {
        expect(e.message, 'http:400');
        expect(e.detail, contains('Unknown model: gpt-image-9'));
      }
    });

    test('401 ayrintisi da korunur', () async {
      final client = MockClient(
        (_) async => err(401, {
          'error': {'message': 'API key not valid'},
        }),
      );
      try {
        await AiService(
          const AiSettings(provider: AiProvider.gemini, apiKey: 'K'),
          client: client,
        ).generate(systemPrompt: 's', userPrompt: 'u');
        fail('AiException bekleniyordu');
      } on AiException catch (e) {
        expect(e.message, 'auth');
        expect(e.detail, contains('API key not valid'));
      }
    });

    test('JSON olmayan govde ham metin olarak tasinir', () async {
      final client = MockClient(
        (_) async => http.Response('502 Bad Gateway', 502),
      );
      try {
        await AiService(
          const AiSettings(provider: AiProvider.gemini, apiKey: 'K'),
          client: client,
        ).generate(systemPrompt: 's', userPrompt: 'u');
        fail('AiException bekleniyordu');
      } on AiException catch (e) {
        expect(e.detail, contains('Bad Gateway'));
      }
    });

    test('cok uzun govde kirpilir (arayuzu bogmasin)', () async {
      final long = 'x' * 5000;
      final client = MockClient((_) async => http.Response(long, 500));
      try {
        await AiService(
          const AiSettings(provider: AiProvider.gemini, apiKey: 'K'),
          client: client,
        ).generate(systemPrompt: 's', userPrompt: 'u');
        fail('AiException bekleniyordu');
      } on AiException catch (e) {
        expect(e.detail!.length, lessThan(700));
        expect(e.detail, endsWith('…'));
      }
    });
  });
}
