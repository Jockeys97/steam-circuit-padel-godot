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
##      What follows the ball is the chest and head only (`rig.set_look_yaw`,
##      owner-approved 2026-09-23): feet, hips and facing keep the composition.
##   2b. Anticipation. The sim reports a stroke on its contact tick only, so the
##      athlete the ball is flying to winds the racket back beforehand
##      (`rig.set_anticipation`, towards the predicted stroke's own backswing),
##      purely from the ball's current position/velocity; the stroke still starts
##      at its contact frame.
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
const Frozen := preload("res://src/sim/frozen.gd") # read-only: ballGravity

const ROLES := ["player", "playerMate", "opponent", "opponentMate"]
## The rig's own gait thresholds, in `paddle.motion` units (0..1).
const WALK_MOTION := 0.08
const RUN_MOTION := 0.55
## Anticipation starts this many seconds before the ball reaches the athlete's
## line and is full at ANTICIPATION_FULL_S. A drive's authored backswing is
## ~0.2 s ahead of contact, so the wind-up spans roughly one backswing.
const ANTICIPATION_START_S := 0.42
const ANTICIPATION_FULL_S := 0.10
## Sim units (px) of horizontal slack beyond half the paddle width: a ball
## further than that from the athlete at their line is not theirs to prepare.
const ANTICIPATION_REACH_PX := 70.0
## Lateral px/s the athlete is credited with while closing on the ball; a
## measured contact arrived from 232 px off with 0.33 s to go (~440 px/s).
const ANTICIPATION_CLOSE_PX_S := 520.0
## Predicted contact height (sim px) above which the wind-up is an overhead.
const OVERHEAD_HEIGHT_PX := 70.0
## Smoothing rates (1/s) of the two layers; frame-rate independent.
const ANTICIPATION_RATE := 16.0
const LOOK_RATE := 9.0
## A ball this far behind the athlete fades the look back to the facing.
const LOOK_FADE_FROM_DEG := 110.0
const LOOK_FADE_TO_DEG := 160.0

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
## Whether the point now in its pause earns the cheer/dejected pair. Decided once,
## on the pause's first frame (`_note_point`), so a whole pause shows one answer.
var _celebrate_point := true
var _in_point_pause := false
var _rally_peak := 0
var _score_mark := 0
var _last_stroke: Dictionary = {}    # role -> StringName
var _colors: Dictionary = {}
var _previous_positions: Dictionary = {}
var _visual_velocity: Dictionary = {}
var _visual_lean: Dictionary = {}
var _split_remaining: Dictionary = {}
var _recovery_remaining: Dictionary = {}
var _was_stroking: Dictionary = {}
var _previous_hitter: String = ""
var _anticipation: Dictionary = {}   # role -> float, smoothed weight
var _look: Dictionary = {}           # role -> float, smoothed degrees
var _chase_turn: Dictionary = {}     # role -> float 0..1, turned towards the back glass
var _chase_sign: Dictionary = {}     # role -> +1/-1, which shoulder the turn goes over
var _chase_hold: Dictionary = {}     # role -> seconds the turn survives a pause
var _reach: Dictionary = {}          # role -> Vector2, smoothed stretch sent to the rig
var _stroke_reach: Dictionary = {}   # role -> Vector2, the stretch this stroke met the ball with
var _stroke_age: Dictionary = {}     # role -> seconds since the stroke started
var _anticipation_reach: Dictionary = {} # role -> Vector2, stretch towards the guessed contact
var _lunging: Dictionary = {}        # role -> bool, this stroke is the generated lunge
## The ball's `postGlassSide` as the previous sync saw it: the sim clears it on the
## strike, so the swing edge reads it from here (wall exit, 2026-09-24).
var _glass_side_seen := ""
const LUNGE_MIN_STRETCH := 0.5       # half-way into the stretch band (~1.0 m to the side)
const LUNGE_CONTACT_PHASE := 0.30    # bake_meshy_fiamma.gd contacts["lunge_forehand"]
const LUNGE_BLEND_S := 0.08
## The Meshy-cut volleys' contact (their bake's `contacts`, 0.42 of 0.50 s).
const VOLLEY_CONTACT_PHASE := 0.42
## The Meshy-cut lobs' contact (their bake's `contacts`, 0.36 of 0.60 s).
const LOB_CONTACT_PHASE := 0.36
const WALL_EXIT_CONTACT_PHASE := 0.34  # bake_meshy_fiamma.gd contacts["wall_exit_forehand"]
var _racket_on_hand: Dictionary = {} # role -> bool; standard and legacy rigs

