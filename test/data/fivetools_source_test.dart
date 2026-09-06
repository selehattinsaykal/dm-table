import 'dart:convert';
import 'dart:io';

import 'package:dm_table/data/import/fivetools/fivetools_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Verilen yollara yanit veren, digerlerine 404 donen sahte istemci.
MockClient _client(Map<String, Object> files) => MockClient((request) async {
  final path = request.url.path.replaceFirst(RegExp('^/veri/'), '');
  final body = files[path];
  if (body == null) return http.Response('yok', 404);
  return http.Response(jsonEncode(body), 200);
});

void main() {
  group('FiveToolsSource.discover', () {
    test('index.json ile dagitilan dosyalari bulur', () async {
      final source = FiveToolsSource(
        baseUrl: 'https://ornek/veri',
        client: _client({
          'bestiary/index.json': {'HB': 'bestiary-hb.json'},
          'spells/index.json': {'HB': 'spells-hb.json'},
        }),
      );

      final result = await source.discover();
      expect(result.problem, DiscoveryProblem.none);
      expect(result.files, hasLength(2));
      expect(
        result.files.map((f) => f.path),
        containsAll(['bestiary/bestiary-hb.json', 'spells/spells-hb.json']),
      );
      expect(result.files.first.source, 'HB');
    });

    test('bulunmayan bolumler sessizce atlanir', () async {
      // Yalnizca canavar sunan bir depo GECERLI bir kaynak.
      final source = FiveToolsSource(
        baseUrl: 'https://ornek/veri',
        client: _client({
          'bestiary/index.json': {'HB': 'bestiary-hb.json'},
        }),
      );

      final result = await source.discover();
      expect(result.files.map((f) => f.kind).toSet(), {'monster'});
    });

    test('tek dosyali turleri yoklar', () async {
      final source = FiveToolsSource(
        baseUrl: 'https://ornek/veri',
        client: _client({
          'items.json': {'item': []},
          'feats.json': {'feat': []},
        }),
      );

      final result = await source.discover();
      expect(result.files.map((f) => f.kind).toSet(), {'item', 'feat'});
    });

    test('sondaki egik cizgi cift slas uretmez', () async {
      final source = FiveToolsSource(
        baseUrl: 'https://ornek/veri/',
        client: _client({
          'bestiary/index.json': {'HB': 'b.json'},
        }),
      );
      expect((await source.discover()).files, hasLength(1));
    });
  });

  group('FiveToolsSource kok cozumleme', () {
    test('site koku verilse de data/ klasorunu bulur', () async {
      // Kullanici cogu zaman SITENIN kokunu yapistiriyor; dosyalar
      // `<kok>/data` altinda duruyor.
      final source = FiveToolsSource(
        baseUrl: 'https://ornek/veri',
        client: _client({
          'data/bestiary/index.json': {'HB': 'b.json'},
        }),
      );

      final result = await source.discover();
      expect(result.files, hasLength(1));
      expect(result.resolvedBase, 'https://ornek/veri/data');
    });

    test('adres zaten data/ ise ikinci kez eklenmez', () async {
      final source = FiveToolsSource(
        baseUrl: 'https://ornek/veri/data',
        client: _client({
          'data/bestiary/index.json': {'HB': 'b.json'},
        }),
      );

      final result = await source.discover();
      expect(result.files, hasLength(1));
      expect(result.resolvedBase, 'https://ornek/veri/data');
    });
  });

  group('FiveToolsSource tanilama', () {
    test('bot korumasi engellendi olarak bildirilir', () async {
      // Cloudflare gibi katmanlar tarayici disi istemcilere dogrulama
      // sayfasi donuyor. Engeli ASMIYORUZ; durumu bildiriyoruz.
      final source = FiveToolsSource(
        baseUrl: 'https://ornek/veri',
        client: MockClient(
          (_) async => http.Response(
            '<html>Just a moment...</html>',
            403,
            headers: {'cf-mitigated': 'challenge'},
          ),
        ),
      );

      final result = await source.discover();
      expect(result.files, isEmpty);
      expect(result.problem, DiscoveryProblem.blocked);
      expect(result.status, 403);
    });

    test('200 donen HTML JSON degil olarak bildirilir', () async {
      final source = FiveToolsSource(
        baseUrl: 'https://ornek/veri',
        client: MockClient((_) async => http.Response('<html></html>', 200)),
      );

      final result = await source.discover();
      expect(result.problem, DiscoveryProblem.notJson);
    });

    test('baglanti hatasi ag sorunu olarak bildirilir', () async {
      final source = FiveToolsSource(
        baseUrl: 'https://ornek/veri',
        client: MockClient((_) async => throw const SocketException('yok')),
      );

      final result = await source.discover();
      expect(result.problem, DiscoveryProblem.network);
    });

    test('bos kaynak bulunamadi olarak bildirilir', () async {
      final source = FiveToolsSource(
        baseUrl: 'https://ornek/veri',
        client: _client({}),
      );

      final result = await source.discover();
      expect(result.problem, DiscoveryProblem.notFound);
      expect(result.status, 404);
    });
  });

  group('FiveToolsSource.fetchEntries', () {
    test('tur adiyla anahtarlanmis listeyi okur', () async {
      final source = FiveToolsSource(
        baseUrl: 'https://ornek/veri',
        client: _client({
          'bestiary/b.json': {
            'monster': [
              {'name': 'Goblin'},
            ],
          },
        }),
      );

      final entries = await source.fetchEntries((
        kind: 'monster',
        source: 'HB',
        path: 'bestiary/b.json',
      ));
      expect(entries.single['name'], 'Goblin');
    });

    test('farkli anahtarda ilk listeye duser', () async {
      // Homebrew dosyalari her zaman resmi anahtari kullanmiyor.
      final source = FiveToolsSource(
        baseUrl: 'https://ornek/veri',
        client: _client({
          'x.json': {
            'baseitem': [
              {'name': 'Kilic'},
            ],
          },
        }),
      );

      final entries = await source.fetchEntries((
        kind: 'item',
        source: '',
        path: 'x.json',
      ));
      expect(entries.single['name'], 'Kilic');
    });

    test('bulunamayan dosya bos liste doner', () async {
      final source = FiveToolsSource(
        baseUrl: 'https://ornek/veri',
        client: _client({}),
      );
      expect(
        await source.fetchEntries((
          kind: 'monster',
          source: '',
          path: 'y.json',
        )),
        isEmpty,
      );
    });
  });
}
