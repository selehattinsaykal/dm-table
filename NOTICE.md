# Third-party content and attribution

DM Table's own source code is licensed under the GNU General Public License v3.0 ([LICENSE](LICENSE)).
The bundled assets below are covered by their own licenses, which are **not** superseded by the GPL.

## Game content — SRD 5.2 (CC BY 4.0)

`assets/data/*.json.gz` contains rules content from the **System Reference Document 5.2**, fetched
through the [Open5e](https://open5e.com) API (`https://api.open5e.com/v2`, document `srd-2024`).

> This work includes material from the System Reference Document 5.2 ("SRD 5.2") by Wizards of the
> Coast LLC, available at <https://www.dndbeyond.com/srd>. The SRD 5.2 is licensed under the
> Creative Commons Attribution 4.0 International License, available at
> <https://creativecommons.org/licenses/by/4.0/legalcode>.

The same attribution is shown to end users inside the app, under **Settings → Content licenses**.

DM Table is an independent, unofficial project. It is not affiliated with, endorsed, sponsored or
approved by Wizards of the Coast LLC. *Dungeons & Dragons* and *D&D* are trademarks of Wizards of the
Coast LLC.

**No content from non-SRD sourcebooks is included in this repository.** Material outside the SRD must
be entered by the user through the app's own content editors, on their own device.

`assets/data/conditions_tr.json` and `assets/data/starter_tables.json` are Turkish translations and
original tables written for this project; they follow the SRD's CC BY 4.0 terms where derived from
SRD text.

## Fonts — SIL Open Font License 1.1

| Font | Source | License file |
|---|---|---|
| Cinzel | [google/fonts](https://github.com/google/fonts/tree/main/ofl/cinzel) | `assets/fonts/OFL-Cinzel.txt` |
| EB Garamond (subset to Latin + Turkish) | [google/fonts](https://github.com/google/fonts/tree/main/ofl/ebgaramond) | `assets/fonts/OFL-EBGaramond.txt` |

Subsetting was done with `fontTools.subset`; the OFL permits modification and redistribution under
the same license.

## Compiled player panel

`assets/player_web/` is a committed build artifact produced from this repository's own source
(`lib/main_player.dart`) by `tools/build_player_web.dart`. It embeds the Flutter engine's CanvasKit
runtime, which is distributed by Google under the terms shipped alongside it (BSD-3-Clause for
Flutter, and the licenses listed in `assets/player_web/assets/NOTICES`).

## Dart/Flutter dependencies

Runtime dependencies are declared in `pubspec.yaml` and resolved from [pub.dev](https://pub.dev);
each keeps its own license (predominantly BSD-3-Clause / MIT / Apache-2.0). A generated list for any
build is available in `assets/player_web/assets/NOTICES` for the web bundle, and via
`flutter build … && <app> --licenses` style tooling for the desktop build.

## Application icon and logo

`assets/logo/` and `Logo/` are original artwork for this project and are covered by the repository's
GPL-3.0 license unless stated otherwise by the author.