## The racket root is the centre of its face. Its grip centre is 0.2405 m below
## that root (`court.gd::make_racket_view`). Another 6 cm along the hand axis
## seats the grip inside the palm rather than centring it on the wrist joint.
const RACKET_HAND_LOCAL := Vector3(0.0, 0.30, 0.0) # grip centre 6 cm into the palm
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
	_previous_hitter = ""
	_previous_positions.clear()
	_visual_velocity.clear()
	_visual_lean.clear()
	_recovery_remaining.clear()
	_was_stroking.clear()
	_anticipation.clear()
	_look.clear()
	_chase_turn.clear()
	_chase_sign.clear()
	_chase_hold.clear()
	_reach.clear()
	_stroke_reach.clear()
	_stroke_age.clear()
	_anticipation_reach.clear()
	_lunging.clear()
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
		# Both skeleton families use +Y along the hand. Legacy exports are in cm;
		# compensate only the internal skeleton scale, preserving athlete scaling.
		var racket_parent: Node3D = rig
		var hand_anchor: BoneAttachment3D = rig.make_hand_attachment(
			StringName("RacketAnchor_%s" % role))
		var on_hand := hand_anchor != null
		if on_hand:
			racket_parent = hand_anchor
		var style: StringName = _racket_style(role, athlete_id, styles)
		var racket := Court.make_racket_view(racket_parent, "Racket_%s" % role, _color_of(role), style)
		if on_hand:
			var skeleton: Skeleton3D = rig.get_skeleton()
			var chain := Transform3D.IDENTITY
			var ancestor: Node = skeleton
			while ancestor != rig and ancestor is Node3D:
				chain = (ancestor as Node3D).transform * chain
				ancestor = ancestor.get_parent()
			var internal_scale := chain.basis.get_scale()
			var unit_scale := Vector3.ONE / internal_scale
			racket.scale = unit_scale
			racket.position = RACKET_HAND_LOCAL * unit_scale
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
		_split_remaining[role] = 0.0
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
func sync(state, delta: float = -1.0) -> void:
	_note_point(state)
	if rigs.is_empty() or state == null:
		return
	if delta < 0.0:
		delta = minf(get_process_delta_time(), 0.05)
	var hitter := String(state.lastHitterSide) if state.lastHitterSide != null else ""
	var new_return: bool = hitter != "" and hitter != _previous_hitter and not state.serving
	_previous_hitter = hitter
	for role in ROLES:
		if not rigs.has(role):
			continue
		var paddle = state.paddle(role)
		var rig: Node3D = rigs[role]
		rig.position = Court.world_pos(paddle.x, paddle.y, 0.0)
		# Facing: the side's base yaw plus the sim's own run-phase sway.
		var base_yaw: float = 180.0 if role.begins_with("player") else 0.0
		var sway: float = sin(float(paddle.runPhase) * 0.8) * 7.0 * float(paddle.motion)
		var current := Vector2(paddle.x, paddle.y)
		var movement: Vector2 = current - _previous_positions.get(role, current)
		_previous_positions[role] = current
		# Teleports between points are not a running direction.
		var teleported: bool = movement.length() > 30.0
		var reset_movement: bool = teleported or state.serving
		if teleported:
			movement = Vector2.ZERO
		# Chasing a lob that went over: turn and run to the glass instead of backing up
		# five metres facing the net. Presentation only; the sim position is untouched.
		var chase := _sync_chase_turn(role, rig, paddle, state, movement, delta, reset_movement)
		rig.set_facing_degrees(base_yaw + sway * (1.0 - 2.0 * chase) + 180.0 * chase * float(_chase_sign.get(role, 1.0)))
		if reset_movement:
			_visual_velocity[role] = Vector2.ZERO
			_visual_lean[role] = Vector2.ZERO
			rig.clear_low_contact()
		var receiving: bool = (hitter == "ai") if role.begins_with("player") else (hitter == "player")
		if new_return and receiving and movement.length() < 0.01 and not rig.is_stroking():
			_split_remaining[role] = 0.28
		_split_remaining[role] = maxf(0.0, float(_split_remaining[role]) - delta)
		_recovery_remaining[role] = maxf(0.0, float(_recovery_remaining.get(role, 0.0)) - delta)
		if _was_stroking.get(role, false) and not rig.is_stroking():
			_recovery_remaining[role] = 0.34
		# Moving input wins immediately. No hop while running, no balance step
		# delaying a new shot, and no stale transient crossing a point reset.
		if reset_movement or movement.length() > 0.01 or float(paddle.swing) > 0.0:
			_split_remaining[role] = 0.0
			_recovery_remaining[role] = 0.0
		var prepare: bool = not state.serving and (float(paddle.charge) > 0.05 or (receiving and float(paddle.motion) < WALK_MOTION))
		if not state.serving and role == state.activePlayerKey and float(state.shotCharge) > 0.05:
			prepare = true
		if float(paddle.charge) > 0.05 or (role == state.activePlayerKey and float(state.shotCharge) > 0.05):
			_split_remaining[role] = 0.0
			_recovery_remaining[role] = 0.0
		_sync_gait(role, rig, paddle, movement, prepare, delta, ceremony_for(role, state, paddle, _celebrate_point))
		_sync_stroke(role, rig, paddle, float(state.ball.x), float(state.ball.z) if not reset_movement else NAN,
			_glass_side_seen == ("player" if role.begins_with("player") else "ai"))
		if rig.is_stroking() and not _was_stroking.get(role, false):
			_stroke_reach[role] = Vector2.ZERO if String(paddle.actionIntent).contains("serve") or bool(_lunging.get(role, false)) \
				else reach_towards(role, float(paddle.x), float(state.ball.x))
			_stroke_age[role] = 0.0
		_was_stroking[role] = rig.is_stroking()
		_sync_movement_weight(role, rig, movement, delta, reset_movement)
		_sync_anticipation(role, rig, paddle, state, delta, reset_movement)
		_sync_look(role, rig, state, delta, teleported)
		_sync_reach(role, rig, delta, reset_movement)
		# Small visual split step; never changes the simulated paddle coordinates.
		var lift := sin(float(_split_remaining[role]) / 0.28 * PI) * 0.025
		rig.set_split_step_lift(lift if receiving and not state.serving and not rig.is_stroking() else 0.0)
		_sync_racket(role, paddle)
	_glass_side_seen = String(state.ball.postGlassSide) if state.ball.postGlassSide != null else ""


