## scripted_player.gd — the deterministic stand-in for a human, used by the
## headless slice run and the capture harness.
##
## It is NOT the game's AI: the opponent AI is in the simulation (`src/sim/sim.gd`,
## `choose_computer_shot` / `move_opponent_team`). This file only fills the same
## 22-field human input struct a person would fill, from the live state, with no
## randomness — so the same seed and the same tick count produce the same match,
## and a failure can be replayed.
##
## Policy, deliberately simple: stand where the ball is going, charge while it
## comes, release at contact. That is enough to produce real rallies against the
## real AI, which is what the slice has to prove.
extends RefCounted

const Sim := preload("res://src/sim/sim.gd")
const Frozen := preload("res://src/sim/frozen.gd")

## How far ahead of the ball the paddle aims (px per tick of ball velocity).
const LEAD_TICKS := 14.0
## Contact box, in px, in which the scripted player releases a charged shot.
const CONTACT_X := 78.0
const CONTACT_Y := 96.0
## Serve charge length in ticks (24 ticks = 0.2 s of charge).
const SERVE_CHARGE_TICKS := 26

var charge_ticks := 0
var charging := false


func decide(state) -> Dictionary:
	var input := Sim.empty_input()
	var court: Dictionary = Frozen.court()
	var net_y: float = float(court["netY"])

	if state.serving:
		if state.serveSide != "player":
			return input
		charge_ticks += 1
		if charge_ticks < SERVE_CHARGE_TICKS:
			input["charging"] = true
		else:
			input["hit"] = true
			charge_ticks = 0
		return input

	var paddle = state.active_player()
	var ball = state.ball
	var target_y: float = ball.y + ball.vy * LEAD_TICKS
	var depth: float = clampf(target_y, net_y + 150.0, float(court["bottom"]) - 60.0)
	var target_x: float = ball.x + ball.vx * LEAD_TICKS * 0.5
	var dx: float = target_x - paddle.x
	var dy: float = depth - paddle.y

	input["moveX"] = clampf(dx / 55.0, -1.0, 1.0)
	input["moveY"] = clampf(dy / 90.0, -1.0, 1.0)
	input["left"] = float(input["moveX"]) < -0.1
	input["right"] = float(input["moveX"]) > 0.1
	input["up"] = float(input["moveY"]) < -0.1
	input["down"] = float(input["moveY"]) > 0.1

	var incoming: bool = ball.vy > 0.0 and ball.y > net_y - 40.0
	var in_contact: bool = absf(ball.x - paddle.x) < CONTACT_X \
		and absf(ball.y - paddle.y) < CONTACT_Y \
		and ball.vy > 0.0

	if in_contact:
		if charging:
			input["hit"] = true
			charging = false
			charge_ticks = 0
		else:
			# Not yet charging and the ball is already on the paddle: hit anyway,
			# with whatever charge the sim has.
			input["hit"] = true
		return input

	if incoming:
		charging = true
		charge_ticks += 1
		input["charging"] = true
	else:
		if charging and charge_ticks > 0:
			# The ball went away mid-charge: release so the charge does not sit
			# at maximum for the next point.
			input["hit"] = true
			charging = false
			charge_ticks = 0
	return input


func reset() -> void:
	charge_ticks = 0
	charging = false
