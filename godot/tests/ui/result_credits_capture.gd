extends SceneTree
## Native visual fixture only: constructed result, no wallet or TypeSafe request.

const ScreenScene := preload("res://src/ui/screens/ResultScreen.tscn")
const Economy := preload("res://src/economy/economy_service.gd")
const Locale := preload("res://src/locale/locale.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var loss := OS.get_cmdline_user_args().has("--loss")
	Locale.set_lang("en" if loss else "it")
	var screen := ScreenScene.instantiate()
	root.add_child(screen)
	var points_played := 28 if loss else 18
	var earned := 76 if loss else 71
	var breakdown := Economy.reward_breakdown(points_played, not loss)
	screen.enter({
		"mode": "quick", "arena_id": "officina", "won": not loss,
		"result": {
			"score": "1-3" if loss else "11-7", "won": not loss,
			"player": 1 if loss else 11, "ai": 3 if loss else 7, "pointsToWin": 0 if loss else 11,
			"stats": {
				"pointsWon": {"player": 12, "ai": 16} if loss else {"player": 11, "ai": 7},
				"aces": {"player": 0, "ai": 0} if loss else {"player": 2, "ai": 1},
				"winners": {"player": 12, "ai": 14} if loss else {"player": 8, "ai": 5},
				"errors": {"player": 2, "ai": 0} if loss else {"player": 2, "ai": 4},
				"rallyCount": points_played, "totalRallyHits": 182 if loss else 78,
				"longestRally": 22 if loss else 12,
			},
		},
		"reward": {
			"ok": true, "already": false, "awarded": earned, "earned": earned,
			"balance": 1002 if loss else 421, "breakdown": breakdown,
		},
	})
	for _i in 5:
		await process_frame
	var filename := "result-premium-loss-1280x720.png" if loss else "result-credits-1280x720.png"
	var path := ProjectSettings.globalize_path("res://../docs/agent-work/result-credits/%s" % filename)
	var err := root.get_viewport().get_texture().get_image().save_png(path)
	print("RESULT_CREDITS_CAPTURE %s %s" % [path, err])
	quit(0 if err == OK else 1)
