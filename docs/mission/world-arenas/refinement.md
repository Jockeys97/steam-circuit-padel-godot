# World-arena refinement — round 2 (final bounded refinement, proof coverage)

Owner: arena integrator, sole production writer *and* engine slot for this
round (both lanes unified; engine run serially, one process at a time).
Date: 2026-09-17. Branch `feat/native-world-arenas`, HEAD `bcecd9b` — **no
commit, no push, no deletion, $0 additional spend, no paid call, no provider
change.** Reference deck `art/concepts/world-arenas-r1/` untouched, including
the pre-existing modified `README.md`.

Sources read before writing: `docs/mission/world-arenas/{COUNCIL.md,CHARTER.md,
LOG.md,integrator.md,MAP.md}`, the production files below, the proof suites and
`tools/world-arenas/*`, `docs/wayfinder/evidence/*` where they bear on the law.

## 1. What the round-2 review asked, and what landed

Round 1: two independent same-family reviewers scored all 40 gating items PASS
(**same-family review only — no cross-family claim; the mandated single native
model cannot produce a heterogeneous council, recorded in COUNCIL.md and kept
in every report**), with five concrete notes. One refinement round was
available; this is it. Items, exactly as dispatched:

| # | review item | what landed | where |
|---|---|---|---|
| 1 | keep the mandated `z<=-8` law and ADD an independent dressing-behind-the-ACTUAL-rear-glass check from real rear-glass geometry; cover `GearRing`/`AccentPostL/R` or classify them; red control: scenery at `z=-9` rejected by glass safety | new measured-glass check (plane from the six `GlassFar*` panes' own geometry: `-10.02`), red control at `z=-9`, `GearRing`/`AccentPostL/R` classified as shared structural dressing **and** covered by measurement; the `-8` law untouched and still gated | `godot/tests/world_arenas_common.gd`, `world_arenas_field_law_test.gd` |
| 2 | selection test completed an actual match only on `torii`; play ALL five with exact per-arena logs | five full deterministic playthroughs, one `WORLD_PLAYTHROUGH` line per arena, one gated result each | `godot/tests/world_arenas_selection_test.gd` |
| 3 | capture the real menu showing the world chooser, fresh output path | new `world_arenas_menu_capture` harness + step: real `Main.tscn` (ported legacy column), real viewport, `captures/menu/menu-world-chooser.png`, gated + hashed | `godot/tests/world_arenas_menu_capture.gd/.tscn`, `tools/world-arenas/run_proof.sh`, `build_manifest.py` |
| 4 | aurora snow-capped ridge readability — modest, local, behind glass, inside the band, never touch cameras | `snowridge` branch only: rock lifted one step, caps larger (`0.38r/0.40h` -> `0.52r/0.46h`) and brighter; `_peak` and every other arena untouched | `godot/game/arenas/arena_scenery.gd` |
| 5 | investigate `band()` playable pitch mismatch; do not change shared/frozen scenery math unless proven necessary | investigated with engine rays: the mismatch is REAL (playable camera is oriented by `look_at`, live pitch **-21.53°** vs the table's `0.0`), the band is nevertheless **conservative** at every preset (worst margin `+0.69 m` top / `+2.04 m` width), so the shared math was NOT changed; the live coverage is now a permanent gated check | `world_arenas_band_probe.gd` (diagnostic), coverage gate in `world_arenas_frame_test.gd` |

No other aesthetic change was made. The proof suites' bounds were never
loosened — the field-law suite is stricter (a second, tighter plane), the frame
suite is stricter (a new coverage gate), the selection suite is stricter (five
played matches instead of one). Nothing was removed from any suite.

## 2. The run

```
tools/world-arenas/run_proof.sh --baseline --run-id=refinement-01
```

Runner exit **0**; manifest `run green: True`, `tree stable during run: True`
(`6e0dad26fcce00fc -> 6e0dad26fcce00fc`). Fresh run dir
`tools/world-arenas/out/refinement-01/`; frozen copy (frames, records, logs)
under `docs/mission/world-arenas/proof/round2/`. **Round 1
(`docs/mission/world-arenas/proof/captures/`, `resume-04`) was not overwritten:
all fifteen frozen hashes recomputed after the run still match
`proof/captures/sha256.txt`, byte for byte.**

| step | exit | tally | SCRIPT ERRORs | log sha256 |
|---|---|---|---|---|
| import | 0 | — | 0 | `f5e9e5ef7688742ecb05464fcd8230f4fa6d226ec7963d22d3831695ae9f5fdc` |
| baseline_slice | 0 | PASS 342/342 | 0 | `b32a7ad8c600b529f26aa8cf250e6ef8aea8e230d0743bf08e16f24b675d4e5d` |
| baseline_demo | 0 | PASS 293/293 | 0 | `c66cdb1bb7370e12ca7c38e7362ce27a532d4c2a708f1cd8ff31f97e364fa10a` |
| field_law | 0 | PASS 88/88 | 0 | `5e59eb6aea4867bdf332c333928d93cb4a22e0c918c511c418b8a34a070bc93c` |
| frame | 0 | PASS 14/14 | 0 | `c21d0aa27b09c2625bad92c4ed46f42c0fd60c0dd5d87dc365d4f7c3349d44eb` |
| selection | 0 | PASS 18/18 | 0 | `332032869c536d622028a4b1be879607bf1fa017ecd10101d1372b462ef6fce2` |
| selection_demo | 0 | PASS 8/8 | 0 | `0fc3e68c0eb834168ab4003ae2bf5aff71d8570455bb2a42106aa356d4bf3c2c` |
| capture | 0 | PASS 111/111 | 0 | `485c2a6e17feebb9f17d3e0dabc8389b142c8097804843b1a884d65828292c49` |
| menu_capture | 0 | PASS 9/9 | 0 | `4c4b4405d931ea99800b4db784229324373c3edadec9223e571781de8018d9cd` |

`grep -c 'SCRIPT ERROR'` over all nine logs: **0**. Shutdown lines
(`resources still in use at exit`): slice 1, slice `--demo` 1, selection 1,
every other suite 0 — logged for comparison with `integrator.md` §9.8, no
allowance in `check_log.sh` edited, no new leak claimed.

Tallies vs round 1: slice `342/342` and demo `293/293` unchanged; field law
`63/63 -> 88/88` (25 new: glass plane + behind-glass + structural, per arena,
plus the red control pair); frame `11/11 -> 14/14` (the band-coverage gate per
preset); selection `13/13 -> 18/18` (four more playthroughs + a summary check);
selection demo `8/8` unchanged; capture `111/111` unchanged; `menu_capture
9/9` new.

## 3. Source digest and delta

`tools/world-arenas/tree_digest.py` (tracked files under `godot/game`,
`godot/src`, `godot/tests`, `godot/project.godot`):

- round 1 (`ceo-verify-01`): `9661fc8add2d1908` (695 files) — round-2 edits change it;
- round 2 (`refinement-01`): `6e0dad26fcce00fc` before **and** after the run
  (695 files; the run is the only writer and it touches nothing).

Files this refinement edited (tracked, sha256 of the working-tree bytes):

| file | sha256 | change |
|---|---|---|
| `godot/game/arenas/arena_scenery.gd` | `948bde7a1d93ee9f0e02ba905919929dce1800461df174e15ba825dff2af8379` | `snowridge` branch only (+ comment) |
| `godot/tests/world_arenas_common.gd` | `11d7c1f2de1ea57ccf7602315dfb51f2c5a20e9f709d1dea2fbf3c49799673e0` | glass plane, structural report, `behind_glass`, live band requirement |
| `godot/tests/world_arenas_field_law_test.gd` | `cb39b2a28d7c2651ebcf908715cc5af038cef22a0d21dea05d880e07e1bebad0` | new checks + red control |
| `godot/tests/world_arenas_frame_test.gd` | `1eec7ae0c9f1cbf0ae82916e72894562e7f871bbd0beef5283cb34bd767734f7` | band-coverage gate |
| `godot/tests/world_arenas_selection_test.gd` | `ec9aab135348b872154fa0ca05f79fd27a35e1b3290ef483a8daba59ff6d192a` | five playthroughs |
| `tools/world-arenas/run_proof.sh` | `26c639511b726a9a4c837fe14cd7a96fa5f3c6e43412b41e6dc9e2bd72b23ca7` | `menu_capture` step (selection watchdog 900s) |
| `tools/world-arenas/build_manifest.py` | `4092e3ee2c740dba3c07bd1bb61d402f3b70c7789c1ee2bb8f2d7f161ceda914` | folds the menu capture record |

Files this refinement added (untracked-new, proof lane only):

| file | sha256 |
|---|---|
| `godot/tests/world_arenas_menu_capture.gd` | `7d5ec523df6cf7963a91d710a0060b5099856674a7201d2b4abef6d4ff95045f` |
| `godot/tests/world_arenas_menu_capture.tscn` | `3dc857d7eaf64c50ab5da0e4259e187eab70489e2de917a0abb66ee00e8d4b75` |
| `godot/tests/world_arenas_band_probe.gd` | `3c5d1f71d71be9387c11384afa85beec0a427c773c5bc51e79d3a62804a8dcc3` |

(Their engine-generated `.gd.uid` sidecars appeared on the official run's
`--import` step; they are untracked, like the rest of the proof lane's files.)

Unchanged by this refinement, for the record: `arena_style.gd`
(`e4955a2d…`), `arena_library.gd` (`129a117b…`), `content_gate.gd`
(`f2cbb511…`), `main_menu.gd` (`e0f80b9b…`), `match_config.gd` (`faada02b…`),
`match_controller.gd` (`43572cd3…`), `world_arenas_capture.gd` (`93f09110…`),
the other probe suites, `court.gd` (never edited in any phase).

## 4. Item 1 — the glass safety, the structural dressing, the red control

Producer: the official run's `logs/field_law.log` (frozen copy under
`proof/round2/logs/`). The mandated plane is untouched: `PASS 88/88` includes
every round-1 check (`closest vertex z <= -8`, wall behind the plane, no
overlap with the playable footprint, intact glass, presets).

Measured glass plane (from the six panes' own vertices, not the constant):
`measured glass z=-10.02 at GlassFar` (per arena; `court_builder.build_rear_wall`
puts the panes at `-hd - 0.02`).

Dressing behind the actual glass, per arena (`closest scenery vertex vs
measured glass plane`):

| arena | closest scenery z | mesh carrying it | margin behind glass |
|---|---|---|---|
| torii | `-10.83` | `Roof0` | 0.81 m |
| medina | `-11.13` | `Base` | 1.11 m |
| carioca | `-10.59` | `Skirt` | 0.57 m |
| aurora | `-11.10` | `Column1` | 1.08 m |
| egeo | `-11.12` | `House0` | 1.10 m |

This is the stricter, geometry-measured twin of the `-8` law, and it is
independent of it in exactly the way the review asked for:

```
ok arena 'torii' every scenery mesh stays behind the MEASURED rear glass (closest z=-10.83 at 'Roof0' vs glass z=-10.02)
ok RED CONTROL arena 'torii': scenery at z=-9 is REJECTED by the glass safety (closest vertex z=-9.00 > measured glass z=-10.02)
ok RED CONTROL arena 'torii': the SAME z=-9 dressing is NOT a violation of the mandated -8 plane (the checks are independent)
```

The red control (a `Dressing_RedControl` box whose nearest vertex sits at
`z = -9.0`, added to the built tree inside the suite, measured by the same walk,
then removed) runs for **every** arena — five `REJECTED` checks and five
independence checks, all `ok` in the log. `z=-9` is behind `-8` and in front of
the glass: one check passes it, the other rejects it. If either half stopped
discriminating, the suite fails.

`GearRing` / `AccentPostL/R` are shared structural dressing built by
`court_builder.gd` into every arena (frozen nine included), outside `Scenery/`,
so the scenery walk cannot see them. They are now **explicitly classified and
covered** — measured, not assumed (`STRUCTURAL` lines, five arenas, identical):

- `GearRing` nearest vertex `z=-11.35` — behind the measured glass `-10.02`;
- `AccentPostL/R` at `z=+3.40`, `x=±7.0` — outside the cage laterally
  (`|x| > 5`), i.e. never over the playable footprint;
- classification string in every line: *shared structural court dressing
  (court_builder.gd), identical in every arena including the frozen nine; not
  arena scenery*.

## 5. Item 2 — all five arenas played through

Official run, `logs/selection.log` — five full quick matches, deterministic
(harness match node, fixed `1/120 s` tick, the same `ScriptedPlayer`, the same
provisional physics), one exact line per arena:

```
# WORLD_PLAYTHROUGH arena=torii   ticks=31295 points=26 result={ "winner": "ai" } score=0-0
# WORLD_PLAYTHROUGH arena=medina  ticks=31295 points=26 result={ "winner": "ai" } score=0-0
# WORLD_PLAYTHROUGH arena=carioca ticks=31295 points=26 result={ "winner": "ai" } score=0-0
# WORLD_PLAYTHROUGH arena=aurora  ticks=31295 points=26 result={ "winner": "ai" } score=0-0
# WORLD_PLAYTHROUGH arena=egeo    ticks=31295 points=26 result={ "winner": "ai" } score=0-0
```

The five results are identical *and that is the expected determinism*: the five
provisional records carry the same neutral `wallBounce` (0.89) and the sim reads
no other arena field, so the same scripted match must replay the same way — and
it does, on every court, from a fresh match node each time. `torii`'s round-1
numbers (`ticks=31295 points=26`) reproduce exactly, which is further
consistency evidence, not a copy: each arena instantiates its own scene and
plays its own 31,295 ticks. Selection's own watchdog was raised 300s -> 900s
(measured: the whole suite runs in ~10 s).

## 6. Item 3 — the real menu with the world chooser

New step `menu_capture` (`9/9`), real viewport, fresh output path
`<run>/captures/menu/menu-world-chooser.png` (never round 1's):

```
MENU_CAPTURE_RECORD png=…/refinement-01/captures/menu/menu-world-chooser.png px=1280x720 colours=122 buttons=5 min_margin=138.0px sha256=c8bf28c1cc1b42e375e01ab5b0882d0a903b936645a372f2d68bf21b9e0a4d4f
```

Gated in-run: not headless; FULL build (the chooser exists only there); the
real `Main.tscn` built its `MenuColumn`; one `WorldArena_<id>` button per world
arena — present, visible in tree, non-empty rect, fully inside the 1280x720
frame (min margin 138.0 px); frame is the full render target at the documented
size; non-vacuous (122 colours); PNG saved and hashed. `menu_capture.json`
records each button's rect, text and the colour sampled from the PNG at its
centre (e.g. the chooser column reads `MONDI (5)` + `TORII / MEDINA / CARIOCA /
AURORA / EGEO`); the frozen copy is
`proof/round2/captures/menu/menu-world-chooser.png`. Visual check of the frame
(independent read of the PNG): the ported menu shows AVVERSARIO / ATLETA /
MONDI columns, the nine-arena row, and the world chooser is legible.

## 7. Item 4 — aurora snow-ridge readability (local, behind glass)

Only the `snowridge` branch changed (aurora's deck line): rock
`tint.lightened(0.06)`, snow caps `crest_r*0.38 -> *0.52` wide,
`crest_h*0.40 -> *0.46` high, base `crest_h*0.60 -> *0.56`, colour
`(0.86,0.91,0.96) -> (0.90,0.94,0.98)`. `_peak` (shared with carioca's `ridge`)
untouched; no z change (the container keeps its table z, `-11.65`, well behind
the `-10.02` glass); no camera touched; band untouched.

Result, measured: **12 of 15 round-1 arena frames are byte-identical**; only
the three aurora frames differ, in a small upper-band region and strictly
brighter (pixel diff vs round-1 frozen PNGs, threshold 2 levels):

| preset | changed bbox | changed px | % of frame | mean value in region |
|---|---|---|---|---|
| default | (518, 78, 812, 154) | 12,959 | 1.406% | 109 -> 137 |
| wide | (578, 174, 743, 215) | 3,993 | 0.433% | 107 -> 143 |
| playable | (566, 246, 767, 298) | 5,798 | 0.629% | 109 -> 134 |

Both the frame suite (dressing fully inside the frame, all three presets) and
the capture suite (framing mandate through the live camera, 111/111) still pass
with the new caps; the worst frame margins are unchanged (`55.1 / 132.8 /
38.3 px`).

## 8. Item 5 — `band()` vs the playable camera (investigation, no math change)

The mismatch is real and was measured, not inferred. `ArenaScenery.band()`
derives the band from the preset's `pitch_deg` with a pure-pitch closed form;
`Court.build_camera` orients `default`/`wide` by `rotation_degrees =
(pitch_deg, 0, 0)` (matches the closed form) but `playable` by
`look_at(0, 0.9, -1)`. `integrator-check.py` records exactly this ("the closed
form is for a pure-pitch camera; look_at needs the basis") and skips the
playable round-trip. New diagnostic `world_arenas_band_probe.gd` (headless,
read-only; log also frozen at `proof/round2/logs/band_probe.log`) measured
through the engine's own rays (`Camera3D.project_ray_normal`):

```
# BAND_PROBE preset=default  cfg_pitch=-36.03 live_pitch=-36.03 band_top=5.49  required_top=4.80  margin_top=+0.69
# BAND_PROBE preset=default  band_half_x=23.54 required_half_x=20.70 margin_half_x=+2.84
# BAND_PROBE preset=wide     cfg_pitch=-50.00 live_pitch=-50.00 band_top=11.94 required_top=11.06 margin_top=+0.88
# BAND_PROBE preset=wide     band_half_x=38.92 required_half_x=36.88 margin_half_x=+2.04
# BAND_PROBE preset=playable cfg_pitch=+0.00  live_pitch=-21.53 band_top=25.75 required_top=12.30 margin_top=+13.45
# BAND_PROBE preset=playable band_half_x=33.34 required_half_x=30.58 margin_half_x=+2.76
```

Conclusion, on the record: the playable preset's real pitch is **-21.53°**
where the table says `0.0`, and the band built from `0.0` is nevertheless
**conservative** for that camera — it over-covers (top +13.45 m of slack) and
still covers width (+2.76 m). Nothing was proven broken, so the shared/frozen
scenery math was **not changed**. Instead the claim is now permanently gated by
the live camera in the frame suite (one new check per preset, `BAND_COVER`
lines above, `PASS 14/14`), so a future edit that moves the presets or the band
out from under each other fails loudly. Watch item for the owner: if the
playable camera's `look_at` is ever re-aimed at the court centre, re-read this
probe before trusting the band's slack.

## 9. Preservation, constraints and budget

- **Round 1 untouched**: `proof/captures/` re-hashed after the refinement run —
  15/15 match; no round-1 file was read as input, edited or regenerated.
- **`godot/=/` debris and the unrelated import `.uid` files preserved**:
  `godot/=/{Users/lucafantini/Desktop/…}` (malformed capture path debris) and
  the 15 pre-existing unrelated `.uid` files (`_probe_*`, `demo_matrix_audit`,
  `uir*` …) are all still in place, untracked, documented here rather than
  deleted (`git status --porcelain` shows them unchanged). The pre-existing
  modification `art/concepts/world-arenas-r1/README.md` is untouched.
- One diagnostic hygiene note, documented rather than hidden: the menu-capture
  *smoke test* (preflight, before the official run) was invoked with a relative
  `--out=`, which Godot resolves against the project dir — the PNGs landed
  under a temporary `godot/tools/…` path. They were moved into the gitignored
  `tools/world-arenas/out/preflight-refinement/menu-captures/` and the empty
  tree removed; no tracked file was touched. The official run always passes an
  absolute `--out`.
- **No commits, pushes, merges, deletions, config changes or paid calls.** The
  only deletions were of that smoke-test's own empty directories (created
  minutes earlier by the same diagnostic).
- Budget: $0 additional spend. Inference on the existing opencode-go
  subscription, native deepseek-flash (telemetry unavailable: cost unknown,
  not zero). Engine: all runs serialized behind the `pgrep -x Godot` guard —
  preflight (1 import, ~15 parse-only `--check-only` runs, 2 band-probe runs,
  one smoke run each of field-law/frame/selection/menu-capture) then the 9
  official steps; no two engine processes ever overlapped. Two attempts per
  gate were available and **one** was needed per gate in the official run; the
  refinement budget is now spent (this was the single refinement round).

## 10. Evidence handles

- Run dir (logs, `results.tsv`, `MANIFEST.json/.md`, captures):
  `tools/world-arenas/out/refinement-01/`
- Frozen round-2 copy (frames, records, logs, manifest):
  `docs/mission/world-arenas/proof/round2/` — see `CAPTURE_MANIFEST.md` there
- Frozen round 1 (untouched): `docs/mission/world-arenas/proof/captures/` +
  `proof/CAPTURE_MANIFEST.md`
- Preflight diagnostics (parse checks, band probe, menu smoke):
  `tools/world-arenas/out/preflight-refinement/`
- Key log lines quoted above live in
  `proof/round2/logs/{field_law,frame,selection,menu_capture,capture}.log`.
- Colour/vision checks of the frozen frames were done against the PNGs in
  `proof/round2/captures/` only; no reference art was imported anywhere.
