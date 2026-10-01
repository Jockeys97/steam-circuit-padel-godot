extends SkeletonModifier3D
## custom_head_scale.gd — the "Crea atleta" bodies' head, scaled up to the roster's
## proportions (2026-09-27, owner: "la testa molto spesso è veramente sproporzionata").
## Measured body height / head height (neck to crown): the roster's stylised athletes
## 5.5-5.9, the Meshy bodies 5.8-6.6 (the strong man 6.6 with shoulders 1.4 heads wide).
## The clips carry no scale track, so the pose scale is set every frame after them; the
## hair piece rides the head bone and scales with it.
var head_bone: int = -1
var head_scale: float = 1.0

func _process_modification_with_delta(_delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or head_bone < 0 or is_equal_approx(head_scale, 1.0):
		return
	skeleton.set_bone_pose_scale(head_bone, Vector3.ONE * head_scale)
