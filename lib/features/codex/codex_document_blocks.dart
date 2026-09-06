/// Kayitlar belgesinin BLOK GORUNUMU: her blok tipinin salt-okunur cizimi
/// (baslik, metin, uyari kutusu, ayrac, liste, zar, tablo, grafik, sayac,
/// gorsel, video, baglanti, karakter gomme).
///
/// `codex_document_page.dart`in bir parcasi (`part`), ayri kutuphane DEGIL:
/// blok widget'larinin tamami ozel ve sayfanin durumuyla ic ice. Dosya 2000
/// satiri gecince yalnizca FIZIKSEL olarak bolundu.
part of 'codex_document_page.dart';

// --- Blok görünümü -------------------------------------------------------

class _BlockContent extends ConsumerWidget {
  const _BlockContent({
    required this.block,
    required this.type,
    required this.data,
    required this.layout,
    required this.editing,
  });

  final CodexBlock block;
  final CodexBlockType type;
  final Map<String, dynamic> data;
  final CodexLayout layout;
  final bool editing;

  /// Metin olcegi (0.7–2.2). Blok bazinda buyutulup kucultulebilir.
  double get _scale =>
      ((data['size'] as num?)?.toDouble() ?? 1.0).clamp(0.7, 2.2);

  CodexTone get _tone => CodexTone.fromName(data['tone']);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final tone = codexToneColors(context, _tone);
    final onTapInline = editing
        ? null
        : (CodexInlineToken token) => _handleInline(context, ref, token);

