import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../data/db/database.dart';
import '../../data/music_store.dart';
import '../../l10n/app_localizations.dart';
import 'music_controller.dart';

/// Müzik kütüphanesi: başlıklara (listelere) ayrılmış parçalar + çalar.
///
/// Dosyalar kampanya klasörüne kopyalanır ve kayıtları veritabanında durur;
/// yedek alındığında müzik de birlikte taşınır.
class MusicPage extends ConsumerStatefulWidget {
  const MusicPage({super.key});

  @override
  ConsumerState<MusicPage> createState() => _MusicPageState();
}

class _MusicPageState extends ConsumerState<MusicPage> {
  /// Seçili liste; `null` = listesiz parçalar.
  String? _playlistId;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final playlists = ref.watch(musicPlaylistsProvider).value ?? const [];
    final tracks =
        ref.watch(musicTracksProvider(_playlistId)).value ?? const [];

    // Secili liste silindiyse listesize dus.
    final selected =
        _playlistId != null && !playlists.any((p) => p.id == _playlistId)
        ? null
        : _playlistId;
    if (selected != _playlistId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _playlistId = null);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navMusic),
        actions: [
          // Eskiden FAB'dı: alt çalar çubuğu (ses seviyesi dahil) her zaman
          // ekranın altında durduğu için sağ-alt köşedeki FAB onun ÜSTÜNE
          // biniyor, ses kontrolünü tıklanamaz yapıyordu. AppBar'a taşımak
          // çakışmayı kökten çözüyor.
          IconButton(
            tooltip: l10n.musicImport,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.library_music_outlined),
            onPressed: _busy ? null : _importFiles,
          ),
          IconButton(
            tooltip: l10n.musicNewPlaylist,
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: _createPlaylist,
          ),
        ],
      ),
      body: Column(
        children: [
          _PlaylistBar(
            playlists: playlists,
            selected: _playlistId,
            onSelect: (id) => setState(() => _playlistId = id),
            onRename: _renamePlaylist,
            onDelete: _deletePlaylist,
          ),
          const Divider(height: 1),
          Expanded(
            child: tracks.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        l10n.musicEmpty,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  )
                : _TrackList(
                    tracks: tracks,
                    playlists: playlists,
                    onPlay: (t) => ref
                        .read(musicControllerProvider.notifier)
                        .play(t, queue: tracks),
                    onRename: _renameTrack,
                    onMove: _moveTrack,
                    onDelete: _deleteTrack,
                    onReorder: _reorder,
                  ),
          ),
          const MusicPlayerBar(),
        ],
      ),
    );
  }

  Future<void> _importFiles() async {
    final files = await openFiles(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Ses', extensions: MusicStore.extensions),
      ],
    );
    if (files.isEmpty) return;

    setState(() => _busy = true);
    final repo = ref.read(musicRepositoryProvider);
    try {
      for (final f in files) {
        await repo.addTrack(File(f.path), playlistId: _playlistId);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createPlaylist() async {
    final name = await _askText(context, L10n.of(context).musicNewPlaylist);
    if (name == null || name.isEmpty) return;
    final id = await ref.read(musicRepositoryProvider).createPlaylist(name);
    if (mounted) setState(() => _playlistId = id);
  }

  Future<void> _renamePlaylist(MusicPlaylist playlist) async {
    final name = await _askText(
      context,
      L10n.of(context).musicRenamePlaylist,
      initial: playlist.name,
    );
    if (name == null || name.isEmpty) return;
    await ref.read(musicRepositoryProvider).renamePlaylist(playlist.id, name);
  }

  Future<void> _deletePlaylist(MusicPlaylist playlist) async {
    final l10n = L10n.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(playlist.name),
        content: Text(l10n.musicDeletePlaylistConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(musicRepositoryProvider).deletePlaylist(playlist.id);
    if (mounted) setState(() => _playlistId = null);
  }

  Future<void> _renameTrack(MusicTrack track) async {
    final name = await _askText(
      context,
      L10n.of(context).musicRenameTrack,
      initial: track.title,
    );
    if (name == null || name.isEmpty) return;
    await ref.read(musicRepositoryProvider).updateTrack(track.id, title: name);
  }

  Future<void> _moveTrack(MusicTrack track, String? playlistId) =>
      ref.read(musicRepositoryProvider).moveTrack(track.id, playlistId);

  Future<void> _deleteTrack(MusicTrack track) async {
    await ref.read(musicControllerProvider.notifier).forgetIfPlaying(track.id);
    await ref.read(musicRepositoryProvider).deleteTrack(track.id);
  }

  Future<void> _reorder(List<String> orderedIds) =>
      ref.read(musicRepositoryProvider).reorder(orderedIds);
}

Future<String?> _askText(
  BuildContext context,
  String title, {
  String initial = '',
}) async {
  final controller = TextEditingController(text: initial);
  final l10n = L10n.of(context);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(border: OutlineInputBorder()),
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: Text(l10n.save),
        ),
      ],
    ),
  );
}

