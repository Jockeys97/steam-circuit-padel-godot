# Evidence — input, controller navigation and accessibility port (slice S13, first tranche)

Slice S13 of [`docs/implementation/PLAN.md`](../../implementation/PLAN.md), first tranche: the input
surface — controller/focus navigation, remapping, the accessibility knobs — ported from the frozen
browser reference as **headless-testable Godot modules plus the reference's own audits ported**.
The ticket is [`docs/implementation/tickets/accessibility-locales-performance.md`](../../implementation/tickets/accessibility-locales-performance.md).

Run date: 2026-09-16, repo `steam-circuit-padel-pro`, reference frozen at git HEAD `2979588`.
Everything below was run from the repo root on this host; outputs are verbatim and the full logs are
on disk under `tools/input-port/out/`. Every Godot invocation is wrapped in
`flock -w 900 /tmp/padel-godot.lock` with a `timeout` inside, one engine at a time.

**This is a model, not a wiring.** No game screen reads these modules yet: the UI lane owns
`godot/src/ui/**` and the scene tree, and `godot/project.godot` / `godot/game/input_map.gd` are other
lanes' files and were not touched. What is proven here is that the reference's navigation rules hold
over the port's own data, and that the port's input map still carries what the reference wires.

## What exists

| Module | What it is | Reference it is a port of |
|---|---|---|
| `godot/src/input/focus_nav.gd` | focus model: what can take the focus, the geometric "next target in this direction", the movement report, container scrolling | `js/main.js:559-627,630-695` (`collectMenuTargets`, `findMenuTarget`, `moveMenuFocus`, `ensureMenuFocus`, `scrollContainer`, `scrollMenu`) |
| `godot/src/input/menu_nav.gd` | the context (screen / overlay / field / OSK), confirm, cancel, the pad's direction + repeat + stick scroll, the keyboard's arrow path | `js/main.js:551-557,692-733,931-999,2551-2569` |
| `godot/src/input/osk.gd` | the on-screen keyboard as data: 5 rows, shift, insert/delete with `maxLength`, the action row, open/close hand-off | `js/main.js:430-542` |
| `godot/src/input/scheme.gd` | the control scheme as data: 24 actions, per-action device coverage, help-label ids, source anchors; bindings are read from the live `InputMap`, never restated | `js/main.js:1006-1093`, `:789-930`, `GAMEPLAY_RULES.md:152-180` |
| `godot/src/input/remap.gd` | remap model: assign/clear with reasons (`empty_binding`, `unknown_action`, `unknown_slot`, `wrong_device`, `conflict` naming the owner, `reserved`, `coverage`, `nothing_to_clear`), conflict scope = one context | the scheme above, plus `js/main.js:756-758` for the context split |
| `godot/src/input/strings.gd` | the locale seam for input-facing strings: 63 ids — pad hints, OSK labels, the controller/keyboard legends, the navigation labels | `js/i18n.js` via `godot/src/locale/**` (consumed, not forked) |
| `godot/src/input/nav_routes.gd` | the reference's 13 screens, their **declared** returns, the `to-*` actions they carry, the `screens` registry, and all 17 `showScreen` call sites — generated, hash-pinned | `index.html`, `js/ui.js:444-458,595`, `js/main.js` |
| `godot/src/accessibility/accessibility_settings.gd` | the two toggles the reference has (`reduceMotion`, `colorblind`) with what they *do*, the absent settings, named controls, the keyboard policy | `index.html:412-421`, `js/ui.js:460-475`, `js/main.js:2214-2215,2300-2305,2376`, `js/fx.js:2-10,26,63`, `styles.css:2715-2728` |
| `tools/input-port/nav-routes.mjs` | extractor/verifier for `nav_routes.gd`: `node tools/input-port/nav-routes.mjs` prints the block, `--report` prints the numbers, `--verify` fails on one byte of drift | `scripts/reachability-audit.mjs`'s read-the-source approach |

