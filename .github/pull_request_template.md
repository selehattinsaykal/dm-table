## What this changes

<!-- One or two sentences. Link the issue if there is one. -->

## Checklist

- [ ] `flutter analyze` is clean
- [ ] `flutter test` is green, and new behaviour has tests
- [ ] `dart format lib test tools` applied
- [ ] New user-visible strings added to **both** `app_en.arb` and `app_tr.arb`
      (and `player_strings.dart` for the panel)
- [ ] Schema change? Column + `addColumn` migration + `schemaVersion++`, and the table is seeded in
      `test/data/migration_test.dart` if needed
- [ ] Protocol or player-panel change? Rebuilt with `dart run tools/build_player_web.dart`
- [ ] No non-SRD game content added to `assets/`

## Manual testing

<!-- What you actually clicked through, on which platform. Note anything you could not verify. -->
