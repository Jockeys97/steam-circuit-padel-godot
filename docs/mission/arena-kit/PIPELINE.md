# Arena kits — the pipeline, end to end

How a hand-generated prop becomes scenery: **image per slot → Meshy model per slot → GLB
per slot → the engine mounts it, the procedural blockout stays as the fallback.**

The frozen contract is `KIT-STANDARD.md` (same directory). This file is the operating
recipe; when the two disagree, the standard wins and this file is wrong.

| | |
|---|---|
| Slot file the engine reads | `godot/assets/arenas/<arena>/<slot>.glb` → `res://assets/arenas/<arena>/<slot>.glb` |
| Arenas | `torii` `medina` `carioca` `aurora` `egeo` (the five `family: "world"` decks) |
| Slots | `hero_landmark` `gate_portal` `light_source` `vegetation_cluster` `ground_dressing` `ornament_accent` `column_pillar` `railing_segment` `furniture` `signage_banner` |
| Spec table (anchors, heights, repeats, footprint, suppress) | `godot/game/arenas/arena_kit.gd` |
| Intake | `godot/game/arenas/arena_scenery.gd::build()` → `ArenaKit.mount()` |
| Drop inbox (no credentials) | `meshy/inbox/<arena>/<slot>.glb` |
| Puller | `tools/arena-kit/pull_meshy.py` |
| Pull log | `run/tmp/arena-kit/pull-log.jsonl` |

Ten slots, and that is the whole surface: `ground_texture` is deliberately absent — it is
the standard's image-only slot (a tileable material, not a model).

## The recipe — add or modify an arena

1. **Pick the arena and the slot.** Ten slots per arena, T1 first (`hero_landmark`,
   `gate_portal`, `light_source`, `vegetation_cluster`, `ground_dressing`,
   `ornament_accent`) then T2. One Meshy model per slot; the budget is 10 per map.

2. **Generate the slot image.** `art/arena-kits/<arena>/<slot>.png`: square 1:1, ≥1024²,
   pure white seamless background, subject 70–90 % and uncropped, matte surfaces, nothing
   crossing the edge. Use the shared style block from the standard's §4 (the low-poly DNA
   paragraph + the `art/concepts/world-arenas-r1/BRIEF.md` palette). The image side of this
   directory (`build_packs.py`, `gen_assets.py`, `prompts/`) generates the batch and keeps
   `MANIFEST.md` per arena plus `art/arena-kits/INDEX.md` and the spend ledger. Gate: all
   six checklist items pass on every image, reviewed by someone who did not make it (G2).

3. **Meshy settings** (standard §3, unchanged): **Smart Topology**, image-to-3D, 100–15,000
   faces, 2K PBR texture, **origin bottom**, one model per image, **no rig, no pose, no
   symmetry**. Keep each prop one connected solid mass; thin/openwork pieces (lantern
   screens, railings, banners) must be authored chunky or split into their own slot. Remesh
   after texturing breaks UVs — texture last.

4. **Land the GLB in its slot** — either way, never hand-copy into `godot/assets/`:
   - **Drop (no credentials):** put the download at `meshy/inbox/<arena>/<slot>.glb`, then
     ```
     python3 tools/arena-kit/pull_meshy.py --from-inbox --arena torii --slot hero_landmark
     python3 tools/arena-kit/pull_meshy.py --from-inbox --all          # every inbox file
     ```
   - **Pull by task id (needs the key):** `--arena <arena> --slot <slot> --task <meshy-id>`
     — the key is read from `$MESHY_API_KEY` or `~/.config/meshy/api_key`. Meshy keeps a
     finished asset for **3 days** and its URLs are signed and time-limited, so pull
     immediately (the standard says the same).
   - Verify: `python3 tools/arena-kit/pull_meshy.py --report` — what is in place, from
     which source, and whether the bytes still match the log. The write is atomic
     (temp + rename) and sha256'd into `run/tmp/arena-kit/pull-log.jsonl`, so a second run
     is a no-op.
   - Not good enough yet? `--retire --arena <arena> --slot <slot>` takes it back out
     (logged); re-generated model? `--force` re-pulls.

