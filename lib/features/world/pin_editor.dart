import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../data/db/world_tables.dart';
import '../../data/loot_repository.dart';
import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import '../combat/combat_providers.dart';
import '../loot/loot_page.dart';
import '../shops/shop_providers.dart';
import 'map_view.dart' show pinKindColor, pinKindIcon;
import 'world_providers.dart';

/// Pin ekleme/duzenleme paneli.
///
/// Bir pin ya serbest not tasir ya da baska bir kayda baglanir (alt yer, NPC,
/// magaza, karsilasma). Bagli oldugu kayit bilgi agacinin kenarini olusturur:
/// "bu NPC nerelerde geciyor" sorusu bu baglantidan cevaplaniyor.
Future<void> showPinEditor(
  BuildContext context,
  WidgetRef ref, {
  required String locationId,
  MapPin? pin,
  double? x,
  double? y,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: _PinEditor(locationId: locationId, pin: pin, x: x, y: y),
  ),
);

class _PinEditor extends ConsumerStatefulWidget {
  const _PinEditor({required this.locationId, this.pin, this.x, this.y});

  final String locationId;
  final MapPin? pin;
  final double? x;
  final double? y;

  @override
  ConsumerState<_PinEditor> createState() => _PinEditorState();
}

class _PinEditorState extends ConsumerState<_PinEditor> {
  late final _label = TextEditingController(text: widget.pin?.label ?? '');
  late final _note = TextEditingController(text: widget.pin?.noteText ?? '');
  late PinKind _kind = widget.pin?.kind ?? PinKind.note;
  late String? _targetId = widget.pin?.targetId;
  late String? _lootSetId = widget.pin?.lootSetId;

  bool get _isNew => widget.pin == null;

  /// Bagli ganimet seti pin olusturulduktan sonra degistirilemez.
  bool get _treasureLocked =>
      _kind == PinKind.treasure && !_isNew && widget.pin?.lootSetId != null;

