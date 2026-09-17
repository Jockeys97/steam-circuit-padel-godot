---
id: UIR-10
title: ModesScreen 1:1 (screen-modes + match setup)
slug: screen-modes
state: blocked
readiness: potential
owner_role: screen worker
blocked_by: [UIR-02, UIR-03, UIR-04, UIR-05, UIR-07]
blocks: [UIR-22, UIR-23]
gates: [plan-approval, gate-a]
plan_approved: false
triage: ready-for-agent
evidence:
  - docs/implementation/ui-recreation/evidence/uir-10-screen-modes.log
capture_states: [default, quick, tournament, career, demo-locked]
---

# UIR-10: ModesScreen 1:1 (screen-modes + match setup)

## Worker brief (copy-paste)

> Recreate `screen-modes` (`index.html:103-154`) as `godot/src/ui/screens/ModesScreen.gd/.tscn`, registered as `modes`, back target `menu`. Three mode cards (quick, tournament, career) with art, title, description, tag and (career) the season tag plus fixture line; below, the match setup groups: difficulty segmented (easy/medium/hard/legend) and match length segmented (points11, points21, games3, games5, set, match2). Selection semantics come from the real config and gate: choosing a mode routes to `characters`; the career tag/fixture come from `UiData`; locked modes stay visible and locked via `DemoGateAdapter`. Do not re-implement mode behavior: quick goes through `Config.pending_mode`, and this screen does not start matches.

## Why this exists

The reference modes screen is the doorway to every mode; the port's current `ModeScreen.tscn` is a different, engine-side detail screen for drill/tournament/career (it stays functional for those flows until UIR-22). The recreation restores the reference's page: cards + setup, with the reference's own locked presentation (`js/ui.js:737-770`: locked cards keep their art, tag text switches to `demoLockedMode`).

## Prerequisites (Definition of Ready)

- GATE-A passed (this ticket is post-verdict mass work); UIR-02/03/04/05 landed; UIR-07 landed (same pattern to follow).

## Read allowlist

