# Modular environment kits → Godot 4 intake (material for the Arena Kit Standard v1)

Scan lane: SOTA methodology + engine seams. Date: 2026-09-18 (all URLs retrieved 2026-09-18).
Repo read at: primary tree `steam-circuit-padel-godot` (read-only; no engine run, no paid calls).
Deliverable: input to the frozen kit standard (slot names, dimensions, Godot import settings, loader seams).

Reader's note: this file mixes three kinds of statement and marks them.
**[DOC]** = from a cited primary source (engine docs, GDC talk, book).
**[REPO]** = measured/read in this repository today, with path and line.
**[REC]** = my recommendation, not a fact about the engine or the industry.
Where a source contradicts another or where I could not verify a numeric value, it is flagged in §7.

---

## 0. TL;DR for the standard

1. A kit is a **system, not a folder of models**: pieces snap on a shared grid, share a pivot convention, and are named by *connection role*, so the combiner (here: our loader) can place any piece in any slot without nudging values. ([DOC] Burgess GDC 2013; [DOC] Level Design Book, "Modular kit design").
2. Our arena band gives the kit a **hard footprint**, not a suggestion: every scenery mesh's AABB must stay behind `z = -8.0` and outside the cage ([REPO] `arena_scenery.gd:101,238-272`). With the current default placement (`z ≈ -11.65`, `arena_scenery.gd:165`) that is **≈3.6 m of depth budget per prop** — the single most important dimension number in the kit spec.
3. Godot can bring a GLB in by **two paths**, and this repo already uses both: the editor-import path turns a `.glb` into a **`PackedScene`** (`type="PackedScene"` in every athlete `.glb.import`; mount by `instantiate()`), while the athlete rig and the arena artwork loader read the bytes at runtime with `GLTFDocument` ("no `.import` cache", `athlete_rig.gd:56-58`). Whichever we freeze, MultiMesh (which takes a `Mesh`) needs a child `MeshInstance3D.mesh` extracted first — and the size check must not use `get_aabb()` on anything skinned (`athlete_rig.gd:790-797`).
4. The GL Compatibility renderer **has no automatic instancing** ([DOC] Optimizing 3D performance: "This is only implemented in the Forward+ renderer, not Mobile or Compatibility"). Tens of props per arena is still a non-problem at our scale; the thing to protect is *unique materials* and *unique meshes*, not node count.
5. Optional assets must be loaded with `ResourceLoader.exists(path)` + `load(path)`; **`preload()` is a parse-time keyword that requires a constant path**, so a missing optional file is a hard failure rather than a `null` check ([DOC] `@GDScript.preload`).
6. If the per-arena catalog is JSON, it is **not exported by default** — non-resource files need the export filter (e.g. `*.json`) ([DOC] `FileAccess`, Exporting projects). A custom `Resource` (`.tres`) needs no filter. This is the deciding argument in §3.1.

---

## 1. What a shipped kit is, and how level-art teams define it

### 1.1 Definition (primary source)

Joel Burgess and Nate Purkeypile, "Skyrim's Modular Level Design" (GDC 2013, Level Design in a Day), transcript published 2013-04-19:
<http://blog.joelburgess.com/2013/04/skyrims-modular-level-design-gdc-2013.html> [DOC]

> "Kits, first and foremost, are systems. A basic pipe kit … may only be four simple pieces of art which can be used together. This kit, as most, snaps together using a grid system. The most important attribute of a kit is that it adds up to far more than the sum of its parts."

The same talk names the two things a kit buys a production: **reuse** ("not having to specifically create and export every fence post and doorway") and **variant economics** (art variants are cheap because geometry is already validated). It also names the failure mode we must design against: **"art fatigue"** — repeated *detail* elements are noticed and resented faster than repeated *broad architecture*, and their mitigation was "doing away with copy and paste design as much as possible" rather than more variants. [DOC]

The Level Design Book's "Modular kit design" page (retrieved 2026-09-18) is a condensed restatement of the two Burgess talks and adds the process order we should copy:
1. pre-production (decide granularity, "how chunky");
2. blockout the kit — **"DO NOT MAKE VARIANTS YET, just build basic pieces first"**;
3. metrics stress tests — **loopback**, **stack** ("floors should NOT be paper thin"), **gap** ("do you have enough glue…");
4. art pass and variants last.
<https://book.leveldesignbook.com/process/blockout/metrics/modular> [DOC]

Practical read for us: the loader's slot contract *is* the "connection matrix" step; our fallback pieces are the blockout; the Meshy models are the art pass. Doing them in the other order (generate 10 models, then discover the grid) is the documented failure path. [REC]

Fallout 4 continued the same system at larger scale: "GDC 2016: Modular Level Design of Fallout 4", Joel Burgess, slides:
<https://www.slideshare.net/slideshow/gdc-2016-modular-level-design-of-fallout-4/59770460> [DOC, slides only — see §7.5]

### 1.2 Slot / piece taxonomy for an exterior "arena" set

There is no universal published slot list, but two concrete published taxonomies exist, and both are *role*-based, not object-based.

**Burgess (Skyrim, interiors/ext):** floor, ceiling, wall, doorway (single), doorway (double), window, corner; then platforms (landscape); **glue** (odd-angle fillers); flanges and arches (caves); shells (caves). [DOC, GDC 2013 + Level Design Book summary]

**Practitioner kit guide (vendor blog, weaker source, flagged):** a kit needs a "connection matrix — every piece type listed against every other piece type it needs to meet, with the specific transition geometry that connection requires"; the same article gives the naming pattern `SM_Kit[KitName]_[PieceType]_[Variant]` and insists piece-type names describe the **connection role**, not the visual content, "so a level designer scanning a content browser finds the right piece by function".
<https://nastyrodent.com/modular-prop-kits-for-games/> [DOC, blog — treat as practice opinion, not authority]

For an **exterior arena backdrop** (no ceilings, no doors, one hero vista, heavy repetition), the role categories that survive translation are:

- **hero / landmark** — the unique identity mass (see §1.2.1);
- **threshold (portal/gate)** — the arrival piece; wayfinding literature calls this the *identification* sign, "placed at the entrances… they symbolize the arrival to a destination" ([DOC] Level Design Book, "Wayfinding");
- **repeatable structural modules** — column, railing/parapet segment, arch/beam ("glue" when off-angle);
- **light source** — the emissive/accent carrier;
- **furniture** and **human-scale clutter** — the pieces that make scale legible;
- **vegetation cluster** — organic contrast, hides seams between hard modules;
- **ornament / motif** — small, cheap, repeatable detail (the art-fatigue risk lives here);
- **signage / banner** — text and identity; also the cheapest possible "this is a different arena" signal;
- **ground dressing** — what the apron beyond the cage is made of.

#### 1.2.1 Why a "hero landmark" slot is not optional

Composition theory: a **landmark** is "a unique and memorable shape, mass, or location"; a **vista** is "an exceptionally deep scene composition that offers an overview of the next area"; an **approach** is "a path with a vista". Spatial hierarchy — "some parts of the level should feel more important than the others" — is what makes an arena read as a place rather than a set of props. The book also warns that props which are *not* functional read as "fake set dressing landmarks".
<https://book.leveldesignbook.com/process/blockout/massing/composition> [DOC]

Our case is a *fixed camera down the court*: the composition is effectively a painted shot, and the band behind the rear glass is the one region where the arena can have a landmark at all ([REPO] `arena_scenery.gd` header: scenery lives only in the proscenium band; the side wedges are ~80 px wide and cannot hold a back-wall-sized object). So in this project the hero landmark is the piece that carries the arena's identity, and it must be authored *for the frame*, not for a walkaround. [REC]

