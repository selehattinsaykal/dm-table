import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../app/ui/ui.dart';
import '../../data/character_image_store.dart';
import '../../data/codex_media_store.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../domain/codex/codex_block.dart';
import '../../domain/codex/codex_style.dart';
import '../../domain/rules/dice.dart';
import '../../domain/rules/experience.dart';
import '../../l10n/app_localizations.dart';
import '../characters/character_providers.dart';
import '../characters/character_sheet_page.dart';
import '../compendium/detail_sheets.dart';
import '../dice/dice_sheet.dart';
import '../dice/roll_log.dart';
import 'codex_block_editors.dart';
import 'codex_charts.dart';
import 'codex_counter.dart';
import 'codex_inline.dart';
import 'codex_page.dart';
import 'codex_providers.dart';
import 'codex_style_ui.dart';
import 'codex_timer.dart';

part 'codex_document_blocks.dart';
part 'codex_document_media.dart';

/// Kayitlar gorselleri portre klasorunde saklanir (genel gorsel deposu).
final _codexImages = CharacterImageStore();

/// Kayitlar videolari ayri codex_media klasorunde saklanir.
final _codexMedia = CodexMediaStore();

/// Blok tabanli belge: Goruntule modu etkilesimli (zar atilir, sayaclar
/// degisir, baglantilar acilir), Duzenle modu blok ekle/sirala/duzenle/sil
/// ve her blogun yerlesimini (genislik/hizalama/yukseklik) kenarlarindan
/// surukleyerek ayarlama.
class CodexDocumentPage extends ConsumerStatefulWidget {
  const CodexDocumentPage({required this.pageId, super.key});

  final String pageId;

  @override
  ConsumerState<CodexDocumentPage> createState() => _CodexDocumentPageState();
}

class _CodexDocumentPageState extends ConsumerState<CodexDocumentPage> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final page = ref.watch(codexPageProvider(widget.pageId)).value;
    final blocks =
        ref.watch(codexBlocksProvider(widget.pageId)).value ?? const [];
    final repo = ref.read(codexRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          page == null || page.title.isEmpty ? l10n.codexUntitled : page.title,
        ),
        actions: [
          IconButton(
            tooltip: _editing ? l10n.codexDone : l10n.edit,
            icon: Icon(_editing ? Icons.check : Icons.edit_outlined),
            onPressed: () => setState(() => _editing = !_editing),
          ),
        ],
      ),
      floatingActionButton: _editing
          ? FloatingActionButton.extended(
              onPressed: () => _addBlock(context),
              icon: const Icon(Icons.add),
              label: Text(l10n.codexAddBlock),
            )
          : null,
      body: _editing
          ? Column(
              children: [
                if (page != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      children: [
                        OutlinedButton.icon(
                          icon: Text(page.icon ?? '📄'),
                          label: Text(l10n.codexPageTitleEdit),
                          onPressed: () async {
                            final name = await codexPrompt(
                              context,
                              l10n.codexRename,
                              page.title,
                            );
                            if (name != null) {
                              await repo.renamePage(page.id, name);
                            }
                          },
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.codexResizeHint,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: blocks.isEmpty
                      ? Center(
                          child: Text(
                            l10n.codexAddBlockHint,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        )
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                          itemCount: blocks.length,
                          // Suruklemeyi yalnizca arac cubugundaki tutamak
                          // baslatir; blogun govdesi kenar tutamaklariyla
                          // yeniden boyutlandirma icin serbest kalir.
                          buildDefaultDragHandles: false,
                          onReorderItem: (oldIndex, newIndex) => repo
                              .reorderBlock(widget.pageId, oldIndex, newIndex),
                          itemBuilder: (context, i) => _BlockTile(
                            key: ValueKey(blocks[i].id),
                            pageId: widget.pageId,
                            block: blocks[i],
                            editing: true,
                            index: i,
                            count: blocks.length,
                          ),
                        ),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (blocks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        l10n.codexPageEmpty,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                  ),
                for (final (i, block) in blocks.indexed)
                  _BlockTile(
                    key: ValueKey(block.id),
                    pageId: widget.pageId,
                    block: block,
                    editing: false,
                    index: i,
                    count: blocks.length,
                  ),
              ],
            ),
    );
  }

  Future<void> _addBlock(BuildContext context) async {
    final type = await showModalBottomSheet<CodexBlockType>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => const _BlockTypePicker(),
    );
    if (type == null || !context.mounted) return;
    final repo = ref.read(codexRepositoryProvider);
    final data = _defaultData(type);
    final id = await repo.addBlock(widget.pageId, type, data: data);
    // Icerik gerektiren bloklar hemen duzenlemeye acilir.
    if (!context.mounted) return;
    if (_needsImmediateEdit(type)) {
      final block = (await repo.blocks(
        widget.pageId,
      )).where((b) => b.id == id).firstOrNull;
      if (block != null && context.mounted) {
        await editCodexBlock(context, ref, block);
      }
    }
  }
}

