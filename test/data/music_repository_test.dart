import 'dart:io';

import 'package:dm_table/data/backup_repository.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/music_repository.dart';
import 'package:dm_table/data/music_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Müzik kütüphanesi: dosya kopyalama, listeler ve yedeğe girmesi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory tmp;
  late MusicStore store;
  late MusicRepository music;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    tmp = await Directory.systemTemp.createTemp('dm_music');
    store = MusicStore(directoryOverride: tmp);
    music = MusicRepository(db, store: store);
  });

  tearDown(() async {
    await db.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  /// Gerçek ses kodlamaya gerek yok: depo dosyayı olduğu gibi kopyalıyor.
  File fakeAudio(String name) {
    final file = File(p.join(tmp.path, name));
    file.writeAsBytesSync(List<int>.filled(64, 7));
    return file;
  }

  test('parca eklenince dosya kopyalanir, goreli yol yazilir', () async {
    final id = await music.addTrack(fakeAudio('taverna.mp3'));
    final track = (await music.tracks(all: true)).single;

    expect(track.id, id);
    // Baslik verilmediyse dosya adindan (uzantisiz) turetilir.
    expect(track.title, 'taverna');
    expect(track.path, startsWith('${MusicStore.folder}${p.separator}'));
    expect((await store.resolve(track.path)).existsSync(), isTrue);
  });

  test('parca silinince DOSYASI da silinir', () async {
    final id = await music.addTrack(fakeAudio('savas.mp3'));
    final path = (await music.tracks(all: true)).single.path;
    expect((await store.resolve(path)).existsSync(), isTrue);

    await music.deleteTrack(id);
    expect(await music.tracks(all: true), isEmpty);
    expect((await store.resolve(path)).existsSync(), isFalse);
  });

  test('liste silinince parcalar KALIR, listesiz duser', () async {
    final list = await music.createPlaylist('Savaş');
    await music.addTrack(fakeAudio('a.mp3'), playlistId: list);
    expect(await music.tracks(playlistId: list), hasLength(1));

    await music.deletePlaylist(list);
    expect(await music.playlists(), isEmpty);
    final left = await music.tracks(all: true);
    expect(left, hasLength(1));
    expect(left.single.playlistId, isNull);
    // Dosya duruyor: baslik silmek dosya silmek DEGIL.
    expect((await store.resolve(left.single.path)).existsSync(), isTrue);
  });

  test('moveTrack parcayi listesiz yapabilir', () async {
    final list = await music.createPlaylist('Taverna');
    final id = await music.addTrack(fakeAudio('b.mp3'), playlistId: list);

    await music.moveTrack(id, null);
    expect(await music.tracks(playlistId: list), isEmpty);
    expect(await music.tracks(playlistId: null), hasLength(1));
  });

  test('reorder siralamayi yazar', () async {
    final a = await music.addTrack(fakeAudio('1.mp3'), title: 'A');
    final b = await music.addTrack(fakeAudio('2.mp3'), title: 'B');
    final c = await music.addTrack(fakeAudio('3.mp3'), title: 'C');

    await music.reorder([c, a, b]);
    final titles = [for (final t in await music.tracks(all: true)) t.title];
    expect(titles, ['C', 'A', 'B']);
  });

  test('muzik dosyalari yedege girer ve geri yuklenir', () async {
    final list = await music.createPlaylist('Gerilim');
    await music.addTrack(
      fakeAudio('korku.mp3'),
      playlistId: list,
      title: 'Korku',
    );

    final backup = BackupRepository(db, music: store);
    final bytes = await backup.export();

    // Kutuphaneyi ve dosyalari tamamen yok et.
    final path = (await music.tracks(all: true)).single.path;
    await music.deleteTrack((await music.tracks(all: true)).single.id);
    await music.deletePlaylist(list);
    expect((await store.resolve(path)).existsSync(), isFalse);

    await backup.import(bytes);

    final restored = await music.tracks(all: true);
    expect(restored, hasLength(1));
    expect(restored.single.title, 'Korku');
    expect(await music.playlists(), hasLength(1));
    expect((await store.resolve(restored.single.path)).existsSync(), isTrue);
  });
}
