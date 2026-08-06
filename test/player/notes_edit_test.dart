import 'package:dm_table/net/protocol.dart';
import 'package:dm_table/player/notes_edit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Not belgesi uzerindeki saf duzenleme islemleri.
void main() {
  test('addSection sona yeni baslik ekler, digerlerine dokunmaz', () {
    final start = [const NoteSection(id: 's1', title: 'Görevler')];
    final next = addSection(start, id: 's2', title: 'NPC’ler');

    expect(next, hasLength(2));
    expect(next.first.id, 's1');
    expect(next.last.id, 's2');
    expect(next.last.title, 'NPC’ler');
    // Girdi degismemis (immutable).
    expect(start, hasLength(1));
  });

  test('renameSection yalnizca hedef basligi degistirir', () {
    final start = [
      const NoteSection(id: 's1', title: 'Eski'),
      const NoteSection(id: 's2', title: 'Diğer'),
    ];
    final next = renameSection(start, 's1', 'Yeni');

    expect(next.firstWhere((s) => s.id == 's1').title, 'Yeni');
    expect(next.firstWhere((s) => s.id == 's2').title, 'Diğer');
  });

  test('deleteSection basligi kaldirir', () {
    final start = [const NoteSection(id: 's1'), const NoteSection(id: 's2')];
    expect(deleteSection(start, 's1').map((s) => s.id), ['s2']);
  });

  test('addEntry notu dogru basligin altina koyar', () {
    final start = [const NoteSection(id: 's1'), const NoteSection(id: 's2')];
    final next = addEntry(
      start,
      's2',
      id: 'e1',
      title: 'Kapı',
      body: 'Kilitli',
    );

    expect(next.firstWhere((s) => s.id == 's1').entries, isEmpty);
    final entries = next.firstWhere((s) => s.id == 's2').entries;
    expect(entries, hasLength(1));
    expect(entries.single.id, 'e1');
    expect(entries.single.title, 'Kapı');
    expect(entries.single.body, 'Kilitli');
  });

  test('editEntry yalnizca hedef notu gunceller', () {
    final start = [
      NoteSection(
        id: 's1',
        entries: const [
          NoteEntry(id: 'e1', title: 'A', body: '1'),
          NoteEntry(id: 'e2', title: 'B', body: '2'),
        ],
      ),
    ];
    final next = editEntry(start, 's1', 'e1', title: 'A2', body: '11');
    final entries = next.single.entries;

    expect(entries.firstWhere((e) => e.id == 'e1').title, 'A2');
    expect(entries.firstWhere((e) => e.id == 'e1').body, '11');
    expect(entries.firstWhere((e) => e.id == 'e2').title, 'B');
  });

  test('deleteEntry notu kaldirir', () {
    final start = [
      NoteSection(
        id: 's1',
        entries: const [
          NoteEntry(id: 'e1'),
          NoteEntry(id: 'e2'),
        ],
      ),
    ];
    expect(deleteEntry(start, 's1', 'e1').single.entries.map((e) => e.id), [
      'e2',
    ]);
  });

  test('belge JSON’a gidip geri doner (round-trip)', () {
    final doc = [
      NoteSection(
        id: 's1',
        title: 'Görevler',
        entries: const [
          NoteEntry(id: 'e1', title: 'Ejderha', body: 'Mağarada'),
        ],
      ),
      const NoteSection(id: 's2', title: 'Boş'),
    ];

    final restored = notesFromJson(notesToJson(doc));
    expect(restored, hasLength(2));
    expect(restored.first.title, 'Görevler');
    expect(restored.first.entries.single.body, 'Mağarada');
    expect(restored.last.title, 'Boş');
    expect(restored.last.entries, isEmpty);
  });

  test('notesFromJson bozuk veride bos liste doner', () {
    expect(notesFromJson(null), isEmpty);
    expect(notesFromJson('değil-liste'), isEmpty);
    expect(notesFromJson([1, 'x']), isEmpty);
  });
}
