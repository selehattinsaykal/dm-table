/// 5etools bicimindeki kayitlarda GORSEL bulur.
///
/// Bicimde gorsel iki yerde durabiliyor:
///
///  * Kaydin kendi icinde: `{"images": [...]}` ya da tek bir `"image"`.
///  * Ayri bir "fluff" dosyasinda: `bestiary/fluff-bestiary-<kitap>.json`
///    icinde ayni ada sahip bir kayit ve onun `images` dizisi. Asil bestiary
///    dosyasi yalnizca `hasFluffImages: true` diyor.
///
/// Bir gorsel girdisi genelde soyle:
/// `{"type":"image","href":{"type":"internal","path":"bestiary/MM/Goblin.webp"}}`
/// `internal` yol VERI KOKUNE gore degil, `img/` klasorune gore. `external`
/// olanlarda tam adres `href.url` icinde.
library;

/// Bir kayda ait gorsel adresi.
typedef ImageRef = ({
  /// Kayit anahtari (`fiveToolsKey` ile ayni).
  String key,

  /// Ic yol (`img/` klasorune gore) ya da tam adres.
  String path,

  /// `true` ise [path] tam bir adres.
  bool external,
});

/// Bir kaydin gorsel girdilerini cikarir; yoksa bos liste.
List<ImageRef> imagesOf(Map<String, dynamic> entry, String key) {
  final out = <ImageRef>[];

  void read(Object? node) {
    if (node is List) {
      for (final item in node) {
        read(item);
      }
      return;
    }
    if (node is! Map) return;
    final map = node.cast<String, dynamic>();
    final href = map['href'];
    if (href is! Map) return;
    final h = href.cast<String, dynamic>();

    final url = h['url'];
    if (url is String && url.isNotEmpty) {
      out.add((key: key, path: url, external: true));
      return;
    }
    final path = h['path'];
    if (path is String && path.isNotEmpty) {
      out.add((key: key, path: path, external: false));
    }
  }

  read(entry['images']);
  read(entry['image']);
  // "fluff" bazen kaydin ICINE gomulu geliyor.
  final fluff = entry['fluff'];
  if (fluff is Map) read(fluff.cast<String, dynamic>()['images']);
  return out;
}

/// Bir fluff dosyasinin govdesinden ad -> gorseller esleme tablosu.
///
/// Fluff dosyalari asil kayitla ADLA eslesiyor; anahtar orada yok. Ad
/// KUCUK HARFE indiriliyor cunku iki dosya arasinda buyuk/kucuk harf farki
/// oluyor ("Goblin" / "goblin").
Map<String, List<ImageRef>> fluffImageIndex(
  Map<String, dynamic> body,
  String Function(String name, String? source) keyOf,
) {
  final out = <String, List<ImageRef>>{};
  for (final value in body.values) {
    if (value is! List) continue;
    for (final item in value) {
      if (item is! Map) continue;
      final entry = item.cast<String, dynamic>();
      final name = entry['name'];
      if (name is! String || name.isEmpty) continue;
      final key = keyOf(name, entry['source'] as String?);
      final images = imagesOf(entry, key);
      if (images.isEmpty) continue;
      out[name.toLowerCase()] = images;
    }
  }
  return out;
}

/// Asil dosyanin adindan fluff dosyasinin adini uretir.
///
/// `bestiary/bestiary-mm.json` -> `bestiary/fluff-bestiary-mm.json`.
/// Baska bir desen tanimazsa null.
String? fluffPathFor(String path) {
  final slash = path.lastIndexOf('/');
  final dir = slash < 0 ? '' : path.substring(0, slash + 1);
  final file = slash < 0 ? path : path.substring(slash + 1);
  if (file.startsWith('fluff-')) return null;
  if (!file.endsWith('.json')) return null;
  return '$dir'
      'fluff-$file';
}

/// Ic yolu tam adrese cevirir.
///
/// Veri koku `<kok>/data`, gorseller ise `<kok>/img` altinda duruyor: yani
/// gorsel adresi veri kokunun BIR USTUNDEN turetiliyor.
String? resolveImageUrl(String dataBaseUrl, ImageRef ref) {
  if (ref.external) return ref.path;
  final root = dataBaseUrl.endsWith('/')
      ? dataBaseUrl.substring(0, dataBaseUrl.length - 1)
      : dataBaseUrl;
  final slash = root.lastIndexOf('/');
  if (slash < 0) return null;
  final parent = root.substring(0, slash);
  final clean = ref.path.startsWith('/') ? ref.path.substring(1) : ref.path;
  return '$parent/img/$clean';
}
