import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../data/db/database.dart';
import '../../data/music_store.dart';
import '../../l10n/app_localizations.dart';
import 'music_controller.dart';
import 'music_download_controller.dart';
import 'music_link_dialog.dart';
import 'tool_installer.dart';

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

    // Seçili liste alt listesi olan bir kök liste mi? Öyleyse kategori
    // görünümü çizilecek.
    final current = playlists.where((p) => p.id == _playlistId).firstOrNull;
    final category =
        current != null &&
            current.parentId == null &&
            playlists.any((p) => p.parentId == current.id)
        ? current
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navMusic),
        actions: [
          // Sıralama: Ayarlar -> Bağlantıdan ekle -> Dosya ekle -> Yeni liste.
          // Ayarlar en solda: araç kurulumu diğer düğmelerin ÖN KOŞULU, akış
          // soldan sağa "önce kur, sonra ekle" diye okunuyor.
          //
          // Indirme YALNIZCA masaustunde: harici bir calistirilabilir
          // (yt-dlp) gerekiyor ve Android bunu hicbir zaman kuramaz. Iki
          // dugme de orada gizleniyor, cunku ayarlar sayfasinin tek isi o
          // aracin kurulumu (bkz. `MusicDownloader.supportedHere`).
          if (ref.watch(musicDownloadSupportedProvider)) ...[
            IconButton(
              tooltip: l10n.musicSettings,
              icon: const Icon(Icons.settings_outlined),
              onPressed: _openSettings,
            ),
            IconButton(
              tooltip: l10n.musicAddLink,
              icon: const Icon(Icons.add_link),
              onPressed: _addFromLink,
            ),
          ],
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
            onAddChild: _createSubPlaylist,
            onAddRoot: _createPlaylist,
          ),
          const Divider(height: 1),
          Expanded(
            // Secili liste bir KATEGORI ise (alt listesi var) parcalar duz
            // liste yerine acilir bolumler halinde gosteriliyor.
            child: category != null
                ? _CategoryBody(
                    category: category,
                    children: playlists
                        .where((p) => p.parentId == category.id)
                        .toList(),
                    onAddChild: () => _createSubPlaylist(category),
                    onChildMenu: _playlistMenu,
                    onTrackMenu: _trackMenu,
                  )
                : tracks.isEmpty
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
          const MusicDownloadStrip(),
          const _AmbienceBar(),
          const MusicPlayerBar(),
        ],
      ),
    );
  }

  /// Bağlantıdan ekleme kutusu. Parça o an seçili listeye düşer.
  ///
  /// Kutu `true` ile kapanırsa yt-dlp kurulu değil demektir; kullanıcı oradaki
  /// düğmeyle kuruluma yönlendiriliyor, ayarları burada açıyoruz.
  Future<void> _addFromLink() async {
    final wantsSettings = await showDialog<bool>(
      context: context,
      builder: (context) => MusicLinkDialog(playlistId: _playlistId),
    );
    if (wantsSettings == true && mounted) await _openSettings();
  }

  Future<void> _importFiles() async {
    final files = await openFiles(
      acceptedTypeGroups: [
        XTypeGroup(
          label: L10n.of(context).fileTypeAudio,
          extensions: MusicStore.extensions,
        ),
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

  /// Alt liste başlığının menüsü (yeniden adlandır / sil).
  Future<void> _playlistMenu(MusicPlaylist playlist) async {
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
    if (action == 'rename') await _renamePlaylist(playlist);
    if (action == 'delete') await _deletePlaylist(playlist);
  }

  /// Kategori görünümündeki parça menüsü.
  Future<void> _trackMenu(MusicTrack track) async {
    final l10n = L10n.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l10n.musicRenameTrack),
              onTap: () => Navigator.pop(context, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move_outlined),
              title: Text(l10n.musicMoveTo),
              onTap: () => Navigator.pop(context, 'move'),
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
    if (!mounted) return;
    switch (action) {
      case 'rename':
        await _renameTrack(track);
      case 'move':
        final playlists = ref.read(musicPlaylistsProvider).value ?? const [];
        final target = await _pickPlaylistSheet(context, playlists);
        if (target != null) await _moveTrack(track, target.$1);
      case 'delete':
        await _deleteTrack(track);
    }
  }

  /// [parent] kategorisinin altına yeni bir liste açar ve ona geçer.
  Future<void> _createSubPlaylist(MusicPlaylist parent) async {
    final name = await _askText(context, L10n.of(context).musicNewSubList);
    if (name == null || name.isEmpty || !mounted) return;
    final id = await ref
        .read(musicRepositoryProvider)
        .createPlaylist(name, parentId: parent.id);
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

  Future<void> _openSettings() async {
    await showDialog<void>(
      context: context,
      builder: (context) => const MusicSettingsDialog(),
    );
  }
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

/// Üstteki liste (başlık) çubuğu: listesizler + her kök liste bir çip.
///
/// Kategori olan (alt listesi bulunan) çiplerin yanında küçük bir ok durur;
/// oka basılınca o kategorinin alt listeleri **hemen altında** ikinci bir
/// satır olarak açılır. Çipler yatay kaydırılabilir kaldığı için sayfanın
/// dikey alanı yalnızca bir kategori açıkken artıyor.
///
/// Her iki satırın da (kök çipler + açık kategorinin alt çipleri) BOŞ
/// alanına sağ tıklayınca o satıra uygun "liste oluştur" seçeneği çıkar —
/// bir liste eklemek için artık mevcut bir çipin uzun basma menüsüne
/// gitmek gerekmiyor.
class _PlaylistBar extends StatefulWidget {
  const _PlaylistBar({
    required this.playlists,
    required this.selected,
    required this.onSelect,
    required this.onRename,
    required this.onDelete,
    required this.onAddChild,
    required this.onAddRoot,
  });

  final List<MusicPlaylist> playlists;
  final String? selected;
  final ValueChanged<String?> onSelect;
  final ValueChanged<MusicPlaylist> onRename;
  final ValueChanged<MusicPlaylist> onDelete;
  final ValueChanged<MusicPlaylist> onAddChild;

  /// Kök satırın boş alanına sağ tıklanınca çağrılır (yeni KÖK liste).
  final VoidCallback onAddRoot;

  @override
  State<_PlaylistBar> createState() => _PlaylistBarState();
}

class _PlaylistBarState extends State<_PlaylistBar> {
  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final roots = widget.playlists.where((p) => p.parentId == null).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Yatay `SingleChildScrollView` DEGIL, `Wrap`: kaydirilabilir alan
        // bos noktalardaki isaretci olaylarini da yutuyor ve disaridaki sag
        // tik dedektoru (opaque olsa bile) hic tetiklenmiyordu. `Wrap`'te
        // ciplerin kaplamadigi her nokta dogrudan bu dedektore dusuyor.
        // Yan fayda: cok liste varken ekran disina tasmak yerine alt satira
        // sariyor.
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onSecondaryTapUp: (details) =>
              _emptySpaceMenu(context, details.globalPosition, parent: null),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: SizedBox(
              width: double.infinity,
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ChoiceChip(
                    label: Text(l10n.musicUnfiled),
                    selected: widget.selected == null,
                    onSelected: (_) => widget.onSelect(null),
                  ),
                  // Yalnizca KOK listeler cip: alt listeler artik govdede
                  // dikey acilir bolumler halinde (bkz. `_CategoryBody`).
                  for (final p in roots)
                    _PlaylistChip(
                      playlist: p,
                      selected: widget.selected == p.id,
                      onSelect: () => widget.onSelect(p.id),
                      onMenu: () => _menu(context, p),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  /// Boş alana sağ tıklanınca açılan mini menü.
  ///
  /// [parent] dolu ise açık kategorinin alt satırındayız: tek seçenek, o
  /// kategorinin altına yeni liste. `null` ise kök satırdayız; orada "yeni
  /// kök liste" her zaman, "yeni alt liste" ise seçili bir kök liste varsa
  /// çıkar — yoksa **ilk** alt listeyi oluşturacak hiçbir yol kalmıyordu
  /// (alt satır ancak zaten alt liste varken çiziliyor).
  Future<void> _emptySpaceMenu(
    BuildContext context,
    Offset position, {
    required MusicPlaylist? parent,
  }) async {
    final l10n = L10n.of(context);

    // Kök satırda: seçili kök liste, alt liste eklenebilecek aday.
    final selectedRoot = parent != null
        ? null
        : widget.playlists
              .where((p) => p.id == widget.selected && p.parentId == null)
              .firstOrNull;

    final action = await showMenuAtPosition<String>(context, position, [
      if (parent == null)
        PopupMenuItem(
          value: 'root',
          child: menuRow(
            Icons.create_new_folder_outlined,
            l10n.musicNewPlaylist,
          ),
        ),
      if (parent != null || selectedRoot != null)
        PopupMenuItem(
          value: 'child',
          child: menuRow(
            Icons.subdirectory_arrow_right,
            parent != null
                ? l10n.musicNewSubList
                : '${l10n.musicNewSubList} — ${selectedRoot!.name}',
          ),
        ),
    ]);

    if (action == 'root') widget.onAddRoot();
    if (action == 'child') widget.onAddChild(parent ?? selectedRoot!);
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
            // Alt kategori yalnızca kök listelere eklenebiliyor: arayüz iki
            // kademe gösteriyor, üçüncü kademe açılsa çizilemezdi.
            if (playlist.parentId == null)
              ListTile(
                leading: const Icon(Icons.create_new_folder_outlined),
                title: Text(l10n.musicNewSubList),
                onTap: () => Navigator.pop(context, 'child'),
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
    if (action == 'rename') widget.onRename(playlist);
    if (action == 'child') widget.onAddChild(playlist);
    if (action == 'delete') widget.onDelete(playlist);
  }
}

/// Tek kök liste çipi.
class _PlaylistChip extends StatelessWidget {
  const _PlaylistChip({
    required this.playlist,
    required this.selected,
    required this.onSelect,
    required this.onMenu,
  });

  final MusicPlaylist playlist;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Uzun bas / sag tik = yeniden adlandir, alt liste ekle, sil.
      onLongPress: onMenu,
      onSecondaryTap: onMenu,
      child: ChoiceChip(
        selected: selected,
        onSelected: (_) => onSelect(),
        label: Text(playlist.name),
      ),
    );
  }
}

/// Alt listesi olan bir kök liste seçiliyken gösterilen gövde.
///
/// Alt listeler çip DEĞİL: her biri kendi başlığı olan, oka basınca içindeki
/// parçaları **aşağı doğru açan** dikey bir bölüm. Üstte seçili kategorinin
/// adı ve ona doğrudan alt liste / dosya ekleme düğmeleri durur.
class _CategoryBody extends ConsumerStatefulWidget {
  const _CategoryBody({
    required this.category,
    required this.children,
    required this.onAddChild,
    required this.onChildMenu,
    required this.onTrackMenu,
  });

  final MusicPlaylist category;
  final List<MusicPlaylist> children;
  final VoidCallback onAddChild;
  final ValueChanged<MusicPlaylist> onChildMenu;
  final ValueChanged<MusicTrack> onTrackMenu;

  @override
  ConsumerState<_CategoryBody> createState() => _CategoryBodyState();
}

class _CategoryBodyState extends ConsumerState<_CategoryBody> {
  /// Açık alt listeler. Birden fazlası aynı anda açık kalabilir — masada
  /// "savaş" ve "gerilim" parçalarını yan yana görmek isteniyor.
  final _open = <String>{};

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final all = ref.watch(allMusicTracksProvider).value ?? const <MusicTrack>[];

    // Kategorinin KENDI parcalari (alt listeye konmamis olanlar).
    final ownTracks = all
        .where((t) => t.playlistId == widget.category.id)
        .toList();

    // Kategori adı BURADA yazmıyor: üstteki çip çubuğunda hangi listenin
    // seçili olduğu zaten görünüyor, ikinci kez yazmak yer harcıyordu.
    return CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildListDelegate([
            for (final track in ownTracks)
              _SectionTrackTile(
                track: track,
                queue: ownTracks,
                onMenu: () => widget.onTrackMenu(track),
              ),
            for (final child in widget.children)
              _SubListSection(
                playlist: child,
                tracks: all.where((t) => t.playlistId == child.id).toList(),
                expanded: _open.contains(child.id),
                onToggle: () => setState(
                  () => _open.contains(child.id)
                      ? _open.remove(child.id)
                      : _open.add(child.id),
                ),
                onMenu: () => widget.onChildMenu(child),
                onTrackMenu: widget.onTrackMenu,
              ),
          ]),
        ),
        // Parçaların ALTINDAKİ boş alan. `ListView` içine konan sade bir
        // GestureDetector işe yaramaz: kaydırılabilir alan boş noktalardaki
        // işaretçi olaylarını yutuyor. `SliverFillRemaining` o boşluğu
        // GERÇEK bir widget hâline getiriyor, sağ tık böylece ulaşıyor.
        SliverFillRemaining(
          hasScrollBody: false,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onSecondaryTapUp: (details) =>
                _emptyAreaMenu(details.globalPosition),
            child: widget.children.isEmpty && ownTracks.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        l10n.musicEmpty,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  )
                : const SizedBox.expand(),
          ),
        ),
      ],
    );
  }

  /// Parçaların altındaki boşluğa sağ tık: bu kategoriye alt liste ekle.
  Future<void> _emptyAreaMenu(Offset position) async {
    final l10n = L10n.of(context);
    final action = await showMenuAtPosition<String>(context, position, [
      PopupMenuItem(
        value: 'child',
        child: menuRow(Icons.create_new_folder_outlined, l10n.musicNewSubList),
      ),
    ]);
    if (action == 'child') widget.onAddChild();
  }
}

