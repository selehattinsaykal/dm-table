import 'package:dm_table/features/world/graph_interaction.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dunya grafiginin dokunus/surukleme ayrimi.
///
/// **Bu dosya neden var:** "dugumler baglanmiyor" hatasinin kokU buradaydi.
/// Iki ayri hesap yanlisti ve ikisi de ayni belirtiyi veriyordu; ikisi de
/// gozle fark edilemez cinsten, cunku fare ile yavas hareket ettiginde
/// dogru calisiyor gibi gorunuyor.
void main() {
  group('dokunus / surukleme ayrimi', () {
    test('titreyen bir dokunus SURUKLEME sayilmaz', () {
      // ESKI HATA: esik ardisik iki olay arasindaki mesafeye bakiyordu.
      // Dokunmatikte bir dokunus tek bir olayda kolayca 5-10 piksel
      // titriyor; hareket surukleme sayilinca baglama modunda dugume
      // dokunmak onu SECMIYOR, yerinden oynatiyordu.
      final session = GraphPointerSession(
        startScreen: Offset.zero,
        kind: PointerDeviceKind.touch,
        nodeId: 'npc-1',
      );

      // Basma noktasindan hep 6 piksel icinde kalan bir titreme dizisi.
      for (final p in [
        const Offset(6, 0),
        const Offset(0, 6),
        const Offset(-6, 0),
        const Offset(0, -6),
      ]) {
        session.update(p);
      }

      expect(session.moved, isFalse);
      expect(session.isTap, isTrue);
      expect(session.gesture, GraphGesture.pending);
    });

    test('basma noktasindan uzaklasan hareket suruklemedir', () {
      final session = GraphPointerSession(
        startScreen: Offset.zero,
        kind: PointerDeviceKind.touch,
        nodeId: 'npc-1',
      );

      // Her adim kucuk ama TOPLAM buyuk: eski hesap bunu kaciriyordu.
      for (var i = 1; i <= 20; i++) {
        session.update(Offset(i * 2.0, 0));
      }

      expect(session.moved, isTrue);
      expect(session.isTap, isFalse);
      expect(session.gesture, GraphGesture.dragNode);
    });

    test('esik bir kez asilinca geri donulmez', () {
      final session = GraphPointerSession(
        startScreen: Offset.zero,
        kind: PointerDeviceKind.touch,
        nodeId: 'npc-1',
      );

      session.update(const Offset(200, 0));
      // Parmak basladigi yere geri gelse bile bu bir surukleme olarak
      // basladi; birakmayi dokunus saymak dugumu yerinden oynatip USTUNE
      // bir de secim yapardi.
      session.update(Offset.zero);

      expect(session.isTap, isFalse);
    });

    test('dugumsuz basma tuvali kaydirir', () {
      final session = GraphPointerSession(
        startScreen: Offset.zero,
        kind: PointerDeviceKind.mouse,
      );
      session.update(const Offset(100, 100));

      expect(session.gesture, GraphGesture.panCanvas);
    });

    test('fare esigi parmaktan dar', () {
      final mouse = GraphPointerSession(
        startScreen: Offset.zero,
        kind: PointerDeviceKind.mouse,
      );
      final touch = GraphPointerSession(
        startScreen: Offset.zero,
        kind: PointerDeviceKind.touch,
      );

      expect(mouse.slop, lessThan(touch.slop));
    });
  });

  group('gorunum: tur filtresi ve odak', () {
    const kinds = {
      'loc-1': 'location',
      'loc-2': 'location',
      'npc-1': 'npc',
      'npc-2': 'npc',
      'fac-1': 'faction',
    };
    const links = [
      (aId: 'fac-1', bId: 'npc-1'),
      (aId: 'loc-1', bId: 'fac-1'),
      (aId: 'loc-2', bId: 'npc-2'),
    ];

    test('filtresiz her sey gorunur', () {
      expect(
        visibleGraphNodes(
          kindOf: kinds,
          links: links,
          visibleKinds: {'location', 'npc', 'faction'},
        ),
        kinds.keys.toSet(),
      );
    });

    test('kapatilan tur cizilmez', () {
      final visible = visibleGraphNodes(
        kindOf: kinds,
        links: links,
        visibleKinds: {'location', 'faction'},
      );
      expect(visible, containsAll(['loc-1', 'loc-2', 'fac-1']));
      expect(visible, isNot(contains('npc-1')));
    });

    test('odak dugumu ve DOGRUDAN komsularini birakir', () {
      final visible = visibleGraphNodes(
        kindOf: kinds,
        links: links,
        visibleKinds: {'location', 'npc', 'faction'},
        focusId: 'fac-1',
      );
      expect(visible, {'fac-1', 'npc-1', 'loc-1'});
      // Iki adim uzaktakiler girmez; odagin anlami bu.
      expect(visible, isNot(contains('npc-2')));
    });

    test('odaklanilan dugum kendi turu kapaliyken de gorunur', () {
      // Once orgute odaklanip sonra orgutleri gizlemek bos ekran verirdi ve
      // odaktan cikmanin yolu da gorunmezdi.
      final visible = visibleGraphNodes(
        kindOf: kinds,
        links: links,
        visibleKinds: {'location'},
        focusId: 'fac-1',
      );
      expect(visible, contains('fac-1'));
      expect(visible, contains('loc-1'));
      expect(visible, isNot(contains('npc-1')));
    });

    test('silinmis bir dugume odak butun agi gizlemez', () {
      final visible = visibleGraphNodes(
        kindOf: kinds,
        links: links,
        visibleKinds: {'location', 'npc', 'faction'},
        focusId: 'yok',
      );
      expect(visible, kinds.keys.toSet());
    });
  });

  group('yakinlastirmaya gore dokunma hedefi', () {
    test('uzaklasinca hedef ekranda kucuk kalmaz', () {
      // 25 birimlik dugum %10 olcekte ekranda 2.5 piksel; boyle bir hedefe
      // dokunmak imkansizdi.
      const worldRadius = 25.0;
      const scale = 0.1;

      final hit = graphHitRadius(worldRadius, scale);

      expect(hit * scale, minHitRadius, reason: 'ekranda taban korunmali');
      expect(hit, greaterThan(worldRadius));
    });

    test('yakinlasinca dugumun kendi boyutu gecerli', () {
      // Yeterince buyuk cizilen bir dugumde hedefi sismanlatmak, komsu
      // dugumleri calan bir "manyetik alan" yaratirdi.
      const worldRadius = 30.0;
      const scale = 2.0;

      expect(graphHitRadius(worldRadius, scale), worldRadius);
    });
  });
}
