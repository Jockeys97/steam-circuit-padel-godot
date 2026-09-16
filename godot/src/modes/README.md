# `godot/src/modes/**` — the ported game modes (drill, tournament, career)

Headless, UI-free, storage-free rule modules for the three modes the browser build
runs on top of the match engine. Ported from the frozen reference (commit
`2979588`, `js/**` read-only) and asserted by `godot/tests/modes/**`.

**A UI lane consumes this directory without reading its internals.** Every module
carries an API block in its header comment; this file is the map.

## Files

| File | What it owns | Reference |
|---|---|---|
| `mode_tables.gd` | The generated tables: career shape, ramp, caps, aggregation, objective pool, 26 outfits, the four drill exercises and the drill's numeric constants. `.data()` returns the whole document. | `js/data.js`, `js/drill.js` |
| `career_rules.gd` | Pure rules: season objectives, match bonus, rival, AI ramp, career and tournament fixtures, unlock rules, outfit challenges, `ai_for_match`, `dictated_rivals`. | `js/data.js:702-936`, `js/ui.js:531-546`, `js/ui.js:1529-1540` |
| `career_progress.gd` | The live career: season total, objective evaluation, star arithmetic, the four season outcomes, outfit awards. Mutates a career dictionary passed in. | `js/ui.js:58-192, 625-648`, `js/main.js:1395-1477` |
| `tournament_rules.gd` | The three-round board, its AI tiers, the round advance and the trophy round. | `js/data.js:916-925`, `js/main.js:1398, 1479-1490` |
| `drill_session.gd` | The drill: exercises, phases, attempts, and `step(dt, input)` which delegates every physical movement to `godot/src/sim/sim.gd`. | `js/drill.js:86-463` |
| `drill_target.gd` | Target placement (seeded), kind alternation, squash quality, zone grading. | `js/drill.js:148-162, 264-313` |
| `drill_scoring.gd` | Attempt points, grade multiplier, score line, the four HUD metrics, record policy. | `js/drill.js:244-262, 465-498`, `js/ui.js:219-230` |
| `drill_seed.gd` | The seeded generator that replaces the reference's unseeded `Math.random` placement, with the defect and its anchors. | `js/drill.js:155, 159, 160` |
| `modes_save.gd` | Persistence, through the existing save module only: career, drill records, history, tournament round. | `js/ui.js:38-54, 206-230, 1540-1561` |
| `data/modes.json` | GENERATED. Do not edit by hand. | — |

## The five calls a UI lane needs

```gdscript
# Start a drill session and step it once per rendered frame's tick.
var session := DrillSession.create("precision", athlete, arena, ai_profile, {"seed": 4242, "lineup": lineup})
session.step(1.0 / 120.0, input)          # `input` is the same dictionary the match uses
session.metrics()                          # four {key, value} rows for the HUD
session.phase                              # "ready" | "live" | "result"

# Which court and which AI a mode hands you.
var ai := CareerRules.ai_for_match("career", 0, "", career["season"], career["matchIndex"])
var arena := CareerRules.career_fixture(career["season"], career["matchIndex"], selectable_arenas)["arena"]

# Award a finished career match (objectives, stars, season outcome).
var awards := CareerProgress.award_objectives(career, state.stats)   # {seasonDone, matchDone, stars}
var outcome := CareerProgress.apply_career_match(career, winner == "player")  # "" | "trophy" | "promoted" | "repeat" | "finale"

# Award outfit challenges at the end of any match.
CareerProgress.award_outfit_challenges(career, athlete["id"], state.stats, won, state.ai["skill"])

# Persist: one store instance, the five existing groups.
var store := SaveStore.new()
ModesSave.save_career(store, career)
ModesSave.drill_record_after(store, session)
ModesSave.record_match(store, ModesSave.history_entry(...))
ModesSave.save_tournament_round(store, TournamentRules.advance(round, won)["round"])
```

## Regenerating the tables

```sh
node tools/modes-port/extract-modes.mjs      # writes src/modes/data/modes.json + the test grid
```

The generator records the sha256 of `js/data.js` and `js/drill.js`, and the grid it
writes to `godot/tests/modes/data/reference-grid.json` holds the reference's own
function outputs. `godot/tests/modes/reference_grid_audit.gd` compares the ported
GDScript against them across 3 130 values, so a retuned table or a mistyped formula
fails rather than passing quietly.

## What this directory does NOT do

- No UI, no scene, no `Node`: nothing here needs a renderer or an input device.
- No storage call of its own: `modes_save.gd` goes through `godot/src/save/**`.
- No physics: the drill steps `godot/src/sim/sim.gd` and nothing else moves the
  ball (`godot/tests/modes/drill_audit.gd` fails the build if a ball-integration
  expression appears in these files).
- No mode screens exist yet. The whole application-to-screen layer is a separate
  slice; this lane delivers the rules those screens will read.

## Evidence

`docs/wayfinder/evidence/modes-port.md` — commands, exit codes, per-audit `PASS`,
the ported and not-ported reference assertions, the divergences found, and the
file inventory with sha256.
