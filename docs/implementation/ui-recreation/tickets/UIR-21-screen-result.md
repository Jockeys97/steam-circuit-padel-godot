---
id: UIR-21
title: ResultScreen 1:1 (screen-result)
slug: screen-result
state: blocked
readiness: potential
owner_role: screen worker
blocked_by: [UIR-02, UIR-03, UIR-04, UIR-05, UIR-07, UIR-08]
blocks: [UIR-22, UIR-23]
gates: [plan-approval, gate-a]
plan_approved: false
triage: ready-for-agent
evidence:
  - docs/implementation/ui-recreation/evidence/uir-21-screen-result.log
capture_states: [win-points, loss-points, win-set, loss-set, multi-set, career-promotion, tournament-next, demo-cta, beta-cta]
---

# UIR-21: ResultScreen 1:1 (screen-result)

## Worker brief (copy-paste)

> Recreate `screen-result` (`index.html:539-563`) as `godot/src/ui/screens/ResultScreen.gd/.tscn`, registered as `result`. Win/loss titles and messages from their separate localized states; the score block renders the format-correct score (point format shows points; one-set tennis shows game score like `6-4`; multi-set shows the set score); the stats table (points won, aces, winners, errors, longest rally, average rally) with better-values highlighted and errors compared lower-is-better; objectives awarded; newly earned outfits announced immediately; RIGIOCA/next-match behavior; the demo/beta CTA block with hidden-when-no-URL and wishlist-vs-follow wording. Data from `UiData.result_view(...)`; strings from `UiStrings`; zero literals. The screen consumes the match/session result; it persists nothing itself (writers: the existing session/save path).

## Why this exists

The reference result renderer (`showResult` at `js/ui.js:1488`, stats `renderMatchStats:1386`, objectives `renderObjectives:1433`, CTA `applyStoreCta` at `js/main.js:2392`) is where the run's story lands. The port's current result surface is `hud.gd`'s result panel (`_build_result:349`, `show_result:472`). This ticket builds the full screen; UIR-22 mounts it.

## Prerequisites (Definition of Ready)

- GATE-A passed; UIR-08 landed (result hooks flow through the HUD family).

## Read allowlist

- `index.html:539-563` (card, badge, title, message, score row, stats container, objectives container, CTA block `:550-557`, actions `:558-561`)
- `styles.css`: `.result-card:1099-1117`, `.result-scores:1117-1143`, `.result-stats:1143-1200`, `.result-objectives:1200-1265`, `.demo-cta:2870-2890`, `.result-actions`
- `js/ui.js:1386-1412` (`renderMatchStats` + `statRow` at `:1374`, including `lowerBetter`), `:1413-1432` (`rivalNarrative`), `:1433-1487` (`renderObjectives`), `:1488-1545` (`showResult`), `:772-805` (`careerOutcomeText`: promotion / season trophy / repeat season / final season)
- `js/main.js:2392-2420` (`applyStoreCta`: destination typing, wishlist vs follow, hidden when null), `js/main.js` result wiring incl. `pendingContinue` semantics (`ui.pendingContinue`) for tournament/career next-match
- `js/i18n.js`: `matchOver`, `victory`, `defeat`, `victoryMsg`/`defeatMsg` (locate), stat labels, objective labels, `rematch`, `menu`, `demoResultTitle`, `demoResultBody`, `betaResultBody`, `storeWishlist`/`storeFollow` labels (locate exact ids; do not invent)
- `godot/game/mode_session.gd` result fields (`awarded`, `saved`, `winner`, `counts`, fixture/round data), `godot/src/modes/modes_save.gd` (`profile:216`), `godot/game/match_config.gd` (mode + continue state)
- UIR-06 captures: `screen-result`

## Write allowlist (you own these)

- `godot/src/ui/screens/ResultScreen.gd`, `godot/src/ui/screens/ResultScreen.tscn`
- `.uid` sidecars for the two files
- `godot/tests/ui/screen_result_audit.gd`, `godot/tests/ui/screen_result_audit.tscn`
- `docs/implementation/ui-recreation/evidence/uir-21-screen-result.log`

No other writes.

## Behavior rules (each becomes an audit assertion)

- Win and loss titles/messages are separate localized states.
- Score block: point format shows the point score; one-set tennis shows the game score (`6-4` shape); multi-set shows the set score. Construct all three shapes in the audit.
- Stats: six rows; better highlight for higher-is-better; errors lower-is-better; values from the session result data, never recomputed here.
- Objectives: rows with check/progress/done/claimed states; newly earned outfits appear in this section IMMEDIATELY (assert with a constructed result carrying an outfit award).
- Career result states: match win/loss, promotion, season trophy, repeat season, final season (`careerOutcomeText` terminology; use the port's career outcome data from the session).
- Tournament result: next-round state and tournament-win state; RIGIOCA becomes the next-match action while continuation is pending (`ui.pendingContinue` semantics; port equivalent via session fixture state).
- CTA: hidden when no store URL exists (default); when a URL is configured, the label follows destination type (wishlist for Steam, follow otherwise); demo and beta body copy are distinct keys and never conflated.
- Actions: RIGIOCA/next, MENU (goes to `menu`).

## Microsteps

1. Field/state table first (three score formats, six stats, objective states, career outcomes, CTA states); write into the log.
2. Static tree per markup.
3. Bind from the result view-model; format helpers (score, stats) implemented once in the screen or a local helper file you own.
4. `screen_result_audit.gd`: the full state list above; language flip; capture states (nine listed).
5. Run; save log.

## Acceptance commands (native macOS)

```bash
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
cd /Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot
"$GODOT" --headless --path godot/ --script res://tests/ui/screen_result_audit.gd ; echo "exit=$?"
```

## Evidence to hand back

`evidence/uir-21-screen-result.log`; hand-back names: the score format sources, the store URL seam status (likely "not configured": CTA hidden; record it), and the pending-continue data source.

## Definition of Done

- [ ] All states rendered and asserted; no persistence in the screen; zero literals; audit green.
- [ ] CTA hidden-by-default proven; wording logic ready for a configured URL.
- [ ] Hand-back names command and tally.

## Failure and recovery

- No store URL config exists in the port: that is the expected default; record "none configured" with the exact place a future config would plug (a config key proposal in the hand-back; not a new file).
- Result data missing a stat (for example aces): render the row only if the datum exists in the session result, or show the reference's empty treatment; record which rows are data-backed today.

## Traces

`index.html:539-563`, `js/ui.js:1374-1545`, `js/main.js:2392-2420`, `styles.css:1099-1265`; scout T10 acceptance list.
