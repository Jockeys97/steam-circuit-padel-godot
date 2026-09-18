# repo-arena-seams — how the five world arenas are built today, and where an "arena kit" intake plugs in

Read-only scan. Tree: `/Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot`
(PRIMARY), HEAD `deab8cf` ("fix(arena): selector click-to-play, …"). No engine run, no edits outside
this file. Every claim carries a `file:line` handle. All paths below are repo-relative.

Scope: the five world arenas `torii, medina, carioca, aurora, egeo` (port additions, `family: "world"`,
no row in `js/data.js`; see `godot/game/arenas/arena_style.gd:46-66`), the modules that build them,
the GLB precedent set by the athletes, the capture tooling, the frozen test pins, and a concrete
intake proposal.

---

## 1. Responsibilities of the five arena modules

### 1.1 `godot/game/arenas/arena_catalog.gd` (145 lines, `extends RefCounted`)

The UI-facing catalog: the nine frozen arenas plus the world five, for BOTH UI paths (the ported menu
column and the recreated `ArenaScreen`). It owns no geometry — it is pure data/selection policy and
the file says so (`arena_catalog.gd:25-30`). Constructed by `content_gate.gd::arena_catalog(demo, exposed)`
via `_init(demo, exposed)` (`arena_catalog.gd:50-52`).

| Function | Lines | What it owns |
|---|---|---|
| `_init(demo, exposed)` | 50-52 | the build's own answers handed in by `content_gate.gd` |
| `exposed_ids()` | 56-60 | frozen ids the build lists as a choice |
| `ids()` / `world_ids()` / `all_ids()` | 63-72 | re-exports of `Arena.ids()/world_ids()/all_ids()` |
| `is_world(id)` | 75-76 | re-export of `ArenaStyle.is_world()` |
| `index_of(id)` | 81-86 | the frozen roster index or -1 (one answer for both UI paths) |
| `frozen_rows(career)` | 93-110 | the nine display rows: locale keys, art path, demo wall, career wall, `selectable` |
| `world_rows()` | 117-120 | the world display rows THIS build offers; **`[]` in a demo** (117-119) |
| `rows(career)` | 124-127 | frozen nine then world set |
| `seat(id)` | 139-145 | `{index, world, offered}` for a selection |

Key fact for kit work: `world_rows()` delegates to `Arena.world_rows()` (`arena_library.gd:201-205`),
so a per-arena kit descriptor that must reach the UI would be added in `world_info()` (§1.2), not here.

### 1.2 `godot/game/arenas/arena_library.gd` (264 lines, `extends RefCounted`) — the build API

Preloads `Frozen`, `Court`, `CourtBuilder`, `ArenaStyle`, `ArenaScenery` (`arena_library.gd:64-68`).

- **World physics stand-ins** (they are NOT tuning): `WORLD_WALL_BOUNCE := 0.89`,
  `WORLD_FLOOR_GRIP := 1.0` (`arena_library.gd:91-92`), documented at `70-90`, marked `provisional: true`
  in `world_info()` (`173-195`).
- `rows()` 96-97, `ids()` 100-104, `default_id()` 107-109, `has(id)` 112-113 (`ids()` OR `ArenaStyle.is_world`),
  `world_ids()` 117-118, `all_ids()` 122-125, `is_world()` 128-129, `row(id)` 133-137.
- `info(id)` 144-162 — frozen row + presentation keys: `family`, `glow`, `sky`, `apron`, `artwork`,
  `props`, `prop_kinds`, `rear_alpha`, `backdrop_z`. (This is the natural home of any per-arena kit
  descriptor the UI and tests should see.)
- `world_info(id)` 173-195 — same shape for a world arena, name/desc/palette out of `arena_style.gd`,
  physics from the two constants above.
- `world_rows()` 201-205, `signature(id)` 208-209, `prop_kinds(id)` 214-218 (reads `style["props"][].kind`),
  `rear_alpha(id)` 223-226 (`CourtBuilder.rear_alpha(wallBounce)`), `band(preset, z)` 230-231.
- **`build(id, preset)` 242-256 — the single construction entry point.** Node name `"Arena"` (248),
  metas `arena_id`/`family`/`world`/`wallBounce` (249-252), then exactly three builder calls:
  `CourtBuilder.build_world(root, arena)` (253), `CourtBuilder.build_court(root, arena, wallBounce)` (254),
  `ArenaScenery.build(root, id, arena, preset)` (255). `null` for an unknown id (243-245).
- `build_into(parent, id, preset)` 259-264 — the call the match scene makes.

### 1.3 `godot/game/arenas/arena_style.gd` (490 lines, `extends RefCounted`) — presentation data only

- `ARTWORK_DIR := "res://game/arenas/art/"` (75).
- **`const STYLES := {…}` 96-425**: nine frozen entries copied from `js/render.js` (97-280) and the
  five world entries (281-424). A world entry carries `family: "world"`, `name`, `desc`, `sky`, `apron`,
  `glow`, `palette`, `artwork: ""` and `props` — e.g. torii `282-313`, medina `314-342`, carioca `343-372`,
  aurora `373-401`, egeo `402-424`.
- `style(id)` 433-436 (unknown → `STYLES["officina"]`, deliberately not `keys()[0]`), `ids()` 442-443,
  `world_ids()` 448-453 (keys whose `family == "world"`), `is_world()` 457-458, `family()` 461-462.
- `signature(id)` 469-482 — the distinctness digest: `family|sky stops|apron|glow|artwork|props count`.
  **Note: it digests the props TABLE, not the built meshes** — a kit swap that keeps the table unchanged
  leaves every signature byte-identical (relevant to the distinctness gates in §5).
- `artwork_path(id)` 488-490.

