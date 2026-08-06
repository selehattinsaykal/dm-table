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
import '../../domain/rules/dice.dart';
import '../../domain/rules/experience.dart';
import '../../l10n/app_localizations.dart';
import '../characters/character_providers.dart';
import '../characters/character_sheet_page.dart';
import '../compendium/detail_sheets.dart';
import '../dice/dice_sheet.dart';
import 'codex_block_editors.dart';
import 'codex_inline.dart';
import 'codex_page.dart';
import 'codex_providers.dart';

/// Kayitlar gorselleri portre klasorunde saklanir (genel gorsel deposu).
final _codexImages = CharacterImageStore();

/// Kayitlar videolari ayri codex_media klasorunde saklanir.
final _codexMedia = CodexMediaStore();

/// Blok tabanli belge: Goruntule modu etkilesimli (zar atilir, baglantilar
/// acilir), Duzenle modu blok ekle/sirala/duzenle/sil.
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
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
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
                          onReorderItem: (oldIndex, newIndex) => repo
                              .reorderBlock(widget.pageId, oldIndex, newIndex),
                          itemBuilder: (context, i) => _BlockTile(
                            key: ValueKey(blocks[i].id),
                            pageId: widget.pageId,
                            block: blocks[i],
                            editing: true,
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
                for (final block in blocks)
                  _BlockTile(
                    key: ValueKey(block.id),
                    pageId: widget.pageId,
                    block: block,
                    editing: false,
                  ),
              ],
            ),
    );
  }

  Future<void> _addBlock(BuildContext context) async {
    final type = await showModalBottomSheet<CodexBlockType>(
      context: context,
      showDragHandle: true,
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
  CodexBlockType.callout => {'emoji': '💡', 'text': ''},
  CodexBlockType.divider => <String, dynamic>{},
  CodexBlockType.image => {'path': null, 'caption': ''},
  CodexBlockType.video => {'path': null, 'caption': ''},
  CodexBlockType.link => {'url': '', 'label': ''},
  CodexBlockType.table => {
    'header': true,
    'rows': [
      ['', ''],
      ['', ''],
    ],
  },
  CodexBlockType.chart => {
    'title': '',
    'items': [
      {'label': '', 'value': 0},
    ],
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

// --- Blok kabuğu (görüntüle/düzenle sarmalayıcı) -------------------------

class _BlockTile extends ConsumerWidget {
  const _BlockTile({
    required this.pageId,
    required this.block,
    required this.editing,
    super.key,
  });

  final String pageId;
  final CodexBlock block;
  final bool editing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = _BlockContent(block: block, editing: editing);
    if (!editing) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: content,
      );
    }
    final l10n = L10n.of(context);
    final repo = ref.read(codexRepositoryProvider);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: content),
            IconButton(
              tooltip: l10n.edit,
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => editCodexBlock(context, ref, block),
            ),
            IconButton(
              tooltip: l10n.delete,
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () => repo.deleteBlock(block.id),
            ),
            const Icon(Icons.drag_handle, size: 20),
          ],
        ),
      ),
    );
  }
}

// --- Blok görünümü -------------------------------------------------------

class _BlockContent extends ConsumerWidget {
  const _BlockContent({required this.block, required this.editing});

  final CodexBlock block;
  final bool editing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final type = CodexBlockType.fromName(block.type);
    final data = jsonDecode(block.dataJson) as Map<String, dynamic>;

