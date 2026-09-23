# Emporio OST — worker checkpoint

## Baseline (captured before any edit)

- Checkout: `/Users/alessiofantini/Documents/steam-circuit-padel-11m`
- Branch: `codex/integrate-arena-11m`
- HEAD: see `/tmp/emporio-baseline/head.txt`
- `git status --porcelain`: 107 entries -> `/tmp/emporio-baseline/git-status.txt`
- Scoped copies: `/tmp/emporio-baseline/godot/...` for
  `main_menu.gd`, `match_controller.gd`, `ResultScreen.gd`, `ScreenRouter.gd`,
  `ScreenShell.gd`, `soundtrack_manager.gd`, `jukebox_screen.gd`, `jukebox_record.gd`.
- Engine: `/opt/homebrew/bin/godot` 4.7.2.stable (direct headless; `flock` absent on this host).

## Inventory

### OST catalog (existing, `godot/src/audio/soundtrack_manager.gd`)

47 tracks, `TRACK_METADATA` with an explicit `category` per track. Category counts:

| category | n | tracks |
|---|---|---|
| Menu & Sistema | 4 | menu, roster, career, training |
| Arena Frozen | 9 | officina, fonderia, cattedrale, forgia, osservatorio, tempesta, abissale, caldera, orrery |
| Arena Mondiale | 5 | torii, medina, carioca, aurora, egeo |
| Arena Speciale | 2 | heritage_hall, steam_workshop |
| Fasi Partita | 2 | climax, victory |
| Epico / Anime Special | 8 | epic_* |
| Sawano / Titan Special | 12 | sawano_* |
| Dragon Ball GT / 90s Anime | 5 | dbgt_* |

`SoundtrackManager.all_track_ids()` already enumerates the catalog; the Jukebox screen
lists it ungated (`jukebox_screen.gd:105`).

### Objective -> OST mapping: NONE EXISTS

`rg 'ost_[a-z0-9_]+' godot/src/modes/ godot/src/steam/` returns no match. The
objective tables (`godot/src/modes/career_rules.gd`, `career_progress.gd`,
`mode_tables.gd`, `data/modes.json`) never name an OST id, and
`soundtrack_manager.gd` carries no `unlock`/`objective` field. Per the contract this is
reported, not invented: the achievement-linked exclusion set is empty.

### Save layer (`godot/src/save/**`)

One profile, five groups (`prefs`, `career`, `history`, `drill`, `feedback`), one
`<group>.json` each under `user://save/`. Atomic write = temp file + rename
(`save_store.gd::_atomic_write_text`), with the `fail_before_rename` test hook.
Corrupt -> quarantined; unknown `schemaVersion` -> refused, file untouched. Groups are
declared in `save_schema.gd` (`GROUP_FILES`, `GROUP_TYPES`, `group_names()`,
`empty_profile()`, `DEFAULTS_BY_GROUP`). `modes_save.gd` is the modes' door.
`cloud_saves.gd` derives the cloud name from the group file, so a new group needs no
cloud change.

### Match completion boundary

`godot/game/match_controller.gd:1608` — `if state.result != null and not finished and
_mode_runs_by_points():`. Drill excluded there (`_mode_runs_by_points`); harness runs
have `engine_driven == false` / `load_models == false`; the router handoff is guarded by
`engine_driven and load_models`. This is the authoritative, non-simulation hook.

### Menu / Jukebox host

`godot/game/main_menu.gd` is the actual initial menu host. The Jukebox is an overlay
launched by `_create_jukebox_button()` + `toggle_jukebox()`, and the right-stick host
(`_update_controller_scroll` -> `_scroll_surface()`) already treats an overlay as the
modal surface. The router table (`ScreenRouter.SCREENS`) is frozen at thirteen ids, so
the Emporio follows the Jukebox overlay construction.

### Concurrent edits to preserve

`main_menu.gd` (right-stick scroll), `match_controller.gd`, `ResultScreen.gd`
(controller activate), `ScreenRouter.gd`/`ScreenShell.gd` (back), `soundtrack_manager.gd`
and `jukebox_*` (covers/transport). All edits below are additive; no file is overwritten
whole.

## Off limits (untouched)

`godot/src/sim/**`, `godot/project.godot`, `godot/game/run.sh`, `tools/parity-godot/**`.

## Migration / integration plan (evidence)

- New port save group `economy` (payload: `credits:int`, `owned:Array[String]`,
  `migrationVersion:int`, `receipts:{match_id:credits}`), registered in
  `save_schema.gd::GROUP_FILES`/`GROUP_TYPES` (+ `ECONOMY_DEFAULTS`).
- `group_names()` deliberately STAYS the reference five, so `read_all()`/`write_all()`
  and `save_steam_test.gd:274` ("one save group per reference key" == 5) are unchanged.
  The economy group is read/written by its own door (`store.read_group/write_group`).
- Atomicity: ownership + debit are ONE `write_group("economy", payload)` — a single
  temp+rename commit, so a failure changes neither.
- Legacy grandfather: `economy` file absent AND at least one of
  `career.json/prefs.json/history.json/drill.json` present -> genuine existing profile
  -> grant all non-objective OSTs once, `migrationVersion=1`. No other group file ->
  brand-new profile -> defaults, `owned=[]`, no grant. Corrupt (recovered) or refused
  economy -> defaults written / nothing written respectively, NEVER a fresh grant.

## Files claimed

New: `godot/src/economy/ost_catalog.gd` (written), `godot/src/economy/economy_service.gd`,
`godot/src/ui/screens/EmporioScreen.gd` + `.tscn`, `godot/tests/economy/emporio_ost_test.gd`.
Additive edits: `godot/src/save/save_schema.gd`, `godot/game/match_controller.gd`
(completion hook), `godot/src/ui/screens/ResultScreen.gd` (reward row),
`godot/game/main_menu.gd` (Emporio button + overlay surface),
`godot/src/ui/jukebox/jukebox_screen.gd` (ownership gating).
