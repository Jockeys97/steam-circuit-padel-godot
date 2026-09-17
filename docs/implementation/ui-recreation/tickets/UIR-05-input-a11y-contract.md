---
id: UIR-05
title: Input, focus and accessibility contract for the new UI
slug: input-a11y
state: done
readiness: potential
owner_role: input/a11y worker
blocked_by: [UIR-03]
blocks: [UIR-07, UIR-08, UIR-10, UIR-11, UIR-12, UIR-13, UIR-14, UIR-15, UIR-16, UIR-17, UIR-18, UIR-19, UIR-20, UIR-21]
gates: [plan-approval]
plan_approved: true
triage: ready-for-agent
evidence:
  - docs/implementation/ui-recreation/evidence/uir-05-input-a11y-audit.log
---

# UIR-05: Input, focus and accessibility contract for the new UI

## Worker brief (copy-paste)

> Wire the new screen shells into the port's existing input stack: `menu_focus.gd` / `focus_nav.gd` / `menu_nav.gd` / `scheme.gd` / `strings.gd` / `osk.gd` / `accessibility_settings.gd`. Produce one audit (`input_a11y_audit.gd`) that proves keyboard and pad navigation reachability for the router screens, that back is a declared target, that locked controls stay discoverable but cannot activate, and that reduce-motion/colorblind prefs flow from `AccessibilitySettings` into the UI layer. Do not modify the input modules. Text-entry limitations without touch are recorded as explicit blockers.

## Why this exists

The port's input layer is already ported and audited (`godot/tests/input/**`, 4/4, 308 checks), including pad navigation of menus and the OSK model. Nothing new exists for the new router. This ticket is the bridge: it makes the new screens navigable by the same model, on the same audits' terms, without inventing a second focus system and without duplicating the OSK.

Key existing API (verified this session):

- `godot/game/menu_focus.gd`: `add(id, node, action, opts)`, `clear`, `has`, `node_of`, `ids`, `action_of`, `refresh`, `handle_key(event)`, `screen_id` (defaults to `NavRoutes.ROOT_SCREEN`)
- `godot/src/input/focus_nav.gd`: geometry focus (`find_target(dir)`, `move_focus`, `register_container`, `is_text_field`, `DIRECTIONS`, penalties)
- `godot/src/input/menu_nav.gd`: `open_screen(screen_id)`, `push_overlay/pop_overlay`, `set_pad_connected`, `set_osk_targets(targets)`, OSK open on confirm of a text field (`:223-231`), context constants `CONTEXT_OSK/OVERLAY/SCREEN`
- `godot/src/input/osk.gd`: OSK model with `open_for(field_id, value, max, label)`, `press_char`, `press`, `toggle_shift`, `close`; visual grid intentionally NOT built (postponed platform decision, UIR-26)
- `godot/src/accessibility/accessibility_settings.gd`: `set_enabled`, `is_reduced_motion`, `is_colorblind`, `apply_prefs`, `particle_count`, `shake`, `label`, `control_label`, `unnamed_controls`, `keyboard_policy`; note its recorded divergence `MARKUP_DEFAULT_DIVERGENCE` (`index.html:414` checked vs `js/ui.js:471` false)

## Prerequisites (Definition of Ready)

- UIR-03 landed (router + ScreenShell exist).

## Read allowlist

- All modules listed above in full
- `godot/tests/input/gamepad_nav_audit.gd`, `godot/tests/input/reachability_audit.gd`, `godot/tests/input/input_coverage_audit.gd`, `godot/tests/input/input_remap_a11y_audit.gd` (what is already asserted; do not duplicate)
- `scripts/gamepad-nav-audit.mjs:48-95` (reference contract: sections >= 8, menu declares no back, declared back wins, B/Circle backs, A/Cross confirms)
- `js/main.js:439-444` region and `:430-542` (the reference OSK the model renders)

## Write allowlist (you own these)

- `godot/src/ui/focus/UiFocusBridge.gd` (new; a thin adapter that registers ScreenShell controls into `MenuFocus` and routes `handle_key`/pad events for router screens)
- `godot/src/ui/focus/*.gd` (further small adapters if needed, one concern each)
- `godot/src/ui/accessibility/UiMotionPolicy.gd` (new; reads `AccessibilitySettings`, exposes `reduced_motion()`, `colorblind()`, `shake(amount)`, `particle_count(base)` for UI effects; the game-side FX stay owned by the existing module)
- `.uid` sidecars for the files above
- `godot/tests/ui/input_a11y_audit.gd`, `godot/tests/ui/input_a11y_audit.tscn`
- `docs/implementation/ui-recreation/evidence/uir-05-input-a11y-audit.log`

