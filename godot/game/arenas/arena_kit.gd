## arena_kit.gd — the ARENA KIT INTAKE: hand-generated Meshy GLBs, dropped one file per
## slot, mount into a built arena; every slot that has no file keeps the procedural
## blockout it has today.
##
## CONTRACT (frozen by `docs/mission/arena-kit/KIT-STANDARD.md`, gate G1):
##   slot file   `godot/assets/arenas/<arena>/<slot>.glb` -> `res://assets/arenas/…`
##   arenas      torii, medina, carioca, aurora, egeo (the five `family: "world"` decks)
##   slots       the ten ids of `SLOTS`, in the standard's order
##   placement   anchor + declared target height in METRES + declared footprint depth
##   fallback    an absent file is not an error: the procedural prop stands, unchanged
##
## WHY RUNTIME `GLTFDocument` AND NOT THE IMPORT PIPELINE. A slot file is OPTIONAL and
## arrives while the game is being built, so the module never `preload()`s one: that is
## a parse-time keyword and a missing file would be a hard failure instead of a fallback
## (`@GDScript.preload` docs). The repo's own precedent for a drop-in asset is the
## athlete rig — `athlete_rig.gd:56-58` "loaded at RUNTIME through GLTFDocument … no
## `.import` cache and no `project.godot` change", loader `athlete_rig.gd:367-374` — and
## this module's own arena artwork loader made the same choice ("nothing depends on the
## editor's import step", `arena_scenery.gd:300-315`). So a `.glb` that has never seen
## the editor mounts, and an empty `assets/arenas/` costs nothing.
##
## WHAT MOUNTS, AND WHERE. `mount()` is called once by `arena_scenery.gd::build()` at
## the end of the scenery build and returns null — adding NOTHING — when the arena has
## no GLB at all, so with no files in `godot/assets/arenas/` the built tree is
## byte-identical to the pre-kit tree (proved by `godot/tests/arena_kit_test.gd` against
## the recorded baseline, not asserted here). With the fifty files in place the tree
## gains exactly
##
##   Arena/Scenery/Kit/Slot_<slot>/Piece[_<n>]        (one Piece per repeat)
##
## `Kit` is a plain `Node3D` under `Scenery`, so the field law, the frame law and the
## capture walk — all of which read every `MeshInstance3D` under `Scenery/` by name-blind
## traversal (`world_arenas_common.gd:309-318, 278-301`) — cover a mounted GLB with no
## test change, and the `Dressing_*` containers (one per authored prop, `meta("kind")`)
## are untouched.
##
## PLACEMENT, IN METRES. A spec anchor is `(x_authored, y, z_world)`: `x` is in the
## authored prop frame the style tables use (±14.35 m for the default preset) and is
## scaled by the running camera preset's own `x_scale`, exactly like a `Dressing_*`
## container's x (`arena_scenery.gd:143,165`); `y` is the ground contact (0.0 for every
## slot today); `z` is the world z of the footprint's centre. Meshy's units are never
## trusted: the mounted piece is measured, uniformly scaled to the spec's `target_h`,
## moved so its bottom sits on the anchor's ground contact (bottom origin) and its x/z
## centre is the anchor, then it is named, sanitized and given the shared kit material.
##
## TWO PLANES BOUND EVERY FOOTPRINT (the spec table is checked against both by the test):
##   * the charter's field-law plane `FIELD_LAW_Z` = -8.0 — the hard ceiling the
##     standard states as "about 3.6 m of depth budget" at the default prop z;
##   * the MEASURED rear glass plane `GLASS_PLANE_Z` = -10.02, the stricter one: the
##     world-arena suite fails any scenery mesh whose nearest point is in front of the
##     glass (`world_arenas_field_law_test.gd:194-209`).
##
## THE FIT (every number in the table below is measured, not authored). A slot's depth is
## bounded by the BAND between the two planes: a piece that crosses the glass floats in
## the court, and a piece that passes the backdrop wall at z = -12.0 is not drawn at all.
## The band is 1.98 m, so `FIT_DEPTH` = 1.98 - the 5 cm glass margin = 1.93 m is the
## deepest a piece may measure. `tools/arena-kit/fit_report.gd --emit` measures every file
## with the kit's own `node_bounds()` walk and reports the row the fit produces for it: a
## piece is scaled UNIFORMLY (height and depth together, never squashed) until it either
## fits the band or reaches its authored height, and its anchor z is clamped into the
## band. Seven of the fifty Meshy meshes are deeper than the band at their authored
## height — medina/ornament_accent, carioca/hero_landmark, carioca/ornament_accent,
## aurora/hero_landmark, aurora/vegetation_cluster, aurora/furniture, egeo/hero_landmark —
## so those seven carry the FITTED (smaller) `target_h`; the other forty-three keep the
## authored height and the authored anchor z. `DEPTH_BUDGET` = 3.26 m (what the DEFAULT
## prop z could take) stays the ceiling the intake test reads; the fit holds a stricter
## one. Every declared `depth` and `footprint` is the measured mesh at 2 dp, and
## `fit_report.gd` re-measures glass, wall, budget, spec honesty, height and repeat
## centring off a built arena, exiting 1 on any drift.
##
## SUPPRESSION (ON for the slots that have a counterpart, OFF for the rest). A slot may
## stand *in place of* the procedural prop it maps to (`"kinds"`) instead of beside it:
## with `"suppress": true` AND a GLB present, `arena_scenery.gd::build()` skips
## `_build_prop()` for those kinds — the container is still built, so the "one
## `Dressing_*` per authored prop" invariant the frozen suites pin stays intact. The
## flag is ON for the sixteen slots that HAVE a procedural counterpart (the four/five
## per arena whose `kinds` is non-empty) and OFF for the thirty-four whose `kinds` is
## `[]`: those have nothing to double, so flipping them would suppress nothing and hide
## a mistake. The mount census measured the doubling before the flip — sixteen slots
## carrying both a procedural prop and a mounted GLB, 296 procedural meshes standing
## beside 145 pieces — and the same census measures the zero after it
## (`tools/arena-kit/mount_census.gd`, `docs/mission/arena-kit/arena-props/CENSUS.md`).
## `suppressed_kinds()` stays a pure function of (table, file presence) so a suite can
## force the skip path either way with `suppress_overrides` without editing the table.
## (The before/after doubling numbers above were counted by the source mission's own mount
## census — `docs/mission/arena-kit/arena-props/CENSUS.md` on the arena-kit branch; that
## census tool is not part of this port.)
##
## NO COLLISION ON DECOR. Slot geometry is band dressing behind the rear glass, outside
## the playable footprint, so nothing here is ever `-col`/`-colonly` (the standard's
## rule): no collider is added, and any `CollisionObject3D`/`CollisionShape3D`, light or
## camera a generated file happens to carry is stripped on mount, together with the
## asset classes the field law cannot measure (`MultiMeshInstance3D`, CSG shapes).
##
## MATERIAL POLICY, SHARED (the athlete rules, `athlete_rig.gd:521-548`): ONE
## `StandardMaterial3D` per (file, surface), built from the GLB's own albedo/normal/ORM
## maps (≤3), `metallic = 0.0`, `roughness = 0.85`, `emission_enabled = false` — Meshy
## exports carry `emissiveFactor (1,1,1)` with the albedo wired as the emissive map, and
## left on it floods the prop with its own albedo. Cached, so a repeated slot shares one
## material and GL Compatibility's lack of automatic instancing costs no extra state.
extends RefCounted

