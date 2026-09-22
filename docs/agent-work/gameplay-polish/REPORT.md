# Gameplay polish — 11m

Direct implementation on `codex/integrate-arena-11m`, preserving the pre-existing
dirty tree. No commit, push, asset regeneration, paid calls or save changes.

## Shipped

- Human teammate coverage now follows the active player's lane, not each lateral
  change of the ball. An 8%-court-width centre band avoids repeated side flips.
  A crossing teammate creates depth separation before moving across the player's
  lane; near the back glass the detour goes forward instead of into the wall.
  Explicit attack/defend/staggered tactics are retained. No autonomous human-team
  shot path was added (manual, semi, auto-selection, co-op and PvP checked).
- Travel forecasts for BOTH teams use actual stamina-adjusted speed. No change
  to speed, reach, contact legality, input timing, ball trajectories or forced errors.
- Modest athlete-based opponent preferences: Fiamma/Pantera are more attacking;
  Oracolo/Steamer more patient; others balanced. Biases affect lob/smash selection
  and offensive depth, not difficulty stats. The existing lineup resolver supplies
  the athlete, including its existing fallback when a lineup entry is absent.
- Running can resume visually after 75% of a stroke and at least 120 ms of its
  post-contact playback. This trims the visual tail only when actually moving;
  contact, follow-through and simulation coordinates remain authoritative.
- Existing lob/chiquita and short-ball rules were retained, not supplemented with
  an artificial attack buff. The attack and shot suites verify their relevant paths.

## Rejected during validation

Adding an earlier reaction hold to the opponent pair increased rally lengths in
the scripted census, so it was discarded. Holding only the support player also
worsened the established X2 defence audit: 121/300 easy-tier winners versus
111/300 from the captured baseline (gate requires fewer than 120). Alternative
fixed-lane recovery did not resolve it. The final patch therefore retains the
original support recovery/reaction behavior; no test thresholds were relaxed.

Cross-engine validation found float32 rounding in the stamina effort-distance
calculation (Vector2). It now uses scalar doubles, matching JS; full trace parity
is exact again rather than hidden behind a tolerance.

## Verification

`node scripts/gameplay-polish-verify.mjs` writes raw evidence into a temporary
directory, or a supplied directory argument. This run's raw logs and baseline
snapshots are in `/tmp/padel-gameplay-polish.8vkbim/` (temporary, not repository data).

- 3 seeds x 12,000 ticks: exact JS/Godot state digests AND event traces.
- Gameplay polish: 40/40 (including no autonomous teammate contacts, actual
  crossing movement, no speed buff, forecast fatigue, styles and visual recovery).
- Stamina: 357/357; animation fluidity: 163/163; tactics: 14/14; AI attack: 16/16.
- Shot logic: 675/675; contact policy: 332 parity + 4 integration cases.
- Full shot balance: 23/23 on final code, including all four X2 defence tiers,
  medium-tier X3 risk and AI shot repertoire. The rejected reaction regression
  is not present in the final implementation.
- Attack bench: short lobs attacked 55/60 (45 smashes); deep lobs attacked 0/60.
  These are seeded scenarios, not universal gameplay percentages.
- Real Match rendering smoke: 960 simulated ticks, exit 0, no script errors.
  Existing ReplayOverlay anchor warnings remain outside this feature.
- In the final three-seed scripted census, mean rally hits remained
  4.33 / 2.87 / 3.27, maxima 9 / 10 / 11, matching baseline. This rules out an
  increase in this sample only; it does not replace human playtesting.

No claim of perfect teammate avoidance, omniscient AI, exhaustive balance, or
guaranteed fun. Live feel still needs the player's feedback.
