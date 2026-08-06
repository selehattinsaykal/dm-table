# Content sources

Hand-maintained JSON that `tools/fetch_open5e.dart` merges into the shipped bundles in
`assets/data/*.json.gz`. These files are **build-time inputs only** — they deliberately live outside
`assets/`, because Flutter packages that whole directory into the app *and* into the player web
bundle, where ~4 MB of raw JSON would be dead weight.

| File | Merged into | Notes |
|---|---|---|
| `spells_phb.json` | `spells.json.gz` | 2024 core spells; replaces the same-named SRD entry so a re-fetch doesn't lose them. |
| `creatures_mm.json` | `creatures.json.gz` | 2024 Monster Manual creatures, plus `beholder`/`flind`, which the Open5e API no longer returns. |
| `items_extra.json`, `magicitems_extra.json`, `backgrounds_extra.json`, `feats_extra.json`, `species_extra.json` | matching bundle | Generic name-deduplicated merge. |
| `classes_phb.json` | `classes.json.gz` | 36 subclasses, merged manually — the fetch tool does **not** wire this one up yet. |
| `creatures.json`, `spells.json` | — | Uncompressed reference dumps kept for diffing; nothing reads them. |

After changing anything here, re-run the fetch tool, then update the counts and `fetchedAt` in
`assets/data/manifest.json` — an unchanged `fetchedAt` means existing databases will not re-seed.
Count-dependent tests live in `test/data/asset_importer_test.dart`.

See [NOTICE.md](../../NOTICE.md) for the licensing status of this material.