Map<String, dynamic> _defaultData(CodexBlockType type) => switch (type) {
  CodexBlockType.heading => {'level': 2, 'text': ''},
  CodexBlockType.text => {'text': ''},
  CodexBlockType.bulleted => {
    'items': <String>[''],
  },
  CodexBlockType.checklist => {
    'items': [
      {'text': '', 'done': false},
    ],
  },
  CodexBlockType.callout => {'emoji': '💡', 'text': '', 'tone': 'info'},
  CodexBlockType.divider => {'style': CodexDividerStyle.ornament.name},
  CodexBlockType.image => {'path': null, 'caption': ''},
  CodexBlockType.video => {'path': null, 'caption': ''},
  CodexBlockType.link => {'url': '', 'label': ''},
  CodexBlockType.table => {
    'header': true,
    'zebra': true,
    'rows': [
      ['', ''],
      ['', ''],
    ],
  },
  CodexBlockType.chart => {
    'title': '',
    'type': CodexChartType.bar.name,
    'palette': CodexPalette.theme.name,
    'items': [
      {'label': '', 'value': 0},
    ],
  },
  CodexBlockType.counter => {
    'title': '',
    'style': CodexCounterStyle.row.name,
    'items': [
      {'label': '', 'value': 0, 'step': 1},
    ],
  },
  CodexBlockType.timer => {
    'title': '',
    'mode': CodexTimerMode.countdown.name,
    'duration': 300,
    'style': CodexTimerStyle.digits.name,
    'alarm': true,
  },
  CodexBlockType.dice => {'label': '', 'expression': '1d20'},
  CodexBlockType.pageLink => {'pageId': null, 'label': ''},
  CodexBlockType.entityLink => {'kind': 'monster', 'key': null, 'label': ''},
  CodexBlockType.characterEmbed => {'characterId': null, 'name': ''},
};

bool _needsImmediateEdit(CodexBlockType type) => switch (type) {
  CodexBlockType.divider => false,
  _ => true,
};

/// Blok turunun listede/arac cubugunda gorunen simgesi.
IconData codexBlockIcon(CodexBlockType type) => switch (type) {
  CodexBlockType.heading => Icons.title,
  CodexBlockType.text => Icons.notes,
  CodexBlockType.bulleted => Icons.format_list_bulleted,
  CodexBlockType.checklist => Icons.checklist,
  CodexBlockType.callout => Icons.lightbulb_outline,
  CodexBlockType.divider => Icons.horizontal_rule,
  CodexBlockType.image => Icons.image_outlined,
  CodexBlockType.video => Icons.movie_outlined,
  CodexBlockType.link => Icons.link,
  CodexBlockType.table => Icons.grid_on,
  CodexBlockType.chart => Icons.bar_chart,
  CodexBlockType.counter => Icons.exposure_plus_1,
  CodexBlockType.timer => Icons.timer_outlined,
  CodexBlockType.dice => Icons.casino,
  CodexBlockType.pageLink => Icons.description_outlined,
  CodexBlockType.entityLink => Icons.auto_awesome_motion,
  CodexBlockType.characterEmbed => Icons.badge_outlined,
};

