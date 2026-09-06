/// MEDYA ve BAGLANTI bloklarinin editorleri: gorsel, video, harici
/// baglanti, sayfa baglantisi, entity baglantisi, karakter gomme.
///
/// `codex_block_editors.dart`in bir parcasi; bkz. `codex_editors_data`.
part of 'codex_block_editors.dart';

// --- Görsel --------------------------------------------------------------

Future<Map<String, dynamic>?> _editImage(
  BuildContext context,
  Map<String, dynamic> data,
  L10n l10n,
) async {
  final captionController = TextEditingController(
    text: '${data['caption'] ?? ''}',
  );
  var path = data['path'] as String?;
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => _EditorFrame(
        title: l10n.codexBlockImage,
        data: data,
        heightAdjustable: true,
        onSave: () => {'path': path, 'caption': captionController.text},
        appearance: (context, style, update) => [
          _EnumChips<CodexMediaFit>(
            label: l10n.codexMediaFit,
            values: CodexMediaFit.values,
            selected: CodexMediaFit.fromName(style['fit']),
            labelFor: (f) => switch (f) {
              CodexMediaFit.contain => l10n.codexFitContain,
              CodexMediaFit.cover => l10n.codexFitCover,
              CodexMediaFit.fill => l10n.codexFitFill,
            },
            onSelected: (f) => update(() => style['fit'] = f.name),
          ),
          _StyleSlider(
            label: l10n.codexCornerRadius,
            keyName: 'radius',
            fallback: 12,
            min: 0,
            max: 40,
            style: style,
            update: update,
          ),
          _StyleSwitch(
            label: l10n.codexMediaFrame,
            keyName: 'frame',
            fallback: false,
            style: style,
            update: update,
          ),
        ],
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.upload),
            label: Text(
              path == null ? l10n.sheetUploadPhoto : l10n.sheetChange,
            ),
            onPressed: () async {
              final file = await pickImageFile(typeLabel: l10n.fileTypeImage);
              if (file == null) return;
              try {
                final stored = await _codexImages.store(file);
                setState(() => path = stored);
              } on FormatException catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(e.message)));
                }
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: captionController,
            decoration: InputDecoration(
              labelText: l10n.codexImageCaption,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
    ),
  );
}

// --- Video ---------------------------------------------------------------

Future<Map<String, dynamic>?> _editVideo(
  BuildContext context,
  Map<String, dynamic> data,
  L10n l10n,
) async {
  final captionController = TextEditingController(
    text: '${data['caption'] ?? ''}',
  );
  var path = data['path'] as String?;
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => _EditorFrame(
        title: l10n.codexBlockVideo,
        data: data,
        heightAdjustable: true,
        onSave: () => {'path': path, 'caption': captionController.text},
        appearance: (context, style, update) => [
          _StyleSlider(
            label: l10n.codexCornerRadius,
            keyName: 'radius',
            fallback: 12,
            min: 0,
            max: 40,
            style: style,
            update: update,
          ),
          _StyleSwitch(
            label: l10n.codexVideoLoop,
            keyName: 'loop',
            fallback: false,
            style: style,
            update: update,
          ),
          _StyleSwitch(
            label: l10n.codexVideoMuted,
            keyName: 'muted',
            fallback: false,
            style: style,
            update: update,
          ),
        ],
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.upload),
            label: Text(
              path == null ? l10n.codexVideoUpload : l10n.sheetChange,
            ),
            onPressed: () async {
              final file = await pickVideoFile(typeLabel: l10n.fileTypeVideo);
              if (file == null) return;
              final stored = await _codexMedia.store(file);
              setState(() => path = stored);
            },
          ),
          if (path != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(Icons.movie_outlined, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.codexVideoSelected,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: captionController,
            decoration: InputDecoration(
              labelText: l10n.codexImageCaption,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
    ),
  );
}

// --- Harici bağlantı -----------------------------------------------------

class _LinkEditor extends StatefulWidget {
  const _LinkEditor({required this.data});
  final Map<String, dynamic> data;
  @override
  State<_LinkEditor> createState() => _LinkEditorState();
}

