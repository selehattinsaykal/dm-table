import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/character_repository.dart';
import '../../data/content_tr.dart';
import '../../data/db/character_tables.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../domain/models/character_build.dart';
import '../../domain/rules/equipment_slots.dart';
import '../../domain/rules/origin_parsing.dart';
import '../../domain/rules/proficiency_parsing.dart';
import '../../domain/rules/spell_preparation.dart';
import 'character_draft.dart';

final characterRepositoryProvider = Provider<CharacterRepository>(
  (ref) => CharacterRepository(ref.watch(databaseProvider)),
);

final charactersProvider = StreamProvider<List<Character>>(
  (ref) => ref.watch(characterRepositoryProvider).watchAll(),
);

/// Tek bir karakterin canli kaydi.
final characterProvider = StreamProvider.family<Character, String>(
  (ref, id) => ref.watch(characterRepositoryProvider).watch(id),
);

/// Karakterin toplam/harcanmis hit dice sayaci (canli).
///
/// Karakter satirini izliyor: oyuncu kendi panelinden hit die harcayinca
/// DM'in kisa dinlenme paneli kendiliginden guncellensin.
final hitDiceStatusProvider =
    FutureProvider.family<({int total, int used}), String>((ref, id) async {
      ref.watch(characterProvider(id));
      return ref.watch(characterRepositoryProvider).hitDiceStatus(id);
    });

/// Karakterin envanteri (canli).
final characterItemsProvider =
    StreamProvider.family<List<CharacterItem>, String>(
      (ref, id) => ref.watch(characterRepositoryProvider).watchItems(id),
    );

/// Envanter satiri baglama (attunement) gerektiriyor mu?
///
/// Yalnizca kutuphanedeki buyulu esyalarda anlamli; serbest metin esyalarda
/// ve siradan esyalarda `false`.
final itemNeedsAttunementProvider = FutureProvider.family<bool, CharacterItem>((
  ref,
  item,
) async {
  final key = item.magicItemKey;
  if (key == null) return false;
  final db = ref.watch(databaseProvider);
  final row = await (db.select(
    db.magicItems,
  )..where((t) => t.key.equals(key))).getSingleOrNull();
  return row?.requiresAttunement ?? false;
});

/// Bir envanter satirinin ekipman yuvasi (elle secilmemisse tahmin edilir).
final itemSlotProvider = FutureProvider.family<EquipSlot, CharacterItem>(
  (ref, item) => ref.watch(characterRepositoryProvider).equipSlotOf(item),
);

/// Karakterin yuva sinirlari (varsayilanlar + elle girilenler).
final slotCapacitiesProvider = FutureProvider.family<SlotCapacities, String>((
  ref,
  id,
) async {
  await ref.watch(characterProvider(id).future);
  return ref.watch(characterRepositoryProvider).slotCapacities(id);
});

/// Kusanili esyalar, yuvaya gore gruplanmis.
///
/// Envanter akisini izliyor: esya eklenince/cikarilinca ekipman sekmesi
/// kendiliginden guncellensin.
final equippedBySlotProvider =
    FutureProvider.family<Map<EquipSlot, List<CharacterItem>>, String>((
      ref,
      id,
    ) async {
      await ref.watch(characterItemsProvider(id).future);
      return ref.watch(characterRepositoryProvider).equippedBySlot(id);
    });

/// Karakterin bagli esya sayisi (sinir: 3).
final attunedCountProvider = FutureProvider.family<int, String>((
  ref,
  id,
) async {
  await ref.watch(characterProvider(id).future);
  return ref.watch(characterRepositoryProvider).attunedCount(id);
});

/// Bir envanter satirinin gorunen adi (kutuphaneden cozulur).
final itemNameProvider = FutureProvider.family<String, CharacterItem>(
  (ref, item) => ref.watch(characterRepositoryProvider).itemDisplayName(item),
);