- `index.html:103-154` (markup), `styles.css`: `.mode-grid:318`, `.mode-card:323-366`, `.mode-card__art:460-474` (including the `--pink` career accent line `:473`), `.mode-card__tag:476-490`, `.mode-card__fixture:490-503`, `.mode-card--locked:503`, `.match-setup`, `.setup-group`, `.segmented:2207-2252`, media queries `:2033, :3299` (1050px one column, 720px length two columns)
- `js/ui.js:737-770` (`applyDemoLimits`), `js/ui.js:772-805` (`careerOutcomeText` context), `js/main.js` career tag updater (`updateCareerTag`), i18n keys: `modesTitle`, `modesSub`, `quickMode`, `quickModeDesc`, `available`, `tournamentMode`, `tournamentModeDesc`, `careerMode`, `careerModeDesc`, `careerTag`, `difficulty`, `diffEasy`, `diffMedium`, `diffHard`, `diffLegend`, `matchLength`, `len11`, `len21`, `lenGames3`, `lenGames5`, `lenSet`, `lenMatch2`, `demoLockedMode`, `lockedModeNote` (locate exact id for the locked note in `js/i18n.js`; do not invent an id)
- `godot/game/match_config.gd:87-100` (`mode_options`), `godot/game/content_gate.gd` (`modes`, `fixed_tier_index`, `DIFFICULTY_TIERS`), `godot/src/modes/mode_tables.gd` (career tag data), `godot/src/modes/career_progress.gd`
- `js/data.js:689-698` (`MATCH_FORMATS` + `MATCH_FORMAT_IDS`; the port's own copy of the frozen values is a separate concern: read where `Config` exposes format selection and use that; if it does not, your audit reports the gap and the difficulty/length segs persist through `UiData.settings_snapshot()`-style storage rather than a new mechanism)

## Write allowlist (you own these)

- `godot/src/ui/screens/ModesScreen.gd`, `godot/src/ui/screens/ModesScreen.tscn`
- `.uid` sidecars for the two files
- `godot/tests/ui/screen_modes_audit.gd`, `godot/tests/ui/screen_modes_audit.tscn`
- `docs/implementation/ui-recreation/evidence/uir-10-screen-modes.log`

No other writes.

## Reference anatomy (verified)

- Header: back button (`data-action="to-menu"`, `data-back`), title `MODALITÀ DI GIOCO`, sub.
- `.mode-grid` three `article.mode-card` (`data-mode=` quick/tournament/career): art div with its own aria label (`ariaQuickModeArt` etc.), `h3`, `p`, tag; career card keeps `id="careerTag"` (`Stagione 1 · 0/3` shape via `careerTag` with params) plus `span#careerFixture` (line 129).
- `.match-setup#matchSetup`: difficulty seg (`#difficultySeg`, four buttons) + length seg (`#lengthSeg`, six buttons).
- Active option styling comes from `.segmented button.is-active`; the demo pins difficulty by disabling buttons (`applyDemoLimits`).
- The reference hides the quick-only setup for tournament/career? No: `#matchSetup` is always present on this screen in the markup; the quick/tournament/career cards are the selectors. Preserve exactly; do not invent per-mode hiding.

## Interaction rules

- Selecting quick/tournament/career routes to `characters` (the reference sets `ui.selectedMode` then shows characters). In the port, selection state lives in the existing seams: set the pending mode via the router payload or `Config`, with the same contract UIR-22 will honor: the arena screen's confirm starts the match through the existing `start_match`/`ModeSession` paths.
- Speed of the difficulty/length segs: write through the save contract via `UiData` writes (settings snapshot), mirroring the reference's prefs persistence; do not hold state only in the scene.

## Microsteps

1. Build the static tree per anatomy; strings via `UiStrings`; art paths per UIR-01 mapping.
2. Wire segs: difficulty maps to the gate's `DIFFICULTY_TIERS` keys; lock the demo-pinned one (disabled, still visible). Length seg writes the chosen format key.
3. Career card: season tag from `UiData` career data with the reference's `{season}/{match}/{total}` shape; fixture line from the career fixture seam (empty state = empty fixture line, the reference hides it via `:empty`).
4. `screen_modes_audit.gd`: asserts card set, tag/fixture content shapes, difficulty options + active states, length options (six), demo run: quick only unlocked, other cards carry the locked class and the locked tag key, difficulty buttons except the pinned one disabled; language flip re-resolves all strings; capture states resolve.
5. Run full + demo audits; save log.

## Acceptance commands (native macOS)

```bash
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
cd /Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot
"$GODOT" --headless --path godot/ --script res://tests/ui/screen_modes_audit.gd ; echo "exit=$?"
"$GODOT" --headless --path godot/ --script res://tests/ui/screen_modes_audit.gd -- --demo ; echo "exit=$?"
```

## Evidence to hand back

`evidence/uir-10-screen-modes.log` plus a hand-back naming: whether the port's length-format storage already existed (with its exact call) or was bridged, and the exact list of disabled buttons in the demo run.

## Definition of Done

- [ ] Cards, tags, fixture, both segs per reference; demo-locked presentation matches `applyDemoLimits` semantics; locked modes remain visible.
- [ ] No mode behavior re-implemented (no `start_mode` logic here); selection persists through existing seams.
- [ ] Zero literals; audits green full + demo; hand-back names commands and tallies.

## Failure and recovery

- No length-format seam in `Config`: this is a real gap; record it as a blocker note naming the missing capability and persist the choice via the prefs path only if the prefs path is the reference's own carrier. Do not add a new settings schema.
- `--pink` unresolved (UIR-06 blocked): leave the career card accent at the theme's documented fallback and record the open item.

## Traces

`index.html:103-154`, `js/ui.js:737-770`, `js/data.js:689-698`, `styles.css:460-503`; scout T02 acceptance list.
