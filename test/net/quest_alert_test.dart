import 'package:dm_table/net/protocol.dart';
import 'package:dm_table/player/player_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Gorev bildirimi: snapshot karsilastirmasindan turetilir (sunucuya yeni
/// mesaj tipi eklenmedi). Kritik davranis: yeniden baglanmada dialog yagmuru
/// olmamali.
void main() {
  QuestView quest({
    String id = 'q1',
    String? myStatus,
    String mode = 'individual',
    bool rewardReady = false,
  }) => QuestView(
    id: id,
    title: 'Kayip cocuk',
    text: 'Cocugu bul',
    reward: '200 altin',
    myStatus: myStatus,
    mode: mode,
    rewardReady: rewardReady,
  );

  TableSnapshot snap(List<QuestView> quests) => TableSnapshot(quests: quests);

  /// Denetleyiciyi kurup verilen snapshot dizisini sirayla besler.
  PlayerState feed(List<TableSnapshot> snapshots) {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(playerControllerProvider.notifier);
    for (final s in snapshots) {
      controller.debugApplySnapshot(s);
    }
    return container.read(playerControllerProvider);
  }

  test('ilk snapshot uyari uretmez (yeniden baglanma dialog yagdirmasin)', () {
    final state = feed([
      snap([quest(), quest(id: 'q2')]),
    ]);
    expect(state.questAlert, isNull);
    expect(state.questAlertSeq, 0);
  });

  test('yeni gorev -> teklif uyarisi', () {
    final state = feed([
      snap(const []),
      snap([quest()]),
    ]);
    expect(state.questAlert?.kind, QuestAlertKind.offered);
    expect(state.questAlert?.quest.id, 'q1');
    expect(state.questAlertSeq, 1);
  });

  test('oylama modunda uyari turu oylama', () {
    final state = feed([
      snap(const []),
      snap([quest(mode: 'vote')]),
    ]);
    expect(state.questAlert?.kind, QuestAlertKind.vote);
  });

  test('karar verilmis gorev tekrar uyari uretmez', () {
    final state = feed([
      snap(const []),
      snap([quest()]), // uyari 1
      snap([quest(myStatus: 'accepted')]),
      snap([quest(myStatus: 'accepted')]),
    ]);
    expect(state.questAlertSeq, 1);
  });

  test('odul havuzu acilinca odul uyarisi', () {
    final state = feed([
      snap([quest(myStatus: 'accepted')]),
      snap([quest(myStatus: 'accepted', rewardReady: true)]),
    ]);
    expect(state.questAlert?.kind, QuestAlertKind.reward);
    expect(state.questAlertSeq, 1);
  });

  test('odul havuzu acik kaldigi surece tekrar uyarmaz', () {
    final state = feed([
      snap([quest(myStatus: 'accepted')]),
      snap([quest(myStatus: 'accepted', rewardReady: true)]),
      snap([quest(myStatus: 'accepted', rewardReady: true)]),
    ]);
    expect(state.questAlertSeq, 1);
  });

  test('gorev geri paylasilirsa (karar sifirlanirsa) yeniden uyarir', () {
    final state = feed([
      snap([quest(myStatus: 'rejected')]),
      snap([quest()]), // DM yeniden paylasti -> myStatus null
    ]);
    expect(state.questAlert?.kind, QuestAlertKind.offered);
    expect(state.questAlertSeq, 1);
  });

  group('rozet sayisi', () {
    test('karar bekleyen ve odulu hazir gorevleri sayar', () {
      final state = feed([
        snap([
          quest(id: 'a'), // karar bekliyor
          quest(id: 'b', myStatus: 'accepted'), // is yok
          quest(id: 'c', myStatus: 'accepted', rewardReady: true), // odul
          quest(id: 'd', myStatus: 'rejected'), // is yok
        ]),
      ]);
      expect(state.pendingQuestCount, 2);
    });

    test('gorev yoksa sifir', () {
      expect(const PlayerState().pendingQuestCount, 0);
    });
  });
}
