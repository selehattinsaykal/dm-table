# Contributing to DM Table

Thanks for taking the time. This document covers the setup, the checks that must pass, and the
handful of project-specific rules that are **not obvious from the code** — most bugs in this project's
history came from breaking one of them.

## Setup

```bash
flutter pub get
flutter analyze     # must be clean
flutter test        # must be green
```

Requirements: Flutter 3.44+ (Dart 3.12+). For Windows builds you also need Visual Studio 2022+ with
the *Desktop development with C++* workload and Developer Mode enabled.

Code style is `flutter_lints` (see `analysis_options.yaml`) plus `dart format`. Comments in `lib/` are
written in Turkish, matching the existing code — please keep a file internally consistent rather than
mixing languages.

## Before you open a pull request

- [ ] `flutter analyze` reports no issues
- [ ] `flutter test` is green (add tests for the behaviour you changed)
- [ ] User-visible strings exist in **both** `lib/l10n/app_en.arb` and `lib/l10n/app_tr.arb`
      (player panel strings live in `lib/player/player_strings.dart`)
- [ ] If you touched the database schema, you added a migration *and* bumped `schemaVersion`
- [ ] If you touched `lib/net/protocol.dart` or anything under `lib/player/`, you rebuilt the panel:
      `dart run tools/build_player_web.dart`

## The rules that bite

### 1. Schema changes need three edits, not one

A new column requires **all** of:

1. the column on the drift table class,
2. an `if (from < N) await m.addColumn(...)` step in the migration,
3. `schemaVersion++`.

Ordinary tests open an in-memory database through `createAll()`, so a missing migration **passes the
test suite** and only explodes on a real, existing campaign file with `no such column`. That is why
`test/data/migration_test.dart` builds a raw legacy schema and opens the app database over it. If your
migration uses `addColumn`, make sure the affected table is also seeded in that test's legacy schema —
otherwise you'll get `no such table` instead.

Regenerate drift code after table changes:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 2. The DM is the only authority

Player messages are requests, never facts. Character identity comes from the server's claim map
(`claimCharacter`), not from the message body; rules values (hit dice, saves, prices) are re-read from
the database. `lib/features/session/character_creation_service.dart` is the reference example:
abilities are clamped, skills are intersected with what the class actually offers.

### 3. Snapshots are filtered per socket

`broadcast()` builds one base `TableSnapshot` and re-scopes it per connection — quests by target,
party purses by membership, chat by whisper target. If you add a field to `TableSnapshot`, add it to
`copyWith` **and** to the per-socket forwarding, or every player silently receives an empty value.
Targeted messages (notes, transfer offers, quest offers) go through `pushToPlayers(..., characterId:)`
and must never be put in the broadcast snapshot.

### 4. Never invalidate the session provider

`ref.invalidate(sessionServiceProvider)` stops the LAN server (`ref.onDispose(service.stop)`). Use a
tick/counter provider to force a rebuild instead.

Campaign switching is equally delicate: `CampaignRoot` sits *above* `ProviderScope` and swaps a whole
`ProviderContainer`, because in-place invalidation would close the database before the server stops.

### 5. Drift stream gotchas

Raw `customStatement` writes do **not** notify `watch()` listeners — use the typed
`db.delete(table)..where(...)` API, or the UI keeps showing deleted rows. Column named `text` clashes
with the builder; name it `questText` and friends.

### 6. Advancing in-game time has one entry point

`GameClock` (`gameClockProvider`) writes the calendar *and* applies shop restocks and reminders. Do not
call `CalendarRepository.advanceDays` directly.

### 7. Widget test traps

- Real async work (writing a portrait to disk, `File.readAsBytes`) awaited directly in a `testWidgets`
  body hangs the test **silently**. Move it to `setUp` or wrap it in `tester.runAsync`.
- `addTearDown` does not fix "Pending timers": the timer check runs before teardowns, so unmount
  inside the test body.
- Finders default to `skipOffstage: true`; widgets below the fold in a `ListView` are invisible unless
  you enlarge `tester.view.physicalSize`.
- `Tooltip` eats long-press drag gestures unless you set `triggerMode: TooltipTriggerMode.manual`.

## Content policy

Only **SRD 5.2 (CC BY 4.0)** and openly licensed material may be added to `assets/data/`. Do not open
pull requests containing text, stat blocks or art from non-SRD sourcebooks — users add that themselves
through the in-app editors. When you do update the SRD bundle, update the counts in
`assets/data/manifest.json` **and** bump `fetchedAt`, otherwise existing databases will not re-seed;
the count-dependent tests in `test/data/asset_importer_test.dart` need updating too.

## Reporting bugs

Open an issue with the OS, app version, and — for anything involving the player panel — which browser
was used. Please never paste an AI API key into an issue.