/// Tek bir alt liste bölümü: başlık (ok + ad + tümünü çal) ve açıkken parçalar.
class _SubListSection extends ConsumerWidget {
  const _SubListSection({
    required this.playlist,
    required this.tracks,
    required this.expanded,
    required this.onToggle,
    required this.onMenu,
    required this.onTrackMenu,
  });

  final MusicPlaylist playlist;
  final List<MusicTrack> tracks;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onMenu;
  final ValueChanged<MusicTrack> onTrackMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Baslik satirinin TAMAMI acma/kapama: kucuk oka nisan almak
        // gerekmiyor, ok yalnizca durumu gosteriyor.
        InkWell(
          onTap: onToggle,
          onLongPress: onMenu,
          onSecondaryTap: onMenu,
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: theme.colorScheme.primary, width: 3),
              ),
              color: theme.colorScheme.surfaceContainer,
            ),
            padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
            child: Row(
              children: [
                Icon(
                  expanded ? Icons.expand_more : Icons.chevron_right,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    playlist.name,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (tracks.isNotEmpty)
                  IconButton(
                    tooltip: l10n.musicPlay,
                    icon: const Icon(Icons.play_arrow, size: 20),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => ref
                        .read(musicControllerProvider.notifier)
                        .play(tracks.first, queue: tracks),
                  ),
              ],
            ),
          ),
        ),
        if (expanded)
          for (final track in tracks)
            _SectionTrackTile(
              track: track,
              queue: tracks,
              indented: true,
              onMenu: () => onTrackMenu(track),
            ),
      ],
    );
  }
}

