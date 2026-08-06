# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this project uses
[semantic versioning](https://semver.org/) for the app version in `pubspec.yaml`.

## [Unreleased]

### Changed

- Renamed the project from *DM Masası* to **DM Table**: Dart package `dm_masasi` → `dm_table`,
  Windows binary `dm_table.exe`, Android application id `com.rpgproje.dm_table`, and the visible
  app name in both languages. Existing campaign database files keep their previous names, so no
  user data is affected.
- Applied `dart format` across the codebase and enforced it in CI.

### Added

- Repository documentation for open source: README (EN/TR), contributing guide, security policy,
  third-party attribution notice, GitHub Actions CI, issue and pull request templates.

### Removed

- The Android runner (`android/`). The DM app targets Windows only; players never install anything.
- ~4 MB of raw source JSON that was being packaged into both the app and the player bundle. The
  files moved to `tools/content_sources/`, where only `tools/fetch_open5e.dart` reads them.
- Dead scaffolding (`lib/app/placeholder_page.dart`) and the duplicated `Logo/` folder, which was
  byte-identical to `assets/logo/logo.png`.

## [1.1.0] — 2026-08-06

### Added

- Calendar reminders: one-off and recurring in-game events, surfaced whenever time advances.
- Music player with playlists, stored per campaign and included in backups.
- Player-side character creation from the web panel, fully validated server-side.
- Backup restore into a *new* campaign without touching the active one.
- Ongoing journeys: multi-stop routes drawn on the map, travel pace, per-segment random encounters
  that survive leaving the screen.
- Party inventories, random tables with a 39-culture name generator, AI encounter and table tools.

### Fixed

- Shop restocking now runs through a single time-advancing entry point (`GameClock`).
- Party purses, random tables and journeys are included in backups.
- Legendary actions are read from both SRD data shapes, restoring them for 12 creatures.

## [1.0.0]

First working table: SRD 5.2 library, character creation and sheets, combat tracker, LAN server with
the player web panel, world graph and maps, shops, quests, codex notes, campaign backups.
