# Character pipeline economics

- Status: open
- Type: research
- Mode: AFK
- Owner: crew-alfa
- Blocked by: none

## Question

Cost and effort of turning the roster into 3D, using the Meshy lane documented
in `meshy/README.md` and the **newly generated** Volpe trial under
`meshy/rigged/volpe/` (a pipeline test, not a retrieved existing asset and not a
roster athlete). Establish per-athlete cost (image-to-3D, remesh, rigging,
animation), the retarget path from Meshy locomotion onto Godot-authored padel
strokes, the polycount budget for a game character, and — the hard part — the
exact recolour path that turns **one rigged model into satisfying outfits**.

Two facts that the answer must confront, both verified:

- **Counts.** `ATHLETE_OUTFITS` in `js/data.js` has **26 entries: 6 base, one
  per athlete, plus 20 unlockable** (maestro 5, pantera 5, steamer 5, fiamma 5,
  oracolo 3, colosso 3). Twenty is the unlock set; 26 is the total. Any port test
  asserts 26, not 20.
- **Today's outfits are sprite swaps, not recolours.** Each non-base outfit
  carries `colors`, a `challenge`, a `preview`, and `sprites` pointing at six
  spritesheets (idle, back-idle, action, back-action, run, back-run) via
  `outfitSpritePaths`, `js/data.js:498-513`. The confirmed direction is that 3D
  outfits **recolour the same rigged model**; that path is unproven, because the
  Volpe rig has a single baked material (`Material_1`, one `baseColorTexture`),
  no garment zones, no vertex colours and no separate materials. Moving from one
  packed texture to per-outfit tints needs an authoring step nobody has done yet.

## Why it matters

The roster order and any spend cap are guesses without this, and the recolour
promise is the one confirmed decision with no proven route behind it.

## Resolved when

Numbers, not adjectives: credits per athlete, minutes per athlete, triangle
count of the trial asset (31,325 across the three GLBs), and **one outfit
recoloured from the trial model with a Godot render or screenshot showing two
distinct outfits from one model via the proposed path**. Sprite paths alone do
not prove the recolour route. Feeds [Athlete roster order](athlete-roster-order.md).

## Evidence (2026-09-16)

Full numbers, methods and reproduction commands:
[`../evidence/character-pipeline-economics.md`](../evidence/character-pipeline-economics.md).

Met on disk:

- **Triangles.** 31,325 per GLB, measured by
  `python3 tools/character/glb_tri_count.py` over the three trial GLBs
  (93,975 summed, i.e. the same mesh carried three times). 1 material,
  `Material_1`, `baseColorFactor: null`, no vertex colours — measured, not
  repeated. Output: `tools/character/out/tri-count.json`.
- **Credits per athlete.** 40 measured (30 image-to-3D + 5 remesh + 5 rigging;
  `consumed_credits` in the three `*_final.json` files, corroborated by the
  account balance 3,060 → 3,020 in `meshy/rigged/RESULT.md`). Roster projection
  6 x 40 = 240 credits at today's prices. The 20 unlockable outfit textures cost
  **0 credits, 0 API calls**.
- **Minutes per athlete.** Measured API time 873.6 s (14.6 min) summed from
  `started_at`/`finished_at`; observed end-to-end 24 min 51 s
  (`gen_create.json` mtime 01:55:23 → `volpe-rigged.glb` 02:20:14), excluding an
  earlier aborted rigging attempt recorded in `RESULT.md`.
- **Asset size.** 26,716,236 B (25.48 MiB) per athlete for the three-GLB
  locomotion set; 5,624,012.5 B mean per authored outfit texture. Roster
  projection 272,777,666 B (260.14 MiB) for 6 athletes plus 20 unlockables.
- **Recolour offline (two textures, one rig).** `outfit-a` vs `outfit-b` mean abs
  diff 4.873/255, changed-texel fraction 0.1460, RMS 20.566, source texture
  sha256 `6cd22f86…` — from `tools/character/out/PROVENANCE.md` and
  `diff-report.json`.