5. **Spec entry — only when something changed.** A GLB dropped at an existing slot path is
   picked up with **no code change at all**: the anchor, target height, repeat count and
   footprint already exist for all 5 × 10 slots. Touch the spec table only when:
   - a **new slot** is specified (amend `KIT-STANDARD.md` first — the slot set is frozen),
   - an **anchor moves** or a **prop needs a different height/repeat/footprint**, or
   - a slot should **stand in place of** its procedural prop (`suppress = true`).

   Each `SPECS` entry is `anchor` (`Vector3(x_authored, y_ground_contact, z_world)` in
   metres — `x` is in the authored prop frame the style tables use and gets the running
   preset's `x_scale`, `y` is the ground contact, `z` is the footprint centre, behind the
   field-law plane `z = -8.0`), `target_h` (metres), `repeats`, `spread`, `depth`,
   `footprint` (a human-readable note), `suppress` (default **false**). `x_scale` per preset
   is handled by the engine, so an arena added at `wide` needs nothing new.

6. **Engine check (headless, one process at a time — the discipline below is not optional):**
   ```
   bash run/tmp/arena-kit/evidence/run_step.sh kit arena_kit 600 \
     /Applications/Godot.app/Contents/MacOS/Godot --headless --path godot/ \
     --script res://tests/arena_kit_test.gd
   ```
   Green means: the spec table is valid, an empty kit reproduces the pre-change build byte
   for byte, and a real GLB placed at a slot mounts at its spec transform, size, material
   and with nothing left behind. Do not eyeball a build without this.

7. **Engine captures.** An authored GLB is the one thing that must be looked at:
   ```
   /Applications/Godot.app/Contents/MacOS/Godot --path godot --rendering-driver opengl3 \
     --resolution 1280x720 res://tests/world_arenas_capture.tscn \
     -- --arenas=torii --out=run/tmp/arena-kit/captures
   ```
   (the full battery, including captures, is `tools/world-arenas/run_proof.sh`). Then the
   taste gate: council round on the assembled arena vs its concept still (G5), Luca's
   verdict last, never self-approved.

8. **Re-run the frozen suites** (they are the regression net from step 5's promise — with
   no files in `godot/assets/arenas/` the built tree is identical to the pre-kit tree):
   ```
   bash run/tmp/arena-kit/evidence/run_battery.sh after godot        # all eight
   ```
   | suite | command | green means |
   |---|---|---|
   | `game_slice_test` | `--headless --path godot --script res://tests/game_slice_test.gd` | the game slice, full build |
   | `game_slice_test --demo` | … `-- --demo` | the same in demo build |
   | `world_arenas_field_law_test` | `--script res://tests/world_arenas_field_law_test.gd` | nothing in front of the plane / glass |
   | `world_arenas_frame_test` | `--script res://tests/world_arenas_frame_test.gd` | every prop inside the frame |
   | `world_arenas_selection_test` (+ `--demo`) | `--script res://tests/world_arenas_selection_test.gd` | arena choice/lock matrix |
   | `arena_selector_contract_test` | `--script res://tests/ui/arena_selector_contract_test.gd` | the selector contract |
   | `screen_arena_audit` | `--script res://tests/ui/screen_arena_audit.gd` | the arena screen in a real router |

## Suppression (default OFF)

