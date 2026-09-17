---
id: UIR-11
title: CharactersScreen 1:1 (screen-characters, team, picker, outfits)
slug: screen-characters
state: done
readiness: potential
owner_role: screen worker
blocked_by: [UIR-02, UIR-03, UIR-04, UIR-05, UIR-07]
blocks: [UIR-12, UIR-22, UIR-23]
gates: [plan-approval, gate-a]
plan_approved: true
triage: ready-for-agent
evidence:
  - docs/implementation/ui-recreation/evidence/uir-11-screen-characters.log
  - docs/implementation/ui-recreation/evidence/uir-finalize/ui-audit-sweep.json
capture_states: [default, picker-open, outfit-open, locked-athlete, demo-locked]
---

# UIR-11: CharactersScreen 1:1 (screen-characters, team, picker, outfits)

## Worker brief (copy-paste)

> Recreate `screen-characters` (`index.html:90-100` plus the renderers it drives) as `godot/src/ui/screens/CharactersScreen.gd/.tscn`, registered as `characters`, back target `modes`. The page renders the four-slot lineup (player, player mate, opponent, opponent mate) resolved by the existing lineup seam, with the player slot visually distinct; activating an editable slot opens the athlete picker; the outfit action opens the outfit grid for the selected athlete; locked athletes/outfits stay visible with their unlock labels; the reference's triple-activation unlock-code flow is preserved for progression-locked content only. Confirm returns to arena. Data from `UiData`/`Lineup`; zero literals.

## Why this exists

The reference's characters screen is a renderer-driven grid (`renderAthletes` at `js/ui.js:846`, `resolveLineup:548`, `dictatedRivals:531`, `athleteWithOutfit:650`, `challengeLabel:670`, `lockLabel:690`, `promptUnlockCode:713`). The port already has the pieces: `godot/game/lineup.gd` (`Lineup.resolve`), `Config.outfit_ids/cycle_outfit/outfit_name_key`, `content_gate` roster/lock, `ModeTables.outfits/outfit_by_unlock_key/unlock_code`. This ticket puts the reference's page over them.

## Prerequisites (Definition of Ready)

- GATE-A passed; UIR-02/03/04/05/07 landed.

## Read allowlist

- `index.html:90-100` (header + `athleteGridHead` + `athleteGrid` containers)
- `styles.css`: `.athlete-grid:314`, cards `:323-390`, selected `:342`, locked `:1280-1293`, `.athlete-card__art/role/desc/special`, `.athlete-grid__head`
- `js/ui.js:485-492` (`selectableAthletes`), `:500-547` (`currentFixture`, `currentTournamentFixture`, `dictatedRivals`), `:548-594` (`resolveLineup`), `:609-624` (`selectedOutfit`), `:625-669` (`awardOutfitChallenges`), `:670-702` (`challengeLabel`, `lockLabel`), `:703-736` (`UNLOCK_TAPS=3`, `UNLOCK_TAP_WINDOW=1400`, `promptUnlockCode`), `:846-1124` (`renderAthletes`)
- i18n keys: `charactersTitle`, `charactersSub`, `back`, plus card/locked/outfit keys referenced by the renderer (do not invent keys; unresolved ids hand back as blockers)
- `godot/game/lineup.gd`, `godot/game/match_config.gd:101-134` (outfits), `godot/src/modes/mode_tables.gd` (outfits, unlock_code), `godot/game/content_gate.gd`

## Write allowlist (you own these)

- `godot/src/ui/screens/CharactersScreen.gd`, `godot/src/ui/screens/CharactersScreen.tscn`
- `godot/src/ui/screens/parts/AthletePicker.gd` (and `.tscn` if you split the picker into a scene; keep the `parts/` directory yours)
- `.uid` sidecars for the files above
- `godot/tests/ui/screen_characters_audit.gd`, `godot/tests/ui/screen_characters_audit.tscn`
- `docs/implementation/ui-recreation/evidence/uir-11-screen-characters.log`

No other writes. Writes to *user progression* go through the existing public API only (`ModesSave`), never direct file writes.

