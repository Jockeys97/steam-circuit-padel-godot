# Captain B result — 2D pre-viz plans, all five world arenas

Date: 2026-09-19 (session run at 22:5x UTC)
Workdir: `/Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot` (branch `main`, nothing committed)

## Probe command (the only source of numbers)

    export GODOT=/Applications/Godot.app/Contents/MacOS/Godot
    $GODOT --headless --path godot/ --script res://tests/arena_kit_specs_dump.gd \
      > docs/mission/arena-kit/arena-props/previz/arena_kit_specs_dump.log 2>&1

Engine: Godot 4.7.2-stable. Exit 0, JSON between the `SPECS_JSON_BEGIN` / `SPECS_JSON_END`
markers, no `SCRIPT ERROR`, no `PROBE_ERROR`. Guarded with `pgrep -x Godot` before each run
(no engine process was running then; another lane's Godot is running now and this lane did
not start a third run). The dump's extracted body hashes to
`sha256 d7c505e6e353cdac80ce90900aea2fe4d14d11c4531c2e14cac39e5c9eadcf70`; every number in
every PNG, in `plan-data.json` and in `index.html` came from it.

Rebuild the plans (no engine needed):

    python3 tools/arena-kit/previz_2d.py            # reads the log above, writes the previz set

The builder re-derives every instance from the raw table (anchor, spread, repeats, `x_scale`)
and refuses to draw if its numbers disagree with the probe's derived block, if an arena's
count is not the sum of its `repeats`, or if any spec value fails a verdict (exit 2).

## Instance totals (from the dump, all 145 drawn)

| arena | slots | repeats per slot (SLOTS order) | instances |
|---|---|---|---|
| torii | 10 | 1,1,3,2,2,4,4,6,2,2 | 27 |
| medina | 10 | 1,1,4,2,3,4,5,6,3,2 | 31 |
| carioca | 10 | 1,1,3,3,2,4,4,6,3,3 | 30 |
| aurora | 10 | 1,1,4,2,3,4,4,5,2,2 | 28 |
| egeo | 10 | 1,1,3,2,2,4,5,6,3,2 | 29 |
| **total** | 50 | — | **145** |

## Field law and the other planes

**No instance breaks the field law.** Zero slots, in any of the five arenas, put a footprint
front face in front of `z = -8.0`; the nearest front face anywhere is `z = -10.20`
(`front_z = anchor.z + depth / 2`). Also clean: the rear glass plane `z = -10.02` (the
stricter gate), the 3.26 m depth budget, and the authored frame law `|x| + run/2 ≤ 14.35`
for all 50 slots. The plan states this on every panel and the switcher repeats it.

Two things the plan had to draw honestly, both real and neither a defect I was asked to fix:

1. **The frame law is drawn in world metres, where the engine mounts it.** `arena_scenery.gd`
   scales a slot's x by the running preset's own `x_scale`; the probe measured
   `band("default", -12.0).prop_half_x = 19.2828 m`, so `x_scale = 19.2828 / 14.35 = 1.34375`.
   A drawn instance therefore sits at `authored x × 1.34375` (the widest is aurora `furniture`
   at world x = +11.83, i.e. +8.80 authored), and the drawn frame-law verticals stand at
   ±19.283 m world, labelled as `authored ±14.35 × x_scale 1.34375`. The thinner amber line
   beside it is the unscaled ±14.35 so both numbers are on the map.
2. **Ten declared footprints pass behind the backdrop wall.** For every arena the
   `hero_landmark` and `vegetation_cluster` back faces land at `z = -12.15 … -12.50`, which is
   behind `BACKDROP_Z = -12.0` (e.g. egeo `hero_landmark` spans -10.20 … -12.50). The depth
   budget is measured against the glass, not the wall — at `PROP_Z = -11.65` a full 3.26 m
   footprint reaches `z = -13.28` — so this is allowed by the table as written, but a mounted
   piece at full declared depth would poke through the painted wall. Flagged for the owner;
   the plan draws it as it is.

## Outputs (all under `docs/mission/arena-kit/arena-props/previz/`)

| file | what |
|---|---|
| `torii-plan.png` … `egeo-plan.png` | one 2300×1147 panel per arena: court outline, net, service lines, all four planes, slot labels with repeat counts, per-instance footprint boxes with index digits and true-anchor dots, slot table, plane key, instance total, scale bar |
| `all-five-arenas-plan.png` | 2514×2426 combined sheet: five panels in a 2×3 grid plus a legend/totals cell |
| `index.html` | 1.93 MB self-contained switcher — six buttons (five arenas + all five), six base64-embedded PNGs, zero external references, no network |
| `plan-data.json` | the 145 drawn instances with their authored and world x, z, footprint w×d, front/back z and every verdict |
| `arena_kit_specs_dump.log` / `arena_kit_specs.json` | the raw probe stdout and its extracted JSON, for reproducibility |

Sources: `godot/tests/arena_kit_specs_dump.gd` (probe, new), `tools/arena-kit/previz_2d.py`
(builder, new), `docs/mission/arena-kit/arena-props/PREVIZ-RESULT.md` (this file).

The court outline is read from **`res://game/court.gd`** — the script `court_builder.gd`
actually builds the bed and the lines from (`court_len()` 10 m x, `court_depth()` 20 m z,
half-span ±5 / ±10, service `z = ±6.95`, net `z = 0`). `tests/world_arenas_common.gd` restates
the same footprint for the suites; the plan uses the source of truth, dumped by the probe.

## Verified, not asserted

- dump exit 0, 5 arenas x 10 slots, no parse/warning lines; every footprint note parsed and
  its H/D agree with `target_h`/`depth` for all 50 slots
- independent Python re-derivation of all 145 instances: 0 mismatches in x, z, front/back z
- per-arena instance totals equal the sum of the table's own `repeats`: 145 total
- labels: 10/10 slots labelled on every panel and every sheet cell, 0 collision fallbacks,
  0 labels clipped by the map edge (reported by the renderer on each run)
- PNGs non-blank: 2300×1147 each, 3.8k distinct colours, ~52 % non-background pixels; the
  sheet 2514×2426
- `index.html`: 6 embedded PNGs decode to valid 2300×1147 / 2514×2426 images; the shipped
  script was executed under a DOM harness — all six tabs switch the active pane correctly and
  the `1`–`6` keyboard path works
- **not verified by me:** no real browser rendering. The browser tool refuses to run here
  (`browser.use_real_profile` is on and the default browser is not Chromium), and a
  `open -g -a Safari` + AppleScript probe hung on an automation prompt, so I stopped. What is
  proven is the DOM behaviour of the shipped script plus the decodability of its images; the
  visual pass over the PNGs was done on the files themselves.

## Notes and limits

- I edited nothing else: no `git` commands beyond status, no commit, no GLB or asset write, no
  touch of the `feat-native-world-arenas` worktree. I did not append `LOG.md` (outside my
  owned paths) — the parent should log this lane.
- Godot 4.7 wrote `godot/tests/arena_kit_specs_dump.gd.uid` next to the probe, and sibling
  `.uid` files for other scripts appeared from the same engine passes. They are engine
  sidecars, not edits; I left them for the parent to keep or drop.
- **Least confident point:** the drawn x-extent of each footprint comes from the first number
  of the slot's own footprint note (`"W x H x D m - …"`), because the spec entry has `depth`
  but no `width` field — it is the only width the engine holds. The plan is therefore exact
  about the *declared* footprint and silent about the real Meshy mesh, which will not be
  exactly W metres wide. If a slot's GLB measures wider than its note, the plan under-reports
  it and the depth/frame verdicts stay as declared, not as measured.
