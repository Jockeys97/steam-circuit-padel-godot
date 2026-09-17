---
id: UIR-26
title: OSK visual grid and touch layer (blocked on the product-scope decision)
slug: osk-touch
state: blocked-external
readiness: external
owner_role: screen worker (after decision)
blocked_by: []
blocks: []
gates: [plan-approval, product-scope-and-platforms]
plan_approved: false
triage: blocked-on-decision
evidence:
  - docs/implementation/ui-recreation/evidence/uir-26-osk-touch.md
---

# UIR-26: OSK visual grid and touch layer (blocked on the product-scope decision)

## Worker brief (copy-paste)

> Do not start this ticket until `docs/wayfinder/tickets/product-scope-and-platforms.md` is answered by Luca with "keep" or "postpone to a stated slice" for touch and the on-screen keyboard. Then: if KEPT, build the OSK visual grid over the existing `godot/src/input/osk.gd` model and the touch control layer per the reference's coarse-pointer rules. If POSTPONED, record the postponement with the decision's own words here and close the ticket; if DROPPED, record that too. Nothing in this ticket is built before the decision.

## Why this exists

The reference has an on-screen keyboard (`index.html:700-708` markup, built by `js/main.js:484-573`; the key rows at `js/main.js:430-437`) and coarse-pointer touch controls + action deck (`index.html:482-495`; CSS `:2058` fine pointer hides the deck, `:2064` coarse + min-width 681 shows it, `:2070` 680px shows touch controls). The port has the OSK MODEL only (`godot/src/input/osk.gd`, wired into `menu_nav.gd:148-231`; asserted by `gamepad_nav_audit.gd`'s `nav/osk_*` checks) and no visual grid, no touch layer. The existing code says this is deliberate: "the reference marks touch and the on-screen keyboard a postponed platform decision; building the visual grid is the UI lane's, and remains postponed until the platform answer says otherwise" (`osk.gd` header). This ticket is that lane, gated.

Deferral is NOT invented here: the decision owner is Luca via the open product-scope ticket, and this ticket exists so nothing is dropped silently (the handoff and both scouts demand the blocker be explicit).

## Prerequisites (Definition of Ready)

- `product-scope-and-platforms` answered explicitly for: input scope (touch/OSK keep, postpone, drop). "Keep" must also state the target platform(s); on a desktop-only release the coarse-pointer states still matter only if a touchscreen/laptop-touch target exists, which the same decision answers.
- UIR-22 landed (the screens mounted).

## Read allowlist

- `index.html:482-495` (action deck + touch controls markup), `:700-708` (OSK markup)
- `styles.css`: `.action-deck:807-844`, `.touch-controls:1081-1099`, media queries `:2058, :2064, :2070`, `.osk` block + the 560px OSK rules (`:3577` region)
- `js/main.js:430-573` (OSK build/open/insert/delete/done), `:742-750` (OSK focus interplay), action-deck/touch handlers
- `godot/src/input/osk.gd` (the model to render), `godot/src/input/menu_nav.gd` (`set_osk_targets`, OSK context), `godot/src/input/focus_nav.gd` (`is_text_field`)
- `docs/wayfinder/tickets/product-scope-and-platforms.md` and its resolution when it lands

## Write allowlist (you own these, once unblocked)

- `godot/src/ui/screens/OskPanel.gd`, `godot/src/ui/screens/OskPanel.tscn`
- `godot/src/ui/screens/TouchControls.gd`, `godot/src/ui/screens/TouchControls.tscn` (+ action deck scene if split)
- `.uid` sidecars for those files
- `godot/tests/ui/osk_touch_audit.gd`, `godot/tests/ui/osk_touch_audit.tscn`
- `docs/implementation/ui-recreation/evidence/uir-26-osk-touch.md`

No other writes.

## Scope if KEPT (each becomes an audit assertion)

- OSK grid: the reference's five rows of true buttons, shift/space/backspace/done behavior from the model; label from the field; preview of the current value; opened on confirm of a text field with a pad (model path already wired), closed by back; 560px-class compact sizing at small widths.
- Touch layer: on the coarse-pointer path only (desktop pointing device = hidden, matching `:2058`); buttons hit-test to the same input actions as the keyboard/pad; the action deck appears only under the reference's own conditions (`:2064`).
- Godot specifics: touch events are `InputEventScreenTouch/Drag`; map to the existing actions through `InputMap` or direct action injection, one path only; record which.

## If POSTPONED or DROPPED

Write the decision, its date, its exact wording (quote), and what remains in the tree (the model stays; no visual). Close with no code.

## Effect on UIR-25

UIR-25 carries this ticket as `conditional_blocked_by`: if the decision is KEPT, UIR-25 waits for this ticket's evidence before its phase A; if POSTPONED/DROPPED, UIR-25 cites the recorded decision verbatim as the accepted scope exception, and the final verdict covers the 13 screens and desktop input only, saying so. Neither path lets UIR-25 close with the OSK/touch question unanswered.

## Acceptance commands (native macOS)

```bash
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
cd /Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot
"$GODOT" --headless --path godot/ --script res://tests/ui/osk_touch_audit.gd ; echo "exit=$?"
```
(Only meaningful if KEPT; otherwise the evidence file carries the decision.)

## Definition of Done

- [ ] Decision recorded verbatim, or the KEPT scope built and audited.
- [ ] Matrix rows for OSK/touch/action deck (FEATURE-MATRIX.md) point at this ticket either way.
- [ ] Hand-back names the decision and, if built, the commands and tallies.

## Failure and recovery

- Decision says "postpone to a stated slice": that slice becomes a new ticket number in this pack (coordinator edits the board); do not leave it unnamed.

## Traces

`godot/src/input/osk.gd` header; `docs/wayfinder/tickets/product-scope-and-platforms.md`; handoff; scout conflicts item 8; S4 ticket "Human gates" section.
