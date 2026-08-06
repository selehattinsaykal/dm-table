import 'dart:convert';

import 'package:drift/drift.dart';

import '../net/protocol.dart';
import 'db/database.dart';

/// Oyuncu notlarini (karaktere bagli) okur/yazar.
///
/// Belge butunuyle kaydedilir: oyuncu panelinde tum notlar tek belge olarak
/// duzenlenir, es zamanli yazan ikinci taraf yoktur, bu yuzden satir satir
/// normalize etmeye gerek yok.
class NotesRepository {
  NotesRepository(this.db);

  final AppDatabase db;

  /// Karakterin kayitli notlarini doner; hic yoksa bos liste.
  Future<List<NoteSection>> getFor(String characterId) async {
    final row = await (db.select(
      db.characterNotes,
    )..where((t) => t.characterId.equals(characterId))).getSingleOrNull();
    if (row == null) return const [];
    try {
      return notesFromJson(jsonDecode(row.documentJson));
    } on FormatException {
      return const [];
    }
  }

  /// Karakterin not belgesini butunuyle degistirir (upsert).
  Future<void> setFor(String characterId, List<NoteSection> sections) async {
    await db
        .into(db.characterNotes)
        .insertOnConflictUpdate(
          CharacterNotesCompanion.insert(
            characterId: characterId,
            documentJson: Value(jsonEncode(notesToJson(sections))),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }
}
