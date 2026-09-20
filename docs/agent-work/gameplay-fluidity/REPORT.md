# Direct Astra completion — 2026-09-20

Workspace: steam-circuit-padel-11m / codex/integrate-arena-11m.
User explicitly requested direct completion without Flash. No new delegation,
paid generation, credentials, branch changes, commits or pushes.

## Implementation

- Replaced the incomplete 421-line prediction/timer with pure bounded first-bounce
  policies in godot/src/sim/ai_contact.gd and js/ai-contact.js. Both callers use
  the decision for movement and retain can_hit, reaction and receiver gates.
- Preserve comfortable net volleys and short descending overhead opportunities.
  Wait only for a first bounce predicted reachable inside a short time horizon,
  with reaction/travel margins. Never defer again after a bounce. Near-glass and
  uncertain wall paths fall back to the existing contact/recovery behavior rather
  than inventing a second physics engine. No new glass tactics claimed.
- Added in-place lateral shuffle, backpedal, preparation, small receiver split
  step and compact volley. Crossfade gait/recovery over 100ms; actual stroke
  starts immediately at authoritative contact phase with zero blending.
- Complete idle/stroke tracks prevent unkeyed limbs reverting to imported T-pose.
  Preserved existing Fiamma stance, asset mappings, Fornaio and material fixes.
- No simulated coordinates, player inputs, ball physics or timing labels changed
  by presentation. New animation code lives in athlete_rig.gd / athletes_view.gd.
- Earlier forecast-return additions and aiDeferTimer removed; state.gd returns
  to its pre-Flash tracked contents. Concurrent UI, court/racket and controller
  edits are not part of this change and were not overwritten.

## Verification

`node docs/agent-work/gameplay-fluidity/tools/verify.mjs` exits 0:
- 332 pure decision parity cases plus 4 Godot caller scenarios (serve, bounced,
  glass-return and reaction gate).
- Three seeded simulations, 12,000 ticks each: JS/Godot digests AND event streams
  identical at every sampled tick. Seeds 12345, 999, 2024.
- Before/after census over five seeds x 12,000 ticks:
  before 123 AI contacts = 63 airborne + 60 bounced (51 serve returns);
  after 118 AI contacts = 40 airborne + 78 bounced (51 serve returns).
  Excluding serve returns: airborne share 87.5% -> 59.7% in this scripted sample.
  Not a global gameplay percentage or an enforced quota. Different decisions
  change later rallies and random draws; identical seeds are not identical rallies.

Godot gates (logs in evidence/):
- fluidity_animation_test: 125/125 across six athlete/rig configurations;
- athlete_stroke_bridge_test: 75/75; athlete_rig_test: 42/42;
- Fiamma idle and three-athlete integration: PASS;
- Colosso 19/19; Fornaio 77/77;
- AI attack 16/16 (short lobs attacked 55/60, smash 45/60; deep lobs 0/60 attacks);
- controller tactics 14/14; timing feedback 100/100.

The initial policy failed the short-lob attack gate. Fixed by preserving reachable
short descending overheads; did not weaken assertions or rewrite expected hashes.
The initial animation probe sampled equal sine phases; corrected the sampling
times, then verified actual changing bone poses and stroke-to-gait recovery.

Rendered evidence: padel-fluidity.png (pose comparison) and
padel-fluidity-match-{360,720,959}.png from the real Match scene, 960 simulated
ticks, exit 0. Existing ReplayOverlay anchor warnings remain, unrelated to this
feature. No script errors in the completed capture.

## Limits

These are procedural in-place animations, not new motion-capture assets or foot
IK. Dedicated forehand/backhand and full smash/bandeja clips remain follow-on work
as scoped in PLAN.md. Bounce forecast ignores air drag over a short horizon and
deliberately rejects edge/wall paths; this is a conservative heuristic, not perfect
prediction. Existing solo teammate positioning is unchanged (not a newly added
autonomous hitting partner). No claim of exhaustive difficulty/arena balance.
