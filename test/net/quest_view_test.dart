import 'package:dm_table/net/protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('QuestView JSON round-trip', () {
    const q = QuestView(
      id: 'q1',
      title: 'Kayıp çocuk',
      text: 'Çocuğu bul',
      reward: '200 altın',
      myStatus: 'accepted',
    );
    final r = QuestView.fromJson(q.toJson());
    expect(r.id, 'q1');
    expect(r.title, 'Kayıp çocuk');
    expect(r.text, 'Çocuğu bul');
    expect(r.reward, '200 altın');
    expect(r.myStatus, 'accepted');
  });

  test('TableSnapshot.quests tur atlar; copyWith yalnız quests değiştirir', () {
    const base = TableSnapshot(
      notice: 'selam',
      quests: [QuestView(id: 'a', title: 'A', text: 't', reward: 'r')],
    );
    final round = TableSnapshot.fromJson(base.toJson());
    expect(round.quests.single.id, 'a');
    expect(round.quests.single.myStatus, isNull);
    expect(round.notice, 'selam');

    final swapped = base.copyWith(quests: const []);
    expect(swapped.quests, isEmpty);
    expect(swapped.notice, 'selam'); // diğer alanlar korunur
  });
}
