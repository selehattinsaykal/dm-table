import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'db/clock_tables.dart';
import 'db/database.dart';

/// Ilerleme saatlerini okur/yazar.
///
/// Kural motoru DEGIL: saat yalnizca "kac dilim doldu" tutuyor, ilerletmeyi
/// her zaman DM yapiyor. Buradaki tek gercek kural [advance]'in siniri
/// asmamasi -- masada en sik yapilan hata bir saati fazladan ilerletmek ve
/// negatif/tasan degerler UI'da sessizce bozuk cizim uretiyordu.
class ClockRepository {
  const ClockRepository(this.db);

  final AppDatabase db;
  static const _uuid = Uuid();

  /// Varsayilan dilim sayisi. Dort "yakin", sekiz "uzak"; alti ikisinin
  /// arasinda ve masada en cok kullanilan olcu.
  static const defaultSegments = 6;

  /// Dilim sayisi siniri. Ustu okunmuyor (daire dilimleri kil gibi kaliyor),
  /// altinda saat olmuyor.
  static const minSegments = 2;
  static const maxSegments = 12;

  /// Acik saatler once, kapatilanlar sonra; her grup kendi sirasinda.
  Stream<List<Clock>> watchAll() =>
      (db.select(db.clocks)..orderBy([
            (t) => OrderingTerm(expression: t.done),
            (t) => OrderingTerm(expression: t.sortOrder),
            (t) => OrderingTerm(expression: t.createdAt),
          ]))
          .watch();

  /// Belirli bir kayda bagli saatler (gorev/fraksiyon/yer/NPC sayfasi icin).
  Stream<List<Clock>> watchLinked(ClockLinkKind kind, String linkId) =>
      (db.select(db.clocks)
            ..where(
              (t) => t.linkKind.equalsValue(kind) & t.linkId.equals(linkId),
            )
            ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
          .watch();

  Future<Clock?> find(String id) =>
      (db.select(db.clocks)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<String> create({
    required String name,
    int segments = defaultSegments,
    String outcome = '',
    ClockLinkKind linkKind = ClockLinkKind.none,
    String? linkId,
  }) async {
    final id = 'clock-${_uuid.v4()}';
    final count = (await db.select(db.clocks).get()).length;
    await db
        .into(db.clocks)
        .insert(
          ClocksCompanion.insert(
            id: id,
            name: name,
            segments: Value(segments.clamp(minSegments, maxSegments)),
            outcome: Value(outcome),
            linkKind: Value(linkKind),
            linkId: Value(linkId),
            sortOrder: Value(count),
          ),
        );
    return id;
  }

  Future<void> update(
    String id, {
    String? name,
    String? outcome,
    String? notes,
    int? segments,
  }) async {
    final clock = await find(id);
    if (clock == null) return;
    // Dilim sayisi KUCULURSE dolu dilim tasabilir; birlikte kirpiliyor.
    final nextSegments = segments == null
        ? clock.segments
        : segments.clamp(minSegments, maxSegments);
    await (db.update(db.clocks)..where((t) => t.id.equals(id))).write(
      ClocksCompanion(
        name: name == null ? const Value.absent() : Value(name),
        outcome: outcome == null ? const Value.absent() : Value(outcome),
        notes: notes == null ? const Value.absent() : Value(notes),
        segments: Value(nextSegments),
        filled: Value(clock.filled.clamp(0, nextSegments)),
      ),
    );
  }

  /// Saati [by] dilim ilerletir (negatif deger geri alir).
  ///
  /// Sinira dayanan bir saat SESSIZCE durur, hata vermez: masada "bir tane
  /// daha" demek yaygin ve bunun uyari uretmesi gereksiz gurultu olurdu.
  /// Doldugunda saat KAPANMAZ -- kapatmak DM'in karari (bkz. [Clocks.done]).
  Future<void> advance(String id, {int by = 1}) async {
    final clock = await find(id);
    if (clock == null) return;
    final next = (clock.filled + by).clamp(0, clock.segments);
    if (next == clock.filled) return;
    await (db.update(db.clocks)..where((t) => t.id.equals(id))).write(
      ClocksCompanion(filled: Value(next)),
    );
  }

  /// Belirli bir dilime ayarlar (daireye dogrudan dokunmak icin).
  Future<void> setFilled(String id, int filled) async {
    final clock = await find(id);
    if (clock == null) return;
    await (db.update(db.clocks)..where((t) => t.id.equals(id))).write(
      ClocksCompanion(filled: Value(filled.clamp(0, clock.segments))),
    );
  }

  Future<void> setDone(String id, bool done) => (db.update(
    db.clocks,
  )..where((t) => t.id.equals(id))).write(ClocksCompanion(done: Value(done)));

  /// Saati bir kayda baglar; [kind] `none` ise bag kaldirilir.
  Future<void> setLink(String id, ClockLinkKind kind, String? linkId) =>
      (db.update(db.clocks)..where((t) => t.id.equals(id))).write(
        ClocksCompanion(
          linkKind: Value(kind),
          linkId: Value(kind == ClockLinkKind.none ? null : linkId),
        ),
      );

  Future<void> delete(String id) =>
      (db.delete(db.clocks)..where((t) => t.id.equals(id))).go();

  /// Saat doldu mu?
  static bool isFull(Clock clock) => clock.filled >= clock.segments;
}