/// Kagitta gosterilen turetilmis degerler.
///
/// Karakter satiri her degistiginde (hasar, tukenmislik, ekipman) yeniden
/// hesaplanmasi icin [characterProvider]'i izliyor.
final characterBuildProvider = FutureProvider.family<CharacterBuild, String>((
  ref,
  id,
) async {
  await ref.watch(characterProvider(id).future);
  return ref.watch(characterRepositoryProvider).buildFor(id);
});

/// Toplam buyu yuvalari: yuva seviyesi -> adet.
final spellSlotsProvider = FutureProvider.family<Map<int, int>, String>((
  ref,
  id,
) async {
  final build = await ref.watch(characterBuildProvider(id).future);
  return ref.watch(characterRepositoryProvider).spellSlots(build);
});

/// Karakterin bildigi buyuler (kutuphane bilgisiyle, canli).
final knownSpellsProvider = FutureProvider.family<List<KnownSpell>, String>((
  ref,
  id,
) async {
  await ref.watch(characterProvider(id).future);
  return ref.watch(characterRepositoryProvider).knownSpells(id);
});

/// Warlock Pact Magic havuzu (varsa).
final pactMagicProvider =
    FutureProvider.family<({int slotLevel, int count})?, String>((
      ref,
      id,
    ) async {
      final build = await ref.watch(characterBuildProvider(id).future);
      return ref.watch(characterRepositoryProvider).pactMagic(build);
    });

final classLevelsProvider =
    FutureProvider.family<List<CharacterClassLevel>, String>((ref, id) async {
      // Seviye atlayinca yeniden okunmasi icin karakteri izliyoruz.
      await ref.watch(characterProvider(id).future);
      return ref.watch(characterRepositoryProvider).classLevels(id);
    });

/// Alt siniflar dahil tum sinif tanimlari, anahtara gore. Karakter kagidinda
/// "Wizard 5 (Evoker)" satirini kurmak icin alt sinif adi da gerekiyor.
final allClassDefinitionsProvider =
    FutureProvider<Map<String, ClassDefinition>>((ref) async {
      final db = ref.watch(databaseProvider);
      final rows = await db.select(db.classDefinitions).get();
      return {for (final r in rows) r.key: r};
    });

final subclassesProvider = FutureProvider.family<List<ClassDefinition>, String>(
  (ref, classKey) =>
      ref.watch(characterRepositoryProvider).subclassesOf(classKey),
);

/// Seviye atlamadan once kazanilacaklarin ozeti.
///
/// [subclassKey] arayuzde henuz kaydedilmemis, o an secili cipi tasir --
/// verilmezse (ya da bu seviye alt sinif secmiyorsa) karakterin kayitli alt
/// sinifina duser. Bu sayede farkli bir alt sinif cipine tiklayinca onizleme
/// (kazanilan yetenekler) hemen guncellenir; yoksa hep ayni (ilk hesaplanan)
/// aciklama gosterilirdi.
final levelUpPreviewProvider =
    FutureProvider.family<
      LevelUpPreview,
      ({String characterId, String classKey, String? subclassKey})
    >((ref, args) async {
      // Seviye atlayinca (characterClassLevels degisir -> classLevelsProvider
      // yeniden okur) bu ozet de yeniden hesaplanmali; yoksa family onbellegi
      // ilk hesaplanan "yeni seviye"de takilip kaliyor ve her acilista ayni
      // seviyeyi (ilk +1'i, or. hep 2) gosteriyordu.
      await ref.watch(classLevelsProvider(args.characterId).future);
      return ref
          .watch(characterRepositoryProvider)
          .previewLevelUp(
            characterId: args.characterId,
            classKey: args.classKey,
            subclassKey: args.subclassKey,
          );
    });

/// Sinif ve alt sinif sayaclari (Rages, Üstünlük Zarı, Ki...).
final classResourcesProvider =
    FutureProvider.family<Map<String, String>, String>((ref, id) async {
      await ref.watch(characterProvider(id).future);
      return ref.watch(characterRepositoryProvider).classResources(id);
    });

/// Karakterin buyu secim durumu (sinir, secili, kalan degistirme hakki).
final spellPreparationsProvider =
    FutureProvider.family<List<SpellPreparation>, String>((ref, id) async {
      await ref.watch(characterProvider(id).future);
      return ref.watch(characterRepositoryProvider).spellPreparations(id);
    });

