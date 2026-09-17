# Execution log

## Initial dispatch
User requested implementation of all tickets through org-simulation. Plan implementation approved by that request. Visual approach, platform scope and final acceptance are not presumed approved. Existing README and BOARD remain the execution map.

Native configured delegation selected. No per-call model identity override is available. Additional paid API budget is $0. Two leaf captains will execute independent foundation and reference work. Foundation captain is the integrator and sole Godot process owner during this wave. Reference captain must not run Godot or edit shared board files. Both return exact evidence handles and observed model identity if available. Parent verifies returned artifacts before promotion to the prototype wave.

## Foundation wave — UIR-00, UIR-03, UIR-04, UIR-05 (2026-09-16/17, native macOS)

Foundation captain executed all four tickets in dependency order, on one engine process at
a time, with the pre-existing play window (PID 94690) left running — every suite below
stayed green with it up, which is itself evidence for the concurrency rule.

- **UIR-00** — baseline frozen at `252ff60`: harness 8/8, game slice 292/292 (full) and
  243/243 (demo), modes 6/6 (3603 checks), saves 137/137, input 4/4 (308 checks), audits
  10/10, music 32/32; 0 SCRIPT ERRORs. Historical deviations recorded, not repaired:
  slice 292 vs 280 and demo 243 vs 229 (the pack addition from `42aafa5`), and music
  32/32 confirms the provenance repair. Evidence: `uir-00-baseline-gates.log`,
  `uir-00-before-set.md` (20 captures registered with hashes).
- **UIR-03** — `ScreenRouter.gd` (13 ids, own `back` column, frozen against
  `nav_routes.gd`, literal-scan guarded), `screens/ScreenContract.gd`, `UiStrings.gd`,
  `ScreenShell.gd`/`.tscn`, `PlaceholderScreen.gd`/`.tscn`, `tests/ui/router_audit.gd`.
  `PASS 86/86`, reachability 21/21 still green. Evidence: `uir-03-router-audit.log`.
- **UIR-04** — `data/UiData.gd`, `data/DemoGateAdapter.gd`, `data/UiArtPaths.gd`,
  `tests/ui/data_audit.gd`: `PASS 131/131` full, `PASS 134/134` demo. Findings: the save
  contract's `null` defaults broke `String(null)` and are now coerced in one place; the
  reference's third build label (`beta`) does not exist in the port (UIR-23); arena art
  names are UIR-01's and two are still missing. Evidence: `uir-04-adapters-audit.log`.
- **UIR-05** — `focus/UiFocusBridge.gd`, `accessibility/UiMotionPolicy.gd`,
  `tests/ui/input_a11y_audit.gd`: `PASS 117/117`, 4 not-ported (drawn OSK grid, touch,
  IME, stepwise key repeat), input suite still 4/4. Findings: `focus_nav.set_focus()` is
  permissive and answers "did it change" (locked targets read as success); `screen-modes`
  declares only its own return; `game`/`result` are flow-entered, not edge-reachable.
  Evidence: `uir-05-input-a11y-audit.log`.

Approval fields set to `plan_approved: true` and `state: done` for exactly these four
tickets. Gate-a, the platform/touch decision (UIR-26) and the final aesthetic verdict
(`luca-final`) remain untouched and unclaimed, as does everything from UIR-07 onward.

Native effective identity: not observable from inside this session's tools (no
per-call model override, no identity surface returned by the harness); nothing is
fabricated in its place.


## Menu wave — UIR-01, UIR-02, UIR-06 verification + UIR-07 (2026-09-17, native macOS)

Integrator dispatch: review the seven implemented foundation tickets independently, fix
genuine foundation defects inside their own scopes, run the pending engine verification,
then implement the menu prototype. One engine at a time — because the checkout already has
a live play window (PID 94690, up since 2026-09-16, left untouched), every engine run of
this wave happened in a byte-identical isolated copy of the working tree
(`/tmp/padel-uir-wave2-20260917/repo`, `rsync -a` excluding `/.git` and `/godot/.godot`,
manifest diff empty before the runs). The checkout collected no `.godot/`, `.import` or
`.uid` artifact from this wave.

