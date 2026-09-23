# Emporio OST — worker report

## Status

ready_for_review. Implemented and tested in `steam-circuit-padel-11m` on
`codex/integrate-arena-11m`. No commit, stage, push or branch change. Off-limits paths
(`godot/src/sim/**`, `godot/project.godot`, `godot/game/run.sh`, `tools/parity-godot/**`)
untouched.

## Changed paths (baseline-relative)

New:
- `godot/src/economy/ost_catalog.gd` — economy view over the existing 47-track catalog.
- `godot/src/economy/economy_service.gd` — wallet/ownership/receipts service.
- `godot/src/ui/screens/EmporioScreen.gd` + `.tscn` — the shop overlay.
- `godot/tests/economy/emporio_ost_test.gd` — the acceptance suite.
- `docs/agent-work/emporio/CHECKPOINT.md`, `REPORT.md`, `captures/emporio-1280x720.png`.

Modified (additive):
- `godot/src/save/save_schema.gd` — `economy` group in `GROUP_FILES`/`GROUP_TYPES`/
  `ECONOMY_DEFAULTS`/`DEFAULTS_BY_GROUP`, `port_group_names()`, `empty_profile()`.
  `group_names()` still returns the reference five.
- `godot/src/save/save_store.gd` — `read_all`/`write_all` enumerate `port_group_names()`.
- `godot/src/steam/cloud_saves.gd` — `upload_profile()` enumerates `port_group_names()`.
- `godot/src/ui/screens/ResultScreen.gd` — reward/balance row (`_render_reward`).
- `godot/src/ui/jukebox/jukebox_screen.gd` — ownership gate (`is_locked`, `locked_ids`,
  `set_store`, lock marker, locked-play refusal + `shop_requested`).
- `godot/game/main_menu.gd` — boot economy init, Emporio button/overlay, focus
  registration, `_overlay_owns_input` guard in `_input` AND `_playable_process`,
  Jukebox to shop route.
- `godot/game/match_controller.gd` — `_award_economy()` at the completion boundary.

`main_menu.gd` and `jukebox_screen.gd` were already dirty from concurrent lanes
(right-stick scroll; Jukebox covers/transport), so their diffstat includes that work.
A concurrent lane (ALELU) also edited `economy_service.gd` (`relock_all` /
`career.lockAll`, folded into `has_access`/`shop_rows`) — preserved and attributed.

## Verification

| command | exit | result |
|---|---|---|
| `godot --headless --check-only --script res://<each changed file>` | 0 | all 9 parse clean |
| `godot --headless --path godot --script res://tests/economy/emporio_ost_test.gd` | 0 | PASS 99/99 |
| `godot --rendering-driver opengl3 --resolution 1280x720 --path godot --script res://tests/economy/emporio_ost_test.gd` | 0 | PASS 101/101, capture written, no clipped rows |
| `godot --headless --path godot --script res://tests/modes/save_progression_audit.gd` | 0 | PASS 46/46 |
| `godot --headless --path godot --script res://tests/jukebox_transport_test.gd` | 0 | PASS (83 checks, 0 failures) |
| `godot --headless --path godot --script res://tests/ui/controller_scroll_test.gd` | 0 | PASS 69/69 |
| `godot --headless --path godot --script res://tests/ui/menu_context_test.gd` | 0 | all PASS (incl. "original nine controls preserved") |
| `godot --headless --path godot --script res://tests/save_steam_test.gd` | 1 | FAIL 136/138 — pre-existing, unrelated |

`save_steam_test` red at baseline: `PREFS_DEFAULTS` at HEAD carries `cameraPreset`
(`git show HEAD:godot/src/save/save_schema.gd:125`) while the test's
`_realistic_prefs()` does not, so "prefs defaults carry all 17 collectPrefs fields"
and "prefs round-trip field for field" fail without this lane touching either.

## Catalog / exclusion evidence

47 tracks; starters `ost_menu/ost_roster/ost_training/ost_victory`; shop 43 items
(18 standard @150, 25 special @250), priced from the catalog's own `category`.
Objective to OST mapping: none exists (`rg 'ost_[a-z0-9_]+' godot/src/modes/
godot/src/steam/` returns nothing), so the achievement-linked exclusion set is empty and
`Catalog.exclusion_report()` states that explicitly rather than inventing one.

## Reward rule

`20 + min(2 * points_played, 80) + 15 (victory)`, where `points_played` is the
ACCUMULATED `state.stats.pointsWon` (both sides, `src/sim/sim.gd:2009`), never the
tennis `state.points` scoreboard. Awarded once per match id (persisted receipt, survives
restart); a rematch is a new id (unix seconds + Crypto nonce, no sim RNG). Excluded by
`Economy.award_eligible`: drills, demo builds, headless harness/probe runs, disabled
fixtures, matches with no result.

## Input ownership

`main_menu._overlay_owns_input()` covers the Jukebox and Emporio overlays only. While one
is up: `_input` skips the menu's focus dispatch, and `_playable_process` returns before
`_focus.poll_pad()` (the held-pad poll), so a real gamepad cannot activate the screen
behind the modal. The right-stick scroll still runs and the GUI still delivers accept to
the overlay's focused control. The OSK is deliberately excluded so its existing bridge
dispatch keeps driving code entry.

The suite exercises that path with real input events: a pad accept (press THEN release —
`BaseButton` activates on release) OPENS the Emporio from the initial menu through the
normal registration (`bridge.set_focus("emporio")`, no registry surgery), and a second
pad accept on the focused `EmporioConfirmBuy` button BUYS a track through the GUI, with
the menu's own focus unchanged.

## Live completion hook

`_controller_award()` in the suite drives the REAL `match_controller._award_economy()`
on a lightweight instance (no scene, no display) with `stats.pointsWon` and `result`
configured: it pays 71 for 18 played points + victory, is idempotent for the same match
id, does not double-pay, exposes the award for the result payload, and leaves
`Config.pending_result` empty (no scene jump).

## Named gaps / residual risk

- The cloud layer's enumeration now includes `economy`, but there is no pre-existing
  production cloud call site (`rg 'CloudSaves|upload_group' godot/game godot/src` matches
  only the layer and tests). `upload_profile()` is ready for that wiring; nothing calls
  it at boot.
