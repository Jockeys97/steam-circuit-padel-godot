extends SceneTree
## save_steam_test.gd — the headless proof for slice S11's save + Steam seam.
##
##   flock -w 900 /tmp/padel-godot.lock timeout 180 env -u DISPLAY \
##     GODOT_SILENCE_ROOT_WARNING=1 /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 \
##     --headless --path godot/ --script res://tests/save_steam_test.gd
##
## Same machine-readable contract as `res://tests/smoke_test.gd`:
##   ok <name> / FAIL <name>: expected <x>, got <y> / PASS n/n | FAIL n/n
## and exit 0 on PASS, 1 on FAIL.
##
## What it proves, and what it refuses to imply:
##
##   SAVE (real engine code, real files under user://save_test)
##     * a realistic profile — the exact fields the reference persists, read out
##       of `js/ui.js` — round-trips group by group through `SaveStore`;
##     * a deliberately incomplete career payload loads with the reference's
##       defaults merged in, not as an empty profile;
##     * an interrupted write leaves the previous file fully intact and no
##       partial `.tmp` behind (the store's failure hook);
##     * a corrupt file is quarantined with its bytes preserved and the group
##       falls back to defaults;
##     * a v0 (unversioned) sample migrates to v1 with every field kept;
##     * a save from an unknown future schema version is REFUSED with the file
##       left untouched — never silently emptied.
##
##   STEAM SEAM (mock only)
##     * achievement unlocks reach the backend at most once per achievement;
##     * the source->API-name mapping is empty and `unlock_source` refuses, so
##       no achievement id is invented while the prerequisites ticket is open;
##     * a cloud upload/download round-trips through the mock and the local file
##       still exists afterwards — cloud is never the only copy;
##     * with no Steam backend the achievement, upload and download paths all
##       skip honestly, and the mock reports failure rather than success for a
##       call it cannot make.
##
## NO LIVE STEAM BEHAVIOUR IS PROVEN HERE. Every Steam assertion below is against
## `MockSteamBackend`, which states on itself that it is a mock. The real backend
## is only checked for degrading correctly with the addon absent.

const Schema := preload("res://src/save/save_schema.gd")
const Store := preload("res://src/save/save_store.gd")
const Migration := preload("res://src/save/save_migration.gd")
const Factory := preload("res://src/steam/steam_backend_factory.gd")
const MockBackend := preload("res://src/steam/mock_steam_backend.gd")
const RealBackend := preload("res://src/steam/godotsteam_backend.gd")
const Achievements := preload("res://src/steam/achievements.gd")
const CloudSaves := preload("res://src/steam/cloud_saves.gd")

## Test root: never the real profile directory.
const TEST_DIR: String = "user://save_test"

var _checks: int = 0
var _failures: int = 0
var _fail_lines: Array[String] = []
var _sections_done: Array[String] = []
var _ran: bool = false


func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	_run_all()
	return true


func _run_all() -> void:
	print("# Godot %s · slice S11 save + Steam seam" % Engine.get_version_info().get("string", "?"))
	_wipe(TEST_DIR)

	_schema_anchors()
	_round_trip()
	_merge_against_defaults()
	_atomic_write()
	_corruption_recovery()
	_version_migration()
	_achievements_against_mock()
	_cloud_against_mock()
	_real_backend_degrades()

	# A runtime error aborts only the function it happens in; the caller carries
	# on. So a broken section could otherwise finish the run without failing it.
	# Each section marks itself complete as its last statement, and here that
	# marker list is checked — a section that died half-way is a red run.
	var expected: Array = [
		"schema_anchors", "round_trip", "merge_against_defaults", "atomic_write",
		"corruption_recovery", "version_migration", "achievements_against_mock",
		"cloud_against_mock", "real_backend_degrades",
	]
	var missing: Array = []
	for s in expected:
		if not _sections_done.has(s):
			missing.append(s)
	check_eq("every test section ran to completion", missing.size(), 0)
	if not missing.is_empty():
		print("# sections that never finished: %s" % str(missing))

	_wipe(TEST_DIR)

	if _failures == 0:
		print("PASS %d/%d" % [_checks, _checks])
		quit(0)
	else:
		print("FAIL %d/%d" % [_checks - _failures, _checks])
		for line in _fail_lines:
			printerr(line)
		quit(1)


func _mark(section: String) -> void:
	if not _sections_done.has(section):
		_sections_done.append(section)


# ---------------------------------------------------------------------------
# Checks
# ---------------------------------------------------------------------------

func check(name: String, condition: bool, got: Variant = "") -> void:
	_checks += 1
	if condition:
		print("ok %s" % name)
		return
	_failures += 1
	var line := "FAIL %s: expected true, got %s" % [name, str(got)]
	print(line)
	_fail_lines.append(line)


