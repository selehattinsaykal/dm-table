import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ui/ui.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import '../shops/shop_detail_page.dart';
import '../shops/shop_providers.dart';
import 'location_page.dart';
import 'pick_image_file.dart';
import 'world_providers.dart';

/// Zengin NPC detay/duzenleme ekrani: portre + tum karakter alanlari.
///
/// Grafikte bir NPC dugumune sag tik / uzun bas ya da NPC listesinden dokunmak
/// buraya getirir. Kayit tek [updateNpc] cagrisiyla yazilir; portre ayri
/// (aninda yuklenir).
class NpcDetailPage extends ConsumerStatefulWidget {
  const NpcDetailPage({required this.npcId, super.key});

  final String npcId;

  @override
  ConsumerState<NpcDetailPage> createState() => _NpcDetailPageState();
}

class _NpcDetailPageState extends ConsumerState<NpcDetailPage> {
  final _c = <String, TextEditingController>{};
  String? _portraitPath;
  bool _loaded = false;
  bool _busy = false;

  static const _fields = [
    'name',
    'role',
    'race',
    'gender',
    'age',
    'alignment',
    'appearance',
    'personality',
    'ideal',
    'bond',
    'flaw',
    'hook',
    'description',
    'secretNotes',
  ];

  @override
  void initState() {
    super.initState();
    for (final f in _fields) {
      _c[f] = TextEditingController();
    }
    _load();
  }

