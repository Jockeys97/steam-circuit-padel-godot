# Reference corpus — machine-readable schema

Owner: Reference team. Consumed by the Port integrator for the A-button differential replay.

## Files

- `corpus/scenarios.json` — the scenario corpus (machine-readable timelines).
- `oracle/a-button-oracle.mjs` — the executable oracle (extracts the REAL browser
  input functions and runs the corpus).
- `out/trace.txt` — the journaled reference trace (the oracle's stdout).
- `verify.mjs` — reproducibility + red-control check.

## Scenario corpus schema (`corpus/scenarios.json`)

```json
{
  "schemaVersion": 1,
  "dt": 0.016666666666666666,          // fixed tick duration, seconds (1/60)
  "seed": 12345,                       // RNG pinned for the sim stage
  "source": "js/main.js",
  "buttonMap": { "A": 0, "B": 1, "X": 2, "Y": 3, "LB": 4, "RB": 5,
                 "LT": 6, "RT": 7, "dpadUp": 12, "dpadDown": 13,
                 "dpadLeft": 14, "dpadRight": 15 },
  "axisMap": { "lx": 0, "ly": 1, "rx": 2, "ry": 3, "LT": 4, "RT": 5 },
  "scenarios": [ { ... } ]
}
```

Each scenario:

| field         | type   | meaning                                                              |
|---------------|--------|----------------------------------------------------------------------|
| `id`          | string | stable scenario name                                                 |
| `description` | string | human-readable intent                                                |
| `bench`       | string | `"stationary"` (isolates input->queued) or `"contact"` (adds a strike) |
| `frames`      | array  | ordered timeline; each frame is `{ b: [button indices], a: [6 axes], n: repeat }` |

`n` (default 1) repeats an identical frame that many times. `b` lists RAW browser
button indices (A=0 …). `a` is the 6-element Gamepad axes array; `a[0..3]` are the
sticks, `a[4]`/`a[5]` feed `pad.buttons[6]`/`[7]` (LT/RT analog values).

## Trace line schema (oracle stdout)

Header (once):
```
# oracle main_js=<sha16> game_js=<sha16> seed=<n> dt=<n> scenarios=<n>
```

Per scenario (once):
```
# scenario <id> bench=<stationary|contact> frames=<n>
```

Per frame (one per tick, fixed key order):
```
# trace {"scenario":..,"frame":..,"input":{..},"sim":{..}}
```

`input` is the full `getInput()` result (the translated intent — 23 fields):
`left,right,up,down,moveX,moveY,charging,hit,slice,shotVariant,special,switchPlayer,
switchDirection,aim,aimY,analogAim,smashUpgrade,cutVolley,globo,splitStep,sprint,
technicalModifier,teamTactic`.

`sim` is the state AFTER `updateMatch` for that tick:
`shotCharge,shotIntent,queuedShotVariant,queuedShotPower,queuedShotSlice,queuedShotAim,
queuedShotAimY,smashPrimed,cutVolleyPrimed,globoPrimed,playerSwingBuffer,shotType`
(`shotType` is `ball.shotType`; baseline captured before the first tick).

Numbers are pre-formatted to 6 decimals (`toFixed(6)`), booleans as `true`/`false`,
absent as `null`. The stream is byte-comparable at tol=0.

Trailer (once):
```
# summary scenarios=<n> frames=<n> exit=0
```

## Known representation notes (not behaviour)

1. **First-frame `smashUpgrade`/`cutVolley`/`globo` = `null`.** On the very first
   tick those `gamepad.*Queued` fields are still `undefined` (no poll has run), so
   `r6` serialises them as `null`; from tick 1 they are `false`. This is the real
   first-frame state of the production input path, not a rewrite.
2. **`stationary` bench ball is not truly stationary.** The reference sim applies
   arcade gravity (~150 px/s²); the bench ball is placed at z=160 so it stays above
   the court for the whole charge+double-tap window (~85 ticks) and never bounces or
   ends the point. It is 125 px from the paddle laterally, so no contact occurs. This
   deliberately isolates the input→queued seam; it does NOT exercise contact.
3. **`contact` bench strikes immediately.** The ball is placed 30 px from the paddle
   (already inside `canHit`), so a tap release queues and strikes in the same tick.
   The `queued` fields read back as their consumed baseline; `shotType` change is the
   strike evidence.
