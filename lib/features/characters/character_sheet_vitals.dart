/// Karakter kagidinin CAN VE ATIS yuzeyi: can puani, deneyim, olum
/// kurtarmasi, temel degerler, yetenek/kurtarma/beceri satirlari.
///
/// `character_sheet_page.dart`in bir parcasi (`part`), ayri bir kutuphane
/// DEGIL: kartlarin hepsi ozel (`_HitPointsCard` gibi) ve ayni sayfanin
/// mahrem parcalari. Ayri kutuphaneye tasimak hepsini disari acmak
/// demekti; dosya 3100 satiri gecince yalnizca FIZIKSEL olarak bolundu.
part of 'character_sheet_page.dart';

// --- Can puani ------------------------------------------------------------

class _HitPointsCard extends ConsumerStatefulWidget {
  const _HitPointsCard({required this.character});

  final Character character;

  @override
  ConsumerState<_HitPointsCard> createState() => _HitPointsCardState();
}

class _HitPointsCardState extends ConsumerState<_HitPointsCard> {
  int _amount = 1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final c = widget.character;
    final repo = ref.read(characterRepositoryProvider);
    final ratio = c.hitPointsMax == 0
        ? 0.0
        : c.hitPointsCurrent / c.hitPointsMax;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${c.hitPointsCurrent}',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: c.hitPointsCurrent == 0
                        ? theme.colorScheme.error
                        : null,
                  ),
                ),
                Text(
                  ' / ${c.hitPointsMax}',
                  style: theme.textTheme.titleMedium,
                ),
                if (c.temporaryHitPoints > 0) ...[
                  const SizedBox(width: 12),
                  Chip(
                    label: Text(l10n.sheetTempHp(c.temporaryHitPoints)),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
                const Spacer(),
                Text(l10n.sheetHpLabel, style: theme.textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 6,
              color: ratio <= 0.25
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => repo.applyDamage(c.id, _amount),
                    icon: const Icon(Icons.remove),
                    label: Text(l10n.sheetDamage),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 92,
                  child: TextFormField(
                    initialValue: '$_amount',
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(isDense: true),
                    onChanged: (v) => _amount = int.tryParse(v) ?? 0,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => repo.applyHealing(c.id, _amount),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.sheetHeal),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => repo.setTemporaryHitPoints(c.id, _amount),
                icon: const Icon(Icons.shield_outlined, size: 18),
                label: Text(l10n.sheetGrantTempHp),
              ),
            ),
            if (c.hitPointsCurrent == 0) ...[
              const Divider(height: 24),
              _DeathSaves(character: c),
            ],
          ],
        ),
      ),
    );
  }
}

/// Deneyim puani (XP) izleme. Seviye atlama elle yapildigi icin bu kart
/// yalnizca toplam XP'yi ve sonraki seviye esigine ilerlemeyi gosterir.
class _ExperienceCard extends StatelessWidget {
  const _ExperienceCard({required this.character});

  final Character character;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final xp = character.experiencePoints;
    final level = Experience.levelForXp(xp);
    final next = Experience.xpToNext(xp);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.military_tech_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(l10n.sheetExperience, style: theme.textTheme.titleMedium),
                const Spacer(),
                Text('$xp XP', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: Experience.progress(xp),
              minHeight: 6,
            ),
            const SizedBox(height: 6),
            Text(
              next == null
                  ? l10n.sheetXpMaxLevel(level)
                  : l10n.sheetXpToNext(next.nextLevel, next.xpNeeded),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeathSaves extends ConsumerWidget {
  const _DeathSaves({required this.character});

  final Character character;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(characterRepositoryProvider);
    final theme = Theme.of(context);
    final l10n = L10n.of(context);

    Widget row(String label, int value, Color color, ValueChanged<int> onSet) =>
        Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(label, style: theme.textTheme.bodySmall),
            ),
            for (var i = 1; i <= 3; i++)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  i <= value ? Icons.circle : Icons.circle_outlined,
                  size: 20,
                  color: i <= value ? color : theme.colorScheme.outline,
                ),
                // Dolu son daireye basmak geri alir.
                onPressed: () => onSet(i == value ? i - 1 : i),
              ),
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.sheetDeathSaves, style: theme.textTheme.titleSmall),
        row(
          l10n.sheetSuccess,
          character.deathSaveSuccesses,
          theme.colorScheme.primary,
          (v) => repo.setDeathSaves(character.id, successes: v),
        ),
        row(
          l10n.sheetFailure,
          character.deathSaveFailures,
          theme.colorScheme.error,
          (v) => repo.setDeathSaves(character.id, failures: v),
        ),
      ],
    );
  }
}

// --- Temel degerler -------------------------------------------------------

class _CoreStatsCard extends StatelessWidget {
  const _CoreStatsCard({required this.character, required this.stats});

