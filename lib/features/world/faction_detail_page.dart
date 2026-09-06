import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../app/ui/ui.dart';
import '../../l10n/app_localizations.dart';
import '../../data/db/clock_tables.dart';
import '../characters/character_avatar.dart';
import '../clocks/clocks_card.dart';
import 'bond_type.dart';
import 'npc_detail_page.dart';
import 'pick_image_file.dart';
import 'world_providers.dart';

/// Bir orgutun sayfasi: arma, tur, amac, aciklama, DM notu ve BAGLARI.
///
/// Baglar bolumu bu sayfanin asil sebebi: masada "Kizil Hancerler kim?"
/// sorusunun cevabi bir paragraf degil, bir AG -- kim uye, kimle dusman,
/// nerede merkezi var. Baglarin kendisi dunya grafiginde kuruluyor; burada
/// yalnizca okunuyor ve tek dokunusla karsi uca gecililiyor.
class FactionDetailPage extends ConsumerStatefulWidget {
  const FactionDetailPage({required this.factionId, super.key});

  final String factionId;

  @override
  ConsumerState<FactionDetailPage> createState() => _FactionDetailPageState();
}

class _FactionDetailPageState extends ConsumerState<FactionDetailPage> {
  final _c = <String, TextEditingController>{};
  bool _loaded = false;

  /// Duzenleme modu KAPALI baslar: bir orgute bakmak — masada en sik yapilan
  /// sey — bos bir form duvari degil, okunur bir ozet olmali
  /// (bkz. `app/ui/edit_mode.dart`).
  bool _editing = false;

  static const _fields = ['name', 'kind', 'goal', 'description', 'secretNotes'];

  @override
  void initState() {
    super.initState();
    for (final f in _fields) {
      _c[f] = TextEditingController();
    }
    _load();
  }

  /// Kaydi diskten (yeniden) okur. "Vazgec" de bunu cagirir: yapilan
  /// duzenlemeler diske hic gitmeden atilir.
  Future<void> _load() async {
    final f = await ref
        .read(worldRepositoryProvider)
        .findFaction(widget.factionId);
    if (f == null || !mounted) return;
    _c['name']!.text = f.name;
    _c['kind']!.text = f.kind;
    _c['goal']!.text = f.goal;
    _c['description']!.text = f.description;
    _c['secretNotes']!.text = f.secretNotes;
    setState(() => _loaded = true);
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _t(String key) => _c[key]!.text.trim();

  Future<void> _save() async {
    final l10n = L10n.of(context);
    await ref
        .read(worldRepositoryProvider)
        .updateFaction(
          widget.factionId,
          name: _t('name').isEmpty ? l10n.factionAdd : _t('name'),
          kind: _t('kind'),
          goal: _t('goal'),
          description: _t('description'),
          secretNotes: _t('secretNotes'),
        );
    if (mounted) setState(() => _editing = false);
  }

  Future<void> _cancel() async {
    setState(() {
      _editing = false;
      _loaded = false;
    });
    await _load();
  }

  Future<void> _pickEmblem() async {
    final picked = await pickImageFile(
      typeLabel: L10n.of(context).fileTypeImage,
    );
    if (picked == null) return;
    await ref
        .read(worldRepositoryProvider)
        .setFactionEmblem(widget.factionId, picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final faction = ref.watch(factionProvider(widget.factionId)).value;
    final space = context.spacing;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editing || (faction?.name.isEmpty ?? true)
              ? l10n.factionTitle
              : faction!.name,
        ),
        actions: [
          if (_editing) ...[
            TextButton.icon(
              onPressed: _loaded ? _save : null,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: Text(l10n.save),
            ),
            IconButton(
              tooltip: l10n.editModeDiscard,
              icon: const Icon(Icons.close),
              onPressed: _loaded ? _cancel : null,
            ),
          ] else
            EditModeButton(
              editing: false,
              onToggle: () => setState(() => _editing = true),
            ),
        ],
      ),
      body: !_loaded || faction == null
          ? const AppLoading()
          : ListView(
              padding: EdgeInsets.all(space.md),
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: _editing ? _pickEmblem : null,
                      child: StoredAvatar(
                        store: ref.watch(worldRepositoryProvider).portraits,
                        portraitPath: faction.portraitPath,
                        name: faction.name,
                        radius: 34,
                      ),
                    ),
                    SizedBox(width: space.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(faction.name, style: theme.textTheme.titleLarge),
                          if (faction.kind.isNotEmpty)
                            Text(
                              faction.kind,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_editing && faction.portraitPath != null)
                      IconButton(
                        tooltip: l10n.factionEmblemClear,
                        icon: const Icon(Icons.hide_image_outlined),
                        onPressed: () => ref
                            .read(worldRepositoryProvider)
                            .clearFactionEmblem(widget.factionId),
                      ),
                  ],
                ),
                SizedBox(height: space.md),
                if (_editing) ...[
                  _field('name', l10n.factionName),
                  _field('kind', l10n.factionKind, hint: l10n.factionKindHint),
                  _field('goal', l10n.factionGoal, lines: 3),
                  _field('description', l10n.factionDescription, lines: 4),
                  _field(
                    'secretNotes',
                    l10n.factionSecretNotes,
                    lines: 4,
                    secret: true,
                  ),
                ] else ...[
                  if (faction.goal.isNotEmpty)
                    _readField(theme, l10n.factionGoal, faction.goal),
                  if (faction.description.isNotEmpty)
                    _readField(
                      theme,
                      l10n.factionDescription,
                      faction.description,
                    ),
                  if (faction.secretNotes.isNotEmpty)
                    _readField(
                      theme,
                      l10n.factionSecretNotes,
                      faction.secretNotes,
                      color: theme.colorScheme.tertiary,
                    ),
                ],
                SizedBox(height: space.md),
                FactionBondsCard(nodeId: widget.factionId),
                SizedBox(height: space.md),
                // Orgutun plani bir saat olarak: "ayin tamamlaniyor".
                ClocksCard(
                  link: (kind: ClockLinkKind.faction, id: widget.factionId),
                ),
              ],
            ),
    );
  }

  Widget _field(
    String key,
    String label, {
    String? hint,
    int lines = 1,
    bool secret = false,
  }) => Padding(
    padding: EdgeInsets.only(bottom: context.spacing.sm),
    child: TextField(
      controller: _c[key],
      minLines: lines,
      maxLines: lines == 1 ? 1 : lines + 4,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: secret ? L10n.of(context).factionSecretHint : null,
        helperStyle: secret
            ? TextStyle(color: Theme.of(context).colorScheme.tertiary)
            : null,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  Widget _readField(
    ThemeData theme,
    String label,
    String value, {
    Color? color,
  }) => Padding(
    padding: EdgeInsets.only(bottom: context.spacing.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: color ?? theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(value, style: theme.textTheme.bodyMedium),
      ],
    ),
  );
}