func _sync_gait(role: String, rig: Node3D, paddle, movement := Vector2.ZERO, prepare := false, delta: float = 1.0 / 60.0, ceremony: StringName = &"") -> void:
	var motion := float(paddle.motion)
	var want: StringName = &"ready"
	var moving: bool = movement.length() > 0.01
	if moving and motion > RUN_MOTION:
		want = &"run"
	elif moving:
		want = &"walk"
	if moving:
		var forward := -movement.y if role.begins_with("player") else movement.y
		var lateral := -movement.x if role.begins_with("player") else movement.x
		# Hysteresis avoids restarting clips at every tiny diagonal stick change.
		var lateral_threshold := 1.15 if _gait[role] in [&"shuffle_left", &"shuffle_right"] else 1.4
		var retreat_threshold := 0.6 if _gait[role] == &"backpedal" else 0.75
		if absf(lateral) > absf(forward) * lateral_threshold:
			want = &"shuffle_left" if lateral < 0.0 else &"shuffle_right"
		elif forward < -absf(lateral) * retreat_threshold:
			want = &"backpedal"
	elif prepare:
		want = &"prepare"
	# Motion is the simulation's smoothed activity signal. Only show settling
	# when translation has stopped; never delay or move the simulated paddle.
	elif motion > 0.03 and movement.length() < 0.01:
		want = &"brake"
	if moving and float(_chase_turn.get(role, 0.0)) > 0.5:
		want = &"run"
	if not moving and not rig.is_stroking():
		if float(_split_remaining.get(role, 0.0)) > 0.0:
			want = &"split_step"
		elif float(_recovery_remaining.get(role, 0.0)) > 0.0:
			want = &"recover_left" if "backhand" in String(_last_stroke.get(role, "")) else &"recover_right"
	# Dead-ball body language wins over the ready stance, never over real movement
	# or a stroke in flight: an athlete walking back to position keeps walking.
	if ceremony != &"" and not moving and not rig.is_stroking() and ceremony in rig.get_locomotion_states():
		want = ceremony
	if _gait[role] != want:
		_gait[role] = want
		rig.play_locomotion(want)
	# Cadence follows actual court distance, including stamina-limited movement.
	# Imported forward running covers more distance per cycle than small shuffles.
	var speed: float = _movement_velocity(role, movement, delta).length()
	var reference_speed := 4.2 if want == &"run" else 2.6
	rig.set_locomotion_speed_scale(1.0 if want in [&"idle", &"ready", &"brake", &"prepare", &"split_step", &"recover_left", &"recover_right", &"cheer", &"dejected", &"serve_bounce"] else clampf(speed / reference_speed, 0.55, 1.8))
	if movement.length() > 0.01:
		rig.recover_to_movement()


## Chase turn (2026-09-24): an athlete retreating while the ball will come down
## well behind them (a lob that is going over) turns its back to the net and runs,
## like a player who has read the lob. It turns back to the net once it is nearly
## at the landing spot, stops, or strikes. Returns the smoothed 0..1 turn; the sim
## never reads it.
const CHASE_TURN_RATE := 11.0     # ~0.2 s for a half turn
const CHASE_START_PX := 45.0      # landing this much deeper than the athlete starts it
const CHASE_KEEP_PX := 12.0       # ...and it holds until this close
const CHASE_HOLD_S := 0.12        # a pause in the run shorter than this keeps the turn
const CHASE_FACE_BACK_S := 0.4    # this long before the ball lands, face the net again
func _sync_chase_turn(role: String, rig: Node3D, paddle, state, movement: Vector2, delta: float, reset: bool) -> float:
	var turn: float = float(_chase_turn.get(role, 0.0))
	var want := 0.0
	var hold: float = maxf(0.0, float(_chase_hold.get(role, 0.0)) - delta)
	if not reset and not rig.is_stroking() and movement.length() > 0.01:
		var near_side := role.begins_with("player")
		var net_y := float(Frozen.court()["netY"])
		var forward := -movement.y if near_side else movement.y
		var retreating: bool = forward < 0.0 and -forward > absf(movement.x) * 0.75
		# Only a ball still in the air towards this side is chased: once it has bounced
		# here the athlete waits for it facing the net, as it must to strike.
		var bounced_here: bool = int(state.ball.bounces["player" if near_side else "ai"]) > 0
		var landing := NAN if bounced_here or landing_time(state.ball) < CHASE_FACE_BACK_S else landing_y(state.ball)
		var moving_on: bool = float(paddle.motion) > (WALK_MOTION if turn > 0.5 else RUN_MOTION)
		if retreating and moving_on and is_finite(landing):
			var land_depth: float = (landing - net_y) if near_side else (net_y - landing)
			var own_depth: float = (float(paddle.y) - net_y) if near_side else (net_y - float(paddle.y))
			if land_depth - own_depth > (CHASE_KEEP_PX if turn > 0.5 else CHASE_START_PX):
				want = 1.0
				hold = CHASE_HOLD_S
				if turn < 0.01:
					# Turn over the shoulder on the ball's side (mirrored for the far team).
					var side := (float(state.ball.x) - float(paddle.x)) * (1.0 if near_side else -1.0)
					_chase_sign[role] = 1.0 if side >= 0.0 else -1.0
	if reset or rig.is_stroking():
		hold = 0.0
	elif want == 0.0 and hold > 0.0 and turn > 0.5 and int(state.ball.bounces["player" if role.begins_with("player") else "ai"]) == 0 \
			and landing_time(state.ball) >= CHASE_FACE_BACK_S:
		want = 1.0 # a stutter in the run, not the end of the chase
	_chase_hold[role] = hold
	turn = want if reset else lerpf(turn, want, 1.0 - exp(-CHASE_TURN_RATE * delta))
	if absf(turn - want) < 0.01:
		turn = want
	_chase_turn[role] = turn
	return turn


