import 'dart:convert';

import 'package:http/http.dart' as http;

/// Ice aktarilabilecek tek bir dosya.
typedef RemoteFile = ({
  /// Hangi kayit turu: `monster`, `spell`, `item`, `race`, `background`,
  /// `feat`.
  String kind,

  /// Kaynak kitap kodu (PHB, MM...); tek dosyali turlerde bos.
  String source,

  /// Kaynagin kokune GORE yol.
  String path,
});

/// Kesif neden basarisiz oldu.
///
/// Kesif eskiden her hatayi yutup bos liste donuyordu; kullanici "hicbir sey
/// bulunamadi" disinda bir sey goremiyor, adresi mi yanlis yazdi yoksa sunucu
/// mu reddetti anlayamiyordu.
enum DiscoveryProblem {
  /// Sorun yok.
  none,

  /// Baglanti kurulamadi ya da zaman asimi.
  network,

  /// Sunucu isteyerek reddetti (403/401/429 ya da bot korumasi challenge'i).
  ///
  /// Bazi siteler tarayici disi istemcileri Cloudflare gibi bir katmanla
  /// engelliyor. Bu ENGELI ASMAYA CALISMIYORUZ; durumu kullaniciya
  /// soyluyoruz.
  blocked,

  /// Adres cevap veriyor ama beklenen dosyalar orada degil.
  notFound,

  /// Cevap geldi, JSON degil (cogunlukla bir HTML sayfasi).
  notJson,
}

/// Bir kesif denemesinin sonucu.
typedef DiscoveryResult = ({
  /// Dosyalarin gercekten bulundugu kok. Kullanicinin yazdigi adresten
  /// FARKLI olabilir (bkz. [FiveToolsSource.discover]).
  String resolvedBase,
  List<RemoteFile> files,
  DiscoveryProblem problem,

  /// Varsa son HTTP durum kodu; arayuzde ham bilgi olarak gosteriliyor.
  int? status,
});

/// 5etools bicimli veri sunan bir adres.
///
/// **Adres KODA GOMULU DEGIL.** Kullanici hangi kaynagi kullanacagina kendi
/// karar veriyor: kendi homebrew deposu, kendi disa aktardigi dosyalar ya da
/// erisim hakkina sahip oldugu bir arsiv. Uygulama sabit bir kaynakla
/// gelmiyor.
class FiveToolsSource {
  const FiveToolsSource({required this.baseUrl, this.client});

  /// Veri klasorunun koku, or. `https://ornek/data`.
  final String baseUrl;

  /// Testlerde sahte istemci verilebilsin diye disari acik.
  final http.Client? client;

  /// Tek dosyada duran turler: kokte `<ad>.json`.
  static const _singleFiles = <String, String>{
    'item': 'items.json',
    'race': 'races.json',
    'background': 'backgrounds.json',
    'feat': 'feats.json',
  };

  /// `index.json` ile dagitilan turler: klasor -> kayit turu.
  ///
  /// 5etools bestiary ve buyuleri kitap basina ayri dosyalara boluyor ve
  /// hangi kitabin hangi dosyada oldugunu `index.json` soyluyor. Bu yuzden
  /// kullanicidan tek bir KOK adres yetiyor -- gerisini kesif buluyor.
  static const _indexedDirs = <String, String>{
    'bestiary': 'monster',
    'spells': 'spell',
  };

  /// Bicimin alisildik klasor adi.
  ///
  /// Kullanici cogu zaman SITENIN kokunu yapistiriyor (`https://ornek`),
  /// oysa dosyalar `https://ornek/data` altinda duruyor. Yazdigi adres bos
  /// cikarsa bir de burayi deniyoruz.
  static const _dataDir = 'data';

  Uri _uri(String root, String path) {
    final trimmed = root.endsWith('/')
        ? root.substring(0, root.length - 1)
        : root;
    return Uri.parse('$trimmed/$path');
  }

  http.Client get _http => client ?? http.Client();

  /// Denenecek kok adresler, sirayla.
  List<String> get _candidates {
    final trimmed = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    // Adres zaten veri klasorunu gosteriyorsa ikinci deneme gereksiz.
    if (trimmed.split('/').last == _dataDir) return [trimmed];
    return [trimmed, '$trimmed/$_dataDir'];
  }

  /// Adreste hangi dosyalarin bulundugunu KESFEDER.
  ///
  /// Once kullanicinin yazdigi kok, sonra onun altindaki `data/` klasoru
  /// deneniyor. Bulunamayan BOLUM sessizce atlaniyor (her kaynak her turu
  /// sunmuyor; yalnizca canavar barindiran bir homebrew deposu gecerli bir
  /// kaynak), ama HICBIR sey bulunamazsa neden bulunamadigi geri donuyor.
  Future<DiscoveryResult> discover() async {
    var problem = DiscoveryProblem.notFound;
    int? status;

    for (final root in _candidates) {
      final out = <RemoteFile>[];

      for (final entry in _indexedDirs.entries) {
        final result = await _tryJson(root, '${entry.key}/index.json');
        if (result.problem != DiscoveryProblem.none) {
          problem = _worse(problem, result.problem);
          status ??= result.status;
          continue;
        }
        final index = result.value;
        if (index is! Map) {
          problem = _worse(problem, DiscoveryProblem.notJson);
          continue;
        }
        for (final item in index.cast<String, dynamic>().entries) {
          out.add((
            kind: entry.value,
            source: item.key,
            path: '${entry.key}/${item.value}',
          ));
        }
      }

      for (final entry in _singleFiles.entries) {
        final result = await _tryJson(root, entry.value);
        if (result.problem != DiscoveryProblem.none) {
          problem = _worse(problem, result.problem);
          status ??= result.status;
          continue;
        }
        out.add((kind: entry.key, source: '', path: entry.value));
      }

      if (out.isNotEmpty) {
        out.sort((a, b) {
          final byKind = a.kind.compareTo(b.kind);
          return byKind != 0 ? byKind : a.source.compareTo(b.source);
        });
        return (
          resolvedBase: root,
          files: out,
          problem: DiscoveryProblem.none,
          status: null,
        );
      }
    }

    return (
      resolvedBase: _candidates.first,
      files: const <RemoteFile>[],
      problem: problem,
      status: status,
    );
  }

