## coach_advice.gd — what the coach does with TypeSafe's answer.
##
## CODE OWNS THE ADVICE. The model picks one category; the sentence, the numbers it
## quotes and the exercise it links to are decided here, from the match's own snapshot.
## The bridge cannot send prose, a metric name or an exercise id — only a category, a
## confidence and a distribution, and every one of those is re-validated below before a
## screen shows anything (`PLAN.md`: no overclaiming, evidence-backed, linked to a real
## drill).
##
## THE GATE IS PROVISIONAL AND CONSERVATIVE. TypeSafe's Choice confidence is a property
## of the distribution it returned, not a promise about the advice
## (https://docs.typesafe.ai/confidence.md); the contract's `confidenceGate` is applied
## to it, and anything under the gate is shown as an uncertain reading — with the
## numbers, without a recommendation. The value is provisional: it is meant to be
## re-derived from the player's own accepted/rejected outcomes, and until then it errs
## towards saying less.
##
## EVERY EXERCISE ID HERE MUST EXIST. `drill_serve`, `drill_smash`, `drill_rally` and
## `drill_precision` are the frozen drill table's own four ids
## (`godot/src/modes/data/modes.json`), so the button always opens a drill that exists —
## the coach test asserts it against `mode_tables.gd::drill_exercises()`.
extends RefCounted

const Contract := preload("res://src/coach/coach_contract.gd")
const Stats := preload("res://src/coach/coach_stats.gd")

## One entry per drillable category: the advice template shown, the existing drill it
## links to, and the numbers that template quotes — all from the snapshot, never from
## the model's answer.
const ADVICE := {
	"serve_accuracy": {"advice": "coachAdviceServe", "drill": "serve"},
	"shot_accuracy": {"advice": "coachAdviceShot", "drill": "precision"},
	"rally_consistency": {"advice": "coachAdviceRally", "drill": "rally"},
	"net_finishing": {"advice": "coachAdviceFinish", "drill": "smash"},
}

## The one evidence line every state that has numbers shows: the match's own counted
## facts, quoted the same way whether or not a recommendation came out of them.
const EVIDENCE_ID := "coachEvidence"

const STATE_ADVICE := "advice"
const STATE_UNCERTAIN := "uncertain"
const STATE_INSUFFICIENT := "insufficient"
const STATE_UNAVAILABLE := "unavailable"
const STATE_INVALID := "invalid"

## How far the returned distribution may miss 1.0 before it is not a distribution.
const DISTRIBUTION_TOLERANCE := 0.02

## How far the chosen category's probability may sit below the peak before the answer is
## internally inconsistent. A Choice's `choice` IS its highest-probability option
## (https://docs.typesafe.ai/api.md), so a body whose chosen option is not the peak — beyond
## a tie's floating-point noise — is a body to refuse rather than to present.
const MAXIMAL_TOLERANCE := 0.000001


## The record the panel renders, from a snapshot and whatever the client brought back.
## `reply` is the transport result: `{status: ok|timeout|unreachable|error|too_large…}`,
## with the bridge's own body under `body` when there is one.
static func evaluate(snapshot: Dictionary, reply: Variant, gate: float = -1.0) -> Dictionary:
	var record := {
		"state": STATE_UNAVAILABLE,
		"category": "",
		"advice_id": "",
		"advice_params": {},
		"evidence_id": EVIDENCE_ID,
		"evidence_params": evidence_params(snapshot),
		"drill_id": "",
		"confidence": 0.0,
		"probabilities": {},
		"detail": "",
	}
	if not bool(snapshot.get("sufficient", false)):
		record["state"] = STATE_INSUFFICIENT
		record["detail"] = "the match did not measure enough to ask about"
		return record

	var validated := validate(reply, snapshot.get("candidates", []))
	if not bool(validated.get("ok", false)):
		var code := String(validated.get("code", "invalid"))
		record["state"] = STATE_UNAVAILABLE if code == "unavailable" else STATE_INVALID
		record["detail"] = String(validated.get("detail", ""))
		# Nothing is presented from an answer that failed its own contract: the numbers
		# still show (they are the match's, not the model's), and no exercise is offered.
		record["confidence"] = float(validated.get("confidence", 0.0))
		record["probabilities"] = validated.get("probabilities", {})
		return record

	var choice := String(validated.get("choice", ""))
	var confidence := float(validated.get("confidence", 0.0))
	record["confidence"] = confidence
	record["probabilities"] = validated.get("probabilities", {})
	record["category"] = choice
	var effective_gate := gate if gate >= 0.0 else Contract.confidence_gate()
	if choice == Contract.INSUFFICIENT:
		record["state"] = STATE_INSUFFICIENT
		record["detail"] = "the model judged the measured counters unsupportive"
		return record
	if confidence < effective_gate:
		record["state"] = STATE_UNCERTAIN
		record["detail"] = "confidence %.3f is under the %.2f gate" % [confidence, effective_gate]
		return record
	record["state"] = STATE_ADVICE
	record["advice_id"] = advice_id(choice)
	record["advice_params"] = advice_params(choice, snapshot)
	record["drill_id"] = drill_id(choice)
	record["detail"] = "confidence %.3f over the %.2f gate" % [confidence, effective_gate]
	return record