### 1.4 `godot/game/arenas/arena_scenery.gd` (808 lines, `extends RefCounted`) — backdrop + props

Constants: `BACKDROP_Z := -12.0` (73), `ARTWORK_BAND := 0.178` (79), `VEIL` stops (81-85),
`APRON_H := 0.42` (88), `FIELD_LAW_Z := -8.0` (101).

- **`build(parent, id, arena, preset)` 109-169 — the scenery root.** Creates `Node3D` named `"Scenery"`
  (112) with metas `arena_id`/`family` (113-114), then:
  1. `Backdrop` — a textured quad from the sky-gradient (`CourtBuilder.gradient_texture`, `textured_quad`)
     at `BACKDROP_Z` (123-124);
  2. `BackdropArtwork` + `BackdropVeil` only when the arena has artwork (128-133, world arenas: none);
  3. `BackdropApron` (136-138);
  4. **one container per authored prop** (160-168): `Node3D` named `"Dressing_%s%d" % [kind, i + 1]` (164),
     positioned `x = prop.x * x_scale`, `z = prop.z(default -7.65) - 4.0` → default z = -11.65 (165),
     `set_meta("kind", kind)` (166), then `_build_prop(container, prop, ctx)` (168).
- `band(preset, z, aspect)` 186-208 — closed-form proscenium band from the camera preset
  (`top`, `half_x`, `prop_half_x`); `_depth`/`_world_y` 211-220.
- `field_law_report(arena_root)` 238-272 — the production-side law check (court nodes present; no
  `Scenery` child reaching z > -8.0, measured per mesh AABB corner at 261-271); `_xform_to` 277-283,
  `_meshes_of` 287-291.
- `_load_artwork(id)` 303-315 — **the existing "load an external file at runtime" precedent**:
  `FileAccess.file_exists` → `Image.load_from_file` → crop → `ImageTexture.create_from_image`; comment at
  300-302 says it is read at runtime *"so nothing depends on the editor's import step"*.
- `_build_prop(parent, prop, ctx)` 421-793 — the `match kind:` table. `_part` 326-345 (unshaded
  `StandardMaterial3D` override, alpha → `TRANSPARENCY_ALPHA` + `CULL_DISABLED`, else `Court.material`),
  `_sky_color` 353-374, `_alpha_quad` 381-389, `_peak` 398-403, `_tint` 406-414, `_gear` 802-808.

### 1.5 `godot/game/arenas/court_builder.gd` (381 lines, `extends RefCounted`) — the shared kit

Court, net, cage, environment, lights, camera-independent primitives. Constants `GLASS_H` (32),
`REAR_TINT`/`SIDE_TINT`/`SIDE_ALPHA` (35-37), `REAR_ALPHA_MIN/MAX` (40-41), frame colours (45-48),
`REAR_PANES := 6` (50).

- `rear_alpha(wall_bounce)` 54-56 (0.83→0.30, 0.95→0.46), `glass_params` 59-60.
- Primitives: `box` 68-69, `unshaded` 74-88, `box_mesh` 91-94, `cyl_mesh` 97-104, `cone_mesh` 107-114,
  `ball_mesh` 117-123, `ring_mesh` 126-132, `quad_mesh` 135-138, `gradient_texture` 144-160,
  `textured_quad` 164-178.
- `build_world(parent, arena)` 187-211 — `WorldEnvironment` + `Sun` + `Fill`.
- `build_court(parent, arena, wall_bounce)` 220-290 — `Surround` (225-232), `Court` (234-240), lines
  `LineFar/LineNear/LineLeft/LineRight/CenterLine/ServiceFar/ServiceNear` (246-252), `Net` subtree
  `NetWire/NetCord/NetTape` (256-270), `NetPostL/R` (271-272), glass cage (274), `AccentPostL/R` (279-280),
  `GearRing` (281-290).
- `build_glass_cage` 297-315, `build_rear_wall` 328-356 (`GlassFar` + `GlassFar2..6` at 341,
  `GlassFarDivider1..5` at 348-350, `GlassFarBottom` 353, `GlassFarRail` 355, `GlassFarRailHilite` 356),
  `glass_wall` 361-381 (`GlassLeft/Right/Near` + `…Rail` + `…Post`).

Shared by the frozen nine AND the world five — identical geometry for all fourteen (`arena_library.gd:51-53`).

---

## 2. How each of the five world arenas builds its scenery today

**Pipeline (identical for all five).** `Arena.build(id, preset)` → `CourtBuilder.build_world` +
`CourtBuilder.build_court` + `ArenaScenery.build(root, id, arena, preset)`
(`arena_library.gd:253-255`). The only per-arena inputs the scenery consumes are: `style.sky` (the
`Backdrop` gradient, `arena_scenery.gd:123-124`), `style.apron` (`BackdropApron`, 136-138),
`style.glow` (the `ctx["glow"]` tint, 148) and `style.props` (the container loop, 159-168). There is
**no per-arena 3D asset, no imported mesh, nothing generated**: every object is a Godot primitive
created from `BoxMesh/CylinderMesh/SphereMesh/TorusMesh/QuadMesh` through `court_builder.gd`'s mesh
helpers (`arena_scenery.gd:33-39` states this explicitly).

**Assets on disk today (none of them 3D):** `godot/game/arenas/art/world/<id>.png` — the UI card art
for the five (`torii.png`, `medina.png`, `carioca.png`, `aurora.png`, `egeo.png` + `.import` sidecars).
These are **card images, not backdrops**: the world five have `artwork: ""` in `STYLES` and build a
gradient-only backdrop. `godot/assets/arenas/` does **not exist yet** (M2 target in the charter).

### 2.1 torii — Portale Torii

