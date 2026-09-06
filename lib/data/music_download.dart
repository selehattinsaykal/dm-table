import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Yapıştırılan bağlantının kaynağı.
enum MusicLinkKind {
  /// YouTube (youtube.com, youtu.be, music.youtube.com).
  youtube,

  /// Başka bir http(s) bağlantısı — yt-dlp'nin genel çözücüsüne verilir
  /// (doğrudan .mp3 bağlantıları ve yüzlerce site bu yoldan çalışır).
  other,

  /// Geçerli bir http(s) adresi değil.
  unknown,
}

/// Alan adı gibi görünen bir sunucu adı: en az bir noktayla ayrılmış geçerli
/// etiketler. `Uri.tryParse` "merhaba dunya"yı da ayrıştırıp sunucu adı
/// saydığı için bu ek elek şart — aksi hâlde her serbest metin bağlantı
/// sanılıp yt-dlp'ye gönderilirdi.
final _hostPattern = RegExp(
  r'^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$',
);

/// [raw] bağlantısını sınıflandırır. Şema yazılmamışsa `https://` varsayar.
MusicLinkKind classifyMusicLink(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return MusicLinkKind.unknown;

  final uri = Uri.tryParse(text.contains('://') ? text : 'https://$text');
  if (uri == null || !uri.hasAuthority) return MusicLinkKind.unknown;
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return MusicLinkKind.unknown;
  }

  final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  if (!_hostPattern.hasMatch(host)) return MusicLinkKind.unknown;

  if (host == 'youtube.com' ||
      host == 'youtu.be' ||
      host.endsWith('.youtube.com')) {
    return MusicLinkKind.youtube;
  }
  return MusicLinkKind.other;
}

/// İndirmenin neden yürümediği. Arayüz her biri için ayrı metin gösterir.
enum MusicDownloadError {
  /// yt-dlp kurulu değil (ya da verilen yolda çalışmıyor).
  toolMissing,

  /// Bağlantı http(s) adresi değil.
  badLink,

  /// Sunucu 403 verdi. Çoğunlukla korumalı/erişime kapalı içerik; daha seyrek
  /// olarak eskimiş yt-dlp ya da bölge kısıtı.
  forbidden,

  /// yt-dlp sıfırdan farklı çıktı — ağ hatası, kaldırılmış/özel video, vb.
  failed,
}

/// yt-dlp'nin stderr'inden hata türünü çıkarır.
MusicDownloadError classifyDownloadFailure(String? stderr) {
  final text = stderr?.toLowerCase() ?? '';
  if (text.contains('403') || text.contains('forbidden')) {
    return MusicDownloadError.forbidden;
  }
  return MusicDownloadError.failed;
}

/// `-J` ile okunan künye.
class MusicMetadata {
  const MusicMetadata({
    required this.title,
    required this.durationMs,
    this.channel,
    this.artist,
    this.album,
  });

  final String title;
  final int durationMs;
  final String? channel;
  final String? artist;
  final String? album;
}

class MusicDownloadException implements Exception {
  MusicDownloadException(this.reason, {this.detail});

  final MusicDownloadError reason;

  /// yt-dlp'nin stderr'inden son satır(lar); arayüzde ayrıntı olarak gösterilir.
  final String? detail;

  @override
  String toString() => 'MusicDownloadException(${reason.name}): $detail';
}

/// İndirilmiş ses dosyası + çözülen künye.
///
/// Dosya GEÇİCİ klasördedir; `MusicRepository.addTrack` onu kampanya klasörüne
/// kopyalar. Kopyalama bittikten sonra [dispose] çağrılmalıdır.
class MusicDownloadResult {
  MusicDownloadResult({
    required this.file,
    required this.title,
    required this.durationMs,
    required Directory workDir,
  }) : _workDir = workDir;

  final File file;
  final String title;
  final int durationMs;
  final Directory _workDir;

  Future<void> dispose() async {
    if (_workDir.existsSync()) await _workDir.delete(recursive: true);
  }
}

/// 0..1 arası oran; yt-dlp yüzde bildirmiyorsa `null` (belirsiz ilerleme).
typedef MusicDownloadProgress = void Function(double? ratio);

