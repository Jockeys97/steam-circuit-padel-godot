# Handoff: Arena selector fixed and pushed, next is org-simulation finalize to 10/10

## Current Goal
Luca scored the app 1/10 and said "do not stop, ensure push and commit, go brother go /org-simulation", then redirected to "actually, auto /session-handoff". Next session: continue the finalize push toward 10/10 via org-simulation, starting from the green arena selector on main.

## Current State
- Commit `deab8cf` on main, pushed, local == remote (`deab8cf78777fdf29da6887bb36b02eee5a3d054`). 14 files, +812/-17.
- ArenaScreen selector fixed: header chrome bound after grid rebuild (no more raw `arenaTitle`), `activate_arena(id, apply_scene)` is the press path (select + `start_match`), locked cards refuse, chosen card gets `_selected_box()`, unlock lines interpolate `lockLabel` params (no `{n} {word}`), `WorldGridArea` sits ABOVE `GridArea` so torii/medina/carioca/aurora/egeo are on screen.
- Five designed stills copied byte-identical (sha256 MATCH) to `godot/game/arenas/art/world/<id>.png` + `.import`; world cards load them as preview TextureRect. 3D backdrops untouched (procedural). Concept deck `art/concepts/world-arenas-r1/` untouched (read-only).
- Tests green, zero SCRIPT ERROR: `arena_selector_contract_test.gd` PASS 30/30 full, 17/17 demo; `screen_arena_audit.gd` PASS 180/180 full.
- Game relaunched for Luca: `Main.tscn -- --seed=20260916 --tier=3 --camera=default`.
- Dirty tree REMAINS: many foreign M files NOT committed (athletes_view, content_gate, court, lineup, main_menu, match_config, match_controller, athlete_rig/spawn, outfit_catalogue, locale_data, UiArtPaths, CharactersScreen, LOG.md) plus untracked cornetto/fornaio specials, vvl-uir evidence, sketches, `godot/=/` debris, stray `.uid`s. Do not sweep these into an arena commit.
- Skill updated: `padel-godot-port-ops` gained an ArenaScreen selector section.

## Decisions
- `select_arena` stays select-only so audits can split select vs start; `activate_arena` is the click path (UIR-12 rule).
- World courts in a separate grid above the frozen nine, frozen node names untouched for audit pins.
- Card art is preview-only; `world_info().artwork` stays empty so the 3D backdrop stays procedural. No `arena_library.gd` change needed.
- Explicit staging only, never `git add -A`, because other lanes own the remaining dirty files.
- Keyboard confirm via focus bridge was not wired (bridge file out of scope); mouse/click start is solid, keyboard seam reported as open.

## Artifacts
- Commit: `deab8cf` (see `git show --stat deab8cf`)
- `godot/src/ui/screens/ArenaScreen.gd` (`_bind_header`, `_card_box_of`, `_apply_selection_styles`, `activate_arena`, `WORLD_ART_DIR`, world grid above fold, world card TextureRect)
- `godot/tests/ui/arena_selector_contract_test.gd` (25 header/world/template/activation checks + 5 world-art texture checks)
- `godot/tests/ui/screen_arena_audit.gd` (sections 9 header, 10 world five, 11 unlock lines, 12 activation)
- `godot/game/arenas/art/world/` (5 PNGs + 5 `.import`)
- `run/tmp/arena-selector-implement.md`, `run/tmp/arena-selector-contract.md`, `run/tmp/opus-world-card-art.md` (briefs)
- Prior session: `@session:dev-work/20260917_220935_39818e` (world-arenas merge `e4a1aff`); handoff `/tmp/handoff-20260917-193500-world-arenas-merge.md`
- Logs: `/tmp/arena-selector-verify/contract.log`, `audit.log`, `contract2.log`

## Next Steps
- Run `git status --short --branch` in the repo and confirm only foreign-lane files are dirty; do not touch them without owner approval.
- Launch the org-simulation finalize loop toward Luca's 10/10: convene the critic council on the current main build, fix the top gaps in vertical slices, keep `arena_selector_contract_test.gd` + `screen_arena_audit.gd` green.
- Verify every claim with engine runs (`$GODOT --headless --path godot/ --script ...`), never child self-report alone.
- Hand the game to Luca for the feel verdict; no self-certified visual claims from this Mac.

## Suggested Skills
- `padel-godot-port-ops` — engine gates, single-engine rule, ArenaScreen selector section
- `org-simulation` — multi-agent finalize structure for the 10/10 push
- `critic-council-loop` — Luca explicitly invoked it; boolean checklist verdicts
- `autonomous-ai-agents/claude-code` — Opus implementer lane Luca asked for
- `adaptive-model-routing` — pin provider/model before any metered run
- `delegate-hermes` — Smart-Zone rule: >3 calls goes to children
- `creative/unslop` — always-on writing rule
