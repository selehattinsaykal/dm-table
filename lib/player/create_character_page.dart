import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../app/theme.dart';
import '../domain/models/ability.dart';
import '../domain/rules/point_buy.dart';
import 'player_client.dart';
import 'player_strings.dart';

/// Oyuncunun kendi karakterini kurduğu sihirbaz (tarayıcı tarafı).
///
/// Kurallar burada ÇÖZÜLMEZ: sınıf/tür/geçmiş kataloğu DM cihazından
/// `creationOptions` ile gelir, seçimler `createCharacter` ile geri gider ve
/// **sunucuda yeniden doğrulanır**. Panel yalnızca seçim arayüzüdür — hit die,
/// kurtarma atışı gibi değerleri hiç göndermez.
class CreateCharacterPage extends ConsumerStatefulWidget {
  const CreateCharacterPage({super.key});

  @override
  ConsumerState<CreateCharacterPage> createState() =>
      _CreateCharacterPageState();
}

class _CreateCharacterPageState extends ConsumerState<CreateCharacterPage> {
  final _name = TextEditingController();

  String? _classKey;
  String? _speciesKey;
  String? _backgroundKey;
  AbilityMethod _method = AbilityMethod.pointBuy;

  /// Köken bonusları EKLENMEDEN önceki puanlar.
  var _base = const AbilityScores(
    strength: 8,
    dexterity: 8,
    constitution: 8,
    intelligence: 8,
    wisdom: 8,
    charisma: 8,
  );

  /// Geçmişin verdiği 3 puanın dağılımı.
  final _origin = <Ability, int>{};
  AbilitySpreadChoice _spread = AbilitySpreadChoice.twoOne;

  final _skills = <String>{};
  String? _equipment;