- Table: `arena_style.gd:282-313`; 16 props. Kinds: `moon`, `petal`×5, `torii`×5, `lantern`×4, `pagoda`.
- Kind implementations (`arena_scenery.gd`): `torii` 555-565 (`PillarL`, `PillarR`, `Nuki`, `Shimaki`,
  `Kasagi`, `Gakuzuka`), `pagoda` 566-580 (`Plinth`, `Body0..4`, `Roof0..4`, `Spire`, `Finial`),
  `lantern` 581-589 (`Cord`, `Paper`, `CapTop`, `CapBottom`), `petal` 590-596 (6 tilted quads),
  `moon` 597-602 (`Disc` + `Occluder` painted with `_sky_color`).
- Built size (proof log, `docs/mission/world-arenas/proof/round2/…baseline_slice.log`-adjacent
  `ARENA id=` lines): **meshes=206, props=16, dressing=16**, closest scenery z = -10.83 (`Roof0`).

### 2.2 medina — Cortile Medina

- Table: `arena_style.gd:314-342`; 13 props. Kinds: `sun`, `wall`, `zellige`, `arch`, `minaret`,
  `palm`×5, `lantern`×3.
- Implementations: `sun` 603-607 (`Disc`, `Halo`, `HaloWide` rings), `wall` 627-634 (`Wall`, `Cap`,
  `Merlon0..n`), `zellige` 635-645 (`Grout` + one 45°-rotated `Tile%d` per tile, geometry only),
  `arch` 646-655 (`Opening`, `JambL/R`, `Arch`, `Keystone`), `minaret` 656-664
  (`Base/Shaft/Balcony/Crown/Dome/Spire`), `palm` 665-676 (`Trunk` + 8 `Frond%d` flattened cones),
  `lantern` 581-589.
- Measured: **meshes=235, props=13, dressing=13**, closest z = -11.13 (`Base`).

### 2.3 carioca — Terrazza Carioca

- Table: `arena_style.gd:343-372`; 14 props. Kinds: `sun`, `cloud`×2, `ridge`, `peak`×2, `cable`,
  `palm`×4, `foam`×3.
- Implementations: `ridge` 677-686 (chain of `_peak` triangular prisms, `count`/`spread`/`alpha`
  params), `peak` 687-695 (`Skirt`, `Dome`, optional `TwinSkirt`/`TwinDome`), `foam` 696-705
  (flattened `TorusMesh` rings), `cable` 706-712 (`Cable`, `Hanger`, `Car`), `cloud` 437-441.
- Measured: **meshes=183, props=14, dressing=14**, closest z = -10.59 (`Skirt`).

### 2.4 aurora — Banco Aurora

- Table: `arena_style.gd:373-401`; 13 props. Kinds: `star`×5, `moon`, `aurora`×2, `basalt`×2,
  `snowridge`, `steam`×2.
- Implementations: `star` 608-614 (constellation of 4 sphere points), `aurora` 615-626
  (`Ribbon` + `RibbonCore` gradient quads with their own alpha via `_alpha_quad`), `basalt` 713-723
  (`Column%d` hex prisms of varying height + pale `Cap%d`), `snowridge` 724-739 (refined in round 2,
  comment at 726-731), `steam` 740-746 (translucent `Puff%d`).
- Measured: **meshes=181, props=13, dressing=13**, closest z = -11.10 (`Column1`).

### 2.5 egeo — Isola Egeo

- Table: `arena_style.gd:402-424`; 7 props. Kinds: `sun`, `sea`, `island`×2, `windmill`,
  `bougainvillea`×2.
- Implementations: `island` 747-760 (`Cliff` + `House0..4` cubes + even-index `Dome%d` cobalt spheres),
  `windmill` 761-771 (`Tower`, `Cap`, `Hub`, `Sail0/1`), `bougainvillea` 772-779 (`Block` + 6 `Bloom%d`),
  `sea` 780-791 (gradient quad `Sea` + `Wave0..2` strokes).
- Measured: **meshes=159, props=7, dressing=7**, closest z = -11.12 (`House0`).

### 2.6 Is there any detail-level / variation system?

**No.** There is no LOD, no holodeck/impostor, no variant or quality switch anywhere in
`godot/game/arenas/*.gd` or `godot/game/court.gd` (grep for `lod|detail_level|quality|variant` finds
only unrelated `Variant` type usages: `court_builder.gd:149`, `court.gd:117` comment). The only
"variation" levers that exist today are:

