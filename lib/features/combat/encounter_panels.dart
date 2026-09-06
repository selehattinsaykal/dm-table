import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../data/encounter_briefing.dart';
import '../../data/loot_resolver.dart';
import '../../data/party_inventory_repository.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../domain/rules/magic_item_pricing.dart';
import '../../l10n/app_localizations.dart';
import '../world/world_providers.dart';
import 'combat_providers.dart';

/// Savas ekraninin YAN PANELLERI.
///
/// Ana panel (initiative listesi) yerinde kalir; bunlar onun yaninda durur.
/// Genis ekranda sagda sabit bir kolon, dar ekranda arac cubugundan acilan
/// birer sheet — ikisinde de AYNI widget'lar cizilir.
///
/// Neden ayri dosya: `encounter_page.dart` zaten 1100+ satir ve initiative
/// mantiginin tamami orada. Brifing/ganimet bagimsiz bir eksen.

/// Brifing paneli: kazanma kosulu, taktik, arazi, takviye, zorluk ayari.
///
/// Salt okunur DEGIL ama duzenleme buradaki kalem dugmesinden acilir; masada
/// savas yonetirken yanlislikla metin silmek istemiyoruz.
class EncounterBriefingPanel extends ConsumerWidget {
  const EncounterBriefingPanel({required this.encounterId, super.key});

  final String encounterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final encounter = ref.watch(encounterProvider(encounterId)).value;
    if (encounter == null) return const SizedBox.shrink();

    final b = encounterBriefingFromJson(encounter.briefingJson);

    return _PanelCard(
      title: l10n.encPanelBriefing,
      icon: Icons.description_outlined,
      trailing: IconButton(
        tooltip: l10n.edit,
        icon: const Icon(Icons.edit_outlined, size: 18),
        onPressed: () => _edit(context, ref, b),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Yer bagi brifingin BOS olup olmamasindan bagimsiz duruyor:
          // "bu dovus nerede geciyor" sorusu metin yazilmamis bir
          // karsilasmada da sorulur.
          EncounterLocationRow(encounterId: encounterId),
          if (briefingIsEmpty(b))
            Text(
              l10n.encPanelBriefingEmpty,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            ..._briefingFields(l10n, b),
        ],
      ),
    );
  }

  List<Widget> _briefingFields(L10n l10n, EncounterBriefing b) => [
    // Kazanma kosulu EN USTTE ve vurgulu: savasin nasil bittigini bilmeden
    // taktik okumanin anlami yok.
    if (b.objective.isNotEmpty)
      _Field(
        label: l10n.encounterObjectiveSection,
        value: b.objective,
        emphasize: true,
      ),
    if (b.summary.isNotEmpty)
      _Field(label: l10n.encounterSummary, value: b.summary),
    if (b.tactics.isNotEmpty)
      _Field(label: l10n.encounterTactics, value: b.tactics),
    if (b.terrain.isNotEmpty)
      _Field(label: l10n.encounterTerrain, value: b.terrain),
    if (b.reinforcements.isNotEmpty)
      _Field(label: l10n.encounterReinforcements, value: b.reinforcements),
    if (b.scaling.isNotEmpty)
      _Field(label: l10n.encounterScaling, value: b.scaling),
    if (b.dmNotes.isNotEmpty)
      _Field(label: l10n.questSectionDm, value: b.dmNotes),
  ];

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    EncounterBriefing current,
  ) async {
    final result = await showModalBottomSheet<EncounterBriefing>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _BriefingEditor(initial: current),
    );
    if (result == null) return;
    await ref.read(combatRepositoryProvider).setBriefing(encounterId, result);
  }
}

/// Karsilasmanin gectigi yer: baglar, degistirir, bagi kaldirir.
///
/// **Neden brifingin icinde:** yer bir arac cubugu eylemi degil, karsilasmanin
/// bir OZELLIGI. Ayni panelde durunca "bu dovus nerede, ne icin, arazi ne"
/// tek bakista okunuyor.
///
/// Bagli yer SILINMIS olabilir (dunya agacindan kaldirilan bir oda); o zaman
/// satir bagi "kopuk" gosterir ve DM yeniden secebilir. Sessizce bos gostermek
/// "hic baglamamisim" yanilgisi yaratirdi.
class EncounterLocationRow extends ConsumerWidget {
  const EncounterLocationRow({required this.encounterId, super.key});

  final String encounterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final encounter = ref.watch(encounterProvider(encounterId)).value;
    final locationId = encounter?.locationId;

    final all = ref.watch(allLocationsProvider).value ?? const <Location>[];
    final linked = locationId == null
        ? null
        : all.where((l) => l.id == locationId).firstOrNull;