## Reference behavior rules (each becomes an audit assertion)

- Initial view: the resolved four-slot lineup (player, player mate, opponent, opponent mate). Roles resolve through the port's `Lineup.resolve`; rival slots dictated by career/tournament fixture are visible but not editable.
- Player slot visually distinct from rival slots (reference `.athlete-card--selected` treatment).
- Activating an editable slot opens the athlete picker scoped to selectable athletes; choosing an athlete already placed in another slot swaps positions, never duplicates.
- Outfit action: opens the same card grid scoped to the selected athlete's outfits; equipped outfit visibly selected; locked outfits show their challenge text and do not activate.
- Locked athletes show the unlock cost/label; they stay visible.
- Triple activation (3 taps inside the 1400 ms window, `js/ui.js:703-704`) inside the picker opens the unlock-code entry for progression-locked content only. Demo-excluded content is NOT unlockable by the code: it remains locked (`js/ui.js:713` + gate semantics).
- Confirmation routes to `arena`; the page's back control (declared target) never competes with a slot-level action.

## Interface (all new)

- `CharactersScreen.gd` extends `ScreenContract`; `capture_states() -> ["default", "picker-open", "outfit-open", "locked-athlete", "demo-locked"]`.
- Unlock-code entry: reuse the existing input-layer OSK TEXT MODEL for gamepad entry (`menu_nav.set_osk_targets` + `osk.open_for`) IF the platform decision allows; if not, physical keyboard entry with the same validation. Never build a second OSK. The code itself is `ModeTables.unlock_code()` (frozen, `js/data.js:700`).

## Microsteps

1. Map every data need to the read list above; write the field table into your log before coding.
2. Build the four-slot header region + grid; strings via `UiStrings`.
3. Picker subview; swap semantics per reference.
4. Outfit subview; lock/challenge labels.
5. Triple-tap detector feeding the unlock-code flow; gate check first (only progression-locked candidates).
6. `screen_characters_audit.gd`: lineup roles and editability; player distinct; swap; outfit selection + locked behavior; locked athletes visible; triple-tap opens code entry; wrong/right code; demo run: demo-excluded athlete remains locked under the code; language flip; capture states.
7. Run full + demo; save log.

## Acceptance commands (native macOS)

```bash
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
cd /Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot
"$GODOT" --headless --path godot/ --script res://tests/ui/screen_characters_audit.gd ; echo "exit=$?"
"$GODOT" --headless --path godot/ --script res://tests/ui/screen_characters_audit.gd -- --demo ; echo "exit=$?"
```

## Evidence to hand back

`evidence/uir-11-screen-characters.log`; hand-back names: lineup seam used, unlock-code entry route (OSK model vs keyboard, with the platform note), demo behavior proof line.

## Definition of Done

- [ ] All behavior rules asserted; zero literals; audits green full + demo.
- [ ] No duplicate athlete possible through any activation path.
- [ ] Demo-excluded content unlock-proof (negated) asserted explicitly.
- [ ] Hand-back names commands and tallies.

## Failure and recovery

- `Lineup.resolve` output lacks a field the reference shows (for example a special-ability label): render the id-based label if a key exists; otherwise record the blocker; do not drop the card field silently.
- Swap semantics clash with dictated rival slots: dictated slots win; record.

## Traces

`index.html:90-100`, `js/ui.js:485-594, :609-736, :846-1124`, `styles.css:314-390, :1280-1293`; scout T03 acceptance list.

## Finalize closure (2026-09-17, integration owner)

Engine record, one Godot process at a time, manifest `docs/implementation/ui-recreation/evidence/uir-finalize/ui-audit-sweep.json` (all sources hashed
before and after: tree digest `1256f5f1d7200437`, stable).

- `tests/ui/screen_characters_audit.gd` — **PASS 148/148**, exit 0, 0 `SCRIPT ERROR` line(s) (1.1s); log `docs/implementation/ui-recreation/evidence/uir-finalize/runs/screen_characters_audit.log`

**State: `done`** — the audit above is this ticket's arbiter and it is green on the
finalize tree.