  @override
  void dispose() {
    _label.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _isNew ? l10n.worldAddPin : l10n.worldPinEdit,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _label,
            autofocus: _isNew,
            decoration: InputDecoration(
              labelText: l10n.worldPinLabel,
              hintText: l10n.worldPinLabelHint,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Text(l10n.worldPinType, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final kind in PinKind.values)
                ChoiceChip(
                  label: Text(pinKindLabel(l10n, kind)),
                  selected: _kind == kind,
                  onSelected: (_) => setState(() {
                    _kind = kind;
                    // Tur degisince eski hedef anlamsiz kalir.
                    _targetId = null;
                    _lootSetId = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_kind == PinKind.treasure) ...[
            // Hazine pini bir ganimet setine baglanir; set secilince label
            // otomatik set adiyla dolar.
            _LootSetPicker(
              lootSetId: _lootSetId,
              locked: _treasureLocked,
              onSelected: (id, name) => setState(() {
                _lootSetId = id;
                if (_label.text.trim().isEmpty) _label.text = name;
              }),
            ),
            // Kismen alinmis bir hazine piniyse kalan durumu goster.
            if (widget.pin?.lootDataJson case final lootJson?) ...[
              const SizedBox(height: 8),
              _RemainingLootInfo(lootDataJson: lootJson),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.worldPinNote,
                hintText: l10n.worldPinNoteHint,
                border: const OutlineInputBorder(),
              ),
            ),
          ] else if (_kind == PinKind.note || _kind == PinKind.place) ...[
            // Haritasiz yerde hedef SECILMEZ: kaydederken lokasyon kaydi
            // kendiliginden aciliyor (bkz. `_save`).
            if (_kind == PinKind.place) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.worldPinPlaceHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _note,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: l10n.worldPinNote,
                hintText: l10n.worldPinNoteHint,
                border: const OutlineInputBorder(),
              ),
            ),
          ] else
            _TargetPicker(
              kind: _kind,
              locationId: widget.locationId,
              selected: _targetId,
              onSelected: (id, name) => setState(() {
                _targetId = id;
                if (_label.text.trim().isEmpty) _label.text = name;
              }),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (!_isNew)
                TextButton.icon(
                  onPressed: () async {
                    await ref
                        .read(worldRepositoryProvider)
                        .deletePin(widget.pin!.id);
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l10n.delete),
                ),
              const Spacer(),
              FilledButton(
                onPressed: _canSave ? _save : null,
                child: Text(_isNew ? l10n.add : l10n.save),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Bagli tur seciliyse hedef zorunlu; yoksa bosa dusen pin olusur.
  bool get _canSave {
    if (_label.text.trim().isEmpty) return false;
    // Haritasiz yer de hedef ISTEMEZ: lokasyonu kaydederken kendisi aciyor.
    if (_kind == PinKind.note ||
        _kind == PinKind.treasure ||
        _kind == PinKind.place) {
      return true;
    }
    return _targetId != null;
  }

  Future<void> _save() async {
    final repo = ref.read(worldRepositoryProvider);

    // Haritasiz yer, ARKASINDA gercek bir lokasyon kaydi tutar: gorev
    // ureticisi, seyahat planlayici ve lokasyon secicileri `Locations`
    // tablosunu okuyor, oraya girmeyen bir pin oralarda hic gozukmezdi.
    if (_kind == PinKind.place) {
      if (_targetId == null) {
        _targetId = await repo.createLocation(
          name: _label.text.trim(),
          parentId: widget.locationId,
          description: _note.text.trim(),
        );
      } else {
        // Duzenlemede ad/aciklama pinle birlikte guncellensin; aksi halde
        // gorev listesinde eski ad gozukmeye devam ederdi.
        await repo.updateLocation(
          _targetId!,
          name: _label.text.trim(),
          description: _note.text.trim(),
        );
      }
    }

    if (_isNew) {
      // Hazine pini bir ganimet setine baglandiysa setin kopyasi "kalan
      // ganimet" olarak pin'e yazilir; DM dagittikca azalir.
      final lootJson = (_kind == PinKind.treasure && _lootSetId != null)
          ? await _initialLootJson(_lootSetId!)
          : null;
      await repo.addPin(
        locationId: widget.locationId,
        kind: _kind,
        label: _label.text.trim(),
        x: widget.x ?? 0.5,
        y: widget.y ?? 0.5,
        targetId: _targetId,
        noteText: _note.text.trim(),
        lootSetId: _lootSetId,
        lootDataJson: lootJson,
      );
    } else {
      await repo.updatePin(
        widget.pin!.id,
        label: _label.text.trim(),
        noteText: _note.text.trim(),
        targetId: _targetId,
      );
    }

    if (mounted) Navigator.pop(context);
  }

  /// Secili ganimet setini pinin baslangic "kalan ganimet" verisine cevirir.
  Future<String?> _initialLootJson(String lootSetId) async {
    final set = await ref.read(lootRepositoryProvider).find(lootSetId);
    if (set == null) return null;
    return LootRepository.initialPinLoot(set);
  }
}

/// Pin turunun okunabilir adi.
String pinKindLabel(L10n l10n, PinKind kind) => switch (kind) {
  PinKind.location => l10n.worldKindLocation,
  PinKind.place => l10n.worldKindPlace,
  PinKind.note => l10n.worldPinNote,
  PinKind.npc => l10n.worldKindNpc,
  PinKind.shop => l10n.worldKindShop,
  PinKind.encounter => l10n.worldKindEncounter,
  PinKind.treasure => l10n.worldKindTreasure,
};

/// Pinin SALT-OKUNUR ozeti (goruntuleme modu).
///
/// Goruntuleme modunda pine dokunmak duzenleyiciyi acmaz — masada yanlislikla
/// bir pini degistirmek istemiyoruz.
Future<void> showPinInfo(
  BuildContext context,
  WidgetRef ref, {
  required MapPin pin,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (context) => _PinInfo(pin: pin),
);

class _PinInfo extends ConsumerWidget {
  const _PinInfo({required this.pin});

  final MapPin pin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final color = pinKindColor(
      pin.kind,
      theme.colorScheme,
      context.fantasyColors,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color,
                  child: Icon(
                    pinKindIcon(pin.kind),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(pin.label, style: theme.textTheme.titleLarge),
                      Text(
                        pinKindLabel(l10n, pin.kind),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (pin.noteText.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(pin.noteText, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.close),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hazine pinine baglanan ganimet setini secer (ya da bagliysa salt okunur
/// gosterir).
class _LootSetPicker extends ConsumerWidget {
  const _LootSetPicker({
    required this.lootSetId,
    required this.locked,
    required this.onSelected,
  });

  /// Secili/bagli set id'si; null = henuz secilmedi.
  final String? lootSetId;

  /// Mevcut pinin seti degistirilebilir mi (olusturulduktan sonra hayir).
  final bool locked;

  final void Function(String id, String name) onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final sets = ref.watch(lootSetsProvider);
    final rows = sets.value ?? const <LootSet>[];

    if (locked) {
      final set = rows.where((s) => s.id == lootSetId).firstOrNull;
      return InputDecorator(
        decoration: InputDecoration(
          labelText: l10n.worldKindTreasureLoot,
          border: const OutlineInputBorder(),
        ),
        child: Text(set?.name ?? lootSetId ?? ''),
      );
    }

    // Henuz set yoksa aciklama.
    if (sets.hasError) {
      return Text(
        l10n.worldTreasureNoLootSets,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    if (sets.isLoading || rows.isEmpty) {
      return Text(
        rows.isEmpty ? l10n.worldTreasureNoLootSets : '',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    final safe = rows.any((s) => s.id == lootSetId) ? lootSetId : null;
    return DropdownButtonFormField<String?>(
      initialValue: safe,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: l10n.worldKindTreasureLoot,
        helperText: l10n.worldKindTreasureLootHint,
        helperMaxLines: 2,
        border: const OutlineInputBorder(),
      ),
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text(l10n.worldKindTreasureLootNone),
        ),
        for (final s in rows)
          DropdownMenuItem<String?>(
            value: s.id,
            child: Text(s.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (id) {
        if (id == null) return;
        final set = rows.firstWhere((s) => s.id == id);
        onSelected(id, set.name);
      },
    );
  }
}

/// Hazineden kalan ganimetin ozeti (kismen alinmis pin icin DM gostergesi).
class _RemainingLootInfo extends StatelessWidget {
  const _RemainingLootInfo({required this.lootDataJson});

  final String lootDataJson;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final loot = LootRepository.pinLootOf(lootDataJson);
    if (loot == null) return const SizedBox.shrink();
    return Row(
      children: [
        Icon(
          Icons.history,
          size: 15,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            l10n.worldTreasureRemainingDetail(loot.coinsCp, loot.items.length),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// Pinin baglanacagi kaydi sectirir.
class _TargetPicker extends ConsumerWidget {
  const _TargetPicker({
    required this.kind,
    required this.locationId,
    required this.selected,
    required this.onSelected,
  });

  final PinKind kind;
  final String locationId;
  final String? selected;
  final void Function(String id, String name) onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final options = switch (kind) {
      PinKind.location =>
        ref
            .watch(childLocationsProvider(locationId))
            .value
            ?.map((l) => (id: l.id, name: l.name))
            .toList(),
      PinKind.npc =>
        ref
            .watch(npcsProvider)
            .value
            ?.map((n) => (id: n.id, name: n.name))
            .toList(),
      PinKind.shop =>
        ref
            .watch(shopsProvider)
            .value
            ?.map((s) => (id: s.id, name: s.name))
            .toList(),
      PinKind.encounter =>
        ref
            .watch(encountersProvider)
            .value
            ?.map((e) => (id: e.id, name: e.name))
            .toList(),
      _ => const <({String id, String name})>[],
    };

    if (options == null) return const LinearProgressIndicator();

    if (options.isEmpty) {
      return Card(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(switch (kind) {
            PinKind.location => l10n.worldTargetNoLocations,
            PinKind.npc => l10n.worldTargetNoNpcs,
            PinKind.shop => l10n.worldTargetNoShops,
            PinKind.encounter => l10n.worldTargetNoEncounters,
            _ => '',
          }, style: theme.textTheme.bodySmall),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.worldTargetLink, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              ChoiceChip(
                label: Text(option.name),
                selected: selected == option.id,
                onSelected: (_) => onSelected(option.id, option.name),
              ),
          ],
        ),
      ],
    );
  }
}
