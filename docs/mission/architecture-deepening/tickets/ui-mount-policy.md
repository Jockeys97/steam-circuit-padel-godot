# UI mount policy

Status: **done — runtime sweep produced by the integration captain, 2026-09-18.** The
mount policy and the coverage migration landed and every static gate passed; the
focused suite's RED/GREEN was produced through its own source-contract predicates
(`mount_statscan.py`) and the engine sections are now run, green: `ui_mount_policy_test`
exit 0 **`PASS 22/22`**, slice full `PASS 345/345` / demo `PASS 296/296` (23/23
sections), `uir22` `PASS 75/75`, `replay_audit` `PASS 166/166`, `timing_feedback_test`
`PASS 100/100`. See "Final integration" below.

Separate clock ownership from shipping UI mounting. A harness-driven match must be able
to mount the recreated UI, and a real-match test must exercise that path.

Done when the recreated UI is tested through the real Match scene and the frozen harness
behavior remains intact.

## What landed

- **The mount is one question, asked once.** `match_controller.gd::_ready()` computes
  `_ui_new = (not ui_legacy) and _arg(args, "--ui=", "new") != "legacy"`, and
  `_build_scene()` mounts the recreated stack behind `if _ui_new:`. The old combined
  condition `if _ui_new and engine_driven:` is gone (machine-checked): which clock steps
  the ticks (`engine_driven`, still guarded as `if not engine_driven:` in `_process`)
  has no say in which UI is built.
- **The ported column left the recreated path.** `game/hud.gd` is constructed behind
  `if not _ui_new:` — only for an explicit request. The recreated path no longer builds
  it, no longer hides it, and no longer refreshes it; the two refresh sites that were
  bare (`_run_capture`) are null-guarded, and every remaining `_hud.` use is preceded by
  its `_hud != null` guard. `game/mode_hud.gd` is NOT the ported column: it is the mode
  session's own panel, carried in both UI modes, and is unchanged.
- **`godot/game/hud.gd` is untouched by this gate** — the ported column needed no
  construction or refresh change. Its uncommitted modification in the tree is gate 1's
  vocabulary move, not this captain's.
- **The explicit legacy request is a documented switch.** New public
  `var ui_legacy := false` (set before `_ready()`), mirroring `main_menu.gd:87`. Nothing
  in the shipped game sets it; `--ui=legacy` is the same request from the command line,
  and both paths are asserted.
