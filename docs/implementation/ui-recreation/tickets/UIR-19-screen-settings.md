---
id: UIR-19
title: SettingsScreen 1:1 (screen-settings + shared SettingsRows component)
slug: screen-settings
state: done
readiness: potential
owner_role: screen worker
blocked_by: [UIR-02, UIR-03, UIR-04, UIR-05, UIR-07]
blocks: [UIR-20, UIR-22]
gates: [plan-approval, gate-a]
plan_approved: true
triage: ready-for-agent
evidence:
  - docs/implementation/ui-recreation/evidence/uir-19-screen-settings.log
  - docs/implementation/ui-recreation/evidence/uir-finalize/ui-audit-sweep.json
capture_states: [default]
---

# UIR-19: SettingsScreen 1:1 (screen-settings + shared SettingsRows component)

## Worker brief (copy-paste)

> Recreate `screen-settings` (`index.html:399-442`) as `godot/src/ui/screens/SettingsScreen.gd/.tscn`, registered as `settings`, back target `menu`. Three groups: language (IT/EN segmented), accessibility (reduce motion, colorblind mode), audio and controller (volume range 0-1 step 0.01 with a visible percentage, deadzone range 0.08-0.30 step 0.01 with a visible percentage, vibration toggle). All writes go through the existing save/prefs contract; language changes apply immediately through `Locale` and refresh every visible surface. Build the range row and toggle row as a shared component (`godot/src/ui/components/SettingsRows.gd`) because the pause overlay's controller tab consumes the same rows; you own the component, UIR-20 consumes it read-only. Reduce-motion and colorblind flow through `AccessibilitySettings` and must have observable behavior (the UI-level motion policy from UIR-05 for UI effects; the game-side FX policy already exists).

## Why this exists

The reference settings screen is where the language, accessibility and input preferences persist (`js/main.js:2314-2520` wiring; `js/ui.js:405-442` prefs load/save/collect). The port has the seams: `Locale.set_lang`, `AccessibilitySettings` (`set_enabled`, `is_reduced_motion`, `is_colorblind`, `apply_prefs`), `ModesSave.save_pref`, and the pad settings consumed by the input layer.

## Prerequisites (Definition of Ready)

- GATE-A passed; UIR-05 landed (motion policy); UIR-04 landed; UIR-07 landed (pattern).

## Read allowlist

- `index.html:399-442` (groups, ids: `settingsLangSeg`, `optReduceMotion`, `optColorblind`, `settingsVolume`, `settingsDeadzone`, `settingsVibration`)
- `styles.css`: `.settings-grid`, `.settings-group`, `.controller-settings__title`, `.controller-range`, `.controller-toggle`, segmented base rules
- `js/main.js:2314-2530` (element refs + handlers: language seg, reduce motion, colorblind, volume, deadzone, vibration; the sync function `:2452-2470`), `js/ui.js:405-442` (`loadPrefs`, `savePrefs`, `collectPrefs`)
- `godot/src/locale/locale.gd` (`set_lang`, `current_lang`, `locales`), `godot/src/accessibility/accessibility_settings.gd:116-206` (API + `MARKUP_DEFAULT_DIVERGENCE` note), `godot/game/hud.gd:494` and `godot/game/match_controller.gd` volume/deadzone consumption points (read-only; verify the current prefs consumer, likely `match_config`/save pref keys)
- i18n keys: `settingsTitle`, `settingsSub`, `language`, `accessibility`, `reduceMotion`, `colorblind`, `audioSettings`, `volume`, `deadzone`, `vibration`, `ariaSettings`

## Write allowlist (you own these)

- `godot/src/ui/screens/SettingsScreen.gd`, `godot/src/ui/screens/SettingsScreen.tscn`
- `godot/src/ui/components/SettingsRows.gd` (+ `.tscn` if split)
- `.uid` sidecars for the files above
- `godot/tests/ui/screen_settings_audit.gd`, `godot/tests/ui/screen_settings_audit.tscn`
- `docs/implementation/ui-recreation/evidence/uir-19-screen-settings.log`

No other writes. Not `godot/src/ui/components/ControlLegend.gd` (UIR-13 owns it).

## Behavior rules (each becomes an audit assertion)

- Language seg: IT/EN, reflects current; changing it calls `Locale.set_lang` and refreshes every visible string on this screen (and the audit flips it back to leave state clean).
- Reduce motion toggle: persists via the save contract; `UiMotionPolicy.reduced_motion()` follows immediately; visible state matches.
- Colorblind toggle: persists; `is_colorblind()` follows; the UI-level treatment hook exists (the full FX treatment is the existing module's; this screen only persists + reflects).
- Volume: range 0-1, step 0.01, visible percentage; persists; the audio layer reads the same value on next session (assert stored value round-trip).
- Deadzone: range 0.08-0.30, step 0.01, visible percentage; persists; matches the pause overlay's value after UIR-20 lands (shared component + shared key make them one value; assert after UIR-20's landing if it is present, otherwise assert the round-trip).
- Vibration toggle persists and is reflected in the pause controller tab (same shared row).
- Slider step semantics: assert typed increments (0.08, 0.09 ... and 0, 0.01 ...) rather than continuous floats.

## Microsteps

1. Key/row table first; include the persistence key for each setting (find the existing prefs keys; do not create new ones without recording the mapping).
2. `SettingsRows.gd`: `make_range(label_key, min, max, step, value, format_percent) -> Control` and `make_toggle(label_key, value) -> Control`, with a `changed` signal carrying the raw value; text through `UiStrings`.
3. Screen groups per markup; wire to save + `Locale` + `AccessibilitySettings`.
4. `screen_settings_audit.gd`: value bounds/step, percentage text, persistence round-trip via a temp store, language flip widening (flip and assert every group's strings change), motion/colorblind policy follows, capture states.
5. Run; save log.

## Acceptance commands (native macOS)

```bash
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
cd /Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot
"$GODOT" --headless --path godot/ --script res://tests/ui/screen_settings_audit.gd ; echo "exit=$?"
```

## Evidence to hand back

`evidence/uir-19-screen-settings.log`; hand-back names the prefs key mapping table and the volume/deadzone consumer call sites it writes for.

## Definition of Done

- [ ] All rows implemented and persisted through existing keys; language flip refreshes the screen; motion/colorblind observable; zero literals; audit green.
- [ ] `SettingsRows` contract documented for UIR-20.
- [ ] Hand-back names command and tally.

## Failure and recovery

- A setting has no existing persistence key (for example reduce motion): `AccessibilitySettings` owns its own persistence via `apply_prefs`; verify how it persists before writing a second path; if nothing persists it, blocker note naming the missing key; do not add a schema.
- Slider formatting diverges (locale percent formatting): keep `%` formatting identical to the reference (integer percent), record.

## Traces

`index.html:399-442`, `js/main.js:2314-2530`, `js/ui.js:405-442`, `godot/src/accessibility/accessibility_settings.gd:91, :116-206`; scout T11 acceptance list.

## Finalize closure (2026-09-17, integration owner)

Engine record, one Godot process at a time, manifest `docs/implementation/ui-recreation/evidence/uir-finalize/ui-audit-sweep.json` (all sources hashed
before and after: tree digest `1256f5f1d7200437`, stable).

- `tests/ui/screen_settings_audit.gd` — **PASS 91/91**, exit 0, 0 `SCRIPT ERROR` line(s) (0.4s); log `docs/implementation/ui-recreation/evidence/uir-finalize/runs/screen_settings_audit.log`

**State: `done`** — the audit above is this ticket's arbiter and it is green on the
finalize tree.
