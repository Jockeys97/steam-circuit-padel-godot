# Match-setup parity rules, and the pace feature's one clock seam

Date: 2026-09-19 · Repo `steam-circuit-padel-godot`, worktree `luca-game-mechanics`, HEAD
`9ea56e53ac1e325b0ebc22ece7f409645e4b1a9c` (branch `luca-game-mechanics`).

**Method, in one line.** Static read only: `grep`, `awk` line-numbered reads and `git
status`. No engine run (another worker owns the engine for the whole of this run), no test
executed, no `gdlint`, no edit to any source file. Every figure below is either a citation
of a line that exists or arithmetic over cited numbers; §6 says which is which.

**Why this exists.** A third control group (`PaceGroup`) is being placed inside the port's
`Frame/ScreenScroll/Body/SetupArea/MatchSetup` next to `DifficultyGroup` and `LengthGroup`.
The placement has to obey the *reference's* rules where the reference has any, and be
declared as a port addition where it does not. This file establishes both sides: §2–§3 are
the reference's rules and silences, §4 is the static proof that the pace feature reaches the
simulation at exactly one place.

---

## 1. What was read

| Surface | Lines read |
|---|---|
| `index.html` | 10-20, 103-215 (the modes section and the neighbouring characters section) |
| `styles.css` | 39-44, 2129-2203, 2204-2256, 2355-2400, 2775-2790, 3291-3303 |
| `js/main.js` | 1150-1200, 1640-1660, 2198-2245, 2265-2285, 2328-2331, 2455-2480, 2535-2560 |
| `js/ui.js` | 285-290, 432-433, 465-480, 700-765, 1531-1550 |
| `js/build.js` | 1-90 (build detection, `IS_DEMO`, `BUILD_CONTENT`) |
| `js/game.js` | 582-600, 2988-2998 — only to identify two `pace` false positives (§4.3) |
| `godot/src/ui/screens/ModesScreen.gd` + `.tscn` | whole files (935 and 127 lines) |
| `godot/game/match_controller.gd` | 100-130, 179-215, 319-355, 419-470, 1000-1180, 1495-1535, 1625-1665, 1895-1930 |
| `godot/game/match_config.gd` | 37-90, 160-200, 420-422 |
| `godot/game/content_gate.gd`, `godot/src/ui/data/DemoGateAdapter.gd` | whole files |
| `godot/src/ui/data/UiData.gd` | 455-477 |
| `godot/src/sim/pace.gd` | whole file (143 lines) |
| `godot/src/save/save_schema.gd` | 130-160 |
| `godot/tests/build/DemoContent.gd`, `ContentFilter.gd`, `demo_content.json` | whole files |
| `godot/tests/ui/screen_modes_audit.gd` | 560-641 (the capture-state and bridge sections) |
| `godot/tests/pace_presets_test.gd`, `godot/_probe_pace_clock.gd` | call sites only (grep) |
| `docs/wayfinder/evidence/game-pace-presets.md` | whole file |

---

## 2. The reference's rules for `#matchSetup`

### 2.1 The region holds exactly two groups

`index.html:132` opens `<div class="match-setup" id="matchSetup">` and `index.html:153` closes
it (`index.html:132-153`). Between those lines there are exactly two children, both
`.setup-group`:

- difficulty — `index.html:133-141`: a `.setup-group__label` and `.segmented#difficultySeg`
  (`:135-140`) with four buttons whose `data-value` are `easy`/`medium`/`hard`/`legend`
  (`index.html:136-139`);
- length — `index.html:142-152`: a label and `.segmented#lengthSeg` (`:144-151`) with six
  buttons (`points11`, `points21`, `games3`, `games5`, `set`, `match2`; `index.html:145-150`).

No third child of any kind. `grep -rn "matchSetup\|match-setup" js/ index.html` returns only
two hits: `js/main.js:1652` (the getter inside `syncMatchSetup`) and `index.html:132` (the
element). The nearest neighbour of the same shape — a segmented with a
`.setup-group__label` and a `.setup-group__hint` — is `.player-mode-panel#playerModeSetup`
(`index.html:166-177`), and it lives on a **different screen** (`#screen-characters`), not
inside `#matchSetup`. So the reference's own precedent for "a setup-shaped control that is
not part of match setup" is: put it on another screen, not in this container.

