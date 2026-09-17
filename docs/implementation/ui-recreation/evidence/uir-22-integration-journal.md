# UIR-22 journal — integration wave (sole engine runner), started 2026-09-17

## Recon (done)
- Theme.blocker confirmed: padel_theme.tres 3-arg Color rows (419-429, 434-435, 13 rows) failed to parse ("Expected 4 arguments for constructor"). FIXED -> alpha-4 per reference; theme_probe now PASS 305/305, 0 SCRIPT ERROR, exit 0.
- Untracked waves on disk: screens 10-21 + overlays 20/26 + components + audits (all present, none tracked).
- Default path to flip: main_menu.gd (`ui_prototype`, `--ui=new|legacy`), match_controller.gd (`_ui_new`).
- Seams to close (recorded by the workers): set_match_paused(bool) (UIR-20 recipe §4), overlay mount recipe (uir-20 §4), result payload builders (UIR-21 payload_from_state), OSK panel bind_model + set_osk_targets (UIR-26 §4), touch layer mount (UIR-26 §9.2), pending-result handoff (new).

## Landed (2026-09-17, this session)
- match_config.gd: `pending_result` + `take_pending_result()` (single-shot handoff), tournament-round doc block.
- match_controller.gd: `--ui=new` is the default playable path; prototype layer mounts `if _ui_new and engine_driven`; overlay+tutorial+touch mount recipe; `set_match_paused(bool)` seam (controller owns `_paused`, overlay told, explicit not toggle); ESC hierarchy through the card; rematch/reset clears pause; pause-card ranges applied to the card's own rows; `leave_match()`; `result_payload()` + `finish_route(dry_run)` (Config.pending_result <- payload, then scene change on the engine path only).
- main_menu.gd: playable host — all twelve recreated Control screens registered on the router, UIR-05 bridge attached per screen change, OSK panel mounted and synced only while the model is open, `range_changed` handed to the screen (`set_volume`/`set_deadzone`/`set_row_value`), stored language applied at boot, result screen mounted from `Config.pending_result` (then consumed), `rematch_route()`, `ui_legacy` opt-out for the ported column.
- hud.gd: HUD_LANG forcing removed (one locale drives menu and match now).
- project.godot: `[display]` 1280x720 canvas_items + keep (the reference's fixed stage).
- SettingsScreen: focus rows now carry the row's own min/max/step/value (the wave-3 carried-keys seam, previously unused).

## Engine failures found and repaired while running the flow
- CharactersScreen.gd: duplicate `var stack` in one scope -> the screen could not load at all (hard parse error).
- ControlLegend.gd: `(root as Container).add_child(line)` was null on the tutorial row (its root is a Button, not a Container) -> the tutorial link existed as a registered button but never rendered in the grid.
- SmashTutorial.gd: `result["cap_up"]` unguarded (the bandeja row carries `cap_down` only) -> engine error every time the tutorial was built; and `box.vertical =` on HBoxContainers -> "Can't change orientation of HBoxContainer" on every build/resize, replaced by a container swap.
- match_controller.gd `_sync_views()`: wrote through `_ball_view` when `load_models == false` (harness/headless) -> null-access error on every start/rematch.
- pause_audit.gd / osk_touch_audit.gd: their own parse errors (static call to a non-static `palette_keys()`, untyped `var x :=` inference) — the audits could not load.

## Serial sweep (pgrep guard, one Godot at a time)
- theme_probe 305/305 · router_audit 86/86 · data_audit 131/131 · fonts_assets_probe 75/75 · hud_audit 172/172 · pause_audit 176/176 · input_a11y_audit 153/153 · uir22_integration_audit 71/71 — all exit 0, 0 engine errors (router's 2 ERROR lines are its own negative cases: bad id, null scene).
- screen audits green: menu 97/97, modes 118/118, arena 133/133, drill 89/89, result 176/176, settings 91/91, feedback 119/119.
- game_slice_test PASS 342/342, exit 0, 1 engine line = the recorded `ALLOW_ARENA` unknown-id probe (uir-00-baseline-gates.log:90-105), SCRIPT ERROR 0.
- Red and classified in evidence/uir-22-integration.log §5: osk_touch 171/177 (0 SCRIPT ERROR), characters 147/148, help 73/75, history 37/42, challenges 64/68, profile 44/60, ui_legibility 572/664 — none mounts through the host; the screens' own lanes carry different historical tallies (lane drift, not these seams).

## Next
- File the evidence log (done: evidence/uir-22-integration.log), report gaps (legacy HUD dev text remains on the diagnostic-only path; d-pad has no model path in the reference either).
- Finalize closure (2026-09-17): the naming drift between the ticket's declared
  `evidence/uir-22-integration.md` and the recorded files is closed — the ticket's frontmatter now
  points at `uir-22-integration.log` + this journal, plus the finalize manifest
  `evidence/uir-finalize/ui-audit-sweep.json` (**32/32 green**, tree digest `1256f5f1d7200437`).
