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
| `optionalfeatures.json` | `optionalfeatures.json.gz` | Class options (Eldritch Invocation, Metamagic, Maneuver, Rune). Generated: `dart run tools/convert_5etools.dart --book=phb-2024 --optional-features=raw/optionalfeatures.json`. |
| `items_phb.json`, `magicitems_phb.json` | matching bundle | 2024 PHB/DMG gear the open5e catalogue omits. Generated: `--book=phb-2024 --items=raw/items.json,raw/items-base.json --source=XPHB,XDMG`. |
| `spell_classes.json` | `spells.json.gz` | Spell→class links open5e doesn't have (the Artificer's list). Generated: `dart run tools/convert_5etools.dart --book=eberron-forge --spell-classes=raw/spells-sources.json`. |
| `creatures_phb.json` | `creatures.json.gz` | 2024 PHB companion/summon stat blocks (Beast of the Land, Draconic Spirit, …) that class and spell text refers to by name. |
| `classes_phb.json` | `classes.json.gz` | The subclasses the SRD leaves out (three per class). Generated: `dart run tools/convert_5etools.dart --book=phb-2024 --subclasses-only --classes=raw/class-*.json`. |
| `{endpoint}_{bookKey}.json` | matching bundle | Sourcebooks converted from 5etools — see below. |
| `desc_overrides.json` | every bundle | Hand-written English text patched onto merged entries — see below. |
| `creatures.json`, `spells.json` | — | Uncompressed reference dumps kept for diffing; nothing reads them. |
| `raw/` | — | Downloaded 5etools input for the converter; **not committed**. |

### Adding new sourcebooks (Eberron, Ravenloft, Forgotten Realms)

Three 2024-era WotC books are added via 5etools-format data, converted to Open5e at build time:

| Book | Document key | 5etools sources |
|---|---|---|
| Eberron: Forge of the Artificer | `eberron-forge` | `EFA` |
| Ravenloft: The Horrors Within | `ravenloft-horrors` | `RHW` |
| Forgotten Realms: Heroes of Faerûn | `faerun-heroes` | `FRHoF` |

These books are **not** on the Open5e API — they live in the 5etools dataset
([5etools-mirror-3/5etools-src](https://github.com/5etools-mirror-3/5etools-src)) as raw JSON.
`tools/convert_5etools.dart` maps the 5etools schema onto the Open5e one and writes
`{endpoint}_{bookKey}.json`; the fetch tool's `_mergeExtraByName()` picks those up by name.

Workflow (run once per book — **do not commit raw 5etools data**):

1. Download the 5etools sourcebook JSON from the mirror into `tools/content_sources/raw/`:
   - creatures → `bestiary-{code}.json`, spells → `spells-{code}.json` (`code` = `efa`, `rhw`, …)
   - classes → `class-{class}.json` — one file per class; subclasses of the new book live inside
     the *class* file, not in a book file
   - shared catalogues → `backgrounds.json`, `races.json`, `feats.json`, `items.json`,
     `items-base.json`, `objects.json` (objects are converted into the creature bundle)
2. `dart run tools/convert_5etools.dart --book=eberron-forge --raw=tools/content_sources/raw`
   (`--raw` discovers the files above; individual `--spells=… --creatures=… --classes=a.json,b.json`
   flags still work, and `--source=EFA,…` overrides the source filter). Items with a rarity are
   written to `magicitems_{bookKey}.json`, the rest to `items_{bookKey}.json`.
3. `dart run tools/fetch_open5e.dart --offline --docs=srd-2024,eberron-forge,ravenloft-horrors,faerun-heroes`
   merges the book files into `assets/data/*.json.gz` and rewrites `manifest.json` without touching
   the API. Drop `--offline` to re-download the SRD catalogue at the same time.

**The output schema is not negotiable.** The app reads Open5e field names directly — `hit_dice`,
`caster_type`, `subclass_of.key`, `verbal`/`somatic`/`material`, `ability_scores.strength`,
`saving_throws`, `benefits[].type`, `cost` as a bare gp number. Inventing convenience fields
(`hd`, `saves`, `components`) makes the data import cleanly and then show up blank. Two details are
easy to get wrong:

- `subclass_of.key` must name a class that actually exists (`srd-2024_bard`,
  `eberron-forge_artificer`). A dangling key turns the subclass into a top-level class in the
  character wizard.
- `CORE_TRAITS_TABLE.desc` is a markdown table parsed by `parseClassCoreTraits`; the row labels
  ("Primary Ability", "Hit Point Die", "Starting Equipment", …) must match SRD wording.

### Repairing upstream text

The fetch tool runs two clean-up passes over every merged bundle before writing it.

`_sanitizeMarkup()` strips conversion residue. The converters leave things like
`20-foot-radius Sphere [Area of Effect]|XPHB|Sphere`, `{#itemEntry Ioun Stone|XDMG}`,
`@UUID[...]{Dancing Lights}`, `the LD property`, `makes a 15 Wisdom saving throw` (no DC) and
`ignore Cover and Cover` in the text a player actually reads. The fix tables are deliberately narrow
— a general "trim pipes" regex would shred the markdown tables — and anything still matching
`_leftoverTag` prints a warning so new residue is noticed instead of shipped.

`_applyDescOverrides()` then patches `desc_overrides.json` onto the merged rows. This is a separate
step because `_mergeEndpoint()` only *adds* rows: it can never fill a field on an entry that already
exists. The file covers three cases:

- entries that ship with an empty `desc` — every species, class and most backgrounds arrived with no
  description at all, and a few magic items are left empty once the unresolved `{#itemEntry …}`
  directive is stripped;
- entries whose `desc` was useless — the twelve `xphb-*` backgrounds repeated the benefit rows
  rendered directly below them, and every weapon and armor said `"A battleaxe."`;
- structural repairs — the eight `xphb-*` species lineages arrived as three unsegmented Foundry
  blobs (which also made `parseSpeciesTraits` read the wrong size), and Druid's Wild Shape column
  leaked in as a level feature named "Cantrips Known" with `[Column data]` as its body.

Schema: `{ "<endpoint>": { "<entry key>": "<desc>" | { "<field>": <value> } } }`. A field whose
current value is a list and whose patch is an object is merged *per sub-entry*, matched on `key` or
`name` (that is how `features` and `benefits` are patched); a list value replaces the whole array.
Keys starting with `_` are notes and ignored, and an entry key that no longer exists prints a
warning rather than silently doing nothing. Turkish translations of the same strings live in
`assets/data/tr/` — see [`lib/data/content_tr.dart`](../../lib/data/content_tr.dart).

After changing anything here, re-run the fetch tool — `fetchedAt` in `assets/data/manifest.json`
must change, otherwise existing databases will not re-seed. Count- and schema-dependent tests live
in `test/data/asset_importer_test.dart`; the translation overlay and the markup clean-up are checked
by `test/data/content_tr_test.dart`.

See [NOTICE.md](../../NOTICE.md) for the licensing status of this material.