  final Character character;
  final CharacterBuild stats;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final entries = <(String, String)>[
      ('AC', '${character.armorClassOverride ?? stats.armorClass}'),
      (l10n.sheetInitiative, formatSigned(stats.initiative)),
      (l10n.sheetSpeed, '${character.speedOverride ?? stats.baseSpeed} ft'),
      (l10n.sheetProficiency, formatSigned(stats.proficiencyBonus)),
      (l10n.sheetPassivePerception, '${stats.passivePerception}'),
      (l10n.sheetCarry, '${stats.carryCapacity} lb'),
    ];

    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Wrap(
              alignment: WrapAlignment.spaceEvenly,
              runSpacing: 12,
              children: [
                for (final (label, value) in entries)
                  SizedBox(
                    width: 104,
                    child: _Stat(label: label, value: value),
                  ),
              ],
            ),
            // Yeterliligin olmayan zirh/kalkan: dezavantaj sayisal bir deger
            // olmadigi icin hesaba girmiyor, masaya HATIRLATILIYOR.
            if (stats.hasArmorPenalty)
              Padding(
                padding: const EdgeInsets.only(top: 12, left: 8, right: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_outlined,
                      size: 18,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        stats.untrainedArmor
                            ? l10n.sheetArmorPenalty
                            : l10n.sheetShieldPenalty,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value, style: theme.textTheme.titleLarge),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

// --- Yetenekler -----------------------------------------------------------

class _AbilitiesCard extends ConsumerWidget {
  const _AbilitiesCard({required this.stats});

  final CharacterBuild stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            for (final a in Ability.values)
              Expanded(
                // Stat'a dokununca yetenek kontrolu (d20 + modifier) atilir.
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => rollAndShow(
                    context,
                    ref,
                    label: l10n.sheetAbilityCheck(l10n.abilityName(a)),
                    modifier: stats.abilityModifier(a),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        Text(
                          l10n.abilityShort(a),
                          style: theme.textTheme.labelSmall,
                        ),
                        Text(
                          formatSigned(stats.abilityModifier(a)),
                          style: theme.textTheme.titleLarge,
                        ),
                        Text(
                          '${stats.abilities[a]}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --- Kurtarma atislari ----------------------------------------------------

class _SavesCard extends ConsumerWidget {
  const _SavesCard({required this.characterId, required this.stats});

  final String characterId;
  final CharacterBuild stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    return _ListCard(
      title: l10n.sheetSavingThrows,
      children: [
        for (final a in Ability.values)
          _ProficiencyRow(
            proficient: stats.saveProficiencies.contains(a),
            label: l10n.abilityName(a),
            value: stats.savingThrow(a),
            rollLabel: l10n.sheetAbilitySave(l10n.abilityName(a)),
            // Kurtarmada uzmanlik yok: isaretli/isaretsiz arasinda gider.
            onToggle: () => ref
                .read(characterRepositoryProvider)
                .setProficiency(
                  characterId,
                  kind: ProficiencyKind.save,
                  value: a.name,
                  proficient: !stats.saveProficiencies.contains(a),
                ),
          ),
      ],
    );
  }
}

// --- Beceriler ------------------------------------------------------------

class _SkillsCard extends ConsumerWidget {
  const _SkillsCard({required this.characterId, required this.stats});

  final String characterId;
  final CharacterBuild stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    return _ListCard(
      title: l10n.sheetSkills,
      children: [
        for (final s in Skill.values)
          _ProficiencyRow(
            proficient: stats.skillProficiencies.contains(s),
            expertise: stats.skillExpertise.contains(s),
            label: l10n.skillName(s),
            trailing: l10n.abilityShort(s.ability),
            value: stats.skillModifier(s),
            rollLabel: l10n.skillName(s),
            // Yok -> yeterli -> uzmanlik -> yok.
            onToggle: () {
              final proficient = stats.skillProficiencies.contains(s);
              final expertise = stats.skillExpertise.contains(s);
              return ref
                  .read(characterRepositoryProvider)
                  .setProficiency(
                    characterId,
                    kind: ProficiencyKind.skill,
                    value: s.name,
                    proficient: !proficient || !expertise,
                    expertise: proficient && !expertise,
                  );
            },
          ),
      ],
    );
  }
}

class _ProficiencyRow extends ConsumerWidget {
  const _ProficiencyRow({
    required this.proficient,
    required this.label,
    required this.value,
    required this.rollLabel,
    this.expertise = false,
    this.trailing,
    this.onToggle,
  });

  final bool proficient;
  final bool expertise;
  final String label;
  final int value;

  /// Zar gunlugunde/bildiriminde gorunecek ad ("Gizlilik", "DEX kurtarma").
  final String rollLabel;
  final String? trailing;

  /// Bastaki isaretin dokunuslu hali: yeterliligi elle degistirir. Satirin
  /// kendisi zar atmaya ayrildigi icin bu yalnizca isarete bagli.
  final Future<void> Function()? onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Satira dokununca d20 + bu deger atilir; masada en cok istenen kisayol.
    return InkWell(
      onTap: () => rollAndShow(context, ref, label: rollLabel, modifier: value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Tooltip(
              message: L10n.of(context).sheetProficiencyToggle,
              child: InkWell(
                onTap: onToggle == null ? null : () => onToggle!(),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    expertise
                        ? Icons.star
                        : (proficient ? Icons.circle : Icons.circle_outlined),
                    size: 14,
                    color: proficient
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
            if (trailing != null)
              Text(
                trailing!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            const SizedBox(width: 10),
            SizedBox(
              width: 36,
              child: Text(
                formatSigned(value),
                textAlign: TextAlign.end,
                style: theme.textTheme.titleSmall,
              ),
            ),
            const Icon(Icons.casino_outlined, size: 16),
          ],
        ),
      ),
    );
  }
}

/// d20 + [modifier] atar, sonucu bildirimle gosterir ve zar gunlugune yazar.
/// Avantaj/dezavantaj icin basili tutmak yerine sadelik adina duz atis.
void rollAndShow(
  BuildContext context,
  WidgetRef ref, {
  required String label,
  required int modifier,
}) {
  final roll = DiceRoller().d20(label: label, modifier: modifier);
  ref.read(rollLogProvider.notifier).add(roll);
  showRollResult(context, roll);
}
