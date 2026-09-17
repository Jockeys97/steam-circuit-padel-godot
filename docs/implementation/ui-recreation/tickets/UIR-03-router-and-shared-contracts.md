---
id: UIR-03
title: Screen router and shared UI contracts
slug: router
state: done
readiness: potential
owner_role: shared-ui worker
blocked_by: []
blocks: [UIR-04, UIR-05, UIR-07, UIR-08, UIR-10, UIR-11, UIR-12, UIR-13, UIR-14, UIR-15, UIR-16, UIR-17, UIR-18, UIR-19, UIR-20, UIR-21, UIR-22, UIR-24]
gates: [plan-approval]
plan_approved: true
triage: ready-for-agent
evidence:
  - docs/implementation/ui-recreation/evidence/uir-03-router-audit.log
---

# UIR-03: Screen router and shared UI contracts

## Worker brief (copy-paste)

> Build the Godot screen router for exactly the 13 reference screen IDs and the shared pieces every screen uses: a screen shell (title row, declared back target, content region, safe-area), a placeholder screen for not-yet-built screens, and `UiStrings.gd`, a thin adapter over `godot/src/locale/**` that owns ids and no dictionary. The router owns its own screen table and must not import `godot/src/input/nav_routes.gd`, which stays the read-only reference inventory; the router audit compares the two. After this ticket lands, the router file freezes: later screen tickets add screens through the registration API and do not edit the router.

## Why this exists

The web build routes through one function (`js/ui.js:595-607` `showScreen`), which guarantees exactly one active screen. The port has no router; the handoff's S4 scope named one but nothing was built (`godot/src/ui/` does not exist). Every screen ticket must be able to land without touching a shared file, so the router, the shell and the string adapter are all built once, here.

## Prerequisites (Definition of Ready)

- Pack approved. UIR-02 not required (no visuals needed for the contract); requiring it would delay the critical path.

## Exact screen inventory (do not add, rename or drop; verified against the frozen reference)

| # | Router id | DOM id | Markup anchor | Declared back |
|---|---|---|---|---|
| 1 | `menu` | `screen-menu` | `index.html:31` | none (root) |
| 2 | `characters` | `screen-characters` | `index.html:90` | `modes` |
| 3 | `modes` | `screen-modes` | `index.html:103` | `menu` |
| 4 | `arena` | `screen-arena` | `index.html:157` | `characters` |
| 5 | `help` | `screen-help` | `index.html:181` | `menu` |
| 6 | `history` | `screen-history` | `index.html:268` | `menu` |
| 7 | `challenges` | `screen-challenges` | `index.html:281` | `menu` |
| 8 | `profile` | `screen-profile` | `index.html:293` | `menu` |
| 9 | `feedback` | `screen-feedback` | `index.html:310` | `menu` |
| 10 | `drill` | `screen-drill` | `index.html:366` | `menu` |
| 11 | `settings` | `screen-settings` | `index.html:399` | `menu` |
| 12 | `game` | `screen-game` | `index.html:445` | none (field) |
| 13 | `result` | `screen-result` | `index.html:539` | none; carries a `to-menu` action |

Source: `godot/src/input/nav_routes.gd` generated block (verified this session against `index.html`). The pause overlay, smash tutorial, OSK, asset-loading overlay, action deck, event log and replay overlay are states, not screens; they are covered by UIR-20 and its siblings.

## Read allowlist

- `godot/src/input/nav_routes.gd` (reference inventory; read-only)
- `godot/src/locale/locale.gd` (`t`, `is_resolvable`, `set_lang`, `current_lang`, `locales`, `substitute` at `:41-161`), `godot/src/locale/locale_data.gd`
- `godot/tests/input/reachability_audit.gd` (the audit that already exists over the reference inventory; the new router audit is a sibling, not a replacement)
- `godot/tests/smoke_test.gd:8-14` (the ok/FAIL/PASS output contract)
- `godot/game/menu_focus.gd`, `godot/src/input/focus_nav.gd`, `godot/src/input/menu_nav.gd` (the existing focus model the shell will report to; do not modify)
- `js/ui.js:444-458` (the registry), `js/ui.js:595-607` (`showScreen` body: unregistered name logs and stays put)

## Write allowlist (you own these)

- `godot/src/ui/ScreenRouter.gd`
- `godot/src/ui/UiStrings.gd`
- `godot/src/ui/ScreenShell.gd` and `godot/src/ui/ScreenShell.tscn`
- `godot/src/ui/PlaceholderScreen.gd` and `godot/src/ui/PlaceholderScreen.tscn`
- `godot/src/ui/screens/ScreenContract.gd` (the base class every screen extends)
- `.uid` sidecars for the files above
- `godot/tests/ui/router_audit.gd`, `godot/tests/ui/router_audit.tscn`
- `docs/implementation/ui-recreation/evidence/uir-03-router-audit.log`

No other writes. No commits.

## Do not touch

`godot/src/input/nav_routes.gd` (generated; a byte change fails its own `--verify`), `godot/game/**`, `godot/project.godot`, the frozen web reference, other tickets' files.

## Interface (all new; these names are the contract later tickets consume)

