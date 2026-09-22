# Luca arena integration — worker report (task `/root/luca_arena_integration`)

**STATUS: ready_for_review.** Workspace `/Users/alessiofantini/Documents/steam-circuit-padel-11m`,
branch `codex/integrate-arena-11m`. No stage, commit, merge or push by this worker; no API calls, no
new Meshy runs, no `.gitattributes`/git-config change, no other worker's file edited.

Source of the port: **f732998**, a **sibling** of HEAD (both branch from `787c579`) — a selective
port, not a merge.

## 1. Changed paths (all inside the brief's owned set)

| path | change |
|---|---|
| `godot/assets/arenas/<arena>/…` | 50 `.glb` + 150 `.jpg` + 205 `.import` + 5 `.png` + 6 `.md` extracted from f732998 with `git cat-file` (real bytes, never pointer text) |
| `godot/game/arenas/arena_kit.gd` | ported from f732998, then the fit repair (§3) |
| `godot/tests/arena_kit_test.gd` | ported verbatim from f732998 (the 252-check intake suite) |
| `godot/tests/arena_kit_specs_dump.gd` (+`.uid`) | ported (spec dump for the 2D plan) |
| `tools/arena-kit/fit_report.gd` | **new** — `--emit` measures every GLB and prints the table row; default mode gates the six spatial laws |
| `tools/arena-kit/render_probe.gd` | **new** — kit-visible vs kit-hidden frame timing in one build |
| `run/tmp/arena-kit/baseline_probe.gd` + `baseline.json` | **new, gitignored** local regression oracle (see §5) |
| `docs/agent-work/luca-arena-integration/…` | this task's contract and evidence |

The five `ground_texture.png` entries showing as `M ` in `git status` are **root's LFS pointer
migration**, not this worker's edit: the worktree bytes are byte-identical to HEAD (1511499 / 998944 /
1249185 / 1135502 / 1374996). `git diff` reports nothing for them because the LFS clean filter maps
the worktree back to the staged pointer.

Not touched: `arena_scenery.gd` (already carries the kit seam here plus another worker's live
bleachers wiring), `bleachers.gd`, `arena_props.gd`, `crowd.gd`, `trees.gd`, character/save/UI code,
`.gitattributes`, git config.

## 2. Named checks — commands, exits, results

```
G=/Applications/Godot.app/Contents/MacOS/Godot
cd /Users/alessiofantini/Documents/steam-circuit-padel-11m
$G --headless --path godot/ --script res://tests/arena_kit_test.gd              # exit 1  FAIL 250/252
$G --headless --path godot/ --script res://tests/world_arenas_field_law_test.gd # exit 1  FAIL 68/88
$G --headless --path godot/ --script res://tests/world_arenas_selection_test.gd # exit 0  PASS 18/18
$G --headless --path godot/ --script tools/arena-kit/fit_report.gd              # exit 0  FIT_VERDICT PASS
$G --path godot/ --rendering-driver opengl3 --resolution 1280x720 \
   res://tests/world_arenas_capture.tscn -- --arenas=torii,medina,carioca,aurora,egeo \
   --presets=default --out=docs/agent-work/luca-arena-integration/evidence/captures  # exit 0 PASS 39/39
$G --path godot/ --rendering-driver opengl3 --resolution 1280x720 \
   --script tools/arena-kit/render_probe.gd -- --frames=90 --warmup=30           # exit 0
```

Logs: `evidence/{arena_kit_test,world_arenas_field_law,world_arenas_selection,fit_emit,fit_gate,capture,render_probe}.log`;
pre-change logs in `baseline/`.

**Inherited vs kit-specific reds.** Both reds in `arena_kit_test` and all 20 in
`world_arenas_field_law_test` are one inherited condition, and none names a kit node:

| check | before | after | cause |
|---|---|---|---|
| `world_arenas_field_law_test.gd` | FAIL 68/88 | FAIL 68/88 | concurrent `Bleachers`/`ArenaProps` reach z `+8.01` / `±3.45` / `±3.00` |
| `arena_kit_test` `regression/the_field_law_still_holds` | (suite absent) | FAIL | same, via the shared `field_law_report` |
| `arena_kit_test` `mount/a_built_arena_keeps_the_field_law_with_the_kit_mounted` | (suite absent) | FAIL | same |
| `world_arenas_selection_test.gd` | PASS 18/18 | PASS 18/18 | — |
| arena-kit-specific assertions (spec, mount, suppression, clean, fit) | — | **all pass** | — |

Field-law delta vs baseline: **0**. Every mounted kit piece is behind the glass, measured piece by
piece (§3). The field-law suite and the bleachers were not touched.

## 3. The repair (three known intake failures), nothing weakened

```
# GLASS: none   # WALL: none   # BUDGET: none
# HONEST: none  # HEIGHT: none # CENTRE: none
FIT_VERDICT PASS
```

1. **Depth budget.** `DEPTH_BUDGET = 3.26 m` is **untouched**, no test edited, no model removed,
   nothing squashed. The band between the rear glass and the backdrop wall became the fit rule
   (`FIT_DEPTH = 1.93 m` = the 1.98 m band minus the 5 cm glass margin); a piece is scaled
   **uniformly** until it fits the band or reaches its authored height. The source's over-budget
   pieces: medina/ornament_accent 2.43→1.90, carioca/hero_landmark 3.71→1.92,
   carioca/ornament_accent 3.62→1.92, aurora/hero_landmark 3.84→1.91,
   aurora/vegetation_cluster 2.36→1.91, aurora/furniture 2.57→1.91, egeo/hero_landmark 3.93→1.91.
   The other 43 keep their authored height. **Those seven heroes now read ~1.9 m tall instead of
   3.6–4.0 m** — the deliberate trade for "no decor crossing the rear glass or disappearing behind
   the backdrop". The alternative (keep 4 m, let 1–2 m stand behind the opaque wall) is Astra's call.
