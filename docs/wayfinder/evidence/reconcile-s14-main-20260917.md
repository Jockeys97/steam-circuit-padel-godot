# Reconciling the S14 lineage with main — the gate sweep on the merged tree

Date: 2026-09-17, on this Mac (macOS 26.2, Apple Silicon).
Tree: `codex/reconcile-20260917`, merge commit `d050769` (parent 1 `bcecd9b` = `origin/main`,
parent 2 `918bfa9` = the S14 lineage) plus one follow-up commit on the test file, below.
Engine: Godot `4.7.2.stable.official.ed1daf0bf` at `/Applications/Godot.app/Contents/MacOS/Godot`.

Every suite was run serially, one engine process at a time, journalled per step to
`/tmp/gates-reconcile/`.

## The sweep

| suite | command (all prefixed `$GODOT --headless --path godot/`) | exit | result |
|---|---|---|---|
| smoke harness | (no script) | 0 | `PASS 8/8` |
| game slice, full | `--script res://tests/game_slice_test.gd` | 0 | `PASS 340/340`, `sections ran 23/23` |
| game slice, demo | `--script res://tests/game_slice_test.gd -- --demo` | 0 | `PASS 291/291`, `sections ran 23/23` |
| court dimensions | `--script res://tests/court_dimensions_test.gd` | 0 | `PASS court dimensions: 1111 checks, 0 failures` |
| save / Steam | `--script res://tests/save_steam_test.gd` | 0 | `PASS 137/137` |
| input | `--script res://tests/input/run_all.gd` | 0 | `PASS 5/5`, `checks=393 failures=0 not-ported=7` |
| audits | `--script res://tests/audits/run_all.gd` | 0 | `PASS 10/10`, `checks=221 failures=0 mismatched=[]` |
| music port | `--script res://tests/music_port_test.gd` | 0 | `PASS 31/31` |

`SCRIPT ERROR` count: **0 in every suite**, counted separately with `grep -c` rather than
inferred from the `PASS` lines.

## The control run, which is what makes the numbers mean anything

`origin/main` at `bcecd9b` was checked out into its own worktree and put through the same
two slice runs: **`FAIL 339/340`** full and **`FAIL 290/291`** demo, the single red in each
being `the shipping pack exists`. The merged tree therefore scores one check better than
main on both runs, and that difference is exactly the pack check, below.

## Four semantic conflicts the textual merge could not see

The merge resolved cleanly as text, and the first sweep still came back 53 red. None of it
was a runtime defect: main's UI-recreation wave had *rewritten* four checks that the S14
lineage still carried in their older form, and a three-way merge has no way to notice that
two sides changed the same assertion's meaning while touching different lines. Each was
fixed by restoring main's newer variant, in the test file only — no runtime source was
touched, and no assertion was weakened:

1. `_menu_reaches_match`: restored `menu.set("ui_legacy", true)`. Main's wave made the
   recreated menu the default; these checks read the legacy column's own contract.
2. `_ui_text`: the same opt-out at the second menu instantiation. Main carries it in two
   places; the merge kept neither.
3. `_arena_library`, artwork: main paints **nine** arenas (two of them reusing another
   arena's backdrop) where the S14 check demanded exactly four. Main's variant also asserts
   the backdrop reuse, so taking it adds a check rather than removing one.
4. `_arena_library`, wiring: main added the demo guard — a demo build grants one arena, so a
   request for any other must land on the granted one in both the environment and the
   simulation. The S14 variant had no demo branch, which is why only the demo run failed it.

## The pack checks, stated rather than scored

`godot/build/` is gitignored, so a source checkout has no exported pack. Rather than
scoring a red the checkout cannot fix, the reconciled slice prints its state:

```
# PACK_MODE full=res://build/linux-x86_64/padel.pck absent (source checkout) — pack-content checks not run, not scored
# PACK_MODE demo=res://build/linux-x86_64-demo/padel-demo.pck absent (source checkout) — pack-content check not run, not scored
```

This is the folded resolution chunk from `287e499`, and it is the entire difference between
340/340 here and 339/340 on main. **A green run on this tree has NOT checked the packaged
build.** Export the pack and the two checks run; a broken pack still fails them.

## An engine flake, not a defect

`--import` segfaults (exit 139) at 91-99%, on `LilitaOne-Regular.ttf`, on this host. It
completes on the second or third attempt and the tree is fine afterwards. While the import
is incomplete `res://src/ui/theme/padel_theme.tres` fails to preload and the slice reports
18 spurious `SCRIPT ERROR` parse failures. Retry the import; do not chase the errors.

## Not measured

- **The packaged build.** No pack exists in this checkout (above).
- **Anything Linux-side.** `godot/game/run.sh` is shaped for the Linux host; this is the
  direct-engine macOS path.
- **Captures and frames.** No `--capture` run was made, so no PNG in `godot/game/out/` was
  regenerated. The four capture PNGs carried by this merge are the S14 lineage's own, and
  regenerating them is a known follow-up.
- **Feel.** Nothing here says how the game plays. macOS window capture of the Godot window
  is unreliable, so no frame evidence and no feel claim is made — that verdict is the
  owner's.
- **The A-button parity investigation.** Deliberately left out of this merge; it is still
  live on `codex/input-bridge-and-slice-s14`.