## Where an airborne ball first comes down (plain ballistics, no drag or walls);
## NAN when it is on the ground or has already bounced on the side it is over.
static func landing_y(ball) -> float:
	var t := landing_time(ball)
	return float(ball.y) + float(ball.vy) * t if is_finite(t) else NAN


## Seconds until an airborne ball first comes down; NAN on the ground.
static func landing_time(ball) -> float:
	var z := float(ball.z)
	var vz := float(ball.vz)
	if z <= 1.0 and vz <= 0.0:
		return NAN
	var g := float(Frozen.balance()["ballGravity"])
	return (vz + sqrt(maxf(0.0, vz * vz + 2.0 * g * z))) / g


## The stretch (2026-09-24): a ball met at the edge of the reach is struck leaning
## over the lead foot. It grows with the anticipation towards the guessed contact,
## peaks at the stroke's first frame (contact), and fades through the follow-through.
## Lateral only: at the swing the sim has already moved the ball in front of the
## racket, so only its x still says where it was met. Presentation only.
# Measured on scripted rallies: the sim meets balls up to ~1.2 m to the side (arm and
# racket), and most strokes land within 0.7 m; the stretch is for the last third.
const REACH_START_M := 0.85   # closer than this the ball is comfortable
const REACH_FULL_M := 1.20    # the edge of the sim's contact width
const REACH_RATE := 16.0
func _sync_reach(role: String, rig: Node3D, delta: float, reset: bool) -> void:
	if not rig.has_method("set_stroke_reach"):
		return
	var target := Vector2.ZERO
	if not reset:
		if rig.is_stroking():
			var age: float = float(_stroke_age.get(role, 0.0)) + delta
			_stroke_age[role] = age
			target = _stroke_reach.get(role, Vector2.ZERO) * (1.0 - smoothstep(0.10, 0.42, age))
		else:
			target = _anticipation_reach.get(role, Vector2.ZERO)
	var reach: Vector2 = _reach.get(role, Vector2.ZERO)
	reach = target if reset else reach.lerp(target, 1.0 - exp(-REACH_RATE * delta))
	if reach.length() < 0.005 and target == Vector2.ZERO:
		reach = Vector2.ZERO
	_reach[role] = reach
	rig.set_stroke_reach(reach)


## Side stretch towards a ball at `ball_x`, in the team's facing frame (the rig's
## local x), 0 when comfortable and 1 at the edge of the reach.
func reach_towards(role: String, paddle_x: float, ball_x: float) -> Vector2:
	var d := Court.world_pos(ball_x, 0.0, 0.0) - Court.world_pos(paddle_x, 0.0, 0.0)
	var side: float = d.x * (-1.0 if role.begins_with("player") else 1.0)
	# A ball far beyond any racket is not a contact being stretched for (no stroke in
	# the sim meets one): no stretch rather than a full one.
	if absf(side) > REACH_FULL_M * 1.6:
		return Vector2.ZERO
	var amount := clampf((absf(side) - REACH_START_M) / (REACH_FULL_M - REACH_START_M), 0.0, 1.0)
	return Vector2(signf(side) * amount, 0.0)


## Metres/second in each team's facing frame; this never feeds the simulation.
func _movement_velocity(role: String, movement: Vector2, delta: float) -> Vector2:
	if delta <= 0.0:
		return Vector2.ZERO
	var world := Court.world_pos(movement.x, movement.y, 0.0) - Court.world_pos(0.0, 0.0, 0.0)
	var facing := -1.0 if role.begins_with("player") else 1.0
	return Vector2(world.x, world.z) * facing / delta


