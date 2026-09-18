# Evidence: Il Cornetto — Fornaio's croissant racket, in the match, without touching the sim

- Date: 2026-09-18. Repo: `steam-circuit-padel-godot`, `HEAD cfa268d7dc06797542f4deb14cc03e3b3b304154`,
  every edit made with `pwd -P` confirming the checkout root.
- Artifacts (absolute paths):
  - `/Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot/godot/game/court.gd`
    (`make_racket_view` style argument, the cornetto head/throat/handle, the geometry maths)
  - `/Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot/godot/game/athletes_view.gd`
    (`racket_style_for`, the per-role `styles` override, the report field)
  - `/Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot/godot/game/match_controller.gd`
    (the capsule fallback asks for the same style)
  - `/Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot/godot/tests/cornetto_racket_test.gd`
- Engine: `/Applications/Godot.app/Contents/MacOS/Godot`, 4.7.2 (`ed1daf0bf`), macOS 27.0, Apple M4.
  The render probe printed `OpenGL API 4.1 Metal - 91.7 - Compatibility`, i.e. a real GPU context, not the
  dummy driver.
- Constraints held and checked, not assumed: `js/`, `index.html`, `styles.css` and the frozen tables are
  untouched (`git status` shows none of them); the sim's `paddle.w` / `paddle.h` contact box is untouched and
  nothing here reads it; no gameplay value changed; **one Godot process at a time** — `pgrep -x Godot` before
  every run, and three runs were deferred for minutes while the owner's play session
  (`Main.tscn -- --seed=20260916 --tier=3 --camera=default`) owned the checkout; nothing committed, and the
  pre-existing untracked `.uid` files and `godot/=/` were left alone.

## 0. Status in one line

**Il Cornetto is in the match as a switchable racket head.** The six frozen athletes draw exactly what they
drew before (measured identical: `plain=(0.26, 0.4355)` and `standard=(0.26, 0.4355)`); `fornaio` gets a
golden-brown croissant head on a beech throat, brass ferrule and a twine-wrapped rolling-pin handle, chosen
from the athlete id alone with no override; and the only thing that changed about the sim is nothing.
`PASS 33/33`, exit 0, **0 `SCRIPT ERROR`, 0 `ERROR:` lines**; gdlint shows **no new findings** on the three
edited files and the new test file is clean.

## 1. Default vs cornetto — the split, as it actually builds

| | `standard` (also the empty/default style) | `cornetto` |
|---|---|---|
| Call | `Court.make_racket_view(parent, name, tint)` or `(..., Court.RACKET_STYLE_STANDARD)` | `(..., Court.RACKET_STYLE_CORNETTO)` |
| Node names | `Face`, `Grip` | `CroissantHead/CroissantSegment_00..13`, `Throat/Ferrule`, `Throat/ThroatStem`, `Throat/ThroatArm_0..1`, `Handle/RollingPin`, `Handle/RollingPinKnob` ×2, `Handle/TwineBand_0..2` |
| Meshes | 2 | 24 (14 capsules + 10 cylinders) |
| Materials | tinted `StandardMaterial3D`, roughness 0.45 / 0.6 | four matte crust tones + beech + brass + cream twine, roughness 0.55–0.9, **metallic 0.0 on every part** (asserted) |
| Measured extent in the racket's own frame | 0.260 × 0.4355 m | 0.271805 × 0.427409 m |
| Who draws it | all six frozen athletes, the Colosso/Maestro asset tests, the racket_review prototype | `fornaio` only (or a caller passing the style explicitly) |

Both roots are the same frame — root at the head centre, grip centre 0.2405 m below — so
`AthletesView.RACKET_HAND_LOCAL` / `RACKET_HAND_ROTATION` are **unchanged** and the cornetto rides the same
hand bone with no new offset. The grip band is the shipped one (`CORNETTO_HANDLE_L` is `RACKET_GRIP_L`, same
centre y): the test asserts the cornetto's handle covers the hand-attach y and reaches the top of the shipped
grip band, and that the hand closes on the rolling pin, never on the pastry.

