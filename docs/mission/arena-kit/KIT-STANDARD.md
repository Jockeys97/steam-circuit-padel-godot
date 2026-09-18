# Arena Kit Standard v1 — FROZEN 2026-09-18

The contract that makes arena creation and modification repeatable: **image per slot →
Meshy model per slot → GLB per slot → engine mounts it, procedural blockout stays as
fallback**. Frozen by the CEO after the five-lane scan (`scan/*.md`, 2,937 lines).
Amend only by a dated edit in this file plus a `LOG.md` entry.

## 1. The slot set (10 + 1 image-only)

| # | slot | tier | repeats/arena | role |
|---|---|---|---|---|
| 1 | `hero_landmark` | T1 | 1 | the identity mass on the horizon (pagoda, minaret, sugarloaf, ice spire, caldera rim) |
| 2 | `gate_portal` | T1 | 1 | the arrival piece (torii, arched gate, quay arch, cairn marker, chapel door) |
| 3 | `light_source` | T1 | 3–6 | emissive accent (stone lantern, brass lamp, festoon, aurora braziers, wind-light) |
| 4 | `vegetation_cluster` | T1 | 2–4 | organic contrast that hides seams (cherry/bamboo, palm, banana/tree-fern, moss-rock, olive) |
| 5 | `ground_dressing` | T1 | 2–4 | apron clusters (raked gravel rocks, pottery, beach boulders, basalt shards, dry-stone) |
| 6 | `ornament_accent` | T1 | 1–2 | focal detail (shrine, fountain, capoeira ring, runestone, donkey cart) |
| 7 | `column_pillar` | T2 | 4–8 | repeatable structure (vermillion post, zellige column, painted mast, basalt prism, whitewashed pier) |
| 8 | `railing_segment` | T2 | 4–8 | perimeter piece (wooden rail, iron grille, quay rope rail, driftwood fence, blue rail) |
| 9 | `furniture` | T2 | 2–3 | human-scale legibility (bench, divan, deck chair, sled bench, taverna chair) |
| 10 | `signage_banner` | T2 | 2–3 | identity signal (noren, awning sign, bandeira, pennant, taverna sign) |
| — | `ground_texture` | image-only | 1 | tileable apron texture — no Meshy model, used as a material |

T1 = build first (6 models per map); T2 = the next 4 when the budget allows. Luca's Meshy
limit is 10 models per map — T1+T2 = exactly 10.

Backdrop, sky, court, glass, net stay procedural (not kit slots).

## 2. File contract

| Thing | Path |
|---|---|
| Slot image (Meshy input) | `art/arena-kits/<arena>/<slot>.png` — square, ≥1024², white bg |
| Model (engine reads this) | `godot/assets/arenas/<arena>/<slot>.glb` |
| Manual drop inbox | `meshy/inbox/<arena>/<slot>.glb` (pulled into the path above) |
| Per-arena image manifest | `art/arena-kits/<arena>/MANIFEST.md` |
| Batch index for Luca | `art/arena-kits/INDEX.md` |
| Spend ledger | `art/arena-kits/image-spend.json` |
| Slot specs (anchors, sizes, suppress) | data table in `godot/game/arenas/arena_kit.gd` |

`.json` manifests were **rejected**: non-resource files are not exported by default. A
GDScript data table matches house style (`arena_style.gd::STYLES`) and has no export trap.
The `.import`/`PackedScene` path was **rejected** for slots: it requires an editor import
pass per arriving asset; the repo's own precedent (athlete rig, arena artwork) is runtime
`GLTFDocument` load with a `ResourceLoader.exists` guard.

## 3. Meshy settings (advice for the owner's GUI runs)

- Model: **Smart Topology** (`meshy-t2` class) — image-to-3D only, 100–15,000 faces,
  default 4,000, triangle output, natively separated parts, ~10 s.
- Texture: 2K, PBR. Origin: **bottom**. One model per image. No rig, no pose, no symmetry.
- Keep each prop one connected solid mass; thin/openwork pieces (lantern screens, railings,
  banners) must be authored chunky, or split into their own slot. Remesh after texturing
  breaks UVs — texture last.
- Download immediately: meshy assets are retained 3 days, signed URLs expire, and GUI
  Workspace models are not enumerated by the documented API.

## 4. Image recipe (the batch we generate)

Follow `scan/image-prototyping.md` §6 template verbatim: shared style block (from
`art/concepts/world-arenas-r1/BRIEF.md` palette + the low-poly DNA paragraph), per-slot
subject, fixed view (front or 3/4), matte materials, shadowless studio lighting, pure
white seamless background, square 1:1, subject filling 70–90 %, nothing crossing the edge.

Meshy-readiness checklist (gating, 6 items per image): single subject · white/transparent
background · no text/watermark/logo · subject 70–90 % and uncropped · all surfaces matte
(no chrome/glass/wet) · ≥1024² square.

## 5. Engine intake rules

- New module `godot/game/arenas/arena_kit.gd`: slot spec table + `mount()`.
- Load: `FileAccess.file_exists(path)` then runtime `GLTFDocument` load; never `preload()`
  for optional files (parse-time keyword → hard failure on a missing asset).
  **Correction 2026-09-18** (measured by the intake lane, confirmed by the CEO): this
  section first said `ResourceLoader.exists`. On a *dropped, unimported* GLB that returns
  `false` while `FileAccess.file_exists` returns `true` — taken literally the kit would
  never fire. `ResourceLoader.exists` is only valid for imported resources; slot assets
  arrive unimported by design.
- Placement: normalize to bottom origin, scale **in metres** to the spec's target height
  (Meshy exports arrive normalized) — never trust source units, never `get_aabb()` on a
  skinned mesh.
- Naming: mount node is `Kit/Slot_<slot>` under the arena root (`Scenery/` walk stays
  untouched). No collision on décor. One shared kit material policy (`surface_override_material`
  with ≤3 maps) to avoid per-model material blowup.
- Default is **additive**: a GLB mounts at its anchor; the procedural prop keeps building.
  A per-slot `suppress` flag may skip the matching procedural prop — tests updated
  deliberately when that flag is exercised.
- Footprint: every slot stays behind the field-law plane `z = -8.0`; with the default
  prop depth (~3.6 m budget) that is the hard ceiling per prop.
- Engine discipline: **one Godot process at a time** — `flock -w 900 /tmp/padel-godot.lock`
  around every run plus a `pgrep -x Godot` guard. GL Compatibility has no automatic
  instancing; protect unique materials/meshes, not node count.

## 6. Gates

- **G1** this standard + the code table exist and agree.
- **G2** every image passes the checklist; reviewed by a critic that is not the maker.
- **G3** headless test proves a GLB in a slot mounts at its spec transform; empty slot →
  procedural path byte-identical to today; frozen audits green (`arena_selector_contract_test.gd`,
  `screen_arena_audit.gd`, `game_slice_test.gd`, `world_arenas_*`).
- **G4** Meshy puller verified against a local fixture (live run needs Luca's key or drop folder).
- **G5** council round on the assembled torii arena vs its concept still; Luca's taste
  verdict stays last and is never self-approved.

## 7. Open (do not guess)

- Whether the nine steampunk arenas get kits this pass.
- Sky strategy: procedural gradient shader vs generated panorama (Compatibility limits).
- Luca's key vs drop-folder for the pull; per-arena anchor polish after his first models land.
