/// Kayitlar belgesinin ZENGIN MEDYA bloklari: gorsel, yakinlastirilabilir
/// gorsel, video oynatici, tablo ve karakter gomme.
///
/// `codex_document_page.dart`in bir parcasi; bkz. `codex_document_blocks`.
part of 'codex_document_page.dart';

class _CodexImage extends StatelessWidget {
  const _CodexImage({
    required this.path,
    required this.caption,
    required this.fit,
    required this.radius,
    required this.framed,
    required this.height,
    required this.captionAlign,
    required this.interactive,
  });

  final String? path;
  final String caption;
  final CodexMediaFit fit;
  final double radius;
  final bool framed;
  final double? height;
  final CodexAlign captionAlign;

  /// Goruntule modunda dokununca tam ekran acilir.
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (path == null) {
      return const SizedBox(
        height: 80,
        child: Center(child: Icon(Icons.image_outlined)),
      );
    }

    final image = FutureBuilder<File>(
      future: _codexImages.resolve(path!),
      builder: (context, snap) {
        final f = snap.data;
        if (f == null || !f.existsSync()) {
          return SizedBox(
            height: height ?? 120,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.broken_image_outlined),
                  if (f != null)
                    Text(
                      L10n.of(context).codexImageMissing,
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          );
        }
        final child = ConstrainedBox(
          // Yukseklik verilmediyse eski davranis: en fazla 320 px.
          constraints: BoxConstraints(maxHeight: height ?? 320),
          child: SizedBox(
            width: double.infinity,
            height: height,
            child: Image.file(f, fit: fit.boxFit),
          ),
        );
        return interactive
            ? _ZoomableImage(file: f, fit: fit, child: child)
            : child;
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: framed
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: context.fantasyColors.brass.withValues(alpha: 0.7),
                    width: 2,
                  ),
                )
              : null,
          padding: framed ? const EdgeInsets.all(4) : EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: image,
          ),
        ),
        if (caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              caption,
              style: theme.textTheme.bodySmall,
              textAlign: captionAlign.textAlign,
            ),
          ),
      ],
    );
  }
}

/// Gorsele dokununca acilan tam ekran goruntuleyici (yakinlastirilabilir).
class _ZoomableImage extends StatelessWidget {
  const _ZoomableImage({
    required this.file,
    required this.fit,
    required this.child,
  });

  final File file;
  final CodexMediaFit fit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Tooltip(
      message: l10n.codexImageFullscreen,
      child: InkWell(
        onTap: () => showDialog<void>(
          context: context,
          barrierColor: Colors.black87,
          builder: (context) => Dialog.fullscreen(
            backgroundColor: Colors.transparent,
            child: Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 6,
                    child: Center(child: Image.file(file)),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton.filledTonal(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Uygulama ici video oynatici (media_kit). Otomatik oynatmaz; kullanici
/// baslatir. Dosya yoksa "bulunamadi" gosterir.
class _CodexVideo extends StatefulWidget {
  const _CodexVideo({
    required this.path,
    required this.caption,
    required this.height,
    required this.radius,
    required this.loop,
    required this.muted,
    required this.captionAlign,
  });

  final String? path;
  final String caption;
  final double height;
  final double radius;
  final bool loop;
  final bool muted;
  final CodexAlign captionAlign;

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
    } else if (old.loop != widget.loop || old.muted != widget.muted) {
      _applyOptions();
    }
  }

  Future<void> _applyOptions() async {
    final player = _player;
    if (player == null) return;
    await player.setPlaylistMode(
      widget.loop ? PlaylistMode.loop : PlaylistMode.none,
    );
    await player.setVolume(widget.muted ? 0 : 100);
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
    await _applyOptions();
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
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(widget.radius),
          child: SizedBox(
            height: widget.height,
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
              textAlign: widget.captionAlign.textAlign,
            ),
          ),
      ],
    );
  }
}

class _CodexTable extends StatelessWidget {
  const _CodexTable({
    required this.rows,
    required this.header,
    required this.zebra,
    required this.dense,
    required this.bordered,
    this.onTap,
  });

  final List<List<String>> rows;
  final bool header;

  /// Bir satir bir, bir satir sifir tonlanir (uzun tablolarda goz kaymasin).
  final bool zebra;
  final bool dense;
  final bool bordered;

  /// Hucre satir-ici parcalarina (wiki/zar/ref) dokununca calisir; null ise
  /// (duzenleme modu) tiklanamaz.
  final void Function(CodexInlineToken token)? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (rows.isEmpty) return const SizedBox.shrink();
    final body = header ? rows.skip(1).toList() : rows;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: header ? (dense ? 36 : 44) : 0,
        dataRowMinHeight: dense ? 30 : 40,
        dataRowMaxHeight: dense ? 40 : 56,
        horizontalMargin: dense ? 10 : 24,
        columnSpacing: dense ? 18 : 32,
        columns: header
            ? [
                for (final c in rows.first)
                  DataColumn(
                    label: DefaultTextStyle.merge(
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      child: _cell(context, c),
                    ),
                  ),
              ]
            : [
                for (final _ in rows.first)
                  const DataColumn(label: SizedBox.shrink()),
              ],
        rows: [
          for (final (i, row) in body.indexed)
            DataRow(
              color: zebra && i.isOdd
                  ? WidgetStatePropertyAll(
                      theme.colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      ),
                    )
                  : null,
              cells: [
                for (var c = 0; c < rows.first.length; c++)
                  DataCell(_cell(context, c < row.length ? row[c] : '')),
              ],
            ),
        ],
        border: bordered
            ? TableBorder.all(color: theme.dividerColor, width: 0.5)
            : null,
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
    required this.compact,
  });

  final String? characterId;
  final String fallbackName;
  final bool editing;

  /// Kompakt: tek satir (ad + HP), ilerleme cubugu yok.
  final bool compact;

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
    final open = editing
        ? null
        : () => Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (_) => CharacterSheetPage(characterId: c.id),
            ),
          );

    if (compact) {
      return Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: open,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.person, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(c.name, style: theme.textTheme.bodyMedium),
                ),
                Text(
                  '${c.hitPointsCurrent}/${c.hitPointsMax}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: ratio <= 0.25 ? theme.colorScheme.error : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: InkWell(
        onTap: open,
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

/// Blok turu secici: aranabilir ve gruplanmis.