    final label = switch ((locationId, linked)) {
      (null, _) => l10n.encLocationNone,
      (_, null) => l10n.encLocationMissing,
      (_, final found?) => found.name,
    };

    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.sm),
      child: Row(
        children: [
          Icon(
            Icons.place_outlined,
            size: 16,
            color: locationId == null
                ? theme.colorScheme.outline
                : context.fantasyColors.brass,
          ),
          SizedBox(width: context.spacing.xs),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: linked == null ? theme.colorScheme.outline : null,
                fontStyle: locationId != null && linked == null
                    ? FontStyle.italic
                    : null,
              ),
            ),
          ),
          if (locationId != null)
            IconButton(
              tooltip: l10n.encLocationClear,
              icon: const Icon(Icons.link_off, size: 18),
              onPressed: () => ref
                  .read(combatRepositoryProvider)
                  .setLocation(encounterId, null),
            ),
          IconButton(
            tooltip: l10n.encLocationPick,
            icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
            onPressed: () => _pick(context, ref, all),
          ),
        ],
      ),
    );
  }

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    List<Location> all,
  ) async {
    final l10n = L10n.of(context);
    // Haritasiz "yer pini" kayitlari da listede: karsilasma bir odada oldugu
    // kadar bir yol ayriminda da gecebilir.
    final sorted = [...all]..sort((a, b) => a.name.compareTo(b.name));

    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: sorted.isEmpty
            ? Padding(
                padding: EdgeInsets.all(context.spacing.lg),
                child: Text(l10n.encLocationNoLocations),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    dense: true,
                    enabled: false,
                    title: Text(l10n.encLocationPick),
                  ),
                  const Divider(height: 1),
                  for (final location in sorted)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.place_outlined, size: 18),
                      title: Text(location.name),
                      onTap: () => Navigator.pop(context, location.id),
                    ),
                ],
              ),
      ),
    );
    if (picked == null) return;
    await ref.read(combatRepositoryProvider).setLocation(encounterId, picked);
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: emphasize
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: emphasize
                ? theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  )
                : theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _BriefingEditor extends StatefulWidget {
  const _BriefingEditor({required this.initial});

  final EncounterBriefing initial;

  @override
  State<_BriefingEditor> createState() => _BriefingEditorState();
}

class _BriefingEditorState extends State<_BriefingEditor> {
  late final _objective = TextEditingController(text: widget.initial.objective);
  late final _summary = TextEditingController(text: widget.initial.summary);
  late final _tactics = TextEditingController(text: widget.initial.tactics);
  late final _terrain = TextEditingController(text: widget.initial.terrain);
  late final _reinforcements = TextEditingController(
    text: widget.initial.reinforcements,
  );
  late final _scaling = TextEditingController(text: widget.initial.scaling);
  late final _dmNotes = TextEditingController(text: widget.initial.dmNotes);

