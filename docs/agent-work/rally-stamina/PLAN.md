# Individual rally stamina — proposed first balance pass

Status: implemented directly after explicit user authorization to bypass Flash;
technical checks completed, human playtest pending. See REPORT.md. Canonical checkout: steam-circuit-padel-11m,
branch codex/integrate-arena-11m. Preserve concurrent edits. No commit/push authorized.

## Evidence and objective

Existing JS/Godot rallyEnergy is side-wide, already feeds shot quality/timing/risk,
costs shots (smash base .13 plus power .095), and regenerates .062/s. Godot
sim.gd consume_rally_energy and the per-tick recovery block mirror js/game.js.
Stamina currently averages the two athletes; AI recovery differs from human.
Extend this system rather than layering independent fatigue penalties over it.

Desired outcome: long, intensive rallies reward controlled shots and positioning,
without making short rallies sluggish or forcing random mistakes. Fair to AI,
solo, co-op and PvP. No between-point or match-long fatigue in this iteration.

## Proposed contract (values require simulation acceptance, not proven balance)

- Energy belongs to each paddle identity, not the selected controller or team.
  Switching must not refill it; an AI teammate expends its own energy.
- Four normalized energy values clamped to [0.15, 1]. Existing side aggregates
  may remain for compatibility, but contact/movement use the actual athlete.
- Full reset at next point. No drain during pause, menus, serve setup, hit stop
  or point-ending transitions; do not count wall-clock time as rally time.
- Total normalized shot costs, replacing existing shot costs: controlled shot
  .025, drive .04, slice .035, bandeja .055, vibora .065, smash .10;
  full-power additional cost at most .025. Charge/cancel/miss does not charge
  contact cost; charge successful contacts exactly once. Keep special cooldown
  separate. Resolve all current aliases to a single cost category.
- Continuous rally workload provisional: .002/s baseline, .008/s at full normal
  movement and additional .016/s at full sprint. Idle recovery .008/s scaled
  down with movement; net stationary recovery .006/s. Apply athlete stamina to
  costs/recovery consistently on both sides. Costs reflect actual movement,
  never an AI target outside the court or a pressed button at a blocked edge.
- Below .60, smooth bounded penalty: fatigue = smoothstep(0,1,(.60-energy)/.45).
  Movement multiplier = 1-.12*fatigue for every movement path, including AI.
  No immobilization, acceleration exploit, sprint bonus bypass or altered hitbox.
- Precision integrates existing energy-dependent assessment/timing/risk rather
  than multiplying another penalty onto them. Final implementation uses a bounded
  assessment-energy mapping [1,.4], giving at most .048 direct quality loss at
  identical contact/timing. The proposed .25 m target-error cap was not adopted:
  existing shot profiles and timing interact nonlinearly, so an independent aim
  clamp would interfere with current trajectories. No new RNG or forced misses.
  Controlled shots retain an advantage; not every tired smash must fail.
- UI: show each visible athlete's energy using existing meter conventions,
  explicit localized stamina hint, and readable low-energy cue. Do not confuse
  special-charge meter with energy. No expensive per-frame UI allocations.
- Keep JS and Godot behavior equivalent. Update serialized/replay state and
  state digests deliberately; older state must default missing energy to full.

## Phase and ownership

One end-to-end implementation bundle: inspect state/movement/contact/HUD paths,
implement mirrored stamina helpers, wire all four athletes, add localized UI,
run deterministic balance fixtures and integration tests, document measurements.
Allowed scope: js gameplay/state/balance modules; godot/src/sim equivalents;
relevant Godot HUD/localization adapters; stamina tests and this feature's report.
Do not alter character models, animations, court physics, scoring, net/wall
rules, existing coach behavior or provider configuration. No external API calls.

## Acceptance

1. Fresh short exchange (<=10s, 3 controlled contacts/athlete, moderate movement)
   retains >=.75 energy and no speed penalty for stamina=1.
2. Controlled 30s scenario retains >=.50; same workload with repeated smash
   loses more energy. Publish contact counts, movement duty cycle and results.
3. Extreme 60s scenario stays bounded; speed >=88% fresh speed always. No NaNs.
4. Test all four identities, alternating hitters, switching, solo/co-op/PvP,
   high/low athlete stamina, no-contact swings, point reset, pauses/serve setup.
5. Equal workloads give equal human/AI costs; 30/60/120Hz fixture outcomes within
   numerical tolerance. Same seed gives repeatable outcomes; cross-engine parity.
6. Existing movement, shot, scoring, AI contact and UI tests remain valid.
   Measure rally length, error distribution and winner rate across fixed seeds;
   distinguish scenario tests from genuine player-tested balance.
7. Visually verify meters and a playable match. If numerical criteria conflict,
   adjust constants transparently, never weaken tests or hide changed rules.

## Original execution gate (resolved)

Installed astra-flash-orchestrator requires verified GPT-6 Astra root before
delegation. Static doctor reports root alias opencode-go-messages/union-alpha,
runtime_verified=false; no evidence mapping alias to Astra was established.
User explicitly authorized direct implementation in the following turn. No worker
was dispatched and no provider settings were changed.
