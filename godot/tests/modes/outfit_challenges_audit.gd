## outfit_challenges_audit.gd — the port of `scripts/outfit-challenges-audit.mjs`.
##
##   flock -w 900 /tmp/padel-godot.lock timeout 300 env -u DISPLAY \
##     GODOT_SILENCE_ROOT_WARNING=1 /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 \
##     --headless --path godot/ --script res://tests/modes/outfit_challenges_audit.gd
##
## The reference audit asserts that the 20 unlockable outfits can be WON, and that
## winning one means something (`scripts/outfit-challenges-audit.mjs:12-26`):
##
##   `:34`      at least twenty outfits carry a challenge;
##   `:39-41`   no outfit is still behind the old stars/trophies wall;
##   `:43-46`   the unlock keys are unique — `circuit` exists for every athlete, so
##              without the `athlete:id` prefix one win would unlock them all;
##   `:50-63`   every challenge derived from the points is winnable inside a match
##              of `CAREER_POINTS_TO_WIN`, and every `at most` ceiling is below the
##              reachable maximum (a ceiling at the cap is a gift, not a challenge);
##   `:65-69`   no two outfits share the exact same trial;
##   `:71-79`   an athlete with three or more outfits asks for at least two
##              different metrics;
##   `:81-97`   inside one athlete the difficulty strictly grows along the ladder
##              `circuit < legend < signature < mythic`;
##   `:99-106`  the first rung demands neither a win nor a minimum difficulty;
##   `:121-130` the evaluator: a perfect match against the Legend wins every
##              challenge, an empty lost match wins none;
##   `:132-139` `isUnlocked` reads the won challenge, not the wallet.
##
## NOT PORTED, and reported as such: `:145-148` reads the TEXT of `js/ui.js` with a
## regex to prove no presentation filter still selects outfits by `unlock`. The
## port's presentation scripts do not exist yet (the UI lane owns them), and
## reading `js/ui.js` would be checking the reference rather than the port, so the
## check has no subject here and is printed as `# not-ported` instead of passing
## silently.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const CareerRules := preload("res://src/modes/career_rules.gd")
const Tables := preload("res://src/modes/mode_tables.gd")

## `const CAP = CAREER_POINTS_TO_WIN` (`scripts/outfit-challenges-audit.mjs:28`).
const DERIVED_FROM_POINTS := ["winners", "smashWinners", "errors", "doubleFaults"]
const LADDER := ["circuit", "legend", "signature", "mythic"]


func _initialize() -> void:
	var audit := AuditBase.new("outfit_challenges")
	run(audit)
	quit(audit.finish())


