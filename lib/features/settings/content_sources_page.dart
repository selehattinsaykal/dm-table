import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../data/db/database.dart';
import '../../data/import/fivetools/fivetools_source.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';

/// Kullanicinin tanimladigi icerik kaynaklarini yoneten ekran.
///
/// **Uygulama hicbir adresle gelmiyor.** Hangi kaynaktan icerik cekilecegine
/// kullanici karar veriyor: kendi homebrew deposu, kendi disa aktardigi
/// dosyalar ya da erisim hakkina sahip oldugu bir arsiv. Ekran yalnizca
/// 5etools JSON BICIMINI anliyor.
class ContentSourcesPage extends ConsumerStatefulWidget {
  const ContentSourcesPage({super.key});

  @override
  ConsumerState<ContentSourcesPage> createState() => _ContentSourcesPageState();
}

class _ContentSourcesPageState extends ConsumerState<ContentSourcesPage> {
  /// Kesif sonuclari; kaynak kimligine gore.
  final _discovered = <String, DiscoveryResult>{};
  final _selected = <String, Set<String>>{};
  String? _busySourceId;
  String? _status;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final sources = ref.watch(contentSourcesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.contentSourcesTitle),
        actions: [
          IconButton(
            tooltip: l10n.contentSourceLocalFiles,
            onPressed: _busySourceId == null ? _importLocalFiles : null,
            icon: const Icon(Icons.folder_open_outlined),
          ),
          IconButton(
            tooltip: l10n.contentSourceDeleteImported,
            onPressed: _busySourceId == null ? _deleteImported : null,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSource,
        icon: const Icon(Icons.add),
        label: Text(l10n.contentSourceAdd),
      ),
      body: ListView(
        padding: EdgeInsets.all(context.spacing.md),
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(context.spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.contentSourcesHint,
                    style: theme.textTheme.bodySmall,
                  ),
                  SizedBox(height: context.spacing.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.gavel_outlined,
                        size: 16,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.contentSourceLegal,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_status != null) ...[
            SizedBox(height: context.spacing.sm),
            Card(
              color: theme.colorScheme.surfaceContainerHighest,
              child: ListTile(
                leading: _busySourceId == null
                    ? const Icon(Icons.check_circle_outline)
                    : const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                title: Text(_status!, style: theme.textTheme.bodyMedium),
              ),
            ),
          ],
          SizedBox(height: context.spacing.sm),
          switch (sources) {
            AsyncData(:final value) when value.isEmpty => Padding(
              padding: EdgeInsets.all(context.spacing.lg),
              child: Center(child: Text(l10n.contentSourceEmpty)),
            ),
            AsyncData(:final value) => Column(
              children: [for (final source in value) _sourceCard(source)],
            ),
            AsyncError(:final error) => Padding(
              padding: EdgeInsets.all(context.spacing.lg),
              child: Text('$error'),
            ),
            _ => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          },
          // Liste FAB'in altinda kalmasin.
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _sourceCard(ContentSource source) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final result = _discovered[source.id];
    final busy = _busySourceId == source.id;

    return Card(
      margin: EdgeInsets.only(bottom: context.spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: Text(source.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(source.baseUrl, style: theme.textTheme.bodySmall),
                Text(
                  source.lastImportedAt == null
                      ? l10n.contentSourceNeverImported
                      : l10n.contentSourceLastImport(
                          _formatDate(source.lastImportedAt!),
                        ),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (busy)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                TextButton.icon(
                  onPressed: _busySourceId == null
                      ? () => _discover(source)
                      : null,
                  icon: const Icon(Icons.travel_explore_outlined, size: 18),
                  label: Text(l10n.contentSourceDiscover),
                ),
                IconButton(
                  tooltip: l10n.delete,
                  onPressed: _busySourceId == null
                      ? () => _removeSource(source)
                      : null,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          if (result != null) _fileList(source, result),
        ],
      ),
    );
  }

  Widget _fileList(ContentSource source, DiscoveryResult result) {
    final l10n = L10n.of(context);
    final files = result.files;
    if (files.isEmpty) return _problem(result);

    final selected = _selected[source.id] ?? <String>{};
    // Tur basina gruplaniyor: bir bestiary'de yuzlerce kitap dosyasi olabiliyor
    // ve duz bir liste okunmuyor.
    final byKind = <String, List<RemoteFile>>{};
    for (final file in files) {
      byKind.putIfAbsent(file.kind, () => []).add(file);
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.spacing.md,
        0,
        context.spacing.md,
        context.spacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Kesif adresi duzeltmisse bunu SOYLE: kullanici yazdigi adresle
          // indirilen adres arasindaki farki gorebilsin.
          if (result.resolvedBase != source.baseUrl)
            Padding(
              padding: EdgeInsets.only(bottom: context.spacing.xs),
              child: Text(
                l10n.contentSourceResolved(result.resolvedBase),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          for (final entry in byKind.entries)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(_kindLabel(entry.key)),
              subtitle: Text(
                '${entry.value.where((f) => selected.contains(f.path)).length}'
                ' / ${entry.value.length}',
              ),
              children: [
                CheckboxListTile(
                  dense: true,
                  title: Text(l10n.contentSourceSelectAll),
                  value: entry.value.every((f) => selected.contains(f.path)),
                  onChanged: (value) => setState(() {
                    final set = _selected.putIfAbsent(source.id, () => {});
                    for (final file in entry.value) {
                      value == true
                          ? set.add(file.path)
                          : set.remove(file.path);
                    }
                  }),
                ),
                for (final file in entry.value)
                  CheckboxListTile(
                    dense: true,
                    title: Text(file.source.isEmpty ? file.path : file.source),
                    value: selected.contains(file.path),
                    onChanged: (value) => setState(() {
                      final set = _selected.putIfAbsent(source.id, () => {});
                      value == true
                          ? set.add(file.path)
                          : set.remove(file.path);
                    }),
                  ),
              ],
            ),
          SizedBox(height: context.spacing.sm),
          FilledButton.icon(
            onPressed: selected.isEmpty || _busySourceId != null
                ? null
                : () => _import(source, result),
            icon: const Icon(Icons.download_outlined),
            label: Text(l10n.contentSourceImportSelected),
          ),
        ],
      ),
    );
  }

  /// Kesif neden bos dondu.
  ///
  /// Eskiden yalnizca "bulunamadi" yaziyordu; kullanici adresi mi yanlis
  /// yazdigini yoksa sunucunun mu reddettigini goremiyordu.
  Widget _problem(DiscoveryResult result) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final status = '${result.status ?? '-'}';
    final message = switch (result.problem) {
      DiscoveryProblem.network => l10n.contentSourceProblemNetwork,
      DiscoveryProblem.blocked => l10n.contentSourceProblemBlocked(status),
      DiscoveryProblem.notJson => l10n.contentSourceProblemNotJson,
      DiscoveryProblem.notFound => l10n.contentSourceProblemNotFound(status),
      DiscoveryProblem.none => l10n.contentSourceNothingFound,
    };

    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.spacing.md,
        0,
        context.spacing.md,
        context.spacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }

  String _kindLabel(String kind) {
    final l10n = L10n.of(context);
    return switch (kind) {
      'monster' => l10n.contentSourceKindMonster,
      'spell' => l10n.contentSourceKindSpell,
      'item' => l10n.contentSourceKindItem,
      'race' => l10n.contentSourceKindRace,
      'background' => l10n.contentSourceKindBackground,
      'feat' => l10n.contentSourceKindFeat,
      _ => kind,
    };
  }

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.${date.year}';

  Future<void> _addSource() async {
    final l10n = L10n.of(context);
    final nameController = TextEditingController();
    final urlController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.contentSourceAdd),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(labelText: l10n.contentSourceName),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: l10n.contentSourceUrl,
                helperText: l10n.contentSourceUrlHint,
                helperMaxLines: 2,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    final url = urlController.text.trim();
    final name = nameController.text.trim();
    nameController.dispose();
    urlController.dispose();
    if (confirmed != true || url.isEmpty) return;

    await ref
        .read(contentSourceRepositoryProvider)
        .add(name: name.isEmpty ? url : name, baseUrl: url);
  }