- **per-prop parameters inside a kind** — `count`, `spread`, `alpha`, `twin`, `hang`, `lean`, `w`, `h`, `r`
  (`arena_scenery.gd:417-429` and every kind's own `_size(prop, …)` reads);
- **the camera preset's `x_scale`** (`arena_scenery.gd:143,165`) — props are authored for the default
  preset's top row (±14.35 m) and rescaled for `wide`/`playable`;
- **material brightness wiring** — `wallBounce → rear_alpha` (`court_builder.gd:54-56`);
- **the backdrop gradient/artwork switch** — artwork present in the reference or gradient-only.

There is no notion of a "slot", no asset folder, no manifest, and nothing that reads
`godot/assets/**` for an arena. `godot/assets/` contains only `athletes/`, `audio/`, `ui/`.

---

## 3. How GLBs are loaded elsewhere in this repo (the athlete precedent)

### 3.1 The load pattern — runtime `GLTFDocument`, not the import pipeline

`godot/src/character/athlete_rig.gd:56-58` (header):

```
## The GLBs are loaded at RUNTIME through GLTFDocument, not through Godot's
## import pipeline, so this scene needs no `.import` cache and no `project.godot`
## change.
```

The loader itself, `athlete_rig.gd:367-374` — quoted exactly:

```gdscript
func _load_glb(path: String) -> Node3D:
	if not FileAccess.file_exists(path):
		return null
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(path, st) != OK:
		return null
	return doc.generate_scene(st) as Node3D
```

Selection is a **pre-build** operation: `set_athlete_asset(athlete_id)` (`athlete_rig.gd:184-200`)
reads the `ATHLETE_GLB` table (`104-108`) and the `COMPANION_CLIPS` table (`121-134`); the rig builds
lazily on first use (`_ensure_built()` 227-235 → `_build()` 242-306), which looks up
`Skeleton3D`/`MeshInstance3D`/`AnimationPlayer` by class (250-252) and sets
`_mesh_instance.extra_cull_margin = 4.0` (265). The factory seam is
`AthleteSpawn.make()` (`godot/src/character/athlete_spawn.gd:127-165`): `set_athlete_asset` **before**
`get_load_error()` (140-147), i.e. "a missing GLB returns `null`, never a half-built node".

### 3.2 Scale conventions

- The rig never scales the model. Import scale stays **1.0** — `docs/art/character-standard.md:70-72`:
  *"la scala di import in Godot resta 1.0"*, and `godot/assets/athletes/colosso.glb.import:21-22`
  confirms `nodes/apply_root_scale=true`, `nodes/root_scale=1.0`.
- The GLB's mesh vertices are already in metres; the bone hierarchy is in centimetres under an
  `Armature` node scaled 0.01. `athlete_rig.gd:790-797` warns:

```
## Do NOT use `MeshInstance3D.get_aabb()` for this. On this GLB the mesh vertices are
## already in metres (mesh-space AABB 1.276 x 1.800 x 0.541), while the bone hierarchy
## is in centimetres under an `Armature` node scaled 0.01. Multiplying the mesh AABB by
## the mesh's global transform therefore double-counts that 0.01 and reports the athlete
## as 0.018 m tall.
```

- `get_world_extent()` (`803-823`) walks bone poses through the node chain to get the true figure
  (~1.04 × 1.68 × 0.27 m). Facing convention: `set_facing_degrees`, 0 = +Z CCW about +Y
  (`athlete_rig.gd:15`, `athlete_spawn.gd:121`).

### 3.3 Material override approach

- The GLB's own material is read off surface 0 (`athlete_rig.gd:267-271`), kept as `_base_material`
  and exposed via `get_base_material()` (834-836).
- The override lives in `set_outfit()` (`521-548`). The non-glTF block, `athlete_rig.gd:536-544`:

```gdscript
	if not _use_glb_pbr:
		_override.metallic = DEFAULT_METALLIC      # 0.0
		_override.roughness = DEFAULT_ROUGHNESS    # 0.85
		# The Meshy exports carry emissiveFactor (1,1,1) with the base-colour texture
		# wired in as the emissive map; left on, that floods the athlete with its own
		# albedo. Emission off is part of the same non-glTF override block, so
		# `use_glb_pbr(true)` still renders exactly what the GLB asks for.
		_override.emission_enabled = false
	_mesh_instance.set_surface_override_material(0, _override)
```

with `DEFAULT_METALLIC := 0.0` / `DEFAULT_ROUGHNESS := 0.85` (`athlete_rig.gd:146-148`), and the escape
hatch `use_glb_pbr(true)` (`565`). Read-back hooks for tests: `get_material_state()` (570-591, exposes
`metallic`/`roughness`/`emission` as strings) and `AthleteSpawn.describe()` (`athlete_spawn.gd:177-196`).
The arena-relevant rule: **Meshy exports arrive with emission on; turn it off in a shared non-glTF
override block, keep `glb_pbr` as the reversible switch.**

### 3.4 Sidecar `.import` files

Two facts, both true today and both relevant:

1. **The on-disk athlete assets carry tracked import sidecars.** `godot/assets/athletes/` contains
   `colosso.glb.import`, `colosso_texture_0.png` (+`.import`), `colosso_texture_0_metallic_roughness.png`
   (+`.import`), `colosso_normal.png` (+`.import`) — the same trio for `maestro-rigged`,
   `maestro-idle/walking/running`, `volpe-rigged/walking/running`. Settings that matter
   (`godot/assets/athletes/colosso.glb.import`): `nodes/root_scale=1.0` (line 22),
   `meshes/generate_lods=true` (27), `skins/use_named_skins=true` (32),
   `gltf/embedded_image_handling=1` (44) — *Extract Textures*.
2. **Those sidecars are NOT what the game loads** — the runtime path (§3.1) reads the `.glb` bytes
   directly, so the rig works without an import pass. The rules around the sidecars are documented in
   `docs/art/character-standard.md:118-133`: one material, max three maps; the extracted PNGs are
   produced by Godot's import, named `<glb>_<glTF image name>.png`, **never renamed by hand**
   (renaming is thrown away on the next import; if a name must change, change the image name inside
   the GLB). Frozen-file practice in this repo: stage the GLBs **with** their sidecars (skill
   `padel-godot-port-ops`, "Inserting the next Meshy athlete"), and never let an open editor rewrite
   `.import` settings silently.

For an arena kit the two models are therefore:

- **runtime `GLTFDocument` (athlete-style):** drop a `.glb` in a folder, it mounts; no `.import`, no
  editor pass, no fresh-clone `--import` ordering; but no auto-generated LODs and no editor preview.
- **editor-imported `PackedScene`:** needs `.import` sidecars tracked and an import pass before tests
  (see the skill's fresh-clone gotcha), gives `generate_lods` and inspector preview.

`arena_scenery.gd`'s own artwork loader already chose runtime (`_load_artwork`, 303-315, comment
300-302: *"so nothing depends on the editor's import step"*), which is the stronger in-repo precedent
for drop-in assets.

---

## 4. How arena stills are captured (`tools/world-arenas/**`)

**Driver:** `tools/world-arenas/run_proof.sh` (166 lines). One Godot process at a time: every step is
guarded by `pgrep -x Godot` (`run_proof.sh:62-70`) and killed by a per-process watchdog (`84-91`);
each step journals command, exit code, `PASS n/n`, `SCRIPT ERROR` count and log sha256 to
`results.tsv` (93-99). Outputs land in `tools/world-arenas/out/<run-id>/` (gitignored, 30-31);
`python3 tools/world-arenas/tree_digest.py` brackets the run (108, 139) and `build_manifest.py` folds
results into `MANIFEST.json`/`MANIFEST.md` (140).

**The capture command** (`run_proof.sh:121-122`, `133-134` for the default arena set):

```bash
$GODOT --path godot --rendering-driver opengl3 --resolution 1280x720 \
  res://tests/world_arenas_capture.tscn -- --arenas=<a,b,…> --out=<run-dir>/captures
$GODOT --path godot --rendering-driver opengl3 --resolution 1280x720 \
  res://tests/world_arenas_menu_capture.tscn -- --out=<run-dir>/captures
```

`--rendering-driver opengl3` + a real display server are mandatory — a `--headless` dummy driver
renders blank frames and the harness refuses by name (`world_arenas_capture.gd:83-85`).

**Presets:** `default,wide,playable`, defaulting in the harness (`world_arenas_capture.gd:318-327`)
and matching the game's own table `Court.CAMERAS` (`godot/game/court.gd:118-137`):
`default` pos (0,20,27.5) pitch -36.0274° fov 30; `wide` pos (0,22,18) pitch -50° fov 60;
`playable` pos (0,8,17) look_at (0,0.9,-1) fov 60. The camera is built by the game's own
`Court.build_camera()` (`court.gd:279-290`, node name `MatchCam`) — the tests deliberately measure
through that call, never a copy.

**Output sizes / paths:** exactly `1280x720` (`CAPTURE_SIZE := Vector2i(1280, 720)`,
`world_arenas_capture.gd:47`; the harness fails if the image is not the full render target and not the
documented size, 158-166). One PNG per arena × preset:
`<out>/<preset>/arena-<id>.png` (`213`), plus `<out>/captures.json` (293-309) with per-frame sha256,
colour count, signature, projected framing points and glass state. Menu capture writes
`<out>/menu/menu-world-chooser.png` + `<out>/menu_capture.json`
(`world_arenas_menu_capture.gd:9-10`, gate list 11-23).

**What each capture gates** (`world_arenas_capture.gd:17-37` header, implemented 88-240): non-vacuous
frame (≥ 8 colours on a 64×36 grid, 47-54, 168-181); within one preset the five arenas must produce
**five different signatures** (104-107); the framing mandate through the live camera (court corners +
side/rear glass extents inside the frame, 183-207); the glass cage present, every `Glass*` mesh
visible, rear panes at `Arena.rear_alpha(id)` and sides at `CourtBuilder.SIDE_ALPHA`, and **every
scenery mesh visible** (`_glass_state`, 243-275). Committed evidence lives under
`docs/mission/world-arenas/proof/captures/**` and `proof/round2/captures/**` (5 arenas × 3 presets +
menu, with `captures.json`, `sha256.txt`, `MANIFEST.md`).

---

## 5. The exact node names and structural facts the tests pin

These are the constraints a kit swap must not break. Grouped by test file.

### 5.1 `godot/tests/game_slice_test.gd` — `_arena_library()` (1884-2033) and `_arena_scenery_in_frame()` (2055-2120)

- nine frozen ids, in order, from the frozen table (1886-1891);
- `Arena.build(id,"default")` non-null for all nine (1914-1917) and **`find_children("*","MeshInstance3D").size() >= 60`** (1918-1920);
- `built.get_node_or_null("Scenery")` non-null **and `Scenery/Backdrop` exists** (1921-1923);
- every `Scenery` child whose name `begins_with("Dressing_")` counted, and **count == `info["props"].size()` and > 0** (1925-1930);
- `Surround` material albedo == `Court.palette_color(row,"floor",…).darkened(0.35)` (1932-1935);
- nine distinct `Arena.signature()` digests (1911, 1942-1943); `_distinct_prop_kinds() >= 12` (1944-1945, helper 2036+);
- `rear_alpha` monotone in `wallBounce` (1949-1956);
- unknown id → `build()` null (1960);
- artwork: all nine `artwork_path` non-empty, on disk, and reaching the backdrop (`scenery.get_meta("artwork")`) (1973-1995);
- match wiring: `node.get_node_or_null("Arena")` meta `arena_id`, `arena_mesh_count() >= 60`, sim state id + wallBounce (2020-2032);
- in-frame section (2055-2120): **every `Dressing_*` object fully inside NDC** (2074-2081); `Scenery/Backdrop` spans the frame (2085-2092); **six panes `GlassFar…GlassFar6`** each `material_override` a `StandardMaterial3D`, `TRANSPARENCY_ALPHA`, `albedo_color.a >= 0.2`, `SHADING_MODE_UNSHADED` (2095-2105); `GlassFarRail`, `GlassFarRailHilite`, `GlassFarBottom`, `GlassFarDivider1`, `GlassFarDivider5` present (2106-2109).

### 5.2 `godot/tests/world_arenas_field_law_test.gd`

- frozen roster exactly the nine, in order, with no world id inside (100-112);
- the five offered as choices by `Config.selectable_world_arenas()` in a full build, none in a demo (114-136);
- per world arena: `family == "world"` (157); name+desc non-empty (158-160); wallBounce > 0 and
  `rear_alpha` inside `[REAR_ALPHA_MIN, REAR_ALPHA_MAX]` (161-165); signature distinct (166-168);
- **`Court` + `Net` nodes and a populated `Scenery` with `dressing == props`** (171-179);
- field law measured on the built tree: closest scenery vertex **z ≤ -8.0** (183-186); `Backdrop` wall
  z ≤ -8.0 (187-190); no scenery AABB over the playable footprint (191-192);
- **six rear panes measured from geometry** and **every scenery mesh behind the MEASURED glass plane**
  (194-209);
- shared structural dressing `GearRing` (behind the measured glass) + `AccentPostL/R` (outside the
  cage laterally) present and classified (211-219, implementation `world_arenas_common.gd:426-453`);
- a red-control `Dressing_RedControl` at z=-9 must FAIL the glass check while passing the -8 plane (221-240);
- per-preset builds ≥ 60 meshes (277-280); the five signatures distinct (289-290).

### 5.3 `godot/tests/world_arenas_frame_test.gd`

- per preset (`default/wide/playable`): all 24 gating points (four court corners, side-glass
  foot/top at both ends, rear-glass foot/top both sides — `world_arenas_common.gd:151-172`) inside the
  frame; none behind the camera (113-115);
- **every `Dressing_*` object's 8 AABB corners inside the frame** (100-109, 116-117);
- the band covers the frame through the LIVE camera (128-139);
- the presets are the game's own, unmodified: `Court.CAMERAS.keys() == ["default","wide","playable"]` (146-148).

### 5.4 `godot/tests/world_arenas_selection_test.gd`

- full-build match node: `get_node_or_null("Arena")` meta `arena_id` == requested id,
  `arena_mesh_count() >= 60`, sim `state.arena.id`, `wallBounce == Arena.WORLD_WALL_BOUNCE`,
  `provisional == true` (183-195);
- a real match played on every target arena (197-219+).

### 5.5 `godot/tests/ui/screen_arena_audit.gd` `_world()` (679-705) and `arena_selector_contract_test.gd`

- world rows on screen == `["torii","medina","carioca","aurora","egeo"]` in catalog order (682-694);
- one `WORLD_CARD_PREFIX + id` card per arena (695-697); `WORLD_AREA` (WorldGridArea) above
  `GRID_AREA_NODE` (GridArea) in the body (698-705); a demo builds no world card and no world area (685-692);
- selector contract: world cards, `WORLD_AREA_NODE`, `WORLD_ART_PREFIX + id` art (178-192), demo has no
  `torii` card (215), body order WorldGridArea before GridArea (222-224).

### 5.6 The structural facts, in one list

Node names a kit swap must neither rename nor hide (all under the `Arena` root returned by
`Arena.build()`): `Arena` (root, meta `arena_id`/`family`/`world`/`wallBounce`), `WorldEnvironment`,
`Sun`, `Fill`, `Surround`, `Court`, `LineFar/LineNear/LineLeft/LineRight/CenterLine/ServiceFar/ServiceNear`,
`Net` (`NetWire`/`NetCord`/`NetTape`), `NetPostL/R`, `GlassFar`, `GlassFar2..6`, `GlassFarDivider1..5`,
`GlassFarRail`, `GlassFarRailHilite`, `GlassFarBottom`, `GlassLeft/Right/Near` (+`…Rail`/`…Post`),
`GlassPostFL/FR/NL/NR`, `AccentPostL/R`, `GearRing`, `Scenery`, `Scenery/Backdrop`,
`Scenery/BackdropArtwork`, `Scenery/BackdropVeil`, `Scenery/BackdropApron`, and **exactly one
`Scenery/Dressing_<Kind><n>` per authored prop, in table order, with `meta("kind")`**.

Two structural facts worth stating because they make a kit swap *safe*:

- the scenery walk used by the proof suites is **name-blind**: `world_arenas_common.gd:309-318`
  collects *every* `MeshInstance3D` under `Scenery/` and the field law measures its vertices
  (`world_aabb`, 278-301) — a GLB mounted inside a `Dressing_*` container is automatically covered by
  the field law, the behind-glass check and the frame check (`dressing_nodes`, 515-523);
- the measured rear glass plane is derived from the six `GlassFar*` panes' own geometry
  (`rear_glass_plane`, 393-412), so scenery clearance is measured against the built glass at the
  built z (-10.02), not against a constant.

---

## 6. Proposal — a data-driven arena-kit intake at the existing seams

Design only. No code was changed.

### 6.1 Folder layout (matches the charter's M2 path)

```
godot/assets/arenas/<arena>/<slot>.glb                     # one Meshy export per slot
godot/assets/arenas/<arena>/<slot>_<glb-image-name>.png    # extracted textures, engine-named (opt.)
godot/assets/arenas/<arena>/MANIFEST.json                  # per-arena kit manifest (optional)
godot/assets/arenas/kit_manifest.json                      # roster-level defaults (optional)
art/arena-kits/<arena>/…                                   # M1 image batch (charter), not engine-visible
```

`<arena>` ∈ `torii|medina|carioca|aurora|egeo` (extendable to the nine later). `<slot>` is the
**existing vocabulary**: the prop `kind` from `arena_style.gd`'s table (`torii`, `pagoda`, `lantern`,
`petal`, `moon`, `palm`, `minaret`, `zellige`, `arch`, `wall`, `ridge`, `peak`, `sea`, `island`,
`windmill`, `bougainvillea`, `basalt`, `snowridge`, `steam`, `aurora`, …). Reusing the kind as the
slot key means: the manifest needs no new naming scheme, the UI/menu needs no change, and the
existing per-prop table stays the fallback description of the same object. When one kind has several
instances (torii ×5, palm ×5), the manifest addresses them by the table's own order
(`instances: "all" | [0,2,4]`).

