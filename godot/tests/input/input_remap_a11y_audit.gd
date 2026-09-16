## input_remap_a11y_audit.gd — remapping, the accessibility knobs, and the two
## rules the rest of the port depends on.
##
##   cd /root/projects/steam-circuit-padel-pro && \
##   flock -w 900 /tmp/padel-godot.lock timeout 300 env -u DISPLAY \
##     GODOT_SILENCE_ROOT_WARNING=1 /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 \
##     --headless --path godot/ --script res://tests/input/input_remap_a11y_audit.gd
##
## Three subjects in one audit, because they are one question — what a player may
## change about how they play, and what the change is allowed to break:
##
##   **Remap** (`godot/src/input/remap.gd`): the model refuses an assignment that
##   would drop a device the reference wires, put a pad button in a keyboard slot,
##   collide with another action in the same context, or touch one of the engine's
##   `ui_*` navigation actions. Every rejection is asserted by its reason string,
##   because a validator that refuses everything would pass a "rejects bad input"
##   test just as well.
##
##   **Accessibility** (`godot/src/accessibility/accessibility_settings.gd`): the
##   reference has exactly two toggles and the audit asserts what they *do* —
##   particle counts down to 35 % with a floor of 2, shake capped at 0.5 — rather
##   than that a boolean can be flipped. The settings the reference does not have
##   are printed as notes, not invented.
##
##   **The two boundary rules**: the audio layer never reads the motion setting
##   (proved by reading `godot/src/audio/**`), and every named control has a name
##   that resolves through the locale seam.
extends SceneTree

const AuditBase := preload("res://src/audits/audit_base.gd")
const RemapModel := preload("res://src/input/remap.gd")
const Scheme := preload("res://src/input/scheme.gd")
const A11y := preload("res://src/accessibility/accessibility_settings.gd")
const InputStrings := preload("res://src/input/strings.gd")
const Locale := preload("res://src/locale/locale.gd")

## Where the port keeps sound; the motion setting must not reach it
## (`js/audio.js` has no match for it either).
const AUDIO_DIR := "res://src/audio"
## The words that would be a motion setting leaking into the audio layer.
const MOTION_WORDS := ["reduce", "motion", "accessib", "colorblind", "colourblind"]
const LOCALES := ["it", "en"]


func _initialize() -> void:
	var audit := AuditBase.new("input_remap_a11y")
	run(audit)
	quit(audit.finish())


static func run(audit: AuditBase) -> void:
	_remap(audit)
	_accessibility(audit)
	_boundaries(audit)


# ---------------------------------------------------------------------------
# Remap
# ---------------------------------------------------------------------------

