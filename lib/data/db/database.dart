import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../campaign/campaign.dart';
import '../campaign/campaign_paths.dart';
import 'calendar_tables.dart';
import 'character_tables.dart';
import 'codex_tables.dart';
import 'combat_tables.dart';
import 'journey_tables.dart';
import 'loot_tables.dart';
import 'music_tables.dart';
import 'notes_tables.dart';
import 'party_tables.dart';
import 'quest_tables.dart';
import 'random_table_tables.dart';
import 'session_log_tables.dart';
import 'shop_tables.dart';
import 'tables.dart';
import 'world_tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Monsters,
    Spells,
    Items,
    MagicItems,
    ClassDefinitions,
    ClassProgressions,
    SpeciesEntries,
    Backgrounds,
    Feats,
    ReferenceEntries,
    ContentVersions,
    Characters,
    CharacterClassLevels,
    CharacterProficiencies,
    CharacterItems,
    CharacterSpells,
    CharacterFeatures,
    Encounters,
    Combatants,
    Shops,
    ShopStock,
    Locations,
    MapPins,
    WorldLinks,
    BondTypes,
    Npcs,
    LootSets,
    PartyInventories,
    RandomTables,
    Journeys,
    MusicPlaylists,
    MusicTracks,
    CharacterNotes,
    SessionLogEntries,
    CodexPages,
    CodexBlocks,
    Quests,
    CalendarConfig,
    CalendarMonths,
    CalendarWeekdays,
    CalendarSeasons,
    CalendarEras,
    ChronicleEvents,
    CalendarReminders,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: Campaign.defaultDbName));

  /// Belirli bir kampanyanın dosyasını açar.
  ///
  /// Yol [CampaignPaths.databaseFile] üzerinden çözülür; silme kodu da aynı
  /// fonksiyonu kullandığı için "açılan dosya" ile "silinen dosya" ayrışamaz.
  AppDatabase.forCampaign(String dbName)
    : super(
        driftDatabase(
          name: dbName,
          native: DriftNativeOptions(
            databasePath: () async =>
                (await CampaignPaths.databaseFile(dbName)).path,
          ),
        ),
      );

  @override
  int get schemaVersion => 31;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // Faz 1a: karakter tablolari. Tek tek yaziliyor -- liste uzerinde
        // donmek ortak ust tipe daralttigi icin createTable kabul etmiyor.
        await m.createTable(characters);
        await m.createTable(characterClassLevels);
        await m.createTable(characterProficiencies);
        await m.createTable(characterItems);
        await m.createTable(characterSpells);
        await m.createTable(characterFeatures);
      }
      if (from < 3) {
        // Faz 1a.5: savas takipcisi.
        await m.createTable(encounters);
        await m.createTable(combatants);
      }
      if (from < 4) {
        // Faz 2: magazalar.
        await m.createTable(shops);
        await m.createTable(shopStock);
      }
      if (from < 5) {
        // Faz 3: dunya haritasi ve bilgi agaci.
        await m.createTable(locations);
        await m.createTable(mapPins);
        await m.createTable(npcs);
      }
      if (from < 6) {
        // Zengin karakter kagidi: kisilik/gorunus alanlari.
        await m.addColumn(characters, characters.appearance);
        await m.addColumn(characters, characters.personality);
        await m.addColumn(characters, characters.ideal);
        await m.addColumn(characters, characters.bond);
        await m.addColumn(characters, characters.flaw);
      }
      if (from < 7) {
        // Haritadan dukkan erisimi.
        await m.addColumn(shops, shops.mapAccessible);
      }
      if (from < 8) {
        // Ganimet setleri.
        await m.createTable(lootSets);
      }
      if (from < 9) {
        // Oyuncu notlari (karaktere bagli).
        await m.createTable(characterNotes);
      }
      if (from < 10) {
        // Inisiyatifi oyuncular kendi atsin: atildi bayragi.
        await m.addColumn(combatants, combatants.initiativeRolled);
      }
      if (from < 11) {
        // Canavar portreleri.
        await m.addColumn(monsters, monsters.portraitPath);
      }
      if (from < 12) {
        // Kalici oturum gunlugu.
        await m.createTable(sessionLogEntries);
      }
      if (from < 13) {
        // DM bilgi tabani (Kayitlar): sayfalar + bloklar.
        await m.createTable(codexPages);
        await m.createTable(codexBlocks);
      }
      if (from < 14) {
        // Gorevler: DM gorevleri, oyunculara hedefli, kabul/ret.
        await m.createTable(quests);
      }
      if (from < 15) {
        // Dunya grafigi (DM-only dugum-agi): serbest konum + yonsuz baglantilar.
        await m.addColumn(locations, locations.graphX);
        await m.addColumn(locations, locations.graphY);
        await m.createTable(worldLinks);
        // Mevcut hiyerarsi (parentId) grafikte bagli gorunsun diye tohumla.
        final withParent = await (select(
          locations,
        )..where((t) => t.parentId.isNotNull())).get();
        for (final loc in withParent) {
          await into(worldLinks).insert(
            WorldLinksCompanion.insert(
              id: 'wl-${loc.parentId}-${loc.id}',
              aId: loc.parentId!,
              bId: loc.id,
            ),
          );
        }
      }
      if (from < 16) {
        // Tipli baglar + NPC dugumleri + zengin NPC alanlari.
        await m.addColumn(worldLinks, worldLinks.aKind);
        await m.addColumn(worldLinks, worldLinks.bKind);
        await m.addColumn(worldLinks, worldLinks.type);
        await m.addColumn(npcs, npcs.graphX);
        await m.addColumn(npcs, npcs.graphY);
        await m.addColumn(npcs, npcs.race);
        await m.addColumn(npcs, npcs.gender);
        await m.addColumn(npcs, npcs.age);
        await m.addColumn(npcs, npcs.alignment);
        await m.addColumn(npcs, npcs.appearance);
        await m.addColumn(npcs, npcs.personality);
        await m.addColumn(npcs, npcs.ideal);
        await m.addColumn(npcs, npcs.bond);
        await m.addColumn(npcs, npcs.flaw);
        await m.addColumn(npcs, npcs.hook);
      }
      if (from < 17) {
        // Duzenlenebilir bag turleri (ad + renk). Varsayilanlar arayuzde
        // (L10n ile) tohumlanir; migration yalnizca tabloyu acar.
        await m.createTable(bondTypes);
      }
      if (from < 18) {
        // Hazine pinleri icin ganimet baglantisi (loot set + kalan durum).
        await m.addColumn(mapPins, mapPins.lootSetId);
        await m.addColumn(mapPins, mapPins.lootDataJson);
      }
      if (from < 19) {
        // Magaza acik/kapali durumu. Kapaliyken oyuncular eşyaları görmez,
        // satin alamaz; pin üzerinde "mağaza kapalı" uyarısı alirlar.
        await m.addColumn(shops, shops.closed);
      }
      if (from < 20) {
        // Dunya grafigindeki dugumlerin gorsel yaricapi ("kure boyutu").
        // Sutunlar v19'da tablolara eklenmisti ama migration yazilmamisti;
        // mevcut veritabanlarinda boyut kaydetmek "no such column" veriyordu.
        await m.addColumn(locations, locations.nodeRadius);
        await m.addColumn(npcs, npcs.nodeRadius);
      }
      if (from < 21) {
        // Gorev odulleri (gercek esya + para) ve oylamali paylasim.
        await m.addColumn(quests, quests.shareMode);
        await m.addColumn(quests, quests.voteStatus);
        await m.addColumn(quests, quests.rewardCoinsCp);
        await m.addColumn(quests, quests.rewardItemsJson);
        await m.addColumn(quests, quests.rewardPoolJson);
      }
      if (from < 22) {
        // Oyun-ici takvim + tarihce. Kampanya = ayri veritabani oldugu icin
        // bu tablolarda campaignId yok; her kampanya kendi takvimini tasir.
        await m.createTable(calendarConfig);
        await m.createTable(calendarMonths);
        await m.createTable(calendarWeekdays);
        await m.createTable(calendarSeasons);
        await m.createTable(calendarEras);
        await m.createTable(chronicleEvents);
      }
      if (from < 23) {
        // Milat-mantigi yil eki: "MO" (cag oncesi, negatif yil) icin ayri
        // etiket. Mevcut yearSuffix "MS" (cag sonrasi) anlamina gelmeye devam
        // eder.
        await m.addColumn(calendarConfig, calendarConfig.beforeYearSuffix);
      }
      if (from < 24) {
        // Haritanin mil cinsinden olcegi (seyahat/mesafe hesaplayicisi).
        await m.addColumn(locations, locations.mapWidthMiles);
        await m.addColumn(locations, locations.mapHeightMiles);
      }
      if (from < 25) {
        // Ortak parti keseleri (uyeler serbestce alir/koyar).
        await m.createTable(partyInventories);
      }
      if (from < 26) {
        // Rastgele tablolar (zar at, satiri oku).
        await m.createTable(randomTables);
      }
      if (from < 27) {
        // Efsanevi eylem + efsanevi direnc sayaclari (DM-only).
        await m.addColumn(combatants, combatants.legendaryMax);
        await m.addColumn(combatants, combatants.legendarySpent);
        await m.addColumn(combatants, combatants.legendaryResistMax);
        await m.addColumn(combatants, combatants.legendaryResistSpent);
      }
      if (from < 28) {
        // Takvime bagli magaza stok yenilemesi.
        await m.addColumn(shops, shops.restockDays);
        await m.addColumn(shops, shops.lastRestockDay);
        await m.addColumn(shopStock, shopStock.restockQuantity);
      }
      if (from < 29) {
        // Suren yolculuk (rota + ilerleme + duran karsilasma).
        await m.createTable(journeys);
      }
      if (from < 30) {
        // Magazayi isleten NPC kaydina baglama (ad serbest metin olarak kalir).
        await m.addColumn(shops, shops.ownerNpcId);
      }
      if (from < 31) {
        // Muzik kutuphanesi + takvim hatirlaticilari.
        await m.createTable(musicPlaylists);
        await m.createTable(musicTracks);
        await m.createTable(calendarReminders);
      }
    },
    onCreate: (m) async {
      await m.createAll();
      // Kutuphane hep ada gore aranip CR/seviyeye gore filtrelendigi icin
      // bu iki eksen indeksleniyor.
      await customStatement(
        'CREATE INDEX idx_monsters_name ON monsters (name_lower)',
      );
      await customStatement(
        'CREATE INDEX idx_monsters_cr ON monsters (challenge_rating)',
      );
      await customStatement(
        'CREATE INDEX idx_spells_name ON spells (name_lower)',
      );
      await customStatement('CREATE INDEX idx_spells_level ON spells (level)');
      await customStatement(
        'CREATE INDEX idx_items_name ON items (name_lower)',
      );
      await customStatement(
        'CREATE INDEX idx_magic_items_name ON magic_items (name_lower)',
      );
      await customStatement(
        'CREATE INDEX idx_magic_items_rarity ON magic_items (rarity_rank)',
      );
    },
  );
}