The port mirrors the element verbatim: `ModesScreen.tscn:83-127` — `MatchSetup`, then
`DifficultyGroup` (label, `DifficultySegmentedBox`, `DifficultySegmented` with `columns = 4`)
and `LengthGroup` (label, `LengthSegmentedBox`, `LengthSegmented` with `columns = 3`).

### 2.2 The show/hide rule — written, and rendered

The written rule, `js/main.js:1651-1657`:

```
1651  function syncMatchSetup() {
1652    const setup = document.getElementById("matchSetup");
1653    if (!setup) return;
1654    setup.hidden = ui.selectedMode !== "quick";
1655    if (ui.selectedMode === "tournament") setup.hidden = true;
1656    if (playerModeSetup) playerModeSetup.hidden = ui.selectedMode !== "quick";
1657  }
```

Three facts about it:

1. It hides the **whole container**, not a group. Line 1655 is redundant (a tournament mode
   is already `!== "quick"`); it expresses no second rule. `playerModeSetup` on :1656 is the
   characters-screen panel, not part of match setup.
2. It is called from exactly two places: `js/main.js:2205-2207` (the `to-modes` action, before
   `showScreen("modes")`) and `js/main.js:2234-2237` (the `selectMode` action, which then
   routes to `characters`). It is not a per-frame sync.
3. It reads `ui.selectedMode`, which is restored from prefs at load (`js/main.js:2265`), so a
   player who stored `career` arrives on the modes screen with a non-quick selection.

**The rendered fact, which contradicts the written one.** `.match-setup` is `display: grid`
(`styles.css:2129-2140`). Author CSS beats the UA stylesheet's `[hidden] { display: none }`,
and `styles.css` carries twelve `[hidden]` guards —
`grep -n "\[hidden\]" styles.css` → lines 62, 729, 1068, 1432, 1481, 1644, 1749, 2359, 2686,
3483, 3614, 3634 (count `12`, and `grep -n "match-setup\[" styles.css` is empty) — of which
**`.player-mode-panel[hidden]` (`styles.css:2359-2361`) is one and `.match-setup[hidden]` is
not**. There is no inline style on the element (`index.html:132`),
no `style.display` write anywhere (`grep` above returns only the two hits), and the only
stylesheet is `styles.css` (`index.html:17`; :11-16 are Google Fonts). So in the frozen
reference, `js/main.js:1654-1655` sets an attribute that **does not take visual effect**: the
setup block keeps rendering with a non-quick mode selected, while the `playerModeSetup` line
on :1656 does hide its panel.

Consequence for the audit: the reference supplies a *stated* rule ("quick only") and a
*different* rendered behaviour ("always visible"). The port implements the stated rule:
`setup_visible()` (`ModesScreen.gd:733-734`) returns `_mode_now() == "quick"`, `_mode_now()`
(`:737-739`) reads the pending-mode seam with `"quick"` as the fallback, and `_apply_layout()`
writes it onto the container (`:808-810`). `godot/tests/ui/screen_modes_audit.gd:593-596`
asserts that both directions, and `:602` asserts the cards are never touched. Recorded as an
open parity question for the owning lane (§7), not as a placement question: **a third group
inherits the container's visibility and must not carry a show/hide rule of its own** — neither
the reference nor the port has one at group level.

### 2.3 What a demo build limits

The demo's content table, `js/build.js:56-64`: `athletes: ["maestro","steamer"]`,
`arenas: ["clockwork"]`, `modes: ["quick"]`, `difficulty: "medium"`, `outfitChallenges: true`;
`IS_DEMO = BUILD !== "full"` (`js/build.js:42`). The beta's table (`js/build.js:78-85`) is the
same except three arenas and `difficulty: null` ("no lock").

`applyDemoLimits` (`js/ui.js:737-765`) does four things:

| Effect | Line |
|---|---|
| `document.body.classList.add("is-demo")` | `js/ui.js:739` |
| badge text + `hidden = false` | `js/ui.js:742-745` |
| mode cards not in `DEMO_CONTENT.modes` → `mode-card--locked mode-card--demo`, tag → `demoLockedMode` | `js/ui.js:746-754` |
| `ui.selectedMode = DEMO_CONTENT.modes[0]` | `js/ui.js:755` |
| `ui.aiDifficulty = DEMO_CONTENT.difficulty` and every **`#difficultySeg button`** whose `data-value` differs gets `disabled = true` | `js/ui.js:756-764` |

What the demo does **not** touch: `#matchSetup` visibility, `#lengthSeg` (neither disabled nor
hidden), and any other control. The demo's difficulty lock is a *named selector*, not a
mechanism: `document.querySelectorAll("#difficultySeg button")` at `js/ui.js:762`. There is no
generic "a control this build does not grant is locked" helper reaching inside `#matchSetup`;
the generic demo rules (`demoFilter`, `demoLocked`, `js/build.js:58-75`) act on athletes and
arenas, and `applyDemoLimits` handles the mode cards by hand.

Port mirror, for the placement's benefit:

- `godot/game/content_gate.gd:38` (`DIFFICULTY_TIERS`), `:103-104` (`modes()`), `:110-111`
  (`locked_key()` → `demoLockedMode`), `:115-116` (`fixed_tier_index()`, `-1` in a full build);
- `godot/src/ui/data/DemoGateAdapter.gd:84-85` (`mode_locked`), `:90-95`
  (`difficulty_allowed`);
- `ModesScreen.gd:502-507` (`pinned_rung()`), `:510-512` (`difficulty_allowed`), `:715-728`
  (`_refresh_selection()` — it writes `disabled` for difficulty buttons at :721 and writes
  **no** disabled state for length buttons at :723-728, matching the reference);
- the demo table itself is generated, not typed: `godot/tests/build/demo_content.json`
  (`modes: ["quick"]`, `difficulty: "medium"`, `arenas: ["clockwork"]`), read by
  `DemoContent.gd`.

So: a demo limit on a *pace* rung would have no reference basis at all. `DEMO_CONTENT` is
athletes/arenas/modes/difficulty (`js/build.js:56-64`); the only difficulty-shaped lock is the
`#difficultySeg button` line. If the port wants a demo to pin a pace rung it is inventing a
rule, and it must say so — and it would need a new gate question, not a reuse of
`difficulty_allowed` (different table, different consumer).

### 2.4 Both controls in the region are quick-scoped *in effect*

This is the fact that most constrains the placement, and it is not written anywhere in the
region itself — it is written at the two consumption sites:

- **difficulty**, `js/ui.js:1540-1549` `getAiForMatch(mode, round, difficulty)`: the rung is
  honoured only under `if (mode === "quick")` (`:1541-1543`); career returns
  `careerAiProfile(...)` (`:1545-1546`) and everything else returns `AI_OPPONENTS[round]`
  (`:1548`). Called with `ui.selectedMode` at `js/main.js:1155`.
- **length**, `js/main.js:1185-1189`: `Object.assign(matchState, MATCH_FORMATS[ui.matchLength]
  ?? MATCH_FORMATS.points11)` sits inside `if (ui.selectedMode === "quick")`; career sets its
  own `scoring`/`pointsToWin` (`:1190-1199`).

Both presses write the value and the prefs **regardless of mode** — `js/main.js:2541-2547`
(difficulty), `:2549-2555` (length), both `savePrefs(collectPrefs())`, with the values carried
at `js/ui.js:432-433` and validated on load at `js/main.js:2276-2277` — they are simply never
consumed outside quick.

The pace preset in the port is the opposite shape: it is read at match start for **every**
mode — `godot/game/match_controller.gd:448` (`_adopt_session()`, the mode-session path) and
`:1012` (the quick/career/tournament start) — so it applies to drills, tournament and career
alike. Placing an all-modes setting inside a region whose stated rule is "quick only" is
coherent only if the reviewer accepts that the region now hides a control that still has
effect (in tournament/career) or that the region's rule is wrong (see §2.2). It is not a
parity violation — the reference has no pace — but it is the decisive semantic argument the
placement has to answer, and it is stronger than the layout argument.