## Commands, exit codes, key output lines

All four audits, one log, one verdict (the aggregate prints exactly one `PASS` line):

```sh
cd /root/projects/steam-circuit-padel-pro && \
flock -w 900 /tmp/padel-godot.lock timeout 600 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
  --script res://tests/input/run_all.gd > tools/input-port/out/run-all.log 2>&1; echo "exit=$?"
```
exit 0 — `# totals checks=308 failures=0 not-ported=7`, `PASS 4/4`.

Each audit on its own (`--script res://tests/input/<name>.gd`), exit codes and summaries:

| Command (`--script res://tests/input/…`) | exit | summary line | checks |
|---|---|---|---|
| `gamepad_nav_audit.gd` | 0 | `PASS 164/164` | 164 |
| `reachability_audit.gd` | 0 | `PASS 21/21` | 21 |
| `input_coverage_audit.gd` | 0 | `PASS 40/40` | 40 |
| `input_remap_a11y_audit.gd` | 0 | `PASS 83/83` | 83 |

Key measured lines from those logs:

```
# report focus targets=8 hints=63 pad-only=8                      (gamepad_nav)
# report screens=13 declared_returns=10 openers=17 markup_reachable=9/13   (reachability)
# report actions=24 keyboard=16 pad=23 pad_only=8 project_declared=18      (input_coverage)
# report a11y settings=2 absent=5 particle(100)=35 shake(2.5)=0.5          (input_remap_a11y)
# report audio files=1 input strings=63
# totals checks=308 failures=0 not-ported=7                        (run_all)
```

The inventory the coverage audit prints (26 lines, generated not typed — one per action, `--list-actions`
prints the same block alone):

```
# input-inventory padel_drive | context=gameplay | devices=keyboard,pad | keyboard=Space | pad=0 | remappable=yes | label=driveLbl | js/main.js:1013 …
# input-inventory padel_lob | context=gamepad… | devices=pad | keyboard=none | pad=3 | remappable=yes | label=lobLbl | js/main.js:1079 …
```

The harness, unchanged and still green:

```sh
flock -w 900 /tmp/padel-godot.lock timeout 120 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/
```
exit 0 — `PASS 8/8`.

The supporting gates:

```sh
node tools/input-port/nav-routes.mjs --verify
```
exit 0 — `nav-routes: ok godot/src/input/nav_routes.gd matches the reference (13 screens, 17 showScreen call sites)`

```sh
node tools/i18n-port/hud-coverage.mjs --fail-on-leak
```
exit 0 — `# ids the sim can emit: 108 — 108 get a readable line, 0 print the id (or contain it)`
(no new raw-id leak: this tranche touches no HUD path, and `input_remap_a11y` asserts every id it owns
resolves in both locales.)

```sh
node tools/i18n-port/verify-i18n-port.mjs
```
exit 0 — `OK — the port's locale data matches js/i18n.js byte for byte, … all 11 injected drifts were caught.`

The reference audits, run as the comparison (both exit 0):

```
node scripts/gamepad-nav-audit.mjs   → {"selettore":"button,input,textarea,select,summary","tagUsati":"button,input,textarea,summary","schermate":13,"aiuto":4,"campiDiTesto":3,"etichetteTastiera":6}
node scripts/reachability-audit.mjs  → {"azioni":15,"gestori":16,"schermate":13}
```

## Files (new; nothing tracked was modified)

`git status --porcelain -uall` shows no ` M ` entry at all: `js/**` and `scripts/**` are untouched,
`godot/project.godot` is untouched, and the `.uid` files Godot generated beside the new `src/` scripts
are the engine's, not hand-written.

| file | bytes | sha256 |
|---|---|---|
| Module (new) | | |