### 1.3 Naming conventions

Two naming surfaces exist and both matter:

1. **Asset naming (content browser / folder / file)** — published pattern `SM_Kit[KitName]_[PieceType]_[Variant]`; rule: encode connection role. [DOC, blog]
   For us the analogue is the *file name in the slot folder*: `godot/assets/arenas/<arena>/<slot>.glb`, e.g. `torii/gate_portal.glb`. The mission's own M2 already fixes this shape ([REPO] `docs/mission/arena-kit/CHARTER.md`).
2. **Engine-level name suffixes** — Godot reads suffixes off *object names inside the source file*: `-col`, `-convcol`, `-colonly`, `-convcolonly` (collision), `-occ`/`-occonly` (occluder), `-navmesh`, `-noimp` (delete at import), `-alpha`, `-vcol` (material flags), `-loop`/`-cycle` (animation). Hyphen, `$` and `_` all work, case-insensitive. `nodes/use_node_type_suffixes` (default `true`) gates the node-type ones; `nodes/use_name_suffixes` (default `true`) gates all of them.
   <https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/node_type_customization.html> [DOC]

Consequence for the standard: the naming convention should be written in **both** places, and the Godot suffix vocabulary should be reserved words in our kit (never name a Meshy part "...–col" by accident; conversely `-noimp` is the documented way to strip helper geometry a generator leaves in the file). [REC]

### 1.4 Module scale / grid rules

**Grid.** "The asset-authoring snap grid is the small-scale grid an artist works to when modeling and placing kit pieces — commonly a **1×1×1 meter base unit** for architectural kits, though the right unit depends on what the kit needs to represent." [DOC, blog] Burgess's kit talks use the same idea (pieces stay inside a defined footprint/bounding box; the Level Design Book records it as "**Define a footprint** — stay in footprint / bounding box"). [DOC]

**Pivot.** "The convention that holds up in production: **pivot at a consistent corner or edge of the piece's bounding box — typically the bottom-front-left corner** for architectural pieces — so that snapping one piece against another aligns both position and orientation without the level designer nudging values." [DOC, blog] Meshy supports exactly this on export: the Resize panel lets you choose **Bottom** or **Center** origin alignment, and the Resize API exposes `origin_at` with `bottom` as the default for auto-size.
<https://help.meshy.ai/en/articles/10523176-resizing-and-repositioning-models-in-meshy>;
<https://docs.meshy.ai/en/api/resize> [DOC]

**Metric.** Godot is **right-handed, Y-up, metres implied**; the docs' direction convention is that an oriented asset faces +Z (so in Blender +Y is rear, −Y is front) and "the convention for 3D assets is to face the opposite direction as the camera".
<https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/model_export_considerations.html> [DOC]

**Our actual grid (this is the number that should be frozen).** From the repo today:

| Quantity | Value | Evidence |
|---|---|---|
| Field-law plane (nothing may cross toward the camera) | `z = -8.0` | [REPO] `arena_scenery.gd:101` `FIELD_LAW_Z`, checked in `field_law_report()` at `:238-272` |
| Default prop container z | `-11.65` (`prop z default -7.65` minus `4.0`) | [REPO] `arena_scenery.gd:165` |
| → depth budget in front of a default-placed prop | **≈ 3.65 m** | derived |
| Authored lateral span for prop tables | ±14.35 m, scaled by `prop_half_x / 14.35` per camera preset | [REPO] `arena_scenery.gd:140-143` |
| Band top | frame's top row + overscan, from the camera preset | [REPO] `arena_scenery.gd:186-200` |
| Enforced? | Yes: "every scenery vertex stays behind the BACKDROP_Z=-8.0 plane, and no scenery AABB intersects the playable footprint" | [REPO] `godot/tests/world_arenas_field_law_test.gd:25-26` |

So the kit's grid rule should be stated as a **per-slot footprint box** (like Burgess's "footprint"), not a tile grid: e.g. "any slot asset must fit inside 3.5 m (depth) × H m (height) × W m (width), origin at bottom-centre, +Z facing the camera". The loader can then assert `mesh.get_aabb()` against the box before mounting. [REC]

**Snap sizes.** Two placement regimes, both legitimate, and the standard should say which slot uses which:
- *grid-snapped* (railing segments, ornament strips, ground-dressing tiles): dimension multiples of the base unit so N copies tile without a seam;
- *procedural/anchored* (hero landmark, gate, vegetation): free-placed from the style table, sized by a declared height. Our existing props are all of the second kind (`h`, `r`, `x` fields) — `arena_style.gd` `props` entries. [REPO]
Burgess's stress tests (loopback / stack / gap) are the acceptance test for the first regime: build a run of N, a stack of 2, and an off-angle joint, and check for gaps. [DOC]

### 1.5 Why a kit beats a bespoke scene here (and the honest cost)

| Claim | Evidence |
|---|---|
| Reuse beats bespoke at scale; validated geometry makes variants cheap | [DOC] Burgess GDC 2013; Level Design Book "Modular kit design" |
| A kit is a *system* whose value is combinations, not pieces | [DOC] Burgess GDC 2013 |
| Swapping/painting variants is the cheap axis (texture + hue), re-validating geometry is the expensive one | [DOC] Level Design Book "Modular kit design" §4 |
| Repetition is the price; players punish repeated *detail* first | [DOC] Burgess GDC 2013 ("art fatigue") |
| Data-driven assembly is what makes "add an arena without code edits" possible | Mission requirement [REPO] `CHARTER.md` outcome #2 |

For our pipeline the decisive argument is different from Skyrim's: **~10 generated models per arena × 5 arenas is a fixed art budget**. A kit makes that budget *combinatorial* (10 pieces × placement rules → a full band) and makes each arena cheap to re-dress when Meshy output is poor, because exactly one slot regresses. [REC]

---

## 2. Godot 4.x specifics for importing GLB props

Engine docs read at 4.7 stable: the documentation site served "Godot Engine **4.7** documentation in English" for every page below, matching `project.godot`'s `config/features=PackedStringArray("4.7", "GL Compatibility")` and `renderer/rendering_method="gl_compatibility"` ([REPO] `godot/project.godot:15,166-167`).

### 2.1 What the importer actually does with a GLB

- A `.glb` is imported by `ResourceImporterScene`; the dock's import type is a **`PackedScene`**, and the imported artifact lands in `.godot/imported/<name>.scn`. [REPO, in-repo proof: `godot/assets/athletes/colosso.glb.import` carries `importer="scene"`, `type="PackedScene"`, `path="res://.godot/imported/colosso.glb-<hash>.scn"`.]
- "Imports a glTF, FBX, COLLADA, or Blender 3D scene." Additional per-mesh/per-material options live behind the Advanced Import Settings dialog.
  <https://docs.godotengine.org/en/stable/classes/class_resourceimporterscene.html> [DOC]
- Mounting is therefore `load(path)` → `PackedScene.instantiate()`; the tutorial states scenes on disk are `PackedScene` resources and you must `instantiate()` to get nodes, and that "images, meshes, etc. are all shared between the scene instances".
  <https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html> [DOC]

**Two intake paths exist in this repo, and the arena code already picked the other one.** Read together with the sibling scan `scan/repo-arena-seams.md` §3.1–3.4:

| | **Editor-import path** | **Runtime path (athletes, arena artwork)** |
|---|---|---|
| How | file in `res://` + `.import` sidecar → `load()` → `PackedScene.instantiate()` | `FileAccess.file_exists()` → `GLTFDocument.append_from_file()` → `generate_scene()` |
| In-repo evidence | `godot/assets/athletes/*.glb.import` exists (all defaults) | `athlete_rig.gd:56-58` "loaded at RUNTIME through GLTFDocument, not through Godot's import pipeline, so this scene needs no `.import` cache"; loader at `:367-374`; `arena_scenery.gd::_load_artwork` (`:303-315`) chose the same for arena artwork — "so nothing depends on the editor's import step" |
| Cost | needs a tracked sidecar **and an import pass** (fresh-clone ordering); gives generated LODs, shadow meshes, inspector preview | no `.import`, no editor pass, drop-folder friendly; **no generated LODs / shadow meshes**, no preview |
| Fits our M2 goal | OK inside `res://` | **better for a drop folder** and for "no code edits" |

[REPO] both. Decision this report recommends: **runtime `GLTFDocument` for the kit slots** (matches both in-repo precedents, survives a fresh clone, and works if the puller writes outside the editor's knowledge), with the import path kept as the option if we later want engine-generated LODs. The two paths are not interchangeable: the runtime path means `ResourceLoader.exists()` is the *wrong* existence check for slots (§2.4). [REC]
- **Scene import options that matter**, with the in-repo values (all eight athlete GLBs currently carry the same defaults, i.e. these *are* this project's live defaults):
  `nodes/apply_root_scale=true`, `nodes/root_scale=1.0`, `nodes/use_name_suffixes=true`, `nodes/use_node_type_suffixes=true`, `meshes/ensure_tangents=true`, `meshes/generate_lods=true`, `meshes/create_shadow_meshes=true`, `meshes/light_baking=1`, `meshes/lightmap_texel_size=0.2`, `meshes/force_disable_compression=false`, `array_mesh/deduplicate_surfaces=true`, `materials/extract=0`, `materials/extract_format=0`, `materials/extract_path=""`, `gltf/naming_version=2`, `gltf/embedded_image_handling=1`. [REPO]
  The class reference confirms the defaults for the mesh/node/array_mesh/material keys (`create_shadow_meshes=true`, `ensure_tangents=true`, `generate_lods=true`, `light_baking=1`, `apply_root_scale=true`, `use_name_suffixes=true`, `use_node_type_suffixes=true`, `array_mesh/deduplicate_surfaces=true`, `materials/extract=0`, `force_disable_compression=false`). [DOC]

### 2.2 Import defaults that matter, and what to do about them

- **Scale.** `nodes/apply_root_scale=true` applies `root_scale` to descendant meshes/animations/bones, keeping the root at scale 1; `root_scale`'s default `1.0` "will not perform any rescaling". So Godot will **not** fix a mis-sized prop for us — normalise upstream (§4 R1). [DOC]
- **Mesh LOD.** `generate_lods=true` is on by default and "Once LOD meshes are generated, they will automatically be used when rendering the scene. You don't need to configure anything manually." Mesh LOD works with `MeshInstance3D`, `MultiMeshInstance3D`, particles. Caveat: "LOD selection uses a screen-space metric… Higher camera FOV and lower viewport resolutions will make LOD selection more aggressive", and for multi-mesh nodes "**all instances will be drawn with the same LOD level at a given time**". A mesh that LOD breaks can be excluded per-mesh in Advanced Import Settings.
  <https://docs.godotengine.org/en/stable/tutorials/3d/mesh_lod.html> [DOC]
- **Shadows.** `create_shadow_meshes=true` "optimizes shadow rendering without reducing quality by welding vertices together"; it cannot use a lower-detail mesh than the source. Per-object control is `GeometryInstance3D`'s **Cast Shadow** property — docs call it out explicitly when you want a lit object that does not cast.
  <https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/import_configuration.html>;
  <https://docs.godotengine.org/en/stable/tutorials/3d/lights_and_shadows.html> [DOC]
  Renderer-side, Compatibility renders shadowed lights with a "multi-pass approach and less accurate blending" and supports **8 OmniLights + 8 SpotLights per mesh** (raisable in `Rendering > Limits > OpenGL` at a performance cost), no PCSS, no projector textures.
  <https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html> [DOC]
  Practical: our band already carries a handful of procedural lights; a prop must not add lights of its own, and props that only ever sit *behind* the camera's shadow-casting concerns should have `cast_shadow` off. [REC]
- **Materials / PBR.** glTF materials map onto Godot's PBR materials; the export-considerations page recommends letting the DCC supply PBR maps and notes Godot's `StandardMaterial3D`/`ORMMaterial3D`. Two import-side knobs matter:
  (a) `gltf/embedded_image_handling` — `Discard All Textures` / `Extract Textures` / `Embed as Basis Universal` / `Embed as Uncompressed`. In-repo value is `1`, and the athlete folders contain sibling `*_texture_0.png`, `*_normal.png`, `*_texture_0_metallic_roughness.png` files — consistent with an *extract* mode, but I did not verify which integer maps to which label (§7.2).
  (b) `materials/extract=0` keeps materials inline in the imported scene; extracting them to `.tres` is the documented route if we ever want **one shared kit material** across independently generated props (the trim-sheet/atlas play, §4 R2).
  [DOC for the option list; REPO for the values]
- **Vertex-colour / alpha materials** can be forced by name suffix (`-vcol`, `-alpha`) — useful for Meshy output that arrives with baked vertex colour or a cutout card (banners, foliage cards). [DOC]
- **Collision for decor: no.** Concave/trimesh shapes "are the slowest option"; they are legal only inside `StaticBody3D`; the docs recommend primitives ("favoring primitive shapes… often provide better performance and reliability") and "if your level has small details, you may want to exclude those from collision". The `-col`/`-colonly`/`-convcol` suffixes exist so a *model* can declare collision at import — but our scenery is by construction outside the playable footprint ([REPO] field law), so generating collision for decor buys nothing and costs physics-server bookkeeping.
  <https://docs.godotengine.org/en/stable/tutorials/physics/collision_shapes_3d.html> [DOC]
  [REC] Default: no collision on any slot asset. If one slot ever needs to block (a gate pillar standing where a player can walk), give it a **single primitive** collider added by the loader, never a trimesh.

### 2.3 Instancing strategy for tens of repeated props

Facts first, because one of them decides the strategy:

- **Automatic instancing does not exist in Compatibility.** "Use automatic instancing… **This is only implemented in the Forward+ renderer, not Mobile or Compatibility.** If you have many identical objects in your scene, you can use automatic instancing to reduce the number of draw calls. This automatically happens for MeshInstance3D nodes that use the same mesh and material."
  <https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html> [DOC]
  So on GL Compatibility, two identical `MeshInstance3D`s in the band are **two draw calls**, no matter what.
- **MultiMesh is one draw primitive** covering every instance, "extremely efficient… it uses the GPU hardware to do this", with two costs: "there is no screen or frustum culling possible for individual instances… always or never drawn, depending on the visibility of the whole MultiMesh" and `visible_instance_count` is the only cheap knob. Workaround the docs suggest: "create several MultiMeshes for different areas of the world". LOD caveat from §2.2 applies (all instances share the LOD level).
  <https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html> [DOC]
- MultiMesh takes a **`Mesh`**, not a scene: the docs' snippet is `multimesh.mesh = BoxMesh.new()`. So a GLB prop used in a MultiMesh must first be resolved to a mesh resource (instantiate → find `MeshInstance3D` → take `.mesh`), and every instance shares that one mesh (and its material; per-instance variation is limited to what the format supports, e.g. instance colour/custom data).
  <https://docs.godotengine.org/en/stable/tutorials/3d/using_multi_mesh_instance.html> [DOC]
- Textures/geometry are shared anyway: "Even if you save a built-in resource, when you instance a scene multiple times, the engine will only load one copy of it." [DOC] So **memory** is not the reason to reach for MultiMesh — **draw calls** are.
- Budget context: a commonly cited draw-call budget table puts "low spec desktop, VR desktop" at 500–1000 and "mid spec desktop" at ~2000 draw calls per frame (the book's own table, with the caveat that these are rules of thumb). [DOC] <https://book.leveldesignbook.com/process/env-art/optimization>

**Therefore, for ~10 slots × a handful of instances each (tens of props):**
- default to **one `PackedScene` instance per placed piece**, parented under a per-slot container — it is debuggable, per-slot overridable (hide, tint, nudge), and auditable by our own frame/field-law tests, which walk the node tree ([REPO] `field_law_report()` iterates children of `Scenery`);
- reach for **MultiMesh only where the same mesh truly repeats** — the slots I would expect: `railing_segment`, `column_pillar` in a colonnade, `ornament_accent` panels, `ground_dressing` tiles. Those are exactly the slots where per-instance culling does not matter, because they are all in one band in front of the camera anyway (the band is a fixed shot — all-or-nothing visibility is acceptable by construction);
- keep **one material per prop family** where possible (see R2) — in Compatibility nothing batches for us, so the only real lever on draw calls is "fewer distinct meshes/materials and fewer shadow casters", then MultiMesh for the genuinely identical pieces. [REC]

### 2.4 Loading an optional asset with a fallback (the core intake seam)

Documented semantics:
- `ResourceLoader.exists(path, type_hint := "")` — "Returns whether a recognized resource exists for the given path."
- `ResourceLoader.load(path, type_hint, cache_mode)`; `@GDScript.load()` is the simplified form. "Files have to be imported into the engine first to load them using this function." The `load()` doc notes a `null` result path is not guaranteed to be quiet — the engine prints/aborts on missing resources by default (`ResourceLoader.set_abort_on_missing_resources`, `ProjectSettings` "abort on missing resources").
  <https://docs.godotengine.org/en/stable/classes/class_resourceloader.html> [DOC]
- **`preload()` is the trap.** "During run-time, the resource is loaded when the script is being parsed. This function effectively acts as a reference to that resource. **Note that this function requires `path` to be a constant String.**" The Resources tutorial repeats it: "unlike `load`, this function will read the file from disk and load it at compile-time. As a result, you cannot call `preload` with a variable path: you need to use a constant string."
  <https://docs.godotengine.org/en/stable/classes/class_%40gdscript.html>;
  <https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html> [DOC]
  So: `preload("res://assets/arenas/torii/gate_portal.glb")` in the loader would make **the whole script fail to parse** the moment that slot is empty — i.e. it would hard-code the "no fallback" behaviour we are explicitly trying to avoid. [REC]

Two patterns, both composed from the above and from what the repo already does elsewhere. **A** is the import-path version and reuses the idiom the UI code ships today; **B** (further down) is the runtime version and is the one this report recommends for slots (§2.1). Pick one and state it in the standard — mixing them means a slot that mounts in the editor and vanishes in a fresh clone.

**A — import path:**

```gdscript
const SLOT_DIR := "res://assets/arenas/%s"
const SLOT_SUFFIX := ".glb"

static func mount_slot(parent: Node3D, arena_id: String, slot: String) -> Node3D:
    var path := SLOT_DIR % arena_id + slot + SLOT_SUFFIX
    var holder := Node3D.new()
    holder.name = "Slot_%s" % slot          # keep the audit's "child of Scenery is Node3D" rule
    parent.add_child(holder)
    if ResourceLoader.exists(path, "PackedScene"):     # optional asset: never preload
        var ps := load(path) as PackedScene
        if ps != null:
            holder.add_child(ps.instantiate())
            holder.set_meta("asset_origin", path)
            return holder
    holder.set_meta("asset_origin", "procedural")
    _build_procedural_fallback(holder, arena_id, slot)  # the blockout never disappears
    return holder
```

**B — runtime path (recommended for slots):** the athlete/artwork pattern, adapted from `athlete_rig.gd:367-374`:

```gdscript
static func _mount_runtime_glb(holder: Node3D, path: String) -> bool:
    if not FileAccess.file_exists(path):     # runtime path: the .import check does not apply
        return false
    var doc := GLTFDocument.new()
    var st := GLTFState.new()
    if doc.append_from_file(path, st) != OK:
        return false
    var scene := doc.generate_scene(st) as Node3D
    if scene == null:
        return false
    holder.add_child(scene)
    return true
```

Repo precedent for exactly this style (already shipped, two places):
`ArenaScreen.gd:763` — `var texture: Texture2D = load(art_path) if ResourceLoader.exists(art_path) else null`;
`ControlLegend.gd:434` — same idiom;
`audio_port.gd:239` — `if not ResourceLoader.exists(path, "AudioStreamWAV")`. [REPO]
Using the **type hint** (`"PackedScene"`) is the existing project convention and guards against a same-named non-scene resource. [REC]

**Export-build caveat (verify before shipping).** Non-resource files (e.g. a `.json` catalog) "are not exported by default"; a file must either be included via the export dialog's non-resource filter (e.g. `*.json`) or "change its import mode to Keep File (exported as is) in the Import dock". [DOC] `class_fileaccess` + Exporting projects. An *imported* resource (a `.glb` with an `.import` file) does not have this problem — but a slot folder that only ever gets `load()`ed has no static reference, so it is worth one explicit export test with an empty-then-filled slot folder before this becomes load-bearing. Flagged as an open item in §7.3. [REC]

---

## 3. Data-driven scene assembly in Godot

### 3.1 Where the per-arena catalog should live

Three options, with the deciding facts:

| Option | Facts | Verdict |
|---|---|---|
| **GDScript const table** (what we do today: `arena_style.gd` `STYLES`, each entry a `props: [{kind,x,y,h,r,tint}]` array) | zero export concerns, type-checked at parse, diffable, already audited by tests; changing it is a code edit | keep for **placement/behaviour** |
| **Custom `Resource` (`.tres`)** | "They have defined properties, so users know 100% that their data will exist"; inspector-editable; auto-serialised; can nest sub-resources; version-control friendly text. Loaded through `ResourceLoader` like anything else — no export filter needed. <https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html> | **best fit for the per-arena catalog** if we want non-programmers to edit it |
| **JSON** | needs `FileAccess` + manual parsing, "non-resource files… are not exported by default" and require an export filter | acceptable, but must not be silently missing in a build |

Note what the task asks for is narrower than either: "add or modify an arena by dropping slot-named assets into a folder — no code edits" ([REPO] `CHARTER.md` outcome #2). That is satisfied by **file presence** as the registry (`ResourceLoader.exists` per slot on the import path, `FileAccess.file_exists` on the runtime path — §2.4), with the *placement* numbers still coming from the style/catalog table. So the recommended shape is two-layered:

1. **Slot occupancy** — resolved from the filesystem per arena (`godot/assets/arenas/<arena>/<slot>.glb`), no catalog edit needed to add art;
2. **Slot placement + whether the slot exists at all** — declared once in the kit standard (a small typed record per slot: anchor position, footprint box, required/optional, repeat count), read by the loader.

[REC] If the team wants the catalog in data rather than code, make it a custom `Resource` (`.tres`) and *not* JSON, purely on the export-filter footgun. Whichever is chosen, the loader must degrade to the procedural fallback when the catalog file itself is absent.

### 3.2 Slot → node mapping (and the naming that keeps the audits green)

Today's tree, read from the repo:

```
Arena                       (arena_library.build, :247-248, meta arena_id/family/world/wallBounce)
├─ …world + court + net + cage…   CourtBuilder.build_world / build_court  (:253-254)  ← FROZEN SURFACE
└─ Scenery                  (arena_scenery.build, :109-115)
   ├─ Backdrop / BackdropArtwork / BackdropVeil / BackdropApron   (:121-138)
   └─ Dressing_<kind><n>     one Node3D per authored prop (:163-167), position (:165)
```

[REPO] all line numbers from `godot/game/arenas/arena_library.gd` and `arena_scenery.gd`.

Two constraints from the frozen audits that the loader must respect:

- every direct child of `Scenery` must be a `Node3D` ("field law: %s is not a Node3D"), and
- every mesh under it must keep its 8 AABB corners behind `z = -8.0` (`field_law_report()`, `:252-271`). The check does not care about node names for the geometry itself — but it *does* require the arena's frozen nodes to be present by name: `LineFar, LineNear, LineLeft, LineRight, GlassLeft, GlassRight, GlassNear, GlassFar, GlassFar2, GlassFar6, GlassFarRail, GlassFarBottom` (`:243-247`), which are `court_builder`'s own. [REPO]

[REC] Mapping rule for the new kit: **`Scenery/Slot_<slot_id>`**, one holder per slot (mirroring today's `Dressing_*`), each holder carrying `set_meta("asset_origin", path|"procedural")` and `set_meta("slot", slot_id)`. This keeps the field-law walker working unchanged (holders are `Node3D`s), gives every future audit a stable name to key on, and makes "which slots are still procedural?" a one-line query — which is exactly the evidence M3 needs. Multi-instance slots (`column_pillar`, `railing_segment`) become `Slot_<slot_id>` containing `Piece_1..n` children, each free to be a duplicated scene or a MultiMeshInstance3D.

### 3.3 Keeping the frozen gameplay surface intact while the kit is swapped

The surface is already separated in code, and the separation is the mechanism to preserve:

- `arena_library.build()` builds the arena in order: world → court (surface, net, cage) → **scenery** (`:253-255`). Scenery is the *last* child and never writes to the court; the library explicitly notes "The environment is identical for both kinds — court, net and cage are common to every arena — and the arena's own values only ever enter colours, sizes and the glass alpha" (`:237-241`). [REPO]
- The band is a *law*, not a convention: `FIELD_LAW_Z = -8.0`, and the field-law test asserts both "no scenery vertex in front of the plane" and "no scenery AABB intersects the playable footprint", plus a **red control** that deliberately places scenery at `z = -9` to prove the glass-safety check actually rejects things (`world_arenas_field_law_test.gd:25-36`). [REPO]
- The frame test walks every `Dressing_*` object and requires it to be inside the camera frame (`world_arenas_frame_test.gd:100`), i.e. props may not merely be legal, they must be *visible* where the shot expects them. [REPO]
- The Level Design Book's framing of the same discipline: environment art is "the cosmetic decoration of a level or game world, **while preserving its core functionality and gameplay**", and the art pass is supposed to start only after "a mature blockout". <https://book.leveldesignbook.com/process/env-art> [DOC]

[REC] Concretely: the kit loader touches nothing outside `Scenery`; it never moves `BACKDROP_Z` (shared with the nine frozen arenas — see `docs/mission/world-arenas/integrator.md:36`), never reparents court nodes, and every new slot asset is validated against (a) the frozen node-name list, (b) the field law, (c) the frame test, before it is allowed to replace a fallback. Fallbacks are not deleted when the first GLB lands: keep the procedural builder callable per slot so an empty/regressed slot degrades instead of vanishing.

---

## 4. Three named risks, with mitigations

### R1 — Scale drift between independently generated models

**Why it is real (and worse than usual for us).** Meshy models are not authored to our metre: "Models generated by Meshy come in a standard size within a range between **-1 and 1**. However, you may need to scale or reposition your model for different applications." The same page's fix is a download-time Resize: set the desired height, choose a unit among mm/cm/m/in/ft, optionally auto-size, and choose origin **Bottom** or **Center**.
<https://help.meshy.ai/en/articles/10523176-resizing-and-repositioning-models-in-meshy> [DOC]
The API equivalent exists and is scriptable by the puller: `resize_height` (metres), `resize_longest_side` (metres, aspect preserved), or `auto_size` (AI vision estimates real-world height); `origin_at` is `bottom` by default for auto-size. Output for an input task id is GLB.
<https://docs.meshy.ai/en/api/resize> [DOC]
Ten models, ten separate generations, ten chances to land at 0.94× or 1.07× — and the failure compounds: "A kit piece exported at 0.98× or 1.02× of the intended scale still looks correct in isolation, but compounds visibly once dozens of pieces chain together". [DOC, blog]
Godot will not catch it: `nodes/root_scale` defaults to `1.0` ("will not perform any rescaling"). [DOC]

**Mitigations (belt and braces).**
1. **Author the target, not the model**: freeze a per-slot height in metres + footprint box in the standard (§5 table) *before* generation, and put the number in the Meshy prompt ("2.4 m tall torii gate, bottom origin").
2. **Normalise on intake, in the puller**: call the Resize API with `resize_height` (metres) and `origin_at: "bottom"` per slot, or, after download, compute the GLB's AABB and rescale to the declared height. Note Meshy's `model_urls` are "signed, time-limited" URLs (`expires_at` is in the task object) so the pull must happen promptly. <https://docs.meshy.ai/en/api/quick-start> [DOC]
3. **Verify, don't trust, in-engine**: at mount time read `mesh.get_aabb()` and (a) fail the slot into fallback, or (b) uniformly rescale, if height/width/depth are outside the declared box by more than a tolerance (e.g. ±2 %). The engine can do this without rendering.
   **Caveat, and it is a real trap**: `mesh.get_aabb()` × transform is only trustworthy for *static* meshes. On a skinned GLB whose vertices are in metres but whose bone hierarchy sits under an `Armature` scaled `0.01`, the multiplication double-counts that scale and reports the model ~100× too small — documented in this repo at `athlete_rig.gd:790-797` ("Do NOT use `MeshInstance3D.get_aabb()` for this…"), with the working alternative `get_world_extent()` there. Our checked path (`field_law_report()`) uses mesh AABB × transform and is fine because every scenery prop is static — so the kit rule is: **slot assets must be static, unskinned meshes**; a skinned/generated-with-armature model fails the size check and must be normalised upstream. [REPO + REC]
4. **Design tolerance into the band**: because the depth budget is ≈3.65 m (§1.4), a 10 % scale error on a 3 m-deep hero piece crosses the field-law plane — so the field law doubles as the drift alarm, provided the loader asserts *before* the audit runs. [REC]

### R2 — Material / texture mismatch between independently generated props

**Why it is real.** Each Meshy asset arrives with its own PBR set (`base_color`, `metallic`, `normal`, `roughness`, `emission` are exposed per task — [DOC] <https://docs.meshy.ai/en/api/image-to-3d>), each on its own 1K/2K atlas. GLB embeds them — "GLB embeds textures in one file, while FBX and OBJ use separate texture files" ([DOC] <https://docs.meshy.ai/en/webapp/guides/platform/export-formats>). Ten independently generated atlases mean ten textures, ten materials, and ten chances to land a different albedo temperature or roughness feel — the classic reason shipped kits use **trim sheets** and shared materials: "Multiple related subtextures grouped together, designed to be used together", plus panels that "combine all the panel segments into one texture". <https://book.leveldesignbook.com/process/env-art/texturing> [DOC]
Second-order engine risk: a GLB's own material may set alpha/transparency. Godot cannot sort transparent objects by material ("Transparent objects are rendered from back to front… try to use as few transparent objects as possible"); our band already has one deliberate transparency case (the veil/backdrop artwork, [REPO] `arena_scenery.gd:126-133`). [DOC]

**Mitigations.**
1. **One material per arena, applied by the loader**: import with `materials/extract=0` (in-repo default) and then, at mount time, walk the slot's `MeshInstance3D`s and set `surface_override_material` to a single kit material (palette-tinted `StandardMaterial3D`) built from `arena_style.gd`'s palette (`accent`/`gear`/`floor`/`glow` are already handed to props via `ctx`, [REPO] `arena_scenery.gd:144-158`). The Meshy atlas becomes optional detail rather than the look.
2. **Constrain the palette in the image batch**: the kit's images (M1) should share a per-arena palette and lighting so that the generated PBR sets at least agree in hue, which is the cheap half of the trim-sheet benefit without building a trim sheet.
3. **If colour consistency still fails, go to one atlas deliberately**: extract materials (`materials/extract=1`) and re-map to a shared atlas/trim sheet in a DCC — the documented motivation for trim sheets is exactly "a relatively small environment art team [creating] a wide variety of looks". [DOC, Level Design Book "Texturing" → GDC 2015 "The Ultimate Trim"]
4. **Never let a prop carry its own light**: Compatibility allows only 8 omni + 8 spot lights **per mesh** and renders shadowed lights multi-pass, so an emissive prop should express "light" via emission material + palette glow, not a real `OmniLight3D`. [DOC] renderers page. [REC]

### R3 — Draw-call / shadow blowup as the kit grows

**Why it is real.** In GL Compatibility there is **no automatic instancing** ([DOC] §2.3), so N duplicated prop scenes = N draw calls, plus (if they cast shadows and a shadowed light is on) additional depth passes ("Realtime lighting, shadows (especially multiple lights)… are especially expensive"; "Realtime lighting… shadows… are especially expensive"). A kit invites exactly the pattern that gets expensive: many copies of a few meshes. Budget reference: ~500–1000 draw calls for "low spec desktop, VR desktop" and ~2000 for mid-spec desktop, per frame — with all the caveats that this class of table deserves. [DOC] <https://book.leveldesignbook.com/process/env-art/optimization>

**Mitigations.**
1. **Count it**: make the loader log per-arena `{slot: instance_count}` and (in the proof run, not headless) the renderer's drawn objects/primitives; mesh LOD's docs give the in-editor readout path (View Frame Time / View Information) and the `Rendering > Mesh LOD > LOD Change > Threshold Pixels` knob. [DOC] <https://docs.godotengine.org/en/stable/tutorials/3d/mesh_lod.html>
2. **MultiMesh the three repeat slots** (`railing_segment`, `column_pillar` colonnade, `ornament_accent` panes, `ground_dressing` tiles) and leave everything else as instances. All-or-nothing visibility is acceptable *here* because the band is a fixed camera shot; still, partition one MultiMesh per slot rather than per arena if culling ever becomes interesting. [DOC] + [REC]
3. **Cheap per-object switches**: `cast_shadow = OFF` on pieces whose shadow can never land in the playable area, and `visibility_range` (HLOD) to drop far/dim pieces entirely — both are first-class Godot features ("Visibility ranges (HLOD)" in the LOD overview). [DOC]
4. **Cap the kit**: the mission already caps generation at ~10 models/map; the standard should also cap *instances* per slot (e.g. ornament ≤ 8, column ≤ 6) so a future "more of everything" edit cannot silently 3× the band. [REC]

**Also worth a line in the standard (not counted among the three):** *art fatigue / sameness across the five arenas*. The five arenas must read as five places; Burgess's finding is that repeated **detail** is what players punish, so the cheap differentiators are texture/palette and the hero landmark, while the repeatable modules are the right thing to share. [DOC] + [REC]

---

## 5. Recommended slot taxonomy (10 core slots + 1 procedural-only)

Rules that apply to every slot: **origin at bottom-centre** (or bottom-front-left for pieces that join edge-to-edge), **+Z faces the camera**, **asset must fit its footprint box**, **no collision**, **no lights**, **one arena folder per arena** (`godot/assets/arenas/<arena>/<slot>.glb`), missing file ⇒ procedural fallback (never a hole). Dimensions are **starting proposals** to be frozen against the default camera preset; the depth ceiling of ≈3.6 m is the hard one ([REPO] §1.4).

| # | Slot id | What it is | Repeatable? | Proposed footprint (m) | Replaces today | One-line rationale |
|---|---|---|---|---|---|---|
| 1 | `hero_landmark` | The arena's unique identity mass, silhouette-first | no (1) | 6 w × 5 h × 3.5 d | `torii`, `ziggurat`, `titan`, `airship`, `island` | One memorable shape gives the arena a "where am I" answer; it is the piece that survives art fatigue and reads at frame size. |
| 2 | `gate_portal` | The threshold/entrance piece the backdrop "opens" through | no (1) | 4 w × 3.5 h × 2 d | `torii` (secondary), arch forms | Wayfinding's *identification* sign belongs at the entrance; it frames the shot and tells the eye the arena is entered, not merely seen. |
| 3 | `column_pillar` | Repeatable vertical module; the kit's snap unit | yes (2–6) | 0.6 w × 2.6 h × 0.6 d | `column`, `piston`, `signal` | Repeats cheaply into colonnades/arcades and sets the band's vertical rhythm — the highest reuse-per-model slot. |
| 4 | `railing_segment` | Repeatable horizontal module (balustrade/fence/parapet) | yes (3–10) | 2 w × 1.1 h × 0.3 d | `rail`, `chain`, `GlassFarRail`-like pieces | The classic kit tile: identical copies that must line up seamlessly — the natural MultiMesh slot (§4 R3). |
| 5 | `light_source` | The arena's accent lamp/post (emissive, not a real light) | yes (2–4) | 0.4 w × 1.8 h × 0.4 d | `lantern`, `floodlight`, `signal` | Carries the palette's `glow`/`accent` into geometry, giving the band its "live" point without spending any of the 8-lights-per-mesh budget. |
| 6 | `furniture` | Human-scale objects (bench, planter, kiosk, crate) | yes (2–4) | 1.2 w × 1.0 h × 0.8 d | `loco`, `foam`, small dressing | One human-scale object is the cheapest way to make the backdrop read as a *place* rather than a wall. |
| 7 | `vegetation_cluster` | Plants: one cluster model (or 2–3 variants) | yes (2–5) | 1.5 w × 2.5 h × 1.5 d | `palm`, `tree`, `bougainvillea`, `petal` | Organic silhouettes break the kit's hard edges, hide seams between modules, and are the strongest per-model "different biome" signal. |
| 8 | `ornament_accent` | Small repeatable motif detail (panel, ring, star, tile) | yes (4–8) | 0.8 w × 0.8 h × 0.2 d | `zellige`, `gearring`, `star`, `orbit` | Where a kit's texture-y richness comes from without new geometry — and, per Burgess, precisely the detail layer that must be varied first if it starts reading as copy-paste. |
| 9 | `signage_banner` | Flat identity/cloth piece (banner, banner-flag, arena name plate) | yes (1–3) | 1.5 w × 1.0 h × 0.05 d | `signal`, painted artwork band | The cheapest slot that says *this* arena's name in *this* arena's voice; flat cards are near-free and can reuse the arena's palette text-free. |
| 10 | `ground_dressing` | What the apron is made of: curb, tile strip, gravel mound, kerb line | yes (as a strip; 1–2 models) | 4 w × 0.4 h × 1.0 d | `BackdropApron` (flattened box today) | Ground is half the frame; a real edge/detail under the glass is the difference between a floor and a plane. |
| 11 | `backdrop_panel` *(procedural-only, no GLB required)* | The sky/horizon surface behind everything | n/a | full band | gradient texture + optional `BackdropArtwork` | Keep it procedural until the sky strategy is decided ([REPO] `CHARTER.md` "Fog"); it is the one slot where a generated panorama would fight the GL Compatibility limits. |

Notes on the set as a whole: slots 3–10 are the reusable "system" (grid/pivot discipline matters most here); slots 1–2 are the identity pieces (uniqueness matters most); slot 11 is infrastructure. That is **10 GLB slots**, matching the owner's stated ≤10 models per map ([REPO] `docs/mission/arena-kit/LOG.md`), with one slot deliberately left to the engine so the budget is never fully spent on decoration. [REC]

---

## 6. Godot import-settings table (GLB props, GL Compatibility, Godot 4.7)

"In-repo today" = the value carried by this project's eight imported athlete GLBs (`godot/assets/athletes/*.glb.import`) — i.e. the importer's defaults, never edited here. `[DOC]` marks values confirmed in the `ResourceImporterScene` class reference.

| Setting | In-repo today | Recommended for kit props | Why |
|---|---|---|---|
| `nodes/root_type` | `""` (Node3D) | `Node3D` (keep) | A slot asset must be transformable as one unit; a non-Node3D root loses 3D placement. [DOC] |
| `nodes/apply_root_scale` | `true` | `true` | Applies `root_scale` to meshes so a child added later is not silently rescaled. [DOC] |
| `nodes/root_scale` | `1.0` | `1.0` (per-slot override only if a slot needs a documented correction) | No rescaling by default; scale is an upstream (Meshy Resize) concern, and a hidden importer rescale defeats the AABB drift check (§4 R1). [DOC] |
| `nodes/use_name_suffixes` | `true` | `true` | Keeps `-col`/`-convcol`/`-noimp`/`-alpha`/`-vcol` available — the documented way to strip generator helper geometry and to declare collision/cutout at the model. [DOC] |
| `nodes/use_node_type_suffixes` | `true` | `true` | Enables the node-type suffixes (`-col`, `-colonly`, …); disable only if a generated name accidentally matches one. [DOC] |
| `meshes/generate_lods` | `true` | `true` | Free distance LOD on a fixed-camera band; harmless, and the docs' own default. Disable per-mesh only if a decimation artifact shows. [DOC] |
| `meshes/create_shadow_meshes` | `true` | `true` | Shadow-mesh vertex welding is a pure win; pair with `cast_shadow = OFF` per piece that cannot cast into play. [DOC] |
| `meshes/ensure_tangents` | `true` | `true` | Meshy supplies normal maps; tangents are required for correct normal-map display. Letting the DCC supply them is preferred, but keeping this `true` is the safe default for generated assets. [DOC] |
| `meshes/light_baking` | `1` | leave default; revisit if UV2 generation costs | This project bakes no lightmaps; the import-time UV2 cost is the only reason to change it. Confirm the "Disabled" enum value in the Import dock before scripting it (§7.2). [DOC/REPO] |
| `meshes/force_disable_compression` | `false` | `false` | Props are small; keep VRAM compression on. |
| `meshes/deduplicate_surfaces` (`array_mesh/*`) | `true` | `true` | Merges identical surfaces in a generated mesh — one fewer draw call per mesh for free. [DOC] |
| `materials/extract` | `0` | `0`, unless we adopt a shared kit material | Inline materials keep each prop self-describing; extraction to `.tres` is the route to one kit material across all slots (§4 R2). [DOC] |
| `gltf/embedded_image_handling` | `1` | keep whatever the batch's texture policy is, but **decide it once** (extract = external PNGs we can re-import/atlas; embed = smaller folders) | In-repo GLBs sit at `1` with extracted-looking PNG siblings; §7.2 flags the label mapping as unverified. [DOC/REPO] |
| `gltf/naming_version` | `2` | `2` | Nothing to gain from reverting. |
| Collision (`-col`/`-colonly`) | not used (athletes) | **not used for decor** | Trimesh/convex collision on scenery buys nothing (field law keeps scenery outside play) and costs physics bookkeeping; if one slot ever must block, add one primitive collider in the loader. [DOC] |
| Per-node `cast_shadow` | n/a (set per node) | `OFF` for pieces that cannot shadow the court | Shadows are the expensive part of a lit frame; in Compatibility shadowed lights are multi-pass. [DOC] |
| Per-node `visibility_range` (HLOD) | n/a | optional, for pieces that are only visible from one preset | The documented per-object LOD/distance control; the band is preset-dependent, so a slot may be genuinely invisible under `wide`. [DOC] |
| Lights/cameras inside the GLB | none | none — reject any that arrive | Compatibility allows 8 omni + 8 spot lights per mesh and no PCSS; a prop must not add lighting. [DOC] |

---

## 7. Uncertainty, contradictions, and what to verify before freezing

1. **Renderer + instancing.** Godot's own docs say automatic instancing is Forward+ only, which is a hard constraint for us; the widely shared claim that "Godot 4 batches identical meshes automatically" is therefore **false for this project** and should not leak into the standard. [DOC]
2. **Numeric mappings I could not verify from the docs text I read.** The *values* above are read from this repo's `.import` files; the *labels* were not in the extracted doc text. Partial resolution: the sibling scan `scan/repo-arena-seams.md` §3.4 reads `gltf/embedded_image_handling=1` as **Extract Textures**, which is consistent with the sibling PNGs on disk (`colosso_texture_0.png`, `colosso_normal.png`, `colosso_texture_0_metallic_roughness.png`) and with `docs/art/character-standard.md`'s rule that those PNGs are produced by Godot's import as `<glb>_<glTF image name>.png` and must never be renamed by hand (renaming is discarded on reimport). `meshes/light_baking=1` remains **unresolved** — confirm in the Import dock before scripting it.
3. **Export build behaviour for dynamically-mounted slots.** Imported resources are remapped into the PCK, but a slot folder that is only ever reached through `load()` has no static reference. Before M3 is called done, export a build with (a) an empty slot folder and (b) a filled one, and confirm both behave — Godot documents the analogous footgun for non-resource files ("not exported by default") but the `.glb`-only-reached-at-runtime case deserves a direct test. [REC]
4. **Meshy generation is non-deterministic per model.** Nothing in the sources says a prompt yields a stable scale or a stable material; the whole point of R1/R2 is to normalise *after* generation. Two of the ten models coming back at a wildly different detail level should be planned for, not treated as a defect.
5. **Fallout 4 talk cited from slides only.** I did not watch the GDC 2016 video; the GDC 2013 transcript and the Level Design Book summary are the load-bearing citations for kit theory here. The Fallout material is corroborating, not source-critical.
6. **The nastyrodent naming/grid article is a vendor blog.** Its statements (1 m base unit, bottom-front-left pivot, `SM_Kit…` pattern) are consistent with the Burgess talks and with general practice, but it is not an engine or studio publication; the standard should cite it as "practice opinion", and any number we freeze from it should be sanity-checked against our own band measurements (§1.4), which are the ones that actually gate us.
7. **Contradiction to keep in view: "grid" vs our placement model.** The published kit practice is a *snap grid* with edge-to-edge pieces; our props are *individually anchored* in a band. Both are legitimate, but the standard should not pretend we are building a tile grid: only slots 3, 4, 8 and 10 are genuinely grid-shaped, and the rest are anchored with declared dimensions. Saying so prevents a future lane from trying to force a colonnade grid onto the hero landmark. [REC]

---

## 8. Source list (all retrieved 2026-09-18)

Kit / level-art practice
1. Burgess, J. & Purkeypile, N. — "Skyrim's Modular Level Design", GDC 2013 (transcript, published 2013-04-19): <http://blog.joelburgess.com/2013/04/skyrims-modular-level-design-gdc-2013.html>
2. "GDC 2016: Modular Level Design of Fallout 4" (slides): <https://www.slideshare.net/slideshow/gdc-2016-modular-level-design-of-fallout-4/59770460>
3. The Level Design Book — "Modular kit design": <https://book.leveldesignbook.com/process/blockout/metrics/modular>
4. The Level Design Book — "Metrics": <https://book.leveldesignbook.com/process/blockout/metrics>
5. The Level Design Book — "Environment Art": <https://book.leveldesignbook.com/process/env-art>
6. The Level Design Book — "Composition": <https://book.leveldesignbook.com/process/blockout/massing/composition>
7. The Level Design Book — "Wayfinding": <https://book.leveldesignbook.com/process/blockout/wayfinding>
8. The Level Design Book — "Texturing" (trim sheets, panels, modular wall textures): <https://book.leveldesignbook.com/process/env-art/texturing>
9. The Level Design Book — "Optimization" (draw-call budget table; batching vs instancing): <https://book.leveldesignbook.com/process/env-art/optimization>
10. "Modular Prop Kits for Games: Grid Systems, Snapping, and Reuse" (vendor blog — practice opinion): <https://nastyrodent.com/modular-prop-kits-for-games/>

Godot 4.7 (stable) documentation
11. Import configuration: <https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/import_configuration.html>
12. Node type customization using name suffixes: <https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/node_type_customization.html>
13. Model export considerations (Y-up, +Z front, metres, triangulate): <https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/model_export_considerations.html>
14. `ResourceImporterScene` (import defaults): <https://docs.godotengine.org/en/stable/classes/class_resourceimporterscene.html>
15. Mesh LOD: <https://docs.godotengine.org/en/stable/tutorials/3d/mesh_lod.html>
16. Overview of renderers (Compatibility feature table, lights/shadows limits): <https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html>
17. 3D lights and shadows (8 lights per mesh in Compatibility; multi-pass shadows): <https://docs.godotengine.org/en/stable/tutorials/3d/lights_and_shadows.html>
18. Optimizing 3D performance (auto-instancing Forward+ only; MultiMesh guidance; lightmap/static bake): <https://docs.godotengine.org/en/stable/tutorials/performance/optimizing_3d_performance.html>
19. Optimization using MultiMeshes (one draw primitive; no per-instance culling; partition workaround): <https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html>
20. Using MultiMeshInstance3D: <https://docs.godotengine.org/en/stable/tutorials/3d/using_multi_mesh_instance.html>
21. `ResourceLoader` (`exists`, `load`, cache modes, missing-resource behaviour): <https://docs.godotengine.org/en/stable/classes/class_resourceloader.html>
22. `@GDScript` (`load` / `preload` semantics): <https://docs.godotengine.org/en/stable/classes/class_%40gdscript.html>
23. Resources (custom resources; preload at parse time): <https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html>
24. `FileAccess` (non-resource files are not exported by default): <https://docs.godotengine.org/en/stable/classes/class_fileaccess.html>
25. Exporting projects (non-resource export filters): <https://docs.godotengine.org/en/stable/tutorials/export/exporting_projects.html>
26. Collision shapes (3D) (trimesh vs convex vs primitive; StaticBody-only concave): <https://docs.godotengine.org/en/stable/tutorials/physics/collision_shapes_3d.html>

Meshy (asset source for this pipeline)
27. "Resizing and Repositioning Models in Meshy" (models come between −1 and 1; Resize: height, units, Bottom/Center origin): <https://help.meshy.ai/en/articles/10523176-resizing-and-repositioning-models-in-meshy>
28. Meshy Docs — Resize API (`resize_height` / `resize_longest_side` / `auto_size`, `origin_at`): <https://docs.meshy.ai/en/api/resize>
29. Meshy Docs — 3D Export Formats (GLB embeds textures): <https://docs.meshy.ai/en/webapp/guides/platform/export-formats>
30. Meshy Docs — Quickstart (`model_urls.glb`, signed time-limited URLs, `expires_at`): <https://docs.meshy.ai/en/api/quick-start>
31. Meshy Docs — Image to 3D API (task object incl. `texture_urls` base_color/normal/metallic/roughness/emission, `target_formats`): <https://docs.meshy.ai/en/api/image-to-3d>
32. Meshy Help — "Import Meshy Models into Any Engine … Godot" (recommended format: GLB): <https://help.meshy.ai/en/articles/11973241-import-meshy-models-into-any-engine-unity-unreal-roblox-godot>

Repo evidence (read-only, primary tree, 2026-09-18)
- `godot/game/arenas/arena_library.gd:242-263` — `build()` order (world → court → scenery), meta on the root.
- `godot/game/arenas/arena_scenery.gd:101,109-169,186-200,238-272` — `FIELD_LAW_Z`, scenery build, prop containers, band math, field-law report.
- `godot/game/arenas/arena_style.gd` — `STYLES` tables (`props: [{kind,x,y,h,r,tint}]`), world deck entries (name/desc/palette).
- `godot/game/arenas/arena_catalog.gd` — the one catalog module for display/availability facts.
- `godot/tests/world_arenas_field_law_test.gd:25-36` — field law (both planes) + red control; frozen node-name list.
- `godot/tests/world_arenas_frame_test.gd:100` — every `Dressing_*` object inside the frame.
- `godot/src/ui/screens/ArenaScreen.gd:763`, `godot/src/ui/components/ControlLegend.gd:434`, `godot/src/audio/audio_port.gd:239` — the existing optional-resource idiom.
- `godot/assets/athletes/*.glb.import` — the project's live GLB import settings (all defaults).
- `godot/project.godot:15,166-167` — 4.7, GL Compatibility.
- `docs/mission/arena-kit/CHARTER.md`, `LOG.md` — mission outcome, gates, limits (10 models/map).
- `docs/mission/world-arenas/integrator.md:36,64` — `BACKDROP_Z` shared with the nine frozen arenas.
- `godot/assets/arenas/` — **does not exist yet** (M2 target folder).
- `godot/src/character/athlete_rig.gd:56-58,367-374,790-797` — the runtime `GLTFDocument` load pattern; the "no `.import` cache" rationale; the `get_aabb()` / Armature-0.01 warning.
- `docs/art/character-standard.md:70-72,118-133` — import scale stays `1.0`; one material / max three maps; extracted PNG naming (`<glb>_<glTF image name>.png`) must not be renamed by hand (per the sibling scan `scan/repo-arena-seams.md` §3.2/§3.4, which quotes it).
- Sibling scans in this folder: `repo-arena-seams.md` (module responsibilities, the two GLB load paths, proposal at the existing seams — read §3.1–3.4 alongside §2.1 here), `meshy-props.md` (Meshy tiers/endpoints/cost), `image-prototyping.md` (image batch). Where this file and `repo-arena-seams.md` overlap, that file is the more detailed source on *repo seams*; this file adds the *industry kit theory*, Godot import/instancing settings, and the slot taxonomy.
