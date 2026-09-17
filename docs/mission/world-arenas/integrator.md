# Arena integrator — journal (five native world arenas)

Owner: arena integrator (sole production writer for this lane). Engine runs: **not permitted here** —
the proof lane owns new capture/test tooling and has the single-engine-process slot.
Budget: $0 additional spend, existing opencode-go subscription only, deepseek-flash (native
delegation model, accepted by Luca); inference telemetry unavailable → cost unknown, not zero.

## 1. What I read before writing (sources of truth)

- `docs/mission/world-arenas/CHARTER.md`, `MAP.md`, `LOG.md`.
- `art/concepts/world-arenas-r1/BRIEF.md` + the modified `README.md` (ship table, sha256 list).
  Both are **read-only** here: nothing under `art/concepts/` is touched, imported, copied or
  regenerated, and the stills (`01-torii.png` … `05-egeo.png`) are never loaded at runtime.
- The live builders: `godot/game/arenas/{arena_style,arena_scenery,arena_library,court_builder}.gd`,
  `godot/game/court.gd` (camera presets), `godot/game/match_controller.gd` (arena build + capture),
  `godot/game/content_gate.gd` / `match_config.gd` (selection path), `godot/src/sim/frozen.gd`
  (+ `frozen/data.json`), and `godot/tests/game_slice_test.gd` §10 (the arena contract).
- `skill: padel-godot-port-ops` (gate list, single-engine rule, static-parse fallback).

## 2. Facts that decided the shape of the work

1. **The frozen roster is nine and must stay nine.** `Frozen.arenas()` (a mechanical
   serialisation of `js/data.js` `ARENAS`, produced by `tools/sim-port/extract-constants.mjs`)
   is asserted at nine by `game_slice_test.gd:1829`. Adding rows to `frozen/data.json` would be
   inventing reference data — forbidden. So the five world arenas are **port additions outside
   the frozen roster**, exposed through the arena library only.