/// Bir bağlantıdan ses indirir.
///
/// YouTube ve yt-dlp'nin çözebildiği diğer siteler için **yt-dlp** kullanır.
/// Uygulama bu aracı PAKETLEMEZ: kullanıcının kendi kurduğu komut PATH'te
/// (ya da Ayarlar'da verilen yolda) aranır. Bilinçli bir tercih — bu araç
/// ayrı lisanslı, sık güncellenir ve neyin indirileceğinin sorumluluğu
/// kullanıcıdadır.
///
/// Ses **yeniden kodlanmaz**: `bestaudio` akışı olduğu gibi alınır (YouTube'da
/// genelde `.m4a`). Böylece ffmpeg'e gerek kalmaz ve kalite
/// kaybı olmaz — libmpv (media_kit) bu kapları zaten çalar.
class MusicDownloader {
  MusicDownloader({this.executablePath});

  /// Ayarlarda elle verilen yt-dlp yolu; boşsa PATH'e bakılır.
  final String? executablePath;

  /// PATH'te denenecek adlar. `.cmd`/`.bat` sarmalayıcıları kabul edilmez:
  /// onları çalıştırmak kabuk gerektirir, kabuğa yapıştırılan bağlantıyı
  /// geçirmek ise komut enjeksiyonuna açık olurdu.
  static const _names = ['yt-dlp', 'yt-dlp.exe'];

  /// YouTube oynatıcı istemcisi.
  ///
  /// yt-dlp'nin kendi seçtiği `android_vr` istemcisi ses akışını çekerken
  /// **403 Forbidden** alıyor (künye çözülüyor, indirme patlıyor) — DRM'le
  /// ilgisi yok, normal videolarda da oluyor. `android` istemcisi sorunsuz
  /// çalışıyor, o yüzden açıkça seçiliyor.
  ///
  /// YouTube bu tarafı sık değiştirdiği için tek sabit hâlinde tutuldu:
  /// bir gün bu da 403 vermeye başlarsa değiştirilecek tek yer burası.
  static const _playerClient = 'android';

  /// Bu platformda baglanti indirme MUMKUN mu?
  ///
  /// yt-dlp harici bir CALISTIRILABILIR ve `Process` ile cagriliyor. Android
  /// uygulamalari kendi sanal alaninda rastgele ikili calistiramaz, indirici
  /// de yalnizca Windows icin paketleniyor. Ozelligi orada "kurulu degil"
  /// diye gostermek yaniltici olurdu -- hicbir zaman kurulamayacak.
  static bool get supportedHere =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  /// Çalışan yt-dlp komutunu döner; bulunamazsa `null`.
  Future<String?> resolveExecutable() async {
    if (!supportedHere) return null;
    final custom = executablePath?.trim();
    for (final name in [
      if (custom != null && custom.isNotEmpty) custom,
      ..._names,
    ]) {
      try {
        final result = await Process.run(name, ['--version']);
        if (result.exitCode == 0) return name;
      } on ProcessException {
        continue; // sıradaki ada geç
      }
    }

    // Yerel kurulum klasörü (tools/)
    try {
      final appDir = await getApplicationSupportDirectory();
      final localPath = p.join(appDir.path, 'tools', 'yt-dlp.exe');
      if (await File(localPath).exists()) {
        final result = await Process.run(localPath, ['--version']);
        if (result.exitCode == 0) return localPath;
      }
    } catch (_) {
      // yoksa null döner
    }

    return null;
  }

  /// [url] için sesi indirir.
  Future<MusicDownloadResult> download(
    String url, {
    MusicDownloadProgress? onProgress,
  }) async {
    final kind = classifyMusicLink(url);
    if (kind == MusicLinkKind.unknown) {
      throw MusicDownloadException(MusicDownloadError.badLink);
    }

    final exe = await resolveExecutable();
    if (exe == null) {
      throw MusicDownloadException(MusicDownloadError.toolMissing);
    }

    final target = url.trim().contains('://')
        ? url.trim()
        : 'https://${url.trim()}';

    // 1) Önce yalnızca künye: başlık indirme başlamadan görünsün ve kaldırılmış
    //    / özel video gibi hatalar dosya yazılmadan yakalansın.
    final info = await _probe(exe, target);

    final workDir = await Directory.systemTemp.createTemp('dmtable-music-');
    try {
      await _fetch(exe, target, workDir, onProgress);
      final file = _outputFile(workDir);
      if (file == null) {
        throw MusicDownloadException(
          MusicDownloadError.failed,
          detail: 'yt-dlp bir dosya üretmedi.',
        );
      }
      return MusicDownloadResult(
        file: file,
        title: info.title,
        durationMs: info.durationMs,
        workDir: workDir,
      );
    } catch (_) {
      if (workDir.existsSync()) await workDir.delete(recursive: true);
      rethrow;
    }
  }

