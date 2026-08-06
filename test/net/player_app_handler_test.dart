import 'package:dm_table/net/player_app_handler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';

/// Oyuncu paneli APK'ya gercekten gomulmus mu ve servis edilebiliyor mu?
///
/// Bu testin degeri su: panel `tools/build_player_web.dart` ile uretilip
/// pubspec'e kaydediliyor. Kayit eksik kalirsa uygulama derlenir, sunucu
/// calisir, ama oyuncunun tarayicisinda bos ekran cikar. Burasi onu yakalar.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Handler handler;

  setUp(() => handler = createPlayerAppHandler());

  Future<Response> get(String path) async =>
      handler(Request('GET', Uri.parse('http://localhost/$path')));

  Future<int> byteLength(Response response) async {
    final chunks = await response.read().toList();
    return chunks.fold<int>(0, (sum, c) => sum + c.length);
  }

  test('panel pakete gomulmus', () async {
    expect(await isPlayerAppBundled(), isTrue);
  });

  test('kok istegi index.html doner', () async {
    final response = await get('');
    expect(response.statusCode, 200);
    expect(response.headers['content-type'], contains('text/html'));

    final body = await response.readAsString();
    expect(body, contains('<html'));
    // Flutter web onyukleyicisi olmadan panel acilmaz.
    expect(body, contains('flutter_bootstrap.js'));
  });

  test('ana betik dogru tiple servis edilir', () async {
    final response = await get('main.dart.js');
    expect(response.statusCode, 200);
    expect(
      response.headers['content-type'],
      contains('application/javascript'),
    );
    expect(await byteLength(response), greaterThan(100000));
  });

  test('CanvasKit wasm dogru tiple servis edilir', () async {
    final response = await get('canvaskit/canvaskit.wasm');
    expect(response.statusCode, 200);
    // Yanlis MIME tipi tarayicinin wasm'i derlemesini engeller.
    expect(response.headers['content-type'], 'application/wasm');
  });

  test('flutter onyukleyicisi ve manifest mevcut', () async {
    for (final path in [
      'flutter.js',
      'flutter_bootstrap.js',
      'manifest.json',
      'version.json',
    ]) {
      final response = await get(path);
      expect(response.statusCode, 200, reason: '$path bulunamadi');
    }
  });

  test('panelin kendi asset manifesti pakette', () async {
    final response = await get('assets/AssetManifest.bin.json');
    expect(response.statusCode, 200, reason: 'panel asset manifesti eksik');
  });

  test('olmayan dosya 404 doner', () async {
    expect((await get('yok-boyle-bir-sey.js')).statusCode, 404);
  });

  test('asset paketi disina cikilamaz', () async {
    // Uri, `..` parcalarini normalize ettigi icin istek zaten kok altinda
    // kaliyor; yine de proje dosyalari servis edilmemeli.
    final response = await get('../../pubspec.yaml');
    expect(response.statusCode, isNot(200));
  });

  test('panel onbellege alinmaz', () async {
    // Masada "eski surum acildi" hatasi en can sikici olani olurdu.
    expect((await get('')).headers['cache-control'], 'no-cache');
  });

  test('pakete gomulu dosya sayisi makul', () async {
    final count = await countBundledPlayerAssets();
    expect(
      count,
      greaterThan(20),
      reason:
          'pubspec asset kaydi eksik olabilir '
          '(dart run tools/build_player_web.dart)',
    );
  });

  test('index.html gecerli UTF-8', () async {
    expect(await (await get('')).readAsString(), contains('<'));
  });
}
