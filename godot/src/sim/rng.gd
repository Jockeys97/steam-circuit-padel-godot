## rng.gd — the bit-exact port of `nextRandom` (`js/game.js:22-28`).
##
## The JavaScript is a mulberry32-style 32-bit generator:
##
##     a = (state.rngState + 0x6D2B79F5) | 0     state.rngState = a
##     t = Math.imul(a ^ (a >>> 15), 1 | a)
##     t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
##     return ((t ^ (t >>> 14)) >>> 0) / 4294967296
##
## GDScript has 64-bit integers and no `Math.imul`, so every operation that can
## leave the 32-bit range is masked explicitly (`simulation-port-boundary.md` §4):
##
##   - `i32(x)` is the signed 32-bit view, applied after every `+` and after every
##     multiply (that is what `Math.imul` is: a signed 32-bit multiply).
##   - JS `>>>` is a *logical* shift of the uint32 view; `(x & 0xFFFFFFFF) >> n`
##     is the same thing (the operand is non-negative, so GDScript's `>>` is
##     logical there). The intermediate is always < 2**31 for the shift amounts
##     used here, so a following `^` keeps the sign bit of the int32 value, which
##     is exactly what JS `^` does after `ToInt32`.
##   - JS `>>` (arithmetic) is not used in this generator.
##
## The returned value is an exact `uint32 / 2**32`, so the stream is
## bit-comparable across engines — the strongest parity signal available.
extends RefCounted

const RNG_CALL_CAP := 1000000

## Signed 32-bit view of a 64-bit integer.
static func i32(x: int) -> int:
	return ((x & 0xFFFFFFFF) ^ 0x80000000) - 0x80000000

## `Math.imul`: low 32 bits of the product, interpreted as a signed int32.
##
## The naive `(a & 0xFFFFFFFF) * (b & 0xFFFFFFFF)` overflows a 64-bit int (two
## 32-bit factors give a 64-bit product that can reach 2**64-1, past INT64_MAX),
## so the product is built from 16-bit halves:
##   a*b = (ah*2**16 + al)(bh*2**16 + bl); the ah*bh term is a multiple of 2**32
##   and drops; the two cross terms only contribute their low 16 bits.
static func imul(a: int, b: int) -> int:
	var al := a & 0xFFFF
	var ah := (a >> 16) & 0xFFFF
	var bl := b & 0xFFFF
	var bh := (b >> 16) & 0xFFFF
	var low := al * bl
	var cross := (ah * bl + al * bh) & 0xFFFF
	return i32((low + (cross << 16)) & 0xFFFFFFFF)

## Advance `state.rng_state` by one step and return the [0,1) draw.
## Also bumps `state.rng_calls`, the real counter the parity ticket asks for
## (`simulation-port-boundary.md` §6) — the JavaScript side can only reconstruct
## this count, so a genuine counter on this side is what tests the reconstruction.
static func next_random(state) -> float:
	var a := i32(state.rng_state + 0x6D2B79F5)
	state.rng_state = a
	var t := imul(a ^ ((a & 0xFFFFFFFF) >> 15), 1 | a)
	t = i32(i32(t + imul(t ^ ((t & 0xFFFFFFFF) >> 7), 61 | t)) ^ t)
	state.rng_calls += 1
	var u := (t ^ ((t & 0xFFFFFFFF) >> 14)) & 0xFFFFFFFF
	return float(u) / 4294967296.0

## `rngAdvance` from `scripts/parity-digest.mjs:137-142`: the state-only step,
## used to reconstruct how many calls happened between two samples.
static func advance(state_value: int) -> int:
	var next := i32(state_value + 0x6D2B79F5)
	var t := imul(next ^ ((next & 0xFFFFFFFF) >> 15), 1 | next)
	t = i32(i32(t + imul(t ^ ((t & 0xFFFFFFFF) >> 7), 61 | t)) ^ t)
	return next

## `countRngCalls` (`scripts/parity-digest.mjs:146-154`): exact, exhaustive replay
## from one state to the next. Returns -1 if `to` is not reachable within the cap,
## which means something wrote `rngState` outside `nextRandom`.
static func count_calls(from: int, to: int) -> int:
	if from == to:
		return 0
	var cursor := from
	for calls in range(1, RNG_CALL_CAP + 1):
		cursor = advance(cursor)
		if cursor == to:
			return calls
	return -1
