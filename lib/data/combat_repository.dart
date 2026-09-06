import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/models/ability.dart';
import '../domain/rules/combat_conditions.dart';
import '../domain/rules/damage_types.dart';
import '../domain/rules/death_saves.dart';
import '../domain/rules/legendary_actions.dart';
import 'db/combat_tables.dart';
import 'db/database.dart';
import 'encounter_briefing.dart';

/// [CombatRepository.advanceTurn] sonucu: sirasi gelen katilimci ve o turda
/// suresi biten durumlar (DM'e "X sona erdi" hatirlatmasi icin).
class CombatTurnResult {
  const CombatTurnResult({
    this.combatantName,
    this.expired = const [],
    this.lairAction,
    this.newRound = false,
  });

  final String? combatantName;
  final List<String> expired;

  /// Bu adimda IN (lair) eylemi tetiklendiyse metni; yoksa null.
  ///
  /// Kural: in eylemi inisiyatif 20'de, kaybedilen beraberliklerde oynanir.
  /// Sirayi o degere GELDIGIMIZDE bir kez hatirlatiliyor.
  final String? lairAction;

  /// Bu adimda yeni tura gecildi mi?
  final bool newRound;
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

  /// Su an baslamis (started) karsilasma.
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

  // --- Brifing ve ganimet ---------------------------------------------------

  /// Karsilasmanin DM brifingi (kazanma kosulu, taktik, arazi...).
  EncounterBriefing briefingOf(Encounter e) =>
      encounterBriefingFromJson(e.briefingJson);

  /// Karsilasmanin gectigi yeri baglar; [locationId] null ise bagi kaldirir.
  ///
  /// `null = degistirme` deseni bir sutunu NULL'a CEKEMEDIGI icin ayri metot
  /// (`WorldRepository.setMapScale` ile ayni sebep).
  Future<void> setLocation(String encounterId, String? locationId) =>
      (db.update(db.encounters)..where((t) => t.id.equals(encounterId))).write(
        EncountersCompanion(locationId: Value(locationId)),
      );

  /// Belirli bir yerde gecen karsilasmalar; en yenisi ustte.
  Stream<List<Encounter>> watchEncountersAt(String locationId) =>
      (db.select(db.encounters)
            ..where((t) => t.locationId.equals(locationId))
            ..orderBy([
              (t) => OrderingTerm(
                expression: t.createdAt,
                mode: OrderingMode.desc,
              ),
            ]))
          .watch();

  Future<void> setBriefing(String encounterId, EncounterBriefing b) =>
      (db.update(db.encounters)..where((t) => t.id.equals(encounterId))).write(
        EncountersCompanion(
          // Tamamen bos brifing null yazilir: panel "hic girilmemis" ile
          // "girilmis ama bos" arasinda ayrim yapmak zorunda kalmasin.
          briefingJson: Value(
            briefingIsEmpty(b) ? null : encounterBriefingToJson(b),
          ),
        ),
      );

  /// Savastan cikacak ganimet.
  EncounterLoot lootOf(Encounter e) => encounterLootFromJson(e.lootJson);

  Future<void> setLoot(String encounterId, EncounterLoot loot) =>
      (db.update(db.encounters)..where((t) => t.id.equals(encounterId))).write(
        EncountersCompanion(
          lootJson: Value(lootIsEmpty(loot) ? null : encounterLootToJson(loot)),
        ),
      );

  /// Ganimete bir esya ekler. [itemKey]/[magicItemKey] verilmezse esya
  /// "kutuphanede yok" olarak isaretlenir (bkz. [lootItemResolved]).
  Future<void> addLootItem(
    String encounterId, {
    required String name,
    bool magic = false,
    String? itemKey,
    String? magicItemKey,
  }) async {
    final e = await findEncounter(encounterId);
    if (e == null) return;
    final loot = lootOf(e);
    await setLoot(encounterId, (
      coinsCp: loot.coinsCp,
      items: [
        ...loot.items,
        (
          id: _uuid.v4(),
          name: name,
          magic: magic,
          itemKey: itemKey,
          magicItemKey: magicItemKey,
        ),
      ],
    ));
  }

