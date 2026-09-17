# World-arena proof journal — proof engineer lane

Owner: proof engineer (independent). Write scope: `godot/tests/world_arenas*`,
`tools/world-arenas/**`, `docs/mission/world-arenas/proof/**` only.
No production edits, no camera-preset edits, no slice-suite edits, no commits.

## 2026-09-17 — reconnaissance + authoring (pre-integration phase)

- Read `docs/mission/world-arenas/CHARTER.md`, `MAP.md`, `LOG.md`,
  `art/concepts/world-arenas-r1/BRIEF.md`, `godot/game/arenas/*.gd`,
  `godot/game/court.gd`, `godot/game/match_config.gd`, `godot/game/content_gate.gd`,
  `godot/tests/game_slice_test.gd`, `godot/tests/ui/capture_ui.gd`,
  `godot/game/tools/arena_probe.gd`, `godot/game/match_controller.gd` (capture paths),
  `godot/game/run.sh`, `godot/game/check_log.sh`.
- Engine verified live: `/Applications/Godot.app/Contents/MacOS/Godot` reports
  `4.7.2.stable.official.ed1daf0bf`; no Godot process running at start (`pgrep -x Godot`).
- Existing capture paths found: (a) `capture_ui.gd` — real-viewport PNG captures via
  `get_viewport().get_texture().get_image()` under `--rendering-driver opengl3`;
  (b) `match_controller.gd --capture=arenas` — one real-viewport frame per arena into
  `res://game/out/arena-<id>.png` (production path, writes tracked files);
  (c) `arena_probe.gd` — headless projection probe (NDC) without rendering.
  This lane adds an independent capture harness and does not touch (a)-(c).
- Current tree facts: frozen roster carries 9 arenas; `torii/medina/carioca/aurora/egeo`
  are NOT yet in it (integrator lane owns that). `ArenaScenery.BACKDROP_Z` is `-12.0`
  (was `-8.0` before the 10x20 m court commit; the mission law plane stays `-8.0`).
  Pack present: `godot/build/linux-x86_64/padel.pck` -> the slice test's pack check can
  be green in this baseline run.
- Authored (this session, new files only):
  - `godot/tests/world_arenas_common.gd` — shared contract helpers.
  - `godot/tests/world_arenas_field_law_test.gd` — selectability + field-law suite.
  - `godot/tests/world_arenas_frame_test.gd` — full-court framing math, all presets.
  - `godot/tests/world_arenas_capture.gd` + `world_arenas_capture.tscn` — real-viewport
    capture harness with SHA-256 per PNG and a machine-readable run JSON.
  - `tools/world-arenas/run_proof.sh` — serialized runner (pgrep guard, per-run
    watchdog, journaled results: command, exit, tally, SCRIPT ERROR count, sha256).
  - `tools/world-arenas/build_manifest.py` — reproducible manifest builder.
- Runs executed so far: _SEE "Runs" BELOW — updated as runs complete._

## Runs

(Exact commands, exit codes, tallies, SCRIPT ERROR counts and log paths; provisional
until the integrator's arenas land and the freeze run happens.)

## STOPPED — user instruction, before any engine run

- 2026-09-17 ~18:15 CEST: out-of-band user instruction: stop edits and engine
  launches, checkpoint, no git mutations; parent will serialize the pull from main
  and the mission branch via the integrator, then resume against updated sources.
- State at stop: **zero Godot runs this session** — `pgrep -x Godot` clean before
  every would-be step and at stop. No `--import` has run either, so the new scripts
  have no engine-side `.gd.uid` yet. The only verification done on the new GDScript
  is by reading; bash/python tooling passed `bash -n` / `ast.parse`. Nothing was
  measured, so nothing is claimed.
- The concurrent production writer has landed edits while this lane authored:
  `godot/game/arenas/arena_library.gd`, `arena_scenery.gd`, `arena_style.gd` are now
  modified in the worktree (this lane touched none of them; `art/concepts/
  world-arenas-r1/README.md` remains the sole pre-existing modification).
- Baseline slice allowance (`game_slice_test.gd` may run once) is UNUSED — reserved
  for the post-pull/post-integration run so its log describes the tree that matters.
- Resume with: `tools/world-arenas/run_proof.sh --baseline` (all four steps; five
  world arenas by default) once the integrator confirms the branch is frozen for
  proof. The capture freeze step (copying `tools/world-arenas/out/<run>/captures/`
  + `MANIFEST.*` into `docs/mission/world-arenas/proof/captures/`) is documented in
  `docs/mission/world-arenas/proof/CAPTURE_MANIFEST.md` (to be written on resume).
- RESUME CLOSURE (integrator, sole engine slot): the freeze is DONE —
  `CAPTURE_MANIFEST.md` above is written and `captures/` holds the 15 frames
  (5 arenas x default/wide/playable, all 1280x720) + `captures.json` +
  `MANIFEST.*` + `sha256.txt`, 15/15 re-verified. Runner is now 8 steps (the
  runner gained `baseline_demo`, `selection`, `selection_demo`); the green run is
  `resume-04` (runner exit 0, `run green: True`, `tree stable: True`): slice
  342/342, demo 293/293, field law 63/63, frame 11/11, selection 13/13,
  selection demo 8/8, capture 111/111. Three RED runs preceded it and are kept
  under `tools/world-arenas/out/` (`resume-01` also has `RED.md`): one real
  production regression (menu fit) and two proof-mechanics defects (identity
  `global_transform` on detached arenas — 399 engine errors; `--out=` parsing +
  a missing per-preset directory). Details: `integrator.md` §9.8.
