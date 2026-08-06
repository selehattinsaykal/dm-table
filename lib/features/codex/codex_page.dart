import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ui/async_view.dart';
import '../../app/ui/ui.dart';
import '../../data/codex_repository.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import 'codex_document_page.dart';
import 'codex_providers.dart';

/// DM bilgi tabani ("Kayitlar"): ic ice sayfa agaci + arama. Bir sayfaya
/// dokununca blok tabanli belge acilir.
class CodexHomePage extends ConsumerStatefulWidget {
  const CodexHomePage({super.key});

  @override
  ConsumerState<CodexHomePage> createState() => _CodexHomePageState();
}

class _CodexHomePageState extends ConsumerState<CodexHomePage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final pages = ref.watch(codexPagesProvider);
    final searching = _query.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navCodex)),
      floatingActionButton: searching
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _createRoot(context),
              icon: const Icon(Icons.add),
              label: Text(l10n.codexNewPage),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: l10n.codexSearchHint,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: const OutlineInputBorder(),
                suffixIcon: searching
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _query = ''),
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: searching
                ? _SearchResults(query: _query.trim())
                : asyncView(
                    context,
                    pages,
                    loading: const SkeletonList(),
                    onRetry: () => ref.invalidate(codexPagesProvider),
                    data: (all) {
                      final roots =
                          all.where((p) => p.parentId == null).toList()..sort(
                            (a, b) => a.sortOrder.compareTo(b.sortOrder),
                          );
                      if (roots.isEmpty) return _Empty(l10n: l10n);
                      return ListView(
                        padding: const EdgeInsets.only(bottom: 88),
                        children: [
                          for (final r in roots)
                            _PageNode(page: r, all: all, depth: 0),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _createRoot(BuildContext context) async {
    final id = await ref.read(codexRepositoryProvider).createPage();
    if (!context.mounted) return;
    openCodexPage(context, id);
  }
}

/// Arama sonuclari: basligi ya da icerigi eslesenler.
class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    return FutureBuilder<List<CodexSearchHit>>(
      future: ref.read(codexRepositoryProvider).search(query),
      builder: (context, snap) {
        final hits = snap.data ?? const [];
        if (snap.connectionState == ConnectionState.done && hits.isEmpty) {
          return Center(
            child: Text(
              l10n.noResults,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          );
        }
        return ListView.builder(
          itemCount: hits.length,
          itemBuilder: (context, i) {
            final hit = hits[i];
            return ListTile(
              leading: Text(
                hit.page.icon ?? '📄',
                style: const TextStyle(fontSize: 18),
              ),
              title: Text(
                hit.page.title.isEmpty ? l10n.codexUntitled : hit.page.title,
              ),
              subtitle: Text(
                hit.snippet,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => openCodexPage(context, hit.page.id),
            );
          },
        );
      },
    );
  }
}

/// Kayitlar belgesini yeni bir rota olarak acar.
void openCodexPage(BuildContext context, String id) {
  Navigator.of(
    context,
    rootNavigator: true,
  ).push(MaterialPageRoute(builder: (_) => CodexDocumentPage(pageId: id)));
}

class _PageNode extends ConsumerStatefulWidget {
  const _PageNode({required this.page, required this.all, required this.depth});

  final CodexPage page;
  final List<CodexPage> all;
  final int depth;

  @override
  ConsumerState<_PageNode> createState() => _PageNodeState();
}

class _PageNodeState extends ConsumerState<_PageNode> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final page = widget.page;
    final children = widget.all.where((p) => p.parentId == page.id).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final hasChildren = children.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: widget.depth * 16),
          child: ListTile(
            leading: hasChildren
                ? IconButton(
                    icon: Icon(
                      _expanded ? Icons.expand_more : Icons.chevron_right,
                    ),
                    onPressed: () => setState(() => _expanded = !_expanded),
                  )
                : const SizedBox(width: 40),
            title: Row(
              children: [
                Text(page.icon ?? '📄', style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    page.title.isEmpty ? l10n.codexUntitled : page.title,
                    style: page.title.isEmpty
                        ? theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.outline,
                            fontStyle: FontStyle.italic,
                          )
                        : null,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            trailing: _NodeMenu(page: page),
            onTap: () => openCodexPage(context, page.id),
          ),
        ),
        if (_expanded)
          for (final c in children)
            _PageNode(page: c, all: widget.all, depth: widget.depth + 1),
      ],
    );
  }
}

class _NodeMenu extends ConsumerWidget {
  const _NodeMenu({required this.page});

  final CodexPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final repo = ref.read(codexRepositoryProvider);
    return PopupMenuButton<String>(
      itemBuilder: (context) => [
        PopupMenuItem(value: 'sub', child: Text(l10n.codexAddSubpage)),
        PopupMenuItem(value: 'rename', child: Text(l10n.codexRename)),
        PopupMenuItem(value: 'icon', child: Text(l10n.codexSetIcon)),
        PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
      ],
      onSelected: (action) async {
        switch (action) {
          case 'sub':
            await repo.createPage(parentId: page.id);
          case 'rename':
            if (!context.mounted) return;
            final name = await codexPrompt(
              context,
              l10n.codexRename,
              page.title,
            );
            if (name != null) await repo.renamePage(page.id, name);
          case 'icon':
            if (!context.mounted) return;
            final icon = await codexPrompt(
              context,
              l10n.codexSetIcon,
              page.icon ?? '',
            );
            if (icon != null) {
              await repo.setIcon(
                page.id,
                icon.trim().isEmpty ? null : icon.trim(),
              );
            }
          case 'delete':
            if (!context.mounted) return;
            final ok = await _confirmDelete(context, l10n, page.title);
            if (ok) await repo.deletePage(page.id);
        }
      },
    );
  }
}

/// Tek satirlik metin sorar (yeniden adlandirma, simge vb.).
Future<String?> codexPrompt(
  BuildContext context,
  String title,
  String initial,
) {
  final controller = TextEditingController(text: initial);
  final l10n = L10n.of(context);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(controller: controller, autofocus: true),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: Text(l10n.save),
        ),
      ],
    ),
  );
}

Future<bool> _confirmDelete(
  BuildContext context,
  L10n l10n,
  String title,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.delete),
      content: Text(
        l10n.codexDeleteConfirm(title.isEmpty ? l10n.codexUntitled : title),
      ),
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
  return ok ?? false;
}

class _Empty extends StatelessWidget {
  const _Empty({required this.l10n});

  final L10n l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(l10n.codexEmpty, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              l10n.codexEmptyHint,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