  Future<void> _removeSource(ContentSource source) async {
    await ref.read(contentSourceRepositoryProvider).remove(source.id);
    if (!mounted) return;
    setState(() {
      _discovered.remove(source.id);
      _selected.remove(source.id);
    });
  }

  Future<void> _discover(ContentSource source) async {
    setState(() {
      _busySourceId = source.id;
      _status = L10n.of(context).contentSourceDiscover;
    });
    try {
      final result = await FiveToolsSource(baseUrl: source.baseUrl).discover();
      if (!mounted) return;
      setState(() {
        _discovered[source.id] = result;
        // Kesif sonrasi hicbiri secili degil: binlerce kaydi yanlislikla
        // cekmek kolay olmasin.
        _selected[source.id] = {};
        _status = null;
      });
    } finally {
      if (mounted) setState(() => _busySourceId = null);
    }
  }

  Future<void> _import(ContentSource source, DiscoveryResult result) async {
    final l10n = L10n.of(context);
    final selected = _selected[source.id] ?? const <String>{};
    final chosen = result.files
        .where((f) => selected.contains(f.path))
        .toList();
    if (chosen.isEmpty) return;

    setState(() => _busySourceId = source.id);
    try {
      final report = await ref
          .read(fiveToolsImporterProvider)
          .importFiles(
            // Kesif adresi duzeltmis olabilir (or. `<kok>/data`); indirme
            // BULUNAN koku kullanmali, kullanicinin yazdigini degil.
            FiveToolsSource(baseUrl: result.resolvedBase),
            chosen,
            onProgress: (file, index, total) {
              if (!mounted) return;
              setState(
                () => _status = l10n.contentSourceImporting(
                  '${index + 1}/$total  ${file.source.isEmpty ? file.path : file.source}',
                ),
              );
            },
            // Gorsel indirme kayit yazmadan cok daha uzun surebiliyor
            // (canavar basina bir istek); ilerleme ayrica bildiriliyor
            // yoksa arayuz donmus gibi gorunuyor.
            onImage: (done, total) {
              if (!mounted) return;
              setState(() => _status = l10n.contentSourceImages(done, total));
            },
          );
      await ref.read(contentSourceRepositoryProvider).markImported(source.id);
      if (!mounted) return;
      setState(
        () => _status = l10n.contentSourceDone(
          report.monsters,
          report.spells,
          report.items,
          report.others,
        ),
      );
    } finally {
      if (mounted) setState(() => _busySourceId = null);
    }
  }