    switch (type) {
      case CodexBlockType.heading:
        final level = (data['level'] as int? ?? 2).clamp(1, 3);
        final base = switch (level) {
          1 => theme.textTheme.headlineSmall,
          2 => theme.textTheme.titleLarge,
          _ => theme.textTheme.titleMedium,
        };
        final style = base?.copyWith(
          fontSize: (base.fontSize ?? 20) * _scale,
          color: _tone == CodexTone.neutral ? null : tone.accent,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildCodexInline(
              context,
              '${data['text'] ?? ''}',
              onTap: onTapInline,
              style: style,
              textAlign: layout.align.textAlign,
            ),
            if (data['rule'] == true)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Container(
                  height: 1.5,
                  color: context.fantasyColors.brass.withValues(alpha: 0.55),
                ),
              ),
          ],
        );

      case CodexBlockType.text:
        final base = readingStyle(context);
        final style = base.copyWith(
          fontSize: (base.fontSize ?? 16) * _scale,
          color: _tone == CodexTone.neutral ? null : tone.accent,
        );
        final text = '${data['text'] ?? ''}';
        if (data['dropCap'] == true && text.trim().isNotEmpty) {
          return _DropCapText(
            text: text,
            style: style,
            align: layout.align,
            onTap: onTapInline,
          );
        }
        return buildCodexInline(
          context,
          text,
          onTap: onTapInline,
          style: style,
          textAlign: layout.align.textAlign,
        );

      case CodexBlockType.bulleted:
        final items = (data['items'] as List? ?? const [])
            .map((e) => '$e')
            .toList();
        final ordered = data['ordered'] == true;
        final marker = '${data['marker'] ?? '•'}';
        final dense = data['dense'] == true;
        final base = readingStyle(context);
        final style = base.copyWith(fontSize: (base.fontSize ?? 16) * _scale);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, item) in items.indexed)
              Padding(
                padding: EdgeInsets.symmetric(vertical: dense ? 0 : 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: ordered ? 28 : 20,
                      child: Text(
                        ordered ? '${i + 1}.' : marker,
                        style: style.copyWith(
                          color: _tone == CodexTone.neutral
                              ? theme.colorScheme.onSurfaceVariant
                              : tone.accent,
                        ),
                        textAlign: ordered ? TextAlign.end : TextAlign.start,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: buildCodexInline(
                        context,
                        item,
                        onTap: onTapInline,
                        style: style,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );

      case CodexBlockType.checklist:
        final items = (data['items'] as List? ?? const []);
        final strike = data['strike'] != false;
        final showProgress = data['progress'] == true;
        final doneCount = items.where((e) => (e as Map)['done'] == true).length;
        final base = readingStyle(context);
        final style = base.copyWith(fontSize: (base.fontSize ?? 16) * _scale);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showProgress && items.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: doneCount / items.length,
                        minHeight: 5,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.codexChecklistDone(doneCount, items.length),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            for (final (i, raw) in items.indexed)
              _ChecklistRow(
                label: buildCodexInline(
                  context,
                  '${(raw as Map)['text'] ?? ''}',
                  onTap: onTapInline,
                  style: (raw['done'] as bool? ?? false) && strike
                      ? style.copyWith(decoration: TextDecoration.lineThrough)
                      : style,
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
        final bordered = data['border'] != false;
        final base = readingStyle(context);
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: tone.background,
            borderRadius: BorderRadius.circular(8),
            border: bordered
                ? Border(left: BorderSide(color: tone.accent, width: 3))
                : null,
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
                  onTap: onTapInline,
                  style: base.copyWith(
                    fontSize: (base.fontSize ?? 16) * _scale,
                    color: tone.foreground,
                  ),
                  textAlign: layout.align.textAlign,
                ),
              ),
            ],
          ),
        );

      case CodexBlockType.divider:
        return _CodexDivider(
          style: CodexDividerStyle.fromName(data['style']),
          thickness: (data['thickness'] as num?)?.toDouble() ?? 1,
          tone: _tone,
        );

      case CodexBlockType.image:
        return _CodexImage(
          path: data['path'] as String?,
          caption: '${data['caption'] ?? ''}',
          fit: CodexMediaFit.fromName(data['fit']),
          radius: (data['radius'] as num?)?.toDouble() ?? 12,
          framed: data['frame'] == true,
          height: layout.height,
          captionAlign: layout.align,
          interactive: !editing,
        );

      case CodexBlockType.video:
        return _CodexVideo(
          path: data['path'] as String?,
          caption: '${data['caption'] ?? ''}',
          height: layout.height ?? 240,
          radius: (data['radius'] as num?)?.toDouble() ?? 12,
          loop: data['loop'] == true,
          muted: data['muted'] == true,
          captionAlign: layout.align,
        );

      case CodexBlockType.link:
        final url = '${data['url'] ?? ''}';
        final label = '${data['label'] ?? ''}';
        return _ActionBlock(
          style: CodexChipStyle.fromName(data['chipStyle']),
          align: layout.align,
          tone: _tone,
          icon: Icons.open_in_new,
          label: label.isNotEmpty
              ? label
              : (url.isEmpty ? l10n.codexBlockLink : url),
          subtitle: label.isNotEmpty && url.isNotEmpty ? url : null,
          onTap: (editing || url.isEmpty)
              ? null
              : () => _openLink(context, url),
        );

      case CodexBlockType.table:
        final rows = (data['rows'] as List? ?? const [])
            .map((r) => (r as List).map((c) => '$c').toList())
            .toList();
        return _CodexTable(
          rows: rows,
          header: data['header'] as bool? ?? false,
          zebra: data['zebra'] == true,
          dense: data['dense'] == true,
          bordered: data['borders'] != false,
          onTap: onTapInline,
        );

      case CodexBlockType.chart:
        var items = [
          for (final e in (data['items'] as List? ?? const []))
            CodexChartItem(
              label: '${(e as Map)['label'] ?? ''}',
              value: (e['value'] as num?)?.toDouble() ?? 0,
              color: (e['color'] as num?) == null
                  ? null
                  : Color((e['color'] as num).toInt()),
            ),
        ];
        if (data['sort'] == true) {
          items = [...items]..sort((a, b) => b.value.compareTo(a.value));
        }
        return CodexChartView(
          title: '${data['title'] ?? ''}',
          type: CodexChartType.fromName(data['type']),
          items: items,
          palette: CodexPalette.fromName(data['palette']),
          height: layout.height,
          showValues: data['showValues'] != false,
          showGrid: data['showGrid'] != false,
          showLegend: data['showLegend'] != false,
          emptyHint: l10n.codexChartEmpty,
          surfaceColor: editing
              ? theme.colorScheme.surfaceContainerLow
              : theme.colorScheme.surface,
        );

      case CodexBlockType.counter:
        final counters = [
          for (final e in (data['items'] as List? ?? const []))
            CodexCounter.fromJson((e as Map).cast<Object?, Object?>()),
        ];
        return CodexCounterView(
          title: '${data['title'] ?? ''}',
          style: CodexCounterStyle.fromName(data['style']),
          counters: counters,
          palette: CodexPalette.fromName(data['palette']),
          // Duzenleme modunda sayilar kilitli: yerlesim ayarlarken
          // yanlislikla degeri degistirmek can sikici olurdu.
          interactive: !editing,
          onChanged: (i, next) {
            final updated = [
              for (final (j, c) in counters.indexed)
                (j == i ? next : c).toJson(),
            ];
            ref.read(codexRepositoryProvider).updateBlock(block.id, {
              ...data,
              'items': updated,
            });
          },
        );

      case CodexBlockType.timer:
        return CodexTimerView(
          title: '${data['title'] ?? ''}',
          timer: CodexTimer.fromJson(data),
          tone: _tone,
          // Sayac yalnizca goruntule modunda calistirilir; duzenlerken
          // dugmeler kilitli (yerlesim ayarlarken kazara baslamasin).
          interactive: !editing,
          onChanged: (next) => ref.read(codexRepositoryProvider).updateBlock(
            block.id,
            {...data, ...next.toJson()},
          ),
        );

      case CodexBlockType.dice:
        final label = '${data['label'] ?? ''}';
        final expr = '${data['expression'] ?? ''}';
        return _ActionBlock(
          style: CodexChipStyle.fromName(data['chipStyle']),
          align: layout.align,
          tone: _tone,
          icon: Icons.casino,
          label: label.isEmpty ? expr : label,
          subtitle: label.isEmpty ? null : expr,
          onTap: editing ? null : () => _rollDice(context, ref, label, expr),
        );

      case CodexBlockType.pageLink:
        final targetId = data['pageId'] as String?;
        return _ActionBlock(
          style: CodexChipStyle.fromName(data['chipStyle']),
          align: layout.align,
          tone: _tone,
          icon: Icons.description_outlined,
          label: '${data['label'] ?? ''}'.isEmpty
              ? l10n.codexBlockPageLink
              : '${data['label']}',
          onTap: (editing || targetId == null)
              ? null
              : () => openCodexPage(context, targetId),
        );

      case CodexBlockType.entityLink:
        final kind = CodexEntityKind.fromName('${data['kind'] ?? 'monster'}');
        final key = data['key'] as String?;
        return _ActionBlock(
          style: CodexChipStyle.fromName(data['chipStyle']),
          align: layout.align,
          tone: _tone,
          icon: _entityIcon(kind),
          label: '${data['label'] ?? ''}',
          onTap: (editing || key == null)
              ? null
              : () => _openEntity(context, ref, kind, key),
        );

      case CodexBlockType.characterEmbed:
        return _CharacterEmbed(
          characterId: data['characterId'] as String?,
          fallbackName: '${data['name'] ?? ''}',
          editing: editing,
          compact: data['compact'] == true,
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
        _rollDice(context, ref, token.text, token.text);
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

  void _rollDice(
    BuildContext context,
    WidgetRef ref,
    String label,
    String expr,
  ) {
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
    ref.read(rollLogProvider.notifier).add(roll);
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

/// Paragrafin ilk harfini el yazmasi kitaplarindaki gibi buyutur.
class _DropCapText extends StatelessWidget {
  const _DropCapText({
    required this.text,
    required this.style,
    required this.align,
    required this.onTap,
  });

  final String text;
  final TextStyle style;
  final CodexAlign align;
  final void Function(CodexInlineToken token)? onTap;

  @override
  Widget build(BuildContext context) {
    final first = text.characters.first;
    final rest = text.characters.skip(1).toString();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 6, top: 2),
          child: Text(
            first,
            style: style.copyWith(
              fontSize: (style.fontSize ?? 16) * 2.6,
              height: 0.92,
              fontWeight: FontWeight.w600,
              color: context.fantasyColors.brass,
            ),
          ),
        ),
        Expanded(
          child: buildCodexInline(
            context,
            rest,
            onTap: onTap,
            style: style,
            textAlign: align.textAlign,
          ),
        ),
      ],
    );
  }
}

