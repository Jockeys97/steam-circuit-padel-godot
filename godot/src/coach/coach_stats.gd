## coach_stats.gd — the coach's snapshot: what this match actually measured.
##
## THE ONLY DOOR FROM A RESULT TO THE COACH. It reads `result.stats` — the same
## dictionary the result screen already renders (`godot/src/ui/data/UiData.gd::result_view`)
## and the ported simulation itself increments (`godot/src/sim/sim.gd:1972-1987`) — and
## copies the declared allowlist out of it. Nothing is inferred: a counter the match did
## not measure (shot placement, court position, why an error happened) has no name here
## and cannot reach the bridge.
##
## THE PLAYER'S NUMBERS ARE THE SIDE'S NUMBERS. `player` is the aggregate of both humans
## on that side of the court, which is what the game's own characters copy already tells
## the player. The coach therefore treats `player` as "your side", and a comparison
## between `player` and `ai` as a comparison between two sides — never as one
## individual's personal count.
##
## WHAT THIS MODULE DECIDES. Only whether the match measured enough to ask about, and
## which declared categories have any of their own evidence present. That second rule is
## deliberately weak — "this focus has numbers behind it at all", not "this focus wins":
## choosing the focus is the model's judgment, and a candidate set narrowed to one real
## option would turn a judgment into a coin toss.
##
## `averageRally` carries the result screen's own formula (`js/ui.js:1394-1396`:
## `rallyCount ? (totalHits / rallyCount).toFixed(1) : "0"`), so the coach quotes the
## same average the player just read two rows above.
extends RefCounted

const Contract := preload("res://src/coach/coach_contract.gd")

## The serve needs at least this many measured serve outcomes on your side (aces plus
## double faults) before the serve can be a focus.
const MIN_SERVE_EVIDENCE := 2

## Finishing and shot accuracy both need point-ending events to look at. Winners and errors
## are the measured endings; smash winners are NOT added to them: a smash that wins the
## point is already a winner, and a smash the opponent fails to return is a smash winner
## with no winner (`godot/src/sim/sim.gd:2406-2413`), so a sum would double-count the
## overlap.
const MIN_FINISH_EVIDENCE := 3
const MIN_SHOT_EVIDENCE := 3

## The points a side must have won before a winners-to-points-won ratio is worth reading.
const MIN_POINTS_WON := 3

## The return focus needs the OPPONENT's own aces to be worth reading: an ace is a serve
## this side did not return, so the count is direct evidence — but one or two is a normal
## part of any match, and advising "train your return" off a single ace would be reading a
## coincidence as a pattern. The floor is deliberately conservative and explicit; two
## aces alone leave the focus unoffered.
const MIN_OPPONENT_ACES := 3


## The snapshot of one result payload. `problems` is audit-facing, never player-facing:
## it names a counter the payload could not have carried so a test can prove the
## adapter refuses to advise on a malformed match.
static func snapshot(result: Dictionary) -> Dictionary:
	var raw: Variant = result.get("stats", {})
	var stats: Dictionary = raw if raw is Dictionary else {}
	var max_value := Contract.max_value()
	var problems: Array[String] = []
	# `problems` is the audit trail (anything the payload could not have carried);
	# `blockers` is the subset that stops the coach advising at all. An unknown counter is
	# ignored and recorded, not blocking: a future build may measure more than this coach
	# knows about, and refusing to advise on that account would look like the coach quietly
	# broke. A counter that is negative, fractional, textual or over the declared bound is
	# a different thing — the match cannot have written it — and it blocks.
	var blockers: Array[String] = []
	var counters := {}
	for group in Contract.group_names():
		var pair_raw: Variant = stats.get(group)
		var sides := {}
		for side in Contract.group_sides(group):
			var path := "%s.%s" % [group, side]
			if not (pair_raw is Dictionary):
				# A group that is absent, or not an object, is not a side that measured zero.
				problems.append("malformed:" + String(group))
				blockers.append("malformed:" + String(group))
				sides[side] = 0
				continue
			var pair: Dictionary = pair_raw
			sides[side] = _count(pair.get(side), max_value, path, pair.has(side), problems, blockers)
		counters[group] = sides
	for name in Contract.counter_names():
		counters[name] = _count(stats.get(name), max_value, name, stats.has(name), problems, blockers)
	for key in stats.keys():
		if not counters.has(String(key)):
			problems.append("ignored:" + String(key))

	var sides_won: Variant = counters.get("pointsWon", {})
	var points_played := 0
	if sides_won is Dictionary:
		points_played = int((sides_won as Dictionary).get("player", 0)) + int((sides_won as Dictionary).get("ai", 0))
	var rallies := int(counters.get("rallyCount", 0))
	var average_rally := 0.0
	if rallies != 0:
		average_rally = float(int(counters.get("totalRallyHits", 0))) / float(rallies)

	var out := {
		"counters": counters,
		"problems": problems,
		"blockers": blockers,
		"pointsPlayed": points_played,
		"averageRally": average_rally,
	}
	var floors := Contract.sufficiency()
	var measured_enough := (
		blockers.is_empty()
		and points_played >= int(floors.get("minPointsPlayed", 8))
		and rallies >= int(floors.get("minRallies", 6))
	)
	var candidates: Array[String] = []
	if measured_enough:
		for category_id in Contract.drill_categories():
			if supported(category_id, out):
				candidates.append(category_id)
		# `minCandidates` counts DRILLABLE categories, exactly as the contract's note says;
		# `insufficient_data` is appended afterwards and is not one of them.
		if candidates.size() < int(floors.get("minCandidates", 2)):
			candidates.clear()
	out["drillCandidates"] = candidates.duplicate()
	candidates.append(Contract.INSUFFICIENT)
	out["candidates"] = candidates
	out["sufficient"] = measured_enough and candidates.size() > 1
	return out


