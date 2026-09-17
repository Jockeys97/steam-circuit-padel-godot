---
id: UIR-15
title: ChallengesScreen 1:1 (screen-challenges)
slug: screen-challenges
state: done
readiness: potential
owner_role: screen worker
blocked_by: [UIR-02, UIR-03, UIR-04, UIR-05, UIR-07]
blocks: [UIR-22]
gates: [plan-approval, gate-a]
plan_approved: true
triage: ready-for-agent
evidence:
  - docs/implementation/ui-recreation/evidence/uir-15-screen-challenges.log
  - docs/implementation/ui-recreation/evidence/uir-finalize/ui-audit-sweep.json
capture_states: [default, some-complete, all-complete, demo-limited]
---

# UIR-15: ChallengesScreen 1:1 (screen-challenges)

## Worker brief (copy-paste)

> Recreate `screen-challenges` (`index.html:281-290`) as `godot/src/ui/screens/ChallengesScreen.gd/.tscn`, registered as `challenges`, back target `menu`. Three explicit sections in the reference's order: characters, outfits, arenas. Each section shows completed/total; character and arena entries show trophy/star progress; outfit entries are grouped by athlete and show their challenge text; completed rows use the medal/done styling; in limited builds a career-limitation note explains that characters and arenas are earned in career. Data from `UiData.unlock_summary()` and the frozen tables; zero literals; read-only screen.

## Why this exists

The reference renderer `renderChallenges` (`js/ui.js:1125`) reads career/progression state; the reference screen is the progression's public face. The port's data already exists (`ModesSave.profile`, `CareerProgress`, gate rosters, `ModeTables.outfits` challenge data via `outfit_by_unlock_key`; the modes lane's `outfit_challenges_audit` proves the rules). This screen is presentation over those.

## Prerequisites (Definition of Ready)

- GATE-A passed; UIR-04 landed; UIR-07 landed (pattern).

## Read allowlist

- `index.html:281-290` (`challengeBoard` container)
- `styles.css`: `.challenge-board`, challenge row styles and the 900px stacking rule (`@media (max-width: 900px)` at `:3245`), medal/done styling (locate exact selectors in the challenges block)
- `js/ui.js:670-702` (`challengeLabel`, `lockLabel`), `js/ui.js:1125-1219` (`renderChallenges`), `awardOutfitChallenges:625`
- i18n keys: `challengesTitle`, `challengesSub`, section headers, completed/total format, career-limitation note key, challenge label keys (locate; do not invent)
- `godot/src/modes/mode_tables.gd` (outfits, unlock keys), `godot/tests/modes/outfit_challenges_audit.gd` (the rules this screen only displays), `godot/src/modes/career_progress.gd`

## Write allowlist (you own these)

- `godot/src/ui/screens/ChallengesScreen.gd`, `godot/src/ui/screens/ChallengesScreen.tscn`
- `.uid` sidecars for the two files
- `godot/tests/ui/screen_challenges_audit.gd`, `godot/tests/ui/screen_challenges_audit.tscn`
- `docs/implementation/ui-recreation/evidence/uir-15-screen-challenges.log`

No other writes.

## Behavior rules (each becomes an audit assertion)

- Three sections, fixed order (characters, outfits, arenas), each with a completed/total count that matches constructed progression state.
- Character/arena entries: trophy/star progress per the career/progression data.
- Outfit entries: grouped by athlete; each shows its challenge text (ids from the frozen tables); locked state renders as not-done; done renders with the medal styling.
- Limited builds: the career-limitation note appears (exact condition: limited build AND section content earned in career); full build does not.
- The 900px stacking behavior is approximated at the port's small size (1024x600) with a readable stacked layout; assert no clipping.

## Microsteps

1. Data table first: three sections, their row shapes, keys, and completion source (write it in the log).
2. Static tree with three sections; rows built from data.
3. `screen_challenges_audit.gd`: empty/all-done/partial states via constructed store + career; demo run shows the limitation note; language flip; capture states; 1024x600 no-overflow.
4. Run full + demo; save log.

## Acceptance commands (native macOS)

```bash
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
cd /Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot
"$GODOT" --headless --path godot/ --script res://tests/ui/screen_challenges_audit.gd ; echo "exit=$?"
"$GODOT" --headless --path godot/ --script res://tests/ui/screen_challenges_audit.gd -- --demo ; echo "exit=$?"
```

## Evidence to hand back

`evidence/uir-15-screen-challenges.log`; hand-back names the completion sources (file:line) and the demo-condition key.

## Definition of Done

- [ ] Three sections with correct counts and row shapes; medal/done styling; limitation note logic; zero literals; audits green.
- [ ] No progression rule evaluated here (display of existing evaluations only).
- [ ] Hand-back names commands and tallies.

## Failure and recovery

- A completion datum has no public seam: display the seam you have and open a blocker naming the missing field; do not recompute rules in the screen.
- The reference groups outfits under an athlete name derived from the athlete table: resolve athlete names via the adapter's rows; if an athlete id in a challenge has no roster entry, show the id and record.

## Traces

`index.html:281-290`, `js/ui.js:625, :670-702, :1125-1219`, `styles.css` challenges block + `:3245`; scout T06 acceptance (challenges part).

## Finalize closure (2026-09-17, integration owner)

Engine record, one Godot process at a time, manifest `docs/implementation/ui-recreation/evidence/uir-finalize/ui-audit-sweep.json` (all sources hashed
before and after: tree digest `1256f5f1d7200437`, stable).

- `tests/ui/screen_challenges_audit.gd` — **PASS 73/73**, exit 0, 0 `SCRIPT ERROR` line(s) (0.6s); log `docs/implementation/ui-recreation/evidence/uir-finalize/runs/screen_challenges_audit.log`

**State: `done`** — the audit above is this ticket's arbiter and it is green on the
finalize tree.
