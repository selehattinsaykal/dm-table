import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ai_settings_provider.dart';
import '../../domain/rules/random_table.dart';
import '../../l10n/app_localizations.dart';
import '../tables/table_providers.dart';
import 'ai_tools_shared.dart';
import 'table_generator.dart';

/// AI Rastgele Tablo Üreteci.
///
/// Üretilen satırlar zar yüzüne [distributeEvenly] ile oturtulur; böylece
/// kaydedilen tablo her zaman boşluksuz/çakışmasız olur (model istenen
/// sayıda madde döndürmese bile).
class TableTool extends ConsumerStatefulWidget {
  const TableTool({super.key});

  @override
  ConsumerState<TableTool> createState() => _TableToolState();
}

class _TableToolState extends ConsumerState<TableTool> {
  final _topic = TextEditingController();
  final _context = TextEditingController();
  final _run = AiRunState();

  int _diceSides = 20;
  int _rowCount = 20;
  TableTone _tone = TableTone.gritty;
  bool _saved = false;

  @override
  void dispose() {
    _topic.dispose();
    _context.dispose();
    super.dispose();
  }

  String _toneLabel(L10n l10n, TableTone t) => switch (t) {
    TableTone.gritty => l10n.aiTableToneGritty,
    TableTone.humorous => l10n.aiTableToneHumorous,
    TableTone.epic => l10n.aiTableToneEpic,
    TableTone.mundane => l10n.aiTableToneMundane,
  };

  Future<void> _generate() async {
    final l10n = L10n.of(context);
    final built = buildTablePrompt(
      topic: _topic.text,
      diceSides: _diceSides,
      rowCount: _rowCount,
      tone: _tone,
      languageName: l10n.localeName == 'tr' ? 'Türkçe' : 'English',
      context: _context.text,
    );
    _saved = false;
    await _run.generate(
      context,
      ref,
      built.system,
      built.user,
      () => setState(() {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    if (!ref.watch(aiSettingsProvider).enabled) return const AiNotConfigured();

    final result = _run.result == null
        ? null
        : parseTableResult(_run.result!, fallbackDiceSides: _diceSides);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _topic,
          decoration: InputDecoration(
            labelText: l10n.aiTableTopic,
            helperText: l10n.aiTableTopicHint,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),

        Text(l10n.tablesDice, style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            for (final sides in kDiceSides)
              ChoiceChip(
                label: Text('d$sides'),
                selected: _diceSides == sides,
                onSelected: _run.loading
                    ? null
                    : (_) => setState(() {
                        _diceSides = sides;
                        // Madde sayisi varsayilan olarak zar yuzune esitlenir;
                        // kullanici asagidan degistirebilir.
                        _rowCount = sides > 30 ? 30 : sides;
                      }),
              ),
          ],
        ),
        const SizedBox(height: 12),
        AiSliderRow(
          label: l10n.aiTableRowCount,
          value: _rowCount,
          min: 4,
          max: 30,
          enabled: !_run.loading,
          onChanged: (v) => setState(() => _rowCount = v),
        ),
        const SizedBox(height: 12),

        Text(l10n.aiTableTone, style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in TableTone.values)
              ChoiceChip(
                label: Text(_toneLabel(l10n, t)),
                selected: _tone == t,
                onSelected: _run.loading
                    ? null
                    : (_) => setState(() => _tone = t),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _context,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: l10n.aiTableContext,
            helperText: l10n.aiTableContextHint,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),

        if (result == null)
          FilledButton.icon(
            onPressed: _run.loading ? null : _generate,
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: Text(l10n.codexAiGenerate),
          ),
        if (_run.error != null)
          AiErrorBox(message: _run.error!, detail: _run.errorDetail),
        if (_run.loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (result != null) ..._resultSections(l10n, theme, result),
      ],
    );
  }

  List<Widget> _resultSections(L10n l10n, ThemeData theme, TableResult r) {
    // Satirlar zar yuzune oturtulur: model 18 madde donse bile tablo
    // bosluksuz olur.
    final rows = distributeEvenly(r.rows, _diceSides);
    return [
      if (r.name.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(r.name, style: theme.textTheme.titleLarge),
        ),
      Text(
        [
          'd$_diceSides',
          l10n.tablesRowCount(rows.length),
          if (r.category.isNotEmpty) r.category,
        ].join(' · '),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
      const SizedBox(height: 12),
      for (final row in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 56,
                child: Text(
                  row.min == row.max ? '${row.min}' : '${row.min}–${row.max}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              Expanded(child: Text(row.text)),
            ],
          ),
        ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: rows.isEmpty || _saved
                ? null
                : () => _saveTable(l10n, r, rows),
            icon: const Icon(Icons.save_outlined, size: 18),
            label: Text(_saved ? l10n.aiTableSaved : l10n.aiTableSave),
          ),
          TextButton(
            onPressed: () => setState(() {
              _run.result = null;
              _run.error = null;
              _saved = false;
            }),
            child: Text(l10n.aiRegenerate),
          ),
        ],
      ),
    ];
  }

  Future<void> _saveTable(
    L10n l10n,
    TableResult r,
    List<RandomTableRow> rows,
  ) async {
    final repo = ref.read(randomTableRepositoryProvider);
    final name = r.name.isEmpty ? l10n.tablesNew : r.name;
    final id = await repo.create(name, diceSides: _diceSides);
    await repo.update(id, category: r.category, rows: rows);

    if (!mounted) return;
    setState(() => _saved = true);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.aiTableSavedTo(name))));
  }
}
