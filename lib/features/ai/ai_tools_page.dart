import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ai_settings_provider.dart';
import '../../app/theme.dart';
import '../../app/ui/ui.dart';
import '../../data/ai/ai_service.dart';
import '../../data/db/database.dart';
import '../../domain/ai/ai_settings.dart';
import '../../domain/codex/codex_block.dart';
import '../../domain/rules/magic_item_pricing.dart';
import '../../l10n/app_localizations.dart';
import '../codex/codex_providers.dart';
import '../quests/quest_providers.dart';
import '../session/session_page.dart';
import '../world/world_providers.dart';
import 'ai_tools_shared.dart';
import 'encounter_tool.dart';
import 'npc_generator.dart';
import 'quest_generator.dart';
import 'table_tool.dart';

/// AI Araçları: opt-in, kendi anahtarınla çalışan üreteçler. Her araç bir sekme.
class AiToolsPage extends ConsumerWidget {
  const AiToolsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.navAiTools),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: l10n.aiToolNpcTab),
              Tab(text: l10n.aiToolQuest),
              Tab(text: l10n.aiToolEncounter),
              Tab(text: l10n.aiToolTable),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_NpcTool(), _QuestTool(), EncounterTool(), TableTool()],
        ),
      ),
    );
  }
}

// --- NPC üreteci ---------------------------------------------------------

class _NpcTool extends ConsumerStatefulWidget {
  const _NpcTool();
  @override
  ConsumerState<_NpcTool> createState() => _NpcToolState();
}

/// Kullanicinin kurdugu bir iliski satiri: hedef NPC + bag turu kodu.
class _RelationDraft {
  String? npcId;
  String? bondCode;

  /// Yarim kalan satirlar (NPC secilmis, tur secilmemis) kaydedilmez.
  bool get isComplete => npcId != null && bondCode != null;
}

class _NpcToolState extends ConsumerState<_NpcTool> {
  final _profession = TextEditingController();
  final _race = TextEditingController();
  final _name = TextEditingController();
  final _extra = TextEditingController();
  NpcGender _gender = NpcGender.random;
  final _run = AiRunState();

  /// NPC'nin bagli oldugu yer (opsiyonel) ve o bagin turu.
  String? _locationId;
  String? _locationBondCode;

  /// Istenildigi kadar NPC iliskisi.
  final List<_RelationDraft> _relations = [];

  /// Portre uretimi acik mi (saglayici destekliyorsa).
  bool _wantPortrait = false;

  /// Uretilen portrenin ham baytlari + durumu. NPC metninden AYRI tutulur:
  /// portre basarisiz olsa bile NPC sonucu gecerlidir.
  Uint8List? _portrait;
  bool _portraitLoading = false;
  String? _portraitError;
  String? _portraitErrorDetail;

  @override
  void dispose() {
    _profession.dispose();
    _race.dispose();
    _name.dispose();
    _extra.dispose();
    super.dispose();
  }

  String _genderLabel(L10n l10n, NpcGender g) => switch (g) {
    NpcGender.male => l10n.npcGenderMale,
    NpcGender.female => l10n.npcGenderFemale,
    NpcGender.other => l10n.npcGenderOther,
    NpcGender.random => l10n.npcGenderRandom,
  };

  /// Secili konum ve iliskileri modele verilecek ADLARA cevirir. Ad
  /// cozulemezse (kayit silinmisse) o baglam disarida birakilir.
  List<NpcRelationContext> _relationContexts(
    List<Npc> npcs,
    List<BondType> bonds,
  ) {
    String? bondName(String? code) {
      if (code == null) return null;
      for (final b in bonds) {
        if (b.code == code) return b.name;
      }
      return null;
    }

    final out = <NpcRelationContext>[];
    for (final rel in _relations) {
      if (!rel.isComplete) continue;
      final npc = npcs.where((n) => n.id == rel.npcId).firstOrNull;
      final bond = bondName(rel.bondCode);
      if (npc == null || bond == null) continue;
      out.add((targetName: npc.name, bondName: bond));
    }
    return out;
  }

  Future<void> _generate({
    required List<Location> locations,
    required List<Npc> npcs,
    required List<BondType> bonds,
  }) async {
    final l10n = L10n.of(context);
    final location = locations.where((l) => l.id == _locationId).firstOrNull;
    final built = buildNpcPrompt(
      profession: _profession.text,
      gender: _gender,
      race: _race.text,
      name: _name.text,
      extra: _extra.text,
      languageName: l10n.localeName == 'tr' ? 'Türkçe' : 'English',
      locationName: location?.name ?? '',
      relations: _relationContexts(npcs, bonds),
    );
    setState(() {
      _portrait = null;
      _portraitError = null;
      _portraitErrorDetail = null;
    });
    await _run.generate(
      context,
      ref,
      built.system,
      built.user,
      () => setState(() {}),
    );
    // Portre ancak metin uretildikten SONRA anlamli: gorunus/irk/yas/mizac
    // alanlari oradan geliyor.
    if (!mounted || _run.result == null) return;
    if (_wantPortrait) await _generatePortrait();
  }