String codexBlockLabel(L10n l10n, CodexBlockType type) => switch (type) {
  CodexBlockType.heading => l10n.codexBlockHeading,
  CodexBlockType.text => l10n.codexBlockText,
  CodexBlockType.bulleted => l10n.codexBlockBulleted,
  CodexBlockType.checklist => l10n.codexBlockChecklist,
  CodexBlockType.callout => l10n.codexBlockCallout,
  CodexBlockType.divider => l10n.codexBlockDivider,
  CodexBlockType.image => l10n.codexBlockImage,
  CodexBlockType.video => l10n.codexBlockVideo,
  CodexBlockType.link => l10n.codexBlockLink,
  CodexBlockType.table => l10n.codexBlockTable,
  CodexBlockType.chart => l10n.codexBlockChart,
  CodexBlockType.counter => l10n.codexBlockCounter,
  CodexBlockType.timer => l10n.codexBlockTimer,
  CodexBlockType.dice => l10n.codexBlockDice,
  CodexBlockType.pageLink => l10n.codexBlockPageLink,
  CodexBlockType.entityLink => l10n.codexBlockEntityLink,
  CodexBlockType.characterEmbed => l10n.codexBlockCharacter,
};

/// Alt kenardan yukseklik de suruklenebilen turler (gorsel yuzeyi olanlar).
bool _hasAdjustableHeight(CodexBlockType type) => switch (type) {
  CodexBlockType.image || CodexBlockType.video || CodexBlockType.chart => true,
  _ => false,
};

// --- Blok kabuğu (görüntüle/düzenle sarmalayıcı) -------------------------

class _BlockTile extends ConsumerWidget {
  const _BlockTile({
    required this.pageId,
    required this.block,
    required this.editing,
    required this.index,
    required this.count,
    super.key,
  });

  final String pageId;
  final CodexBlock block;
  final bool editing;
  final int index;
  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = CodexBlockType.fromName(block.type);
    final data = (jsonDecode(block.dataJson) as Map).cast<String, dynamic>();
    final layout = CodexLayout.fromData(data);
    final resizableHeight = _hasAdjustableHeight(type);

    final content = _BlockContent(
      block: block,
      type: type,
      data: data,
      layout: layout,
      editing: editing,
    );

    if (!editing) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: CodexLayoutBox(layout: layout, child: content),
      );
    }

    final repo = ref.read(codexRepositoryProvider);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BlockToolbar(
              type: type,
              layout: layout,
              index: index,
              count: count,
              onLayout: (next) =>
                  repo.updateBlock(block.id, {...data, ...next.toData()}),
              onEdit: () => editCodexBlock(context, ref, block),
              onDuplicate: () => repo.duplicateBlock(block.id),
              onDelete: () => repo.deleteBlock(block.id),
              onMove: (up) => repo.moveBlock(pageId, block.id, up: up),
              onResetSize: () {
                final cleaned = Map<String, dynamic>.from(data)
                  ..remove('width')
                  ..remove('align')
                  ..remove('height');
                repo.updateBlock(block.id, cleaned);
              },
            ),
            const SizedBox(height: 6),
            CodexResizable(
              layout: layout,
              enabled: true,
              resizableHeight: resizableHeight,
              onChanged: (next) =>
                  repo.updateBlock(block.id, {...data, ...next.toData()}),
              child: content,
            ),
          ],
        ),
      ),
    );
  }
}

/// Duzenleme modunda her blogun ustunde duran ince arac cubugu:
/// suruklu tutamak, tur etiketi, hizalama, genislik onayarlari ve eylemler.
class _BlockToolbar extends StatelessWidget {
  const _BlockToolbar({
    required this.type,
    required this.layout,
    required this.index,
    required this.count,
    required this.onLayout,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
    required this.onMove,
    required this.onResetSize,
  });

