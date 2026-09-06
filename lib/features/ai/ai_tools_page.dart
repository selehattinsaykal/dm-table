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
  NpcDisposition _disposition = NpcDisposition.any;
  NpcImportance _importance = NpcImportance.recurring;
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

  String _dispositionLabel(L10n l10n, NpcDisposition d) => switch (d) {
    NpcDisposition.any => l10n.npcDispAny,
    NpcDisposition.friendly => l10n.npcDispFriendly,
    NpcDisposition.neutral => l10n.npcDispNeutral,
    NpcDisposition.wary => l10n.npcDispWary,
    NpcDisposition.hostile => l10n.npcDispHostile,
    NpcDisposition.deceptive => l10n.npcDispDeceptive,
  };

  String _importanceLabel(L10n l10n, NpcImportance i) => switch (i) {
    NpcImportance.walkOn => l10n.npcImpWalkOn,
    NpcImportance.recurring => l10n.npcImpRecurring,
    NpcImportance.major => l10n.npcImpMajor,
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
      disposition: _disposition,
      importance: _importance,
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
        AiEnumChips<NpcDisposition>(
          label: l10n.npcDisposition,
          values: NpcDisposition.values,
          selected: _disposition,
          enabled: !busy,
          labelOf: (d) => _dispositionLabel(l10n, d),
          onSelected: (v) => setState(() => _disposition = v),
        ),
        SizedBox(height: context.spacing.md),
        AiEnumChips<NpcImportance>(
          label: l10n.npcImportance,
          values: NpcImportance.values,
          selected: _importance,
          enabled: !busy,
          labelOf: (i) => _importanceLabel(l10n, i),
          onSelected: (v) => setState(() => _importance = v),
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
    // Gecerli JSON gelmediyse (cogunlukla yanit kesilmis) ham metni NPC gibi
    // gostermek yaniltici; hata olarak soyle ve yeniden uretmeyi oner.
    if (!r.parsed) {
      return [
        AiErrorBox(message: l10n.npcParseFailed, detail: r.appearance),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => setState(() {
            _run.result = null;
            _run.error = null;
          }),
          icon: const Icon(Icons.refresh, size: 18),
          label: Text(l10n.aiRegenerate),
        ),
      ];
    }

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
      // MASA alanlari: DM karakteri canlandirirken bunlari okur, bu yuzden
      // kancadan ONCE ve bir arada duruyorlar.
      if (r.voice.isNotEmpty || r.mannerism.isNotEmpty)
        AiSection(
          title: l10n.npcSectionVoice,
          body: [
            if (r.voice.isNotEmpty) r.voice,
            if (r.mannerism.isNotEmpty) r.mannerism,
          ].join('\n'),
        ),
      if (r.wants.isNotEmpty)
        AiSection(title: l10n.npcSectionWants, body: r.wants),
      if (r.firstLine.isNotEmpty)
        AiSection(
          title: l10n.npcSectionFirstLine,
          body: '“${r.firstLine}”',
          note: l10n.npcFirstLineNote,
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
    para(
      l10n.npcSectionVoice,
      [
        if (r.voice.isNotEmpty) r.voice,
        if (r.mannerism.isNotEmpty) r.mannerism,
      ].join('\n'),
    );
    para(l10n.npcSectionWants, r.wants);
    para(
      l10n.npcSectionFirstLine,
      r.firstLine.isEmpty ? '' : '“${r.firstLine}”',
    );
    para(l10n.npcSectionHook, r.hook);
    if (includeSecret) para(l10n.npcSectionSecret, r.secret);
    return b.toString().trim();
  }

  /// Yapisal sutunu olmayan MASA alanlarini NPC'nin "Notlar" alanina yazar.
  ///
  /// `Npcs` semasinda ses/tavir/istek/replik icin sutun yok. Bunun icin sema
  /// gocu acmak (yedekleme/geri yukleme uyumlulugu dahil) bu alanlarin
  /// degdiginden fazla risk; etiketli metin olarak notlarda duruyorlar ve NPC
  /// sayfasinda oldugu gibi okunuyorlar.
  String _tableNotes(L10n l10n, NpcResult r) {
    final b = StringBuffer(r.summary.trim());
    void line(String label, String value) {
      if (value.trim().isEmpty) return;
      if (b.isNotEmpty) b.write('\n\n');
      b.write('$label: ${value.trim()}');
    }

    line(l10n.npcSectionVoice, r.voice);
    line(l10n.npcSectionMannerism, r.mannerism);
    line(l10n.npcSectionWants, r.wants);
    line(
      l10n.npcSectionFirstLine,
      r.firstLine.isEmpty ? '' : '“${r.firstLine}”',
    );
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
      description: _tableNotes(l10n, r),
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
        AiLocationTreePicker(
          label: l10n.npcBoundLocation,
          noneLabel: l10n.npcBoundLocationNone,
          hint: l10n.npcBoundLocationHint,
          nodes: locations.toNodes(),
          value: safe,
          enabled: enabled,
          onChanged: (id) => onChanged(
            id,
            // Yer seçilince bağ türü boş kalmasın: ilkini varsayılan yap.
            id == null
                ? null
                : (selectedBond ??
                      (bonds.isNotEmpty ? bonds.first.code : null)),
          ),
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
  QuestKind _kind = QuestKind.any;
  QuestScope _scope = QuestScope.oneShot;
  QuestTone _tone = QuestTone.any;
  QuestUrgency _urgency = QuestUrgency.none;

  /// Somut süre (yalnız süre baskısı varken sorulur).
  int _deadlineAmount = 3;
  QuestTimeUnit _deadlineUnit = QuestTimeUnit.days;

  // İsteğe bağlı bağlar (null = serbest bırak, üretici kendi seçsin).
  String? _giverNpcId;

  /// Görevin ALINDIĞI yer — hedef lokasyondan ayrı bir alan. Parti görevi
  /// handa alır ama olay dağdaki harabede geçer; tek alanla bu ikisi
  /// karışıyordu.
  String? _giverLocationId;
  String? _targetLocationId;
  String? _antagonistNpcId;
  String? _followsUpQuestId;

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

  String _kindLabel(L10n l10n, QuestKind k) => switch (k) {
    QuestKind.any => l10n.questKindAny,
    QuestKind.retrieve => l10n.questKindRetrieve,
    QuestKind.eliminate => l10n.questKindEliminate,
    QuestKind.escort => l10n.questKindEscort,
    QuestKind.rescue => l10n.questKindRescue,
    QuestKind.investigate => l10n.questKindInvestigate,
    QuestKind.delivery => l10n.questKindDelivery,
    QuestKind.defend => l10n.questKindDefend,
    QuestKind.explore => l10n.questKindExplore,
    QuestKind.diplomacy => l10n.questKindDiplomacy,
    QuestKind.heist => l10n.questKindHeist,
  };

  String _scopeLabel(L10n l10n, QuestScope s) => switch (s) {
    QuestScope.oneShot => l10n.questScopeOneShot,
    QuestScope.shortArc => l10n.questScopeShortArc,
    QuestScope.campaignArc => l10n.questScopeCampaign,
  };

  String _toneLabel(L10n l10n, QuestTone t) => switch (t) {
    QuestTone.any => l10n.questToneAny,
    QuestTone.heroic => l10n.questToneHeroic,
    QuestTone.mysterious => l10n.questToneMysterious,
    QuestTone.grim => l10n.questToneGrim,
    QuestTone.comedic => l10n.questToneComedic,
    QuestTone.morallyGrey => l10n.questToneGrey,
  };

  String _urgencyLabel(L10n l10n, QuestUrgency u) => switch (u) {
    QuestUrgency.none => l10n.questUrgencyNone,
    QuestUrgency.soft => l10n.questUrgencySoft,
    QuestUrgency.hard => l10n.questUrgencyHard,
  };

  String _unitLabel(L10n l10n, QuestTimeUnit u) => switch (u) {
    QuestTimeUnit.hours => l10n.questUnitHours,
    QuestTimeUnit.days => l10n.questUnitDays,
    QuestTimeUnit.weeks => l10n.questUnitWeeks,
    QuestTimeUnit.months => l10n.questUnitMonths,
  };

  Future<void> _generate() async {
    final l10n = L10n.of(context);
    final npcs = ref.read(npcsProvider).value ?? const <Npc>[];
    final locations =
        ref.read(allLocationsProvider).value ?? const <Location>[];
    final quests = ref.read(questsProvider).value ?? const <Quest>[];
    final built = buildQuestPrompt(
      partySize: _partySize,
      partyLevel: _partyLevel,
      difficulty: _difficulty,
      setting: _setting.text,
      languageName: l10n.localeName == 'tr' ? 'Türkçe' : 'English',
      kind: _kind,
      scope: _scope,
      tone: _tone,
      urgency: _urgency,
      deadline: _urgency.takesDeadline
          ? (amount: _deadlineAmount, unit: _deadlineUnit)
          : null,
      questGiverNpc: _giverContext(_findNpc(npcs, _giverNpcId)),
      antagonistNpc: _giverContext(_findNpc(npcs, _antagonistNpcId)),
      giverLocation: _targetContext(_findLocation(locations, _giverLocationId)),
      targetLocation: _targetContext(
        _findLocation(locations, _targetLocationId),
      ),
      followsUpQuest: _questContext(_findQuest(quests, _followsUpQuestId)),
    );
    await _run.generate(
      context,
      ref,
      built.system,
      built.user,
      () => setState(() {}),
      // Asamalar + kancalar + komplikasyonlar + yan karakterler tek yanitta
      // geliyor; butce KAPSAMA gore olceklenir, sabit butce kampanya
      // yaylarinda JSON'i ortasindan kesiyordu.
      maxTokens: _scope.maxTokens,
    );
  }

  Quest? _findQuest(List<Quest> quests, String? id) {
    if (id == null) return null;
    for (final q in quests) {
      if (q.id == id) return q;
    }
    return null;
  }

  /// Devamı yazılacak görevi prompta kısa bağlam olarak biçimlendirir.
  String? _questContext(Quest? q) {
    if (q == null) return null;
    final parts = <String>[
      q.title.trim().isEmpty ? '(adsız görev)' : q.title.trim(),
    ];
    if (q.questText.trim().isNotEmpty) parts.add(_clip(q.questText.trim()));
    return parts.join(' — ');
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
    final quests = ref.watch(questsProvider).value ?? const <Quest>[];

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
        AiEnumChips<QuestKind>(
          label: l10n.questKind,
          values: QuestKind.values,
          selected: _kind,
          enabled: !_run.loading,
          labelOf: (k) => _kindLabel(l10n, k),
          onSelected: (v) => setState(() => _kind = v),
        ),
        const SizedBox(height: 12),
        AiEnumChips<QuestScope>(
          label: l10n.questScope,
          values: QuestScope.values,
          selected: _scope,
          enabled: !_run.loading,
          labelOf: (s) => _scopeLabel(l10n, s),
          onSelected: (v) => setState(() => _scope = v),
        ),
        const SizedBox(height: 12),
        AiEnumChips<QuestTone>(
          label: l10n.questTone,
          values: QuestTone.values,
          selected: _tone,
          enabled: !_run.loading,
          labelOf: (t) => _toneLabel(l10n, t),
          onSelected: (v) => setState(() => _tone = v),
        ),
        const SizedBox(height: 12),
        AiEnumChips<QuestUrgency>(
          label: l10n.questUrgency,
          values: QuestUrgency.values,
          selected: _urgency,
          enabled: !_run.loading,
          labelOf: (u) => _urgencyLabel(l10n, u),
          onSelected: (v) => setState(() => _urgency = v),
        ),
        // Somut süre yalnız baskı varken sorulur: "baskı yok" seçiliyken
        // süre sormak kullanıcıyı anlamsız bir karara zorlar.
        if (_urgency.takesDeadline) ...[
          const SizedBox(height: 12),
          _DeadlineRow(
            label: l10n.questDeadline,
            amount: _deadlineAmount,
            unit: _deadlineUnit,
            enabled: !_run.loading,
            unitLabel: (u) => _unitLabel(l10n, u),
            onAmountChanged: (v) => setState(() => _deadlineAmount = v),
            onUnitChanged: (v) => setState(() => _deadlineUnit = v),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _setting,
          decoration: InputDecoration(
            labelText: l10n.codexAiSetting,
            border: const OutlineInputBorder(),
          ),
        ),
        SectionHeader(label: l10n.questLinksSection, icon: Icons.link),
        AiOptionalPicker(
          label: l10n.questGiverNpc,
          noneLabel: l10n.questGiverNone,
          hint: l10n.questGiverHint,
          entries: [for (final n in npcs) (n.id, n.name)],
          value: _giverNpcId,
          enabled: !_run.loading,
          onChanged: (v) => setState(() => _giverNpcId = v),
        ),
        const SizedBox(height: 12),
        AiLocationTreePicker(
          label: l10n.questGiverLocation,
          noneLabel: l10n.questTargetNone,
          hint: l10n.questGiverLocationHint,
          nodes: locations.toNodes(),
          value: _giverLocationId,
          enabled: !_run.loading,
          onChanged: (v) => setState(() => _giverLocationId = v),
        ),
        const SizedBox(height: 12),
        AiLocationTreePicker(
          label: l10n.questTargetLocation,
          noneLabel: l10n.questTargetNone,
          hint: l10n.questTargetHint,
          nodes: locations.toNodes(),
          value: _targetLocationId,
          enabled: !_run.loading,
          onChanged: (v) => setState(() => _targetLocationId = v),
        ),
        const SizedBox(height: 12),
        AiOptionalPicker(
          label: l10n.questAntagonist,
          noneLabel: l10n.questGiverNone,
          hint: l10n.questAntagonistHint,
          entries: [for (final n in npcs) (n.id, n.name)],
          value: _antagonistNpcId,
          enabled: !_run.loading,
          onChanged: (v) => setState(() => _antagonistNpcId = v),
        ),
        const SizedBox(height: 12),
        AiOptionalPicker(
          label: l10n.questFollowsUp,
          noneLabel: l10n.questGiverNone,
          hint: l10n.questFollowsUpHint,
          entries: [
            for (final q in quests)
              (q.id, q.title.trim().isEmpty ? '—' : q.title),
          ],
          value: _followsUpQuestId,
          enabled: !_run.loading,
          onChanged: (v) => setState(() => _followsUpQuestId = v),
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
        if (result != null) ..._resultSections(l10n, theme, result),
      ],
    );
  }

  List<Widget> _resultSections(L10n l10n, ThemeData theme, QuestResult r) {
    // Model gecerli JSON dondurmediyse (cogunlukla yanit kesilmis) elimizdeki
    // tek sey ham metin. Bunu sessizce "gorev metni" diye gostermek yaniltici:
    // DM neyin eksik oldugunu bilmeli ve yeniden uretebilmeli.
    if (!r.parsed) {
      return [
        AiErrorBox(message: l10n.questParseFailed, detail: r.quest),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => setState(() {
            _run.result = null;
            _run.error = null;
          }),
          icon: const Icon(Icons.refresh, size: 18),
          label: Text(l10n.aiRegenerate),
        ),
      ];
    }

    return [
      AiSection(title: l10n.questSectionQuest, body: r.quest),
      if (r.reward.isNotEmpty)
        AiSection(title: l10n.questSectionReward, body: r.reward),
      if (r.rewardCoinsCp > 0 || r.rewardItems.isNotEmpty)
        _QuestRewardLoot(result: r),
      // Asagisi tamamen DM'e ozel PLANLAMA malzemesi; oyunculara giden
      // kopyaya (bkz. _playerText) hicbiri girmez.
      if (r.hooks.isNotEmpty)
        AiSection(
          title: l10n.questSectionHooks,
          body: _bullets(r.hooks),
          dmOnly: true,
          note: l10n.questHooksNote,
        ),
      if (r.stages.isNotEmpty)
        AiSection(
          title: l10n.questSectionStages,
          body: _stagesText(r.stages),
          dmOnly: true,
        ),
      if (r.complications.isNotEmpty)
        AiSection(
          title: l10n.questSectionComplications,
          body: _bullets(r.complications),
          dmOnly: true,
        ),
      if (r.failure.isNotEmpty)
        AiSection(
          title: l10n.questSectionFailure,
          body: r.failure,
          dmOnly: true,
        ),
      if (r.keyNpcs.isNotEmpty)
        AiSection(
          title: l10n.questSectionKeyNpcs,
          body: _npcsText(r.keyNpcs),
          dmOnly: true,
        ),
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
  /// ödülü olarak yazılır.
  Future<void> _saveToQuests(L10n l10n, QuestResult r) async {
    final repo = ref.read(questRepositoryProvider);
    final title = r.title.isNotEmpty ? r.title : l10n.aiQuestHeading;
    final id = await repo.create(title: title);
    await repo.update(
      id,
      title: title,
      questText: r.quest,
      reward: r.reward,
      // Kancalar, aşamalar, komplikasyonlar ve yan karakterler de DM notuna
      // girer; aksi halde üretilen planın çoğu kaydedince kaybolurdu.
      dmNotes: _questDmNotes(l10n, r),
      rewardCoinsCp: r.rewardCoinsCp,
      rewardItems: r.rewardItems,
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.questSavedToQuests)));
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
    final dm = _questDmNotes(l10n, r);
    if (dm.isNotEmpty) b.write('\n\n$dm');
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
/// Somut süre satırı: sayı kaydırıcısı + birim chip'leri ("3 gün").
class _DeadlineRow extends StatelessWidget {
  const _DeadlineRow({
    required this.label,
    required this.amount,
    required this.unit,
    required this.enabled,
    required this.unitLabel,
    required this.onAmountChanged,
    required this.onUnitChanged,
  });

  final String label;
  final int amount;
  final QuestTimeUnit unit;
  final bool enabled;
  final String Function(QuestTimeUnit) unitLabel;
  final ValueChanged<int> onAmountChanged;
  final ValueChanged<QuestTimeUnit> onUnitChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AiSliderRow(
          label: label,
          value: amount,
          min: 1,
          // 30 hem "30 gün" hem "30 saat" için makul bir tavan; daha uzunu
          // için birim yükseltilir.
          max: 30,
          enabled: enabled,
          onChanged: onAmountChanged,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final u in QuestTimeUnit.values)
              ChoiceChip(
                label: Text(unitLabel(u)),
                selected: unit == u,
                onSelected: enabled ? (_) => onUnitChanged(u) : null,
              ),
          ],
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
/// Madde imli liste metni.
String _bullets(List<String> items) =>
    [for (final i in items) '• $i'].join('\n');

/// Aşamalar: numaralı başlık, altında açıklaması.
String _stagesText(List<QuestStage> stages) {
  final b = StringBuffer();
  for (final (i, s) in stages.indexed) {
    if (b.isNotEmpty) b.write('\n\n');
    b.write(s.title.isEmpty ? '${i + 1}.' : '${i + 1}. ${s.title}');
    if (s.detail.isNotEmpty) b.write('\n${s.detail}');
  }
  return b.toString();
}

String _npcsText(List<QuestNpcBrief> npcs) => [
  for (final n in npcs)
    n.role.isEmpty ? '• ${n.name}' : '• ${n.name} — ${n.role}',
].join('\n');

/// Görev kaydının DM notu: üretilen tüm planlama malzemesi tek metinde.
///
/// Neden tek alan: `Quests` şemasında aşama/kanca/komplikasyon için sütun yok.
/// Bunun için şema göçü açmak (yedekleme/geri yükleme uyumluluğu dahil) bu
/// özelliğin değdiğinden fazla risk taşıyordu; biçimli metin DM notunda durur
/// ve görev sayfasında olduğu gibi okunur.
String _questDmNotes(L10n l10n, QuestResult r) {
  final b = StringBuffer();
  void section(String title, String body) {
    if (body.trim().isEmpty) return;
    if (b.isNotEmpty) b.write('\n\n');
    b.write('$title\n$body');
  }

  section(l10n.questSectionHooks, _bullets(r.hooks));
  section(l10n.questSectionStages, _stagesText(r.stages));
  section(l10n.questSectionComplications, _bullets(r.complications));
  section(l10n.questSectionFailure, r.failure);
  section(l10n.questSectionKeyNpcs, _npcsText(r.keyNpcs));
  section(l10n.questSectionDm, r.dm);
  return b.toString();
}

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
  // DM'e özel her şey TEK kilitli blokta: Codex sayfasında oyuncuya
  // gösterilebilecek metinle karışmasın.
  final dmNotes = _questDmNotes(l10n, r);
  if (dmNotes.isNotEmpty) {
    await repo.addBlock(
      pageId,
      CodexBlockType.callout,
      data: {'emoji': '🔒', 'text': dmNotes},
    );
  }
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.codexAiInserted)));
  }
}
