---
id: UIR-16
title: ProfileScreen 1:1 (screen-profile)
slug: screen-profile
state: done
readiness: potential
owner_role: screen worker
blocked_by: [UIR-02, UIR-03, UIR-04, UIR-05, UIR-07]
blocks: [UIR-22]
gates: [plan-approval, gate-a]
plan_approved: true
triage: ready-for-agent
evidence:
  - docs/implementation/ui-recreation/evidence/uir-16-screen-profile.log
  - docs/implementation/ui-recreation/evidence/uir-finalize/ui-audit-sweep.json
capture_states: [default, empty-objectives, mid-season]
---

# UIR-16: ProfileScreen 1:1 (screen-profile)

## Worker brief (copy-paste)

> Recreate `screen-profile` (`index.html:293-306`) as `godot/src/ui/screens/ProfileScreen.gd/.tscn`, registered as `profile`, back target `menu`. Shows the career stats row (wins, seasons/trophies, stars, win rate), the season objectives list with check state, label, progress/target, and done/claimed state, and the unlock summary with a route to the challenges screen. Empty objective states are localized. Data from `UiData.profile_summary()/season_objectives()/unlock_summary()`; strings from `UiStrings`; zero literals; read-only.

## Why this exists

The reference renderer is `renderProfile` (`js/ui.js:1608`) over the objectives model (`ensureSeasonObjectives:62`, `objectiveStatus:131`, `awardObjectives:144`, `seasonProgress:120`). The port's career lane already persists and evaluates this data (`ModesSave.profile:216`, `CareerProgress`); this screen displays it.

## Prerequisites (Definition of Ready)

- GATE-A passed; UIR-04 landed; UIR-07 landed (pattern).

## Read allowlist

- `index.html:293-306` (containers `profileStats`, `profileObjectives`, `profileUnlocks`, section titles)
- `styles.css`: `.profile-stats:1296`, `.profile-section-title:1311`, `.profile-objectives/.profile-unlocks:1319-1327`, `.profile-empty:1327`, `.profile-kind:1332`
- `js/ui.js:1608-1731` (`renderProfile` and its helpers), `js/ui.js:58-205` (objectives model incl. `objectivesSignature`, `matchProgress`, `accumulateSeasonProgress`, `objectiveMet`)
- i18n keys: `profileTitle`, `profileSub`, `objSeasonTitle`, `profileUnlocksTitle`, stat labels, objective rows keys, empty-state key (locate; do not invent)
- `godot/src/modes/career_progress.gd`, `godot/src/modes/mode_tables.gd` (`objective_defs`, `season_metric_agg`)

## Write allowlist (you own these)

- `godot/src/ui/screens/ProfileScreen.gd`, `godot/src/ui/screens/ProfileScreen.tscn`
- `.uid` sidecars for the two files
- `godot/tests/ui/screen_profile_audit.gd`, `godot/tests/ui/screen_profile_audit.tscn`
- `docs/implementation/ui-recreation/evidence/uir-16-screen-profile.log`

No other writes.

## Behavior rules (each becomes an audit assertion)

- Stats row: wins, seasons/trophies, stars, win rate; values agree with `ModesSave.profile` for the constructed store (the scout's acceptance: "Profile stats and unlock counts agree with ModesSave").
- Objectives: each rendered row shows check state, label id, progress/target, done/claimed state; the list reflects a constructed mid-season state (some done, some not).
- Empty objectives state is localized (no blank section, no raw id).
- Unlock summary: compact counts + a working route to `challenges` (router call).
- Language flip re-resolves everything.

## Microsteps

1. Field table: stat row fields + objective row fields with keys; write into the log.
2. Static tree: stats row, objectives section, unlocks section.
3. Bind from `UiData`; route button to `go_to("challenges")`.
4. `screen_profile_audit.gd`: constructed store variants (fresh, mid-season, complete); agreement assertions vs `ModesSave.profile`; empty state; route; language flip; capture states.
5. Run; save log.

## Acceptance commands (native macOS)

```bash
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
cd /Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot
"$GODOT" --headless --path godot/ --script res://tests/ui/screen_profile_audit.gd ; echo "exit=$?"
```

## Evidence to hand back

`evidence/uir-16-screen-profile.log`; hand-back names the objective label source and any field rendered from an id fallback.

## Definition of Done

- [ ] Stats/objectives/unlocks rendered; agreement with the store asserted; empty state localized; route works; zero literals; audit green.
- [ ] No progression rule evaluated or mutated here.
- [ ] Hand-back names command and tally.

## Failure and recovery

- Win rate or derived stat has no seam: display the numerator/denominator form if the reference does; otherwise blocker note; do not compute silently with invented rounding.
- Objective label ids unresolvable: render the id and record; the locale lane owns the fix.

## Traces

`index.html:293-306`, `js/ui.js:58-205, :1608-1731`, `styles.css:1296-1340`; scout T06 acceptance (profile part).

## Finalize closure (2026-09-17, integration owner)

Engine record, one Godot process at a time, manifest `docs/implementation/ui-recreation/evidence/uir-finalize/ui-audit-sweep.json` (all sources hashed
before and after: tree digest `1256f5f1d7200437`, stable).

- `tests/ui/screen_profile_audit.gd` — **PASS 74/74**, exit 0, 0 `SCRIPT ERROR` line(s) (0.3s); log `docs/implementation/ui-recreation/evidence/uir-finalize/runs/screen_profile_audit.log`

**State: `done`** — the audit above is this ticket's arbiter and it is green on the
finalize tree.
