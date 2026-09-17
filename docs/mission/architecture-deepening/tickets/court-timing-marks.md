# Court timing marks

Status: **done — runtime proof produced by the integration captain, 2026-09-18.** The
extraction landed and every static gate passed; the scoped engine RED/GREEN and the
scoped suites were blocked on a user-owned Godot editor (PID 42103) and are now run:
`court_timing_marks_test` exit 0 **`PASS 87/87`** with **0 SCRIPT ERRORs and 0 engine
ERROR lines** (was `PASS 45/45` over 1 SCRIPT ERROR and 12 `!is_inside_tree()` ERRORs —
review F-03/F-05, both repaired), slice full `PASS 345/345` / demo `PASS 296/296` with
23/23 sections, `timing_feedback_test` `PASS 100/100` with the trace unchanged. See
"Final integration" below.

Move court timing geometry, state, placement, verdict rendering, and report behavior out of the match shell. Keep the frozen sim untouched. Tests cross the new module interface instead of private controller fields where possible.

Done when `match_controller.gd` delegates the concern and scoped plus integration tests pass.

## What landed

- **New module `godot/game/court_timing_marks.gd`** (701 lines, the one owner): the 37
  `TIMING_*` geometry constants with their reference anchors and the frame measurements
  that forced them, the eleven mark nodes, every builder, the per-frame placement, the
  verdict's own rendering, the report, and the capture's marker lines.
- **Its public seam is seven calls** — `mount(parent) -> int`, `mark_names()`,
  `update(state, finished) -> Dictionary`, `report()`, `set_muted(bool)`,
  `is_muted()`, `capture_lines(camera)`. It preloads `court.gd` and
  `feedback_vocabulary.gd` and nothing else: no caller (no cycle, no pass-through) and
  no sim script (it reads the state it is handed).
- **`godot/game/match_controller.gd` delegates.** 531 lines out, 30 in:
  `const CourtTiming := preload(...)`, `var _timing_marks`,
  `CourtTiming.new()` + `.mount(self)` in `_build_scene`, ONE `.update(state, finished)`
  per frame in `_sync_views` (the same point in the frame, before the athletes' early
  return), the A/B capture's `set_muted(true/false)` + update, and `capture_lines()`
  printed by `_save_frame`. `timing_report()` now forwards the module's report and a new
  `court_timing_marks()` accessor hands the seam to the tests. The file carries no
  `TIMING_*` constant and no `_timing_*` identifier but `_timing_marks` (machine-checked
  by the new suite and by `court_statscan.py`, below).
- **The tree did not move, the owner did**: the eleven marks are the same nodes, under
  the same names, in the same build order, as children of the same parent (the match
  node). Nothing about the scene graph, the frame order or a screen-space read changed —
  which is what keeps the A/B capture and every existing proof comparable.
- **The report is enriched, not changed in behaviour**: each mark's placed position
  (`ring_at`, `prec_at`, `prec_fill_at`, `advice_at`, `energy_at`, `energy_fill_at`,
  `verdict_at`), the colour it was drawn with (`prec_color`, `energy_color`) and the
  drawn arc's measured extent (`fill_extent`) are now in the report. Every pre-existing
  key kept its name and its value, so the capture lines read the same numbers.
- **The capture's two marker lines are byte-identical**: the format strings are the ones
  `HEAD` shipped — 206/206 and 110/110 characters, verified by reconstructing the joined
  literals against `git show HEAD:godot/game/match_controller.gd`.
- **Tests cross the seam.** New `godot/tests/court_timing_marks_test.gd` (634 lines, 84
  check call sites): the seam's ownership scans, the marks and their drawing contract,
  the placement from a live state, the verdict, the A/B mute, the report contract and
  the capture lines. `game_slice_test.gd`'s `_timing_presentation` now reads
  `court_timing_marks()` / `timing_report()` and names no private variable of the shell
  (its "every mark exists in the match scene" check walks the module's own
  `mark_names()`).

Behaviour is a move: a normalised, per-function diff of the module against the
pre-extraction controller (rename map applied: `_timing_ring` → `_ring`,
`_timing_mesh` → `_build_mesh`, `HudScript.` → `Vocabulary.`, …) is clean apart from the
declared deltas — `mount(parent)`/`update(state, finished)` signatures, `self` →
`_parent`, the verdict taking `state` as a parameter (its unused `_ground` dropped), the
report additions, and the `fill_extent` measured at the rebuild the fill already did.

## Evidence (this captain)

**Runtime RED/GREEN — BLOCKED.** The engine was held for the whole dispatch: `pgrep -x
Godot` reported editor PID 42103 at the start, at every checkpoint, and at the end. No
engine was launched and the lock was never taken. The command integration must run:

    /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot/ \
      --script res://tests/court_timing_marks_test.gd

**Static RED → GREEN of the seam scans** (`/tmp/court-gate3/court_statscan.py`, which
applies the new suite's own A-section checks from the test file's own constant lists):

    before the controller edit (module present, shell still owning the concern)
      FAIL 6/11   exit 1   — the shell carried all 37 TIMING_* constants, all ten moved
                             builders, the 22 private `_timing_*` names and neither the
                             preload nor the interface calls
    after the controller edit
      PASS 11/11  exit 0   — module owns the constants/builders/seam; the shell's only
                             `_timing_*` name is `_timing_marks`; one preload, and the
                             create/mount/update/report/capture_lines calls

