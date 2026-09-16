## demo_audit.gd — the ported `scripts/demo-audit.mjs`, promise for promise.
##
##   flock -w 900 /tmp/padel-godot.lock timeout 300 env -u DISPLAY \
##     GODOT_SILENCE_ROOT_WARNING=1 /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 \
##     --headless --path godot/ res://tests/build/demo_audit.tscn
##
## and, for the demo's half of every answer, the same command with `-- --demo`.
##
## The reference audit verifies the *declared content*, not the detection
## (`scripts/demo-audit.mjs:6-7`: "si verifica il contenuto dichiarato, non il
## rilevamento: quello dipende dal contesto"). It can only do that because
## `IS_DEMO` is false under Node. The port can do better, so it does: the file is
## run twice, once as a full build and once as a demo build, and the two answers
## the reference insists on keeping apart (`demoFilter`, `demoLocked`) are
## asserted separately in each.
##
## Promises carried over, with the reference line each comes from:
##
##   :10-15  the demo's athletes and arenas resolve from the real tables
##   :21     no demo item carries an `unlock` — nothing offered is itself locked
##   :30     the two demo athletes differ by at least 0.25 on control AND power
##   :40     every balance key the fixed difficulty needs exists
##   :44-46  modes is exactly ["quick"], difficulty exactly "medium"
##   :49-51  demoFilter is a no-op with the flag off and reduces with it on
##   :62-65  at least one athlete and one arena are excluded
##   :71     demoLocked equals the demo flag for everything outside the allowed set
##   :74     every demo athlete is unlocked
##   :83-90  `outfitChallenges: true` and the demo athletes really have challenges
##
## One promise is strengthened because the ticket asks for it: the demo's two
## athletes must be the roster's extremes, not any two. The reference proves only
## the separation number; this proves, from the frozen tables, that the pair the
## demo grants is the pair that maximises the control+power separation among the
## athletes the demo could grant (the ones with no `unlock` to buy) — the locked
## ones are the full game's extremes and cannot be the demo's.
extends "res://tests/build/TestHarness.gd"

const BuildFlag := preload("res://tests/build/BuildFlag.gd")
const DemoContent := preload("res://tests/build/DemoContent.gd")
const ContentFilter := preload("res://tests/build/ContentFilter.gd")
const Frozen := preload("res://src/sim/frozen.gd")


