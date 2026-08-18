import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../l10n/app_localizations.dart';

/// İndirilebilir araç türü.
enum InstallableTool {
  ytDlp('yt-dlp', 'yt-dlp.exe');

  const InstallableTool(this.name, this.executable);
  final String name;
  final String executable;
}

/// Kurulum durumu.
enum InstallStatus {
  notInstalled,
  checking,
  downloading,
  extracting,
  installing,
  installed,
  failed,
}

/// Kurulum ilerleme durumu.
class ToolInstallState {
  const ToolInstallState({
    required this.tool,
    required this.status,
    this.progress = 0.0,
    this.installedPath,
    this.error,
  });

  final InstallableTool tool;
  final InstallStatus status;
  final double progress;
  final String? installedPath;
  final String? error;

  ToolInstallState copyWith({
    InstallStatus? status,
    double? progress,
    String? installedPath,
    String? error,
  }) {
    return ToolInstallState(
      tool: tool,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      installedPath: installedPath ?? this.installedPath,
      error: error ?? this.error,
    );
  }
}

/// Araç kurulum yöneticisi.
///
/// Kurulu durumu `shared_preferences`'a yazılır; böylece sayfaya gir-çık
/// yapınca araç tekrar "kurulmamış" görünmez, kurulu hâli korunur.
class ToolInstaller extends Notifier<Map<InstallableTool, ToolInstallState>> {
  @override
  Map<InstallableTool, ToolInstallState> build() {
    _restore();
    // `notInstalled` ile başlanmıyor: kayıtlı kurulum doğrulanana kadar bir an
    // için "Kur" düğmesi yanıp sönerdi. `checking` o titremeyi engelliyor.
    return {
      for (final tool in InstallableTool.values)
        tool: ToolInstallState(tool: tool, status: InstallStatus.checking),
    };
  }

  static String _prefKey(InstallableTool tool) => 'music.tool.${tool.name}';

