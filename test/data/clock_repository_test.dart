import 'package:dm_table/data/clock_repository.dart';
import 'package:dm_table/data/db/clock_tables.dart';
import 'package:dm_table/data/db/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ilerleme saatleri.
///
/// Saatte kural motoru YOK; tek gercek kural sinirlarin asilmamasi. Tasan ya
/// da negatif bir `filled` degeri kadranda sessizce bozuk cizim uretir (dolu
/// dilim sayisi dilim sayisindan buyuk olur), bu yuzden sinirlar burada
/// kilitleniyor.
void main() {
  late AppDatabase db;
  late ClockRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ClockRepository(db);
  });

  tearDown(() async => db.close());

  test('varsayilan degerlerle olusturulur', () async {
    final id = await repo.create(name: 'Kuşatma geliyor');
    final clock = (await repo.find(id))!;

    expect(clock.name, 'Kuşatma geliyor');
    expect(clock.segments, ClockRepository.defaultSegments);
    expect(clock.filled, 0);
    expect(clock.done, isFalse);
    expect(clock.linkKind, ClockLinkKind.none);
    expect(ClockRepository.isFull(clock), isFalse);
  });

  test('advance sinirda durur, negatife dusmez', () async {
    final id = await repo.create(name: 'Ayin', segments: 4);

    await repo.advance(id, by: 3);
    expect((await repo.find(id))!.filled, 3);

    // Tasma yok: dort dilimli bir saat besinci dilime gecemez.
    await repo.advance(id, by: 5);
    final full = (await repo.find(id))!;
    expect(full.filled, 4);
    expect(ClockRepository.isFull(full), isTrue);
    // Dolan saat KENDILIGINDEN kapanmaz; kapatmak DM'in karari.
    expect(full.done, isFalse);

    await repo.advance(id, by: -10);
    expect((await repo.find(id))!.filled, 0);
  });

  test('dilim sayisi kucululunce dolu dilim kirpilir', () async {
    final id = await repo.create(name: 'Söylenti', segments: 8);
    await repo.advance(id, by: 7);

    await repo.update(id, segments: 4);

    final clock = (await repo.find(id))!;
    expect(clock.segments, 4);
    expect(clock.filled, 4, reason: 'dolu dilim toplami asamaz');
  });

  test('dilim sayisi sinirlara kirpilir', () async {
    final tooMany = await repo.create(name: 'Çok', segments: 99);
    expect((await repo.find(tooMany))!.segments, ClockRepository.maxSegments);

    final tooFew = await repo.create(name: 'Az', segments: 1);
    expect((await repo.find(tooFew))!.segments, ClockRepository.minSegments);
  });

  test('setFilled dogrudan ayarlar ve kirpar', () async {
    final id = await repo.create(name: 'Fırtına', segments: 6);

    await repo.setFilled(id, 4);
    expect((await repo.find(id))!.filled, 4);

    await repo.setFilled(id, 99);
    expect((await repo.find(id))!.filled, 6);

    await repo.setFilled(id, -3);
    expect((await repo.find(id))!.filled, 0);
  });

  test('bagli saatler yalnizca kendi kaydinda listelenir', () async {
    await repo.create(
      name: 'Görev saati',
      linkKind: ClockLinkKind.quest,
      linkId: 'quest-1',
    );
    await repo.create(
      name: 'Başka görev',
      linkKind: ClockLinkKind.quest,
      linkId: 'quest-2',
    );
    await repo.create(name: 'Serbest saat');

    final linked = await repo.watchLinked(ClockLinkKind.quest, 'quest-1').first;
    expect(linked.map((c) => c.name), ['Görev saati']);

    // Tum saatler listesinde ucu de var.
    expect(await repo.watchAll().first, hasLength(3));
  });

  test('bag kaldirilinca linkId de temizlenir', () async {
    final id = await repo.create(
      name: 'Ayin',
      linkKind: ClockLinkKind.faction,
      linkId: 'faction-1',
    );

    await repo.setLink(id, ClockLinkKind.none, null);

    final clock = (await repo.find(id))!;
    expect(clock.linkKind, ClockLinkKind.none);
    expect(
      clock.linkId,
      isNull,
      reason: 'sarkitta kalan kimlik yanlis kayda baglanabilirdi',
    );
  });

  test('kapatilan saat listenin sonuna duser', () async {
    final first = await repo.create(name: 'Bir');
    await repo.create(name: 'İki');

    await repo.setDone(first, true);

    expect((await repo.watchAll().first).map((c) => c.name), ['İki', 'Bir']);
  });
}
