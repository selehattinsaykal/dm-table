import 'package:dm_table/app/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kural metinleri tablolari markdown olarak tasiyor; duz `Text` ile
/// gosterildiginde alt sinif buyu listeleri ve yoldas stat bloklari boru
/// isaretlerinden bir duvara donuyordu.
void main() {
  Future<void> pump(WidgetTester tester, String text) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: GameText(text))),
    ),
  );

  testWidgets('markdown tablosu gercek tabloya donusur', (tester) async {
    await pump(tester, '''
When you reach an Artificer level specified in the table, you always have the
listed spells prepared.

Table: Armorer Spells
| Artificer Level | Spells |
|---|---|
| 3 | Magic Missile, Thunderwave |
| 5 | Mirror Image, Shatter |
''');

    expect(find.byType(Table), findsOneWidget);
    // Baslik ve hucreler ayri ayri gorunur; ayrac satiri (|---|) cizilmez.
    expect(find.text('Artificer Level'), findsOneWidget);
    expect(find.text('Magic Missile, Thunderwave'), findsOneWidget);
    expect(find.text('Mirror Image, Shatter'), findsOneWidget);
    expect(find.textContaining('---'), findsNothing);
    // Tablo basligi ayri bir satir olarak kalir.
    expect(find.text('Armorer Spells'), findsOneWidget);
  });

  testWidgets('bassiz ozet tablosu da cizilir', (tester) async {
    await pump(tester, '''
Table: Eldritch Cannon
| | |
|---|---|
|Armor Class|18|
|Hit Points|5 x your Artificer level|
''');

    expect(find.byType(Table), findsOneWidget);
    expect(find.text('Armor Class'), findsOneWidget);
    expect(find.text('18'), findsOneWidget);
  });

  testWidgets('madde isaretleri ve vurgu bicimlenir', (tester) async {
    await pump(tester, '''
You gain the following benefits.

- **Flamethrower.** The cannon blasts fire in a 15-foot Cone.
- *Force Ballista.* Make a ranged spell attack.
''');

    expect(find.textContaining('Flamethrower.'), findsOneWidget);
    expect(find.textContaining('Force Ballista.'), findsOneWidget);
    // Yildizlar metinde kalmamali.
    expect(find.textContaining('**'), findsNothing);
  });

  testWidgets('bos metin hicbir sey cizmez', (tester) async {
    await pump(tester, '');
    expect(find.byType(Table), findsNothing);
    expect(find.byType(Text), findsNothing);
  });
}
