## What this changes

Adds three things to the DM toolkit: a music library that can pull tracks from a link, one level of categories inside music playlists, and a "location" map pin for places that have no map of their own. Also replaces the flat location dropdowns in the AI generators with a hierarchical tree picker.

### Music — add from a link

Paste a YouTube link (or anything else yt-dlp resolves) and the track downloads into the library. yt-dlp is **not bundled**; the app looks for it on `PATH` or in its own `tools/` folder, and Music settings can install it. Audio is taken as-is (`bestaudio`, usually `.m4a`), so there is no ffmpeg dependency and no re-encode.

Two behaviours worth calling out:

- The YouTube player client is pinned to `android`. yt-dlp's default (`android_vr`) returns **HTTP 403 on the media fetch** while metadata still resolves fine, which made every download fail — including ordinary, non-protected videos. This is the single constant to change when YouTube breaks it again.
- Licensed music distributed through label channels is refused. The `android` client does not report the DRM flag at all (`has_drm` is empty even on protected tracks), so the check runs on metadata instead: a `- Topic` channel, or artist **and** album both populated. Artist alone is not enough — plenty of ambience channels fill that field, and using it alone would block legitimate content.

Raw yt-dlp stderr is no longer surfaced verbatim; failures are classified into DRM-protected / 403 / generic so the message tells the user what to do.

### Music — playlist categories

Playlists can nest one level (`parentId`). Sub-lists are **not** chips: selecting a category renders its sub-lists as vertical expandable sections with their tracks inside, several of which can be open at once. Right-clicking empty space in the playlist bar, or below the tracks, offers "new list" / "new sub-list".

Deleting a category never destroys data: its sub-lists move to root and its tracks become unfiled.

### World — mapless location pin

New `place` pin kind. It creates a real `Locations` row, which is the whole point: quest generators, the travel planner and location pickers all read that table, so a pin that stayed outside it would never appear in them. It has no map image and cannot be entered — tapping shows its info instead.

- Visibility: `place` is treated as an informational pin. The rule used for sub-location pins asks whether the target is *accessible*, and accessibility requires having a map — applying it here would have made these pins invisible to players forever. "Show to players" writes **both** the pin flag (map marker) and the location flag (travel/quest lists).
- Lifecycle: deleting the pin deletes its location row, and deleting the row deletes the pin. Other pin kinds still leave their targets alone; there is a contrast test for that.
- Mapless places are filtered out of the child-locations strip, which is for places you can actually walk into.

### AI tools — hierarchical location picker

The NPC, quest-giver and quest-target dropdowns listed every location flat. They now show root locations with a chevron that expands sub-locations inline, at any depth. Any level is selectable and the chosen entry displays its full path (`Region > City > Inn`).

## Checklist

- [x] `flutter analyze` is clean
- [x] `flutter test` is green, and new behaviour has tests
- [x] `dart format lib test tools` applied
- [x] New user-visible strings added to **both** `app_en.arb` and `app_tr.arb`
      (no new player-panel strings — the panel change is an icon only)
- [x] Schema change? Column + `addColumn` migration + `schemaVersion++`, and the table is seeded in
      `test/data/migration_test.dart` if needed
- [x] Protocol or player-panel change? Rebuilt with `dart run tools/build_player_web.dart`
- [x] No non-SRD game content added to `assets/`

**On the schema change:** 32 → 33 adds `music_playlists.parent_id`. The migration is guarded with `from >= 31`, because `createTable` writes the *current* schema — a database arriving through the v31 block already has the column, and a second `addColumn` fails with `duplicate column name`. The existing migration tests caught this immediately; no extra seeding was needed since the migration creates the table itself.

## Manual testing

Windows release build, run from `build\windows\x64\runner\Release\dm_table.exe`.

- Installed yt-dlp from Music settings, added tracks from YouTube links, watched progress and playback.
- Verified against a real ambience video (Michael Ghelfi) that downloads succeed, and against a label-distributed soundtrack (`Jeremy Soule - Topic`) that it is refused with the DRM message.
- Created categories and sub-lists, expanded/collapsed sections, played tracks from a section, renamed and deleted lists.
- Added a mapless location pin, confirmed it appears in the quest generator and travel planner, that it cannot be entered, and that deleting the pin removes it from those lists.

Not verified: Android — the target was dropped from this repo, so this is Windows-only. Real playback quality across every container yt-dlp may return was not exhaustively checked; only `.m4a`/`.mp4` audio was played back.

## Notes for reviewers

Three UI-layer gotchas are documented in code comments and locked with tests, because each cost a debugging round trip:

1. **Scrollables swallow pointer events over their empty areas.** A `GestureDetector` wrapping a `SingleChildScrollView`/`ListView` never fires for right-clicks on blank space, even with `HitTestBehavior.opaque`. Hence `Wrap` for the playlist bar and `SliverFillRemaining` for the area under the tracks.
2. **An `InkWell` inside a `ChoiceChip` label never receives taps** — the chip covers its own hit area. The expand arrow is a sibling `IconButton` now. This one was never reported; a widget test caught that the arrow had never worked.
3. **Context menus need overlay-local coordinates.** The app uses `StatefulShellRoute.indexedStack`, so each tab owns an Overlay offset by the navigation rail (measured at `Offset(250, 0)`). Passing screen coordinates to `showMenu` opened menus exactly that far to the right. Fixed via `overlay.globalToLocal`; the regression test wraps the page in an offset nested `Navigator`, since a plain full-screen test harness cannot reproduce it.

The commit also carries earlier uncommitted work that was already in the tree at the start of the session (encounter briefing, loot resolver, edit mode, AI JSON helpers and their tests). It is included here rather than split out, but it is unrelated to the features described above.