func check_eq(name: String, actual: Variant, expected: Variant) -> void:
	_checks += 1
	if actual == expected:
		print("ok %s" % name)
		return
	_failures += 1
	var line := "FAIL %s: expected %s, got %s" % [name, str(expected), str(actual)]
	print(line)
	_fail_lines.append(line)


## Structural equality that ignores key order and int/float spelling — the right
## comparison for a JSON round-trip, since JSON has no int/float distinction.
func json_eq(a: Variant, b: Variant) -> bool:
	return JSON.stringify(a) == JSON.stringify(b)


# ---------------------------------------------------------------------------
# The reference profile: exactly what `js/ui.js` persists, values and all
# ---------------------------------------------------------------------------

func _realistic_prefs() -> Dictionary:
	# Every field `collectPrefs()` writes (`js/ui.js:422-442`), non-default so a
	# round-trip that dropped one would be visible, plus the port's own additions,
	# non-default for the same reason. The key order is `PREFS_DEFAULTS`'s, because
	# the comparison below is `JSON.stringify` equality.
	return {
		# PORT ADDITION: the match camera preset (`game/court.gd::CAMERAS`).
		"cameraPreset": "broadcast",
		"athleteId": "maestro",
		"arenaId": "arena-centrale",
		"mode": "career",
		"tournamentRound": 2,
		"muted": false,
		"volume": 0.35,
		# PORT ADDITIONS: the Music bus level, its mute, and the now-playing toast.
		"musicVolume": 0.6,
		"musicMuted": true,
		"nowPlaying": false,
		"controlMode": "manual",
		"gamepadDeadzone": 0.22,
		"vibration": false,
		"aiDifficulty": "hard",
		"matchLength": "sets3",
		"reduceMotion": true,
		"matchPanel": true,
		"colorblind": true,
		"lang": "it",
		"playerMode": "pvp",
		# PORT ADDITION, no `js/ui.js` line: the game-pace preset (`src/sim/pace.gd`).
		"pacePreset": "relaxed",
		"lineup": {"playerMate": "pantera", "opponent": "maestro", "opponentMate": "pantera"},
	}


func _realistic_career() -> Dictionary:
	# `js/ui.js:12-36` fields, plus the ones the game adds on the way
	# (`outfitsWon`/`athleteWins` at `js/ui.js:629-630`).
	return {
		"season": 4,
		"matchIndex": 2,
		"wins": 11,
		"losses": 3,
		"trophies": 1,
		"stars": 7,
		"seasonObjectives": [{"id": "winners", "target": 10, "claimed": true}],
		"seasonStars": 2,
		"rivalStreak": 1,
		"seasonWins": 2,
		"seasonProgress": {
			"pointsWon": 41,
			"winners": 12,
			"smashWinners": 5,
			"errors": 3,
			"doubleFaults": 1,
			"longestRally": 9,
		},
		"claimedObjectives": {"4": ["winners"]},
		"bestSeason": 4,
		"finaleSeen": true,
		"unlockAll": false,
		"equippedOutfits": {"maestro": "base"},
		"outfitsWon": {"maestro-challenge-1": true},
		"athleteWins": {"maestro": 6},
	}


func _realistic_history() -> Array:
	# One entry in the exact shape `recordMatch` is called with (`js/main.js:1399-1414`).
	return [{
		"ts": 1789000000000,
		"mode": "career",
		"humanMode": "solo",
		"winner": "player",
		"score": "6-4, 3-6, 7-5",
		"opponent": "Pantera",
		"athlete": "Maestro",
		"arena": "Centrale",
		"difficulty": "hard",
		"pointsToWin": 11,
		"trophy": true,
		"season": 4,
	}]


func _realistic_drill() -> Dictionary:
	# One record per exercise (`js/ui.js:206-230`).
	return {"target": 7, "rally": 12, "serve": 5}


func _realistic_feedback() -> Array:
	# One queue entry in the shape `queueFeedback` builds (`js/ui.js:316-333`).
	return [{
		"id": "fb-abc123",
		"ts": "2026-09-16T10:00:00.000Z",
		"topic": "balance",
		"message": "lo smash e' troppo forte",
		"contact": "",
		"diagnostics": {
			"version": "alpha-0.2",
			"balance": "b7",
			"lang": "it",
			"demo": false,
			"career": {"season": 4, "trophies": 1, "stars": 7, "wins": 11, "losses": 3},
			"drillRecords": {"target": 7},
			"recentMatches": [],
			"matchesPlayed": 1,
		},
		"sent": false,
	}]


func _realistic_profile() -> Dictionary:
	return {
		"prefs": _realistic_prefs(),
		"career": _realistic_career(),
		"history": _realistic_history(),
		"drill": _realistic_drill(),
		"feedback": _realistic_feedback(),
	}


