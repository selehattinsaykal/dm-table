/// Karakter kagidinin BUYU yuzeyi: bilinen/hazir buyuler, buyu kullanma,
/// konsantrasyon ve buyu secme dialogu.
///
/// `character_sheet_page.dart`in bir parcasi; bkz. `character_sheet_vitals`.
part of 'character_sheet_page.dart';

class _KnownSpellsCard extends ConsumerWidget {
  const _KnownSpellsCard({required this.characterId});

  final String characterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final slots = ref.watch(spellSlotsProvider(characterId)).value ?? const {};
    final pact = ref.watch(pactMagicProvider(characterId)).value;
    // Buyu yuvasi yoksa (buyu yapmayan sinif) karti hic gosterme.
    if (slots.isEmpty && pact == null) return const SizedBox.shrink();

    final spells =
        ref.watch(knownSpellsProvider(characterId)).value ?? const [];
    final repo = ref.read(characterRepositoryProvider);
    final l10n = L10n.of(context);

    Future<void> addSpell() async {
      final classKeys = (await repo.classLevels(
        characterId,
      )).map((l) => l.classKey).toList();
      if (!context.mounted) return;
      final spell = await showDialog<Spell>(
        context: context,
        builder: (context) => _SpellPickerDialog(classKeys: classKeys),
      );
      if (spell == null) return;
      await repo.addKnownSpell(characterId, spell.key);
      ref.invalidate(knownSpellsProvider(characterId));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.sheetSpells,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: addSpell,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l10n.sheetAddSpell),
                ),
              ],
            ),
            // Oyuncunun kendi secimi icin gecerli olan sinirlar DM'e de
            // gorunsun: "6 hazir buyunun 4'u secili" bilgisi masada lazim.
            for (final p
                in ref.watch(spellPreparationsProvider(characterId)).value ??
                    const <SpellPreparation>[])
              if (p.canChoose)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${p.className}: '
                    '${l10n.sheetPreparedCount(p.prepared.length, p.preparedLimit)}'
                    '${p.cantripLimit > 0 ? ' · ${l10n.sheetCantripCount(p.cantrips.length, p.cantripLimit)}' : ''}'
                    ' · ${l10n.sheetSpellChangesLeft(p.changesAvailable)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
            if (spells.isEmpty)
              Text(l10n.sheetNoSpellsAdded, style: theme.textTheme.bodySmall)
            else
              for (final s in spells)
                Row(
                  children: [
                    SizedBox(
                      width: 26,
                      child: Text(
                        s.level == 0 ? l10n.spellCantripAbbr : '${s.level}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        s.name,
                        style: TextStyle(
                          fontWeight: s.prepared || s.alwaysPrepared
                              ? FontWeight.bold
                              : null,
                        ),
                      ),
                    ),
                    if (s.alwaysPrepared)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          l10n.sheetAlways,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      )
                    else
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: s.prepared
                            ? l10n.sheetPrepared
                            : l10n.sheetPrepare,
                        icon: Icon(
                          s.prepared
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          size: 18,
                          color: s.prepared ? theme.colorScheme.primary : null,
                        ),
                        onPressed: () async {
                          await repo.togglePrepared(
                            characterId,
                            s.spellKey,
                            !s.prepared,
                          );
                          ref.invalidate(knownSpellsProvider(characterId));
                        },
                      ),
                    // Kullan: yuvayi harcar, saldiri/hasar zarini atar ve
                    // sonucu masaya dusurur. Buyu verisindeki saldiri/kurtarma
                    // /hasar alanlari bugune kadar hic kullanilmiyordu.
                    if (s.prepared || s.alwaysPrepared || s.level == 0)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: l10n.sheetCastSpell,
                        icon: const Icon(Icons.auto_awesome, size: 18),
                        onPressed: () =>
                            _castSpell(context, ref, characterId, s),
                      ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: l10n.delete,
                      icon: const Icon(Icons.remove_circle_outline, size: 18),
                      onPressed: () async {
                        await repo.removeSpell(characterId, s.spellKey);
                        ref.invalidate(knownSpellsProvider(characterId));
                      },
                    ),
                  ],
                ),
          ],
        ),
      ),
    );
  }
}

/// Buyuyu kullanir: yuva seviyesini sorar, yuvayi harcar, zarlari atar.
Future<void> _castSpell(
  BuildContext context,
  WidgetRef ref,
  String characterId,
  KnownSpell spell,
) async {
  final l10n = L10n.of(context);
  final repo = ref.read(characterRepositoryProvider);

  var slotLevel = spell.level;
  if (spell.level > 0) {
    // Ust seviye yuvayla kullanma secenegi: yalnizca ACIK yuvalar listelenir.
    final slots = await ref.read(spellSlotsProvider(characterId).future);
    final options = slots.keys.where((level) => level >= spell.level).toList()
      ..sort();
    if (!context.mounted) return;
    if (options.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.sheetNoSlotLeft)));
      return;
    }
    if (options.length > 1) {
      final picked = await showDialog<int>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(l10n.sheetCastAtLevel),
          children: [
            for (final level in options)
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(level),
                child: Text(l10n.sheetOrdinalLevel(level)),
              ),
          ],
        ),
      );
      if (picked == null) return;
      slotLevel = picked;
    } else {
      slotLevel = options.first;
    }
  }

  final plan = await repo.castSpell(
    characterId: characterId,
    spellKey: spell.spellKey,
    slotLevel: slotLevel,
  );
  if (!context.mounted) return;
  if (plan == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.sheetNoSlotLeft)));
    return;
  }

  ref.invalidate(characterProvider(characterId));
  showSpellCastResult(context, plan);
}

