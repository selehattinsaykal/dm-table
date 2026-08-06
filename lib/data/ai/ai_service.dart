import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../domain/ai/ai_settings.dart';

/// AI çağrısı başarısız olduğunda fırlatılır.
///
/// [message] kısa bir KOD ('auth', 'rate', 'empty'...); arayüz bunu çevrilmiş
/// bir cümleye eşler. [detail] sağlayıcının kendi hata metnidir ve kullanıcıya
/// olduğu gibi gösterilir.
///
/// Neden ayrı bir [detail]: kodlar tek başına yanıltıcı olabiliyor. Gemini,
/// bir model hesabın planında KULLANILAMADIĞINDA da 429 döndürüyor (limit 0
/// ile RESOURCE_EXHAUSTED) — "istek sınırına ulaşıldı, birazdan dene" demek
/// yanlış yönlendiriyor, çünkü beklemek çözmüyor. Gerçek cümle yanıt
/// gövdesinde; onu atmak yerine taşıyoruz.
class AiException implements Exception {
  const AiException(this.message, {this.detail});
  final String message;

  /// Sağlayıcının ham hata açıklaması (varsa).
  final String? detail;

  @override
  String toString() => detail == null ? message : '$message: $detail';
}

/// "Kendi anahtarını getir" metin üretimi. Üç sağlayıcının (Gemini/OpenAI/
/// Anthropic) ham HTTP biçimini tek bir [generate] arayüzü altında toplar.
///
/// Test için [client] enjekte edilebilir (http'nin MockClient'i).
class AiService {
  AiService(this.settings, {http.Client? client})
    : _client = client ?? http.Client();

  final AiSettings settings;
  final http.Client _client;

  /// [systemPrompt] rol/talimat, [userPrompt] asıl istek. Üretilen metni döner.
  /// Anahtar yoksa ya da API hata verirse [AiException] fırlatır.
  Future<String> generate({
    required String systemPrompt,
    required String userPrompt,
    int maxTokens = 2048,
  }) async {
    if (!settings.enabled) {
      throw const AiException('no-key');
    }
    switch (settings.provider) {
      case AiProvider.gemini:
        return _gemini(systemPrompt, userPrompt, maxTokens);
      case AiProvider.openai:
        return _openai(systemPrompt, userPrompt, maxTokens);
      case AiProvider.anthropic:
        return _anthropic(systemPrompt, userPrompt, maxTokens);
    }
  }

