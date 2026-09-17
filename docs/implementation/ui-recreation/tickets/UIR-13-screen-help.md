---
id: UIR-13
title: HelpScreen 1:1 (screen-help + shared ControlLegend component)
slug: screen-help
state: blocked
readiness: potential
owner_role: screen worker
blocked_by: [UIR-02, UIR-03, UIR-04, UIR-05, UIR-07]
blocks: [UIR-20, UIR-22]
gates: [plan-approval, gate-a]
plan_approved: false
triage: ready-for-agent
evidence:
  - docs/implementation/ui-recreation/evidence/uir-13-screen-help.log
capture_states: [keyboard-tab, controller-tab]
---

# UIR-13: HelpScreen 1:1 (screen-help + shared ControlLegend component)

## Worker brief (copy-paste)

> Recreate `screen-help` (`index.html:181-265`) as `godot/src/ui/screens/HelpScreen.gd/.tscn`, registered as `help`, back target `menu`. Eight help cards (objective, charge/hit, Circuit Academy, slice, special, player switch, serve, score) in the left column; the right column carries the input tabs (keyboard default, controller second) and their panels: a keyboard guide, and on the controller tab the controller artwork plus the full 13-row mapping legend. Build the legend as a shared component (`godot/src/ui/components/ControlLegend.gd`) because the pause overlay's controls tab consumes the same legend; the component supports an optional smash-tutorial row (used only by the pause consumer; the help screen shows none). You own the component; UIR-20 consumes it read-only.

## Why this exists

The help content is static reference prose with ids in `js/i18n.js` (the port must not carry prose). The legend rows already exist as data in the input layer's own terms (`godot/src/input/scheme.gd` rows carry `label_id`/`desc_id`), so the legend can be generated rather than hand-copied, keeping one source of truth for controls.

## Prerequisites (Definition of Ready)

- GATE-A passed; UIR-02/03/04/05/07 landed.
- Controller artwork present via UIR-01 (`xbox-controller-steam.webp`).

## Read allowlist

- `index.html:181-265` (cards 191-222, tabs 225-228, keyboard panel 230-240, controller panel 242-262)
- `styles.css`: `.help-layout`, `.help-sections`, `.help-card`, `.help-card--academy`, `.help-controller-art`, `.controls-guide__legend`, `.help-input-tabs` (segmented variant), `.kbd-guide`, `kbd` styling, media queries `:2775` (860px one column), `:2785-2795` (560px cards one column)
- `js/main.js` help tab handlers (`data-help-input`) and controller-image swap logic (`generic/playstation/xbox` by layout)
- `godot/src/input/scheme.gd` ACTIONS rows (label_id/desc_id), `godot/src/input/strings.gd` (the legend id list it already owns), `godot/src/locale/locale.gd`
- i18n keys: `helpTitle`, `helpIntro`, `back`, `helpObj`, `helpObjDesc`, `helpCharge`, `helpChargeDesc`, `helpAcademy`, `helpAcademyDesc`, `helpSlice`, `helpSliceDesc`, `helpSpecial`, `helpSpecialDesc`, `helpSwitch`, `helpSwitchDesc`, `helpServe`, `helpServeDesc`, `helpScore`, `helpScoreDesc`, `helpKeyboard`, `helpGamepad`, `ariaInputTabs`, `moveNet`, `chargeShot`, `chargeSlice`, `aimWhile`, `specialBtn`, `switchBtn`, `pauseBtn`, `xboxLayout`, `ariaControllerImg`, `ariaControlsLegend`, and the 13 legend rows' `*Lbl`/`pad*Desc` keys

## Write allowlist (you own these)

- `godot/src/ui/screens/HelpScreen.gd`, `godot/src/ui/screens/HelpScreen.tscn`
- `godot/src/ui/components/ControlLegend.gd` (+ `.tscn` if split)
- `.uid` sidecars for the files above
- `godot/tests/ui/screen_help_audit.gd`, `godot/tests/ui/screen_help_audit.tscn`
- `docs/implementation/ui-recreation/evidence/uir-13-screen-help.log`

No other writes. `godot/src/ui/components/**` becomes yours for the legend only; other component files stay with their owners.

## Reference behavior rules (each becomes an audit assertion)

- Eight cards with the exact title/body key pairs above.
- Keyboard tab active initially; controller tab swaps to artwork + full mapping.
- Controller mapping includes: LS, RS, A, X, Y, B, LB, LT, RT, RB, D-pad, A+A, pause (13 rows, matching `index.html:248-260`).
- Tab state is keyboard and pad navigable and localized (tab labels via `helpKeyboard`/`helpGamepad`; the segmented control's active state styling from the theme).
- Narrow layouts: two-column layout collapses to one at 860px; cards to one column at 560px. Verify at 1024x600 (the smallest required size) that nothing clips and the legend stays readable; `help-layout` uses scroll if content exceeds the frame (the reference page scrolls; the Godot screen adds a ScrollContainer for the same behavior, recorded as the port's scroll policy).
- No text clipped or hidden behind the controller illustration.

## Interface (all new)

`ControlLegend.gd` (extends VBoxContainer or Control):
- `setup(rows: Array[Dictionary], opts: Dictionary = {}) -> void` where rows come from `scheme.gd` ACTIONS (`{id, label_id, desc_id}`) and `opts` may include `tutorial_link: true` plus a signal `tutorial_requested`.
- `set_device_layout(type: String) -> void` for artwork swap (`xbox`/`playstation`/`generic`) if the input layer publishes a connected-pad layout; default `xbox` artwork as the reference does.
- Text resolves through `UiStrings`; kbd cap glyphs are reference content (LS/RS/A/X/Y/B/LB/LT/RT/RB/D-PAD/A+A/☰), reproduce verbatim.

## Microsteps

1. Row/data table first: 8 cards + 13 legend rows with their keys.
2. Static tree; cards column; tabs; panels.
3. `ControlLegend.gd` generated from `scheme.gd` rows; wire into the controller panel; include the keyboard `kbd-guide` panel with its seven rows (`index.html:232-238`).
4. `screen_help_audit.gd`: card count/keys; tab initial state; legend row count and order; tab switch swaps panels; both languages; capture states; 1024x600 no-overflow check.
5. Run; save log.

## Acceptance commands (native macOS)

```bash
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
cd /Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot
"$GODOT" --headless --path godot/ --script res://tests/ui/screen_help_audit.gd ; echo "exit=$?"
```

## Evidence to hand back

`evidence/uir-13-screen-help.log`; hand-back names: whether the port has a pad-layout seam (artwork swap), the legend source rows used, and the scroll policy decision.

## Definition of Done

- [ ] Eight cards + both tabs + 13-row legend rendered from the shared rows; zero literals; audit green at 1280x720 and 1024x600.
- [ ] `ControlLegend` usable by UIR-20 (contract documented in the file header; tutorial-link hook present).
- [ ] Hand-back names command and tally.

## Failure and recovery

- `scheme.gd` rows lack a label for one legend row (for example LB or the D-pad): render from the `label_id`; if a row maps to no id, blocker note naming it; do not hardcode prose.
- Artwork swap seam missing: default xbox artwork (reference static default), record.

## Traces

`index.html:181-265`, `styles.css` help block + `:2775, :2785`, `godot/src/input/scheme.gd` header, `godot/src/input/strings.gd` header; scout T05 acceptance list.