  Future<void> _generatePortrait() async {
    final result = _run.result;
    if (result == null) return;
    final l10n = L10n.of(context);
    final ai = ref.read(aiSettingsProvider);
    setState(() {
      _portraitLoading = true;
      _portraitError = null;
      _portraitErrorDetail = null;
    });
    try {
      final bytes = await AiService(
        ai,
      ).generateImage(prompt: buildPortraitPrompt(parseNpcResult(result)));
      if (mounted) setState(() => _portrait = bytes);
    } on AiException catch (e) {
      if (mounted) {
        setState(() {
          _portraitError = aiErrorMessage(l10n, e.message);
          _portraitErrorDetail = e.detail;
        });
      }
    } finally {
      if (mounted) setState(() => _portraitLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final ai = ref.watch(aiSettingsProvider);
    if (!ai.enabled) return const AiNotConfigured();

    // Konum/NPC/bag turu listeleri dunya sekmesiyle AYNI kaynaktan gelir;
    // burada kopya bir liste tutulmaz.
    final locations =
        ref.watch(allLocationsProvider).value ?? const <Location>[];
    final npcs = ref.watch(npcsProvider).value ?? const <Npc>[];
    final bonds = ref.watch(bondTypesProvider).value ?? const <BondType>[];

    final result = _run.result == null ? null : parseNpcResult(_run.result!);
    final busy = _run.loading || _portraitLoading;

    return ListView(
      padding: EdgeInsets.all(context.spacing.md),
      children: [
        TextField(
          controller: _profession,
          decoration: InputDecoration(
            labelText: l10n.npcProfession,
            hintText: l10n.npcProfessionHint,
          ),
        ),
        SizedBox(height: context.spacing.md),
        Text(l10n.npcGender, style: theme.textTheme.labelLarge),
        SizedBox(height: context.spacing.xs + 2),
        Wrap(
          spacing: context.spacing.sm,
          children: [
            for (final g in NpcGender.values)
              ChoiceChip(
                label: Text(_genderLabel(l10n, g)),
                selected: _gender == g,
                onSelected: busy ? null : (_) => setState(() => _gender = g),
              ),
          ],
        ),
        SizedBox(height: context.spacing.md),
        TextField(
          controller: _race,
          decoration: InputDecoration(
            labelText: l10n.npcRace,
            hintText: l10n.npcRaceHint,
          ),
        ),
        SizedBox(height: context.spacing.md),
        TextField(
          controller: _name,
          decoration: InputDecoration(
            labelText: l10n.npcName,
            hintText: l10n.npcNameHint,
          ),
        ),
        SizedBox(height: context.spacing.md),
        TextField(
          controller: _extra,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: l10n.npcExtra,
            hintText: l10n.npcExtraHint,
          ),
        ),

        SectionHeader(label: l10n.npcBoundLocation, icon: Icons.place_outlined),
        _LocationPicker(
          locations: locations,
          bonds: bonds,
          selectedId: _locationId,
          selectedBond: _locationBondCode,
          enabled: !busy,
          onChanged: (id, bond) => setState(() {
            _locationId = id;
            _locationBondCode = bond;
          }),
        ),

        SectionHeader(
          label: l10n.npcRelations,
          icon: Icons.hub_outlined,
          trailing: TextButton.icon(
            onPressed: busy || npcs.isEmpty
                ? null
                : () => setState(() => _relations.add(_RelationDraft())),
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.npcAddRelation),
          ),
        ),
        _RelationsEditor(
          relations: _relations,
          npcs: npcs,
          bonds: bonds,
          enabled: !busy,
          onChanged: () => setState(() {}),
        ),

        SectionHeader(
          label: l10n.npcPortraitTitle,
          icon: Icons.face_retouching_natural_outlined,
        ),
        _PortraitToggle(
          value: _wantPortrait,
          settings: ai,
          enabled: !busy,
          onChanged: (v) => setState(() => _wantPortrait = v),
        ),

        SizedBox(height: context.spacing.md),
        if (result == null)
          FilledButton.icon(
            onPressed: busy
                ? null
                : () =>
                      _generate(locations: locations, npcs: npcs, bonds: bonds),
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: Text(l10n.codexAiGenerate),
          ),
        if (_run.error != null)
          AiErrorBox(message: _run.error!, detail: _run.errorDetail),
        if (_run.loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: AppLoading(),
          ),
        if (result != null)
          ..._resultSections(l10n, theme, result, locations, npcs, bonds),
      ],
    );
  }