- `ScreenRouter.gd` (extends Node, added to a scene root by UIR-09):
  - `register(id: String, scene: PackedScene) -> void`
  - `go_to(id: String, payload: Dictionary = {}) -> bool`
  - `active_id() -> String`
  - `active_screen() -> Node`
  - `back_target_of(id: String) -> String` ("" for menu/game/result)
  - signal `screen_changed(from_id: String, to_id: String)`
  - On `go_to`: free (or pool) the previous screen first, so exactly one screen exists in the tree; unknown id: log and stay, mirroring `js/ui.js:597-607`.
- `ScreenContract.gd` (extends Control):
  - `screen_id() -> String` (abstract)
  - `back_target() -> String`
  - `enter(payload: Dictionary) -> void`, `exit() -> void`
  - `capture_states() -> Array[String]` (default `["default"]`; each screen ticket declares its own states)
  - `apply_capture_state(state_id: String) -> bool` (default false; the capture harness in UIR-24 calls these)
- `UiStrings.gd` (extends RefCounted):
  - `static func t(message_id: String, params: Dictionary = {}) -> String` forwards to `Locale.t()`; fallback is the id itself, exactly the locale seam's chain
  - `static func has(message_id: String) -> bool` forwards to `Locale.is_resolvable`
  - It owns no table. Any literal prose in a screen script is a red finding.
- `ScreenShell.gd`: title row (back button + title + subtitle), content region, safe-area margins (`SAFE_MARGIN := 8.0` pattern from `godot/game/hud.gd:75`), styled by the theme once UIR-02 lands (until then, unstyled is acceptable for the contract test).
- `PlaceholderScreen.gd`: shows the screen id and "not built yet" (text via UiStrings fallback id, no invented prose beyond this label), carries the correct back target, and is the only thing later tickets replace.

## Microsteps (do in order)

1. Write `ScreenContract.gd` first, with doc comments citing `js/ui.js:595-607` and the table above.
2. Write `ScreenRouter.gd` with the 13-id table embedded (own copy, NOT imported from nav_routes) and the declared back edges from the table. Add a doc comment: "this table is compared, not shared; `nav_routes.gd` is the reference's own copy and the two are cross-checked by `router_audit.gd`".
3. Write `UiStrings.gd` (thin, doc comment names `godot/src/locale/locale.gd:97-138` as the resolution chain).
4. Write `ScreenShell.gd/.tscn` and `PlaceholderScreen.gd/.tscn`.
5. Write `router_audit.gd/.tscn` (extends SceneTree, headless). Assertions, each printing `ok`/`FAIL` and a `PASS n/n` summary:
   - the router knows exactly 13 ids, equal to both `nav_routes.gd`'s `ROUTE_SCREENS` ids and `ROUTE_REGISTRY` (both ways);
   - `go_to` for each id leaves exactly one active screen (`active_screen()` not null, previous freed);
   - every non-root screen's back target is a registered id and matches `nav_routes.gd`'s `back` field;
   - menu/game/result declare no back target; result carries the `to-menu` action;
   - `go_to("nope")` logs and leaves the active screen unchanged;
   - no view script under `godot/src/ui/**` (excluding `UiStrings.gd` itself and the placeholder label) contains a user-facing literal: grep-style scan inside the audit, print offenders by file and line;
   - `UiStrings.t("does_not_exist_key", {})` returns the key itself (fallback chain).
6. Run the audit headless on this Mac; save the log.
7. Hand back with the exact tally.

## Acceptance commands (native macOS)

```bash
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
cd /Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot
"$GODOT" --headless --path godot/ --script res://tests/ui/router_audit.gd ; echo "exit=$?"
"$GODOT" --headless --path godot/ --script res://tests/input/reachability_audit.gd ; echo "exit=$?"   # must stay green
```

## Acceptance commands (Linux CI form, existing, host agents only)

The same two commands under `flock -w 900 /tmp/padel-godot.lock timeout 300` with the Linux binary.

## Evidence to hand back

- `evidence/uir-03-router-audit.log`: exit 0 and `PASS n/n`.
- Hand-back message: router API list, audit tally, the literal-scan result (files scanned, offenders, none).

## Definition of Done

- [ ] 13 ids exactly; back edges match the table; audit green; reachability audit untouched and still green.
- [ ] `UiStrings.gd` contains no dictionary; grep for `"` in `ScreenRouter.gd` shows only ids and format strings, no prose.
- [ ] One screen in the tree at a time, proven by the audit.
- [ ] Freeze note in the router header: after this ticket, only the integration owner (UIR-22) or a coordinator-approved change edits this file.
- [ ] Hand-back names command and tally.

## Failure and recovery

- nav_routes mismatch: fix the router table, never nav_routes.
- The literal-scan flags the placeholder's own label: whitelist that one string explicitly in the audit with a comment, or route it through an existing locale id if one resolves; do not weaken the scan to skip whole files.
- Focus integration surprises: the shell reports focusable controls but does not own focus policy; defer focus details to UIR-05 and note the hand-off.

## Traces

`js/ui.js:444-458`, `js/ui.js:595-607`, `godot/src/input/nav_routes.gd` header, `scripts/reachability-audit.mjs` §3 + registry cross-check, old S4 ticket file list (`docs/implementation/tickets/hud-and-menu.md:52-56`), scout UI-02.