| `godot/src/input/focus_nav.gd` | 12 179 | `d1750932e7b55f6d64d3dc4c8c75f2bdf937fe5b111e5f0933acbe32e514e30e` |
| `godot/src/input/menu_nav.gd` | 14 256 | `bb5bf2070653fe971566aa4cd9de11a55aa751244b58156292bce470c91686c9` |
| `godot/src/input/osk.gd` | 6 707 | `ef135ae4789dbd4c4d88bd7dbca9ec527423e3bb9c3cdb8db920d14f30a11bc1` |
| `godot/src/input/remap.gd` | 10 350 | `44610137acb5220299a1d0cd75af03b6dfeac916ac68b38422cf5cc8908b270a` |
| `godot/src/input/scheme.gd` | 12 186 | `5e65e43faa1ed2bcbdc1c7afbfa2f70d7c39ca4823353b1be43bceed083d82be` |
| `godot/src/input/strings.gd` | 6 605 | `c1663c95b620a463edcc121dac6eb4fcc56ce1b465ab8216e2e8251a151b5d32` |
| `godot/src/input/nav_routes.gd` | 7 355 | `1b1fea2d92308b7200c440346e48de81003b8ac98847f2461166d193f2220c14` |
| `godot/src/accessibility/accessibility_settings.gd` | 8 517 | `6c6bfd0837a3c5533369810e27759e193a36610bf71f08d2ec76e91a2c1e6acb` |

| Test (new) | | |

| `godot/tests/input/gamepad_nav_audit.gd` | 36 307 | `94348f17c2dbd221c11f812673e899568328e91d02feabfb78c8f32ca6264014` |
| `godot/tests/input/reachability_audit.gd` | 9 810 | `af3bdcdac181cda725cb1d916cb1676d31053a774aa3fff4d62e027e3602aa5d` |
| `godot/tests/input/input_coverage_audit.gd` | 11 579 | `49626b7f992d1db9406d0c84b5f0426e4b2a2d79269130e2a0ce1db7c8782bf9` |
| `godot/tests/input/input_remap_a11y_audit.gd` | 17 683 | `bd87761d101a57dd5144faf8e4ffed150397828db3c747007797546c7527c904` |
| `godot/tests/input/run_all.gd` | 2 772 | `a70ad2033db2a60b1aaf5a09087d0dbfb37ce68bbab3e6deb7473733d0661321` |

| Tool (new) | | |

| `tools/input-port/nav-routes.mjs` | 9 417 | `47062bd3957f0bc37ab1bdfaa03d14bf3cf7368097926e7650f11ab52333eb79` |

| Run log (new, on disk) | | |

| `tools/input-port/out/run-all.log` | 24 165 | `fb5ff1692fd28fcede9342fb3261d57ef3bdc55a65b053590893947ee52ba4e6` |
| `tools/input-port/out/gamepad_nav_audit.log` | 8 229 | `d07bbe66970b5103b1698f5491ec967b200dff026f220dca808e2991f25917c4` |
| `tools/input-port/out/reachability_audit.log` | 2 274 | `44ffebdb90ccf3c1236e085805c19f4f05358ae40fbedf018a91ce851a7d5c98` |
| `tools/input-port/out/input_coverage_audit.log` | 7 855 | `a046c86970f7060e6daaf78b3901aded7a223cc8c239f18709e1fe9d5c5d961c` |
| `tools/input-port/out/input_remap_a11y_audit.log` | 5 452 | `3bfee87cb78298a9cac9a79fb83bbc3036054ea75c3b220afd5ef67c3c03328b` |
| `tools/input-port/out/harness.log` | 550 | `616d5f9d4c89c307de50182a506b138b353a8fd6abb5bfedab7738d733e9144b` |
| `tools/input-port/out/nav-routes-verify.log` | 106 | `0e8e2e7a97d299536301417918d7eede19e8c030f1cb8682ca00c14451dcf9ec` |
| `tools/input-port/out/nav-routes-report.json` | 778 | `a3ff3649bca264703831424a7b826a1f8bc50d693488279b93120b31aeab3703` |
| `tools/input-port/out/hud-coverage.log` | 162 | `3a3147837d3c333ebde1ebbab3a4248f0ae8e98e9410ba15ac055bc76d01cb61` |
| `tools/input-port/out/i18n-drift.log` | 1 274 | `7cece5bd90275a87183561b48f11625b0994eb8cd5a2e12e86c0bcb42c3967ae` |
| `tools/input-port/out/reference-gamepad-nav.log` | 266 | `ff1623882ec214d19fb28c06e8d63a2cc4b11cd4747ff082e405970244e64a53` |
| `tools/input-port/out/reference-reachability.log` | 55 | `ea72257a9d0d74841bfc6c9e36e527b911e349e799a600ec733e6c28e7943a1a` |