final characterFeaturesProvider =
    FutureProvider.family<List<CharacterFeature>, String>((ref, id) async {
      await ref.watch(characterProvider(id).future);
      return ref.watch(characterRepositoryProvider).features(id);
    });

/// Karakterin butun yeterlilikleri (beceri ve kurtarma dahil).
final characterProficienciesProvider =
    FutureProvider.family<List<CharacterProficiency>, String>((ref, id) async {
      await ref.watch(characterProvider(id).future);
      return ref.watch(characterRepositoryProvider).proficiencies(id);
    });

/// Kaynaklarin biraktiği, henuz yapilmamis olabilecek secimler
/// (Bard'in uc calgisi, background'un "bir zanaatkar aleti sec"i).
final proficiencyChoicesProvider =
    FutureProvider.family<
      List<({ProficiencySource source, ProficiencyChoice choice})>,
      String
    >((ref, id) async {
      await ref.watch(characterProvider(id).future);
      return ref
          .watch(characterRepositoryProvider)
          .pendingProficiencyChoices(id);
    });

/// Bir alet kumesindeki secenekler: kutuphanedeki esya adlarindan geliyor.
final toolOptionsProvider = FutureProvider.family<List<String>, ToolGroup>((
  ref,
  group,
) async {
  const categories = {
    ToolGroup.artisansTools: ["Artisan's Tools"],
    ToolGroup.gamingSet: ['Gaming Set'],
    ToolGroup.musicalInstrument: ['Instrument'],
    ToolGroup.any: ['Tools', "Artisan's Tools", 'Gaming Set', 'Instrument'],
  };
  final db = ref.watch(databaseProvider);
  final rows = await (db.select(
    db.items,
  )..where((t) => t.category.isIn(categories[group]!))).get();
  // "Gaming Set, Dice" gibi bilesik adlarin ikinci parcasi yeterlilik
  // metinlerinde tek basina geciyor; fiyat parantezi de ada dahil degil.
  final names = <String>{};
  for (final row in rows) {
    var name = row.name;
    if (name.contains(', ')) name = name.split(', ').last;
    names.add(name.split(' (').first.trim());
  }
  return names.toList()..sort();
});

/// Elle eklenebilecek diller.
///
/// SRD 2024 verisinde dil YAPISAL degil (hicbir tur/gecmis dil vermiyor), bu
/// yuzden liste sozlukten geliyor; masada kullanilan 24 dil orada.
final languageOptionsProvider = FutureProvider<List<String>>((ref) async {
  final glossary = await ref.read(glossaryTrProvider.future);
  final known = glossary.keysOf('languages').toList();
  // Sozluk anahtarlari kucuk harf; kaydedilen deger de o bicimde olsun ki
  // tekrar eklemede cakismasin.
  return known.toList()..sort();
});

/// Silah ustaligi secilebilecek silahlar: mastery ozelligi olan her silah.
final masteryWeaponsProvider = FutureProvider<List<String>>((ref) async {
  final db = ref.watch(databaseProvider);
  final rows = await (db.select(
    db.items,
  )..where((t) => t.category.equals('Weapon'))).get();
  return (rows.map((r) => r.name).toSet().toList())..sort();
});

/// Seviye atlamada secilebilecek feat.
typedef FeatOption = ({
  String key,
  String name,
  String prerequisite,
  String description,
});