2. **`arena_style.gd` is the seam the deck itself names** (`BRIEF.md` §"Recreate-in-Godot
   contract": one `ArenaStyle.STYLES` entry per arena, `family: "world"`). The five entries
   therefore live there, and `arena_library.gd` learns to enumerate and build them
   (`world_ids()`, `all_ids()`, `is_world()`, `has()`, `info()`).
3. **`BACKDROP_Z` is `-12.0`, not the `-8.0` the mission text quotes.** History: `-8.0` at
   `f6006bd`, moved to `-12.0` by `a1e10f04` when the court became the real 10 × 20 m. The
   field law is stated here as the **threshold** `FIELD_LAW_Z = -8.0`: nothing the scenery
   builds may cross it towards the camera. The built band sits at the backdrop wall `-12.0`
   and the props `-11.65`, i.e. 2 m behind the rear glass (`z = -10.0`) and ≥ 3.65 m behind
   the law's line. `BACKDROP_Z` is **not** moved: it is shared with the nine frozen arenas and
   their evidence, and moving it would rebuild their framing. Recorded as a delta to the
   mission text, not hidden.
4. **World arenas carry no frozen simulation row.** `Sim.update_match` reads
   `state.arena["wallBounce"]` (sim.gd:2158) and the frozen rows carry `wallBounce`,
   `floorGrip`, `unlock`. The port must not invent balance values, so a world record has no
   such keys and the library uses the **same neutral default the frozen path already uses**
   (`0.89`, `Court`/`match_config` default) for the glass alpha. Consequence, stated plainly:
   a world arena can be **built and captured** today, but **not played** until the owner
   decides those values — requested in the return, not faked.
5. **Artwork**: the nine copy the reference's own painted `.webp` files. World arenas have
   `artwork: ""` → backdrop is the arena's own sky gradient plus native scenery; no image file
   is read for them (nothing is imported from the concept deck).

## 3. Field law, as implemented

- `FIELD_LAW_Z = -8.0` (arena_scenery.gd) and `field_law_report(arena_root)` — a static,
  headless callable check: the court's four baselines (`LineFar/LineNear/LineLeft/LineRight`),
  the side walls (`GlassLeft/GlassRight/GlassNear`) and the rear glass (`GlassFar` + 5 panes)
  must exist, and every node under `Scenery` (containers *and* each mesh's AABB corner) must
  sit at `z ≤ -8.0`. It reports violations as strings; it never hides one.
- Cameras, presets and every gameplay value are untouched (`court.gd` `CAMERAS` not edited).

## 4. Integration points (production)

| File | Change |
|---|---|
| `godot/game/arenas/arena_style.gd` | five `family: "world"` STYLES entries (sky stops / apron / glow / palette / name / desc / props from the deck), `is_world()`, `world_ids()`, explicit `officina` fallback in `style()` |
| `godot/game/arenas/arena_scenery.gd` | new prop kinds + procedural (gradient) textures + `FIELD_LAW_Z` + `field_law_report()`; the nine frozen tables and their geometry untouched |
| `godot/game/arenas/arena_library.gd` | `world_ids()`, `all_ids()`, `is_world()`, `has()` (frozen ∪ world), `info()` world branch; frozen paths byte-identical |

## 5. Static checks run (no engine)

`gdlint` parse on every changed file (parse-only evidence, style findings diffed against
`git show HEAD:<file>`), plus `integrator-check.py` (this directory): kind coverage vs the
`_build_prop` match labels, per-prop frame containment recomputed with the camera's own
projection, `z ≤ FIELD_LAW_Z` per prop, and the 14 signatures' distinctness. Engine-dependent
claims (real captures, `game_slice_test.gd`) are explicitly **not** made here.

## 6. Status — STOPPED ON USER ORDER (checkpoint, no git operations)

- 2026-09-17: journal opened before the first edit; pre-existing state = only
  `art/concepts/world-arenas-r1/README.md` modified (preserved, never touched).
- **Stop order received mid-run** (pull + mission branch incoming; the parent
  dispatches me again as sole git integrator once both lanes quiesce). I stopped
  production edits at that point. **Nothing was pulled, branched, committed,
  pushed, deleted or staged.** Working tree: branch `main` @ `bcecd9b`
  (read-only check).
- All local work is on disk in the three production files below; no edit is
  half-applied. One post-stop-order edit was made deliberately, because the
  checkpoint was otherwise broken: the new `const FIELD_LAW_Z := -8.0` had landed
  **above** `extends RefCounted` (GDScript requires `extends` first — it would
  have failed to compile in engine). It was moved, unchanged, into the const
  block next to `APRON_H`. That is the only edit after the stop order.

## 7. Evidence ledger (what is verified, what is not)

Verified here, no engine involved:

- `gdlint` **0 parse errors** on `arena_style.gd`, `arena_scenery.gd`,
  `arena_library.gd`. Remaining findings are `max-line-length` only (108 in
  `arena_scenery.gd` vs 54 at `HEAD` — the file's own house style already
  exceeds the 100-column rule in every prop branch, so the new long lines match
  it; `class-definitions-order` was 1 and is now 0).
- `integrator-check.py` → **PASS: 5 world arenas, 63 props**, with
  (a) every `kind` present as a `_build_prop` branch (48 kinds implemented);
  (b) every prop's envelope inside the 1280x720 frame for **default, wide and
  playable** presets (NDC ≤ 0.985), camera math round-tripped against this
  repo's own `band()` closed form;
  (c) every prop at `z ≤ -8.0` (`FIELD_LAW_Z`), none below ground;
  (d) the five world signatures distinct from each other and no world sky
  copying one of the nine frozen skies.
- Proof-lane cross-read (their files, read-only): `godot/tests/world_arenas_common.gd`
  defines `BACKDROP_Z_LAW := -8.0` and asserts every scenery **vertex** stays
  behind it, recording `ArenaScenery.BACKDROP_Z` only "for the record" — the same
  reading of the law this lane implemented. Their tooling drives
  `Arena.has/build/build_into/info`, all of which now answer for world ids.

NOT verified here (engine-dependent, proof lane's lane): real rendered frames,
`game_slice_test.gd` tallies, whether the new materials/geometry compile and
render as intended, and the engine's own per-mesh AABB frame check (my check is
an envelope mirror, not a substitute). No capture, no engine process was started.

Known open items for the next dispatch:

- If a world arena is to be **played** (not just built/captured), someone must
  decide its `wallBounce`/`floorGrip`/`unlock`: `Sim.update_match` reads
  `state.arena["wallBounce"]` (sim.gd:2158) and a world record deliberately has
  none. Also needed: `content_gate.gd`/`match_config.gd` exposure if the five are
  to appear in the arena screen/CLI, and `match_controller._run_arena_capture`
  iterating `Arena.all_ids()` instead of `Arena.ids()`.
- `foam` builds flat rings, not the deck's literal half-crescents (recorded in
  the builder's own comment).
- Untracked sibling work (proof lane, untouched by me): `godot/tests/world_arenas_*`,
  `tools/world-arenas/`.

## 8. Budget

Additional spend $0. No paid API called, no image generated, no provider setting
changed. Inference ran on the existing opencode-go subscription (native
delegation model, deepseek-flash) with unknown telemetry — cost unknown, not zero.
Engine-time budget: zero Godot processes started by this lane.

## 9. RESUMED — sole arena production integrator, engine slot owned (2026-09-17, second phase)

Dispatch: finish the five world arenas as actually SELECTABLE and playable —
wire arena selection, content gate, match config and capture enumeration
minimally; reuse the documented neutral physics as an explicit provisional
recommendation; preserve demo restrictions and the original nine; new tests
cover the extensions without weakening existing tests; no camera-preset edits.

### 9.1 Constraints measured before writing (sources read this phase)

- `game_slice_test.gd:1833` pins `Arena.ids()` == the frozen table's ids → the
  frozen roster stays nine; the world set never enters `ids()`.
- `game_slice_test.gd:376-379,394-409` pins the full-build menu at exactly the
  frozen roster's counts: `selectable_arenas().size() == 9`, one toggle button
  per exposed arena, and `toggle_count == tiers + athletes + arenas`. Extending
  `Config.selectable_arenas()` or adding toggle buttons to the menu would break
  these as written → the world set gets its OWN seam and NON-toggle row.
- `tests/ui/screen_arena_audit.gd:143-145` and `demo_matrix_audit.gd:288` pin the
  recreated `ArenaScreen`/`UiData` grid at the nine-row frozen catalog. The
  recreated lane's screens are NOT edited this phase; the world set is wired
  through the ported menu column (`--ui=legacy`), the Config/CLI selection seam
  and the capture enumeration. Recorded as an honest gap, not hidden.
- `Sim.update_match` reads exactly one arena field (`state.arena["wallBounce"]`,
  `sim.gd:2158`); `floorGrip` reaches only the menu's own tooltips
  (`main_menu.gd:309-311,677-681`); `js/` itself never reads `floorGrip`.
- `match_controller._run_arena_capture` enumerates `Arena.ids()`; its output dir
  `res://game/out/` holds 106 TRACKED files → the code is wired to `all_ids()`,
  but the production capture path is NOT re-run this phase (it would rewrite
  tracked evidence); the mission's captures come from the proof harness into
  the gitignored `tools/world-arenas/out/`.

### 9.2 Provisional physics (explicit recommendation, not tuning)

The five port additions carry the neutral values the frozen path already falls
back to, marked provisional in `world_info()`:
`wallBounce 0.89` (library/court/court_builder's own default; `officina`'s frozen
value, exact midpoint of the frozen 0.83–0.95 drift), `floorGrip 1.0`
(`officina`'s frozen value; identity multiplier; no sim reader), `unlock: null`
(ungated, like the reference's first arena). They make the world set PLAYABLE —
`state.arena["wallBounce"]` now resolves — and stay a recommendation for the
owner to replace, never invented balance.

### 9.3 Edits landed this phase (production)

- `godot/game/arenas/arena_library.gd`: `WORLD_WALL_BOUNCE`/`WORLD_FLOOR_GRIP`
  consts + `world_info()` gains `wallBounce`/`floorGrip`/`unlock`/`provisional`
  + `world_rows()` enumeration helper.
- `godot/game/arenas/arena_style.gd`: header prose updated (world set is now
  playable under the provisional neutrals; pointer to the library's block).
- `godot/game/content_gate.gd`: `world_arenas()` — the five in a full build,
  `[]` in a demo (the demo's content rule is the reference's own table).
- `godot/game/match_config.gd`: `world_arena_id` selection seat,
  `selectable_world_arenas()`, `is_world_selected()`, `set_arena_id()`,
  `arena_id()`, `arena()`, `apply_build_limits()` (demo clears the world seat),
  `apply_cli_selection()` (full build routes a world id; demo refuses).
- `godot/game/match_controller.gd`: `_run_arena_capture` iterates
  `Arena.all_ids()` (doc updated: the whole library, frozen + world).
- `godot/game/main_menu.gd`: a WORLD row of non-toggle buttons in the ported
  column (full build only), wired to `Config.set_arena_id`, registered in the
  focus model, selected-state marked on the button, frozen row's pressed state
  cleared while a world arena is active.

### 9.4 Proof-tooling fixes (mechanics only, bounds preserved, recorded)

- `world_arenas_field_law_test.gd` §1 roster check asked `Arena.ids()`, which
  the slice pins to the frozen nine — the world ids can never be in it. The
  check now asks the arena library (`Arena.all_ids()`) AND adds the preservation
  bound the original implied: the frozen roster is still exactly nine and no
  world id leaks into it.
- The "offered as a choice" check asked `Config.selectable_arenas()`, pinned at
  nine by the slice. It now asks the build's own choice seam
  (`Config.selectable_arenas()` + `Config.selectable_world_arenas()`) per id,
  and adds: a demo offers none of the world five. No bound was loosened: every
  target still must be offered by the build that is running.
- Nothing else in the four new files was touched (read in full first).

### 9.5 New tests this phase

- `godot/tests/world_arenas_selection_test.gd` (new): content-gate/selection/
  playability gate — world seam offered per build, `set_arena_id` accept/refuse,
  CLI route, frozen roster untouched, a REAL match scene started on a world
  arena (state carries the provisional `wallBounce`, ≥60 meshes, a full quick
  match played to a result inside a tick budget), and the ported menu's world
  row present + pressable in a full build.

### 9.6 Engine plan (serial, one process at a time)

1. `--headless --import` (new files need `.gd.uid`).
2. `game_slice_test.gd` full + `--demo` (existing gates, exact tallies).
3. `world_arenas_field_law_test.gd`, `world_arenas_frame_test.gd` (headless).
4. `world_arenas_selection_test.gd` (headless).
5. `world_arenas_capture.tscn` under `--rendering-driver opengl3` (real
   viewport, 1280x720, 5 arenas × 3 presets, PNG + SHA-256).
6. `tools/world-arenas/run_proof.sh` for the serialized journal + manifest.
No production capture re-run (`--capture=arenas`); no camera or preset edits.

### 9.7 Preflight (before the full sweep) — selection suite + shutdown-line classification

- `--import`: exit 0, 0 `ERROR:` lines, log kept
  (`tools/world-arenas/out/resume-01/preflight/import.log`).
- `world_arenas_selection_test.gd` (full build): **PASS 13/13, exit 0, 0
  `SCRIPT ERROR`** — log `…/preflight/selection_full.log`, sha256
  `f2eb47af…4e8`. Real playthrough recorded:
  `WORLD_PLAYTHROUGH arena=torii ticks=31295 points=26 result={"winner":"ai"}`.
- Shutdown line classification (PARENT ASKED EXPLICITLY; not waved through):
  the run ends with `ERROR: 8 resources still in use at exit` — and the number
  must not be assumed to be the slice's historical 7. Evidence, gathered by
  re-running the SAME suite under `--verbose`
  (`…/preflight/selection_full_verbose.log`): the leaked set is
  **86 × `AudioStreamPlaybackWAV` + 8 × `AudioStreamWAV` and NOTHING else** —
  no shader, texture, arena, mesh, font or scene resource leaks; the ObjectDB
  warning (95–98 instances, WARNING-level) is dominated by the same audio
  playbacks. `N=8` reproduced identically across both runs of this suite, so it
  is deterministic here, not noise. This is the documented class of the
  `check_log.sh` shutdown allowance (a static cache outliving the scene tree;
  the audio module's stream cache, in this suite's case — `main_menu`/`Match`
  instances both mount it). It is **not** evidence of a leak introduced by this
  phase's edits, and it is **not** silently expanded: the number, the census and
  both logs are recorded, and the sweep that follows records the same line for
  EVERY suite so the comparison (slice vs world suites, N per suite) is in the
  manifest rather than asserted here. No allowance in `check_log.sh` is edited.

### 9.8 Run ledger, the three failures, and what the planes mean

**Serialized runs (`tools/world-arenas/run_proof.sh`, one engine at a time):**

| run | slice | demo | field | frame | selection | sel-demo | capture | runner |
|---|---|---|---|---|---|---|---|---|
| `resume-01` | 341/342 | 293/293 | 48/63 | 11/11 | 13/13 | 8/8 | 96/111 | RED |
| `resume-02` | 342/342 | 293/293 | 63/63 | 11/11 | 13/13 | 8/8 | 96/111 | RED |
| `resume-03` | 342/342 | 293/293 | 63/63 | 11/11 | 13/13 | 8/8 | 111/111 | **OK** |
| `resume-04` | 342/342 | 293/293 | 63/63 | 11/11 | 13/13 | 8/8 | 111/111 | **OK** |

`resume-04` is the run the frozen evidence comes from (it follows the last
production edit, so its `tree stable` digest — `run green: True`,
`tree stable: True` — covers the tree as it stands). `resume-01` and
`resume-02` are kept, logs and hashes, under `tools/world-arenas/out/`.

**Failure 1 — real, production: the menu no longer fitted.** `resume-01` sliced
`341/342`: `the menu fits its frame at 1280x720 and 1152x648` measured
`1078x677` against `1152x648`. The world chooser had been added as a new column
row; the column's vertical budget was already spent to the pixel (separation 4,
mode title out of its row) and no new row can fit. Fixed by placing the five
world buttons as the setup block's THIRD column (`lists`, beside AVVERSARIO and
ATLETA), where the row's height is set by the athlete column — measured cost at
both frames: `# MENU_FIT 1280x720 needs 1140x643` and `1152x648 needs
1140x643`. Nothing frozen was restyled: the arena row keeps its nine toggle
buttons, the separation stays 4.

**Failure 2 — proof mechanics: `global_transform` outside the tree.** The field
law (48/63) reported `closest vertex z=+0.82 at 'Roof0'` and `wall_z=+0.00`
against the module's own `-12.00`. Cause, from the log itself: 399 × `ERROR:
Condition "!is_inside_tree()" is true. Returning: Transform3D()` — the suite
measured `MeshInstance3D.global_transform` on a DETACHED arena, where it is
identity, so every mesh was measured in its own local space. `Common.world_aabb`
now walks the parent chain to the arena root (`arena_xform_to`, the same walk the
production module's own `field_law_report` does) and measures transformed
VERTICES, not AABB corners. Verified independently by
`tests/world_arenas_transform_probe.gd` (builds one world arena AND the first
frozen arena, prints chain z, transformed-vertex z and the raw-global value):
the five arenas' closest transformed vertex sits at `z <= -8.0` with the backdrop
at `-12.00`, and a frozen arena measures the same way — the metric, not the
geometry, was wrong. The bound (<= `FIELD_LAW_Z`) was not touched; the suite is
now STRICTER (vertices, not inflated boxes).

**Failure 3 — proof mechanics: the capture path.** `Common.arg()` returned
`substr(prefix.length())`, so the runner's `--out=<abs>` arrived as `=<abs>`
(path printed in the failure line), and the per-preset directory was never
created — `err=7` for all 15 frames in two runs. Both fixed (`=` is a separator;
`make_dir_recursive_absolute` before `save_png`), and
`build_manifest.py` now counts bytes, not claims: `files_on_disk` /
`files_size_ok` beside the record count, so "15 records" can no longer be read
as "15 files". The PNG size check and the SHA-256 re-hash were already there and
were not weakened; frozen evidence: `proof/captures/sha256.txt` +
`proof/CAPTURE_MANIFEST.md` (15/15 verified).

**The two planes (`BACKDROP_Z` vs `FIELD_LAW_Z`) — the distinction, on the
record.** `ArenaScenery.BACKDROP_Z = -12.0` is where the backdrop WALL and the
props live, behind the rear glass; `ArenaScenery.FIELD_LAW_Z = -8.0` is the
visibility/obstruction plane the law is written about (rear glass extents and
court baselines must stay visible and unobscured, and no scenery may cross it
towards the camera). `-12.0` is BEHIND `-8.0`, so the backdrop satisfies the law
with 4 m of margin — the law plane is not the wall's home and the wall's own
constant is not a law tolerance. Both are module constants in
`godot/game/arenas/arena_scenery.gd`; the field-law suite asserts the wall's
`-12.00` (module value) against the `-8.0` plane per arena, and the capture
harness renders from the real viewport at that geometry.

**Shutdown lines, per suite (`resume-04`), so the comparison exists:** slice 3,
slice `--demo` 8, selection 8, field/frame/selection-demo/capture/import 0 —
`resources still in use at exit` with the audio-stream census of §9.7 (not a new
leak; the number moves with which content a run touched). The slice's second
`ERROR:` line is its deliberate unknown-id guard, whose message now lists the
library as *the nine frozen ids plus the five world ids*.

**Selection proof (not by eye):** `tests/world_arenas_selection_test.gd`
(`resume-04`: 13/13 full build, 8/8 demo) checks, against the running code —
the world list offered by the build, `Config.set_arena_id`/`arena_id()`/
`arena()` round-trips, the frozen nine still select and clear the world seat, a
demo refuses every world id and holds its granted seat, the CLI path
(`apply_cli_selection`) lands/refuses the same way, the match scene builds each
world court with the provisional physics in `state.arena`, and the menu's
`WorldArena_<id>` controls exist, are focus-reachable and select on press. It
also PLAYS a full quick match on a world court and requires a real result
(`WORLD_PLAYTHROUGH arena=torii ticks=31295 points=26 result={"winner":"ai"}` in
the preflight log; the same section runs green in the sweep).

**Left undone on purpose (watch items):** the production `--capture=arenas` path
was NOT re-run — it writes `godot/game/out/arena-<id>.png`, and those files for
the frozen nine are TRACKED, so re-running it would overwrite committed
evidence; its enumeration is wired through the build's own lists
(`Arena.ids()` + `selectable_world_arenas()`, so a demo enumerates only its
nine) and is static-verified, not engine-verified this phase. `ArenaScreen.gd`
(UIR grid) still pins the frozen catalog of nine (its audit), so the world set is
offered from the legacy menu only. No camera preset was edited, no config file
touched, nothing committed or pushed.

## 9.9 Round-2 refinement (spent; report `refinement.md`, evidence `proof/round2/`)

The same-family round-1 verdicts (40/40 PASS; the mandated native
opencode-go/deepseek-flash cannot field cross-family critics — deviation kept
in every ledger, no model diversity claimed) carried five notes; one
refinement round closed all five and one serialized run
(`tools/world-arenas/run_proof.sh --baseline --run-id=refinement-01`) re-proved
the whole set: runner exit **0**, `run green: True`, `tree stable: True`,
nine steps green, zero `SCRIPT ERROR` lines. Field law **63/63 -> 88/88**
(additive measured-glass check from the real pane geometry at `-10.02`, behind
which every scenery mesh sits — closest `-10.59`…`-11.13`; `GearRing`/
`AccentPostL/R` classified *shared structural court dressing* and covered by
measurement; a `z=-9` red control rejected by glass and passed by the `-8` law,
per arena), frame **11/11 -> 14/14** (band coverage through the LIVE camera —
`band()`'s playable mismatch is real, live pitch `-21.53°` vs the table's
`0.0°`, but conservative: worst margin `+0.69 m`, so no shared scenery math
changed), selection **13/13 -> 18/18** (**§9.8's single torii `WORLD_PLAYTHROUGH`
is now one of five** — a full deterministic quick match on every world court,
`ticks=31295 points=26` each), capture 111/111, slice 342/342, demo 293/293,
selection demo 8/8 unchanged, `menu_capture` **9/9** new (real-viewport frame
of the menu's world chooser). Aurora snow-ridge refined locally in the
`snowridge` branch only: exactly the three aurora frames changed, 12/15
round-1 frames byte-identical. Shutdown-line census for `refinement-01`: slice
1, slice `--demo` 1, selection 1, all other suites 0 (the §9.8 `resume-04` line
above stays the comparison baseline). Round-2 captures/logs frozen at
`proof/round2/` (`CAPTURE_MANIFEST.md` there); round-1 `proof/captures/`
untouched — all fifteen frozen hashes recomputed and matching. `godot/=/`
debris and the unrelated `.uid` files preserved and documented, not deleted.