  /// Iki sorundan KULLANICIYA daha cok sey anlatani secer.
  ///
  /// "404" en az bilgi veren sonuc: adres yanlis da olabilir, o kaynak o turu
  /// sunmuyor da olabilir. Engellenme ya da baglanti hatasi ise kesin bir
  /// sebep, onlar one cikmali.
  static DiscoveryProblem _worse(DiscoveryProblem a, DiscoveryProblem b) {
    const rank = {
      DiscoveryProblem.none: 0,
      DiscoveryProblem.notFound: 1,
      DiscoveryProblem.notJson: 2,
      DiscoveryProblem.network: 3,
      DiscoveryProblem.blocked: 4,
    };
    return rank[a]! >= rank[b]! ? a : b;
  }

  /// Bir dosyanin icindeki kayit listesini okur.
  ///
  /// 5etools her dosyayi tur adiyla anahtarlanmis bir nesne olarak veriyor:
  /// `{"monster": [...]}`. Anahtar bulunamazsa ilk liste alaniyla yetiniliyor
  /// -- homebrew dosyalari bazen farkli adlandiriyor.
  Future<List<Map<String, dynamic>>> fetchEntries(RemoteFile file) async {
    final body = (await _tryJson(_candidates.first, file.path)).value;
    if (body is! Map) return const [];
    final map = body.cast<String, dynamic>();

    final expected = switch (file.kind) {
      'monster' => 'monster',
      'spell' => 'spell',
      'item' => 'item',
      'race' => 'race',
      'background' => 'background',
      'feat' => 'feat',
      _ => file.kind,
    };

    var list = map[expected];
    if (list is! List) {
      // `items.json` hem `item` hem `itemGroup` tasiyabiliyor; ilk listeyi al.
      for (final value in map.values) {
        if (value is List && value.isNotEmpty && value.first is Map) {
          list = value;
          break;
        }
      }
    }
    if (list is! List) return const [];
    return [
      for (final entry in list)
        if (entry is Map) entry.cast<String, dynamic>(),
    ];
  }

  /// Bir gorseli indirir; basarisiz olursa null.
  ///
  /// Gorseller VERI KOKUNUN DISINDA (`img/`) durdugu icin tam adres
  /// disaridan geliyor; bu yuzden [baseUrl] kullanilmiyor.
  Future<List<int>?> fetchImage(String url) async {
    try {
      final response = await _http
          .get(
            Uri.parse(url),
            headers: const {'User-Agent': 'DMTable/1.1 (+content-import)'},
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) return null;
      return response.bodyBytes;
    } on Object {
      return null;
    }
  }

  /// Bir yoldaki JSON govdesini okur; yoksa null.
  ///
  /// Fluff (gorsel) dosyalari icin: bulunamamasi NORMAL, her kitabin
  /// gorsel dosyasi olmuyor.
  Future<Map<String, dynamic>?> fetchBody(String path) async {
    final body = (await _tryJson(_candidates.first, path)).value;
    return body is Map ? body.cast<String, dynamic>() : null;
  }

  /// Adresi okur; basarisizlik SEBEBIYLE birlikte doner.
  Future<({Object? value, DiscoveryProblem problem, int? status})> _tryJson(
    String root,
    String path,
  ) async {
    http.Response response;
    try {
      response = await _http
          .get(
            _uri(root, path),
            // Sunucular kimlik belirtmeyen istemcileri reddedebiliyor;
            // uygulama kendini DURUSTCE tanitiyor (tarayici taklidi YOK).
            headers: const {'User-Agent': 'DMTable/1.1 (+content-import)'},
          )
          .timeout(const Duration(seconds: 30));
    } on Object {
      return (value: null, problem: DiscoveryProblem.network, status: null);
    }

    // Bot korumasi: sunucu bir dogrulama sayfasi donuyor. ASMAYA
    // CALISMIYORUZ -- durumu oldugu gibi bildiriyoruz.
    final blocked =
        const [401, 403, 429].contains(response.statusCode) ||
        response.headers.containsKey('cf-mitigated');
    if (blocked) {
      return (
        value: null,
        problem: DiscoveryProblem.blocked,
        status: response.statusCode,
      );
    }
    if (response.statusCode != 200) {
      return (
        value: null,
        problem: DiscoveryProblem.notFound,
        status: response.statusCode,
      );
    }

    try {
      return (
        value: jsonDecode(utf8.decode(response.bodyBytes)),
        problem: DiscoveryProblem.none,
        status: 200,
      );
    } on Object {
      return (
        value: null,
        problem: DiscoveryProblem.notJson,
        status: response.statusCode,
      );
    }
  }
}
