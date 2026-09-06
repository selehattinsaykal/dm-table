import 'package:dm_table/features/clocks/clock_dial.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kadranin DOKUNMA GEOMETRISI.
///
/// **Bu dosya neden var:** kadran saat 12'den baslayip saat yonunde ilerliyor,
/// oysa `atan2` saat 3'ten baslayip saat yonunun TERSINE artiyor. Aradaki
/// donusum gozle dogrulanamaz (dilim numarasi ekranda yazmiyor) ve yanlis
/// olursa saat "dokundugum yerden baska bir dilime" atlar. Hesabin kendisi
/// burada kilitleniyor.
void main() {
  const size = 100.0;

  Future<int?> tapAt(
    WidgetTester tester,
    Offset local, {
    int filled = 0,
  }) async {
    int? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ClockDial(
              segments: 4,
              filled: filled,
              size: size,
              onSet: (value) => result = value,
            ),
          ),
        ),
      ),
    );
    final dial = tester.getTopLeft(find.byType(ClockDial));
    await tester.tapAt(dial + local);
    await tester.pump();
    return result;
  }

  testWidgets('sag ust ceyrek ilk dilim', (tester) async {
    expect(await tapAt(tester, const Offset(75, 25)), 1);
  });

  testWidgets('sag alt ceyrek ikinci dilim', (tester) async {
    expect(await tapAt(tester, const Offset(75, 75)), 2);
  });

  testWidgets('sol alt ceyrek ucuncu dilim', (tester) async {
    expect(await tapAt(tester, const Offset(25, 75)), 3);
  });

  testWidgets('sol ust ceyrek dorduncu dilim', (tester) async {
    expect(await tapAt(tester, const Offset(25, 25)), 4);
  });

  testWidgets('son dolu dilime dokunmak bir dilim geri alir', (tester) async {
    // Bir dilim doluyken ayni dilime dokunmak "yanlislikla ilerlettim"i
    // duzeltir; ayri bir geri dugmesi olmamasinin sebebi bu.
    expect(await tapAt(tester, const Offset(75, 25), filled: 1), 0);
  });

  testWidgets('merkeze cok yakin dokunus yok sayilir', (tester) async {
    // Merkezde hangi dilime dokunuldugu belirsiz; sessizce gecmeli.
    expect(await tapAt(tester, const Offset(50, 50)), isNull);
  });

  testWidgets('onSet verilmezse kadran salt gosterim', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: ClockDial(segments: 6, filled: 3))),
      ),
    );
    expect(find.byType(GestureDetector), findsNothing);
  });
}
