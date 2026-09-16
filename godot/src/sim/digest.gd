## digest.gd — the Godot side of the parity digest: the same field order, the
## same numeric formatting and the same sha256 shape as
## `scripts/parity-digest.mjs` (read-only reference; the shapes below are copied
## from `sampleState` / `digestLine` / the summary at lines 166-229 and 269-326).
##
## Formatting rules that matter for byte-stability:
##   - every float goes through `fixed()` = `%.6f`, and a negative zero is
##     printed as `0.000000` because that is what JavaScript's `toFixed` does;
##   - ints are printed as ints (`rngState`, `rngCalls`, the score counters);
##   - `tick` is zero-padded to six digits.
##
## `digestSha256` is the sha256 of the digest lines joined by "\n" **plus a
## trailing "\n"** — identical construction to the JavaScript tool, so the two
## hashes are directly comparable.
extends RefCounted

const Rng := preload("res://src/sim/rng.gd")


static func fixed(value: float) -> String:
	if not is_finite(value):
		if is_nan(value):
			return "NaN"
		return "Infinity" if value > 0.0 else "-Infinity"
	if value == 0.0:
		# JavaScript `(-0).toFixed(6)` is "0.000000"; GDScript's "%.6f" would
		# print "-0.000000".
		return "0.000000"
	return "%.6f" % value


static func point(x: float, y: float) -> String:
	return "(%s,%s)" % [fixed(x), fixed(y)]


static func vector(x: float, y: float, z: float) -> String:
	return "(%s,%s,%s)" % [fixed(x), fixed(y), fixed(z)]


## `sampleState` (`scripts/parity-digest.mjs:166-201`).
static func sample_state(state, tick: int, rng_calls: int) -> Dictionary:
	var ball = state.ball
	return {
		"tick": tick,
		"rngState": state.rng_state,
		"rngCalls": rng_calls,
		"ball": {
			"x": ball.x, "y": ball.y, "z": ball.z,
			"vx": ball.vx, "vy": ball.vy, "vz": ball.vz,
			"spin": ball.spin,
			"shotType": ball.shotType,
			"smashStage": ball.smashStage,
			"bounces": {"player": int(ball.bounces["player"]), "ai": int(ball.bounces["ai"])},
		},
		"paddles": {
			"player": {"x": state.player.x, "y": state.player.y},
			"playerMate": {"x": state.playerMate.x, "y": state.playerMate.y},
			"opponent": {"x": state.opponent.x, "y": state.opponent.y},
			"opponentMate": {"x": state.opponentMate.x, "y": state.opponentMate.y},
		},
		"score": {
			"points": "%d-%d" % [int(state.points["player"]), int(state.points["ai"])],
			"games": "%d-%d" % [int(state.games["player"]), int(state.games["ai"])],
			"sets": "%d-%d" % [int(state.sets["player"]), int(state.sets["ai"])],
			"playerScore": state.playerScore,
			"aiScore": state.aiScore,
			"pointsWon": "%d-%d" % [int(state.stats["pointsWon"]["player"]), int(state.stats["pointsWon"]["ai"])],
			"rallyHits": state.rallyHits,
			"serveAttempts": state.serveAttempts,
			"longestRally": int(state.stats["longestRally"]),
		},
	}


## `digestLine` (`scripts/parity-digest.mjs:203-229`): identical field order.
static func digest_line(sample: Dictionary) -> String:
	var ball: Dictionary = sample["ball"]
	var paddles: Dictionary = sample["paddles"]
	var score: Dictionary = sample["score"]
	var parts: Array = [
		"tick=%06d" % int(sample["tick"]),
		"rngState=%d" % int(sample["rngState"]),
		"rngCalls=%d" % int(sample["rngCalls"]),
		"ball=%s" % vector(ball["x"], ball["y"], ball["z"]),
		"v=%s" % vector(ball["vx"], ball["vy"], ball["vz"]),
		"spin=%s" % fixed(ball["spin"]),
		"bounces=%d/%d" % [int(ball["bounces"]["player"]), int(ball["bounces"]["ai"])],
		"shotType=%s" % String(ball["shotType"]),
		"smashStage=%d" % int(ball["smashStage"]),
		"player=%s" % point(paddles["player"]["x"], paddles["player"]["y"]),
		"playerMate=%s" % point(paddles["playerMate"]["x"], paddles["playerMate"]["y"]),
		"opponent=%s" % point(paddles["opponent"]["x"], paddles["opponent"]["y"]),
		"opponentMate=%s" % point(paddles["opponentMate"]["x"], paddles["opponentMate"]["y"]),
		"points=%s" % String(score["points"]),
		"games=%s" % String(score["games"]),
		"sets=%s" % String(score["sets"]),
		"playerScore=%s" % String(score["playerScore"]),
		"aiScore=%s" % String(score["aiScore"]),
		"pointsWon=%s" % String(score["pointsWon"]),
		"rallyHits=%s" % str(int(score["rallyHits"])),
		"serveAttempts=%s" % str(int(score["serveAttempts"])),
		"longestRally=%s" % str(int(score["longestRally"])),
	]
	return " ".join(parts)


static func sha256_of_lines(lines: Array) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(("%s\n" % "\n".join(lines)).to_utf8_buffer())
	return context.finish().hex_encode()