func _sync_movement_weight(role: String, rig: Node3D, movement: Vector2, delta: float, reset: bool) -> void:
	if delta <= 0.0:
		return
	var velocity := _movement_velocity(role, movement, delta).limit_length(8.0)
	if float(_chase_turn.get(role, 0.0)) > 0.5:
		velocity = -velocity # the body faces the glass: its own frame is reversed
	var previous: Vector2 = _visual_velocity.get(role, Vector2.ZERO)
	_visual_velocity[role] = velocity
	# A short acceleration impulse sells starts/stops and reversals. Exponential
	# smoothing is frame-rate independent; angles are capped to protect footing.
	var acceleration := ((velocity - previous) / delta).limit_length(18.0)
	var target := (velocity * 0.55 + acceleration * 0.22).limit_length(6.0)
	var lean: Vector2 = _visual_lean.get(role, Vector2.ZERO)
	lean = lean.lerp(target, 1.0 - exp(-12.0 * delta))
	if reset or rig.is_stroking():
		lean = Vector2.ZERO
	_visual_lean[role] = lean
	rig.set_movement_lean(lean)


## The stroke is a one-shot on the rising edge of `paddle.swing`. `actionIntent`
## is the sim's own word for the shot; the mapping onto the rig's four strokes is
## this view's, and it is the only place it decides anything.
func _sync_stroke(role: String, rig: Node3D, paddle, ball_x: float = NAN, ball_height: float = NAN, off_own_glass: bool = false) -> void:
	var swinging := float(paddle.swing) > 0.0
	if swinging and not _swing_seen[role]:
		var recipe := stroke_recipe(String(paddle.actionIntent))
		var stroke: StringName = recipe["clip"]
		var imported := meshy_stroke_for(String(paddle.actionIntent), role, float(paddle.x), ball_x)
		if imported in rig.get_stroke_names():
			stroke = imported
		var contact_phase := float(recipe["contact_phase"])
		var speed_scale := float(recipe["speed_scale"])
		var blend := 0.0
		# A stretched contact below head height bends the legs like a low one (the
		# lunge's crouch); a high ball is reached for, not crouched under.
		var low_enough: bool = is_finite(ball_height) and ball_height < OVERHEAD_HEIGHT_PX \
			and not String(paddle.actionIntent).contains("serve") \
			and low_contact_amount(String(paddle.actionIntent), 0.0) > 0.0
		var stretch := reach_towards(role, float(paddle.x), ball_x).length() if is_finite(ball_x) and low_enough else 0.0
		var low := maxf(low_contact_amount(String(paddle.actionIntent), ball_height), stretch * 0.67)
		# A forehand at the edge of the reach is the generated lunge (2026-09-24): it
		# carries its own step and pelvis drop, so no extra crouch and no slide.
		_lunging[role] = false
		if stroke == &"meshy_drive" and stretch >= LUNGE_MIN_STRETCH and &"meshy_lunge_forehand" in rig.get_stroke_names():
			stroke = &"meshy_lunge_forehand"
			contact_phase = LUNGE_CONTACT_PHASE
			speed_scale = 1.0
			low = 0.0
			blend = LUNGE_BLEND_S
			_lunging[role] = true
		# A forehand met coming back off one's own back glass is the generated wall exit.
		if not _lunging[role] and off_own_glass and stroke in [&"meshy_drive", &"meshy_slice", &"drive", &"slice"] \
				and &"meshy_wall_exit_forehand" in rig.get_stroke_names() and not is_backhand_side(role, float(paddle.x), ball_x):
			stroke = &"meshy_wall_exit_forehand"
			contact_phase = WALL_EXIT_CONTACT_PHASE
			speed_scale = 1.0
			blend = LUNGE_BLEND_S
		# A volley is cut from the Meshy drive/backhand (2026-09-26), by contact side;
		# PADEL_MESHY_VOLLEY=0 keeps the hand-authored one, to compare in a match.
		if stroke == &"volley" and OS.get_environment("PADEL_MESHY_VOLLEY") != "0":
			var volley_clip := &"meshy_backhand_volley" if is_backhand_side(role, float(paddle.x), ball_x) else &"meshy_forehand_volley"
			if volley_clip in rig.get_stroke_names():
				stroke = volley_clip
				contact_phase = VOLLEY_CONTACT_PHASE
				speed_scale = 1.0
				low = 0.0
				blend = LUNGE_BLEND_S
		# The lob likewise (2026-09-26): cut from the Meshy drive/backhand, low contact and
		# a high finish in front. PADEL_MESHY_LOB=0 keeps the hand-authored one.
		if stroke == &"lob" and OS.get_environment("PADEL_MESHY_LOB") != "0":
			var lob_clip := &"meshy_backhand_lob" if is_backhand_side(role, float(paddle.x), ball_x) else &"meshy_forehand_lob"
			if lob_clip in rig.get_stroke_names():
				stroke = lob_clip
				contact_phase = LOB_CONTACT_PHASE
				speed_scale = 1.0
				blend = LUNGE_BLEND_S
		var played: bool = rig.play_stroke_at(stroke, contact_phase, speed_scale, low, blend) \
			if rig.has_method("play_stroke_at") else rig.play_stroke(stroke)
		if played:
			_last_stroke[role] = stroke
	_swing_seen[role] = swinging