  Uint8List? _portrait;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Katalog daha once gelmediyse iste.
    if (ref.read(playerControllerProvider).creationOptions == null) {
      ref.read(playerControllerProvider.notifier).requestCreationOptions();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  AbilityScores get _finalScores => _base.plus(_origin);

  Map<String, dynamic>? get _selectedClass {
    final list = _options?['classes'] as List? ?? const [];
    for (final c in list) {
      if ((c as Map)['key'] == _classKey) return c.cast<String, dynamic>();
    }
    return null;
  }

  Map<String, dynamic>? get _selectedBackground {
    final list = _options?['backgrounds'] as List? ?? const [];
    for (final b in list) {
      if ((b as Map)['key'] == _backgroundKey) return b.cast<String, dynamic>();
    }
    return null;
  }

  Map<String, dynamic>? _options;

  @override
  Widget build(BuildContext context) {
    final l = PlayerL10n.of(context);
    final space = context.spacing;
    _options = ref.watch(
      playerControllerProvider.select((s) => s.creationOptions),
    );

    if (_options == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l.createCharacter)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final classes = (_options!['classes'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final species = (_options!['species'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final backgrounds = (_options!['backgrounds'] as List? ?? const [])
        .cast<Map<String, dynamic>>();

    return Scaffold(
      appBar: AppBar(title: Text(l.createCharacter)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: EdgeInsets.all(space.md),
            children: [
              _portraitRow(l),
              SizedBox(height: space.md),
              TextField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: l.characterName,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              SizedBox(height: space.md),
              _dropdown(
                label: l.species,
                value: _speciesKey,
                entries: species,
                onChanged: (v) => setState(() => _speciesKey = v),
              ),
              SizedBox(height: space.sm),
              _dropdown(
                label: l.background,
                value: _backgroundKey,
                entries: backgrounds,
                onChanged: (v) => setState(() {
                  _backgroundKey = v;
                  _origin.clear();
                }),
              ),
              if (_selectedBackground != null) _originSection(l),
              SizedBox(height: space.sm),
              _dropdown(
                label: l.characterClass,
                value: _classKey,
                entries: classes,
                onChanged: (v) => setState(() {
                  _classKey = v;
                  _skills.clear();
                  _equipment = null;
                }),
              ),
              SizedBox(height: space.md),
              _abilitySection(l),
              if (_selectedClass != null) ...[
                SizedBox(height: space.md),
                _skillSection(l),
                SizedBox(height: space.md),
                _equipmentSection(l),
              ],
              SizedBox(height: space.lg),
              FilledButton.icon(
                onPressed: _canSubmit && !_sending ? _submit : null,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(l.createCharacter),
              ),
              SizedBox(height: space.md),
            ],
          ),
        ),
      ),
    );
  }

  bool get _canSubmit {
    if (_name.text.trim().isEmpty || _classKey == null) return false;
    final core = _selectedClass;
    if (core == null) return false;
    final need = core['skillChoiceCount'] as int? ?? 0;
    if (_skills.length != need) return false;
    if (_method == AbilityMethod.pointBuy && PointBuy.remaining(_base) != 0) {
      return false;
    }
    if (_selectedBackground != null && _originPointsUsed != 3) return false;
    return true;
  }

  int get _originPointsUsed => _origin.values.fold(0, (a, b) => a + b);

  Widget _portraitRow(PlayerL10n l) => Row(
    children: [
      CircleAvatar(
        radius: 36,
        backgroundImage: _portrait == null ? null : MemoryImage(_portrait!),
        child: _portrait == null ? const Icon(Icons.person, size: 32) : null,
      ),
      SizedBox(width: context.spacing.md),
      Expanded(
        child: Wrap(
          spacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: _pickPortrait,
              icon: const Icon(Icons.add_a_photo_outlined, size: 18),
              label: Text(_portrait == null ? l.addPortrait : l.changePortrait),
            ),
            if (_portrait != null)
              TextButton(
                onPressed: () => setState(() => _portrait = null),
                child: Text(l.removePortrait),
              ),
          ],
        ),
      ),
    ],
  );

  Future<void> _pickPortrait() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();

    // Telefon fotografi 5 MB olabiliyor; websocket'ten base64 olarak gecmeden
    // ONCE kucultuluyor. Cozulemezse ham baytlar gonderilir (DM tarafi zaten
    // yeniden kodluyor).
    final decoded = img.decodeImage(bytes);
    final out = decoded == null
        ? bytes
        : Uint8List.fromList(
            img.encodeJpg(img.copyResize(decoded, width: 512), quality: 85),
          );
    if (mounted) setState(() => _portrait = out);
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required List<Map<String, dynamic>> entries,
    required ValueChanged<String?> onChanged,
  }) => DropdownButtonFormField<String?>(
    initialValue: entries.any((e) => e['key'] == value) ? value : null,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    items: [
      for (final e in entries)
        DropdownMenuItem(
          value: e['key'] as String,
          child: Text('${e['name']}', overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: onChanged,
  );

  /// Geçmişin verdiği 3 puanın dağıtımı (2024 kuralı: +2/+1 ya da +1/+1/+1).
  Widget _originSection(PlayerL10n l) {
    final options =
        (_selectedBackground!['abilityOptions'] as List? ?? const [])
            .map((a) => Ability.values.firstWhere((x) => x.name == a))
            .toList();
    if (options.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: context.spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.originBonus, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          SegmentedButton<AbilitySpreadChoice>(
            segments: [
              ButtonSegment(
                value: AbilitySpreadChoice.twoOne,
                label: Text(l.spreadTwoOne),
              ),
              ButtonSegment(
                value: AbilitySpreadChoice.oneOneOne,
                label: Text(l.spreadOneOneOne),
              ),
            ],
            selected: {_spread},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() {
              _spread = s.first;
              _origin.clear();
              if (_spread == AbilitySpreadChoice.oneOneOne) {
                for (final a in options) {
                  _origin[a] = 1;
                }
              }
            }),
          ),
          if (_spread == AbilitySpreadChoice.twoOne) ...[
            const SizedBox(height: 8),
            for (final a in options)
              Row(
                children: [
                  Expanded(child: Text(a.name)),
                  for (final amount in [0, 1, 2])
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: ChoiceChip(
                        label: Text(amount == 0 ? '—' : '+$amount'),
                        selected: (_origin[a] ?? 0) == amount,
                        onSelected: (_) => setState(() {
                          if (amount == 0) {
                            _origin.remove(a);
                          } else {
                            // +2 tek bir yetenege verilebilir.
                            if (amount == 2) {
                              _origin.removeWhere((_, v) => v == 2);
                            }
                            _origin[a] = amount;
                          }
                        }),
                      ),
                    ),
                ],
              ),
          ],
          Text(
            l.originRemaining(3 - _originPointsUsed),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _abilitySection(PlayerL10n l) {
    final scores = _finalScores;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.abilityScores, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            for (final m in AbilityMethod.values)
              ChoiceChip(
                label: Text(_methodLabel(l, m)),
                selected: _method == m,
                onSelected: (_) => setState(() {
                  _method = m;
                  if (m == AbilityMethod.standardArray) {
                    _base = const AbilityScores(
                      strength: 15,
                      dexterity: 14,
                      constitution: 13,
                      intelligence: 12,
                      wisdom: 10,
                      charisma: 8,
                    );
                  }
                }),
              ),
          ],
        ),
        if (_method == AbilityMethod.pointBuy)
          Text(
            l.pointsLeft(PointBuy.remaining(_base)),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        const SizedBox(height: 8),
        for (final a in Ability.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(width: 110, child: Text(a.name)),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  onPressed: () => _bump(a, -1),
                ),
                SizedBox(
                  width: 34,
                  child: Text('${_base[a]}', textAlign: TextAlign.center),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  onPressed: () => _bump(a, 1),
                ),
                const Spacer(),
                Text(
                  '${scores[a]} (${_mod(scores[a])})',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Kural asagi yuvarlama; `~/` sifira dogru kirptigi icin `floor` sart.
  String _mod(int score) {
    final v = ((score - 10) / 2).floor();
    return v >= 0 ? '+$v' : '$v';
  }

  void _bump(Ability a, int delta) {
    final current = _base[a];
    var next = current + delta;
    if (_method == AbilityMethod.pointBuy) {
      next = next.clamp(PointBuy.min, PointBuy.max);
      if (delta > 0) {
        final cost = PointBuy.costToRaise(current);
        if (cost == null || PointBuy.remaining(_base) < cost) return;
      }
    } else {
      next = next.clamp(1, 20);
    }
    setState(() => _base = _base.plus({a: next - current}));
  }

  Widget _skillSection(PlayerL10n l) {
    final core = _selectedClass!;
    final need = core['skillChoiceCount'] as int? ?? 0;
    if (need == 0) return const SizedBox.shrink();
    final any = core['anySkill'] as bool? ?? false;
    final options = any
        ? [for (final s in Skill.values) s.name]
        : (core['skillOptions'] as List? ?? const []).cast<String>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.chooseSkills(need),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in options)
              FilterChip(
                label: Text(s),
                selected: _skills.contains(s),
                onSelected: (on) => setState(() {
                  if (on) {
                    if (_skills.length >= need) return;
                    _skills.add(s);
                  } else {
                    _skills.remove(s);
                  }
                }),
              ),
          ],
        ),
      ],
    );
  }

  Widget _equipmentSection(PlayerL10n l) {
    final options = [
      ...(_selectedClass!['equipment'] as List? ?? const []),
      ...(_selectedBackground?['equipment'] as List? ?? const []),
    ].cast<Map<String, dynamic>>();
    if (options.isEmpty) return const SizedBox.shrink();

    // Ayni etiket (A/B) sinif ve gecmis icin ortak; tekillestir.
    final labels = {for (final o in options) '${o['label']}'}.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.startingGear, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        // RadioGroup: RadioListTile'in kendi groupValue/onChanged'i bu Flutter
        // surumunde kullanimdan kalkti.
        RadioGroup<String>(
          groupValue: _equipment,
          onChanged: (v) => setState(() => _equipment = v),
          child: Column(
            children: [
              for (final label in labels)
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: label,
                  title: Text(label),
                  subtitle: Text(
                    [
                      for (final o in options.where(
                        (o) => o['label'] == label,
                      )) ...[
                        for (final e in (o['items'] as List? ?? const []))
                          '${(e as Map)['name']}'
                              '${(e['quantity'] as int? ?? 1) > 1 ? ' ×${e['quantity']}' : ''}',
                        if ((o['gold'] as int? ?? 0) > 0) '${o['gold']} gp',
                      ],
                    ].join(', '),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _methodLabel(PlayerL10n l, AbilityMethod m) => switch (m) {
    AbilityMethod.pointBuy => l.methodPointBuy,
    AbilityMethod.standardArray => l.methodStandardArray,
    AbilityMethod.manual => l.methodManual,
  };

  void _submit() {
    setState(() => _sending = true);
    final scores = _finalScores;
    ref.read(playerControllerProvider.notifier).createCharacter({
      'name': _name.text.trim(),
      'playerName': ref.read(playerControllerProvider).playerName,
      'classKey': _classKey,
      'speciesKey': _speciesKey,
      'backgroundKey': _backgroundKey,
      'scores': {for (final a in Ability.values) a.name: scores[a]},
      'skills': _skills.toList(),
      if (_equipment != null) 'equipmentChoice': _equipment,
      if (_portrait != null) 'portrait': base64Encode(_portrait!),
    });
    Navigator.of(context).pop();
  }
}

/// Geçmiş bonusunun dağıtım biçimi (2024 kuralı).
enum AbilitySpreadChoice { twoOne, oneOneOne }