/// Verilen karakter seviyesinde alinabilecek feat'ler.
///
/// 2024 kurallarinda ASI seviyelerinde YALNIZCA General feat aliniyor; koken
/// feat'i gecmisten geliyor, Epic Boon 19+ seviyede. Metindeki "Level N+"
/// onkosulu da eleniyor.
final availableFeatsProvider = FutureProvider.family<List<FeatOption>, int>((
  ref,
  characterLevel,
) async {
  final db = ref.watch(databaseProvider);
  final rows = await db.select(db.feats).get();

  final out = <FeatOption>[];
  for (final row in rows) {
    final data = jsonDecode(row.dataJson) as Map<String, dynamic>;
    final type = '${data['type'] ?? ''}';
    final prerequisite = '${data['prerequisite'] ?? ''}';

    final isEpicBoon = type == 'Epic Boon';
    if (type != 'General' && !isEpicBoon) continue;

    final required = int.tryParse(
      RegExp(r'Level\s+(\d+)').firstMatch(prerequisite)?.group(1) ?? '',
    );
    if (required != null && characterLevel < required) continue;
    if (isEpicBoon && characterLevel < 19) continue;

    final benefits = [
      for (final b in (data['benefits'] as List? ?? const []).whereType<Map>())
        '${b['desc'] ?? ''}',
    ].where((s) => s.isNotEmpty);

    out.add((
      key: row.key,
      name: row.name,
      prerequisite: prerequisite,
      description: [
        '${data['desc'] ?? ''}'.trim(),
        ...benefits,
      ].where((s) => s.isNotEmpty).join('\n\n'),
    ));
  }
  out.sort((a, b) => a.name.compareTo(b.name));
  return out;
});

/// Karakterin siniflarina uygun sinif secenekleri.
final classOptionChoicesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, id) async {
      await ref.watch(characterProvider(id).future);
      return ref.watch(characterRepositoryProvider).classOptionsFor(id);
    });

final speciesOptionsProvider = FutureProvider<List<SpeciesEntry>>(
  (ref) => ref.watch(characterRepositoryProvider).speciesOptions(),
);

final backgroundOptionsProvider = FutureProvider<List<Background>>(
  (ref) => ref.watch(characterRepositoryProvider).backgroundOptions(),
);

final classOptionsProvider = FutureProvider<List<ClassDefinition>>(
  (ref) => ref.watch(characterRepositoryProvider).classOptions(),
);

/// Secilen background'in ayristirilmis faydalari.
final backgroundBenefitsProvider =
    FutureProvider.family<BackgroundBenefits?, String?>((ref, key) async {
      if (key == null) return null;
      final rows = await ref.watch(backgroundOptionsProvider.future);
      final row = rows.where((b) => b.key == key).firstOrNull;
      if (row == null) return null;
      final data = jsonDecode(row.dataJson) as Map<String, dynamic>;
      return parseBackgroundBenefits(data['benefits'] as List? ?? const []);
    });

/// Secilen sinifin cekirdek ozellikleri (hit die, kurtarma atislari,
/// beceri secenekleri, baslangic ekipmani).
final classCoreTraitsProvider =
    FutureProvider.family<ClassCoreTraits?, String?>((ref, key) async {
      if (key == null) return null;
      final rows = await ref.watch(classOptionsProvider.future);
      final row = rows.where((c) => c.key == key).firstOrNull;
      if (row == null) return null;

      final data = jsonDecode(row.dataJson) as Map<String, dynamic>;
      final core = (data['features'] as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .where((f) => '${f['feature_type']}' == 'CORE_TRAITS_TABLE')
          .firstOrNull;
      if (core == null) return null;
      return parseClassCoreTraits('${core['desc'] ?? ''}');
    });

/// Secilen turun boyut/hiz bilgisi.
final speciesTraitsProvider = FutureProvider.family<SpeciesTraits?, String?>((
  ref,
  key,
) async {
  if (key == null) return null;
  final rows = await ref.watch(speciesOptionsProvider.future);
  final row = rows.where((s) => s.key == key).firstOrNull;
  if (row == null) return null;
  final data = jsonDecode(row.dataJson) as Map<String, dynamic>;
  return parseSpeciesTraits(data['traits'] as List? ?? const []);
});

/// Sihirbaz taslagi.
class DraftNotifier extends Notifier<CharacterDraft> {
  @override
  CharacterDraft build() => const CharacterDraft();

  void update(CharacterDraft next) => state = next;

  void reset() => state = const CharacterDraft();
}

final characterDraftProvider = NotifierProvider<DraftNotifier, CharacterDraft>(
  DraftNotifier.new,
);
