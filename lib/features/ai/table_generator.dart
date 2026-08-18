/// AI rastgele tablo üreteci: konu + ton + zar yüzüne göre bir tablo kurgular.
///
/// Saf modül (Flutter/Drift bilmez): istem kurar, JSON yanıtı ayrıştırır.
/// `encounter_generator.dart` ile aynı ayrım.
library;

import 'ai_json.dart';

/// Tablonun atmosferi; istemde düzyazı olarak geçer.
enum TableTone {
  gritty('karanlık, gerçekçi, tehditkâr'),
  humorous('mizahi, absürt, hafif'),
  epic('destansı, görkemli, kaderî'),
  mundane('gündelik, sıradan, inandırıcı');

  const TableTone(this.promptDescriptor);

  /// İsteme yazılan Türkçe betimleme.
  final String promptDescriptor;
}

/// Ayrıştırılmış tablo.
typedef TableResult = ({
  String name,
  String category,
  int diceSides,
  List<String> rows,
});

({String system, String user}) buildTablePrompt({
  required String topic,
  required int diceSides,
  required int rowCount,
  required TableTone tone,
  required String languageName,
  String context = '',
}) {
  final system =
      'D&D 5e (2024) Zindan Efendisi yardımcısısın. Masada anında '
      'kullanılabilecek bir RASTGELE TABLO hazırla ve yanıtı $languageName '
      'yaz. Telifli evren/yer/karakter adı kullanma. SADECE şu JSON nesnesini '
      'döndür, başka hiçbir metin/işaret ekleme:\n'
      '{"name": "...", "category": "...", "diceSides": $diceSides, '
      '"rows": ["...", "..."]}\n'
      '"name" = tablonun kısa adı. "category" = tek kelimelik etiket '
      '(ör. şehir, yol, ganimet, npc). "rows" = TAM $rowCount adet madde; '
      'her madde masada olduğu gibi okunabilecek, KENDİ BAŞINA anlamlı, tek '
      'cümlelik bir sonuç olmalı. Maddeler birbirini TEKRAR ETMESİN ve '
      'birbirinden belirgin şekilde farklı olsun; hepsi aynı kalıpla '
      'başlamasın. Kural/sayı verme (hasar, DC, zar) — anlatı sonucu yaz. '
      'Her madde en fazla 20 kelime.';

  final buffer = StringBuffer(
    'Konu/tema: ${topic.trim().isEmpty ? 'serbest' : topic.trim()}. '
    'Zar: d$diceSides, yani TAM $rowCount madde. '
    'Ton: ${tone.promptDescriptor}.',
  );
  if (context.trim().isNotEmpty) {
    buffer.write(' Bağlam: ${context.trim()}.');
  }
  return (system: system, user: buffer.toString());
}

/// Modelin JSON yanıtını ayrıştırır.
///
/// ```json çitlerini ve JSON dışı önek/soneki tolere eder. `rows` düz string
/// dizisi ya da `{"text": ...}` nesneleri olabilir. Ayrıştırılamazsa satırlar
/// ham metinden satır satır çıkarılır (model kimi zaman düz liste döndürüyor).
TableResult parseTableResult(String raw, {int fallbackDiceSides = 20}) {
  final text = raw.trim();
  // Kesilmis yanit da kurtarilir: uzun tablolarda (d100) yanit token
  // butcesini doldurup ortadan kesilebiliyor; o durumda gelen satirlar
  // kaybolmasin (bkz. `ai_json.dart`).
  final map = decodeAiJsonObject(text);
  if (map != null) {
    final rows = _rowsFrom(map['rows']);
    if (rows.isNotEmpty) {
      final rawSides = map['diceSides'];
      return (
        name: aiField(map, 'name'),
        category: aiField(map, 'category'),
        diceSides: rawSides is num
            ? rawSides.round()
            : int.tryParse('$rawSides') ?? fallbackDiceSides,
        rows: rows,
      );
    }
  }

  // Duz metin yedegi: numarali/tireli satirlari ayikla.
  final lines = [
    for (final line in text.split('\n'))
      if (_stripBullet(line) case final cleaned when cleaned.isNotEmpty)
        cleaned,
  ];
  return (name: '', category: '', diceSides: fallbackDiceSides, rows: lines);
}

List<String> _rowsFrom(Object? raw) {
  if (raw is! List) return const [];
  final out = <String>[];
  for (final entry in raw) {
    if (entry is String) {
      final text = entry.trim();
      if (text.isNotEmpty) out.add(text);
    } else if (entry is Map) {
      final text = '${entry['text'] ?? entry['result'] ?? ''}'.trim();
      if (text.isNotEmpty) out.add(text);
    }
  }
  return out;
}

/// "1. Şey", "- Şey", "12) Şey" -> "Şey"
String _stripBullet(String line) => line
    .trim()
    .replaceFirst(
      RegExp(r'^\s*(\d+\s*[-.):]|\d+\s*[-–]\s*\d+\s*[-.):]|[-*•])\s*'),
      '',
    )
    .trim();