## Where slot files live, relative to the project. One folder per arena.
const KIT_DIR := "res://assets/arenas/"
## The frozen slot set (KIT-STANDARD §1), in the standard's order. `ground_texture` is
## deliberately NOT here: it is the image-only slot — a material, not a model.
const SLOTS := [
	"hero_landmark",
	"gate_portal",
	"light_source",
	"vegetation_cluster",
	"ground_dressing",
	"ornament_accent",
	"column_pillar",
	"railing_segment",
	"furniture",
	"signage_banner",
]
## The arenas a kit is specified for: the five `family: "world"` decks.
const ARENAS := ["torii", "medina", "carioca", "aurora", "egeo"]
## The charter's hard plane: no scenery vertex in front of it (`arena_scenery.gd:101`).
const FIELD_LAW_Z := -8.0
## The rear glass as the world-arena suite MEASURES it from the six `GlassFar*` panes
## (`world_arenas_common.gd:393-412`, built at -10.02). Stricter than the charter plane.
const GLASS_PLANE_Z := -10.02
## The default prop container z (`arena_scenery.gd:165`: prop z -7.65 minus 4.0).
const PROP_Z := -11.65
## Metres of depth a slot footprint may use at `PROP_Z` before its front face reaches
## the glass: `2 * (GLASS_PLANE_Z - PROP_Z)`. The standard rounds this to "~3.6 m" from
## the -8.0 plane; the glass is what a built arena is actually gated on.
const DEPTH_BUDGET := 3.26
## The authored half-span of the style tables (the default preset's top row); a slot's x
## and its whole repeat run must stay inside it to keep the frame law.
const AUTHORED_HALF_X := 14.35

