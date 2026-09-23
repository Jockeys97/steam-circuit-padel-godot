## economy_service.gd — the ONE wallet/ownership service for the Emporio OST.
##
## WHAT IT OWNS. A profile's Circuit Credits, the OST ids it owns, the migration
## marker and the match-award receipts. All four live in ONE saved record — the port's
## own `economy` save group (`godot/src/save/save_schema.gd::ECONOMY_DEFAULTS`) — and
## every mutation is a SINGLE `SaveStore.write_group("economy", payload)`. That write
## is a temp-file-then-rename commit, so ownership and debit land together or not at
## all: there is no ordering in which credits leave a wallet without the track arriving.
##
## WHY A DEDICATED GROUP. The contract asks for a group of its own so a stale career or
## prefs write can never overwrite the wallet. The five reference groups are untouched;
## `SaveSchema.port_group_names()` is the six the whole-profile read/write and the cloud
## backup enumerate, so the wallet is part of a real backup.
##
## PRICES ARE NEVER TRUSTED FROM A CALLER. `purchase()` re-derives the price from
## `ost_catalog.gd` (which reads the catalog's own category) and refuses anything that
## is not a known, sellable catalog id — a UI cannot name its own price.
##
## MIGRATION, AND WHY THE TIMING MATTERS. `ensure_initialized()` must run at BOOT,
## before any other group is written. Its one dangerous decision is "is this a genuine
## existing profile (grandfather its OSTs) or a brand-new one (start at zero)?" — and it
## answers that by looking for the reference groups' FILES. If a new profile's prefs or
## career were written first, a later init would see those files and falsely grandfather
## all 47 tracks to a new player. Two rules keep that from happening:
##
##   1. `ensure_initialized()` is called first thing at boot (`game/main_menu.gd`), and
##      the service itself initializes before it awards or sells anything.
##   2. The decision is recorded IMMUTABLY, twice: `economy.migrationVersion` (1 once
##      decided, never lowered) and a `prefs.economyInit` marker holding the decision
##      itself. So a later boot that finds the economy file missing after a refused or
##      failed write reads the marker and honours it instead of re-deciding — a missing
##      economy file is NEVER a fresh "grant everything".
##
## REFUSED IS REFUSED. A `schemaVersion` this build does not know leaves the file on
## disk and this service refuses every operation on it. A corrupt economy file is
## quarantined by the store and re-initialized EMPTY (no grant): corruption is not an
## upgrade, so it may not hand out the catalog.
##
## LUCALE (`career.unlockAll`) GRANTS ACCESS, NOT CREDITS. When it is on, every catalog
## track is playable and `purchase()` refuses an unlocked track as already-owned without
## debiting — the override gives the tracks, it does not fake a balance.
##
## CROSS-SCRIPT REFERENCES are `preload` consts (see `godot/src/save/README.md`).
extends RefCounted

const Schema := preload("res://src/save/save_schema.gd")
const Catalog := preload("res://src/economy/ost_catalog.gd")

## The save group this service owns. Named once; `SaveSchema` declares the file/type.
const GROUP: String = "economy"

## Written once, never lowered. `1` = "the legacy-vs-new decision has been made".
const MIGRATION_VERSION: int = 1

## How many award receipts are kept. A receipt only has to outlive the match it names,
## so the list is bounded: oldest ids are dropped first (Godot dictionaries keep
## insertion order), and an id that fell out of the window can only be re-awarded by a
## match that is already long gone.
const RECEIPT_CAP: int = 200

## The reward shape: 20 for finishing + 2 per point actually played (both sides),
## capped at 80 of variable pay, +15 for the win. No difficulty or wall-clock term.
const REWARD_BASE: int = 20
const REWARD_PER_POINT: int = 2
const REWARD_VARIABLE_CAP: int = 80
const REWARD_VICTORY: int = 15

## The immutable init marker inside the reference `prefs` group. Its presence means the
## legacy-vs-new decision was already made, whatever happened to the economy file since.
const PREFS_INIT_KEY: String = "economyInit"


# ---------------------------------------------------------------------------
# The pure reward rule
# ---------------------------------------------------------------------------

## The credits a completed match pays. Pure: no store, no clock, no difficulty.
static func reward_for(points_played: int, won: bool) -> int:
	var variable := mini(maxi(points_played, 0) * REWARD_PER_POINT, REWARD_VARIABLE_CAP)
	return REWARD_BASE + variable + (REWARD_VICTORY if won else 0)