No `res://` preload of kit files anywhere: presence is decided with `FileAccess.file_exists`
(athlete precedent, `athlete_rig.gd:368-369`), so an empty kit costs nothing and the repo stays
buildable with zero `.glb` files.

### 6.2 Where the swap lives (files + functions)

1. **New module `godot/game/arenas/arena_kit.gd`** (`extends RefCounted`, no preloads of kit assets).
   Public surface:
   - `KITS_DIR := "res://assets/arenas/"`;
   - `manifest(arena_id) -> Dictionary` — merges `kit_manifest.json` + `<arena>/MANIFEST.json`
     (cached per id; `{}` when neither exists);
   - `slot_path(arena_id, kind) -> String` — `res://assets/arenas/<arena>/<kind>.glb` or the manifest's
     `glb` name, or `""`;
   - `has_slot(arena_id, kind) -> bool` — manifest opt-in **and** file on disk;
   - `mount_slot(container: Node3D, arena_id: String, kind: String, prop: Dictionary, ctx: Dictionary) -> bool`
     — loads via `GLTFDocument` (mirroring `athlete_rig.gd:367-374`), applies placement policy
     (see 6.4), attaches to `container`, returns `false` (and leaves the container empty) on any
     problem so the caller falls back.
2. **The call site — `godot/game/arenas/arena_scenery.gd::build()`, the prop loop at 160-168.**
   After the container is created, named `Dressing_<Kind><n>`, positioned and given `meta("kind")`
   (163-166), and **instead of** the unconditional `_build_prop(container, prop, ctx)` (168):

   ```
   if not ArenaKit.mount_slot(container, id, kind, prop, ctx):
       _build_prop(container, prop, ctx)      # procedural fallback, byte-identical today
   ```

   Why here and not in `_build_prop`: the container already carries every fact the tests read (name,
   order, `meta("kind")`, position); swapping inside the container keeps the container count/name
   invariant that `game_slice_test.gd:1925-1930` and `world_arenas_field_law_test.gd:176` pin, and it
   means the field law / frame / capture walks (§5.6) cover the GLB with no test change. `_build_prop`
   then becomes the fallback builder only — unchanged otherwise.