  Future<void> _load() async {
    final npc = await ref.read(worldRepositoryProvider).findNpc(widget.npcId);
    if (npc == null || !mounted) return;
    _c['name']!.text = npc.name;
    _c['role']!.text = npc.role;
    _c['race']!.text = npc.race;
    _c['gender']!.text = npc.gender;
    _c['age']!.text = npc.age;
    _c['alignment']!.text = npc.alignment;
    _c['appearance']!.text = npc.appearance;
    _c['personality']!.text = npc.personality;
    _c['ideal']!.text = npc.ideal;
    _c['bond']!.text = npc.bond;
    _c['flaw']!.text = npc.flaw;
    _c['hook']!.text = npc.hook;
    _c['description']!.text = npc.description;
    _c['secretNotes']!.text = npc.secretNotes;
    setState(() {
      _portraitPath = npc.portraitPath;
      _loaded = true;
    });
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
    await ref
        .read(worldRepositoryProvider)
        .updateNpc(
          widget.npcId,
          name: _t('name').isEmpty ? L10n.of(context).worldNpcAdd : _t('name'),
          role: _t('role'),
          race: _t('race'),
          gender: _t('gender'),
          age: _t('age'),
          alignment: _t('alignment'),
          appearance: _t('appearance'),
          personality: _t('personality'),
          ideal: _t('ideal'),
          bond: _t('bond'),
          flaw: _t('flaw'),
          hook: _t('hook'),
          description: _t('description'),
          secretNotes: _t('secretNotes'),
        );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _uploadPortrait() async {
    final picked = await pickImageFile();
    if (picked == null) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(worldRepositoryProvider)
          .setNpcPortrait(widget.npcId, picked);
      final npc = await ref.read(worldRepositoryProvider).findNpc(widget.npcId);
      if (mounted) setState(() => _portraitPath = npc?.portraitPath);
    } on FormatException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removePortrait() async {
    await ref.read(worldRepositoryProvider).removeNpcPortrait(widget.npcId);
    if (mounted) setState(() => _portraitPath = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    if (!_loaded) {
      return const Scaffold(body: AppLoading());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.npcHeading),
        actions: [
          TextButton.icon(
            onPressed: _busy ? null : _save,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: Text(l10n.save),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _portrait(l10n, theme),
          const SizedBox(height: 16),
          _field(l10n.worldNpcNameLabel, 'name'),
          _field(l10n.worldNpcRoleLabel, 'role'),
          Row(
            children: [
              Expanded(child: _field(l10n.npcRace, 'race')),
              const SizedBox(width: 8),
              Expanded(child: _field(l10n.npcGender, 'gender')),
            ],
          ),
          Row(
            children: [
              Expanded(child: _field(l10n.npcAge, 'age')),
              const SizedBox(width: 8),
              Expanded(child: _field(l10n.npcAlignment, 'alignment')),
            ],
          ),
          _field(l10n.npcSectionAppearance, 'appearance', lines: 2),
          _field(l10n.npcSectionPersonality, 'personality', lines: 2),
          Row(
            children: [
              Expanded(child: _field(l10n.npcTraitIdeal, 'ideal')),
              const SizedBox(width: 8),
              Expanded(child: _field(l10n.npcTraitBond, 'bond')),
            ],
          ),
          _field(l10n.npcTraitFlaw, 'flaw'),
          _field(l10n.npcSectionHook, 'hook', lines: 2),
          _field(l10n.npcNotes, 'description', lines: 3),
          _field(l10n.npcSecretLabel, 'secretNotes', lines: 2),
          const SizedBox(height: 8),
          _LinksCard(npcId: widget.npcId),
        ],
      ),
    );
  }

  Widget _portrait(L10n l10n, ThemeData theme) {
    final path = _portraitPath;
    return Row(
      children: [
        if (path == null)
          const CircleAvatar(radius: 44, child: Icon(Icons.person, size: 44))
        else
          FutureBuilder<File>(
            future: ref.read(worldRepositoryProvider).portraits.resolve(path),
            builder: (context, snap) {
              final f = snap.data;
              if (f == null || !f.existsSync()) {
                return const CircleAvatar(
                  radius: 44,
                  child: Icon(Icons.person, size: 44),
                );
              }
              return CircleAvatar(radius: 44, backgroundImage: FileImage(f));
            },
          ),
        const SizedBox(width: 16),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _uploadPortrait,
                icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                label: Text(
                  path == null ? l10n.npcAddPortrait : l10n.npcChangePortrait,
                ),
              ),
              if (path != null)
                TextButton(
                  onPressed: _busy ? null : _removePortrait,
                  child: Text(l10n.delete),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _field(String label, String key, {int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _c[key],
        maxLines: lines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}

/// NPC'nin dunyaya baglandigi yerler: harita pinleri + islettigi magazalar.
///
/// `backlinksProvider` bu sayfa yazilana kadar HIC KULLANILMIYORDU (veri
/// vardi, yuzeyi yoktu); magaza bagi da yeni eklenen `Shops.ownerNpcId`
/// uzerinden ilk kez burada gorunuyor. Iki yon de tiklanabilir, boylece
/// "bu tuccar nerede oturuyordu" sorusu tek dokunusla cevaplanir.
class _LinksCard extends ConsumerWidget {
  const _LinksCard({required this.npcId});

  final String npcId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final places = ref.watch(backlinksProvider(npcId)).value ?? const [];
    final shops = (ref.watch(shopsProvider).value ?? const <Shop>[])
        .where((s) => s.ownerNpcId == npcId)
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              label: l10n.worldNpcAppearsIn,
              padding: const EdgeInsets.only(bottom: 8),
            ),
            if (places.isEmpty && shops.isEmpty)
              Text(l10n.worldNpcNoLinks, style: theme.textTheme.bodySmall)
            else ...[
              for (final b in places)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.place_outlined, size: 20),
                  title: Text(b.locationName),
                  subtitle: b.pinLabel.isEmpty ? null : Text(b.pinLabel),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (_) => LocationPage(locationId: b.locationId),
                    ),
                  ),
                ),
              for (final s in shops)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.storefront_outlined, size: 20),
                  title: Text(s.name),
                  subtitle: Text(l10n.sdOperator(s.ownerName ?? '')),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (_) => ShopDetailPage(shopId: s.id),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