class _LinkEditorState extends State<_LinkEditor> {
  late final _url = TextEditingController(text: '${widget.data['url'] ?? ''}');
  late final _label = TextEditingController(
    text: '${widget.data['label'] ?? ''}',
  );
  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return _EditorFrame(
      title: l10n.codexBlockLink,
      data: widget.data,
      onSave: () => {'url': _url.text.trim(), 'label': _label.text.trim()},
      appearance: (context, style, update) => [
        _ChipStyleSelector(style: style, update: update),
        _ToneSelector(style: style, update: update),
      ],
      children: [
        TextField(
          controller: _url,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: l10n.codexLinkUrl,
            hintText: 'https://…',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _label,
          decoration: InputDecoration(
            labelText: l10n.codexLinkLabel,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}

// --- Sayfa bağlantısı ----------------------------------------------------

Future<Map<String, dynamic>?> _editPageLink(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> data,
) async {
  final l10n = L10n.of(context);
  final pages = ref.read(codexPagesProvider).value ?? const [];
  var targetId = data['pageId'] as String?;
  final labelController = TextEditingController(text: '${data['label'] ?? ''}');
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => _EditorFrame(
        title: l10n.codexBlockPageLink,
        data: data,
        onSave: () => {
          'pageId': targetId,
          'label': labelController.text.trim().isEmpty
              ? (pages.where((p) => p.id == targetId).firstOrNull?.title ?? '')
              : labelController.text.trim(),
        },
        appearance: (context, style, update) => [
          _ChipStyleSelector(style: style, update: update),
          _ToneSelector(style: style, update: update),
        ],
        children: [
          DropdownButtonFormField<String>(
            initialValue: targetId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.codexLinkTargetPage,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final p in pages)
                DropdownMenuItem(
                  value: p.id,
                  child: Text(
                    p.title.isEmpty ? l10n.codexUntitled : p.title,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (v) => setState(() => targetId = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: labelController,
            decoration: InputDecoration(
              labelText: l10n.codexLinkLabel,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
    ),
  );
}

// --- Entity bağlantısı (canavar/büyü/eşya/karakter) ----------------------

Future<Map<String, dynamic>?> _editEntityLink(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> data,
) async {
  final l10n = L10n.of(context);
  var kind = CodexEntityKind.fromName('${data['kind'] ?? 'monster'}');
  var key = data['key'] as String?;
  var label = '${data['label'] ?? ''}';

  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => _EditorFrame(
        title: l10n.codexBlockEntityLink,
        data: data,
        canSave: key != null,
        onSave: () => {'kind': kind.name, 'key': key, 'label': label},
        appearance: (context, style, update) => [
          _ChipStyleSelector(style: style, update: update),
          _ToneSelector(style: style, update: update),
        ],
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.auto_awesome_motion),
            title: Text(label.isEmpty ? l10n.searchHint : label),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final picked =
                  await showDialog<
                    ({CodexEntityKind kind, String key, String label})
                  >(
                    context: context,
                    builder: (context) =>
                        _EntityPickerDialog(initialKind: kind),
                  );
              if (picked != null) {
                setState(() {
                  kind = picked.kind;
                  key = picked.key;
                  label = picked.label;
                });
              }
            },
          ),
        ],
      ),
    ),
  );
}

// --- Karakter gömme ------------------------------------------------------

Future<Map<String, dynamic>?> _editCharacterEmbed(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> data,
) async {
  final l10n = L10n.of(context);
  // future'i bekle: Kayitlar sekmesine dogrudan gelindiginde charactersProvider
  // henuz abone olunmamis olabilir; .value o an null doner (liste bos gorunur).
  final all = await ref.read(charactersProvider.future);
  if (!context.mounted) return null;
  var characterId = data['characterId'] as String?;
  var name = '${data['name'] ?? ''}';

  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => _EditorFrame(
        title: l10n.codexBlockCharacter,
        data: data,
        canSave: characterId != null,
        onSave: () => {'characterId': characterId, 'name': name},
        appearance: (context, style, update) => [
          _StyleSwitch(
            label: l10n.codexEmbedCompact,
            keyName: 'compact',
            fallback: false,
            style: style,
            update: update,
          ),
        ],
        children: [
          if (all.isEmpty)
            Text(l10n.combatNeedCharacter)
          else
            DropdownButtonFormField<String>(
              initialValue: characterId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.codexBlockCharacter,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final c in all)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() {
                characterId = v;
                name = all.where((c) => c.id == v).firstOrNull?.name ?? '';
              }),
            ),
        ],
      ),
    ),
  );
}

class _EntityPickerDialog extends ConsumerStatefulWidget {
  const _EntityPickerDialog({required this.initialKind});
  final CodexEntityKind initialKind;
  @override
  ConsumerState<_EntityPickerDialog> createState() =>
      _EntityPickerDialogState();
}

class _EntityPickerDialogState extends ConsumerState<_EntityPickerDialog> {
  late CodexEntityKind _kind = widget.initialKind;
  String _query = '';

  Future<List<({String key, String name})>> _search() async {
    final repo = ref.read(compendiumRepositoryProvider);
    switch (_kind) {
      case CodexEntityKind.monster:
        return [
          for (final m in await repo.searchMonsters(query: _query, limit: 40))
            (key: m.key, name: m.name),
        ];
      case CodexEntityKind.spell:
        return [
          for (final s in await repo.searchSpells(query: _query, limit: 40))
            (key: s.key, name: s.name),
        ];
      case CodexEntityKind.item:
        return [
          for (final i in await repo.searchItems(query: _query, limit: 40))
            (key: i.key, name: i.name),
        ];
      case CodexEntityKind.magicItem:
        return [
          for (final mi in await repo.searchMagicItems(
            query: _query,
            limit: 40,
          ))
            (key: mi.key, name: mi.name),
        ];
      case CodexEntityKind.character:
        final all = await ref.read(charactersProvider.future);
        final q = _query.toLowerCase();
        return [
          for (final c in all)
            if (q.isEmpty || c.name.toLowerCase().contains(q))
              (key: c.id, name: c.name),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return AlertDialog(
      title: Text(l10n.codexBlockEntityLink),
      content: SizedBox(
        width: 420,
        height: 460,
        child: Column(
          children: [
            SegmentedButton<CodexEntityKind>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: CodexEntityKind.monster,
                  label: Text(l10n.compendiumMonsters),
                ),
                ButtonSegment(
                  value: CodexEntityKind.spell,
                  label: Text(l10n.compendiumSpells),
                ),
                ButtonSegment(
                  value: CodexEntityKind.item,
                  label: Text(l10n.compendiumItems),
                ),
                ButtonSegment(
                  value: CodexEntityKind.magicItem,
                  label: Text(l10n.compendiumMagicItems),
                ),
                ButtonSegment(
                  value: CodexEntityKind.character,
                  label: Text(l10n.navCharacters),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: InputDecoration(
                hintText: l10n.searchHint,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<({String key, String name})>>(
                future: _search(),
                builder: (context, snap) {
                  final rows = snap.data ?? const [];
                  return ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (context, i) => ListTile(
                      dense: true,
                      title: Text(rows[i].name),
                      onTap: () => Navigator.pop(context, (
                        kind: _kind,
                        key: rows[i].key,
                        label: rows[i].name,
                      )),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}