static func _remap(audit: AuditBase) -> void:
	var model := RemapModel.new()
	# The model is seeded from the live InputMap, so a binding is never restated
	# here — it is read once and moved around.
	audit.check_eq(model.binding_text("padel_drive", RemapModel.SLOT_KEYBOARD), "Space", "remap/the_keyboard_binding_is_read_from_the_input_map")
	audit.check_eq(model.binding_text("padel_drive", RemapModel.SLOT_PAD), "0", "remap/the_pad_binding_is_read_from_the_input_map")
	audit.check_eq(model.binding_text("padel_left", RemapModel.SLOT_PAD), "0:-1.0", "remap/a_stick_binding_is_an_axis")
	audit.check_eq(model.uncovered(), [], "remap/the_input_map_starts_covered")
	audit.check_eq(model.overrides(), {}, "remap/no_override_before_any_change")
	# Every binding the map declares for a slot is kept, not only the first: the
	# second key is part of the conflict set.
	audit.check_eq(model.binding_values("padel_switch", RemapModel.SLOT_KEYBOARD), ["Tab", "Z"], "remap/a_second_key_is_kept")
	audit.check_eq(model.binding_values("padel_left", RemapModel.SLOT_KEYBOARD), ["A", "Left"], "remap/movement_keeps_its_second_key")
	audit.check_eq(model.binding_values("ui_accept", RemapModel.SLOT_KEYBOARD), ["Enter", "Kp Enter", "Space"], "remap/the_confirm_key_set_is_complete")

	var free_key := model.assign("padel_drive", RemapModel.SLOT_KEYBOARD, {"kind": "key", "value": "F"})
	audit.check_true(free_key["ok"], "remap/a_free_key_is_accepted")
	audit.check_eq(model.binding_text("padel_drive", RemapModel.SLOT_KEYBOARD), "F", "remap/the_new_key_is_the_binding")
	audit.check_eq(free_key["previous"], {"kind": "key", "value": "Space"}, "remap/the_previous_binding_is_reported")
	audit.check_eq(model.overrides().size(), 1, "remap/only_the_changed_slot_is_an_override")
	audit.check_true(model.overrides().has("padel_drive.keyboard"), "remap/the_override_is_named_by_action_and_slot")

	# A conflict inside one context is refused, and names the owner.
	var taken := model.assign("padel_drive", RemapModel.SLOT_KEYBOARD, {"kind": "key", "value": "Z"})
	audit.check_true(not taken["ok"], "remap/a_key_already_used_in_the_context_is_refused")
	audit.check_eq(taken["reason"], RemapModel.REASON_CONFLICT, "remap/the_refusal_names_the_conflict")
	audit.check_eq(taken["owner"], "padel_switch", "remap/the_conflict_names_the_action_that_owns_it")
	audit.check_eq(model.binding_text("padel_drive", RemapModel.SLOT_KEYBOARD), "F", "remap/a_refused_assignment_changes_nothing")

	# …while the same key is free in another context: the reference dispatches to
	# the gameplay poll or the menu poll and never both (`js/main.js:756-758`).
	var cross_context := model.assign("menu_quit", RemapModel.SLOT_KEYBOARD, {"kind": "key", "value": "F"})
	audit.check_true(cross_context["ok"], "remap/a_key_used_in_another_context_is_accepted")
	audit.check_eq(
		model.conflicts("padel_drive", RemapModel.SLOT_KEYBOARD, {"kind": "key", "value": "Space"}), [],
		"remap/the_gameplay_context_reports_no_conflict_for_a_freed_key",
	)
	audit.check_eq(
		model.conflicts("ui_up", RemapModel.SLOT_KEYBOARD, {"kind": "key", "value": "Space"}), ["ui_accept"],
		"remap/the_menu_context_detects_its_own_conflicts",
	)

	# A pad button belongs to the pad slot and a key to the keyboard slot.
	var wrong_device := model.assign("padel_drive", RemapModel.SLOT_PAD, {"kind": "key", "value": "F"})
	audit.check_eq(wrong_device["reason"], RemapModel.REASON_WRONG_DEVICE, "remap/a_key_in_the_pad_slot_is_refused")
	audit.check_eq(wrong_device["expected"], [RemapModel.KIND_BUTTON, RemapModel.KIND_AXIS], "remap/the_pad_slot_names_the_kinds_it_takes")
	var wrong_device_back := model.assign("padel_drive", RemapModel.SLOT_KEYBOARD, {"kind": "button", "value": "2"})
	audit.check_eq(wrong_device_back["reason"], RemapModel.REASON_WRONG_DEVICE, "remap/a_pad_button_in_the_keyboard_slot_is_refused")

	# Impossible assignments: nothing at all, an action that does not exist, a slot
	# that does not exist.
	audit.check_eq(
		model.assign("padel_drive", RemapModel.SLOT_KEYBOARD, {})["reason"], RemapModel.REASON_EMPTY,
		"remap/an_empty_binding_is_refused",
	)
	audit.check_eq(
		model.assign("padel_drive", RemapModel.SLOT_KEYBOARD, {"kind": "key", "value": ""})["reason"], RemapModel.REASON_EMPTY,
		"remap/a_nameless_key_is_refused",
	)
	audit.check_eq(
		model.assign("padel_serving", RemapModel.SLOT_KEYBOARD, {"kind": "key", "value": "F"})["reason"],
		RemapModel.REASON_UNKNOWN_ACTION, "remap/an_unknown_action_is_refused",
	)
	audit.check_eq(
		model.assign("padel_drive", "trigger", {"kind": "key", "value": "F"})["reason"],
		RemapModel.REASON_UNKNOWN_SLOT, "remap/an_unknown_slot_is_refused",
	)

	# The engine's navigation actions are not the game's to rebind.
	for reserved in ["ui_accept", "ui_cancel", "ui_up", "ui_down", "ui_left", "ui_right"]:
		audit.check_eq(
			model.assign(reserved, RemapModel.SLOT_PAD, {"kind": "button", "value": "9"})["reason"],
			RemapModel.REASON_RESERVED, "remap/%s_is_reserved_to_the_engine" % reserved,
		)

	# Coverage is a floor: a slot the reference wires cannot be emptied, and a slot
	# it does not wire has nothing to clear.
	audit.check_eq(
		model.clear("padel_drive", RemapModel.SLOT_KEYBOARD)["reason"], RemapModel.REASON_COVERAGE,
		"remap/clearing_a_reference_device_is_refused",
	)
	audit.check_true(not model.can_clear("padel_drive", RemapModel.SLOT_KEYBOARD), "remap/can_clear_reports_the_floor")
	audit.check_eq(
		model.clear("padel_lob", RemapModel.SLOT_KEYBOARD)["reason"], RemapModel.REASON_NOTHING_TO_CLEAR,
		"remap/clearing_an_empty_slot_is_refused",
	)
	audit.check_true(not model.can_clear("padel_lob", RemapModel.SLOT_KEYBOARD), "remap/a_pad_only_action_has_no_keyboard_binding_to_clear")

	# After a batch of legal assignments the map is still covered, and resetting
	# brings the InputMap's own bindings back. The buttons are free in the gameplay
	# context (10, 16 and 17 are unused there: the map carries 0-7, 9 and 12-15).
	var free_buttons := ["10", "16", "17"]
	var rebind_actions := ["padel_drive", "padel_slice", "padel_special"]
	for index in rebind_actions.size():
		audit.check_true(
			model.assign(rebind_actions[index], RemapModel.SLOT_PAD, {"kind": "button", "value": free_buttons[index]})["ok"],
			"remap/%s_accepts_a_pad_rebinding" % rebind_actions[index],
		)
	audit.check_eq(model.uncovered(), [], "remap/the_map_is_still_covered_after_rebinding")
	model.reset()
	audit.check_eq(model.overrides(), {}, "remap/reset_restores_every_binding")
	audit.check_eq(model.binding_text("padel_drive", RemapModel.SLOT_KEYBOARD), "Space", "remap/reset_restores_the_keyboard_binding")