## True when this category's own evidence is present in the counters: the measured
## events a focus would be about have happened at least a few times.
static func supported(category_id: String, snapshot_in: Dictionary) -> bool:
	var points_floor := int(Contract.sufficiency().get("minPointsPlayed", 8))
	var rallies_floor := int(Contract.sufficiency().get("minRallies", 6))
	var counters: Dictionary = snapshot_in.get("counters", {})
	match category_id:
		"serve_accuracy":
			return player_count(snapshot_in, "aces") + player_count(snapshot_in, "doubleFaults") >= MIN_SERVE_EVIDENCE
		"serve_return":
			# Only the opponent's aces: `aces.ai` is the measured count of serves the human
			# side never returned. Nothing else in this build measures a return.
			return opponent_count(snapshot_in, "aces") >= MIN_OPPONENT_ACES
		"net_finishing":
			var endings := player_count(snapshot_in, "winners") + player_count(snapshot_in, "errors")
			return (
				int(snapshot_in.get("pointsPlayed", 0)) >= points_floor
				and player_count(snapshot_in, "pointsWon") >= MIN_POINTS_WON
				and endings >= MIN_FINISH_EVIDENCE
			)
		"shot_accuracy":
			return player_count(snapshot_in, "errors") + player_count(snapshot_in, "winners") >= MIN_SHOT_EVIDENCE
		"rally_consistency":
			return int(counters.get("rallyCount", 0)) >= rallies_floor
	return false


## Your side's count for one measured group.
static func player_count(snapshot_in: Dictionary, group: String) -> int:
	var counters: Dictionary = snapshot_in.get("counters", {})
	var sides: Variant = counters.get(group, {})
	if not (sides is Dictionary):
		return 0
	return int((sides as Dictionary).get("player", 0))


## The rival side's count for one measured group. The coach compares the two sides (the
## criteria do), so both sides are readable by name.
static func opponent_count(snapshot_in: Dictionary, group: String) -> int:
	var counters: Dictionary = snapshot_in.get("counters", {})
	var sides: Variant = counters.get(group, {})
	if not (sides is Dictionary):
		return 0
	return int((sides as Dictionary).get("ai", 0))


## One measured counter, bounded and normalized. A counter the payload does not carry at
## all, or one the simulation cannot have written (text, a negative, a fraction,
## infinity), is named in `problems` and read as zero, and it also lands in `blockers`: the
## adapter must never hand the bridge a payload the bridge would reject, and a match that
## did not carry a declared counter is NOT a match that measured zero of it — the sim
## writes every declared one (`godot/src/sim/sim.gd:2397-2417`).
static func _count(value: Variant, max_value: int, path: String, present: bool, problems: Array[String], blockers: Array[String]) -> int:
	if not present or value == null:
		problems.append("missing:" + path)
		blockers.append("missing:" + path)
		return 0
	if value is bool or not (value is int or value is float):
		problems.append("malformed:" + path)
		blockers.append("malformed:" + path)
		return 0
	var number := float(value)
	if not is_finite(number):
		problems.append("malformed:" + path)
		blockers.append("malformed:" + path)
		return 0
	if number < 0.0:
		problems.append("negative:" + path)
		blockers.append("negative:" + path)
		return 0
	if number != floor(number):
		problems.append("fractional:" + path)
		blockers.append("fractional:" + path)
		return 0
	if number > float(max_value):
		problems.append("clamped:" + path)
		blockers.append("clamped:" + path)
		return max_value
	return int(number)
