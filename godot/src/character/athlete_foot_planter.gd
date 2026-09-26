extends SkeletonModifier3D
## AthleteFootPlanter — feet that stay on the court (2026-09-26).
##
## The simulation moves the athlete; the footwork clips animate the legs IN PLACE. On
## the clips where the body travels while the feet barely lift (the shuffles, the
## backpedal, the brake) the planted foot therefore slid with the body — measured in a
## match (`game/tools/foot_slip_probe.gd`): the support foot moved at a median 2.9-3.6
## m/s during a shuffle, 100% of those frames visibly. No fixed clip can fix that: the
## speed is the simulation's and changes every frame.
##
## This layer places the feet procedurally, after the AnimationPlayer (and after the
## pose layer, which never touches the legs):
##   * each foot is PINNED to a point on the court while planted;
##   * when the body has moved it too far from where the clip wants it (STEP_DIST), or
##     too far overall (MAX_DIST), it takes a real step: a short arc (STEP_HEIGHT) to
##     where the clip wants it, led by the body's velocity so it lands ahead of time;
##   * one foot steps at a time unless the leg would overstretch;
##   * the leg reaches the foot with an analytic two-bone IK (thigh, shin) that keeps
##     the knee on the side the clip bends it; the foot keeps the clip's orientation.
## `weight` (0..1, faded by the rig) says how much of this is shown: off while running,
## hopping (split step) or stroking, where the clips' own feet are right. Like the pose
## layer, nothing here persists into the bone poses or touches the simulation.

const STEP_DIST := 0.22      # m, pinned foot vs where the clip wants it (0.16 made many short steps)
const MAX_DIST := 0.55       # m, beyond this the foot steps even if the other one is
const STEP_HEIGHT := 0.045   # m, arc apex: a shuffle skims the court
const STEP_TIME_SLOW := 0.26 # s, a step at walking pace
const STEP_TIME_MIN := 0.11  # s, the quickest step
const STEP_LEN := 0.32       # m of travel one step covers
const OVERLAP_T := 0.6       # the next foot may leave once the other is this far into its step
const LEAD := 0.30           # share of the step time the landing is led by the velocity (0.55 overshot: feet 0.8-1.2 m apart)
const TURN_STEP_DEG := 35.0  # the body turned this far over a pinned foot: step
## Owner 2026-09-26: "le gambe troppo larghe e innaturali". Measured: the feet reached
## 0.83-1.19 m apart while shuffling. A player's feet move between about shoulder width
## and an open step, so no landing may open the stance past MAX_GAP, and a foot closes
## (steps) as soon as the stance passes CLOSE_SHARE of it.
const MAX_GAP := 0.58        # m, widest stance
const CLOSE_SHARE := 0.85
const MIN_GAP := 0.22        # m, feet never cross and never close tighter than a player's closing step (0.12 let heavy thighs meet in an X)
## The body follows the steps (owner 2026-09-26: "troppo rigido il busto sopra rispetto
## ai piedi"): the pelvis sinks into a lower stance while stepping and dips a little
## more as each foot lands. (A first version also rolled the pelvis and turned the
## chest: see CROUCH below for why those are 0.)
const BOB := 0.025           # m, extra pelvis dip at a landing
const SHIFT_SHARE := 0.05    # of the way from the pelvis to the support foot, mid-step
const HIP_ROLL_DEG := 0.0
const SPINE_COUNTER := 0.6   # share of the hip roll the spine takes back
const CHEST_YAW_DEG := 0.0
const STEPPING_DECAY := 4.0  # 1/s: how fast the body settles once the steps stop
## Owner 2026-09-26, after the version above: "sembrano dei pinguini". The waddle was the
## pelvis roll, the weight shift and the chest turn. An athlete's shuffle keeps the
## torso square and level and gets its life from the LEGS: a lower centre of gravity
## while travelling (CROUCH) and long, low steps. Roll and turn are now 0.
const CROUCH := 0.06         # m, pelvis lowered while the steps go on
const KNEE_OUT := 0.35       # outward share of the knee's forward direction
const KNEE_POLE_SHARE := 0.7 # how much of the knee bend follows that, vs the clip's

## Set by the rig every frame (already faded).
var weight: float = 0.0
## The rig node that moves with the simulation (world velocity is read from it).
var rig: Node3D = null
## [upleg, leg, foot] bone indices, per side; set by the rig.
var legs: Dictionary = {}
## The pelvis and the spine chain (parent first), set by the rig; -1 / empty = no body.
var hips: int = -1
var spine: Array = []

var _feet := {}
var _last_rig_pos := Vector3.ZERO
var _velocity := Vector3.ZERO
var _has_last := false
var _stepping := 0.0