# ---------------------------------------------------------------------------
# 1. Schema anchors — the schema may not drift from the reference
# ---------------------------------------------------------------------------

func _schema_anchors() -> void:
	check_eq("save root is user://save (js/ui.js:7-11 has five localStorage keys)",
		Schema.SAVE_DIR, "user://save")
	check_eq("there is one save group per reference key", Schema.group_names().size(), 5)
	var files := {}
	for g in Schema.group_names():
		files[Schema.GROUP_FILES[g]] = true
	check_eq("no two groups share a file", files.size(), 5)
	check_eq("history is capped at 20 entries (js/ui.js:1551)", Schema.HISTORY_CAP, 20)
	check_eq("feedback queue is capped at FEEDBACK.maxQueued (js/data.js:73)", Schema.FEEDBACK_MAX_QUEUED, 40)

	# The career defaults are the reference's DEFAULT_CAREER (js/ui.js:12-36),
	# not a smaller hand-made set.
	check_eq("career defaults carry all 16 reference fields", Schema.CAREER_DEFAULTS.size(), 16)
	check_eq("career default season is 1 (js/ui.js:13)", int(Schema.CAREER_DEFAULTS["season"]), 1)
	check_eq("career default seasonProgress has the 6 SEASON_METRIC_AGG keys (js/data.js:775-782)",
		(Schema.CAREER_DEFAULTS["seasonProgress"] as Dictionary).size(), 6)
	check("career default seasonProgress keys match the reference exactly",
		json_eq(Schema.CAREER_DEFAULTS["seasonProgress"].keys(),
			["pointsWon", "winners", "smashWinners", "errors", "doubleFaults", "longestRally"]),
		str(Schema.CAREER_DEFAULTS["seasonProgress"].keys()))
	check_eq("career default claimedObjectives is empty (js/ui.js:30)", Schema.CAREER_DEFAULTS["claimedObjectives"], {})

	# The prefs defaults are the `ui` object's own start values (js/ui.js:460-481)
	# for every field collectPrefs writes, plus the audio defaults, plus the port's
	# own additions. Counted apart, so a reference field that goes missing still
	# fails even while the port adds keys of its own.
	const PORT_PREF_KEYS := ["cameraPreset", "musicVolume", "musicMuted", "nowPlaying", "pacePreset"]
	var reference_prefs := Schema.PREFS_DEFAULTS.size() - PORT_PREF_KEYS.size()
	check_eq("prefs defaults carry all 17 collectPrefs fields", reference_prefs, 17)
	for key in PORT_PREF_KEYS:
		check("prefs defaults carry the port addition '%s'" % key,
			Schema.PREFS_DEFAULTS.has(key), str(Schema.PREFS_DEFAULTS.keys()))
	check_eq("prefs default controlMode is 'semi' (js/ui.js:466)", Schema.PREFS_DEFAULTS["controlMode"], "semi")
	check_eq("prefs default gamepadDeadzone is 0.15 (js/ui.js:467)", Schema.PREFS_DEFAULTS["gamepadDeadzone"], 0.15)
	check_eq("prefs default matchLength is 'points11' (js/ui.js:470)", Schema.PREFS_DEFAULTS["matchLength"], "points11")
	check_eq("prefs default volume is 0.5 (js/audio.js:5)", Schema.PREFS_DEFAULTS["volume"], 0.5)
	check_eq("prefs default tournamentRound is 0 (js/ui.js:464)", Schema.PREFS_DEFAULTS["tournamentRound"], 0)
	check("prefs defaults carry the lineup triple (js/ui.js:480)",
		json_eq(Schema.PREFS_DEFAULTS["lineup"], {"playerMate": null, "opponent": null, "opponentMate": null}),
		str(Schema.PREFS_DEFAULTS["lineup"]))

	# The writing build is recorded, the way the feedback carries it.
	check("the envelope records the writing build (js/data.js:20)",
		Schema.BUILD == "alpha-0.2" and Schema.BALANCE == "b7",
		"%s/%s" % [Schema.BUILD, Schema.BALANCE])
	_mark("schema_anchors")


# ---------------------------------------------------------------------------
# 2. Round-trip through the real store on real files
# ---------------------------------------------------------------------------

