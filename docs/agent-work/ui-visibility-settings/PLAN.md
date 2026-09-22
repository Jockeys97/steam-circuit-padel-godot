# In-match UI visibility settings

## Objective

Extend the accepted arena clean-mode implementation with a discoverable restore hint and a fourth `UI` tab in the pause overlay. The player can select presets or individual informational surfaces without changing simulation, scoring, pause, replay, or input behavior.

## Product contract

### Visibility model

The match controller owns one per-match visibility profile with these six stable component ids:

- `score`: scoreboard and match score facts.
- `time`: timer only.
- `map`: mini-map.
- `guidance`: serve banner, shot/help panel, and mode/objective strip.
- `indicators`: active-player ring/pin, drill target, timing/precision/advice and all stamina bars.
- `events`: quick-action chrome and match/event feed.

The shipping HUD exposes a component-visibility seam; the controller applies the same profile to legacy/world-space surfaces where applicable. Refreshes must never re-show a disabled component.

### Presets

- `all`: all six components on.
- `essential`: score, time, indicators, and quick-action/event chrome on; map and guidance off.
- `score_only`: score on, every other component off.
- `clean`: all six components off.

The pause tab shows the four presets first, then the six independent toggles. Changing a toggle that no longer exactly matches a preset leaves no preset selected. All controls must be reachable and operable with mouse, keyboard, and existing controller focus navigation.

### Existing clean-mode gesture

- Left double-click, PS Options/Start, or Xbox View/Back toggles between `clean` and the last non-clean profile.
- Choosing `clean` stores the prior non-clean profile; restoring returns that exact profile rather than forcing `all`.
- A new match/rematch starts at `all`, preserving the already accepted reset behavior.
- Keyboard Escape and pause-menu behavior remain unchanged.

### Restore indication

When and only when the profile is fully clean and the pause overlay is closed, show one small, unobtrusive bottom-centre hint outside the hidden HUD: `Doppio clic · Options / View — Mostra UI` (localized Italian/English). It must not block mouse input and must disappear immediately when UI is restored or the pause card opens.

The new UI tab also includes a localized short explanation of the same shortcut.

## Architecture and interfaces

- `Hud.gd`: add `set_component_visibility(profile: Dictionary)` and a readable snapshot/report of applied component visibility. Do not hide the whole HUD root; hide the named top-level/sub-panels so the external restore hint can remain independent.
- `match_controller.gd`: own the canonical profile and last non-clean profile; expose `ui_visibility_snapshot()`, `set_ui_component(id, visible)`, `set_ui_preset(id)`, and `ui_preset_id()`. Keep existing `set_hud_hidden`, `toggle_hud_hidden`, and `is_hud_hidden` compatible.
- `PauseOverlay.gd`: add `TAB_UI`, build preset controls and toggle rows, read/write only through the bound controller seam, and include them in `focus_controls`, `set_row_value`, refresh, localization, narrow layout, report, and capture/audit surfaces.
- Localization: add explicit Italian and English message ids in the existing locale table; do not embed new player-facing prose in GDScript.
- Restore hint may be a small dedicated UI script/scene or a tightly bounded UI node owned by the controller, but it must be a sibling of the main HUD under `HudLayer`, below the pause overlay.

## Non-goals

- No persistent save-schema migration; the profile is per match and resets on rematch.
- No InputMap or controller mapping changes.
- No changes to simulation, scoring, AI, replay, touch controls, assets, or global settings.
- No commit, stage, push, branch switch, cleanup, or unrelated formatting.

## Owned paths

- `godot/game/match_controller.gd` (preserve all pre-existing dirty changes).
- `godot/src/ui/Hud.gd` and, only if structurally required, `godot/src/ui/Hud.tscn`.
- `godot/src/ui/screens/PauseOverlay.gd` and, only if structurally required, `PauseOverlay.tscn`.
- `godot/src/locale/locale_data.gd`.
- Focused tests under `godot/tests/ui/` and evidence in this directory.

## Acceptance

1. All four presets produce the exact component map above.
2. Each of the six toggles changes only its component and the HUD/world indicators follow immediately and across refresh frames.
3. Clean-mode gesture restores the exact previous custom/preset profile.
4. Hint appears only in clean live play, is localized, ignores mouse input, and disappears on restore/pause.
5. Fourth pause tab displays correctly at 1280x720 and a narrow supported frame; four tabs and all UI rows participate in controller/keyboard focus without breaking back hierarchy.
6. Existing pause, HUD, clean-mode, controller navigation, and UIR-22 integration audits remain green.
7. Add a focused audit for presets, custom profile, restore memory, hint, refresh, tab controls, localization, and rematch reset; capture at least the new UI tab and the clean restore hint for visual review.

## Progress protocol

Checkpoint after baseline/discovery and after first working implementation, or at five minutes. Target a finite review handoff within fifteen minutes; otherwise return exact changed files, tests, captures, blockers, and remaining work.
