import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/world_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fraksiyonlar: dunya grafiginin ucuncu dugum tipi.
///
/// Kritik nokta BAGLAR: fraksiyon kendi basina bir metin kutusu degil, bir
/// agin dugumu. `bondsOf` bir dugumun baglarini KARSI UC acisindan normalize
/// ediyor (kenarlar yonsuz, bag ya `aId` ya `bId` ucunda duruyor) ve bu
/// normalize etme sessizce bozulabilecek bir yer.
void main() {
  late AppDatabase db;
  late WorldRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = WorldRepository(db);
  });

  tearDown(() async => db.close());

  test('olusturulur, guncellenir, listelenir', () async {
    final id = await repo.createFaction(name: 'Kızıl Hançerler', kind: 'çete');

    var faction = (await repo.findFaction(id))!;
    expect(faction.name, 'Kızıl Hançerler');
    expect(faction.kind, 'çete');
    expect(faction.goal, isEmpty);

    await repo.updateFaction(id, goal: 'Limanı ele geçirmek');
    faction = (await repo.findFaction(id))!;
    expect(faction.goal, 'Limanı ele geçirmek');
    // Guncellenmeyen alan KORUNMALI: `null = degistirme` deseni.
    expect(faction.kind, 'çete');

    expect((await repo.allFactions()).map((f) => f.name), ['Kızıl Hançerler']);
  });

  test('bondsOf her iki uctan da bagi bulur ve karsi ucu verir', () async {
    final faction = await repo.createFaction(name: 'Tüccar Loncası');
    final npc = await repo.createNpc(name: 'Gundren');
    final place = await repo.createLocation(name: 'Liman');

    // NPC -> fraksiyon (fraksiyon `b` ucunda).
    await repo.createLink(
      npc,
      faction,
      xKind: 'npc',
      yKind: 'faction',
      type: 'membership',
    );
    // Fraksiyon -> yer (fraksiyon `a` ucunda).
    await repo.createLink(
      faction,
      place,
      xKind: 'faction',
      yKind: 'location',
      type: 'trade',
    );

    final bonds = await repo.bondsOf(faction);
    expect(bonds, hasLength(2));

    final membership = bonds.firstWhere((b) => b.type == 'membership');
    expect(membership.otherId, npc, reason: 'karsi uc NPC olmali');
    expect(membership.otherKind, 'npc');

    final trade = bonds.firstWhere((b) => b.type == 'trade');
    expect(trade.otherId, place);
    expect(trade.otherKind, 'location');

    // NPC tarafindan bakinca ayni bag, karsi uc fraksiyon.
    final npcBonds = await repo.bondsOf(npc);
    expect(npcBonds.single.otherId, faction);
    expect(npcBonds.single.otherKind, 'faction');
  });

  test('nodeName turune gore dogru tabloya bakar', () async {
    final faction = await repo.createFaction(name: 'Simyacılar');
    final npc = await repo.createNpc(name: 'Sildar');
    final place = await repo.createLocation(name: 'Mahzen');

    expect(await repo.nodeName('faction', faction), 'Simyacılar');
    expect(await repo.nodeName('npc', npc), 'Sildar');
    expect(await repo.nodeName('location', place), 'Mahzen');
    // Silinmis uc null doner; arayuz bagi "kopuk" gosterir.
    expect(await repo.nodeName('faction', 'yok'), isNull);
  });

  test('silinen fraksiyonun baglari da kalkar', () async {
    final faction = await repo.createFaction(name: 'Ejderha Kültü');
    final npc = await repo.createNpc(name: 'Kurgan');
    await repo.createLink(
      faction,
      npc,
      xKind: 'faction',
      yKind: 'npc',
      type: 'membership',
    );

    await repo.deleteFaction(faction);

    expect(await repo.findFaction(faction), isNull);
    expect(
      await repo.bondsOf(npc),
      isEmpty,
      reason: 'sarkitta kalan kenar grafigi bozardi',
    );
  });

  test('grafik konumu kalici', () async {
    final id = await repo.createFaction(name: 'Loncalar Birliği');
    await repo.setFactionGraphPosition(id, 12.5, -40);

    final faction = (await repo.findFaction(id))!;
    expect(faction.graphX, 12.5);
    expect(faction.graphY, -40);
  });
}
