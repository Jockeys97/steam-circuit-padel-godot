# Feature coverage matrix

Every screen, state and cross-cutting feature of the frozen reference traced to exactly one owning ticket, its acceptance command and its evidence path. Overlaid features (OSK, touch) point at their blocked ticket by name; nothing is dropped.

Command shorthand used in the table (all run on this Mac, serialized, one engine at a time):

- `heads <script>` means `"$GODOT" --headless --path godot/ --script res://tests/<script>; echo "exit=$?"`
- `capture` means `"$GODOT" --rendering-driver opengl3 --path godot res://tests/ui/capture_ui.tscn -- --capture=<id|all> --seed=20260916 --tier=3` (never `--headless`: the dummy driver captures blank frames)
- every command's exit code and tally line must land in the ticket's evidence log; `PASS` next to a `SCRIPT ERROR` is a failure.

Evidence root: `docs/implementation/ui-recreation/evidence/`. Capture root: `godot/game/out/`.

## 1. Screens and their states

| Screen | State | Reference anchor | Ticket | Acceptance command | Evidence |
|---|---|---|---|---|---|
| menu | default | `index.html:31-87` | UIR-07 | `heads ui/screen_menu_audit.gd` | `uir-07-screen-menu.log` + `ui-menu.png` |
| menu | demo/beta badge | `index.html:77-80`, `js/ui.js:737-747` | UIR-07 + UIR-23 | `heads ui/screen_menu_audit.gd -- --demo` | `uir-23-demo-matrix.md` |
| menu | language toggle (IT/EN) | `index.html:43`, `js/main.js:2421` | UIR-07 | same as default (language assertions inside) | `uir-07-screen-menu.log` |
| menu | six hero actions | `index.html:59-66` | UIR-07 | same as default | `uir-07-screen-menu.log` |
| menu | top nav profile/settings | `index.html:40-44` | UIR-07 | same as default | `uir-07-screen-menu.log` |
| characters | resolved 4-slot lineup | `index.html:90-100`, `js/ui.js:548` | UIR-11 | `heads ui/screen_characters_audit.gd` | `uir-11-screen-characters.log` |
| characters | athlete picker open | `js/ui.js:846-1124` | UIR-11 | same | `uir-11-screen-characters.log` |
| characters | outfit picker | `index.html:90-100`, `js/ui.js:609-669` | UIR-11 | same | `uir-11-screen-characters.log` |
| characters | locked athlete/outfit | `js/ui.js:670-702`, `styles.css:1280-1293` | UIR-11 | same (+ `-- --demo`) | `uir-11-screen-characters.log` |
| characters | triple-tap unlock code | `js/ui.js:703-736` | UIR-11 | same | `uir-11-screen-characters.log` |
| characters | demo-excluded stays locked | `js/ui.js:713`, gate | UIR-11 + UIR-23 | `heads ui/screen_characters_audit.gd -- --demo` | `uir-23-demo-matrix.md` |
| modes | three mode cards | `index.html:111-131` | UIR-10 | `heads ui/screen_modes_audit.gd` | `uir-10-screen-modes.log` |
| modes | difficulty segmented | `index.html:135-140` | UIR-10 | same | `uir-10-screen-modes.log` |
| modes | match-length segmented (6) | `index.html:144-151`, `js/data.js:689-698` | UIR-10 | same | `uir-10-screen-modes.log` |
| modes | career tag + fixture | `index.html:128-129` | UIR-10 | same | `uir-10-screen-modes.log` |
| modes | demo locks (quick only, medium pinned) | `js/ui.js:737-770` | UIR-10 + UIR-23 | `heads ui/screen_modes_audit.gd -- --demo` | `uir-23-demo-matrix.md` |
| arena | nine-arena grid | `index.html:165`, `js/ui.js:1220` | UIR-12 | `heads ui/screen_arena_audit.gd` | `uir-12-screen-arena.log` |
| arena | career calendar state | `js/ui.js:500-530` | UIR-12 | same | `uir-12-screen-arena.log` |
| arena | tournament bracket wording | `js/ui.js:505-530` | UIR-12 | same | `uir-12-screen-arena.log` |
| arena | locked/demo arenas dimmed | `styles.css:1280-1293` | UIR-12 + UIR-23 | `heads ui/screen_arena_audit.gd -- --demo` | `uir-23-demo-matrix.md` |
| arena | player-mode panel (solo/coop/pvp) | `index.html:166-177` | UIR-12 | `heads ui/screen_arena_audit.gd` | `uir-12-screen-arena.log` |
| help | eight help cards | `index.html:191-222` | UIR-13 | `heads ui/screen_help_audit.gd` | `uir-13-screen-help.log` |
| help | keyboard tab (default) | `index.html:230-240` | UIR-13 | same | `uir-13-screen-help.log` |
| help | controller tab + 13-row legend | `index.html:242-262` | UIR-13 | same | `uir-13-screen-help.log` |
| help | narrow layouts (860/560) | `styles.css:2775, :2785` | UIR-13 | same (1024x600 assertion) | `uir-13-screen-help.log` |
| history | empty state | `js/ui.js:1574` | UIR-14 | `heads ui/screen_history_audit.gd` | `uir-14-screen-history.log` |
| history | populated + summary + 20 cap | `index.html:276-277` | UIR-14 | same | `uir-14-screen-history.log` |
| challenges | three sections + counts | `index.html:289`, `js/ui.js:1125` | UIR-15 | `heads ui/screen_challenges_audit.gd` | `uir-15-screen-challenges.log` |
| challenges | done/medal styling | `styles.css` challenges block | UIR-15 | same | `uir-15-screen-challenges.log` |
| challenges | career-limitation note (limited builds) | `js/ui.js:1125+` | UIR-15 + UIR-23 | same (+ `-- --demo`) | `uir-23-demo-matrix.md` |
| profile | stats row | `index.html:301` | UIR-16 | `heads ui/screen_profile_audit.gd` | `uir-16-screen-profile.log` |
| profile | season objectives + done state | `index.html:302-303` | UIR-16 | same | `uir-16-screen-profile.log` |
| profile | unlock summary + route | `index.html:304-305` | UIR-16 | same | `uir-16-screen-profile.log` |
| profile | empty objectives state | `js/ui.js:1608+` | UIR-16 | same | `uir-16-screen-profile.log` |
| feedback | six topics | `index.html:321-328` | UIR-17 | `heads ui/screen_feedback_audit.gd` | `uir-17-screen-feedback.log` |
| feedback | counter 0/1200 + cap | `index.html:332-335` | UIR-17 | same | `uir-17-screen-feedback.log` |
| feedback | diagnostics disclosure | `index.html:346-349`, `js/ui.js:270` | UIR-17 | same | `uir-17-screen-feedback.log` |
| feedback | queue-first submit + sent state | `js/ui.js:316-385` | UIR-17 | same | `uir-17-screen-feedback.log` |
| feedback | failure ladder (mail/copy/manual, no fake delivery) | `js/ui.js:387-404` | UIR-17 | same | `uir-17-screen-feedback.log` |
| feedback | Steam button hidden when null | `index.html:353` | UIR-17 | same | `uir-17-screen-feedback.log` |
| feedback | OSK model entry (gamepad) | `js/main.js:484-573`, `osk.gd` | UIR-17 (model) + UIR-26 (visual, blocked-external) | same | `uir-17-screen-feedback.log` |
| drill | four exercises | `index.html:374-379`, `js/drill.js:53-71` | UIR-18 | `heads ui/screen_drill_audit.gd` | `uir-18-screen-drill.log` |
| drill | independent difficulty | `index.html:380-385` | UIR-18 | same | `uir-18-screen-drill.log` |
| drill | metric boxes per exercise | `index.html:386-391`, `js/drill.js:475` | UIR-18 | same | `uir-18-screen-drill.log` |
| drill | records display | `js/ui.js:206-243` | UIR-18 | same | `uir-18-screen-drill.log` |
| drill | start -> existing session route | `js/main.js:1681`, `mode_screen.gd:280` | UIR-18 | same | `uir-18-screen-drill.log` |
| drill | in-match drill HUD metrics | `js/drill.js:475`, session fields | UIR-18 (data) + UIR-22 (restyle) | `heads modes/run_all.gd` + UIR-22 sweep | `uir-22-integration.md` |
| settings | language seg | `index.html:410-413` | UIR-19 | `heads ui/screen_settings_audit.gd` | `uir-19-screen-settings.log` |
| settings | reduce motion | `index.html:417-420`, `accessibility_settings.gd` | UIR-19 | same | `uir-19-screen-settings.log` |
| settings | colorblind | `index.html:421-424` | UIR-19 | same | `uir-19-screen-settings.log` |
| settings | volume 0-1 step .01 | `index.html:428-431` | UIR-19 | same | `uir-19-screen-settings.log` |
| settings | deadzone .08-.30 step .01 | `index.html:432-435` | UIR-19 | same | `uir-19-screen-settings.log` |
| settings | vibration | `index.html:436-439` | UIR-19 | same | `uir-19-screen-settings.log` |
| game | scoreboard (names, scores, VS) | `index.html:447-453` | UIR-08 | `heads ui/hud_audit.gd` | `uir-08-hud-audit.log` |
| game | match info + active-player 5 branches | `index.html:455-456`, `js/ui.js:1288-1299` | UIR-08 | same | `uir-08-hud-audit.log` |
| game | team tactic + split-step/sprint | `index.html:457`, `js/ui.js:1300-1312` | UIR-08 | same | `uir-08-hud-audit.log` |
| game | combo + color ladder | `index.html:458`, `js/ui.js:1330-1335` | UIR-08 | same | `uir-08-hud-audit.log` |
| game | timer MM:SS | `index.html:462-465` | UIR-08 | same | `uir-08-hud-audit.log` |
| game | panel / mute / gamepad indicator / pause buttons | `index.html:466-471` | UIR-08 | same | `uir-08-hud-audit.log` |
| game | serve banner (4 states) | `index.html:477`, `js/ui.js:1358-1366` | UIR-08 | same | `uir-08-hud-audit.log` |
| game | mini-map | `index.html:478-481` | UIR-08 | same | `uir-08-hud-audit.log` |
| game | action deck | `index.html:482-486`, `styles.css:2058-2064` | UIR-26 (blocked-external; hidden on desktop pointer, which is the reference's own desktop presentation) | n/a until decision | `uir-26-osk-touch.md` |
| game | touch controls | `index.html:487-495`, `styles.css:2070` | UIR-26 (blocked-external) | n/a until decision | `uir-26-osk-touch.md` |
| game | immersive panel default + toggle | `index.html:498-528` | UIR-08 | `heads ui/hud_audit.gd` | `uir-08-hud-audit.log` |
| game | special meter + cooldown opacity | `index.html:514-517`, `js/ui.js:1341-1343` | UIR-08 | same | `uir-08-hud-audit.log` |
| game | shot meter (intent/advice/power/aim/timing) | `index.html:518-527`, `js/ui.js:1344-1357` | UIR-08 | same | `uir-08-hud-audit.log` |
| game | event log collapsed default | `index.html:530-535`, `styles.css:1059-1072` | UIR-08 | same | `uir-08-hud-audit.log` |
| game | pause overlay (3 tabs) | `index.html:566-640` | UIR-20 | `heads ui/pause_audit.gd` | `uir-20-overlays.log` |
| game | quit 2-step (ESCI -> CONFERMI?) | `js/main.js:1615-1628`, `js/i18n.js:51` | UIR-20 | same | `uir-20-overlays.log` |
| game | controller tab (control mode, deadzone, sticks, vibration, volume) | `index.html:588-613` | UIR-20 (+ UIR-19 rows, UIR-05 stick bindings) | same | `uir-20-overlays.log` |
| game | controls tab + smash tutorial link | `index.html:615-640` | UIR-20 (+ UIR-13 legend) | same | `uir-20-overlays.log` |
| game | smash tutorial (steps, stick guide, readiness, try) | `index.html:642-685` | UIR-20 | same | `uir-20-overlays.log` |
| game | ESC hierarchy (5 steps) | scout T09 list; `js/main.js` handlers | UIR-20 | same | `uir-20-overlays.log` |
| game | replay overlay (banner, exit hint, progress) | `js/main.js:1362`, `:1243-1324` | UIR-27 (buffer + overlay; button wired by UIR-20) | `heads ui/replay_audit.gd` | `uir-27-replay.log` |
| result | win/loss title+message | `index.html:542-543` | UIR-21 | `heads ui/screen_result_audit.gd` | `uir-21-screen-result.log` |
| result | score formats (points / 6-4 / sets) | `js/ui.js:1488+` | UIR-21 | same | `uir-21-screen-result.log` |
| result | stats table + better-value marking | `index.html:548`, `js/ui.js:1374-1412` | UIR-21 | same | `uir-21-screen-result.log` |
| result | objectives + outfit unlock announcement | `index.html:549`, `js/ui.js:1433` | UIR-21 | same | `uir-21-screen-result.log` |
| result | career outcomes (promotion/trophy/repeat/final) | `js/ui.js:772-805` | UIR-21 | same | `uir-21-screen-result.log` |
| result | tournament next / tournament win | `js/main.js` result wiring | UIR-21 | same | `uir-21-screen-result.log` |
| result | rematch -> next match while pending | `js/main.js` `pendingContinue` | UIR-21 | same | `uir-21-screen-result.log` |
| result | demo/beta CTA (hidden when null; wishlist vs follow) | `index.html:550-557`, `js/main.js:2392-2420` | UIR-21 + UIR-23 | same (+ matrix run) | `uir-23-demo-matrix.md` |

## 2. Cross-cutting features

| Feature | Reference anchor | Ticket | Acceptance | Evidence |
|---|---|---|---|---|
| Screen router, one active screen | `js/ui.js:595-607` | UIR-03 | `heads ui/router_audit.gd` | `uir-03-router-audit.log` |
| Route graph + declared back targets | `nav_routes.gd` | UIR-03 (+ input suite stays green) | `heads ui/router_audit.gd` + `heads input/run_all.gd` | `uir-03-router-audit.log` |
| Theme (palette + type + components) | `styles.css:1-13` | UIR-02 | `heads ui/theme_probe.gd` | `uir-02-theme-probe.log` |
| Fonts (Lilita One, Nunito 400/600/700/800) | `index.html:11-16` | UIR-01 | `--import` + load probe | `uir-01-assets.md` |
| UI images (key art, controllers, modes, previews) | markup + styles `url()` | UIR-01 | `--import` + load probe | `uir-01-assets.md` |
| Locale through one seam (no literals) | `js/i18n.js`, `js/main.js:2421` | UIR-03/UIR-04 + every screen's audit | per-screen audits | per-screen logs |
| Demo/beta gate (roster, arenas, modes, difficulty, badge, CTA copy) | `js/build.js:55-112` | UIR-04 + UIR-23 | `heads ui/demo_matrix_audit.gd` (+ `-- --demo`) | `uir-23-demo-matrix.md` |
| Keyboard + pad navigation, focus, locked controls | `scripts/gamepad-nav-audit.mjs` | UIR-05 | `heads ui/input_a11y_audit.gd` | `uir-05-input-a11y-audit.log` |
| Reduce motion + colorblind behavior | `styles.css:2748-2762`, `accessibility_settings.gd` | UIR-19 + UIR-05 (policy) | `heads ui/screen_settings_audit.gd` | `uir-19-screen-settings.log` |
| Responsive breakpoint states | `styles.css:1970, 2003, 2033, 2058, 2064, 2070, 2775, 2785, 2936, 3245, 3299, 3436, 3577` | UIR-24 (legibility at 4 sizes) + per-screen narrow assertions | `heads ui/ui_legibility_audit.gd` | `uir-24-legibility.log` |
| Safe-area contract (no overflow/overlap) | slice assertions `game_slice_test.gd:1796-1811` | UIR-08 + UIR-22 | slice + HUD audits | `uir-22-integration.md` |
| Captures at 1280x720 + narrow | pack requirement | UIR-24 (namespace) + UIR-09 (prototype) | `capture` | `uir-24-capture.log` |
| Pause seam (no `SceneTree.paused`) | `match_controller.gd:1080-1113` | UIR-22 (creates) + UIR-20 (consumes) | `heads ui/pause_audit.gd` + slice | `uir-22-integration.md` |
| Replay (buffer + overlay + `r` key) | `js/main.js:1243-1324, :1362, :2532` | UIR-27 | `heads ui/replay_audit.gd` | `uir-27-replay.log` |
| OSK visual grid | `index.html:700-708`, `js/main.js:484-573` | UIR-26 (blocked-external: product scope) | n/a until decision | `uir-26-osk-touch.md` |
| Touch controls + action deck (coarse pointer) | `index.html:482-495`, `styles.css:2058-2070` | UIR-26 (blocked-external) | n/a until decision | `uir-26-osk-touch.md` |
| Display scaling with window size | handoff item 5; `project.godot` today has no `[display]` | UIR-22 | four-size legibility + slice fit | `uir-22-integration.md` |
| Dev text removal from player surfaces | `main_menu.gd:110, :405, :412`; `hud.gd:315, :334, :402` | UIR-22 (with UIR-07/UIR-08 replacing the surfaces) | slice + captures | `uir-22-integration.md` |
| `--pink` / computed pixels / font metrics | `styles.css:473` + unknowns | UIR-06 | browser session (documented) | `uir-06-computed-styles.md/.json` |
| Before/after capture pairs + verdict | handoff | UIR-25 (HITL; phase A under plan-approval + gate-a, closes on luca-final; UIR-26 disposition cited) | full sweep + capture set | `uir-25-final.md` |

## 3. Traceability rules

- A row is done when its acceptance command ran with a recorded exit code and tally, and the evidence file exists at the named path. A PNG without its log is not evidence; a claim without a command is not a claim.
- Rows pointing at UIR-26 carry the product-scope gate explicitly; they are not "postponed by default", they are blocked on a named human decision with a ticket ready to build. If the decision excludes touch/OSK, UIR-25 cites the decision verbatim and the final verdict covers the 13 screens and desktop input only, saying so; a silent omission is not an accepted state.
- The demo/beta rows point at UIR-23 regardless of which screen owns the pixel, because the matrix is proven per build in one place.
- When a screen ticket lands a state not listed here, the coordinator adds the row; when the reference's line anchors move (they will not; the web reference is frozen), the packet's citation style is `file:line` against the frozen commit `2979588` reference used by the port's generators, and against the working tree for files this pack verified on 2026-09-16.
