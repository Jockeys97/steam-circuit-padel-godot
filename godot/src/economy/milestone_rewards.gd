extends RefCounted
const Rules = preload("res://src/modes/career_rules.gd")
## Additional rewards, separate from simulation and existing star/trophy unlocks.
## Empty key = repeatable completion bonus; named keys are lifetime first clears.
static func candidates(result: Dictionary) -> Array:
	var rows: Array = []
	if result.get("mode", "") == "tournament" and bool(result.get("won", false)) and int(result.get("round", -1)) == 2:
		rows.append({"key": "", "label": "rewardTournament", "amount": 200})
		rows.append({"key": "first_tournament", "label": "rewardFirstTournament", "amount": 250})
	if result.get("mode", "") == "career":
		var outcome: Dictionary = result.get("outcome", {})
		if bool(outcome.get("seasonEnded", false)) and String(outcome.get("outcome", "")) in ["promoted", "trophy", "finale"]:
			var perfect := bool(outcome.get("seasonWon", false))
			rows.append({"key": "", "label": "rewardSeasonPerfect" if perfect else "rewardPromotion", "amount": 250 if perfect else 125})
			rows.append({"key": "season_%d" % int(result.get("season", 1)), "label": "rewardFirstSeason", "amount": 100})
			var cup := Rules.master_cup(int(result.get("season", 1)))
			if perfect and not cup.is_empty():
				rows.append({"key": "cup_" + String(cup.id), "label": "rewardFirstCup", "amount": 300})
		if String(outcome.get("outcome", "")) == "finale":
			rows.append({"key": "career_finale", "label": "rewardFinale", "amount": 600})
	return rows
