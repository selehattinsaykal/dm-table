import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import '../world/world_providers.dart';

/// Magazayi isleten kisi: ya var olan bir NPC kaydi ya da serbest metin.
typedef ShopOwner = ({String? npcId, String? name});

const ShopOwner noShopOwner = (npcId: null, name: null);

/// "Isleten" alani — NPC listesinden secim + serbest ad.
///
/// NPC secilince ad alani o NPC'nin adiyla doldurulup KILITLENIR: ad, oyuncuya
/// giden veride ve listelerde tek kaynak olarak kullaniliyor, elle degistirilip
/// bagli NPC'den ayrisirsa hangisinin dogru oldugu belirsizlesir. "Yok"
/// secilince alan yeniden serbest metin olur.
class ShopOwnerField extends ConsumerStatefulWidget {
  const ShopOwnerField({
    super.key,
    this.initial = noShopOwner,
    required this.onChanged,
  });

  final ShopOwner initial;
  final ValueChanged<ShopOwner> onChanged;

  @override
  ConsumerState<ShopOwnerField> createState() => _ShopOwnerFieldState();
}

class _ShopOwnerFieldState extends ConsumerState<ShopOwnerField> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initial.name ?? '',
  );
  late String? _npcId = widget.initial.npcId;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _emit() => widget.onChanged((
    npcId: _npcId,
    name: _name.text.trim().isEmpty ? null : _name.text.trim(),
  ));

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final npcs = ref.watch(npcsProvider).value ?? const <Npc>[];
    // Bagli NPC silinmis olabilir; dropdown listede olmayan bir degerle
    // assert'e dusuyor, bu yuzden once dogrula.
    final safeId = npcs.any((n) => n.id == _npcId) ? _npcId : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String?>(
          initialValue: safeId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: l10n.shopsOwnerNpc,
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(value: null, child: Text(l10n.shopsOwnerNpcNone)),
            for (final npc in npcs)
              DropdownMenuItem(
                value: npc.id,
                child: Text(npc.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (id) {
            setState(() {
              _npcId = id;
              if (id != null) {
                _name.text = npcs.firstWhere((n) => n.id == id).name;
              }
            });
            _emit();
          },
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _name,
          enabled: _npcId == null,
          decoration: InputDecoration(
            labelText: l10n.shopsOwner,
            helperText: _npcId == null ? l10n.shopsOwnerHint : null,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => _emit(),
        ),
      ],
    );
  }
}