| Reference, read only (pinned) | | |

| `js/main.js` | 95 899 | `f4d24f7c0bad20971b70e31b86c2cd835b82bdc63134d5c2527109e3fdf25529` |
| `js/ui.js` | 73 322 | `3f439f378ebe6ac0bc332de91df4e811df756e02bba502fc1946cff218829405` |
| `js/i18n.js` | 67 726 | `a884267562d3aad30ea4d9634195a85cd727e421c7bd68bbb1cc3a9f6748ed30` |
| `index.html` | 49 575 | `c1060116462db0b96efe40a235262f1a804588375081bfaeb50d43b24058c13b` |

## Reference assertions ported

| Reference | Ported as |
|---|---|
| `gamepad-nav-audit.mjs:24-30` focus selector read from the source | `nav/every_interactive_kind_is_focusable` (kinds are data, not a selector) |
| `:32-46` every markup element kind is reachable by the focus | `nav/collect_keeps_only_what_the_focus_may_land_on` (+7 per-kind checks) |
| `:48-65` every screen declares its return (`data-back`) | `reach/ten_screens_declare_their_return`, `reach/only_the_root_the_field_and_the_result_declare_no_return` |
| `:67-82` the root declares none, and `menuBack` looks for the declared one | `nav/root_back_leads_nowhere`, `nav/the_declared_return_is_the_one_used`, `nav/legacy_fallback_*`, `reach/the_root_declares_no_return` |
| `:84-92` A/Cross confirms, B/Circle goes back | `nav/button_0_confirms*`, `nav/button_1_goes_back`, `nav/button_2_goes_back_too`, `coverage/confirm_has_a_pad_button`, `coverage/back_has_a_pad_button`, `coverage/dpad_{up,down,left,right}_reaches_ui_{…}` |
| `:93-102` the help strings promise the mapping that exists | `nav/pad_help_promises_b_circle_for_back_{it,en}`, `nav/pad_help_promises_a_confirm_{it,en}` (with the reference's own `pad(?:Hints3\|MenuHint)` scope) |
| `:105-133` a text field is filled with the pad: confirm opens the OSK, the keyboard becomes the focus context, back closes it | `nav/confirm_on_a_text_field_opens_the_keyboard_with_a_pad`, `nav/the_open_keyboard_becomes_the_focus_context`, `nav/back_closes_the_keyboard`, `nav/the_field_takes_the_focus_back` + 30 `osk/*` checks |
| `:136-144` the key labels exist in both languages (`n === 2`) | `nav/every_input_string_resolves_{it,en}`, `osk/action_keys_are_labelled_{it,en}`, `a11y/no_input_string_leaks_as_a_raw_id` |
| `:146-152` the focus skips hidden, disabled and undrawn | `nav/{hidden,disabled,not_drawn,locked_card}_is_skipped`, `nav/container_card_with_its_own_button_is_skipped` |
| `:155-176` a wide target is not skipped: transverse overlap beats centre distance, computed from the rect edges | `nav/wide_target_wins_over_a_closer_aligned_one`, `nav/overlap_is_computed_from_the_rect_edges` |
| `:179-206` read-only screens scroll; `moveMenuFocus` reports whether it moved; the right stick always scrolls; the arrows scroll where the focus cannot go | `nav/read_only_*`, `nav/move_reports_*`, `nav/the_right_stick_scrolls_*`, `nav/arrows_scroll_when_the_focus_cannot_move`, `nav/the_stick_scrolls_15_per_frame_*` |
| `reachability-audit.mjs:67-74` every screen is opened by some `showScreen` | `reach/every_screen_is_opened_by_some_showScreen` (13/13, 17 call sites) |
| `:76-80` code must not open a screen that does not exist | `reach/no_opener_names_a_screen_that_does_not_exist` |
| `:82-98` markup screens == registry keys, both ways | `reach/the_registry_and_the_markup_list_the_same_screens`, `reach/no_markup_screen_is_missing_from_the_registry`, `reach/the_registry_lists_no_screen_that_does_not_exist` |
| `:69` the eight-screen floor | `reach/the_eight_screen_floor_is_met` (13) |
| ticket `:108` "a pad-only action is a failure" | asserted as a **floor** (`coverage/every_pad_action_has_a_button_or_axis_in_the_live_map`) and the 8 pad-only actions reported — see the divergence below |

## Reference assertions that could not be ported (7 `# not-ported` lines, in the logs)

| Not ported | Why |
|---|---|
| `nav/focus_selector_is_read_from_the_sources` | there is no selector in the port; the equivalent is the descriptor-kind inventory |
| `nav/focus_skips_what_is_not_drawn_offsetParent` | `el.offsetParent !== null` is a DOM layout fact; the model takes a `drawn` flag and asserts the filter |
| `nav/scroll_positions_come_from_getComputedStyle` | `getComputedStyle(el).overflowY` + `scrollHeight/clientHeight` have no headless form; the model takes registered containers and asserts the same comparison |
| `nav/scrollIntoView_on_focus_move` | `scrollIntoView` is browser-only; it belongs to the UI lane's Control tree |
| `reach/markup_actions_have_handlers` | there is no markup and no event binding; asserted instead over the scheme + live `InputMap` |
| `reach/actions_generated_by_templates` | there is no template code; the equivalent reverse check is `coverage/project_declared_actions_match_the_scheme` |
| `coverage/every_action_binds_both_a_pad_button_and_a_keyboard_key` | the reference does not do it — see below |

Also not asserted, only reported with its number: markup-edge reachability from the root
(`9/13`, `# report`). A `showScreen("x")` inside a callback carries no static origin screen, so the
graph cannot be closed from the sources; the reference's own rule (every screen has an opener) is
asserted instead.

## Divergences found (numbers and anchors)

1. **The reference's menu-back defect is not fully fixed in the reference.** `menuBack` looks for the
   declared `[data-back]` *and then still falls back* to the first `[data-action^="to-"]`
   (`js/main.js:731`). The menu declares no `data-back` (`index.html:31-85`) and carries 8 `to-*`
   actions, the first being the top bar's `to-profile`, so in the browser as frozen, B/Circle on the
   main menu opens the Profile — going forward, which is the exact defect
   `scripts/gamepad-nav-audit.mjs:67-71` describes. The port refuses that path on the declared root
   (`nav/root_back_leads_nowhere`, `menu_nav.gd:back()`) and keeps the positional criterion as
   unreachable data (`nav/no_shipped_screen_falls_back_to_the_positional_criterion`, 10/10 screens
   declare a return). Note the fallback's *target* differs by data order: sorted, the port's copy
   gives `to-challenges` where the markup order gives `to-profile`.
2. **"Every action needs both devices" is not true of the reference.** 8 of 24 actions are pad-only:
   `padel_lob` (no keyboard branch exists, `js/main.js:1079`), `padel_split_step` (LT analog,
   `:792`), `padel_sprint` (RT analog, `:793`), `padel_technical` (RB, `:794`), and the four D-pad
   tactics (`GAMEPLAY_RULES.md:174-175`). Measured: keyboard 16, pad 23. The port asserts the
   reference's coverage as a floor and does not invent keys.
3. **The second back button has no `InputMap` action.** The reference fires back on `b(1) || b(2)`
   (`js/main.js:992`); the live map's `ui_cancel` carries button 1 only (and `ui_accept` button 0 and
   6). The model accepts both (`nav/button_2_goes_back_too`); the missing half is recorded in the
   coverage log for whoever owns `godot/project.godot`.