    switch (type) {
      case CodexBlockType.heading:
        final level = (data['level'] as int? ?? 2).clamp(1, 3);
        final style = switch (level) {
          1 => theme.textTheme.headlineSmall,
          2 => theme.textTheme.titleLarge,
          _ => theme.textTheme.titleMedium,
        };
        return buildCodexInline(
          context,
          '${data['text'] ?? ''}',
          onTap: editing ? null : (token) => _handleInline(context, ref, token),
          style: style,
        );

      case CodexBlockType.text:
        return buildCodexInline(
          context,
          '${data['text'] ?? ''}',
          onTap: editing ? null : (token) => _handleInline(context, ref, token),
          style: readingStyle(context),
        );

      case CodexBlockType.bulleted:
        final items = (data['items'] as List? ?? const []).cast<String>();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('•  ', style: readingStyle(context)),
                    Expanded(
                      child: buildCodexInline(
                        context,
                        item,
                        onTap: editing
                            ? null
                            : (token) => _handleInline(context, ref, token),
                        style: readingStyle(context),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );

      case CodexBlockType.checklist:
        final items = (data['items'] as List? ?? const []);
        return Column(
          children: [
            for (final (i, raw) in items.indexed)
              _ChecklistRow(
                label: buildCodexInline(
                  context,
                  '${(raw as Map)['text'] ?? ''}',
                  onTap: editing
                      ? null
                      : (token) => _handleInline(context, ref, token),
                  style: readingStyle(context),
                ),
                done: raw['done'] as bool? ?? false,
                onToggle: (v) {
                  final next = [...items];
                  next[i] = {'text': raw['text'], 'done': v};
                  ref.read(codexRepositoryProvider).updateBlock(block.id, {
                    ...data,
                    'items': next,
                  });
                },
              ),
          ],
        );

      case CodexBlockType.callout:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${data['emoji'] ?? '💡'}',
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: buildCodexInline(
                  context,
                  '${data['text'] ?? ''}',
                  onTap: editing
                      ? null
                      : (token) => _handleInline(context, ref, token),
                  style: readingStyle(context),
                ),
              ),
            ],
          ),
        );

      case CodexBlockType.divider:
        return const OrnamentDivider();

      case CodexBlockType.image:
        return _CodexImage(
          path: data['path'] as String?,
          caption: '${data['caption'] ?? ''}',
        );

      case CodexBlockType.video:
        return _CodexVideo(
          path: data['path'] as String?,
          caption: '${data['caption'] ?? ''}',
        );

      case CodexBlockType.link:
        final url = '${data['url'] ?? ''}';
        final label = '${data['label'] ?? ''}';
        return Align(
          alignment: Alignment.centerLeft,
          child: ActionChip(
            avatar: const Icon(Icons.open_in_new, size: 18),
            label: Text(
              label.isNotEmpty
                  ? label
                  : (url.isEmpty ? L10n.of(context).codexBlockLink : url),
            ),
            onPressed: (editing || url.isEmpty)
                ? null
                : () => _openLink(context, url),
          ),
        );

      case CodexBlockType.table:
        final rows = (data['rows'] as List? ?? const [])
            .map((r) => (r as List).map((c) => '$c').toList())
            .toList();
        return _CodexTable(
          rows: rows,
          header: data['header'] as bool? ?? false,
          onTap: editing ? null : (token) => _handleInline(context, ref, token),
        );

      case CodexBlockType.chart:
        final items = (data['items'] as List? ?? const [])
            .map(
              (e) => (
                label: '${(e as Map)['label'] ?? ''}',
                value: (e['value'] as num?)?.toDouble() ?? 0,
              ),
            )
            .toList();
        return _CodexChart(title: '${data['title'] ?? ''}', items: items);

      case CodexBlockType.dice:
        final label = '${data['label'] ?? ''}';
        final expr = '${data['expression'] ?? ''}';
        return Align(
          alignment: Alignment.centerLeft,
          child: ActionChip(
            avatar: const Icon(Icons.casino, size: 18),
            label: Text(label.isEmpty ? expr : '$label  ($expr)'),
            onPressed: editing ? null : () => _rollDice(context, label, expr),
          ),
        );

      case CodexBlockType.pageLink:
        final targetId = data['pageId'] as String?;
        return Align(
          alignment: Alignment.centerLeft,
          child: ActionChip(
            avatar: const Icon(Icons.description_outlined, size: 18),
            label: Text(
              '${data['label'] ?? ''}'.isEmpty
                  ? L10n.of(context).codexBlockPageLink
                  : '${data['label']}',
            ),
            onPressed: (editing || targetId == null)
                ? null
                : () => openCodexPage(context, targetId),
          ),
        );

      case CodexBlockType.entityLink:
        final kind = CodexEntityKind.fromName('${data['kind'] ?? 'monster'}');
        final key = data['key'] as String?;
        return Align(
          alignment: Alignment.centerLeft,
          child: ActionChip(
            avatar: Icon(_entityIcon(kind), size: 18),
            label: Text('${data['label'] ?? ''}'),
            onPressed: (editing || key == null)
                ? null
                : () => _openEntity(context, ref, kind, key),
          ),
        );

      case CodexBlockType.characterEmbed:
        return _CharacterEmbed(
          characterId: data['characterId'] as String?,
          fallbackName: '${data['name'] ?? ''}',
          editing: editing,
        );
    }
  }

  Future<void> _openWiki(
    BuildContext context,
    WidgetRef ref,
    String title,
  ) async {
    final repo = ref.read(codexRepositoryProvider);
    final l10n = L10n.of(context);
    final existing = await repo.findPageByTitle(title);
    if (existing != null) {
      if (context.mounted) openCodexPage(context, existing.id);
      return;
    }
    if (!context.mounted) return;
    final create = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.codexWikiMissingTitle),
        content: Text(l10n.codexWikiMissingBody(title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.codexWikiCreate),
          ),
        ],
      ),
    );
    if (create == true) {
      final id = await repo.createPage(title: title);
      if (context.mounted) openCodexPage(context, id);
    }
  }

  /// Satir-ici bir parcaya (wiki/zar/ref) dokununca calisir.
  void _handleInline(
    BuildContext context,
    WidgetRef ref,
    CodexInlineToken token,
  ) {
    switch (token.kind) {
      case CodexInlineKind.wiki:
        _openWiki(context, ref, token.text);
      case CodexInlineKind.roll:
        _rollDice(context, token.text, token.text);
      case CodexInlineKind.characterRef:
        _openCharacterByName(context, ref, token.text);
      case CodexInlineKind.monsterRef:
        _openEntityByName(context, ref, CodexEntityKind.monster, token.text);
      case CodexInlineKind.spellRef:
        _openEntityByName(context, ref, CodexEntityKind.spell, token.text);
      case CodexInlineKind.itemRef:
        _openEntityByName(context, ref, CodexEntityKind.item, token.text);
      case CodexInlineKind.link:
        _openLink(context, token.text);
      case CodexInlineKind.pageRef:
        // Sayfa basligiyla ac (yoksa olustur) — wiki ile ayni davranis.
        _openWiki(context, ref, token.text);
      case CodexInlineKind.plain:
      case CodexInlineKind.bold:
      case CodexInlineKind.italic:
      case CodexInlineKind.code:
        break;
    }
  }

  Future<void> _openCharacterByName(
    BuildContext context,
    WidgetRef ref,
    String name,
  ) async {
    final all = await ref.read(charactersProvider.future);
    if (!context.mounted) return;
    final needle = name.toLowerCase();
    final c =
        all.where((x) => x.name.toLowerCase() == needle).firstOrNull ??
        all.where((x) => x.name.toLowerCase().contains(needle)).firstOrNull;
    if (c == null) {
      _notFound(context, ref, name);
      return;
    }
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => CharacterSheetPage(characterId: c.id)),
    );
  }

  Future<void> _openEntityByName(
    BuildContext context,
    WidgetRef ref,
    CodexEntityKind kind,
    String name,
  ) async {
    final repo = ref.read(compendiumRepositoryProvider);
    final needle = name.toLowerCase();
    String? key;
    switch (kind) {
      case CodexEntityKind.monster:
        final rows = await repo.searchMonsters(query: name, limit: 10);
        key =
            (rows.where((m) => m.name.toLowerCase() == needle).firstOrNull ??
                    rows.firstOrNull)
                ?.key;
      case CodexEntityKind.spell:
        final rows = await repo.searchSpells(query: name, limit: 10);
        key =
            (rows.where((s) => s.name.toLowerCase() == needle).firstOrNull ??
                    rows.firstOrNull)
                ?.key;
      case CodexEntityKind.item:
        final rows = await repo.searchItems(query: name, limit: 10);
        key =
            (rows.where((i) => i.name.toLowerCase() == needle).firstOrNull ??
                    rows.firstOrNull)
                ?.key;
      case CodexEntityKind.magicItem:
      case CodexEntityKind.character:
        break;
    }
    if (key == null) {
      if (context.mounted) _notFound(context, ref, name);
      return;
    }
    if (context.mounted) await _openEntity(context, ref, kind, key);
  }

  void _notFound(BuildContext context, WidgetRef ref, String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(L10n.of(context).codexRefNotFound(name))),
    );
  }

  void _rollDice(BuildContext context, String label, String expr) {
    final parsed = parseDiceExpression(expr);
    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.of(context).codexBadExpression)),
      );
      return;
    }
    final roll = DiceRoller().roll(
      sides: parsed.sides,
      count: parsed.count,
      modifier: parsed.modifier,
      label: label.isEmpty ? expr : label,
    );
    showRollResult(context, roll);
  }

  Future<void> _openLink(BuildContext context, String url) async {
    // Yalin adresleri (ornegin "example.com") da acabilmek icin sema ekle.
    final normalized = url.contains('://') ? url : 'https://$url';
    final uri = Uri.tryParse(normalized);
    final ok =
        uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.of(context).codexLinkFailed(url))),
      );
    }
  }
}