/// Üstteki liste (başlık) çubuğu: "Tümü" yerine listesizler + her liste bir çip.
class _PlaylistBar extends StatelessWidget {
  const _PlaylistBar({
    required this.playlists,
    required this.selected,
    required this.onSelect,
    required this.onRename,
    required this.onDelete,
  });

  final List<MusicPlaylist> playlists;
  final String? selected;
  final ValueChanged<String?> onSelect;
  final ValueChanged<MusicPlaylist> onRename;
  final ValueChanged<MusicPlaylist> onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          ChoiceChip(
            label: Text(l10n.musicUnfiled),
            selected: selected == null,
            onSelected: (_) => onSelect(null),
          ),
          for (final p in playlists) ...[
            const SizedBox(width: 8),
            GestureDetector(
              // Uzun bas = yeniden adlandir/sil; cip icine ikon sigmiyor.
              onLongPress: () => _menu(context, p),
              onSecondaryTap: () => _menu(context, p),
              child: ChoiceChip(
                label: Text(p.name),
                selected: selected == p.id,
                onSelected: (_) => onSelect(p.id),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _menu(BuildContext context, MusicPlaylist playlist) async {
    final l10n = L10n.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l10n.musicRenamePlaylist),
              onTap: () => Navigator.pop(context, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(l10n.delete),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'rename') onRename(playlist);
    if (action == 'delete') onDelete(playlist);
  }
}

class _TrackList extends ConsumerWidget {
  const _TrackList({
    required this.tracks,
    required this.playlists,
    required this.onPlay,
    required this.onRename,
    required this.onMove,
    required this.onDelete,
    required this.onReorder,
  });

  final List<MusicTrack> tracks;
  final List<MusicPlaylist> playlists;
  final ValueChanged<MusicTrack> onPlay;
  final ValueChanged<MusicTrack> onRename;
  final void Function(MusicTrack, String?) onMove;
  final ValueChanged<MusicTrack> onDelete;

  /// Yeni sıradaki parça id'lerini (baştan sona) verir.
  final ValueChanged<List<String>> onReorder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final current = ref.watch(musicControllerProvider).track;

    // ReorderableListView her satır icin BENZERSIZ bir Key ister; parca id'si
    // zaten kalici uuid oldugu icin dogrudan kullanilabiliyor.
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      itemCount: tracks.length,
      // `onReorderItem` (onReorder yerine) newIndex'i zaten dogru ayarlanmis
      // verir; eski `onReorder` kaldirilan ogeye gore kaydirma gerektiriyordu.
      onReorderItem: (oldIndex, newIndex) {
        final reordered = tracks.toList()
          ..insert(newIndex, tracks.removeAt(oldIndex));
        onReorder([for (final t in reordered) t.id]);
      },
      itemBuilder: (context, i) {
        final track = tracks[i];
        final isCurrent = current?.id == track.id;
        return ListTile(
          key: ValueKey(track.id),
          leading: Icon(
            isCurrent ? Icons.graphic_eq : Icons.music_note_outlined,
            color: isCurrent ? theme.colorScheme.primary : null,
          ),
          title: Text(
            track.title,
            style: TextStyle(
              fontWeight: isCurrent ? FontWeight.w600 : null,
              color: isCurrent ? theme.colorScheme.primary : null,
            ),
          ),
          subtitle: track.durationMs > 0
              ? Text(
                  formatMusicDuration(Duration(milliseconds: track.durationMs)),
                )
              : null,
          onTap: () => onPlay(track),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PopupMenuButton<String>(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'rename',
                    child: Text(l10n.musicRenameTrack),
                  ),
                  PopupMenuItem(value: 'move', child: Text(l10n.musicMoveTo)),
                  PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
                ],
                onSelected: (value) async {
                  switch (value) {
                    case 'rename':
                      onRename(track);
                    case 'move':
                      final target = await _pickPlaylist(context);
                      if (target != null) onMove(track, target.$1);
                    case 'delete':
                      onDelete(track);
                  }
                },
              ),
              // Surukleme yalnizca bu tutamactan baslar; satirin geneli
              // dokununca calmaya devam eder (onTap ile catismaz).
              ReorderableDragStartListener(
                index: i,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.drag_handle),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Seçilen listeyi `(id,)` olarak döner; iptal edilirse `null`.
  /// Kayıt `null` id ile "listesiz" anlamına geldiği için tek elemanlı record.
  Future<(String?,)?> _pickPlaylist(BuildContext context) async {
    final l10n = L10n.of(context);
    return showModalBottomSheet<(String?,)>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.inbox_outlined),
              title: Text(l10n.musicUnfiled),
              onTap: () => Navigator.pop(context, (null,)),
            ),
            for (final p in playlists)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(p.name),
                onTap: () => Navigator.pop(context, (p.id,)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Alt çalar çubuğu: şu an çalan + oynat/duraklat/durdur, ileri/geri, konum
/// çubuğu, ses seviyesi, döngü.
class MusicPlayerBar extends ConsumerWidget {
  const MusicPlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(musicControllerProvider);
    final controller = ref.read(musicControllerProvider.notifier);
    final track = state.track;

    if (track == null) return const SizedBox.shrink();

    final total = state.duration.inMilliseconds;
    final position = state.position.inMilliseconds.clamp(0, total).toDouble();

    return Material(
      elevation: 8,
      color: theme.colorScheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.graphic_eq, color: context.fantasyColors.brass),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.missing
                          ? l10n.musicMissingFile(track.title)
                          : track.title,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.musicPrevious,
                    icon: const Icon(Icons.skip_previous),
                    onPressed: controller.previous,
                  ),
                  IconButton(
                    tooltip: state.playing ? l10n.musicPause : l10n.musicPlay,
                    icon: Icon(
                      state.playing ? Icons.pause_circle : Icons.play_circle,
                      size: 34,
                    ),
                    onPressed: state.missing ? null : controller.toggle,
                  ),
                  IconButton(
                    tooltip: l10n.musicNext,
                    icon: const Icon(Icons.skip_next),
                    onPressed: () => controller.next(),
                  ),
                  IconButton(
                    tooltip: l10n.musicStop,
                    icon: const Icon(Icons.stop_circle_outlined),
                    onPressed: controller.stop,
                  ),
                  IconButton(
                    // Uctan uca dongu: kapali -> tum liste -> tek parca ->
                    // kapali. Her mod ayri ikonla gosterilir, tek dugmeye
                    // sigdirmak icin ayri sekme/menu acilmadi.
                    tooltip: switch (state.loopMode) {
                      MusicLoopMode.off => l10n.musicLoopOff,
                      MusicLoopMode.all => l10n.musicLoopAll,
                      MusicLoopMode.one => l10n.musicLoopOne,
                    },
                    icon: Icon(
                      switch (state.loopMode) {
                        MusicLoopMode.off => Icons.repeat,
                        MusicLoopMode.all => Icons.repeat_on,
                        MusicLoopMode.one => Icons.repeat_one_on,
                      },
                      color: state.loopMode == MusicLoopMode.off
                          ? null
                          : theme.colorScheme.primary,
                    ),
                    onPressed: () =>
                        controller.setLoopMode(switch (state.loopMode) {
                          MusicLoopMode.off => MusicLoopMode.all,
                          MusicLoopMode.all => MusicLoopMode.one,
                          MusicLoopMode.one => MusicLoopMode.off,
                        }),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    formatMusicDuration(state.position),
                    style: theme.textTheme.labelSmall,
                  ),
                  Expanded(
                    child: Slider(
                      value: total <= 0 ? 0 : position,
                      max: total <= 0 ? 1 : total.toDouble(),
                      onChanged: total <= 0
                          ? null
                          : (v) => controller.seek(
                              Duration(milliseconds: v.round()),
                            ),
                    ),
                  ),
                  Text(
                    formatMusicDuration(state.duration),
                    style: theme.textTheme.labelSmall,
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    state.volume == 0 ? Icons.volume_off : Icons.volume_up,
                    size: 18,
                  ),
                  SizedBox(
                    width: 120,
                    child: Slider(
                      value: state.volume,
                      onChanged: controller.setVolume,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `m:ss` / `s:mm:ss`. Süre bilinmiyorsa `--:--`.
String formatMusicDuration(Duration d) {
  if (d <= Duration.zero) return '--:--';
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:$seconds';
  }
  return '$minutes:$seconds';
}