Note also that the port's *own* difficulty is not quick-scoped: `Config.tier()` is read at
match start (`match_config.gd:420-422`, consumed at `match_controller.gd:347/470`), and there
is a second tier selector in `godot/game/main_menu.gd:196/707/760`. So the port has already
drifted from the reference here; "the port already does it globally" is true but is not
evidence that the reference scopes it that way.

### 2.5 Layout: the container, the breakpoint, and what a third cell would do

Reference numbers (all from `styles.css`):

| Rule | Value | Line |
|---|---|---|
| `.match-setup` | `display: grid`, `grid-template-columns: repeat(2, minmax(0, 1fr))` | 2129-2131 |
| | `align-items: start` | 2135 |
| | `gap: 18px` | 2136 |
| | `width: min(760px, 100%)` | 2137 |
| | `margin: 26px auto 0` | 2138 |
| | `padding: 0 24px` | 2139 |
| `.match-setup .setup-group` | flex column, `gap: 12px`, `padding: 15px 17px 17px`, 1 px cyan-alpha border, radius 14 | 2150-2162 |
| `.segmented` | `grid-auto-flow: column`, `grid-auto-columns: minmax(0, 1fr)`, `gap: 4px`, `padding: 5px` | 2207-2217 |
| `.segmented button` | `height: 42px`, `padding: 0 6px`, `font: 900 0.68rem` | 2219-2236 |
| `#lengthSeg` | the one control that wraps: `grid-auto-flow: row`, `repeat(3, minmax(0, 1fr))` | 3294-3297 |
| `@media (max-width: 860px)` | `.match-setup { grid-template-columns: 1fr }` | 2775-2782 |

**The container has exactly two cells.** A third `.setup-group` in the reference does not make
a three-across row; the grid is two columns, so the third child flows onto a second row (a 2×2
block with one empty cell), and below 860 px all three stack. The reference therefore contains
**no expression of a three-across setup row** to comply with or violate. The reference's own
recorded experience of squeezing this control (`styles.css:2204-2206`) is the opposite
direction: with three fixed columns the four difficulty rungs broke, and "Leggenda cadeva a
capo da sola" — the fix was to size the columns from the buttons
(`grid-auto-flow: column` + `grid-auto-columns: minmax(0,1fr)`).

Port numbers:

- `MatchSetup` is an **`HBoxContainer`** with `separation = 18` (`ModesScreen.tscn:83-85`);
  both children carry `size_flags_horizontal = 3` (`:87-90`, `:108-110`). A third child
  becomes a third equal third — structurally the port *tolerates* it, but by a container the
  reference does not have.
- `SetupArea` reproduces the reference's width rule: `side = max(0, (size.x - 760) / 2) + 24`
  written to `margin_left`/`margin_right` (`ModesScreen.gd:811-815`), `margin_top 26` /
  `margin_bottom 48` (`ModesScreen.tscn:76-81`). At the project's 1280×720 viewport
  (`godot/project.godot:159-160`) the setup content box is therefore **712 px**, which is
  exactly the reference's inner width (760 − 2×24).
- Arithmetic over those cited numbers (**inferred, not measured**): two groups → 347 px each;
  three groups → (712 − 2×18) / 3 = **225.3 px** each, a 35 % shrink, leaving ≈ 191 px inside
  each group's 17 px padding for a four-cell segmented row. The reference's own comment
  (2204-2206) is the evidence that this is the region where the four-rung row breaks first.
- The port has **no narrow-width rule for `MatchSetup`**: `_apply_layout()`
  (`ModesScreen.gd:803-815`) switches only `ModeGrid.columns` (at `GRID_BREAKPOINT = 1050`,
  `:119`/`:806`) and re-applies the `SetupArea` margins. The setup row is an `HBoxContainer`
  at every width, and `ScreenScroll` has `horizontal_scroll_mode = 0`
  (`ModesScreen.tscn:29`). A Godot container cannot shrink a child below its minimum size, so
  a row that does not fit clips at the edge rather than stacking or scrolling (**inferred** —
  needs one engine measure, §7).