func _round_trip() -> void:
	var store: RefCounted = Store.new(TEST_DIR)
	var profile := _realistic_profile()
	var w: Dictionary = store.write_all(profile)
	check("write_all writes every group", bool(w["ok"]), str(w["errors"]))
	check("write_all reports non-zero bytes", int(w["bytes_total"]) > 0, str(w["bytes_total"]))

	var on_disk_ok := true
	var on_disk_detail := []
	for g in Schema.group_names():
		var p: String = store.group_path(g)
		if not FileAccess.file_exists(p):
			on_disk_ok = false
			on_disk_detail.append("%s missing" % p)
			continue
		var f := FileAccess.open(p, FileAccess.READ)
		var n := f.get_length()
		f.close()
		on_disk_detail.append("%s=%d" % [g, n])
		if n <= 0:
			on_disk_ok = false
	check("every group is a real non-empty file on disk", on_disk_ok, str(on_disk_detail))

	var r: Dictionary = store.read_all()
	check("read_all succeeds with nothing recovered or refused",
		bool(r["ok"]) and (r["recovered"] as Array).is_empty() and (r["refused"] as Array).is_empty(),
		str(r["errors"]))

	var back: Dictionary = r["profile"]
	check("career round-trips field for field", json_eq(back["career"], profile["career"]), str(back["career"].keys()))
	check("prefs round-trip field for field", json_eq(back["prefs"], profile["prefs"]), str(back["prefs"]))
	check("history round-trips (1 entry)", json_eq(back["history"], profile["history"]), str(back["history"]))
	check("drill records round-trip", json_eq(back["drill"], profile["drill"]), str(back["drill"]))
	check("the feedback queue round-trips with `sent` preserved",
		json_eq(back["feedback"], profile["feedback"]) and back["feedback"][0]["sent"] == false,
		str(back["feedback"]))
	check_eq("the feedback entry keeps its topic (js/data.js:78)", back["feedback"][0]["topic"], "balance")
	# Godot's JSON parser returns every number as a float; the store normalises
	# whole-valued numbers back to ints so a round-trip is exact and the game's
	# integer fields reload as integers.
	check("whole numbers reload as ints, not floats",
		typeof(back["career"]["season"]) == TYPE_INT and typeof(back["career"]["stars"]) == TYPE_INT
			and typeof(back["history"][0]["ts"]) == TYPE_INT,
		"%s/%s/%s" % [str(typeof(back["career"]["season"])), str(typeof(back["career"]["stars"])),
			str(typeof(back["history"][0]["ts"]))])
	check("fractional numbers stay floats",
		typeof(back["prefs"]["gamepadDeadzone"]) == TYPE_FLOAT
			and typeof(back["prefs"]["volume"]) == TYPE_FLOAT,
		"%s/%s" % [str(typeof(back["prefs"]["gamepadDeadzone"])), str(typeof(back["prefs"]["volume"]))])

	# The file itself is the documented envelope, checkable without the engine.
	var raw := FileAccess.open(store.group_path("career"), FileAccess.READ).get_as_text()
	var parsed: Variant = JSON.parse_string(raw)
	check("the career file is a JSON object", parsed is Dictionary, str(typeof(parsed)))
	check_eq("the file carries the format tag", String((parsed as Dictionary).get("format", "")), Schema.FORMAT_TAG)
	check_eq("the file carries schemaVersion 1", int((parsed as Dictionary).get("schemaVersion", -1)), 1)
	check_eq("the file carries the build that wrote it", String((parsed as Dictionary).get("build", "")), "alpha-0.2")
	check("the payload is nested under `payload`", (parsed as Dictionary).has("payload"), str((parsed as Dictionary).keys()))
	check("store.last_write_ok and byte count are recorded",
		bool(store.last_write_ok) and int(store.last_write_bytes) > 0,
		"%s/%d" % [str(store.last_write_ok), int(store.last_write_bytes)])
	_mark("round_trip")


# ---------------------------------------------------------------------------
# 3. Merge against defaults — the merge rule from js/ui.js:41
# ---------------------------------------------------------------------------