  @override
  void dispose() {
    for (final c in [
      _objective,
      _summary,
      _tactics,
      _terrain,
      _reinforcements,
      _scaling,
      _dmNotes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.encPanelBriefing,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _field(_objective, l10n.encounterObjectiveSection),
              _field(_summary, l10n.encounterSummary, lines: 3),
              _field(_tactics, l10n.encounterTactics, lines: 3),
              _field(_terrain, l10n.encounterTerrain, lines: 2),
              _field(_reinforcements, l10n.encounterReinforcements, lines: 2),
              _field(_scaling, l10n.encounterScaling, lines: 2),
              _field(_dmNotes, l10n.questSectionDm, lines: 3),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.cancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, (
                      summary: _summary.text.trim(),
                      objective: _objective.text.trim(),
                      tactics: _tactics.text.trim(),
                      terrain: _terrain.text.trim(),
                      reinforcements: _reinforcements.text.trim(),
                      scaling: _scaling.text.trim(),
                      dmNotes: _dmNotes.text.trim(),
                    )),
                    child: Text(l10n.save),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {int lines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          maxLines: lines,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
      );
}

/// Ganimet paneli: savastan cikacak para + esyalar, ve savas bitince bunu
/// partiye verme.
///
/// Her esya kutuphaneye COZULMUS mu isaretlenir: cozulmusse keseye tam
/// kaydiyla (fiyat/aciklama) gider, cozulmemisse yalnizca ad olarak. DM
/// uydurma bir esyayi gercek sanmasin diye bu ayrim gorunur.
class EncounterLootPanel extends ConsumerWidget {
  const EncounterLootPanel({required this.encounterId, super.key});

  final String encounterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final encounter = ref.watch(encounterProvider(encounterId)).value;
    if (encounter == null) return const SizedBox.shrink();

    final loot = encounterLootFromJson(encounter.lootJson);
    final repo = ref.read(combatRepositoryProvider);
    final unresolved = loot.items.where((i) => !lootItemResolved(i)).length;

    return _PanelCard(
      title: l10n.encPanelLoot,
      icon: Icons.diamond_outlined,
      trailing: IconButton(
        tooltip: l10n.encLootAdd,
        icon: const Icon(Icons.add, size: 20),
        onPressed: () => _addItem(context, ref),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (lootIsEmpty(loot))
            Text(
              l10n.encPanelLootEmpty,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else ...[
            InkWell(
              onTap: () => _editCoins(context, ref, loot.coinsCp),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.savings_outlined,
                      size: 18,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        loot.coinsCp > 0
                            ? formatCoins(loot.coinsCp)
                            : l10n.encLootNoCoins,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const Icon(Icons.edit_outlined, size: 15),
                  ],
                ),
              ),
            ),
            for (final item in loot.items)
              _LootRow(
                item: item,
                onRemove: () => repo.removeLootItem(encounterId, item.id),
              ),
            // Cozulemeyenler ozetle bildirilir: DM listeyi tek tek
            // taramak zorunda kalmasin.
            if (unresolved > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.encLootUnresolvedHint(unresolved),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _grant(context, ref, loot),
              icon: const Icon(Icons.card_giftcard, size: 18),
              label: Text(l10n.encLootGrant),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _editCoins(
    BuildContext context,
    WidgetRef ref,
    int current,
  ) async {
    final controller = TextEditingController(text: '${current ~/ 100}');
    final l10n = L10n.of(context);
    final gp = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.encLootCoins),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            suffixText: 'gp',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              int.tryParse(controller.text.trim()) ?? 0,
            ),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (gp == null) return;
    await ref
        .read(combatRepositoryProvider)
        .setLootCoins(encounterId, gp * 100);
  }

  /// Esya ekler; girilen ad kutuphaneye cozulmeye calisilir.
  Future<void> _addItem(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    var magic = false;
    final l10n = L10n.of(context);

    final name = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(l10n.encLootAdd),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.lootAddItem,
                  helperText: l10n.encLootAddHint,
                  helperMaxLines: 2,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (v) => Navigator.pop(context, v.trim()),
              ),
              const SizedBox(height: 12),
              FilterChip(
                label: Text(l10n.lootMagic),
                selected: magic,
                onSelected: (v) => setLocal(() => magic = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text(l10n.add),
            ),
          ],
        ),
      ),
    );
    if (name == null || name.isEmpty) return;

    final resolved = await LootResolver(
      ref.read(compendiumRepositoryProvider),
    ).resolve(name: name, magic: magic);
    await ref
        .read(combatRepositoryProvider)
        .addLootItem(
          encounterId,
          name: resolved.name,
          magic: resolved.magic,
          itemKey: resolved.itemKey,
          magicItemKey: resolved.magicItemKey,
        );
  }

  /// Ganimeti bir parti kesesine aktarir ve karsilasmadan siler.
  ///
  /// Kese SECTIRILIR: birden fazla kese olabilir ve yanlis keseye ganimet
  /// koymak geri alinmasi can sikici bir hata.
  Future<void> _grant(
    BuildContext context,
    WidgetRef ref,
    EncounterLoot loot,
  ) async {
    final l10n = L10n.of(context);
    final repo = PartyInventoryRepository(ref.read(databaseProvider));
    final inventories = await repo.all();
    if (!context.mounted) return;

    if (inventories.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.encLootNoInventory)));
      return;
    }

    final target = inventories.length == 1
        ? inventories.first.id
        : await showDialog<String>(
            context: context,
            builder: (context) => SimpleDialog(
              title: Text(l10n.encLootPickInventory),
              children: [
                for (final inv in inventories)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, inv.id),
                    child: Text(inv.name),
                  ),
              ],
            ),
          );
    if (target == null) return;

    for (final item in loot.items) {
      await repo.depositItem(
        target,
        item: (
          id: item.id,
          name: item.name,
          magic: item.magic,
          itemKey: item.itemKey,
          magicItemKey: item.magicItemKey,
          desc: null,
          quantity: 1,
        ),
      );
    }
    if (loot.coinsCp > 0) {
      await repo.depositCoins(target, amountCp: loot.coinsCp);
    }
    // Ganimet verildi: karsilasmada durmasin, yoksa ikinci kez verilir.
    await ref
        .read(combatRepositoryProvider)
        .setLoot(encounterId, emptyEncounterLoot);

    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.encLootGranted)));
  }
}

class _LootRow extends StatelessWidget {
  const _LootRow({required this.item, required this.onRemove});

  final EncounterLootItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final resolved = lootItemResolved(item);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            item.magic ? Icons.auto_awesome : Icons.backpack_outlined,
            size: 18,
            color: item.magic ? theme.colorScheme.tertiary : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: theme.textTheme.bodyMedium),
                // Kutuphanede olmayan esya ACIKCA isaretlenir: anlam yalnizca
                // renge birakilmaz, metin de yazar.
                if (!resolved)
                  Text(
                    l10n.encLootNotInLibrary,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
          if (resolved)
            Tooltip(
              message: l10n.encLootInLibrary,
              child: Icon(
                Icons.verified_outlined,
                size: 16,
                color: theme.colorScheme.primary,
              ),
            ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 16),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

/// Yan panellerin ortak cercevesi.
class _PanelCard extends StatelessWidget {
  const _PanelCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.only(bottom: context.spacing.sm),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.spacing.md,
          context.spacing.sm,
          context.spacing.sm,
          context.spacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: context.fantasyColors.brass),
                SizedBox(width: context.spacing.sm),
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            SizedBox(height: context.spacing.sm),
            child,
          ],
        ),
      ),
    );
  }
}
