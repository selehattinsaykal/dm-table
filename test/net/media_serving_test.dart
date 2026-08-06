import 'dart:convert';
import 'dart:io';

import 'package:dm_table/data/character_repository.dart';
import 'package:dm_table/data/combat_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/import/asset_importer.dart';
import 'package:dm_table/data/map_image_store.dart';
import 'package:dm_table/data/shop_repository.dart';
import 'package:dm_table/data/world_repository.dart';
import 'package:dm_table/features/session/session_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// Oyuncunun tarayicisi haritayi gercekten indirebiliyor mu?
///
/// Rapor: "oyuncular haritayi goremiyor". Gorsel LAN uzerinden `/media/...`
/// yolundan servis ediliyor; burasi gercek sunucu + gercek dosyayla ham
/// soket uzerinden indirilebildigini dogrular (TestWidgetsFlutterBinding
/// HttpClient'i sahteledigi icin ham soket sart).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SessionService session;
  late Directory tempDir;
  late String locationId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await AssetImporter(db).importIfNeeded();
    tempDir = await Directory.systemTemp.createTemp('dm_masasi_media');
    final images = MapImageStore(directoryOverride: tempDir);
    final world = WorldRepository(db, images: images);

    session = SessionService(
      db: db,
      characters: CharacterRepository(db),
      combat: CombatRepository(db),
      shops: ShopRepository(db),
      world: world,
    );

    locationId = await world.createLocation(name: 'Yıkık Kale');
    final source = File(p.join(tempDir.path, 'harita.png'));
    final image = img.Image(width: 1200, height: 800);
    img.fill(image, color: img.ColorRgb8(50, 70, 90));
    await source.writeAsBytes(img.encodePng(image));
    await world.setMapImage(locationId, source);
    // Gorunurluk artik lokasyon bazli: "Oyunculara göster" = revealed.
    await world.updateLocation(locationId, revealed: true);
    await session.start();
  });

  tearDown(() async {
    await session.stop();
    await db.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Uri baseUri() => Uri.parse('http://127.0.0.1:${session.server!.port}');

  test('snapshot haritanin gorsel URL\'sini icerir', () async {
    final map = (await session.buildSnapshot()).maps.single;
    expect(map.imageUrl, isNotNull);
    expect(map.imageUrl, startsWith('/media/'));
    expect(map.aspectRatio, closeTo(1.5, 0.01)); // 1200/800
  });

  test('harita gorseli LAN üzerinden indirilebilir', () async {
    final map = (await session.buildSnapshot()).maps.single;
    final res = await _rawGet(baseUri(), map.imageUrl!);

    expect(res.status, 200, reason: 'harita servis edilmedi');
    expect(res.contentType, anyOf(contains('image/'), isNotEmpty));
    expect(res.byteCount, greaterThan(1000), reason: 'boş görsel geldi');
  });

  test('gorsel Content-Length ile sunulur (chunked degil)', () async {
    // Mobil tarayici chunked + keep-alive'da cevabin bittigini yakalayamayip
    // istegi sonsuza dek "beklemede" tutabiliyordu. Sabit uzunluk cerceveleme
    // her tarayicida kesin: govde akis degil, bilinen uzunlukta gitmeli.
    final map = (await session.buildSnapshot()).maps.single;
    final res = await _rawGet(baseUri(), map.imageUrl!);

    expect(res.contentLength, isNotNull, reason: 'Content-Length yok');
    expect(
      res.contentLength,
      res.byteCount,
      reason: 'uzunluk gövdeyle uyuşmuyor',
    );
    expect(
      res.transferEncoding.toLowerCase(),
      isNot(contains('chunked')),
      reason: 'chunked kodlama mobilde asılı kalabiliyor',
    );
  });

  test('olmayan medya 404 döner, çökmez', () async {
    final res = await _rawGet(baseUri(), '/media/yok-boyle-dosya.jpg');
    expect(res.status, 404);
  });

  test('medya yolundan üst dizine çıkılamaz', () async {
    final res = await _rawGet(baseUri(), '/media/..%2F..%2Fpubspec.yaml');
    expect(res.status, isNot(200));
  });
}

Future<
  ({
    int status,
    String contentType,
    int byteCount,
    int? contentLength,
    String transferEncoding,
  })
>
_rawGet(Uri base, String path) async {
  final socket = await Socket.connect(base.host, base.port);
  socket.write(
    'GET $path HTTP/1.1\r\n'
    'Host: ${base.host}:${base.port}\r\n'
    'Connection: close\r\n\r\n',
  );
  await socket.flush();

  final bytes = <int>[];
  await for (final chunk in socket) {
    bytes.addAll(chunk);
  }
  socket.destroy();

  final headEnd = _indexOfCrlfCrlf(bytes);
  final head = latin1.decode(
    bytes.sublist(0, headEnd < 0 ? bytes.length : headEnd),
  );
  final bodyLen = headEnd < 0 ? 0 : bytes.length - headEnd - 4;

  final status =
      int.tryParse(
        RegExp(r'HTTP/1\.\d (\d{3})').firstMatch(head)?.group(1) ?? '',
      ) ??
      0;
  final contentType =
      RegExp(
        r'content-type:\s*(.+)',
        caseSensitive: false,
      ).firstMatch(head)?.group(1)?.trim() ??
      '';
  final contentLength = int.tryParse(
    RegExp(
          r'content-length:\s*(\d+)',
          caseSensitive: false,
        ).firstMatch(head)?.group(1) ??
        '',
  );
  final transferEncoding =
      RegExp(
        r'transfer-encoding:\s*(.+)',
        caseSensitive: false,
      ).firstMatch(head)?.group(1)?.trim() ??
      '';

  return (
    status: status,
    contentType: contentType,
    byteCount: bodyLen,
    contentLength: contentLength,
    transferEncoding: transferEncoding,
  );
}

int _indexOfCrlfCrlf(List<int> bytes) {
  for (var i = 0; i < bytes.length - 3; i++) {
    if (bytes[i] == 13 &&
        bytes[i + 1] == 10 &&
        bytes[i + 2] == 13 &&
        bytes[i + 3] == 10) {
      return i;
    }
  }
  return -1;
}