/// Karakter kagidini A4 PDF olarak kaydeder.
///
/// `pdf` paketi SAF DART: yerel bir yazici eklentisi yok, cikti bayt dizisi
/// olarak uretilip kullanicinin sectigi dosyaya yaziliyor. Yazdirmayi
/// isletim sisteminin kendi PDF goruntuleyicisi yapiyor.
void showSpellCastResult(BuildContext context, SpellCastPlan plan) {
  final l10n = L10n.of(context);
  final roller = DiceRoller();
  final lines = <String>[];

  if (plan.hasAttack) {
    final roll = roller.d20(label: plan.spellName, modifier: plan.attackBonus!);
    lines.add(
      '${l10n.sheetSpellAttack}: ${roll.total} (${roll.results.first}'
      '${plan.attackBonus! >= 0 ? '+' : ''}${plan.attackBonus})',
    );
  }
  if (plan.hasSave) {
    lines.add(
      '${l10n.abilityName(plan.saveAbility!)} ${l10n.sheetSaveDc} ${plan.saveDc}',
    );
  }
  if (plan.hasDamage) {
    final dice = parseDamageDice(plan.damageDice!);
    if (dice != null) {
      final roll = roller.roll(
        sides: dice.sides,
        count: dice.count,
        modifier: dice.modifier,
        label: plan.spellName,
      );
      lines.add(
        '${l10n.sheetSpellDamage}: ${roll.total} '
        '(${plan.damageDice}${plan.damageType == null ? '' : ' ${plan.damageType}'})',
      );
    }
  }
  if (plan.concentration) lines.add(l10n.sheetConcentrationNote);
  // Alan buyusuyse olcu de yaziliyor: masada "on beş fitlik koni" cumlesi
  // buyunun metninden cikariliyor (bkz. `spellAreaFrom`).
  final area = plan.area;
  if (area != null) {
    lines.add('${area.kind.name} ${area.size.toStringAsFixed(0)} ft');
  }

  if (lines.isEmpty) lines.add(l10n.sheetSpellCastNoRoll);

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        '${plan.spellName}'
        '${plan.slotLevel > 0 ? ' (${l10n.sheetOrdinalLevel(plan.slotLevel)})' : ''}'
        '\n${lines.join('  ·  ')}',
      ),
      duration: const Duration(seconds: 6),
    ),
  );
}

/// Sinif secenegi secme paneli: tipe gore grupli, ayrintili liste.
class _ConcentrationCard extends ConsumerWidget {
  const _ConcentrationCard({required this.character});

  final Character character;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spell = character.concentrationSpell;
    if (spell == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            const Icon(Icons.blur_on, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.sheetConcentratingOn(spell),
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    l10n.sheetConcentrationHint,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => ref
                  .read(characterRepositoryProvider)
                  .setConcentration(character.id, null),
              child: Text(l10n.sheetConcentrationEnd),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kutuphaneden buyu secme dialogu; secilen [Spell]'i doner. Varsayilan olarak
/// karakterin siniflarina uygun buyulere filtreler.
class _SpellPickerDialog extends ConsumerStatefulWidget {
  const _SpellPickerDialog({required this.classKeys});

  /// Karakterin sinif anahtarlari; filtre bunlara gore.
  final List<String> classKeys;

  @override
  ConsumerState<_SpellPickerDialog> createState() => _SpellPickerDialogState();
}

class _SpellPickerDialogState extends ConsumerState<_SpellPickerDialog> {
  final _search = TextEditingController();
  late bool _onlyClass = widget.classKeys.isNotEmpty;

  /// Anahtarin son parcasi ('srd-2024_wizard' -> 'wizard'); farkli onekleri
  /// eslestirmek icin.
  static String _tail(String key) =>
      key.contains('_') ? key.substring(key.lastIndexOf('_') + 1) : key;

  bool _matchesClass(Spell s) {
    final want = widget.classKeys.map(_tail).toSet();
    final has = s.classesCsv
        .split(',')
        .where((e) => e.isNotEmpty)
        .map(_tail)
        .toSet();
    return want.intersection(has).isNotEmpty;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(spellQueryProvider);
    final results = ref.watch(spellResultsProvider);
    final l10n = L10n.of(context);
    final glossary = glossaryTrOf(context, ref);

    return AlertDialog(
      title: Text(l10n.sheetAddSpell),
      content: SizedBox(
        width: 460,
        height: 520,
        child: Column(
          children: [
            TextField(
              controller: _search,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.sheetSearchSpell,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => ref
                  .read(spellQueryProvider.notifier)
                  .set(query.copyWith(text: v)),
            ),
            if (widget.classKeys.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: FilterChip(
                    label: Text(l10n.sheetOnlyClassSpells),
                    selected: _onlyClass,
                    onSelected: (v) => setState(() => _onlyClass = v),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: asyncView(
                context,
                results,
                loading: const AppLoading(),
                data: (all) {
                  final rows = _onlyClass && widget.classKeys.isNotEmpty
                      ? all.where(_matchesClass).toList()
                      : all;
                  return rows.isEmpty
                      ? Center(child: Text(l10n.noResults))
                      : ListView.builder(
                          itemCount: rows.length,
                          itemBuilder: (context, i) {
                            final s = rows[i];
                            return ListTile(
                              dense: true,
                              title: Text(s.name),
                              subtitle: Text(
                                [
                                  s.level == 0
                                      ? l10n.spellCantrip
                                      : l10n.spellLevelN(s.level),
                                  if (s.school != null)
                                    glossary.term('schools', s.school!),
                                  if (s.concentration)
                                    l10n.spellConcentrationShort,
                                  if (s.ritual) l10n.filterRitual,
                                ].join(' · '),
                              ),
                              onTap: () => Navigator.pop(context, s),
                            );
                          },
                        );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}

/// Hikaye ve kisilik alanlari (2024 kagidi): serbest metin, DM duzenler.
