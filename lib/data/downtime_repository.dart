import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../domain/rules/downtime.dart';
import 'db/database.dart';

/// Bos zaman faaliyetleri.
///
/// Takvimle bagli: [DowntimeActivities.startDay] oyun-ici gun sayaci.
/// Takvim ilerledikce arayuz kalan gunu gosteriyor; bir faaliyet gunu
/// dolunca kendiliginden BITMIS SAYILMIYOR -- sonucu DM yazmali (zar
/// atilacak, komplikasyon cikabilecek), yoksa masada sessizce kaybolurdu.
class DowntimeRepository {
  const DowntimeRepository(this.db);

  final AppDatabase db;
  static const _uuid = Uuid();

  Stream<List<DowntimeActivity>> watchAll({String? characterId}) {
    final q = db.select(db.downtimeActivities)
      ..orderBy([
        (t) => OrderingTerm(expression: t.done),
        (t) => OrderingTerm(expression: t.startDay),
      ]);
    if (characterId != null) {
      q.where((t) => t.characterId.equals(characterId));
    }
    return q.watch();
  }

  Future<String> add({
    required String title,
    DowntimeKind kind = DowntimeKind.custom,
    String? characterId,
    int days = 1,
    int? startDay,
    String notes = '',
  }) async {
    final id = _uuid.v4();
    await db
        .into(db.downtimeActivities)
        .insert(
          DowntimeActivitiesCompanion.insert(
            id: id,
            title: title.trim(),
            kind: Value(kind.name),
            characterId: Value(characterId),
            days: Value(days < 1 ? 1 : days),
            startDay: Value(startDay),
            notes: Value(notes),
          ),
        );
    return id;
  }

  Future<void> update(
    String id, {
    String? title,
    DowntimeKind? kind,
    int? days,
    int? startDay,
    String? notes,
    String? outcome,
    bool? done,
  }) => (db.update(db.downtimeActivities)..where((t) => t.id.equals(id))).write(
    DowntimeActivitiesCompanion(
      title: title == null ? const Value.absent() : Value(title.trim()),
      kind: kind == null ? const Value.absent() : Value(kind.name),
      days: days == null ? const Value.absent() : Value(days < 1 ? 1 : days),
      startDay: startDay == null ? const Value.absent() : Value(startDay),
      notes: notes == null ? const Value.absent() : Value(notes),
      outcome: outcome == null ? const Value.absent() : Value(outcome),
      done: done == null ? const Value.absent() : Value(done),
    ),
  );

  Future<void> remove(String id) =>
      (db.delete(db.downtimeActivities)..where((t) => t.id.equals(id))).go();

  /// Faaliyetin para etkisini karakterin kesesine uygular ve tamamlar.
  ///
  /// Kese EKSIYE dusurulmuyor: gideri karsilayamayan bir faaliyet masada
  /// bir sahne (borc, iyilik) demek, sessizce negatif bakiye degil.
  Future<void> complete(String id, {String outcome = ''}) async {
    await db.transaction(() async {
      final row = await (db.select(
        db.downtimeActivities,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (row == null || row.done) return;

      final net = downtimeNetCp(DowntimeKind.fromName(row.kind), row.days);
      final characterId = row.characterId;
      if (characterId != null && net != 0) {
        final character = await (db.select(
          db.characters,
        )..where((t) => t.id.equals(characterId))).getSingleOrNull();
        if (character != null) {
          final next = character.coinsCp + net;
          await (db.update(
            db.characters,
          )..where((t) => t.id.equals(characterId))).write(
            CharactersCompanion(
              coinsCp: Value(next < 0 ? 0 : next),
              updatedAt: Value(DateTime.now()),
            ),
          );
        }
      }

      await (db.update(
        db.downtimeActivities,
      )..where((t) => t.id.equals(id))).write(
        DowntimeActivitiesCompanion(
          done: const Value(true),
          outcome: Value(outcome),
        ),
      );
    });
  }
}
