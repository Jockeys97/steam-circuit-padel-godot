---
id: UIR-23
title: Demo and beta content matrix evidence
slug: demo-matrix
state: blocked
readiness: potential
owner_role: verification worker
blocked_by: [UIR-04, UIR-10, UIR-11, UIR-12, UIR-21]
blocks: [UIR-25]
gates: [plan-approval, gate-a]
plan_approved: false
triage: ready-for-agent
evidence:
  - docs/implementation/ui-recreation/evidence/uir-23-demo-matrix.md
---

# UIR-23: Demo and beta content matrix evidence

## Worker brief (copy-paste)

> Prove the limited-build behavior across the recreated screens, one row per matrix cell, with a headless audit run in both `full` and `--demo` modes (and beta if the build flag supports it). Content: athletes, arenas, modes, difficulty, outfit challenges, badge, result CTA copy. Every row cites the screen, the evidence line, and the gate source. This ticket writes one audit (`demo_matrix_audit.gd`) and one evidence file; it does not modify any screen. If a screen disagrees with the matrix, that is a FINDING: name the screen ticket and hand it back, do not patch the screen here.

## Why this exists

The demo rule lives in `godot/game/content_gate.gd` over `godot/tests/build/**` (`BuildFlag`, `DemoContent`, `ContentFilter`), ported from `js/build.js` (`BUILD_CONTENT`, `IS_DEMO`, `demoFilter`, `demoLocked`; verified: demo = athletes [maestro, steamer], arenas [clockwork], modes [quick], difficulty "medium", outfitChallenges true; beta = same athletes, three arenas, all difficulties, career/tournament still out). The scout's T12 acceptance list is the reference behavior; this ticket turns it into executable evidence across the new screens, and it exists because a misapplied demo rule is invisible state (the `content_gate.gd` header documents a real defect this seam closed).

## Prerequisites (Definition of Ready)

- GATE-A passed; UIR-10/11/12/21 landed; UIR-04 landed.

## Read allowlist

- `js/build.js:1-112`; `js/ui.js:737-770` (`applyDemoLimits`), `:1417-1420` region (demo CTA copy usage), `js/main.js:2392-2420` (`applyStoreCta`)
- `godot/game/content_gate.gd` (full), `godot/tests/build/**`, `godot/tests/build/demo_audit.gd` (the existing demo audit: extend coverage, do not duplicate it; if your matrix belongs there, coordinate ownership: `demo_audit.gd` is owned by the export lane's history; yours is the UI-facing matrix in `tests/ui/`)
- The screens' audit logs from UIR-10/11/12/21

## Write allowlist (you own these)

- `godot/tests/ui/demo_matrix_audit.gd`, `godot/tests/ui/demo_matrix_audit.tscn`
- `.uid` sidecars for the two files
- `docs/implementation/ui-recreation/evidence/uir-23-demo-matrix.md`
- `docs/implementation/ui-recreation/evidence/uir-23-demo-matrix.log`

No other writes. Do not edit screens, gate modules, or build flag modules.

## The matrix (one row per cell; each row gets a line in the evidence file)

| # | Aspect | Full build | Demo build | Beta build (if flag exists) |
|---|---|---|---|---|
| 1 | Athletes exposed | all roster | maestro, steamer | maestro, steamer |
| 2 | Athletes not exposed | n/a | visible, locked, not selectable | visible, locked |
| 3 | Arenas exposed | nine | clockwork | clockwork, officina, locomotive |
| 4 | Arenas not exposed | n/a | visible, locked, dimmed preview | visible, locked |
| 5 | Modes | quick, tournament, career | quick only, others visible+locked | quick only, others visible+locked |
| 6 | Difficulty | all four | pinned medium, others disabled | all four |
| 7 | Outfit challenges | available | available (kept) | available |
| 8 | Build badge | hidden | "DEMO" | "BETA" |
| 9 | Result CTA body copy | hidden (no store URL) | demo copy key | beta copy key |
| 10 | Result CTA label | n/a | wishlist vs follow by destination; hidden when null | same |
| 11 | Menu top nav / actions | all | all (unchanged) | all |
| 12 | Language handling | it/en | it/en | it/en |

## Microsteps

1. Confirm how the build flag is set for a run (`godot/tests/build/BuildFlag.gd`; the slice's `-- --demo` path); record the exact mechanism.
2. For each row, collect the assertion from the owning screen's audit if it already exists (cite log + line); add the missing ones INSIDE YOUR audit by mounting the screens through the router (you may mount read-only; you do not modify screens).
3. Run `full`, `--demo`, and beta (only if the flag supports it; if beta is not selectable, mark rows "not runnable in the port today" with the reason from `BuildFlag.gd`, and record it as a traceability note, not a pass).
4. Write the evidence file: the table with per-cell status, evidence line, and any finding naming the owning ticket.

## Acceptance commands (native macOS)

```bash
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
cd /Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot
"$GODOT" --headless --path godot/ --script res://tests/ui/demo_matrix_audit.gd ; echo "full exit=$?"
"$GODOT" --headless --path godot/ --script res://tests/ui/demo_matrix_audit.gd -- --demo ; echo "demo exit=$?"
```

## Evidence to hand back

`evidence/uir-23-demo-matrix.md` + `.log`; hand-back message: cells proven, cells not runnable, findings with owning tickets.

## Definition of Done

- [ ] Matrix fully populated; every cell either proven with a log line or explicitly not-runnable with a reason.
- [ ] No screen or gate file modified; findings handed to owners.
- [ ] Hand-back names commands and tallies.

## Failure and recovery

- A screen disagrees with the matrix: finding, not a patch; name the ticket and the exact assertion that failed.
- Beta flag absent: record the absence; do not emulate beta by string substitution.

## Traces

`js/build.js:1-112`, `js/ui.js:737-770, :1417-1420`, `godot/game/content_gate.gd`; scout T12 acceptance list; handoff demo-lock treatment requirement.
