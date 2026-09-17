# Feedback vocabulary

Status: **done** — acceptance correction landed (retry 1); all tallies verified in the
final integrated proof, 2026-09-18 (see "Final integration" below — `PASS 70/70`, the
`# tm` trace `401009a7…` byte-identical, slice `PASS 345/345`).

Move grade, color, label, advice, and event knowledge out of the legacy HUD into one deep module. Keep presentation in UI adapters. Test the vocabulary through its public interface. Preserve parity behavior.

Done when shipping callers no longer depend on the legacy HUD for vocabulary and scoped plus integration tests pass.

## What landed

- **New module `godot/game/feedback_vocabulary.gd`** (the one owner): the id
  encodings the ported simulation stores (`shot:<grade>` → `feedback_key`/`grade_of`,
  `shotMode:<mode>` → `mode_key`/`mode_of`, a bare id is already a key), the words
  (`feedback_label`, `mode_label`, `advice_word`, `advice_of` with the reference's
  `?? "read"`), the colours (`grade_color`, `field_grade_color`,
  `field_energy_color`, `precision_color`, `advice_color` + the palette constants),
  the resolver rule (`_resolve_or`) and the `UNREADABLE` marker. `static` functions
  and constants only; it preloads the verified locale layer and nothing else.
- **`godot/game/hud.gd` consumes it and keeps painting.** The moved block is gone
  from the HUD (no aliases, no second copy of a palette or a word): `_update_feedback`
  asks `Vocabulary.feedback_label/mode_label/grade_color`; the file keeps its own
  painting — the panels, the safe-area pass, the score, the energy bar's own (port)
  bands, and the event log's lines (resolved by the module; see retry 1).
- **`godot/game/match_controller.gd` takes every vocabulary answer from the module.**
  All nine `HudScript.<vocabulary>` call sites became `Vocabulary.*` (the ring's
  precision fill, the energy bands, the advice word and tone, the verdict's word,
  mode and colour). Its only remaining use of the legacy HUD script is
  `HudScript.new()` — the mount, which gate 4 owns. The hidden legacy HUD no longer
  exists solely to expose vocabulary.
- **`godot/src/ui/ViewState.gd` stops duplicating the marker.** Its private
  `UNREADABLE := "??"` (whose comment said it existed because the fallback table
  lives in `hud.gd`) is now the module's `Vocabulary.UNREADABLE`; the recreated
  path's own message resolution is otherwise untouched.
- **Tests cross the seam.** New `godot/tests/feedback_vocabulary_test.gd` (58
  checks) tests the module through its public interface. `game_slice_test.gd`'s
  feedback checks (`feedback_label`, `mode_label` and the three court-mark colours)
  and its `UNREADABLE` reference now call the module; `timing_feedback_test.gd`'s
  private `mode_key` copy is deleted and the trace reads `Vocabulary.mode_key`.

Behaviour is a move: every branch and every value is byte-for-byte the one the HUD
shipped (the timing trace hash below is the machine-checked form of that claim).

## Evidence (this captain, `/Applications/Godot.app/Contents/MacOS/Godot 4.7.2`, one engine at a time, `/tmp/padel-godot-engine.lock`)

RED — `res://tests/feedback_vocabulary_test.gd` against a stub module (interface, no
knowledge), before the production files were touched:

    --headless --path godot/ --script res://tests/feedback_vocabulary_test.gd    exit 1  FAIL 5/58
    54 failures, 0 SCRIPT ERRORs; first: "the legacy HUD no longer declares the moved
    vocabulary: [...]", "the controller's only use of the legacy HUD script is the
    mount: HudScript. x12", then every word/encoding/colour check.

GREEN — same command, same test, after the module and the call sites landed:

    --script res://tests/feedback_vocabulary_test.gd    exit 0  PASS 58/58   0 SCRIPT ERRORs