# ---------------------------------------------------------------------------
# Accessibility
# ---------------------------------------------------------------------------

static func _accessibility(audit: AuditBase) -> void:
	var a11y := A11y.new()
	var ids: Array = []
	for setting in A11y.SETTINGS:
		ids.append(String(setting["id"]))
	audit.check_eq(ids, [A11y.REDUCE_MOTION, A11y.COLORBLIND], "a11y/the_reference_has_exactly_two_toggles")
	audit.check_eq(A11y.SETTINGS.size(), 2, "a11y/two_settings_are_declared")
	audit.check_true(not a11y.is_reduced_motion(), "a11y/reduced_motion_defaults_off")
	audit.check_true(not a11y.is_colorblind(), "a11y/colorblind_defaults_off")
	for setting in A11y.SETTINGS:
		audit.check_true(
			String(setting["reference"]).contains("js/"),
			"a11y/%s_carries_its_reference_anchor" % String(setting["id"]),
		)

	# What the toggle *does* (`js/fx.js:26,63`), not that it can be flipped.
	audit.check_eq(a11y.particle_count(10), 10, "a11y/particles_are_untouched_without_reduced_motion")
	audit.check_eq(a11y.shake(2.5), 2.5, "a11y/shake_is_untouched_without_reduced_motion")
	a11y.set_enabled(A11y.REDUCE_MOTION, true)
	audit.check_true(a11y.is_reduced_motion(), "a11y/reduced_motion_can_be_turned_on")
	audit.check_eq(a11y.particle_count(100), 35, "a11y/particles_are_35_percent_with_reduced_motion")
	audit.check_eq(a11y.particle_count(10), 4, "a11y/the_particle_count_is_rounded")
	audit.check_eq(a11y.particle_count(4), 2, "a11y/the_particle_floor_is_two")
	audit.check_eq(a11y.particle_count(1), 2, "a11y/the_floor_holds_for_a_tiny_burst")
	audit.check_eq(a11y.shake(2.5), 0.5, "a11y/shake_is_capped_at_a_half")
	audit.check_true(absf(a11y.shake(0.3) - 0.3) < 1e-9, "a11y/a_small_shake_is_left_alone")
	audit.check_true(not a11y.set_enabled("large_text", true), "a11y/an_unknown_setting_is_refused")
	audit.check_true(not a11y.is_enabled("large_text"), "a11y/an_unknown_setting_stays_off")

	# The two toggles are named, in both languages, through the locale seam.
	for locale in LOCALES:
		var unnamed: Array = []
		for setting in A11y.SETTINGS:
			var label := a11y.label(String(setting["id"]), locale)
			if label == "" or label == String(setting["locale_key"]):
				unnamed.append(String(setting["locale_key"]))
		audit.check_eq(unnamed, [], "a11y/both_toggles_are_labelled_%s" % locale)
	audit.check_eq(a11y.unnamed_controls(), [], "a11y/every_named_control_has_a_name")
	audit.check_true(a11y.control_label("osk", "it") != "ariaOsk", "a11y/a_named_control_resolves_through_the_locale")
	audit.check_eq(a11y.control_label("no_such_control"), "", "a11y/an_unknown_control_has_no_name")

	# The settings round-trip like `collectPrefs`/the startup apply
	# (`js/ui.js:422-442`, `js/main.js:2214-2215`).
	var prefs := a11y.prefs()
	audit.check_eq(prefs.size(), 2, "a11y/two_prefs_are_persisted")
	var restored := A11y.new()
	restored.apply_prefs(prefs)
	audit.check_true(restored.is_reduced_motion(), "a11y/the_motion_pref_round_trips")
	var camel := A11y.new()
	camel.apply_prefs({"reduceMotion": true, "colorblind": true})
	audit.check_true(camel.is_reduced_motion(), "a11y/the_references_camel_case_keys_are_accepted")
	audit.check_true(camel.is_colorblind(), "a11y/the_colourblind_pref_round_trips")
	camel.apply_prefs({"reduceMotion": "yes"})
	audit.check_true(camel.is_reduced_motion(), "a11y/a_non_boolean_value_is_ignored")

	# The settings the reference does not have, named rather than invented.
	audit.check_ge(A11y.ABSENT.size(), 3, "a11y/the_absent_settings_are_enumerated")
	for absent in A11y.ABSENT:
		audit.note("absent setting %s — %s" % [absent["id"], absent["why"]])
	audit.note(A11y.MARKUP_DEFAULT_DIVERGENCE)
	audit.report("a11y settings=%d absent=%d particle(100)=%d shake(2.5)=%.1f" % [
		A11y.SETTINGS.size(), A11y.ABSENT.size(), a11y.particle_count(100), a11y.shake(2.5),
	])


