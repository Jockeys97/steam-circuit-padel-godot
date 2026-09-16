## drill_seed.gd — the seeded generator the drill's target placement draws from.
##
## THE DEFECT THIS REPLACES (recorded, not fixed in the reference):
##
##   `js/drill.js:149-162` places the target with global `Math.random` —
##   `js/drill.js:155` for `x`, `:159` and `:160` for `y` (one of the two `y`
##   lines runs, both draw). `js/drill.js` never calls `nextRandom`, the engine's
##   seeded generator: at the frozen commit, `grep -c 'nextRandom(' js/drill.js`
##   is 0, and the three `Math.random` hits are the only randomness in the file.
##   A drill run in the browser is therefore unreproducible, and its digests are
##   NOT comparable with the port's — this lane may not edit `js/**`, so that
##   stays a finding rather than a fix.
##
## The port draws from an explicitly injected seed instead, through the same
## mulberry32 the simulation uses (`godot/src/sim/rng.gd`, a bit-exact port of
## `nextRandom`, `js/game.js:22-28`). Same seed => same target positions and the
## same sequence of attempts, provable in two runs (`godot/tests/modes/
## drill_audit.gd`, the determinism section). The port's stream is deliberately
## NOT aligned with the reference's patched `Math.random` draws: the reference
## consumes its stream for the engine's `rngState` and the placement together,
## the port injects the two separately, so the two sequences diverge even for the
## same seed. That is the honest consequence of the reference's defect, and no
## test here claims cross-engine drill digests.
##
## API:
##
##   var gen := DrillSeed.from_seed(4242)
##   gen.draw() -> float          one draw in [0, 1), mulberry32's own scale
##   gen.state -> int             the generator's current state (for evidence)
##
## `draw()` is the exact arithmetic of `Rng.next_random` without a `SimState` to
## hang the counter on — the drill's placement is not part of the simulation's
## rng stream and must not be, or the two owners of randomness would be one.
extends RefCounted

const Rng := preload("res://src/sim/rng.gd")

var state: int = 0
var calls: int = 0


## `from_seed(seed)`: the generator opens on the seed itself, the same
## convention `AuditSupport.inject_seed` gives the engine's `rngState`
## (`state.rng_state = seed`).
static func from_seed(seed_value: int) -> RefCounted:
	var gen := new()
	gen.state = Rng.i32(seed_value)
	return gen


## One mulberry32 draw, `Rng.next_random`'s arithmetic on this generator's own
## state.
func draw() -> float:
	var a := Rng.i32(state + 0x6D2B79F5)
	state = a
	var t := Rng.imul(a ^ ((a & 0xFFFFFFFF) >> 15), 1 | a)
	t = Rng.i32(Rng.i32(t + Rng.imul(t ^ ((t & 0xFFFFFFFF) >> 7), 61 | t)) ^ t)
	calls += 1
	var u := (t ^ ((t & 0xFFFFFFFF) >> 14)) & 0xFFFFFFFF
	return float(u) / 4294967296.0