func _merge_against_defaults() -> void:
	var store: RefCounted = Store.new(TEST_DIR)

	# A payload written by an older/partial build: one field only.
	var w: Dictionary = store.write_group("career", {"season": 4})
	check("an incomplete career payload can be written", bool(w["ok"]), str(w["message"]))
	var merged: Dictionary = store.read_all()["profile"]["career"]
	check_eq("the stored field survives the merge", int(merged["season"]), 4)
	check_eq("missing matchIndex is the default 0 (js/ui.js:14)", int(merged["matchIndex"]), 0)
	check_eq("missing trophies is the default 0 (js/ui.js:17)", int(merged["trophies"]), 0)
	check_eq("missing seasonProgress gains all 6 default metrics", (merged["seasonProgress"] as Dictionary).size(), 6)
	check_eq("missing claimedObjectives is {}", merged["claimedObjectives"], {})
	check_eq("missing equippedOutfits is {}", merged["equippedOutfits"], {})
	check_eq("missing unlockAll is false", merged["unlockAll"], false)
	check_eq("missing finaleSeen is false", merged["finaleSeen"], false)

	# Unknown extra keys are kept, like JS spread keeps them.
	var w2: Dictionary = store.write_group("career", {"season": 5, "futureField": "kept"})
	check("a payload with an unknown key is written", bool(w2["ok"]), str(w2["message"]))
	var merged2: Dictionary = store.read_all()["profile"]["career"]
	check_eq("a field the schema does not know is preserved, not dropped", merged2.get("futureField", ""), "kept")
	check_eq("and the known field is still there", int(merged2["season"]), 5)

	# An explicit null in the payload is kept (the reference's spread does too):
	# only a MISSING key is supplied by the defaults.
	store.write_group("prefs", {"lang": "it"})
	var prefs: Dictionary = store.read_all()["profile"]["prefs"]
	check_eq("a stored prefs field wins over its default", prefs["lang"], "it")
	check_eq("a missing prefs field is supplied by the ui defaults (js/ui.js:466)",
		prefs["controlMode"], "semi")

	# A fresh install: no files at all is not corruption.
	_wipe(TEST_DIR)
	var fresh: Dictionary = store.read_all()
	check("a fresh install reads as a complete empty profile, not an error",
		bool(fresh["ok"]) and (fresh["refused"] as Array).is_empty()
			and int(fresh["profile"]["career"]["season"]) == 1
			and (fresh["profile"]["history"] as Array).is_empty(),
		str(fresh["errors"]))
	check("the fresh profile's groups were all absent, not corrupt",
		(fresh["recovered"] as Array).is_empty(),
		str(fresh["recovered"]))
	_mark("merge_against_defaults")


# ---------------------------------------------------------------------------
# 4. Atomic write — the commit point is the rename
# ---------------------------------------------------------------------------

func _atomic_write() -> void:
	var store: RefCounted = Store.new(TEST_DIR)
	store.write_group("drill", {"target": 3, "rally": 4})
	var path: String = store.group_path("drill")
	var before := FileAccess.open(path, FileAccess.READ).get_as_text()

	# Overwriting an existing file must work (rename over an existing target).
	var over: Dictionary = store.write_group("drill", {"target": 9, "rally": 4})
	check("a second write replaces the first in place", bool(over["ok"]), str(over["message"]))
	check_eq("the new payload is the one on disk", int(store.read_group("drill")["payload"]["target"]), 9)

	# Now the interrupted write: the failure hook fires after the temp file is
	# written and before the rename.
	var before_bytes := FileAccess.open(path, FileAccess.READ).get_as_text()
	store.fail_before_rename = true
	var failed: Dictionary = store.write_group("drill", {"target": 99, "rally": 4})
	check("an interrupted write reports failure", not bool(failed["ok"]) and bool(failed.get("simulated", false)),
		str(failed))
	store.fail_before_rename = false

	var after_bytes := FileAccess.open(path, FileAccess.READ).get_as_text()
	check("the target file is byte-identical after the interrupted write", after_bytes == before_bytes,
		"len %d vs %d" % [after_bytes.length(), before_bytes.length()])
	check_eq("the old payload is still the one on disk", int(store.read_group("drill")["payload"]["target"]), 9)
	check("no .tmp file is left behind", not FileAccess.file_exists(path + ".tmp"), path + ".tmp")
	check("the previous good content was non-empty to begin with", before.length() > 0, str(before.length()))
	_mark("atomic_write")


# ---------------------------------------------------------------------------
# 5. Corruption recovery — quarantine the bytes, fall back to defaults
# ---------------------------------------------------------------------------

func _corruption_recovery() -> void:
	var store: RefCounted = Store.new(TEST_DIR)
	store.write_all(_realistic_profile())

	var career_path: String = store.group_path("career")
	var f := FileAccess.open(career_path, FileAccess.WRITE)
	f.store_string("{\"payload\": this is not json")
	f.close()

	var r: Dictionary = store.read_all()
	check("read_all reports the corrupted group",
		(r["recovered"] as Array).has("career"),
		"recovered=%s refused=%s errors=%s" % [str(r["recovered"]), str(r["refused"]), str(r["errors"])])
	check("the corrupt group falls back to the reference defaults, not an empty profile",
		int(r["profile"]["career"]["season"]) == 1 and (r["profile"]["career"] as Dictionary).size() == 16,
		str(r["profile"]["career"].keys()))
	check("the other groups are untouched by one corrupt file",
		json_eq(r["profile"]["drill"], _realistic_drill()) and (r["profile"]["history"] as Array).size() == 1,
		"%s / %d" % [str(r["profile"]["drill"]), (r["profile"]["history"] as Array).size()])

	var quarantine: String = String(r["groups"]["career"]["quarantine_path"])
	check("the corrupt file was quarantined, not deleted", quarantine != "" and FileAccess.file_exists(quarantine),
		quarantine)
	if quarantine != "":
		var kept := FileAccess.open(quarantine, FileAccess.READ).get_as_text()
		check_eq("the quarantined bytes are the ones that were there", kept, "{\"payload\": this is not json")
	check("the corrupted path itself is gone (renamed away)", not FileAccess.file_exists(career_path), career_path)

	# And a further write rebuilds the group cleanly.
	var rebuilt: Dictionary = store.write_group("career", {"season": 2})
	check("a clean write after recovery succeeds", bool(rebuilt["ok"]), str(rebuilt["message"]))
	check_eq("the rebuilt file reads back", int(store.read_group("career")["payload"]["season"]), 2)
	_mark("corruption_recovery")


