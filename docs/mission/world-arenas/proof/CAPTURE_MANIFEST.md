# World-arena capture manifest (frozen evidence)

Frozen from run **`resume-04`** of `tools/world-arenas/run_proof.sh
--baseline --run-id=resume-04` (runner exit **0**, manifest `run green: True`,
`tree stable during run: True`). The run dir is kept under
`tools/world-arenas/out/resume-04/` (logs, `results.tsv`, `MANIFEST.json`,
`MANIFEST.md`); this directory holds the frames themselves plus the run's own
records, copied verbatim.

## What was captured, and from where

- **Arena set**: the five world arenas — `torii`, `medina`, `carioca`, `aurora`,
  `egeo` (port additions, `godot/game/arenas/arena_style.gd`, `family: "world"`).
- **Presets**: `default`, `wide`, `playable` — the frozen camera presets, read
  from `court.gd::CAMERAS`. No camera or preset was edited for this phase.
- **Harness**: `res://tests/world_arenas_capture.tscn` —
  `--path godot --rendering-driver opengl3 --resolution 1280x720`.
  Real viewport, not headless: the capture suite refuses a headless display by
  name, and records `display=macOS`, `adapter=Apple M4`.
- **Frames**: 15 PNGs, every one **1280 × 720**, one distinct SHA-256 each.

## Frames (paths are relative to this directory)

| preset | arena | bytes | sha256 |
|---|---|---|---|
| default | aurora | 1280x720 | `9585e1102dba441d1323da0d171db37e8356c2d0f5a364c8f393dea11957f193` |
| default | carioca | 1280x720 | `ff94cd6a6f160692b1840a6387b6605109b86a9d3561a6c45eb7463449ae4dbb` |
| default | egeo | 1280x720 | `a8cd0676f423525f571c1b5f7ef7bb632c48c666cc04caf2b833d36b7a35d614` |
| default | medina | 1280x720 | `4142060f46eb8310200e4695c98dc0ae520eaaf9100a0a4160ba3740571c8b34` |
| default | torii | 1280x720 | `6e0d46be919e5755cd464a3cd10ad0bd81f30974c488946279bb3b71021b1db8` |
| wide | aurora | 1280x720 | `ef6bc1cdb94580f17d2f3dcb5b28836c34eda1b77d027d4577db8996a81a4c4c` |
| wide | carioca | 1280x720 | `3994cc0ba6d0b8d8f45d34cd5481cd3c223424f5b5baf3db5ff64c89502d4d65` |
| wide | egeo | 1280x720 | `0f573f8fa955dccd02190755f08643317bfda83015dbcffb9951691a04c1d131` |
| wide | medina | 1280x720 | `bfa12203e4ef33dafa9b15923dd67e4bef0ee25311ab0bba4e5049bb2e91a3a2` |
| wide | torii | 1280x720 | `4fc20d886f11a9308c2981e32c29ba233441581c09f1694259ad28cb698deaba` |
| playable | aurora | 1280x720 | `6d62e8d2ac2c450899cb5829826c3b6e0e913ea162d4ae60c7c4ffb8027ad25f` |
| playable | carioca | 1280x720 | `92224a8a266c6f19c05f9671a3b4b79eef54c5f242711b58346725c71510adb5` |
| playable | egeo | 1280x720 | `6a8a86d50e25d017c96287e9458ffbc3edef0707a20e959661bbd5c3f71ff2b5` |
| playable | medina | 1280x720 | `0572b43a5e0b8bf44cbc982b017d349d3132dcd215cff65e827618cbd517d1f9` |
| playable | torii | 1280x720 | `23c8c101b4edb9de94653b90e34e0d72bec60f34aac7400a1fec9841753950bd` |

`sha256.txt` is `shasum -a 256 default/*.png wide/*.png playable/*.png` over the
files in this directory. `captures.json` is the run's own record (path, sha256,
size, colour count, sampled-pixel grid, projected court/glass points, glass
alphas, engine/display facts). **`MANIFEST.json` re-hashes every PNG from the
bytes on disk** (`sha256_matches_in_run_record` per file) — a producer's hash is
re-verified, never trusted.

Verification performed after the freeze: all **15/15** files in this directory
hash to the value recorded in `captures.json`, and the run's manifest counts
`15 records, 15 files on disk, 15 at the recorded size ([1280, 720])`.

## What the frames are gated on (inside the run, not by eye)

Per frame, `world_arenas_capture.gd` checks, and the run passed **111/111**:

1. the display server is not headless;
2. the image is the viewport texture's size **and** the requested `1280x720`;
3. the sampled pixel grid is not blank and the arenas render distinctly (one
   capture, one signature);
4. every glass pane and scenery mesh is **visible** at capture time, with the
   rear-glass alpha equal to the arena's `wallBounce`-derived value;
5. every court corner and side/rear glass extent projects inside the frame;
6. the PNG is saved and hashed.

No frame was judged by looking at it: this file records hashes and the
harness's own checks. Nothing here claims a human or a model has seen the
images.

## RED before green (kept, not hidden)

- `resume-01` (RED, first full sweep): slice 341/342 (menu fit 677 > 648),
  field-law 48/63, capture 96/111. Kept in `tools/world-arenas/out/resume-01/`
  with `RED.md` and `logs_sha256.txt`.
- `resume-02`: every suite green except capture (96/111, PNG `err=7`).
- `resume-03`: all eight steps green (slice 342/342, demo 293/293, field 63/63,
  frame 11/11, selection 13/13, selection demo 8/8, capture 111/111).
- `resume-04`: the same, re-run after the last production edit (capture
  enumeration + comment in `match_controller.gd`), so the green manifest
  corresponds to the tree as it stands.

Three failures were real and were fixed on evidence, none by touching a bound:

1. **Menu fit** (production): the world chooser had been added as a new column
   row, which measured 677 px against the 1152x648 frame. Re-placed as the
   setup block's third column, where the row's height is already set by the
   athlete column (zero height cost; `# MENU_FIT` now `1140x643` at both
   frames).
2. **Field law** (proof mechanics): `Common.world_aabb()` read
   `MeshInstance3D.global_transform` on a **detached** arena, where it is
   identity (399 × `Condition "!is_inside_tree()" is true`), so it measured raw
   local AABBs. It now walks the parent chain to the arena root and measures
   transformed VERTICES — the production module's own frame. The field law
   itself (`<= -8.0`) was untouched, and the five arenas pass it **63/63**.
3. **Capture** (proof mechanics): `Common.arg()` returned `substr(len(prefix))`
   without stripping the `=` of `--out=<path>`, and the per-preset directory was
   never created — `err=7` for all 15 frames. Both fixed; the PNG-size and hash
   checks were already there and were not weakened.

## Reproduce

```sh
cd /Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot
tools/world-arenas/run_proof.sh --baseline --run-id=<fresh-id>
```

One engine process at a time (the proof runner serializes every step and
journals `results.tsv`, per-step logs, their SHA-256s, and the tracked-source
digest around the run).
