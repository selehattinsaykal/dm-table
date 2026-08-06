// Not belgesi (baslik listesi) uzerinde saf, degismez duzenleme islemleri.
//
// Her biri yeni bir liste doner; oyuncu paneli sonucu saveNotes ile sunucuya
// gonderir. Saf olduklari icin dogrudan test edilebilirler.
import '../net/protocol.dart';

/// Yeni bir baslik ekler.
List<NoteSection> addSection(
  List<NoteSection> sections, {
  required String id,
  required String title,
}) => [...sections, NoteSection(id: id, title: title)];

/// Basligi yeniden adlandirir.
List<NoteSection> renameSection(
  List<NoteSection> sections,
  String sectionId,
  String title,
) => [
  for (final s in sections)
    if (s.id == sectionId) s.copyWith(title: title) else s,
];

/// Basligi (ve altindaki tum notlari) siler.
List<NoteSection> deleteSection(List<NoteSection> sections, String sectionId) =>
    [
      for (final s in sections)
        if (s.id != sectionId) s,
    ];

/// Bir basligin altina yeni not ekler.
List<NoteSection> addEntry(
  List<NoteSection> sections,
  String sectionId, {
  required String id,
  String title = '',
  String body = '',
}) => [
  for (final s in sections)
    if (s.id == sectionId)
      s.copyWith(
        entries: [
          ...s.entries,
          NoteEntry(id: id, title: title, body: body),
        ],
      )
    else
      s,
];

/// Bir notu duzenler.
List<NoteSection> editEntry(
  List<NoteSection> sections,
  String sectionId,
  String entryId, {
  required String title,
  required String body,
}) => [
  for (final s in sections)
    if (s.id == sectionId)
      s.copyWith(
        entries: [
          for (final e in s.entries)
            if (e.id == entryId) e.copyWith(title: title, body: body) else e,
        ],
      )
    else
      s,
];

/// Bir notu siler.
List<NoteSection> deleteEntry(
  List<NoteSection> sections,
  String sectionId,
  String entryId,
) => [
  for (final s in sections)
    if (s.id == sectionId)
      s.copyWith(
        entries: [
          for (final e in s.entries)
            if (e.id != entryId) e,
        ],
      )
    else
      s,
];