# ---------------------------------------------------------------------------
# 6. Version migration — v0 migrates, an unknown version is refused
# ---------------------------------------------------------------------------

func _version_migration() -> void:
	var store: RefCounted = Store.new(TEST_DIR)
	_wipe(TEST_DIR)

	# A v0 sample: exactly what the browser stored — a bare payload with no
	# envelope at all.
	var v0: Dictionary = {"season": 4, "stars": 9, "wins": 11, "legacyField": "preserved"}
	var f := FileAccess.open(store.group_path("career"), FileAccess.WRITE)
	f.store_string(JSON.stringify(v0))
	f.close()
	check_eq("the v0 sample has no schemaVersion", Migration.detect_version(JSON.parse_string(FileAccess.open(store.group_path("career"), FileAccess.READ).get_as_text())), 0)

	var read: Dictionary = store.read_group("career")
	check("the v0 file is read as a migration, not a corruption", bool(read["ok"]) and bool(read["migrated"]),
		str(read["message"]))
	check_eq("v0 -> v1 preserves a stored field verbatim", int(read["payload"]["stars"]), 9)
	check_eq("v0 -> v1 preserves an unknown field too", read["payload"]["legacyField"], "preserved")
	var mig: Dictionary = Migration.migrate(v0, "career")
	check_eq("the migrated envelope is at the current schema version",
		int(mig["envelope"]["schemaVersion"]), Schema.CURRENT_SCHEMA_VERSION)
	check_eq("the migrated envelope records where it came from", int(mig["envelope"].get(Migration.MIGRATED_FROM_KEY, -1)), 0)
	check("migration reports the action it took", (mig["actions"] as Array).size() == 1, str(mig["actions"]))

	# A v0 list group (history is an Array in the reference) migrates as an Array.
	var hf := FileAccess.open(store.group_path("history"), FileAccess.WRITE)
	hf.store_string(JSON.stringify([{"mode": "quick", "winner": "player"}]))
	hf.close()
	var hread: Dictionary = store.read_group("history")
	check("a v0 array payload migrates as an array",
		bool(hread["ok"]) and hread["payload"] is Array and (hread["payload"] as Array).size() == 1,
		str(hread["message"]))

	# An unknown FUTURE version is refused, and the file is left alone.
	var future: Dictionary = Schema.envelope("career", {"season": 9})
	future["schemaVersion"] = 99
	var cf := FileAccess.open(store.group_path("career"), FileAccess.WRITE)
	cf.store_string(JSON.stringify(future))
	cf.close()
	var future_bytes := FileAccess.open(store.group_path("career"), FileAccess.READ).get_as_text()

	var r: Dictionary = store.read_group("career")
	check("a save from an unknown future schema version is refused", bool(r["refused"]), str(r["message"]))
	check("the refusal does not claim a payload to merge", r["payload"] == null, str(r["payload"]))
	check("the refused file is NOT quarantined (the bytes are left for a newer build)",
		String(r["quarantine_path"]) == "" and FileAccess.file_exists(store.group_path("career")),
		str(r["quarantine_path"]))
	check_eq("the refused file is byte-identical after the read",
		FileAccess.open(store.group_path("career"), FileAccess.READ).get_as_text(), future_bytes)

	# The whole-profile read surfaces that refusal instead of hiding it.
	var all: Dictionary = store.read_all()
	check("read_all lists the refusal", (all["refused"] as Array).has("career"), str(all["refused"]))
	check("read_all reports the profile as not ok while a group is refused", not bool(all["ok"]), str(all["errors"]))
	_mark("version_migration")


# ---------------------------------------------------------------------------
# 7. Achievements against the mock — exactly once each, and no invented ids
# ---------------------------------------------------------------------------