- **UIR-01** — verification ran: import clean, `fonts_assets_probe` `PASS 75/75`. The key
  art the menu's poster needs resolves on the engine path. Appendix in `uir-01-assets.md`.
- **UIR-02** — verification ran, and the probe carried three real defects, all fixed in
  scope: the grid never assigned the theme to a node (bands read 31 px engine defaults),
  the segmented chip's 42 px is a CSS *height* the probe had to declare the screen-side
  way (bands unchanged, measured 52/42), and the three-column grid overflowed 1024x600.
  `theme_probe` `FAIL 239/248` -> `PASS 254/254`; static validator `PASS 25/25`. Three
  palette colours needed by the menu (`nav_bg`, `caption_shadow`, `poster_fade`, each from
  its own reference line) added to `padel_theme.tres` + README §3, with the theme README §7
  follow-up naming the variation set the menu's composed chrome should become. Appendix in
  `uir-02-theme-probe.log`.
- **UIR-06** — verified through the theme: every value it measured is asserted by UIR-02's
  probe (254/254) and by the validator's README-hex check (25/25). A fresh browser capture
  was not re-run (frozen reference; browser work outside this wave). Its three
  never-tokenised colours are now palette rows.
- **UIR-07** — `MenuScreen.gd` + `.tscn` (the reference's front page, all eight `to-*`
  actions through the router, every string through `UiStrings`, badge through
  `DemoGateAdapter`, the hero-title `clamp(2.4rem, 5vw, 4rem)` and the poster's 16:9
  re-derived from the frame) and `tests/ui/screen_menu_audit.gd` + `.tscn`:
  `PASS 95/95` full, `PASS 96/96` `--demo`, 0 SCRIPT ERRORs in both (the one deliberate
  engine ERROR — the router's refusal check — is named by the audit's own note). The
  UI-lane literal scan now reads 12 files with 0 offenders. Deviations recorded in
  `uir-07-screen-menu.log`: the theme palette rows, `DemoGateAdapter.badge_text_key_for()`
  (UIR-04 scope, for the reference's beta branch), and the two viewport rules that live in
  the screen because a theme holds absolute sizes (README §6.5/§6.9). `ui-menu.png` pending
  UIR-24's harness.

No foundation audit was trusted: re-run, all reproduced — router 86/86, adapters 131/131 +
134/134, input/a11y 117/117, reachability 21/21. The full baseline (harness 8/8, slice
292/292, slice demo 243/243, input 4/4, audits 10/10, modes 6/6, save 137/137, music 32/32)
was re-run **after** the menu landed and stayed green with the play window up.

Approval fields set to `plan_approved: true` and `state: done` for exactly UIR-01, UIR-02,
UIR-06 and UIR-07. `gate-a`, the platform/touch decision (UIR-26), `luca-final` and every
post-gate-a ticket remain untouched and unclaimed; UIR-08 stays with its own child (HUD
lane, no engine runs) and was not edited here.

Native effective identity: the previous batch reported `deepseek-flash`; no per-call
provider override is claimed by this wave, and nothing was fabricated in its place.

## HUD + mount wave — UIR-08 fixes, UIR-09 mount, UIR-24 harness (2026-09-17, native macOS)

Integration owner, real checkout `steam-circuit-padel-godot` at
`252ff6074039372ebbf8ec682f9adda0e9c80d03` (working tree; nothing committed). Sole engine
runner: every run below was serial and preceded by a `pgrep -x Godot` check; the owner's
play window was not running during this wave and was never killed.

**Engine failures fixed (UIR-08's lane, real checkout only).** The parent's verification
log (`/tmp/uir-parent-hud-verification.log`) had shown exit 0 with 3 SCRIPT ERRORs: a
duplicate `MINIMAP_HEADER` constant (`Hud.gd:116`) and fonts whose `.import` sidecars
existed only in the isolated copy. Both fixed at the root (constant removed; sidecars
created by `--import` in this checkout), plus the four findings the wave-3 reviewer
reported (timing window, AI score colour, actions-row geometry) and one real integration
bug the reviewer did not reach: the numeric locale parameter crash
(`UiStrings.t()` now stringifies numbers before `Locale.t`, because GDScript has no
`String(int)` and the frozen locale module fails on a non-String `{n}` — the adapter is
the correct fix site; `src/{sim,save,locale,modes}` untouched).

**HUD audit: PASS 151/151** (was 140/150 with 3 SCRIPT ERRORs), 0 SCRIPT ERROR lines:
cards are `PanelContainer`s that grow to their content (a bare `Panel` keeps the offsets'
rectangle and an autowrapping Label's minimum height explodes through an unanchored
margin), markers are named (`AimNeedle`/`TimingWindow`/`TimingNeedle`), the serve label is
`ServeLabel`, and the audit's own `_spilling` is visibility-aware.

**UIR-09 mount landed** (`--ui=new`, additive): the recreated menu through UIR-03's router
in `main_menu.gd`, the recreated HUD in `match_controller.gd`'s own layer, both fed the
same state+meta. Evidence, before/after pairs and the honest frame read are in
`evidence/uir-09-prototype-mount.md`; the captures are real GPU frames
(`OpenGL API 4.1 Metal … Apple M4`) at 1280x720 and 1152x648, seed 20260916, tier 3,
camera default, 0 SCRIPT ERRORs on every run. The ported HUD's before-frames were restored
byte-identical from the registered set (sha256 re-checked against `uir-00-before-set.md`:
all five menu/HUD files match).

**UIR-24 harness implemented** (`tests/ui/capture_ui.gd/.tscn` + `ui_legibility_audit.gd`):
`PASS 5/5` walking the router and capturing one PNG per registered screen and declared
state (`ui-menu{,-demo,-beta}.png`, colours 64-70 — non-vacuous read-back), and the
legibility audit runs at the four sizes with contrast floors. Two real defects the new
audit caught are fixed in this wave: the training/tournament strip no longer collides with
the scoreboard (its top now rides the card's real bottom, `_score_panel.resized`), and the
`drill` capture state no longer shows a serve banner (a drill serves nothing).

**Open findings, recorded not hidden.** (1) The menu caption leaves its poster frame by
9 px at 1024x600 — `MenuScreen`, UIR-07's file, outside this wave's write allowlist; the
audit therefore exits 1 on that one finding (73/76; the other three sizes are clean).
(2) `game_slice_test.gd`'s object ceiling: the demo slice measured `delta=459` against its
`<= 450` ceiling because the prototype scenes were preloaded unconditionally — fixed by
loading them only under `--ui=new`; both slices now run leaner than their recorded
baselines (365/387 vs 395). (3) The ported `modes` screen keeps its own capture lane and
reads the same `--capture=` argument, so the harness checks the UIR-03 contract off-tree
and reports it pending rather than mounting it (an earlier build mounted it and its lane
quit the run from below).

**Suite sweep, final code, serial** — harness 8/8, slice 292/292, slice demo 243/243,
input 4/4, rules 10/10, modes 6/6, save+Steam 137/137, music 32/32, `hud_audit` 151/151,
`ui_legibility_audit` 73/76 — **0 SCRIPT ERROR lines in every suite**.

**Not done, on purpose:** no commit, no push, no deletion; GATE-A is untouched (no
look/feel verdict is claimed anywhere; the frame notes are a description); platform/touch
(UIR-26) and every post-gate-a ticket stay unclaimed; `BOARD.md` rows were left to the
coordinator.

## Pre-gate-a closeout — menu caption, HUD review reconciled, suites, captures (2026-09-17, native macOS)

**The menu caption's recorded defect is closed (UIR-07's open finding).** The fixed 378 px
caption box left the poster by 9 px once the hero column narrowed to 391 px at 1024x600
(three states, `uir-24-legibility.log`). `MenuScreen._apply_caption_fit()` now re-derives the
width from the poster itself on every poster resize and on `enter()`, capped at the design
378 px, so the design value is a ceiling, not a constant. `ui_legibility_audit` is
`PASS 76/76` (was `FAIL 73/76`; the same 76 checks, the three flipped and nothing else —
`evidence/uir-pre-gate-a-legibility.log`).

**A second, unrecorded caption defect was found while measuring the first, and is also
closed.** The reference pins the *text block* to `bottom: 18px` over a content-sized box; the
port's 92 px box had the text top-aligned, so the rendered glyphs sat 52 px above the poster's
bottom edge where the reference's sit 24 px (measured by colour mask on
`reference-captures/menu.png`: glyph bottom y=522, poster border rows 544/545). One line in
`MenuScreen.tscn` (`Caption` VBox `alignment = 2`) puts it at 25 px — 1 px off the reference —
and `screen_menu_audit` now asserts containment, both declared insets, the poster-vs-column
width assumption the wave-3 review flagged as unasserted, and the text-bottom-hug at both
sizes (`97/97`, `98/98 --demo`).

**The wave-3 HUD review is reconciled finding by finding, in source and in tests**
(`evidence/uir-pre-gate-a-closeout.md` §3 has the table). The review's own claim that the HUD
audit had never been executed is now false: it runs `PASS 172/172` with 0 SCRIPT ERRORs. Its
two named blind spots are exactly what the new checks read — the *rendered* timing-window
anchors in the live rally frame and in both capture states (the window is pinned at 52 %,
never centred on the needle), and the `combo_glow`/`tactic_flash` flags (now rendered through
theme-owned values: palette `combo_glow`, the `SegmentedFlash` and `TimerBall` variations,
both documented in `theme/README.md` §3/§4/§5). The timer's 38x38 ball exists now too. The
findings the review listed as already-fixed-in-source (window pin, AI coral, the row's
134.52/8 geometry, the duplicate `MINIMAP_HEADER`) were re-read in source and each is now
guarded by an assertion rather than trusted. The audit's first run of this wave printed
`PASS 158/158` beside one `SCRIPT ERROR` (a `Label`-typed read of the `ComboLabel` *button*,
which silently dropped 14 checks) — fixed and re-run as `172/172`, recorded because a PASS
next to a SCRIPT ERROR is how a suite lies.

**One stale red in the router audit was a false positive, fixed as a precision defect.** The
check `ui_strings_owns_no_table` matched a *function-local* dict added to `UiStrings.gd`
(`:36`) after the last router run and read `FAIL 85/86`; it now scans top-level declarations
only — a top-level table still fails it (`86/86`).

**Full sweep on the frozen tree, serial, one engine at a time:** menu 97/97 + 98/98, HUD
172/172, legibility 76/76, router 86/86, theme 271/271, fonts 75/75, data 131/131 + 134/134,
input/a11y 117/117, reachability 21/21, and UIR-00's eight baseline commands unchanged and
identical (harness 8/8, slice 292/292, slice demo 243/243, input 4/4, rules 10/10, modes 6/6,
save+Steam 137/137, music 32/32) — **19 runs, every exit code 0, 0 SCRIPT ERROR lines in
every run** (`evidence/uir-pre-gate-a-suite.log`). `ui_legibility_audit`'s closing report
line was also fixed: it printed hardcoded `screens=0 hud_states=0` next to a 76-check PASS;
it now counts what it walks (`sizes=4 screens=4 hud_states=18`).

**Captures regenerated for real** (11 runs, exit 0, 0 SCRIPT ERRORs): the menu harness at
1152x648 / 1024x600 / 1280x720, the UIR-09 prototype lane at 1280x720, and the match/HUD lane
at 1152x648 / 1024x600 / 1280x720 — the pre-wave set was copied to `/tmp/uir-pregate/prior/`
first; `ui-menu.png` `1f0e32d3…` -> `b99f1cc7…`, the 1024x600 overflow proof is the
before-log + the after-log + the real frame `ui-menu-1024x600.png`
(`evidence/uir-pre-gate-a-captures.log`). The four plan-lane files the match lane had to
rewrite to derive the `ui-*` frames are UIR-00's frozen before-set: they were restored
byte-identical afterwards and re-verified against the register's full sha256 (all MATCH).

**Not done, on purpose:** no commit, no push, no merge (the coordinator checkpoints in the
next single-owner wave); no deletion (before-set preserved outside the tree); GATE-A
untouched — no look/feel verdict is claimed anywhere, this wave's frame notes are
measurements; the brother branch's `match_controller`/HUD timing cues are not merged here;
`BOARD.md`'s ticket rows are again left to the coordinator (the wave paragraph records what
each flip now has behind it).
