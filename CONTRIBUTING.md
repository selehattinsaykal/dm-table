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
the *Desktop development with C++* workload and Developer Mode enabled; for Android, the Android
SDK (`flutter doctor` will tell you what is missing).

Code style is `flutter_lints` (see `analysis_options.yaml`) plus `dart format`. Comments in `lib/` are
written in Turkish, matching the existing code — please keep a file internally consistent rather than
mixing languages.

## Before you open a pull request

- [ ] `flutter analyze` reports no issues
- [ ] `flutter test` is green (add tests for the behaviour you changed)
- [ ] User-visible strings exist in **both** `lib/l10n/app_en.arb` and `lib/l10n/app_tr.arb`
      (`test/l10n/arb_parity_test.dart` fails otherwise)
- [ ] If you touched the database schema, you added a migration *and* bumped `schemaVersion`

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

A migration step must also be **self-sufficient**. If it writes into a table that an *earlier* step
creates, call `createTable` (which is `IF NOT EXISTS`) first: which steps run depends on the version
the file started from, so "the table is surely there by now" is not true for every path. v50 shipped
this bug and the migration test caught it.

Regenerate drift code after table changes:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 2. Campaign switching swaps the whole container

`CampaignRoot` sits *above* `ProviderScope` and replaces the entire `ProviderContainer` instead of
invalidating `databaseProvider`. Riverpod runs a provider's own `onDispose` (i.e. `db.close()`)
before its dependents are disposed, so in-place invalidation would close the database out from under
the repositories still reading it.

### 3. Drift stream gotchas

Raw `customStatement` writes do **not** notify `watch()` listeners — use the typed
`db.delete(table)..where(...)` API, or the UI keeps showing deleted rows. Column named `text` clashes
with the builder; name it `questText` and friends.

### 4. Advancing in-game time has one entry point

`GameClock` (`gameClockProvider`) writes the calendar *and* applies shop restocks and reminders. Do not
call `CalendarRepository.advanceDays` directly.

### 5. A record page needs a route, not just a `push`

Lists open records with `Navigator.push`, but every record type also has a route
(`/npcs/<id>`, `/npcs/faction/<id>`, …) declared as a child of its shell branch. That is what lets
the command palette open a record instead of dumping you on a tab. Deleting a branch's `routes:`
still compiles and only makes the palette quietly regress — `test/app/record_routes_test.dart`
locks it.

### 6. Widget test traps

- Real async work (writing a portrait to disk, `File.readAsBytes`) awaited directly in a `testWidgets`
  body hangs the test **silently**. Move it to `setUp` or wrap it in `tester.runAsync`.
- `addTearDown` does not fix "Pending timers": the timer check runs before teardowns, so unmount
  inside the test body.
- Finders default to `skipOffstage: true`; widgets below the fold in a `ListView` are invisible unless
  you enlarge `tester.view.physicalSize`.
- `Tooltip` eats long-press drag gestures unless you set `triggerMode: TooltipTriggerMode.manual`.

## Content policy

Please do not open pull requests that add further copyrighted game text, stat blocks or art. New
bundled content should be **SRD 5.2 (CC BY 4.0)** or otherwise openly licensed; anything else belongs
in the user's own device, through the in-app content editors.

The bundles currently shipped are not purely SRD — see the "Additional 2024 rules content" section of
[NOTICE.md](NOTICE.md) before redistributing this project.

The generator is `tools/fetch_open5e.dart`; its hand-maintained inputs live in
`tools/content_sources/` (never in `assets/`, which is packaged wholesale into the app). After
regenerating, update the counts in `assets/data/manifest.json` **and** bump `fetchedAt`,
otherwise existing databases will not re-seed; the count-dependent tests in
`test/data/asset_importer_test.dart` need updating too.

## Reporting bugs

Open an issue with the OS and the app version. Please never paste an AI API key into an issue.