The croissant head, in the numbers the code uses: a **solid crescent** (`CORNETTO_OUTER_R` 0.13 disc minus a
bite disc centred `CORNETTO_BITE_D` 0.062 below the centre; `CORNETTO_TIP_Y` 0.078 sets where the two circles
cross, from which `cornetto_crescent()` derives bite radius 0.1052 and horn angle 126.9°). 15 knots along the
crescent's midline, one capsule per gap, radius tapering to a point at each horn with
`CORNETTO_HORN_TAPER` 0.45 pulling the outward edge in and `CORNETTO_SEGMENT_GAP` 0.05 thinning every other
segment — the rolled, flaky read. The head is fitted so its widest segment lands on `2 * RACKET_FACE_R`
(0.26 m, the ellipse face's width) and is centred on the root: fit scale 1.0213, offset −0.0232.

## 2. How `fornaio` is bound to `cornetto`

Three ways in, in priority order (`athletes_view.gd`):

1. **Explicit style per role** — `spawn(lineup, outfits, colors, styles)` with `styles["player"] = "cornetto"`.
   The new 4th argument is optional and empty by default, so every existing caller (the match controller, the
   Colosso asset test) is untouched. This is also the escape hatch for a preview or a menu that owns the prop
   before the athlete id exists.
2. **The athlete id** — `AthletesView.racket_style_for(athlete_id)` returns `cornetto` for `fornaio` and
   `standard` for everything else (including an empty id). The match controller does not need to know: it
   passes the lineup, `spawn` reads each role's athlete id, and the croissant follows. Verified end-to-end,
   no override: `CORNETTO_SPECIAL rigs=1 style=cornetto` — the special spawned as a real rig and its racket
   node carries a `CroissantHead` on the hand bone.
3. **The degraded path** — `match_controller.gd::_build_capsule_fallback()` (used when no rig GLB can be
   read) now asks `_racket_style_of(role)`, which is the same id rule read off the resolved lineup, so
   Fornaio keeps Il Cornetto even in the fallback build.

The roster lane landed `fornaio` in `src/character/athlete_rig.gd` during this session (it maps to
`maestro-rigged.glb` as a placeholder rig); before that the id was nowhere in code, which is why the style can
also be requested by name. No roster, frozen-data or character file was touched by this change.

## 3. Verification, with the commands that produced it

```
# the gate (headless; only run when pgrep -x Godot is empty)
$GODOT --headless --path godot/ --script res://tests/cornetto_racket_test.gd
  -> exit 0, "PASS 33/33", SCRIPT ERROR 0, ERROR 0
  -> CORNETTO_SPANS plain=(0.26, 0.4355) standard=(0.26, 0.4355) cornetto=(0.271805, 0.427409)
  -> CORNETTO_SPECIAL rigs=1 style=cornetto

# lint: new findings only, per file, against the HEAD byte-for-byte baseline in /tmp/cornetto-base/
gdlint godot/game/court.gd godot/game/athletes_view.gd godot/game/match_controller.gd
  -> court.gd 4 max-line-length + 1 duplicated-load, athletes_view.gd 2 class-definitions-order,
     match_controller.gd 14 max-line-length + max-public-methods + max-file-lines
  -> every one of those is in the HEAD baseline too: diff of the normalised findings = empty (0 new)
gdlint godot/tests/cornetto_racket_test.gd   -> "Success: no problems found"

# the look (temporary SceneTree probe, deleted after use; windowed so the GPU renders)
$GODOT --path godot/ --script res://tests/_probe_cornetto_render.gd
  -> /tmp/cornetto-render-front.png, /tmp/cornetto-render-3q.png (1280x720, real Metal context)
```

The test asserts: the default and explicit `standard` still build `Face` + `Grip` and **no** croissant; the
cornetto builds a `CroissantHead` with one mesh per segment, a `Throat` and a `Handle` (not an empty root),
every mesh carrying a mesh and a material, every material non-metallic; both styles in the 0.36–0.52 m band
and within 5 cm of each other; the head width on the ellipse face's width; the grip band covering the
hand-attach y; and all three binding paths above.

Independent read of the two engine renders (vision pass over `/tmp/cornetto-render-3q.png`): *"the crescent
curve, paired with the baked golden/brown colour bands and segmented, layered form, clearly evokes the shape
and appearance of a baked laminated croissant… the three-quarter view shows the head as a solid 3D form with
visible thickness and depth, with no hollow or empty areas."* The front view reads as an open crescent with
the throat's Y in the concave underside — which is the intake image's own pose, not a defect.

## 4. What the measurements caught (recorded, not hidden)

1. **`CapsuleMesh.height` includes both hemispheres.** Passing the chord length made every segment pinch to a
   point at each knot: the first measured head was 0.250028 m wide and the total 0.392605 m. With
   `chord + 2 * radius` the tube is continuous and the same numbers became 0.2718 / 0.4274. The fix and the
   measured before/after are in the `_add_racket_capsule` docstring.
2. **`global_transform` before tree entry.** The test's first run printed **630**
   `Condition "!is_inside_tree()" is true` errors and measured nonsense spans ((0.052, 0.13) for the
   cornetto) because a `SceneTree` script's `_initialize()` runs before the scene is in the tree. Measuring in
   the racket's own frame by composing local transforms — which is the honest frame for comparing the two
   styles anyway — took the run to 0 errors.
3. **The 0.2718 m width is the bounding box, not the outline.** The test measures the AABB of each rotated
   capsule mesh; the rotated box over-reports the visible capsule by about a centimetre. The fit targets
   0.2600 m and the measured box is 0.2718 m (4.5% over) — inside the asserted 2 cm tolerance, and recorded
   here rather than rounded down.
4. **The head is a crescent, so the front view is open.** A vision pass on the front render asked for a faint
   string grid "to signal racket". Refused: the owner's DNA for this prop is a solid pastry head with no
   strings and no perforations, and the concave underside is where the beech throat sits (same as
   `meshy/views/cornetto-front.png`).
5. Low-poly by house band: 14 radial segments per capsule (the ellipse face uses 20, the grip 10), no smooth
   normals workaround, four flat crust tones rather than a baked texture.

## 5. Visual stand-in, plainly

This is **procedural replacement art, not the prop**. Il Cornetto's real asset is the Meshy
Image-to-3D bake from `meshy/views/cornetto-front.png` (brief: `meshy/fornaio-brief.md`, "Racket DNA";
spend: `meshy/image-spend-fornaio.json`) — **there is no `cornetto.glb` in the tree**, so until that GLB is
delivered and imported, the match shows the geometry above. When it lands it mounts at the same anchor with
the same `RACKET_HAND_LOCAL` / `RACKET_HAND_ROTATION`, and this head retires; nothing about the style
argument or the binding needs to change. Scratch material used to check the shape before the engine run is
outside the repo (`/tmp/cornetto_projection*.py`, `/tmp/cornetto-projection*.png`).

## 6. Not done

- The full slice and the other slices were **not** run (task scope; and the checkout was shared with a live
  play session and three other lanes' uncommitted edits). What is claimed is the command above and its tally.
- No line in `docs/mission/LOG.md`: that file is being edited concurrently by another lane in this shared
  checkout, and the instruction here was not to commit. Nothing was committed.
- No human look at the in-match framing. The racket is a 0.43 m prop in a whole-court camera: the owner's
  verdict on how the croissant reads at match distance is the one measurement this file cannot make.
