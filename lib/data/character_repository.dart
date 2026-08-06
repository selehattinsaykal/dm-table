import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/models/ability.dart';
import '../domain/models/character_build.dart';
import '../domain/rules/character_math.dart';
import 'character_image_store.dart';
import 'db/character_tables.dart';
import 'db/database.dart';

/// Karakterin bildigi bir buyu (kutuphane bilgisiyle birlestirilmis).
typedef KnownSpell = ({
  String spellKey,
  String name,
  int level,
  String? school,
  bool concentration,
  bool ritual,
  bool prepared,
  bool alwaysPrepared,
});

/// Seviye atlamada ne kazanilacaginin ozeti.
class LevelUpPreview {
  const LevelUpPreview({
    required this.classKey,
    required this.className,
    required this.newLevel,
    required this.hitDieSides,
    required this.isNewClass,
    required this.features,
    required this.grantsSubclass,
    required this.grantsAbilityIncrease,
    this.currentSubclassKey,
  });

  final String classKey;
  final String className;
  final int newLevel;
  final int hitDieSides;

  /// Bu sinif karakterde yoksa multiclass olacak.
  final bool isNewClass;
  final String? currentSubclassKey;

  final List<({String key, String name, String description})> features;
  final bool grantsSubclass;
  final bool grantsAbilityIncrease;

  /// Zar atmak istemeyenler icin sabit artis.
  int get averageHitPoints => CharacterMath.averageHitDie(hitDieSides);
}

/// Karakter kayitlarini okur/yazar ve kural motorunun ihtiyaci olan
/// [CharacterBuild] anlik goruntusunu kurar.
/// Bir hit die harcamasinin sonucu.
typedef HitDieSpend = ({int sides, int roll, int conModifier, int healed});

class CharacterRepository {
  CharacterRepository(this.db, {CharacterImageStore? portraits})
    : portraits = portraits ?? CharacterImageStore();

  final AppDatabase db;
  final CharacterImageStore portraits;

  static const _uuid = Uuid();

  /// Tam buyucu yuva tablosunun okundugu sinif. Multiclass Spellcaster
  /// tablosu SRD'de tam buyucu tablosuyla birebir ayni oldugu icin ayrica
  /// veri tutmak yerine buradan okunuyor.
  static const _fullCasterReferenceClass = 'srd-2024_wizard';

  /// Sihirbazda secilebilecek turler, background'lar ve siniflar.
  /// Homebrew kayitlar da ayni tablolarda oldugu icin otomatik dahil olur.
  Future<List<SpeciesEntry>> speciesOptions() =>
      (db.select(db.speciesEntries)
            ..where((t) => t.isSubspecies.equals(false))
            ..orderBy([(t) => OrderingTerm(expression: t.nameLower)]))
          .get();

  Future<List<Background>> backgroundOptions() => (db.select(
    db.backgrounds,
  )..orderBy([(t) => OrderingTerm(expression: t.nameLower)])).get();

  Future<List<ClassDefinition>> classOptions() =>
      (db.select(db.classDefinitions)
            ..where((t) => t.subclassOf.isNull())
            ..orderBy([(t) => OrderingTerm(expression: t.nameLower)]))
          .get();

  Future<List<ClassDefinition>> subclassesOf(String classKey) =>
      (db.select(db.classDefinitions)
            ..where((t) => t.subclassOf.equals(classKey))
            ..orderBy([(t) => OrderingTerm(expression: t.nameLower)]))
          .get();

  Stream<List<Character>> watchAll() => (db.select(
    db.characters,
  )..orderBy([(t) => OrderingTerm(expression: t.name)])).watch();

