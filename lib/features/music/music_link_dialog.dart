import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/music_download.dart';
import '../../l10n/app_localizations.dart';
import 'music_download_controller.dart';

/// yt-dlp kurulum sayfası. Uygulama aracı paketlemediği için kullanıcıyı
/// kaynağına yönlendiriyoruz.
const _ytDlpHelpUrl = 'https://github.com/yt-dlp/yt-dlp#installation';

/// "Bağlantıdan ekle" kutusu.
///
/// YouTube (ve yt-dlp'nin çözebildiği diğer siteler) indirme kuyruğuna girer.
class MusicLinkDialog extends ConsumerStatefulWidget {
  const MusicLinkDialog({super.key, this.playlistId});

  /// Parçanın ekleneceği liste; `null` = listesiz.
  final String? playlistId;

  @override
  ConsumerState<MusicLinkDialog> createState() => _MusicLinkDialogState();
}

class _MusicLinkDialogState extends ConsumerState<MusicLinkDialog> {
  final _url = TextEditingController();

  String? _error;

  @override
  void initState() {
    super.initState();
    // Yapıştırılan bağlantı değişince hata sıfırlansın.
    _url.addListener(() {
      if (_error != null) {
        setState(() => _error = null);
      }
    });
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final toolReady = ref.watch(ytDlpAvailableProvider).value ?? true;

    return AlertDialog(
      title: Text(l10n.musicLinkTitle),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _url,
                autofocus: true,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: l10n.musicLinkHint,
                  prefixIcon: const Icon(Icons.link),
                  errorText: _error,
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.musicLinkNotice,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                ],
              ),
              if (!toolReady) ...[
                const SizedBox(height: 16),
                // Ayarları BURADAN açmıyoruz: `Navigator.pop` sonrası bu
                // diyalogun context'i ölüyor, onunla yeni diyalog açmak
                // kırılgan. Bunun yerine `true` ile kapanıyoruz; ayarları
                // açmak çağıran sayfanın işi (bkz. `MusicPage._addFromLink`).
                _ToolMissingCard(
                  onOpenSettings: () => Navigator.pop(context, true),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton.icon(
          onPressed: toolReady ? _submit : null,
          icon: const Icon(Icons.download),
          label: Text(l10n.musicLinkDownload),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final l10n = L10n.of(context);
    final url = _url.text.trim();

    switch (classifyMusicLink(url)) {
      case MusicLinkKind.unknown:
        setState(() => _error = l10n.musicLinkBad);

      case MusicLinkKind.youtube:
      case MusicLinkKind.other:
        ref
            .read(musicDownloadQueueProvider.notifier)
            .enqueue(url, playlistId: widget.playlistId);
        Navigator.pop(context);
    }
  }
}

/// yt-dlp yoksa gösterilen uyarı — ayarlar diyaloguna yönlendirir.
class _ToolMissingCard extends ConsumerWidget {
  const _ToolMissingCard({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_outlined,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.musicToolMissing,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.musicToolMissingHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.settings, size: 18),
              label: Text(l10n.musicOpenSettings),
              onPressed: onOpenSettings,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(l10n.musicToolInstall),
                onPressed: () => launchUrl(Uri.parse(_ytDlpHelpUrl)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Çalar çubuğunun üstünde duran indirme kuyruğu şeridi. Kuyruk boşsa hiç
/// yer kaplamaz.
class MusicDownloadStrip extends ConsumerWidget {
  const MusicDownloadStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final jobs = ref.watch(musicDownloadQueueProvider);
    if (jobs.isEmpty) return const SizedBox.shrink();

    final queue = ref.read(musicDownloadQueueProvider.notifier);
    final anyFinished = jobs.any(
      (j) =>
          j.status == MusicJobStatus.done || j.status == MusicJobStatus.failed,
    );

    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
            child: Row(
              children: [
                Text(l10n.musicDownloads, style: theme.textTheme.labelLarge),
                const Spacer(),
                if (anyFinished)
                  TextButton(
                    onPressed: queue.clearFinished,
                    child: Text(l10n.musicDownloadClear),
                  ),
              ],
            ),
          ),
          for (final job in jobs)
            _JobTile(job: job, onDismiss: () => queue.dismiss(job.id)),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _JobTile extends StatelessWidget {
  const _JobTile({required this.job, required this.onDismiss});

  final MusicDownloadJob job;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final failed = job.status == MusicJobStatus.failed;

    return ListTile(
      dense: true,
      leading: switch (job.status) {
        MusicJobStatus.queued => const Icon(Icons.schedule, size: 20),
        MusicJobStatus.running => const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        MusicJobStatus.done => Icon(
          Icons.check_circle_outline,
          size: 20,
          color: theme.colorScheme.primary,
        ),
        MusicJobStatus.failed => Icon(
          Icons.error_outline,
          size: 20,
          color: theme.colorScheme.error,
        ),
      },
      title: Text(job.label, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: switch (job.status) {
        MusicJobStatus.running => LinearProgressIndicator(value: job.progress),
        MusicJobStatus.done => Text(l10n.musicDownloadDone),
        MusicJobStatus.failed => Text(
          _failureText(l10n, job),
          style: TextStyle(color: theme.colorScheme.error),
        ),
        MusicJobStatus.queued => null,
      },
      trailing:
          job.status == MusicJobStatus.queued ||
              job.status == MusicJobStatus.running
          ? null
          : IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onDismiss,
            ),
      isThreeLine: failed && job.detail != null,
    );
  }

  String _failureText(L10n l10n, MusicDownloadJob job) => switch (job.error) {
    MusicDownloadError.toolMissing => l10n.musicToolMissing,
    MusicDownloadError.badLink => l10n.musicLinkBad,
    MusicDownloadError.forbidden => l10n.musicForbidden,
    _ => job.detail ?? l10n.musicDownloadFailed,
  };
}
