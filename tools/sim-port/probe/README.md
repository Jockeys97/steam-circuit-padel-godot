# probe/ — throwaway instrumentation used to find the tick-2207 divergence

Diagnostics only. **Nothing here is part of the port or of the frozen reference.**

`js/` is a byte-for-byte copy of the repository's `js/` tree with three
`globalThis.__SCP_DBG`-gated `console.error` hooks inserted into `js/game.js`:

* `chooseComputerShot` — prints `kind`, `baseX`, `sideBias`, `ampiezza`,
  `accuracyError`, `skill`, `coverageX` for every call;
* `applyComputerShot` — prints the post-jitter `target.x` / `target.y`,
  `executionSpread`, `assessment.risk`, `assessment.quality`, the contact ball
  position and `flightTime`;
* `evaluateShotQuality` — prints every component of the assessment
  (`timing`, `position`, `balance`, `height`, `energy`, `control`, `split`,
  `quality`, `risk`, `aggression`, `moveRatio`, `motion`) for overhead variants.

`digest_dbg.mjs` is a copy of `scripts/parity-digest.mjs` pointing at that copy
and tagging each hook line with the tick.

The copy exists because the real `js/**` is the specification and is
read-only by rule: instrumenting the reference in place is not allowed, and a
copy with added `console.error` calls cannot change any simulated number
(nothing reads stderr).

The Godot half of the instrumentation was a temporary `OS.get_environment("SCP_SIM_DBG")`-gated
`print` in `godot/src/sim/sim.gd` (same three sites). It was removed before the
fix was applied; the captured output is in
`tools/sim-port/out/probe-logs/gd-*.out`.

Reproduce:

```sh
cd tools/sim-port/probe
node digest_dbg.mjs --seed=2024 --ticks=2215 --every=2215 --quiet >/dev/null 2>js.err
grep DBGEVAL js.err
```

Raw captures: `tools/sim-port/out/probe-logs/`.