  Future<String> _gemini(String system, String user, int maxTokens) async {
    final model = settings.effectiveModel;
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$model:generateContent?key=${settings.apiKey}',
    );
    final res = await _post(
      uri,
      headers: const {'content-type': 'application/json'},
      body: {
        'system_instruction': {
          'parts': [
            {'text': system},
          ],
        },
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': user},
            ],
          },
        ],
        'generationConfig': {'maxOutputTokens': maxTokens},
      },
    );
    final data = _decode(res);
    final candidates = data['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw const AiException('empty');
    }
    final parts = (candidates.first as Map)['content']?['parts'];
    if (parts is! List || parts.isEmpty) throw const AiException('empty');
    return _joinTexts(parts);
  }

  Future<String> _openai(String system, String user, int maxTokens) async {
    final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
    final res = await _post(
      uri,
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer ${settings.apiKey}',
      },
      body: {
        'model': settings.effectiveModel,
        'max_tokens': maxTokens,
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': user},
        ],
      },
    );
    final data = _decode(res);
    final choices = data['choices'];
    if (choices is! List || choices.isEmpty) throw const AiException('empty');
    final content = (choices.first as Map)['message']?['content'];
    if (content is! String || content.trim().isEmpty) {
      throw const AiException('empty');
    }
    return content.trim();
  }

  Future<String> _anthropic(String system, String user, int maxTokens) async {
    final uri = Uri.parse('https://api.anthropic.com/v1/messages');
    final res = await _post(
      uri,
      headers: {
        'content-type': 'application/json',
        'x-api-key': settings.apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: {
        'model': settings.effectiveModel,
        'max_tokens': maxTokens,
        'system': system,
        'messages': [
          {'role': 'user', 'content': user},
        ],
      },
    );
    final data = _decode(res);
    // Güvenlik reddi: content boş/parçasız olabilir.
    if (data['stop_reason'] == 'refusal') throw const AiException('refused');
    final content = data['content'];
    if (content is! List || content.isEmpty) throw const AiException('empty');
    return _joinTexts(content);
  }

  // --- Görsel üretimi ------------------------------------------------------

  /// Verilen istemden bir görsel üretir ve ham baytlarını döner (JPEG/PNG).
  ///
  /// Yalnızca görsel üretim uç noktası olan sağlayıcılarda çalışır; Anthropic
  /// görsel OKUR ama ÜRETMEZ, orada `AiException('no-image')` fırlar. Çağıran
  /// bunu ölümcül saymamalı: NPC metni zaten üretilmiş olur, yalnızca portre
  /// eksik kalır.
  Future<Uint8List> generateImage({required String prompt}) async {
    if (!settings.enabled) throw const AiException('no-key');
    final model = settings.effectiveImageModel;
    if (model == null) throw const AiException('no-image');
    switch (settings.provider) {
      case AiProvider.gemini:
        return _geminiImage(model, prompt);
      case AiProvider.openai:
        return _openaiImage(model, prompt);
      case AiProvider.anthropic:
        throw const AiException('no-image');
    }
  }

  Future<Uint8List> _geminiImage(String model, String prompt) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$model:generateContent?key=${settings.apiKey}',
    );
    final res = await _post(
      uri,
      headers: const {'content-type': 'application/json'},
      body: {
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        // Görsel modelleri TEXT+IMAGE ister; yalnız IMAGE isteyen biçim bazı
        // model sürümlerinde 400 dönüyor.
        'generationConfig': {
          'responseModalities': ['TEXT', 'IMAGE'],
        },
      },
    );
    final data = _decode(res);
    final candidates = data['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw const AiException('empty');
    }
    final parts = (candidates.first as Map)['content']?['parts'];
    if (parts is! List) throw const AiException('empty');
    for (final part in parts) {
      // Yanıtta metin parçaları da gelebilir; ilk gömülü görseli al.
      final inline = (part as Map)['inlineData'] ?? part['inline_data'];
      final b64 = inline is Map ? inline['data'] : null;
      if (b64 is String && b64.isNotEmpty) return _decodeBase64(b64);
    }
    throw const AiException('empty');
  }

  Future<Uint8List> _openaiImage(String model, String prompt) async {
    final uri = Uri.parse('https://api.openai.com/v1/images/generations');
    final res = await _post(
      uri,
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer ${settings.apiKey}',
      },
      // `response_format` BILINCLI olarak gonderilmiyor: gpt-image-1 bu
      // parametreyi reddediyor, dall-e-3 ise varsayilan olarak url donuyor.
      // Iki durumu da asagida yanittan okuyoruz.
      body: {'model': model, 'prompt': prompt, 'n': 1, 'size': '1024x1024'},
    );
    final data = _decode(res);
    final list = data['data'];
    if (list is! List || list.isEmpty) throw const AiException('empty');
    final first = list.first as Map;

    final b64 = first['b64_json'];
    if (b64 is String && b64.isNotEmpty) return _decodeBase64(b64);

    final url = first['url'];
    if (url is String && url.isNotEmpty) {
      try {
        final img = await _client.get(Uri.parse(url));
        if (img.statusCode >= 400 || img.bodyBytes.isEmpty) {
          throw const AiException('empty');
        }
        return img.bodyBytes;
      } on AiException {
        rethrow;
      } catch (_) {
        throw const AiException('network');
      }
    }
    throw const AiException('empty');
  }

  Uint8List _decodeBase64(String value) {
    try {
      final bytes = base64Decode(value);
      if (bytes.isEmpty) throw const AiException('empty');
      return bytes;
    } on AiException {
      rethrow;
    } catch (_) {
      throw const AiException('parse');
    }
  }

  // --- Ortak yardımcılar ---------------------------------------------------

  Future<http.Response> _post(
    Uri uri, {
    required Map<String, String> headers,
    required Map<String, dynamic> body,
  }) async {
    try {
      return await _client.post(uri, headers: headers, body: jsonEncode(body));
    } catch (_) {
      throw const AiException('network');
    }
  }

  /// Gövdeyi çözer; HTTP hatalarını okunur mesaja çevirir.
  Map<String, dynamic> _decode(http.Response res) {
    if (res.statusCode >= 400) {
      final detail = _errorDetail(res);
      if (res.statusCode == 401 || res.statusCode == 403) {
        throw AiException('auth', detail: detail);
      }
      if (res.statusCode == 429) throw AiException('rate', detail: detail);
      throw AiException('http:${res.statusCode}', detail: detail);
    }
    try {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw const AiException('parse');
    }
  }

  /// Sağlayıcının hata açıklamasını çıkarır.
  ///
  /// Gemini, OpenAI ve Anthropic üçü de `{"error": {"message": ...}}` biçimini
  /// kullanıyor. Gemini ayrıca `error.status` (ör. RESOURCE_EXHAUSTED) ve
  /// kota ayrıntılarını veriyor — hangi kotanın dolduğunu ancak orası söylüyor.
  /// Gövde JSON değilse ham metin (kırpılmış) döner; hiçbir şey yoksa null.
  String? _errorDetail(http.Response res) {
    String? clip(String? s) {
      final t = s?.trim();
      if (t == null || t.isEmpty) return null;
      return t.length <= 600 ? t : '${t.substring(0, 600)}…';
    }

    try {
      final body = jsonDecode(res.body);
      if (body is Map) {
        final error = body['error'];
        if (error is Map) {
          final parts = <String>[
            if (error['status'] is String) '${error['status']}',
            if (error['message'] is String) '${error['message']}',
          ];
          // Gemini kota ayrintisi: hangi metrik ve limit kac.
          final details = error['details'];
          if (details is List) {
            for (final d in details) {
              if (d is! Map) continue;
              final violations = d['violations'];
              if (violations is! List) continue;
              for (final v in violations) {
                if (v is! Map) continue;
                final id = v['quotaId'] ?? v['quotaMetric'];
                final limit = v['quotaValue'];
                if (id != null) {
                  parts.add(
                    'quota=$id${limit == null ? '' : ' (limit $limit)'}',
                  );
                }
              }
            }
          }
          if (parts.isNotEmpty) return clip(parts.join(' · '));
        }
        if (error is String) return clip(error);
      }
    } catch (_) {
      // JSON degilse asagida ham govdeye duser.
    }
    return clip(res.body);
  }

  /// Bir "parts"/"content" dizisindeki tüm text alanlarını birleştirir.
  String _joinTexts(List<dynamic> items) {
    final buffer = StringBuffer();
    for (final item in items) {
      final text = (item as Map)['text'];
      if (text is String) buffer.write(text);
    }
    final result = buffer.toString().trim();
    if (result.isEmpty) throw const AiException('empty');
    return result;
  }
}