/// Bölüm içindeki tek parça satırı.
class _SectionTrackTile extends ConsumerWidget {
  const _SectionTrackTile({
    required this.track,
    required this.queue,
    required this.onMenu,
    this.indented = false,
  });

  final MusicTrack track;
  final List<MusicTrack> queue;
  final VoidCallback onMenu;
  final bool indented;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final current = ref.watch(musicControllerProvider).track;
    final isCurrent = current?.id == track.id;

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.only(left: indented ? 32 : 12, right: 8),
      leading: Icon(
        isCurrent ? Icons.graphic_eq : Icons.music_note_outlined,
        size: 18,
        color: isCurrent ? theme.colorScheme.primary : null,
      ),
      title: Text(
        track.title,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: isCurrent ? FontWeight.w600 : null,
          color: isCurrent ? theme.colorScheme.primary : null,
        ),
      ),
      subtitle: track.durationMs > 0
          ? Text(formatMusicDuration(Duration(milliseconds: track.durationMs)))
          : null,
      onTap: () =>
          ref.read(musicControllerProvider.notifier).play(track, queue: queue),
      onLongPress: onMenu,
      trailing: IconButton(
        icon: const Icon(Icons.more_vert, size: 18),
        onPressed: onMenu,
      ),
    );
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
                      final target = await _pickPlaylistSheet(
                        context,
                        playlists,
                      );
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
}

