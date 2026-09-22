# Arena clean-mode implementation plan

## Goal

Add an in-match clean-view toggle that hides informational UI without changing simulation, pause state, gameplay controls, or match persistence.

## Product contract

- Toggle with a pressed left-mouse double-click while the pause overlay is closed.
- Toggle with joypad Start/Options (`JOY_BUTTON_START`) or Back/View (`JOY_BUTTON_BACK`) while the pause overlay is closed.
- Consume those toggle events so they cannot also pause or activate gameplay UI.
- Keep keyboard Escape and the on-screen pause flow unchanged.
- Hide the shipping HUD, legacy HUD, mode facts, mini-map, score/time/actions, serve banner, event log, active-player ring/pin, drill target, and court timing/energy/advice marks.
- Keep the pause overlay, replay overlay, touch controls, players, ball, court, and gameplay effects available.
- Reset clean mode to visible UI for each new match/rematch.
- Provide small public seams for deterministic tests: `set_hud_hidden`, `toggle_hud_hidden`, and `is_hud_hidden`.

## Implementation boundaries

- Primary owned file: `godot/game/match_controller.gd`.
- `godot/game/court_timing_marks.gd` may be changed only if its existing `set_muted` seam cannot satisfy the contract.
- Add focused tests under `godot/tests/ui/` and evidence under this directory.
- Do not change `project.godot`: the two standard joypad button indices are handled directly to avoid platform mapping ambiguity.
- Preserve all pre-existing dirty changes in `match_controller.gd`; do not revert, reformat, stage, commit, push, or touch unrelated files.

## Acceptance checks

1. Initial and rematched game shows HUD.
2. Synthetic left double-click toggles hidden and visible.
3. Synthetic Start and Back/View joypad presses each toggle hidden and visible.
4. Shipping/legacy informational HUD and world-space informational marks follow the state.
5. Pause/replay/touch layers are not hidden by clean mode.
6. Keyboard Escape pause behavior remains intact.
7. Existing targeted pause/HUD/timing audits still pass, plus the new clean-mode audit.

## Checkpoint protocol

Report a concise milestone after discovery/implementation or within five minutes. If the bundle is not complete within fifteen minutes, return a handoff with exact changed paths, tests run, failures, and remaining work.