func _achievements_against_mock() -> void:
	# The mapping is gated: while steamworks-prerequisites is open, nothing may
	# map a source to an id.
	var gated_backend: RefCounted = MockBackend.new(MockBackend.Mode.AVAILABLE)
	gated_backend.init_backend()
	var gated: RefCounted = Achievements.new(gated_backend)
	check("no source->API-name mapping exists yet (steamworks-prerequisites open)", not bool(gated.mapping_ready()))
	check("unlock_source refuses while the mapping is empty", not bool(gated.unlock_source("career.stars")), "refused")
	check("the refusal is recorded with its reason",
		(gated.refusals() as Array).size() == 1 and String(gated.refusals()[0]["reason"]).contains("refusing to invent"),
		str(gated.refusals()))
	check_eq("no achievement reached the backend from a refused source",
		int(gated_backend.call_count("unlock_achievement")), 0)
	check("the sources list is the three families the ticket names (6 values)",
		Achievements.SOURCES.size() == 6 and Achievements.SOURCES.has("outfits.won"),
		str(Achievements.SOURCES))
	check_eq("the 20 unlockable outfit challenges are named", Achievements.OUTFIT_CHALLENGE_COUNT, 20)
	check("every source is still uncovered", (gated.uncovered_sources() as Array).size() == Achievements.SOURCES.size(),
		str(gated.uncovered_sources()))

	# The wire itself, driven explicitly with test names.
	var backend: RefCounted = MockBackend.new(MockBackend.Mode.AVAILABLE)
	backend.init_backend()
	var ach: RefCounted = Achievements.new(backend)

	check("an achievement unlocks through the seam", bool(ach.unlock_api("TEST_ACH_ONE")), "TEST_ACH_ONE")
	check_eq("the backend saw exactly one call", int(backend.call_count("unlock_achievement")), 1)
	check("unlocking the same achievement again still reports true", bool(ach.unlock_api("TEST_ACH_ONE")))
	check_eq("and does NOT call the backend a second time", int(backend.call_count("unlock_achievement")), 1)
	check("a second achievement unlocks too", bool(ach.unlock_api("TEST_ACH_TWO")))
	check_eq("the backend saw one call per distinct achievement", int(backend.call_count("unlock_achievement")), 2)
	check_eq("the seam's own call counter matches", int(ach.backend_calls()), 2)
	check_eq("two achievements are recorded as unlocked", (ach.unlocked_ids() as Array).size(), 2)
	check("an empty API name is refused rather than sent", not bool(ach.unlock_api("")))
	check_eq("the empty name did not reach the backend", int(backend.call_count("unlock_achievement")), 2)
	check_eq("the mock is a mock", backend.is_mock(), true)
	check_eq("the mock does not claim live Steam", backend.live_steam_proven(), false)

	# No Steam backend: honest refusal, never a fake success.
	var off: RefCounted = MockBackend.new(MockBackend.Mode.UNAVAILABLE)
	var init: Dictionary = off.init_backend()
	check_eq("with no client the mock reports a soft status 2", int(init["status"]), 2)
	check("with no client the gate is closed", not bool(off.is_steam_enabled()))
	var ach_off: RefCounted = Achievements.new(off)
	check("an unlock with no Steam backend fails honestly", not bool(ach_off.unlock_api("TEST_ACH_ONE")))
	check("nothing is recorded as unlocked when the backend refused", (off.unlocked as Dictionary).is_empty(),
		str(off.unlocked))
	check("the refusal is recorded on the mock", (off.refusals as Array).size() == 1, str(off.refusals))
	check("a refused unlock is not remembered as unlocked", (ach_off.unlocked_ids() as Array).is_empty(),
		str(ach_off.unlocked_ids()))

	# INIT_FAILED is the other soft path the route requires.
	var bad: RefCounted = MockBackend.new(MockBackend.Mode.INIT_FAILED)
	var bad_init: Dictionary = bad.init_backend()
	check_eq("an init failure reports status 1", int(bad_init["status"]), 1)
	check("an init failure keeps the gate closed and the game running", not bool(bad.is_steam_enabled()))
	_mark("achievements_against_mock")


# ---------------------------------------------------------------------------
# 8. Cloud against the mock — layered on the local file, never replacing it
# ---------------------------------------------------------------------------

