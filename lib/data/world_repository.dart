import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'character_image_store.dart';
import 'db/database.dart';
import 'db/world_tables.dart';
import 'loot_repository.dart';
import 'map_image_store.dart';

/// Bir pinin baglandigi kaydin okunabilir ozeti.
typedef PinTarget = ({String label, String? subtitle});

/// Bir NPC'nin ya da magazanin nerelerde geciyor oldugunu gosteren geri
/// referans.
typedef Backlink = ({String locationId, String locationName, String pinLabel});

/// Bir dugumun tek bir baglantisi, KARSI UC acisindan normalize edilmis.
typedef NodeBond = ({
  String linkId,
  String type,
  String otherId,
  String otherKind,
});

/// Dunya agaci: lokasyonlar, harita pinleri, NPC'ler.
class WorldRepository {
  WorldRepository(
    this.db, {
    MapImageStore? images,
    CharacterImageStore? portraits,
  }) : images = images ?? MapImageStore(),
       portraits = portraits ?? CharacterImageStore();

  final AppDatabase db;
  final MapImageStore images;

  /// NPC portreleri (karakter portresi deposuyla ayni klasor mantigi).
  final CharacterImageStore portraits;

  static const _uuid = Uuid();

  // --- Lokasyonlar --------------------------------------------------------

  /// Kok lokasyonlar (bir ust yeri olmayanlar).
  Stream<List<Location>> watchRoots() =>
      (db.select(db.locations)
            ..where((t) => t.parentId.isNull())
            ..orderBy([
              (t) => OrderingTerm(expression: t.sortOrder),
              (t) => OrderingTerm(expression: t.name),
            ]))
          .watch();

  Stream<List<Location>> watchChildren(String parentId) =>
      (db.select(db.locations)
            ..where((t) => t.parentId.equals(parentId))
            ..orderBy([
              (t) => OrderingTerm(expression: t.sortOrder),
              (t) => OrderingTerm(expression: t.name),
            ]))
          .watch();

  Stream<Location?> watchLocation(String id) => (db.select(
    db.locations,
  )..where((t) => t.id.equals(id))).watchSingleOrNull();

  /// TUM lokasyonlar (dunya grafigi dugumleri). Grafik hiyerarsiden bagimsiz,
  /// duz bir dugum-agi cizdigi icin hepsini birden ister.
  Stream<List<Location>> watchAllLocations() => (db.select(
    db.locations,
  )..orderBy([(t) => OrderingTerm(expression: t.createdAt)])).watch();

  /// "Haritasiz yer" ([PinKind.place]) pinlerinin arkasindaki lokasyon
  /// kimlikleri.
  ///
  /// Bu kayitlar GERCEK yer degil, harita uzerindeki isaretler: gorev
  /// ureticisinde ve seyahat planlayicida gozuksunler diye `Locations`
  /// tablosuna yaziliyorlar (bkz. `PinKind.place`). Dunya dugum agina
  /// girmemeleri gerekiyor -- oraya girince agi doldurup asil yerleri
  /// bogiyorlar.
  Stream<Set<String>> watchMarkerLocationIds() =>
      (db.select(
        db.mapPins,
      )..where((t) => t.kind.equalsValue(PinKind.place))).watch().map(
        (rows) => {
          for (final row in rows)
            if (row.targetId != null) row.targetId!,
        },
      );

  /// Grafikteki serbest konumu kaydeder. Yalnizca surukleme bitince / oturunca
  /// cagrilir; her frame degil (aksi halde her piksel bir yazma olurdu).
  Future<void> setGraphPosition(String id, double x, double y) async {
    await (db.update(db.locations)..where((t) => t.id.equals(id))).write(
      LocationsCompanion(graphX: Value(x), graphY: Value(y)),
    );
  }

  /// Birden cok dugumun konumunu TEK transaction'da yazar (grafik oturunca).
  /// Boylece tableUpdates yayini bir kez tetiklenir (N ayri yazma degil).
  Future<void> saveGraphPositions(
    List<({String id, double x, double y})> positions,
  ) async {
    if (positions.isEmpty) return;
    await db.transaction(() async {
      for (final p in positions) {
        await (db.update(db.locations)..where((t) => t.id.equals(p.id))).write(
          LocationsCompanion(graphX: Value(p.x), graphY: Value(p.y)),
        );
      }
    });
  }

