# Shot logic parity — every intent, anchor to anchor

- Status: open
- Type: task
- Mode: AFK
- Owner: crew-shotlogic
- Blocked by: none

Slice S14a. Owner question: *"se i colpi corrispondono come logica a quelle della
versione 2d"* — do the shots correspond, as logic, to the 2D version?

## Objective

Prove, intent by intent, that the port decides a shot the way the reference does, and
name every place where it does not. The deliverable is a table the owner can read:
each shot intent, the decision that produces it, the reference anchor, the port
anchor, the constants involved, and a verdict (`identical` / `divergent (named)` /
`not comparable (why)`).

Coverage is the whole intent space, not a sample: the 13 shot intents the reference
can produce (`drive`, `slice`, `vibora`, `bandeja`, `chiquita`, `volley`,
`cut-volley`, `lob`, `defensive-lob`, `globo`, `smash`, `wall-angle`, `serve`) plus
the four modifiers that upgrade an intent (`special`, `smashUpgrade`, `cutVolley`,
`teamTactic`) and the charge/double-tap rules that select them.

## Existing source anchors

| decision | reference | port |
|---|---|---|
| which intent an input produces | `js/main.js:1047-1094` (`getInput`), `js/game.js:719` | `godot/game/input_map.gd`, `godot/src/sim/sim.gd:697` |
| shot quality | `js/game.js:995` | `godot/src/sim/sim.gd:1156` |
| the x3 (perfect) chance | `js/game.js:1213` | `godot/src/sim/sim.gd:1330` |
| the charge→intent rules, double taps | `js/game.js` (`hit` path) | `godot/src/sim/sim.gd` (`hit_ball`, `:2504`) |
| the modifier keys | `js/main.js:836` (RB technical) | `godot/game/input_map.gd` (`PAD_TECHNICAL`) |
| the rules the game promises | `GAMEPLAY_RULES.md:158`, `:178` | the same file |

The reference tree is read-only: `/Users/alessiofantini/Documents/Padel`.

## File ownership / allowlist

- `docs/wayfinder/evidence/shot-logic-parity.md` (new, yours)
- `godot/tests/shot_logic_parity_test.gd` (new, yours) + its `.uid`
- `tools/sim-port/**` (additive only: a new trace runner if the existing ones cannot
  print the intent)
- Read-only everywhere else. Do **not** touch `godot/src/sim/**` in this ticket: a
  proven divergence is handed to the timing/integration lane with the two anchors and
  the reproduction, not fixed in passing.

## Inputs and outputs

In: both trees on disk, the frozen harness (`tools/parity-godot/`), the existing
trace comparators under `tools/sim-port/**`.
Out: the evidence table above, plus a machine-checkable trace of one scripted
scenario per intent, per engine.

## Tests

`godot/tests/shot_logic_parity_test.gd` — runs the port's core headlessly with the
scripted input for each intent and asserts the produced intent, the direction, the
spin sign and the x3 flag. A test that passes for every intent without exercising
the upgrade path is not acceptable: include at least one double-tap upgrade, one
special and one cut-volley.

## Execution commands

```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
$GODOT --headless --path godot/ --script res://tests/shot_logic_parity_test.gd
$GODOT --headless --path godot/ --script res://tests/game_slice_test.gd   # non-regression
```

`flock` and `timeout` do not exist on this Mac: run the binary directly, and one
engine process at a time.

## Expected evidence

`docs/wayfinder/evidence/shot-logic-parity.md`: the table, the exact commands with
their output, the test's pass count, and a "what this does NOT prove" section (the
unexercised modes, the human path, any intent that could not be reached).

## Failure and recovery criteria

Two attempts per failing gate, then record a blocker with the exact reproduction.
A divergence found at the reference's own printed precision is a finding, not a
regression: report it, do not tune the port to hide it, and leave the reference tree
untouched.
