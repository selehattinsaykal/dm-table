import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import '../../data/db/database.dart';
import '../../data/music_repository.dart';
import '../../data/music_store.dart';
import '../../data/providers.dart';

final musicRepositoryProvider = Provider<MusicRepository>(
  (ref) => MusicRepository(ref.watch(databaseProvider)),
);

final musicPlaylistsProvider = StreamProvider<List<MusicPlaylist>>(
  (ref) => ref.watch(musicRepositoryProvider).watchPlaylists(),
);

/// Bir listenin parçaları. `null` aile anahtarı = listesiz parçalar.
final musicTracksProvider = StreamProvider.family<List<MusicTrack>, String?>(
  (ref, playlistId) =>
      ref.watch(musicRepositoryProvider).watchTracks(playlistId: playlistId),
);

/// TÜM parçalar (liste farkı gözetmeden).
///
/// Kategori görünümü aynı anda birden çok alt listenin parçalarını çizdiği
/// için gerekli: her alt liste için ayrı bir aile sağlayıcısı izlemek yerine
/// tek akış alınıp bellekte gruplanıyor.
final allMusicTracksProvider = StreamProvider<List<MusicTrack>>(
  (ref) => ref.watch(musicRepositoryProvider).watchTracks(all: true),
);

/// Tekrar biçimi: kapalı, tüm liste, yalnız o an çalan tek parça.
enum MusicLoopMode { off, all, one }

/// Çalma durumu. Konum/süre saniyede birkaç kez değiştiği için ayrı tutulmadı:
/// tek kayıt hâlinde yayınlanıp arayüzde tek yerde dinleniyor.
typedef MusicState = ({
  MusicTrack? track,
  bool playing,
  double volume,
  Duration position,
  Duration duration,
  MusicLoopMode loopMode,
  bool missing,
});

const MusicState _idle = (
  track: null,
  playing: false,
  volume: 0.7,
  position: Duration.zero,
  duration: Duration.zero,
  loopMode: MusicLoopMode.all,
  missing: false,
);

/// Müzik çalar.
///
/// media_kit kullanılıyor: **projede zaten var** (Kayıtlar video bloğu için) ve
/// hem Windows hem Android'de ses çalar; ses efektleri için eskiden eklenen
/// `audioplayers` bağımlılığı kaldırılmıştı, geri getirilmedi.
///
/// `Player` **tembel** kuruluyor: ilk çalma isteğine kadar hiç native kaynak
/// açılmaz — uygulama açılışını yavaşlatmaz ve widget testleri native
/// kütüphaneye hiç dokunmaz.
class MusicController extends Notifier<MusicState> {
  Player? _player;
  final _subs = <StreamSubscription<Object?>>[];

  /// Sıradaki parçalar (çalmaya başlanan listenin o anki hâli).
  List<MusicTrack> _queue = const [];
  int _index = -1;

  @override
  MusicState build() {
    ref.onDispose(_disposePlayer);
    return _idle;
  }

  MusicStore get _store => ref.read(musicRepositoryProvider).store;

  Player _ensurePlayer() {
    final existing = _player;
    if (existing != null) return existing;

    final player = Player();
    _player = player;
    _subs.addAll([
      player.stream.playing.listen((v) {
        state = (
          track: state.track,
          playing: v,
          volume: state.volume,
          position: state.position,
          duration: state.duration,
          loopMode: state.loopMode,
          missing: false,
        );
      }),
      player.stream.position.listen((v) {
        state = (
          track: state.track,
          playing: state.playing,
          volume: state.volume,
          position: v,
          duration: state.duration,
          loopMode: state.loopMode,
          missing: state.missing,
        );
      }),
      player.stream.duration.listen((v) {
        state = (
          track: state.track,
          playing: state.playing,
          volume: state.volume,
          position: state.position,
          duration: v,
          loopMode: state.loopMode,
          missing: state.missing,
        );
      }),
      // Parça bitince sıradakine geç; son parçadan sonra döngü açıksa başa
      // sarar, kapalıysa durur.
      player.stream.completed.listen((done) {
        if (done) unawaited(next(auto: true));
      }),
    ]);
    unawaited(player.setVolume(state.volume * 100));
    return player;
  }