4. **RT is named two ways in the reference.** `index.html:252` labels it "Angolo"/"Angle"
   (`padSprintDesc`), `GAMEPLAY_RULES.md:169-171` calls it the analog sprint, `godot/project.godot`
   binds `padel_sprint` to it. Reported, not renamed.
5. **The audio layer mentions a motion word** — the one occurrence in `godot/src/audio/audio_port.gd:425`,
   a diagnostic `reduced_motion_affects_audio` read from the mixer contract (`event_map.json`
   `mixer.reducedMotion.affectsAudio: false`). `js/audio.js` has no such field. Asserted as: the audio
   layer does not import the accessibility module, the flag is false, and every occurrence is a
   false-valued diagnostic, with file:line in the log.
6. **The reference disagrees with itself on the reduced-motion default**: `index.html:414` marks
   `optReduceMotion` `checked` while `js/ui.js:471` defaults `ui.reduceMotion` to `false` and
   `js/main.js:2376` assigns the state onto the checkbox when the settings screen syncs. The port
   takes the state default and records the markup discrepancy.

## NOT-DONE

- **Not wired into the game.** These are models with narrow documented APIs; no screen, scene or
  Control tree calls them yet, and `godot/project.godot`'s `run/main_scene` is untouched. The UI lane
  consumes them (`menu_nav.gd`'s header lists the four calls a screen needs).
- **Touch and the on-screen keyboard remain postponed platform decisions** (`product-scope-and-platforms`,
  open, HITL). Only the OSK *model* exists; no grid, no layout, no input method, and nothing is
  dropped: `a11y/the_touch_and_osk_decision_is_named_as_postponed`.
- **No performance claim, and none is possible here.** This host renders through software GL
  (`llvmpipe`, no GPU), so it is valid for correctness and invalid for any frame-rate statement. The
  frame-time probe (`FrameTimeProbe.gd`, `tools/measure_performance.sh`) is the slice's next tranche;
  `input_remap_a11y_audit.gd` prints a `# note` saying so.
- **The accessibility knobs are the reference's two and no more.** No large text / font scale (there
  is no such control anywhere in the reference), no high contrast, no screen-reader API (Godot exposes
  no DOM: the port keeps named controls and a keyboard path and claims no screen-reader parity), no
  caption sizes, no input-assist options. All five are enumerated in `A11y.ABSENT` and printed as notes.
- **The audit for the locale *pair* is not this tranche's** (`i18n_audit.gd` is the locale seam's, and
  `verify-i18n-port.mjs` already guards it). What is asserted here is narrower: every input-facing id
  this tranche introduces resolves in both locales and none leaks as a raw id.
- **The `data-action` ↔ handler pairing is not reassembled.** The scheme declares 24 actions; nothing
  yet asserts that a *screen* offers an action for each one — that is the UI lane's router audit,
  which will consume `nav_routes.gd` and `scheme.gd` as the reference's expectation.

## Reproduce

```sh
cd /root/projects/steam-circuit-padel-pro
flock -w 900 /tmp/padel-godot.lock timeout 600 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
  --script res://tests/input/run_all.gd          # PASS 4/4, 308 checks
node tools/input-port/nav-routes.mjs --verify    # ok, 13 screens, 17 call sites
node tools/i18n-port/hud-coverage.mjs --fail-on-leak   # 0 leaks
```