3. **A per-slot material policy in `ArenaKit` (or a small shared helper),** copying the athlete rules:
   keep the GLB's own material, but on first mount set `metallic = 0.0`, `roughness = 0.85`,
   `emission_enabled = false` (Meshy default is emission 1,1,1 — `athlete_rig.gd:536-544`), with a
   `glb_pbr` opt-in per manifest entry. Unlike the athletes' `set_outfit`, a slot mesh needs no
   `_base_material` bookkeeping — a `material_override` per surface is enough, and it must be set
   before the first draw (captures gate visibility and alpha, `world_arenas_capture.gd:243-275`).
4. **Descriptor exposure (optional, for the UI/badge "kit: n/10 slots"):** `Arena.info(id)` /
   `world_info(id)` (`arena_library.gd:144-162, 173-195`) get a `kit_slots` key computed from
   `ArenaKit` — a pure addition, no signature change (`signature()` at `arena_style.gd:469-482`
   deliberately stays untouched so the distinctness gates remain stable).

### 6.3 Data-driven manifest (per-arena, additive only)

`godot/assets/arenas/<arena>/MANIFEST.json` — example:

```json
{
  "arena": "torii",
  "units": "meters",
  "origin": "ground-contact",
  "front": "+Z",
  "slots": [
    { "kind": "torii",  "glb": "torii_gate.glb", "instances": [0, 1, 2, 3],
      "target_h": 2.30, "max_h": 2.60, "z_offset": 0.0, "y_offset": 0.0, "rot_y_deg": 0.0 },
    { "kind": "pagoda", "glb": "pagoda.glb",     "target_h": 3.10, "pbr": false },
    { "kind": "lantern","glb": "lantern.glb",    "instances": "all", "target_h": 0.40 },
    { "kind": "petal",  "disabled": true }
  ]
}
```

