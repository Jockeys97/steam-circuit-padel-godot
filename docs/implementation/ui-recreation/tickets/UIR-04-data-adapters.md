---
id: UIR-04
title: UI data adapters (locale, progression, demo gate)
slug: data-adapters
state: done
readiness: potential
owner_role: contract/adapters worker
blocked_by: [UIR-03]
blocks: [UIR-07, UIR-08, UIR-10, UIR-11, UIR-12, UIR-13, UIR-14, UIR-15, UIR-16, UIR-17, UIR-18, UIR-19, UIR-20, UIR-21, UIR-23]
gates: [plan-approval]
plan_approved: true
triage: ready-for-agent
evidence:
  - docs/implementation/ui-recreation/evidence/uir-04-adapters-audit.log
---

# UIR-04: UI data adapters (locale, progression, demo gate)

## Worker brief (copy-paste)

> Build thin read-only adapters that sit between the new screens and the existing seams: `UiData.gd` over `ModesSave`, `SaveStore`, `ModeTables`, `Config` and content reads; `DemoGateAdapter.gd` over `godot/game/content_gate.gd`. The adapters return display data with ids, and screen code never touches `user://`, save internals, mode rules or the demo rule directly. Do not modify any existing module. Prove the adapter surface with `data_audit.gd` headless.

## Why this exists

Screens for characters, arena, modes, history, challenges, profile, result and settings all read the same persisted career/history/unlock data. If each screen reads saves or re-derives the demo rule, the pack creates a dozen owners for one rule. The port already has the right seams; this ticket makes them safe to consume without widening them:

- `godot/src/modes/modes_save.gd` (public mode persistence API: `load_career:79`, `save_career:90`, `load_drill_records:99`, `drill_best:105`, `save_drill_score:111`, `load_history:142`, `record_match:149`, `history_entry:160`, `tournament_round:192`, `save_tournament_round:199`, `save_pref:204`, `profile:216`)
- `godot/src/save/save_store.gd` (atomic writes, quarantine, migration; never called from UI)
- `godot/game/content_gate.gd` (`is_demo`, `label`, `roster`, `arenas`, `is_locked`, `modes`, `fixed_tier_index`, `first_exposed_athlete_index`, `first_exposed_arena_index`)
- `godot/src/modes/mode_tables.gd` (frozen tables incl. `unlock_code`, `outfits`, `outfit_by_unlock_key`, `objective_defs`, `career_*`, `drill_*`)
- `godot/game/match_config.gd` (selection: `athletes/arenas/selectable_*/tiers/outfit_ids/outfit_id/mode_options`)

## Prerequisites (Definition of Ready)

- UIR-03 landed (UiStrings exists; adapters do not own strings).

## Read allowlist

- The modules above, in full
- `js/ui.js` renderers for the read screens: `renderAthletes:846`, `renderChallenges:1125`, `renderArenas:1220`, `renderMatchStats:1386`, `renderObjectives:1433`, `renderHistory:1574`, `renderProfile:1608`; `applyDemoLimits:737-770`; `resolveLineup:548`; `dictatedRivals:531`; `currentFixture:500`; `selectableAthletes:485`; `selectableArenas:490`
- `js/build.js:55-112` (`BUILD_CONTENT`, `DEMO_CONTENT`, `demoFilter`, `demoLocked`)
- `godot/tests/build/BuildFlag.gd`, `godot/tests/build/DemoContent.gd`, `godot/tests/build/ContentFilter.gd` (where the gate data lives today; `content_gate.gd` header notes a requested future move to `res://src/build/`; adapters must not care)

## Write allowlist (you own these)

- `godot/src/ui/data/UiData.gd`
- `godot/src/ui/data/DemoGateAdapter.gd`
- `godot/src/ui/data/*.gd` (any further adapter files, one concern each)
- `.uid` sidecars for the files above
- `godot/tests/ui/data_audit.gd`, `godot/tests/ui/data_audit.tscn`
- `docs/implementation/ui-recreation/evidence/uir-04-adapters-audit.log`

No other writes. Do NOT edit `godot/src/ui/UiStrings.gd` (UIR-03 owns it).

## Do not touch

`godot/game/content_gate.gd`, `godot/tests/build/**`, `godot/src/modes/**`, `godot/src/save/**`, `godot/src/locale/**`, `godot/game/match_config.gd` (all read-only; if you believe one needs a change, that is a blocker note, not an edit).

## Interface (all new)

`UiData.gd` (extends RefCounted), minimum surface; grow only with a consuming ticket:

