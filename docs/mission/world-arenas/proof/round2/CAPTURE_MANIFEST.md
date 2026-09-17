# World-arena capture manifest — round 2 (refinement freeze)

Frozen from run **`refinement-01`** of `tools/world-arenas/run_proof.sh
--baseline --run-id=refinement-01` (runner exit **0**, manifest `run green:
True`, `tree stable during run: True`, tree digest
`6e0dad26fcce00fc` -> `6e0dad26fcce00fc`). The run dir is kept under
`tools/world-arenas/out/refinement-01/`; this directory holds the frames, the
run's own records and the step logs, copied verbatim and re-hashed here.

**Round 1 stays frozen and untouched.** `docs/mission/world-arenas/proof/captures/`
(`resume-04`, hashes in `proof/captures/sha256.txt` + `proof/CAPTURE_MANIFEST.md`)
was re-hashed after this run: all fifteen values still match, byte for byte.
This directory is the separate round-2 set the re-score reads.

## What was captured, and from where

- **Arena set**: the five world arenas — `torii`, `medina`, `carioca`, `aurora`,
  `egeo` (`godot/game/arenas/arena_style.gd`, `family: "world"`).
- **Presets**: `default`, `wide`, `playable` — the frozen camera presets, read
  from `court.gd::CAMERAS`. No camera or preset was edited in this refinement.
- **Harnesses**: `res://tests/world_arenas_capture.tscn` (15 frames) and the new
  `res://tests/world_arenas_menu_capture.tscn` (the real menu with the world
  chooser), both `--path godot --rendering-driver opengl3 --resolution 1280x720`
  from a real viewport (`display=macOS`, `adapter=Apple M4`).
- **Frames**: 15 arena PNGs + 1 menu PNG, every one **1280 x 720**, hashed from
  the bytes on disk after the copy.

## Frames (paths relative to `captures/` in this directory)

| preset | arena | size | sha256 |
|---|---|---|---|
| default | aurora | 1280x720 | `c54ef6009af4db699d0e2812f525fd9f981f2be618e6c9d87b1d0335b3c6ceee` |
| default | carioca | 1280x720 | `ff94cd6a6f160692b1840a6387b6605109b86a9d3561a6c45eb7463449ae4dbb` |
| default | egeo | 1280x720 | `a8cd0676f423525f571c1b5f7ef7bb632c48c666cc04caf2b833d36b7a35d614` |
| default | medina | 1280x720 | `4142060f46eb8310200e4695c98dc0ae520eaaf9100a0a4160ba3740571c8b34` |
| default | torii | 1280x720 | `6e0d46be919e5755cd464a3cd10ad0bd81f30974c488946279bb3b71021b1db8` |
| wide | aurora | 1280x720 | `3b32a249cda875750d5d3e4fb78f77360f4d367111a968cf8dfcfaa1fa284836` |
| wide | carioca | 1280x720 | `3994cc0ba6d0b8d8f45d34cd5481cd3c223424f5b5baf3db5ff64c89502d4d65` |
| wide | egeo | 1280x720 | `0f573f8fa955dccd02190755f08643317bfda83015dbcffb9951691a04c1d131` |
| wide | medina | 1280x720 | `bfa12203e4ef33dafa9b15923dd67e4bef0ee25311ab0bba4e5049bb2e91a3a2` |
| wide | torii | 1280x720 | `4fc20d886f11a9308c2981e32c29ba233441581c09f1694259ad28cb698deaba` |
| playable | aurora | 1280x720 | `970a18047242bd313e2f9dc29a0a42b4c8d6fe3697a3ae9cf1122cbaa4b13ef3` |
| playable | carioca | 1280x720 | `92224a8a266c6f19c05f9671a3b4b79eef54c5f242711b58346725c71510adb5` |
| playable | egeo | 1280x720 | `6a8a86d50e25d017c96287e9458ffbc3edef0707a20e959661bbd5c3f71ff2b5` |
| playable | medina | 1280x720 | `0572b43a5e0b8bf44cbc982b017d349d3132dcd215cff65e827618cbd517d1f9` |
| playable | torii | 1280x720 | `23c8c101b4edb9de94653b90e34e0d72bec60f34aac7400a1fec9841753950bd` |
| menu | world chooser | 1280x720 | `c8bf28c1cc1b42e375e01ab5b0882d0a903b936645a372f2d68bf21b9e0a4d4f` |

## Delta against round 1 (`resume-04` frozen set)

- **12 of 15 arena frames are byte-identical** to round 1 — every frame except
  `aurora` under each of the three presets. Hash comparison of all fifteen
  values: only `default/arena-aurora.png`, `wide/arena-aurora.png`,
  `playable/arena-aurora.png` differ, which is the intended, local aurora
  snow-ridge refinement and nothing else (the `snowridge` branch of
  `arena_scenery.gd`; `_peak` and every other arena's geometry untouched).
- **Aurora change is small and strictly brighter** (pixel diff, `>2` levels,
  measured against the round-1 frozen PNGs):
  - default: bbox `(518, 78, 812, 154)`, 12,959 px changed (1.406% of frame),
    mean channel value 109 -> 137 in the changed region;
  - wide: bbox `(578, 174, 743, 215)`, 3,993 px (0.433%), 107 -> 143;
  - playable: bbox `(566, 246, 767, 298)`, 5,798 px (0.629%), 109 -> 134.
- **New frame**: the real menu with the world chooser (`menu/`), 5 world buttons
  present, visible and inside the frame (min margin 138.0 px), captured by the
  new `world_arenas_menu_capture` step (9/9).
- Run-level: `refinement-01` is green with 9 steps; round 1 was green with 8
  (`resume-04`). Tallies moved only where the review asked: field-law 63 -> 88,
  frame 11 -> 14, selection 13 -> 18; slice 342/342, demo 293/293, selection
  demo 8/8, capture 111/111 unchanged; `menu_capture` 9/9 new.

## Verification performed here (after the copy)

- All 15 arena PNGs re-hashed against the run's `captures.json` records:
  **15/15 match**; the menu PNG re-hashed against `menu_capture.json`:
  **match**.
- Round-1 set re-hashed against `proof/captures/sha256.txt`: **15/15 match**
  (untouched).
- Step logs (`logs/<step>.log`), `results.tsv`, `tree_before/after.json` and
  `runner.out` are the run's own files, copied verbatim; the manifest
  (`MANIFEST.md`/`MANIFEST.json`) is the run's own manifest.