## Anticipation: the athlete the ball is flying to winds up before contact.
## Reads the ball's position and velocity only (a ballistic guess, no bounce
## modelling); the simulation decides whether and how the shot happens.
func _sync_anticipation(role: String, rig: Node3D, paddle, state, delta: float, reset: bool) -> void:
	if not rig.has_method("set_anticipation"):
		return
	var target := 0.0
	var stroke: StringName = &""
	var contact_phase := 0.5
	var guess := _contact_guess(role, paddle, state)
	if not reset and not guess.is_empty() and not rig.is_stroking() and float(_chase_turn.get(role, 0.0)) < 0.5:
		var t: float = guess["t"]
		target = 1.0 - smoothstep(ANTICIPATION_FULL_S, ANTICIPATION_START_S, t)
		_anticipation_reach[role] = reach_towards(role, float(paddle.x), float(guess["x"])) * target
		var recipe := anticipation_stroke(rig.get_stroke_names(), role, float(paddle.x), float(guess["x"]), float(guess["z"]))
		stroke = recipe["clip"]
		contact_phase = float(recipe["contact_phase"])
		# A forehand coming back off one's own back glass winds up as the wall exit
		# (2026-09-24): side-on, racket back, waiting. The stroke itself starts at
		# contact, so without this the wall exit read as a plain drive.
		var side := "player" if role.begins_with("player") else "ai"
		var off_glass: bool = state.ball.postGlassSide != null and String(state.ball.postGlassSide) == side \
			and (float(state.ball.vy) < 0.0 if side == "player" else float(state.ball.vy) > 0.0)
		if off_glass and &"meshy_wall_exit_forehand" in rig.get_stroke_names() \
				and not is_backhand_side(role, float(paddle.x), float(guess["x"])) and float(guess["z"]) < OVERHEAD_HEIGHT_PX:
			stroke = &"meshy_wall_exit_forehand"
			contact_phase = WALL_EXIT_CONTACT_PHASE
		# A clip with no frame that reads as a preparation would silently drop the
		# wind-up: fall back to one that has it (the smash, e.g., on a rig whose
		# overhead clip holds only the strike).
		stroke = anticipation_fallback(rig, stroke, contact_phase)
		if stroke == &"":
			target = 0.0
	if target == 0.0:
		_anticipation_reach[role] = Vector2.ZERO
	var weight: float = float(_anticipation.get(role, 0.0))
	if reset or rig.is_stroking():
		weight = 0.0
	else:
		weight = lerpf(weight, target, 1.0 - exp(-ANTICIPATION_RATE * delta))
		if weight < 0.01 and target == 0.0:
			weight = 0.0
	_anticipation[role] = weight
	if stroke == &"":
		stroke = StringName(rig.get_anticipation()["stroke"])
		contact_phase = float(rig.get_anticipation().get("contact_phase", 0.34))
	rig.set_anticipation(stroke, weight, contact_phase)


## Rallies this long earn the celebration even on an ordinary point.
const LONG_RALLY_HITS := 6


## Not every point is a celebration: the owner found a cheer on every point would get
## old fast. The pair plays when the point MEANT something — it closed a game or a
## set (the score's own totals moved), or it ended a long rally. The match result
## always celebrates (`ceremony_for` checks `result` before this). Deterministic, no
## dice: the same match shows the same celebrations, and a test can predict them.
static func celebrates(score_before: int, score_after: int, rally_peak: int) -> bool:
	return score_after != score_before or rally_peak >= LONG_RALLY_HITS


## Games and sets folded into one number that changes exactly when either does.
static func score_mark(state) -> int:
	return int(state.games["player"]) + int(state.games["ai"]) \
		+ 1000 * (int(state.sets["player"]) + int(state.sets["ai"]))


## Called once per sync. While the ball is live it keeps the rally's peak hit count
## and the score as it stood; on the pause's first frame it compares, decides, and
## resets. `rallyHits` is zeroed by `score_point` before the pause starts, which is
## why the peak is kept here rather than read then.
func _note_point(state) -> void:
	if float(state.pointPause) <= 0.0:
		_in_point_pause = false
		_rally_peak = maxi(_rally_peak, int(state.rallyHits))
		_score_mark = score_mark(state)
		return
	if _in_point_pause:
		return
	_in_point_pause = true
	_celebrate_point = celebrates(_score_mark, score_mark(state), _rally_peak)
	_rally_peak = 0