  Future<void> _importLocalFiles() async {
    final l10n = L10n.of(context);
    final picked = await openFiles(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'JSON', extensions: ['json']),
      ],
    );
    if (picked.isEmpty || !mounted) return;

    setState(() {
      _busySourceId = 'local';
      _status = l10n.contentSourceLocalFiles;
    });
    try {
      final importer = ref.read(fiveToolsImporterProvider);
      var monsters = 0;
      var spells = 0;
      var items = 0;
      var others = 0;
      for (final (index, file) in picked.indexed) {
        if (mounted) {
          setState(
            () => _status = l10n.contentSourceImporting(
              '${index + 1}/${picked.length}  ${file.name}',
            ),
          );
        }
        // Bozuk bir dosya digerlerini engellemesin.
        Object? decoded;
        try {
          decoded = jsonDecode(await File(file.path).readAsString());
        } on Object {
          continue;
        }
        final report = await importer.importJsonBody(decoded);
        monsters += report.monsters;
        spells += report.spells;
        items += report.items;
        others += report.others;
      }
      if (!mounted) return;
      setState(
        () => _status = l10n.contentSourceDone(monsters, spells, items, others),
      );
    } finally {
      if (mounted) setState(() => _busySourceId = null);
    }
  }

  Future<void> _deleteImported() async {
    final l10n = L10n.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.contentSourceDeleteImported),
        content: Text(l10n.contentSourceDeleteImportedBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final removed = await ref.read(fiveToolsImporterProvider).deleteImported();
    if (!mounted) return;
    setState(() => _status = l10n.contentSourceDeleted(removed));
  }
}