- **New focused suite `godot/tests/ui_mount_policy_test.gd`** (355 lines). Section 1 is
  the source contract (the predicates above, with the needles as named constants so a
  static reader can apply them without a second copy). Sections 2-3 drive the REAL Match
  scene: `harness_mode()` before the tree (the slice's own order), then the mounted
  `HudLayer/UiHud` is read through its public `report()` after 60 ticks through the
  production `tick_fixed()` path and one frame through `apply_frame()`; ESC through
  `_unhandled_input` opens and closes `HudLayer/PauseOverlay` (the card's own public
  `is_open()`); and a `ui_legacy` node is asserted to build the ported column and no
  recreated HUD. No private controller state is read (`_ui_hud`, `_paused`, `_bridge`)
  and no HUD is mounted by the test.
- **The slice's real-match coverage moved to the shipping seam.**
  `_hud_reflects_state()` now reads `HudLayer/UiHud`'s public `report()` (the sim's own
  player/ai score, the rendered log, the no-raw-id scan over every rendered string) and
  asserts `HudLayer/Hud` is ABSENT in the shipping run; the finished match's result is
  asserted through `result_payload()` (the surface the result route mounts). The two
  sections whose subject IS `game/hud.gd` (`_visual_contract`'s panel-naming/frame-edge
  checks, `_hud_safe_area`'s layout contract) now ask for the ported column explicitly
  via `_new_match_node(0, true)` — `ui_legacy`, not a command-line flag.
- **`uir22_integration_audit.gd` grows the harness proof** its section 3 promised: the
  harness-driven (clock off) match of section 4 is asserted to mount `UiHud` and
  `PauseOverlay` and to build no ported column.
- **Cross-seam reconciliation (the court captain's recorded item).**
  `tests/feedback_vocabulary_test.gd::_ownership()` re-points its one source-location
  check from the match shell to `godot/game/court_timing_marks.gd` (the shipping
  consumer since gate 3) and renames the `HudScript.` neighbour to say *legacy* mount.
  The `HudScript.` use count stays 1 (the legacy construction), so its predicate still
  holds literally.

## TDD

- RED (pre-change): `python3 /tmp/mount-gate4/mount_statscan.py
  /tmp/mount-gate4/controller_prechange.gd godot/tests/ui_mount_policy_test.gd` →
  `FAIL 2/5`, exit 1. The three failures are the old combined condition
  (`!_ui_new and engine_driven`), the missing legacy guard (`HudScript.new() x1`, built
  unconditionally), and three unguarded ported-column uses
  (`_hud.visible = false`, two bare `_hud.refresh(state, meta)` in `_run_capture`).
  `controller_prechange.gd` is `git show HEAD:godot/game/match_controller.gd` — the
  committed revision carries the same mount condition the working copy had before this
  gate's edit (verified: `_ui_new and engine_driven` at line 800 of that revision).
- GREEN (after the production change): the same scanner against
  `godot/game/match_controller.gd` → `PASS 5/5`, exit 0.
- The suite's sections 2-3 (the real Match scene) are RUNTIME and were NOT emulated:
  the scanner prints that explicitly. Their RED/GREEN is owed to an engine owner.
- The reconstruction is byte-checked: reversing this captain's hunks from the working
  copy reproduced the pre-edit file exactly (sha256[:16] `651f2cb925b343fe`, the hash
  taken before the first edit), so the gdlint comparison below is against the real
  baseline.

## Evidence

- Static, all green: `gdlint godot/tests/ui_mount_policy_test.gd` → "Success: no
  problems found". `gdlint` finding multisets, normalised and compared against the
  reconstructed pre-edit files: `match_controller.gd` 16 → 16 (same classes),
  `game_slice_test.gd` 118 → 115 (three long legacy-label lines left with the migrated
  assertions; zero added), `uir22_integration_audit.gd` 30 → 30, `feedback_vocabulary_test.gd`
  unchanged. `git diff --check` clean. Frozen paths (`js/**`, `scripts/**`,
  `godot/src/sim/**`) byte-identical; `godot/project.godot` still the editor's 23:07
  rewrite, not touched by this captain.
- Also re-run by this captain where parse-level proof was possible: the four changed
  scripts parse (gdlint parse gate) — a syntax error would surface as a parse failure.
- OWED to an engine owner (one process at a time, serial): the focused suite
  (`res://tests/ui_mount_policy_test.gd`) RED-before/GREEN-after with the real scene,
  `game_slice_test.gd` full and `-- --demo`, `tests/ui/uir22_integration_audit.gd`,
  `tests/ui/replay_audit.gd`, `tests/timing_feedback_test.gd` (the `# tm` trace sha256
  `401009a7…` must stay byte-identical: this gate touches no sim input).

## Known gaps

- Runtime proof of every suite named above — blocked here (engine held by PID 42103).
- **The slice's object-count ceiling needs a look on the first green run.** Harness
  nodes now mount four UI scenes; the check is `objects_delta <= 450` against a measured
  baseline of 395 taken when harness runs mounted nothing. All four mounts are freed
  with their node, so this should stay inside the ceiling, but it is the one number this
  gate could move without the engine.
- Two legacy-only assertions were replaced rather than ported, because the shipping
  surface has no equivalent: the ported debug line ("SEED … TIER …") and the legacy
  result panel's visibility. Their shipping counterparts are asserted instead (the
  `result_payload()` block); the ported column's own panels are still asserted by
  `_visual_contract`/`_hud_safe_area` and by the new suite's legacy section.
- Recorded, not fixed (found while migrating the log assertion): the recreated HUD's
  event log does NOT drop a line identical to the one above it, while the ported
  `hud.gd::_update_log` does. That is a view-model divergence in `ViewState.log_lines`
  vs the ported painting rule, pre-existing and outside this gate.
- The captures (`shots`, `shots-arenas`) were not re-run; the recreated path is
  unchanged for engine-driven runs except that two no-op refreshes of a hidden legacy
  HUD are gone, so the frames should be identical — worth a deliberate re-capture by
  integration if it wants that on the record.

## Final integration (2026-09-18) — the runtime sweep, and F-01/F-04/F-12

- **The owed sweep is run** (serial under `/tmp/padel-godot-engine.lock`, one engine at
  a time): `ui_mount_policy_test` exit 0 `PASS 22/22`; `game_slice_test` exit 0
  `PASS 345/345` and `-- --demo` exit 0 `PASS 296/296` (23/23 sections each);
  `uir22_integration_audit` 75/75; `replay_audit` 166/166; `timing_feedback_test`
  100/100 with `# tm` trace `401009a7…` byte-identical. The main harness (PASS 8/8) and
  every other suite in the final proof are green too.
- **Review F-01 repaired (this gate's migrated coverage)**: the recreated-HUD scan uses
  `str()` on report entries, so the three checks that were silently skipped
  (no-raw-id scan, result payload, win flag) now execute and pass — that is exactly the
  342 → **345** move.
- **Review F-04 repaired (this gate's recorded known gap)**: the object ceiling was
  re-baselined with measurements, not bumped blind. Full `518/520/518`, demo `537/537`,
  `nodes=1 orphans=0` on every run; ceiling 450 → **600** with the numbers and the
  bounded margin recorded in the check's own comment.
- **Review F-12 resolved**: the tally re-baseline and the per-check comparison are
  recorded; every other section kept its count and its order.
- **Review F-10 recorded, no change here**: this gate added no public API beyond the
  documented `ui_legacy` switch; the four removed methods belong to gates 2/3/5.
- Commit handle: `refactor: deepen match architecture seams` (local, 2026-09-18);
  no push.