## Where the ball is DRAWN during the server's bounce ritual, or null when the
## simulation's own position stands. Presentation only: the simulation keeps its
## ball parked beside the server (`sim.gd` prepare_serve) and never sees this. The
## drawn ball follows the left hand and drops to the floor and back once per loop
## of `serve_bounce`, so ball and hand share one clock: the clip's own position.
func serve_ball_override(state) -> Variant:
	if not bool(state.serving) or float(state.pointPause) > 0.0 or state.result != null:
		return null
	var role := "player" if String(state.serveSide) == "player" else "opponent"
	var rig: Node3D = rigs.get(role, null)
	if rig == null or not rig.is_inside_tree():
		return null
	var anim: AnimationPlayer = rig.get("_anim")
	if anim == null or anim.current_animation != "serve_bounce":
		return null
	var length := maxf(anim.current_animation_length, 0.001)
	var phase := fposmod(anim.current_animation_position / length, 1.0)
	var skeleton: Skeleton3D = rig.get_skeleton()
	var bone := skeleton.find_bone(rig._resolve_bone_name("LeftHand"))
	if bone < 0:
		return null
	var hand: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(bone).origin
	# In the hand at the loop's ends, on the floor at its middle.
	var height := Court.BALL_R + (hand.y - Court.BALL_R) * absf(cos(phase * PI))
	return Vector3(hand.x, maxf(Court.BALL_R, height), hand.z)


## Which dead-ball clip this athlete owes (`athlete_rig.gd::CEREMONIES`), or &""
## while the ball is live. A pure read of the simulation, which stays the only
## authority on who won what:
##   - the match result: `state.result.winner` ("player" | "ai", `sim.gd:1959`);
##   - the point: the 1.4 s `pointPause` and its `pointMessage`, which begins with
##     "pointYou" or "pointOpp" (`sim.gd:2039`). A LET has no winner and owes nothing;
##   - the serve wait: the server is `player` or `opponent` by `serveSide`
##     (`sim.gd` prepare_serve), and bounces the ball until they start charging.
static func ceremony_for(role: String, state, paddle, celebrate_point := true) -> StringName:
	var near_team := role.begins_with("player")
	if state.result != null:
		var winner := String((state.result as Dictionary).get("winner", ""))
		if winner == "":
			return &""
		return &"cheer" if (winner == "player") == near_team else &"dejected"
	if float(state.pointPause) > 0.0:
		if not celebrate_point:
			return &""
		var message := String(state.pointMessage)
		if message.begins_with("pointYou"):
			return &"cheer" if near_team else &"dejected"
		if message.begins_with("pointOpp"):
			return &"dejected" if near_team else &"cheer"
		return &""
	if state.serving:
		var server := "player" if String(state.serveSide) == "player" else "opponent"
		var charging := float(paddle.charge) > 0.05 \
			or (role == String(state.activePlayerKey) and float(state.shotCharge) > 0.05)
		if role == server and not charging:
			return &"serve_bounce"
	return &""


## Time (s), x and height (sim px) at which the ball reaches this athlete's line,
## or {} when it is not coming to them (wrong direction, behind them, or their
## partner is closer to it). Pure read of the state.
func _contact_guess(role: String, paddle, state) -> Dictionary:
	if state.serving or float(state.pointPause) > 0.0 or state.result != null:
		return {}
	var ball = state.ball
	var near_team := role.begins_with("player")
	var vy := float(ball.vy)
	if (near_team and vy <= 28.0) or (not near_team and vy >= -28.0):
		return {}
	# Contact happens when the ball enters the athlete's depth reach
	# (`Sim.can_hit`: |ball.y - paddle.y| < reach * depthReach), not at the line.
	var balance: Dictionary = Frozen.balance()
	var depth_reach: float = float(paddle.reach) * float(balance["playerDepthReach"] if paddle.isPlayer else balance["aiDepthReach"])
	var gap := (float(paddle.y) - float(ball.y)) * (1.0 if near_team else -1.0)
	if gap <= 0.0:
		return {}
	var t := maxf(0.0, gap - depth_reach) / absf(vy)
	if not is_finite(t) or t > ANTICIPATION_START_S:
		return {}
	var x := float(ball.x) + float(ball.vx) * t
	var g := float(balance["ballGravity"])
	var z := maxf(0.0, float(ball.z) + float(ball.vz) * t - 0.5 * g * t * t)
	# The athlete is still running to the ball: allow what they can cover in t.
	var mine := absf(x - float(paddle.x))
	if mine > float(paddle.w) * 0.5 + ANTICIPATION_REACH_PX + ANTICIPATION_CLOSE_PX_S * t:
		return {}
	var mate_role: String = {"player": "playerMate", "playerMate": "player",
		"opponent": "opponentMate", "opponentMate": "opponent"}[role]
	var mate = state.paddle(mate_role)
	if mate != null and absf(x - float(mate.x)) < mine:
		return {}
	return {"t": t, "x": x, "z": z}


## Which of the rig's strokes to wind up for: an overhead for a high ball, else
## the forehand/backhand by contact side (same rule as `meshy_stroke_for`).
static func anticipation_stroke(available: Array, role: String, paddle_x: float, contact_x: float, contact_z: float) -> Dictionary:
	var intent := "smash" if contact_z > OVERHEAD_HEIGHT_PX else "drive"
	var clip: StringName = meshy_stroke_for(intent, role, paddle_x, contact_x)
	var recipe := stroke_recipe(intent)
	if not clip in available:
		clip = recipe["clip"]
	return {"clip": clip, "contact_phase": recipe["contact_phase"]}