**Parser and style gates** (`gdlint`, default config; a parse failure surfaces as a
parse error, so a clean parse and a finding diff below are real evidence):

    godot/game/court_timing_marks.gd        0 findings (new file, clean)
    godot/tests/court_timing_marks_test.gd  0 findings (new file, clean)
    godot/game/match_controller.gd          23 → 16 findings, same classes:
                                            21 → 14 max-line-length (two of them the
                                            moved CAPTURE_* strings, split across
                                            adjacent literals with the printed line
                                            byte-identical), max-file-lines 1 → 1,
                                            max-public-methods 1 → 1
    godot/tests/game_slice_test.gd          121 → 118 findings, same classes
    git diff --check                        clean
    frozen paths (godot/src/sim/**, js/**, scripts/**)  62 files byte-identical
    neighbours (Wave-1 arena/audio files, feedback_vocabulary.gd, hud.gd, the other
    suites, ViewState/UiData/ArenaScreen)   byte-identical — untouched
    godot/project.godot                     byte-identical to this captain's pre-flight
                                            hash (the editor's earlier reorder was NOT
                                            touched, restored, or staged)

## Cross-seam item for integration (recorded, not fixed here)

`godot/tests/feedback_vocabulary_test.gd::_ownership()` (line 141-142) asserts the
**match shell** contains `preload("res://game/feedback_vocabulary.gd")`. Gate 1 made
the shell that consumer because the court marks lived there; gate 3 moved the marks —
and with them the shell's last vocabulary consumer — into
`godot/game/court_timing_marks.gd`, which preloads the vocabulary module itself. That
one check now reads false; the other five checks of that section still hold (emulated
statically: module exists, no caller preload, HUD declarations moved, `HudScript.` use
count still 1, no `HudScript.<vocabulary>` call). This captain's write set does not
include that file. The re-point is one line — assert the **court timing module** (the
shipping court presentation's vocabulary reader) instead of the shell:

    controller.contains("preload(\"%s\")" % MODULE_PATH)
      -> court_timing.read_text().contains("preload(\"%s\")" % MODULE_PATH)

Gate 4 will invalidate the `HudScript.` neighbour of that check for the same reason
(it removes the mount), so this file needs one reconciliation pass at integration, not
one patch per gate.

## Known gaps

- The runtime proof of the whole slice: `court_timing_marks_test.gd` (its own tally),
  `game_slice_test.gd` — note its `_timing_presentation` was rewritten to read the
  module's report, so its check call sites go 36 → 40 against `HEAD` and the suite tally
  moves 342 → 346 by call-site count: re-baseline it and confirm every other section
  kept its count — and `timing_feedback_test.gd` (`PASS 100/100` with the `# tm` trace
  sha256 `401009a7…` byte-identical to gate 1's run: this slice touches neither the sim
  nor the trace's inputs, so any drift there is a finding, not a re-baseline). All owed
  to an engine owner.
- `capture_lines()` is exercised without a camera in the new suite (the format and the
  report fields are pinned); the projected coordinates are the capture run's business,
  which is integration's.
- The `timing.png` / `timing-off.png` A/B frames are not re-captured: they are tracked
  evidence and a re-run is a deliberate act, not a slice step.

## Final integration (2026-09-18) — the runtime proof, and the review's repairs

- **The owed engine proof is produced.** `/Applications/Godot.app/Contents/MacOS/Godot
  4.7.2`, serial under `/tmp/padel-godot-engine.lock`:
  `--headless --path godot/ --script res://tests/court_timing_marks_test.gd`
  → exit 0 **`PASS 87/87`**, 0 SCRIPT ERRORs, 0 engine `ERROR:` lines. The C section
  (placement from a live state — the part that had never executed in the engine) runs
  and passes in full, as do D (verdict) and E (mute/report/capture lines).
- **Review F-03 repaired**: `_placement()` now calls `_marks.update(_state, false)`
  before its first `report()` read, and the suite grew a slice-style section guard
  (`SECTIONS`/`_section_done`, checked at the end of `_run`), so a thrown section can
  never tally green again.
- **Review F-05 repaired**: `await process_frame` after the mount, before the capture
  section — the 12 `ERROR: Condition "!is_inside_tree()"` lines are gone because the
  reads are real; **no allowance was added** for that class.
- **Review F-10 applied**: the test-only `is_muted()` is deleted; the seam is now six
  calls (`mount`, `mark_names`, `update`, `report`, `set_muted`, `capture_lines`) and
  the mute is asserted through the frame it produces. The suite's own seam inventory
  and check name were updated to six.
- **Slice integration (F-02/F-12)**: `_timing_presentation` now registers completion at
  its normal end (`_drop(node)` + `_section_done`), so `# sections ran 23/23`; the slice
  tally is re-baselined 342 → **345** full (the three F-01-recovered recreated-HUD
  checks) and 293 → **296** demo, with a check-sequence comparison against the review's
  logs proving every other check is identical, same order.
- Commit handle: `refactor: deepen match architecture seams` (local, 2026-09-18);
  no push.
