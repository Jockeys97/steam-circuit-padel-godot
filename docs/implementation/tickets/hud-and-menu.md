# In-match HUD and main menu in Godot Control nodes (slice S4)

- Status: open
- Type: task
- Mode: AFK
- Owner: unassigned
- Blocked by: [Quick-match vertical slice in 3D](quick-match-slice.md) technically — there is no match to draw a HUD over until it lands. The done verdict is blocked by [UI port approach](../../wayfinder/tickets/ui-port-approach.md) (open, owner Luca), which decides whether a Godot Control tree can carry this interface at all, and by [Product scope and platforms](../../wayfinder/tickets/product-scope-and-platforms.md) for whether the on-screen keyboard and touch are kept, postponed or dropped. The two screens may be built now; the slice may not be called complete.

This ticket implements row S4 of `docs/implementation/PLAN.md` ("In-match HUD and main menu in Godot Control nodes"). It does not change that plan, its slice numbering or its open-decision table, and it does not start S5 through S13.

## Objective

Rebuild the two screens the Godot port needs first — the main menu and the in-match HUD — as real Godot `Control` nodes, at the palette and legibility standard the web build already holds, and stop there for Luca's verdict. The web build has thirteen screens; this slice builds exactly two plus the router that will later hold the rest, and it proves the two by rendered captures and by a headless navigation run. It is deliberately stopped short of the other eleven screens, of the touch layer and of the on-screen keyboard, all of which are named rather than dropped.

The [Quick-match vertical slice in 3D](quick-match-slice.md) lane already builds a first `MainMenu` and a minimum `DebugHud` so the slice is playable. This ticket owns the screen router, the shared theme resource and the full HUD, and it takes over those two files at handoff: one writer at a time, and after the handoff the router is the only writer of the screen files.

## Existing source anchors

| Anchor | What it is |
|---|---|
| `index.html:31` | `screen-menu`, the main menu — the screen this slice rebuilds, with `data-i18n-aria` hooks |
| `index.html:441` | `screen-game`, the in-match screen — the second screen this slice rebuilds |
| `index.html:535` | `screen-result`, the result screen. Named because the HUD ends where it begins; it is not rebuilt here |
| `index.html:86, 99, 153, 177, 264, 277, 289, 306, 362, 395` | `screen-characters`, `screen-modes`, `screen-arena`, `screen-help`, `screen-history`, `screen-challenges`, `screen-profile`, `screen-feedback`, `screen-drill`, `screen-settings` — the eleven screens this slice does not build, listed so nothing is dropped silently |
| `styles.css:1` | `:root`, the palette custom properties the Godot theme resource must carry |
| `styles.css:44` | `.screen--active`, the visibility model the router's screen stack mirrors |
| `styles.css:499` | `#screen-game.screen--active`, the in-match layout rule |
| `js/ui.js:595` | `showScreen(name)`, the single navigation entry point. The Godot router is its equivalent, and `scripts/reachability-audit.mjs` reads it |
| `js/ui.js:1265` | `updateHud(state)`, the per-frame HUD update — the reference for every HUD element this slice draws |
| `js/ui.js:1477` | `showResult(state, winner)`, the result screen call the HUD's last frame leads into |
| `js/ui.js:837, 1116, 1209, 1375, 1422, 1563` | `renderAthletes`, `renderChallenges`, `renderArenas`, `renderMatchStats`, `renderObjectives`, `renderHistory` — the DOM renderers for the screens this slice does not build |
| `js/ui.js:737` | `applyDemoLimits()`, the demo filter applied to the two rebuilt screens; the rule itself is [Demo gate rule](../../wayfinder/tickets/demo-gate-preset.md)'s |
| `js/main.js:1218` | `updateHud(...)` called from the frame loop, once per rendered frame |
| `js/main.js:439-444` | The on-screen keyboard: `oskEl`, `oskGrid`, `oskTarget`, `oskShift`. Named, not built; its fate is [Product scope and platforms](../../wayfinder/tickets/product-scope-and-platforms.md)'s |
| `js/main.js:2301` | The `body.reduce-motion` class toggle, the DOM half of reduced motion |
| `styles.css:2715-2722` | The `body.reduce-motion` rules — reduced motion is a CSS class in the web build, and the Godot equivalent is a setting the theme and the effects layer read |
| `GAMEPLAY_RULES.md:142-150` | The player-feedback contract: the log explains valid serve, valid glass, second bounce, double fault and defensive shot; the score stays tennis; the ball animation must make height and bounce point obvious; a short grade label follows contact; a thin bar shows remaining rally energy |
| `scripts/reachability-audit.mjs:68-97` | The screen inventory and the two-way check: every `<section id="screen-…">` is opened by some `showScreen`, and the `screens` registry in `js/ui.js` matches the markup. `:28` requires more than five actions in the markup |
| `scripts/gamepad-nav-audit.mjs:51` | `sections.length >= 8` — at least eight screens must be present, so a Godot router that starts with two is not yet the audit's target |
| `scripts/gamepad-nav-audit.mjs:73-92` | The menu-back rule: `menuBack` must find the *declared* return target, not the first `data-action` on the screen, and the pad must confirm on the A/Cross button |
| `scripts/i18n-audit.mjs:29-34` | More than 200 keys, and the Italian and English key sets must be identical — every string on the two rebuilt screens is a key, not a literal |
| `godot/tests/smoke_test.gd`, `godot/tests/SmokeTest.tscn` | The machine-readable contract every Godot test in this port prints: `ok <name>`, `FAIL <name>: expected <x>, got <y>`, `PASS <n>/<n>` |
| `godot/prototypes/arena_spike/arena_playable_1280x720.png` | A real 1280x720 capture from the working render route, the precedent for this slice's captures |