func _process_modification_with_delta(delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or rig == null or not rig.is_inside_tree() or legs.is_empty():
		return
	var pos := rig.global_position
	if _has_last and delta > 0.0:
		var v := (pos - _last_rig_pos) / delta
		v.y = 0.0
		# A point reset moves the athlete metres in one frame: not a velocity.
		if v.length() < 20.0:
			_velocity = _velocity.lerp(v, 1.0 - exp(-14.0 * delta))
		else:
			_feet.clear()
	_last_rig_pos = pos
	_has_last = true
	if weight <= 0.001:
		_feet.clear()
		return
	var to_world := skeleton.global_transform
	var to_skel := to_world.affine_inverse()
	var speed := _velocity.length()
	# Faster travel = quicker steps, not longer ones: each step covers about STEP_LEN,
	# so the cadence keeps up with the simulation's speed (a fixed 0.2 s step at 2.5 m/s
	# left the trailing foot 0.8 m behind the body).
	var step_time := clampf(STEP_LEN / maxf(speed, 0.01), STEP_TIME_MIN, STEP_TIME_SLOW)
	var yaw := rig.global_rotation.y
	var goals := {}
	for side in legs:
		var ids: Array = legs[side]
		var anim_foot: Vector3 = to_world * skeleton.get_bone_global_pose(ids[2]).origin
		if not _feet.has(side):
			_feet[side] = {"pin": anim_foot, "swing": false, "yaw": yaw}
	# The foot left furthest behind decides first: iterating Left then Right let the
	# left always win, so moving to the right the leading foot waited, fell behind the
	# trailing one and the two crossed in the air (measured: -0.39 m at 2.5 m/s).
	var order: Array = legs.keys()
	order.sort_custom(func(a, b): return _lag(skeleton, to_world, a) > _lag(skeleton, to_world, b))
	for side in order:
		var ids: Array = legs[side]
		var other: String = "Right" if side == "Left" else "Left"
		var foot: Dictionary = _feet[side]
		var anim_foot: Vector3 = to_world * skeleton.get_bone_global_pose(ids[2]).origin
		var wanted := _uncrossed(side, anim_foot + _velocity * step_time * LEAD, other)
		if bool(foot["swing"]):
			foot["t"] = float(foot["t"]) + delta / float(foot["dur"])
			foot["to"] = wanted
			if float(foot["t"]) >= 1.0:
				foot["swing"] = false
				foot["pin"] = Vector3(wanted.x, anim_foot.y, wanted.z)
				foot["yaw"] = yaw
		else:
			var pin: Vector3 = foot["pin"]
			var off := Vector2(pin.x - anim_foot.x, pin.z - anim_foot.z).length()
			var turned := absf(rad_to_deg(angle_difference(float(foot["yaw"]), yaw)))
			var other_swinging: bool = _feet.has(other) and bool(_feet[other]["swing"]) and float(_feet[other]["t"]) < OVERLAP_T
			var too_wide := _stance_gap() > MAX_GAP * CLOSE_SHARE and off > 0.05
			if off > MAX_DIST or ((off > STEP_DIST or turned > TURN_STEP_DEG or too_wide) and not other_swinging):
				foot["swing"] = true
				foot["t"] = 0.0
				foot["dur"] = step_time
				foot["from"] = pin
				foot["to"] = wanted
		var goal: Vector3
		if bool(foot["swing"]):
			var t := clampf(float(foot["t"]), 0.0, 1.0)
			var e := t * t * (3.0 - 2.0 * t)
			var from: Vector3 = foot["from"]
			var to: Vector3 = foot["to"]
			goal = from.lerp(Vector3(to.x, anim_foot.y, to.z), e)
			goal.y = lerpf(from.y, anim_foot.y, e) + sin(t * PI) * STEP_HEIGHT
		else:
			goal = foot["pin"]
		goals[side] = anim_foot.lerp(goal, clampf(weight, 0.0, 1.0))
	_keep_apart(goals)
	_move_body(skeleton, to_world, to_skel, delta)
	# Knees point forward and a little outwards, as an athlete's do: the clip's own
	# bend alone let a narrow stance (Colosso) fold the knees inwards into an X.
	var fwd := rig.global_transform.basis.z
	var lat := rig.global_transform.basis.x
	for side in goals:
		var outward := lat * (1.0 if side == "Left" else -1.0)
		var pole := to_skel.basis * (fwd + outward * KNEE_OUT)
		_reach(skeleton, legs[side], to_skel * (goals[side] as Vector3), pole)


## The body's share of a step, applied BEFORE the legs are solved (so the feet stay
## pinned): pelvis dip/rise and weight shift, pelvis roll with the spine rolling back,
## a small chest turn. Zero while no step has happened for a moment.
func _move_body(skeleton: Skeleton3D, to_world: Transform3D, to_skel: Transform3D, delta: float) -> void:
	if hips < 0:
		return
	var swing_side := ""
	var t := 0.0
	for side in _feet:
		if bool(_feet[side]["swing"]):
			swing_side = side
			t = clampf(float(_feet[side]["t"]), 0.0, 1.0)
	if swing_side != "":
		_stepping = 1.0
	else:
		_stepping = maxf(0.0, _stepping - STEPPING_DECAY * delta)
	var amount := _stepping * clampf(weight, 0.0, 1.0)
	if amount <= 0.001:
		return
	var lift := sin(t * PI) if swing_side != "" else 0.0
	var side_sign := 0.0
	if swing_side != "":
		side_sign = 1.0 if swing_side == "Left" else -1.0
	# Pelvis translation, in world space: dip at the landings, shift over the support.
	var offset := Vector3(0.0, -CROUCH - BOB * (1.0 - lift), 0.0)
	if swing_side != "":
		var support: String = "Right" if swing_side == "Left" else "Left"
		var hip_world: Vector3 = to_world * skeleton.get_bone_global_pose(hips).origin
		var lateral := rig.global_transform.basis.x
		lateral.y = 0.0
		lateral = lateral.normalized()
		var to_support: Vector3 = (_feet[support]["pin"] as Vector3) - hip_world
		offset += lateral * to_support.dot(lateral) * SHIFT_SHARE * lift
	offset *= amount
	var parent := skeleton.get_bone_parent(hips)
	var parent_basis := skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	var local_offset := parent_basis.inverse() * (to_skel.basis * offset)
	skeleton.set_bone_pose_position(hips, skeleton.get_bone_pose_position(hips) + local_offset)
	# Pelvis roll about the athlete's forward axis, the spine taking most of it back.
	var forward := (to_skel.basis * rig.global_transform.basis.z).normalized()
	var up := (to_skel.basis * rig.global_transform.basis.y).normalized()
	var roll := deg_to_rad(HIP_ROLL_DEG) * lift * side_sign * amount
	if absf(roll) > 1e-5 and forward.is_finite():
		var hip_g := skeleton.get_bone_global_pose(hips)
		_set_global_rotation(skeleton, hips, Basis(Quaternion(forward, roll)) * hip_g.basis)
		if not spine.is_empty():
			var first: int = spine[0]
			var sg := skeleton.get_bone_global_pose(first)
			_set_global_rotation(skeleton, first, Basis(Quaternion(forward, -roll * SPINE_COUNTER)) * sg.basis)
	# Chest turn against the step, on the top of the spine.
	var yaw_turn := deg_to_rad(CHEST_YAW_DEG) * lift * -side_sign * amount
	if absf(yaw_turn) > 1e-5 and spine.size() > 1 and up.is_finite():
		var top: int = spine[spine.size() - 1]
		var tg := skeleton.get_bone_global_pose(top)
		_set_global_rotation(skeleton, top, Basis(Quaternion(up, yaw_turn)) * tg.basis)


## The current stance width along the athlete's lateral axis (pinned or landing spots).
func _stance_gap() -> float:
	if not _feet.has("Left") or not _feet.has("Right"):
		return 0.0
	var l: Dictionary = _feet["Left"]
	var r: Dictionary = _feet["Right"]
	var lp: Vector3 = l["to"] if bool(l["swing"]) else l["pin"]
	var rp: Vector3 = r["to"] if bool(r["swing"]) else r["pin"]
	var lateral := rig.global_transform.basis.x
	lateral.y = 0.0
	return (lp - rp).dot(lateral.normalized())


## How far a planted foot has been left behind where the clip wants it (0 in flight).
func _lag(skeleton: Skeleton3D, to_world: Transform3D, side: String) -> float:
	if not _feet.has(side) or bool(_feet[side]["swing"]):
		return 0.0
	var anim_foot: Vector3 = to_world * skeleton.get_bone_global_pose(legs[side][2]).origin
	var pin: Vector3 = _feet[side]["pin"]
	return Vector2(pin.x - anim_foot.x, pin.z - anim_foot.z).length()


## The final guard, on the positions actually shown this frame (in flight included):
## the left foot stays at least MIN_GAP/2 to the left of the right one, split between
## them. Landings are kept apart by `_uncrossed`; this also covers two feet in flight.
func _keep_apart(goals: Dictionary) -> void:
	if not goals.has("Left") or not goals.has("Right"):
		return
	var lateral := rig.global_transform.basis.x
	lateral.y = 0.0
	lateral = lateral.normalized()
	var gap: float = ((goals["Left"] as Vector3) - (goals["Right"] as Vector3)).dot(lateral)
	var floor_gap := MIN_GAP * 0.5
	if gap < floor_gap:
		var push := lateral * (floor_gap - gap) * 0.5
		goals["Left"] = (goals["Left"] as Vector3) + push
		goals["Right"] = (goals["Right"] as Vector3) - push


## A shuffle never crosses the feet: led by the velocity, the trailing foot's landing
## could pass the leading one. Keep each foot on its own side of the other along the
## rig's lateral axis (+X is the athlete's left), at least MIN_GAP apart.
func _uncrossed(side: String, target: Vector3, other: String) -> Vector3:
	if not _feet.has(other):
		return target
	var o: Dictionary = _feet[other]
	var other_pos: Vector3 = o["to"] if bool(o["swing"]) else o["pin"]
	var lateral := rig.global_transform.basis.x
	lateral.y = 0.0
	lateral = lateral.normalized()
	var gap := (target - other_pos).dot(lateral) * (1.0 if side == "Left" else -1.0)
	if gap < MIN_GAP:
		target += lateral * (MIN_GAP - gap) * (1.0 if side == "Left" else -1.0)
	elif gap > MAX_GAP:
		target -= lateral * (gap - MAX_GAP) * (1.0 if side == "Left" else -1.0)
	return target


## Analytic two-bone IK in skeleton space: rotate the thigh, then the shin, so the
## ankle lands on `goal`; the knee stays in the plane the clip bends it in, and the
## foot keeps its global orientation.
func _reach(skeleton: Skeleton3D, ids: Array, goal: Vector3, pole: Vector3 = Vector3.ZERO) -> void:
	var up: int = ids[0]
	var mid: int = ids[1]
	var end: int = ids[2]
	var up_g := skeleton.get_bone_global_pose(up)
	var mid_g := skeleton.get_bone_global_pose(mid)
	var end_g := skeleton.get_bone_global_pose(end)
	var hip := up_g.origin
	var knee := mid_g.origin
	var ankle := end_g.origin
	var l1 := hip.distance_to(knee)
	var l2 := knee.distance_to(ankle)
	if l1 < 1e-4 or l2 < 1e-4:
		return
	var to_goal := goal - hip
	var d := clampf(to_goal.length(), absf(l1 - l2) + 1e-3, l1 + l2 - 1e-3)
	var n := to_goal.normalized()
	if not n.is_finite() or n.length_squared() < 0.5:
		return
	var bend := (knee - hip) - n * (knee - hip).dot(n)
	if bend.length_squared() < 1e-8:
		return
	bend = bend.normalized()
	var pole_bend := pole - n * pole.dot(n)
	if pole_bend.length_squared() > 1e-8:
		bend = (bend * (1.0 - KNEE_POLE_SHARE) + pole_bend.normalized() * KNEE_POLE_SHARE).normalized()
	var a := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(l1 * l1 - a * a, 0.0))
	var knee_new := hip + n * a + bend * h
	var target := hip + n * d
	# Thigh: swing its direction onto the new knee.
	var q1 := _arc(knee - hip, knee_new - hip)
	var up_new := Basis(q1) * up_g.basis
	# Shin: after the thigh moved, swing it onto the goal.
	var ankle_moved := knee_new + q1 * (ankle - knee)
	var q2 := _arc(ankle_moved - knee_new, target - knee_new)
	var mid_new := Basis(q2 * q1) * mid_g.basis
	_set_global_rotation(skeleton, up, up_new)
	_set_global_rotation(skeleton, mid, mid_new)
	_set_global_rotation(skeleton, end, end_g.basis)


func _arc(from: Vector3, to: Vector3) -> Quaternion:
	var a := from.normalized()
	var b := to.normalized()
	if not a.is_finite() or not b.is_finite():
		return Quaternion.IDENTITY
	var c := a.dot(b)
	if c > 0.99999:
		return Quaternion.IDENTITY
	if c < -0.99999:
		return Quaternion.IDENTITY
	return Quaternion(a.cross(b).normalized(), acos(clampf(c, -1.0, 1.0)))


func _set_global_rotation(skeleton: Skeleton3D, bone: int, global_basis: Basis) -> void:
	var parent := skeleton.get_bone_parent(bone)
	var parent_basis := skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	var local := (parent_basis.inverse() * global_basis).get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(bone, local.normalized())
