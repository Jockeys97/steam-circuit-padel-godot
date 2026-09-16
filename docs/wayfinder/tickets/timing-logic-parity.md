# Timing logic parity — the numbers behind "PERFETTO"

- Status: open
- Type: task
- Mode: AFK
- Owner: crew-timinglogic
- Blocked by: none

Slice S14b. Owner request: *"metterei anche qui le scritte e le logiche del timing
con Perfetto che c'erano nel 2d"* — the words are already in the HUD; this ticket
covers the logic.

## Objective

Prove that the port's timing model produces the reference's numbers, field by field,
on the same scripted scenario: `shotCharge`, `shotRead.active`, `shotRead.eta`,
`shotRead.perfectWindow`, `shotRead.advice`, `shotRead.profile`, `shotRead.overlap`,
the resulting `quality` and the `x3` flag. Where a field exists in both engines, the
values must agree at the reference's printed precision; where a field is missing in
the port, say so plainly and hand the gap to the presentation lane.

## Existing source anchors

| field | reference | port |
|---|---|---|
| `shotRead` shape and defaults | `js/game.js:220` | `godot/src/sim/sim.gd:351-352` (`perfectWindow` default 0.055) |
| `shotCharge` | `js/game.js:289`, `:719` | `godot/src/sim/sim.gd:429`, `:697` |
| eta (time to the contact window) | `js/game.js` (`playableEta`) | `godot/src/sim/sim.gd:1053` (`playable_eta`) |
| the perfect window | `js/game.js:900` (`contextualPerfectWindow`) | `godot/src/sim/sim.gd:1071` (`contextual_perfect_window`) |
| the shot profile | `js/game.js:902` (`shotProfile`) | `godot/src/sim/sim.gd` (same name) |
| the x3 decision | `js/game.js:1213` | `godot/src/sim/sim.gd:1330` |
| the words the HUD shows | `js/render.js:1730` (`shotAdvice_*`), `:1745` (profile colour) | `godot/game/hud.gd:513-544` (`GRADE_COLORS`, `grade_of`, `feedback_label`) |

## File ownership / allowlist

- `docs/wayfinder/evidence/timing-logic-parity.md` (new, yours)
- `godot/tests/timing_feedback_test.gd` (new, yours) + its `.uid`
- `tools/sim-port/**` (additive: extend a comparator to carry the timing fields)
- `godot/src/sim/sim.gd` — **only** with a proven divergence: the ticket must first
  show the two anchors and a failing reproduction, then the smallest edit, then the
  parity trio re-run and digests reported unchanged.

## Inputs and outputs

In: the frozen harness and the existing strict comparator
(`tools/sim-port/trace-compare.py`), the scripted scenarios already in
`tools/sim-port/**`.
Out: a timing-field trace per engine, compared tick by tick, plus the evidence table.

## Tests

`godot/tests/timing_feedback_test.gd` — asserts the window's boundaries as constants
(`0.055` and whatever `contextual_perfect_window` computes for a given charge), that
`eta` is null outside the incoming window and finite inside it, that the grade
mapping matches the reference's own ids, and that a released charge carries the last
charging `eta`. Float traps: Godot's `Vector2`/`float` are single precision — assert
values clearly inside the bands, never on an edge.

## Execution commands

```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
$GODOT --headless --path godot/ --script res://tests/timing_feedback_test.gd
node tools/sim-port/<comparator>.mjs <js-trace> <gd-trace>     # exact name in the evidence
$GODOT --headless --path godot/ --script res://tests/game_slice_test.gd   # non-regression
```

## Expected evidence

`docs/wayfinder/evidence/timing-logic-parity.md`: the field-by-field comparison with
digests, the comparator's verdict, the test count, and the honest limits (fields
sampled only while charging, the human path unexercised).

## Failure and recovery criteria

Two attempts, then a blocker with the reproduction. Never tune the reference and
never widen a tolerance to make a comparison pass: a widened tolerance is the
finding.