## True when a completed match may be awarded at all. Pure, so the exclusions are
## testable without a scene. NOT awarded: a drill (its end belongs to its own module), a
## demo build (there is no shop), a headless harness or probe (`engine_driven`/
## `load_models` are not real play), a fixture that disabled the award, or a match with
## no result (an aborted game).
static func award_eligible(
	mode: String, is_demo: bool, engine_driven: bool, load_models: bool, enabled: bool, has_result: bool
) -> bool:
	if not enabled or not has_result:
		return false
	if mode == "drill":
		return false
	if is_demo:
		return false
	if not engine_driven or not load_models:
		return false
	return true


## The points actually played in a match, from the ACCUMULATED per-side totals the
## simulation keeps (`state.stats.pointsWon`, incremented once per rally in
## `src/sim/sim.gd:2009`) — never the tennis scoreboard (`state.points`), which resets
## every game. Both sides are counted: every rally played scored for exactly one of them.
static func points_played(stats: Dictionary) -> int:
	var entry: Variant = stats.get("pointsWon", null)
	if entry is Dictionary:
		return maxi(0, int((entry as Dictionary).get("player", 0))) \
			+ maxi(0, int((entry as Dictionary).get("ai", 0)))
	return maxi(0, int(entry)) if entry != null else 0


# ---------------------------------------------------------------------------
# Reading the record
# ---------------------------------------------------------------------------

## The stored payload sanitized into the shape callers read. Never writes.
static func _payload_of(read: Dictionary) -> Dictionary:
	var out: Dictionary = Schema.ECONOMY_DEFAULTS.duplicate(true)
	var raw: Variant = read.get("payload", null)
	if raw is Dictionary:
		for key in (raw as Dictionary):
			out[key] = (raw as Dictionary)[key]
	# Types are not trusted to match their field names (a hand-edited file, an older
	# build): the read door is where the shape is made safe.
	out["credits"] = maxi(0, int(out.get("credits", 0)))
	out["migrationVersion"] = int(out.get("migrationVersion", 0))
	var owned: Array = []
	var raw_owned: Variant = out.get("owned", [])
	if raw_owned is Array:
		for id in (raw_owned as Array):
			var s := String(id)
			if s != "" and Catalog.is_known(s) and not owned.has(s):
				owned.append(s)
	out["owned"] = owned
	var receipts: Dictionary = {}
	var raw_receipts: Variant = out.get("receipts", {})
	if raw_receipts is Dictionary:
		for key in (raw_receipts as Dictionary):
			receipts[String(key)] = int((raw_receipts as Dictionary)[key])
	out["receipts"] = receipts
	return out


## The current state, read-only. Returns:
##   ok, refused, recovered, existed, initialized, credits, owned (Array),
##   migration_version, receipts, path, reason
static func read_state(store) -> Dictionary:
	var read: Dictionary = store.read_group(GROUP)
	var payload := _payload_of(read)
	var refused := bool(read.get("refused", false))
	var recovered := bool(read.get("recovered", false))
	var existed := bool(read.get("existed", false))
	return {
		"ok": bool(read.get("ok", false)) or refused or recovered,
		"refused": refused,
		"recovered": recovered,
		"existed": existed,
		"initialized": int(payload["migrationVersion"]) >= MIGRATION_VERSION,
		"future": int(payload["migrationVersion"]) > MIGRATION_VERSION,
		"credits": int(payload["credits"]),
		"owned": payload["owned"],
		"migration_version": int(payload["migrationVersion"]),
		"receipts": payload["receipts"],
		"path": String(read.get("path", "")),
		"reason": String(read.get("message", "")),
	}


static func balance(store) -> int:
	return int(read_state(store)["credits"])


static func owned_ids(store) -> Array:
	return read_state(store)["owned"]


## True when the profile OWNS the track outright (a starter or a purchased id).
static func is_owned(store, track_id: String) -> bool:
	if Catalog.is_starter(track_id):
		return true
	return (owned_ids(store) as Array).has(track_id)


## True when `career.unlockAll` (the LUCALE override) is on. Read through the reference
## `career` group; absent means off.
static func unlock_all(store) -> bool:
	var read: Dictionary = store.read_group("career")
	var payload: Variant = read.get("payload", null)
	if payload is Dictionary:
		return bool((payload as Dictionary).get("unlockAll", false))
	return false


## True when the track can be PLAYED: owned, or granted by the override.
static func has_access(store, track_id: String) -> bool:
	if not Catalog.is_starter(track_id) and relock_all(store):
		return false
	return is_owned(store, track_id) or unlock_all(store)


