extends SceneTree

class Probe extends Node:
	var ready_ran := false
	func _ready() -> void:
		ready_ran = true

var a: Probe
var b: Probe
var frames := 0

func _initialize() -> void:
	a = Probe.new()
	root.add_child(a)
	print("PROBE initialize: a.ready=%s" % str(a.ready_ran))

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 1:
		b = Probe.new()
		root.add_child(b)
		print("PROBE frame1: a.ready=%s b.ready=%s" % [str(a.ready_ran), str(b.ready_ran)])
	if frames == 2:
		print("PROBE frame2: a.ready=%s b.ready=%s" % [str(a.ready_ran), str(b.ready_ran)])
		quit(0)
		return true
	return false
