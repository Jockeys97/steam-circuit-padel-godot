# UIR-23 — demo and beta content matrix: evidence

**State: done** (2026-09-17, release captain, sole engine owner). Acceptance executed on the
finalize tree; the two runs serial, `pgrep -x Godot` empty before each. Nothing else in the
pack was re-run for this ticket.

## Artifacts

- Audit: `godot/tests/ui/demo_matrix_audit.gd` (+ `demo_matrix_audit.tscn`) — mounts the playable
  host (`game/Main.tscn` → its router) read-only, writes only to a temp profile
  (`user://uir23-demo-matrix-audit`, wiped at the end).
- Transcripts: `evidence/uir-23-demo-matrix.log` (both runs; line numbers below are that file).

## Acceptance commands (the ticket's own two)

| build | command | result |
|---|---|---|
| full | `"$GODOT" --headless --path godot/ --script res://tests/ui/demo_matrix_audit.gd` | **PASS 133/133**, exit 0, 0 `SCRIPT ERROR`, 0 engine `ERROR:` |
| demo | same + `-- --demo` | **PASS 178/178**, exit 0, 0 `SCRIPT ERROR`, 0 engine `ERROR:` |

## The matrix (one row per cell)

| # | Aspect | Full build | Demo build | Beta build |
|---|---|---|---|---|
| 1 | Athletes exposed | **PASS** — whole roster (6) listed and selectable; `ok gate/a_full_build_exposes_the_whole_roster`, `ok char/the_whole_roster_is_listed_in_this_build`; source `js/build.js:58-61` (filter is a no-op) | **PASS** — maestro + steamer; `ok gate/a_demo_exposes_both_granted_athletes` (log:164), `ok char/row_maestro|steamer_demo_lock_is_the_builds_own` | same as demo per `js/build.js`; **not runnable** |
| 2 | Athletes not exposed | n/a (no wall) | **PASS** — the four withheld are visible + locked, not selectable, not openable: `ok char/row_<id>_is_locked_visibly` / `_renders_locked` / `_cannot_be_selected` / `_is_not_openable_by_any_code` (log:217-222 …); `data_audit.gd:490` (UIR-04) pins the same listing rule | **not runnable** |
| 3 | Arenas exposed | **PASS** — nine listed; `ok gate/a_full_build_exposes_every_arena`, `ok arena/the_whole_arena_set_is_listed_in_this_build`, `ok arena/every_arena_outside_the_career_wall_can_be_chosen` | **PASS** — clockwork; `ok gate/a_demo_exposes_its_one_arena`, `ok arena/a_demo_lands_on_its_one_granted_arena`, `ok arena/and_that_arena_can_start` | per `js/build.js`: clockwork, officina, locomotive; **not runnable** |
| 4 | Arenas not exposed | n/a — no card claims `demoOnlyFull` (`ok arena/row_<id>_never_claims_the_full_game`) | **PASS** — 8 cards: `ok arena/row_<id>_card_carries_the_lock` / `_lock_is_visible` / `_says_in_the_full_game` (`demoOnlyFull`) / `_cannot_be_chosen`; `ok arena/a_demos_lock_list_is_exactly_what_it_withholds`. The port's lock presentation is the lock badge + the sentence (`screen_arena_audit.gd:197-209`, UIR-12); the reference's preview dim (`.arena-card--locked` `opacity .5` + `grayscale`, `styles.css:1280-1293`) is not re-asserted here | **not runnable** |
| 5 | Modes | **PASS** — all three unlocked; `ok modes/a_full_build_opens_tournament` lands on characters | **PASS** — quick only; `ok modes/row_tournament|c areer_lock_is_the_builds_own`, `ok modes/a_demo_cannot_open_tournament`, `ok modes/a_demo_cannot_open_career`, `ok modes/a_demo_opens_quick`; the tag sentence is `demoLockedMode`, resolvable in it/en (`ok lang/…`) | per `js/build.js`: quick only; **not runnable** |
| 6 | Difficulty | **PASS** — four buttons enabled; `ok diff/a_full_build_grants_<rung>` ×4, `ok diff/a_full_build_pins_nothing`, `ok diff/a_full_build_takes_legend` | **PASS** — pinned medium; `ok diff/a_demo_pins_medium`, others disabled (`ok diff/the_<rung>_button_disabled_state…`), `ok diff/a_demo_refuses_hard`, `ok diff/and_the_session_tier_is_the_pinned_one`; source `js/ui.js:760-764`, `content_gate.gd:37` | all four per matrix; **not runnable** |
| 7 | Outfit challenges | **PASS** — available; `ok gate/outfit_challenges_stay_available_in_every_build`, `ok gate/the_two_demo_athletes_still_carry_eight_challenge_outfits`; `js/build.js:53`; screens: `screen_challenges_audit.gd:320-325` (the demo note is the reference's own sentence), characters outfits | **PASS** — same | **not runnable** |
| 8 | Build badge | **PASS** — hidden, no text: `ok menu/a_full_build_hides_the_badge_row`, `ok menu/a_full_build_shows_no_badge_text` (`js/ui.js:744-749`) | **PASS** — `ok menu/and_it_reads_DEMO` (log:174), `ok menu/a_demo_shows_the_badge_row` | key asked through the adapter (`ok beta/the_beta_badge_key_is_the_adapters_own`); **not runnable** |
| 9 | Result CTA body | **PASS** — hidden while nothing is configured (`ok cta/the_block_starts_hidden_no_store_url_is_configured`, `js/main.js:2392-2420`); body key `betaResultBody` (recorded locale gap) | **PASS** — `ok cta/the_body_key_is_the_builds_own` = `demoResultBody`; a configured url shows the block (`ok cta/the_demo_cta_capture_applies`, constructed payload — the live build has no store page) | `betaResultBody`; **not runnable** |
| 10 | Result CTA label | **PASS** — wishlist vs follow by destination; `ok cta/a_wishlist_destination_wishes`, `ok cta/a_follow_destination_follows`; hidden when null (`ok cta/and_the_block_hides_again`) | **PASS** — same (`screen_result_audit.gd:465-487`) | same; **not runnable** |
| 11 | Menu top nav / actions | **PASS** — the eight `to-*` actions and their buttons all present and visible; `ok menu/the_router_row_carries_the_references_eight_actions`, `ok menu/<Button>_is_visible_in_this_build` ×8, `ok menu/the_language_toggle_is_part_of_the_top_nav` | **PASS** — same (`js/main.js:2199-2246`) | same; **not runnable** |
| 12 | Language handling | **PASS** — it/en; `ok lang/the_badge_copy_resolves_in_it|en`, `ok lang/the_toggle_flips_to_english`, `ok lang/and_back_to_italian` | **PASS** — same | same; **not runnable** |

## Beta column: traceability, not a pass

`# not-ported beta/build_column` is printed in both runs (log:144, 332): `tests/build/BuildFlag.gd:49-66`
resolves **one** boolean over (feature tag, args) — the reference's third label (`js/build.js`,
`BUILD === "beta"`) has no port equivalent. The beta keys are still asked through their own doors
(`DemoGateAdapter.badge_text_key_for` → `betaBadge`; `ResultScreen.set_store_config(url, "follow")`),
and `betaResultBody` has no frozen locale entry, so the id renders — the reference's own visible
fallback. Never emulated by string substitution.