IconData _entityIcon(CodexEntityKind kind) => switch (kind) {
  CodexEntityKind.monster => Icons.pest_control,
  CodexEntityKind.spell => Icons.auto_awesome,
  CodexEntityKind.item => Icons.backpack_outlined,
  CodexEntityKind.magicItem => Icons.auto_fix_high,
  CodexEntityKind.character => Icons.person,
};

Future<void> _openEntity(
  BuildContext context,
  WidgetRef ref,
  CodexEntityKind kind,
  String key,
) async {
  final db = ref.read(databaseProvider);
  switch (kind) {
    case CodexEntityKind.character:
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => CharacterSheetPage(characterId: key)),
      );
    case CodexEntityKind.monster:
      final m = await (db.select(
        db.monsters,
      )..where((t) => t.key.equals(key))).getSingleOrNull();
      if (m != null && context.mounted) {
        await showDetailSheet(context, MonsterDetail(monster: m));
      }
    case CodexEntityKind.spell:
      final s = await (db.select(
        db.spells,
      )..where((t) => t.key.equals(key))).getSingleOrNull();
      if (s != null && context.mounted) {
        await showDetailSheet(context, SpellDetail(spell: s));
      }
    case CodexEntityKind.item:
      final i = await (db.select(
        db.items,
      )..where((t) => t.key.equals(key))).getSingleOrNull();
      if (i != null && context.mounted) {
        await showDetailSheet(context, ItemDetail(item: i));
      }
    case CodexEntityKind.magicItem:
      final mi = await (db.select(
        db.magicItems,
      )..where((t) => t.key.equals(key))).getSingleOrNull();
      if (mi != null && context.mounted) {
        await showDetailSheet(context, MagicItemDetail(item: mi));
      }
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.label,
    required this.done,
    required this.onToggle,
  });

  /// Satir-ici bicimlendirilmis etiket (buildCodexInline ile kurulur).
  final Widget label;
  final bool done;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Yalniz kutu tiklamayi toggle eder; etiketteki satir-ici ogeler
          // (zar/wiki/ref) kendi dokunuslarini korur.
          InkWell(
            onTap: () => onToggle(!done),
            child: Icon(
              done ? Icons.check_box : Icons.check_box_outline_blank,
              size: 20,
              color: done
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Opacity(opacity: done ? 0.55 : 1, child: label),
          ),
        ],
      ),
    );
  }
}