  /// `-J`: indirmeden künye okur.
  Future<MusicMetadata> _probe(String exe, String url) async {
    final result = await Process.run(exe, [
      '-J',
      '--no-playlist',
      '--no-warnings',
      '--socket-timeout',
      '20',
      '--extractor-args',
      'youtube:player_client=$_playerClient',
      // `--` sonrası her şey konum argümanı: `-` ile başlayan bir bağlantı
      // yt-dlp seçeneği gibi yorumlanamaz.
      '--',
      url,
    ]);
    if (result.exitCode != 0) {
      final detail = _lastLines(result.stderr);
      throw MusicDownloadException(
        classifyDownloadFailure(detail),
        detail: detail,
      );
    }

    try {
      final json = jsonDecode(result.stdout as String) as Map<String, Object?>;
      final title = (json['title'] as String?)?.trim();
      final seconds = json['duration'];
      return MusicMetadata(
        title: title == null || title.isEmpty ? 'Adsız parça' : title,
        durationMs: seconds is num ? (seconds * 1000).round() : 0,
        channel: (json['channel'] as String?)?.trim(),
        artist: (json['artist'] as String?)?.trim(),
        album: (json['album'] as String?)?.trim(),
      );
    } on FormatException catch (e) {
      throw MusicDownloadException(
        MusicDownloadError.failed,
        detail: e.message,
      );
    }
  }

  /// Sesi indirir; `[download] 42.0%` satırlarını [onProgress]'e aktarır.
  Future<void> _fetch(
    String exe,
    String url,
    Directory workDir,
    MusicDownloadProgress? onProgress,
  ) async {
    final process = await Process.start(exe, [
      '-f',
      // m4a varsa onu tercih et (en yaygın, en uyumlu kap); yoksa eldeki en iyi
      // sesi olduğu gibi al.
      'bestaudio[ext=m4a]/bestaudio/best',
      '--no-playlist',
      '--newline',
      '--no-warnings',
      '--retries',
      '3',
      '--socket-timeout',
      '20',
      '--extractor-args',
      'youtube:player_client=$_playerClient',
      '-o',
      p.join(workDir.path, 'audio.%(ext)s'),
      '--',
      url,
    ]);

    final percent = RegExp(r'\[download\]\s+(\d+(?:\.\d+)?)%');
    final progressSub = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          final match = percent.firstMatch(line);
          if (match != null) {
            onProgress?.call(double.parse(match.group(1)!) / 100);
          }
        });

    // stderr'i bekleyen okuyucu olmazsa boru dolduğunda yt-dlp askıda kalır.
    final errors = await process.stderr.transform(utf8.decoder).join();
    final code = await process.exitCode;
    await progressSub.cancel();

    if (code != 0) {
      final detail = _lastLines(errors);
      throw MusicDownloadException(
        classifyDownloadFailure(detail),
        detail: detail,
      );
    }
  }

  /// Geçici klasördeki ses dosyası. Yarım kalan indirme artıkları elenir.
  File? _outputFile(Directory workDir) {
    for (final entity in workDir.listSync()) {
      if (entity is! File) continue;
      final ext = p.extension(entity.path).toLowerCase();
      if (ext == '.part' || ext == '.ytdl') continue;
      return entity;
    }
    return null;
  }

  /// Hata kutusuna sığacak kadarını alır: stderr onlarca satır olabiliyor.
  static String? _lastLines(Object? stderr, {int count = 3}) {
    final text = (stderr as String?)?.trim();
    if (text == null || text.isEmpty) return null;
    final lines = text.split('\n');
    return lines
        .sublist(lines.length > count ? lines.length - count : 0)
        .join('\n');
  }
}