  void _disposePlayer() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _subs.clear();
    unawaited(_player?.dispose());
    _player = null;
  }

  /// [queue] içindeki [track]'i çalar. Sıradaki/önceki bu listeye göre işler.
  Future<void> play(
    MusicTrack track, {
    List<MusicTrack> queue = const [],
  }) async {
    _queue = queue.isEmpty ? [track] : queue;
    _index = _queue.indexWhere((t) => t.id == track.id);
    if (_index < 0) _index = 0;

    final file = await _store.resolve(track.path);
    if (!file.existsSync()) {
      // Dosya elle silinmis olabilir; kayit duruyor ama calinamiyor.
      state = (
        track: track,
        playing: false,
        volume: state.volume,
        position: Duration.zero,
        duration: Duration.zero,
        loopMode: state.loopMode,
        missing: true,
      );
      return;
    }

    state = (
      track: track,
      playing: true,
      volume: state.volume,
      position: Duration.zero,
      duration: Duration.zero,
      loopMode: state.loopMode,
      missing: false,
    );
    await _ensurePlayer().open(Media(file.path));
  }

  Future<void> toggle() async {
    final player = _player;
    if (player == null || state.track == null) return;
    if (state.playing) {
      await player.pause();
    } else {
      await player.play();
    }
  }

  /// Tamamen durdurur: konum sıfırlanır, "şu an çalan" temizlenir.
  Future<void> stop() async {
    await _player?.stop();
    state = (
      track: null,
      playing: false,
      volume: state.volume,
      position: Duration.zero,
      duration: Duration.zero,
      loopMode: state.loopMode,
      missing: false,
    );
  }

  /// [auto] otomatik geçiş (parça bitti) — DM elle "sonraki"ye bastıysa her
  /// zaman listede ilerler; parça kendiliğinden bittiğinde tekrar biçimine
  /// bakılır: [MusicLoopMode.one] AYNI parçayı yeniden başlatır (listede
  /// ilerlemez), [MusicLoopMode.off] listenin sonunda durur.
  Future<void> next({bool auto = false}) async {
    if (_queue.isEmpty) return;

    if (auto && state.loopMode == MusicLoopMode.one) {
      await play(_queue[_index], queue: _queue);
      return;
    }

    final last = _index >= _queue.length - 1;
    if (last && auto && state.loopMode == MusicLoopMode.off) {
      await stop();
      return;
    }
    final i = last ? 0 : _index + 1;
    await play(_queue[i], queue: _queue);
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;
    // Parça 3 saniyeden ilerideyse "onceki" once basa sarar (alisildik davranis).
    if (state.position.inSeconds > 3 && state.track != null) {
      await play(state.track!, queue: _queue);
      return;
    }
    final i = _index <= 0 ? _queue.length - 1 : _index - 1;
    await play(_queue[i], queue: _queue);
  }

  Future<void> seek(Duration to) async {
    if (_player == null || state.track == null) return;
    await _player!.seek(to);
  }

  Future<void> setVolume(double value) async {
    final v = value.clamp(0.0, 1.0);
    state = (
      track: state.track,
      playing: state.playing,
      volume: v,
      position: state.position,
      duration: state.duration,
      loopMode: state.loopMode,
      missing: state.missing,
    );
    await _player?.setVolume(v * 100);
  }

  void setLoopMode(MusicLoopMode value) {
    state = (
      track: state.track,
      playing: state.playing,
      volume: state.volume,
      position: state.position,
      duration: state.duration,
      loopMode: value,
      missing: state.missing,
    );
  }

  /// Silinen parça çalıyorsa çalmayı durdurur (aksi hâlde olmayan dosyayı
  /// çalmaya devam etmiş gibi görünürdü).
  Future<void> forgetIfPlaying(String trackId) async {
    if (state.track?.id == trackId) await stop();
    _queue = [
      for (final t in _queue)
        if (t.id != trackId) t,
    ];
  }
}

final musicControllerProvider = NotifierProvider<MusicController, MusicState>(
  MusicController.new,
);

/// Ortam sesi (ambians) katmani.
///
/// AYRI bir calar: yagmur, magara yankisi ya da meydan ugultusu MUZIKLE
/// AYNI ANDA calmali. Tek calarla bunu yapmak "muzigi durdur, ambiansi ac"
/// demekti; masada iki katman bir arada duruyor ve ikisinin sesi ayri
/// ayarlaniyor.
///
/// Daima DONGUDE: ortam sesi bitmez, sahne surdugu surece devam eder.
typedef AmbienceState = ({MusicTrack? track, bool playing, double volume});

const _ambienceIdle = (track: null, playing: false, volume: 0.35);

class AmbienceController extends Notifier<AmbienceState> {
  Player? _player;
  final _subs = <StreamSubscription<Object?>>[];

  @override
  AmbienceState build() {
    ref.onDispose(_dispose);
    return _ambienceIdle;
  }

  MusicStore get _store => ref.read(musicRepositoryProvider).store;

  Player _ensurePlayer() {
    final existing = _player;
    if (existing != null) return existing;
    final player = Player();
    _player = player;
    _subs.add(
      player.stream.playing.listen(
        (v) => state = (track: state.track, playing: v, volume: state.volume),
      ),
    );
    // Ortam sesi bitince basa sarar; "playlist" kavrami yok.
    _subs.add(
      player.stream.completed.listen((done) {
        if (done && state.track != null) unawaited(player.seek(Duration.zero));
      }),
    );
    unawaited(player.setPlaylistMode(PlaylistMode.single));
    unawaited(player.setVolume(state.volume * 100));
    return player;
  }

  void _dispose() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _subs.clear();
    unawaited(_player?.dispose());
    _player = null;
  }

  Future<void> play(MusicTrack track) async {
    final file = await _store.resolve(track.path);
    if (!file.existsSync()) return;
    state = (track: track, playing: true, volume: state.volume);
    final player = _ensurePlayer();
    await player.setPlaylistMode(PlaylistMode.single);
    await player.open(Media(file.path));
  }

  Future<void> toggle() async {
    final player = _player;
    if (player == null || state.track == null) return;
    if (state.playing) {
      await player.pause();
    } else {
      await player.play();
    }
  }

  Future<void> stop() async {
    await _player?.stop();
    state = (track: null, playing: false, volume: state.volume);
  }

  Future<void> setVolume(double value) async {
    final volume = value.clamp(0.0, 1.0);
    state = (track: state.track, playing: state.playing, volume: volume);
    await _player?.setVolume(volume * 100);
  }
}

final ambienceControllerProvider =
    NotifierProvider<AmbienceController, AmbienceState>(AmbienceController.new);