  Future<void> removeLootItem(String encounterId, String itemId) async {
    final e = await findEncounter(encounterId);
    if (e == null) return;
    final loot = lootOf(e);
    await setLoot(encounterId, (
      coinsCp: loot.coinsCp,
      items: [
        for (final i in loot.items)
          if (i.id != itemId) i,
      ],
    ));
  }

  Future<void> setLootCoins(String encounterId, int coinsCp) async {
    final e = await findEncounter(encounterId);
    if (e == null) return;
    final loot = lootOf(e);
    await setLoot(encounterId, (
      coinsCp: coinsCp < 0 ? 0 : coinsCp,
      items: loot.items,
    ));
  }

  Future<Encounter?> findEncounter(String id) => (db.select(
    db.encounters,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

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
    bool groupInitiative = false,
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

    // Hasar turu savunmalari kutuphane verisinden geliyor; boylece "ates
    // topuna direncli miydi?" sorusu savas ekraninda cevapli duruyor.
    final defenses = _defensesOf(data);

    // GRUP inisiyatifi: ayni turden alti goblin icin alti ayri atis masada
    // listeyi gereksizce uzatiyor ve sirayi takip etmeyi zorlastiriyor
    // (DMG'nin de onerdigi yol). Kapaliyken her yaratik kendi atisini alir.
    final shared = _random.nextInt(20) + 1 + dexterity;

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
            initiative: Value(
              groupInitiative ? shared : _random.nextInt(20) + 1 + dexterity,
            ),
            sortOrder: Value(order++),
            hitPointsMax: Value(hp),
            hitPointsCurrent: Value(hp),
            armorClass: Value(monster.armorClass),
            legendaryMax: Value(
              hasLegendary ? kDefaultLegendaryActionsPerRound : null,
            ),
            legendaryResistMax: Value(legendaryResist),
            defensesJson: Value(defenses.encode()),
          ),
        );
      }
    });
  }

  /// Karakterin tur/sinif ozelliklerinden gelen hasar savunmalari.
  ///
  /// Kaynak: tur kaydinin ozellik metinleri ("Damage Resistance: poison",
  /// "Hellish Resistance"). Yapisal bir alan YOK, o yuzden metin taraniyor
  /// (bkz. [defensesFromText]). Yanlis bir eslesme cikarsa DM savas
  /// ekranindan duzeltebiliyor; hic doldurmamak ise ozelligi partinin
  /// yarisi icin olu birakiyordu.
  Future<Defenses> _characterDefenses(String characterId) async {
    final character = await (db.select(
      db.characters,
    )..where((t) => t.id.equals(characterId))).getSingleOrNull();
    final speciesKey = character?.speciesKey;
    if (speciesKey == null) return const Defenses();

    final species = await (db.select(
      db.speciesEntries,
    )..where((t) => t.key.equals(speciesKey))).getSingleOrNull();
    if (species == null) return const Defenses();

    try {
      final data = jsonDecode(species.dataJson);
      if (data is! Map) return const Defenses();
      // Ozellik metinlerinin tamami tek bir govdede taraniyor.
      final buffer = StringBuffer('${data['desc'] ?? ''}');
      final traits = data['traits'];
      if (traits is List) {
        for (final trait in traits) {
          if (trait is Map) buffer.write(' ${trait['desc'] ?? ''}');
        }
      }
      final text = buffer.toString();
      // Yalnizca DIRENC cikariliyor: tur ozellikleri bagisiklik/zayiflik
      // vermiyor ve "immune to being frightened" gibi DURUM bagisikliklarini
      // hasar bagisikligi sanmak yanlis olurdu.
      return Defenses(
        resistant: defensesFromText(
          resistances: _resistanceSentences(text),
        ).resistant,
      );
    } on Object {
      return const Defenses();
    }
  }

  /// Metinden yalnizca "resistance" gecen cumleleri suzer.
  ///
  /// Tum metni taramak, "fire" kelimesi gecen her ozelligi ates direnci
  /// sayardi ("you can cast fire bolt" gibi).
  static String _resistanceSentences(String text) => text
      .split(RegExp(r'(?<=[.;])\s+'))
      .where((sentence) => sentence.toLowerCase().contains('resistance'))
      .join(' ');

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

    // Savunmalar TOPLU islemden once toplaniyor: `batch` icinde `await`
    // edilemiyor.
    final defenses = <String, Defenses>{
      for (final character in characters)
        if (!alreadyIn.contains(character.id))
          character.id: await _characterDefenses(character.id),
    };

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
            // Tur ozelliklerinden gelen direncler; DM savas ekranindan
            // duzenleyebiliyor.
            defensesJson: Value(
              (defenses[character.id] ?? const Defenses()).encode(),
            ),
          ),
        );
      }
    });
  }

  /// Hizli giris ekler; olusan satirin KIMLIGINI doner.
  ///
  /// Kimlik geri donuyor cunku haritadan savasa katilan bir jetonun
  /// olusan satira baglanmasi gerekiyor (bkz. `CombatRoster`).
  Future<String> addAdhoc({
    required String encounterId,
    required String name,
    int initiative = 0,
    int hitPoints = 0,
  }) async {
    final existing = await combatants(encounterId);
    final id = _uuid.v4();
    await db
        .into(db.combatants)
        .insert(
          CombatantsCompanion.insert(
            id: id,
            encounterId: encounterId,
            kind: CombatantKind.adhoc,
            name: name,
            initiative: Value(initiative),
            sortOrder: Value(existing.length),
            hitPointsMax: Value(hitPoints),
            hitPointsCurrent: Value(hitPoints),
          ),
        );
    return id;
  }

  /// Katilimcinin adini degistirir.
  ///
  /// Haritadan savasa katilan bir jetonun adi kullaniciya ait olabiliyor
  /// ("Kapidaki muhafiz"); savas listesinde de o gorunmeli.
  Future<void> renameCombatant(String combatantId, String name) =>
      (db.update(db.combatants)..where((t) => t.id.equals(combatantId))).write(
        CombatantsCompanion(name: Value(name.trim())),
      );

  /// Silinen bir katilimciyi AYNEN geri koyar (genel geri alma icin).
  ///
  /// `insertOnConflictUpdate`: geri alma iki kez tetiklenirse ikinci cagri
  /// birincil anahtar hatasi vermesin.
  Future<void> restoreCombatant(Combatant row) =>
      db.into(db.combatants).insertOnConflictUpdate(row.toCompanion(false));

  Future<void> removeCombatant(String id) async {
    await (db.delete(db.combatants)..where((t) => t.id.equals(id))).go();
  }

  Future<void> setInitiative(String combatantId, int value) async {
    await (db.update(db.combatants)..where((t) => t.id.equals(combatantId)))
        .write(CombatantsCompanion(initiative: Value(value)));
  }

  /// Savasi baslatir: initiative'i atilmamis CANAVAR/adhoc katilimcilar icin
  /// zar atar.
  ///
  /// Oyuncu karakterlerine DOKUNULMAZ: onlarin zarini masadaki oyuncu atar,
  /// DM sayiyi listeye kendisi girer. Otomatik atmak, masada zaten atilmis
  /// bir zarin uzerine yazardi.
  Future<void> start(String encounterId) async {
    final rows = await combatants(encounterId);
    await db.batch((b) {
      for (final c in rows) {
        if (c.kind == CombatantKind.player) continue;
        if (c.initiative != 0) continue;
        b.update(
          db.combatants,
          CombatantsCompanion(initiative: Value(_random.nextInt(20) + 1)),
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

  /// Savasi bitirir: baslamamis duruma dondurur.
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
    final previousIndex = index.clamp(0, rows.length - 1);

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

    // Efsanevi eylemler ve REAKSIYON katilimcinin turu BASLAYINCA tazelenir
    // (D&D kurali). Efsanevi DIRENC gunluk bir kaynak, burada sifirlanmaz.
    final refreshLegendary =
        active.legendaryMax != null && active.legendarySpent != 0;
    if (refreshLegendary || active.reactionUsed) {
      await (db.update(
        db.combatants,
      )..where((t) => t.id.equals(active.id))).write(
        CombatantsCompanion(
          legendarySpent: refreshLegendary
              ? const Value(0)
              : const Value.absent(),
          reactionUsed: const Value(false),
        ),
      );
    }

    return CombatTurnResult(
      combatantName: active.name,
      expired: ticked.expired,
      lairAction: _lairTrigger(encounter, rows, index, previousIndex),
      newRound: round != encounter.round,
    );
  }

  /// Bu adimda in (lair) eylemi tetiklendi mi?
  ///
  /// Kural: in eylemi inisiyatif 20'de oynanir. Listede tam 20'lik bir
  /// katilimci olmayabilecegi icin, sirasi GECILEN esikle karsilastiriliyor:
  /// bir onceki katilimcinin inisiyatifi esigin ustunde, yenisininki
  /// altindaysa tam o araliktan gecmisiz demektir. Tur basinda da (liste
  /// bastan sarmisken) esigin ustundeki ilk katilimciya gelince tetiklenir.
  String? _lairTrigger(
    Encounter encounter,
    List<Combatant> rows,
    int index,
    int previousIndex,
  ) {
    final text = encounter.lairActionText;
    if (text == null || text.trim().isEmpty) return null;

    final threshold = encounter.lairInitiative;
    final current = rows[index].initiative;
    // Tura bastan donuldugunde ilk katilimci esigin altindaysa esikten
    // gecilmis olur.
    if (index <= previousIndex) return current <= threshold ? text : null;

    final previous = rows[previousIndex].initiative;
    return previous > threshold && current <= threshold ? text : null;
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

    // Olum kurtarmasi da tasiniyor: oyuncu kendi panelinden bir kurtarma
    // atinca karakter kaydi guncelleniyor ve DM'in savas ekrani eskiden
    // eski sayaci gostermeye devam ediyordu -- iki taraf ayrisiyordu.
    await (db.update(db.combatants)..where((t) => t.id.equals(row.id))).write(
      CombatantsCompanion(
        hitPointsCurrent: Value(character.hitPointsCurrent),
        temporaryHitPoints: Value(character.temporaryHitPoints),
        defeated: Value(character.hitPointsCurrent == 0),
        deathSaveSuccesses: Value(character.deathSaveSuccesses),
        deathSaveFailures: Value(character.deathSaveFailures),
      ),
    );
  }

  /// Savas sirasini ELLE yeniden dizer.
  ///
  /// Sira normalde initiative'e gore; esitlikte [Combatants.sortOrder]
  /// belirliyor. DM listede bir satiri surukledigi anda o satirin
  /// initiative'i komsularina esitlenip sortOrder ile araya sokuluyor --
  /// aksi halde surukleme hicbir sey yapmis gibi gorunmezdi.
  ///
  /// [from]/[to] `combatants()` sirasindaki indeksler.
  Future<void> reorderCombatants(String encounterId, int from, int to) async {
    final rows = await combatants(encounterId);
    if (from < 0 || from >= rows.length) return;
    final target = to.clamp(0, rows.length - 1);
    if (from == target) return;

    final ordered = [...rows];
    final moved = ordered.removeAt(from);
    ordered.insert(target, moved);

    // Suruklenen satirin initiative'i yeni komsularinin arasina oturuyor;
    // liste bastan asagi azalan kalmali.
    final above = target == 0 ? null : ordered[target - 1].initiative;
    final below = target == ordered.length - 1
        ? null
        : ordered[target + 1].initiative;
    final initiative = switch ((above, below)) {
      (null, null) => moved.initiative,
      (final a?, null) => a,
      (null, final b?) => b,
      (final a?, final b?) => a == b ? a : ((a + b) / 2).round().clamp(b, a),
    };

    await db.transaction(() async {
      for (var i = 0; i < ordered.length; i++) {
        await (db.update(
          db.combatants,
        )..where((t) => t.id.equals(ordered[i].id))).write(
          CombatantsCompanion(
            sortOrder: Value(i),
            initiative: ordered[i].id == moved.id
                ? Value(initiative)
                : const Value.absent(),
          ),
        );
      }
    });
  }

  /// Hasar uygular.
  ///
  /// Oyuncu karakterlerinde karakter kaydi da guncellenir; savas ve karakter
  /// kagidi ayni cani gostersin diye.
  ///
  /// Hasar alan yaratik KONSANTRE ise gereken kurtarma DC'sini doner (5e:
  /// 10 ya da hasarin yarisi, hangisi buyukse); degilse null. Konsantrasyonu
  /// KENDILIGINDEN bozmuyor -- zar oyuncunun, karar DM'in.
  /// Hasar uygular; konsantrasyon kontrolu gerekiyorsa DC'sini doner.
  ///
  /// [type] verilirse katilimcinin DIRENC/BAGISIKLIK/ZAYIFLIK listesi
  /// uygulanir ve gercekten dusen hasar [DamageOutcome.amount] ile geri
  /// gonderilir -- masada "yarisi gitti" bilgisi arayuzde gorunsun diye.
  Future<DamageOutcome> applyDamageTyped(
    String combatantId,
    int amount, {
    DamageType? type,
    bool critical = false,
  }) async {
    final before = await (db.select(
      db.combatants,
    )..where((t) => t.id.equals(combatantId))).getSingleOrNull();
    if (before == null || amount <= 0) {
      return const DamageOutcome(
        amount: 0,
        modifier: DamageModifier.normal,
        concentrationDc: null,
      );
    }

    final defenses = Defenses.decode(before.defensesJson);
    final applied = applyDefenses(amount, type, defenses);

    // ZATEN 0 CANDA olan bir yaratik hasar alirsa bu bir olum kurtarma
    // basarisizligi (kural); kritik vurus ikisini birden goturur.
    if (before.hitPointsCurrent == 0 && applied.amount > 0) {
      await _addDeathSaveFailure(before, critical: critical);
    }

    await _changeHitPoints(combatantId, -applied.amount);

    return DamageOutcome(
      amount: applied.amount,
      modifier: applied.modifier,
      concentrationDc: before.concentrating && applied.amount > 0
          ? concentrationSaveDc(applied.amount)
          : null,
    );
  }

  Future<int?> applyDamage(String combatantId, int amount) async {
    final result = await applyDamageTyped(combatantId, amount);
    return result.concentrationDc;
  }

  /// In (lair) eylemini yazar; [text] null ise in eylemi kapanir.
  Future<void> setLairAction(
    String encounterId, {
    String? text,
    int initiative = 20,
  }) =>
      (db.update(db.encounters)..where((t) => t.id.equals(encounterId))).write(
        EncountersCompanion(
          lairActionText: Value(text),
          lairInitiative: Value(initiative),
        ),
      );

  /// Tur suresi sinirini yazar; null = sinirsiz.
  Future<void> setTurnLimit(String encounterId, int? seconds) =>
      (db.update(db.encounters)..where((t) => t.id.equals(encounterId))).write(
        EncountersCompanion(turnLimitSeconds: Value(seconds)),
      );

  /// Katilimcinin savunmalarini yazar (DM elle duzenliyor).
  Future<void> setDefenses(String combatantId, Defenses defenses) =>
      (db.update(db.combatants)..where((t) => t.id.equals(combatantId))).write(
        CombatantsCompanion(defensesJson: Value(defenses.encode())),
      );

  /// Reaksiyon isaretini degistirir. Sira o katilimciya GELINCE
  /// [advanceTurn] kendiliginden sifirliyor.
  Future<void> setReactionUsed(String combatantId, bool used) =>
      (db.update(db.combatants)..where((t) => t.id.equals(combatantId))).write(
        CombatantsCompanion(reactionUsed: Value(used)),
      );

  /// Olum kurtarma atisi isler.
  ///
  /// [roll] verilmezse zar burada atilir; masada zar zaten atildiysa sonuc
  /// disaridan verilir.
  Future<({DeathSaves saves, DeathSaveState state})> rollDeathSaveFor(
    String combatantId, {
    int? roll,
  }) async {
    final row = await (db.select(
      db.combatants,
    )..where((t) => t.id.equals(combatantId))).getSingleOrNull();
    if (row == null) {
      return (saves: emptyDeathSaves, state: DeathSaveState.pending);
    }

    final result = rollDeathSave((
      successes: row.deathSaveSuccesses,
      failures: row.deathSaveFailures,
    ), roll ?? (_random.nextInt(20) + 1));
    await _writeDeathSaves(row, result.saves, result.state);
    return result;
  }

  /// Sayaci elle duzenler (DM bir atisi geri almak istediginde).
  Future<void> setDeathSaves(String combatantId, DeathSaves saves) async {
    final row = await (db.select(
      db.combatants,
    )..where((t) => t.id.equals(combatantId))).getSingleOrNull();
    if (row == null) return;
    await _writeDeathSaves(row, saves, deathSaveState(saves));
  }

  Future<void> _addDeathSaveFailure(
    Combatant row, {
    required bool critical,
  }) async {
    final result = damageWhileDown((
      successes: row.deathSaveSuccesses,
      failures: row.deathSaveFailures,
    ), critical: critical);
    await _writeDeathSaves(row, result.saves, result.state);
  }

  Future<void> _writeDeathSaves(
    Combatant row,
    DeathSaves saves,
    DeathSaveState state,
  ) async {
    await (db.update(db.combatants)..where((t) => t.id.equals(row.id))).write(
      CombatantsCompanion(
        deathSaveSuccesses: Value(saves.successes),
        deathSaveFailures: Value(saves.failures),
        // Dogal 20: 1 canla ayaga kalkiyor. `defeated` bayragi da kalkmali,
        // yoksa sira atlamaya devam ederdi.
        hitPointsCurrent: state == DeathSaveState.revived
            ? const Value(1)
            : const Value.absent(),
        defeated: state == DeathSaveState.revived
            ? const Value(false)
            : (state == DeathSaveState.dead
                  ? const Value(true)
                  : const Value.absent()),
      ),
    );

    // Oyuncu karakterlerinde ANA KAYIT karakter kagidi; sayac orayla
    // esitlenmezse kagitta eski deger kalirdi.
    final characterId = row.characterId;
    if (characterId != null) {
      await (db.update(
        db.characters,
      )..where((t) => t.id.equals(characterId))).write(
        CharactersCompanion(
          deathSaveSuccesses: Value(saves.successes),
          deathSaveFailures: Value(saves.failures),
          hitPointsCurrent: state == DeathSaveState.revived
              ? const Value(1)
              : const Value.absent(),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  /// Kutuphane verisinden hasar savunmalarini cikarir.
  static Defenses _defensesOf(Map<String, dynamic> data) {
    final node = data['resistances_and_immunities'];
    if (node is! Map) return const Defenses();
    final map = node.cast<String, dynamic>();

    Set<DamageType> read(String key) {
      final list = map[key];
      if (list is! List) return const {};
      return {
        for (final item in list)
          ?DamageType.parse(
            item is Map ? '${item['key'] ?? item['name']}' : '$item',
          ),
      };
    }

    return Defenses(
      resistant: read('damage_resistances'),
      immune: read('damage_immunities'),
      vulnerable: read('damage_vulnerabilities'),
    );
  }

  Future<void> applyHealing(String combatantId, int amount) async {
    await _changeHitPoints(combatantId, amount);
    // Iyilesen yaratik ayaga kalkar: olum kurtarma sayaci sifirlanir (kural).
    if (amount > 0) await setDeathSaves(combatantId, resetDeathSaves());
  }

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

/// Uygulanan hasarin sonucu.
///
/// Ham hasar degil GERCEKTEN dusen can donuyor: direnc/bagisiklik uygulandiktan
/// sonraki deger. Arayuz "24 → 12 (direnc)" yazabilsin diye [modifier] de
/// birlikte geliyor.
class DamageOutcome {
  const DamageOutcome({
    required this.amount,
    required this.modifier,
    required this.concentrationDc,
  });

  final int amount;
  final DamageModifier modifier;

  /// Konsantrasyon kontrolu gerekiyorsa DC; yoksa null.
  final int? concentrationDc;
}
