import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../campaign/campaign.dart';
import '../campaign/campaign_paths.dart';
import 'calendar_tables.dart';
import 'character_tables.dart';
import 'clock_tables.dart';
import 'codex_tables.dart';
import 'combat_tables.dart';
import 'journey_tables.dart';
import 'loot_tables.dart';
import 'music_tables.dart';
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
    Factions,
    LootSets,
    PartyInventories,
    RandomTables,
    Journeys,
    MusicPlaylists,
    MusicTracks,
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
    ContentSources,
    EncounterTemplates,
    Macros,
    DowntimeActivities,
    Clocks,
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
  int get schemaVersion => 51;

  /// Sutunu YOKSA ekler.
  ///
  /// **Neden gerekli:** drift `onUpgrade`'i tek bir islem (transaction) icinde
  /// kosturmuyor. Zincirin ortasinda bir adim patlarsa ondan onceki
  /// `ALTER TABLE ... ADD COLUMN`lar dosyada KALIR ama `user_version`
  /// ilerlemez; bir sonraki acilista ayni blok bastan kosar ve bu kez
  /// "duplicate column" ile patlar. Dosya iki hata arasinda sikisir.
  ///
  /// Bu tam olarak v42'ye gecişte yasandi: v41 blogu sutunu ekledikten sonra
  /// tabloyu URETILMIS bir sorguyla okumaya calisti (o sorgu tablonun guncel
  /// kolonlarini ister, oysa yenileri bir sonraki blokta ekleniyor) ve
  /// patladi. Yeni blok yazarken hem bu yardimci hem de "migration icinde
  /// tablo okurken ham SQL" kurali gecerli.
  Future<void> _addColumnIfMissing(
    Migrator m,
    TableInfo<Table, dynamic> table,
    GeneratedColumn<Object> column,
  ) async {
    final rows = await customSelect(
      'PRAGMA table_info(${table.actualTableName})',
    ).get();
    // Tablo HIC YOKSA: bu veritabani o tablodan onceki bir surumden geliyor
    // demektir ve zincirin daha erken bir adimindaki `createTable` onu
    // GUNCEL kolonlariyla kuracak. Burada ALTER denemek "no such table" ile
    // patlardi.
    if (rows.isEmpty) return;
    final existing = {for (final row in rows) row.read<String>('name')};
    if (existing.contains(column.name)) return;
    await m.addColumn(table, column);
  }

  /// Sutunu VARSA dusurur.
  ///
  /// [_addColumnIfMissing]'in aynasi ve ayni sebeple var: v48 artik yasamayan
  /// (oyuncu paneline ozel) sutunlari dusuruyor, ama ayni veritabani zincirin
  /// hangi adimindan geldigine gore o sutunu hic edinmemis olabilir --
  /// `onCreate` guncel semayi yaziyor. Kosulsuz `DROP COLUMN` orada
  /// "no such column" ile patlardi.
  ///
  /// Tablo adi ve sutun adi HAM METIN: sutunlar bu surumde tablo
  /// tanimlarindan silindigi icin uretilmis bir `GeneratedColumn` referansi
  /// artik yok.
  Future<void> _dropColumnIfPresent(String table, String column) async {
    final rows = await customSelect('PRAGMA table_info($table)').get();
    if (rows.isEmpty) return;
    final existing = {for (final row in rows) row.read<String>('name')};
    if (!existing.contains(column)) return;
    await customStatement('ALTER TABLE $table DROP COLUMN $column');
  }

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
      // v7 (haritadan dukkan erisimi), v9 (oyuncu notlari) ve v10 (oyuncunun
      // kendi inisiyatifini atmasi) BOS BIRAKILDI: uc adimin da actigi
      // tablo/sutun v48'de dusuruldu, yani once yaratip sonra silmek olurdu.
      if (from < 8) {
        // Ganimet setleri.
        await m.createTable(lootSets);
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
        // Gorevler.
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
        // Gorev odulleri (gercek esya + para). Ayni adimda gelen oylama
        // sutunlari (shareMode/voteStatus/rewardPoolJson) v48'de dusuruldu.
        await m.addColumn(quests, quests.rewardCoinsCp);
        await m.addColumn(quests, quests.rewardItemsJson);
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
      if (from < 32) {
        // Karsilasma paneli: DM brifingi + savastan cikacak ganimet.
        await m.addColumn(encounters, encounters.briefingJson);
        await m.addColumn(encounters, encounters.lootJson);
      }
      if (from < 33 && from >= 31) {
        // Muzik listelerinde kategori (alt liste) hiyerarsisi.
        //
        // `from >= 31` sarti SART: `musicPlaylists` v31 blogunda createTable
        // ile kuruluyor ve createTable GUNCEL semayi (parentId dahil) yaziyor.
        // Daha eski bir veritabani o yoldan gelince sutun zaten var olur,
        // ikinci kez eklemek "duplicate column name" ile patlar.
        await m.addColumn(musicPlaylists, musicPlaylists.parentId);
      }
      if (from < 34) {
        // Oyuncunun kendi buyulerini secmesi: kalan degistirme hakki.
        await m.addColumn(characters, characters.spellChangesAvailable);
      }
      if (from < 35) {
        // Konsantrasyon takibi.
        await m.addColumn(characters, characters.concentrationSpell);
      }
      if (from < 37) {
        // AI ile istege bagli ceviri (v36) kaldirildi: kutuphane metinlerinin
        // Turkcesi artik `assets/data/tr/*.json` ile paketle birlikte geliyor,
        // yani onbellege gerek yok. Tablo v36'dan gecen veritabanlarinda
        // duruyor olabilir.
        await customStatement('DROP TABLE IF EXISTS content_translations');
      }
      if (from < 38) {
        // Ekipman yuvalari: kusanilan esyanin yeri ve karakter bazinda
        // duzenlenebilen yuva sinirlari.
        await m.addColumn(characterItems, characterItems.slot);
        await m.addColumn(characters, characters.slotCapacitiesJson);
      }
      if (from < 42) {
        // Dunya grafiginde katlama. Ayni adimda gelen savas haritasi
        // sutunlari (jeton yonu/kilidi, isik, karanlik gorusu, sahne sesi)
        // v48'de tabloyla birlikte dusuruldu.
        await _addColumnIfMissing(m, locations, locations.graphCollapsed);
      }
      // v43 (noktasal isik/ses kaynaklari), v44 (cizim ve tile katmanlari) ve
      // v45 (kor gorusu/titresim duyusu/hakiki gorus) BOS: hepsi savas
      // haritasi tablolarina aitti, v48'de dusuruldu.
      if (from < 46) {
        // Kullanicinin tanimladigi icerik kaynaklari.
        await m.createTable(contentSources);
      }
      if (from < 47) {
        // Savas takibi: reaksiyon, hasar turu savunmalari, olum kurtarmasi.
        await _addColumnIfMissing(m, combatants, combatants.reactionUsed);
        await _addColumnIfMissing(m, combatants, combatants.defensesJson);
        await _addColumnIfMissing(m, combatants, combatants.deathSaveSuccesses);
        await _addColumnIfMissing(m, combatants, combatants.deathSaveFailures);
        // Tur sayaci ve in (lair) eylemi.
        await _addColumnIfMissing(m, encounters, encounters.turnLimitSeconds);
        await _addColumnIfMissing(m, encounters, encounters.lairActionText);
        await _addColumnIfMissing(m, encounters, encounters.lairInitiative);
        // Karsilasma kaliplari, makrolar, bos zaman faaliyetleri.
        await m.createTable(encounterTemplates);
        await m.createTable(macros);
        await m.createTable(downtimeActivities);
      }
      if (from < 48) {
        // Uygulama TEK KISILIK bir DM aracina donduruldu: yerel ag sunucusu,
        // oyuncu web paneli ve savas haritasi kaldirildi. Bu blok o iki
        // ozelligin geride biraktigi semayi temizler.
        //
        // Neden gercekten DUSURULUYOR (bosta birakilmiyor): savas haritasi
        // tablolari kampanya dosyasinin en buyuk parcasiydi -- jeton, sis
        // katmani ve tile satirlari. Okunmayan bir tablo olarak birakmak
        // yedek arsivini ve kampanya birlestirmeyi de bosuna sisirirdi.
        //
        // GERI DONUSU YOK: bu satirlarin yedegi alinmadiysa savas haritalari
        // ve oyuncu notlari kalici olarak gider.
        for (final table in const [
          'battle_maps',
          'battle_walls',
          'battle_tokens',
          'battle_levels',
          'battle_fog_layers',
          'battle_templates',
          'battle_lights',
          'battle_sounds',
          'battle_drawings',
          'battle_tiles',
          'character_notes',
        ]) {
          await customStatement('DROP TABLE IF EXISTS $table');
        }

        // Yalnizca "oyuncu ne goruyor?" sorusunu cevaplamak icin var olan
        // sutunlar. Kesif/gizleme kavraminin kendisi de gitti: izleyen
        // olmayinca gorunurluk bayraginin anlami kalmiyor.
        const droppedColumns = <String, List<String>>{
          'locations': ['revealed', 'map_preview_path'],
          'map_pins': ['revealed'],
          'shops': ['open_to_players', 'map_accessible', 'requires_approval'],
          'quests': [
            'shared',
            'acceptances_json',
            'share_mode',
            'vote_status',
            'reward_pool_json',
          ],
          'combatants': ['initiative_rolled', 'hidden_from_players'],
          // Makronun "kime gorunsun" alani (dm/player/both); artik tek
          // izleyici var.
          'macros': ['scope'],
        };
        for (final entry in droppedColumns.entries) {
          for (final column in entry.value) {
            await _dropColumnIfPresent(entry.key, column);
          }
        }
      }
      if (from < 49) {
        // Karsilasma <-> yer bagi. Bu bag eskiden savas haritasi tablosunda
        // (`battle_maps.encounter_id`) dolayli olarak duruyordu ve harita
        // v48'de kaldirilinca koptu; artik karsilasmanin kendi sutunu.
        await _addColumnIfMissing(m, encounters, encounters.locationId);
      }
      if (from < 50) {
        // Fraksiyonlar: dunya grafiginin ucuncu dugum tipi.
        await m.createTable(factions);

        // "Uyelik" bag turu. `ensureDefaultBondTypes` yalnizca tablo TAMAMEN
        // bossa tohumluyor (kullanicinin sildigi/adlandirdigi turler geri
        // gelmesin diye), yani mevcut kampanyalar yeni varsayilani oradan
        // ALAMAZ. Bu yuzden burada, tek seferlik ekleniyor.
        //
        // Adi Ingilizce: migration'in dili yok. DM bag turu ayarlarindan tek
        // dokunusla degistirebiliyor; taze kampanyalar zaten cevirisini
        // `defaultBondTypes` uzerinden aliyor.
        //
        // Once `createTable`: bu adim BASKA bir adimin actigi tabloya yaziyor
        // ve boyle bir bagimlilik sessizce kirilgan. `createTable` zaten
        // "IF NOT EXISTS", yani var olan tabloya dokunmuyor; karsiligindaysa
        // blok kendi kendine yetiyor ve zincirin hangi surumden basladigindan
        // bagimsiz calisiyor.
        await m.createTable(bondTypes);
        await into(bondTypes).insert(
          BondTypesCompanion.insert(
            code: 'membership',
            name: 'Membership',
            color: 0xFF8D6E63,
            sortOrder: const Value(9),
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
      if (from < 51) {
        // Ilerleme saatleri (progress clocks).
        await m.createTable(clocks);
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
