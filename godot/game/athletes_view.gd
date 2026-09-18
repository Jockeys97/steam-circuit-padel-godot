## athletes_view.gd — the four athletes on court: real rigs from
## `src/character/athlete_spawn.gd`, driven by the simulation's paddle state.
##
## WHAT IT REPLACES. Until this slice the match drew four copies of a raw GLB with
## a paused animation (`court.gd::make_athlete`) and a tint ring — a placeholder
## that never moved. This view spawns the verified animated rig
## (`src/character/AthleteRig.tscn`, 24 joints, 31,325 triangles, three locomotion
## clips and four strokes) through the documented factory
## `AthleteSpawn.make(athlete_id, outfit_id, opts)`, and drives it once per tick
## from the state the simulation already produced. Nothing here decides anything
## about padel: every value it writes comes from `state.paddle(role)`.
##
## WHAT THE RIG FOLLOWS, EXACTLY:
##   position  — the sim's contact-box centre, through `Court.world_pos`, i.e. the
##               same mapping the ball uses (`match_controller.gd::_sync_views`);
##   facing    — the side's base yaw (player pair +Z, AI pair -Z) plus the sim's own
##               run-phase sway (`sin(runPhase * 0.8) * 7 * motion`), unchanged from
##               the placeholder's formula;
##   gait      — `idle` / `walk` / `run` from `paddle.motion`, with the clip's speed
##               scale set from the same number;
##   stroke    — a one-shot animation on the RISING EDGE of `paddle.swing`, chosen
##               from `paddle.actionIntent` (the sim's own word for the shot).
##
## WHAT IS APPROXIMATED, SAID PLAINLY (also in the evidence file):
##   1. The sim has no per-limb state. The racket's trajectory is the sim's
##      `paddle.swing` ramp, not a solved swing: the rig plays a canned stroke of
##      the right family and the racket rides its hand offset. The stroke's exact
##      contact instant is therefore not the animation's contact frame.
##   2. Facing does not track the ball. The reference's athletes face along their
##      own movement axis, and `face_towards(ball)` was available but is NOT used:
##      using it would change the on-court composition, which is an owner gate.
##   3. The rig is not a physics body. Contact is the sim's contact box; the rig
##      never collides with the ball, the net or the glass.
##   4. All four athletes are the same model, differing by outfit colour only
##      (`docs/wayfinder/evidence/athlete-roster-and-spawn.md`, OD-4). That is the
##      rig lane's finding, not something this view can fix.
##
## COST. `AthleteSpawn.make()` loads three GLBs per rig (base + walk + run), so four
## rigs cost twelve `GLTFDocument` parses at scene setup. This is paid ONCE, and the
## measured numbers are printed by `cost_report()` and recorded in the evidence. No
## per-frame allocation happens in `sync()`: the dictionaries it reads are the
## sim's own, the only writes are node transforms, and `play_locomotion()` is called
## only when the gait actually changes (it restarts the clip).
extends Node3D

const Court := preload("res://game/court.gd")
const AthleteSpawn := preload("res://src/character/athlete_spawn.gd")

const ROLES := ["player", "playerMate", "opponent", "opponentMate"]
## The rig's own gait thresholds, in `paddle.motion` units (0..1).
const WALK_MOTION := 0.08
const RUN_MOTION := 0.55

var rigs: Dictionary = {}            # role -> Node3D
var ids: Dictionary = {}             # role -> athlete id
var outfits: Dictionary = {}         # role -> outfit id
var rackets: Dictionary = {}         # role -> Node3D, on hand bone or legacy rig fallback
var racket_styles: Dictionary = {}   # role -> String, which head that racket was built with
var spawn_ms: float = 0.0
var spawn_rigs: int = 0
var load_errors: int = 0

var _gait: Dictionary = {}           # role -> StringName, so the clip is set once
var _swing_seen: Dictionary = {}     # role -> bool
var _last_stroke: Dictionary = {}    # role -> StringName
var _colors: Dictionary = {}
var _racket_on_hand: Dictionary = {} # role -> bool; only standard Mixamo rigs

## The racket root is the centre of its face. Its grip centre is 0.2405 m below
## that root (`court.gd::make_racket_view`), so +0.24 along the hand/finger axis
## puts the exported RightHand bone in the middle of the grip instead of the face.
const RACKET_HAND_LOCAL := Vector3(0.0, 0.24, 0.0)
const RACKET_HAND_ROTATION := Vector3.ZERO


# ---------------------------------------------------------------------------
# Spawn
# ---------------------------------------------------------------------------

