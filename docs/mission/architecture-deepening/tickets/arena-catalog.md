# Arena catalog

Status: done — gate 2 green (scoped evidence below); verified in the final integrated
proof and corrected at integration (review F-10), 2026-09-18.

Create one source of truth for frozen and world arena selection, lock reasons, demo availability, and display rows. Feed both legacy and recreated UI adapters without changing the frozen roster rules.

Done when world arenas are reachable through the recreated UI under the same rules as the legacy path and tests cross the catalog seam.

## What landed

- **New module `godot/game/arenas/arena_catalog.gd`** (the one catalog): `ids()` /
  `world_ids()` / `all_ids()` / `is_world()` / `index_of()`, `frozen_rows(career)`
  (display rows with the build wall and the career wall), `world_rows()` (the five a
  full build offers, none in a demo), `rows(career)`, `seat(id)` → `{index, world,
  offered}`, `offered(id)`. It never reads `tests/build/**`; the build's own answers
  are handed in by the gate.
- `godot/game/content_gate.gd`: `arena_catalog()` binds the catalog to this build
  (`is_demo()`, `arenas()`); `world_arenas()` is now a delegation to it. The `Arena`
  preload became unused and was dropped.
- `godot/src/ui/data/UiData.gd`: `arena_rows()` and the new `world_arena_rows()` are
  pass-throughs to the catalog (no arena rule re-derived in the adapter).
- `godot/game/match_config.gd`: `arena_ids()`, `arena_index_of()` and
  `set_arena_id()` / `apply_cli_selection()`'s arena branch ask the catalog's `seat()`
  — one frozen-vs-world rule for both paths. Behaviour preserved (the demo still
  refuses a world id; a frozen id still lands on its roster index and clears the
  world seat; CLI refusals are unchanged).
- `godot/src/ui/screens/ArenaScreen.gd`: the world five are now reachable in the
  recreated UI — one card per offered world arena in a `WorldArenaGrid` built beside
  the frozen grid, named/described by the row the ported column reads, selectable,
  carried in `start_payload()` (`arena_index` -1, `world` true) and landed in the
  world seat through `Config.set_arena_id()` on start; a frozen press clears it;
  career/tournament switch every world card off exactly like a non-fixture frozen
  card; a demo builds no world grid. The frozen grid (`arena_rows_now()`,
  `locked_ids()`) and the frozen roster are untouched.
- `godot/game/main_menu.gd`: unchanged on purpose — the ported column already reads
  `Config.selectable_world_arenas()`, which is the catalog now.

## Evidence (this captain, `/Applications/Godot.app/Contents/MacOS/Godot 4.7.2`, one engine at a time)

RED — `godot/tests/arena_catalog_test.gd` (new, section A/B red, section C green):

    --headless --path godot/ --script res://tests/arena_catalog_test.gd            exit 1  FAIL 7/12
    ... -- --demo                                                                  exit 1  FAIL 7/8
    0 SCRIPT ERRORs; first failure: "A/a_full_build_lists_one_card_per_world_arena_in_the_recreated_grid: expected [...] got []"

GREEN — same two commands; the only edit to the test between the runs was naming the
match-scene path (`MATCH_SCENE`, a gdlint line-length fix) — no assertion was touched:

    --script res://tests/arena_catalog_test.gd                 exit 0  PASS 15/15
    --script res://tests/arena_catalog_test.gd -- --demo        exit 0  PASS 11/11
    0 SCRIPT ERRORs in both.

Regression (scoped arena/UI-data suites, unchanged by this slice):

    tests/ui/screen_arena_audit.gd           exit 0  PASS 133/133   (demo 120/120)
    tests/ui/demo_matrix_audit.gd            exit 0  PASS 133/133   (demo 178/178)
    tests/ui/data_audit.gd                   exit 0  PASS 131/131   (demo 134/134)
    tests/world_arenas_selection_test.gd     exit 0  PASS 18/18     (5/5 courts played)
    tests/world_arenas_field_law_test.gd     exit 0  PASS 88/88
    tests/world_arenas_selection_test.gd -- --demo  exit 0  PASS 8/8

`gdlint` on every changed script: one new finding only —
`ArenaScreen.gd:1114 max-file-lines (1000)` (the same class the repo's other large
screens already carry: `PauseOverlay.gd` 1546, `CharactersScreen.gd` 1415); one
pre-existing over-long line was wrapped, `arena_catalog.gd` and
`arena_catalog_test.gd` are clean.

## Known gaps

- The main harness (`game_slice_test.gd`) and the UI integration suites were NOT run
  by this captain: the dispatch scopes this slice to the arena tests, and gate 6 owns
  the combined sweep. Checked statically instead: the suites that touch this screen
  (`uir_route_audit.gd`, `uir22_integration_audit.gd`) assert route identity, the
  payload's `arena_id == Config.arena_id()`, and `bridge.ids().size() > 0` — none
  pins the arena screen's node count, so the added world grid cannot move them.
- `docs/mission/world-arenas/integrator.md` §9.1 records the recreated-lane gap
  ("the recreated lane's screens are NOT edited this phase"), which this slice closes.
  That file is outside this ticket's write scope: integration should reconcile it.
- `start_match()` now clears the world seat when a frozen arena is started (the
  catalog's single seat rule). That was a latent mixed-path bug — the ported column
  could leave a world seat set while the recreated screen started on a frozen arena —
  and no existing test pinned the old behaviour.

## Final integration (2026-09-18)

- **Verified in the integrated sweep** (serial, engine lock): `arena_catalog_test`
  exit 0 `PASS 15/15` and `-- --demo` exit 0 `PASS 11/11`, 0 SCRIPT ERRORs;
  `world_arenas_selection_test` exit 0 `PASS 18/18` (5/5 courts played);
  `world_arenas_field_law_test` exit 0 `PASS 88/88`; slice full `PASS 345/345` and
  demo `PASS 296/296` (the store/seat rules hold in both lineages). The main harness
  (`PASS 8/8`) and the UI integration suites (`uir22` 75/75, `replay_audit` 166/166)
  are green with the world grid mounted.
- **Review F-10 applied**: the unused public `demo()` and `offered(id)` are deleted
  (production reads `seat()`; the tests read `seat()`/`world_rows()`/`all_ids()`).
  No dangling references; the seat's own `offered` field is untouched.
- **Recorded gap reconciled**: `docs/mission/world-arenas/integrator.md` §9.1's
  recreated-lane gap is closed by this slice and the note there is updated.
- Commit handle: `refactor: deepen match architecture seams` (local, 2026-09-18);
  no push.