The seam this slice sits next to: the window/locale contract lives in `godot/src/locale/**`, built by another lane. Every string this slice draws comes from that seam through the translation layer; the HUD holds message ids only, the same rule the simulation core holds. The locale seam has one owner and this ticket is not it.

## File ownership / allowlist

New files this ticket creates:

- `godot/src/ui/theme/padel_theme.tres` — the palette and type scale exported from `styles.css:1` `:root` values, one resource, no inline colours anywhere else
- `godot/src/ui/ScreenRouter.gd` — the screen stack, the equivalent of `js/ui.js:595` `showScreen`: exactly one screen active at a time, an explicit back target per screen, and a named signal on every transition
- `godot/src/ui/Hud.gd` and `godot/src/ui/Hud.tscn` — the in-match HUD: score, grades and intent, the energy bar, the point log, per `GAMEPLAY_RULES.md:142-150`
- `godot/src/ui/screens/MenuScreen.gd` and `godot/src/ui/screens/MenuScreen.tscn` — the main menu
- `godot/src/ui/screens/PlaceholderScreen.gd` — the shell the eleven unbuilt screens instantiate, so the router's inventory is real and reachable without any of them pretending to be finished. It carries the screen's name and a "not built in this slice" statement, and it is the only file the later slices replace
- `godot/src/ui/UiStrings.gd` — the thin adapter that asks `godot/src/locale/**` for a key and falls back to the key itself. It owns no dictionary
- `godot/tests/reachability_audit.gd` and `godot/tests/reachability_audit.tscn` — the ported reachability check over the router
- `godot/tests/ui_legibility_audit.gd` and `godot/tests/ui_legibility_audit.tscn` — the overflow and contrast checks the web build enforces visually
- `godot/tests/hud_audit.gd` and `godot/tests/hud_audit.tscn` — the HUD elements against a scripted match state
- `godot/tests/capture_ui.gd` — the capture harness for the two screens
- `godot/shots/ui-menu.png`, `godot/shots/ui-hud-rally.png`, `godot/shots/ui-hud-point.png` and `godot/shots/README.md` — the captures, appended to the file the quick-match slice started
- `docs/implementation/evidence/s4-*` — the evidence files listed below

Files this ticket takes over at handoff from [Quick-match vertical slice in 3D](quick-match-slice.md): `godot/src/ui/MainMenu.gd`, `godot/src/ui/MainMenu.tscn`, `godot/src/view/DebugHud.gd`. The handoff is explicit — the slice lane stops writing them, this lane resumes, and afterwards the adapter `godot/src/ui/UiStrings.gd` and the router are the only writers.

Must not be touched by this ticket: `js/` (any file), `scripts/` (any file), `index.html`, `styles.css` (read-only references for the palette), `docs/implementation/PLAN.md`, `docs/mission/`, `docs/wayfinder/`, `godot/src/sim/` (owned by [Sim core parity](sim-core-parity.md)), `godot/src/locale/**` (owned by the locale lane), `godot/src/audio/**` (owned by the audio lane), `godot/src/input/` (owned by [Quick-match vertical slice in 3D](quick-match-slice.md)), `godot/scenes/QuickMatch.tscn` beyond the HUD node it already expects, and `godot/prototypes/` (read-only).

## Inputs and outputs

Inputs:

- The match state the HUD reads, through [Quick-match vertical slice in 3D](quick-match-slice.md)'s view seam and never by reading the simulation's internals directly: score fields, the ordered point outcomes, the grade and intent of the last contact, the remaining rally energy, and the event list whose ids name valid serve, valid glass, second bounce, double fault and defensive shot.
- Message ids, never localized strings: `godot/src/locale/**` resolves them, `godot/src/ui/UiStrings.gd` is the only caller, and the HUD holds ids the way `godot/src/sim/sim.gd` stores them.
- The palette and type scale from `styles.css:1` `:root`, exported once into `padel_theme.tres`.
- The framing verdict from [Camera and feel spike](../../wayfinder/tickets/camera-and-feel-spike.md) is not an input: the HUD is drawn in screen space above whatever camera the slice uses, so a camera change does not force a HUD change.

Outputs:

- `res://scenes/QuickMatch.tscn` driven from a real menu: the menu opens the match, the match is exitable back to the menu, and the router is the only thing that changes screens.
- A HUD that shows, on the built screens only: the tennis score, the last grade and intent, the remaining-energy bar under the active player, and a point log with the five named messages.
- Two rendered 1280x720 captures of the built screens and two of the HUD in play.
- A headless run that walks every registered screen through the router and reports `PASS n/n`.
- The eleven unbuilt screens present as placeholder shells behind real doors, so the router's inventory is complete and `reachability` has something true to check.

Explicitly not output: the other eleven screens' real content, the on-screen keyboard, touch input, the demo lock UI beyond the two screens, audio cues, and any accessibility-setting screen. Those belong to later slices and each needs its own ticket.

## Tests

The web audits that bear on this slice, by real file name under `scripts/`:

- `scripts/reachability-audit.mjs` — the primary shape. Its two claims are ported: every registered screen is reachable, and nothing in the registry is dead (`:68-97`). The ported `reachability_audit.gd` asserts the same over the Godot router, with the screen inventory read from the router rather than from markup.
- `scripts/gamepad-nav-audit.mjs` — its `sections.length >= 8` floor (`:51`) is not yet met by a two-screen slice and is recorded, not asserted; the two checks that do apply are ported now: every menu action is bound to a named input action, and back is a declared target rather than "the first action on the screen" (`:73-92`).
- `scripts/i18n-audit.mjs` — the key-set claims (`:29-34`) are the locale seam's; this slice's contribution is that no view script contains a literal user-facing string, which the headless run checks by asserting every drawn string resolves through `UiStrings.gd`.
- `scripts/assets-audit.mjs` — the Godot equivalent is load-time: the headless run fails to load if a resource path in the two screens does not resolve.
- `scripts/modules-audit.mjs` and `scripts/module-contract-audit.mjs` do not port literally; the replacement stays the headless load with zero script errors.

Godot-side equivalents, keeping the original name stem:

- `godot/tests/reachability_audit.gd` — walks every registered screen and every declared back target, asserts one active screen at a time, asserts no screen is unreachable and none is dead, prints one `ok`/`FAIL` per check and a `PASS n/n` summary.
- `godot/tests/hud_audit.gd` — drives a scripted match through the HUD and asserts the score line, the grade and intent, the energy bar value and the five named log messages, all from ids.
- `godot/tests/ui_legibility_audit.gd` — asserts no `Control` in either screen overflows its container at 1280x720, at 1920x1080 and at 1024x600, and that every text node's fore/background pair meets the web build's contrast standard. The three sizes are chosen because the web build's layout is tuned for a 960-wide canvas inside a wider window (`js/render.js:740-745`).
- `godot/tests/capture_ui.gd` — renders the two screens and writes the captures.

## Execution commands

Pinned binary `/root/tools/godot/Godot_v4.7.2-stable_linux.x86_64` (4.7.2.stable.official, `ed1daf0bf`). Godot is the heavy process on this host; every invocation is wrapped in the shared lock. `timeout` is the CI bound, not `--quit-after` — a runtime error that aborts `_ready()` hangs the loop instead of going red, and `--quit-after` exits 0 on an aborted run.

Headless UI checks:

```sh
cd /root/projects/steam-circuit-padel-pro && for a in reachability_audit hud_audit ui_legibility_audit; do \
  flock -w 900 /tmp/padel-godot.lock \
  env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 timeout 300 \
    /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
    res://tests/${a}.tscn > docs/implementation/evidence/s4-${a//_/-}.log 2>&1; \
  echo "$a exit=$?"; grep -E '^(FAIL|PASS)' docs/implementation/evidence/s4-${a//_/-}.log; \
done
```

Rendered captures under software GL — `--headless` installs a dummy driver and a viewport capture under it is blank, so the working route is `xvfb-run` plus an explicit rendering driver, exactly as the prototype render scripts do:

```sh
cd /root/projects/steam-circuit-padel-pro && \
  flock -w 900 /tmp/padel-godot.lock \
  env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 timeout 300 xvfb-run -a \
    /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path godot/ --rendering-driver opengl3 \
    res://tests/capture_ui.tscn -- --shot=menu,hud-rally,hud-point \
    > docs/implementation/evidence/s4-capture.log 2>&1; echo "exit=$?"
```

Harness smoke and the project-load check:

```sh
cd /root/projects/steam-circuit-padel-pro && \
  flock -w 900 /tmp/padel-godot.lock \
  env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 timeout 120 \
    /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/; echo "exit=$?"
```

Web control, which must not change:

```sh
cd /root/projects/steam-circuit-padel-pro && npm run audit \
  > docs/implementation/evidence/s4-web-baseline.log 2>&1; echo "exit=$?"
```

Manual review, for the human verdict — the two screens with a real window:

```sh
cd /root/projects/steam-circuit-padel-pro && \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path godot/ \
    res://scenes/QuickMatch.tscn
```

## Expected evidence

- `docs/implementation/evidence/s4-reachability-audit.log`, `s4-hud-audit.log`, `s4-ui-legibility-audit.log` — each with its own exit code and its `PASS`/`FAIL` summary line.
- `docs/implementation/evidence/s4-capture.log` — the capture run, its exit code and the list of PNG paths written.
- `godot/shots/ui-menu.png`, `godot/shots/ui-hud-rally.png`, `godot/shots/ui-hud-point.png` — 1280x720 captures of the two built screens and two in-play HUD moments.
- `godot/shots/README.md` — extended, not replaced: which preset, which scale and which capture is software GL.
- `docs/implementation/evidence/s4-web-baseline.log` — the untouched web suite at `27/27 audit passano`, exit 0.
- `docs/implementation/evidence/s4-screen-inventory.md` — the two screens built, the eleven present as placeholder shells with the ticket or decision that will fill each, and the note that the on-screen keyboard and touch are postponed rather than dropped, pending [Product scope and platforms](../../wayfinder/tickets/product-scope-and-platforms.md).
- `docs/implementation/evidence/s4-ui-notes.md` — the theme's palette source lines, the type scale, the three window sizes the legibility audit checks, and the list of what the HUD does not yet show.

What does not count as proof: a screenshot without its capture log and exit code; a claim that a screen is reachable without the headless run that walks it; a HUD string compared as text rather than as a resolved id; and any claim about the eleven unbuilt screens, which are placeholder shells by construction.

## Failure and recovery criteria

Red means any of these:

- Any of the three headless runs exits non-zero, or hangs and `timeout` kills it (exit 124).
- The project loads with a script error, or a screen scene fails to instantiate.
- A view script contains a user-facing literal instead of resolving a key through `godot/src/ui/UiStrings.gd`.
- A screen is unreachable, or a second screen is active at the same time, or a back target is "the first action found on the screen" rather than a declared target.
- A `Control` overflows its container at any of the three checked window sizes.
- The slice re-implements a scoring or feedback rule in the HUD instead of reading it from the simulation's state and event ids.
- A file outside the allowlist changes, `js/` or `scripts/` changes at all, or the HUD reads `godot/src/locale/**` or `godot/src/sim/**` internals directly instead of through their published seams.
- The slice resolves a camera, arena or roster question by drawing around it.

What stops the slice: a red run after the retry rule below; a UI-approach verdict that rejects a Godot Control tree, in which case the slice is re-scoped rather than patched around; or the locale seam not yet publishing a lookup, in which case `UiStrings.gd` falls back to the key and the blocker is recorded against the locale lane rather than worked around with literals.

Retry rule: two attempts per failing gate, then a blocker with the failing check, the log line and both attempts. No identical third retry; unrelated unblocked work continues.

Recovery paths worth trying before declaring a blocker: confirm the capture run uses `xvfb-run` with an explicit rendering driver rather than `--headless`, because the dummy driver renders blank; confirm the router clears the previous screen before adding the next; confirm the legibility audit's three sizes include the 960-wide inner canvas the web layout is tuned to (`js/render.js:740-745`); confirm the HUD reads the energy value from the state field rather than recomputing it.

## Human gates that block this slice (open, owner Luca)

- **UI port approach** — whether a Godot `Control` tree can carry this interface without losing readable type, semantic colour and no overflow. This ticket builds the two screens and stops; the other eleven are not rebuilt on this ticket's authority, and no completion claim is made before the verdict.
- **Product scope and platforms** — the fate of the on-screen keyboard (`js/main.js:439-444`) and touch input. This ticket names both and postpones them to a stated later slice; it does not decide, and nothing is dropped silently.
