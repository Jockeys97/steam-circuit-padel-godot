extends SkeletonModifier3D
## AthletePoseLayer — two presentation-only layers applied AFTER the
## AnimationPlayer has posed the skeleton, every frame.
##
##   1. ANTICIPATION. Blends the upper body towards a stroke's own backswing
##      frame (`AthleteRig.set_anticipation`). The simulation only reports a
##      stroke on its contact tick, so without this the body jumps from the
##      ready stance straight into the contact pose. With it, the approaching
##      ball draws the racket back first and the contact reads as the forward
##      swing. The weight drops to zero the instant a stroke plays: contact
##      stays authoritative (`AthleteRig.play_stroke_at`).
##   2. LOOK. Turns the spine chain and the head about the rig's own up axis by
##      a clamped yaw (`AthleteRig.set_look_yaw`), so the athletes follow the
##      ball instead of staring at the net. Feet, hips and the rig's facing are
##      untouched, so the court composition and the footwork do not move.
##
## A SkeletonModifier3D does not persist its result into the bone poses
## (Godot restores them after the modifier stack), so `get_bone_pose_*`,
## `get_pose()` and every test that samples a clip still read the clip's own
## values. The racket's BoneAttachment3D follows the modified pose.
##
## Nothing here reads or writes the simulation.

## bone index -> Quaternion DELTA (local, post-multiplied onto the current pose),
## filled by the rig per stroke; each is already bounded by PREP_LIMIT_DEG, so
## the layer can never rotate a bone further than that from what the clip
## underneath is doing.
var prep_pose: Dictionary = {}
var prep_weight: float = 0.0
## [bone index, share] in parent-first order; shares sum to 1.
var look_chain: Array = []
var look_yaw_degrees: float = 0.0
## The rig node whose +Y is "up" for the look rotation.
var rig: Node3D = null


func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	if prep_weight > 0.0001 and not prep_pose.is_empty():
		var w := clampf(prep_weight, 0.0, 1.0)
		for bone in prep_pose:
			var current: Quaternion = skeleton.get_bone_pose_rotation(bone)
			var delta: Quaternion = Quaternion.IDENTITY.slerp(prep_pose[bone], w)
			skeleton.set_bone_pose_rotation(bone, (current * delta).normalized())
	if absf(look_yaw_degrees) > 0.01 and not look_chain.is_empty() and rig != null and rig.is_inside_tree():
		# The rig's up axis expressed in skeleton space (the skeleton may sit
		# under a scaled or rotated Armature node).
		var up_skel := (skeleton.global_transform.basis.inverse() * rig.global_transform.basis.y).normalized()
		if not up_skel.is_finite() or up_skel.length_squared() < 0.5:
			return
		var total := deg_to_rad(look_yaw_degrees)
		for entry in look_chain:
			var bone: int = entry[0]
			var share: float = entry[1]
			var parent := skeleton.get_bone_parent(bone)
			var parent_q := Quaternion.IDENTITY
			if parent >= 0:
				parent_q = skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion()
			var turn := Quaternion(up_skel, total * share)
			var local: Quaternion = skeleton.get_bone_pose_rotation(bone)
			skeleton.set_bone_pose_rotation(bone, (parent_q.inverse() * turn * parent_q * local).normalized())
