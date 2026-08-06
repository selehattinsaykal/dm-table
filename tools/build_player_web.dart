// Oyuncu panelini web'e derler ve DM uygulamasina gomulecek hale getirir.
//
//   dart run tools/build_player_web.dart
//
// Cikti `assets/player_web/` altina yazilir ve pubspec uzerinden APK'ya
// gomulur; DM cihazi bunu LAN'da servis eder. Internet baglantisi
// gerekmedigi icin CanvasKit de paketin icinde tasinir.
//
// Derleme sonrasi calisma zamaninda gereksiz dosyalar budanir: `.js.symbols`
// yalnizca yigin izi cozumlemesi icindir ve tek basina ~8 MB tutuyor.

import 'dart:io';

const _outputDir = 'assets/player_web';

Future<void> main() async {
  // Onemli: derlemeden once hem cikti klasoru hem de pubspec'teki kaydi
  // temizleniyor. Aksi halde `assets/player_web/` uygulama asset'i olarak
  // tanimli oldugu icin web derlemesi kendi onceki kopyasini icine gomuyor
  // ve paket her derlemede ikiye katlaniyor.
  _clearPubspecAssets();
  final outDir = Directory(_outputDir);
  if (outDir.existsSync()) outDir.deleteSync(recursive: true);

  stdout.writeln('Oyuncu paneli derleniyor...');

  final build = await Process.run('flutter', [
    'build',
    'web',
    '-t',
    'lib/main_player.dart',
    '--output=$_outputDir',
    '--release',
    '--no-wasm-dry-run',
    // Service worker KAPALI: aksi halde telefon paneli onbellekten aciyor ve
    // panel duzeltmeleri cihaza hic ulasmiyor (no-cache basligini SW eziyor).
    '--pwa-strategy=none',
  ], runInShell: true);

  if (build.exitCode != 0) {
    stderr
      ..writeln(build.stdout)
      ..writeln(build.stderr);
    exit(build.exitCode);
  }

  final dir = Directory(_outputDir);
  if (!dir.existsSync()) {
    stderr.writeln('Beklenen cikti bulunamadi: $_outputDir');
    exit(1);
  }

  var removed = 0;
  var freed = 0;

  // Oyuncu panelinde KULLANILMAYAN, ama bagimlilik agacinda oldugu icin her web
  // derlemesine giren asset klasorleri. Panel (main_player) media_kit/wakelock
  // KULLANMIYOR (yalnizca DM'in Kayitlar video blogu icin). CanvasKit sabit
  // renderer oldugu icin skwasm cesitleri ve deneysel varyant da hic yuklenmez.
  const prunedDirs = [
    'assets/packages/media_kit',
    'assets/packages/wakelock_plus',
    'canvaskit/experimental_webparagraph',
  ];
  // CanvasKit-sabit modda hic istenmeyen skwasm renderer dosyalari.
  const prunedFiles = ['skwasm.wasm', 'skwasm_heavy.wasm'];

  int sizeOf(Directory d) => d
      .listSync(recursive: true)
      .whereType<File>()
      .fold<int>(0, (s, f) => s + f.lengthSync());

  for (final rel in prunedDirs) {
    final d = Directory('$_outputDir/$rel');
    if (d.existsSync()) {
      freed += sizeOf(d);
      removed += d.listSync(recursive: true).whereType<File>().length;
      d.deleteSync(recursive: true);
    }
  }

  for (final entity in dir.listSync(recursive: true)) {
    if (entity is! File) continue;
    final name = entity.path.replaceAll('\\', '/').split('/').last;
    // `.last_build_id` her derlemede degisip gereksiz fark uretiyor;
    // `.js.symbols` yalniz yigin izi cozumu icin; skwasm* CanvasKit'te
    // kullanilmaz.
    if (name.endsWith('.js.symbols') ||
        name == '.last_build_id' ||
        prunedFiles.contains(name)) {
      freed += entity.lengthSync();
      entity.deleteSync();
      removed++;
    }
  }

  final total = dir
      .listSync(recursive: true)
      .whereType<File>()
      .fold<int>(0, (sum, f) => sum + f.lengthSync());

  final declared = _syncPubspecAssets(dir);

  stdout
    ..writeln(
      '$removed gereksiz dosya silindi '
      '(${(freed / 1024 / 1024).toStringAsFixed(1)} MB)',
    )
    ..writeln('pubspec.yaml: $declared dizin kaydedildi')
    ..writeln(
      'Paketlenecek boyut: ${(total / 1024 / 1024).toStringAsFixed(1)} MB',
    );
}

const _begin = '    # >>> player_web';
const _end = '    # <<< player_web';

/// Derleme oncesi kaydi bosaltir; boylece panel kendini icine gomemez.
void _clearPubspecAssets() {
  final pubspec = File('pubspec.yaml');
  final lines = pubspec.readAsLinesSync();
  final start = lines.indexWhere((l) => l.trimRight() == _begin);
  final stop = lines.indexWhere((l) => l.trimRight() == _end);
  if (start < 0 || stop < 0 || stop < start) return;

  pubspec.writeAsStringSync(
    [...lines.take(start + 1), ...lines.skip(stop)].join('\n'),
  );
}

/// `pubspec.yaml` icindeki player_web asset listesini gercek klasor yapisiyla
/// esitler.
///
/// Flutter bir asset dizinini yalnizca dogrudan icindeki dosyalar icin
/// paketler; alt klasorler ayri satir ister. Elle tutulunca Flutter surumu
/// cikti yapisini degistirdiginde sessizce eksik dosya paketleniyor ve panel
/// tarayicida bos ekran veriyor -- o yuzden liste burada uretiliyor.
int _syncPubspecAssets(Directory dir) {
  final pubspec = File('pubspec.yaml');
  final lines = pubspec.readAsLinesSync();
  final start = lines.indexWhere((l) => l.trimRight() == _begin);
  final stop = lines.indexWhere((l) => l.trimRight() == _end);
  if (start < 0 || stop < 0 || stop < start) {
    throw StateError('pubspec.yaml icinde player_web isaretleri bulunamadi');
  }

  final directories = <String>{_relative(dir.path)};
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is Directory) directories.add(_relative(entity.path));
  }
  final sorted = directories.toList()..sort();

  pubspec.writeAsStringSync(
    [
      ...lines.take(start + 1),
      for (final d in sorted) '    - $d/',
      ...lines.skip(stop),
    ].join('\n'),
  );
  return sorted.length;
}

String _relative(String path) => path
    .replaceAll('\\', '/')
    .replaceFirst(RegExp('^.*?(?=assets/player_web)'), '');