- Chrome is applied from a **hard-coded two-name list**: `_style_chrome()` iterates
  `["DifficultyGroup", "LengthGroup"]` (`ModesScreen.gd:863-866`) and stamps `_setup_box(theme)`
  (`:901-916`) on each. A third `PanelContainer` gets **no frame** unless that list grows or
  the scene carries its own `StyleBox`; there is no theme variation for this box (the comment
  at `:901-905` records it as a theme request).
- **Height is not content-height.** The reference pins `align-items: start` with its own
  comment (`styles.css:2132-2135`) precisely so a one-row group is not stretched to the height
  of the two-row length group. The port has no equivalent: `HBoxContainer` gives every child
  the container's height, so the two existing groups are already forced level, and a group
  whose own content is taller (a five-rung, one-per-row stack is five 42 px buttons plus gaps,
  ≈250 px) sets the height of the whole row and stretches the other two. Recorded as a
  divergence the third group makes visible; not something the reference can adjudicate.

### 2.6 Port-side, machine-checked constraints a third group must satisfy

These are not reference rules; they are the port's own gates — two of them are asserted by a
suite that will go red if the new group is wired the way the existing two are:

- **Focusable count.** `godot/tests/ui/screen_modes_audit.gd:616` asserts exactly **14**
  focusables, and `:629` asserts the bridge reads 14 controls. The screen registers Back (1),
  the three cards, four rungs and six formats (`ModesScreen.gd:767-783`). Five pace rungs that
  register focus specs, in the pattern the other groups use (`:778-783`), take this to 19 and
  turn both checks red. That has to be a deliberate, owned decision (the audit is the record of
  the screen's shape), never a silent side effect.
- **Aria slots.** `ARIA_SLOTS` (`ModesScreen.gd:108-112`) names `DifficultySegmented` and
  `LengthSegmented`; `aria_names()`/`_refresh_aria()` (`:676-697`) walk it.
- **No literals.** `godot/tests/ui/router_audit.gd:398-420` fails any string literal
  containing a space in `godot/src/ui/**` (rule stated at `:420`, whitelist at `:69`). The pace
  strings already live in the owning module (`godot/src/sim/pace.gd:58-85`), which is the same
  rule that keeps `godot/src/locale/locale_data.gd` untouched.
- **Read-back.** The value the screen would show already exists:
  `UiData.settings_snapshot()` returns `"pace_preset"` (`UiData.gd:475`) from the same prefs
  group the length segment reads (`:472`), and the write path the neighbours use is
  `ModesSave.save_pref(store, key, value)` (`ModesScreen.gd:524/539`;
  `godot/src/modes/modes_save.gd:204-212`).

---

## 3. What the reference does NOT say

Stated explicitly, because the placement question is mostly a question about silence:

- **There is no pace control in the reference.** `index.html:132-153` holds two groups; the
  segmented ids in the whole document are `#difficultySeg` and `#lengthSeg` (`:135`, `:144`); `grep -rniw "pace"
  js/*.js index.html` returns four hits, all inside `js/game.js` and all unrelated (§4.3); `grep
  -rn "pace\|speedScale\|timeScale" js/ui.js js/main.js js/data.js` has no hit for a time-rate
  setting.
- **There is no pace preference.** The reference's prefs defaults
  (`js/ui.js:465-480`) and its load-time validation (`js/main.js:2273-2282`) carry `aiDifficulty`
  and `matchLength` and nothing about tempo. The port's key is a declared port addition:
  `godot/src/save/save_schema.gd:141-144` (`"pacePreset": Pace.DEFAULT_ID`, with the
  "PORT ADDITION, no reference line" comment).
- The reference therefore cannot adjudicate: **whether** a pace control belongs in
  `#matchSetup`; its **order** among the groups; whether a **demo** pins or locks it; and the
  **three-across layout** (its container never has three cells, §2.5).
- What the reference *does* constrain, by the shape of what it puts there: the region holds
  per-match settings that are persisted to prefs and consumed at match start (difficulty
  `js/ui.js:1541-1543`, length `js/main.js:1185-1189`), the region is quick-only by its stated
  rule (§2.2), and a demo's limitations come from a generated table applied by *named*
  selectors (§2.3). Pace matches the first (read at match start only, §4.1) and does not match
  the second.

---

## 4. The pace clock: exactly one seam (static audit)

### 4.1 The chain, with citations

```
pace.gd PRESETS ................................................ godot/src/sim/pace.gd:47-53
  └ factor_for(id) / scaled_dt(dt,id) ......................... pace.gd:115-116, 125-126
save key "pacePreset" (prefs group) ........................... save_schema.gd:144 (default)
  written through ModesSave.save_pref(...) .................... modes_save.gd:204-212
  (from the UI: SettingsScreen.gd:269-273 → :187-188)
Config.pace_id() / Config.pace_factor() ....................... game/match_config.gd:178-186
  (reads the prefs group via stored_prefs() ................... match_config.gd:79-85)
latched ONCE per match start .................................. match_controller.gd:448 (_adopt_session)
                                                               match_controller.gd:1012 (match start)
used in ONE function .......................................... match_controller.gd:1077 advance_frame
    dt = minf(delta, MAX_FRAME_DELTA) * pace_factor ............ match_controller.gd:1085
    accumulator cap = FIXED_STEP * MAX_SIM_STEPS * pace_factor .. match_controller.gd:1086
sub-steps at the reference's own FIXED_STEP .................... match_controller.gd:1091
```

`pace_factor` is declared at `match_controller.gd:204` and appears in exactly eight places
repo-wide; the complete list (`grep -rn "pace_factor" godot/ --include=*.gd`):

```
godot/game/match_config.gd:185      static func pace_factor() -> float:
godot/game/match_controller.gd:204   var pace_factor: float = 1.0
godot/game/match_controller.gd:448   pace_factor = Config.pace_factor()
godot/game/match_controller.gd:1012  pace_factor = Config.pace_factor()
godot/game/match_controller.gd:1085  var dt := minf(delta, MAX_FRAME_DELTA) * pace_factor
godot/game/match_controller.gd:1086  sim_accumulator = minf(sim_accumulator + dt, FIXED_STEP * float(MAX_SIM_STEPS) * pace_factor)
godot/_probe_pace_clock.gd:85, :97   (the ad-hoc probe's own assertions)
```

### 4.2 The five evidences that there is no second multiplication

1. **Only one function consumes it, and it is the whole clock.** `advance_frame`
   (`match_controller.gd:1077`) is the sole consumer, and lines 1085/1086 are the same
   statement in two places: the real→sim conversion and the catch-up cap, both scaled so the
   cap stays the reference's `FIXED_STEP * MAX_SIM_STEPS` **in simulated seconds**. The
   sub-step size itself is unscaled (`:1091`), so nothing inside the simulation sees `k`.
   The comment at `:1080-1084` states that reasoning; `:196-204` states the one-seam
   invariant.
2. **One caller.** `grep -rn "advance_frame(" godot/ --include=*.gd` returns exactly two call
   sites: `match_controller.gd:1148` (inside `apply_frame`) and `_probe_pace_clock.gd:101`
   (the ad-hoc probe). `apply_frame` itself is called from `_process`
   (`match_controller.gd:1186`, `:1188`) and by tests. There is no second frame path.
3. **Modes and drills inherit, they do not scale.** `tick_fixed` (`:1265`) calls
   `session.step(dt, input, input2)` at `:1274`, which forwards to `drill.step(dt, input)` or
   `Sim.update_match(state, dt, ...)` (`godot/game/mode_session.gd:252-260`) — always with the
   whole `FIXED_STEP` the loop passed (`match_controller.gd:1091`). A second multiply inside a
   mode or a drill would be the double application, and there is none.
4. **The clock-adjacent paths are named and outside the seam.** `_run_capture`
   (`:1525`), `_run_mode_capture` (`:1651`, `:1654`) call `tick_fixed(FIXED_STEP, …)` directly
   — capture-harness bursts that deliberately bypass the accumulator; `_replay_frame`
   (`:1908-1925`) advances only a playback cursor with `_replay_accum += minf(delta,
   MAX_FRAME_DELTA)` (`:1913`) and never advances the simulation (`:1906-1907` states it).
   `camera_study.gd:282` is a prototype. None of them reads `pace_factor`.
5. **The module's own helper is not a second seam.** `Pace.scaled_dt` (`pace.gd:125-126`) has
   **no production caller**: `grep -rn "scaled_dt" godot/ --include=*.gd` returns only its
   definition and two assertions in `godot/tests/pace_presets_test.gd:61,63`. The controller
   spells the multiplication inline at `:1085`. That is one arithmetic with two spellings — a
   hygiene observation for whoever touches this next (either call the helper from the
   controller or drop it), not an extra place the factor reaches the simulation.

### 4.3 Two named false positives (readers of a `grep` for "pace" will hit these)

- `godot/src/sim/sim.gd:2752-2754` — a local `var pace: float = 7.5 + …` feeding
  `paddle.runPhase`. It is the paddle's stride rate for the run animation, taken from the
  reference verbatim (`js/game.js:2992-2996`): a constant, not a player setting, and it
  consumes the `dt` its caller already delivered.
- `js/game.js:584-585` (reference only) — `const pace = Math.hypot(ball.vx, ball.vy)` feeding
  `state.aiShotPressure` via `pacePressure`. A per-shot ball speed magnitude for an AI
  reaction term; it has no prefs, no factor, and no port counterpart named `pace`.

Neither is a clock and neither scales anything.

### 4.4 What this implies for a control in `#matchSetup`

- The factor is **latched at match start** (`:448`, `:1012`), so a UI control only has to write
  the pref. Nothing may assign `match_controller.pace_factor` directly, and a change made
  mid-match cannot retune the running match — which is the same behaviour the reference's own
  difficulty and length have (they are read when the match is created,
  `js/main.js:1155`/`:1189`).
- The write path the two existing groups use is `ModesSave.save_pref(store, key, value)`
  (`ModesScreen.gd:524` for `aiDifficulty`, `:539` for `matchLength`), and the read-back the
  screen already has is `UiData.settings_snapshot().pace_preset` (`UiData.gd:475`) — no new
  schema.
- The sibling evidence file's measurement stands as the only end-to-end proof that the seam
  works; it was **not re-run here** (no engine). `game-pace-presets.md:79-91`: ticks over 60
  real frames `{brisk:120, learning:60, realistic:180, relaxed:72, standard:90}` = `120 × k`
  exactly.

---

## 5. Frozen-surface status

- **The frozen reference is untouched.** `git status --short -- js/ index.html styles.css` is
  empty at the end of this run: `js/**`, `index.html` and `styles.css` are byte-identical to
  HEAD `9ea56e5`. Nothing in this audit wrote to them.
- **This audit wrote exactly one file**: this document (`?? docs/wayfinder/evidence/pace-match-setup-parity.md`,
  untracked). No other file was created, modified or staged by this run; no commit, no
  `git add`, no engine process, no test, no `gdlint`, no export.
- **An in-flight edit by the concurrent worker was observed during this run** (read-only; the
  snapshot moved while this audit was reading it, so these are the *last* observations, not a
  review of finished work). `git status --short` reported three tracked files modified and one
  new untracked test:
  - `godot/src/ui/screens/ModesScreen.gd` (+115 lines, pure insertions) and
    `godot/src/ui/screens/ModesScreen.tscn` (+21 lines: `PaceGroup`, `PaceStack`, `PaceLabel`,
    `PaceSegmentedBox`, `PaceSegmented` under `MatchSetup`, `columns = 1`);
  - `godot/tests/ui/screen_modes_audit.gd` (+17/-5): the focusable count and the bridge count
    both moved from `14` to `19` (`screen_modes_audit.gd:619`, `:639` in the working copy) with
    a new assertion that every `Pace.ids()` rung reports an action — i.e. §2.6's first
    constraint was met by an owned edit of the record, not by a silent side effect;
  - `godot/tests/pace_screen_test.gd` (new, untracked, 16.9 KB) — the file the audit's new
    comment names as the owner of the rungs' behaviour. **Not read or run here.**
  - At the moment of this read the `_style_chrome()` list had also grown to
    `["DifficultyGroup", "LengthGroup", "PaceGroup"]`, so §2.5's frame note is answered in the
    working copy (the scene's `PaceSegmentedBox` carries `SegmentedContainer`, the group frame
    comes from the list). No `setup_visible()`/`_apply_layout()` change: the group inherits the
    container's quick-only visibility, as §2.2 concludes it should.
- **Line citations for the two edited files are HEAD-relative.** Every `ModesScreen.gd` and
  `ModesScreen.tscn` line number in this document refers to HEAD `9ea56e5` (935 and 127 lines
  respectively), not to the working copy: the concurrent diff is a set of pure insertions, so
  it shifts the lines it follows. Recover a cited line with
  `git show 9ea56e5:godot/src/ui/screens/ModesScreen.gd`. All `js/`, `index.html`,
  `styles.css`, `godot/game/**` and `godot/src/sim/pace.gd` citations are unambiguous —
  those files are unmodified.

## 6. What was measured vs inferred

| Kind | Items |
|---|---|
| **Read** (exact, reproducible by the cited line) | every rule and line in §2, §3 and §4; the `grep` result sets of §4.1-§4.3; the git state of §5 |
| **Arithmetic over cited numbers** (inferred) | 712 px setup content box; 347 px vs 225.3 px per group with two vs three groups; the 35 % shrink; ≈191 px inside a group's padding |
| **Inferred, needs an engine measure** | that a three-group `HBoxContainer` does not fit at 1280 and clips rather than stacking or scrolling (no 860 px rule in the port, `horizontal_scroll_mode = 0`); the actual per-button text widths at `font: 900 0.68rem` |
| **Inferred, needs a browser** | that `#matchSetup` stays rendered in the reference despite `hidden = true` (§2.2 — a CSS cascade reading, not a browser observation) |
| **Not run here** | every gate; the pace clock probe; `gdlint`; the modes-screen audit |

## 7. Limitations

1. **Static only.** No Godot process was started (another worker owns the engine for this
   run), so nothing in §2.5 about clipping or in §4 about the clock was executed. The clock
   seam claim is a source-level claim: `advance_frame` is the only function that turns real
   frame time into simulated time, evidenced by the complete `grep` result sets in §4.1-§4.2 —
   not by a tick count.
2. **`grep` coverage.** The seam audit searches literal identifiers (`pace_factor`, `pace_id`,
   `pacePreset`, `pace_preset`, `scaled_dt`) and the multiplication patterns `* pace` / `* factor`
   / `* Config.`. A future second seam written with different names (e.g. a helper that scales
   `FIXED_STEP` inside the sim) would not be caught by these searches. The structural evidence —
   `advance_frame`'s single caller, `tick_fixed` passing a whole `FIXED_STEP`, and the sim
   taking `dt` as an argument — is what makes the claim hold beyond the greps.
3. **The `[hidden]` finding is a cascade reading.** §2.2's claim that the reference's setup block
   stays visible in career/tournament is derived from the absence of a `.match-setup[hidden]`
   rule and from author-vs-UA cascade order. If it matters to the decision, open the reference
   in a browser with `prefs.mode = "career"` and look. It is presented as a fact about the
   frozen files, and as an open parity question about the port, not as a recommendation to
   change the port's behaviour.
4. **No judgment on the placement.** This document does not decide whether `PaceGroup` belongs
   in `MatchSetup`. It records what the reference does and does not say, and it names the
   machine-checked surfaces that will register the change (focusable count, aria slots, literal
   scan, chrome list).
5. **Out of scope.** Audio/HUD timing of the pace change, the replay path's own clock, the
   `mode_screen.gd:380` warm-up burst (a stat burst, deliberately unscaled — recorded in
   `game-pace-presets.md:44-46`), and the demo's broader content questions. The reference's
   `ui.selectedMode = DEMO_CONTENT.modes[0]` pin (`js/ui.js:755`) has no port equivalent at that
   seam (the port's pending mode defaults to `quick`, `match_config.gd:43`, and its mode lock is
   per-card + `mode_session.gd:142-150`); whether that divergence should close is the owning
   lane's call and is not part of the pace placement.
6. **No LOG line.** `docs/mission/LOG.md` was not touched: the run's allowlist is the one new
   evidence file and nothing else.
