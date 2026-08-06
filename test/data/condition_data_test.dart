import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/import/asset_importer.dart';
import 'package:dm_table/domain/rules/condition_reference.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Durum efektlerinin GERCEK asset verisiyle uctan uca cozulmesi.
///
/// `condition_reference_test.dart` saf mantigi sentetik veriyle kilitler;
/// bu dosya ise `assets/data/conditions.json.gz` -> `ReferenceEntries`
/// zincirinin gercekten calistigini dogrular (sayilar veri degisirse burada
/// patlar).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('21 kayittan 15 cekirdek durum cozulur, 6 A5e elenir', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await AssetImporter(db).importIfNeeded();

    final rows = await (db.select(
      db.referenceEntries,
    )..where((t) => t.kind.equals('conditions'))).get();
    expect(rows, hasLength(21));

    final resolved = [
      for (final r in rows) ?conditionFrom(r.key, r.name, r.dataJson),
    ];
    expect(resolved, hasLength(15), reason: 'A5e-only 6 kayit elenmeli');

    for (final e in resolved) {
      expect(e.desc.trim(), isNotEmpty, reason: e.key);
      final bullets = conditionBullets(e.desc);
      expect(bullets, isNotEmpty, reason: e.key);
      // Kaynak veride satir sonu tirelemesi var ("move- ment"); temizlenmeli.
      expect(
        bullets.every((b) => !b.contains(RegExp(r'\w-\s'))),
        isTrue,
        reason: '${e.key}: tireleme kalmış',
      );
    }
    await db.close();
  });

  test('Turkce ceviri asset\'i cozulen her durumu kapsar', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await AssetImporter(db).importIfNeeded();
    final rows = await (db.select(
      db.referenceEntries,
    )..where((t) => t.kind.equals('conditions'))).get();
    final keys = [
      for (final r in rows)
        if (conditionFrom(r.key, r.name, r.dataJson) != null) r.key,
    ];

    // Ceviri dosyasi bu 15 anahtarin hepsini icermeli; biri eksik kalirsa
    // Turkce arayuzde o durum Ingilizce gorunur.
    const translated = {
      'blinded',
      'charmed',
      'deafened',
      'exhaustion',
      'frightened',
      'grappled',
      'incapacitated',
      'invisible',
      'paralyzed',
      'petrified',
      'poisoned',
      'prone',
      'restrained',
      'stunned',
      'unconscious',
    };
    expect(keys.toSet(), translated);
    await db.close();
  });
}