/// Verilen **ekran** noktasında bir açılır menü gösterir.
///
/// `showMenu` konumu OVERLAY'e göre yorumluyor; elimizdeki ise ekran
/// koordinatı. Uygulama `StatefulShellRoute.indexedStack` kullandığı için her
/// sekmenin kendi Navigator/Overlay'i var ve bu overlay soldaki gezinme menüsü
/// kadar sağa kaymış durumda — ekran koordinatını olduğu gibi vermek menüyü
/// tam o kayma kadar sağda açıyordu. `globalToLocal` bunu düzeltir.
Future<T?> showMenuAtPosition<T>(
  BuildContext context,
  Offset globalPosition,
  List<PopupMenuEntry<T>> items,
) {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final local = overlay.globalToLocal(globalPosition);
  return showMenu<T>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromLTWH(local.dx, local.dy, 0, 0),
      Offset.zero & overlay.size,
    ),
    items: items,
  );
}

/// Menü satırı: ikon + etiket.
Widget menuRow(IconData icon, String label) => Row(
  children: [
    Icon(icon, size: 18),
    const SizedBox(width: 8),
    Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
  ],
);

/// Seçilen listeyi `(id,)` olarak döner; iptal edilirse `null`.
/// Kayıt `null` id ile "listesiz" anlamına geldiği için tek elemanlı record.
///
/// Üst seviyede: hem düz parça listesi hem kategori görünümü kullanıyor.
Future<(String?,)?> _pickPlaylistSheet(
  BuildContext context,
  List<MusicPlaylist> playlists,
) {
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
          // Kök listeler, her birinin hemen ardından girintili alt listeleri.
          for (final root in playlists.where((p) => p.parentId == null)) ...[
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(root.name),
              onTap: () => Navigator.pop(context, (root.id,)),
            ),
            for (final child in playlists.where((p) => p.parentId == root.id))
              ListTile(
                contentPadding: const EdgeInsets.only(left: 40, right: 16),
                leading: const Icon(Icons.subdirectory_arrow_right, size: 18),
                title: Text(child.name),
                onTap: () => Navigator.pop(context, (child.id,)),
              ),
          ],
        ],
      ),
    ),
  );
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