## THE PER-ARENA SPEC TABLE (KIT-STANDARD §2: "Slot specs (anchors, sizes, suppress)").
##
## One entry per (arena, slot) — 5 x 10 — each with:
##   anchor     Vector3(x_authored, y_ground_contact, z_world) — see the header
##   target_h   the height in METRES the mounted piece is normalized to
##   repeats    how many instances the slot places (1 = a single piece)
##   spread     metres between repeat instances, authored units (0.0 when repeats == 1)
##   depth      the declared depth of ONE instance's footprint, in metres
##   footprint  the human-readable footprint note: `w x h x d m — what it is`
##   suppress   skip the procedural prop(s) in `kinds` when a GLB is present (default OFF)
##   kinds      the procedural prop kind(s) this slot stands over (used only by suppress)
##
## The numbers are authored for the default camera preset and are starting values: the
## owner's first real models are what a per-arena anchor polish is for (KIT-STANDARD §7).
const SPECS := {
	"torii": {
		"hero_landmark": {
			"anchor": Vector3(-3.2, 0.0, -11.2107), "target_h": 4.0, "repeats": 1, "spread": 0.0,
			"depth": 1.56, "footprint": "1.52 x 4.00 x 1.56 m - pagoda mass on the left of the band",
			"suppress": true, "kinds": ["pagoda"],
		},
		"gate_portal": {
			"anchor": Vector3(4.0, 0.0, -11.10), "target_h": 2.6, "repeats": 1, "spread": 0.0,
			"depth": 0.50, "footprint": "2.77 x 2.60 x 0.50 m - vermillion gate, opening on the anchor",
			"suppress": true, "kinds": ["torii"],
		},
		"light_source": {
			"anchor": Vector3(-8.4, 0.0, -11.05), "target_h": 1.15, "repeats": 3, "spread": 1.5,
			"depth": 0.58, "footprint": "0.58 x 1.15 x 0.58 m - stone lantern on a post",
			"suppress": true, "kinds": ["lantern"],
		},
		"vegetation_cluster": {
			"anchor": Vector3(-10.2, 0.0, -11.3413), "target_h": 2.6, "repeats": 2, "spread": 1.8,
			"depth": 1.30, "footprint": "2.70 x 2.60 x 1.30 m - cherry cluster, seams hidden",
			"suppress": true, "kinds": ["petal"],
		},
		"ground_dressing": {
			"anchor": Vector3(6.6, 0.0, -10.75), "target_h": 0.55, "repeats": 2, "spread": 2.2,
			"depth": 1.25, "footprint": "1.35 x 0.55 x 1.25 m - raked gravel mound",
			"suppress": false, "kinds": [],
		},
		"ornament_accent": {
			"anchor": Vector3(0.8, 0.0, -10.90), "target_h": 0.9, "repeats": 4, "spread": 0.9,
			"depth": 0.73, "footprint": "0.76 x 0.90 x 0.73 m - shrine panel",
			"suppress": false, "kinds": [],
		},
		"column_pillar": {
			"anchor": Vector3(9.6, 0.0, -10.95), "target_h": 2.6, "repeats": 4, "spread": 0.8,
			"depth": 0.42, "footprint": "0.56 x 2.60 x 0.42 m - vermillion post",
			"suppress": false, "kinds": [],
		},
		"railing_segment": {
			"anchor": Vector3(-6.2, 0.0, -10.70), "target_h": 1.05, "repeats": 6, "spread": 1.1,
			"depth": 0.26, "footprint": "1.62 x 1.05 x 0.26 m - wooden rail tile",
			"suppress": false, "kinds": [],
		},
		"furniture": {
			"anchor": Vector3(2.6, 0.0, -10.80), "target_h": 0.95, "repeats": 2, "spread": 1.6,
			"depth": 0.89, "footprint": "3.02 x 0.95 x 0.89 m - bench",
			"suppress": false, "kinds": [],
		},
		"signage_banner": {
			"anchor": Vector3(-1.4, 0.0, -10.92), "target_h": 1.4, "repeats": 2, "spread": 1.2,
			"depth": 0.36, "footprint": "0.86 x 1.40 x 0.36 m - noren panel",
			"suppress": false, "kinds": [],
		},
	},
	"medina": {
		"hero_landmark": {
			"anchor": Vector3(-4.2, 0.0, -11.35), "target_h": 3.9, "repeats": 1, "spread": 0.0,
			"depth": 0.72, "footprint": "0.73 x 3.90 x 0.72 m - minaret shaft and balcony",
			"suppress": true, "kinds": ["minaret"],
		},
		"gate_portal": {
			"anchor": Vector3(3.6, 0.0, -11.15), "target_h": 2.8, "repeats": 1, "spread": 0.0,
			"depth": 0.68, "footprint": "2.37 x 2.80 x 0.68 m - horseshoe arch",
			"suppress": true, "kinds": ["arch"],
		},
		"light_source": {
			"anchor": Vector3(-7.8, 0.0, -11.00), "target_h": 1.3, "repeats": 4, "spread": 1.4,
			"depth": 0.38, "footprint": "0.44 x 1.30 x 0.38 m - brass lantern",
			"suppress": true, "kinds": ["lantern"],
		},
		"vegetation_cluster": {
			"anchor": Vector3(-10.6, 0.0, -11.4416), "target_h": 2.7, "repeats": 2, "spread": 2.0,
			"depth": 1.10, "footprint": "2.13 x 2.70 x 1.10 m - palm cluster",
			"suppress": true, "kinds": ["palm"],
		},
		"ground_dressing": {
			"anchor": Vector3(5.8, 0.0, -10.70), "target_h": 0.6, "repeats": 3, "spread": 2.0,
			"depth": 0.75, "footprint": "0.70 x 0.60 x 0.75 m - pottery and kerb strip",
			"suppress": false, "kinds": [],
		},
		"ornament_accent": {
			"anchor": Vector3(0.4, 0.0, -11.0392), "target_h": 0.78, "repeats": 4, "spread": 1.0,
			"depth": 1.90, "footprint": "1.90 x 0.78 x 1.90 m - zellige panel",
			"suppress": true, "kinds": ["zellige"],
		},
		"column_pillar": {
			"anchor": Vector3(8.8, 0.0, -10.90), "target_h": 2.7, "repeats": 5, "spread": 0.85,
			"depth": 0.41, "footprint": "0.83 x 2.70 x 0.41 m - zellige column",
			"suppress": false, "kinds": [],
		},
		"railing_segment": {
			"anchor": Vector3(-5.6, 0.0, -10.65), "target_h": 1.15, "repeats": 6, "spread": 1.15,
			"depth": 0.23, "footprint": "1.70 x 1.15 x 0.23 m - iron grille",
			"suppress": false, "kinds": [],
		},
		"furniture": {
			"anchor": Vector3(2.2, 0.0, -10.78), "target_h": 0.95, "repeats": 3, "spread": 1.3,
			"depth": 1.42, "footprint": "1.42 x 0.95 x 1.42 m - divan",
			"suppress": false, "kinds": [],
		},
		"signage_banner": {
			"anchor": Vector3(-1.6, 0.0, -10.88), "target_h": 1.3, "repeats": 2, "spread": 1.1,
			"depth": 1.23, "footprint": "2.28 x 1.30 x 1.23 m - awning sign",
			"suppress": false, "kinds": [],
		},
	},
	"carioca": {
		"hero_landmark": {
			"anchor": Vector3(4.6, 0.0, -11.0319), "target_h": 1.86, "repeats": 1, "spread": 0.0,
			"depth": 1.92, "footprint": "1.92 x 1.86 x 1.92 m - sugarloaf mass",
			"suppress": true, "kinds": ["peak"],
		},
		"gate_portal": {
			"anchor": Vector3(-4.0, 0.0, -11.10), "target_h": 2.4, "repeats": 1, "spread": 0.0,
			"depth": 0.60, "footprint": "2.57 x 2.40 x 0.60 m - quay arch",
			"suppress": false, "kinds": [],
		},
		"light_source": {
			"anchor": Vector3(7.6, 0.0, -10.95), "target_h": 1.5, "repeats": 3, "spread": 1.7,
			"depth": 0.38, "footprint": "2.77 x 1.50 x 0.38 m - festoon post",
			"suppress": false, "kinds": [],
		},
		"vegetation_cluster": {
			"anchor": Vector3(-9.8, 0.0, -11.1990), "target_h": 2.5, "repeats": 3, "spread": 1.7,
			"depth": 1.58, "footprint": "2.40 x 2.50 x 1.58 m - banana and tree-fern clump",
			"suppress": true, "kinds": ["palm"],
		},
		"ground_dressing": {
			"anchor": Vector3(4.2, 0.0, -10.70), "target_h": 0.5, "repeats": 2, "spread": 2.6,
			"depth": 0.84, "footprint": "0.88 x 0.50 x 0.84 m - beach boulders",
			"suppress": true, "kinds": ["foam"],
		},
		"ornament_accent": {
			"anchor": Vector3(-1.0, 0.0, -11.0320), "target_h": 0.45, "repeats": 4, "spread": 1.1,
			"depth": 1.92, "footprint": "1.92 x 0.45 x 1.92 m - capoeira ring brass",
			"suppress": false, "kinds": [],
		},
		"column_pillar": {
			"anchor": Vector3(-7.2, 0.0, -10.85), "target_h": 2.6, "repeats": 4, "spread": 0.9,
			"depth": 0.44, "footprint": "0.49 x 2.60 x 0.44 m - painted mast",
			"suppress": false, "kinds": [],
		},
		"railing_segment": {
			"anchor": Vector3(1.4, 0.0, -10.55), "target_h": 1.0, "repeats": 6, "spread": 1.2,
			"depth": 0.29, "footprint": "1.51 x 1.00 x 0.29 m - quay rope rail",
			"suppress": false, "kinds": [],
		},
		"furniture": {
			"anchor": Vector3(9.4, 0.0, -10.85), "target_h": 0.9, "repeats": 3, "spread": 1.4,
			"depth": 1.05, "footprint": "0.80 x 0.90 x 1.05 m - deck chair",
			"suppress": false, "kinds": [],
		},
		"signage_banner": {
			"anchor": Vector3(-2.4, 0.0, -10.80), "target_h": 1.2, "repeats": 3, "spread": 1.3,
			"depth": 0.09, "footprint": "0.78 x 1.20 x 0.09 m - bandeira",
			"suppress": false, "kinds": [],
		},
	},
	"aurora": {
		"hero_landmark": {
			"anchor": Vector3(-5.0, 0.0, -11.0339), "target_h": 1.99, "repeats": 1, "spread": 0.0,
			"depth": 1.91, "footprint": "1.99 x 1.99 x 1.91 m - ice spire",
			"suppress": true, "kinds": ["snowridge"],
		},
		"gate_portal": {
			"anchor": Vector3(3.2, 0.0, -11.05), "target_h": 2.2, "repeats": 1, "spread": 0.0,
			"depth": 1.72, "footprint": "1.70 x 2.20 x 1.72 m - cairn marker",
			"suppress": false, "kinds": [],
		},
		"light_source": {
			"anchor": Vector3(-8.8, 0.0, -11.03), "target_h": 1.6, "repeats": 4, "spread": 1.5,
			"depth": 1.90, "footprint": "1.90 x 1.60 x 1.90 m - brazier",
			"suppress": false, "kinds": [],
		},
		"vegetation_cluster": {
			"anchor": Vector3(8.6, 0.0, -11.0354), "target_h": 1.54, "repeats": 2, "spread": 2.2,
			"depth": 1.91, "footprint": "1.91 x 1.54 x 1.91 m - moss-rock tuft",
			"suppress": false, "kinds": [],
		},
		"ground_dressing": {
			"anchor": Vector3(-2.8, 0.0, -10.65), "target_h": 0.7, "repeats": 3, "spread": 2.4,
			"depth": 0.59, "footprint": "0.66 x 0.70 x 0.59 m - basalt shards",
			"suppress": true, "kinds": ["basalt"],
		},
		"ornament_accent": {
			"anchor": Vector3(0.6, 0.0, -10.78), "target_h": 1.1, "repeats": 4, "spread": 1.0,
			"depth": 0.14, "footprint": "0.44 x 1.10 x 0.14 m - runestone",
			"suppress": false, "kinds": [],
		},
		"column_pillar": {
			"anchor": Vector3(5.4, 0.0, -10.88), "target_h": 2.8, "repeats": 4, "spread": 1.0,
			"depth": 1.18, "footprint": "1.25 x 2.80 x 1.18 m - basalt prism",
			"suppress": false, "kinds": [],
		},
		"railing_segment": {
			"anchor": Vector3(-3.6, 0.0, -10.50), "target_h": 0.95, "repeats": 5, "spread": 1.3,
			"depth": 0.23, "footprint": "1.18 x 0.95 x 0.23 m - driftwood fence",
			"suppress": false, "kinds": [],
		},
		"furniture": {
			"anchor": Vector3(10.2, 0.0, -11.0345), "target_h": 0.67, "repeats": 2, "spread": 1.6,
			"depth": 1.91, "footprint": "1.19 x 0.67 x 1.91 m - sled bench",
			"suppress": false, "kinds": [],
		},
		"signage_banner": {
			"anchor": Vector3(1.8, 0.0, -10.72), "target_h": 1.5, "repeats": 2, "spread": 1.4,
			"depth": 0.11, "footprint": "0.93 x 1.50 x 0.11 m - pennant",
			"suppress": false, "kinds": [],
		},
	},
	"egeo": {
		"hero_landmark": {
			"anchor": Vector3(3.8, 0.0, -11.0335), "target_h": 1.80, "repeats": 1, "spread": 0.0,
			"depth": 1.91, "footprint": "1.93 x 1.80 x 1.91 m - caldera rim with domes",
			"suppress": true, "kinds": ["island"],
		},
		"gate_portal": {
			"anchor": Vector3(-3.4, 0.0, -11.00), "target_h": 2.5, "repeats": 1, "spread": 0.0,
			"depth": 1.70, "footprint": "1.62 x 2.50 x 1.70 m - chapel door",
			"suppress": false, "kinds": [],
		},
		"light_source": {
			"anchor": Vector3(7.2, 0.0, -10.90), "target_h": 1.7, "repeats": 3, "spread": 1.8,
			"depth": 0.41, "footprint": "0.40 x 1.70 x 0.41 m - wind-light",
			"suppress": false, "kinds": [],
		},
		"vegetation_cluster": {
			"anchor": Vector3(-9.4, 0.0, -11.30), "target_h": 2.2, "repeats": 2, "spread": 2.0,
			"depth": 1.24, "footprint": "2.13 x 2.20 x 1.24 m - olive and growth clump",
			"suppress": true, "kinds": ["bougainvillea"],
		},
		"ground_dressing": {
			"anchor": Vector3(5.6, 0.0, -10.68), "target_h": 0.55, "repeats": 2, "spread": 2.4,
			"depth": 0.83, "footprint": "0.89 x 0.55 x 0.83 m - dry-stone stub",
			"suppress": false, "kinds": [],
		},
		"ornament_accent": {
			"anchor": Vector3(-0.8, 0.0, -10.76), "target_h": 0.95, "repeats": 4, "spread": 1.0,
			"depth": 1.29, "footprint": "1.89 x 0.95 x 1.29 m - donkey cart",
			"suppress": false, "kinds": [],
		},
		"column_pillar": {
			"anchor": Vector3(-6.6, 0.0, -10.82), "target_h": 2.5, "repeats": 5, "spread": 0.85,
			"depth": 0.56, "footprint": "1.13 x 2.50 x 0.56 m - whitewashed pier",
			"suppress": false, "kinds": [],
		},
		"railing_segment": {
			"anchor": Vector3(1.2, 0.0, -10.52), "target_h": 1.0, "repeats": 6, "spread": 1.25,
			"depth": 0.25, "footprint": "1.32 x 1.00 x 0.25 m - blue rail",
			"suppress": false, "kinds": [],
		},
		"furniture": {
			"anchor": Vector3(9.8, 0.0, -10.86), "target_h": 1.0, "repeats": 3, "spread": 1.5,
			"depth": 0.55, "footprint": "0.52 x 1.00 x 0.55 m - taverna chair",
			"suppress": false, "kinds": [],
		},
		"signage_banner": {
			"anchor": Vector3(-1.9, 0.0, -10.70), "target_h": 1.3, "repeats": 2, "spread": 1.3,
			"depth": 0.21, "footprint": "1.16 x 1.30 x 0.21 m - taverna sign",
			"suppress": false, "kinds": [],
		},
	},
}

