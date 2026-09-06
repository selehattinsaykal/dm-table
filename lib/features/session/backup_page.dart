import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../app/ui/ui.dart';
import '../../data/backup_repository.dart';
import '../../data/backup_restore_service.dart';
import '../../data/campaign/campaign_manager.dart';
import '../../data/export_service.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';

final backupRepositoryProvider = Provider<BackupRepository>(
  (ref) => BackupRepository(ref.watch(databaseProvider)),
);

/// Kampanya yedegi.
///
/// Yedek, oyun masasindaki tek kopyayi ikiye cikaran sey: telefon kaybolursa
/// ya da uygulama silinirse kampanya bu dosyayla geri geliyor.
class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  bool _busy = false;
  String? _message;
  String? _lastExportPath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.sessionBackup)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.backupExport, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(l10n.backupExportHint, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _busy ? null : _export,
                    icon: const Icon(Icons.archive_outlined),
                    label: Text(l10n.backupCreateFile),
                  ),
                  if (_lastExportPath != null) ...[
                    const SizedBox(height: 12),
                    SelectableText(
                      _lastExportPath!,
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      l10n.backupExportedHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Acik bicimler: yedek DEGIL. Yedek yalnizca bu uygulamaya geri
          // yuklenebiliyor; bunlar her yerde acilir ama geri yuklenmez.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.exportTitle, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(l10n.exportHint, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _exportOpenFormat(markdown: true),
                        icon: const Icon(Icons.article_outlined),
                        label: Text(l10n.exportMarkdown),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _exportOpenFormat(markdown: false),
                        icon: const Icon(Icons.data_object),
                        label: Text(l10n.exportJson),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.backupRestore, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    l10n.backupRestoreHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _import,
                    icon: const Icon(Icons.restore),
                    label: Text(l10n.backupPickFile),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Ayri kart: bu geri yukleme DEGIL, ice aktarma. Acik kampanyaya
          // hic dokunmaz — baskasinin masasini yanina almak icin.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.backupImportAsCampaign,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.backupImportAsCampaignHint,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _importAsNewCampaign,
                    icon: const Icon(Icons.library_add_outlined),
                    label: Text(l10n.backupPickFile),
                  ),
                ],
              ),
            ),
          ),
          if (_busy) ...[const SizedBox(height: 24), const AppLoading()],
          if (_message != null) ...[
            const SizedBox(height: 16),
            Card(
              color: theme.colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_message!),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _export() async {
    final l10n = L10n.of(context);
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final bytes = await ref.read(backupRepositoryProvider).export();
      final file = await _destinationFile();
      await file.writeAsBytes(bytes);

      setState(() {
        _lastExportPath = file.path;
        _message = l10n.backupExportedKb((bytes.length / 1024).round());
      });
    } on _Cancelled {
      // Kullanici kaydetme penceresini kapatti; hata degil.
    } on Object catch (e) {
      setState(() => _message = l10n.backupExportFailed('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Yedegin yazilacagi dosya.
  Future<File> _destinationFile() =>
      _saveTarget('zip', L10n.of(context).backupFileType);

  /// Kullanicinin sectigi hedef dosya.
  ///
  /// Android'de uygulamaya ozel dis depolama kullaniliyor: izin istemeden
  /// yazilabiliyor ve kullanici dosya yoneticisiyle ya da USB ile alabiliyor.
  /// Masaustunde normal kaydetme kutusu acilir.
  Future<File> _saveTarget(String extension, String typeLabel) async {
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final name = 'dm-masasi-$stamp.$extension';

    if (Platform.isAndroid) {
      final external = await getExternalStorageDirectory();
      final dir = external ?? await getApplicationDocumentsDirectory();
      return File(p.join(dir.path, name));
    }

    final location = await getSaveLocation(
      suggestedName: name,
      acceptedTypeGroups: [
        XTypeGroup(label: typeLabel, extensions: [extension]),
      ],
    );
    if (location == null) throw const _Cancelled();
    return File(location.path);
  }

  /// Kayitlar agacini Markdown'a, kampanyayi JSON'a yazar.
  ///
  /// Yedekten AYRI bir akis ve bilincli olarak oyle: bu dosyalar geri
  /// YUKLENMEZ. Amac notlarin bu uygulamaya kilitli kalmamasi.
  Future<void> _exportOpenFormat({required bool markdown}) async {
    final l10n = L10n.of(context);
    setState(() {
      _busy = true;
      _message = null;
      _lastExportPath = null;
    });
    try {
      final service = ExportService(ref.read(databaseProvider));
      final content = markdown
          ? await service.codexToMarkdown()
          : await service.campaignToJsonString();
      if (!mounted) return;
      final file = await _saveTarget(
        markdown ? 'md' : 'json',
        markdown ? l10n.exportMarkdownType : l10n.exportJsonType,
      );
      await file.writeAsString(content);
      if (!mounted) return;
      setState(() {
        _lastExportPath = file.path;
        _message = l10n.exportDone;
      });
    } on _Cancelled {
      // Kullanici kaydetme kutusunu kapatti; sessizce gec.
    } on Object catch (e) {
      if (mounted) setState(() => _message = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Dosyayı seçtirip içeriğini okur. Bozuk arşivde mesajı yazar ve `null`
  /// döner; iki içe aktarma akışı da bunu kullanıyor.
  Future<({List<int> bytes, BackupSummary summary})?> _pickAndInspect() async {
    final l10n = L10n.of(context);
    final picked = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(label: l10n.backupFileType, extensions: const ['zip']),
      ],
    );
    if (picked == null || !mounted) return null;

    final bytes = await picked.readAsBytes();
    try {
      return (
        bytes: bytes,
        summary: ref.read(backupRepositoryProvider).inspect(bytes),
      );
    } on Object catch (e) {
      if (mounted) setState(() => _message = l10n.backupReadFailed('$e'));
      return null;
    }
  }

  /// Yedeğin içeriğini gösterip onay alır. [warning] boş bırakılırsa uyarı
  /// satırı çıkmaz (yeni kampanyaya aktarmada silinen bir şey yok).
  Future<bool> _confirm(
    BackupSummary summary, {
    required String title,
    required String action,
    String? warning,
  }) async {
    final l10n = L10n.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.backupDate(summary.createdAt)),
            const SizedBox(height: 8),
            for (final e in summary.counts.entries)
              Text('${_labelFor(l10n, e.key)}: ${e.value}'),
            if (summary.mapCount > 0)
              Text(l10n.backupMapFiles(summary.mapCount)),
            if (summary.portraitCount > 0)
              Text(l10n.backupPortraitFiles(summary.portraitCount)),
            if (summary.mediaCount > 0)
              Text(l10n.backupMediaFiles(summary.mediaCount)),
            if (summary.musicCount > 0)
              Text(l10n.backupMusicFiles(summary.musicCount)),
            if (warning != null) ...[
              const SizedBox(height: 12),
              Text(
                warning,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _import() async {
    final l10n = L10n.of(context);
    final picked = await _pickAndInspect();
    if (picked == null || !mounted) return;

    // Once icerigi gosterip onay al: geri yukleme geri alinamaz.
    final ok = await _confirm(
      picked.summary,
      title: l10n.backupRestore,
      action: l10n.backupRestoreButton,
      warning: l10n.backupWillReplace,
    );
    if (!ok || !mounted) return;

    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref.read(backupRepositoryProvider).import(picked.bytes);
      setState(() => _message = l10n.backupRestored);
    } on Object catch (e) {
      setState(() => _message = l10n.backupRestoreFailed('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Yedeği AYRI bir kampanya olarak kurar; açık kampanyaya dokunmaz.
  Future<void> _importAsNewCampaign() async {
    final l10n = L10n.of(context);
    final manager = ref.read(campaignManagerProvider);
    if (manager == null) return;

    final picked = await _pickAndInspect();
    if (picked == null || !mounted) return;

    final ok = await _confirm(
      picked.summary,
      title: l10n.backupImportAsCampaign,
      action: l10n.backupImportButton,
    );
    if (!ok || !mounted) return;

    final name = await _askCampaignName();
    if (name == null || name.isEmpty || !mounted) return;

    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final campaign = await BackupRestoreService(
        manager,
      ).restoreAsNewCampaign(name: name, bytes: picked.bytes);
      if (!mounted) return;
      setState(() => _message = l10n.backupImportedAsCampaign(campaign.name));

      // Kampanyaya gecmek ayri karar: DM yedegi yanina almis olabilir ama
      // masasini birakmak istemeyebilir.
      final open = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(campaign.name),
          content: Text(l10n.backupOpenImportedCampaign),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.campaignOpen),
            ),
          ],
        ),
      );
      if (open == true) await manager.open(campaign.id);
    } on Object catch (e) {
      if (mounted) setState(() => _message = l10n.backupRestoreFailed('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askCampaignName() {
    final l10n = L10n.of(context);
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.campaignNameLabel),
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
            child: Text(l10n.create),
          ),
        ],
      ),
    );
  }

  static String _labelFor(L10n l10n, String table) => switch (table) {
    'characters' => l10n.backupLabelCharacters,
    'character_class_levels' => l10n.backupLabelClassLevels,
    'character_proficiencies' => l10n.backupLabelProficiencies,
    'character_items' => l10n.backupLabelInventory,
    'character_spells' => l10n.backupLabelCharacterSpells,
    'character_features' => l10n.backupLabelCharacterFeatures,
    'character_notes' => l10n.backupLabelPlayerNotes,
    'encounters' => l10n.backupLabelEncounters,
    'combatants' => l10n.backupLabelCombatants,
    'shops' => l10n.backupLabelShops,
    'shop_stock' => l10n.backupLabelShopStock,
    'loot_sets' => l10n.backupLabelLootSets,
    'locations' => l10n.backupLabelLocations,
    'map_pins' => l10n.backupLabelMapPins,
    'world_links' => l10n.backupLabelWorldLinks,
    'bond_types' => l10n.backupLabelBondTypes,
    'npcs' => l10n.backupLabelNpcs,
    'quests' => l10n.backupLabelQuests,
    'session_log_entries' => l10n.backupLabelSessionLog,
    'codex_pages' => l10n.backupLabelCodexPages,
    'codex_blocks' => l10n.backupLabelCodexBlocks,
    // Sonradan eklenen tablolar; etiketi olmayan tablo ham adiyla gorunuyordu
    // ("music_tracks: 12" gibi).
    'party_inventories' => l10n.backupLabelPartyInventories,
    'random_tables' => l10n.backupLabelRandomTables,
    'journeys' => l10n.backupLabelJourneys,
    'calendar_config' ||
    'calendar_months' ||
    'calendar_weekdays' ||
    'calendar_seasons' => l10n.backupLabelCalendar,
    'calendar_eras' => l10n.backupLabelEras,
    'chronicle_events' => l10n.backupLabelChronicle,
    'calendar_reminders' => l10n.backupLabelReminders,
    'music_playlists' => l10n.backupLabelMusicPlaylists,
    'music_tracks' => l10n.backupLabelMusicTracks,
    'spells' => l10n.backupLabelSpells,
    'monsters' => l10n.backupLabelMonsters,
    'items' => l10n.backupLabelItems,
    'magic_items' => l10n.backupLabelMagicItems,
    'class_definitions' => l10n.backupLabelClasses,
    'species_entries' => l10n.backupLabelSpecies,
    'backgrounds' => l10n.backupLabelBackgrounds,
    'feats' => l10n.backupLabelFeats,
    _ => table,
  };
}

/// Kullanici kaydetme penceresini kapatti.
class _Cancelled implements Exception {
  const _Cancelled();
}
