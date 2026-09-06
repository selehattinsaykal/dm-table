import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../data/db/character_tables.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../domain/models/ability.dart';
import '../../domain/rules/character_math.dart';
import '../../domain/rules/damage_types.dart';
import '../../l10n/app_localizations.dart';
import 'character_providers.dart';

/// Partinin tamaminin bir bakista okunan degerleri.
///
/// **Neden var:** DM'in masada en sik sordugu seyler ("pasif algin kac?",
/// "kurtarma bonusun ne?", "elf dili biliyor musun?") tek tek karakter
/// kagidi acmayi gerektiriyordu. Bu ekran o sorularin hepsini tek yerde
/// cevapliyor.
///
/// SALT OKUNUR: hicbir sey duzenlenmiyor. Duzenleme karakter kagidinda; iki
/// yerde duzenleme iki farkli dogru demekti.
class PartyBoardPage extends ConsumerWidget {
  const PartyBoardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final characters = ref.watch(charactersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.partyBoard)),
      body: switch (characters) {
        AsyncData(:final value) when value.isEmpty => Center(
          child: Text(l10n.partyBoardEmpty),
        ),
        AsyncData(:final value) => _Board(characters: value),
        AsyncError(:final error) => Center(child: Text('$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Board extends ConsumerWidget {
  const _Board({required this.characters});

  final List<Character> characters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Yatay kaydirma: sutun sayisi sabit ve dar ekranda sikistirmak
    // rakamlari okunmaz hale getiriyordu.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final character in characters)
                _CharacterRow(character: character),
            ],
          ),
        ),
      ),
    );
  }
}

class _CharacterRow extends ConsumerWidget {
  const _CharacterRow({required this.character});

  final Character character;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final build = ref.watch(characterBuildProvider(character.id)).value;
    final languages = ref.watch(_languagesProvider(character.id)).value;
    final defenses = ref.watch(_defensesProvider(character.id)).value;

    if (build == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    String signed(int value) => value >= 0 ? '+$value' : '$value';

    Widget stat(String label, String value, {Color? color}) => Padding(
      padding: const EdgeInsets.only(right: 18),
      child: Semantics(
        // Ekran okuyucu tek parca okusun: "Pasif algi 14".
        label: '$label $value',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );

    final hpRatio = character.hitPointsMax == 0
        ? 1.0
        : character.hitPointsCurrent / character.hitPointsMax;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 150,
                  child: Text(
                    character.name,
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                stat('AC', '${build.armorClass}'),
                stat(
                  'HP',
                  '${character.hitPointsCurrent}/${character.hitPointsMax}'
                      '${character.temporaryHitPoints > 0 ? ' +${character.temporaryHitPoints}' : ''}',
                  color: hpRatio <= 0.25 ? theme.colorScheme.error : null,
                ),
                stat(l10n.partyBoardPassive, '${build.passivePerception}'),
                stat('Init', signed(build.initiative)),
                stat('Speed', '${build.baseSpeed}'),
                stat('Prof', signed(build.proficiencyBonus)),
                if (character.exhaustion > 0)
                  stat(
                    'Exh',
                    '${character.exhaustion}',
                    color: theme.colorScheme.error,
                  ),
                if (character.inspiration)
                  Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: theme.extension<AppFantasyColors>()?.gold,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Kurtarmalar: yeterlilik olanlar kalin, boylece "hangisinde
            // iyi?" sorusu renk gerektirmeden okunuyor.
            Row(
              children: [
                SizedBox(
                  width: 150,
                  child: Text(
                    l10n.partyBoardSaves,
                    style: theme.textTheme.labelSmall,
                  ),
                ),
                const SizedBox(width: 12),
                for (final ability in Ability.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Text(
                      '${ability.name.substring(0, 3).toUpperCase()} '
                      '${signed(build.savingThrow(ability))}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: build.saveProficiencies.contains(ability)
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
              ],
            ),
            // Direnc/bagisiklik: masada "ates ona islemiyor mu?" sorusunun
            // cevabi. Bos ise satir hic cizilmiyor.
            if (defenses != null && !defenses.isEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 150,
                    child: Text(
                      l10n.partyBoardDefenses,
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    [
                      for (final type in defenses.immune)
                        '${type.name} (${l10n.defenseImmune})',
                      for (final type in defenses.resistant)
                        '${type.name} (${l10n.defenseResist})',
                      for (final type in defenses.vulnerable)
                        '${type.name} (${l10n.defenseVulnerable})',
                    ].join(', '),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
            if (languages != null && languages.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 150,
                    child: Text(
                      l10n.partyBoardLanguages,
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(languages.join(', '), style: theme.textTheme.bodySmall),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Karakterin savas takipcisindeki hasar savunmalari.
///
/// Kaynak SAVAS SATIRI, karakter kagidi degil: savunmalar karsilasmaya
/// girerken tur ozelliklerinden dolduruluyor ve DM orada duzenleyebiliyor.
/// Pano o guncel hali gostermeli, kagitta olmayan bir alani degil.
final _defensesProvider = StreamProvider.family<Defenses, String>((
  ref,
  characterId,
) {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.combatants,
  )..where((t) => t.characterId.equals(characterId))).watch().map((rows) {
    // Ayni karakter birden fazla karsilasmada olabilir; en son eklenen
    // satirin savunmalari en guncel olani.
    if (rows.isEmpty) return const Defenses();
    return Defenses.decode(rows.last.defensesJson);
  });
});

/// Karakterin bildigi diller.
///
/// Karakter kagidinda yeterlilik satiri olarak duruyor; parti panosu icin
/// ayri bir sorgu, cunku `CharacterBuild` dil tasimıyor (kural hesaplarina
/// girmiyor).
final _languagesProvider = FutureProvider.family<List<String>, String>((
  ref,
  characterId,
) async {
  final db = ref.watch(databaseProvider);
  final rows =
      await (db.select(db.characterProficiencies)
            ..where(
              (t) =>
                  t.characterId.equals(characterId) &
                  t.kind.equalsValue(ProficiencyKind.language),
            )
            ..orderBy([(t) => OrderingTerm(expression: t.value)]))
          .get();
  return [for (final row in rows) row.value];
});
