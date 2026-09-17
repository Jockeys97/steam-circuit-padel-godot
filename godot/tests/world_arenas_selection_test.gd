## world_arenas_selection_test.gd — the SELECTION and PLAYABILITY gate for the
## five world arenas (port additions, `arena_style.gd` `family: "world"`).
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot/ \
##     --script res://tests/world_arenas_selection_test.gd
##   ... -- --arenas=torii        (subset; default is the five world ids)
##   ... -- --demo                (the demo half of every branch below)
##
## WHAT IT GATES, per `docs/mission/world-arenas/CHARTER.md` gate 1 ("five
## distinct selectable arenas") and the resume dispatch ("actually SELECTABLE and
## playable, not merely buildable"):
##   1. the build's own world seam offers exactly the five (a full build) or none
##      (a demo), and every offered row carries name, desc and the PROVISIONAL
##      physics marked as such;
##   2. `Config.set_arena_id` accepts each world id in a full build and REFUSES it
##      in a demo, where the selection must not move at all; `arena_id()` and
##      `arena()` follow, and choosing a frozen arena afterwards clears the world
##      seat (the two seats are mutually exclusive);
##   3. the CLI route (`Config.apply_cli_selection`) lands on the requested world
##      arena in a full build and refuses it by name in a demo;
##   4. the REAL match scene builds each world court and the simulation state
##      carries the arena's own record — including the provisional `wallBounce`
##      the sim reads — with ≥60 meshes on screen;
##   5. a full quick match is PLAYED to a real result on EVERY world court — all
##      five, not one — inside the slice's own tick budget, one exact
##      `WORLD_PLAYTHROUGH` line per arena: selection is not just a setter, every
##      arena is playable (round-2 review item);
##   6. the ported menu column (`--ui=legacy` shape) carries one `WorldArena_<id>`
##      button per offered world arena in a full build (none in a demo), each
##      registered in the focus model (so the keyboard/pad can reach it), and a
##      press lands the selection on that arena while a frozen arena's press
##      clears it again;
##   7. the original nine are untouched: every frozen id still selects and lands,
##      and `Config.selectable_arenas()` is still the frozen list (a demo still
##      grants exactly one arena).
##
## HEADLESS IS CORRECT HERE: nothing renders. The RENDERED half of the proof is
## `world_arenas_capture.gd` under `--rendering-driver opengl3`.
##
## Exit 0 on PASS, 1 on any FAIL; `PASS n/n` is the tally, and a `SCRIPT ERROR`
## anywhere in the log is a failure even next to a green tally.
extends SceneTree

const Common := preload("res://tests/world_arenas_common.gd")
const Arena := preload("res://game/arenas/arena_library.gd")
const Config := preload("res://game/match_config.gd")
const Gate := preload("res://game/content_gate.gd")
const Frozen := preload("res://src/sim/frozen.gd")
const Sim := preload("res://src/sim/sim.gd")
const ScriptedPlayer := preload("res://game/scripted_player.gd")

const MATCH_SCENE := "res://game/Match.tscn"
const MENU_SCENE := "res://game/Main.tscn"
const TICK := 1.0 / 120.0
## The slice's own playthrough budget (`game_slice_test.gd::MATCH_TICK_BUDGET`).
const MATCH_TICK_BUDGET := 400000

var _c := Common.new()
## 0 = not started, 1 = running (a section awaits a frame), 2 = finished.
var _state := 0