Rules the loader enforces from the manifest (all measurable, none aesthetic):

- `target_h` (metres) → uniform scale `= target_h / measured_AABB_height`; the loader refuses the
  slot if the scaled AABB exceeds `max_h`, exceeds a default lateral budget, or if the container's
  z-extent would reach past `FIELD_LAW_Z` (-8.0) — i.e. **`z_offset - depth/2 > -8.0 - (-11.65)`**,
  about 3.65 m of headroom at the default prop z (`arena_scenery.gd:165`).
- `origin: ground-contact`, `front: +Z` make the placement rule the athlete rule
  (`athlete_rig.gd:15`); no rotation guessing at the loader.
- `disabled: true` keeps the procedural prop on purpose (so a slot can be retired without deleting
  files).
- Unknown `kind`, unreadable GLB, or any budget violation → `mount_slot` returns `false` and the
  procedural builder runs; the loader logs one `push_warning`, never `push_error` (an absent slot is
  normal during the trickle-in phase).

Globals that belong in `kit_manifest.json` rather than per arena: the folder template
(`res://assets/arenas/<arena>/<slot>.glb`), the default budgets (`max_h`, lateral cap), the default
material policy, and a `version` field.

### 6.4 Verification the proposal implies (fits G3)

- a new headless gate `godot/tests/world_arenas_kit_test.gd` (owns its own file; the frozen suites
  stay untouched) that: builds each arena with an empty kit dir → asserts the built tree is
  byte-identical in structure to today (same `Dressing_*` names/count, same `meta("kind")`); then
  copies a fixture GLB into a temp `res://assets/arenas/<arena>/` slot → asserts the slot node is
  mounted, its AABB height ≈ `target_h`, the field law holds (`ArenaScenery.field_law_report` empty),
  and the old primitives for that slot are absent; then removes the file and re-asserts fallback.