## ALELU blocks access while retaining the wallet, purchase ledger and receipts.
static func relock_all(store) -> bool:
	var payload: Variant = store.read_group("career").get("payload", null)
	return payload is Dictionary and bool(payload.get("lockAll", false))


## The shop shelf as rows: id, title, category, price, owned, affordable, accessible.
## `owned` is ownership only; `accessible` folds in the override, because a LUCALE
## profile can play a track it does not own.
static func shop_rows(store) -> Array:
	var state := read_state(store)
	var owned: Array = state["owned"]
	var credits := int(state["credits"])
	var override := unlock_all(store)
	var relocked := relock_all(store)
	var out: Array = []
	for row in Catalog.shop_rows():
		var id := String(row["id"])
		var is_owned_row := owned.has(id)
		out.append({
			"id": id,
			"title": row["title"],
			"category": row["category"],
			"price": int(row["price"]),
			"owned": is_owned_row,
			"relocked": relocked,
			"affordable": credits >= int(row["price"]),
			"accessible": not relocked and (is_owned_row or override),
		})
	return out


# ---------------------------------------------------------------------------
# Initialization / migration
# ---------------------------------------------------------------------------

## Initialize the economy group exactly once, at boot, before any other group is
## written. Idempotent: a second call is a no-op. Returns:
##   ok, initialized, already, granted (bool), granted_ids (Array), reason
##
## DATA-PRESERVATION RULES, each one deliberate:
##   * a refused file is left untouched and nothing is granted;
##   * an UNREADABLE (I/O) economy file is never overwritten — the init refuses;
##   * a `migrationVersion` NEWER than this build refuses every mutation, so a newer
##     build's record is never downgraded or rewritten;
##   * the legacy-vs-new decision is recorded DURABLY (in `prefs`) BEFORE the economy
##     write, and if that record cannot be made the init refuses. A corrupt economy
##     decides "new" (corruption is not an upgrade), so a later missing file can never
##     turn into a grant-everything;
##   * migrating an older economy UNIONs the grant with the ids it already owns — an
##     existing purchase is never assigned over.
static func ensure_initialized(store) -> Dictionary:
	var read: Dictionary = store.read_group(GROUP)

	# A refused file is left exactly where it is and nothing is granted.
	if bool(read.get("refused", false)):
		return _init_refusal("economy file refused: %s" % String(read.get("message", "")))

	var recovered := bool(read.get("recovered", false))
	# An unreadable economy that is NOT corruption (an open failure) must never be
	# overwritten: refuse rather than clobber bytes this build could not read.
	if not bool(read.get("ok", false)) and not recovered:
		return _init_refusal("economy unreadable: %s" % String(read.get("message", "")))

	var payload := _payload_of(read)
	var version := int(payload["migrationVersion"])
	# A record from a NEWER build is not ours to rewrite.
	if version > MIGRATION_VERSION:
		return _init_refusal(
			"economy migrationVersion %d is newer than this build's %d; refusing to mutate"
			% [version, MIGRATION_VERSION]
		)
	if bool(read.get("existed", false)) and not recovered and version >= MIGRATION_VERSION:
		return {
			"ok": true, "initialized": true, "already": true, "granted": false,
			"granted_ids": [], "reason": "already initialized (migrationVersion %d)" % version,
		}

	# The legacy-vs-new decision. An existing immutable marker wins; otherwise a
	# pre-marker economy record means "not a new profile"; otherwise the reference
	# groups' FILES decide. A corrupt economy is NOT an upgrade, so it decides "new".
	var marker := _read_init_marker(store)
	if not bool(marker["ok"]):
		return _init_refusal("cannot read the economy decision record: %s" % String(marker["reason"]))
	var recorded: Dictionary = marker["marker"]
	var legacy := false
	var existing_owned: Array = []
	if recovered:
		legacy = bool(recorded.get("legacy", false))
	elif not recorded.is_empty():
		legacy = bool(recorded.get("legacy", false))
		existing_owned = payload["owned"]
	elif bool(read.get("existed", false)) and version < MIGRATION_VERSION:
		legacy = true
		existing_owned = payload["owned"]
	else:
		legacy = _legacy_profile_files_exist(store)

	# Record the decision durably FIRST. If it cannot be recorded, refuse before any
	# economy write: a grant must never exist without a durable record of the decision.
	if recorded.is_empty():
		var marker_write: Dictionary = _write_init_marker(store, legacy)
		if not bool(marker_write.get("ok", false)):
			return _init_refusal("cannot record the economy decision: %s" % String(marker_write.get("reason", "")))

	# UNION the grant with what the record already owns — never assign over a purchase.
	var granted_ids: Array = Catalog.all_ids() if legacy else []
	var owned: Array = existing_owned.duplicate()
	for id in granted_ids:
		if not owned.has(id):
			owned.append(id)
	payload["owned"] = owned
	payload["migrationVersion"] = MIGRATION_VERSION
	var write: Dictionary = store.write_group(GROUP, payload)
	if not bool(write.get("ok", false)):
		return _init_refusal("economy write failed: %s" % String(write.get("message", "")))
	return {
		"ok": true, "initialized": true, "already": false, "granted": legacy,
		"granted_ids": granted_ids.duplicate(),
		"reason": (
			"grandfathered %d existing OSTs (owned now %d)" % [granted_ids.size(), owned.size()]
			if legacy else "new profile: zero credits, starter tracks only"
		),
	}