  List<Widget> _resultSections(
    L10n l10n,
    ThemeData theme,
    NpcResult r,
    List<Location> locations,
    List<Npc> npcs,
    List<BondType> bonds,
  ) {
    final personality = StringBuffer(r.personality.trim());
    void trait(String label, String v) {
      if (v.trim().isEmpty) return;
      if (personality.isNotEmpty) personality.write('\n');
      personality.write('$label: ${v.trim()}');
    }

    trait(l10n.npcTraitIdeal, r.ideal);
    trait(l10n.npcTraitBond, r.bond);
    trait(l10n.npcTraitFlaw, r.flaw);

    return [
      if (_wantPortrait || _portrait != null || _portraitError != null)
        _PortraitPanel(
          bytes: _portrait,
          loading: _portraitLoading,
          error: _portraitError,
          errorDetail: _portraitErrorDetail,
          onRegenerate: _portraitLoading ? null : _generatePortrait,
        ),
      if (r.name.isNotEmpty || r.summary.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (r.name.isNotEmpty)
                Text(r.name, style: theme.textTheme.headlineSmall),
              if (r.summary.isNotEmpty)
                Text(
                  r.summary,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
            ],
          ),
        ),
      if (r.appearance.isNotEmpty)
        AiSection(title: l10n.npcSectionAppearance, body: r.appearance),
      if (personality.isNotEmpty)
        AiSection(
          title: l10n.npcSectionPersonality,
          body: personality.toString(),
        ),
      if (r.hook.isNotEmpty)
        AiSection(title: l10n.npcSectionHook, body: r.hook),
      if (r.secret.isNotEmpty)
        AiSection(
          title: l10n.npcSectionSecret,
          body: r.secret,
          dmOnly: true,
          note: l10n.questDmOnly,
        ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: () => _saveToNpcs(l10n, r),
            icon: const Icon(Icons.person_add_alt, size: 18),
            label: Text(l10n.npcSaveToNpcs),
          ),
          if (_portrait == null && !_portraitLoading && _run.result != null)
            OutlinedButton.icon(
              onPressed: ref.read(aiSettingsProvider).canGenerateImages
                  ? _generatePortrait
                  : null,
              icon: const Icon(Icons.face_retouching_natural, size: 18),
              label: Text(l10n.npcPortraitRegenerate),
            ),
          OutlinedButton.icon(
            onPressed: () => _copyAll(l10n, r),
            icon: const Icon(Icons.copy, size: 18),
            label: Text(l10n.codexAiCopy),
          ),
          OutlinedButton.icon(
            onPressed: () => _insertToCodex(
              context,
              ref,
              heading: r.name.isNotEmpty ? r.name : l10n.npcHeading,
              text: _descriptionText(l10n, r, includeSecret: false),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.codexAiInsert),
          ),
          TextButton(
            onPressed: () => setState(() {
              _run.result = null;
              _run.error = null;
            }),
            child: Text(l10n.aiRegenerate),
          ),
        ],
      ),
    ];
  }

  /// NPC alanlarini tek bir okunur metne toplar. [includeSecret] false ise
  /// DM sirri disarida birakilir (kopyalama/oyuncuya gidebilecek metinler icin).
  String _descriptionText(
    L10n l10n,
    NpcResult r, {
    required bool includeSecret,
  }) {
    final b = StringBuffer();
    void para(String label, String body) {
      if (body.trim().isEmpty) return;
      if (b.isNotEmpty) b.writeln();
      b
        ..writeln('$label:')
        ..writeln(body.trim());
    }

    if (r.summary.isNotEmpty) b.writeln(r.summary.trim());
    para(l10n.npcSectionAppearance, r.appearance);

    final pers = StringBuffer(r.personality.trim());
    void trait(String label, String v) {
      if (v.trim().isEmpty) return;
      if (pers.isNotEmpty) pers.write('\n');
      pers.write('$label: ${v.trim()}');
    }

    trait(l10n.npcTraitIdeal, r.ideal);
    trait(l10n.npcTraitBond, r.bond);
    trait(l10n.npcTraitFlaw, r.flaw);
    para(l10n.npcSectionPersonality, pers.toString());
    para(l10n.npcSectionHook, r.hook);
    if (includeSecret) para(l10n.npcSectionSecret, r.secret);
    return b.toString().trim();
  }

  /// Uretilen NPC'yi kalici NPC listesine kaydeder: isim + meslek (rol) +
  /// tum detaylar (aciklama). NPC listesi DM'e ozel oldugundan sir de dahildir.
  ///
  /// Kaydetmeyle birlikte secilen yer ve iliskiler dunya grafiginde GERCEK
  /// kenarlara donusur — ayni `WorldLinks` tablosu, ayni bag turleri, yani
  /// yeni NPC haritada aninda bagli gorunur.
  Future<void> _saveToNpcs(L10n l10n, NpcResult r) async {
    final repo = ref.read(worldRepositoryProvider);
    final name = r.name.isNotEmpty
        ? r.name
        : (_name.text.trim().isNotEmpty ? _name.text.trim() : l10n.npcHeading);
    // Uretilen NPC yapilandirilmis alanlara yazilir (aciklamaya gomulmez);
    // sonra NPC ekraninda portre/duzenleme yapilir.
    final id = await repo.createNpc(
      name: name,
      role: _profession.text.trim().isNotEmpty
          ? _profession.text.trim()
          : r.summary,
      description: r.summary,
      race: r.race.isNotEmpty ? r.race : _race.text.trim(),
      gender: r.gender,
      age: r.age,
      alignment: r.alignment,
      appearance: r.appearance,
      personality: r.personality,
      ideal: r.ideal,
      bond: r.bond,
      flaw: r.flaw,
      hook: r.hook,
      secretNotes: r.secret,
    );

    var links = 0;
    final locationId = _locationId;
    if (locationId != null) {
      await repo.createLink(
        id,
        locationId,
        xKind: 'npc',
        yKind: 'location',
        type: _locationBondCode ?? 'road',
      );
      links++;
    }
    for (final rel in _relations) {
      if (!rel.isComplete || rel.npcId == id) continue;
      await repo.createLink(
        id,
        rel.npcId!,
        xKind: 'npc',
        yKind: 'npc',
        type: rel.bondCode!,
      );
      links++;
    }

    final portrait = _portrait;
    if (portrait != null) {
      // Portre kaydi NPC'nin kendisini gecersiz kilmamali: gorsel bozuksa
      // NPC yine de kaydedilmis olur.
      try {
        await repo.setNpcPortraitFromBytes(id, portrait);
      } catch (_) {
        // yok sayilir; DM portreyi NPC ekranindan elle ekleyebilir
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            links == 0 ? l10n.npcSavedToNpcs : l10n.npcSavedWithLinks(links),
          ),
        ),
      );
    }
  }

  Future<void> _copyAll(L10n l10n, NpcResult r) async {
    final b = StringBuffer();
    if (r.name.isNotEmpty) b.writeln(r.name);
    final body = _descriptionText(l10n, r, includeSecret: true);
    if (body.isNotEmpty) b.write(body);
    await Clipboard.setData(ClipboardData(text: b.toString().trim()));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.codexAiCopied)));
    }
  }
}