2. **Disappearing behind the backdrop.** 11 anchors re-clamped into the band; worst front margin is
   now +5 cm behind the glass, closest back −11.99 (in front of the −12.0 wall). The source left 23
   pieces behind the wall.
3. **Asymmetric repeat offsets.** Fixed at the root in `mount_slot()`/`_place_piece()`: the repeat
   offset is now the **piece node's** x and the model's own x asymmetry is absorbed on the **child**,
   so both suite checks that read the same placement (node-on-spread, box-centre-on-offset) hold —
   the source's one-line overwrite could not satisfy both. aurora/furniture's 0.466 m drift is gone.
   `fit_report.gd --emit` is **idempotent**: a fresh emit reproduces the table in the file (0/50 rows
   differ).

## 4. Rendering: what the kit costs, measured

Captures (real viewport, `opengl3`, 1280×720): `PASS 39/39`, 5 PNGs in `evidence/captures/default/`,
gated non-vacuous and arena-distinct by the frozen harness. Visually inspected: props read as each
arena's own decor (torii blossom/pagoda/lantern/gravel, medina palms/arch/zellige), all behind the
rear glass, court clear.

Kit visible vs kit hidden, same build, same camera, vsync off, 30 warm-up + 90 measured frames:

| arena | kit meshes | kit tris | visible ms | hidden ms | delta | visible fps |
|---|---|---|---|---|---|---|
| torii | 27 | 111,742 | 7.603 | 7.216 | **+0.388** | 131.5 |
| medina | 31 | 130,512 | 7.703 | 7.334 | **+0.370** | 129.8 |
| carioca | 30 | 127,493 | 7.747 | 7.433 | **+0.314** | 129.1 |
| aurora | 28 | 113,487 | 7.771 | 7.224 | **+0.548** | 128.7 |
| egeo | 29 | 120,113 | 7.909 | 7.316 | **+0.593** | 126.4 |

**Honest limits.** Main-thread wall-clock frame times on **this** macOS desktop GL run (Apple M4), not
GPU frame times and not target hardware; headless timing would be no proof, so the probe refuses it.
The kit costs **+0.31 to +0.59 ms/frame (≈4–7 %)** for 111k–131k triangles per arena — real but
bounded, with no cliff — measured against 5 arenas × 1 preset × 1 camera.

## 5. Exit-time "leaked" warnings — pre-existing pattern, not a new bug

The GL runs end with `50 Mesh / 50 Material / 150 Texture / 50 Instance RID allocations ... leaked at
exit`, plus `ObjectDB instances were leaked at exit`. Those counts are exactly the content: 50 mounted
GLB scenes (1 mesh each), their 150 embedded JPG textures, and their cull instances. They are held by
the **kit's own `static var _scene_cache`**, which is the source's deliberate design ("the cached
runtime load ... the null is cached too" — parsed once, never re-parsed) and which this worker did not
change.

This is an **existing repo pattern, not something the port introduced**: the pre-change baseline logs
already report the same class of warning (`2 RID allocations ... DummyMesh` per type and
`WARNING: 16 ObjectDB instances were leaked at exit`) from the concurrent prop caches — `trees.gd`
documents its own `static var` scene cache for the same reason. The kit simply adds one cached scene
per file it mounts, so the count is proportional to the new content, not per-frame or per-arena.

Two honest consequences, reported rather than fixed: the warnings are process-exit noise in
test/probe runs, but the cache also means the kit's 50 scenes (and their textures) stay resident for
the process lifetime — worth a look if kit memory becomes a budget item. Fixing that lifecycle
(a `release()`/`clear()` seam) is a design change to the source's caching, outside this brief.

## 6. Decisions for Astra / outstanding risks

1. **The seven fitted heroes (§3.1)** — shrink-to-band vs accept partial burial behind the wall.
2. **The inherited field-law red** — `Bleachers`/`ArenaProps` reach z `+8.01`; the field law is a
   z-only rear-band rule, so side-line scenery trips it. Neither the suite nor the bleachers is mine to
   change; the kit neither causes nor can fix it.
3. **LFS** — nothing staged by this worker; the 205 pointers are root's. On disk the 50 GLB / 150 JPG
   are real binaries (`glTF` magic on 50/50, zero pointer text under `godot/assets/arenas/`).
4. **The regression oracle's provenance** — `baseline.json` is the pre-kit build digest, recorded
   locally because the source's own copy was never committed (it was already missing at baseline).
   With suppression off and the `Kit` subtree excluded, `arena_scenery.gd` reads `arena_kit.gd` only
   through `suppressed_kinds()` (→ `[]`) and `mount()` (→ the excluded subtree), so no table value or
   GLB can reach it. What I could **not** reproduce is the source worktree's own number. Deleting
   `run/tmp/arena-kit/baseline.json` returns those two checks to red with no source change.
5. **Not done, deliberately** — `mount_census.gd`, `previz_2d.py`, the Meshy generator scripts and the
   mission dumps were not copied (required tooling only); the `arena_kit.gd` header says so where it
   cites them. No full-suite runs: only the named checks above.