static func _init_refusal(reason: String) -> Dictionary:
	return {"ok": false, "initialized": false, "already": false, "granted": false, "granted_ids": [], "reason": reason}


## The immutable decision marker inside the reference `prefs` group. Returns
## `{ok, marker, reason}`: `ok` is FALSE when the prefs group exists but could not be
## read (refused, or an I/O failure) — the caller must then refuse, never overwrite a
## prefs file this build could not read.
static func _read_init_marker(store) -> Dictionary:
	var read: Dictionary = store.read_group("prefs")
	if not bool(read.get("ok", false)) and not bool(read.get("recovered", false)):
		return {"ok": false, "marker": {}, "reason": String(read.get("message", ""))}
	var payload: Variant = read.get("payload", null)
	if payload is Dictionary:
		var marker: Variant = (payload as Dictionary).get(PREFS_INIT_KEY, null)
		if marker is Dictionary:
			return {"ok": true, "marker": marker, "reason": ""}
	return {"ok": true, "marker": {}, "reason": ""}


## Write the marker ONCE, preserving every other prefs field (read-modify-write, the
## same shape `modes_save.gd::save_pref` uses). Refuses to write when the prefs group
## is present but unreadable (refused or an I/O failure): overwriting bytes this build
## could not read would destroy a newer build's preferences.
static func _write_init_marker(store, legacy: bool) -> Dictionary:
	var read: Dictionary = store.read_group("prefs")
	if not bool(read.get("ok", false)) and not bool(read.get("recovered", false)):
		return {"ok": false, "reason": "prefs unreadable (%s); refusing to overwrite" % String(read.get("message", ""))}
	var prefs: Dictionary = {}
	var payload: Variant = read.get("payload", null)
	if payload is Dictionary:
		prefs = (payload as Dictionary).duplicate(true)
	if prefs.has(PREFS_INIT_KEY):
		return {"ok": true, "skipped": true, "reason": "marker already present"}
	prefs[PREFS_INIT_KEY] = {"version": MIGRATION_VERSION, "legacy": legacy}
	return store.write_group("prefs", prefs)


## True when at least one of the reference groups' FILES exists: the profile is not a
## first launch, so its OSTs are grandfathered. Reads file existence only — never a
## group's content, and never the economy file itself.
static func _legacy_profile_files_exist(store) -> bool:
	for group in Schema.group_names():
		if FileAccess.file_exists(store.group_path(group)):
			return true
	return false


# ---------------------------------------------------------------------------
# Purchase
# ---------------------------------------------------------------------------

