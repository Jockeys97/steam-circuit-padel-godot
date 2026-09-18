# run/tmp/arena-kit/evidence — what was run, and what it said

Evidence tooling for the arena-kit intake (`docs/mission/arena-kit/PIPELINE.md`). Nothing
here is part of the game; it exists so every claim in that document is a run, not a
recollection.

## The runner

    run_step.sh   <phase> <name> <watchdog-s> <godot-args…>
    run_battery.sh <phase> <project-path> [suite…]        # the eight frozen suites
    puller_offline_check.sh                              # the credential-free pull path

`run_step.sh` is the only thing that starts Godot: it takes
`flock -w 900 /tmp/padel-godot.lock`, refuses to start when `pgrep -x Godot` shows a live
process, kills the child at the watchdog, and journals **the exact command, exit code,
`PASS n/n` tally, `SCRIPT ERROR` count, verdict and log sha256** to `results.tsv`.

A step is green only when **all three** hold: exit code 0, zero `SCRIPT ERROR` lines, and a
`PASS n/n` tally (`ALLOW_NO_TALLY=1` for a probe that prints its own marker instead).
**A missing tally is a failure, not a pass**: a GDScript parse error exits 0 with no tally,
and the first run of the kit suite was journalled `exit=0 tally='<none>'` while carrying
a parse error — a false green. That rule is why the suite is trustworthy now.

macOS ships no util-linux `flock`, so `bin/flock` is a shim with the same semantics on the
same lock file.

## Files

| file | what it is |
|---|---|
| `results.tsv` | the journal: one row per engine run (phase, name, exit, tally, errors, verdict, log sha256, command) |
| `results-baseline.tsv` | the pre-change journal rows, before `verdict`/sha columns existed (kept as-is) |
| `logs/<phase>-<name>.log` | the full stdout of each run (the run's own log sha256 is in the journal) |
| `logs/<phase>-<name>.cmd` | the exact command line that produced it |
| `baseline_probe.gd` | the baseline recorder: builds all five arenas and digests the tree (`--diff=<arena>` for the two-build diagnostic) |
| `run_step.sh`, `run_battery.sh` | the runners above |
| `puller_offline_check.sh` | the puller's offline verification, re-runnable |
| `bin/flock` | the lock shim |
| `../baseline.json` | **the** pre-change baseline (recorded on `../pristine`, i.e. HEAD's `arena_scenery.gd`, with the fixed digest) |
| `../pristine/` | a copy of `godot/` with only this lane's edits reverted — the controlled A/B tree for "before" |

Digest note: `baseline_probe.gd` and `arena_kit_test.gd` mask Godot's process-local auto
node names (`@MeshInstance3D@2` → `<auto>`) before hashing. Without that, the same arena
built twice in one process differs on ~14 nodes of pure noise, which is what the first
baseline comparison hit.

## The runs

Pre-change baselines were taken on the working tree before this lane's edits (see
`results-baseline.tsv`), and re-taken on `../pristine` for the suites that had no earlier
run — `../pristine` is the working tree with `arena_scenery.gd` at HEAD and
`arena_kit.gd`/`arena_kit_test.gd` removed, so a difference there is a difference this lane
made.

| suite (runner path) | before | after |
|---|---|---|
| `tests/game_slice_test.gd` | FAIL 344/345 (1 pre-existing locale check¹) | FAIL 344/345 — same check |
| `tests/game_slice_test.gd -- --demo` | FAIL 295/296 (same check) | FAIL 295/296 — same check |
| `tests/world_arenas_field_law_test.gd` | PASS 88/88 | PASS 88/88 |
| `tests/world_arenas_frame_test.gd` | PASS 14/14 | PASS 14/14 |
| `tests/world_arenas_selection_test.gd` | PASS 18/18 | PASS 18/18 |
| `tests/world_arenas_selection_test.gd -- --demo` | PASS 8/8 | PASS 8/8 |
| `tests/ui/arena_selector_contract_test.gd` | PASS 30/30 | PASS 30/30 |
| `tests/ui/arena_selector_contract_test.gd -- --demo` | PASS 17/17 | PASS 17/17 — the log sha256 is *identical* to before |
| `tests/ui/screen_arena_audit.gd` | PASS 180/180 | PASS 180/180 |
| **`tests/arena_kit_test.gd`** (this lane's suite) | n/a | **PASS 83/83**, 0 SCRIPT ERRORs — mid-session, on the final tree, and again after the lint cleanup; the three green logs are byte-identical (`sha256 93e46bafc40cf055…`) |

¹ `FAIL locale table sizes match the reference (688 keys each): expected true, got it=689 en=689`
— pre-existing on the untouched tree, another lane's locale key; identical before and after,
and it is the only failing check in either mode.

Two warnings worth keeping:

- **The "before" copy must be import-warm.** The first `screen_audit` run on `../pristine`
  read FAIL 178/180 and `selection` emitted 12 `SCRIPT ERROR`s; one
  `--headless --path ../pristine --import` pass later both matched the after numbers exactly
  (180/180, 18/18, 0 errors). The UI suites load imported resources; a cold `.godot/` is a
  property of the copy, not of the code.
- **`Kit` is measured through its children now.** `ArenaScenery.field_law_report()` used to
  multiply the holder's transform by the mesh's own, so a piece under
  `Kit/Slot_<slot>/Piece` read as if it stood at the kit node's origin (`Kit reaches z
  -0.25` on the first fixture mount). It walks the full chain to the arena root now — the
  same product the world-arena suite uses — and a container with no geometry is "nothing
  drawn" instead of "a violation at its origin".

## The puller's offline path

`logs/puller_offline_check.log` is a full run: the fixture rebuilds byte-identically;
`--from-inbox` copies it to the slot path and the bytes are checked with `shasum`
independently of the tool; the second run is a no-op; `--report` reads the log back and
reports `placed=1 problems=0 (of 50 slots)`; a non-GLB source is refused with exit 6 and
writes nothing; `--retire` takes it back out and the tree is left with 0 GLBs. The live
`--task` path exits 4 (no key on this machine) — unverified until the owner provides one.

An engine proof rides along with it: with the pulled fixture in place at
`torii/light_source`, `world_arenas_field_law_test.gd` still passes **88/88** (`pull_proof`
rows in the journal) — i.e. a GLB that arrived through the puller is legal scenery in a real
build.
