# Rally stamina — implementation and verification

Implemented directly in the canonical 11m checkout; no Flash, API calls, commit or
push for this task. Concurrent changes to modes, coach and setup were preserved.

## Runtime

- Each paddle owns staminaEnergy (fresh/default 1, floor .15). Successful contact
  charges its actual hitter and resolved shot, so automatic smashes and bandeja
  fallbacks pay the correct cost. Four independent meters in the 3D court.
- Shared recovery/drain was removed. Costs scale with the actual athlete's stamina,
  equally for humans and AI. Continuous work uses actual displacement, not requested
  motion, preventing wall pushing and idle AI targets from draining energy.
- Controlled shot .025, drive .04, slice .035, bandeja .055, vibora .065, smash .10;
  balanced charge adds .01, power adds .025. Aliases handled in mirrored helpers.
- Movement drain .002/s baseline + .008/s movement + .016/s moving sprint;
  recovery .008/s when still, fading with movement. Resistance scales both.
- Above 60%, fatigue has no effect. Smoothstep below 60% reaches a maximum 12%
  reduction in movement at 15%. All human/AI movement paths and AI contact planning
  use the multiplier. Stored base speed is never mutated.
- Existing assessment/timing/risk handles precision using effective energy
  1 - .6*fatigue. No additional jitter/RNG or forced miss; direct quality reduction
  at fixed timing/contact is bounded to .048. Existing shot-profile thresholds
  still apply; no separate centimetre-level dispersion guarantee is claimed.
- No continuous drain during pause, serve preparation, point pauses or hit stop.
  Point end resets all four; switching preserves individual values. Replay records
  and restores energy, with full-energy fallback for older snapshots.
- Existing rallyEnergy.player compatibility field mirrors the active athlete;
  rallyEnergy.ai is the opponents' average. Neither drives contact/movement now.
- IT/EN help explains stamina and foot-level meters; special charge is separate.

## Deterministic balance fixtures

At stamina=1 and 50% movement, one controlled shot every 3 seconds:
10 seconds -> .905 energy, 30 seconds -> .690. Replacing those contacts with
smashes gives .15 after 30 seconds. Same results at 30/60/120Hz. These are workload
fixtures, not claims about typical real player rally duration.

Three scripted 100-second matches (seeds 12345/999/2024): 42 completed points,
144 total hits, longest rallies 9/10/11 contacts. Minimum individual energies
.686/.745/.634 respectively. Scripted player is mostly stationary and loses
40 of 42 points: this is a reproducible regression workload, NOT a fair skill
matchup or evidence that win-rate balance is settled. Long-intensive workloads
are covered separately by the fatigue fixtures.

## Verification

- `node scripts/rally-stamina-test.mjs /tmp/stamina-fixtures.json`: PASS;
  324 cross-engine helper fixtures plus finite/bounds checks through 36,000 ticks.
- Godot `res://tests/rally_stamina_test.gd -- /tmp/stamina-fixtures.json`:
  1234/1234. Includes real movement penalty, precision threshold, misses,
  independent contact costs, solo/co-op/PvP, pause/serve/hitstop, switch and reset.
- Three `ref-match.mjs` / `match_digest_gd.gd` / `compare-match.mjs` runs:
  IDENTICAL digest/events, 12,001 samples each. Legacy digest doesn't encode energy
  directly; helper fixtures and dedicated assertions cover the new values.
- Court timing/energy presentation 87/87; timing feedback 100/100;
  AI attack 16/16; controller tactics 14/14; replay 166/166;
  AI bounce policy 332 fixtures + 4 integration scenarios PASS.
- Rendered Match.tscn through 960 gameplay ticks: PASS, four meters inspected.
  `rally_stamina_capture.gd` renders deliberately staged energy bands at
  `/tmp/padel-stamina-levels.png`; these are UI fixtures, not gameplay measurements.
- `git diff --check`: PASS. Replay audit passes assertions but prints a resource
  still-in-use exit warning; rendered match also prints ReplayOverlay anchor
  warnings. Those are not a clean warning-free end-to-end run.

## Remaining product validation

Human playtest of extended rallies, aggressive-vs-controlled play and stamina
differences across the roster. Tune costs from those observations, without
changing the bounded slowdown or adding a second accuracy penalty. No claim of
final competitive balance or broader frame-rate/performance audit.
