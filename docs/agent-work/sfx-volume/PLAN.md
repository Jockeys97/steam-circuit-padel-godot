# Independent SFX volume control

## Objective

Add one persistent, live SFX-volume slider, independent of the existing master and music controls. Make it available in the main Settings screen and in the in-match pause controller/audio tab, where volume settings already live.

## Repository baseline

- Checkout: `/Users/alessiofantini/Documents/steam-circuit-padel-11m`
- Branch: `codex/integrate-arena-11m`
- Baseline commit: `98356c2c232de6547fd51bfd8d4b97d2fffd33d6`
- The initial baseline check showed no tracked edits; while preparing this brief, concurrent Meshy edits appeared in `docs/agent-work/meshy-lunge/tasks-meshy2.json` and `tools/meshy/lunge-strokes.cjs`, alongside untracked `docs/agent-work/meshy-lunge/{forehand_volley,ready_stance}.{fbx,glb}` assets. Preserve all of them; they are outside this task.
- Existing mixer graph has `SFX -> Master` and `Music -> Master`; the current Settings screen controls master and music only. `AudioPort` sends its one-shot effects to `SFX`.

## Product and compatibility contract

- Add preference `sfxVolume`, normalized to `[0.0, 1.0]`, default `1.0`. Existing saves without this key must retain today's SFX level.
- Apply the preference only to the existing `SFX` bus. Keep master gain and the existing music bus/gain/mute independent; moving the SFX slider must not change either preference or bus.
- Zero means silent; one means the current/reference SFX level. Changes apply immediately and persist through the existing save-profile path.
- Expose the same value/control in the global audio settings and pause audio/controller tab. Keep keyboard/controller focus, slider stepping, localization, and refresh behavior consistent with neighboring rows.
- Inspect all live gameplay SFX routing during implementation. Route intended effects through the SFX bus without changing their authored/event-relative mix; do not move music or UI navigation sounds unless current architecture already classifies them as SFX.

## Non-goals

- No changes to master/music sliders, soundtrack continuity, OST selection, music context behavior, individual event gains, audio assets, or sound design.
- No change to HUD profiles, controller vibration, simulation, input mapping, or settings-screen redesign.
- No commit, staging, push, branch switch, cleanup, or modification of unrelated Meshy assets.

## Owned implementation paths

The worker may inspect adjacent callers/tests and should keep the patch limited to the relevant files among:

- `godot/src/save/save_schema.gd`
- `godot/src/ui/data/UiData.gd`
- `godot/src/audio/mixer_contract.gd` and the existing audio adapter(s)
- `godot/src/ui/screens/SettingsScreen.gd`
- `godot/src/ui/screens/PauseOverlay.gd`
- `godot/src/locale/locale_data.gd`
- focused settings, pause, save, and mixer tests under `godot/tests/`

Do not rewrite existing settings or pause UI structure.

## Acceptance criteria

1. The new setting appears in both audio-control locations, has Italian and English labels, is focusable/operable by existing mouse, keyboard, and controller paths, and refreshes from the saved value.
2. Old saves default to `1.0`; slider changes persist and take effect during the current session.
3. Tests prove min/mid/max gain behavior, exact mute at zero, and that SFX gain changes leave master/music bus state and saved values unchanged.
4. Focused settings and pause audits verify the row, navigation, persistence, localization, and live update; the mixer audit verifies routing and gain.
5. Existing soundtrack/music tests remain green; no unrelated regression work is included.

## Verification commands

Run focused scripts using the installed Godot binary, for example:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --script res://tests/mixer_contract_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --script res://tests/ui/screen_settings_audit.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --script res://tests/ui/pause_audit.gd
```

Also run the focused save/audio test that covers the new preference and the existing music settings test if the implementation touches shared mixer initialization. Report actual commands, exits, and pass counts; do not claim full-suite success from these focused checks.

## Implementation and review status

- One vertical implementation bundle; no independent parallel writers.
- The user asked whether Luna could proceed directly, so this implementation was completed in the current session without delegation.
- Focused acceptance: `screen_settings_audit.gd` PASS 154/154; `pause_audit.gd` PASS 241/241; `mixer_contract_test.gd` PASS 39/39; `save_steam_test.gd` PASS 146/146; `music_preferences_test.gd` PASS 43/43.
- Integration spot-check: `game_slice_test.gd` loaded the updated menu and match-controller code but finished FAIL 337/338 on `OST starts an available track`; the diagnostic itself reports `playing: true` while that assertion expected a boolean. The focused audio/pause/save audits pass, and soundtrack behavior was not changed.
- Audio routing inspection found gameplay event effects on the existing `SFX` bus via `AudioPort`, plus the passing-train ambient player also explicitly uses `SFX`. Music/Jukebox players use `Music`; no additional gameplay player needed rerouting.
- `git diff --check` passes. Nothing was staged or committed.
- The implementation must continue to preserve the concurrent Meshy work and the unrelated pause-menu edits already present in the checkout.