- `static func history_entries() -> Array[Dictionary]` (id-keyed rows: win/loss, mode id, human mode, opponent id, athlete id, arena id, score fields, timestamp; resolves nothing)
- `static func history_summary() -> Dictionary` (wins, losses, trophies)
- `static func profile_summary() -> Dictionary` (wins, seasons, stars, win rate, per `ModesSave.profile`)
- `static func season_objectives() -> Array[Dictionary]` (check state, label id, progress, target, done/claimed)
- `static func unlock_summary() -> Dictionary` (characters/outfits/arenas counts, completed/total, per the reference's three sections)
- `static func drill_records() -> Dictionary`
- `static func athlete_rows() -> Array[Dictionary]` and `static func arena_rows() -> Array[Dictionary]` (id, name key, description key, art path, locked flag, unlock label data; art path built from `godot/assets/ui/**` per UIR-01)
- `static func lineup_defaults() -> Dictionary`
- `static func mode_rows() -> Array[Dictionary]` (id, title key, description key, art path, locked flag + tag data, career tag/fixture fields when applicable)
- `static func settings_snapshot() -> Dictionary` (language, reduce motion, colorblind, volume, deadzone, vibration from the save contract)
- `static func result_view(...) -> Dictionary` (score fields, stats rows with better/worse marking, objectives rows, outfit-unlock rows; presentation-free)
- `static func feedback_topics() -> Array[Dictionary]` (six topic ids with label keys)

`DemoGateAdapter.gd` (extends RefCounted):

- `static func build() -> String` ("full" | "demo" | "beta")
- `static func badge_text_key() -> String` / `static func badge_visible() -> bool`
- `static func locked(item_id: String, kind: String) -> bool` (delegates to `Gate.is_locked`)
- `static func mode_locked(mode_id: String) -> bool`
- `static func difficulty_allowed(tier_key: String) -> bool`
- `static func exposed_ids(kind: String) -> Array`

Hard rule: no listener writes `user://`, no adapter caches mutable state owned by the save contract, no screen calls `ModesSave.save_*`; writes belong to action tickets and go through the same public API.

Production vs test data: adapters read the real seams in every run. Audits that need saved state construct a temp `SaveStore` (`SaveStore.new(dir)`), never the real `user://` profile; every assertion that runs against constructed state is labeled as such in the log. The `-- --demo` runs are real build-flag runs, not simulations, and are labeled as the measured build.

Settings snapshot source: the snapshot reads through the public save API (`ModesSave.profile(store)`, `SaveStore.read_all()` with schema defaults; `save_pref` is the write side). If a field the snapshot needs has no public reader, file the missing accessor as a blocker naming it; never read `user://` directly from the adapter.

## Microsteps (do in order)

1. Skim each module in the read list; write down the exact pinned line for each function you wrap (they go in the doc comments).
2. Write `UiData.gd` with one function per consumer need; every returned dictionary carries ids only.
3. Write `DemoGateAdapter.gd`; every function delegates, nothing re-derives. Doc comment cites `js/ui.js:734` ("vedere cosa manca vende piu' che nasconderlo": listed items stay visible, locked).
4. Write `data_audit.gd`: constructs a `SaveStore` in a temp dir (`SaveStore.new(dir)`), round-trips a career via `ModesSave`, and asserts the adapter views match the saved data; asserts `DemoGateAdapter.build()` equals `Gate`'s answers in the current build (`--demo` run flips to demo); asserts no adapter function returns a localized string (scan for `Locale.t` usage: adapters must not call it).
5. Run headless, both full and demo: `-- --demo` must show the pinned demo answers.
6. Hand back.

## Acceptance commands (native macOS)

```bash
export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
cd /Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot
"$GODOT" --headless --path godot/ --script res://tests/ui/data_audit.gd ; echo "exit=$?"
"$GODOT" --headless --path godot/ --script res://tests/ui/data_audit.gd -- --demo ; echo "exit=$?"
```

## Acceptance commands (Linux CI form, existing, host agents only)

The same two commands under `flock`/`timeout` with the Linux binary.

## Evidence to hand back

- `evidence/uir-04-adapters-audit.log`: both runs, exit 0, tallies.
- Hand-back message: adapter surface list, which `ModesSave` functions were wrapped (with pin lines), demo-run answers.

## Definition of Done

- [ ] Adapter surface implemented; all data id-keyed; no localized literal anywhere in `godot/src/ui/data/**`.
- [ ] Both audits green; demo run shows the pinned content (roster [maestro, steamer] semantics for the port's equivalent ids, single arena, tier fixed).
- [ ] No edit to any read-only module.
- [ ] Hand-back names commands and tallies.

## Failure and recovery

- A needed value has no public seam (for example a career field not in `ModesSave.profile`): record a blocker naming the missing field and the consuming screen; do not widen `ModesSave` here.
- Demo/full divergence: the gate is the truth; fix the adapter.

## Traces

`godot/game/content_gate.gd` header; `godot/src/modes/modes_save.gd`, `godot/src/save/save_store.gd`; `js/build.js:55-112`; `js/ui.js` renderers above; scout UI-07; S4 ticket `docs/implementation/tickets/hud-and-menu.md:56` (UiStrings rule).
