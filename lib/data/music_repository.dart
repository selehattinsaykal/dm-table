import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'db/database.dart';
import 'music_store.dart';

/// Müzik kütüphanesi: listeler (başlıklar) + parçalar.
///
/// Dosyalar `music/` klasörüne kopyalanır, kayıtlar veritabanında durur —
/// böylece yedek/geri yükleme kütüphaneyi olduğu gibi taşır. Kaynak dosya
/// sonradan silinse bile çalma bozulmaz.
class MusicRepository {
  MusicRepository(this.db, {MusicStore? store}) : store = store ?? MusicStore();

  final AppDatabase db;
  final MusicStore store;

  static const _uuid = Uuid();

  // --- Listeler ------------------------------------------------------------

  Stream<List<MusicPlaylist>> watchPlaylists() =>
      (db.select(db.musicPlaylists)..orderBy([
            (t) => OrderingTerm(expression: t.sortOrder),
            (t) => OrderingTerm(expression: t.createdAt),
          ]))
          .watch();

  Future<List<MusicPlaylist>> playlists() => (db.select(
    db.musicPlaylists,
  )..orderBy([(t) => OrderingTerm(expression: t.sortOrder)])).get();

  Future<String> createPlaylist(String name) async {
    final id = 'mpl-${_uuid.v4()}';
    final count = (await playlists()).length;
    await db
        .into(db.musicPlaylists)
        .insert(
          MusicPlaylistsCompanion.insert(
            id: id,
            name: name,
            sortOrder: Value(count),
          ),
        );
    return id;
  }

  Future<void> renamePlaylist(String id, String name) =>
      (db.update(db.musicPlaylists)..where((t) => t.id.equals(id))).write(
        MusicPlaylistsCompanion(name: Value(name)),
      );

  /// Listeyi siler. **Parçalar silinmez**, listesiz duruma düşer: dosyaları
  /// yanlışlıkla kaybetmek, bir başlığı yanlışlıkla silmekten çok daha pahalı.
  Future<void> deletePlaylist(String id) async {
    await db.transaction(() async {
      await (db.update(db.musicTracks)..where((t) => t.playlistId.equals(id)))
          .write(const MusicTracksCompanion(playlistId: Value(null)));
      await (db.delete(db.musicPlaylists)..where((t) => t.id.equals(id))).go();
    });
  }

  // --- Parçalar ------------------------------------------------------------

  /// [playlistId] `null` verilirse TÜM parçalar döner (liste filtresi yok).
  Stream<List<MusicTrack>> watchTracks({String? playlistId, bool all = false}) {
    final q = db.select(db.musicTracks)
      ..orderBy([
        (t) => OrderingTerm(expression: t.sortOrder),
        (t) => OrderingTerm(expression: t.createdAt),
      ]);
    if (!all) {
      if (playlistId == null) {
        q.where((t) => t.playlistId.isNull());
      } else {
        q.where((t) => t.playlistId.equals(playlistId));
      }
    }
    return q.watch();
  }

  Future<List<MusicTrack>> tracks({String? playlistId, bool all = false}) {
    final q = db.select(db.musicTracks)
      ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]);
    if (!all) {
      if (playlistId == null) {
        q.where((t) => t.playlistId.isNull());
      } else {
        q.where((t) => t.playlistId.equals(playlistId));
      }
    }
    return q.get();
  }

  /// Dosyayı kütüphaneye ekler (kopyalar + kayıt açar).
  ///
  /// [title] verilmezse dosya adı (uzantısız) başlık olur.
  Future<String> addTrack(
    File source, {
    String? title,
    String? playlistId,
    int durationMs = 0,
  }) async {
    final relative = await store.store(source);
    final id = 'mtr-${_uuid.v4()}';
    final count = (await tracks(playlistId: playlistId)).length;
    await db
        .into(db.musicTracks)
        .insert(
          MusicTracksCompanion.insert(
            id: id,
            title: title?.trim().isNotEmpty == true
                ? title!.trim()
                : p.basenameWithoutExtension(source.path),
            path: relative,
            playlistId: Value(playlistId),
            durationMs: Value(durationMs),
            sortOrder: Value(count),
          ),
        );
    return id;
  }

  Future<void> updateTrack(
    String id, {
    String? title,
    int? durationMs,
    int? sortOrder,
  }) => (db.update(db.musicTracks)..where((t) => t.id.equals(id))).write(
    MusicTracksCompanion(
      title: title == null ? const Value.absent() : Value(title),
      durationMs: durationMs == null ? const Value.absent() : Value(durationMs),
      sortOrder: sortOrder == null ? const Value.absent() : Value(sortOrder),
    ),
  );

  /// Parçayı başka bir listeye taşır; [playlistId] `null` = listesiz.
  ///
  /// `updateTrack`'ten ayrı: oradaki "null = değiştirme" deseni bir parçayı
  /// listesiz yapamazdı (bkz. `ShopRepository.setOwner` ile aynı gerekçe).
  Future<void> moveTrack(String id, String? playlistId) =>
      (db.update(db.musicTracks)..where((t) => t.id.equals(id))).write(
        MusicTracksCompanion(playlistId: Value(playlistId)),
      );

  /// Parçayı ve DOSYASINI siler.
  Future<void> deleteTrack(String id) async {
    final row = await (db.select(
      db.musicTracks,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    await (db.delete(db.musicTracks)..where((t) => t.id.equals(id))).go();
    await store.delete(row.path);
  }

  /// Sürükle-bırak sonrası sırayı yazar.
  Future<void> reorder(List<String> orderedIds) async {
    await db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (db.update(db.musicTracks)
              ..where((t) => t.id.equals(orderedIds[i])))
            .write(MusicTracksCompanion(sortOrder: Value(i)));
      }
    });
  }
}
