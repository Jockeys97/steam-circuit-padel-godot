## fantasy_motion.gd — the six fantasy arenas' bounded presentation animation.
##
## The contract asks for "tasteful bounded animation" and forbids rapid strobe. This
## node is the single place per-frame change happens, and it is deliberately narrow:
##
##   SPIN   — a registered pivot turns about an axis at a capped angular speed. The
##            vault gears, the armillary rings and the foundry flywheels are the only
##            spinners, all at or below 8 deg/s (`MAX_SPIN_DEG_PER_SEC`), which is a
##            full revolution in 45 s or more: readable as machinery, never as motion
##            blur.
##   DRIFT  — a registered MultiMesh's instances rise within a fixed vertical band and
##            wrap at the top. Embers, bubbles and storm motes are all one MultiMesh
##            each, so a whole field of them costs one draw call and one transform
##            update per frame. The band is fixed at registration, so nothing can
##            escape its arena-authored volume and nothing can grow over time.
##
## There is no strobe anywhere: no brightness is written here at all (the drifting
## shader layers carry their own capped pulse), and every drift wrap is a hard fmod
## on position, not a flash. Motion stops with the tree (`_process` never runs while
## paused), so a paused match is a still frame.
##
## Everything is a pure function of elapsed time, so two runs at the same time agree
## and the test can assert the bounds without rendering.
extends Node3D

## The angular-speed ceiling, in degrees per second. 8 deg/s is a 45 s revolution.
const MAX_SPIN_DEG_PER_SEC := 8.0

var _spinners: Array = []
var _drifts: Array = []
var _time := 0.0


## Register a pivot that turns about `axis` at `speed_deg` per second (clamped to the
## ceiling). The node is expected to be a bare `Node3D` holding decorative meshes.
func add_spin(node: Node3D, speed_deg := 4.0, axis := Vector3.UP, phase_deg := 0.0) -> void:
	if node == null:
		return
	var speed := clampf(speed_deg, -MAX_SPIN_DEG_PER_SEC, MAX_SPIN_DEG_PER_SEC)
	node.rotation = (axis.normalized() if axis.length() > 0.0 else Vector3.UP) * deg_to_rad(phase_deg)
	_spinners.append({"node": node, "axis": axis.normalized() if axis.length() > 0.0 else Vector3.UP, "speed": speed})


## Register a MultiMesh whose instances rise `rise` metres per second inside
## [`lo`, `hi`] (in the node's own local space) and wrap to the bottom at the top.
## `spread` scatters the starting heights so the field never moves as one plane.
func add_drift(node: MultiMeshInstance3D, rise: float, lo: float, hi: float,
		spread := 0.0, spin_deg := 0.0) -> void:
	if node == null or node.multimesh == null:
		return
	var mm := node.multimesh
	var base: Array = []
	var phase: Array = []
	var span := maxf(hi - lo, 0.001)
	for i in mm.instance_count:
		base.append(mm.get_instance_transform(i))
		var h := hash(i * 2654435761) % 1000
		var t := float(h) / 1000.0
		phase.append(t * (spread if spread > 0.0 else span))
	_drifts.append({
		"mm": mm, "base": base, "phase": phase,
		"rise": rise, "lo": lo, "hi": hi, "span": span,
		"spin": clampf(spin_deg, -MAX_SPIN_DEG_PER_SEC, MAX_SPIN_DEG_PER_SEC),
	})


func _process(delta: float) -> void:
	_time += delta
	for entry in _spinners:
		var node: Node3D = entry["node"]
		if not is_instance_valid(node):
			continue
		node.rotate(entry["axis"], deg_to_rad(float(entry["speed"])) * delta)
	for entry in _drifts:
		var mm: MultiMesh = entry["mm"]
		if mm == null:
			continue
		var base: Array = entry["base"]
		var phase: Array = entry["phase"]
		var lo := float(entry["lo"])
		var hi := float(entry["hi"])
		var rise := float(entry["rise"])
		var spin := deg_to_rad(float(entry["spin"])) * _time
		for i in base.size():
			var xf: Transform3D = base[i]
			var y := lo + fposmod(float(phase[i]) + _time * rise, maxf(hi - lo, 0.001))
			var pos := xf.origin
			pos.y = y
			var basis := xf.basis
			if spin != 0.0:
				basis = Basis(Vector3.UP, spin) * basis
			mm.set_instance_transform(i, Transform3D(basis, pos))


## The fastest registered spin, in degrees per second. The lane's test asserts this is
## at or below `MAX_SPIN_DEG_PER_SEC` for every arena, so "bounded animation" is
## measured rather than promised.
func max_spin_speed_deg() -> float:
	var worst := 0.0
	for entry in _spinners:
		worst = maxf(worst, absf(float(entry["speed"])))
	return worst


## The vertical velocity of the fastest registered drift, and how many instances it
## moves. Reported per arena by the test.
func drift_report() -> Dictionary:
	var fastest := 0.0
	var instances := 0
	var spins := 0
	for entry in _drifts:
		fastest = maxf(fastest, absf(float(entry["rise"])))
		instances += (entry["base"] as Array).size()
	for entry in _spinners:
		spins += 1
	return {"fastest_rise_mps": fastest, "drift_instances": instances, "spinners": spins}
