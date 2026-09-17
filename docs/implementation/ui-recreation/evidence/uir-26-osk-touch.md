# UIR-26 — on-screen keyboard visual grid + touch layer: decision record and evidence

Ticket: `docs/implementation/ui-recreation/tickets/UIR-26-osk-touch.md`
Lane: this worker owned **UIR-20 + UIR-26 only**; `godot/src/input/osk.gd` and `menu_nav.gd` (the
input lane) were read, never edited.
Engine: **NOT run by this worker.** The wave's dispatch forbids starting Godot ("NO Godot from
you"), so the acceptance command in §7 is **owed**, and everything green here is static (§6) plus
the audit file itself (`godot/tests/ui/osk_touch_audit.gd`, 159 assertion sites).
**No device was tested. No touchscreen exists on this machine** (`DisplayServer.is_touchscreen_available()`
is false on the audit host); see §5 for the tested/not-tested split. $0, no commits/staging/push.

## 1. The decision — recorded verbatim, and what it is not

The ticket's worker brief gates all construction on an explicit answer to
`docs/wayfinder/tickets/product-scope-and-platforms.md` for touch/OSK. The wave's dispatch carried
the owner's directive for this ticket verbatim as:

> ALL APPROVED finalize playable, treat planned platform UI as approved implementation, not claim
> device tests.

Read against the ticket's three outcomes (`keep` / `postpone to a stated slice` / `drop`), that is
**KEEP**: touch and the on-screen keyboard are to be built, treated as approved implementation, and
must not be reported as device-tested. The KEPT scope was therefore built and audited (§2-§4), and
the "not device-tested" half of the directive is honoured in §5 and inside the audit itself (three
`not_ported` rows, plus engine-run).