  /// Kayıtlı kurulu durumunu okur ve **doğrular**.
  ///
  /// Yalnızca `shared_preferences`'a güvenmek yetmez: araç dışarıdan silinmiş
  /// ya da bozulmuş olabilir. Kayıtlı yol çalışmıyorsa normal arama (PATH +
  /// yerel klasör) yapılır, böylece gir-çık sonrası durum hep gerçeği gösterir.
  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    for (final tool in InstallableTool.values) {
      final saved = prefs.getString(_prefKey(tool));
      if (saved != null && await _runs(saved)) {
        _update(tool, status: InstallStatus.installed, installedPath: saved);
      } else {
        await checkInstalled(tool);
      }
    }
  }

  /// Verilen komut `--version` ile sorunsuz çalışıyor mu?
  Future<bool> _runs(String path) async {
    try {
      final result = await Process.run(path, ['--version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Kurulu durumunu yeniden doğrular (araç dışarıdan kaldırılmış olabilir).
  Future<void> refresh() async {
    for (final tool in InstallableTool.values) {
      await checkInstalled(tool);
    }
  }

  /// Aracın kurulu olup olmadığını kontrol et.
  Future<bool> checkInstalled(InstallableTool tool) async {
    _update(tool, status: InstallStatus.checking);

    // Önce PATH, sonra uygulamanın kendi `tools/` klasörü.
    for (final candidate in [tool.executable, await _getLocalToolPath(tool)]) {
      if (await _runs(candidate)) {
        await _saveInstalledPath(tool, candidate);
        _update(
          tool,
          status: InstallStatus.installed,
          installedPath: candidate,
        );
        return true;
      }
    }

    _update(tool, status: InstallStatus.notInstalled);
    return false;
  }

  Future<void> _saveInstalledPath(InstallableTool tool, String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey(tool), path);
  }

  /// Aracı indir ve kur.
  Future<void> install(InstallableTool tool) async {
    _update(tool, status: InstallStatus.downloading, progress: 0);

    try {
      final localPath = await _getLocalToolPath(tool);
      final dir = Directory(p.dirname(localPath));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final downloadUrl = _getDownloadUrl(tool);

      // İndir
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final streamedResponse = await http.Client().send(request);

      if (streamedResponse.statusCode != 200) {
        throw Exception('HTTP ${streamedResponse.statusCode}');
      }

      final contentLength = streamedResponse.contentLength ?? 0;
      var downloaded = 0;
      final bytes = <int>[];

      await for (final chunk in streamedResponse.stream) {
        bytes.addAll(chunk);
        downloaded += chunk.length;
        if (contentLength > 0) {
          _update(tool, progress: downloaded / contentLength);
        }
      }

      // Kaydet
      final file = File(localPath);
      await file.writeAsBytes(bytes);

      // Doğrudan .exe indirildi — kalıcı olarak kaydet
      await _saveInstalledPath(tool, localPath);
      _update(tool, status: InstallStatus.installed, installedPath: localPath);
    } catch (e) {
      _update(tool, status: InstallStatus.failed, error: e.toString());
    }
  }

  /// Yerel araç yolunu al.
  Future<String> _getLocalToolPath(InstallableTool tool) async {
    final appDir = await getApplicationSupportDirectory();
    final toolsDir = '${appDir.path}/tools';
    return '$toolsDir/${tool.executable}';
  }

  /// İndirme URL'sini al.
  String _getDownloadUrl(InstallableTool tool) {
    switch (tool) {
      case InstallableTool.ytDlp:
        return 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe';
    }
  }

  void _update(
    InstallableTool tool, {
    InstallStatus? status,
    double? progress,
    String? installedPath,
    String? error,
  }) {
    state = {
      ...state,
      tool: state[tool]!.copyWith(
        status: status,
        progress: progress,
        installedPath: installedPath,
        error: error,
      ),
    };
  }
}

final toolInstallerProvider =
    NotifierProvider<ToolInstaller, Map<InstallableTool, ToolInstallState>>(
      ToolInstaller.new,
    );

/// Kurulum kartı (şablon) — ayarlar diyalogunda ve link diyalogunda kullanılır.
class ToolInstallTile extends ConsumerWidget {
  const ToolInstallTile({super.key, required this.tool, required this.state});

  final InstallableTool tool;
  final ToolInstallState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tool.name, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  _getStatusText(l10n, state),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _getStatusColor(theme, state),
                  ),
                ),
                if (state.status == InstallStatus.downloading ||
                    state.status == InstallStatus.extracting) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: state.progress),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildActionButton(context, ref),
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final installer = ref.read(toolInstallerProvider.notifier);

    switch (state.status) {
      case InstallStatus.notInstalled:
      case InstallStatus.failed:
        return FilledButton.tonal(
          onPressed: () => installer.install(tool),
          child: Text(l10n.musicToolInstallAction),
        );
      case InstallStatus.checking:
      case InstallStatus.downloading:
      case InstallStatus.extracting:
      case InstallStatus.installing:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case InstallStatus.installed:
        return TextButton.icon(
          icon: const Icon(Icons.check_circle, size: 18),
          label: Text(l10n.musicToolInstalled),
          onPressed: null,
        );
    }
  }

  String _getStatusText(L10n l10n, ToolInstallState state) {
    switch (state.status) {
      case InstallStatus.notInstalled:
        return l10n.musicToolNotInstalled;
      case InstallStatus.checking:
        return l10n.musicToolChecking;
      case InstallStatus.downloading:
        return l10n.musicToolDownloading(
          (state.progress * 100).toStringAsFixed(0),
        );
      case InstallStatus.extracting:
        return l10n.musicToolExtracting;
      case InstallStatus.installing:
        return l10n.musicToolInstalling;
      case InstallStatus.installed:
        return '${l10n.musicToolInstalled}: ${state.installedPath}';
      case InstallStatus.failed:
        return l10n.musicToolError(state.error ?? '');
    }
  }

  Color _getStatusColor(ThemeData theme, ToolInstallState state) {
    switch (state.status) {
      case InstallStatus.installed:
        return theme.colorScheme.primary;
      case InstallStatus.failed:
        return theme.colorScheme.error;
      default:
        return theme.colorScheme.onSurfaceVariant;
    }
  }
}