## Findings handed back (named, not patched here)

1. **`storeFollow` has no frozen locale entry in either language** — the follow destination's label
   renders as its id. Already recorded by UIR-21 (`screen_result_audit.gd:606`,
   `evidence/uir-21-screen-result.log:82`); re-confirmed here (`ok lang/the_follow_label_is_the_recorded_locale_gap_in_it|en`).
   Owner: locale lane.
2. **`ArenaScreen.gd:10-11` header prose is stale** — it says the career's wall is something "no
   arena carries (none has an `unlock`)"; `js/data.js` (ARENAS) and the frozen table both carry
   unlock costs (cattedrale 2 trophies … orrery 5+18), and this run proves the wall is real in the
   UI (full build: `locked_ids` == the six career-walled arenas, `ok arena/a_full_build_locks_only_the_careers_own_wall`).
   Prose-only; the behaviour reads the data correctly. Owner: UIR-12; not patched from this ticket.
3. **Full-build badge key is the adapter's constant** — `badge_key_shown()` answers `demoBadge`
   even in a full build while the row is hidden; pinned by `screen_menu_audit.gd:242` and gated by
   visibility. Recorded, not a defect.

## Why the pack's record stays honest

- The finalize manifest (`evidence/uir-finalize/ui-audit-sweep.json`, 32 runs) was frozen before
  this audit existed; it is unchanged, and these two runs carry their own commands and tallies in
  `uir-23-demo-matrix.log`. `evidence/uir-finalize/sweep.py`'s `RUNS` list now also carries the two
  UIR-23 runs so the next full sweep (UIR-25's) includes them; `demo_matrix_audit` is also inside
  UIR-25's own `tests/ui/*_audit.gd` scope.
- No screen or gate file was modified by this ticket (`git status` at closure: the audit pair and
  this evidence are the only additions).