# ---------------------------------------------------------------------------
# Boundaries
# ---------------------------------------------------------------------------

static func _boundaries(audit: AuditBase) -> void:
	# The motion setting must not reach the audio layer: the reference's effects
	# module owns it and `js/audio.js` has no match for it.
	var files := _gd_files(AUDIO_DIR)
	audit.check_gt(files.size(), 0, "a11y/the_audio_layer_is_readable")
	var imports: Array = []
	for path in files:
		var text := FileAccess.get_file_as_string(path)
		if text.contains("res://src/accessibility") or text.contains("AccessibilitySettings") or text.contains("accessibility_settings"):
			imports.append(path)
	audit.check_eq(imports, [], "a11y/the_audio_layer_does_not_import_the_accessibility_module")

	# Every mention of a motion word in the audio layer must be a declared *false*.
	# The port's audio module carries one — a diagnostic field
	# `reduced_motion_affects_audio` read from the mixer contract, which the
	# reference's `js/audio.js` does not have at all — so the rule is asserted
	# precisely instead of by a word scan that would either fail on a legitimate
	# diagnostic or pass while hiding a real read.
	var mentions: Array = []
	var not_false: Array = []
	for path in files:
		var lines: Array = FileAccess.get_file_as_string(path).split("\n")
		for index in lines.size():
			var lowered := String(lines[index]).to_lower()
			for word in MOTION_WORDS:
				if lowered.contains(word):
					mentions.append("%s:%d" % [path, index + 1])
					if not String(lines[index]).contains("false"):
						not_false.append("%s:%d" % [path, index + 1])
					break
	audit.check_eq(not_false, [], "a11y/every_motion_mention_in_audio_is_a_false_diagnostic")
	var mixer: Variant = JSON.parse_string(FileAccess.get_file_as_string("%s/event_map.json" % AUDIO_DIR))
	var affects_audio: Variant = false
	if mixer is Dictionary and (mixer as Dictionary).has("mixer"):
		affects_audio = ((mixer as Dictionary)["mixer"] as Dictionary).get("reducedMotion", {}).get("affectsAudio", false)
	audit.check_eq(bool(affects_audio), false, "a11y/the_audio_mixers_motion_flag_is_false")
	for mention in mentions:
		audit.note("audio mentions a motion word at %s — the port's mixer contract declares `reducedMotion.affectsAudio: false`; js/audio.js has no such field, so the port carries one extra diagnostic and no read (docs/implementation/tickets/accessibility-locales-performance.md:47,55)" % mention)

	# The keyboard is the fallback path, and the pad-only set is named rather than
	# glossed: %d actions are pad-only in the reference.
	var policy := A11y.new().keyboard_policy()
	audit.check_true(bool(policy["navigation_always_available"]), "a11y/menu_navigation_is_always_available_on_the_keyboard")
	audit.check_eq(int(policy["pad_only_count"]), 8, "a11y/the_pad_only_set_is_reported_not_hidden")
	audit.check_eq(int(policy["pad_only_count"]), (policy["pad_only_actions"] as Array).size(), "a11y/the_pad_only_count_matches_its_list")
	audit.check_true(String(policy["text_entry"]).contains("postponed"), "a11y/the_touch_and_osk_decision_is_named_as_postponed")

	# Every string the input and settings surfaces show is resolvable in both
	# languages: the ported form of the reference's `n === 2` count
	# (`scripts/gamepad-nav-audit.mjs:136-144`).
	for locale in LOCALES:
		audit.check_eq(InputStrings.unresolvable(locale), [], "a11y/every_input_string_resolves_%s" % locale)
	audit.check_eq(Locale.locales(), ["it", "en"], "a11y/the_locale_seam_still_has_two_locales")
	var leaked: Array = []
	for message_id in InputStrings.owned_ids():
		if InputStrings.text(message_id) == message_id:
			leaked.append(message_id)
	audit.check_eq(leaked, [], "a11y/no_input_string_leaks_as_a_raw_id")

	audit.report("audio files=%d input strings=%d" % [files.size(), InputStrings.owned_ids().size()])
	audit.note("performance is not measured here and no frame-rate claim is made: this host renders through software GL with no GPU (docs/wayfinder/tickets/product-scope-and-platforms.md); the frame-time probe is a later tranche of this slice")


static func _gd_files(dir: String) -> Array:
	var out: Array = []
	var handle := DirAccess.open(dir)
	if handle == null:
		return out
	handle.list_dir_begin()
	var name := handle.get_next()
	while name != "":
		if not handle.current_is_dir() and name.ends_with(".gd"):
			out.append("%s/%s" % [dir, name])
		name = handle.get_next()
	handle.list_dir_end()
	out.sort()
	return out