## The first of `wanted` (then the forehand family) whose clip actually holds a
## preparation frame, or &"" when none does — measured on the rig, not assumed.
static func anticipation_fallback(rig: Node3D, wanted: StringName, contact_phase: float) -> StringName:
	var candidates: Array = [wanted, &"meshy_drive", &"meshy_slice", &"drive", &"slice", &"lob"]
	var available: Array = rig.get_stroke_names()
	for candidate in candidates:
		if candidate in available and not (rig.get_prep_readout(candidate, contact_phase) as Dictionary).is_empty() \
				and int((rig.get_prep_readout(candidate, contact_phase) as Dictionary).get("bones", 0)) > 0:
			return candidate
	return &""


## Chest and head follow the ball (clamped in the rig); feet and facing do not.
func _sync_look(role: String, rig: Node3D, state, delta: float, snap: bool) -> void:
	if not rig.has_method("set_look_yaw"):
		return
	var ball = state.ball
	var target := look_yaw_towards(rig.position, rig.get_facing_degrees(),
		Court.world_pos(float(ball.x), float(ball.y), float(ball.z)))
	if rig.is_stroking():
		target = 0.0 # the stroke clip owns the torso around contact
	var yaw: float = float(_look.get(role, 0.0))
	yaw = target if snap else lerpf(yaw, target, 1.0 - exp(-LOOK_RATE * delta))
	_look[role] = yaw
	rig.set_look_yaw(yaw)


## Relative yaw (degrees, same sign as `set_facing_degrees`) from a rig at
## `from` facing `facing_degrees` to `target`, faded out for a ball behind it.
static func look_yaw_towards(from: Vector3, facing_degrees: float, target: Vector3) -> float:
	var d := target - from
	if Vector2(d.x, d.z).length_squared() < 0.04:
		return 0.0
	var rel := wrapf(rad_to_deg(atan2(d.x, d.z)) - facing_degrees, -180.0, 180.0)
	var fade := 1.0 - smoothstep(LOOK_FADE_FROM_DEG, LOOK_FADE_TO_DEG, absf(rel))
	return rel * fade


## Height observed on the swing edge, never tracked during follow-through.
static func low_contact_amount(intent: String, height: float) -> float:
	if not is_finite(height) or intent.contains("smash") or intent.contains("bandeja") or intent.contains("serve") or intent.contains("vibora"):
		return 0.0
	return clampf((38.0 - height) / 30.0, 0.0, 1.0)


## Presentation only: use contact side, NOT swingSide (human swingSide is aim).
## A +Z-facing right-handed rig holds its racket on local -X. The near team
## faces the opposite direction, hence the sign reversal.
## The same side test `meshy_stroke_for` uses for the backhand.
static func is_backhand_side(role: String, paddle_x: float, ball_x: float) -> bool:
	var local_side := (ball_x - paddle_x) * (-1.0 if role.begins_with("player") else 1.0)
	return is_finite(local_side) and local_side > 6.0


static func meshy_stroke_for(intent: String, role: String, paddle_x: float, ball_x: float) -> StringName:
	var word := intent.to_lower()
	if word in ["drive", "safe-drive"]:
		var local_side := (ball_x - paddle_x) * (-1.0 if role.begins_with("player") else 1.0)
		return &"meshy_backhand" if is_finite(local_side) and local_side > 6.0 else &"meshy_drive"
	if word.contains("smash"): return &"meshy_smash"
	if word.contains("bandeja"): return &"meshy_bandeja"
	if word == "slice": return &"meshy_slice"
	return &""


## `actionIntent` (`js/game.js`) -> the rig's own stroke vocabulary
## (`athlete_rig.gd::STROKE_SPECS`: drive / slice / lob / serve).
static func stroke_for(intent: String) -> StringName:
	return StringName(stroke_recipe(intent)["clip"])


## Semantic shot -> authored rig recipe. The sim remains the authority on the
## shot type; this table only decides which existing body motion is visible and
## where its contact frame starts. Keeping it data-shaped makes the seam
## inspectable and lets us replace individual clips later without touching rules.
static func stroke_recipe(intent: String) -> Dictionary:
	var word := intent.to_lower()
	var clip: StringName = &"drive"
	var contact_phase := 0.34
	var speed_scale := 1.12
	if word.contains("serve"):
		clip = &"serve"
		contact_phase = 0.30
		speed_scale = 1.0
	elif word == "volley" or word == "cut-volley":
		clip = &"volley"
		contact_phase = 0.5
		speed_scale = 1.0
	elif word.contains("lob") or word.contains("globo"):
		clip = &"lob"
		contact_phase = 0.40
		speed_scale = 1.0
	elif word.contains("slice") or word.contains("vibora") or word.contains("chiquita") \
			or word.contains("cut-volley") or word.contains("bandeja"):
		clip = &"slice"
		contact_phase = 0.32 if not word.contains("bandeja") else 0.38
		speed_scale = 1.18 if word.contains("vibora") or word.contains("cut-volley") else 1.08
	elif word.contains("smash") or word.contains("wall-angle"):
		# Smash and wall-angle keep the drive body mechanics for now, but start
		# later in the follow-through so the contact reads as an overhead action.
		clip = &"drive"
		contact_phase = 0.46
		speed_scale = 1.28
	return {
		"clip": clip,
		"contact_phase": contact_phase,
		"speed_scale": speed_scale,
	}


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