func _cloud_against_mock() -> void:
	var store: RefCounted = Store.new(TEST_DIR)
	_wipe(TEST_DIR)
	store.write_all(_realistic_profile())

	var backend: RefCounted = MockBackend.new(MockBackend.Mode.AVAILABLE)
	backend.init_backend()
	var cloud: RefCounted = CloudSaves.new(backend, store)

	var up: Dictionary = cloud.upload_group("career")
	check("the mock cloud accepts the upload", bool(up["ok"]), str(up["reason"]))
	check_eq("the cloud file is named after the local group file",
		String(up["cloud_name"]), cloud.cloud_name_for("career"))
	check("the mock cloud holds the file", (backend.cloud_files() as Array).has(String(up["cloud_name"])),
		str(backend.cloud_files()))
	check("the local file still exists after the upload (cloud is not the only copy)",
		FileAccess.file_exists(store.group_path("career")), store.group_path("career"))

	var local_f := FileAccess.open(store.group_path("career"), FileAccess.READ)
	var local_bytes := local_f.get_buffer(local_f.get_length())
	local_f.close()
	check("the uploaded bytes are the local file's own bytes",
		backend.cloud_bytes(String(up["cloud_name"])) == local_bytes,
		"%d vs %d" % [backend.cloud_bytes(String(up["cloud_name"])).size(), local_bytes.size()])

	var down: Dictionary = cloud.download_on_start("career")
	check("the cloud copy downloads", bool(down["ok"]), str(down["reason"]))
	check("and is byte-identical to what was uploaded", (down["bytes"] as PackedByteArray) == local_bytes,
		"%d vs %d" % [(down["bytes"] as PackedByteArray).size(), local_bytes.size()])
	check_eq("the conflict rule today is local-wins, never cloud-wins (the save-format decision owns it)",
		cloud.resolve_conflict(true, true), "local")
	check_eq("cloud is used only when there is no local copy at all",
		cloud.resolve_conflict(false, true), "cloud")
	check("the mock reports itself as a mock in the cloud status",
		cloud.status()["is_mock"] == true and cloud.status()["live_steam_proven"] == false,
		str(cloud.status()))

	# No Steam: a skip, and nothing lost.
	var off: RefCounted = MockBackend.new(MockBackend.Mode.UNAVAILABLE)
	off.init_backend()
	var cloud_off: RefCounted = CloudSaves.new(off, store)
	var up_off: Dictionary = cloud_off.upload_group("career")
	check("with no backend the upload is skipped, not failed",
		not bool(up_off["ok"]) and bool(up_off["skipped"]), str(up_off["reason"]))
	var down_off: Dictionary = cloud_off.download_on_start("career")
	check("with no backend the download is skipped", bool(down_off["skipped"]), str(down_off["reason"]))
	check("the local file is untouched by the skipped cloud pass",
		FileAccess.file_exists(store.group_path("career"))
			and FileAccess.open(store.group_path("career"), FileAccess.READ).get_as_text() != "",
		store.group_path("career"))

	# Honest failure with the gate OPEN: the caller must not believe the write landed.
	backend.honest_failure = true
	var refused_up: Dictionary = cloud.upload_group("prefs")
	check("an open gate that refuses the write is reported as not ok",
		not bool(refused_up["ok"]) and not bool(refused_up["skipped"]), str(refused_up["reason"]))
	check("the refused write is not in the mock cloud",
		not (backend.cloud_files() as Array).has(cloud.cloud_name_for("prefs")),
		str(backend.cloud_files()))
	backend.honest_failure = false
	_mark("cloud_against_mock")


# ---------------------------------------------------------------------------
# 9. The real backend degrades — and the factory does not select it
# ---------------------------------------------------------------------------

func _real_backend_degrades() -> void:
	# The addon is deliberately absent. The real class must still be loadable and
	# must degrade softly, because this is the class a swap would put in place.
	var real: RefCounted = RealBackend.new()
	check_eq("the real bridge class is not a mock", real.is_mock(), false)
	check_eq("the real bridge class never claims live Steam", real.live_steam_proven(), false)
	var init: Dictionary = real.init_backend()
	check("with the addon absent the real bridge reports a non-zero (soft) status",
		int(init["status"]) != 0, str(init))
	check("and leaves the gate closed", not bool(real.is_steam_enabled()))
	check("an achievement on a closed real bridge returns false", not bool(real.unlock_achievement("TEST_ACH_ONE")))
	check("a cloud write on a closed real bridge returns false",
		not bool(real.cloud_write("padel-career.json", PackedByteArray([1, 2, 3]))))
	check_eq("Engine.has_singleton(\"Steam\") is false here, which is why the above is the honest answer",
		Engine.has_singleton("Steam"), false)

	# The factory must still hand out the mock: nothing may pick the real bridge
	# by accident before the addon and the App ID exist.
	var created: Dictionary = Factory.create_initialised()
	var backend: RefCounted = created["backend"]
	check_eq("the factory's default backend is the mock", backend.backend_id(), "mock")
	check_eq("the factory's default mock is a mock", backend.is_mock(), true)
	check_eq("the factory's default reports the honest no-Steam status", int(created["status"]), 2)
	check("the factory's default leaves Steam off", not bool(created["enabled"]))
	check_eq("the factory never claims live Steam", bool(created["live_steam_proven"]), false)

	# And an explicit AVAILABLE mock, which is a test-only choice.
	var live_shaped: Dictionary = Factory.create_initialised(MockBackend.Mode.AVAILABLE)
	check("an explicit AVAILABLE mock opens the gate for tests only",
		bool(live_shaped["enabled"]) and String((live_shaped["backend"] as RefCounted).backend_id()) == "mock",
		str(live_shaped))
	_mark("real_backend_degrades")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _wipe(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if not d.current_is_dir():
			d.remove(name)
		name = d.get_next()
	d.list_dir_end()
