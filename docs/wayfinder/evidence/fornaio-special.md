# IL FORNAIO — Godot-only special athlete (evidence)

Ticket: add the cheerful baker as a **Godot-only special athlete**, selectable and playable,
without touching the frozen six-athlete roster. Repo:
`/Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot` (`pwd -P` verified).

## What landed (paths)

| Path (absolute) | State | What |
| --- | --- | --- |
| `…/godot/assets/athletes/specials_catalogue.json` | NEW | the overlay: `specials[]` (fornaio) + `outfits` (base). `_schema: steam-circuit-padel-pro.specials-catalogue` v1 |
| `…/godot/src/character/specials.gd` | NEW | `Specials.ids()/has()/rows()/athlete()/outfit_ids()/colors()/selectable(is_demo)/stand_in_asset()` — reads the overlay, never the frozen file |
| `…/godot/src/character/outfit_catalogue.gd` | edited | `has_outfit/athlete/outfit_ids/colors/_outfit_record` answer fornaio from the overlay; `athlete_ids()` and `entries()` unchanged (six / 26) |
| `…/godot/src/character/athlete_rig.gd` | edited | `ATHLETE_GLB["fornaio"]` + `COMPANION_CLIPS["fornaio"]` point at the **maestro stand-in** rig/clips; `get_athlete_glb_path()` added |
| `…/godot/src/character/athlete_spawn.gd` | edited | `record()` door (frozen row for the six, overlay record for a special); `describe()` carries `asset_glb` |
| `…/godot/game/content_gate.gd` | edited | `Gate.special_athletes()` — full build only, a list of its own, never merged into `selectable_athletes()` |
| `…/godot/game/match_config.gd` | edited | the **special seat** (`special_athlete_id`), `selectable_special_athletes()`, `is_special_selected()`, `athlete_id()`, demo clears the seat, `athlete()`/`outfit_ids()` special-aware |
| `…/godot/game/main_menu.gd` | edited | `SPECIAL (n)` strip inside the setup row's extras column (plain buttons, no toggle), `_on_special_athlete()`, mutual exclusion with a frozen pick |
| `…/godot/game/lineup.gd` | edited | team-selection pref pool is `Gate.roster() + Gate.special_athletes()` so a special can be fielded in any of the four slots, AI slots included |
| `…/godot/src/ui/screens/CharactersScreen.gd` | edited | the picker's special strip (own node prefixes `SpecialAthlete_*`, so the `PickCard_<id>` audits over the frozen roster are untouched), `_select_special()` |
| `…/godot/src/ui/data/UiArtPaths.gd` | edited | `athletes/<id>.png` for a special (the frozen six keep `.webp`) |
| `…/godot/src/locale/locale_data.gd` | edited | `athlete_fornaio_name` = `IL FORNAIO` / `THE BAKER`, both tables, marked `PORT ADDITION` |
| `…/godot/assets/ui/athletes/fornaio.png` | NEW | the portrait, copied byte for byte (no regeneration) |
| `…/godot/tests/fornaio_special_test.gd` | NEW | the focused gate (sections below) |

Frozen by construction: `js/`, `index.html`, `styles.css`, `godot/src/sim/frozen/data.json`,
`godot/assets/athletes/reference_catalogue.json`, `tools/`. Proof:
`git diff --name-only -- js/ index.html styles.css godot/src/sim/frozen/ tools/ | wc -l` → `0`,
same for `reference_catalogue.json` → `0`. `Frozen.athletes` is still the original six.

## Portrait (byte copy, no regeneration)

```
cp meshy/views/fornaio-front.png godot/assets/ui/athletes/fornaio.png
shasum -a 256 meshy/views/fornaio-front.png godot/assets/ui/athletes/fornaio.png
```

Both sides: `78c9f22a9c73f7e857b956cee9d0e5f773578f9ffde8cab0f773be38b2115a18`.
The `.import` sidecar does not exist yet — the first engine run generates it (the same run
imports the new script `.uid`s). Nothing was regenerated or re-encoded.

## NOT DONE — no Meshy export

**There is no `fornaio.glb` and none has been created.** No GLB was placed in
`godot/assets/athletes/` under a name that is not a frozen roster id (the character standard
forbids that), and no Meshy job was run.