/// Müzik ayarları diyalogu: yt-dlp kurulum/yönetim.
class MusicSettingsDialog extends ConsumerWidget {
  const MusicSettingsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final states = ref.watch(toolInstallerProvider);
    final installer = ref.read(toolInstallerProvider.notifier);

    return AlertDialog(
      title: Text(l10n.musicSettings),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('yt-dlp', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                l10n.musicToolPurpose,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              for (final tool in InstallableTool.values)
                ToolInstallTile(tool: tool, state: states[tool]!),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(l10n.musicToolRecheck),
                  onPressed: installer.refresh,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}

/// Ortam sesi seridi.
///
/// Muzik cubugunun HEMEN USTUNDE ve ayni dilde: iki katman yan yana
/// gorunsun, biri digerinin ayari saniImasin. Yalnizca bir ortam sesi
/// secilmisken cikiyor -- bos bir serit masada yer yemesin.
class _AmbienceBar extends ConsumerWidget {
  const _AmbienceBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(ambienceControllerProvider);
    final controller = ref.read(ambienceControllerProvider.notifier);
    final track = state.track;
    if (track == null) return const SizedBox.shrink();

    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(Icons.graphic_eq, size: 18, color: theme.colorScheme.tertiary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.musicAmbience, style: theme.textTheme.labelSmall),
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 110,
              child: Slider(
                value: state.volume,
                onChanged: controller.setVolume,
              ),
            ),
            IconButton(
              icon: Icon(state.playing ? Icons.pause : Icons.play_arrow),
              onPressed: controller.toggle,
            ),
            IconButton(
              tooltip: l10n.musicAmbienceStop,
              icon: const Icon(Icons.stop),
              onPressed: controller.stop,
            ),
          ],
        ),
      ),
    );
  }
}