func _ready() -> void:
	var demo := BuildFlag.is_demo()
	print("# demo_audit — build=%s (demo feature tag: %s)" % [BuildFlag.label(), OS.has_feature("demo")])

	var roster: Array = Frozen.athletes()
	var arenas: Array = Frozen.arenas()
	var demo_athlete_ids: Array = DemoContent.allowed_athlete_ids()
	var demo_arena_ids: Array = DemoContent.allowed_arena_ids()

	# --- the declared content resolves from the real tables (:10-15) ----------
	var demo_athletes := _by_id(roster, demo_athlete_ids)
	var demo_arenas := _by_id(arenas, demo_arena_ids)
	check_eq(demo_athletes.size(), demo_athlete_ids.size(), "every declared demo athlete exists in ATHLETES")
	check_eq(demo_arenas.size(), demo_arena_ids.size(), "every declared demo arena exists in ARENAS")
	check_eq(demo_athlete_ids.size(), 2, "the demo declares exactly two athletes")
	check_eq(demo_arena_ids.size(), 1, "the demo declares exactly one arena")

	# --- nothing offered by the demo is itself locked (:21) -------------------
	for athlete in demo_athletes:
		check_false(athlete.has("unlock"), "demo athlete carries no unlock: %s" % athlete.get("id", "?"))
	for arena in demo_arenas:
		check_false(arena.has("unlock"), "demo arena carries no unlock: %s" % arena.get("id", "?"))

	# --- the two athletes are opposed (:30), and are the eligible extremes ----
	var pair_control: float = absf(float(demo_athletes[0].stats.control) - float(demo_athletes[1].stats.control))
	var pair_power: float = absf(float(demo_athletes[0].stats.power) - float(demo_athletes[1].stats.power))
	check_at_least(pair_control, 0.25, "demo athletes differ on control")
	check_at_least(pair_power, 0.25, "demo athletes differ on power")

	var eligible := _without_unlock(roster)
	var best := _widest_pair(eligible)
	var granted := [str(demo_athletes[0].id), str(demo_athletes[1].id)]
	granted.sort()
	var widest: Array = [str(best[0]), str(best[1])]
	widest.sort()
	check_eq(granted, widest, "the demo grants the widest control+power pair among athletes it could grant")
	check_eq(str(_max_by(eligible, "control").id), str(demo_athletes[0].id), "the demo's first athlete is the eligible control extreme")
	check_eq(str(_max_by(eligible, "power").id), str(demo_athletes[1].id), "the demo's second athlete is the eligible power extreme")

	# --- the shot repertoire is kept whole (:33-42) --------------------------
	var shots := [
		"smashMinHeight", "smashX2MinQuality", "smashX3MinQuality",
		"cutVolleyMinQuality", "globoMinQuality", "tightAngleReachGain",
		"viboraNetWindow",
	]
	for key in shots:
		check_true(Frozen.has_bal(key), "balance key the demo's difficulty needs exists: %s" % key)

	# --- modes and difficulty are fixed (:44-47) -----------------------------
	check_eq(DemoContent.allowed_mode_ids(), ["quick"], "the demo exposes only the quick match mode")
	check_eq(DemoContent.difficulty(), "medium", "the demo runs the fixed medium difficulty")
	check_eq(DemoContent.all_mode_ids(), ["quick", "tournament", "career"], "the reference menu's full mode set is known")

	# --- filter: no-op off, reduces on (:49-51) ------------------------------
	if demo:
		check_eq(ContentFilter.roster().size(), 2, "demo filter reduces the roster to the granted athletes")
		check_eq(ContentFilter.arenas().size(), 1, "demo filter reduces the arenas to the granted arena")
		check_eq(ContentFilter.mode_ids(), ["quick"], "demo filter reduces the modes to quick match")
		check_eq(ContentFilter.roster().size() < roster.size(), true, "the demo filter is not a no-op")
	else:
		check_eq(ContentFilter.filter(roster, demo_athlete_ids), roster, "full build: the filter is a no-op on the roster")
		check_eq(ContentFilter.filter(arenas, demo_arena_ids), arenas, "full build: the filter is a no-op on the arenas")
		check_eq(ContentFilter.mode_ids(), ["quick", "tournament", "career"], "full build: every mode is listed")

	# --- something is excluded, or there is nothing to sell (:62-66) ---------
	var outside_athletes := _outside(roster, demo_athlete_ids)
	var outside_arenas := _outside(arenas, demo_arena_ids)
	check_eq(outside_athletes.size() > 0, true, "at least one athlete is outside the demo (%d)" % outside_athletes.size())
	check_eq(outside_arenas.size() > 0, true, "at least one arena is outside the demo (%d)" % outside_arenas.size())

	# --- the lock answer is the demo flag, per item (:71-77) ------------------
	for athlete in outside_athletes:
		check_eq(ContentFilter.is_locked(athlete, demo_athlete_ids), demo, "lock answer outside the set equals the demo flag: %s" % athlete.id)
	for athlete in demo_athletes:
		check_false(ContentFilter.is_locked(athlete, demo_athlete_ids), "a granted athlete is never locked: %s" % athlete.id)
	for arena in outside_arenas:
		check_eq(ContentFilter.is_locked(arena, demo_arena_ids), demo, "lock answer outside the set equals the demo flag: %s" % arena.id)
	for arena in demo_arenas:
		check_false(ContentFilter.is_locked(arena, demo_arena_ids), "a granted arena is never locked: %s" % arena.id)

	# --- the demo's only earned reward stays reachable (:79-90) --------------
	check_eq(DemoContent.outfit_challenges_enabled(), true, "the demo declares that outfit challenges count here")
	check_at_least(float(DemoContent.demo_outfit_challenge_count()), 6.0, "challenge outfits the demo grants")
	for id in demo_athlete_ids:
		check_true(int(DemoContent.outfit_challenges().get(id, 0)) > 0, "demo athlete has challenge outfits: %s" % id)

	finish()


static func _by_id(list: Array, ids: Array) -> Array:
	var out: Array = []
	for item in list:
		if ids.has(item.get("id", "")):
			out.append(item)
	return out


static func _outside(list: Array, ids: Array) -> Array:
	var out: Array = []
	for item in list:
		if not ids.has(item.get("id", "")):
			out.append(item)
	return out


static func _without_unlock(list: Array) -> Array:
	var out: Array = []
	for item in list:
		if not item.has("unlock"):
			out.append(item)
	return out


## The pair that maximises |Δcontrol| + |Δpower|. The demo's whole reason for
## having two athletes is that they play differently, so the extremes are the
## right pair to grant — computed, not asserted by name.
static func _widest_pair(list: Array) -> Array:
	var best: Array = []
	var best_sum := -1.0
	for i in list.size():
		for j in range(i + 1, list.size()):
			var s: float = absf(float(list[i].stats.control) - float(list[j].stats.control)) \
				+ absf(float(list[i].stats.power) - float(list[j].stats.power))
			if s > best_sum:
				best_sum = s
				best = [str(list[i].id), str(list[j].id)]
	return best


static func _max_by(list: Array, stat: String) -> Dictionary:
	var best: Dictionary = {}
	for item in list:
		if best.is_empty() or float(item.stats[stat]) > float(best.stats[stat]):
			best = item
	return best