## Spawns one rig per role. Returns how many rigs were actually built: 0 means the
## caller must fall back (the rig's GLBs are unreadable, e.g. a build that did not
## pack `res://assets/athletes/**`). Never leaves a half-built rig behind —
## `AthleteSpawn.make()` returns null rather than a broken node and this view does
## not add a null child.
##
## `styles` is optional and per role: an explicit racket style name
## (`Court.RACKET_STYLE_*`) that OVERRIDES the athlete-id rule. The croissant is
## Fornaio's (`fornaio` -> `cornetto`, `racket_style_for`), so it is chosen from the
## lineup alone; the override exists for a caller that knows the racket but not the id
## — a preview, or a menu holding the prop before the special athlete ships.
func spawn(lineup: Dictionary, outfit_map: Dictionary, colors: Dictionary,
		styles: Dictionary = {}) -> int:
	var started := Time.get_ticks_msec()
	_colors = colors
	spawn_rigs = 0
	for role in ROLES:
		if not lineup.has(role):
			continue
		var athlete: Dictionary = lineup[role]
		var athlete_id := StringName(String(athlete["id"]))
		var outfit_id: StringName = outfit_map.get(role, &"base")
		var rig: Node3D = AthleteSpawn.make(athlete_id, outfit_id, {
			"name": "Rig_%s" % role,
			"position": Vector3.ZERO,
			"facing_degrees": 180.0 if role.begins_with("player") else 0.0,
			"locomotion": &"idle",
		})
		if rig == null:
			load_errors += 1
			continue
		add_child(rig)
		# Standard Meshy/Mixamo athletes carry the racket on the actual wrist bone.
		# The legacy Volpe skeleton is deliberately left on the old body-relative
		# placement; AthleteRig rejects it rather than guessing across incompatible
		# units and axes.
		var racket_parent: Node3D = rig
		var hand_anchor: BoneAttachment3D = rig.make_standard_bone_attachment(
			&"RightHand", StringName("RacketAnchor_%s" % role))
		var on_hand := hand_anchor != null
		if on_hand:
			racket_parent = hand_anchor
		var style: StringName = _racket_style(role, athlete_id, styles)
		var racket := Court.make_racket_view(racket_parent, "Racket_%s" % role, _color_of(role), style)
		if on_hand:
			racket.position = RACKET_HAND_LOCAL
			racket.rotation_degrees = RACKET_HAND_ROTATION
		rigs[role] = rig
		rackets[role] = racket
		racket_styles[role] = String(style)
		_racket_on_hand[role] = on_hand
		ids[role] = String(athlete["id"])
		outfits[role] = String(outfit_id)
		_gait[role] = &"idle"
		_swing_seen[role] = false
		_last_stroke[role] = &""
		spawn_rigs += 1
	spawn_ms = float(Time.get_ticks_msec() - started)
	return spawn_rigs


## Which head an athlete swings: Fornaio the croissant, everyone else the shipped
## ellipse. The special athlete's id is not in the frozen roster yet (the roster lane
## owns that), so this is the one place the id -> racket rule lives, and an explicit
## style name (`spawn(..., styles)`) can say it directly without waiting for the id.
static func racket_style_for(athlete_id: StringName) -> StringName:
	if String(athlete_id) == "fornaio":
		return Court.RACKET_STYLE_CORNETTO
	return Court.RACKET_STYLE_STANDARD


## Explicit style wins; otherwise the athlete id decides; otherwise the ellipse.
func _racket_style(role: String, athlete_id: StringName, styles: Dictionary) -> StringName:
	if styles.has(role):
		return StringName(String(styles[role]))
	return racket_style_for(athlete_id)


func _color_of(role: String) -> Color:
	return _colors.get(role, Color(0.9, 0.9, 0.9))


## Switches one athlete's outfit in place (`AthleteSpawn.set_outfit`, four shader
## uniforms, no allocation). False for an unknown role or a rejected outfit.
func set_outfit(role: String, outfit_id: StringName) -> bool:
	if not rigs.has(role):
		return false
	if not AthleteSpawn.set_outfit(rigs[role], StringName(ids[role]), outfit_id):
		return false
	outfits[role] = String(outfit_id)
	return true


# ---------------------------------------------------------------------------
# Per-tick sync
# ---------------------------------------------------------------------------

