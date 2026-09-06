import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/combat_repository.dart';
import '../../data/db/combat_tables.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../domain/rules/encounter_budget.dart';
import '../characters/character_providers.dart';

final combatRepositoryProvider = Provider<CombatRepository>(
  (ref) => CombatRepository(ref.watch(databaseProvider)),
);

final encountersProvider = StreamProvider<List<Encounter>>(
  (ref) => ref.watch(combatRepositoryProvider).watchEncounters(),
);

/// Belirli bir yerde gecen karsilasmalar (lokasyon sayfasindaki liste).
final encountersAtProvider = StreamProvider.family<List<Encounter>, String>(
  (ref, locationId) =>
      ref.watch(combatRepositoryProvider).watchEncountersAt(locationId),
);

final encounterProvider = StreamProvider.family<Encounter?, String>(
  (ref, id) => ref.watch(combatRepositoryProvider).watchEncounter(id),
);

final combatantsProvider = StreamProvider.family<List<Combatant>, String>(
  (ref, encounterId) =>
      ref.watch(combatRepositoryProvider).watchCombatants(encounterId),
);

/// Savas ekranindan hizlica acilan stat blok icin canavar kaydi.
final monsterByKeyProvider = FutureProvider.family<Monster?, String>((
  ref,
  key,
) async {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.monsters,
  )..where((t) => t.key.equals(key))).getSingleOrNull();
});

/// Karsilasmanin zorluk degerlendirmesi: parti seviyeleri + toplam canavar
/// XP'si (2024 XP butcesi). Savas degistikce yeniden hesaplanir.
final encounterBudgetProvider =
    FutureProvider.family<EncounterAssessment, String>((
      ref,
      encounterId,
    ) async {
      // Savas degistikce yeniden hesaplamak icin akisi tetikleyici olarak izle;
      // veriyi ise deterministik Future'dan oku (test/ilk-cerceve guvenilir).
      ref.watch(combatantsProvider(encounterId));
      final db = ref.watch(databaseProvider);
      final charRepo = ref.watch(characterRepositoryProvider);
      final combatants = await ref
          .watch(combatRepositoryProvider)
          .combatants(encounterId);

      // Canavar XP'leri tek sorguda.
      final keys = combatants
          .map((c) => c.monsterKey)
          .whereType<String>()
          .toSet();
      final xpByKey = <String, int?>{};
      if (keys.isNotEmpty) {
        final rows = await (db.select(
          db.monsters,
        )..where((t) => t.key.isIn(keys.toList()))).get();
        for (final r in rows) {
          xpByKey[r.key] = r.experiencePoints;
        }
      }

      // Oyuncu-disi katilimcilar dusman sayilir; XP'si bilinmeyenler (adhoc,
      // XP'siz homebrew) ayrica raporlanir.
      var monsterXp = 0;
      var uncounted = 0;
      for (final c in combatants) {
        if (c.kind == CombatantKind.player) continue;
        final xp = c.monsterKey == null ? null : xpByKey[c.monsterKey];
        if (xp == null) {
          uncounted++;
        } else {
          monsterXp += xp;
        }
      }

      // Parti seviyeleri (oyuncu katilimcilarin karakter toplam seviyesi).
      final partyLevels = <int>[];
      for (final c in combatants) {
        if (c.kind != CombatantKind.player || c.characterId == null) continue;
        final levels = await charRepo.classLevels(c.characterId!);
        final total = levels.fold<int>(0, (a, b) => a + b.level);
        partyLevels.add(total < 1 ? 1 : total);
      }

      return EncounterAssessment(
        monsterXp: monsterXp,
        partyLevels: partyLevels,
        uncounted: uncounted,
      );
    });

// Durum efektleri listesi `features/compendium/condition_providers.dart`
// icindeki `conditionNamesEnProvider`'a tasindi: orada A5e'ye ozel kayitlar
// (5e metni tasimayan 6 tane) eleniyor ve ayni kaynak referans kartlarini da
// besliyor. Burada ikinci bir liste tutmak iki farkli "durum listesi"
// dogururdu.

/// TUM savascilar (karsilasma farki gozetmeden).
///
/// Hedef `Combatants.id` ile tasiniyor ve saldiri sayfasi hangi karsilasmada
/// oldugunu bilmiyor; tek akistan cozmek aile saglayicilarini takip etmekten
/// basit.
final allCombatantsProvider = StreamProvider<List<Combatant>>(
  (ref) => ref
      .watch(databaseProvider)
      .select(ref.watch(databaseProvider).combatants)
      .watch(),
);

/// Su an HEDEF alinmis savasci (`Combatants.id`); yoksa null.
///
/// Savas haritasindaki `T` kisayolu burayi yaziyor, stat blogundaki saldiri
/// sayfasi buradan okuyor: "zar at" ile "hasari uygula" arasindaki elle
/// tasima adimi boylece kalkiyor.
class CombatTargetNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? combatantId) => state = combatantId;
}

final combatTargetProvider = NotifierProvider<CombatTargetNotifier, String?>(
  CombatTargetNotifier.new,
);