## Node classes a slot asset may not contribute: physics (no collision on decor), lights
## and cameras (GL Compatibility spends its light budget on the court), and the two
## classes the field law cannot measure (a `MultiMeshInstance3D` and a CSG shape would be
## invisible to `world_arenas_common.gd::scenery_meshes`).
const REJECTED_CLASSES := [
	"CollisionObject3D", "CollisionShape3D", "Light3D", "Camera3D",
	"MultiMeshInstance3D", "CSGShape3D", "SoftBody3D", "NavigationRegion3D",
]

## TEST SEAM, never set by production code: `{"<arena>": {"<slot>": true|false}}` lets a
## suite exercise the suppress path (skip the procedural prop when a GLB is present)
## without editing the frozen table above. Absent/empty in every game run.
static var suppress_overrides: Dictionary = {}
## Loaded GLB scenes by path (`null` cached for an unreadable file, so a broken slot is
## reported once and never re-parsed). Scenes are shared: `mount_slot()` duplicates one
## before placing it, so the mesh and texture resources stay shared across repeats.
static var _scene_cache: Dictionary = {}
## The shared kit material per (path, surface index) — see the header's material policy.
static var _material_cache: Dictionary = {}


# ---------------------------------------------------------------------------
# The public surface
# ---------------------------------------------------------------------------