/// Bağ türü seçici: harita grafiğindeki türlerin AYNISI, renk noktasıyla.
class _BondDropdown extends StatelessWidget {
  const _BondDropdown({
    required this.bonds,
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.label,
  });

  final List<BondType> bonds;
  final String? value;
  final bool enabled;
  final ValueChanged<String?> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    // Tür silinmiş olabilir; geçersiz bir değer DropdownButton'u patlatır.
    final safe = bonds.any((b) => b.code == value) ? value : null;
    return DropdownButtonFormField<String>(
      initialValue: safe,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final b in bonds)
          DropdownMenuItem(
            value: b.code,
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(b.color),
                  ),
                ),
                SizedBox(width: context.spacing.sm),
                Flexible(child: Text(b.name, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
      ],
      onChanged: enabled ? onChanged : null,
    );
  }
}

/// NPC'nin bağlı olduğu yer + o bağın türü.
class _LocationPicker extends StatelessWidget {
  const _LocationPicker({
    required this.locations,
    required this.bonds,
    required this.selectedId,
    required this.selectedBond,
    required this.enabled,
    required this.onChanged,
  });

  final List<Location> locations;
  final List<BondType> bonds;
  final String? selectedId;
  final String? selectedBond;
  final bool enabled;
  final void Function(String? locationId, String? bondCode) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    if (locations.isEmpty) {
      return Text(
        l10n.npcNoLocations,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    final safe = locations.any((l) => l.id == selectedId) ? selectedId : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String?>(
          initialValue: safe,
          isExpanded: true,
          decoration: InputDecoration(labelText: l10n.npcBoundLocation),
          items: [
            DropdownMenuItem(
              value: null,
              child: Text(l10n.npcBoundLocationNone),
            ),
            for (final loc in locations)
              DropdownMenuItem(
                value: loc.id,
                child: Text(loc.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: enabled
              ? (id) => onChanged(
                  id,
                  // Yer seçilince bağ türü boş kalmasın: ilkini varsayılan yap.
                  id == null
                      ? null
                      : (selectedBond ??
                            (bonds.isNotEmpty ? bonds.first.code : null)),
                )
              : null,
        ),
        if (safe != null) ...[
          SizedBox(height: context.spacing.sm),
          _BondDropdown(
            bonds: bonds,
            value: selectedBond,
            enabled: enabled,
            label: l10n.bondSettingsTitle,
            onChanged: (code) => onChanged(safe, code),
          ),
        ],
        SizedBox(height: context.spacing.xs),
        Text(
          l10n.npcBoundLocationHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// İstenildiği kadar (NPC + bağ türü) satırı.
class _RelationsEditor extends StatelessWidget {
  const _RelationsEditor({
    required this.relations,
    required this.npcs,
    required this.bonds,
    required this.enabled,
    required this.onChanged,
  });

  final List<_RelationDraft> relations;
  final List<Npc> npcs;
  final List<BondType> bonds;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    if (npcs.isEmpty) {
      return Text(
        l10n.npcNoOtherNpcs,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, rel) in relations.indexed)
          Padding(
            padding: EdgeInsets.only(bottom: context.spacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    initialValue: npcs.any((n) => n.id == rel.npcId)
                        ? rel.npcId
                        : null,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.npcRelationPickNpc,
                    ),
                    items: [
                      for (final n in npcs)
                        DropdownMenuItem(
                          value: n.id,
                          child: Text(n.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: enabled
                        ? (v) {
                            rel.npcId = v;
                            // Bağ türü boş kalmasın.
                            rel.bondCode ??= bonds.isNotEmpty
                                ? bonds.first.code
                                : null;
                            onChanged();
                          }
                        : null,
                  ),
                ),
                SizedBox(width: context.spacing.sm),
                Expanded(
                  flex: 3,
                  child: _BondDropdown(
                    bonds: bonds,
                    value: rel.bondCode,
                    enabled: enabled,
                    label: l10n.bondSettingsTitle,
                    onChanged: (v) {
                      rel.bondCode = v;
                      onChanged();
                    },
                  ),
                ),
                IconButton(
                  tooltip: l10n.npcRemoveRelation,
                  onPressed: enabled
                      ? () {
                          relations.removeAt(i);
                          onChanged();
                        }
                      : null,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        Text(
          l10n.npcRelationsHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Portre üretimi anahtarı. Sağlayıcı görsel üretmiyorsa KAPALI ve nedeni
/// yazılı — sessizce çalışmayan bir anahtar bırakmak yerine.
class _PortraitToggle extends StatelessWidget {
  const _PortraitToggle({
    required this.value,
    required this.settings,
    required this.enabled,
    required this.onChanged,
  });

  final bool value;
  final AiSettings settings;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final supported = settings.provider.supportsImages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.npcPortraitToggle),
          subtitle: Text(
            supported
                ? l10n.npcPortraitToggleHint
                : l10n.npcPortraitUnsupported(settings.provider.label),
          ),
          value: supported && value,
          onChanged: supported && enabled ? onChanged : null,
        ),
        if (!supported)
          Padding(
            padding: EdgeInsets.only(top: context.spacing.xs),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                SizedBox(width: context.spacing.xs + 2),
                Expanded(
                  child: Text(
                    l10n.aiImageUnsupportedNote,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Üretilen portrenin gösterimi: kemerli çerçeve içinde, yükleme/hata halleri.
class _PortraitPanel extends StatelessWidget {
  const _PortraitPanel({
    required this.bytes,
    required this.loading,
    required this.error,
    required this.errorDetail,
    required this.onRegenerate,
  });

  final Uint8List? bytes;
  final bool loading;
  final String? error;
  final String? errorDetail;
  final VoidCallback? onRegenerate;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    // Hata halinde dar portre kutusu metni kirpar; tam genislikte ayrintili
    // kutu gosterilir — sorunu ancak saglayicinin cumlesi cozuyor.
    if (!loading && bytes == null && error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AiErrorBox(
            message: l10n.npcPortraitFailed(error!),
            detail: errorDetail,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onRegenerate,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(l10n.npcPortraitRegenerate),
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.md),
      child: Column(
        children: [
          SizedBox(
            width: 190,
            height: 250,
            child: switch ((loading, bytes)) {
              (true, _) => Center(
                child: AppLoading(label: l10n.npcPortraitGenerating),
              ),
              (_, final Uint8List b) => ArchFrame(
                child: Image.memory(b, fit: BoxFit.cover),
              ),
              _ => const SizedBox.shrink(),
            },
          ),
          if (!loading && bytes != null)
            TextButton.icon(
              onPressed: onRegenerate,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(l10n.npcPortraitRegenerate),
            ),
        ],
      ),
    );
  }
}

// --- Görev üreteci -------------------------------------------------------

class _QuestTool extends ConsumerStatefulWidget {
  const _QuestTool();
  @override
  ConsumerState<_QuestTool> createState() => _QuestToolState();
}

class _QuestToolState extends ConsumerState<_QuestTool> {
  final _setting = TextEditingController();
  int _partySize = 4;
  int _partyLevel = 3;
  QuestDifficulty _difficulty = QuestDifficulty.medium;

  // İsteğe bağlı: görevi veren NPC ve hedef lokasyon (null = serbest).
  String? _giverNpcId;
  String? _targetLocationId;

  final _run = AiRunState();

  @override
  void dispose() {
    _setting.dispose();
    super.dispose();
  }

  String _diffLabel(L10n l10n, QuestDifficulty d) => switch (d) {
    QuestDifficulty.veryEasy => l10n.questDiffVeryEasy,
    QuestDifficulty.easy => l10n.questDiffEasy,
    QuestDifficulty.medium => l10n.questDiffMedium,
    QuestDifficulty.hard => l10n.questDiffHard,
    QuestDifficulty.veryHard => l10n.questDiffVeryHard,
  };

  Future<void> _generate() async {
    final l10n = L10n.of(context);
    final npcs = ref.read(npcsProvider).value ?? const <Npc>[];
    final locations =
        ref.read(allLocationsProvider).value ?? const <Location>[];
    final built = buildQuestPrompt(
      partySize: _partySize,
      partyLevel: _partyLevel,
      difficulty: _difficulty,
      setting: _setting.text,
      languageName: l10n.localeName == 'tr' ? 'Türkçe' : 'English',
      questGiverNpc: _giverContext(_findNpc(npcs, _giverNpcId)),
      targetLocation: _targetContext(
        _findLocation(locations, _targetLocationId),
      ),
    );
    await _run.generate(
      context,
      ref,
      built.system,
      built.user,
      () => setState(() {}),
    );
  }

  Npc? _findNpc(List<Npc> npcs, String? id) {
    if (id == null) return null;
    for (final n in npcs) {
      if (n.id == id) return n;
    }
    return null;
  }

  Location? _findLocation(List<Location> locations, String? id) {
    if (id == null) return null;
    for (final l in locations) {
      if (l.id == id) return l;
    }
    return null;
  }

  /// NPC'yi prompta kısa bağlam olarak biçimlendirir (ad + rol + özet).
  String? _giverContext(Npc? n) {
    if (n == null) return null;
    final parts = <String>[n.name.trim()];
    if (n.role.trim().isNotEmpty) parts.add(n.role.trim());
    if (n.description.trim().isNotEmpty) {
      parts.add(_clip(n.description.trim()));
    }
    return parts.join(' — ');
  }

  /// Lokasyonu prompta kısa bağlam olarak biçimlendirir (ad + özet).
  String? _targetContext(Location? l) {
    if (l == null) return null;
    final parts = <String>[l.name.trim()];
    if (l.description.trim().isNotEmpty) {
      parts.add(_clip(l.description.trim()));
    }
    return parts.join(' — ');
  }

  static String _clip(String s, [int max = 160]) =>
      s.length <= max ? s : '${s.substring(0, max).trimRight()}…';

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final ai = ref.watch(aiSettingsProvider);
    if (!ai.enabled) return const AiNotConfigured();

    final result = _run.result == null ? null : parseQuestResult(_run.result!);

    final npcs = ref.watch(npcsProvider).value ?? const <Npc>[];
    final locations =
        ref.watch(allLocationsProvider).value ?? const <Location>[];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AiSliderRow(
          label: l10n.questPartySize,
          value: _partySize,
          min: 1,
          max: 8,
          enabled: !_run.loading,
          onChanged: (v) => setState(() => _partySize = v),
        ),
        const SizedBox(height: 8),
        AiSliderRow(
          label: l10n.questPartyLevel,
          value: _partyLevel,
          min: 1,
          max: 20,
          enabled: !_run.loading,
          onChanged: (v) => setState(() => _partyLevel = v),
        ),
        const SizedBox(height: 12),
        Text(l10n.questDifficulty, style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            for (final d in QuestDifficulty.values)
              ChoiceChip(
                label: Text(_diffLabel(l10n, d)),
                selected: _difficulty == d,
                onSelected: _run.loading
                    ? null
                    : (_) => setState(() => _difficulty = d),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _setting,
          decoration: InputDecoration(
            labelText: l10n.codexAiSetting,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        _OptionalEntityDropdown(
          label: l10n.questGiverNpc,
          noneLabel: l10n.questGiverNone,
          hint: l10n.questGiverHint,
          entries: [for (final n in npcs) (n.id, n.name)],
          value: _giverNpcId,
          enabled: !_run.loading,
          onChanged: (v) => setState(() => _giverNpcId = v),
        ),
        const SizedBox(height: 12),
        _OptionalEntityDropdown(
          label: l10n.questTargetLocation,
          noneLabel: l10n.questTargetNone,
          hint: l10n.questTargetHint,
          entries: [for (final l in locations) (l.id, l.name)],
          value: _targetLocationId,
          enabled: !_run.loading,
          onChanged: (v) => setState(() => _targetLocationId = v),
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
            child: AppLoading(),
          ),
        if (result != null)
          ..._resultSections(
            l10n,
            theme,
            result,
            ref.watch(sessionControllerProvider).isRunning,
          ),
      ],
    );
  }

  List<Widget> _resultSections(
    L10n l10n,
    ThemeData theme,
    QuestResult r,
    bool sessionRunning,
  ) {
    return [
      AiSection(title: l10n.questSectionQuest, body: r.quest),
      if (r.reward.isNotEmpty)
        AiSection(title: l10n.questSectionReward, body: r.reward),
      if (r.rewardCoinsCp > 0 || r.rewardItems.isNotEmpty)
        _QuestRewardLoot(result: r),
      if (r.dm.isNotEmpty)
        AiSection(
          title: l10n.questSectionDm,
          body: r.dm,
          dmOnly: true,
          note: l10n.questDmOnly,
        ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: () => _saveToQuests(l10n, r),
            icon: const Icon(Icons.assignment_add, size: 18),
            label: Text(l10n.questSendToQuests),
          ),
          OutlinedButton.icon(
            onPressed: () => _sendToPlayers(l10n, r, sessionRunning),
            icon: const Icon(Icons.cast, size: 18),
            label: Text(l10n.questSendPlayers),
          ),
          OutlinedButton.icon(
            onPressed: () => _copyPlayer(l10n, r),
            icon: const Icon(Icons.people_outline, size: 18),
            label: Text(l10n.questCopyPlayer),
          ),
          OutlinedButton.icon(
            onPressed: () => _copyAll(l10n, r),
            icon: const Icon(Icons.copy, size: 18),
            label: Text(l10n.questCopyAll),
          ),
          OutlinedButton.icon(
            onPressed: () => _insertQuestToCodex(context, ref, l10n, r),
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.codexAiInsert),
          ),
          TextButton(
            onPressed: () => setState(() {
              _run.result = null;
              _run.error = null;
            }),
            child: Text(l10n.aiRegenerate),
          ),
        ],
      ),
    ];
  }

  String _playerText(L10n l10n, QuestResult r) {
    final b = StringBuffer(r.quest);
    if (r.reward.isNotEmpty) {
      b.write('\n\n${l10n.questSectionReward}: ${r.reward}');
    }
    return b.toString();
  }

  /// Üretilen görevi kalıcı Görevler listesine kaydeder (başlık/metin/ödül/DM).
  /// Üreticinin verdiği sayısal ödül (para + eşyalar) doğrudan görevin gerçek
  /// ödülü olur: görev tamamlanınca oyunculara ortak ganimet havuzu olarak açılır.
  Future<void> _saveToQuests(L10n l10n, QuestResult r) async {
    final repo = ref.read(questRepositoryProvider);
    final title = r.title.isNotEmpty ? r.title : l10n.aiQuestHeading;
    final id = await repo.create(title: title);
    await repo.update(
      id,
      title: title,
      questText: r.quest,
      reward: r.reward,
      dmNotes: r.dm,
      rewardCoinsCp: r.rewardCoinsCp,
      rewardItems: r.rewardItems,
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.questSavedToQuests)));
    }
  }

  /// Oyuncu metnini (DM notu HARİÇ) canlı olarak oyuncu panellerine gönderir.
  /// Oturum açık değilse uyarır.
  Future<void> _sendToPlayers(
    L10n l10n,
    QuestResult r,
    bool sessionRunning,
  ) async {
    if (!sessionRunning) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.questNeedSession)));
      return;
    }
    await ref
        .read(sessionServiceProvider)
        .showHandoutText(
          text: _playerText(l10n, r),
          caption: l10n.aiQuestHeading,
        );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.questSentPlayers)));
    }
  }

  Future<void> _copyPlayer(L10n l10n, QuestResult r) async {
    await Clipboard.setData(ClipboardData(text: _playerText(l10n, r)));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.codexAiCopied)));
    }
  }

  Future<void> _copyAll(L10n l10n, QuestResult r) async {
    final b = StringBuffer(_playerText(l10n, r));
    if (r.dm.isNotEmpty) b.write('\n\n${l10n.questSectionDm}: ${r.dm}');
    await Clipboard.setData(ClipboardData(text: b.toString()));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.codexAiCopied)));
    }
  }
}

