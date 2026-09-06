import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../data/music_download.dart';
import 'music_controller.dart';
import 'tool_installer.dart';

/// yt-dlp'nin elle verilen yolu. Boşsa PATH'e bakılır.
///
/// `AiSettingsController` ile aynı desen: `shared_preferences`, cihazda kalır,
/// yedeğe girmez. Windows'ta PATH sık sık ayarsız kaldığı için "Ayarlar'a tam
/// yolu yapıştır" kaçış yolu şart.
class YtDlpPathController extends Notifier<String> {
  static const _key = 'music.ytDlpPath';

  bool _touched = false;

  @override
  String build() {
    _load();
    return '';
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (_touched) return;
    state = prefs.getString(_key) ?? '';
  }

  Future<void> set(String path) async {
    _touched = true;
    state = path.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, state);
  }
}

final ytDlpPathProvider = NotifierProvider<YtDlpPathController, String>(
  YtDlpPathController.new,
);

final musicDownloaderProvider = Provider<MusicDownloader>(
  (ref) => MusicDownloader(executablePath: ref.watch(ytDlpPathProvider)),
);

/// yt-dlp kullanılabilir mi?
///
/// [toolInstallerProvider] izleniyor: kurulum bitince bu değer kendiliğinden
/// yeniden hesaplanır, yani ayarlardan kurulum yapılınca bağlantı kutusundaki
/// "kurulu değil" uyarısı elle tazelemeye gerek kalmadan kaybolur.
final ytDlpAvailableProvider = FutureProvider<bool>((ref) async {
  ref.watch(toolInstallerProvider);
  return await ref.watch(musicDownloaderProvider).resolveExecutable() != null;
});

/// Baglantidan indirme bu platformda VAR MI?
///
/// [ytDlpAvailableProvider] "kurulu mu" sorusunu cevapliyor; bu ise "hic
/// kurulabilir mi". Android'de ikincisi hayir, o yuzden arayuz kurulum
/// yonergesi degil ozelligin kendisini gizliyor.
final musicDownloadSupportedProvider = Provider<bool>(
  (ref) => MusicDownloader.supportedHere,
);

enum MusicJobStatus { queued, running, done, failed }

/// Kuyruktaki tek bir indirme.
class MusicDownloadJob {
  const MusicDownloadJob({
    required this.id,
    required this.url,
    required this.label,
    required this.status,
    this.playlistId,
    this.progress,
    this.error,
    this.detail,
  });

  final String id;
  final String url;

  /// Künye çözülene kadar bağlantının kendisi, sonra parça başlığı.
  final String label;

  final MusicJobStatus status;
  final String? playlistId;

  /// 0..1; yt-dlp yüzde bildirmiyorsa `null`.
  final double? progress;

  final MusicDownloadError? error;
  final String? detail;

  MusicDownloadJob copyWith({
    String? label,
    MusicJobStatus? status,
    double? progress,
    MusicDownloadError? error,
    String? detail,
  }) => MusicDownloadJob(
    id: id,
    url: url,
    label: label ?? this.label,
    status: status ?? this.status,
    playlistId: playlistId,
    progress: progress,
    error: error ?? this.error,
    detail: detail ?? this.detail,
  );
}

/// Bağlantıdan indirme kuyruğu.
///
/// İşler **sırayla** yürütülür: aynı anda beş akış çekmek ne kullanıcıya ne de
/// kaynak siteye bir şey kazandırır, hata ayıklamayı zorlaştırır.
class MusicDownloadQueue extends Notifier<List<MusicDownloadJob>> {
  static const _uuid = Uuid();

  bool _pumping = false;

  @override
  List<MusicDownloadJob> build() => const [];

  /// Kuyruğa ekler ve (çalışmıyorsa) işlemeyi başlatır.
  void enqueue(String url, {String? playlistId}) {
    final job = MusicDownloadJob(
      id: 'mdl-${_uuid.v4()}',
      url: url.trim(),
      label: url.trim(),
      status: MusicJobStatus.queued,
      playlistId: playlistId,
    );
    state = [...state, job];
    unawaited(_pump());
  }

  /// Biten/başarısız bir satırı listeden kaldırır.
  void dismiss(String id) {
    state = [
      for (final job in state)
        if (job.id != id) job,
    ];
  }

  void clearFinished() {
    state = [
      for (final job in state)
        if (job.status == MusicJobStatus.queued ||
            job.status == MusicJobStatus.running)
          job,
    ];
  }

  Future<void> _pump() async {
    if (_pumping) return;
    _pumping = true;
    try {
      while (true) {
        final next = state
            .where((j) => j.status == MusicJobStatus.queued)
            .firstOrNull;
        if (next == null) return;
        await _run(next);
      }
    } finally {
      _pumping = false;
    }
  }

  Future<void> _run(MusicDownloadJob job) async {
    _update(job.id, (j) => j.copyWith(status: MusicJobStatus.running));

    final downloader = ref.read(musicDownloaderProvider);
    MusicDownloadResult? result;
    try {
      result = await downloader.download(
        job.url,
        onProgress: (ratio) =>
            _update(job.id, (j) => j.copyWith(progress: ratio)),
      );
      await ref
          .read(musicRepositoryProvider)
          .addTrack(
            result.file,
            title: result.title,
            playlistId: job.playlistId,
            durationMs: result.durationMs,
          );
      _update(
        job.id,
        (j) => j.copyWith(
          label: result!.title,
          status: MusicJobStatus.done,
          progress: 1,
        ),
      );
    } on MusicDownloadException catch (e) {
      _update(
        job.id,
        (j) => j.copyWith(
          status: MusicJobStatus.failed,
          error: e.reason,
          detail: e.detail,
        ),
      );
    } catch (e) {
      _update(
        job.id,
        (j) => j.copyWith(
          status: MusicJobStatus.failed,
          error: MusicDownloadError.failed,
          detail: '$e',
        ),
      );
    } finally {
      // Geçici klasör her durumda silinir; dosya bu noktada kampanya
      // klasörüne kopyalanmış oluyor.
      await result?.dispose();
    }
  }

  void _update(
    String id,
    MusicDownloadJob Function(MusicDownloadJob) transform,
  ) {
    state = [
      for (final job in state)
        if (job.id == id) transform(job) else job,
    ];
  }
}

final musicDownloadQueueProvider =
    NotifierProvider<MusicDownloadQueue, List<MusicDownloadJob>>(
      MusicDownloadQueue.new,
    );
