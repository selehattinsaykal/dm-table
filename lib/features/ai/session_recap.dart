import 'package:drift/drift.dart';

import '../../data/ai/ai_service.dart';
import '../../data/db/database.dart';

/// Oturum gunlugunden anlati ozeti uretir.
///
/// **Neden AI:** gunluk kayitlari masada aceleyle yazilmis notlar ("goblin
/// pususu", "Mira 12 hasar aldi", "koye vardilar"). Bunlari bir sonraki
/// oturumun basinda okunacak bir "gecen bolum ozeti"ne cevirmek insan isi;
/// tek tek okumak kimsenin yapmadigi bir is.
///
/// AI KAPALIYSA calismiyor ve kendi anahtarini kullaniyor (bkz.
/// `AiSettings`); gunluk metni cihazdan disari yalnizca kullanici bu
/// dugmeye bastiginda cikiyor.
class SessionRecap {
  const SessionRecap(this.db, this.ai);

  final AppDatabase db;
  final AiService ai;

  /// Ozetlenecek en fazla kayit.
  ///
  /// Uzun kampanyalarda gunluk binlerce satir olabiliyor; hepsini gondermek
  /// hem pahali hem de ozetin odagini dagitiyor. Son oturum masadaki soru.
  static const maxEntries = 120;

  /// Son [maxEntries] kaydi ozetler.
  ///
  /// Gunluk bossa null doner -- bos bir istek gondermek anlamsiz.
  Future<String?> generate({String language = 'tr'}) async {
    final entries =
        await (db.select(db.sessionLogEntries)
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.sortKey,
                  mode: OrderingMode.desc,
                ),
              ])
              ..limit(maxEntries))
            .get();
    if (entries.isEmpty) return null;

    // Kronolojik siraya cevriliyor: ozet olaylari olus sirasiyla anlatmali.
    final lines = entries.reversed.map((e) => '- ${e.message}').join('\n');

    final system = language == 'tr'
        ? 'Sen bir D&D oyununun tarihcisisin. Verilen ham oturum '
              'notlarindan, bir sonraki oturumun basinda masaya yuksek sesle '
              'okunacak kisa bir "gecen bolumde" ozeti yaz. Uc ila bes '
              'paragraf. Kural detayi, zar sonucu ve hasar rakami YAZMA; '
              'olaylari ve kararlari anlat. Notlarda olmayan hicbir sey '
              'uydurma.'
        : 'You are the chronicler of a D&D game. From the raw session notes, '
              'write a short "previously on" recap to be read aloud at the '
              'start of the next session. Three to five paragraphs. Do not '
              'include rules details, dice results or damage numbers; narrate '
              'events and decisions. Invent nothing that is not in the notes.';

    return ai.generate(
      systemPrompt: system,
      userPrompt: lines,
      maxTokens: 1200,
    );
  }
}