No other writes.

## Do not touch

`godot/src/input/**` (including `nav_routes.gd`), `godot/game/menu_focus.gd`, `godot/src/accessibility/accessibility_settings.gd`, `godot/project.godot` (the InputMap is complete for the reference actions; adding actions is a blocker note, not an edit).

## Interface (all new)

- `UiFocusBridge.gd` (extends RefCounted):
  - `attach(shell: Control, focus: MenuFocus) -> void`
  - `register(id: String, node: Control, action: String, opts: Dictionary = {}) -> void` (opts: `locked`, `disabled`, `hidden`)
  - `dispatch(event: InputEvent) -> bool` (keys -> `MenuFocus.handle_key`; pad -> focus_nav geometry move + `ui_accept`/`ui_cancel` semantics, delegating to `menu_nav.gd`; returns handled)
  - `focus_id() -> String`, `set_focus(id: String) -> bool`
- `UiMotionPolicy.gd`: as above; every UI-level animation the shell adds asks this policy before running.

## Microsteps (do in order)

1. Write `UiFocusBridge.gd` with doc comments naming the existing modules and the boundary: the bridge adds router screens to `MenuFocus`; it does not implement geometry or key repeat (those are `focus_nav.gd`'s, already audited).
2. Write `UiMotionPolicy.gd`.
3. Extend the ScreenShell (from UIR-03) minimally if needed so its back control registers as `back` action; the shell owns the id naming (`"<screen_id>/back"`).
4. Write `input_a11y_audit.gd` (headless, extends SceneTree). Assertions at minimum:
   - every registered router screen can be reached by walking declared edges from the root (graph reachability over the router's own table);
   - every focusable control on the shell registers with a stable id; no duplicates across the screen;
   - a locked control is still discoverable (focusable) but `dispatch` of confirm on it does not signal activation; and it reports `locked` upward;
   - back dispatch on a non-root screen calls `go_to(back_target)` (verified via signal capture);
   - `UiMotionPolicy.reduced_motion()` mirrors `AccessibilitySettings.is_reduced_motion()` after `set_enabled`; toggling flips it;
   - `menu_nav` OSK context: opening a text field via confirm with a pad connected opens the OSK model (`osk.is_open() == true`) and back closes it; this runs against a probe text field owned by this test scene, not against a real screen;
   - pack a `not-ported` count and print it, following `godot/tests/input/run_all.gd` style.
5. Run headless; save the log.
6. Hand back; list every text-entry limitation (no visual OSK grid until UIR-26; on desktop the physical keyboard is the entry path).

## Acceptance commands (native macOS)

```bash
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
cd /Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot
"$GODOT" --headless --path godot/ --script res://tests/ui/input_a11y_audit.gd ; echo "exit=$?"
"$GODOT" --headless --path godot/ --script res://tests/input/run_all.gd ; echo "exit=$?"   # must stay 4/4
```

## Acceptance commands (Linux CI form, existing, host agents only)

Same commands under `flock`/`timeout` with the Linux binary.

## Evidence to hand back

- `evidence/uir-05-input-a11y-audit.log`: exit 0, tally.
- Hand-back message: bridge API, audit tally, the explicit text-entry limitation list.

## Definition of Done

- [ ] Bridge and motion policy implemented; audits run; input suite untouched and green.
- [ ] No double activation from custom focus plus engine navigation (audit covers it; if a conflict appears, fix the bridge, not the engine defaults).
- [ ] Text-entry limitations written down, not implied.
- [ ] Hand-back names commands and tallies.

## Failure and recovery

- `MenuFocus` lacks a capability the shell needs (for example overlay contexts): use `menu_nav.gd`'s overlay API; if still blocked, stop and write the blocker naming the exact missing behavior. Do not fork the focus model.
- The audit runs into engine key-repeat semantics: assert the final focused id, not the intermediate steps.

## Traces

`godot/tests/input/gamepad_nav_audit.gd` header (reference assertions 1-10), `godot/src/input/osk.gd` header, `godot/src/accessibility/accessibility_settings.gd:91`, scout UI-08, `scripts/gamepad-nav-audit.mjs:73-92`.