/// Görev üretecinde isteğe bağlı seçim (görev veren NPC / hedef lokasyon).
/// [value] null ise "yok (serbest)" seçili demektir; kayıt silinmişse güvenle
/// null'a düşer.
class _OptionalEntityDropdown extends StatelessWidget {
  const _OptionalEntityDropdown({
    required this.label,
    required this.noneLabel,
    required this.hint,
    required this.entries,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final String noneLabel;
  final String hint;

  /// (id, görünen ad) çiftleri.
  final List<(String, String)> entries;
  final String? value;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safe = entries.any((e) => e.$1 == value) ? value : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String?>(
          initialValue: safe,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: [
            DropdownMenuItem(value: null, child: Text(noneLabel)),
            for (final e in entries)
              DropdownMenuItem(
                value: e.$1,
                child: Text(e.$2, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: enabled ? onChanged : null,
        ),
        SizedBox(height: context.spacing.xs),
        Text(
          hint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// --- Ortak parçalar ------------------------------------------------------

/// Bir aracın çalışma durumu (yükleniyor/sonuç/hata) + üretim akışı.
class _QuestRewardLoot extends StatelessWidget {
  const _QuestRewardLoot({required this.result});

  final QuestResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.diamond_outlined,
                size: 16,
                color: theme.colorScheme.tertiary,
              ),
              const SizedBox(width: 6),
              Text(
                l10n.questRealReward,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.tertiary,
                ),
              ),
            ],
          ),
          Text(l10n.aiQuestRewardAuto, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (result.rewardCoinsCp > 0)
                Chip(
                  avatar: const Icon(Icons.paid, size: 16),
                  label: Text(formatCoins(result.rewardCoinsCp)),
                ),
              for (final item in result.rewardItems)
                Chip(
                  avatar: Icon(
                    item.magic ? Icons.auto_awesome : Icons.backpack_outlined,
                    size: 16,
                    color: item.magic ? theme.colorScheme.tertiary : null,
                  ),
                  label: Text(item.name),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<String?> _pickCodexPage(BuildContext context, WidgetRef ref) async {
  final l10n = L10n.of(context);
  final pages = await ref.read(codexPagesProvider.future);
  if (!context.mounted) return null;
  if (pages.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.aiNoPages)));
    return null;
  }
  return showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(l10n.aiPickPage),
      children: [
        for (final p in pages)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, p.id),
            child: Text(p.title.isEmpty ? l10n.codexUntitled : p.title),
          ),
      ],
    ),
  );
}

