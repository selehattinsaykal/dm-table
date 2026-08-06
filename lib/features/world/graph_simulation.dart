import 'dart:math';

/// Force-directed dunya grafigi simulasyonu (saf; widget'tan bagimsiz → test).
///
/// Her [step] bir adim: dugumler birbirini iter (ters-kare), kenarlar iki ucu
/// bir dinlenme uzunluguna ceker (yay), hafif merkez cekimi ve sonum uygulanir.
/// Adim toplam kinetik enerjiyi doner; widget bu deger esigin altina dusunce
/// ticker'i durdurur (CPU bosa harcanmasin).

/// Simulasyondaki tek bir dugum. Konum/hiz degisebilir; [pinned] ise
/// (surukleniyor ya da kullanici sabitledi) kuvvetlerden etkilenmez.
class SimNode {
  SimNode(this.x, this.y);
  double x, y;
  double vx = 0;
  double vy = 0;
  bool pinned = false;
}

class GraphSimulation {
  const GraphSimulation({
    this.repulsion = 9000,
    this.springLength = 135,
    this.springStiffness = 0.02,
    this.centerGravity = 0.003,
    this.damping = 0.85,
    this.maxVelocity = 60,
  });

  /// Dugumler arasi itme kuvvetinin buyuklugu (yuksek = daha genis dagilim).
  final double repulsion;

  /// Bir kenarin dinlenme uzunlugu (bagli dugumler bu mesafeye yaklasir).
  final double springLength;

  /// Yay sertligi (Hooke sabiti).
  final double springStiffness;

  /// Grafigin dagilip kacmamasi icin merkeze cekim.
  final double centerGravity;

  /// Hiz sonumu (her adim hiz bu oranla carpilir).
  final double damping;

  /// Adim basina azami hiz (buyuk itmeler dugumu firlatmasin).
  final double maxVelocity;

  /// Bir adim uygular ve toplam kinetik enerjiyi (Σ v²) doner. [edges] dugum
  /// index ciftleridir; [centerX]/[centerY] cekim merkezidir.
  double step(
    List<SimNode> nodes,
    List<(int, int)> edges, {
    double centerX = 0,
    double centerY = 0,
  }) {
    final n = nodes.length;
    if (n == 0) return 0;

    final fx = List.filled(n, 0.0);
    final fy = List.filled(n, 0.0);

    // İtme: her dugum cifti ters-kare ile birbirini iter.
    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        var dx = nodes[i].x - nodes[j].x;
        var dy = nodes[i].y - nodes[j].y;
        var d2 = dx * dx + dy * dy;
        if (d2 < 0.01) {
          // Cakisik dugumleri belirlenimci sekilde ayir.
          dx = (i - j) + 0.1;
          dy = 0.13;
          d2 = dx * dx + dy * dy;
        }
        final d = sqrt(d2);
        final f = repulsion / d2;
        final ux = dx / d, uy = dy / d;
        fx[i] += f * ux;
        fy[i] += f * uy;
        fx[j] -= f * ux;
        fy[j] -= f * uy;
      }
    }

    // Yay: her kenar iki ucunu dinlenme uzunluguna ceker.
    for (final (a, b) in edges) {
      if (a < 0 || b < 0 || a >= n || b >= n || a == b) continue;
      final dx = nodes[b].x - nodes[a].x;
      final dy = nodes[b].y - nodes[a].y;
      final d = sqrt(dx * dx + dy * dy) + 0.001;
      final f = springStiffness * (d - springLength);
      final ux = dx / d, uy = dy / d;
      fx[a] += f * ux; // a'yi b'ye dogru (uzaksa) ceker
      fy[a] += f * uy;
      fx[b] -= f * ux;
      fy[b] -= f * uy;
    }

    // Merkez cekimi + entegrasyon + sonum.
    var energy = 0.0;
    for (var i = 0; i < n; i++) {
      final node = nodes[i];
      if (node.pinned) {
        node.vx = 0;
        node.vy = 0;
        continue;
      }
      fx[i] += (centerX - node.x) * centerGravity;
      fy[i] += (centerY - node.y) * centerGravity;
      node.vx = (node.vx + fx[i]) * damping;
      node.vy = (node.vy + fy[i]) * damping;
      final speed = sqrt(node.vx * node.vx + node.vy * node.vy);
      if (speed > maxVelocity) {
        node.vx = node.vx / speed * maxVelocity;
        node.vy = node.vy / speed * maxVelocity;
      }
      node.x += node.vx;
      node.y += node.vy;
      energy += node.vx * node.vx + node.vy * node.vy;
    }
    return energy;
  }
}