## The answer's own contract: the right type, a category that was actually offered, a
## finite confidence in [0, 1] and a real distribution over the offered categories.
## Anything else is refused with a reason a test can read.
static func validate(reply: Variant, offered: Array) -> Dictionary:
	var out := {"ok": false, "code": "invalid", "detail": "", "confidence": 0.0, "probabilities": {}}
	if not (reply is Dictionary):
		out["detail"] = "no reply"
		return out
	var body: Dictionary = reply
	var status := String(body.get("status", ""))
	if status != "ok":
		out["code"] = "unavailable" if status != "invalid" else "invalid"
		out["detail"] = "transport status '%s'" % status
		return out
	var inner: Variant = body.get("body", {})
	if not (inner is Dictionary):
		out["detail"] = "reply body is not an object"
		return out
	var answer: Dictionary = inner
	if String(answer.get("type", "")) != "choice":
		out["detail"] = "answer type '%s' is not a choice" % String(answer.get("type", ""))
		return out
	var choice: Variant = answer.get("choice", "")
	if not (choice is String) or not offered.has(String(choice)):
		out["detail"] = "choice '%s' was not offered" % String(choice)
		return out
	var confidence: Variant = answer.get("confidence", null)
	if not (confidence is float or confidence is int):
		out["detail"] = "confidence is not a number"
		return out
	var value := float(confidence)
	if not is_finite(value) or value < 0.0 or value > 1.0:
		out["detail"] = "confidence %s is outside [0, 1]" % str(value)
		return out
	var distribution: Variant = answer.get("probabilities", null)
	if not (distribution is Dictionary):
		out["detail"] = "no distribution came back"
		return out
	var probabilities: Dictionary = distribution
	var total := 0.0
	var seen := 0
	var peak := 0.0
	for key in probabilities.keys():
		if not offered.has(String(key)):
			out["detail"] = "distribution carries '%s', which was not offered" % String(key)
			return out
		var part: Variant = probabilities[key]
		if not (part is float or part is int):
			out["detail"] = "distribution entry '%s' is not a number" % String(key)
			return out
		var part_value := float(part)
		if not is_finite(part_value) or part_value < 0.0 or part_value > 1.0:
			out["detail"] = "distribution entry '%s' is outside [0, 1]" % String(key)
			return out
		total += part_value
		seen += 1
		peak = maxf(peak, part_value)
	if seen != offered.size():
		out["detail"] = "distribution covers %d of %d offered categories" % [seen, offered.size()]
		return out
	if absf(total - 1.0) > DISTRIBUTION_TOLERANCE:
		out["detail"] = "distribution sums to %.3f" % total
		return out
	if float(probabilities[choice]) < peak - MAXIMAL_TOLERANCE:
		out["detail"] = "the chosen category is not the most probable one"
		return out
	out["ok"] = true
	out["code"] = "ok"
	out["choice"] = String(choice)
	out["confidence"] = value
	out["probabilities"] = probabilities
	return out


## The counted facts every state with numbers shows. `rallies`/`averageRally` are the
## result screen's own two foot figures, so the coach repeats the player's numbers
## rather than a second reading of them.
static func evidence_params(snapshot_in: Dictionary) -> Dictionary:
	return {
		"errors": Stats.player_count(snapshot_in, "errors"),
		"winners": Stats.player_count(snapshot_in, "winners"),
		"aces": Stats.player_count(snapshot_in, "aces"),
		"doubleFaults": Stats.player_count(snapshot_in, "doubleFaults"),
		"rallies": int(snapshot_in.get("counters", {}).get("rallyCount", 0)),
		"averageRally": "%.1f" % float(snapshot_in.get("averageRally", 0.0)),
	}


## The numbers one category's sentence quotes, all of them measured.
static func advice_params(category_id: String, snapshot_in: Dictionary) -> Dictionary:
	var average := "%.1f" % float(snapshot_in.get("averageRally", 0.0))
	match category_id:
		"serve_accuracy":
			return {
				"doubleFaults": Stats.player_count(snapshot_in, "doubleFaults"),
				"aces": Stats.player_count(snapshot_in, "aces"),
			}
		"shot_accuracy":
			return {
				"errors": Stats.player_count(snapshot_in, "errors"),
				"winners": Stats.player_count(snapshot_in, "winners"),
			}
		"rally_consistency":
			return {
				"averageRally": average,
				"rallies": int(snapshot_in.get("counters", {}).get("rallyCount", 0)),
				"errors": Stats.player_count(snapshot_in, "errors"),
			}
		"net_finishing":
			return {
				"winners": Stats.player_count(snapshot_in, "winners"),
				"pointsWon": Stats.player_count(snapshot_in, "pointsWon"),
			}
	return {}


static func advice_id(category_id: String) -> String:
	var entry: Variant = ADVICE.get(category_id, {})
	return String((entry as Dictionary).get("advice", "")) if entry is Dictionary else ""


## The existing drill a category links to, or "" when the category advises without one.
static func drill_id(category_id: String) -> String:
	var entry: Variant = ADVICE.get(category_id, {})
	return String((entry as Dictionary).get("drill", "")) if entry is Dictionary else ""


## The categories this module can advise on — the keys the coach test compares against
## the contract's drillable categories, so a new category cannot arrive without its
## sentence, its drill and its numbers.
static func categories() -> Array[String]:
	var out: Array[String] = []
	for key in ADVICE.keys():
		out.append(String(key))
	return out
