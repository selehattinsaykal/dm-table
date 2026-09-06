import 'dart:convert';
import 'dart:io';

import 'package:dm_table/data/db/database.dart';
import 'package:dm_table/data/import/fivetools/fivetools_importer.dart';
import 'package:dm_table/domain/models/ability.dart';
import 'package:dm_table/domain/models/character_build.dart';
import 'package:dm_table/features/characters/character_pdf.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Denetimde bulunan hatalarin geri gelmesini engelleyen testler.
///
/// Her grup, DUZELTILEN somut davranisi kilitliyor; hepsi duzeltmeden ONCE
/// basarisiz oluyordu.
void main() {
  group('ice aktarilan icerigi silme akislari tazeler', () {
    test('silme sonrasi canli sorgu bos doner', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final importer = FiveToolsImporter(db);
      await importer.importJsonBody(
        jsonDecode('{"spell": [{"name": "Isik", "source": "HB", "level": 0}]}'),
      );

      // Canli akis: silmeden sonra BOS bir olay yayinlamali. `updates`
      // bos gecildiginde drift hicbir sey bildirmiyordu ve kutuphane
      // ekrani eski listeyi gostermeye devam ediyordu.
      final stream = db.select(db.spells).watch();
      final first = await stream.first;
      expect(first, hasLength(1));

      final next = stream.firstWhere((rows) => rows.isEmpty);
      await importer.deleteImported();
      await expectLater(next, completes);
      await db.close();
    });
  });

  group('karakter kagidi PDF', () {
    setUp(TestWidgetsFlutterBinding.ensureInitialized);

    test('Turkce harfler kutuya donmez', () async {
      final bytes = await buildCharacterPdf(
        character: Character(
          id: 'c',
          name: 'Seyhmuz Agiroglu',
          playerName: null,
          speciesKey: null,
          backgroundKey: null,
          alignment: null,
          strength: 10,
          dexterity: 10,
          constitution: 10,
          intelligence: 10,
          wisdom: 10,
          charisma: 10,
          experiencePoints: 0,
          hitPointsMax: 20,
          hitPointsCurrent: 20,
          temporaryHitPoints: 0,
          deathSaveSuccesses: 0,
          deathSaveFailures: 0,
          exhaustion: 0,
          inspiration: false,
          coinsCp: 0,
          armorClassOverride: null,
          speedOverride: null,
          conditionsJson: '[]',
          hitDiceUsedJson: '{}',
          spellChangesAvailable: 0,
          concentrationSpell: null,
          slotCapacitiesJson: '{}',
          spellSlotsUsedJson: '{}',
          portraitPath: null,
          notes:
              'Turkce sinama: ğüşıöç '
              'ĞÜŞİÖÇ',
          appearance: '',
          personality: '',
          ideal: '',
          bond: '',
          flaw: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        build: const CharacterBuild(abilities: AbilityScores(), classes: []),
      );

      // Gomulu font YOKSA paket eksik harfin yerine capraz cizgili bir kutu
      // ciziyor; o cizim icerik akisinda `re 1 w S` deseni birakiyor.
      final content = _textStream(bytes);
      expect(content, isNotNull, reason: 'metin akisi bulunamadi');
      expect(
        content!.contains('re 1 w S'),
        isFalse,
        reason: 'Turkce harfler kutu yer tutucuyla cizilmis',
      );
    });
  });
}

/// PDF icindeki ilk metin cizim akisini acar (Flate ile sikistirilmis olabilir).
String? _textStream(List<int> bytes) {
  final data = Uint8List.fromList(bytes);
  final marker = utf8.encode('stream');
  for (var i = 0; i + marker.length < data.length; i++) {
    if (!_matches(data, i, marker)) continue;
    var start = i + marker.length;
    while (start < data.length && (data[start] == 13 || data[start] == 10)) {
      start++;
    }
    final end = _indexOf(data, utf8.encode('endstream'), start);
    if (end < 0) continue;
    final chunk = data.sublist(start, end);
    List<int> body;
    try {
      body = ZLibDecoder().convert(chunk);
    } on Object {
      body = chunk;
    }
    final text = latin1.decode(body, allowInvalid: true);
    if (text.contains('Tj') || text.contains('TJ')) return text;
  }
  return null;
}

bool _matches(Uint8List data, int at, List<int> needle) {
  for (var i = 0; i < needle.length; i++) {
    if (data[at + i] != needle[i]) return false;
  }
  return true;
}

int _indexOf(Uint8List data, List<int> needle, int from) {
  for (var i = from; i + needle.length <= data.length; i++) {
    if (_matches(data, i, needle)) return i;
  }
  return -1;
}