## The frozen slot set, in the standard's order (a copy: never hand out the constant).
static func slots() -> Array:
	return SLOTS.duplicate()


## The five arenas a kit is specified for.
static func arenas() -> Array:
	return ARENAS.duplicate()


## One slot's spec entry, or `{}` for an unknown arena/slot.
static func spec(arena_id: String, slot: String) -> Dictionary:
	var table: Dictionary = SPECS.get(arena_id, {})
	return table.get(slot, {})


## Where a slot's GLB is expected, whether or not it is there.
static func slot_path(arena_id: String, slot: String) -> String:
	return "%s%s/%s.glb" % [KIT_DIR, arena_id, slot]


## Is a slot file there? `ResourceLoader.exists` is the standard's guard; the athlete
## rig and this module's own artwork loader test with `FileAccess.file_exists`, which is
## what answers for a `.glb` the editor has never imported (the recorded finding in
## `docs/mission/arena-kit/PIPELINE.md`). Both are accepted; `preload()` never is.
static func glb_exists(path: String) -> bool:
	if ResourceLoader.exists(path):
		return true
	return FileAccess.file_exists(path)


## Does this arena have a kit? `slot == ""` asks about the whole arena (any slot file
## present), a slot id asks about that slot only.
static func has_kit(arena_id: String, slot := "") -> bool:
	if not SPECS.has(arena_id):
		return false
	if slot != "":
		return glb_exists(slot_path(arena_id, slot))
	for s in SLOTS:
		if glb_exists(slot_path(arena_id, s)):
			return true
	return false