class _CodexImage extends StatelessWidget {
  const _CodexImage({required this.path, required this.caption});

  final String? path;
  final String caption;

  @override
  Widget build(BuildContext context) {
    if (path == null) {
      return const SizedBox(
        height: 80,
        child: Center(child: Icon(Icons.image_outlined)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: FutureBuilder<File>(
            future: _codexImages.resolve(path!),
            builder: (context, snap) {
              final f = snap.data;
              if (f == null || !f.existsSync()) {
                return const SizedBox(
                  height: 120,
                  child: Center(child: Icon(Icons.broken_image_outlined)),
                );
              }
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: Image.file(f, fit: BoxFit.contain),
              );
            },
          ),
        ),
        if (caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              caption,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

/// Uygulama ici video oynatici (media_kit). Otomatik oynatmaz; kullanici
/// baslatir. Dosya yoksa "bulunamadi" gosterir.
class _CodexVideo extends StatefulWidget {
  const _CodexVideo({required this.path, required this.caption});

  final String? path;
  final String caption;

  @override
  State<_CodexVideo> createState() => _CodexVideoState();
}

class _CodexVideoState extends State<_CodexVideo> {
  Player? _player;
  VideoController? _controller;
  bool _missing = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(_CodexVideo old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) {
      _player?.dispose();
      _player = null;
      _controller = null;
      _missing = false;
      _init();
    }
  }

  Future<void> _init() async {
    final path = widget.path;
    if (path == null) return;
    final file = await _codexMedia.resolve(path);
    if (!file.existsSync()) {
      if (mounted) setState(() => _missing = true);
      return;
    }
    final player = Player();
    final controller = VideoController(player);
    await player.open(Media(file.path), play: false);
    if (!mounted) {
      await player.dispose();
      return;
    }
    setState(() {
      _player = player;
      _controller = controller;
    });
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.path == null || _missing) {
      return SizedBox(
        height: 100,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.path == null
                    ? Icons.movie_outlined
                    : Icons.broken_image_outlined,
              ),
              if (_missing) ...[
                const SizedBox(height: 4),
                Text(
                  L10n.of(context).codexVideoMissing,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      );
    }
    final controller = _controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 240,
            child: controller == null
                ? const AppLoading()
                : Video(controller: controller),
          ),
        ),
        if (widget.caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              widget.caption,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

class _CodexTable extends StatelessWidget {
  const _CodexTable({required this.rows, required this.header, this.onTap});

  final List<List<String>> rows;
  final bool header;

  /// Hucre satir-ici parcalarina (wiki/zar/ref) dokununca calisir; null ise
  /// (duzenleme modu) tiklanamaz.
  final void Function(CodexInlineToken token)? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (rows.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: header ? 44 : 0,
        columns: header
            ? [for (final c in rows.first) DataColumn(label: _cell(context, c))]
            : [
                for (final _ in rows.first)
                  const DataColumn(label: SizedBox.shrink()),
              ],
        rows: [
          for (final row in (header ? rows.skip(1) : rows))
            DataRow(
              cells: [
                for (var i = 0; i < rows.first.length; i++)
                  DataCell(_cell(context, i < row.length ? row[i] : '')),
              ],
            ),
        ],
        border: TableBorder.all(color: theme.dividerColor, width: 0.5),
      ),
    );
  }

  Widget _cell(BuildContext context, String text) =>
      buildCodexInline(context, text, onTap: onTap);
}

/// Canli oyuncu karakter karti: adi, XP-seviyesi ve HP; karakter kagidiyla
/// senkron (charactersProvider akisi). Dokununca tam kagit acilir.
class _CharacterEmbed extends ConsumerWidget {
  const _CharacterEmbed({
    required this.characterId,
    required this.fallbackName,
    required this.editing,
  });

  final String? characterId;
  final String fallbackName;
  final bool editing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final charactersAsync = ref.watch(charactersProvider);
    final all = charactersAsync.value ?? const [];
    final c = characterId == null
        ? null
        : all.where((x) => x.id == characterId).firstOrNull;

    if (c == null) {
      // Liste henuz yuklenmediyse "bulunamadi" demeden once bekle: aksi halde
      // karakter var olsa da kart yanlislikla "Karakter bulunamadi" gosterir.
      if (characterId != null && charactersAsync.isLoading) {
        return const Card(
          child: ListTile(
            leading: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            title: Text(''),
          ),
        );
      }
      return Card(
        child: ListTile(
          leading: const Icon(Icons.person_off_outlined),
          title: Text(
            fallbackName.isEmpty ? l10n.codexCharacterMissing : fallbackName,
          ),
          subtitle: Text(l10n.codexCharacterMissing),
        ),
      );
    }

    final level = Experience.levelForXp(c.experiencePoints);
    final ratio = c.hitPointsMax == 0
        ? 0.0
        : c.hitPointsCurrent / c.hitPointsMax;

    return Card(
      child: InkWell(
        onTap: editing
            ? null
            : () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (_) => CharacterSheetPage(characterId: c.id),
                ),
              ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                child: Text(c.name.isEmpty ? '?' : c.name.characters.first),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name, style: theme.textTheme.titleMedium),
                    Text(
                      l10n.codexCharacterLevel(level),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: ratio.clamp(0.0, 1.0),
                      minHeight: 5,
                      color: ratio <= 0.25
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${c.hitPointsCurrent}/${c.hitPointsMax}',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Basit cubuk grafik (harici bagimlilik yok; degerlere gore oransal cubuklar).
class _CodexChart extends StatelessWidget {
  const _CodexChart({required this.title, required this.items});

  final String title;
  final List<({String label, double value})> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (items.isEmpty) return const SizedBox.shrink();
    final maxValue = items
        .map((e) => e.value)
        .fold<double>(0, (a, b) => b > a ? b : a);
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(title, style: theme.textTheme.titleSmall),
          ),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Text(
                    item.label,
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => Stack(
                      children: [
                        Container(
                          height: 20,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Container(
                          height: 20,
                          width: (constraints.maxWidth * (item.value / safeMax))
                              .clamp(0.0, constraints.maxWidth),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 44,
                  child: Text(
                    _fmt(item.value),
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

class _BlockTypePicker extends StatelessWidget {
  const _BlockTypePicker();

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final entries = <(CodexBlockType, IconData, String)>[
      (CodexBlockType.text, Icons.notes, l10n.codexBlockText),
      (CodexBlockType.heading, Icons.title, l10n.codexBlockHeading),
      (
        CodexBlockType.bulleted,
        Icons.format_list_bulleted,
        l10n.codexBlockBulleted,
      ),
      (CodexBlockType.checklist, Icons.checklist, l10n.codexBlockChecklist),
      (CodexBlockType.callout, Icons.lightbulb_outline, l10n.codexBlockCallout),
      (CodexBlockType.table, Icons.grid_on, l10n.codexBlockTable),
      (CodexBlockType.chart, Icons.bar_chart, l10n.codexBlockChart),
      (CodexBlockType.image, Icons.image_outlined, l10n.codexBlockImage),
      (CodexBlockType.video, Icons.movie_outlined, l10n.codexBlockVideo),
      (CodexBlockType.link, Icons.link, l10n.codexBlockLink),
      (CodexBlockType.divider, Icons.horizontal_rule, l10n.codexBlockDivider),
      (CodexBlockType.dice, Icons.casino, l10n.codexBlockDice),
      (
        CodexBlockType.pageLink,
        Icons.description_outlined,
        l10n.codexBlockPageLink,
      ),
      (CodexBlockType.entityLink, Icons.link, l10n.codexBlockEntityLink),
      (
        CodexBlockType.characterEmbed,
        Icons.badge_outlined,
        l10n.codexBlockCharacter,
      ),
    ];
    return SafeArea(
      child: Wrap(
        children: [
          for (final (type, icon, label) in entries)
            SizedBox(
              width: 160,
              child: ListTile(
                leading: Icon(icon),
                title: Text(label),
                onTap: () => Navigator.pop(context, type),
              ),
            ),
        ],
      ),
    );
  }
}
