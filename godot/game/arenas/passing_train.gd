## Presentation ticked by the match, never by wall time or the global RNG.
extends Node3D
const SPEED := 2.8
const EDGE := 26.0
var wait_seconds := 75.0
var travelling := false
var passes := 0
var rng := RandomNumberGenerator.new()
var sound: AudioStreamPlayer
var wheel_spokes: Array[Dictionary] = []
var spoke_mesh: MultiMesh

func _ready() -> void:
	var spokes := get_node_or_null("box_brass") as MultiMeshInstance3D
	if spokes != null: spoke_mesh = spokes.multimesh
	sound = AudioStreamPlayer.new()
	sound.name = "RailRumble"
	sound.stream = rail_loop()
	sound.volume_db = -34.0
	add_child(sound)
	reset_schedule()

func reset_schedule() -> void:
	rng.seed = 71073
	passes = 0
	travelling = false
	wait_seconds = rng.randf_range(60.0,90.0)
	position.x = -EDGE
	hide()
	if sound != null: sound.stop()

func step(delta: float,between_points: bool,ended: bool) -> void:
	if ended:
		travelling = false
		hide()
		if sound != null: sound.stop()
		return
	if delta <= 0.0: return
	if travelling:
		position.x += SPEED*delta
		if spoke_mesh != null:
			var turn := Basis(Vector3.BACK,-(position.x+EDGE)/0.57)
			for spoke in wheel_spokes:
				var transform: Transform3D = spoke.transform
				transform.basis = turn*transform.basis
				spoke_mesh.set_instance_transform(spoke.index,transform)
		if position.x >= EDGE:
			travelling = false
			hide()
			wait_seconds = rng.randf_range(60.0,90.0)
			if sound != null: sound.stop()
	else:
		wait_seconds = maxf(0.0,wait_seconds-delta)
		if wait_seconds == 0.0 and between_points:
			position.x = -EDGE
			travelling = true
			passes += 1
			show()

func sync_audio(paused: bool,muted: bool) -> void:
	if sound == null: return
	# The match mixer owns gain. Never fall back to Master if SFX is absent.
	if AudioServer.get_bus_index("SFX") < 0 or not travelling or muted:
		sound.stop()
		return
	sound.bus = "SFX"
	sound.stream_paused = paused
	if not paused and not sound.playing: sound.play()
	var envelope := clampf(1.0-absf(position.x)/EDGE,0.0,1.0)
	sound.volume_db = linear_to_db(maxf(0.00001,envelope*0.025))

static func rail_loop() -> AudioStreamWAV:
	# Quiet, seamless synthetic rail rhythm; no download, horn or paid sound.
	const RATE := 11025
	var bytes := PackedByteArray()
	bytes.resize(RATE*2)
	for i in RATE:
		var t := float(i)/RATE
		var pulse := pow(0.5+0.5*cos(TAU*4.0*t),10.0)
		var sample := (sin(TAU*66.0*t)*0.35 + sin(TAU*99.0*t)*0.15 + sin(TAU*220.0*t)*pulse*0.18)
		bytes.encode_s16(i*2,int(sample*32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = bytes
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = RATE
	return wav