/// Düz metni seçilen bir Kayıtlar sayfasına başlık+metin olarak ekler.
Future<void> _insertToCodex(
  BuildContext context,
  WidgetRef ref, {
  required String heading,
  required String text,
}) async {
  final pageId = await _pickCodexPage(context, ref);
  if (pageId == null || !context.mounted) return;
  final repo = ref.read(codexRepositoryProvider);
  await repo.addBlock(
    pageId,
    CodexBlockType.heading,
    data: {'level': 2, 'text': heading},
  );
  await repo.addBlock(pageId, CodexBlockType.text, data: {'text': text});
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(L10n.of(context).codexAiInserted)));
  }
}

/// Görevi üç bölüm olarak seçilen Kayıtlar sayfasına ekler; DM açıklaması
/// DM'e özel callout (🔒) olur.
Future<void> _insertQuestToCodex(
  BuildContext context,
  WidgetRef ref,
  L10n l10n,
  QuestResult r,
) async {
  final pageId = await _pickCodexPage(context, ref);
  if (pageId == null || !context.mounted) return;
  final repo = ref.read(codexRepositoryProvider);
  await repo.addBlock(
    pageId,
    CodexBlockType.heading,
    data: {'level': 2, 'text': l10n.aiQuestHeading},
  );
  await repo.addBlock(pageId, CodexBlockType.text, data: {'text': r.quest});
  if (r.reward.isNotEmpty) {
    await repo.addBlock(
      pageId,
      CodexBlockType.text,
      data: {'text': '**${l10n.questSectionReward}:** ${r.reward}'},
    );
  }
  if (r.dm.isNotEmpty) {
    await repo.addBlock(
      pageId,
      CodexBlockType.callout,
      data: {'emoji': '🔒', 'text': '${l10n.questSectionDm}: ${r.dm}'},
    );
  }
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.codexAiInserted)));
  }
}
