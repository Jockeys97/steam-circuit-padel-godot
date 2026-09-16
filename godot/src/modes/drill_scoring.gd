## drill_scoring.gd — the drill's attempt scoring, its score line, its HUD
## metrics and its bests. Ported from `js/drill.js:244-262` (`closeAttempt`'s
## arithmetic), `js/drill.js:465-472` (`drillScoreLine`) and `js/drill.js:474-498`
## (`drillMetrics`), plus the record policy `js/ui.js:219-230`.
##
## API (a UI lane consumes this without reading its internals):
##
##   DrillScoring.GRADE_IDS -> Array            `perfect`, `good`, `early`, `late`
##   DrillScoring.grade_multiplier(grade) -> float   `js/drill.js:251`
##   DrillScoring.attempt_points(tier, grade) -> int `js/drill.js:252`
##   DrillScoring.score_line(grade, points) -> String
##       The grade as a MESSAGE ID plus the points, e.g. `shot:perfect · 12`.
##       The reference builds this line from display literals (`js/drill.js:469`)
##       but never calls it — `grep -rn drillScoreLine js/` finds the definition
##       only, no caller — so the port keeps the function and drops the literals
##       in favour of the id the simulation already emits for the same grade
##       (`shot:<grade>`, `js/game.js`'s `showShotFeedback`). A divergence in
##       presentation only, recorded here rather than silently carried.
##   DrillScoring.metrics(drill) -> Array[Dictionary]
##       The four HUD metrics, `{key, value}`, with the reference's own keys
##       (`drillScore`, `drillBest`, `drillHits`, `drillIn`, `drillStreak`,
##       `drillBestRally`, `drillEnergy`, `drillDoubleFaults`) and its own value
##       formatting. Four per exercise, always.
##   DrillScoring.best_after(existing, score) -> int   session best
##   DrillScoring.record_improves(existing, score) -> bool
##       `js/ui.js:222`: a record is written only on improvement. Delegates to
##       `SaveSchema.drill_record_improves` — the save module owns that rule and
##       it is not duplicated here.
extends RefCounted

const Tables := preload("res://src/modes/mode_tables.gd")
const Schema := preload("res://src/save/save_schema.gd")

## The four grades the engine produces (`js/drill.js:468-469`, `js/game.js`'s
## shot feedback classes).
const GRADE_IDS: Array = ["perfect", "good", "early", "late"]


## `js/drill.js:251`: `perfect` pays full, `good` 0.72, everything else 0.45.
static func grade_multiplier(grade: Variant) -> float:
	if grade == "perfect":
		return 1.0
	if grade == "good":
		return 0.72
	return 0.45


## `js/drill.js:252`: `Math.round(10 * tier * gradeMult)`, half away from zero.
static func attempt_points(tier: float, grade: Variant) -> int:
	return roundi(10.0 * tier * grade_multiplier(grade))


## `js/drill.js:468-471`, with the label replaced by the grade's message id.
static func score_line(grade: Variant, points: int) -> String:
	if grade == null or not GRADE_IDS.has(String(grade)):
		return "—"
	return "shot:%s · %d" % [String(grade), points]


## `drillMetrics(drill)` (`js/drill.js:474-498`). The branch is on the exercise
## id, exactly as the reference branches.
static func metrics(drill) -> Array:
	var id: String = String(drill.exercise.get("id", ""))
	var energy: float = 1.0
	if drill.state != null and drill.state.rallyEnergy is Dictionary:
		energy = float((drill.state.rallyEnergy as Dictionary).get("player", 1.0))
	if id == "rally":
		return [
			{"key": "drillScore", "value": str(drill.score)},
			{"key": "drillBestRally", "value": str(drill.best_rally)},
			{"key": "drillEnergy", "value": "%d%%" % roundi(energy * 100.0)},
			{"key": "drillBest", "value": str(drill.best)},
		]
	if id == "serve":
		return [
			{"key": "drillScore", "value": str(drill.score)},
			{"key": "drillBest", "value": str(drill.best)},
			{"key": "drillIn", "value": "%d/%d" % [drill.hits, drill.attempts]},
			{"key": "drillDoubleFaults", "value": str(drill.double_faults)},
		]
	return [
		{"key": "drillScore", "value": str(drill.score)},
		{"key": "drillBest", "value": str(drill.best)},
		{"key": "drillHits", "value": "%d/%d" % [drill.hits, drill.attempts]},
		{"key": "drillStreak", "value": str(drill.streak)},
	]


## `drill.best = Math.max(drill.best, drill.score)` (`js/drill.js:257`).
static func best_after(existing: int, score: int) -> int:
	return maxi(existing, score)


## `saveDrillRecord` (`js/ui.js:219-230`): write only on improvement.
static func record_improves(existing: int, score: int) -> bool:
	return Schema.drill_record_improves(existing, score)
