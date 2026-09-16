# Local macOS gate sweep — what reproduces, what does not

First local run of the whole gate story on the owner's Mac, taken straight after the
hand-off prompt (`docs/handoff/local-hermes-catchup.md`) was written. Nothing was
edited to make a suite pass: this file is a measurement, and the two red surfaces it
found are handed back rather than repaired here.

## Environment

| | |
|---|---|
| Commit measured | `d9c58a18238de4e6210e2c552a26236efd3c4c6d` (branch `main`, working tree clean before the run) |
| Engine | Godot `4.7.2.stable.official.ed1daf0bf` — same build hash the mission pinned |
| Host | macOS 27, Apple Silicon M4; real GPU via `OpenGL API 4.1 Metal - Compatibility` |
| Clone | fresh `git clone` of the one repository named in the hand-off; first `--import` exit 0 |

All suites ran strictly serialised, one engine process at a time, headless, from the
repository root with `GODOT=/Applications/Godot.app/Contents/MacOS/Godot`.

## Result table

| Suite | Hand-off claim | Measured here | Verdict |
|---|---|---|---|
| harness | `PASS 8/8` | `PASS 8/8`, exit 0 | reproduces |
| slice, full build | `PASS 304/304` | `FAIL 277/278`, exit 1 | **red** — one check, see A |
| slice, demo build | `PASS 229/229` | `FAIL 222/227`, exit 1 | **red** — five checks, see A and B |
| saves + Steam seam | `PASS 137/137` | `PASS 137/137`, exit 0 | reproduces |
| input | `PASS 4/4` (308 checks) | `PASS 4/4`, 308 checks, 0 failures, 7 not-ported | reproduces exactly |
| rules audits | `PASS 10/10` (221 checks) | `PASS 10/10`, 221 checks, `expected-checks=221 mismatched=[]` | reproduces exactly |
| music port | `PASS 32/32` | `FAIL 30/32`, exit 1 | **red** — two checks, see C |

No `SCRIPT ERROR` appeared next to any `PASS` in any run (the strict log gate the
hand-off describes was honoured by hand: `scripterrors=0` on every suite).

## A — the exported pack is missing, and the suite fails on it by design

`godot/tests/game_slice_test.gd:952`:

```
var full_pck := "res://build/linux-x86_64/padel.pck"
if not FileAccess.file_exists(full_pck):
    check("the shipping pack exists (export it before running this test)", false, full_pck)
```

`godot/build/` is in `.gitignore`, so a fresh clone has no pack: the check fails, and
the two checks that follow it (athlete scene inside the pack, no excluded tree inside
the pack) are skipped instead of run. That is exactly two checks, which is the whole
difference between the mission's own counts and mine:

- full build: LOG.md records the slice at **280 checks** after the modes lane; measured here **278** = 280 − 2 skipped.
- demo build: LOG.md records **229 checks**; measured here **227** = 229 − 2 skipped.

The hand-off's `304` matches neither the log nor this run, so the claimed
`PASS 304/304` is not a number that can be reproduced from the committed tree. The
underlying failure is a clone artifact, not a code defect: export the pack and the
counts and the check both come back.

## B — the demo run cannot be green on this commit

Four checks in the demo run fail for a reason that has nothing to do with a missing
pack, and the same four are structurally unable to pass in a demo build:

```
FAIL the selected arena reaches both the environment and the simulation:
     expected true, got ["cattedrale: env=clockwork meshes=172 sim=clockwork bounce=0.86",
                         "caldera: env=clockwork meshes=172 sim=clockwork bounce=0.86"]
FAIL tier 0 (rivale) constructs a match: expected true, got { "id": "ingegnere", ... }
FAIL tier 2 (campione) constructs a match: expected true, got { "id": "ingegnere", ... }
FAIL tier 3 (leggenda) constructs a match: expected true, got { "id": "ingegnere", ... }
```

The demo content gate (`js/build.js` `DEMO_CONTENT`: athletes `{maestro, steamer}`,
arena `{clockwork}`, modes `{quick}`) pins the arena and the difficulty — the demo menu
section itself confirms the gate is live in that run: `MENU_ON_SCREEN build=demo
tiers_shown=4 tiers_enabled=1 athletes=2 arenas=1`. Two later sections do not account
for it:

- `_arena_library` (`godot/tests/game_slice_test.gd:1546-1567`) sets two other arenas by
  id and demands the environment and the simulation both follow the choice. In a demo
  both fall back to `clockwork`, so both iterations are recorded red.
- `_tiers_playable` (`godot/tests/game_slice_test.gd:1021-1040`) constructs all four
  tiers and demands each one's AI id. In a demo the pinned difficulty answers every
  time, so three of the four are red.

The correct fix is a demo guard on those two sections (assert the pin instead of free
choice), not a change to the gate. Until then the demo slice is red on `d9c58a1` for
anyone, with or without an exported pack — the demo numbers in the hand-off cannot have
been a pass count on this tree.

## C — the music port is red on a fresh clone, one check of which is substantive

```
FAIL dump is vendored byte-identical to the generated one: 235473 vs 0 bytes,
     sha256 5912ff073731dd2f... vs (nothing)
FAIL dump matches the js/main.js on disk: dump f4d24f7c0bad2097 vs on disk d1e2d3d20b37395e
     — re-run the extractor
```

The first is a clone artifact: `tools/*/out/` is gitignored, so
`tools/audio-music-port/out/music-reference.json` does not exist and the comparison is
against zero bytes.

The second is not. The vendored dump records a hash of `js/main.js` that the
`js/main.js` committed in this repository does not produce (`f4d24f7c…` vs
`d1e2d3d2…`), and the suite's own message says what that means: re-run the extractor.
The hand-off's rule is that the browser game is the frozen reference and nothing edits
it, so either the dump was generated from a reference that was modified and never
committed, or the dump is stale. Either way the 15-scenario stream comparison that
follows is being checked against a dump whose provenance does not match the tree — the
one finding here I would not leave standing.

## Repository hygiene

The first `--import` on a clean clone leaves **59 untracked generated files**: seven
`*.gd.uid` for port scripts under `godot/game/` plus `*.import` sidecars for roughly
fifty PNGs under `godot/game/out/` and `godot/prototypes/camera_study/out/`. The
repository already tracks 104 `.uid` files elsewhere, so the port's own scripts were
simply never given theirs. A generated `*.import` or `*.uid` written into a tracked
asset folder will otherwise drift into someone's commit. Left untouched here — flagged,
not fixed.

## Play state at the time of writing

The playable window runs on this Mac in a real Metal context (`Godot Engine
v4.7.2.stable.official` then `OpenGL API 4.1 Metal - 91.7 - Compatibility - Using
Device: Apple - Apple M4`), launched as:

```
/Applications/Godot.app/Contents/MacOS/Godot --path <repo>/godot res://game/Main.tscn \
  -- --seed=20260916 --tier=3 --camera=default
```

**Not proven:** whether the picture on screen is right. Window-targeted capture of the
Godot window failed on this host (`cua-driver` accessibility walk timed out;
`screencapture -l` refused the window id), so there is no frame evidence in this file.
Feel and framing stay the owner's verdict, as the hand-off requires — no self-report
here.

## What this file does not claim

No frame-rate, latency or performance statement of any kind was made or implied — the
input suite says the same in its own note. Only the nine suites above were run; the
parity matrix, the packaged-build self-checks and the asset tooling were not.