/// Bir dugumun baglari: karsi ucun adi, bagin turu ve rengi.
///
/// Hem fraksiyon hem NPC sayfasinda kullaniliyor -- "kim kiminle ne" sorusu
/// ikisinde de ayni soru. Baglar burada KURULMAZ; kurmak grafigin isi
/// (`WorldGraph`), burasi okuma ve gezinme yuzeyi.
class FactionBondsCard extends ConsumerWidget {
  const FactionBondsCard({required this.nodeId, super.key});

  final String nodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final bonds = ref.watch(nodeBondsProvider(nodeId)).value ?? const [];
    final types = {
      for (final t in ref.watch(bondTypesProvider).value ?? const []) t.code: t,
    };

    return Card(
      child: Padding(
        padding: EdgeInsets.all(context.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.factionBonds, style: theme.textTheme.titleMedium),
            SizedBox(height: context.spacing.xs),
            if (bonds.isEmpty)
              Text(
                l10n.factionBondsEmpty,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              )
            else
              for (final bond in bonds)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    switch (bond.otherKind) {
                      'npc' => Icons.face,
                      'faction' => Icons.groups_2_outlined,
                      _ => Icons.place_outlined,
                    },
                    size: 18,
                    color: Color(types[bond.type]?.color ?? kBondFallbackColor),
                  ),
                  title: Text(bond.otherName ?? l10n.factionBondBroken),
                  subtitle: Text(types[bond.type]?.name ?? bond.type),
                  // Ucu silinmis bir bag tiklanamaz: gidilecek kayit yok.
                  onTap: bond.otherName == null
                      ? null
                      : () => _openOther(context, bond),
                ),
          ],
        ),
      ),
    );
  }

  void _openOther(BuildContext context, ResolvedBond bond) {
    // Yer ucu KENDI dalinda yasiyor: ustune bir sayfa itmek yerine dunya
    // sekmesindeki kayit rotasina gidiyoruz (bkz. `app/router.dart`).
    if (bond.otherKind == 'location') {
      context.go('/world/${bond.otherId}');
      return;
    }
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => bond.otherKind == 'npc'
            ? NpcDetailPage(npcId: bond.otherId)
            : FactionDetailPage(factionId: bond.otherId),
      ),
    );
  }
}