**Stand-in honesty line: on court, IL FORNAIO's body is the MAESTRO mesh (and maestro's
idle/walk/run companion clips) until the owner drops a Meshy GLB of the baker. The rig is a
TEMPORARY human stand-in; the on-court body is not the baker's own art, only his colours
(#f7f4ee jacket / #d98e2b amber) and his name in the UI.** Today his identity lives in: this
overlay, the portrait PNG, the name/role lines, and the palette. His `stand_in` path is
declared in `specials_catalogue.json` (`res://assets/athletes/maestro-rigged.glb`) and read
back as `Specials.stand_in_asset()`; the swap point is one table entry in
`athlete_rig.gd::ATHLETE_GLB` + `COMPANION_CLIPS` (+ the `.import` of the new GLB).

The height in the overlay is the owner's 1.82 m; the stand-in mesh keeps its own proportions,
so on-court scale does not yet read 1.82 m.

## Verification

- `gdlint` (`/Library/Frameworks/Python.framework/Versions/3.13/bin/gdlint`) against a
  `git show HEAD:<file>` baseline of the SAME files: **0 new findings** from the changes.
  Every edited file kept exactly its pre-existing house-style findings (`max-line-length`,
  `class-definitions-order`, `max-file-lines`); `specials.gd` and `fornaio_special_test.gd`
  exit 0 (`Success: no problems found`). Script `/tmp/fornaio/gdlint_check.sh`, raw output
  `/tmp/fornaio/gdlint/`.
- Overlay parses as JSON and carries id/name/colour/height/stats/special/stand-in/outfit
  (checked with `python3 -c json.load`).
- **Engine runs — GREEN, one at a time** (each preceded by `pgrep -x Godot`; an unrelated
  play session and another lane's runs held the engine twice, and the runs below waited for it
  rather than sharing it; logs in `/tmp/fornaio/`):

  | command | result |
  | --- | --- |
  | `… --headless --path godot/ --script res://tests/fornaio_special_test.gd` (full build) | `PASS 77/77`, exit 0 |
  | `… --headless --path godot/ --script res://tests/fornaio_special_test.gd -- --demo` | `PASS 65/65`, exit 0 |
  | `… --headless --path godot/ --script res://tests/ui/screen_characters_audit.gd` (UIR-11 regression, not the slice) | `PASS 148/148`, exit 0 |

  Measured in the full run: `frozen_athletes=6`, `catalogue_entries=26`, `specials=["fornaio"]`,
  `joints=24 triangles=30980 asset=fornaio glb=res://assets/athletes/maestro-rigged.glb`,
  `locomotion=[&"idle", &"walk", &"run"]`,
  `lineup_player_special={"opponent":"pantera","opponentMate":"steamer","player":"fornaio","playerMate":"maestro"}`,
  `lineup_special_pref={"opponent":"fornaio",…}` (an AI slot really takes him),
  `menu_setup_row_min=(1044.0, 261.0) extras_min_h=258.0 tallest_other=261.0` — the strip costs
  **0 px of the 1056 width budget** and 0 px of row height, and
  `portrait_bytes copy=1538759 source=1538759`.
  In the demo run the menus build without the strip (`DIAG` never fires), `Gate.special_athletes()`
  is empty, the seat refuses `fornaio`, `apply_build_limits()` clears a seat forced behind the API's
  back, and the same AI-slot pref resolves to `steamer` instead — the negation is asserted, not
  assumed. `--import` was run once before the tests (it generated `fornaio.png.import` and the new
  scripts' `.uid`s; nothing else in the project was re-imported).

## Owed

- **A Meshy GLB of the baker.** Until then the on-court body is the maestro stand-in (above).
  The swap is one entry in `athlete_rig.gd::ATHLETE_GLB` (+ `COMPANION_CLIPS` if the export brings
  its own idle/walk/run) plus its `.import`.
- The **characters picker's** special strip is covered by gdlint and by the frozen contracts the
  UIR-11 audit re-ran green, but no executed check PRESSES it in-engine: the audit asserts the
  frozen cards/literals/layout, and `fornaio_special_test.gd` presses the MENU strip only. A
  picker press is the one seam still owed a run (`CharactersScreen` needs its router harness,
  which lives in `screen_characters_audit.gd`, not in the focused gate).
- Balance: the provisional stats/cooldown in the overlay are the author's, not the reference's.

## What `fornaio_special_test.gd` covers

Overlay loaded + contains `fornaio`; `Frozen.athletes().size()`
still 6; `Catalogue.athlete_ids()` still 6 and `entries()` 26; `has_outfit("fornaio","base")` and
no `legend`; `athlete("fornaio")` name/role/stat rows; `resolve()` returns #f7f4ee / #d98e2b;
`AthleteSpawn.make("fornaio","base")` non-null with `asset_glb == maestro-rigged.glb` and no
`load_error`; the seat round trip; `Lineup.resolve()` fields him in the player slot and in an AI
slot through `prefs.lineup`; the menu strip's toggle count still equals tiers + frozen athletes +
frozen arenas; the `SPECIAL (n)` row fits the 1152×648 width budget; and in demo the strip node is
absent, `Gate.special_athletes()` is empty, the seat refuses and is cleared.

## Locale drift (deliberate, recorded)

`athlete_fornaio_name` is not in `js/i18n.js` — a special athlete is Godot-only, so no frozen key
exists. The key is added to both tables with a `PORT ADDITION` comment;
`tools/i18n-port/verify-i18n-port.mjs` classifies keys against the reference and will report this
one as an addition (the tooling was not modified). Hand-edit drift is the accepted cost of a port
addition, and this file is the record of it.

## Provisional numbers (mine, not the reference's)

`stats {speed 0.92, power 1.18, control 0.94, reach 1.06, stamina 1.10}`, special
`Racchetta Croissant`, cooldown 3 — a sturdy baker, balanced around the frozen six's spread
(`rosterAverage` untouched). The overlay marks the row `special_athlete: true`,
`provisional: true` so a reader can always tell an addition from a frozen row. Balance is the
owner's call; nothing in the frozen balance file was touched.