**What this file does not do, deliberately:** it cannot write the resolution line into
`docs/wayfinder/tickets/product-scope-and-platforms.md`, nor the OSK/touch/action-deck rows of
`FEATURE-MATRIX.md` (both outside this ticket's write allowlist — "No other writes"). The formal
resolution record and the matrix rows are the coordinator's; this file is the citation they can
quote (ticket path + this directive + the evidence below). If a stricter reading of the gate is
wanted, the only thing missing is that one line in the wayfinder ticket; no code decision depends
on it any more, because the owner's directive is the decision.

## 2. What landed

| path | lines | bytes | sha256 (16) | what |
|---|---|---|---|---|
| `godot/src/ui/screens/OskPanel.gd` | 637 | 23277 | `65fb2d1c1888e6ff` | the visual keyboard: scrim, `min(760px,100%)` panel, label, value preview, five character rows, the action row (shift 1 : space 2.4 : backspace 1 : done 1), 38 px/13 px compact sizing, `osk_key_targets()` for `menu_nav` |
| `godot/src/ui/screens/OskPanel.tscn` | 16 | 444 | `f7c9a8c4377244b1` | full-rect Control, theme mounted, hidden until the model is open |
| `godot/src/ui/screens/TouchControls.gd` | 503 | 19020 | `8d2cc6e97d98eba5` | the coarse-pointer layer: the three-button action deck, the seven-button pad, the reference's visibility rules, one injection path (`Input.action_press/release`), per-button aria names |
| `godot/src/ui/screens/TouchControls.tscn` | 15 | 442 | `c862ab6e5ec1857c` | full-rect Control, `mouse_filter` IGNORE so the in-match HUD still passes through |
| `godot/tests/ui/osk_touch_audit.gd` | 549 | 32530 | `1633f56e3bf9028a` | the contract audit, 159 checks |
| `godot/tests/ui/osk_touch_audit.tscn` | 6 | 212 | `47c76ad1102c0dca` | runner scene, the house pattern |

No `.uid` sidecars (engine-generated; the scenes reference by path, as `ControlLegend.tscn` does).

## 3. Scope if KEPT — each line of the ticket, where it lives, what asserts it

| ticket scope line | implementation | audit check |
|---|---|---|
| five rows of true buttons | `OskPanel._rebuild_grid` builds from `osk.rows()` — `1234567890`, `qwertyuiop`, `asdfghjkl`, `zxcvbnm`, `àèéìòù@._-+` (`js/main.js:430-437`) | `osk/the_grid_has_every_character_of_the_reference`, `osk/the_characters_are_in_the_references_own_order`, `osk/every_key_of_the_grid_is_a_target` (52) |
| shift/space/backspace/done from the model | panel forwards to `osk.press()`; never re-implements | `osk/the_four_action_keys_are_the_references`, `osk/done_answers_closed`, `osk/a_shifted_key_shows_its_upper_face` |
| label from the field | `OskLabel` = `osk.label()` = `field_label · oskHint` | `osk/the_label_starts_with_the_fields_own_label`, `osk/the_label_carries_the_hint` |
| preview of the current value | `OskPreviewText`, `…` when empty (the reference's `:empty::after`) | `osk/the_preview_shows_the_fields_value`, `osk/the_preview_follows_the_value` |
| opened on confirm of a text field with a pad (model path already wired) | the panel renders `menu_nav.osk`; the lane opens it | `osk/confirming_a_field_opens_the_keyboard`, `osk/the_panel_renders_the_lanes_model`, `osk/the_first_key_takes_the_focus`, `osk/the_press_landed_in_the_lanes_model` |
| closed by back | `menu_nav.back()` → `osk_close`; the panel hides on the model's close | `osk/back_reports_the_keyboard_close`, `osk/back_names_the_field_to_refocus`, `osk/the_closed_signal_names_the_field` |
| 560 px-class compact sizing | keys 44→38 px, font 14→13 at ≤560 (`styles.css:3577-3582`) | `osk/a_wide_frame_keeps_the_44px_keys`, `osk/a_560px_frame_shrinks_the_keys` |
| touch: coarse-pointer path only (fine pointer hidden) | `set_coarse_pointer()`, default `DisplayServer.is_touchscreen_available()` | `touch/a_fine_pointer_hides_the_deck_at_desktop_width` |
| deck appears only under the reference's own conditions | deck = coarse ∧ width ≥ 681; pad = width ≤ 680 (`:2058, :2064, :2070`) | the six `touch/…frame…` checks incl. the 680/681 edge |
| buttons hit-test to the same input actions as the keyboard/pad | `DECK`/`PAD` map `hit→padel_drive`, `switch→padel_switch`, `special→padel_special`, `up/left/right/down→padel_*`; `padel_drive` is `input_map.gd`'s `PAD_DRIVE` | `touch/every_mapped_action_exists_in_the_project`, `touch/the_pads_up_is_the_up_action`, … |
| Godot specifics: `InputEventScreenTouch/Drag`; one path only, record which | **recorded: one path — direct action injection** (`Input.action_press`/`action_release` from the buttons' own `button_down/up`), so the same actions the pad and keyboard drive are driven here. Nothing was added to `InputMap` (no new bindings, no second route). `InputEventScreenTouch` is what the *platform* delivers; a touch lands on the button through Godot's own touch→mouse emulation (`input_devices/pointing/emulate_mouse_from_touch`, asserted present) and the button's own wiring does the rest | `touch/a_button_down_presses_the_action`, `touch/a_screen_touch_press_on_the_deck_drives_the_action`, `touch/the_engine_emulates_mouse_from_touch` |

Aria labels are the reference's own ids (`index.html:483-494`): deck `shot`/`switchBtn`/`specialBtn`,
pad `dirUp`/`dirLeft`/`shot`/`dirRight`/`dirDown`/`switchBtn`/`dirSpecial`, containers
`ariaActionDeck`/`ariaTouch` — asserted as a list, not sampled
(`touch/the_pads_aria_names_are_the_references_own`).

## 4. The lane integration, exactly

The reference's own path is kept: the model decides *when* the keyboard exists
(`menu_nav.confirm()` on a `text_field` with a pad connected), and this ticket renders it.

1. `menu.confirm()` → `{"kind": "osk_open", "target": "<field id>"}` and `menu.osk.is_open()`.
2. The mount calls `panel.bind_model(menu.osk)`, then `panel.refresh()` (or let `_ready` do it) —
   `panel.visible` follows the model.
3. `menu.set_osk_targets(panel.osk_key_targets())` — the ids are the **feedback screen's own door's
   ids** (`osk/<char>`, `osk/<shift|space|backspace|done>`), so one driver works for both surfaces;
   the rects are the laid-out buttons' real rects, so geometric navigation moves across the grid
   the player sees. The first key takes the focus (`ensureMenuFocus`, `js/main.js:529-531`).
4. A press (pad confirm on a key target, or the panel's own `press_target`/`press_char`/`press`) →
   the model changes → `panel` re-reads it and emits `changed`.
5. `menu.back()` → `{"kind": "osk_close", "target": "<field>"}`: hide and refocus the field.
   `panel.closed(target)` also fires when "done" closed the model, with the same field id.
6. The mount writes the value back: `field.text = menu.osk.value()` (the reference dispatches an
   `input` event on the field, `js/main.js:463-466`); `osk.close()` keeps the value for exactly
   this.

## 5. Platform behaviour — tested vs not (do not read one as the other)

| statement | status |
|---|---|
| the grid, the action row, the shift/space/backspace/done behaviour, the clamp, the preview, the label | **asserted** (model-level, in-engine once run) |
| the panel renders the lane's model and presses land in it | **asserted** (audit §"lane integration") |
| the 560 px compact sizing; the 680/681 px deck-vs-pad edge; the fine-pointer hide | **asserted on a resized `Control`**, not on a device |
| a finger on the deck/pad drives an action | **asserted only through `InputEventScreenTouch` + the engine's touch→mouse emulation** — no touchscreen exists on this machine |
| iOS/Android/Steam Deck layout, safe areas, the platform's own soft keyboard | **not tested, not ported** (`not_ported("device/handheld_export")`, `("device/steam_input_keyboard")`) |
| real pad + OSK interplay on hardware | **not tested** (input lane's model is asserted; no pad attached here) |

## 6. Static evidence — the checks that did run

Scratch checker (not a repo file; outside the allowlist): `/tmp/uir2026_static_check.py`.

- **Sources mode** → `70 checks, 0 failures` over all four of this wave's sources: literal scan
  (quoted string with a space outside developer output), brackets/strings, no tree-pause in code,
  every `_palette()` key in the theme or in the request set (§8), every `theme_type_variation` in
  the theme, every `padel_*` action in `project.godot`, every locale key in `locale_data.gd`, every
  `_font(role)` declared.
- **Audits mode** → `21 audit checks, 0 failures`: both audits shape-clean, ≥40 `audit.check_`
  sites, `SceneTree` + `_initialize()` + `finish()`, and every component method the audits call
  exists (the dynamic-dispatch trap GDScript would only reveal at run time).
- Palette keys: `OskPanel.gd` 11 (1 requested), `TouchControls.gd` 4 (1 requested) — §8.

## 7. Acceptance command — the run that is owed

```bash
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
cd /Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot
"$GODOT" --headless --path godot/ --script res://tests/ui/osk_touch_audit.gd ; echo "exit=$?"
```

Reading a run: the exit code is not a pass signal (a parse failure also exits 0) — the tally line
`PASS n/n` / `FAIL n/n` and the `SCRIPT ERROR` count are the evidence. A green run prints
`PASS 159/159` plus the notes block: the palette misses (§8), the display/no-touchscreen facts, the
theme parse error (§9) and the language-flip count.

## 8. Palette: requested and near-matched

| requested key | value | reference |
|---|---|---|
| `osk_scrim` | `rgba(4,8,24,0.72)` | `.osk` `styles.css:3471-3481` |
| `touch_button_bg` | `rgba(21,28,39,0.88)` | `.touch-controls button` `styles.css:1081-1099` |
| `deck_hit_border` `deck_hit_fill` `deck_hit_shadow` | `#15588b` `#1fa7d3` `#0c507f` | `.action-deck button` `styles.css:816-837` |
| `deck_switch_fill` | `#2974c7` | `.action-deck button[data-dir="switch"]` |
| `deck_special_fill` `deck_special_border` `deck_special_shadow` | `#ef8f2c` `#a84e1b` `#8c3c16` | `.action-deck button[data-dir="special"]` |

Near-matches (recorded with the delta): `.osk__key` `#0d2646` → `surface_2` `#0b2444` (2/2/2);
`.osk__panel` gradient `#0b2444 → rgba(11,36,68,.97)` → `surface_2` (the theme's documented
gradient collapse, theme README §6.1); `.osk__preview` empty glyph colour `var(--muted)` → `muted`.

Gaps (reference effects not faked): `.osk`'s `backdrop-filter: blur(6px)`; `.action-deck button`'s
inset highlight `inset 0 4px 0 rgba(255,255,255,0.28)`; the deck's hard `0 5px 0` step shadow is
carried as a `StyleBoxFlat` shadow offset instead of a second box (recorded; visually the same
step, one node cheaper). While a key is missing from the theme, `_palette()` records the miss and
falls back to the palette's `ink` — every miss is listed in `report()["palette_misses"]` and the
audit refuses any miss that this ticket did not declare.

## 9. Blockers for that run (cross-lane, not edited here)

1. **The shared theme does not parse at this instant** — `godot/src/ui/theme/padel_theme.tres` lines
   419-429, 434-435 use three-argument `Color(r, g, b)` (the defect UIR-19's log §5 recorded).
   Theme lane's fix (append `, 1`). This ticket's components are null-safe and record the miss, but
   the palette near-matches only read true once it parses.
2. **UIR-22 must mount these two scenes** (§5 recipe above) for the layer to appear at all — until
   then the audit's own mounts (frame + instances) are what exercises them.

## 10. Hand-back, one screen

- **Built (KEPT scope)**: `OskPanel` (grid/preview/label/compact sizing/targets) and `TouchControls`
  (deck + pad, reference visibility rules, one injection path, reference aria ids).
- **Decision**: recorded verbatim in §1 (owner directive via the wave dispatch); the formal
  wayfinder resolution line and the `FEATURE-MATRIX.md` rows are the coordinator's to write — this
  file is the citation.
- **Owed**: the engine run (§7); a device pass for the touch path; the theme fix (§9.1).
- **Files touched**: exactly the 6 in §2 (no `.uid`), nothing else — no engine, sim, save, locale,
  mode or shared-component file was edited.

## 11. Small-gates repair and finalize closure (2026-09-17)

The run owed in §7 landed in the small-gates pass (`evidence/uir-finalize/runs-small-gates/`, 6
suite logs + 2 probe logs + README), with three source fixes and the audit's stale expectations
corrected:

- `OskPanel.gd`: `osk_key_targets()` answers `[]` while closed; the field id is captured before the
  closing press (the model clears its target on close); the panel builds eagerly so key rects are
  laid out before any read.
- `osk_touch_audit.gd`: the hardcoded 52 -> computed 47+4; two settle frames before reading key
  rects; `root.size` re-asserted before the touch press (headless windows revert to 64×64 and
  touches outside the window rect never reach the GUI — probe evidence kept); stale theme note
  dropped.
- **Result**: `"$GODOT" --headless --path godot/ --script res://tests/ui/osk_touch_audit.gd`
  → exit 0, **PASS 177/177**, 0 `SCRIPT ERROR`; re-confirmed by the finalize sweep (32/32 green,
  tree digest `1256f5f1d7200437`).
- §9.1's theme blocker is closed (the theme parses; `padel_theme.tres` `f735bfce8ba67b2d`); §9.2's
  mount landed with the UIR-22 integration.
- **Closure fingerprints** (§2 carries the wave snapshot; these are current):
  `OskPanel.gd` 644 lines / 23723 B / `0bd8d7cf641feaea`,
  `osk_touch_audit.gd` 564 lines / 33427 B / `01695cfb2d108c66`.
- **Still owed (unchanged)**: the device/touch pass and the handheld exports (§5, `not_ported`).
