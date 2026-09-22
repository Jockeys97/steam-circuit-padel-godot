extends SceneTree
const Config = preload("res://game/match_config.gd")
const Save = preload("res://src/modes/modes_save.gd")
const Spawn = preload("res://src/character/athlete_spawn.gd")
const Catalogue = preload("res://src/character/outfit_catalogue.gd")
const Lineup = preload("res://game/lineup.gd")
const Frozen = preload("res://src/sim/frozen.gd")
const IDS = ["fiamma", "pantera", "steamer", "oracolo", "colosso"]
var checks := 0
var failures := 0
var matches := 0
func check(ok: bool, message: String):
	checks += 1
	if not ok:
		failures += 1
		print("FAIL ",message)
func _initialize(): call_deferred("run")
func run():
	Config.save_dir = "user://mythic-batch-test-%s" % Time.get_ticks_usec()
	var career := Save.load_career(Config.save_store())
	career.unlockAll = true
	Save.save_career(Config.save_store(),career)
	var screen = load("res://src/ui/screens/CharactersScreen.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	for id in IDS:
		check(screen.equip_outfit(id,"mythic"),"real wardrobe accepts "+id)
		check(Lineup.equipped_outfit(id,Save.load_career(Config.save_store())) == &"mythic","disk reload retains "+id)
		check(Lineup.equipped_outfit(id,{"equippedOutfits":{id:"mythic"},"outfitsWon":{}}) == &"base","locked skin stays locked "+id)
		var base = Spawn.make(StringName(id),&"base")
		var mythic = Spawn.make(StringName(id),&"mythic")
		check(base != null and mythic != null,"both bodies load "+id)
		if base != null and mythic != null:
			check(not base.get_athlete_glb_path().contains("/mythic/"),"original body retained "+id)
			check(mythic.get_athlete_glb_path().contains("/"+id+"/mythic/"),"dedicated geometry "+id)
			check(mythic.get_geometry_outfit() == &"mythic" and mythic.get_athlete_asset() == StringName(id),"identity retained "+id)
			check(Catalogue.read_back(mythic).get("visual_status") == "applied","catalogue confirms real skin "+id)
			check(not Spawn.set_outfit(mythic,StringName(id),&"base"),"unsafe hot mesh replacement refused "+id)
			for clip in [&"idle", &"walk", &"run"]:
				check(mythic.play_clip(clip),"locomotion "+id+String(clip))
			base.free()
			mythic.free()
	screen.hide()
	for id in IDS:
		for i in Frozen.athletes().size():
			if Frozen.athletes()[i].id == id:
				Config.athlete_index = i
		Config.special_athlete_id = ""
		Config.pending_mode = "quick"
		var others := IDS.duplicate()
		others.erase(id)
		Save.save_pref(Config.save_store(),"lineup",{"playerMate":others[0],"opponent":others[1],"opponentMate":others[2]})
		Lineup.set_pref_source(Config.stored_prefs())
		var game = load("res://game/Match.tscn").instantiate()
		game.harness_mode()
		root.add_child(game)
		await process_frame
		check(game.build_athletes() == 4,"four real match rigs "+id)
		check(game._athletes.rigs.player.get_athlete_asset() == StringName(id),"selected player reaches match "+id)
		for role in ["player","playerMate","opponent","opponentMate"]:
			var rig = game._athletes.rigs[role]
			check(game._athletes.outfits[role] == &"mythic" and rig.get_geometry_outfit() == &"mythic","saved outfit reaches "+id+role)
			check(Catalogue.read_back(rig).get("visual_status") == "applied","real match material "+id+role)
			check(game._athletes.rackets[role].get_parent() is BoneAttachment3D,"racket anchored "+id+role)
			for shot in ["drive","smash","bandeja","backhand","slice"]:
				check(StringName("meshy_"+shot) in rig.get_stroke_names(),"stroke installed "+id+role+shot)
		if "--capture" in OS.get_cmdline_user_args():
			game._sync_views()
			await process_frame
			await RenderingServer.frame_post_draw
			var path = ProjectSettings.globalize_path("res://../docs/agent-work/meshy-mythic-batch/"+id+"-rig/match.png")
			check(root.get_texture().get_image().save_png(path) == OK,"match capture "+id)
		game.free()
		matches += 1
		await process_frame
	screen.free()
	check(matches == 5,"all five match sections completed")
	print("MYTHIC_BATCH_INTEGRATION %d/%d" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