Scoped and integration suites (serial; every tally identical to the pre-change run):

    tests/timing_feedback_test.gd            exit 0  PASS 100/100   # tm trace sha256
                                             401009a7… / digest 560b2acf… — IDENTICAL to the
                                             pre-change run (the `fbMode=` derivation now comes
                                             from the module), diff of the non-trace lines empty
    tests/game_slice_test.gd                 exit 0  PASS 342/342   (identical tally; only
                                             spawn_ms noise + line-number shifts in the diff)
    tests/ui/uir22_integration_audit.gd      exit 0  PASS 71/71
    tests/ui/router_audit.gd                 exit 0  PASS 86/86    (the UI literal scan covers
                                             the edited `ViewState.gd`)

Anti-churn control for the slice suite: with the slice stashed, two runs of
`game_slice_test.gd` were `PASS 342/342` too, and the exit-time leak warning is a
pre-existing nondeterministic class (audio streams still in use: 10 and 114 leaked
instances in the stashed baseline vs 98–103 with the slice) — not a regression of
this slice.

`gdlint` on every changed script: the new module and the new test are clean (0
findings); `match_controller.gd`, `ViewState.gd`, `game_slice_test.gd` and
`timing_feedback_test.gd` have the same findings, same counts (no new ones);
`hud.gd` drops 29 → 21 (the deleted block carried 8 `class-definitions-order`
findings). `git diff --check` clean; `js/**`, `scripts/**`, `godot/src/sim/**` and
`godot/project.godot` untouched; every Wave-1 file keeps its pre-slice mtime
(22:41–22:44 vs this slice's 22:55–23:01); the pre-existing untracked UID/debris
files are byte-for-byte untouched and unstaged. No commit.

## Retry 1 — the event knowledge moves out of the HUD (acceptance correction)

Gate 1 requires the vocabulary module to own grade, colour, label, advice **and event
knowledge**. The first landing left `EVENT_LABELS`, `describe_event()` and
`reason_label()` in `godot/game/hud.gd`; this retry moves them — and their generator
and their reader — to the module. No behaviour change: the table and the resolver are
byte-for-byte the ones the committed HUD shipped.

- **`godot/game/feedback_vocabulary.gd`** now declares `EVENT_LABELS` (in the const
  region, so the file's declaration order stays lint-clean) and
  `describe_event`/`reason_label` (verified locale layer first, the generated floor
  second, `UNREADABLE` last). This is the only copy of the table in the game.
- **`godot/game/hud.gd`** declares no table and no resolver: `_update_log` asks
  `Vocabulary.describe_event(...)`; the log's de-dup rule, the panels and the panel
  maths stay.
- **`godot/game/tools/gen_hud_labels.py`** writes and `--check`-verifies the block in
  `feedback_vocabulary.gd` (marker text unchanged; the markers now live in the
  module).
- **`tools/i18n-port/hud-coverage.mjs`** reads the table from the module. This repoint
  is required: left pointing at the HUD the probe would have read `{}` and every
  emitted id would have counted as a leak (`--fail-on-leak` red).
- **Tests.** `feedback_vocabulary_test.gd` moves `const EVENT_LABELS`,
  `static func describe_event` and `static func reason_label` from the KEPT list to
  the MOVED list, keeps `func _update_log`/`static func panel_rect` as the HUD's own
  painting, and adds a 12-check event-log section: the production wiring (the check
  goes red if the `Vocabulary.describe_event(` call is deleted from `hud.gd`), the
  four resolver outcomes, the table's never-an-id/projection properties, the
  debt-ledger fallbacks. `game_slice_test.gd`'s six `Hud.EVENT_LABELS`/
  `Hud.describe_event` references now read the module. Expected tally: 70 checks
  (58 + 12), to be confirmed by the engine run.

Evidence (static — the engine was busy, see below):

    python3 godot/game/tools/gen_hud_labels.py --check
        OK — feedback_vocabulary.gd EVENT_LABELS is byte-identical to the generated block    exit 0
        (94 entries: 84 projected from the `it` table + the 10 debt-ledger fallbacks)
    python3 -m py_compile godot/game/tools/gen_hud_labels.py                                  exit 0
    node tools/i18n-port/hud-coverage.mjs --fail-on-leak
        # godot/game/feedback_vocabulary.gd — 94 generated event labels, sha256 2db8bcc6e9b1
        # ids the sim can emit: 108 — 108 get a readable line, 0 print the id (or contain it)   exit 0
    gdlint: feedback_vocabulary_test.gd clean; hud.gd 21 -> 16 findings;
        feedback_vocabulary.gd 0 -> 4 (the four >100-char generated lines moved with the block —
        same class, same count, no new class anywhere); game_slice_test.gd unchanged at 121
    byte-for-byte: the moved block (markers included) is identical to the committed
        `godot/game/hud.gd` block — sha256 7c1d60d8… on both sides; the resolver's code bodies
        differ only by the new `reason_label` docstring

Engine verification (feedback_vocabulary_test.gd, timing_feedback_test.gd,
game_slice_test.gd) is **blocked for this retry**: PID 39787 held the project when the
retry started and a Godot editor process (PID 42103, started 23:07:03) held it when the
work finished — no engine was launched by this captain and
`/tmp/padel-godot-engine.lock` was never taken. The integrator re-runs the three suites
serially (and confirms the module test's new tally of 70).

External interference observed, not this captain: the Godot **editor** PID 42103
rewrote the frozen `godot/project.godot` at 23:07:06 (section reorder, comment loss —
`[display]` moved above `[input]`; `git diff godot/project.godot`). Restore it
byte-for-byte from HEAD before the final commit (charter hard limits).

## Known gaps

- **A pre-existing divergence this slice preserves, recorded rather than fixed.**
  For a successful smash the simulation stores the mode as the grade already
  uppercased (`sim.gd:1795`, mirroring `js/game.js:1832`) and the reference draws
  that stored string verbatim (`js/render.js:1068-1069`); the port's resolver refuses
  to echo a stored value back as its own label, so that one mode renders the port's
  marker instead of `PERFECT`. `feedback_vocabulary_test.gd` pins today's value with
  a named check ("RECORDED, NOT ENDORSED") — fixing it is a behaviour change and
  belongs to a defect slice, not to a deepening slice.
- **`EVENT_LABELS`/`describe_event()` staying in `hud.gd` — CLOSED by retry 1.** The
  first landing left the event log's table and resolver in the HUD because the
  generator and the coverage tool read that file; the charter's gate 1 requires the
  vocabulary module to own event knowledge, so retry 1 moved them (and their two
  readers) to the module. See "Retry 1" below for the exact scope and evidence.
- **The port's panel palette has no reference anchor.** `GRADE_COLORS` (the corner
  line) is the port's own palette as shipped; only the field verdict's four, the
  energy bands, the precision fill and the advice tone have `js/render.js` anchors.
  Its values are pinned as parity in the new test.
- **The legacy HUD is still mounted** (invisible under `--ui=new`): removing the
  mount is gate 4's (mount policy), and the controller's `HudScript` preload is now
  used for nothing else.
- The main harness, the demo slice, the audio suites, the world-arena proof and the
  JS audit are the integrator's gate-6 sweep; this lane ran the scoped and
  integration suites named above.

## Final integration (2026-09-18)

- **Verified in the integrated sweep** (serial, engine lock): `feedback_vocabulary_test`
  exit 0 **`PASS 70/70`**, 0 SCRIPT ERRORs (the retry's expected tally confirmed);
  `timing_feedback_test` exit 0 `PASS 100/100` with `timingSha256=401009a7cc07a7d6…` /
  `digestSha256=560b2acf…` — byte-identical to gate 1's own run, the machine-checked
  form of "behaviour moved, not changed". Slice full `PASS 345/345`, demo `PASS 296/296`,
  `uir22` 75/75, `router_audit` was 86/86 in the lane.
- **The generator and coverage gates re-run at integration**: `gen_hud_labels.py
  --check` exit 0 (94 entries, byte-identical) and `hud-coverage.mjs --fail-on-leak`
  exit 0 (108 ids — 108 readable, 0 leaks).
- **The recorded divergence stays recorded**: the smash mode's stored uppercase grade
  is pinned "RECORDED, NOT ENDORSED" in the suite; fixing it is a defect slice's work.
- **The legacy-HUD-mount gap is closed by gate 4**: the ported column is now built only
  for an explicit legacy request; the slice asserts `HudLayer/Hud` ABSENT in a shipping run.
- Commit handle: `refactor: deepen match architecture seams` (local, 2026-09-18);
  no push.
