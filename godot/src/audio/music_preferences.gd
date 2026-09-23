extends RefCounted
## Independent menu/match favourites; playback access remains Economy's authority.
const Save := preload("res://src/modes/modes_save.gd")
const Manager := preload("res://src/audio/soundtrack_manager.gd")

static func read(store) -> Dictionary:
	var value: Variant = store.read_group("prefs").get("payload", {})
	return value if value is Dictionary else {}

static func favorites(store, scope: String) -> Array[String]:
	var result: Array[String] = []
	var raw: Variant = read(store).get("musicFavorites_" + scope, [])
	if raw is Array:
		for value in raw:
			var id := String(value)
			if (id == "classic_match" or Manager.all_track_ids().has(id)) and not result.has(id):
				result.append(id)
	return result

static func toggle(store, scope: String, id: String) -> void:
	var ids := favorites(store, scope)
	if ids.has(id):
		ids.erase(id)
	else:
		ids.append(id)
	Save.save_pref(store, "musicFavorites_" + scope, ids)

static func only(store, scope: String) -> bool:
	return bool(read(store).get("musicOnlyFavorites_" + scope, false))

static func set_only(store, scope: String, enabled: bool) -> void:
	Save.save_pref(store, "musicOnlyFavorites_" + scope, enabled)

static func random_skip(store) -> bool:
	return bool(read(store).get("musicRandomR3", false))

static func set_random_skip(store, enabled: bool) -> void:
	Save.save_pref(store, "musicRandomR3", enabled)

static func belongs(store, id: String, scope: String) -> bool:
	var overrides: Variant = read(store).get("musicContexts", {})
	if overrides is Dictionary and overrides.get(id) is Array:
		return overrides[id].has(scope)
	var menu := id in ["ost_menu", "ost_roster", "ost_career"]
	return menu == (scope == "menu") or favorites(store, scope).has(id)

static func transfer(store, id: String, source: String, move: bool) -> void:
	var target := "match" if source == "menu" else "menu"
	var prefs := read(store)
	var raw: Variant = prefs.get("musicContexts", {})
	var contexts: Dictionary = raw.duplicate(true) if raw is Dictionary else {}
	contexts[id] = [target] if move else ["menu", "match"]
	prefs["musicContexts"] = contexts
	var source_favorites := favorites(store, source)
	var target_favorites := favorites(store, target)
	if source_favorites.has(id):
		if not target_favorites.has(id):
			target_favorites.append(id)
		if move:
			source_favorites.erase(id)
	prefs["musicFavorites_" + source] = source_favorites
	prefs["musicFavorites_" + target] = target_favorites
	# One write preserves unrelated preferences and both halves of a move together.
	store.write_group("prefs", prefs)
