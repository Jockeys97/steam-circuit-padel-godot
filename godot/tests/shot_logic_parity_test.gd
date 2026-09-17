## shot_logic_parity_test.gd — the port decides every shot the way the 2D reference
## does: one scripted scenario per intent, the port's own core, headless.
##
## Ticket: `docs/wayfinder/tickets/shot-logic-parity.md` (slice S14a). Evidence:
## `docs/wayfinder/evidence/shot-logic-parity.md`.
##
## Reference side: `tools/sim-port/shot-intent-probe.mjs` runs the SAME 35 scenarios
## against the frozen `js/game.js` and prints the same `# trace` lines. `EXPECTED`
## below is that probe's real output, transcribed — not a hand-written hope — so a
## green run here means "the port reproduces the reference's printed numbers", and a
## red run names the field that moved.
##
## Coverage (the whole intent space, not a sample):
##   * the 13 intents the reference can produce — `drive`, `slice`, `vibora`,
##     `bandeja`, `chiquita`, `volley`, `cut-volley`, `lob`, `defensive-lob`,
##     `globo`, `smash` (x2 / x3 / flat), `wall-angle`, `serve`;
##   * the four modifiers — `special` (the input path, `trySpecial` -> `applySpecial`),
##     `smashUpgrade` (the A double tap), `cutVolley` (the X double tap),
##     `globo` (the lob tap) and `teamTactic` (which steers the pair and does NOT
##     change the shot intent — recorded as such);
##   * the charge / double-tap rules that select them — the charge accrual and the
##     queued power, the variant translation, the smash priming conditions and every
##     way they refuse (slice, service return, baseline, low ball, soft contact),
##     the priming window expiry, the degrade-without-the-second-tap rule, the x3
##     threshold and its downgrade, and the service return that forbids the smash.
##
## Every scenario before the first draw sets `state.rngState = SEED` (the convention
## of `tools/parity/**`), so both engines consume the same RNG stream and the floats
## are comparable at 6 printed decimals. `hit_ball` is reached with the arguments the
## queue path itself passes (`state.queuedShot*`), never with a hand-picked intent.
##
## Run:
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot/ \
##     --script res://tests/shot_logic_parity_test.gd
##
## Output contract: `# trace <json>` per scenario (the machine-checkable trace), then
## `ok <check>` / `FAIL <check>` per field, then `PASS n/n`.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const Support := preload("res://src/audits/audit_support.gd")
const Sim := preload("res://src/sim/sim.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const State := preload("res://src/sim/state.gd")
const Ent := preload("res://src/sim/entities.gd")

## `state.rngState = SEED` — the same literal the probe injects.
const SEED := 12345
## `TAP_DT` — the tick `js/main.js` uses for the accumulator fixed step.
const TAP_DT := 1.0 / 60.0
const TRACE_PREFIX := "# trace "

## The 13 intents, each pinned to the scenario that produces it.
const INTENT_SCENARIOS := {
	"drive": "intent/drive",
	"slice": "intent/slice",
	"vibora": "intent/vibora",
	"bandeja": "intent/bandeja",
	"chiquita": "intent/chiquita",
	"volley": "intent/volley",
	"cut-volley": "intent/cut-volley",
	"lob": "intent/lob",
	"defensive-lob": "intent/defensive-lob",
	"globo": "intent/globo",
	"smash": "intent/smash/x2",
	"wall-angle": "intent/wall-angle",
	"serve": "intent/serve",
}

## The reference's printed outcome per scenario: `tools/sim-port/shot-intent-probe.mjs`
## (seed 12345, maestro vs ingegnere, dt 1/60), transcribed verbatim.
const EXPECTED := {
	"intent/drive": {"kind": "shot", "path": "hitBall: no branch taken (baseline contact, |aimedOffset| < 0.72)", "shotType": "drive", "intentField": "drive", "dir": -1, "spinSign": 0, "x3": false, "vx": "0.000000", "vy": "-509.147984", "vz": "225.141483", "spin": "0.000000", "backspin": "0.000000", "topspin": "0.000000", "wallKill": "0.000000", "smashTargetSide": null, "flags": {}},
	"intent/slice": {"kind": "shot", "path": "hitBall: `else if (slice)` and NOT viboraRange (outside viboraNetWindow)", "shotType": "slice", "intentField": "slice", "dir": -1, "spinSign": 0, "x3": false, "vx": "0.000000", "vy": "-432.831581", "vz": "265.628767", "spin": "0.000000", "backspin": "1.019138", "topspin": "0.000000", "wallKill": "0.000000", "smashTargetSide": null, "flags": {}},
	"intent/vibora": {"kind": "shot", "path": "hitBall: `slice` + viboraRange + contactHeight >= 42 (vibora asks smashNetWindow)", "shotType": "vibora", "intentField": "vibora", "dir": -1, "spinSign": 1, "x3": false, "vx": "313.744864", "vy": "-397.913300", "vz": "228.126829", "spin": "76.000000", "backspin": "0.820000", "topspin": "0.000000", "wallKill": "0.000000", "smashTargetSide": null, "flags": {}},
	"intent/bandeja": {"kind": "shot", "path": "hitBall: explicitSmash with smashReady false -> smashType bandeja", "shotType": "bandeja", "intentField": "bandeja", "dir": -1, "spinSign": 1, "x3": false, "vx": "180.596307", "vy": "-312.965190", "vz": "329.945098", "spin": "48.000000", "backspin": "0.580000", "topspin": "0.000000", "wallKill": "0.000000", "smashTargetSide": null, "flags": {}},
	"intent/chiquita": {"kind": "shot", "path": "hitBall: `shotVariant === \"chiquita\"`", "shotType": "chiquita", "intentField": "chiquita", "dir": -1, "spinSign": 0, "x3": false, "vx": "0.000000", "vy": "-275.880478", "vz": "313.278431", "spin": "0.000000", "backspin": "0.550000", "topspin": "0.000000", "wallKill": "0.000000", "smashTargetSide": null, "flags": {}},
	"intent/volley": {"kind": "shot", "path": "applyComputerShot -> chooseComputerShot: kind = volley (seed 1)", "shotType": "volley", "intentField": "volley", "dir": 1, "spinSign": 1, "x3": false, "vx": "306.595694", "vy": "275.324767", "vz": "230.830388", "spin": "24.527656", "backspin": "0.000000", "topspin": "0.000000", "wallKill": "0.000000", "smashTargetSide": null, "flags": {}},
	"intent/cut-volley": {"kind": "shot", "path": "hitBall: variant cut-volley + quality >= cutVolleyMinQuality", "shotType": "cut-volley", "intentField": "cut-volley", "dir": -1, "spinSign": 1, "x3": false, "vx": "106.912011", "vy": "-443.484927", "vz": "245.646512", "spin": "66.560000", "backspin": "1.150000", "topspin": "0.000000", "wallKill": "1.000000", "smashTargetSide": null, "flags": {}},
	"intent/lob": {"kind": "shot", "path": "hitBall: variant lob", "shotType": "lob", "intentField": "lob", "dir": -1, "spinSign": 0, "x3": false, "vx": "0.000000", "vy": "-264.758808", "vz": "460.482554", "spin": "0.000000", "backspin": "0.000000", "topspin": "0.000000", "wallKill": "0.000000", "smashTargetSide": null, "flags": {}},
	"intent/defensive-lob": {"kind": "shot", "path": "hitBall: variant defensive-lob (pad Y + RB)", "shotType": "defensive-lob", "intentField": "defensive-lob", "dir": -1, "spinSign": 0, "x3": false, "vx": "0.000000", "vy": "-233.649401", "vz": "543.939197", "spin": "0.000000", "backspin": "0.000000", "topspin": "0.000000", "wallKill": "0.000000", "smashTargetSide": null, "flags": {}},
	"intent/globo": {"kind": "shot", "path": "hitBall: variant globo + quality >= globoMinQuality", "shotType": "globo", "intentField": "globo", "dir": -1, "spinSign": 0, "x3": false, "vx": "0.000000", "vy": "-204.577594", "vz": "685.022222", "spin": "0.000000", "backspin": "0.000000", "topspin": "0.000000", "wallKill": "0.000000", "smashTargetSide": null, "flags": {}},
	"intent/smash/x2": {"kind": "shot", "path": "hitBall: smashReady + explicitSmash + aimedDepth -1 -> x2 (|aimedOffset| < 0.42)", "shotType": "smash-x2", "intentField": "smash-x2", "dir": -1, "spinSign": 0, "x3": false, "vx": "0.000000", "vy": "-642.351654", "vz": "113.972414", "spin": "0.000000", "backspin": "0.000000", "topspin": "1.000000", "wallKill": "0.000000", "smashTargetSide": "ai", "flags": {}},
	"intent/smash/x3": {"kind": "shot", "path": "hitBall: smashReady + explicitSmash + aimedDepth <= -0.28 + |aimedOffset| >= 0.42", "shotType": "smash-x3", "intentField": "smash-x3", "dir": -1, "spinSign": 1, "x3": true, "vx": "451.072864", "vy": "-592.033134", "vz": "134.490323", "spin": "104.960000", "backspin": "0.000000", "topspin": "1.150000", "wallKill": "0.000000", "smashTargetSide": "ai", "flags": {}},
	"intent/smash/flat": {"kind": "shot", "path": "hitBall: smash-flat branch (quality < smashX3MinQuality, >= smashFlatMinQuality)", "shotType": "smash-flat", "intentField": "smash-flat", "dir": -1, "spinSign": 1, "x3": false, "vx": "323.479756", "vy": "-550.926459", "vz": "129.436066", "spin": "57.600000", "backspin": "0.000000", "topspin": "0.720000", "wallKill": "0.000000", "smashTargetSide": null, "flags": {}},
	"intent/wall-angle": {"kind": "shot", "path": "hitBall: seeksSideGlass (|aimedOffset| >= 0.72, no smashType, not slice, not lob)", "shotType": "wall-angle", "intentField": "wall-angle", "dir": -1, "spinSign": 1, "x3": false, "vx": "439.566138", "vy": "-505.341317", "vz": "225.141483", "spin": "87.040000", "backspin": "0.000000", "topspin": "0.000000", "wallKill": "0.000000", "smashTargetSide": null, "flags": {}},
	"intent/serve": {"kind": "shot", "path": "performServe: server.shotIntent = serve (the reference's own representation)", "shotType": "serve", "intentField": "serve", "dir": -1, "spinSign": -1, "x3": false, "vx": "-296.943648", "vy": "-237.234076", "vz": "369.833630", "spin": "-14.000000", "backspin": "0.000000", "topspin": "0.000000", "wallKill": null, "smashTargetSide": null, "flags": {"serveTargetX": "298.930640", "serveTargetY": "224.665490", "served": true, "serveInFlight": true}},
	"intent/serve/slice": {"kind": "shot", "path": "performServe: slice=true -> backspin 0.75 and spin x1.8", "shotType": "serve", "intentField": "serve", "dir": -1, "spinSign": -1, "x3": false, "vx": "-296.943648", "vy": "-237.234076", "vz": "369.833630", "spin": "-25.200000", "backspin": "0.750000", "topspin": "0.000000", "wallKill": null, "smashTargetSide": null, "flags": {"backspinIsSlice": true, "serveTargetX": "298.930640", "serveTargetY": "224.665490"}},
	"modifier/special": {"kind": "shot", "path": "updateMatch: input.special -> trySpecial -> hitBall(isSpecial) -> applySpecial(maestro)", "shotType": "smash-x2", "intentField": "smash-x2", "dir": -1, "spinSign": 0, "x3": false, "vx": "0.000000", "vy": "-469.295000", "vz": "313.000000", "spin": "0.000000", "backspin": "0.000000", "topspin": "0.995000", "wallKill": "0.000000", "smashTargetSide": "ai", "flags": {"aiReactionDelay": "0.862622", "specialCooldown": "2.983333", "specialReady": "0.000000", "swingBuffer": "0.240000", "hitCooldown": "0.180000"}},
	"modifier/smashUpgrade": {"kind": "shot", "path": "updateMatch: A release primes -> second tap confirms -> queuedShotVariant smash -> struck on contact", "shotType": "smash-x2", "intentField": "smash-x2", "dir": -1, "spinSign": 0, "x3": false, "vx": "0.000000", "vy": "-642.351654", "vz": "81.213793", "spin": "0.000000", "backspin": "0.000000", "topspin": "1.000000", "wallKill": "0.000000", "smashTargetSide": "ai", "flags": {"primedAfterFirstRelease": true, "tapWindowAfterPrime": "0.700000", "swingBufferAfterPrime": "0.883333", "variantAfterFirstRelease": "drive", "primedAfterSecondTap": false, "intentAfterTap": "smash", "queuedVariantAfterTap": "smash", "contactTick": 18}},
	"modifier/cutVolley": {"kind": "shot", "path": "updateMatch: X release primes the cut volley -> second tap confirms -> struck on contact", "shotType": "cut-volley", "intentField": "cut-volley", "dir": -1, "spinSign": 1, "x3": false, "vx": "0.000000", "vy": "-352.854492", "vz": "223.553488", "spin": "66.560000", "backspin": "1.150000", "topspin": "0.000000", "wallKill": "0.787870", "smashTargetSide": null, "flags": {"primedAfterFirstRelease": true, "tapWindowAfterPrime": "0.700000", "swingBufferAfterPrime": "0.833333", "sliceAfterFirstRelease": true, "primedAfterSecondTap": false, "intentAfterTap": "cut-volley", "contactTick": 6}},
	"modifier/globo": {"kind": "shot", "path": "updateMatch: lob release primes the globo -> globo tap confirms -> struck on contact", "shotType": "globo", "intentField": "globo", "dir": -1, "spinSign": 0, "x3": false, "vx": "0.000000", "vy": "-204.577594", "vz": "676.385859", "spin": "0.000000", "backspin": "0.000000", "topspin": "0.000000", "wallKill": "0.000000", "smashTargetSide": null, "flags": {"primedAfterFirstRelease": true, "tapWindowAfterPrime": "0.700000", "intentAfterTap": "globo", "contactTick": 2}},
	"modifier/teamTactic": {"kind": "state", "path": "updateMatch: setPlayerTeamTactic(input.teamTactic) — steers the pair, does not change the shot intent", "shotType": "queued", "intentField": "drive", "dir": 0, "spinSign": 0, "x3": false, "vx": null, "vy": null, "vz": null, "spin": null, "backspin": null, "topspin": null, "wallKill": null, "smashTargetSide": null, "flags": {"before": "balanced", "after": "attack", "tacticFlashAfterSet": "1.100000", "reSetIsNoOp": true}},
	"rule/charge-accrual": {"kind": "state", "path": "updateShotControl: shotCharge += dt/1.05, queuedShotPower = 0.4 + charge*0.95", "shotType": "queued", "intentField": "drive", "dir": 0, "spinSign": 0, "x3": false, "vx": null, "vy": null, "vz": null, "spin": null, "backspin": null, "topspin": null, "wallKill": null, "smashTargetSide": null, "flags": {"ticks": 30, "chargeAfterTicks": "0.476190", "intentWhileCharging": "drive", "queuedShotPower": "0.852381", "queuedShotCharge": "0.476190", "queuedShotVariant": "auto", "queuedShotSlice": false}},
	"rule/charge-variant-slice": {"kind": "state", "path": "queueChargedShot(slice=true, variant = input.slice ? \"slice\" : \"auto\")", "shotType": "queued", "intentField": "drive", "dir": 0, "spinSign": 0, "x3": false, "vx": null, "vy": null, "vz": null, "spin": null, "backspin": null, "topspin": null, "wallKill": null, "smashTargetSide": null, "flags": {"queuedShotVariant": "slice", "queuedShotSlice": true, "queuedShotPower": "0.685000"}},
	"rule/smash-prime-accepted": {"kind": "state", "path": "updateMatch: canPrimeSmash = drive && !slice && rallyHits>0 && withinNetRange(smashNetWindow) && z >= smashMinHeight-8 && power >= smashMinPower", "shotType": "queued", "intentField": "drive", "dir": 0, "spinSign": 0, "x3": false, "vx": null, "vy": null, "vz": null, "spin": null, "backspin": null, "topspin": null, "wallKill": null, "smashTargetSide": null, "flags": {"smashPrimed": true, "smashTapWindow": "0.700000", "swingBuffer": "0.883333", "smashContactFallback": false}},
	"rule/smash-prime-slice-refused": {"kind": "state", "path": "canPrimeSmash: queuedShotVariant != drive (a slice is queued) -> refused", "shotType": "queued", "intentField": "drive", "dir": 0, "spinSign": 0, "x3": false, "vx": null, "vy": null, "vz": null, "spin": null, "backspin": null, "topspin": null, "wallKill": null, "smashTargetSide": null, "flags": {"smashPrimed": false, "cutVolleyPrimed": false}},
	"rule/smash-prime-service-return-refused": {"kind": "state", "path": "canPrimeSmash: state.rallyHits > 0 -> refused on the service return", "shotType": "queued", "intentField": "drive", "dir": 0, "spinSign": 0, "x3": false, "vx": null, "vy": null, "vz": null, "spin": null, "backspin": null, "topspin": null, "wallKill": null, "smashTargetSide": null, "flags": {"smashPrimed": false}},
	"rule/smash-prime-baseline-refused": {"kind": "state", "path": "canPrimeSmash: withinNetRange(paddle, smashNetWindow) -> refused from the baseline", "shotType": "queued", "intentField": "drive", "dir": 0, "spinSign": 0, "x3": false, "vx": null, "vy": null, "vz": null, "spin": null, "backspin": null, "topspin": null, "wallKill": null, "smashTargetSide": null, "flags": {"smashPrimed": false}},
	"rule/smash-prime-low-ball-refused": {"kind": "state", "path": "canPrimeSmash: ball.z >= smashMinHeight - 8 -> refused on a low ball", "shotType": "queued", "intentField": "drive", "dir": 0, "spinSign": 0, "x3": false, "vx": null, "vy": null, "vz": null, "spin": null, "backspin": null, "topspin": null, "wallKill": null, "smashTargetSide": null, "flags": {"smashPrimed": false}},
	"rule/smash-prime-low-power-refused": {"kind": "state", "path": "canPrimeSmash: queuedShotPower * athlete.power >= smashMinPower -> refused on a soft contact", "shotType": "queued", "intentField": "drive", "dir": 0, "spinSign": 0, "x3": false, "vx": null, "vy": null, "vz": null, "spin": null, "backspin": null, "topspin": null, "wallKill": null, "smashTargetSide": null, "flags": {"smashPrimed": false, "queuedShotPower": "0.495000"}},
	"rule/smash-tap-window-expiry": {"kind": "state", "path": "decayHumanSwing/updateMatch: smashTapWindow <= 0 -> smashPrimed = false (contact impossible: ball above playableHitHeight)", "shotType": "queued", "intentField": "drive", "dir": 0, "spinSign": 0, "x3": false, "vx": null, "vy": null, "vz": null, "spin": null, "backspin": null, "topspin": null, "wallKill": null, "smashTargetSide": null, "flags": {"primedAfterFirstRelease": true, "expiredAfterTicks": 42, "queuedShotVariant": "drive", "swingBuffer": "0.183333"}},
	"rule/no-double-tap-degrades": {"kind": "shot", "path": "updateMatch: no second tap -> queuedShotVariant stays drive -> drive struck after the tap window expires", "shotType": "drive", "intentField": "drive", "dir": -1, "spinSign": 0, "x3": false, "vx": "30.909187", "vy": "-242.849088", "vz": "308.296953", "spin": "0.000000", "backspin": "0.000000", "topspin": "0.000000", "wallKill": "0.000000", "smashTargetSide": null, "flags": {"contactTick": 43, "lastHitterSide": "player"}},
	"rule/x3-vs-x2-auto": {"kind": "shot", "path": "hitBall: smashReady + auto -> smash-x3 when |aimedOffset| >= 0.52", "shotType": "smash-x3", "intentField": "smash-x3", "dir": -1, "spinSign": 1, "x3": true, "vx": "451.072864", "vy": "-592.033134", "vz": "134.490323", "spin": "104.960000", "backspin": "0.000000", "topspin": "1.150000", "wallKill": "0.000000", "smashTargetSide": "ai", "flags": {}},
	"rule/x3-downgrade": {"kind": "shot", "path": "hitBall: the smash-x3 branch requires quality >= smashX3MinQuality, else the x3 is downgraded to x2", "shotType": "smash-x2", "intentField": "smash-x2", "dir": -1, "spinSign": 1, "x3": false, "vx": "161.739878", "vy": "-611.578913", "vz": "129.436066", "spin": "25.000000", "backspin": "0.000000", "topspin": "0.960000", "wallKill": "0.000000", "smashTargetSide": "ai", "flags": {}},
	"rule/service-return-no-smash": {"kind": "shot", "path": "hitBall: serviceReturn (rallyHits == 0) forbids smashReady -> the explicit smash becomes a bandeja", "shotType": "bandeja", "intentField": "bandeja", "dir": -1, "spinSign": 1, "x3": false, "vx": "180.596307", "vy": "-312.965190", "vz": "313.278431", "spin": "48.000000", "backspin": "0.580000", "topspin": "0.000000", "wallKill": "0.000000", "smashTargetSide": null, "flags": {}},
	"rule/smash-defence-vs-incoming": {"kind": "shot", "path": "hitBall: returningSmash && grade != perfect/good -> smashed/scrambled defence arc and depth", "shotType": "drive", "intentField": "drive", "dir": -1, "spinSign": 0, "x3": false, "vx": "19.359521", "vy": "-213.614996", "vz": "431.767941", "spin": "0.000000", "backspin": "0.000000", "topspin": "0.000000", "wallKill": "0.000000", "smashTargetSide": null, "flags": {}},}

## Fields the reference leaves `undefined`, so its trace prints `null`, while the
## port's entity declares them: `createBall` (`js/game.js:74-107`) has no `wallKill`
## key — it is first written inside `hitBall` (`js/game.js:1506`) — while
## `entities.gd` declares `wallKill: float = 0.0`. Every read of it in both engines is
## an assignment or a numeric comparison, so "undefined" and "0.0" mean the same
## thing (no wall kill armed). The check is the explicit zero, never "whatever came
## out", and the exception is named here rather than hidden in a tolerance.
const UNINITIALISED_IN_REFERENCE := {
	"intent/serve": {"wallKill": "0.000000"},
	"intent/serve/slice": {"wallKill": "0.000000"},
}

const ROW_FIELDS := [
	"kind", "path", "shotType", "intentField", "dir", "spinSign", "x3",
	"vx", "vy", "vz", "spin", "backspin", "topspin", "wallKill", "smashTargetSide",
]


func _initialize() -> void:
	var audit := AuditBase.new("shot_logic_parity")
	run(audit)
	quit(audit.finish())


# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------

static func run(audit: AuditBase) -> void:
	audit.check_eq(EXPECTED.size(), 35, "shot_logic/scenario_count")
	var produced: Dictionary = {}
	for scenario in EXPECTED:
		var actual: Dictionary = run_scenario(String(scenario))
		produced[String(scenario)] = actual
		print(TRACE_PREFIX + JSON.stringify(actual))
		check_row(audit, String(scenario), actual, EXPECTED[scenario])
	# The ticket's promise, named intent by intent: the produced intent, the
	# direction, the spin sign and the x3 flag.
	for intent in INTENT_SCENARIOS:
		var scenario: String = INTENT_SCENARIOS[intent]
		var expected: Dictionary = EXPECTED[scenario]
		var actual: Dictionary = produced[scenario]
		audit.check_eq(actual["shotType"], expected["shotType"], "shot_logic/intent/%s/intent" % intent)
		audit.check_eq(actual["dir"], expected["dir"], "shot_logic/intent/%s/direction" % intent)
		audit.check_eq(actual["spinSign"], expected["spinSign"], "shot_logic/intent/%s/spin_sign" % intent)
		audit.check_eq(actual["x3"], expected["x3"], "shot_logic/intent/%s/x3_flag" % intent)
	audit.report("scenarios=%d intents=%d expected_rows=%d" % [
		produced.size(), INTENT_SCENARIOS.size(), EXPECTED.size(),
	])


static func check_row(audit: AuditBase, scenario: String, actual: Dictionary, expected: Dictionary) -> void:
	for field in ROW_FIELDS:
		if UNINITIALISED_IN_REFERENCE.has(scenario) and UNINITIALISED_IN_REFERENCE[scenario].has(field):
			var documented: String = UNINITIALISED_IN_REFERENCE[scenario][field]
			audit.check_eq(actual.get(field, "<missing>"), documented,
				"shot_logic/%s/%s (undefined in the reference, %s in the port)" % [scenario, field, documented])
			continue
		audit.check_eq(actual.get(field, "<missing>"), expected[field], "shot_logic/%s/%s" % [scenario, field])
	var want_keys: Array = expected["flags"].keys()
	want_keys.sort()
	var got_keys: Array = actual["flags"].keys()
	got_keys.sort()
	audit.check_eq(got_keys, want_keys, "shot_logic/%s/flags_keys" % scenario)
	for key in want_keys:
		audit.check_eq(actual["flags"][key], expected["flags"][key], "shot_logic/%s/flags/%s" % [scenario, key])


# ---------------------------------------------------------------------------
# Trace helpers — the same row shape the probe prints.
# ---------------------------------------------------------------------------

## A number at the digest's printed precision; booleans and nulls pass through.
static func r6(value: Variant) -> Variant:
	if value == null:
		return null
	match typeof(value):
		TYPE_BOOL:
			return value
		TYPE_INT:
			return "%.6f" % float(value)
		TYPE_FLOAT:
			return "%.6f" % float(value)
	return value


## `String(value)` of the reference: `null` reads "null", not "<null>".
static func js_str(value: Variant) -> String:
	if value == null:
		return "null"
	return str(value)


static func sgn(value: float) -> int:
	if value > 0.0:
		return 1
	if value < 0.0:
		return -1
	return 0


## A stroke was struck: the outcome is read off the ball and the paddle.
static func outcome(state: State, striker: String, scenario: String, path: String, flags: Dictionary = {}) -> Dictionary:
	var paddle: Ent.SimPaddle = state.paddle(striker)
	var ball: Ent.SimBall = state.ball
	var shot_type := String(ball.shotType)
	return {
		"scenario": scenario, "kind": "shot", "path": path, "shotType": shot_type,
		"intentField": String(paddle.shotIntent), "dir": sgn(ball.vy), "spinSign": sgn(ball.spin),
		"x3": shot_type == "smash-x3",
		"vx": r6(ball.vx), "vy": r6(ball.vy), "vz": r6(ball.vz),
		"spin": r6(ball.spin), "backspin": r6(ball.backspin), "topspin": r6(ball.topspin),
		"wallKill": r6(ball.wallKill),
		"smashTargetSide": (ball.smashTargetSide if ball.smashTargetSide != null else null),
		"flags": flags,
	}


## A rule/state observation: the ball fields are not the evidence, `flags` are.
static func observe(state: State, scenario: String, path: String, flags: Dictionary = {}) -> Dictionary:
	return {
		"scenario": scenario, "kind": "state", "path": path, "shotType": "queued",
		"intentField": String(state.shotIntent), "dir": 0, "spinSign": 0, "x3": false,
		"vx": null, "vy": null, "vz": null, "spin": null, "backspin": null,
		"topspin": null, "wallKill": null, "smashTargetSide": null,
		"flags": flags,
	}


# ---------------------------------------------------------------------------
# The benches — the port of the probe's `bench()` / `tapBench()` / `session()`
# ---------------------------------------------------------------------------

## One deterministic contact: the ball sits exactly on the paddle (offset 0).
static func bench(opts: Dictionary = {}) -> Dictionary:
	var state: State = Sim.create_match_state(
		"quick", Frozen.athletes()[0], Frozen.arenas()[0], Frozen.ai_opponents()[1],
	)
	Support.inject_seed(state, SEED)
	state.running = true
	state.serving = false
	state.rallyHits = int(opts.get("rallyHits", 2))
	var y: float = float(opts.get("y", float(Frozen.court()["netY"]) + 170.0))
	state.player.x = 480.0
	state.player.y = y
	state.player.hitCooldown = 0.0
	state.player.moveRatio = float(opts.get("moveRatio", 0.0))
	state.player.splitStep = float(opts.get("splitStep", 0.0))
	state.ball.x = 480.0
	state.ball.y = y + float(opts.get("passed", 0.0))
	state.ball.z = float(opts.get("height", 55.0))
	state.ball.vy = float(opts.get("ballVy", 120.0))
	state.ball.serveInFlight = false
	state.ball.netFaultOwner = null
	if opts.has("incoming"):
		state.ball.shotType = String(opts["incoming"])
	var charge: float = float(opts.get("charge", 0.76))
	var power: float = 0.4 + charge * 0.95
	var struck: bool = Sim.hit_ball(
		state, state.player, power, bool(opts.get("special", false)), true,
		float(opts.get("aim", 0.0)), bool(opts.get("slice", false)), String(opts.get("variant", "auto")),
		float(opts.get("aimY", -1.0)), float(opts.get("timingAge", 0.0)), float(opts.get("precision", 0.0)),
	)
	return {"state": state, "ok": struck}


## The tap bench: the ball is 125 px out and closing, so the first ticks only QUEUE.
static func tap_bench() -> State:
	var state: State = Sim.create_match_state(
		"quick", Frozen.athletes()[0], Frozen.arenas()[0], Frozen.ai_opponents()[1],
	)
	Support.inject_seed(state, SEED)
	state.running = true
	state.serving = false
	state.shotCharge = 0.76
	state.activePlayerKey = "player"
	state.rallyHits = 2
	state.player.x = 480.0
	state.player.y = float(Frozen.court()["netY"]) + 170.0
	state.player.hitCooldown = 0.0
	state.player.moveRatio = 0.0
	state.ball.x = 480.0
	state.ball.y = state.player.y - 125.0
	state.ball.z = 68.0
	state.ball.vx = 0.0
	state.ball.vy = 260.0
	state.ball.vz = 135.0
	state.ball.bounces = {"player": 0, "ai": 1}
	state.ball.serveInFlight = false
	state.ball.netFaultOwner = null
	return state


## A tick session: counts ticks and records the tick the queued stroke is struck.
## The `ball.shotType` baseline is captured before the first tick, because a tap and
## the contact can happen in the same tick.
static func session(state: State) -> Dictionary:
	return {"state": state, "base": String(state.ball.shotType), "tick": 0, "struck": -1}


static func step(s: Dictionary, overrides: Dictionary = {}) -> Dictionary:
	var inp: Dictionary = Support.vuoto()
	for key in overrides:
		inp[key] = overrides[key]
	var state: State = s["state"]
	Sim.update_match(state, TAP_DT, inp)
	s["tick"] = int(s["tick"]) + 1
	if int(s["struck"]) < 0 and String(s["state"].ball.shotType) != String(s["base"]):
		s["struck"] = int(s["tick"])
	return s


static func idle(s: Dictionary, max_ticks: int) -> Dictionary:
	var frame := 0
	while frame < max_ticks and int(s["struck"]) < 0:
		step(s, {})
		frame += 1
	return s


# ---------------------------------------------------------------------------
# Scenarios — 35 of them, one per intent / modifier / selection rule
# ---------------------------------------------------------------------------

static func run_scenario(name: String) -> Dictionary:
	match name:
		"intent/drive":
			return scenario_drive()
		"intent/slice":
			return scenario_slice()
		"intent/vibora":
			return scenario_vibora()
		"intent/bandeja":
			return scenario_bandeja()
		"intent/chiquita":
			return scenario_chiquita()
		"intent/volley":
			return scenario_volley()
		"intent/cut-volley":
			return scenario_cut_volley()
		"intent/lob":
			return scenario_lob()
		"intent/defensive-lob":
			return scenario_defensive_lob()
		"intent/globo":
			return scenario_globo()
		"intent/smash/x2":
			return scenario_smash_x2()
		"intent/smash/x3":
			return scenario_smash_x3()
		"intent/smash/flat":
			return scenario_smash_flat()
		"intent/wall-angle":
			return scenario_wall_angle()
		"intent/serve":
			return scenario_serve(false)
		"intent/serve/slice":
			return scenario_serve(true)
		"modifier/special":
			return scenario_special()
		"modifier/smashUpgrade":
			return scenario_smash_upgrade()
		"modifier/cutVolley":
			return scenario_cut_volley_tap()
		"modifier/globo":
			return scenario_globo_tap()
		"modifier/teamTactic":
			return scenario_team_tactic()
		"rule/charge-accrual":
			return scenario_charge_accrual()
		"rule/charge-variant-slice":
			return scenario_charge_variant_slice()
		"rule/smash-prime-accepted":
			return scenario_smash_prime_accepted()
		"rule/smash-prime-slice-refused":
			return scenario_smash_prime_slice_refused()
		"rule/smash-prime-service-return-refused":
			return scenario_smash_prime_service_return_refused()
		"rule/smash-prime-baseline-refused":
			return scenario_smash_prime_baseline_refused()
		"rule/smash-prime-low-ball-refused":
			return scenario_smash_prime_low_ball_refused()
		"rule/smash-prime-low-power-refused":
			return scenario_smash_prime_low_power_refused()
		"rule/smash-tap-window-expiry":
			return scenario_smash_tap_window_expiry()
		"rule/no-double-tap-degrades":
			return scenario_no_double_tap_degrade()
		"rule/x3-vs-x2-auto":
			return scenario_x3_vs_x2_auto()
		"rule/x3-downgrade":
			return scenario_x3_downgrade()
		"rule/service-return-no-smash":
			return scenario_service_return_no_smash()
		"rule/smash-defence-vs-incoming":
			return scenario_smash_defence()
	audit_unknown(name)
	return {}


# --- the 13 intents --------------------------------------------------------

static func scenario_drive() -> Dictionary:
	var bench_row := bench({"variant": "auto", "height": 55.0, "y": float(Frozen.court()["netY"]) + 220.0, "aim": 0.0})
	var state: State = bench_row["state"]
	return outcome(state, "player", "intent/drive",
		"hitBall: no branch taken (baseline contact, |aimedOffset| < 0.72)")


static func scenario_slice() -> Dictionary:
	var bench_row := bench({"variant": "auto", "slice": true, "height": 50.0, "y": float(Frozen.court()["netY"]) + 220.0})
	var state: State = bench_row["state"]
	return outcome(state, "player", "intent/slice",
		"hitBall: `else if (slice)` and NOT viboraRange (outside viboraNetWindow)")


static func scenario_vibora() -> Dictionary:
	var bench_row := bench({"variant": "vibora", "slice": true, "height": 55.0, "y": float(Frozen.court()["netY"]) + 170.0})
	var state: State = bench_row["state"]
	return outcome(state, "player", "intent/vibora",
		"hitBall: `slice` + viboraRange + contactHeight >= 42 (vibora asks smashNetWindow)")


static func scenario_bandeja() -> Dictionary:
	var bench_row := bench({
		"variant": "smash", "height": float(Frozen.balance()["smashMinHeight"]) - 8.0,
		"y": float(Frozen.court()["netY"]) + 170.0, "aim": 0.0,
	})
	var state: State = bench_row["state"]
	return outcome(state, "player", "intent/bandeja",
		"hitBall: explicitSmash with smashReady false -> smashType bandeja")


static func scenario_chiquita() -> Dictionary:
	var bench_row := bench({"variant": "chiquita", "height": 55.0, "y": float(Frozen.court()["netY"]) + 170.0, "aim": 0.0})
	var state: State = bench_row["state"]
	return outcome(state, "player", "intent/chiquita",
		"hitBall: `shotVariant === \"chiquita\"`")


static func scenario_volley() -> Dictionary:
	# The one intent only the AI produces (`chooseComputerShot`: atNet && z > 42 and
	# the kind roll misses the vibora band), reached through the exported `hit_ball`
	# on the opponent paddle — what `updateDoublesAI` itself calls.
	var state: State = Sim.create_match_state(
		"quick", Frozen.athletes()[0], Frozen.arenas()[0], Frozen.ai_opponents()[1],
	)
	Support.inject_seed(state, 1)
	state.running = true
	state.serving = false
	state.rallyHits = 2
	state.opponent.x = 480.0
	state.opponent.y = float(Frozen.court()["netY"]) - 100.0
	state.opponent.hitCooldown = 0.0
	state.ball.x = 480.0
	state.ball.y = state.opponent.y + 40.0
	state.ball.z = 50.0
	state.ball.vy = -120.0
	state.ball.serveInFlight = false
	state.ball.netFaultOwner = null
	Sim.hit_ball(state, state.opponent, 0.88 + 0.6 * 0.12, false, true)
	return outcome(state, "opponent", "intent/volley",
		"applyComputerShot -> chooseComputerShot: kind = volley (seed 1)")


static func scenario_cut_volley() -> Dictionary:
	var bench_row := bench({
		"variant": "cut-volley", "height": 55.0, "y": float(Frozen.court()["netY"]) + 170.0, "aim": 0.3,
	})
	var state: State = bench_row["state"]
	return outcome(state, "player", "intent/cut-volley",
		"hitBall: variant cut-volley + quality >= cutVolleyMinQuality")


static func scenario_lob() -> Dictionary:
	var bench_row := bench({"variant": "lob", "height": 55.0, "y": float(Frozen.court()["netY"]) + 170.0, "aim": 0.0})
	var state: State = bench_row["state"]
	return outcome(state, "player", "intent/lob", "hitBall: variant lob")


static func scenario_defensive_lob() -> Dictionary:
	var bench_row := bench({"variant": "defensive-lob", "height": 55.0, "y": float(Frozen.court()["netY"]) + 170.0, "aim": 0.0})
	var state: State = bench_row["state"]
	return outcome(state, "player", "intent/defensive-lob",
		"hitBall: variant defensive-lob (pad Y + RB)")


static func scenario_globo() -> Dictionary:
	var bench_row := bench({"variant": "globo", "height": 55.0, "y": float(Frozen.court()["netY"]) + 170.0, "aim": 0.0})
	var state: State = bench_row["state"]
	return outcome(state, "player", "intent/globo",
		"hitBall: variant globo + quality >= globoMinQuality")


static func scenario_smash_x2() -> Dictionary:
	var bench_row := bench({
		"variant": "smash", "height": 55.0, "y": float(Frozen.court()["netY"]) + 170.0, "aim": 0.0, "aimY": -1.0,
	})
	var state: State = bench_row["state"]
	return outcome(state, "player", "intent/smash/x2",
		"hitBall: smashReady + explicitSmash + aimedDepth -1 -> x2 (|aimedOffset| < 0.42)")


static func scenario_smash_x3() -> Dictionary:
	var bench_row := bench({
		"variant": "smash", "height": 55.0, "y": float(Frozen.court()["netY"]) + 170.0, "aim": 0.82, "aimY": -1.0,
	})
	var state: State = bench_row["state"]
	return outcome(state, "player", "intent/smash/x3",
		"hitBall: smashReady + explicitSmash + aimedDepth <= -0.28 + |aimedOffset| >= 0.42")


static func scenario_smash_flat() -> Dictionary:
	var bench_row := bench({
		"variant": "smash", "height": 55.0, "y": float(Frozen.court()["netY"]) + 170.0, "aim": 0.82, "aimY": -1.0,
		"timingAge": 0.3, "moveRatio": 1.0, "passed": 20.0,
	})
	var state: State = bench_row["state"]
	return outcome(state, "player", "intent/smash/flat",
		"hitBall: smash-flat branch (quality < smashX3MinQuality, >= smashFlatMinQuality)")


static func scenario_wall_angle() -> Dictionary:
	var bench_row := bench({
		"variant": "auto", "height": 55.0, "y": float(Frozen.court()["netY"]) + 220.0, "aim": 1.0, "aimY": -1.0,
	})
	var state: State = bench_row["state"]
	return outcome(state, "player", "intent/wall-angle",
		"hitBall: seeksSideGlass (|aimedOffset| >= 0.72, no smashType, not slice, not lob)")


static func scenario_serve(sliced: bool) -> Dictionary:
	var state: State = Sim.create_match_state(
		"quick", Frozen.athletes()[0], Frozen.arenas()[0], Frozen.ai_opponents()[1],
	)
	Support.inject_seed(state, SEED)
	state.running = true
	state.serveSide = "player"
	state.serveCourt = "right"
	state.serveAttempts = 0
	state.serving = true
	Sim.perform_serve(state, 0.62, sliced)
	var scenario := "intent/serve/slice" if sliced else "intent/serve"
	var path := ("performServe: slice=true -> backspin 0.75 and spin x1.8" if sliced
		else "performServe: server.shotIntent = serve (the reference's own representation)")
	var row := outcome(state, "player", scenario, path)
	row["shotType"] = String(state.player.shotIntent)
	if sliced:
		row["flags"] = {
			"backspinIsSlice": state.ball.backspin == 0.75,
			"serveTargetX": r6(state.ball.serveTargetX),
			"serveTargetY": r6(state.ball.serveTargetY),
		}
	else:
		row["flags"] = {
			"serveTargetX": r6(state.ball.serveTargetX),
			"serveTargetY": r6(state.ball.serveTargetY),
			"served": state.ball.served == true,
			"serveInFlight": state.ball.serveInFlight == true,
		}
	return row


# --- the modifiers --------------------------------------------------------

static func scenario_special() -> Dictionary:
	# The input path: `input.special` -> `trySpecial` -> `hitBall(isSpecial)` ->
	# `applySpecial` (maestro: the vy/vz override plus the read penalty, which
	# `hit_ball` consumes into `aiReactionDelay` in the same call).
	var state := tap_bench()
	state.ball.y = state.player.y - 20.0
	state.ball.z = 55.0
	state.ball.vy = 120.0
	state.ball.vz = 0.0
	state.specialReady = 1.0
	state.specialCooldown = 0.0
	var inp: Dictionary = Support.vuoto()
	inp["special"] = true
	Sim.update_match(state, TAP_DT, inp)
	return outcome(state, "player", "modifier/special",
		"updateMatch: input.special -> trySpecial -> hitBall(isSpecial) -> applySpecial(maestro)", {
			"aiReactionDelay": r6(state.aiReactionDelay),
			"specialCooldown": r6(state.specialCooldown),
			"specialReady": r6(state.specialReady),
			"swingBuffer": r6(state.playerSwingBuffer),
			"hitCooldown": r6(state.player.hitCooldown),
		})


static func scenario_smash_upgrade() -> Dictionary:
	# The double tap end to end: the first release of A primes, the second tap
	# confirms the upgrade to `smash`, and the prepared stroke keeps until contact.
	var s := session(tap_bench())
	var st: State = s["state"]
	step(s, {"hit": true, "shotVariant": "drive", "aim": 0.0, "aimY": -1.0, "analogAim": true})
	var primed: bool = s["state"].smashPrimed == true
	var tap_window: float = s["state"].smashTapWindow
	var buffer: float = s["state"].playerSwingBuffer
	var variant_after_first := String(s["state"].queuedShotVariant)
	step(s, {"smashUpgrade": true, "aim": 0.0, "aimY": -1.0, "analogAim": true})
	var primed_after_tap: bool = s["state"].smashPrimed == true
	var intent_after_tap := String(s["state"].shotIntent)
	var variant_after_tap := String(s["state"].queuedShotVariant)
	idle(s, 40)
	var row := outcome(st, "player", "modifier/smashUpgrade",
		"updateMatch: A release primes -> second tap confirms -> queuedShotVariant smash -> struck on contact")
	row["flags"] = {
		"primedAfterFirstRelease": primed,
		"tapWindowAfterPrime": r6(tap_window),
		"swingBufferAfterPrime": r6(buffer),
		"variantAfterFirstRelease": variant_after_first,
		"primedAfterSecondTap": primed_after_tap,
		"intentAfterTap": intent_after_tap,
		"queuedVariantAfterTap": variant_after_tap,
		"contactTick": int(s["struck"]),
	}
	return row


static func scenario_cut_volley_tap() -> Dictionary:
	# The same grammar on X: the first release is a slice, the second tap upgrades it
	# to a cut volley while the priming window is open. The player stands inside
	# `viboraNetWindow` and the ball starts outside `canHit`.
	var s := session(tap_bench())
	var st: State = s["state"]
	st.player.y = float(Frozen.court()["netY"]) + 95.0
	st.ball.y = float(Frozen.court()["netY"]) + 20.0
	st.ball.z = 68.0
	st.ball.vy = 260.0
	step(s, {"hit": true, "slice": true, "aim": 0.0, "aimY": -1.0, "analogAim": true})
	var primed: bool = s["state"].cutVolleyPrimed == true
	var tap_window: float = s["state"].cutVolleyTapWindow
	var buffer: float = s["state"].playerSwingBuffer
	var slice_after_first: bool = s["state"].queuedShotSlice == true
	step(s, {"cutVolley": true, "aim": 0.0, "aimY": -1.0, "analogAim": true})
	var primed_after_tap: bool = s["state"].cutVolleyPrimed == true
	var intent_after_tap := String(s["state"].shotIntent)
	idle(s, 40)
	var row := outcome(st, "player", "modifier/cutVolley",
		"updateMatch: X release primes the cut volley -> second tap confirms -> struck on contact")
	row["flags"] = {
		"primedAfterFirstRelease": primed,
		"tapWindowAfterPrime": r6(tap_window),
		"swingBufferAfterPrime": r6(buffer),
		"sliceAfterFirstRelease": slice_after_first,
		"primedAfterSecondTap": primed_after_tap,
		"intentAfterTap": intent_after_tap,
		"contactTick": int(s["struck"]),
	}
	return row


static func scenario_globo_tap() -> Dictionary:
	# The third tap grammar: a lob off a real charge on a ball that is not too high.
	var s := session(tap_bench())
	var st: State = s["state"]
	st.ball.y = s["state"].player.y - 60.0
	step(s, {"hit": true, "shotVariant": "lob", "aim": 0.0, "aimY": -1.0, "analogAim": true})
	var primed: bool = s["state"].globoPrimed == true
	var tap_window: float = s["state"].globoTapWindow
	step(s, {"globo": true, "aim": 0.0, "aimY": -1.0, "analogAim": true})
	var intent_after_tap := String(s["state"].shotIntent)
	idle(s, 40)
	var row := outcome(st, "player", "modifier/globo",
		"updateMatch: lob release primes the globo -> globo tap confirms -> struck on contact")
	row["flags"] = {
		"primedAfterFirstRelease": primed,
		"tapWindowAfterPrime": r6(tap_window),
		"intentAfterTap": intent_after_tap,
		"contactTick": int(s["struck"]),
	}
	return row


static func scenario_team_tactic() -> Dictionary:
	# The D-pad tactic: it steers the pair, it does NOT change the shot intent.
	var state := tap_bench()
	var before := String(state.playerTeamTactic)
	var first: Dictionary = Support.vuoto()
	first["teamTactic"] = "attack"
	Sim.update_match(state, TAP_DT, first)
	var after := String(state.playerTeamTactic)
	var flash: float = state.tacticFlash
	var again: Dictionary = Support.vuoto()
	again["teamTactic"] = "attack"
	Sim.update_match(state, TAP_DT, again)
	return observe(state, "modifier/teamTactic",
		"updateMatch: setPlayerTeamTactic(input.teamTactic) — steers the pair, does not change the shot intent", {
			"before": before,
			"after": after,
			"tacticFlashAfterSet": r6(flash),
			"reSetIsNoOp": String(state.playerTeamTactic) == after,
		})


# --- the charge / double-tap rules that select them ------------------------

static func scenario_charge_accrual() -> Dictionary:
	var state := tap_bench()
	state.shotCharge = 0.0
	var charging: Dictionary = Support.vuoto()
	charging["charging"] = true
	var ticks := 30
	for i in range(0, ticks):
		Sim.update_match(state, TAP_DT, charging)
	var charge_after: float = state.shotCharge
	var intent_while_charging := String(state.shotIntent)
	var release: Dictionary = Support.vuoto()
	release["hit"] = true
	Sim.update_match(state, TAP_DT, release)
	return observe(state, "rule/charge-accrual",
		"updateShotControl: shotCharge += dt/1.05, queuedShotPower = 0.4 + charge*0.95", {
			"ticks": ticks,
			"chargeAfterTicks": r6(charge_after),
			"intentWhileCharging": intent_while_charging,
			"queuedShotPower": r6(state.queuedShotPower),
			"queuedShotCharge": r6(state.queuedShotCharge),
			"queuedShotVariant": String(state.queuedShotVariant),
			"queuedShotSlice": state.queuedShotSlice == true,
		})


static func scenario_charge_variant_slice() -> Dictionary:
	var state := tap_bench()
	state.shotCharge = 0.3
	var inp: Dictionary = Support.vuoto()
	inp["hit"] = true
	inp["slice"] = true
	Sim.update_match(state, TAP_DT, inp)
	return observe(state, "rule/charge-variant-slice",
		"queueChargedShot(slice=true, variant = input.slice ? \"slice\" : \"auto\")", {
			"queuedShotVariant": String(state.queuedShotVariant),
			"queuedShotSlice": state.queuedShotSlice == true,
			"queuedShotPower": r6(state.queuedShotPower),
		})


static func scenario_smash_prime_accepted() -> Dictionary:
	var state := tap_bench()
	var inp: Dictionary = Support.vuoto()
	inp["hit"] = true
	inp["shotVariant"] = "drive"
	Sim.update_match(state, TAP_DT, inp)
	return observe(state, "rule/smash-prime-accepted",
		"updateMatch: canPrimeSmash = drive && !slice && rallyHits>0 && withinNetRange(smashNetWindow) && z >= smashMinHeight-8 && power >= smashMinPower", {
			"smashPrimed": state.smashPrimed == true,
			"smashTapWindow": r6(state.smashTapWindow),
			"swingBuffer": r6(state.playerSwingBuffer),
			"smashContactFallback": state.smashContactFallback == true,
		})


static func scenario_smash_prime_slice_refused() -> Dictionary:
	var state := tap_bench()
	var inp: Dictionary = Support.vuoto()
	inp["hit"] = true
	inp["slice"] = true
	Sim.update_match(state, TAP_DT, inp)
	return observe(state, "rule/smash-prime-slice-refused",
		"canPrimeSmash: queuedShotVariant != drive (a slice is queued) -> refused", {
			"smashPrimed": state.smashPrimed == true,
			"cutVolleyPrimed": state.cutVolleyPrimed == true,
		})


static func scenario_smash_prime_service_return_refused() -> Dictionary:
	var state := tap_bench()
	state.rallyHits = 0
	var inp: Dictionary = Support.vuoto()
	inp["hit"] = true
	inp["shotVariant"] = "drive"
	Sim.update_match(state, TAP_DT, inp)
	return observe(state, "rule/smash-prime-service-return-refused",
		"canPrimeSmash: state.rallyHits > 0 -> refused on the service return", {
			"smashPrimed": state.smashPrimed == true,
		})


static func scenario_smash_prime_baseline_refused() -> Dictionary:
	var state := tap_bench()
	state.player.y = float(Frozen.court()["netY"]) + float(Frozen.balance()["smashNetWindow"]) + 30.0
	var inp: Dictionary = Support.vuoto()
	inp["hit"] = true
	inp["shotVariant"] = "drive"
	Sim.update_match(state, TAP_DT, inp)
	return observe(state, "rule/smash-prime-baseline-refused",
		"canPrimeSmash: withinNetRange(paddle, smashNetWindow) -> refused from the baseline", {
			"smashPrimed": state.smashPrimed == true,
		})


static func scenario_smash_prime_low_ball_refused() -> Dictionary:
	var state := tap_bench()
	state.ball.z = float(Frozen.balance()["smashMinHeight"]) - 9.0
	var inp: Dictionary = Support.vuoto()
	inp["hit"] = true
	inp["shotVariant"] = "drive"
	Sim.update_match(state, TAP_DT, inp)
	return observe(state, "rule/smash-prime-low-ball-refused",
		"canPrimeSmash: ball.z >= smashMinHeight - 8 -> refused on a low ball", {
			"smashPrimed": state.smashPrimed == true,
		})


static func scenario_smash_prime_low_power_refused() -> Dictionary:
	var state := tap_bench()
	state.shotCharge = 0.1
	var inp: Dictionary = Support.vuoto()
	inp["hit"] = true
	inp["shotVariant"] = "drive"
	Sim.update_match(state, TAP_DT, inp)
	return observe(state, "rule/smash-prime-low-power-refused",
		"canPrimeSmash: queuedShotPower * athlete.power >= smashMinPower -> refused on a soft contact", {
			"smashPrimed": state.smashPrimed == true,
			"queuedShotPower": r6(state.queuedShotPower),
		})


static func scenario_smash_tap_window_expiry() -> Dictionary:
	# No contact is possible (the ball sits above `playableHitHeight`), so the priming
	# window is left to run out: the tap dies after `BALANCE.smashDoubleTapWindow`.
	var state := tap_bench()
	state.ball.z = float(Frozen.balance()["playableHitHeight"]) + 22.0
	state.ball.vy = 0.0
	state.ball.vz = 250.0
	var prime: Dictionary = Support.vuoto()
	prime["hit"] = true
	prime["shotVariant"] = "drive"
	Sim.update_match(state, TAP_DT, prime)
	var primed_first: bool = state.smashPrimed == true
	var expired_at := -1
	var idle_input: Dictionary = Support.vuoto()
	for frame in range(0, 90):
		Sim.update_match(state, TAP_DT, idle_input)
		if state.smashPrimed != true:
			expired_at = frame + 1
			break
	return observe(state, "rule/smash-tap-window-expiry",
		"decayHumanSwing/updateMatch: smashTapWindow <= 0 -> smashPrimed = false (contact impossible: ball above playableHitHeight)", {
			"primedAfterFirstRelease": primed_first,
			"expiredAfterTicks": expired_at,
			"queuedShotVariant": String(state.queuedShotVariant),
			"swingBuffer": r6(state.playerSwingBuffer),
		})


static func scenario_no_double_tap_degrade() -> Dictionary:
	# Without the second tap the prepared shot degrades to the plain drive.
	var s := session(tap_bench())
	var st: State = s["state"]
	step(s, {"hit": true, "shotVariant": "drive", "moveX": 0.0, "moveY": 0.0})
	idle(s, 70)
	var row := outcome(st, "player", "rule/no-double-tap-degrades",
		"updateMatch: no second tap -> queuedShotVariant stays drive -> drive struck after the tap window expires")
	row["flags"] = {
		"contactTick": int(s["struck"]),
		"lastHitterSide": js_str(st.lastHitterSide),
	}
	return row


static func scenario_x3_vs_x2_auto() -> Dictionary:
	var bench_row := bench({
		"variant": "auto", "height": 55.0, "y": float(Frozen.court()["netY"]) + 170.0, "aim": 0.82, "aimY": -1.0,
	})
	var state: State = bench_row["state"]
	return outcome(state, "player", "rule/x3-vs-x2-auto",
		"hitBall: smashReady + auto -> smash-x3 when |aimedOffset| >= 0.52")


static func scenario_x3_downgrade() -> Dictionary:
	var bench_row := bench({
		"variant": "smash", "height": 55.0, "y": float(Frozen.court()["netY"]) + 170.0, "aim": 0.82, "aimY": -1.0,
		"timingAge": 0.06,
	})
	var state: State = bench_row["state"]
	return outcome(state, "player", "rule/x3-downgrade",
		"hitBall: the smash-x3 branch requires quality >= smashX3MinQuality, else the x3 is downgraded to x2")


static func scenario_service_return_no_smash() -> Dictionary:
	var bench_row := bench({
		"variant": "smash", "height": 55.0, "y": float(Frozen.court()["netY"]) + 170.0, "aim": 0.0, "aimY": -1.0,
		"rallyHits": 0,
	})
	var state: State = bench_row["state"]
	return outcome(state, "player", "rule/service-return-no-smash",
		"hitBall: serviceReturn (rallyHits == 0) forbids smashReady -> the explicit smash becomes a bandeja")


static func scenario_smash_defence() -> Dictionary:
	var bench_row := bench({
		"variant": "auto", "height": 55.0, "y": float(Frozen.court()["netY"]) + 220.0, "aim": 0.0, "aimY": -1.0,
		"incoming": "smash-x2", "timingAge": 0.3, "moveRatio": 1.0, "passed": 20.0,
	})
	var state: State = bench_row["state"]
	return outcome(state, "player", "rule/smash-defence-vs-incoming",
		"hitBall: returningSmash && grade != perfect/good -> smashed/scrambled defence arc and depth")


## Unreachable unless the dispatcher and `EXPECTED` drift apart: a missing scenario
## must not read as a pass with an empty row.
static func audit_unknown(name: String) -> void:
	printerr("shot_logic_parity: no scenario registered for '%s'" % name)