## Writes this tick's state onto every rig. Reads the sim, allocates nothing in
## the steady state (the only allocation is on an outfit change, which is a menu
## action, not a tick).
func sync(state) -> void:
	if rigs.is_empty() or state == null:
		return
	for role in ROLES:
		if not rigs.has(role):
			continue
		var paddle = state.paddle(role)
		var rig: Node3D = rigs[role]
		rig.position = Court.world_pos(paddle.x, paddle.y, 0.0)
		# Facing: the side's base yaw plus the sim's own run-phase sway.
		var base_yaw: float = 180.0 if role.begins_with("player") else 0.0
		var sway: float = sin(float(paddle.runPhase) * 0.8) * 7.0 * float(paddle.motion)
		rig.set_facing_degrees(base_yaw + sway)
		_sync_gait(role, rig, paddle)
		_sync_stroke(role, rig, paddle)
		_sync_racket(role, paddle)


func _sync_gait(role: String, rig: Node3D, paddle) -> void:
	var motion := float(paddle.motion)
	var want: StringName = &"idle"
	if motion > RUN_MOTION:
		want = &"run"
	elif motion > WALK_MOTION:
		want = &"walk"
	if _gait[role] != want:
		_gait[role] = want
		rig.play_locomotion(want)
	rig.set_locomotion_speed_scale(clampf(motion, 0.25, 2.0))


## The stroke is a one-shot on the rising edge of `paddle.swing`. `actionIntent`
## is the sim's own word for the shot; the mapping onto the rig's four strokes is
## this view's, and it is the only place it decides anything.
func _sync_stroke(role: String, rig: Node3D, paddle) -> void:
	var swinging := float(paddle.swing) > 0.0
	if swinging and not _swing_seen[role]:
		var stroke := stroke_for(String(paddle.actionIntent))
		if rig.play_stroke(stroke):
			_last_stroke[role] = stroke
	_swing_seen[role] = swinging


## `actionIntent` (`js/game.js`) -> the rig's own stroke vocabulary
## (`athlete_rig.gd::STROKE_SPECS`: drive / slice / lob / serve).
static func stroke_for(intent: String) -> StringName:
	var word := intent.to_lower()
	if word.contains("serve"):
		return &"serve"
	if word.contains("slice") or word.contains("vibora") or word.contains("chiquita"):
		return &"slice"
	if word.contains("lob") or word.contains("globo"):
		return &"lob"
	return &"drive"


## The racket rides the athlete's hand: the same numbers the previous slice used
## (`court.gd::HAND_*`), now in the rig's LOCAL frame so the athlete's yaw carries
## it. `paddle.swingSide` is the sim's own answer to which side the swing is on.
##
## The local frame makes the "towards the net" sign the same for both sides: the
## player's pair is yawed 180 deg, so its local +Z already points at the net, and
## the AI's pair is yawed 0 with the net on its +Z too. The hand offset is
## therefore +HAND_FWD for all four athletes, and the previous slice's
## `-1 / +1` per side cancels out exactly.
##
## In WORLD terms nothing changed: `HAND_FWD` still lands the racket between the
## athlete and the net, which the slice test asserts as a distance, not a sign.
func _sync_racket(role: String, paddle) -> void:
	var view: Node3D = rackets[role]
	# A BoneAttachment3D already follows the animated wrist, including authored
	# strokes. Reapplying the old procedural body offset here would detach it again.
	if bool(_racket_on_hand.get(role, false)):
		return
	var swing: float = clampf(float(paddle.swing), 0.0, 1.0)
	var swing_side: float = -1.0 if float(paddle.swingSide) < 0.0 else 1.0
	view.position = Vector3(
		swing_side * Court.HAND_SIDE * (1.0 + swing * 0.6),
		Court.HAND_H + swing * Court.HAND_SWING_LIFT,
		Court.HAND_FWD
	)
	view.rotation_degrees = Vector3(-18.0 - swing * 40.0, 0.0, swing_side * (18.0 + swing * 30.0))


# ---------------------------------------------------------------------------
# Reports
# ---------------------------------------------------------------------------

func rig(role: String) -> Node3D:
	return rigs.get(role, null)


## What was actually spawned, read back off the nodes rather than from what this
## view remembers. For the slice test and the evidence dump.
func describe_all() -> Dictionary:
	var out := {}
	for role in rigs:
		var d: Dictionary = AthleteSpawn.describe(rigs[role])
		d["athlete_id"] = ids[role]
		d["outfit_id"] = outfits[role]
		d["racket_style"] = racket_styles.get(role, "standard")
		d["gait"] = String(_gait[role])
		d["last_stroke"] = String(_last_stroke[role])
		out[role] = d
	return out


func cost_report() -> Dictionary:
	return {
		"rigs": spawn_rigs,
		"spawn_ms": spawn_ms,
		"glb_loads": spawn_rigs * 3,
		"load_errors": load_errors,
	}
