import 'package:dm_table/features/session/player_presence_panel.dart';
import 'package:dm_table/features/session/session_page.dart';
import 'package:dm_table/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Varlik paneli sag altta SABIT duruyordu ve oradaki dugmeleri kapatiyordu;
/// artik basili tutup surukleyerek tasinabilmeli.
void main() {
  Widget harness() => ProviderScope(
    overrides: [
      connectedPlayersProvider.overrideWith(
        (ref) => Stream.value(const <ConnectedPlayerView>[]),
      ),
    ],
    child: const MaterialApp(
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      home: Scaffold(
        body: Stack(children: [SizedBox.expand(), PlayerPresencePanel()]),
      ),
    ),
  );

  testWidgets('basili tutup surukleyince panel tasinir', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    final button = find.byIcon(Icons.people_outline);
    final before = tester.getTopLeft(button);

    final gesture = await tester.startGesture(tester.getCenter(button));
    // Uzun basma esigini gecir, sonra surukle.
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(-120, -200));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    final after = tester.getTopLeft(button);
    expect(after.dx, lessThan(before.dx));
    expect(after.dy, lessThan(before.dy));
  });

  testWidgets('acip kapatinca dugme birakildigi yerde kalir', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    final button = find.byIcon(Icons.people_outline);
    // Sag kenara yakin bir yere tasi: panel acilinca 260px'lik kart sigsin
    // diye sola cekiliyor, kapaninca da orada kaliyordu.
    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(0, -300));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    final placed = tester.getTopLeft(button);

    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.byIcon(Icons.people_outline)), placed);
  });

  testWidgets('acik kart ekranin sagindan tasmaz', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    await tester.tap(find.byIcon(Icons.people_outline));
    await tester.pumpAndSettle();

    final card = tester.getRect(find.byType(Card));
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(card.right, lessThanOrEqualTo(screen.width));
    expect(card.left, greaterThanOrEqualTo(0));
  });

  testWidgets('kisa dokunus paneli acar (surukleme tiklamayi yemez)', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    await tester.tap(find.byIcon(Icons.people_outline));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.drag_indicator), findsOneWidget);
  });
}