## Buy one track. Central validation: known + sellable catalog id, catalog price,
## ownership, funds. Returns:
##   ok, reason, id, price, balance, owned, debited
## A refusal changes nothing. A success writes wallet + ownership in ONE commit.
static func purchase(store, track_id: String) -> Dictionary:
	var init := ensure_initialized(store)
	if not bool(init["ok"]):
		return _refusal(track_id, "store_unavailable", 0, store)
	var state := read_state(store)
	if bool(state["refused"]):
		return _refusal(track_id, "refused", 0, store)

	if not Catalog.is_known(track_id):
		return _refusal(track_id, "unknown", 0, store)
	if Catalog.is_starter(track_id):
		return _refusal(track_id, "starter", 0, store)
	if Catalog.is_excluded(track_id):
		return _refusal(track_id, "excluded", 0, store)
	var price := Catalog.price_of(track_id)
	if relock_all(store):
		return _refusal(track_id, "relocked", price, store)
	if price <= 0:
		return _refusal(track_id, "not_for_sale", 0, store)
	if (state["owned"] as Array).has(track_id):
		return _refusal(track_id, "owned", price, store)
	if unlock_all(store):
		# LUCALE gives access, not a fake balance, and never debits for unlocked content.
		return _refusal(track_id, "unlocked", price, store)
	var credits := int(state["credits"])
	if credits < price:
		return _refusal(track_id, "insufficient", price, store)

	var payload: Dictionary = Schema.ECONOMY_DEFAULTS.duplicate(true)
	var read: Dictionary = store.read_group(GROUP)
	var raw: Variant = read.get("payload", null)
	if raw is Dictionary:
		payload = (raw as Dictionary).duplicate(true)
	payload["credits"] = credits - price
	var owned: Array = (state["owned"] as Array).duplicate()
	owned.append(track_id)
	payload["owned"] = owned
	payload["migrationVersion"] = MIGRATION_VERSION
	var write: Dictionary = store.write_group(GROUP, payload)
	if not bool(write.get("ok", false)):
		# Ownership and debit are one commit: a failed write leaves neither.
		return {
			"ok": false, "reason": "write_failed", "id": track_id, "price": price,
			"balance": credits, "owned": state["owned"], "debited": 0,
		}
	return {
		"ok": true, "reason": "purchased", "id": track_id, "price": price,
		"balance": credits - price, "owned": owned, "debited": price,
	}


static func _refusal(track_id: String, reason: String, price: int, store) -> Dictionary:
	var state := read_state(store)
	return {
		"ok": false, "reason": reason, "id": track_id, "price": price,
		"balance": int(state["credits"]), "owned": state["owned"], "debited": 0,
	}


# ---------------------------------------------------------------------------
# Match award
# ---------------------------------------------------------------------------

## Award a completed match's credits, exactly once per match id. Returns:
##   ok, reason, already, awarded, balance, match_id
## The receipt is persisted with the credit in ONE commit, so a crash between the two
## is impossible; a repeated call (a re-mounted result screen, a restart) sees the
## receipt and awards nothing.
static func award_completion(store, match_id: String, points_played: int, won: bool) -> Dictionary:
	if match_id == "":
		return {"ok": false, "reason": "no_match_id", "already": false, "awarded": 0, "balance": balance(store), "match_id": ""}
	var init := ensure_initialized(store)
	if not bool(init["ok"]):
		return {"ok": false, "reason": "store_unavailable", "already": false, "awarded": 0, "balance": 0, "match_id": match_id}
	var state := read_state(store)
	if bool(state["refused"]):
		return {"ok": false, "reason": "refused", "already": false, "awarded": 0, "balance": int(state["credits"]), "match_id": match_id}

	var receipts: Dictionary = (state["receipts"] as Dictionary).duplicate()
	if receipts.has(match_id):
		return {
			"ok": true, "reason": "already_awarded", "already": true, "awarded": 0,
			"balance": int(state["credits"]), "match_id": match_id,
		}

	var reward := reward_for(points_played, won)
	var credits := int(state["credits"]) + reward
	receipts[match_id] = reward
	receipts = _prune_receipts(receipts)

	var payload: Dictionary = Schema.ECONOMY_DEFAULTS.duplicate(true)
	var read: Dictionary = store.read_group(GROUP)
	var raw: Variant = read.get("payload", null)
	if raw is Dictionary:
		payload = (raw as Dictionary).duplicate(true)
	payload["credits"] = credits
	payload["receipts"] = receipts
	payload["migrationVersion"] = MIGRATION_VERSION
	var write: Dictionary = store.write_group(GROUP, payload)
	if not bool(write.get("ok", false)):
		return {
			"ok": false, "reason": "write_failed", "already": false, "awarded": 0,
			"balance": int(state["credits"]), "match_id": match_id,
		}
	return {
		"ok": true, "reason": "awarded", "already": false, "awarded": reward,
		"balance": credits, "match_id": match_id,
	}


## Keep the newest `RECEIPT_CAP` receipts. Insertion order is the award order, so the
## oldest ids are dropped first.
static func _prune_receipts(receipts: Dictionary) -> Dictionary:
	if receipts.size() <= RECEIPT_CAP:
		return receipts
	var keys := receipts.keys()
	var out: Dictionary = {}
	for i in range(keys.size() - RECEIPT_CAP, keys.size()):
		out[keys[i]] = receipts[keys[i]]
	return out