static func run(audit: AuditBase) -> void:
	var cap: int = CareerRules.career_points_to_win()
	var outfits := all_outfits()
	var with_challenge: Array = []
	for outfit in outfits:
		if outfit.get("challenge") != null:
			with_challenge.append(outfit)

	audit.check_ge(with_challenge.size(), 20, "outfit_challenges/at_least_twenty_outfits_carry_a_challenge")

	# Nessun completo deve restare dietro al vecchio muro di stelle e trofei.
	var behind_the_wall: Array = []
	for outfit in outfits:
		if outfit.get("unlock") != null and String(outfit["id"]) != "base":
			behind_the_wall.append(String(outfit["unlockKey"]))
	audit.check_eq(behind_the_wall.size(), 0, "outfit_challenges/no_outfit_behind_stars_or_trophies")

	# La chiave deve essere unica.
	var keys: Array = []
	for outfit in with_challenge:
		keys.append(String(outfit["unlockKey"]))
	audit.check_eq(_distinct(keys).size(), keys.size(), "outfit_challenges/unlock_keys_are_unique")

	# Ogni prova derivata dai punti deve essere vincibile, e ogni tetto fallibile.
	for outfit in with_challenge:
		for prova in _prove(outfit["challenge"]):
			var metric := String(prova["metric"])
			if not DERIVED_FROM_POINTS.has(metric):
				continue
			var label := "%s/%s" % [String(outfit["unlockKey"]), metric]
			if bool(prova.get("atMost", false)):
				audit.check_lt(
					int(prova["target"]), cap,
					"outfit_challenges/%s/at_most_%d_is_fallible" % [label, int(prova["target"])],
				)
			else:
				audit.check_le(
					int(prova["target"]), cap,
					"outfit_challenges/%s/at_least_%d_is_reachable" % [label, int(prova["target"])],
				)

	# Ogni sfida deve essere distinta.
	var signatures: Array = []
	for outfit in with_challenge:
		signatures.append(JSON.stringify(outfit["challenge"]))
	audit.check_eq(_distinct(signatures).size(), signatures.size(), "outfit_challenges/no_two_outfits_share_a_challenge")

	# Ogni atleta con quattro completi deve chiedere almeno due cose diverse.
	for athlete_id in Tables.outfits():
		var challenges: Array = []
		for outfit in Tables.outfits_for_athlete(String(athlete_id)):
			if outfit.get("challenge") != null:
				challenges.append(outfit)
		if challenges.size() < 3:
			continue
		var metrics: Dictionary = {}
		for outfit in challenges:
			for prova in _prove(outfit["challenge"]):
				metrics[String(prova["metric"])] = true
		audit.check_ge(
			metrics.size(), 2,
			"outfit_challenges/%s/asks_for_at_least_two_metrics" % String(athlete_id),
		)

	# Dentro un atleta la difficolta' deve crescere.
	for athlete_id in Tables.outfits():
		var ladder: Array = []
		for id in LADDER:
			for outfit in Tables.outfits_for_athlete(String(athlete_id)):
				if String(outfit["id"]) == String(id) and outfit.get("challenge") != null:
					ladder.append(outfit)
		for i in range(1, ladder.size()):
			var harder := _weight(ladder[i]["challenge"], cap)
			var easier := _weight(ladder[i - 1]["challenge"], cap)
			audit.check_gt(
				harder, easier,
				"outfit_challenges/%s/%s_is_harder_than_%s" % [
					String(athlete_id), String(ladder[i]["id"]), String(ladder[i - 1]["id"]),
				],
			)

	# Il primo gradino deve essere alla portata di chi apre il gioco.
	for athlete_id in Tables.outfits():
		for outfit in Tables.outfits_for_athlete(String(athlete_id)):
			if String(outfit["id"]) != "circuit" or outfit.get("challenge") == null:
				continue
			var challenge: Dictionary = outfit["challenge"]
			audit.check_true(not bool(challenge.get("win", false)), "outfit_challenges/%s/first_rung_needs_no_win" % String(athlete_id))
			audit.check_true(challenge.get("minSkill") == null, "outfit_challenges/%s/first_rung_needs_no_difficulty" % String(athlete_id))

	# --- la macchina che valuta ----------------------------------------------
	var full_stats := {
		"pointsWon": {"player": 11, "ai": 2}, "winners": {"player": 10, "ai": 0},
		"errors": {"player": 0, "ai": 0}, "smashWinners": {"player": 10, "ai": 0},
		"doubleFaults": {"player": 0, "ai": 0}, "longestRally": 40, "totalRallyHits": 300,
	}
	var empty_stats := {
		"pointsWon": {"player": 0, "ai": 11}, "winners": {"player": 0, "ai": 0},
		"errors": {"player": 11, "ai": 0}, "smashWinners": {"player": 0, "ai": 0},
		"doubleFaults": {"player": 6, "ai": 0}, "longestRally": 1, "totalRallyHits": 12,
	}
	for outfit in with_challenge:
		var key := String(outfit["unlockKey"])
		audit.check_true(
			CareerRules.outfit_challenge_met(outfit["challenge"], {
				"stats": full_stats, "won": true, "skill": 0.95, "athleteWins": 99,
			}),
			"outfit_challenges/%s/perfect_match_wins_it" % key,
		)
		audit.check_true(
			not CareerRules.outfit_challenge_met(outfit["challenge"], {
				"stats": empty_stats, "won": false, "skill": 0.46, "athleteWins": 0,
			}),
			"outfit_challenges/%s/empty_lost_match_does_not" % key,
		)

	# `isUnlocked` deve guardare la sfida vinta, non piu' il portafoglio.
	var sample: Dictionary = with_challenge[0]
	var sample_key := String(sample["unlockKey"])
	audit.check_true(
		not CareerRules.is_unlocked(sample, {"trophies": 99, "stars": 99}),
		"outfit_challenges/stars_and_trophies_do_not_unlock_an_outfit",
	)
	audit.check_true(
		CareerRules.is_unlocked(sample, {"outfitsWon": {sample_key: true}}),
		"outfit_challenges/won_challenge_unlocks_the_outfit",
	)
	audit.check_true(CareerRules.is_unlocked(sample, {"unlockAll": true}), "outfit_challenges/unlock_code_still_works")

	audit.not_ported(
		"outfit_challenges/no_presentation_filter_selects_by_unlock",
		"the port has no presentation script yet (UI lane owns them); checking js/ui.js would audit the reference, not the port",
	)
	audit.report("completiConSfida=%d outfits=%d tettoPunti=%d" % [with_challenge.size(), outfits.size(), cap])
	audit.report("metriche=%s" % JSON.stringify(_metrics_with_challenges(with_challenge)))


# ---------------------------------------------------------------------------
# Helpers, in the reference's own shapes
# ---------------------------------------------------------------------------

## `ATHLETE_OUTFITS` flattened, each outfit carrying its `athleteId` — the same
## flattening `scripts/outfit-challenges-audit.mjs:30-32` performs.
static func all_outfits() -> Array:
	var out: Array = []
	for athlete_id in Tables.outfits():
		for outfit in Tables.outfits_for_athlete(String(athlete_id)):
			var entry: Dictionary = outfit.duplicate(true)
			entry["athleteId"] = String(athlete_id)
			out.append(entry)
	return out


## `const prove = (challenge) => [challenge, challenge.also].filter(Boolean)`
## (`scripts/outfit-challenges-audit.mjs:48`).
static func _prove(challenge: Dictionary) -> Array:
	var out: Array = [challenge]
	if challenge.get("also") != null and challenge["also"] is Dictionary:
		out.append(challenge["also"])
	return out


## `peso(challenge)` (`scripts/outfit-challenges-audit.mjs:83-86`), deliberately
## crude: it catches an inversion, it does not measure fun.
static func _weight(challenge: Dictionary, cap: int) -> float:
	var total := 0.0
	for prova in _prove(challenge):
		var metric := String(prova["metric"])
		var scala := 0.1 if metric == "totalRallyHits" else (0.5 if metric == "longestRally" else 1.0)
		if bool(prova.get("atMost", false)):
			total += float(cap - int(prova["target"])) * scala
		else:
			total += float(int(prova["target"])) * scala
	if bool(challenge.get("win", false)):
		total += 3.0
	if challenge.get("minSkill") != null:
		total += float(challenge["minSkill"]) * 12.0
	return total


static func _metrics_with_challenges(outfits: Array) -> Array:
	var out: Array = []
	for outfit in outfits:
		for prova in _prove(outfit["challenge"]):
			var metric := String(prova["metric"])
			if not out.has(metric):
				out.append(metric)
	return out


static func _distinct(values: Array) -> Dictionary:
	var out: Dictionary = {}
	for value in values:
		out[value] = true
	return out