## Mounts every slot of `arena_id` that has a file, under a new `Kit` node in
## `scenery_root` (a built `Scenery`). Returns the `Kit` node, or **null and nothing
## added** when the arena has no file at all — the empty-kit path `arena_scenery.gd`
## depends on to stay identical to the pre-kit build. `ctx` carries the running camera
## preset's `x_scale` (as the `Dressing_*` containers use); anything else is ignored.
static func mount(scenery_root: Node3D, arena_id: String, ctx: Dictionary = {}) -> Node3D:
	if scenery_root == null or not SPECS.has(arena_id):
		return null
	var present: Array[String] = []
	for s in SLOTS:
		if glb_exists(slot_path(arena_id, s)):
			present.append(s)
	if present.is_empty():
		return null
	var kit := Node3D.new()
	kit.name = "Kit"
	kit.set_meta("arena_id", arena_id)
	scenery_root.add_child(kit)
	var mounted := 0
	for s in present:
		if mount_slot(kit, arena_id, s, ctx) != null:
			mounted += 1
	if mounted == 0:
		# Every file present was unreadable: add nothing rather than an empty node.
		scenery_root.remove_child(kit)
		kit.free()
		return null
	kit.set_meta("slots", mounted)
	return kit


## Mounts ONE slot into `parent`, at its spec anchor: `Slot_<slot>` holding one `Piece`
## per `repeats` (named `Piece_<n>` when the slot repeats). Returns the slot node, or
## null when the file is absent/unreadable — the caller then keeps the procedural prop.
static func mount_slot(parent: Node3D, arena_id: String, slot: String,
		ctx: Dictionary = {}) -> Node3D:
	if parent == null:
		return null
	var entry := spec(arena_id, slot)
	if entry.is_empty():
		return null
	var path := slot_path(arena_id, slot)
	var source := _load_scene(path)
	if source == null:
		return null
	var x_scale := float(ctx.get("x_scale", 1.0))
	var repeats := maxi(1, int(entry["repeats"]))
	var spread := float(entry["spread"]) * x_scale
	var holder := Node3D.new()
	holder.name = "Slot_%s" % slot
	holder.set_meta("slot", slot)
	holder.set_meta("asset", path)
	holder.set_meta("target_h", float(entry["target_h"]))
	holder.position = anchor_at(arena_id, slot, x_scale)
	parent.add_child(holder)
	var pieces := 0
	for i in repeats:
		# The repeat offset is the piece's own x, ON TOP of the centring `_place_piece()`
		# does: assigning `position.x` here would throw the centring away (see its note).
		var piece := _place_piece(source, entry, path,
			(float(i) - float(repeats - 1) * 0.5) * spread)
		if piece == null:
			continue
		piece.name = "Piece_%d" % (i + 1) if repeats > 1 else "Piece"
		holder.add_child(piece)
		pieces += 1
	if pieces == 0:
		parent.remove_child(holder)
		holder.free()
		return null
	holder.set_meta("pieces", pieces)
	return holder