/// Ayrac blogu: sus / cizgi / kesik / kalin / nokta / bosluk.
class _CodexDivider extends StatelessWidget {
  const _CodexDivider({
    required this.style,
    required this.thickness,
    required this.tone,
  });

  final CodexDividerStyle style;
  final double thickness;
  final CodexTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = codexToneColors(context, tone);
    final color = tone == CodexTone.neutral
        ? context.fantasyColors.brass.withValues(alpha: 0.55)
        : colors.accent;

    return switch (style) {
      CodexDividerStyle.ornament => const OrnamentDivider(),
      CodexDividerStyle.space => SizedBox(height: 12 + thickness * 8),
      CodexDividerStyle.dots => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Container(
                  width: 3 + thickness,
                  height: 3 + thickness,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
      CodexDividerStyle.dashed => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: CustomPaint(
          size: Size(double.infinity, thickness.clamp(1, 8)),
          painter: _DashedLinePainter(color: color, thickness: thickness),
        ),
      ),
      CodexDividerStyle.line || CodexDividerStyle.thick => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Container(
          height: style == CodexDividerStyle.thick
              ? (thickness * 3).clamp(2, 12)
              : thickness.clamp(0.5, 6),
          color: color,
        ),
      ),
    };
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color, required this.thickness});

  final Color color;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness.clamp(1, 8)
      ..strokeCap = StrokeCap.round;
    const dash = 7.0;
    const gap = 5.0;
    var x = 0.0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + dash).clamp(0, size.width), y),
        paint,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) =>
      old.color != color || old.thickness != thickness;
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

/// Cip / dugme / kart gorunumlerini paylasan tek dokunuslu blok govdesi.
class _ActionBlock extends StatelessWidget {
  const _ActionBlock({
    required this.style,
    required this.align,
    required this.tone,
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final CodexChipStyle style;
  final CodexAlign align;
  final CodexTone tone;
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = codexToneColors(context, tone);
    final theme = Theme.of(context);

    final child = switch (style) {
      CodexChipStyle.chip => ActionChip(
        avatar: Icon(icon, size: 18, color: colors.accent),
        label: Text(label),
        onPressed: onTap,
      ),
      CodexChipStyle.button => FilledButton.tonalIcon(
        icon: Icon(icon, size: 18),
        label: Text(label),
        onPressed: onTap,
      ),
      CodexChipStyle.card => Card(
        margin: EdgeInsets.zero,
        color: tone == CodexTone.neutral ? null : colors.background,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon, color: colors.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label, style: theme.textTheme.titleSmall),
                      if (subtitle != null && subtitle!.isNotEmpty)
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(Icons.chevron_right, color: theme.colorScheme.outline),
              ],
            ),
          ),
        ),
      ),
    };

    return style == CodexChipStyle.card
        ? child
        : Align(alignment: align.alignment, child: child);
  }
}
