import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/models/ability.dart';
import '../domain/rules/combat_conditions.dart';
import '../domain/rules/legendary_actions.dart';
import 'db/combat_tables.dart';
import 'db/database.dart';

/// [CombatRepository.advanceTurn] sonucu: sirasi gelen katilimci ve o turda
/// suresi biten durumlar (DM'e "X sona erdi" hatirlatmasi icin).
class CombatTurnResult {
  const CombatTurnResult({this.combatantName, this.expired = const []});

  final String? combatantName;
  final List<String> expired;
}

/// Savas takipcisinin veri katmani.
///
/// Oyuncu karakterlerinin cani iki yerde tutulmaz: [Combatants] satirindaki
/// HP yalnizca canavarlar icindir, oyuncularda karakter kaydi kaynaktir.
/// Boylece savas sirasinda alinan hasar karakter kagidinda da gorunuyor.
class CombatRepository {
  CombatRepository(this.db);

  final AppDatabase db;

  final _random = Random();

  /// Kimlikler zaman damgasindan uretilemiyor: ayni mikrosaniye icinde
  /// birden fazla katilimci eklenince (toplu ekleme, hizli dokunus) birincil
  /// anahtar cakisiyordu.
  static const _uuid = Uuid();

  Stream<List<Encounter>> watchEncounters() =>
      (db.select(db.encounters)..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
          .watch();

  Stream<Encounter?> watchEncounter(String id) => (db.select(
    db.encounters,
  )..where((t) => t.id.equals(id))).watchSingleOrNull();

  /// Su an baslamis (started) karsilasma; oyunculara otomatik yansitilan budur.
  Future<Encounter?> startedEncounter() =>
      (db.select(db.encounters)
            ..where((t) => t.started.equals(true))
            ..limit(1))
          .getSingleOrNull();

  /// Katilimcilar initiative'e gore azalan, esitlikte [Combatants.sortOrder]
  /// ile sabit sirada gelir.
  Stream<List<Combatant>> watchCombatants(String encounterId) =>
      (db.select(db.combatants)
            ..where((t) => t.encounterId.equals(encounterId))
            ..orderBy([
              (t) => OrderingTerm(
                expression: t.initiative,
                mode: OrderingMode.desc,
              ),
              (t) => OrderingTerm(expression: t.sortOrder),
            ]))
          .watch();

  Future<List<Combatant>> combatants(String encounterId) =>
      (db.select(db.combatants)
            ..where((t) => t.encounterId.equals(encounterId))
            ..orderBy([
              (t) => OrderingTerm(
                expression: t.initiative,
                mode: OrderingMode.desc,
              ),
              (t) => OrderingTerm(expression: t.sortOrder),
            ]))
          .get();

  Future<String> createEncounter(String name) async {
    final id = 'enc-${_uuid.v4()}';
    await db
        .into(db.encounters)
        .insert(EncountersCompanion.insert(id: id, name: name));
    return id;
  }

  Future<void> deleteEncounter(String id) async {
    // Tipli API: ham SQL Drift akislarini yenilemiyor (silinen karsilasma
    // listede kaliyordu).
    await db.transaction(() async {
      await (db.delete(
        db.combatants,
      )..where((t) => t.encounterId.equals(id))).go();
      await (db.delete(db.encounters)..where((t) => t.id.equals(id))).go();
    });
  }

  /// Kutuphaneden canavar ekler.
  ///
  /// [count] birden buyukse "Goblin 1", "Goblin 2" diye numaralanir; HP
  /// [rollHitPoints] ile hit dice'tan atilabilir, aksi halde ortalama alinir.
  Future<void> addMonsters({
    required String encounterId,
    required Monster monster,
    int count = 1,
    bool rollHitPoints = false,
  }) async {
    final existing = await combatants(encounterId);
    var order = existing.length;

    final data = jsonDecode(monster.dataJson) as Map<String, dynamic>;
    final dexterity =
        (data['modifiers'] as Map?)?['dexterity'] as int? ??
        AbilityScores.fromJson(
          ((data['ability_scores'] as Map?) ?? const {})
              .cast<String, dynamic>(),
        ).modifier(Ability.dexterity);

    // Efsanevi eylemi olan her canavara sayac kendiliginden gelir. Veride tur
    // basina hak YAZMADIGI icin varsayilan kullanilir (DM degistirebilir);
    // efsanevi direnc ise trait adindan cikarilir.
    final hasLegendary = legendaryActionsOf(data).isNotEmpty;
    final legendaryResist = legendaryResistanceOf(data);

    await db.batch((b) {
      for (var i = 1; i <= count; i++) {
        final hp = rollHitPoints
            ? _rollHitDice(data['hit_dice'] as String?) ??
                  monster.hitPoints ??
                  1
            : monster.hitPoints ?? 1;

        b.insert(
          db.combatants,
          CombatantsCompanion.insert(
            id: _uuid.v4(),
            encounterId: encounterId,
            kind: CombatantKind.monster,
            name: count > 1 ? '${monster.name} $i' : monster.name,
            monsterKey: Value(monster.key),
            // Canavarlarin initiative'i eklenirken bir kez atiliyor;
            // DM isterse elle degistirebilir.
            initiative: Value(_random.nextInt(20) + 1 + dexterity),
            sortOrder: Value(order++),
            hitPointsMax: Value(hp),
            hitPointsCurrent: Value(hp),
            armorClass: Value(monster.armorClass),
            legendaryMax: Value(
              hasLegendary ? kDefaultLegendaryActionsPerRound : null,
            ),
            legendaryResistMax: Value(legendaryResist),
          ),
        );
      }
    });
  }

  /// Partiyi savasa katar. Zaten ekli olanlar tekrar eklenmez.
  Future<void> addCharacters({
    required String encounterId,
    required List<Character> characters,
  }) async {
    final existing = await combatants(encounterId);
    final alreadyIn = existing
        .map((c) => c.characterId)
        .whereType<String>()
        .toSet();
    var order = existing.length;

    await db.batch((b) {
      for (final character in characters) {
        if (alreadyIn.contains(character.id)) continue;
        b.insert(
          db.combatants,
          CombatantsCompanion.insert(
            id: '$encounterId-pc-${character.id}',
            encounterId: encounterId,
            kind: CombatantKind.player,
            name: character.name,
            characterId: Value(character.id),
            sortOrder: Value(order++),
            hitPointsMax: Value(character.hitPointsMax),
            hitPointsCurrent: Value(character.hitPointsCurrent),
            // Oyuncu inisiyatifini kendi panelinden atar; atilana kadar
            // listede sayi yerine zar dugmesi gorunur.
            initiativeRolled: const Value(false),
          ),
        );
      }
    });
  }

  Future<void> addAdhoc({
    required String encounterId,
    required String name,
    int initiative = 0,
    int hitPoints = 0,
  }) async {
    final existing = await combatants(encounterId);
    await db
        .into(db.combatants)
        .insert(
          CombatantsCompanion.insert(
            id: _uuid.v4(),
            encounterId: encounterId,
            kind: CombatantKind.adhoc,
            name: name,
            initiative: Value(initiative),
            sortOrder: Value(existing.length),
            hitPointsMax: Value(hitPoints),
            hitPointsCurrent: Value(hitPoints),
          ),
        );
  }

  Future<void> removeCombatant(String id) async {
    await (db.delete(db.combatants)..where((t) => t.id.equals(id))).go();
  }

  Future<void> setInitiative(String combatantId, int value) async {
    await (db.update(
      db.combatants,
    )..where((t) => t.id.equals(combatantId))).write(
      CombatantsCompanion(
        initiative: Value(value),
        initiativeRolled: const Value(true),
      ),
    );
  }

  /// Savasi baslatir: initiative'i atilmamis CANAVAR/adhoc katilimcilar icin
  /// zar atar. Oyuncular kendi panellerinden attigi icin onlara dokunulmaz
  /// (atilmamislar 0 kalir ve listede zar dugmesi gosterir).
  Future<void> start(String encounterId) async {
    final rows = await combatants(encounterId);
    await db.batch((b) {
      for (final c in rows) {
        if (c.kind == CombatantKind.player) continue;
        if (c.initiative != 0) continue;
        b.update(
          db.combatants,
          CombatantsCompanion(
            initiative: Value(_random.nextInt(20) + 1),
            initiativeRolled: const Value(true),
          ),
          where: (t) => t.id.equals(c.id),
        );
      }
    });
    await (db.update(
      db.encounters,
    )..where((t) => t.id.equals(encounterId))).write(
      const EncountersCompanion(
        started: Value(true),
        round: Value(1),
        activeIndex: Value(0),
      ),
    );
  }

  /// Savasi bitirir: baslamamis duruma dondurur. Oyunculara yansitilan savas
  /// da kendiliginden kapanir (sunucu started karsilasmayi otomatik gosteriyor).
  Future<void> end(String encounterId) =>
      (db.update(db.encounters)..where((t) => t.id.equals(encounterId))).write(
        const EncountersCompanion(
          started: Value(false),
          round: Value(0),
          activeIndex: Value(0),
        ),
      );

  /// Sirayi bir ileri alir; liste basa donunce tur sayaci artar.
  ///
  /// Yenilmis katilimcilar atlanir; hepsi yenilmisse oldugu yerde kalir. Sirasi
  /// gelen katilimcinin sureli durumlari bir azalir; suresi biten durumlar
  /// kaldirilir ve [CombatTurnResult.expired] ile bildirilir (DM'e hatirlatma).
  Future<CombatTurnResult> advanceTurn(String encounterId) async {
    final encounter = await (db.select(
      db.encounters,
    )..where((t) => t.id.equals(encounterId))).getSingleOrNull();
    if (encounter == null) return const CombatTurnResult();

    final rows = await combatants(encounterId);
    if (rows.isEmpty) return const CombatTurnResult();

    var index = encounter.activeIndex;
    var round = encounter.round;

    for (var step = 0; step < rows.length; step++) {
      index++;
      if (index >= rows.length) {
        index = 0;
        round++;
      }
      if (!rows[index].defeated) break;
    }

    await (db.update(
      db.encounters,
    )..where((t) => t.id.equals(encounterId))).write(
      EncountersCompanion(activeIndex: Value(index), round: Value(round)),
    );

    // Sirasi gelen katilimcinin durum sureleri azalir.
    final active = rows[index];
    final ticked = tickConditions(parseConditions(active.conditionsJson));
    if (ticked.expired.isNotEmpty) {
      await _writeConditions(active.id, ticked.next);
    }

    // Efsanevi eylemler katilimcinin turu BASLAYINCA tazelenir (D&D kurali).
    // Efsanevi DIRENC gunluk bir kaynak, burada sifirlanmaz.
    if (active.legendaryMax != null && active.legendarySpent != 0) {
      await (db.update(db.combatants)..where((t) => t.id.equals(active.id)))
          .write(const CombatantsCompanion(legendarySpent: Value(0)));
    }
    return CombatTurnResult(
      combatantName: active.name,
      expired: ticked.expired,
    );
  }

  /// Karakter kaydindaki cani BASLAMIS karsilasmadaki satirina yazar.
  ///
  /// Ters yon (`applyDamage`) zaten karakter kaydini guncelliyor; bu, karakter
  /// tarafinda olan degisiklikleri (mola, seviye atlama, DM'in elle duzenlemesi)
  /// savas listesine tasir. Yoksa uzun moladan sonra savas ekrani eski cani
  /// gostermeye devam eder.
  Future<void> syncFromCharacter(String characterId) async {
    final encounter = await startedEncounter();
    if (encounter == null) return;

    final character = await (db.select(
      db.characters,
    )..where((t) => t.id.equals(characterId))).getSingleOrNull();
    if (character == null) return;

    final rows = await combatants(encounter.id);
    final row = rows.where((c) => c.characterId == characterId).firstOrNull;
    if (row == null) return;

    await (db.update(db.combatants)..where((t) => t.id.equals(row.id))).write(
      CombatantsCompanion(
        hitPointsCurrent: Value(character.hitPointsCurrent),
        temporaryHitPoints: Value(character.temporaryHitPoints),
        defeated: Value(character.hitPointsCurrent == 0),
      ),
    );
  }

  /// Hasar uygular.
  ///
  /// Oyuncu karakterlerinde karakter kaydi da guncellenir; savas ve karakter
  /// kagidi ayni cani gostersin diye.
  Future<void> applyDamage(String combatantId, int amount) =>
      _changeHitPoints(combatantId, -amount);

  Future<void> applyHealing(String combatantId, int amount) =>
      _changeHitPoints(combatantId, amount);

  Future<void> _changeHitPoints(String combatantId, int delta) async {
    await db.transaction(() async {
      final c = await (db.select(
        db.combatants,
      )..where((t) => t.id.equals(combatantId))).getSingleOrNull();
      if (c == null || delta == 0) return;

      var temp = c.temporaryHitPoints;
      var current = c.hitPointsCurrent;

      if (delta < 0) {
        // Hasar once gecici cani tuketir.
        final damage = -delta;
        final absorbed = temp >= damage ? damage : temp;
        temp -= absorbed;
        current -= damage - absorbed;
        if (current < 0) current = 0;
      } else {
        current += delta;
        if (current > c.hitPointsMax) current = c.hitPointsMax;
      }

      await (db.update(
        db.combatants,
      )..where((t) => t.id.equals(combatantId))).write(
        CombatantsCompanion(
          hitPointsCurrent: Value(current),
          temporaryHitPoints: Value(temp),
          defeated: Value(current == 0),
          // Can sifirlaninca konsantrasyon kirilir.
          concentrating: current == 0
              ? const Value(false)
              : const Value.absent(),
        ),
      );

      final characterId = c.characterId;
      if (characterId != null) {
        await (db.update(
          db.characters,
        )..where((t) => t.id.equals(characterId))).write(
          CharactersCompanion(
            hitPointsCurrent: Value(current),
            temporaryHitPoints: Value(temp),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    });
  }

  /// Durumlari yalnizca adlariyla (suresiz) yazar. Eski cagiranlarla uyumlu.
  Future<void> setConditions(String combatantId, List<String> conditions) =>
      _writeConditions(combatantId, [
        for (final c in conditions) CombatCondition(c),
      ]);

  /// Durumlari tur sureleriyle birlikte yazar.
  Future<void> setConditionsTyped(
    String combatantId,
    List<CombatCondition> conditions,
  ) => _writeConditions(combatantId, conditions);

  Future<void> _writeConditions(
    String combatantId,
    List<CombatCondition> conditions,
  ) async {
    await (db.update(
      db.combatants,
    )..where((t) => t.id.equals(combatantId))).write(
      CombatantsCompanion(conditionsJson: Value(encodeConditions(conditions))),
    );
  }

  Future<void> setConcentration(
    String combatantId, {
    required bool value,
    String? note,
  }) async {
    await (db.update(
      db.combatants,
    )..where((t) => t.id.equals(combatantId))).write(
      CombatantsCompanion(
        concentrating: Value(value),
        concentrationNote: Value(value ? note : null),
      ),
    );
  }

  Future<void> setDefeated(String combatantId, bool value) async {
    await (db.update(db.combatants)..where((t) => t.id.equals(combatantId)))
        .write(CombatantsCompanion(defeated: Value(value)));
  }

  // --- Efsanevi eylemler (DM-only) -----------------------------------------

  /// Harcanan efsanevi eylem sayisi; 0..[Combatant.legendaryMax] arasina
  /// kirpilir.
  Future<void> setLegendarySpent(String combatantId, int spent) async {
    final row = await (db.select(
      db.combatants,
    )..where((t) => t.id.equals(combatantId))).getSingleOrNull();
    if (row == null || row.legendaryMax == null) return;
    await (db.update(
      db.combatants,
    )..where((t) => t.id.equals(combatantId))).write(
      CombatantsCompanion(
        legendarySpent: Value(spent.clamp(0, row.legendaryMax!)),
      ),
    );
  }

  /// Tur basina efsanevi eylem hakki. `null` sayaci tamamen kaldirir.
  Future<void> setLegendaryMax(String combatantId, int? max) async {
    final value = max == null || max < 1 ? null : max;
    await (db.update(
      db.combatants,
    )..where((t) => t.id.equals(combatantId))).write(
      CombatantsCompanion(
        legendaryMax: Value(value),
        // Hak azaltilinca harcanan onun uzerinde kalmasin.
        legendarySpent: const Value(0),
      ),
    );
  }

  /// Harcanan efsanevi direnc; 0..[Combatant.legendaryResistMax] arasina
  /// kirpilir.
  Future<void> setLegendaryResistSpent(String combatantId, int spent) async {
    final row = await (db.select(
      db.combatants,
    )..where((t) => t.id.equals(combatantId))).getSingleOrNull();
    if (row == null || row.legendaryResistMax == null) return;
    await (db.update(
      db.combatants,
    )..where((t) => t.id.equals(combatantId))).write(
      CombatantsCompanion(
        legendaryResistSpent: Value(spent.clamp(0, row.legendaryResistMax!)),
      ),
    );
  }

  /// "20d10 + 40" -> zar atarak toplam.
  ///
  /// Formati tanimazsa null doner ve cagiran ortalamaya duser.
  static int? _rollHitDice(String? expression) {
    if (expression == null) return null;
    final match = RegExp(
      r'(\d+)\s*d\s*(\d+)\s*(?:([+-])\s*(\d+))?',
      caseSensitive: false,
    ).firstMatch(expression);
    if (match == null) return null;

    final count = int.parse(match.group(1)!);
    final sides = int.parse(match.group(2)!);
    final random = Random();
    var total = 0;
    for (var i = 0; i < count; i++) {
      total += random.nextInt(sides) + 1;
    }
    if (match.group(3) != null) {
      final modifier = int.parse(match.group(4)!);
      total += match.group(3) == '-' ? -modifier : modifier;
    }
    return total < 1 ? 1 : total;
  }
}
