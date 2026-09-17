---
id: UIR-18
title: DrillScreen 1:1 (screen-drill, setup + session handoff)
slug: screen-drill
state: done
readiness: potential
owner_role: screen worker
blocked_by: [UIR-02, UIR-03, UIR-04, UIR-05, UIR-07]
blocks: [UIR-22]
gates: [plan-approval, gate-a]
plan_approved: true
triage: ready-for-agent
evidence:
  - docs/implementation/ui-recreation/evidence/uir-18-screen-drill.log
  - docs/implementation/ui-recreation/evidence/uir-finalize/ui-audit-sweep.json
capture_states: [precision, smash, rally, serve, difficulty-variants]
---

# UIR-18: DrillScreen 1:1 (screen-drill, setup + session handoff)

## Worker brief (copy-paste)

> Recreate `screen-drill` (`index.html:366-396`) as `godot/src/ui/screens/DrillScreen.gd/.tscn`, registered as `drill`, back target `menu`. The reference page holds the exercise selector (precision, smash, rally, serve), an independent difficulty selector, the four drill metric boxes (with `drillMetrics` labels per exercise), the drill court area, and the instruction line. In the port the drill plays in the real 3D match scene through the existing session contract, so this screen is the reference's setup page and its start action enters the existing `Config.pending_mode = "drill"` / `pending_exercise` handoff into `Match.tscn` (`ModeSession`/`DrillSession`). The in-match drill HUD keeps flowing through the existing session (`mode_hud.gd`); its visual restyle is UIR-22's. Do not build a fake drill.

## Why this exists

The port already has the whole drill engine (`godot/src/modes/drill_session.gd`, `drill_target.gd`, `drill_seed.gd`, `drill_scoring.gd`, `ModeTables.drill_*`, plus `godot/tests/modes/drill_audit.gd`). What is missing is the reference's page in front of it. The reference's own drill metrics mapping (`js/drill.js:475` `drillMetrics`, exercises at `:53-71`) is the label source.

## Prerequisites (Definition of Ready)

- GATE-A passed; UIR-04 landed; UIR-07 landed (pattern).
- The drill session route exists today through `godot/game/mode_screen.gd` (`_col_make_drill:357`, `start_mode:280`); read it before writing.

## Read allowlist

- `index.html:366-396` (segmented selectors, `drill-hud` boxes, `drillCanvas` wrap, `drillHint`, `drillSub`)
- `styles.css`: `.drill-seg:1344`, `.drill-seg--difficulty:1351`, `.drill-hud:1362-1386`, `.drill-canvas-wrap`, `.drill-instructions`
- `js/drill.js:53-71` (four exercises), `:466-498` (`drillScoreLine`, `drillMetrics`), `js/ui.js` drill record display (`drillRecord`, `saveDrillRecord` at `js/ui.js:215-243`)
- `js/main.js:1681` (`startDrill`) and the drill HUD update path (`syncDrillChrome` semantics)
- i18n keys: `drillTitle`, `drillSub`, `ariaDrill`, `drillExercise`, `difficulty`, `diffEasy/Medium/Hard/Legend`, `drill_precision_name`, `drill_smash_name`, `drill_rally_name`, `drill_serve_name`, the per-exercise metric labels and instructions/hints (locate all; do not invent)
- `godot/game/mode_screen.gd:280-336, :357-385` (start/handoff), `godot/game/match_config.gd` (`pending_exercise`), `godot/src/modes/drill_session.gd` (grade/points/attempts/hits/streak fields `:69-88`), `godot/tests/modes/drill_audit.gd` (rules this screen must not touch)
- UIR-06 captures: `screen-drill`

## Write allowlist (you own these)

- `godot/src/ui/screens/DrillScreen.gd`, `godot/src/ui/screens/DrillScreen.tscn`
- `.uid` sidecars for the two files
- `godot/tests/ui/screen_drill_audit.gd`, `godot/tests/ui/screen_drill_audit.tscn`
- `docs/implementation/ui-recreation/evidence/uir-18-screen-drill.log`

No other writes.

## Behavior rules (each becomes an audit assertion)

- Four exercises in the selector; difficulty independently selectable from match difficulty (its own state; the reference's drill difficulty is per drill).
- The metric boxes' labels change per exercise through the drill-metrics mapping; values come from the session's record data (best record per exercise, from `ModesSave.drill_best` semantics).
- Start enters the existing handoff: `Config.pending_exercise = <choice>`, `Config.pending_mode = "drill"`, scene change to `Match.tscn` (exact contract today; UIR-22 keeps it). Assert the payload fields, not the whole match run (the drill behaviour is already audited by the modes lane).
- Ready/running/result states of the drill belong to the session (existing); the setup page shows the best record and the instruction line, and re-reads records after returning from a session (re-enter the screen and assert).
- Escape/back handling: the screen's declared back goes to `menu`; the reference drill's "Escape stops the drill loop" behaviour is the in-match session's (already implemented; do not duplicate).

## Microsteps

1. Field table: exercises x (labels, metrics, instructions, records) with keys; write into the log.
2. Static tree; segmented selectors; metric boxes. The reference shows a live court inside this screen; the port plays in the match scene, so this screen renders the reference layout with the court area as a static frame (reuse the arena preview seam if it is cheap, else the reference's own frame treatment) plus a prominent start action. Record the choice in the evidence file; anything beyond that is GATE-A material, not a silent divergence.
3. Records read via `UiData.drill_records()`.
4. `screen_drill_audit.gd`: exercise set; difficulty independence; metric labels per exercise; records display; start payload assertion (capture `Config` fields and the scene-change call via a test double or by asserting the values set immediately before the call); language flip; capture states.
5. Run; save log.

## Acceptance commands (native macOS)

```bash
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
cd /Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot
"$GODOT" --headless --path godot/ --script res://tests/ui/screen_drill_audit.gd ; echo "exit=$?"
```

## Evidence to hand back

`evidence/uir-18-screen-drill.log`; hand-back names: the start payload contract lines, the canvas-area decision from microstep 2, and the records source.

## Definition of Done

- [ ] Selectors, metrics, records, instructions per reference; start handoff asserted; zero literals; audit green.
- [ ] No drill rules reimplemented (grade/scoring/targets stay in the frozen session modules).
- [ ] Hand-back names command and tally.

## Failure and recovery

- The reference's metric labels for some exercise map to missing ids: render the id and record; locale lane owns the fix.
- The start path cannot be asserted without launching the match: assert the payload immediately pre-change in the same test process (do not launch a second engine).

## Traces

`index.html:366-396`, `js/drill.js:53-71, :466-498`, `js/ui.js:206-243`, `godot/game/mode_screen.gd:280-336`, `godot/src/modes/drill_session.gd`; scout T08 acceptance list.

## Finalize closure (2026-09-17, integration owner)

Engine record, one Godot process at a time, manifest `docs/implementation/ui-recreation/evidence/uir-finalize/ui-audit-sweep.json` (all sources hashed
before and after: tree digest `1256f5f1d7200437`, stable).

- `tests/ui/screen_drill_audit.gd` — **PASS 89/89**, exit 0, 0 `SCRIPT ERROR` line(s) (0.5s); log `docs/implementation/ui-recreation/evidence/uir-finalize/runs/screen_drill_audit.log`

**State: `done`** — the audit above is this ticket's arbiter and it is green on the
finalize tree.