## A slot's anchor in the scenery frame at a given camera preset's `x_scale`.
static func anchor_at(arena_id: String, slot: String, x_scale := 1.0) -> Vector3:
	var entry := spec(arena_id, slot)
	if entry.is_empty():
		return Vector3.ZERO
	var a: Vector3 = entry["anchor"]
	return Vector3(a.x * x_scale, a.y, a.z)


## Per-slot status of one arena's kit — one entry per frozen slot, in the standard's
## order: `slot`, the resolved `path`, `present` (a file is there), `status`
## ("loaded" when the file is present AND readable, "unreadable" when a file is there
## but cannot be read, "procedural" when the slot is empty and the blockout stands),
## `anchor`, `target_h`, `repeats`, `footprint`, `suppress`, `kinds`.
static func slot_report(arena_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not SPECS.has(arena_id):
		return out
	for slot in SLOTS:
		var entry := spec(arena_id, slot)
		var path := slot_path(arena_id, slot)
		var present := glb_exists(path)
		var status := "procedural"
		if present:
			status = "loaded" if _load_scene(path) != null else "unreadable"
		out.append({
			"slot": slot,
			"path": path,
			"present": present,
			"status": status,
			"anchor": anchor_at(arena_id, slot),
			"target_h": float(entry.get("target_h", 0.0)),
			"repeats": int(entry.get("repeats", 0)),
			"footprint": String(entry.get("footprint", "")),
			"suppress": bool(entry.get("suppress", false)),
			"kinds": (entry.get("kinds", []) as Array).duplicate(),
		})
	return out


## The procedural prop kinds `arena_scenery.gd::build()` must skip for this arena: a
## slot's `kinds` enter here only when the slot has BOTH `suppress = true` and a GLB in
## place. With the table as it ships that is sixteen slots across the five arenas; with
## no GLB anywhere it is empty for every arena, whatever the flags say, which is what
## `tests/arena_kit_test.gd` pins in both disk states.
static func suppressed_kinds(arena_id: String) -> Array[String]:
	var out: Array[String] = []
	var override: Dictionary = suppress_overrides.get(arena_id, {})
	for slot in SLOTS:
		var entry := spec(arena_id, slot)
		if entry.is_empty():
			continue
		var on := bool(override.get(slot, entry["suppress"]))
		if not on or not glb_exists(slot_path(arena_id, slot)):
			continue
		for kind in (entry.get("kinds", []) as Array):
			var k := String(kind)
			if not out.has(k):
				out.append(k)
	return out


## The box of everything a `Node3D` (and its subtree) renders, in the PARENT frame of
## that node — i.e. the node's own transform IS applied, so the answer is directly
## comparable with the node's own `position`/`scale` and with a sibling. Built from the
## union of every `MeshInstance3D`'s AABB through the node chain, with one deliberate
## exception — a SKINNED mesh is measured in mesh space and its chain skipped, because a
## skinned GLB's vertices are in metres while its bone hierarchy can sit under an armature
## scaled 0.01, and multiplying the two double-counts that scale (`athlete_rig.gd:790-797`:
## "Do NOT use `MeshInstance3D.get_aabb()` for this"). Meshy props are static — the
## standard's rule for a slot asset — and a skinned file still mounts at a sane size
## instead of 100x too tall.
static func node_bounds(node: Node3D) -> AABB:
	if node == null:
		return AABB()
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	var any := false
	for candidate in _mesh_instances(node):
		var mi := candidate as MeshInstance3D
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		var box: AABB = mesh.get_aabb()
		if mi.skin != null:
			for i in 8:
				var corner: Vector3 = node.transform * box.get_endpoint(i)
				lo = lo.min(corner)
				hi = hi.max(corner)
				any = true
			continue
		var xf := node.transform * _chain_to(mi, node)
		for i in 8:
			var corner: Vector3 = xf * box.get_endpoint(i)
			lo = lo.min(corner)
			hi = hi.max(corner)
			any = true
	if not any:
		return AABB()
	return AABB(lo, hi - lo)


# ---------------------------------------------------------------------------
# Placement
# ---------------------------------------------------------------------------

## One placed instance: a wrapper `Node3D` holding a duplicate of the cached GLB scene,
## normalized to the spec — uniformly scaled so the measured box is `target_h` tall,
## moved so the box's bottom is on the wrapper's own origin (bottom origin) and its x/z
## centre is there too, sanitized and given the shared material. Null when the source
## has no measurable geometry at all (nothing to normalize against).
##
## `offset_x` is the piece's own repeat offset, and it is the WRAPPER's x — the intake
## suite pins `Piece_<n>.position.x` to the declared spread. The geometry's own x centre
## is therefore brought onto the wrapper origin on the CHILD instead: a source model whose
## AABB is not x-centred (aurora/furniture is 0.18 m off) would otherwise carry that
## asymmetry into the measured box, and the two checks that read the same placement —
## `mount/every_repeat_is_placed_on_the_declared_spread` (the node) and
## `mount/every_mounted_box_sits_on_its_repeat_offset` (the box) — would disagree.
static func _place_piece(source: Node3D, entry: Dictionary, path: String, offset_x := 0.0) -> Node3D:
	var piece := Node3D.new()
	var child: Node3D = source.duplicate()
	if child == null:
		piece.free()
		return null
	piece.add_child(child)
	var box := node_bounds(piece)
	if box.size.y <= 0.0001:
		piece.free()
		return null
	var s := float(entry["target_h"]) / box.size.y
	piece.scale = Vector3(s, s, s)
	# x: the child takes the centring (so the wrapper's own x is the repeat offset); z and
	# y: the wrapper takes them (bottom origin, z centre on the anchor).
	child.position.x -= box.position.x + box.size.x * 0.5
	piece.position = Vector3(
		offset_x,
		-box.position.y * s,
		-(box.position.z + box.size.z * 0.5) * s)
	_sanitize(piece)
	_apply_material_policy(child, path)
	return piece


## Strips what a slot asset may not contribute (see `REJECTED_CLASSES`): physics (no
## collision on decor), lights, cameras and the classes the field law cannot measure.
## Returns how many nodes were removed, so a caller can report it.
static func _sanitize(root: Node3D) -> int:
	var doomed: Array[Node] = []
	for node in _all_nodes(root):
		if node == root:
			continue
		for cls in REJECTED_CLASSES:
			if node.is_class(cls):
				doomed.append(node)
				break
	var removed := 0
	for node in doomed:
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		node.free()
		removed += 1
	return removed


## The shared kit material policy, applied per surface of every mesh in the subtree: one
## cached `StandardMaterial3D` per (file, surface index), built from the GLB's own maps
## (albedo, normal, ORM — the standard's "≤3 maps"), opaque, with the Meshy defaults
## corrected (`metallic = 0.0`, `roughness = 0.85`, emission off). Returns the number of
## surfaces it set.
static func _apply_material_policy(root: Node3D, path: String) -> int:
	var count := 0
	for candidate in _mesh_instances(root):
		var mi := candidate as MeshInstance3D
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var key := "%s#%d" % [path, s]
			var mat: StandardMaterial3D = _material_cache.get(key)
			if mat == null:
				mat = _kit_material(mesh.surface_get_material(s) as StandardMaterial3D)
				_material_cache[key] = mat
			mi.set_surface_override_material(s, mat)
			count += 1
	return count


static func _kit_material(src: StandardMaterial3D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	if src != null:
		m.albedo_color = src.albedo_color
		m.albedo_texture = src.albedo_texture
		m.normal_texture = src.normal_texture
		m.orm_texture = src.orm_texture
		if src.emission_enabled and src.emission_texture != null and src.albedo_texture == null:
			# A GLB whose only colour comes from the emission map: keep it, but as
			# albedo, so the prop reads lit instead of glowing (Meshy's wiring).
			m.albedo_texture = src.emission_texture
	# The Meshy correction, exactly the athlete rig's non-glTF override block
	# (`athlete_rig.gd:536-544`): a generated export carries emission (1,1,1) with the
	# albedo as the emissive map, and left on the prop floods itself with its own colour.
	m.metallic = 0.0
	m.roughness = 0.85
	m.emission_enabled = false
	# Slots stay OPAQUE: the band's transparency budget belongs to the backdrop veil and
	# the glass panes, whose exact alphas the capture gate reads.
	m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_BACK
	return m


## The cached runtime load (see the header). `null` for a missing/unreadable file, and
## the null is cached too, so a broken slot warns once instead of every build.
static func _load_scene(path: String) -> Node3D:
	if _scene_cache.has(path):
		var cached = _scene_cache[path]
		return cached as Node3D
	if not glb_exists(path):
		_scene_cache[path] = null
		return null
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		push_warning("arena_kit: cannot read '%s' (slot falls back to procedural)" % path)
		_scene_cache[path] = null
		return null
	var scene := doc.generate_scene(state) as Node3D
	if scene == null:
		push_warning("arena_kit: '%s' produced no scene (slot falls back to procedural)" % path)
	_scene_cache[path] = scene
	return scene


# ---------------------------------------------------------------------------
# Small walks
# ---------------------------------------------------------------------------

static func _mesh_instances(node: Node3D) -> Array:
	var out: Array = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		out.append(node)
	return out


static func _all_nodes(root: Node) -> Array:
	var out: Array = [root]
	for child in root.get_children():
		out.append_array(_all_nodes(child))
	return out


## A node's transform relative to `ancestor`, the walk (not `global_transform`) because
## a built arena is a detached subtree while the scenery is being assembled.
static func _chain_to(node: Node3D, ancestor: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node3D = node
	while cur != null and cur != ancestor:
		xf = cur.transform * xf
		cur = cur.get_parent() as Node3D
	return xf