A slot is **additive**: the GLB mounts at its anchor and the procedural prop keeps
building. Setting `"suppress": true` on a slot makes its matching procedural prop kinds be
skipped **when a GLB is present** (`ArenaKit.suppressed_kinds(arena)`, a pure function of
the table and file presence; the `Dressing_*` container is still built, so the "one
container per authored prop" invariant the frozen suites pin stays whole). Because it is a
pure function, a suite can prove the skip path with `ArenaKit.suppress_overrides` without
editing the frozen table — that is exactly what `arena_kit_test.gd` does (`suppress/…`).

## The engine side, if you have to touch it

```gdscript
ArenaKit.has_kit("torii")                        # any slot filled?
ArenaKit.has_kit("torii", "light_source")        # that slot filled?
ArenaKit.slot_report("torii")                    # per slot: loaded|procedural + resolved path
ArenaKit.mount(scenery, "torii", ctx)            # called by arena_scenery.gd::build()
ArenaKit.mount_slot(parent, "torii", slot, ctx)  # one slot, returns the node or null
ArenaKit.anchor_at("torii", "hero_landmark", xs) # the resolved anchor for a preset's x_scale
ArenaKit.suppressed_kinds("torii")               # kinds the kit is skipping (empty by default)
```

## Evidence

Every claim above is a run, journalled in `run/tmp/arena-kit/evidence/` (see that
directory's `README.md` for the full table; `results.tsv` is the journal, `logs/` holds each
run's stdout, `baseline.json` is the pre-change tree digest).

| suite | before | after |
|---|---|---|
| `game_slice_test` | FAIL 344/345 ¹ | FAIL 344/345 — same check |
| `game_slice_test --demo` | FAIL 295/296 ¹ | FAIL 295/296 — same check |
| `world_arenas_field_law_test` | PASS 88/88 | PASS 88/88 |
| `world_arenas_frame_test` | PASS 14/14 | PASS 14/14 |
| `world_arenas_selection_test` (+ `--demo`) | PASS 18/18 · 8/8 | PASS 18/18 · 8/8 |
| `arena_selector_contract_test` (+ `--demo`) | PASS 30/30 · 17/17 | PASS 30/30 · 17/17 |
| `screen_arena_audit` | PASS 180/180 | PASS 180/180 |
| `arena_kit_test` (this pipeline) | — | **PASS 83/83** |

¹ Pre-existing, on the untouched tree: `locale table sizes match the reference (688 keys
each): expected true, got it=689 en=689` — one failing check per mode, identical before and
after (another lane's locale key).

The empty-kit gate is proved against `baseline.json`, a digest of all five arenas built
from `arena_scenery.gd` **at HEAD** (recorded in a controlled copy of the project with only
this lane's edits reverted), and re-checked at the end of the suite after both fixtures are
removed: the tree must come back byte-identical. The fixture gate drops a real GLB and the
repo's own athlete GLB at slot paths in turn, asserts the mount node, the spec transform,
the size, the material policy, the absence of collision and the field law, then removes both
and fails if any `.glb` is left under `godot/assets/arenas/`.

## Measured gotchas (each one cost a run)

- **`ResourceLoader.exists()` is FALSE for a dropped GLB** — measured on the fixture:
  `ResourceLoader.exists("res://assets/arenas/torii/light_source.glb")=false` while
  `FileAccess.file_exists(…)` = `true`. Godot only knows a file the editor has imported;
  nothing in this pipeline imports slot files (the whole point is that a drop needs no
  editor pass). The intake therefore guards on `FileAccess.file_exists()` and parses with
  `GLTFDocument`. **This is the one place this lane departs from KIT-STANDARD §5's
  "ResourceLoader.exists then runtime GLTFDocument"** — taken as written, the guard would
  never fire and the kit would be dead on arrival. Report it to the standard's owner rather
  than editing the frozen file.
- **Never record Godot's auto node names in a regression digest.** `@MeshInstance3D@2`
  counts per process, so the same arena built twice differs; `arena_kit_test.gd` and the
  baseline probe mask them to `<auto>`. (This is what made the first baseline comparison
  fail on 14 nodes of pure noise.)
- **A skinned source is measured in mesh space, not through the node chain.** A rigged GLB
  arrives with an `Armature` at 0.01 scale, so the chained AABB is centimetres and the prop
  mounts 100× too tall; the kit detects `skin != null` and uses the mesh-space box
  (metres). Slot assets are meant to be static, and the standard's "never `get_aabb()` on a
  skinned mesh" rule is honoured on the chain walk — a rigged drop-in still mounts, at the
  mesh's own scale, which is the honest fallback rather than a silent 100× error.
- **`ArenaScenery.field_law_report()` measured nested scenery wrongly** before this lane:
  it multiplied the *holder's* transform by the mesh's own, so a piece under
  `Kit/Slot_<slot>/Piece` read as if it stood at the kit node's origin, and its carrier had
  no meshes of its own to measure. It now walks the full chain to the arena root (the same
  product the world-arena suite uses) and measures a container without geometry as
  "nothing drawn" instead of "a violation at its origin". For today's trees — one mesh
  directly under each `Dressing_*` — both products are the same number.
- **Keep GODOT's engine discipline**: `flock -w 900 /tmp/padel-godot.lock` around every
  run, `pgrep -x Godot` first, one process at a time. macOS ships no `flock`, so this lane's
  runner uses its own shim (`run/tmp/arena-kit/bin/flock`). The runner treats a **missing
  `PASS n/n` tally or any `SCRIPT ERROR` as a step failure** — a parse error exits 0 with no
  tally, which is exactly how a red run can look green.