- the existing suite order in `tools/world-arenas/run_proof.sh` (field_law → frame → selection →
  capture) is the natural acceptance run for a kit: it already measures the two laws a GLB can break
  and writes the stills.

### 6.5 Risks

1. **Field law applies to any mesh under `Scenery/`** (`world_arenas_common.gd:309-318`,
   `arena_scenery.gd:238-272`). A slot GLB deeper than ~3.65 m toward the camera (container default
   z = -11.65, law at -8.0, glass measured at -10.02) fails frozen tests. The loader must refuse, not
   clamp silently — a silently shrunk asset is a wrong-looking arena that still passes.
2. **`Dressing_*` count is pinned to `props.size()`** (`game_slice_test.gd:1925-1930`,
   `world_arenas_field_law_test.gd:176`). A swap must never add or remove containers — only replace
   geometry inside one. "Add an extra decoration" requires a `props` table entry, which in turn changes
   `signature()` (`arena_style.gd:469-482`).
3. **Frame law** (`world_arenas_frame_test.gd:100-109`, `game_slice_test.gd:2074-2081`): the container
   AABB's 8 corners must project inside the frame under all three presets. Tall/wide GLBs break this
   where primitives were authored to the band; per-slot height budgets are the mitigation.
4. **Capture gates**: within one preset the five arenas must keep producing five distinct signatures
   (`world_arenas_capture.gd:104-107`), and every scenery mesh must be `visible` (243-275). A kit that
   makes two arenas look alike (or a slot node hidden to "fix" a frame) fails — and a *successful* kit
   can only move the signature digest if the props table changes, so the engine cannnot catch
   "all five now look the same" — that stays the council/taste gate (CHARTER G5).
5. **Import model choice.** Runtime `GLTFDocument` (recommended, athlete precedent) means no
   `generate_lods` and no editor preview; editor-imported `PackedScene` means tracked `.import`
   sidecars, an `--import` pass before tests on a fresh clone, and the documented hazard of an open
   editor rewriting `.import` settings (skill `padel-godot-port-ops`, "Close Godot Editor…"). Pick one
   and state it in the kit standard.
6. **Cost per build.** `Arena.build()` runs at every `_build_scene` and every `_swap_arena`
   (`match_controller.gd:565`, `:528`). Ten GLBs per arena load would be felt at match start; mitigate
   by caching the imported `PackedScene`/`GLTFState` per slot once (lazy, first match) and by keeping
   each slot to a single mesh + single material (the character standard's rule, transposed).
7. **Frozen node names are a charter hard limit** (`CHARTER.md:41-42`): a kit must not rename
   `Scenery`, `Backdrop`, `Dressing_*`, `GearRing`, `GlassFar*` or the court nodes; the loader only
   adds children.
8. **Material/GL-Compatibility details**: GLB PBR with emission on floods the frame (Meshy default;
   `athlete_rig.gd:539-543`); alpha-blended slot geometry can fight the glass panes' alpha sorting, and
   the capture gate reads exact glass alphas (`world_arenas_capture.gd:133-139`) — keep slots opaque
   or use `CULL_DISABLED`/`TRANSPARENCY_ALPHA` the way `_part` already does (`arena_scenery.gd:332-339`).
9. **Texture staging**: either the GLB embeds its textures, or the extracted PNGs + their `.import`
   sidecars must be staged with the GLB or the asset renders white (`character-standard.md:118-133`).
   The puller (M2) should write both and record them.
10. **Detached-tree measurement**: the proof suites build arenas as detached subtrees and measure by
    walking vertices (`world_arenas_common.gd:278-301`). Slot GLBs must be plain
    `MeshInstance3D`/`Node3D` hierarchies — `MultiMeshInstance3D`, `CSG*` or `CollisionShape3D`-only
    imports would be invisible to the field law (and to `arena_mesh_count()`), i.e. an unmeasurable
    asset class. The kit standard should forbid them.

---

### Handles index (quick)

- Build entry: `arena_library.gd:242-264`; the three builder calls `253-255`.
- Scenery root + prop loop: `arena_scenery.gd:109-169`; container naming `164-166`; fallback call `168`.
- Prop kinds: `arena_scenery.gd:421-793`; world kinds `554-793`.
- World prop tables: `arena_style.gd:281-424`.
- Shared court/cage/environment: `court_builder.gd:187-381`.
- Camera presets: `court.gd:118-137`; `build_camera` `279-290`.
- GLB precedent: `athlete_rig.gd:104-148, 184-200, 242-306, 367-374, 521-548, 803-823`;
  `athlete_spawn.gd:127-165`.
- Captures: `tools/world-arenas/run_proof.sh:110-140`; `godot/tests/world_arenas_capture.gd`;
  `godot/tests/world_arenas_menu_capture.gd`.
- Test pins: `game_slice_test.gd:1884-2033, 2055-2120`; `world_arenas_field_law_test.gd:100-240`;
  `world_arenas_frame_test.gd:60-148`; `world_arenas_selection_test.gd:174-219`;
  `world_arenas_common.gd:32-51, 151-172, 278-318, 393-453, 515-523`;
  `screen_arena_audit.gd:679-705`; `arena_selector_contract_test.gd:178-224`.
- Charter / targets: `docs/mission/arena-kit/CHARTER.md:7-42`; `art/concepts/world-arenas-r1/`.