func _process(_delta: float) -> bool:
	if _state == 0:
		_state = 1
		_run()
	return _state == 2


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	Common.banner("WORLD_ARENAS_SELECTION")
	var ids := Common.target_ids(args)
	var demo := Gate.is_demo()
	print("# targets=%s build=%s" % [str(ids), Gate.label()])

	var want: Array = []
	for id in Arena.world_ids():
		want.append(String(id))

	# --- 1. the world seam this build offers ---------------------------------
	var offered: Array = []
	for row in Config.selectable_world_arenas():
		offered.append(String((row as Dictionary)["id"]))
	if demo:
		_c.check("a DEMO build offers none of the world five", offered.is_empty(), str(offered))
	else:
		_c.check("a FULL build offers exactly the five world arenas, in table order",
			offered == want and offered.size() == 5, "offered=%s want=%s" % [str(offered), str(want)])
		var thin: Array[String] = []
		for row in Config.selectable_world_arenas():
			var entry: Dictionary = row
			if String(entry.get("name", "")) == "" or String(entry.get("desc", "")) == "" \
					or float(entry.get("wallBounce", 0.0)) <= 0.0 \
					or float(entry.get("floorGrip", 0.0)) <= 0.0 \
					or not bool(entry.get("provisional", false)):
				thin.append(String(entry.get("id", "?")))
		_c.check("every offered world row carries name, desc and the PROVISIONAL physics (marked as such)",
			thin.is_empty(), str(thin))

	# --- 7. the original nine are untouched (asserted first: the world work sits
	#        on top of this and must not have moved it) --------------------------
	var frozen_problems: Array[String] = []
	var frozen_ids: Array = []
	for row in Frozen.arenas():
		frozen_ids.append(String(row["id"]))
	var selected: Array = []
	for row in Config.selectable_arenas():
		selected.append(String((row as Dictionary)["id"]))
	if demo:
		if selected.size() != 1:
			frozen_problems.append("a demo grants %d arenas, expected 1" % selected.size())
	else:
		if selected != frozen_ids:
			frozen_problems.append("selectable_arenas()=%s != the frozen nine %s" % [str(selected), str(frozen_ids)])
	var frozen_fail: Array[String] = []
	for id in frozen_ids:
		if demo and id != selected[0]:
			continue
		if not Config.set_arena_id(String(id)) or Config.arena_id() != String(id) or Config.is_world_selected():
			frozen_fail.append(String(id))
	_c.check("the frozen list this build offers is still exactly the reference's own (%s)" % Gate.label(),
		frozen_problems.is_empty(), str(frozen_problems))
	_c.check("every frozen arena this build grants still selects and lands (and never sets the world seat)",
		frozen_fail.is_empty(), str(frozen_fail))

	# --- 2. the world selection path ------------------------------------------
	var refused: Array[String] = []
	var misrouted: Array[String] = []
	for id in ids:
		var ok := Config.set_arena_id(String(id))
		if demo:
			if ok:
				refused.append("%s: set_arena_id said true in a demo" % id)
			if Config.arena_id() != String(selected[0]) or Config.is_world_selected():
				misrouted.append("%s: demo selection moved to %s" % [id, Config.arena_id()])
			continue
		if not ok:
			refused.append("%s: set_arena_id false" % id)
			continue
		if Config.arena_id() != String(id):
			misrouted.append("%s: arena_id() is %s" % [id, Config.arena_id()])
		if String(Config.arena().get("id", "")) != String(id) or not Config.is_world_selected():
			misrouted.append("%s: arena() is %s (world seat %s)" % [id, Config.arena().get("id", ""), str(Config.is_world_selected())])
	_c.check("every world id selects through Config.set_arena_id in a FULL build and is refused in a DEMO",
		refused.is_empty(), str(refused))
	_c.check("a world selection reaches Config.arena_id()/arena(); a demo never moves off its granted arena",
		misrouted.is_empty(), str(misrouted))

	# The two seats are mutually exclusive: a frozen choice clears the world one.
	if not demo:
		var back := String(frozen_ids[3])
		var cleared := Config.set_arena_id(back) and Config.arena_id() == back and not Config.is_world_selected()
		_c.check("choosing a frozen arena after a world one clears the world seat", cleared,
			"arena_id=%s world=%s" % [Config.arena_id(), str(Config.is_world_selected())])

	# --- 3. the CLI route ------------------------------------------------------
	var cli_problems: Array[String] = []
	for id in ids:
		var cli: Dictionary = Config.apply_cli_selection("", String(id), "")
		var effective := String((cli["effective"] as Dictionary)["arena"])
		var denied: Dictionary = cli["refused"]
		if demo:
			if not denied.has("arena") or effective != String(selected[0]):
				cli_problems.append("%s: demo route refused=%s effective=%s" % [id, str(denied), effective])
		elif denied.has("arena") or effective != String(id):
			cli_problems.append("%s: refused=%s effective=%s" % [id, str(denied), effective])
	_c.check("the CLI route lands on the requested world arena in a FULL build and refuses it by name in a DEMO",
		cli_problems.is_empty(), str(cli_problems))

	# Reset the selection to the build's own first choice before the match work.
	Config.set_arena_id(String(selected[0]))

	# --- 4./5. the REAL match scene: builds, sim state, one played match -------
	if not demo:
		var state_problems: Array[String] = []
		for id in ids:
			Config.set_arena_id(String(id))
			var node := _new_match_node(0)
			if node == null:
				state_problems.append("%s: no match node" % id)
				continue
			var built: Node = node.get_node_or_null("Arena")
			var got_id := String(built.get_meta("arena_id")) if built != null else "<none>"
			var sim_arena: Dictionary = node.state.arena
			if got_id != String(id) or node.arena_mesh_count() < 60 \
					or String(sim_arena.get("id", "")) != String(id) \
					or absf(float(sim_arena.get("wallBounce", -1.0)) - Arena.WORLD_WALL_BOUNCE) > 0.0001 \
					or not bool(sim_arena.get("provisional", false)):
				state_problems.append("%s: env=%s meshes=%d sim=%s bounce=%s" % [
					id, got_id, node.arena_mesh_count(), String(sim_arena.get("id", "")),
					str(sim_arena.get("wallBounce"))])
			_drop(node)
		_c.check("every world arena builds in the REAL match scene, and the sim state carries the provisional wallBounce",
			state_problems.is_empty(), str(state_problems))

		# 5. a FULL quick match PLAYED on EVERY target court — not one arena while
		# the other four are only built. Round-2 review item: the suite completed
		# an actual match on torii alone. One exact log line per arena
		# (`WORLD_PLAYTHROUGH`), the same deterministic conditions for each
		# (harness match node, fixed tick 1/120, the same `ScriptedPlayer`), and
		# one gated result per arena. `ids` defaults to the five world ids; a
		# `--arenas=` subset plays exactly its own list.
		var play_problems: Array[String] = []
		for id_in in ids:
			var played_id := String(id_in)
			if not Arena.has(played_id):
				play_problems.append("%s: not a buildable arena" % played_id)
				continue
			Config.set_arena_id(played_id)
			var node := _new_match_node(1)
			if node == null:
				play_problems.append("%s: no match node" % played_id)
				continue
			var bot := ScriptedPlayer.new()
			var budget_exhausted := false
			while node.state.result == null:
				if node.ticks >= MATCH_TICK_BUDGET:
					budget_exhausted = true
					break
				node.tick_fixed(TICK, bot.decide(node.state), Sim.empty_input())
			var summary: Dictionary = node.summary()
			print("# WORLD_PLAYTHROUGH arena=%s ticks=%d points=%d result=%s score=%s-%s" % [
				played_id, node.ticks, int(summary["points_scored"]), str(node.state.result),
				str(summary["player_score"]), str(summary["ai_score"])])
			var ok := node.state.result != null and not budget_exhausted and int(summary["points_scored"]) >= 1
			if not ok:
				play_problems.append("%s: ticks=%d result=%s points=%s budget_exhausted=%s" % [
					played_id, node.ticks, str(node.state.result), str(summary["points_scored"]), str(budget_exhausted)])
			_c.check("a full quick match PLAYED on world court '%s' reaches a real result (ticks=%d points=%d)" % [
				played_id, node.ticks, int(summary["points_scored"])], ok,
				"ticks=%d result=%s points=%s" % [node.ticks, str(node.state.result), str(summary["points_scored"])])
			_drop(node)
		_c.check("every target world arena completed its own played match (%d arenas, exact lines above)" % ids.size(),
			play_problems.is_empty(), str(play_problems))

	# --- 6. the ported menu column's world row ---------------------------------
	var packed: PackedScene = load(MENU_SCENE)
	if packed == null:
		_c.check("the menu scene loads", false, MENU_SCENE)
	else:
		var menu: Node = packed.instantiate()
		# The shape the slice and the UIR harnesses read: the ported column, with
		# `ui_legacy` set before the tree so `_ready()` builds it exactly as always.
		menu.set("ui_legacy", true)
		var host := Control.new()
		host.name = "SelectionTestFrame"
		host.size = Vector2(1280.0, 720.0)
		root.add_child(host)
		host.add_child(menu)
		await process_frame
		await process_frame
		await process_frame
		var row_problems: Array[String] = []
		for id in ids:
			var button := _find(menu, "WorldArena_%s" % id) as Button
			if demo:
				if button != null:
					row_problems.append("%s: a demo built a world button" % id)
				continue
			if button == null:
				row_problems.append("%s: no WorldArena_ button" % id)
				continue
			var model = menu.focus_model() if menu.has_method("focus_model") else null
			if model == null or not (model.focusable_ids() as Array).has("arena:%s" % id):
				row_problems.append("%s: not focusable in the model" % id)
		_c.check("the ported menu offers one focusable WorldArena_ button per world arena (none in a demo)",
			row_problems.is_empty(), str(row_problems))

		if not demo:
			# Pressing the row selects; pressing a frozen arena clears it again.
			var press_problems: Array[String] = []
			for id_in in ids:
				var id := String(id_in)
				var button := _find(menu, "WorldArena_%s" % id) as Button
				if button == null:
					continue
				button.emit_signal("pressed")
				if Config.arena_id() != id or not Config.is_world_selected():
					press_problems.append("%s: press landed on %s" % [id, Config.arena_id()])
			var back_id := String(selected[0])
			var back_button: Button = _find(menu, "Arena_%s" % back_id) as Button
			if back_button == null:
				press_problems.append("no Arena_%s button to clear with" % back_id)
			else:
				back_button.emit_signal("pressed")
				if Config.arena_id() != back_id or Config.is_world_selected():
					press_problems.append("frozen press left arena_id=%s world=%s" % [Config.arena_id(), str(Config.is_world_selected())])
			_c.check("a world button press selects that arena, and a frozen press clears the world seat",
				press_problems.is_empty(), str(press_problems))
		root.remove_child(host)
		host.free()

	# --- 7b. the world work never entered the frozen list ----------------------
	_c.check("the world work never entered selectable_arenas() (the frozen list this build reports)",
		Config.selectable_arenas().size() == (1 if demo else 9),
		"%d offered" % Config.selectable_arenas().size())

	_c.verdict()
	_state = 2
	quit(_c.exit_code())


# ---------------------------------------------------------------------------
# Helpers (the slice's own shapes: instantiate Match.tscn in harness mode, find
# a node by name)
# ---------------------------------------------------------------------------

func _new_match_node(tier_index: int) -> Node:
	Config.pending_mode = "quick"
	Config.pending_round = -1
	Config.tier_index = tier_index
	var packed: PackedScene = load(MATCH_SCENE)
	if packed == null:
		return null
	var node: Node = packed.instantiate()
	node.harness_mode()
	root.add_child(node)
	node.start_match()
	return node


func _drop(node: Node) -> void:
	root.remove_child(node)
	node.free()


func _find(from: Node, node_name: String) -> Node:
	for node in from.find_children("*", "", true, false):
		if String(node.name) == node_name:
			return node
	return null