  Future<Location?> find(String id) => (db.select(
    db.locations,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<Location>> children(String parentId) => (db.select(
    db.locations,
  )..where((t) => t.parentId.equals(parentId))).get();

  Future<String> createLocation({
    required String name,
    String? parentId,
    String description = '',
  }) async {
    final id = 'loc-${_uuid.v4()}';
    final siblings = parentId == null
        ? await (db.select(
            db.locations,
          )..where((t) => t.parentId.isNull())).get()
        : await children(parentId);

    await db
        .into(db.locations)
        .insert(
          LocationsCompanion.insert(
            id: id,
            name: name,
            parentId: Value(parentId),
            description: Value(description),
            sortOrder: Value(siblings.length),
          ),
        );
    return id;
  }

  Future<void> updateLocation(
    String id, {
    String? name,
    String? description,
    String? secretNotes,
    int? mapWidth,
    int? mapHeight,
    double? nodeRadius,
    bool? graphCollapsed,
  }) async {
    await (db.update(db.locations)..where((t) => t.id.equals(id))).write(
      LocationsCompanion(
        name: name == null ? const Value.absent() : Value(name),
        description: description == null
            ? const Value.absent()
            : Value(description),
        secretNotes: secretNotes == null
            ? const Value.absent()
            : Value(secretNotes),
        mapWidth: mapWidth == null ? const Value.absent() : Value(mapWidth),
        mapHeight: mapHeight == null ? const Value.absent() : Value(mapHeight),
        nodeRadius: nodeRadius == null
            ? const Value.absent()
            : Value(nodeRadius),
        graphCollapsed: graphCollapsed == null
            ? const Value.absent()
            : Value(graphCollapsed),
      ),
    );
  }

  /// Bir lokasyonu ve altindaki her seyi siler.
  ///
  /// Alt agac tek tek dolasiliyor: SQLite'ta ON DELETE CASCADE tanimlamak
  /// yerine burada yapmak, harita dosyalarini da temizleyebilmemizi sagliyor.
  Future<void> deleteLocation(String id) async {
    final toDelete = await _subtreeIds(id);
    // Tipli API: ham SQL Drift akislarini yenilemiyor (silinen yer listede
    // kaliyordu).
    for (final locationId in toDelete) {
      final location = await find(locationId);
      if (location != null) {
        await images.delete(location.mapImagePath);
      }
      await (db.delete(
        db.mapPins,
      )..where((t) => t.locationId.equals(locationId))).go();
      // Bu lokasyona isaret eden pinler de anlamsiz kalir. `place` de dahil:
      // haritasiz yer pininin arkasindaki lokasyon silinince pin sarkitta
      // kalir, tiklaninca "baglanti kopmus" gosterirdi.
      await (db.delete(db.mapPins)..where(
            (t) =>
                t.targetId.equals(locationId) &
                (t.kind.equalsValue(PinKind.location) |
                    t.kind.equalsValue(PinKind.place)),
          ))
          .go();
      // Bu yeri iceren grafik baglantilari da kalksin.
      await (db.delete(db.worldLinks)
            ..where((t) => t.aId.equals(locationId) | t.bId.equals(locationId)))
          .go();
      await (db.delete(
        db.locations,
      )..where((t) => t.id.equals(locationId))).go();
    }
  }

  // --- Dunya grafigi baglantilari (kenarlar) ------------------------------

  Stream<List<WorldLink>> watchLinks() => db.select(db.worldLinks).watch();

  /// Iki dugum (yer/NPC) arasinda yonsuz, tipli bir baglanti kurar. Uclar
  /// [xKind]/[yKind] ile 'location'/'npc' olabilir. Ayni cift (her iki sirada
  /// da) zaten varsa yalnizca tipini gunceller; kendine baglanti yok sayilir.
  Future<void> createLink(
    String x,
    String y, {
    String xKind = 'location',
    String yKind = 'location',
    String type = 'road',
  }) async {
    if (x == y) return;
    final existing =
        await (db.select(db.worldLinks)..where(
              (t) =>
                  (t.aId.equals(x) & t.bId.equals(y)) |
                  (t.aId.equals(y) & t.bId.equals(x)),
            ))
            .getSingleOrNull();
    if (existing != null) {
      await updateLinkType(existing.id, type);
      return;
    }
    await db
        .into(db.worldLinks)
        .insert(
          WorldLinksCompanion.insert(
            id: 'wl-${_uuid.v4()}',
            aId: x,
            bId: y,
            aKind: Value(xKind),
            bKind: Value(yKind),
            type: Value(type),
          ),
        );
  }

  /// Iki dugum arasindaki bagi bulur (yon fark etmez); yoksa null.
  Future<WorldLink?> findLink(String x, String y) =>
      (db.select(db.worldLinks)..where(
            (t) =>
                (t.aId.equals(x) & t.bId.equals(y)) |
                (t.aId.equals(y) & t.bId.equals(x)),
          ))
          .getSingleOrNull();

  /// Iki dugum arasindaki bagi siler (geri alma icin).
  Future<void> deleteLinkBetween(String x, String y) async {
    await (db.delete(db.worldLinks)..where(
          (t) =>
              (t.aId.equals(x) & t.bId.equals(y)) |
              (t.aId.equals(y) & t.bId.equals(x)),
        ))
        .go();
  }

  Future<void> updateLinkType(String id, String type) async {
    await (db.update(db.worldLinks)..where((t) => t.id.equals(id))).write(
      WorldLinksCompanion(type: Value(type)),
    );
  }

  Future<void> deleteLink(String id) async {
    await (db.delete(db.worldLinks)..where((t) => t.id.equals(id))).go();
  }

  // --- Bag turleri (duzenlenebilir ad + renk) -----------------------------

  Stream<List<BondType>> watchBondTypes() =>
      (db.select(db.bondTypes)..orderBy([
            (t) => OrderingTerm(expression: t.sortOrder),
            (t) => OrderingTerm(expression: t.name),
          ]))
          .watch();

  /// Ilk acilista varsayilan bag turlerini tohumlar (`ensureDefaultCalendar`
  /// ile AYNI desen: tablo TAMAMEN bossa tohumlar, tek tek "eksik" olani
  /// tamamlamaz).
  ///
  /// Eskiden DM'in SILDIGI bir varsayilan tur "eksik" sayilip her Dunya
  /// grafigi acilisinda (widget'in `_seeded` bayragi sayfa her acildiginda
  /// sifirlandigi icin bu fiilen "her acilista") sessizce geri ekleniyordu —
  /// silme hicbir zaman kalici olmuyordu. Artik yalnizca hic bag turu yoksa
  /// (ilk kurulum) tohumlanir.
  Future<void> ensureDefaultBondTypes(
    List<({String code, String name, int color, int sort})> defaults,
  ) async {
    if ((await db.select(db.bondTypes).get()).isNotEmpty) return;
    await db.batch((b) {
      for (final d in defaults) {
        b.insert(
          db.bondTypes,
          BondTypesCompanion.insert(
            code: d.code,
            name: d.name,
            color: d.color,
            sortOrder: Value(d.sort),
          ),
        );
      }
    });
  }

  Future<void> upsertBondType({
    required String code,
    required String name,
    required int color,
    int sort = 0,
  }) async {
    await db
        .into(db.bondTypes)
        .insertOnConflictUpdate(
          BondTypesCompanion.insert(
            code: code,
            name: name,
            color: color,
            sortOrder: Value(sort),
          ),
        );
  }

  Future<void> deleteBondType(String code) async {
    await (db.delete(db.bondTypes)..where((t) => t.code.equals(code))).go();
  }

  /// NPC dugumunun grafik konumu.
  Future<void> setNpcGraphPosition(String id, double x, double y) async {
    await (db.update(db.npcs)..where((t) => t.id.equals(id))).write(
      NpcsCompanion(graphX: Value(x), graphY: Value(y)),
    );
  }

  Future<void> saveNpcGraphPositions(
    List<({String id, double x, double y})> positions,
  ) async {
    if (positions.isEmpty) return;
    await db.transaction(() async {
      for (final p in positions) {
        await (db.update(db.npcs)..where((t) => t.id.equals(p.id))).write(
          NpcsCompanion(graphX: Value(p.x), graphY: Value(p.y)),
        );
      }
    });
  }

  Future<void> setFactionGraphPosition(String id, double x, double y) async {
    await (db.update(db.factions)..where((t) => t.id.equals(id))).write(
      FactionsCompanion(graphX: Value(x), graphY: Value(y)),
    );
  }

  Future<void> saveFactionGraphPositions(
    List<({String id, double x, double y})> positions,
  ) async {
    if (positions.isEmpty) return;
    await db.transaction(() async {
      for (final p in positions) {
        await (db.update(db.factions)..where((t) => t.id.equals(p.id))).write(
          FactionsCompanion(graphX: Value(p.x), graphY: Value(p.y)),
        );
      }
    });
  }

  Future<List<String>> _subtreeIds(String rootId) async {
    final result = <String>[];
    final queue = <String>[rootId];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      result.add(current);
      for (final child in await children(current)) {
        queue.add(child.id);
      }
    }
    // Yapraklar once silinsin.
    return result.reversed.toList();
  }

  /// Kokten bu lokasyona kadar olan yol; ekmek kirintisi icin.
  Future<List<Location>> breadcrumb(String id) async {
    final trail = <Location>[];
    String? current = id;
    // Dongusel veri kazayla olussa bile sonsuz donmesin.
    var guard = 0;
    while (current != null && guard++ < 50) {
      final location = await find(current);
      if (location == null) break;
      trail.insert(0, location);
      current = location.parentId;
    }
    return trail;
  }

  /// Haritayi kaydeder, onceki gorseli temizler.
  Future<void> setMapImage(String locationId, File source) async {
    final previous = await find(locationId);
    final stored = await images.store(source);

    await (db.update(
      db.locations,
    )..where((t) => t.id.equals(locationId))).write(
      LocationsCompanion(
        mapImagePath: Value(stored.imagePath),
        mapWidth: Value(stored.width),
        mapHeight: Value(stored.height),
      ),
    );

    if (previous != null) {
      await images.delete(previous.mapImagePath);
    }
  }

  Future<void> removeMapImage(String locationId) async {
    final location = await find(locationId);
    if (location == null) return;
    await images.delete(location.mapImagePath);
    await (db.update(
      db.locations,
    )..where((t) => t.id.equals(locationId))).write(
      const LocationsCompanion(
        mapImagePath: Value(null),
        mapWidth: Value(null),
        mapHeight: Value(null),
        // Gorsel gidince olcek de gider: haritasi olmayan bir yerde mil
        // olcegi erisilemez (ve anlamsiz) bir durum olurdu.
        mapWidthMiles: Value(null),
        mapHeightMiles: Value(null),
      ),
    );
  }

  /// Haritanin mil cinsinden olcegini yazar; iki deger de null verilirse
  /// olcegi TEMIZLER.
  ///
  /// [updateLocation] kullanilmaz: onun `x == null ? absent : Value(x)` deseni
  /// bir kolonu null'lamayi yapisal olarak imkansiz kilar, "olcegi temizle"
  /// ise gercek bir kullanici eylemi.
  Future<void> setMapScale(
    String locationId, {
    required double? widthMiles,
    required double? heightMiles,
  }) async {
    await (db.update(
      db.locations,
    )..where((t) => t.id.equals(locationId))).write(
      LocationsCompanion(
        mapWidthMiles: Value(widthMiles),
        mapHeightMiles: Value(heightMiles),
      ),
    );
  }

  // --- Pinler -------------------------------------------------------------

  Stream<List<MapPin>> watchPins(String locationId) =>
      (db.select(db.mapPins)
            ..where((t) => t.locationId.equals(locationId))
            ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
          .watch();

  Future<List<MapPin>> pins(String locationId) => (db.select(
    db.mapPins,
  )..where((t) => t.locationId.equals(locationId))).get();

  Future<String> addPin({
    required String locationId,
    required PinKind kind,
    required String label,
    required double x,
    required double y,
    String? targetId,
    String noteText = '',
    String? lootSetId,
    String? lootDataJson,
  }) async {
    final id = 'pin-${_uuid.v4()}';
    await db
        .into(db.mapPins)
        .insert(
          MapPinsCompanion.insert(
            id: id,
            locationId: locationId,
            kind: kind,
            label: label,
            x: x,
            y: y,
            targetId: Value(targetId),
            noteText: Value(noteText),
            lootSetId: Value(lootSetId),
            lootDataJson: Value(lootDataJson),
          ),
        );
    return id;
  }

  Future<void> updatePin(
    String id, {
    String? label,
    double? x,
    double? y,
    String? noteText,
    String? targetId,
    String? lootDataJson,
  }) async {
    await (db.update(db.mapPins)..where((t) => t.id.equals(id))).write(
      MapPinsCompanion(
        label: label == null ? const Value.absent() : Value(label),
        x: x == null ? const Value.absent() : Value(x),
        y: y == null ? const Value.absent() : Value(y),
        noteText: noteText == null ? const Value.absent() : Value(noteText),
        targetId: targetId == null ? const Value.absent() : Value(targetId),
        lootDataJson: lootDataJson == null
            ? const Value.absent()
            : Value(lootDataJson),
      ),
    );
  }

  /// Pini siler.
  ///
  /// `place` (haritasiz yer) pininde ARKASINDAKI lokasyon kaydi da silinir:
  /// o kayit tamamen bu pine ait, pin gidince yer seciclerinde sahipsiz bir
  /// satir olarak kalmasi istenmiyor. Diger turlerde hedef kayda (NPC,
  /// magaza, karsilasma) dokunulmaz -- onlar pinden bagimsiz yasar.
  Future<void> deletePin(String id) async {
    final pin = await (db.select(
      db.mapPins,
    )..where((t) => t.id.equals(id))).getSingleOrNull();

    await (db.delete(db.mapPins)..where((t) => t.id.equals(id))).go();

    if (pin != null && pin.kind == PinKind.place && pin.targetId != null) {
      await deleteLocation(pin.targetId!);
    }
  }

  /// Hazine pininden bir esya ya da parayi alir.
  ///
  /// [itemId] doluysa o esya, bossa kalan para (cp) alinir. Kalan ganimet
  /// DB'de guncellenir; biterse pin silinir. Donduren `deleted`: pin silindi
  /// mi; `error`: hata kodu (yoksa null); `takenName`: esya alindiyse adi,
  /// `takenCoinsCp`: para alindiyse miktari (cagiran envantere ekleyebilsin
  /// diye). Ayni esyayi iki oyuncu almak isterse ikincisi `itemGone` alir --
  /// esya iki kisiye de verilmez.
  Future<({bool deleted, String? error, String? takenName, int takenCoinsCp})>
  takeTreasureLoot(String pinId, {String? itemId}) async {
    final pin = await (db.select(
      db.mapPins,
    )..where((t) => t.id.equals(pinId))).getSingleOrNull();
    if (pin == null) {
      return (deleted: false, error: 'noPin', takenName: null, takenCoinsCp: 0);
    }
    final raw = pin.lootDataJson;
    if (raw == null || raw.isEmpty) {
      return (
        deleted: false,
        error: 'noLoot',
        takenName: null,
        takenCoinsCp: 0,
      );
    }

    final data = jsonDecode(raw) as Map<String, dynamic>;
    var coins = data['coinsCp'] as int? ?? 0;
    final items = <Map<String, dynamic>>[
      for (final e in (data['items'] as List? ?? const []))
        (e as Map).cast<String, dynamic>(),
    ];

    String? takenName;
    int takenCoinsCp = 0;
    if (itemId != null) {
      final index = items.indexWhere((i) => i['id'] == itemId);
      if (index == -1) {
        return (
          deleted: false,
          error: 'itemGone',
          takenName: null,
          takenCoinsCp: 0,
        );
      }
      takenName = items[index]['name'] as String? ?? '';
      items.removeAt(index);
    } else {
      if (coins <= 0) {
        return (
          deleted: false,
          error: 'noMoneyLeft',
          takenName: null,
          takenCoinsCp: 0,
        );
      }
      takenCoinsCp = coins;
      coins = 0;
    }

    if (items.isEmpty && coins <= 0) {
      await deletePin(pinId);
      return (
        deleted: true,
        error: null,
        takenName: takenName,
        takenCoinsCp: takenCoinsCp,
      );
    }

    await (db.update(db.mapPins)..where((t) => t.id.equals(pinId))).write(
      MapPinsCompanion(
        lootDataJson: Value(jsonEncode({'coinsCp': coins, 'items': items})),
      ),
    );
    return (
      deleted: false,
      error: null,
      takenName: takenName,
      takenCoinsCp: takenCoinsCp,
    );
  }

  /// Hazine pininin kalan TUM ganimetini (esyalar + para) alir ve pini siler.
  ///
  /// Donduren `items`/`coinsCp`: aktarilacak ganimet; cagiran bunlari hedef
  /// envantere ekler. Yarim kalmis bir hazine "Tumunu al" ile tek islemde
  /// tuketilir; pin DB'den silinir.
  Future<
    ({
      String? error,
      List<({String id, String name, bool magic})> items,
      int coinsCp,
    })
  >
  takeAllTreasureLoot(String pinId) async {
    final pin = await (db.select(
      db.mapPins,
    )..where((t) => t.id.equals(pinId))).getSingleOrNull();
    if (pin == null) {
      return (
        error: 'noPin',
        items: const <({String id, String name, bool magic})>[],
        coinsCp: 0,
      );
    }
    final loot = LootRepository.pinLootOf(pin.lootDataJson);
    if (loot == null) {
      return (
        error: 'noLoot',
        items: const <({String id, String name, bool magic})>[],
        coinsCp: 0,
      );
    }
    await deletePin(pinId);
    return (error: null, items: loot.items, coinsCp: loot.coinsCp);
  }

  /// Bir pinin isaret ettigi kaydin okunabilir ozeti.
  ///
  /// Pin bir alt lokasyona, NPC'ye ya da magazaya baglanabilir; hedef
  /// silinmisse null doner ve arayuz "bağlantı kopmuş" gosterir.
  Future<PinTarget?> resolveTarget(MapPin pin) async {
    // Hazine pini lootSetId'ye bakar (targetId degil); set adini gosterir.
    if (pin.kind == PinKind.treasure) {
      final lootSetId = pin.lootSetId;
      if (lootSetId == null) return null;
      final set = await (db.select(
        db.lootSets,
      )..where((t) => t.id.equals(lootSetId))).getSingleOrNull();
      return set == null ? null : (label: set.name, subtitle: null);
    }

    final targetId = pin.targetId;
    if (targetId == null) return null;

    switch (pin.kind) {
      case PinKind.location:
      case PinKind.place:
        final location = await find(targetId);
        return location == null
            ? null
            : (label: location.name, subtitle: location.description);
      case PinKind.npc:
        final npc = await (db.select(
          db.npcs,
        )..where((t) => t.id.equals(targetId))).getSingleOrNull();
        return npc == null ? null : (label: npc.name, subtitle: npc.role);
      case PinKind.shop:
        final shop = await (db.select(
          db.shops,
        )..where((t) => t.id.equals(targetId))).getSingleOrNull();
        return shop == null
            ? null
            : (label: shop.name, subtitle: shop.ownerName);
      case PinKind.encounter:
        final encounter = await (db.select(
          db.encounters,
        )..where((t) => t.id.equals(targetId))).getSingleOrNull();
        return encounter == null
            ? null
            : (label: encounter.name, subtitle: null);
      case PinKind.note:
      case PinKind.treasure:
        return null;
    }
  }

  /// "Bu NPC nerelerde geciyor?" -- bilgi agacinin geri referanslari.
  Future<List<Backlink>> backlinks(String targetId) async {
    final rows = await (db.select(
      db.mapPins,
    )..where((t) => t.targetId.equals(targetId))).get();

    final result = <Backlink>[];
    for (final pin in rows) {
      final location = await find(pin.locationId);
      if (location == null) continue;
      result.add((
        locationId: location.id,
        locationName: location.name,
        pinLabel: pin.label,
      ));
    }
    return result;
  }

  // --- NPC'ler ------------------------------------------------------------

  Stream<List<Npc>> watchNpcs() => (db.select(
    db.npcs,
  )..orderBy([(t) => OrderingTerm(expression: t.name)])).watch();

  Future<List<Npc>> allNpcs() => (db.select(
    db.npcs,
  )..orderBy([(t) => OrderingTerm(expression: t.name)])).get();

  Future<String> createNpc({
    required String name,
    String role = '',
    String description = '',
    String race = '',
    String gender = '',
    String age = '',
    String alignment = '',
    String appearance = '',
    String personality = '',
    String ideal = '',
    String bond = '',
    String flaw = '',
    String hook = '',
    String secretNotes = '',
    String? monsterKey,
  }) async {
    final id = 'npc-${_uuid.v4()}';
    await db
        .into(db.npcs)
        .insert(
          NpcsCompanion.insert(
            id: id,
            name: name,
            role: Value(role),
            description: Value(description),
            race: Value(race),
            gender: Value(gender),
            age: Value(age),
            alignment: Value(alignment),
            appearance: Value(appearance),
            personality: Value(personality),
            ideal: Value(ideal),
            bond: Value(bond),
            flaw: Value(flaw),
            hook: Value(hook),
            secretNotes: Value(secretNotes),
            monsterKey: Value(monsterKey),
          ),
        );
    return id;
  }

  Future<void> updateNpc(
    String id, {
    String? name,
    String? role,
    String? description,
    String? race,
    String? gender,
    String? age,
    String? alignment,
    String? appearance,
    String? personality,
    String? ideal,
    String? bond,
    String? flaw,
    String? hook,
    String? secretNotes,
    Value<String?> monsterKey = const Value.absent(),
    double? nodeRadius,
  }) async {
    Value<String> v(String? s) => s == null ? const Value.absent() : Value(s);
    await (db.update(db.npcs)..where((t) => t.id.equals(id))).write(
      NpcsCompanion(
        name: v(name),
        role: v(role),
        description: v(description),
        race: v(race),
        gender: v(gender),
        age: v(age),
        alignment: v(alignment),
        appearance: v(appearance),
        personality: v(personality),
        ideal: v(ideal),
        bond: v(bond),
        flaw: v(flaw),
        hook: v(hook),
        secretNotes: v(secretNotes),
        monsterKey: monsterKey,
        nodeRadius: nodeRadius == null
            ? const Value.absent()
            : Value(nodeRadius),
      ),
    );
  }

  Future<Npc?> findNpc(String id) =>
      (db.select(db.npcs)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> setNpcPortrait(String id, File source) async {
    final previous = await findNpc(id);
    final stored = await portraits.store(source);
    await (db.update(db.npcs)..where((t) => t.id.equals(id))).write(
      NpcsCompanion(portraitPath: Value(stored)),
    );
    await portraits.delete(previous?.portraitPath);
  }

  /// AI ile uretilen portreyi (ham baytlar) NPC'ye yazar. [setNpcPortrait]'in
  /// dosya yerine bellekten calisan esi.
  Future<void> setNpcPortraitFromBytes(String id, Uint8List bytes) async {
    final previous = await findNpc(id);
    final stored = await portraits.storeBytes(bytes);
    await (db.update(db.npcs)..where((t) => t.id.equals(id))).write(
      NpcsCompanion(portraitPath: Value(stored)),
    );
    await portraits.delete(previous?.portraitPath);
  }

  Future<void> removeNpcPortrait(String id) async {
    final npc = await findNpc(id);
    if (npc == null) return;
    await portraits.delete(npc.portraitPath);
    await (db.update(db.npcs)..where((t) => t.id.equals(id))).write(
      const NpcsCompanion(portraitPath: Value(null)),
    );
  }

  /// NPC'yi ve ona bagli her seyi siler; GERI ALMA islevi doner.
  ///
  /// Silme kaskad: haritadaki pinler ve grafik baglantilari da gidiyor.
  /// Geri alma yalnizca NPC satirini koysaydi, kullanici "geri alindi"
  /// bildirimini gorup pinlerini kaybetmis olurdu -- o yuzden silinen her
  /// sey burada yakalaniyor.
  Future<Future<void> Function()> deleteNpcUndoable(String id) async {
    final npc = await findNpc(id);
    final pins =
        await (db.select(db.mapPins)..where(
              (t) => t.targetId.equals(id) & t.kind.equalsValue(PinKind.npc),
            ))
            .get();
    final links = await (db.select(
      db.worldLinks,
    )..where((t) => t.aId.equals(id) | t.bId.equals(id))).get();

    await deleteNpc(id);

    return () async {
      if (npc == null) return;
      await db.transaction(() async {
        await db.into(db.npcs).insertOnConflictUpdate(npc.toCompanion(false));
        for (final pin in pins) {
          await db
              .into(db.mapPins)
              .insertOnConflictUpdate(pin.toCompanion(false));
        }
        for (final link in links) {
          await db
              .into(db.worldLinks)
              .insertOnConflictUpdate(link.toCompanion(false));
        }
      });
    };
  }

  Future<void> deleteNpc(String id) async {
    final npc = await findNpc(id);
    await db.transaction(() async {
      // NPC'ye isaret eden pinler bosa dusmesin. Tipli API: ham SQL Drift
      // akislarini yenilemiyor.
      await (db.delete(db.mapPins)..where(
            (t) => t.targetId.equals(id) & t.kind.equalsValue(PinKind.npc),
          ))
          .go();
      // Grafik baglantilarini da kaldir.
      await (db.delete(
        db.worldLinks,
      )..where((t) => t.aId.equals(id) | t.bId.equals(id))).go();
      await (db.delete(db.npcs)..where((t) => t.id.equals(id))).go();
    });
    await portraits.delete(npc?.portraitPath);
  }

  // --- Fraksiyonlar -------------------------------------------------------

  Stream<List<Faction>> watchFactions() => (db.select(
    db.factions,
  )..orderBy([(t) => OrderingTerm(expression: t.name)])).watch();

  Future<List<Faction>> allFactions() => (db.select(
    db.factions,
  )..orderBy([(t) => OrderingTerm(expression: t.name)])).get();

  Stream<Faction?> watchFaction(String id) => (db.select(
    db.factions,
  )..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<Faction?> findFaction(String id) =>
      (db.select(db.factions)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<String> createFaction({required String name, String kind = ''}) async {
    final id = 'faction-${_uuid.v4()}';
    await db
        .into(db.factions)
        .insert(
          FactionsCompanion.insert(id: id, name: name, kind: Value(kind)),
        );
    return id;
  }

  Future<void> updateFaction(
    String id, {
    String? name,
    String? kind,
    String? description,
    String? goal,
    String? secretNotes,
    double? nodeRadius,
  }) async {
    Value<String> v(String? s) => s == null ? const Value.absent() : Value(s);
    await (db.update(db.factions)..where((t) => t.id.equals(id))).write(
      FactionsCompanion(
        name: v(name),
        kind: v(kind),
        description: v(description),
        goal: v(goal),
        secretNotes: v(secretNotes),
        nodeRadius: nodeRadius == null
            ? const Value.absent()
            : Value(nodeRadius),
      ),
    );
  }

  Future<void> setFactionEmblem(String id, File source) async {
    final previous = await findFaction(id);
    final stored = await portraits.store(source);
    await (db.update(db.factions)..where((t) => t.id.equals(id))).write(
      FactionsCompanion(portraitPath: Value(stored)),
    );
    await portraits.delete(previous?.portraitPath);
  }

  Future<void> clearFactionEmblem(String id) async {
    final faction = await findFaction(id);
    if (faction == null) return;
    await (db.update(db.factions)..where((t) => t.id.equals(id))).write(
      const FactionsCompanion(portraitPath: Value(null)),
    );
    await portraits.delete(faction.portraitPath);
  }

  Future<void> deleteFaction(String id) async {
    final faction = await findFaction(id);
    await db.transaction(() async {
      await (db.delete(
        db.worldLinks,
      )..where((t) => t.aId.equals(id) | t.bId.equals(id))).go();
      await (db.delete(db.factions)..where((t) => t.id.equals(id))).go();
    });
    await portraits.delete(faction?.portraitPath);
  }

  /// Bir dugumun (yer/NPC/fraksiyon) TUM baglantilari, iki yonde de.
  ///
  /// Grafik kenarlari yonsuz: bir bag ya `aId` ya `bId` ucunda duruyor.
  /// Cagiran taraf "karsi uc kim" diye ugrasmasin diye burada normalize
  /// ediliyor.
  Future<List<NodeBond>> bondsOf(String nodeId) async {
    final rows = await (db.select(
      db.worldLinks,
    )..where((t) => t.aId.equals(nodeId) | t.bId.equals(nodeId))).get();
    return [
      for (final row in rows)
        (
          linkId: row.id,
          type: row.type,
          otherId: row.aId == nodeId ? row.bId : row.aId,
          otherKind: row.aId == nodeId ? row.bKind : row.aKind,
        ),
    ];
  }

  /// Bir dugumun adini turune gore cozer; kayit silinmisse null.
  Future<String?> nodeName(String kind, String id) async => switch (kind) {
    'npc' => (await findNpc(id))?.name,
    'faction' => (await findFaction(id))?.name,
    _ => (await find(id))?.name,
  };
}