  Future<Character?> find(String id) => (db.select(
    db.characters,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<CharacterClassLevel>> classLevels(String characterId) =>
      (db.select(db.characterClassLevels)
            ..where((t) => t.characterId.equals(characterId))
            ..orderBy([(t) => OrderingTerm(expression: t.order)]))
          .get();

  Future<List<CharacterProficiency>> proficiencies(String characterId) =>
      (db.select(
        db.characterProficiencies,
      )..where((t) => t.characterId.equals(characterId))).get();

  /// Yeni bir 1. seviye karakter yazar ve id'sini dondurur.
  ///
  /// Tek islemde: karakter satiri, sinif seviyesi, yeterlilikler (sinif
  /// kurtarma atislari + secilen beceriler + background becerileri) ve
  /// baslangic altini.
  Future<String> createLevelOneCharacter({
    required String id,
    required String name,
    String? playerName,
    required String classKey,
    String? speciesKey,
    String? backgroundKey,
    required AbilityScores abilities,
    required Set<Ability> savingThrows,
    required Set<Skill> skills,
    required int hitDieSides,
    int startingGoldGp = 0,
    List<({String name, int quantity})> startingItems = const [],
  }) async {
    await db.transaction(() async {
      final constitution = abilities.modifier(Ability.constitution);
      // 1. seviyede hit die'in tam degeri alinir.
      final hp = hitDieSides + constitution;

      await db
          .into(db.characters)
          .insert(
            CharactersCompanion.insert(
              id: id,
              name: name,
              playerName: Value(playerName),
              speciesKey: Value(speciesKey),
              backgroundKey: Value(backgroundKey),
              strength: Value(abilities.strength),
              dexterity: Value(abilities.dexterity),
              constitution: Value(abilities.constitution),
              intelligence: Value(abilities.intelligence),
              wisdom: Value(abilities.wisdom),
              charisma: Value(abilities.charisma),
              hitPointsMax: Value(hp < 1 ? 1 : hp),
              hitPointsCurrent: Value(hp < 1 ? 1 : hp),
              coinsCp: Value(startingGoldGp * 100),
            ),
          );

      await db
          .into(db.characterClassLevels)
          .insert(
            CharacterClassLevelsCompanion.insert(
              characterId: id,
              classKey: classKey,
              level: const Value(1),
              order: const Value(0),
            ),
          );

      await db.batch((b) {
        b.insertAll(db.characterProficiencies, [
          for (final ability in savingThrows)
            CharacterProficienciesCompanion.insert(
              characterId: id,
              kind: ProficiencyKind.save,
              value: ability.name,
              source: const Value(ProficiencySource.characterClass),
            ),
          for (final skill in skills)
            CharacterProficienciesCompanion.insert(
              characterId: id,
              kind: ProficiencyKind.skill,
              value: skill.name,
              source: const Value(ProficiencySource.characterClass),
            ),
        ]);
      });

      // Secilen baslangic ekipmani envantere yazilir; SRD'de esyalar serbest
      // metin geldigi icin kutuphane anahtari yerine [customName] kullanilir.
      if (startingItems.isNotEmpty) {
        await db.batch((b) {
          b.insertAll(db.characterItems, [
            for (final (i, item) in startingItems.indexed)
              CharacterItemsCompanion.insert(
                id: _uuid.v4(),
                characterId: id,
                customName: Value(item.name),
                quantity: Value(item.quantity),
                sortOrder: Value(i),
              ),
          ]);
        });
      }
    });
    return id;
  }

  Stream<Character> watch(String characterId) => (db.select(
    db.characters,
  )..where((t) => t.id.equals(characterId))).watchSingle();

  /// Hasar uygular.
  ///
  /// 5e kurali: hasar once gecici canlari (temp HP) tuketir, artan kisim
  /// asil cana iner. Can sifirin altina inmez.
  Future<void> applyDamage(String characterId, int amount) async {
    if (amount <= 0) return;
    final c = await find(characterId);
    if (c == null) return;

    final absorbed = c.temporaryHitPoints >= amount
        ? amount
        : c.temporaryHitPoints;
    final toHp = amount - absorbed;

    await _update(
      characterId,
      (t) => t.copyWith(
        temporaryHitPoints: Value(c.temporaryHitPoints - absorbed),
        hitPointsCurrent: Value(
          (c.hitPointsCurrent - toHp) < 0 ? 0 : c.hitPointsCurrent - toHp,
        ),
      ),
    );
  }

  /// Iyilestirir; azami canin uzerine cikmaz.
  ///
  /// Iyilesen karakter artik olum kurtarma atisi yapmadigi icin sayaclar
  /// sifirlanir.
  Future<void> applyHealing(String characterId, int amount) async {
    if (amount <= 0) return;
    final c = await find(characterId);
    if (c == null) return;

    final next = c.hitPointsCurrent + amount;
    await _update(
      characterId,
      (t) => t.copyWith(
        hitPointsCurrent: Value(next > c.hitPointsMax ? c.hitPointsMax : next),
        deathSaveSuccesses: const Value(0),
        deathSaveFailures: const Value(0),
      ),
    );
  }

  /// Gecici can eklenmez, en yuksek olan gecerlidir (5e kurali).
  Future<void> setTemporaryHitPoints(String characterId, int amount) async {
    final c = await find(characterId);
    if (c == null) return;
    await _update(
      characterId,
      (t) => t.copyWith(
        temporaryHitPoints: Value(
          amount > c.temporaryHitPoints ? amount : c.temporaryHitPoints,
        ),
      ),
    );
  }

  Future<void> setExhaustion(String characterId, int level) => _update(
    characterId,
    (t) =>
        t.copyWith(exhaustion: Value(level < 0 ? 0 : (level > 6 ? 6 : level))),
  );

  Future<void> setInspiration(String characterId, bool value) =>
      _update(characterId, (t) => t.copyWith(inspiration: Value(value)));

  /// Karaktere XP ekler (karsilasma odulu). Seviye atlama elle yapildigi icin
  /// yalnizca toplam XP artar; negatife dusmez.
  Future<void> addExperience(String characterId, int amount) async {
    if (amount == 0) return;
    final c = await find(characterId);
    if (c == null) return;
    final next = c.experiencePoints + amount;
    await _update(
      characterId,
      (t) => t.copyWith(experiencePoints: Value(next < 0 ? 0 : next)),
    );
  }

  Future<void> setDeathSaves(
    String characterId, {
    int? successes,
    int? failures,
  }) => _update(
    characterId,
    (t) => t.copyWith(
      deathSaveSuccesses: successes == null
          ? const Value.absent()
          : Value(successes),
      deathSaveFailures: failures == null
          ? const Value.absent()
          : Value(failures),
    ),
  );

  Future<void> setCoins(String characterId, int cp) =>
      _update(characterId, (t) => t.copyWith(coinsCp: Value(cp < 0 ? 0 : cp)));

  Future<void> setNotes(String characterId, String notes) =>
      _update(characterId, (t) => t.copyWith(notes: Value(notes)));

  /// Hikaye ve kisilik alanlari (2024 kagidi). Verilmeyen alan degismez.
  Future<void> setStory(
    String characterId, {
    String? notes,
    String? appearance,
    String? personality,
    String? ideal,
    String? bond,
    String? flaw,
  }) => _update(
    characterId,
    (t) => t.copyWith(
      notes: notes == null ? const Value.absent() : Value(notes),
      appearance: appearance == null ? const Value.absent() : Value(appearance),
      personality: personality == null
          ? const Value.absent()
          : Value(personality),
      ideal: ideal == null ? const Value.absent() : Value(ideal),
      bond: bond == null ? const Value.absent() : Value(bond),
      flaw: flaw == null ? const Value.absent() : Value(flaw),
    ),
  );

  // --- Portre --------------------------------------------------------------

  /// Secilen gorseli saklar ve karaktere baglar; eskisini temizler.
  Future<void> setPortrait(String characterId, File source) async {
    final previous = await find(characterId);
    final stored = await portraits.store(source);
    await _update(characterId, (t) => t.copyWith(portraitPath: Value(stored)));
    await portraits.delete(previous?.portraitPath);
  }

  Future<void> removePortrait(String characterId) async {
    final character = await find(characterId);
    if (character == null) return;
    await portraits.delete(character.portraitPath);
    await _update(
      characterId,
      (t) => t.copyWith(portraitPath: const Value(null)),
    );
  }

  // --- Bilinen buyuler -----------------------------------------------------

  /// Karakterin bildigi buyuleri kutuphane bilgisiyle birlestirip doner.
  Future<List<KnownSpell>> knownSpells(String characterId) async {
    final rows = await (db.select(
      db.characterSpells,
    )..where((t) => t.characterId.equals(characterId))).get();
    if (rows.isEmpty) return const [];

    final keys = rows.map((r) => r.spellKey).toList();
    final spells = await (db.select(
      db.spells,
    )..where((t) => t.key.isIn(keys))).get();
    final byKey = {for (final s in spells) s.key: s};

    final result =
        <KnownSpell>[
          for (final r in rows)
            if (byKey[r.spellKey] case final s?)
              (
                spellKey: r.spellKey,
                name: s.name,
                level: s.level,
                school: s.school,
                concentration: s.concentration,
                ritual: s.ritual,
                prepared: r.prepared,
                alwaysPrepared: r.alwaysPrepared,
              ),
        ]..sort(
          (a, b) => a.level != b.level
              ? a.level.compareTo(b.level)
              : a.name.compareTo(b.name),
        );
    return result;
  }

  Future<void> addKnownSpell(
    String characterId,
    String spellKey, {
    String? classKey,
    bool prepared = false,
  }) => db
      .into(db.characterSpells)
      .insertOnConflictUpdate(
        CharacterSpellsCompanion.insert(
          characterId: characterId,
          spellKey: spellKey,
          classKey: Value(classKey),
          prepared: Value(prepared),
        ),
      );

  Future<void> removeSpell(String characterId, String spellKey) =>
      (db.delete(db.characterSpells)..where(
            (t) =>
                t.characterId.equals(characterId) & t.spellKey.equals(spellKey),
          ))
          .go();

  Future<void> togglePrepared(
    String characterId,
    String spellKey,
    bool prepared,
  ) =>
      (db.update(db.characterSpells)..where(
            (t) =>
                t.characterId.equals(characterId) & t.spellKey.equals(spellKey),
          ))
          .write(CharacterSpellsCompanion(prepared: Value(prepared)));

  static final _restRandom = Random();

  /// Uzun dinlenme: HP tam, tum yuvalar geri gelir, gecici HP silinir,
  /// tukenmislik 1 azalir, olum kurtarmalari sifirlanir.
  ///
  /// Hit dice'in YARISI (en az 1) geri gelir -- 2024 PHB: "you regain spent
  /// Hit Point Dice, up to a number equal to half your total number of them".
  /// Onceden hepsi geri veriliyordu; bu, ardisik uzun molalarla hit dice'i
  /// sinirsiz kaynaga ceviriyordu.
  Future<void> longRest(String characterId) async {
    final c = await find(characterId);
    if (c == null) return;

    final status = await hitDiceStatus(characterId);
    final recovered = (status.total ~/ 2) < 1 ? 1 : status.total ~/ 2;
    final used = <String, int>{
      for (final e in (jsonDecode(c.hitDiceUsedJson) as Map).entries)
        e.key as String: e.value as int,
    };
    // Geri kazanim siniftan sinifa dagitilir; hangi sirayla oldugu kural
    // acisindan onemsiz (oyuncu zaten hangisini harcayacagini seciyor).
    var remaining = recovered;
    for (final key in used.keys.toList()) {
      if (remaining <= 0) break;
      final give = used[key]! < remaining ? used[key]! : remaining;
      used[key] = used[key]! - give;
      remaining -= give;
      if (used[key] == 0) used.remove(key);
    }

    await _update(
      characterId,
      (t) => t.copyWith(
        hitPointsCurrent: Value(c.hitPointsMax),
        temporaryHitPoints: const Value(0),
        spellSlotsUsedJson: const Value('{}'),
        hitDiceUsedJson: Value(jsonEncode(used)),
        deathSaveSuccesses: const Value(0),
        deathSaveFailures: const Value(0),
        exhaustion: Value(c.exhaustion > 0 ? c.exhaustion - 1 : 0),
      ),
    );
  }

  /// Kisa dinlenme: bir hit die harcayip iyilesir (hit die + CON). Bos hit
  /// die yoksa `null` doner. Iyilesilen HP'yi doner.
  /// Harcanan hit die'in ayrintisi.
  ///
  /// Yalnizca iyilesen can degil ZARIN KENDISI de doner: oyuncu panelinde
  /// atis kendi zar animasyonuyla gosteriliyor, bunun icin kac yuzlu zarin
  /// kac geldigi gerekiyor.
  Future<HitDieSpend?> spendHitDie(String characterId) async {
    final c = await find(characterId);
    if (c == null) return null;

    final levels = await classLevels(characterId);
    final defs = await _classDefinitions(
      levels.map((l) => l.classKey).toList(),
    );
    final used = <String, int>{
      for (final e in (jsonDecode(c.hitDiceUsedJson) as Map).entries)
        e.key as String: e.value as int,
    };

    for (final level in levels) {
      final u = used[level.classKey] ?? 0;
      if (u >= level.level) continue; // bu sinifta hit die kalmadi
      final sides = _hitDieSides(defs[level.classKey]?.hitDice);
      final con = ((c.constitution - 10) / 2).floor();
      final roll = _restRandom.nextInt(sides) + 1;
      final heal = (roll + con).clamp(1, 1 << 20);
      used[level.classKey] = u + 1;
      final newHp = (c.hitPointsCurrent + heal).clamp(0, c.hitPointsMax);
      await _update(
        characterId,
        (t) => t.copyWith(
          hitPointsCurrent: Value(newHp),
          hitDiceUsedJson: Value(jsonEncode(used)),
        ),
      );
      return (
        sides: sides,
        roll: roll,
        conModifier: con,
        // Can zaten doluysa iyilesme 0 olabilir; zar yine de harcanir.
        healed: newHp - c.hitPointsCurrent,
      );
    }
    return null; // hic bos hit die yok
  }

  /// Toplam ve kullanilmis hit dice (kisa dinlenme arayuzu icin).
  Future<({int total, int used})> hitDiceStatus(String characterId) async {
    final c = await find(characterId);
    if (c == null) return (total: 0, used: 0);
    final levels = await classLevels(characterId);
    final total = levels.fold(0, (sum, l) => sum + l.level);
    final usedMap = jsonDecode(c.hitDiceUsedJson) as Map;
    final used = usedMap.values.fold(0, (sum, v) => sum + (v as int));
    return (total: total, used: used);
  }

  /// Harcanmis buyu yuvalari: yuva seviyesi -> adet.
  Future<void> setSpentSlots(String characterId, Map<int, int> spent) =>
      _update(
        characterId,
        (t) => t.copyWith(
          spellSlotsUsedJson: Value(
            jsonEncode(spent.map((k, v) => MapEntry('$k', v))),
          ),
        ),
      );

  Future<void> _update(
    String characterId,
    CharactersCompanion Function(CharactersCompanion) build,
  ) async {
    await (db.update(db.characters)..where((t) => t.id.equals(characterId)))
        .write(build(CharactersCompanion(updatedAt: Value(DateTime.now()))));
  }

  /// Seviye atlamadan once ne kazanilacagini hesaplar.
  ///
  /// Arayuz bunu gosterip onay aliyor; hicbir sey yazilmaz.
  Future<LevelUpPreview> previewLevelUp({
    required String characterId,
    required String classKey,
    String? subclassKey,
  }) async {
    final existing =
        await (db.select(db.characterClassLevels)..where(
              (t) =>
                  t.characterId.equals(characterId) &
                  t.classKey.equals(classKey),
            ))
            .getSingleOrNull();
    final newLevel = (existing?.level ?? 0) + 1;

    final definition = (await _classDefinitions([classKey]))[classKey];
    final featureKeys = await featureKeysAt(classKey, newLevel);

    final byKey = <String, Map<String, dynamic>>{};
    if (definition != null) {
      for (final f
          in ((jsonDecode(definition.dataJson) as Map)['features'] as List? ??
                  const [])
              .cast<Map<String, dynamic>>()) {
        byKey['${f['key']}'] = f;
      }
    }

    // Alt sinifin bu seviyedeki yetenekleri de listeye girer; oyuncu neyin
    // geldigini tek yerde gorsun. [subclassKey] arayuzde HENUZ SECILMIS ama
    // kaydedilmemis alt sinifi tasir -- yalnizca kaydedilmis olana (existing)
    // bakarsak kullanici farkli bir cip secince onizleme degismezdi (hep ayni
    // -- ya bos ya da onceki -- aciklamayi gosterirdi).
    final effectiveSubclassKey = subclassKey ?? existing?.subclassKey;
    ClassDefinition? subclassDefinition;
    if (effectiveSubclassKey != null) {
      subclassDefinition = (await _classDefinitions([
        effectiveSubclassKey,
      ]))[effectiveSubclassKey];
      if (subclassDefinition != null) {
        for (final f
            in ((jsonDecode(subclassDefinition.dataJson) as Map)['features']
                        as List? ??
                    const [])
                .cast<Map<String, dynamic>>()) {
          byKey['${f['key']}'] = f;
        }
      }
      featureKeys.addAll(await featureKeysAt(effectiveSubclassKey, newLevel));
    }

    // SRD'nin "alt sinif sec" yetenegi ("Ranger Subclass" gibi) aciklamasi
    // her zaman TEK sinif-varsayilan alt sinifi ADIYLA anar (ör. "The Hunter
    // subclass is detailed after..."), cunku SRD 5.2 sinif basina yalnizca
    // bir alt sinif icerir. Uygulama coklu (ozel) alt sinifi destekledigi
    // icin bu metin secilen baska bir alt sinifle celisiyordu -- secili alt
    // sinifin KENDI aciklamasiyla degistirilir.
    final subclassChoiceDesc = subclassDefinition == null
        ? null
        : '${(jsonDecode(subclassDefinition.dataJson) as Map)['desc'] ?? ''}';

    return LevelUpPreview(
      classKey: classKey,
      className: definition?.name ?? classKey,
      newLevel: newLevel,
      hitDieSides: _hitDieSides(definition?.hitDice),
      isNewClass: existing == null,
      currentSubclassKey: existing?.subclassKey,
      features: [
        for (final key in featureKeys)
          (
            key: key,
            name: '${byKey[key]?['name'] ?? key}',
            description:
                key.contains('subclass') &&
                    subclassChoiceDesc != null &&
                    subclassChoiceDesc.isNotEmpty
                ? subclassChoiceDesc
                : '${byKey[key]?['desc'] ?? ''}',
          ),
      ],
      // SRD'de bu iki secim birer "feature" olarak geliyor; anahtardan
      // taniniyorlar.
      grantsSubclass: featureKeys.any((k) => k.contains('subclass')),
      grantsAbilityIncrease: featureKeys.any(
        (k) => k.contains('ability-score-improvement'),
      ),
    );
  }

  /// Bir seviye atlar.
  ///
  /// Var olan bir sinifin seviyesini artirir; [classKey] karakterde yoksa
  /// multiclass olarak yeni satir acilir. Tek islemde HP, seviye, alt sinif,
  /// ASI ve yeni yetenekler birlikte yazilir ki yarim kalmis bir seviye
  /// olusmasin.
  ///
  /// [hitPointRoll] verilmezse ortalama kullanilir. Ilk sinifin 1. seviyesi
  /// bu akistan gecmez (karakter olusturmada veriliyor).
  Future<void> levelUp({
    required String characterId,
    required String classKey,
    int? hitPointRoll,
    String? subclassKey,
    Map<Ability, int> abilityIncreases = const {},
  }) async {
    await db.transaction(() async {
      final character = await find(characterId);
      if (character == null) return;

      final existing =
          await (db.select(db.characterClassLevels)..where(
                (t) =>
                    t.characterId.equals(characterId) &
                    t.classKey.equals(classKey),
              ))
              .getSingleOrNull();

      final definition = (await _classDefinitions([classKey]))[classKey];
      final hitDieSides = _hitDieSides(definition?.hitDice);

      // ASI once uygulanir: CON artisi bu seviyenin HP'sine de yansimali.
      final abilities = _applyIncreases(character, abilityIncreases);
      final constitution = abilities.modifier(Ability.constitution);

      final roll = hitPointRoll ?? CharacterMath.averageHitDie(hitDieSides);
      final newLevel = (existing?.level ?? 0) + 1;

      if (existing == null) {
        final others = await classLevels(characterId);
        await db
            .into(db.characterClassLevels)
            .insert(
              CharacterClassLevelsCompanion.insert(
                characterId: characterId,
                classKey: classKey,
                level: const Value(1),
                order: Value(others.length),
                subclassKey: Value(subclassKey),
                hitPointRollsJson: Value(jsonEncode([roll])),
              ),
            );
      } else {
        final rolls = (jsonDecode(existing.hitPointRollsJson) as List)
            .cast<int>();
        await (db.update(db.characterClassLevels)..where(
              (t) =>
                  t.characterId.equals(characterId) &
                  t.classKey.equals(classKey),
            ))
            .write(
              CharacterClassLevelsCompanion(
                level: Value(newLevel),
                subclassKey: subclassKey == null
                    ? const Value.absent()
                    : Value(subclassKey),
                hitPointRollsJson: Value(jsonEncode([...rolls, roll])),
              ),
            );
      }

      // ASI ile CON degistiyse gecmis seviyelerin HP'si de degisir; bu
      // yuzden azami can bastan hesaplaniyor.
      final gained = roll + constitution;
      final conDelta =
          constitution -
          AbilityScores(
            strength: character.strength,
            dexterity: character.dexterity,
            constitution: character.constitution,
            intelligence: character.intelligence,
            wisdom: character.wisdom,
            charisma: character.charisma,
          ).modifier(Ability.constitution);
      // Bu sorgu seviye yazildiktan SONRA calisiyor, yani yeni seviye dahil.
      final totalLevelAfter = (await classLevels(
        characterId,
      )).fold<int>(0, (sum, c) => sum + c.level);
      // Yeni seviyenin CON'u `gained` icinde; geriye kalan seviyeler icin
      // yalnizca CON farki eklenir.
      final newMax =
          character.hitPointsMax + gained + conDelta * (totalLevelAfter - 1);

      await (db.update(
        db.characters,
      )..where((t) => t.id.equals(characterId))).write(
        CharactersCompanion(
          hitPointsMax: Value(newMax < 1 ? 1 : newMax),
          hitPointsCurrent: Value(
            character.hitPointsCurrent + gained + conDelta,
          ),
          strength: Value(abilities.strength),
          dexterity: Value(abilities.dexterity),
          constitution: Value(abilities.constitution),
          intelligence: Value(abilities.intelligence),
          wisdom: Value(abilities.wisdom),
          charisma: Value(abilities.charisma),
          updatedAt: Value(DateTime.now()),
        ),
      );

      await _recordFeatures(
        characterId,
        classKey,
        newLevel,
        chosenSubclassKey: subclassKey,
      );
      // Alt sinif secildiyse onun yetenekleri de kagida girer.
      final chosenSubclass =
          subclassKey ??
          (await (db.select(db.characterClassLevels)..where(
                    (t) =>
                        t.characterId.equals(characterId) &
                        t.classKey.equals(classKey),
                  ))
                  .getSingleOrNull())
              ?.subclassKey;
      if (chosenSubclass != null) {
        await _recordFeatures(characterId, chosenSubclass, newLevel);
      }
    });
  }

  /// Bu seviyede kazanilan yetenekleri karakter kagidina isler.
  ///
  /// [chosenSubclassKey] yalnizca [classKey] TEMEL sinif iken ve bu seviyede
  /// alt sinif seciliyorsa verilir; SRD'nin "alt sinif sec" yetenegi hep
  /// sinifin TEK varsayilan alt sinifini adiyla anan sabit bir metin tasidigi
  /// icin (bkz. `previewLevelUp`), o metin secilen GERCEK alt sinifin kendi
  /// aciklamasiyla degistirilir -- yoksa kagitta yanlis alt sinif adi kalirdi.
  Future<void> _recordFeatures(
    String characterId,
    String classKey,
    int level, {
    String? chosenSubclassKey,
  }) async {
    final keys = await featureKeysAt(classKey, level);
    if (keys.isEmpty) return;

    final definition = (await _classDefinitions([classKey]))[classKey];
    if (definition == null) return;

    final byKey = <String, Map<String, dynamic>>{};
    for (final f
        in ((jsonDecode(definition.dataJson) as Map)['features'] as List? ??
                const [])
            .cast<Map<String, dynamic>>()) {
      byKey['${f['key']}'] = f;
    }

    String? subclassChoiceDesc;
    if (chosenSubclassKey != null) {
      final subclassDefinition = (await _classDefinitions([
        chosenSubclassKey,
      ]))[chosenSubclassKey];
      if (subclassDefinition != null) {
        subclassChoiceDesc =
            '${(jsonDecode(subclassDefinition.dataJson) as Map)['desc'] ?? ''}';
      }
    }

    await db.batch((b) {
      b.insertAll(db.characterFeatures, [
        for (final key in keys)
          if (byKey[key] case final feature?)
            CharacterFeaturesCompanion.insert(
              id: '$characterId:$key',
              characterId: characterId,
              featureKey: Value(key),
              name: '${feature['name'] ?? key}',
              description: Value(
                key.contains('subclass') &&
                        subclassChoiceDesc != null &&
                        subclassChoiceDesc.isNotEmpty
                    ? subclassChoiceDesc
                    : '${feature['desc'] ?? ''}',
              ),
              source: Value(classKey),
              gainedAtLevel: Value(level),
            ),
      ], mode: InsertMode.insertOrReplace);
    });
  }

  static AbilityScores _applyIncreases(
    Character character,
    Map<Ability, int> increases,
  ) => AbilityScores(
    strength: character.strength,
    dexterity: character.dexterity,
    constitution: character.constitution,
    intelligence: character.intelligence,
    wisdom: character.wisdom,
    charisma: character.charisma,
  ).plus(increases);

  /// Karakterin sahip oldugu yetenekler.
  Future<List<CharacterFeature>> features(String characterId) =>
      (db.select(db.characterFeatures)
            ..where((t) => t.characterId.equals(characterId))
            ..orderBy([(t) => OrderingTerm(expression: t.gainedAtLevel)]))
          .get();

  /// Elle eklenen (homebrew) bir yetenek/ozellik. `source: 'manual'` ile
  /// SRD/alt-sinif kaynaklilardan ayrilir; yalnizca bunlar silinebilir/
  /// duzenlenebilir (karakter kagidinda kaynagi belirsiz otomatik satirlar
  /// kurcalanmaz).
  Future<String> addManualFeature(
    String characterId, {
    required String name,
    String description = '',
    int? usesMax,
  }) async {
    final id = _uuid.v4();
    await db
        .into(db.characterFeatures)
        .insert(
          CharacterFeaturesCompanion.insert(
            id: id,
            characterId: characterId,
            name: name,
            description: Value(description),
            source: const Value('manual'),
            usesMax: Value(usesMax),
          ),
        );
    return id;
  }

  Future<void> updateManualFeature(
    String id, {
    required String name,
    String description = '',
    int? usesMax,
  }) => (db.update(db.characterFeatures)..where((t) => t.id.equals(id))).write(
    CharacterFeaturesCompanion(
      name: Value(name),
      description: Value(description),
      usesMax: Value(usesMax),
    ),
  );

  Future<void> deleteFeature(String id) =>
      (db.delete(db.characterFeatures)..where((t) => t.id.equals(id))).go();

  /// Sinirli kullanimli bir yetenegin (ör. Second Wind) harcanan kullanim
  /// sayisi; 0 ile [usesMax] arasinda kirpilir.
  Future<void> setFeatureUsesSpent(String id, int usesSpent) async {
    final row = await (db.select(
      db.characterFeatures,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return;
    final max = row.usesMax;
    final clamped = max == null
        ? (usesSpent < 0 ? 0 : usesSpent)
        : usesSpent.clamp(0, max);
    await (db.update(db.characterFeatures)..where((t) => t.id.equals(id)))
        .write(CharacterFeaturesCompanion(usesSpent: Value(clamped)));
  }

  // --- Envanter -----------------------------------------------------------

  Stream<List<CharacterItem>> watchItems(String characterId) =>
      (db.select(db.characterItems)
            ..where((t) => t.characterId.equals(characterId))
            ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
          .watch();

  Future<List<CharacterItem>> items(String characterId) =>
      (db.select(db.characterItems)
            ..where((t) => t.characterId.equals(characterId))
            ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
          .get();

  /// Envantere esya ekler; ayni esya zaten varsa adedini artirir.
  ///
  /// Stack mantigi: satin alma ya da elle ekleme sonucu "3 ayri hancer"
  /// yerine "hancer x3" gorunsun. Serbest metin esyalar ada gore staklanir.
  Future<void> addItem({
    required String characterId,
    String? itemKey,
    String? magicItemKey,
    String? customName,
    String? customDesc,
    int quantity = 1,
  }) async {
    final existing = await items(characterId);

    CharacterItem? match;
    for (final row in existing) {
      final same =
          (itemKey != null && row.itemKey == itemKey) ||
          (magicItemKey != null && row.magicItemKey == magicItemKey) ||
          (customName != null &&
              itemKey == null &&
              magicItemKey == null &&
              row.customName == customName);
      if (same) {
        match = row;
        break;
      }
    }

    if (match != null) {
      await (db.update(
        db.characterItems,
      )..where((t) => t.id.equals(match!.id))).write(
        CharacterItemsCompanion(quantity: Value(match.quantity + quantity)),
      );
      return;
    }

    await db
        .into(db.characterItems)
        .insert(
          CharacterItemsCompanion.insert(
            id: _uuid.v4(),
            characterId: characterId,
            itemKey: Value(itemKey),
            magicItemKey: Value(magicItemKey),
            customName: Value(customName),
            customDesc: Value(customDesc),
            quantity: Value(quantity),
            sortOrder: Value(existing.length),
          ),
        );
  }

  /// Adedi degistirir; sifir ya da alti silinir.
  Future<void> setItemQuantity(String itemId, int quantity) async {
    if (quantity <= 0) {
      await (db.delete(
        db.characterItems,
      )..where((t) => t.id.equals(itemId))).go();
      return;
    }
    await (db.update(db.characterItems)..where((t) => t.id.equals(itemId)))
        .write(CharacterItemsCompanion(quantity: Value(quantity)));
  }

  Future<void> setEquipped(String itemId, bool value) async {
    await (db.update(db.characterItems)..where((t) => t.id.equals(itemId)))
        .write(CharacterItemsCompanion(equipped: Value(value)));
  }

  Future<void> setAttuned(String itemId, bool value) async {
    await (db.update(db.characterItems)..where((t) => t.id.equals(itemId)))
        .write(CharacterItemsCompanion(attuned: Value(value)));
  }

  Future<void> removeItem(String itemId) async {
    await (db.delete(
      db.characterItems,
    )..where((t) => t.id.equals(itemId))).go();
  }

  /// Bir esyayi (adet kadar) bir karakterden digerine tasir. Atomik.
  ///
  /// Kaynak satirdan adet dusulur (sifirlanirsa silinir), hedefe anahtarlari
  /// korunarak eklenir (ada/anahtara gore staklanir). Kusanma/baglanma (equip/
  /// attune) TASINMAZ -- yeni sahip kendi kusanir. Esya yoksa ya da adet
  /// yetmiyorsa hicbir sey yapmaz ve false doner.
  Future<bool> transferItem({
    required String itemId,
    required String toCharacterId,
    int quantity = 1,
  }) => db.transaction(() async {
    if (quantity <= 0) return false;
    final row = await (db.select(
      db.characterItems,
    )..where((t) => t.id.equals(itemId))).getSingleOrNull();
    if (row == null || row.quantity < quantity) return false;
    if (row.characterId == toCharacterId) return false; // kendine gonderemez

    await setItemQuantity(itemId, row.quantity - quantity);
    await addItem(
      characterId: toCharacterId,
      itemKey: row.itemKey,
      magicItemKey: row.magicItemKey,
      customName: row.customName,
      customDesc: row.customDesc,
      quantity: quantity,
    );
    return true;
  });

  /// Bir karakterden digerine para aktarir (cp). Yeterli para yoksa false.
  Future<bool> transferCoins({
    required String fromCharacterId,
    required String toCharacterId,
    required int amountCp,
  }) => db.transaction(() async {
    if (amountCp <= 0 || fromCharacterId == toCharacterId) return false;
    final from = await find(fromCharacterId);
    final to = await find(toCharacterId);
    if (from == null || to == null || from.coinsCp < amountCp) return false;

    await setCoins(fromCharacterId, from.coinsCp - amountCp);
    await setCoins(toCharacterId, to.coinsCp + amountCp);
    return true;
  });

  /// Bir eşyanın kütüphanedeki adı; envanter arayüzü için.
  Future<String> itemDisplayName(CharacterItem item) async {
    if (item.customName != null) return item.customName!;
    if (item.itemKey != null) {
      final row = await (db.select(
        db.items,
      )..where((t) => t.key.equals(item.itemKey!))).getSingleOrNull();
      if (row != null) return row.name;
    }
    if (item.magicItemKey != null) {
      final row = await (db.select(
        db.magicItems,
      )..where((t) => t.key.equals(item.magicItemKey!))).getSingleOrNull();
      if (row != null) return row.name;
    }
    // Bos ad: gosterim katmani dile gore "Bilinmeyen eşya / Unknown item" koyar.
    return '';
  }

  /// Ham `customStatement` Drift'in tablo-degisti akislarini (`.watch()`)
  /// tetiklemez -- karakter listesi silindikten sonra ekranda kalmaya devam
  /// ederdi (yeniden acilana kadar). Tipli silme API'si kullanilir.
  Future<void> delete(String characterId) async {
    await db.transaction(() async {
      await (db.delete(
        db.characterProficiencies,
      )..where((t) => t.characterId.equals(characterId))).go();
      await (db.delete(
        db.characterClassLevels,
      )..where((t) => t.characterId.equals(characterId))).go();
      await (db.delete(
        db.characterItems,
      )..where((t) => t.characterId.equals(characterId))).go();
      await (db.delete(
        db.characterSpells,
      )..where((t) => t.characterId.equals(characterId))).go();
      await (db.delete(
        db.characterFeatures,
      )..where((t) => t.characterId.equals(characterId))).go();
      await (db.delete(
        db.characters,
      )..where((t) => t.id.equals(characterId))).go();
    });
  }

  /// Kural motorunun uzerinde calisacagi anlik goruntuyu kurar.
  ///
  /// Sinif meta verisi (hit die, caster type) kutuphaneden okunur; boylece
  /// homebrew bir sinif eklendiginde de dogru calisir.
  Future<CharacterBuild> buildFor(String characterId) async {
    final character = await find(characterId);
    if (character == null) {
      throw StateError('Karakter bulunamadı: $characterId');
    }

    final levels = await classLevels(characterId);
    final definitions = await _classDefinitions(
      levels.map((l) => l.classKey).toList(),
    );

    final classes = <ClassLevel>[];
    final hitPointRolls = <String, List<int>>{};
    for (final level in levels) {
      final def = definitions[level.classKey];
      classes.add(
        ClassLevel(
          classKey: level.classKey,
          subclassKey: level.subclassKey,
          level: level.level,
          casterType: CasterType.parse(def?.casterType),
          hitDieSides: _hitDieSides(def?.hitDice),
          isPrimary: level.order == 0,
        ),
      );
      hitPointRolls[level.classKey] =
          (jsonDecode(level.hitPointRollsJson) as List).cast<int>();
    }

    final profs = await proficiencies(characterId);
    final skills = <Skill>{};
    final expertise = <Skill>{};
    final saves = <Ability>{};
    for (final p in profs) {
      switch (p.kind) {
        case ProficiencyKind.skill:
          final skill = Skill.fromName(p.value);
          if (skill != null) {
            skills.add(skill);
            if (p.expertise) expertise.add(skill);
          }
        case ProficiencyKind.save:
          final ability = Ability.fromName(p.value);
          if (ability != null) saves.add(ability);
        case _:
          break;
      }
    }

    final gear = await _equippedDefense(characterId);

    return CharacterBuild(
      abilities: AbilityScores(
        strength: character.strength,
        dexterity: character.dexterity,
        constitution: character.constitution,
        intelligence: character.intelligence,
        wisdom: character.wisdom,
        charisma: character.charisma,
      ),
      classes: classes,
      skillProficiencies: skills,
      skillExpertise: expertise,
      saveProficiencies: saves,
      armor: gear.armor,
      hasShield: gear.hasShield,
      unarmoredDefenseAbility: _unarmoredDefenseFor(classes),
      exhaustion: character.exhaustion,
      hitPointRolls: hitPointRolls,
    );
  }

  /// Karakterin sahip oldugu buyu yuvalari: yuva seviyesi -> adet.
  ///
  /// Tek sinifta sinifin kendi tablosu, multiclass'ta birlesik buyucu
  /// seviyesiyle tam buyucu tablosu kullanilir.
  Future<Map<int, int>> spellSlots(CharacterBuild build) async {
    final casters = build.classes
        .where((c) => c.casterType != CasterType.none)
        .toList();
    if (casters.isEmpty) return const {};

    final ordinary = casters
        .where((c) => c.casterType != CasterType.pact)
        .toList();
    if (ordinary.isEmpty) return const {};

    if (ordinary.length == 1 && build.classes.length == 1) {
      return _slotsFrom(ordinary.single.classKey, ordinary.single.level);
    }

    final casterLevel = build.combinedCasterLevel;
    if (casterLevel < 1) return const {};
    return _slotsFrom(_fullCasterReferenceClass, casterLevel);
  }

  /// Warlock'un Pact Magic havuzu: (yuva seviyesi, adet).
  ///
  /// Ortak yuva havuzundan ayridir ve kagitta ayri gosterilir.
  Future<({int slotLevel, int count})?> pactMagic(CharacterBuild build) async {
    final warlockLevel = build.pactCasterLevel;
    if (warlockLevel < 1) return null;

    final warlock = build.classes.firstWhere(
      (c) => c.casterType == CasterType.pact,
    );
    final row = await _progression(warlock.classKey, warlockLevel);
    if (row == null) return null;

    final table = (jsonDecode(row.classTableJson) as Map)
        .cast<String, dynamic>();
    final count = int.tryParse('${table['Spell Slots'] ?? ''}');
    // "3rd" -> 3
    final levelText = '${table['Slot Level'] ?? ''}';
    final slotLevel = int.tryParse(
      RegExp(r'\d+').firstMatch(levelText)?.group(0) ?? '',
    );
    if (count == null || slotLevel == null) return null;
    return (slotLevel: slotLevel, count: count);
  }

  /// Karakterin sinif ve alt sinif sayaclari: "Rages 3", "Üstünlük Zarı 4".
  ///
  /// Her sinifin kendi seviyesindeki tablo sutunlari toplanir; alt sinif
  /// varsa onunkiler de eklenir. Karakter kagidi bunlari ayrica hesaplamaz.
  Future<Map<String, String>> classResources(String characterId) async {
    final levels = await classLevels(characterId);
    final resources = <String, String>{};

    for (final level in levels) {
      for (final key in [level.classKey, level.subclassKey]) {
        if (key == null) continue;
        final row = await _progression(key, level.level);
        if (row == null) continue;

        final table = (jsonDecode(row.classTableJson) as Map)
            .cast<String, dynamic>();
        for (final entry in table.entries) {
          // Yeterlilik bonusu kagitta zaten ayri gosteriliyor.
          if (entry.key == 'Proficiency Bonus') continue;
          resources[entry.key] = '${entry.value}';
        }
      }
    }
    return resources;
  }

  /// Bu seviyede kazanilan sinif yetenekleri; level atlama akisinda kullanilir.
  Future<List<String>> featureKeysAt(String classKey, int level) async {
    final row = await _progression(classKey, level);
    if (row == null) return <String>[];
    return (jsonDecode(row.featureKeysJson) as List).cast<String>().toList();
  }

  Future<Map<int, int>> _slotsFrom(String classKey, int level) async {
    final row = await _progression(classKey, level);
    if (row == null) return const {};
    final raw = (jsonDecode(row.spellSlotsJson) as Map).cast<String, dynamic>();
    return {
      for (final e in raw.entries)
        if (int.tryParse(e.key) case final slot?)
          if (e.value is int) slot: e.value as int,
    };
  }

  Future<ClassProgression?> _progression(String classKey, int level) =>
      (db.select(db.classProgressions)
            ..where((t) => t.classKey.equals(classKey) & t.level.equals(level)))
          .getSingleOrNull();

  Future<Map<String, ClassDefinition>> _classDefinitions(
    List<String> keys,
  ) async {
    if (keys.isEmpty) return const {};
    final rows = await (db.select(
      db.classDefinitions,
    )..where((t) => t.key.isIn(keys))).get();
    return {for (final r in rows) r.key: r};
  }

  /// Giyili zirh ve kalkani envanterden cikarir.
  Future<({ArmorPiece? armor, bool hasShield})> _equippedDefense(
    String characterId,
  ) async {
    final equipped =
        await (db.select(db.characterItems)..where(
              (t) =>
                  t.characterId.equals(characterId) & t.equipped.equals(true),
            ))
            .get();
    if (equipped.isEmpty) return (armor: null, hasShield: false);

    final itemKeys = equipped
        .map((e) => e.itemKey)
        .whereType<String>()
        .toList();
    final magicKeys = equipped
        .map((e) => e.magicItemKey)
        .whereType<String>()
        .toList();

    final payloads = <Map<String, dynamic>>[];
    if (itemKeys.isNotEmpty) {
      for (final row in await (db.select(
        db.items,
      )..where((t) => t.key.isIn(itemKeys))).get()) {
        payloads.add(jsonDecode(row.dataJson) as Map<String, dynamic>);
      }
    }
    if (magicKeys.isNotEmpty) {
      for (final row in await (db.select(
        db.magicItems,
      )..where((t) => t.key.isIn(magicKeys))).get()) {
        payloads.add(jsonDecode(row.dataJson) as Map<String, dynamic>);
      }
    }

    ArmorPiece? armor;
    var hasShield = false;
    for (final payload in payloads) {
      final data = payload['armor'];
      if (data is! Map) continue;
      final baseAc = data['ac_base'] as int?;
      if (baseAc == null) continue;

      // Kalkan zirh yerine gecmez, ustune eklenir.
      if ('${data['category'] ?? ''}'.toLowerCase() == 'shield' ||
          '${payload['name'] ?? ''}'.toLowerCase().contains('shield')) {
        hasShield = true;
        continue;
      }
      armor = ArmorPiece(
        baseAc: baseAc,
        addDexModifier: data['ac_add_dexmod'] == true,
        maxDexModifier: data['ac_cap_dexmod'] as int?,
        stealthDisadvantage: data['stealth_disadvantage'] == true,
        strengthRequired: data['strength_score_required'] as int?,
      );
    }
    return (armor: armor, hasShield: hasShield);
  }

  /// Barbarian CON, Monk WIS ile zirhsiz savunma kazanir.
  static Ability? _unarmoredDefenseFor(List<ClassLevel> classes) {
    for (final c in classes) {
      final name = c.classKey.split('_').last;
      if (name == 'barbarian') return Ability.constitution;
      if (name == 'monk') return Ability.wisdom;
    }
    return null;
  }

  /// "D12" -> 12.
  static int _hitDieSides(String? hitDice) =>
      int.tryParse(hitDice?.replaceAll(RegExp('[^0-9]'), '') ?? '') ?? 8;
}
