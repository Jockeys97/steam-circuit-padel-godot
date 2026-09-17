---
id: UIR-14
title: HistoryScreen 1:1 (screen-history)
slug: screen-history
state: done
readiness: potential
owner_role: screen worker
blocked_by: [UIR-02, UIR-03, UIR-04, UIR-05, UIR-07]
blocks: [UIR-22]
gates: [plan-approval, gate-a]
plan_approved: true
triage: ready-for-agent
evidence:
  - docs/implementation/ui-recreation/evidence/uir-14-screen-history.log
  - docs/implementation/ui-recreation/evidence/uir-finalize/ui-audit-sweep.json
capture_states: [empty, populated]
---

# UIR-14: HistoryScreen 1:1 (screen-history)

## Worker brief (copy-paste)

> Recreate `screen-history` (`index.html:268-278`) as `godot/src/ui/screens/HistoryScreen.gd/.tscn`, registered as `history`, back target `menu`. Empty state shows the localized "no matches" message; populated state shows the summary stats row (wins, losses, trophies) and the entry list: win/loss badge, mode, human mode where applicable, opponent, athlete, arena, score, localized date. Maximum retained history is 20 entries, the reference's own cap. All data from `UiData.history_entries()/history_summary()`; all strings from `UiStrings`; zero literals; read-only screen (no writes anywhere).

## Why this exists

History is written by the existing save contract (`ModesSave.record_match/history_entry/load_history`, cap per the reference) and currently has no screen in the port. The reference renderer is `renderHistory` (`js/ui.js:1574`, and the summary boxes `:1303-1307`), driven by `HISTORY_KEY` semantics (`js/ui.js:8`).

## Prerequisites (Definition of Ready)

- GATE-A passed; UIR-04 landed (adapters); UIR-07 landed (pattern).

## Read allowlist

- `index.html:268-278` (`historyStats` + `historyList` containers, `ariaHistory`, `ariaHistoryStats`)
- `styles.css`: `.history-stats`, `.history-stats__box--stars:1303`, `.history-stats__box--rate:1307`, `.history-list`, row styles (locate; the push rows use the shared list styling)
- `js/ui.js:1574-1607` (`renderHistory`), `js/ui.js:8` (`HISTORY_KEY`), the writer side (`js/main.js` showResult path recording), cap of 20 entries (find the trim in `js/ui.js` or `js/main.js` and cite it in your log; the scout recorded 20)
- i18n keys: `historyTitle`, `historySub`, `ariaHistoryStats`, the empty-state message key, per-entry keys (win/loss, mode labels, human-mode label, date format), stat labels (locate; do not invent)
- `godot/src/modes/modes_save.gd` (`load_history:142`, `history_entry:160`), `godot/src/locale/locale.gd` (`substitute` for the date/score params)
- UIR-06 captures: `screen-history` reference PNG (populated state may need a played session in the reference; if the reference capture is empty-only, say so in your log and work from the renderer code)

## Write allowlist (you own these)

- `godot/src/ui/screens/HistoryScreen.gd`, `godot/src/ui/screens/HistoryScreen.tscn`
- `.uid` sidecars for the two files
- `godot/tests/ui/screen_history_audit.gd`, `godot/tests/ui/screen_history_audit.tscn`
- `docs/implementation/ui-recreation/evidence/uir-14-screen-history.log`

No other writes.

## Behavior rules (each becomes an audit assertion)

- Empty state: localized message, no list, no error.
- Populated: summary counts (wins, losses, trophies) match the entries; each row renders all reference fields; the win/loss badge carries the semantic color from the theme.
- Cap: with 25 constructed entries in the store, the screen shows at most 20 (or exactly 20 if the trim is on write; assert the end state matches the reference's own behavior, citing where the trim lives).
- Date formatting: localized per current language; flip language and assert the rendered date changes through the locale seam (not by reformatting in the screen).
- Mode label and human-mode field only where applicable.

## Microsteps

1. Field table first: locate every row field in `renderHistory` and its keys.
2. Static tree: header, stats box row, list (ScrollContainer for overflow; the reference page scrolls).
3. Bind from `UiData`; format params via `UiStrings.t(key, params)`.
4. `screen_history_audit.gd`: construct a `SaveStore` in a temp dir with 0 / 3 / 25 entries via `ModesSave.record_match`; assert empty/populated/cap/language flip/capture states.
5. Run; save log.

## Acceptance commands (native macOS)

```bash
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
cd /Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot
"$GODOT" --headless --path godot/ --script res://tests/ui/screen_history_audit.gd ; echo "exit=$?"
```

## Evidence to hand back

`evidence/uir-14-screen-history.log`; hand-back names the exact trim location (file:line) and the date locale mechanism used.

## Definition of Done

- [ ] Empty + populated + cap + language assertions green; zero literals; read-only proven (no save writes from this screen; the audit's store is a temp dir).
- [ ] Hand-back names command and tally.

## Failure and recovery

- No date localization helper exists: use the locale seam's `substitute` with the reference's own date keys; if the reference formats dates in JS (`toLocaleDateString` semantics), record the divergence and the chosen port behavior in the log for Luca; do not silently switch formats.
- Score rendering needs the score-format helper from the result screen: import the same helper if it exists as a shared utility; otherwise duplicate ONLY the format string, recorded here as a shared-candidate for UIR-21's owner to lift later.

## Traces

`index.html:268-278`, `js/ui.js:1574-1607`, `styles.css:1296-1310`; scout T06 acceptance (history part).

## Finalize closure (2026-09-17, integration owner)

Engine record, one Godot process at a time, manifest `docs/implementation/ui-recreation/evidence/uir-finalize/ui-audit-sweep.json` (all sources hashed
before and after: tree digest `1256f5f1d7200437`, stable).

- `tests/ui/screen_history_audit.gd` — **PASS 56/56**, exit 0, 0 `SCRIPT ERROR` line(s) (0.5s); log `docs/implementation/ui-recreation/evidence/uir-finalize/runs/screen_history_audit.log`

**State: `done`** — the audit above is this ticket's arbiter and it is green on the
finalize tree.