- **In-engine render (2026-09-16, added this tick).** The owed Godot render now
  exists: `godot/prototypes/character_material/` renders `volpe-rigged.glb` twice
  in one frame, the left copy with `StandardMaterial3D.albedo_texture =
  outfit-a.png` and the right with `outfit-b.png` (surface override on the
  duplicated `Material_1`; lit `StandardMaterial3D`, `shading_mode=1`, one
  surface, 31,325 triangles re-measured in engine). Three real PNGs and every
  number — engine log, sha256, colour counts, null controls, the measured
  cross-region difference — in
  [`../evidence/character-material-render.md`](../evidence/character-material-render.md).
  The **mechanism is proven; the visible outcome is not**: the mean rendered
  colour of the model moves only 1.2/255 between the two outfits (garment windows
  up to 6/255), and the two textures themselves differ by only 4.874/255 mean
  over 14.5 % of the atlas. See Remaining.

## Remaining

One item, and only one: **an in-engine render proving two *visually distinct*
outfits from one model via the proposed path.** Everything else in "Resolved when"
is met on disk.

- The render is delivered (2026-09-16): `godot/prototypes/character_material/`,
  evidence `docs/wayfinder/evidence/character-material-render.md`. It proves the
  path mechanically — one GLB, one material, one surface, one skeleton per copy,
  two per-instance `albedo_texture` overrides, both copies in one frame, the
  override applied to a lit (not unshaded) `StandardMaterial3D` and logged, and
  two rendered bodies that are demonstrably not the same render (null control
  exactly 0.0000 mean abs; cross-copy signed shifts of 1–6/255).
- **What failed:** visible distinctness. The alignment-free statistic (mean
  rendered colour of the model) moves 1.2/255 between outfits; the largest
  garment-window shift is ~6/255 (shorts). The limit is in the authored textures,
  not the path: `outfit-a` vs `outfit-b` change only 14.5 % of atlas texels and
  their mean colour differs by ≤ 6.5/255 per channel. The render cannot show more
  than the textures carry. Second, unresolved, confound: the two copies stand
  off-axis at ±0.75 m, so a view-dependent shading term of order 1/255 is mixed
  into every cross-copy number (inferred, not measured).
- **Next diagnostic (0 credits), now costed rather than guessed.** Its offline half
  ran on 2026-09-16 (CEO-re-run; see
  [`character-recolour-delta-ceiling.md`](../evidence/character-recolour-delta-ceiling.md))
  and the answer is **authoring coverage, not the render/override path**. Only
  14.25 % of the packed atlas is recolourable (mask mean 0.1425, and the tool already
  moves every texel the mask permits), so the ceiling at today's mask is 36.35/255
  atlas → **8.95/255** on the whole rendered model, while today's pair delivers
  4.873/255 atlas → the measured 1.2/255 rendered. The transfer ratio is a stable
  0.246 and it scales linearly, so a stronger render cannot manufacture difference
  the texture does not carry. Step 2's "raise the target-colour delta" is now
  prescribed as `tools/character/outfits-strong.json` — same schema, same tool, fur
  guard untouched at `protect_sat 0.22`, so the render changes exactly one variable —
  predicting 15.19/255 atlas → **3.74/255** on the whole model, garment window up to
  25.2/255. **What remains is the render itself:** step 1 (one copy at x = 0, one
  frame per outfit) and step 2 (the same render against `outfits-strong.json`). It
  was deliberately not dispatched on 2026-09-16: the host was memory-starved (the
  neighbouring DemonPet job's own process was OOM-killed minutes before dispatch)
  and the software-GL render is the single heaviest process this mission runs.
- Correction to the command that was recorded here before: `--headless` installs
  the dummy rendering driver, so a viewport capture under it is blank. The working
  invocation is `render.sh`'s — `xvfb-run` + `--rendering-driver opengl3`:

```bash
cd /root/projects/steam-circuit-padel-pro/godot/prototypes/character_material
./render.sh 1280x720     # exit 0, "RESULT: CM_PASS", 3 PNGs, 4.74 s, max RSS 380,828 kB
```

Also still open, listed rather than asserted: whether Godot retargets Meshy's
24-joint humanoid onto hand-authored padel strokes, whether the mesh imports
clean in engine (`RESULT.md` records fused fingers/toes, tail/shorts seam and leg
texture smearing, never checked in engine), the post-decimation shipping
polycount (no decimated artifact exists), and the wall-clock/RSS cost of one
recolour pass (unmeasured; the documenting command is in evidence section 4).
