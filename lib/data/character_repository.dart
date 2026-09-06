import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/models/ability.dart';
import '../domain/models/character_build.dart';
import '../domain/rules/character_math.dart';
import '../domain/rules/equipment_slots.dart';
import '../domain/rules/granted_spells.dart';
import '../domain/rules/origin_parsing.dart';
import '../domain/rules/proficiency_parsing.dart';
import '../domain/rules/spell_casting.dart';
import '../domain/rules/spell_preparation.dart';
import '../domain/search_text.dart';
import 'character_image_store.dart';
import 'db/character_tables.dart';
import 'db/database.dart';

/// Kusanma denemesinin sonucu.
enum EquipOutcome {
  ok,

  /// Yuvanin siniri dolu; arayuz kullaniciya once yer acmasini soyler.
  slotFull,

  /// Esya bulunamadi (silinmis olabilir).
  missing;

  bool get isOk => this == EquipOutcome.ok;
}

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
    String? originFeatName,
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

      // Gecmisin verdigi koken feat'i ("Magic Initiate (Cleric)") sihirbazda
      // gosteriliyor ama kagida yazilmiyordu.
      if (originFeatName != null) {
        final key = await featKeyByName(originFeatName);
        if (key != null) await _grantFeat(id, key);
      }

      // 1. seviye yetenekleri de kagida girsin: seviye atlama akisi yalnizca
      // 2 ve sonrasini isliyor, yeni karakterin kagidi bos aciliyordu.
      await _syncClassContent(id);
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
  /// Hasar uygular ve konsantrasyon tutuluyorsa kurtarma DC'sini doner.
  ///
  /// Kurtarma atisini masada oyuncu yapiyor; burada yalnizca "hangi DC" ve
  /// "can sifirlandiysa konsantrasyon zaten bitti" kurali isliyor.
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
        // Can sifirlanirsa konsantrasyon kendiliginden biter.
        concentrationSpell: (c.hitPointsCurrent - toHp) <= 0
            ? const Value(null)
            : const Value.absent(),
      ),
    );
  }

  /// Hasar alan bir buyucunun konsantrasyon kurtarmasi.
  ///
  /// 5e: DC, alinan hasarin yarisi (en az 10). Konsantrasyon tutulmuyorsa
  /// `null` doner.
  static int? concentrationSaveDc(int damage) {
    if (damage <= 0) return null;
    final half = damage ~/ 2;
    return half < 10 ? 10 : half;
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

  // --- Yaratildiktan sonra duzenleme ---------------------------------------
  //
  // Sihirbaz yalnizca 1. seviyeyi kuruyor; masada yanlis yazilmis bir ad ya da
  // "aslinda Cleric olacakti" gibi kararlar sonradan geliyor. Buradaki her
  // islem TEK transaction'da tamamlaniyor ve can, yetenek, yeterlilik gibi
  // turetilmis degerleri kendisi toparliyor -- yarim kalmis bir duzenleme
  // kagidi tutarsiz birakirdi.

  /// Ad, oyuncu adi ve hizalama.
  Future<void> updateIdentity(
    String characterId, {
    required String name,
    String? playerName,
    String? alignment,
  }) => _update(
    characterId,
    (t) => t.copyWith(
      name: Value(name.trim()),
      playerName: Value(_emptyToNull(playerName)),
      alignment: Value(_emptyToNull(alignment)),
    ),
  );

  /// Nihai yetenek puanlari (kagitta gorunen degerler).
  ///
  /// CON degisirse azami can da kayar: kural motorunun hesapladigi can
  /// FARKI mevcut cana uygulanir, boylece DM'in elle yaptigi duzeltmeler
  /// (or. sihirli bir kalici bonus) korunur.
  Future<void> setAbilityScores(String characterId, AbilityScores scores) =>
      db.transaction(
        () => _keepingHitPointsInSync(characterId, () async {
          await _update(
            characterId,
            (t) => t.copyWith(
              strength: Value(scores.strength),
              dexterity: Value(scores.dexterity),
              constitution: Value(scores.constitution),
              intelligence: Value(scores.intelligence),
              wisdom: Value(scores.wisdom),
              charisma: Value(scores.charisma),
            ),
          );
        }),
      );

  /// Azami cani elle ayarlar; mevcut can yeni tavani asamaz.
  Future<void> setHitPointsMax(String characterId, int max) async {
    final character = await find(characterId);
    if (character == null) return;
    final clamped = max < 1 ? 1 : max;
    await _update(
      characterId,
      (t) => t.copyWith(
        hitPointsMax: Value(clamped),
        hitPointsCurrent: Value(
          character.hitPointsCurrent > clamped
              ? clamped
              : character.hitPointsCurrent,
        ),
      ),
    );
  }

  /// AC ve hiz icin elle deger. `null` verilirse hesaplanan degere donulur.
  Future<void> setOverrides(
    String characterId, {
    required int? armorClass,
    required int? speed,
  }) => _update(
    characterId,
    (t) => t.copyWith(
      armorClassOverride: Value(armorClass),
      speedOverride: Value(speed),
    ),
  );

  /// Turu degistirir. Tur yeterlilik satiri yazmadigi icin yalnizca anahtar
  /// degisir; boyut ve hiz kagitta tur verisinden okundugu icin kendiliginden
  /// guncellenir.
  /// Turu degistirir ve turden TURETILEN her seyi yeniden hesaplar.
  ///
  /// Tur satiri tek basina yazilinca kagit eski turun hizini ve yeterliliklerini
  /// gostermeye devam ediyordu; duzenleme ekranindan tur degistirmek gorunurde
  /// hicbir sey yapmiyordu. Arka plandaki hesap [buildFor] icinde turden
  /// okundugu icin burada yalnizca turetilmis yeterlilikleri tazelemek yetiyor.
  Future<void> setSpecies(String characterId, String? speciesKey) async {
    await _update(
      characterId,
      (t) => t.copyWith(speciesKey: Value(speciesKey)),
    );
    await syncDerivedProficiencies(characterId);
  }

  /// Turun hiz/boyut ozellikleri; tur yoksa ya da veri okunamazsa null.
  Future<SpeciesTraits?> speciesTraits(String? speciesKey) async {
    if (speciesKey == null) return null;
    final row = await (db.select(
      db.speciesEntries,
    )..where((t) => t.key.equals(speciesKey))).getSingleOrNull();
    if (row == null) return null;
    final data = jsonDecode(row.dataJson) as Map<String, dynamic>;
    return parseSpeciesTraits(data['traits'] as List? ?? const []);
  }

  /// Gecmisi degistirir ve verdigi beceri yeterliliklerini yeniden uygular.
  ///
  /// Eski gecmisin becerileri kaldirilir, yenisininki `background` kaynagiyla
  /// yazilir. Sihirbazin ilk surumu gecmis becerilerini de sinif kaynagiyla
  /// kaydettigi icin o eski satirlar da (yalnizca eski gecmisin listesindeyse)
  /// temizlenir; aksi halde kagitta kimsenin vermedigi beceriler kalirdi.
  Future<void> setBackground(String characterId, String? backgroundKey) async {
    final character = await find(characterId);
    if (character == null) return;

    final previous = await _backgroundSkills(character.backgroundKey);
    final next = await _backgroundSkills(backgroundKey);

    await db.transaction(() async {
      for (final skill in previous) {
        if (next.contains(skill)) continue;
        await (db.delete(db.characterProficiencies)..where(
              (t) =>
                  t.characterId.equals(characterId) &
                  t.kind.equalsValue(ProficiencyKind.skill) &
                  t.value.equals(skill.name),
            ))
            .go();
      }
      if (next.isNotEmpty) {
        await db.batch((b) {
          b.insertAll(db.characterProficiencies, [
            for (final skill in next)
              CharacterProficienciesCompanion.insert(
                characterId: characterId,
                kind: ProficiencyKind.skill,
                value: skill.name,
                source: const Value(ProficiencySource.background),
              ),
          ], mode: InsertMode.insertOrIgnore);
        });
      }
      await _update(
        characterId,
        (t) => t.copyWith(backgroundKey: Value(backgroundKey)),
      );
    });
    // Islem disinda: yeni background'un alet yeterliligi de turetilsin.
    await syncDerivedProficiencies(characterId);
  }

  /// Tek bir beceri/kurtarma yeterliligini elle acar, kapatir ya da uzmanliga
  /// cevirir. Kaynak `manual` olur; sihirbazin yazdigi satirin yerini alir.
  Future<void> setProficiency(
    String characterId, {
    required ProficiencyKind kind,
    required String value,
    required bool proficient,
    bool expertise = false,
  }) async {
    await db.transaction(() async {
      if (!proficient) {
        await (db.delete(db.characterProficiencies)..where(
              (t) =>
                  t.characterId.equals(characterId) &
                  t.kind.equalsValue(kind) &
                  t.value.equals(value),
            ))
            .go();
      } else {
        await db
            .into(db.characterProficiencies)
            .insertOnConflictUpdate(
              CharacterProficienciesCompanion.insert(
                characterId: characterId,
                kind: kind,
                value: value,
                expertise: Value(expertise),
                source: const Value(ProficiencySource.manual),
              ),
            );
      }
      // Kagit karakter satirini izliyor; dokunmazsak ekran yenilenmez.
      await _touch(characterId);
    });
  }

  /// Bir sinif satirini bastan bir baska sinifa cevirir.
  ///
  /// Seviye, siralama ve atilmis can zarlari korunur; alt sinif dusar (yeni
  /// sinifin alt sinifi degildi). Eski sinifin ve alt sinifin yetenekleri
  /// kagittan silinip yenisininkiler 1'den mevcut seviyeye kadar islenir.
  Future<void> changeClass({
    required String characterId,
    required String fromClassKey,
    required String toClassKey,
  }) async {
    if (fromClassKey == toClassKey) return;
    await db.transaction(
      () => _keepingHitPointsInSync(characterId, () async {
        final row =
            await (db.select(db.characterClassLevels)..where(
                  (t) =>
                      t.characterId.equals(characterId) &
                      t.classKey.equals(fromClassKey),
                ))
                .getSingleOrNull();
        if (row == null) return;

        await _forgetClassFeatures(characterId, [
          fromClassKey,
          ?row.subclassKey,
        ]);

        await (db.delete(db.characterClassLevels)..where(
              (t) =>
                  t.characterId.equals(characterId) &
                  t.classKey.equals(fromClassKey),
            ))
            .go();
        await db
            .into(db.characterClassLevels)
            .insert(
              CharacterClassLevelsCompanion.insert(
                characterId: characterId,
                classKey: toClassKey,
                level: Value(row.level),
                order: Value(row.order),
                hitPointRollsJson: Value(row.hitPointRollsJson),
              ),
            );

        // Bilinen buyuler sinifa bagli (buyu DC'si ve yuvalar icin);
        // sahipsiz kalmasinlar.
        await (db.update(db.characterSpells)..where(
              (t) =>
                  t.characterId.equals(characterId) &
                  t.classKey.equals(fromClassKey),
            ))
            .write(CharacterSpellsCompanion(classKey: Value(toClassKey)));

        // Kurtarma atislari yalnizca ILK siniftan gelir.
        if (row.order == 0) {
          await _replaceClassSaves(characterId, toClassKey);
        }

        // Yetenekler ve alt sinifin verdigi buyuler bastan kurulur.
        await _syncClassContent(characterId);
      }),
    );
  }

  /// Alt sinifi degistirir (ya da kaldirir).
  Future<void> setSubclass({
    required String characterId,
    required String classKey,
    required String? subclassKey,
  }) async {
    await db.transaction(() async {
      final row =
          await (db.select(db.characterClassLevels)..where(
                (t) =>
                    t.characterId.equals(characterId) &
                    t.classKey.equals(classKey),
              ))
              .getSingleOrNull();
      if (row == null || row.subclassKey == subclassKey) return;

      if (row.subclassKey != null) {
        await _forgetClassFeatures(characterId, [row.subclassKey!]);
      }
      await (db.update(db.characterClassLevels)..where(
            (t) =>
                t.characterId.equals(characterId) & t.classKey.equals(classKey),
          ))
          .write(
            CharacterClassLevelsCompanion(subclassKey: Value(subclassKey)),
          );

      await _syncClassContent(characterId);
      await _touch(characterId);
    });
  }

  /// Bir sinifin seviyesini elle duzeltir.
  ///
  /// Yukari cikarken atilmamis seviyelerin cani ortalamadan verilir (zar
  /// atmak isteyen seviye atlama akisini kullanir), asagi inerken o seviyelerde
  /// kazanilan yetenekler ve can geri alinir.
  Future<void> setClassLevel({
    required String characterId,
    required String classKey,
    required int level,
  }) async {
    final target = level.clamp(1, 20);
    await db.transaction(
      () => _keepingHitPointsInSync(characterId, () async {
        final row =
            await (db.select(db.characterClassLevels)..where(
                  (t) =>
                      t.characterId.equals(characterId) &
                      t.classKey.equals(classKey),
                ))
                .getSingleOrNull();
        if (row == null || row.level == target) return;

        final definition = (await _classDefinitions([classKey]))[classKey];
        final average = CharacterMath.averageHitDie(
          _hitDieSides(definition?.hitDice),
        );
        final rolls = (jsonDecode(row.hitPointRollsJson) as List).cast<int>();

        // Ilk sinifin 1. seviyesi zar atmaz; kaydedilen atis sayisi bu yuzden
        // seviye-1 kadar.
        final free = row.order == 0 ? 1 : 0;
        final wanted = target - free;
        final next = [
          ...rolls.take(wanted),
          for (var i = rolls.length; i < wanted; i++) average,
        ];

        await (db.update(db.characterClassLevels)..where(
              (t) =>
                  t.characterId.equals(characterId) &
                  t.classKey.equals(classKey),
            ))
            .write(
              CharacterClassLevelsCompanion(
                level: Value(target),
                hitPointRollsJson: Value(jsonEncode(next)),
              ),
            );

        // Yeni seviyenin yetenekleri gelir, dusen seviyeninkiler gider.
        await _syncClassContent(characterId);
      }),
    );
  }

  /// Karakterin sinif/alt sinif kaynakli yeteneklerini ve "daima hazir"
  /// buyulerini kutuphanedeki GUNCEL veriyle yeniden kurar.
  ///
  /// Yetenekler seviye atlarken tek tek yazildigi icin, kutuphane verisi
  /// sonradan duzelirse (eksik yetenekler eklenir, metinler tamamlanir) eski
  /// kagitlar donuk kaliyordu: Armorer'in zirh modelleri, alt sinifin verdigi
  /// buyuler kagitta hic gorunmuyordu. Paket her guncellendiginde bu islem
  /// tum karakterler icin bir kez calisiyor.
  ///
  /// DM'in elle ekledigi yetenekler (`source: manual`) ve harcanmis kullanim
  /// sayaclari korunur.
  Future<void> syncClassContent(String characterId) => db.transaction(() async {
    await _syncClassContent(characterId);
    await _touch(characterId);
  });

  /// Paketlenmis icerik yenilendikten sonra tum karakterleri tazeler.
  Future<void> syncAllCharacters() async {
    for (final character in await db.select(db.characters).get()) {
      await syncClassContent(character.id);
    }
  }

  Future<void> _syncClassContent(String characterId) async {
    final levels = await classLevels(characterId);
    if (levels.isEmpty) return;

    // Harcanmis kullanimlar silinip yeniden yazilan satirlarda kaybolmasin.
    final spent = <String, int>{
      for (final f in await features(characterId))
        if (f.usesSpent > 0) f.id: f.usesSpent,
    };

    for (final row in levels) {
      final sources = [row.classKey, ?row.subclassKey];
      await _forgetClassFeatures(characterId, sources);
      for (var level = 1; level <= row.level; level++) {
        for (final key in sources) {
          await _recordFeatures(characterId, key, level);
        }
      }
      await _syncGrantedSpells(characterId, row);
    }

    for (final entry in spent.entries) {
      await (db.update(db.characterFeatures)
            ..where((t) => t.id.equals(entry.key)))
          .write(CharacterFeaturesCompanion(usesSpent: Value(entry.value)));
    }

    // Yetenek satirlari yazildiktan SONRA: dil veren sinif ozellikleri
    // ([classFeatureProficiencies]) bu satirlardan okunuyor.
    await syncDerivedProficiencies(characterId);
  }

  /// Alt sinifin (ya da sinifin) tablosunda "daima hazir" diye gecen buyuleri
  /// karakterin buyu listesine isler ve artik hak edilmeyenleri kaldirir.
  Future<void> _syncGrantedSpells(
    String characterId,
    CharacterClassLevel row,
  ) async {
    final keys = [row.classKey, ?row.subclassKey];
    final definitions = await _classDefinitions(keys);

    final names = <String>{};
    for (final key in keys) {
      final definition = definitions[key];
      if (definition == null) continue;
      for (final feature
          in ((jsonDecode(definition.dataJson) as Map)['features'] as List? ??
                  const [])
              .cast<Map<String, dynamic>>()) {
        final table = parseGrantedSpellTable('${feature['desc'] ?? ''}');
        for (final entry in table.entries) {
          if (entry.key <= row.level) names.addAll(entry.value);
        }
      }
    }

    final wanted = <String>{};
    if (names.isNotEmpty) {
      final normalized = names.map(searchNormalize).toList();
      final matches = await (db.select(
        db.spells,
      )..where((t) => t.nameLower.isIn(normalized))).get();
      wanted.addAll(matches.map((s) => s.key));
    }

    // Bu siniftan verilmis ama artik listede olmayanlari kaldir. Yalnizca
    // "daima hazir" isaretliler siliniyor; oyuncunun kendi ogrendigi buyuye
    // dokunulmuyor.
    await (db.delete(db.characterSpells)..where(
          (t) =>
              t.characterId.equals(characterId) &
              t.classKey.equals(row.classKey) &
              t.alwaysPrepared.equals(true) &
              (wanted.isEmpty
                  ? const Constant(true)
                  : t.spellKey.isNotIn(wanted)),
        ))
        .go();

    if (wanted.isEmpty) return;
    await db.batch((b) {
      b.insertAll(db.characterSpells, [
        for (final key in wanted)
          CharacterSpellsCompanion.insert(
            characterId: characterId,
            spellKey: key,
            classKey: Value(row.classKey),
            alwaysPrepared: const Value(true),
          ),
      ], mode: InsertMode.insertOrReplace);
    });
  }

  /// [mutate] calistiktan sonra kural motorunun hesapladigi azami can farkini
  /// kagida yansitir. Fark uygulaniyor (mutlak deger degil): DM'in elle
  /// verdigi ek canlar kaybolmasin.
  Future<void> _keepingHitPointsInSync(
    String characterId,
    Future<void> Function() mutate,
  ) async {
    final before = (await buildFor(characterId)).maxHitPoints;
    await mutate();
    final after = (await buildFor(characterId)).maxHitPoints;
    final delta = after - before;
    if (delta == 0) {
      await _touch(characterId);
      return;
    }

    final character = await find(characterId);
    if (character == null) return;
    final max = character.hitPointsMax + delta;
    final current = character.hitPointsCurrent + delta;
    await _update(
      characterId,
      (t) => t.copyWith(
        hitPointsMax: Value(max < 1 ? 1 : max),
        hitPointsCurrent: Value(current.clamp(0, max < 1 ? 1 : max)),
      ),
    );
  }

  /// Bir sinifin/alt sinifin kagida islenmis yeteneklerini siler.
  Future<void> _forgetClassFeatures(String characterId, List<String> sources) =>
      (db.delete(db.characterFeatures)..where(
            (t) => t.characterId.equals(characterId) & t.source.isIn(sources),
          ))
          .go();

  /// Sinif kaynakli kurtarma atisi yeterliliklerini yeni sinifinkiyle degistirir.
  Future<void> _replaceClassSaves(String characterId, String classKey) async {
    await (db.delete(db.characterProficiencies)..where(
          (t) =>
              t.characterId.equals(characterId) &
              t.kind.equalsValue(ProficiencyKind.save) &
              t.source.equalsValue(ProficiencySource.characterClass),
        ))
        .go();

    final definition = (await _classDefinitions([classKey]))[classKey];
    if (definition == null) return;
    final core = _coreTraitsOf(definition);
    if (core == null) return;

    await db.batch((b) {
      b.insertAll(db.characterProficiencies, [
        for (final ability in core.savingThrows)
          CharacterProficienciesCompanion.insert(
            characterId: characterId,
            kind: ProficiencyKind.save,
            value: ability.name,
            source: const Value(ProficiencySource.characterClass),
          ),
      ], mode: InsertMode.insertOrReplace);
    });
  }

  static ClassCoreTraits? _coreTraitsOf(ClassDefinition definition) {
    final core =
        ((jsonDecode(definition.dataJson) as Map)['features'] as List? ??
                const [])
            .cast<Map<String, dynamic>>()
            .where((f) => '${f['feature_type']}' == 'CORE_TRAITS_TABLE')
            .firstOrNull;
    if (core == null) return null;
    return parseClassCoreTraits('${core['desc'] ?? ''}');
  }

  Future<Set<Skill>> _backgroundSkills(String? backgroundKey) async {
    if (backgroundKey == null) return const {};
    final row = await (db.select(
      db.backgrounds,
    )..where((t) => t.key.equals(backgroundKey))).getSingleOrNull();
    if (row == null) return const {};
    final data = jsonDecode(row.dataJson) as Map<String, dynamic>;
    return parseBackgroundBenefits(
      data['benefits'] as List? ?? const [],
    ).skills.toSet();
  }

  /// Sinif, background, feat ve sinif ozelliklerinden gelen zirh/silah/alet/dil
  /// yeterliliklerini bastan turetir.
  ///
  /// DELTA DEGIL, YENIDEN HESAP: seviye atlama, background degisimi ve feat
  /// kazanimi ayni kumeyi farkli yollardan degistiriyor; artimli guncelleme
  /// yazmak her yolda ayri bir "geri alma" kuralı gerektirirdi. Burada
  /// turetilmis olanların hepsi silinip yeniden yaziliyor.
  ///
  /// ELLE eklenenlere ([ProficiencySource.manual]) dokunulmuyor -- DM'in
  /// kagida yazdigi bir dil seviye atlayinca kaybolmamali. Beceri ve kurtarma
  /// yeterlilikleri de bu fonksiyonun disinda; onlarin kendi akislari var.
  Future<void> syncDerivedProficiencies(String characterId) async {
    const derivedKinds = [
      ProficiencyKind.armor,
      ProficiencyKind.weapon,
      ProficiencyKind.tool,
      ProficiencyKind.language,
      ProficiencyKind.weaponMastery,
    ];

    final character = await find(characterId);
    if (character == null) return;

    // --- kaynaklardan topla ------------------------------------------------
    final bySource = <ProficiencySource, ProficiencyGrant>{};
    void add(ProficiencySource source, ProficiencyGrant grant) {
      if (grant.isEmpty) return;
      bySource[source] = (bySource[source] ?? const ProficiencyGrant()).merge(
        grant,
      );
    }

    final levels = await classLevels(characterId);
    final definitions = await _classDefinitions([
      for (final l in levels) l.classKey,
    ]);
    for (final level in levels) {
      final definition = definitions[level.classKey];
      if (definition == null) continue;
      final data = jsonDecode(definition.dataJson) as Map<String, dynamic>;
      for (final f
          in (data['features'] as List? ?? const [])
              .cast<Map<String, dynamic>>()) {
        if (f['feature_type'] != 'CORE_TRAITS_TABLE') continue;
        final core = parseClassCoreTraits('${f['desc'] ?? ''}');
        add(
          ProficiencySource.characterClass,
          parseClassProficiencies(
            armorText: core.armorText,
            weaponText: core.weaponText,
            toolText: core.toolText,
          ),
        );
      }
    }

    if (character.backgroundKey case final key?) {
      final row = await (db.select(
        db.backgrounds,
      )..where((t) => t.key.equals(key))).getSingleOrNull();
      if (row != null) {
        final data = jsonDecode(row.dataJson) as Map<String, dynamic>;
        for (final b
            in (data['benefits'] as List? ?? const [])
                .cast<Map<String, dynamic>>()) {
          if (b['name'] != 'Tool Proficiency') continue;
          add(
            ProficiencySource.background,
            parseBackgroundProficiencies('${b['desc'] ?? ''}'),
          );
        }
      }
    }

    // Feat'ler ve dil veren sinif ozellikleri kagittaki yetenek satirlarindan
    // okunuyor; ikisi de ADIYLA eslesiyor.
    for (final feature in await features(characterId)) {
      if (feature.source == 'feat') {
        add(ProficiencySource.feat, featProficiencies(feature.name));
      } else if (feature.source != 'manual' && feature.source != 'option') {
        add(
          ProficiencySource.characterClass,
          classFeatureProficiencies(feature.name),
        );
      }
    }

    // --- yaz ---------------------------------------------------------------
    await db.transaction(() async {
      await (db.delete(db.characterProficiencies)..where(
            (t) =>
                t.characterId.equals(characterId) &
                t.kind.isInValues(derivedKinds) &
                t.source.equalsValue(ProficiencySource.manual).not(),
          ))
          .go();

      final rows = <CharacterProficienciesCompanion>[];
      for (final entry in bySource.entries) {
        void emit(ProficiencyKind kind, Iterable<String> values) {
          for (final value in values) {
            rows.add(
              CharacterProficienciesCompanion.insert(
                characterId: characterId,
                kind: kind,
                value: value,
                source: Value(entry.key),
              ),
            );
          }
        }

        emit(ProficiencyKind.armor, entry.value.armor);
        emit(ProficiencyKind.weapon, entry.value.weapons);
        emit(ProficiencyKind.tool, entry.value.tools);
        emit(ProficiencyKind.language, entry.value.languages);
      }
      if (rows.isNotEmpty) {
        // Ayni deger iki kaynaktan gelebilir (Fighter + Lightly Armored);
        // birincil anahtar (karakter, tur, deger) oldugu icin ilki kaliyor.
        await db.batch(
          (b) => b.insertAll(
            db.characterProficiencies,
            rows,
            mode: InsertMode.insertOrIgnore,
          ),
        );
      }
    });

    // Kagit yeterlilikleri KARAKTER satirini izleyerek yeniden okuyor. Tur ve
    // gecmis degisimi once karakter satirini yaziyor, yeterlilikleri sonra:
    // dokunmazsak ekran degisimden ONCEKI listeyi gosterip oyle kaliyordu.
    await _touch(characterId);
  }

  /// Elle bir zirh/silah/alet/dil/ustalik satiri ekler.
  ///
  /// Kaynak `manual`: bir sonraki [syncDerivedProficiencies] bunu silmez.
  Future<void> addManualProficiency(
    String characterId, {
    required ProficiencyKind kind,
    required String value,
  }) async {
    await db
        .into(db.characterProficiencies)
        .insert(
          CharacterProficienciesCompanion.insert(
            characterId: characterId,
            kind: kind,
            value: value,
            source: const Value(ProficiencySource.manual),
          ),
          // Ayni deger zaten sinifdan geliyorsa kaynak degismesin.
          mode: InsertMode.insertOrIgnore,
        );
    await _touch(characterId);
  }

  /// Elle eklenmis bir satiri kaldirir. Turetilmis satirlara dokunmaz --
  /// onlar kaynak degisince kendiliginden gider.
  Future<void> removeProficiency(
    String characterId, {
    required ProficiencyKind kind,
    required String value,
  }) async {
    await (db.delete(db.characterProficiencies)..where(
          (t) =>
              t.characterId.equals(characterId) &
              t.kind.equalsValue(kind) &
              t.value.equals(value) &
              t.source.equalsValue(ProficiencySource.manual),
        ))
        .go();
    await _touch(characterId);
  }

  /// Karakterin bekleyen yeterlilik secimleri (Bard'in uc calgisi gibi).
  ///
  /// Secim yapilmis mi diye bakmaz; arayuz kac tane secildigini kendi
  /// sayiyor. Kaynak, secimin nereden geldigini gostermek icin.
  Future<List<({ProficiencySource source, ProficiencyChoice choice})>>
  pendingProficiencyChoices(String characterId) async {
    final out = <({ProficiencySource source, ProficiencyChoice choice})>[];
    final character = await find(characterId);
    if (character == null) return out;

    final levels = await classLevels(characterId);
    final definitions = await _classDefinitions([
      for (final l in levels) l.classKey,
    ]);
    for (final level in levels) {
      final data = jsonDecode(definitions[level.classKey]?.dataJson ?? '{}');
      if (data is! Map) continue;
      for (final f
          in (data['features'] as List? ?? const [])
              .cast<Map<String, dynamic>>()) {
        if (f['feature_type'] != 'CORE_TRAITS_TABLE') continue;
        final core = parseClassCoreTraits('${f['desc'] ?? ''}');
        for (final c in parseClassProficiencies(
          toolText: core.toolText,
        ).choices) {
          out.add((source: ProficiencySource.characterClass, choice: c));
        }
      }
    }

    if (character.backgroundKey case final key?) {
      final row = await (db.select(
        db.backgrounds,
      )..where((t) => t.key.equals(key))).getSingleOrNull();
      if (row != null) {
        final data = jsonDecode(row.dataJson) as Map<String, dynamic>;
        for (final b
            in (data['benefits'] as List? ?? const [])
                .cast<Map<String, dynamic>>()) {
          if (b['name'] != 'Tool Proficiency') continue;
          for (final c in parseBackgroundProficiencies(
            '${b['desc'] ?? ''}',
          ).choices) {
            out.add((source: ProficiencySource.background, choice: c));
          }
        }
      }
    }

    for (final feature in await features(characterId)) {
      final grant = feature.source == 'feat'
          ? featProficiencies(feature.name)
          : classFeatureProficiencies(feature.name);
      final source = feature.source == 'feat'
          ? ProficiencySource.feat
          : ProficiencySource.characterClass;
      for (final c in grant.choices) {
        out.add((source: source, choice: c));
      }
    }

    // Silah ustaligi sayisi sinif ILERLEME TABLOSUNDA bir sutun (yalnizca
    // Fighter ve Barbarian'da) ve seviyeyle artiyor: 3 -> 4 -> 5 -> 6.
    // Feat'ten gelen +1 yukarida ayrica sayiliyor.
    final masteries = await weaponMasterySlots(characterId);
    if (masteries > 0) {
      out.add((
        source: ProficiencySource.characterClass,
        choice: ProficiencyChoice(
          type: ProficiencyType.weaponMastery,
          count: masteries,
        ),
      ));
    }
    return out;
  }

  /// Sinif ilerleme tablosunun verdigi silah ustaligi sayisi.
  ///
  /// Coklu sinifta en yuksegi gecerli: iki sinif da veriyorsa sayilar
  /// toplanmaz, karakter tek bir ustalik havuzu tasir.
  Future<int> weaponMasterySlots(String characterId) async {
    var best = 0;
    for (final level in await classLevels(characterId)) {
      final row = await _progression(level.classKey, level.level);
      if (row == null) continue;
      final table = (jsonDecode(row.classTableJson) as Map)
          .cast<String, dynamic>();
      final value = int.tryParse('${table['Weapon Mastery'] ?? ''}');
      if (value != null && value > best) best = value;
    }
    return best;
  }

  /// Karakter satirini "degisti" olarak isaretler.
  ///
  /// Kagittaki her turetilmis deger [watch] akisini izliyor; yalnizca yan
  /// tablolar degistiginde ekran kendiliginden yenilenmiyor.
  Future<void> _touch(String characterId) => _update(characterId, (t) => t);

  static String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

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

    // Uzun dinlenmede hazir buyu listesi bastan kurulabilir; hak, listenin
    // tamamini degistirmeye yetecek kadar veriliyor.
    final spellChanges = await _longRestSpellChanges(
      characterId,
      c.spellChangesAvailable,
    );

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
        spellChangesAvailable: Value(spellChanges),
      ),
    );
  }

  /// Uzun dinlenmeden sonraki degistirme hakki.
  ///
  /// Yalnizca "her uzun dinlenmede listeni degistirebilirsin" diyen siniflar
  /// (Cleric, Druid, Paladin, Wizard, Artificer) icin doluyor; digerlerinde
  /// birikmis hak (seviye basi) oldugu gibi kaliyor.
  Future<int> _longRestSpellChanges(String characterId, int current) async {
    var granted = current;
    for (final row in await classLevels(characterId)) {
      if (SpellChangePolicy.forClass(row.classKey) !=
          SpellChangePolicy.longRest) {
        continue;
      }
      final limit = await _classTableValue(
        row.classKey,
        row.level,
        'Prepared Spells',
      );
      if (limit > granted) granted = limit;
    }
    return granted;
  }

  /// Kisa dinlenme: bir hit die harcayip iyilesir (hit die + CON). Bos hit
  /// die yoksa `null` doner. Iyilesilen HP'yi doner.
  /// Harcanan hit die'in ayrintisi.
  ///
  /// Yalnizca iyilesen can degil ZARIN KENDISI de doner: atis masada zar
  /// animasyonuyla gosteriliyor, bunun icin kac yuzlu zarin kac geldigi
  /// gerekiyor.
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
    String? featKey,
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
          // Bard/Ranger/Sorcerer/Warlock seviye basina BIR buyu degistirir;
          // hak burada birikiyor.
          spellChangesAvailable:
              SpellChangePolicy.forClass(classKey) == SpellChangePolicy.levelUp
              ? Value(character.spellChangesAvailable + 1)
              : const Value.absent(),
          updatedAt: Value(DateTime.now()),
        ),
      );

      // ASI seviyesinde puan yerine feat secilebilir; kagida kalici bir
      // yetenek olarak giriyor.
      if (featKey != null) await _grantFeat(characterId, featKey);

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

  /// Bir feat'i karaktere yazar (seviye atlama ya da koken feat'i).
  ///
  /// Ayni feat iki kez yazilmasin diye anahtar id'ye giriyor; metin
  /// kutuphaneden geldigi icin veri guncellenince tazelenebilir.
  Future<void> _grantFeat(String characterId, String featKey) async {
    final feat = await (db.select(
      db.feats,
    )..where((t) => t.key.equals(featKey))).getSingleOrNull();
    if (feat == null) return;

    final data = jsonDecode(feat.dataJson) as Map<String, dynamic>;
    final benefits = [
      for (final b in (data['benefits'] as List? ?? const []).whereType<Map>())
        [
          if ('${b['name'] ?? ''}'.isNotEmpty) '${b['name']}.',
          '${b['desc'] ?? ''}',
        ].join(' ').trim(),
    ].where((s) => s.isNotEmpty);

    await db
        .into(db.characterFeatures)
        .insertOnConflictUpdate(
          CharacterFeaturesCompanion.insert(
            id: '$characterId:$featKey',
            characterId: characterId,
            featureKey: Value(featKey),
            name: feat.name,
            description: Value(
              [
                '${data['desc'] ?? ''}'.trim(),
                ...benefits,
              ].where((s) => s.isNotEmpty).join('\n\n'),
            ),
            source: const Value('feat'),
          ),
        );
  }

  // --- Sinif secenekleri (Invocation, Metamagic, Maneuver...) --------------

  /// Karakterin siniflarina uygun secenekler.
  ///
  /// Fighting Style 2024'te feat oldugu icin burada degil; bu liste
  /// Eldritch Invocation, Metamagic, Maneuver ve Rune gibi "sinifin verdigi
  /// ama oyuncunun sectigi" ozellikleri tasiyor.
  Future<List<Map<String, dynamic>>> classOptionsFor(String characterId) async {
    final levels = await classLevels(characterId);
    if (levels.isEmpty) return const [];
    final keys = {for (final l in levels) l.classKey};

    final rows = await (db.select(
      db.referenceEntries,
    )..where((t) => t.kind.equals('optionalfeatures'))).get();

    return [
      for (final row in rows)
        if (jsonDecode(row.dataJson) case final Map<String, dynamic> data)
          if (keys.contains('${data['class_key']}')) data,
    ];
  }

  /// Secilen secenegi kagida yazar (kaynak: `option`).
  Future<void> addClassOption(
    String characterId,
    Map<String, dynamic> option,
  ) async {
    await db
        .into(db.characterFeatures)
        .insertOnConflictUpdate(
          CharacterFeaturesCompanion.insert(
            id: '$characterId:${option['key']}',
            characterId: characterId,
            featureKey: Value('${option['key']}'),
            name: '${option['type_name']}: ${option['name']}',
            description: Value('${option['desc'] ?? ''}'),
            source: const Value('option'),
          ),
        );
    await _touch(characterId);
  }

  /// Feat'i adiyla bulur ("Magic Initiate (Cleric)" -> parantez atilir).
  Future<String?> featKeyByName(String name) async {
    final cleaned = name.replaceAll(RegExp(r'\(.*\)'), '').trim();
    if (cleaned.isEmpty) return null;
    final row =
        await (db.select(db.feats)
              ..where((t) => t.nameLower.equals(searchNormalize(cleaned))))
            .getSingleOrNull();
    return row?.key;
  }

  /// Kagida elle ya da koken uzerinden feat ekler.
  Future<void> grantFeat(String characterId, String featKey) async {
    await _grantFeat(characterId, featKey);
    await syncDerivedProficiencies(characterId);
    await _touch(characterId);
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
    EquipSlot? slot,
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
            // Serbest yazilan esyalarda tur ADDAN tahmin edilemeyebilir
            // ("Babamın yüzüğü" tutar, "Gölge Örtüsü" tutmaz); ekleyen kisi
            // sectiyse tahmine hic bakilmiyor.
            slot: Value(slot?.name),
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

  /// Bir esyayi kusanir ya da cikarir.
  ///
  /// Yuva dolu ise kusanma YAPILMAZ ve [EquipOutcome.slotFull] doner: masada
  /// "iki zirh birden giyili" gibi bir durum kagida sizmasin. Yuzuk/kolye gibi
  /// sinirsiz yuvalarda bu kontrol hicbir zaman devreye girmez.
  Future<EquipOutcome> setEquipped(
    String itemId,
    bool value, {
    EquipSlot? slot,
  }) async {
    final item = await (db.select(
      db.characterItems,
    )..where((t) => t.id.equals(itemId))).getSingleOrNull();
    if (item == null) return EquipOutcome.missing;

    final target = slot ?? await equipSlotOf(item);

    if (value) {
      final capacities = await slotCapacities(item.characterId);
      final used = await _slotUsage(item.characterId, exceptItemId: itemId);
      if (!capacities.hasRoom(target, used[target] ?? 0)) {
        return EquipOutcome.slotFull;
      }
    }

    await (db.update(
      db.characterItems,
    )..where((t) => t.id.equals(itemId))).write(
      CharacterItemsCompanion(
        equipped: Value(value),
        // Yuva her kusanmada yaziliyor: sonradan esya verisi degisse de
        // kagitta gorunen yer sabit kalsin.
        slot: Value(target.name),
      ),
    );
    await _touch(item.characterId);
    return EquipOutcome.ok;
  }

  /// Kusanili bir esyayi baska bir yuvaya tasir (yuva doluysa reddeder).
  Future<EquipOutcome> setItemSlot(String itemId, EquipSlot slot) async {
    final item = await (db.select(
      db.characterItems,
    )..where((t) => t.id.equals(itemId))).getSingleOrNull();
    if (item == null) return EquipOutcome.missing;

    if (item.equipped) {
      final capacities = await slotCapacities(item.characterId);
      final used = await _slotUsage(item.characterId, exceptItemId: itemId);
      if (!capacities.hasRoom(slot, used[slot] ?? 0)) {
        return EquipOutcome.slotFull;
      }
    }
    await (db.update(db.characterItems)..where((t) => t.id.equals(itemId)))
        .write(CharacterItemsCompanion(slot: Value(slot.name)));
    await _touch(item.characterId);
    return EquipOutcome.ok;
  }

  /// Bir envanter satirinin yuvasi: elle secilmisse o, degilse esyadan
  /// tahmin edilen.
  Future<EquipSlot> equipSlotOf(CharacterItem item) async {
    final stored = item.slot;
    if (stored != null && stored.isNotEmpty) return equipSlotFromName(stored);

    if (item.itemKey != null) {
      final row = await (db.select(
        db.items,
      )..where((t) => t.key.equals(item.itemKey!))).getSingleOrNull();
      if (row != null) {
        return inferEquipSlot(
          name: row.name,
          categoryKey: row.category,
          payload: jsonDecode(row.dataJson) as Map<String, dynamic>,
        );
      }
    }
    if (item.magicItemKey != null) {
      final row = await (db.select(
        db.magicItems,
      )..where((t) => t.key.equals(item.magicItemKey!))).getSingleOrNull();
      if (row != null) {
        return inferEquipSlot(
          name: row.name,
          categoryKey: row.category,
          payload: jsonDecode(row.dataJson) as Map<String, dynamic>,
        );
      }
    }
    return inferEquipSlot(name: item.customName ?? '');
  }

  /// Karakterin yuva sinirlari (varsayilanlar + elle girilenler).
  Future<SlotCapacities> slotCapacities(String characterId) async {
    final row = await (db.select(
      db.characters,
    )..where((t) => t.id.equals(characterId))).getSingleOrNull();
    return SlotCapacities.fromJson(row?.slotCapacitiesJson);
  }

  /// Bir yuvanin sinirini degistirir; [capacity] null ise varsayilana doner,
  /// negatifse sinirsiz olur.
  Future<void> setSlotCapacity(
    String characterId,
    EquipSlot slot,
    int? capacity,
  ) async {
    final current = await slotCapacities(characterId);
    final next = current.withCapacity(slot, capacity);
    await (db.update(db.characters)..where((t) => t.id.equals(characterId)))
        .write(CharactersCompanion(slotCapacitiesJson: Value(next.toJson())));
    await _touch(characterId);
  }

  /// Karakterin kusanili esyalari, yuvaya gore gruplanmis (gosterim sirasinda).
  Future<Map<EquipSlot, List<CharacterItem>>> equippedBySlot(
    String characterId,
  ) async {
    final rows = await items(characterId);
    final out = <EquipSlot, List<CharacterItem>>{};
    for (final row in rows) {
      if (!row.equipped) continue;
      (out[await equipSlotOf(row)] ??= []).add(row);
    }
    return out;
  }

  /// Yuva basina kac esya kusanili (bir satir haric tutulabilir).
  Future<Map<EquipSlot, int>> _slotUsage(
    String characterId, {
    String? exceptItemId,
  }) async {
    final rows = await items(characterId);
    final out = <EquipSlot, int>{};
    for (final row in rows) {
      if (!row.equipped || row.id == exceptItemId) continue;
      final slot = await equipSlotOf(row);
      out[slot] = (out[slot] ?? 0) + 1;
    }
    return out;
  }

  /// Bir esyayi bagli (attuned) yapar ya da birakir.
  ///
  /// 5e kurali: ayni anda EN FAZLA UC esya bagli olabilir. Sinir dolmusken
  /// dorduncuyu baglamak `false` doner; alan vardi ama kural hic
  /// uygulanmiyordu.
  Future<bool> setAttuned(String itemId, bool value) async {
    final item = await (db.select(
      db.characterItems,
    )..where((t) => t.id.equals(itemId))).getSingleOrNull();
    if (item == null) return false;

    if (value) {
      final attuned = await attunedCount(item.characterId);
      if (!item.attuned && attuned >= maxAttunedItems) return false;
    }

    await (db.update(db.characterItems)..where((t) => t.id.equals(itemId)))
        .write(CharacterItemsCompanion(attuned: Value(value)));
    await _touch(item.characterId);
    return true;
  }

  /// Su an bagli esya sayisi.
  Future<int> attunedCount(String characterId) async {
    final rows =
        await (db.select(db.characterItems)..where(
              (t) => t.characterId.equals(characterId) & t.attuned.equals(true),
            ))
            .get();
    return rows.length;
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
    final armorTraining = <String>{};
    final toolProficiencies = <String>{};
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
        case ProficiencyKind.armor:
          armorTraining.add(p.value);
        case ProficiencyKind.tool:
          toolProficiencies.add(p.value);
        case _:
          break;
      }
    }

    final gear = await _equippedDefense(characterId);
    // Hiz turden geliyor; kagit bugune kadar herkese 30 ft yaziyordu.
    final traits = await speciesTraits(character.speciesKey);

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
      armorProficiencies: armorTraining,
      toolProficiencies: toolProficiencies,
      hitPointRolls: hitPointRolls,
      baseSpeed: traits?.speed ?? 30,
    );
  }

  // --- Oyuncunun kendi buyu secimi ----------------------------------------

  // --- Buyu kullanma -------------------------------------------------------

  /// Bir buyuyu kullanir: yuvayi harcar ve masaya donecek plani hazirlar.
  ///
  /// Zari BURADA atmiyoruz: plan yalnizca "ne atilacak"i soyluyor, atisi
  /// arayuz kendi zar akisinda yapiyor. Yuva yoksa `null` doner.
  Future<SpellCastPlan?> castSpell({
    required String characterId,
    required String spellKey,
    required int slotLevel,
  }) async {
    final character = await find(characterId);
    if (character == null) return null;

    final row = await (db.select(
      db.spells,
    )..where((t) => t.key.equals(spellKey))).getSingleOrNull();
    if (row == null) return null;

    final known =
        await (db.select(db.characterSpells)..where(
              (t) =>
                  t.characterId.equals(characterId) &
                  t.spellKey.equals(spellKey),
            ))
            .getSingleOrNull();
    if (known == null) return null;

    final build = await buildFor(characterId);
    // Yuva seviyesi buyunun seviyesinin altinda olamaz; cantrip yuva harcamaz.
    final level = row.level == 0
        ? 0
        : (slotLevel < row.level ? row.level : slotLevel);
    if (level > 0 && !await _spendSlot(characterId, character, build, level)) {
      return null;
    }

    // Buyu yetenegi buyuyu hangi siniftan bildigine bagli; kayitli sinif
    // yoksa karakterin buyu yapabilen ilk sinifi kullanilir.
    final classKey =
        known.classKey ??
        build.classes
            .firstWhere(
              (c) => spellcastingAbilityFor(c.classKey) != null,
              orElse: () => build.classes.first,
            )
            .classKey;
    final ability = spellcastingAbilityFor(classKey) ?? Ability.intelligence;

    final plan = planSpellCast(
      spell: jsonDecode(row.dataJson) as Map<String, dynamic>,
      slotLevel: level,
      characterLevel: build.totalLevel,
      abilityModifier: build.abilities.modifier(ability),
      proficiencyBonus: build.proficiencyBonus,
    );

    // Konsantrasyon tek buyuyle tutulur: yenisi eskisini bitirir.
    if (plan.concentration) await setConcentration(characterId, plan.spellName);
    return plan;
  }

  /// Konsantrasyon tutulan buyuyu isaretler; `null` birakmayi bitirir.
  Future<void> setConcentration(String characterId, String? spellName) =>
      _update(
        characterId,
        (t) => t.copyWith(concentrationSpell: Value(spellName)),
      );

  /// Yuvayi dusurur; bos yuva yoksa `false` doner.
  Future<bool> _spendSlot(
    String characterId,
    Character character,
    CharacterBuild build,
    int level,
  ) async {
    final total = await spellSlots(build);
    final pact = await pactMagic(build);
    final available =
        (total[level] ?? 0) +
        (pact != null && pact.slotLevel == level ? pact.count : 0);
    if (available <= 0) return false;

    final spent = {
      for (final e in (jsonDecode(character.spellSlotsUsedJson) as Map).entries)
        int.parse('${e.key}'): e.value as int,
    };
    final used = spent[level] ?? 0;
    if (used >= available) return false;

    spent[level] = used + 1;
    await setSpentSlots(characterId, spent);
    return true;
  }

  /// Karakterin her buyucu sinifi icin secim durumu (sinir, secili buyuler,
  /// kalan degistirme hakki).
  Future<List<SpellPreparation>> spellPreparations(String characterId) async {
    final character = await find(characterId);
    if (character == null) return const [];

    final levels = await classLevels(characterId);
    if (levels.isEmpty) return const [];

    final definitions = await _classDefinitions(
      levels.map((l) => l.classKey).toList(),
    );
    final build = await buildFor(characterId);
    final slots = await spellSlots(build);
    final pact = await pactMagic(build);
    final maxSlotLevel = [
      ...slots.keys,
      if (pact != null) pact.slotLevel,
    ].fold<int>(0, (a, b) => a > b ? a : b);

    final chosen = await (db.select(
      db.characterSpells,
    )..where((t) => t.characterId.equals(characterId))).get();
    final spellLevels = await _spellLevels(
      chosen.map((s) => s.spellKey).toList(),
    );

    final out = <SpellPreparation>[];
    for (final row in levels) {
      final policy = SpellChangePolicy.forClass(row.classKey);
      final mine = chosen.where(
        (s) => s.classKey == row.classKey && !s.alwaysPrepared,
      );

      out.add(
        SpellPreparation(
          classKey: row.classKey,
          className: definitions[row.classKey]?.name ?? row.classKey,
          level: row.level,
          cantripLimit: await _classTableValue(
            row.classKey,
            row.level,
            'Cantrips',
          ),
          preparedLimit: await _classTableValue(
            row.classKey,
            row.level,
            'Prepared Spells',
          ),
          maxSpellLevel: maxSlotLevel,
          policy: policy,
          cantrips: {
            for (final s in mine)
              if ((spellLevels[s.spellKey] ?? 0) == 0) s.spellKey,
          },
          // Defter tutan sinifta HAZIR olanlar ayri: defterdeki bir buyu
          // hazir olmayabilir.
          prepared: {
            for (final s in mine)
              if ((spellLevels[s.spellKey] ?? 0) > 0 && s.prepared) s.spellKey,
          },
          spellbook: {
            for (final s in mine)
              if ((spellLevels[s.spellKey] ?? 0) > 0) s.spellKey,
          },
          spellbookLimit: SpellbookRules.size(row.classKey, row.level),
          changesAvailable: character.spellChangesAvailable,
        ),
      );
    }
    return out;
  }

  /// Bir sinifin secebilecegi buyuler: anahtar -> seviye.
  ///
  /// Sinif listesi buyunun kendi `classes` alanindan geliyor; alt siniftan
  /// gelen "daima hazir" buyuler bu listeye girmez (zaten kagitta).
  Future<Map<String, int>> selectableSpells(
    String classKey, {
    required int maxSpellLevel,
  }) async {
    final rows =
        await (db.select(db.spells)..where(
              (t) =>
                  t.classesCsv.contains(classKey) &
                  t.level.isSmallerOrEqualValue(maxSpellLevel),
            ))
            .get();
    return {for (final s in rows) s.key: s.level};
  }

  /// Secilen buyu listesini dogrular ve yazar.
  ///
  /// Sinirlar (cantrip/hazir buyu sayisi, seviye) BURADA zorlaniyor; arayuz
  /// yalnizca ekrani ciziyor.
  Future<SpellSelectionResult> applySpellSelection({
    required String characterId,
    required String classKey,
    required Set<String> cantrips,
    required Set<String> prepared,
  }) async {
    final preparations = await spellPreparations(characterId);
    final current = preparations
        .where((p) => p.classKey == classKey)
        .firstOrNull;
    if (current == null) {
      return const SpellSelectionRejected(SpellSelectionError.notAllowed);
    }

    final classSpells = await selectableSpells(
      classKey,
      maxSpellLevel: current.maxSpellLevel,
    );
    // Defter tutan sinifta hazir buyuler DEFTERDEN secilir; cantrip'ler her
    // zaman sinif listesinden.
    final allowed = current.usesSpellbook
        ? {
            for (final entry in classSpells.entries)
              if (entry.value == 0 || current.spellbook.contains(entry.key))
                entry.key: entry.value,
          }
        : classSpells;

    final result = validateSpellSelection(
      current: current,
      nextCantrips: cantrips,
      nextPrepared: prepared,
      allowed: allowed,
    );
    if (result is! SpellSelectionAccepted) return result;

    await db.transaction(() async {
      // Defter tutan sinifta satirlar KALIR, yalnizca `prepared` bayragi
      // degisir: defterdeki buyu hazir olmasa da defterde durur. Digerlerinde
      // secilmeyen satir silinir. Alt sinifin verdigi "daima hazir"
      // kayitlara iki durumda da dokunulmuyor.
      final keep = {...cantrips, ...prepared};
      if (current.usesSpellbook) {
        await (db.update(db.characterSpells)..where(
              (t) =>
                  t.characterId.equals(characterId) &
                  t.classKey.equals(classKey) &
                  t.alwaysPrepared.equals(false),
            ))
            .write(const CharacterSpellsCompanion(prepared: Value(false)));
        await (db.delete(db.characterSpells)..where(
              (t) =>
                  t.characterId.equals(characterId) &
                  t.classKey.equals(classKey) &
                  t.alwaysPrepared.equals(false) &
                  t.spellKey.isNotIn(current.spellbook.toList()) &
                  t.spellKey.isNotIn(keep.toList()),
            ))
            .go();
      } else {
        await (db.delete(db.characterSpells)..where(
              (t) =>
                  t.characterId.equals(characterId) &
                  t.classKey.equals(classKey) &
                  t.alwaysPrepared.equals(false),
            ))
            .go();
      }

      await db.batch((b) {
        b.insertAll(db.characterSpells, [
          for (final key in keep)
            CharacterSpellsCompanion.insert(
              characterId: characterId,
              spellKey: key,
              classKey: Value(classKey),
              prepared: const Value(true),
            ),
        ], mode: InsertMode.insertOrReplace);
      });

      final left = current.changesAvailable - result.changesSpent;
      await _update(
        characterId,
        (t) => t.copyWith(spellChangesAvailable: Value(left < 0 ? 0 : left)),
      );
    });
    return result;
  }

  /// Buyu defterini yazar (Wizard).
  ///
  /// Defterden cikan buyu hazir listesinden de duser; kagitta sahipsiz bir
  /// "hazir ama defterde yok" satiri kalmasin.
  Future<SpellSelectionResult> applySpellbook({
    required String characterId,
    required String classKey,
    required Set<String> spellKeys,
  }) async {
    final current = (await spellPreparations(
      characterId,
    )).where((p) => p.classKey == classKey).firstOrNull;
    if (current == null) {
      return const SpellSelectionRejected(SpellSelectionError.notAllowed);
    }

    final allowed = await selectableSpells(
      classKey,
      maxSpellLevel: current.maxSpellLevel,
    );
    final result = validateSpellbook(
      current: current,
      next: spellKeys,
      allowed: allowed,
    );
    if (result is! SpellSelectionAccepted) return result;

    await db.transaction(() async {
      await (db.delete(db.characterSpells)..where(
            (t) =>
                t.characterId.equals(characterId) &
                t.classKey.equals(classKey) &
                t.alwaysPrepared.equals(false) &
                t.spellKey.isIn(
                  current.spellbook.difference(spellKeys).toList(),
                ),
          ))
          .go();

      await db.batch((b) {
        b.insertAll(db.characterSpells, [
          for (final key in spellKeys)
            CharacterSpellsCompanion.insert(
              characterId: characterId,
              spellKey: key,
              classKey: Value(classKey),
              // Deftere girmek hazirlamak degil; hazir listesi ayri seciliyor.
              prepared: Value(current.prepared.contains(key)),
            ),
        ], mode: InsertMode.insertOrReplace);
      });
      await _touch(characterId);
    });
    return result;
  }

  Future<Map<String, int>> _spellLevels(List<String> keys) async {
    if (keys.isEmpty) return const {};
    final rows = await (db.select(
      db.spells,
    )..where((t) => t.key.isIn(keys))).get();
    return {for (final s in rows) s.key: s.level};
  }

  /// Sinif tablosundaki bir sutunun o seviyedeki sayisal degeri.
  Future<int> _classTableValue(
    String classKey,
    int level,
    String column,
  ) async {
    final row = await _progression(classKey, level);
    if (row == null) return 0;
    final table = (jsonDecode(row.classTableJson) as Map)
        .cast<String, dynamic>();
    return int.tryParse(
          RegExp(r'\d+').firstMatch('${table[column] ?? ''}')?.group(0) ?? '',
        ) ??
        0;
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
      // Yuva siniri gelmeden once kaydedilmis kagitlarda birden fazla zirh
      // giyili olabilir; sonuncuyu degil EN IYISINI kullaniyoruz ki AC
      // envanterdeki siralamaya gore oynamasin.
      if (armor != null && armor.baseAc >= baseAc) continue;
      armor = ArmorPiece(
        baseAc: baseAc,
        // Zirh egitimi kontrolu bu alana bakiyor: light / medium / heavy.
        category: '${data['category'] ?? ''}'.trim().isEmpty
            ? null
            : '${data['category']}'.trim().toLowerCase(),
        addDexModifier: data['ac_add_dexmod'] == true,
        maxDexModifier: data['ac_cap_dexmod'] as int?,
        // Veri alaninin adi `grants_stealth_disadvantage`; eski ad hicbir
        // zaman eslesmedigi icin bu bayrak butun zirhlarda false kaliyordu.
        stealthDisadvantage: data['grants_stealth_disadvantage'] == true,
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