  final CodexBlockType type;
  final CodexLayout layout;
  final int index;
  final int count;
  final ValueChanged<CodexLayout> onLayout;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final void Function(bool up) onMove;
  final VoidCallback onResetSize;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);

    return Row(
      children: [
        ReorderableDragStartListener(
          index: index,
          child: MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
              child: Icon(
                Icons.drag_indicator,
                size: 18,
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Icon(codexBlockIcon(type), size: 15, color: theme.colorScheme.outline),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            codexBlockLabel(l10n, type),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const Spacer(),
        for (final align in CodexAlign.values)
          IconButton(
            tooltip: switch (align) {
              CodexAlign.left => l10n.codexAlignLeft,
              CodexAlign.center => l10n.codexAlignCenter,
              CodexAlign.right => l10n.codexAlignRight,
            },
            icon: Icon(align.icon, size: 17),
            isSelected: layout.align == align,
            visualDensity: VisualDensity.compact,
            color: layout.align == align ? theme.colorScheme.primary : null,
            onPressed: () => onLayout(layout.copyWith(align: align)),
          ),
        PopupMenuButton<double>(
          tooltip: l10n.codexWidth,
          icon: Icon(
            Icons.width_normal,
            size: 17,
            color: layout.isFullWidth ? null : theme.colorScheme.primary,
          ),
          onSelected: (value) => onLayout(layout.copyWith(width: value)),
          itemBuilder: (context) => [
            for (final preset in const [1.0, 0.75, 0.66, 0.5, 0.33, 0.25])
              PopupMenuItem(
                value: preset,
                child: Row(
                  children: [
                    if ((layout.width - preset).abs() < 0.02)
                      const Icon(Icons.check, size: 16)
                    else
                      const SizedBox(width: 16),
                    const SizedBox(width: 8),
                    Text('%${(preset * 100).round()}'),
                  ],
                ),
              ),
          ],
        ),
        IconButton(
          tooltip: l10n.edit,
          icon: const Icon(Icons.tune, size: 18),
          visualDensity: VisualDensity.compact,
          onPressed: onEdit,
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 18),
          onSelected: (value) => switch (value) {
            'duplicate' => onDuplicate(),
            'up' => onMove(true),
            'down' => onMove(false),
            'reset' => onResetSize(),
            _ => onDelete(),
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'duplicate',
              child: _menuRow(Icons.copy_all_outlined, l10n.codexDuplicate),
            ),
            if (index > 0)
              PopupMenuItem(
                value: 'up',
                child: _menuRow(Icons.arrow_upward, l10n.codexMoveUp),
              ),
            if (index < count - 1)
              PopupMenuItem(
                value: 'down',
                child: _menuRow(Icons.arrow_downward, l10n.codexMoveDown),
              ),
            PopupMenuItem(
              value: 'reset',
              child: _menuRow(Icons.aspect_ratio, l10n.codexResetSize),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'delete',
              child: _menuRow(Icons.delete_outline, l10n.delete),
            ),
          ],
        ),
      ],
    );
  }

  Widget _menuRow(IconData icon, String label) => Row(
    children: [Icon(icon, size: 18), const SizedBox(width: 10), Text(label)],
  );
}

class _BlockTypePicker extends StatefulWidget {
  const _BlockTypePicker();

  @override
  State<_BlockTypePicker> createState() => _BlockTypePickerState();
}

class _BlockTypePickerState extends State<_BlockTypePicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final groups = <(String, List<CodexBlockType>)>[
      (
        l10n.codexGroupText,
        const [
          CodexBlockType.text,
          CodexBlockType.heading,
          CodexBlockType.bulleted,
          CodexBlockType.checklist,
          CodexBlockType.callout,
          CodexBlockType.divider,
        ],
      ),
      (
        l10n.codexGroupData,
        const [
          CodexBlockType.table,
          CodexBlockType.chart,
          CodexBlockType.counter,
          CodexBlockType.timer,
          CodexBlockType.dice,
        ],
      ),
      (
        l10n.codexGroupMedia,
        const [CodexBlockType.image, CodexBlockType.video],
      ),
      (
        l10n.codexGroupLinks,
        const [
          CodexBlockType.link,
          CodexBlockType.pageLink,
          CodexBlockType.entityLink,
          CodexBlockType.characterEmbed,
        ],
      ),
    ];

    final needle = _query.trim().toLowerCase();
    bool matches(CodexBlockType t) =>
        needle.isEmpty ||
        codexBlockLabel(l10n, t).toLowerCase().contains(needle);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.codexBlockSearch,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (label, types) in groups)
                      if (types.any(matches)) ...[
                        SectionHeader(label: label),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final type in types)
                              if (matches(type))
                                ActionChip(
                                  avatar: Icon(codexBlockIcon(type), size: 18),
                                  label: Text(codexBlockLabel(l10n, type)),
                                  onPressed: () => Navigator.pop(context, type),
                                ),
                          ],
                        ),
                      ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
