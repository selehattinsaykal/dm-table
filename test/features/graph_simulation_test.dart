import 'dart:math';

import 'package:dm_table/features/world/graph_simulation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Force-directed dunya grafigi fizigi (saf, deterministik).
void main() {
  double dist(SimNode a, SimNode b) {
    final dx = a.x - b.x, dy = a.y - b.y;
    return sqrt(dx * dx + dy * dy);
  }

  test('kenarla bagli iki dugum makul bir mesafeye oturur', () {
    const sim = GraphSimulation();
    final nodes = [SimNode(0, 0), SimNode(400, 0)]; // cok uzak baslar
    const edges = [(0, 1)];
    for (var i = 0; i < 500; i++) {
      sim.step(nodes, edges);
    }
    final d = dist(nodes[0], nodes[1]);
    // Yay + itme dengesi: dinlenme uzunlugu (135) civari, ne cakisik ne cok uzak.
    expect(d, greaterThan(80));
    expect(d, lessThan(240));
  });

  test('bagsiz iki dugum birbirini iter (ust uste kalmaz)', () {
    const sim = GraphSimulation();
    final nodes = [SimNode(0, 0), SimNode(1, 0)]; // neredeyse cakisik
    for (var i = 0; i < 400; i++) {
      sim.step(nodes, const []);
    }
    expect(dist(nodes[0], nodes[1]), greaterThan(60));
  });

  test('simulasyon oturur (enerji zamanla duser)', () {
    const sim = GraphSimulation();
    final nodes = [SimNode(0, 0), SimNode(300, 40), SimNode(-120, 90)];
    const edges = [(0, 1), (1, 2)];
    late double energy;
    for (var i = 0; i < 600; i++) {
      energy = sim.step(nodes, edges);
    }
    expect(energy, lessThan(0.4)); // oturma esiginin altina iner
  });

  test('sabitlenen (pinned) dugum hareket etmez', () {
    const sim = GraphSimulation();
    final pinned = SimNode(50, 50)..pinned = true;
    final nodes = [pinned, SimNode(60, 50)];
    for (var i = 0; i < 50; i++) {
      sim.step(nodes, const []);
    }
    expect(pinned.x, 50);
    expect(pinned.y, 50);
  });
}
