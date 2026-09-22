# Priorities 2 + 3 — Godot-only counterattack and closing chances

Canonical `steam-circuit-padel-11m`, `codex/integrate-arena-11m`.
Direct implementation, no Flash, commits, paid services or JavaScript edits.
Existing uncommitted work preserved. This supersedes the earlier plan's parity
requirement for this bounded extension: new gameplay behavior is Godot-only.

## Design and delivered behavior

- A low drive hit near the net while stretching/running is contained rather than
  as deep as a planted drive. A continuous factor combines contact height below
  38, lateral reach, movement and existing skill; depth interpolates 168→120 and
  flight time .98→1.12 seconds before existing profile multipliers. No new dice
  rolls, forced errors, input changes, reach or movement buffs. It is geometry
  dependent, not a bonus attached to the name of the incoming shot.
- Comfortable contacts, lob choices, volleys, smash returns, player shot physics
  and first-bounce rules remain unchanged. The opponent can still choose a lob,
  so rushing the net blindly is not guaranteed to work. Human teammate still
  positions only; the user must switch/hit.
- Existing compact advice can say STEP IN / AVANZA CON CALMA when a high, deep
  in-court lob has actually pushed BOTH opponents back; or FIND THE GAP / CERCA
  LO SPAZIO for a reachable short low reply with an uncovered outside lane while
  the player has earned a forward position. Forecast includes air drag, is
  advisory, and does not predict wall bounces or promise a winner. No target aim
  assist, extra panels, guaranteed smash or automatic shot.
- Advice uses the existing visibility controls and clean-HUD mode.

## Rejected experiment

Automatically setting AI recovery mode on a contained drive sent the pair deep
and produced a 25-hit rally in the three-seed sample. Removed: original movement
and recovery state remain unchanged. Only the contextual drive trajectory and
advice are shipped. No audit thresholds were loosened.

## Validation

Evidence directory: `/tmp/padel-counterattack.BjAO1p` (temporary). Baseline is a
snapshot of the actual dirty simulation immediately before this change, not HEAD.
Focused tests cover continuous boundaries, all four tiers, unchanged RNG and shot
choices, legal contacts and real flights over the net, exclusions for smash
defence, false-positive advice, localization and real Match display/hide.

Final results: counterattack + native rendered Match checks **571/571** (99 drive
decisions, 22 real contained replies traced over the net); full shot balance
**23/23**, AI attack **16/16**, teammate/style/recovery regression **40/40**, stamina
**357/357**, timing marks **87/87**, UI visibility **154/154**. Exit codes 0;
no script errors in final native captures. Existing ReplayOverlay anchor warnings
and UI-audit ObjectDB shutdown warning remain outside this feature. `git diff
--check` passes. Captures: `/tmp/padel-counterattack-advance.png` and
`/tmp/padel-counterattack-space.png`.

Three fixed-input Godot samples, 12,000 ticks each (not human playtesting):

| Seed | Before: hits / rallies / longest | After: hits / rallies / longest |
| --- | --- | --- |
| 12345 | 52 / 12 / 9 | 42 / 17 / 9 |
| 999 | 43 / 15 / 10 | 43 / 16 / 8 |
| 2024 | 49 / 15 / 11 | 43 / 16 / 5 |

These inputs mostly stand still and repeatedly charge; they establish regression
evidence, not that all players will get shorter rallies or find the change fun.
Player errors in these samples were 1/5/3 before and 5/5/3 after: trajectories
change what this fixed input reaches. No player error formula changed. Real
playtesting is still needed, particularly advancing behind chiquitas and lobs.
