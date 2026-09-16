# Camera spike — rendered evidence

Status: IN PROGRESS (scaffold written before the build; appended as runs complete).

Spike ticket: `docs/wayfinder/tickets/camera-and-feel-spike.md`
Prototype: `godot/prototypes/arena_spike/`

## 1. Source constants (authoritative reads)

### `js/data.js` — `COURT` (lines 1-8)

```js
export const COURT = {
  left: 80,
  right: 880,
  top: 56,
  bottom: 564,
  netY: 310,
  netHeight: 38,
};
```

Derived: width = 880-80 = 800 px; length = 564-56 = 508 px; net at y=310.

### `index.html` — the match canvas (line 472)

```html
<canvas id="game" width="960" height="700" ...>
```

### Web camera composition (2D build)

> SUPERSEDED — the numbers below were derived before `js/render.js` was read.
> The real web camera is the pseudo-3D trapezoid in `render.js` (`point()`,
> quoted in section 2); the flat-canvas numbers below are kept only to show what
> changed. Use section 2.

The web build has no 3D camera: the "default match camera" is the fixed
composition of the `COURT` rectangle inside the 960x700 match canvas.

Framing numbers derived from the two reads above (recorded as evidence):

- canvas 960x700, court 800x508 -> court occupies 83.33% of width, 72.57% of height.
- court is horizontally centred (court centre x = 480 = 960/2).
- court centre y = 310 = netY; canvas centre y = 350 -> court sits 40 px ABOVE the
  canvas centre, i.e. the composition leaves ~136 px of empty space below the
  near (player) baseline and only 56 px above the far baseline.

(remaining sections appended below as the build/render proceeds)

---

## 2. The web match camera, read properly (`js/render.js`)

`js/main.js` line 1231 is the only "camera call" in the render loop:

```js
drawScene(ctx, canvas, matchState, now);
```

`js/main.js:61` `const canvas = document.getElementById("game");` and
`index.html:472` `<canvas id="game" width="960" height="700">`. Inside
`drawScene`, the court is projected by a hand-tuned pseudo-3D trapezoid
(`js/render.js`, immediately before `const polygon = ...`):

```js
const topLeft = { x: 210, y: 100 };
const topRight = { x: 750, y: 100 };
const bottomLeft = { x: 48, y: canvas.height - 13 };      // y = 687
const bottomRight = { x: 912, y: canvas.height - 13 };
const point = (x, y) => {
  const u = (x - COURT.left) / (COURT.right - COURT.left);
  const v = (y - COURT.top) / (COURT.bottom - COURT.top);
  // Put the net slightly deeper in the shot so the player's half reads as spacious.
  const depth = v <= 0.5 ? v * 0.88 : 0.44 + (v - 0.5) * 1.12;
  ...
```

So the web "match camera" is: far baseline (`COURT.top`, 20 m end) at y=100,
x 210..750 (540 px wide); near baseline (`COURT.bottom`, player's end) at y=687,
x 48..912 (864 px wide); the net (`COURT.netY`) is warped to depth 0.44, i.e.
y = 100 + 587*0.44 = 358.3. Frame fractions: far y 0.14286, near y 0.98143,
near half-width 0.45000, far half-width 0.28125, net y 0.51183.

## 3. Court dimensions used

`js/data.js` lines 1-8, verbatim: `left: 80, right: 880, top: 56, bottom: 564,
netY: 310, netHeight: 38`.
`js/game.js:30` `const SERVICE_LINE_OFFSET = 126;`

One uniform scale, `PX_TO_M = 0.025`, chosen so that COURT's 800 px span is
exactly the FIP padel length 20.00 m:

| from COURT | px | x 0.025 |
|---|---|---|
| `right - left` | 800 | **20.000 m** (court length, world X) |
| `bottom - top` | 508 | **12.700 m** (court depth, world Z) |
| `netHeight` | 38 | **0.950 m** |
| `netY` = 310 = (56+564)/2 | - | net is at mid-court (Z = 0) |
| `SERVICE_LINE_OFFSET` | 126 | **3.150 m** from the net |

**Finding (for the ticket):** COURT's aspect is 800:508 = **1.575**, not
20:10 = **2.000**. Under a single uniform scale COURT cannot be both a 20 m long
and a 10 m wide padel court — the web layout either compresses depth or is not a
scale plan. The spike uses the uniform scale and reports the 12.70 m depth rather
than silently re-scaling depth to 10 m. Note `netHeight` at 0.025 m/px gives
0.95 m, against the 0.88 m FIP net — consistent to ~8%, so the scale is sane.

Values **not** in COURT, used by the spike and flagged as spike defaults:
glass cage height 3.0 m (FIP); ball radius 0.10 m (no radius exists in
`js/data.js` — only `ballGravity: 720` — and a real 0.033 m ball is sub-pixel at
whole-court distance).

## 4. Camera fitted to that composition

A true pinhole camera at the required 16:9 output **cannot** reproduce the web
trapezoid exactly: solving the four constraints (near/far baseline y, near/far
baseline width) with `tan(fov_h) = 16/9 * tan(fov_v)` requires
`sin(pitch) = 1.036 > 1`. So the composition was fitted as closely as a pinhole
camera allows, holding the near (player) baseline **exactly** and taking the
far-baseline residuals:

- `default`: pos **(0, 14.4552, 6.4000)**, pitch **-65.200°**, fov_v **50.866°**.
  In-engine `Camera3D.unproject_position` output (log `arena_default_1280x720.log`):
  `near_centre frac=(0.5000, 0.9814)` vs web 0.98143 (exact);
  `near_left/right x = 64.0 / 1216.0` = frac 0.05 / 0.95 vs web 0.05 / 0.95 (exact);
  `far_centre frac=(0.5000, 0.1863)` vs web 0.14286 (30 px lower);
  `far x = 230.1 / 1049.9` = frac 0.1798 / 0.8202 vs web 0.21875 / 0.78125
  (far end 37 px wider than the web's hand-tuned projection).
- `wide` (variant B, "slightly wider/higher"): pos (0, 16.6235, 7.4000),
  pitch -68.0°, fov_v 60.0° -> `near_centre frac=(0.5000, 0.7878)`,
  `far_centre frac=(0.5000, 0.2254)`.
- `playable` (variant C, NOT the web composition): pos (0, 3.2000, 5.8000)
  looking at (0, 0.9, -1.0), pitch -18.687°, fov_v 60° — a normal 3D match
  camera behind the player, inside the cage.

**Finding (for the ticket):** the web's default match camera is a near
**top-down** view of the whole court (12-15 m up, 65-68° pitch, the near baseline
on the bottom edge of the frame). Any 3D camera that reproduces today's
composition is therefore the same top-down view, and a playable 3D camera behind
the player is a *different* composition. Framing parity and 3D playability are
not the same target; Luca's verdict should be asked against both.

## 5. Prototype layout and commands

`godot/prototypes/arena_spike/` — `project.godot` (gl_compatibility,
1280x720), `Main.tscn`, `arena_spike.gd` (builds court / net / glass cage / ball /
lights / camera and loads the rig in code), `render.sh`, `assets/volpe-rigged.glb`.
The GLB is a byte-identical copy of `meshy/rigged/volpe/volpe-rigged.glb`
(sha256 `ab6b3086e6a455d9cdaaf8b198dfb762924b31cd77ee01bd8fe0135e9d687ec5` for
both files; Godot can only resolve `res://`, and `meshy/` was not modified).

Command actually run (same recipe as the proven render probe: Xvfb + Mesa
llvmpipe, no GPU on this host):

```
godot/prototypes/arena_spike/render.sh <view> [out.png] [WxH]
# internally:
env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 ARENA_VIEW="$VIEW" ARENA_PNG="$OUT" \
  timeout 180 xvfb-run -a -s "-screen 0 1280x720x24" \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 \
  --rendering-driver opengl3 --resolution 1280x720 --path "$HERE"
```

Runs: `./render.sh default`, `./render.sh wide`, `./render.sh playable` —
**all three exit 0**, each log ends in `ARENA_PASS`, each PNG is a real
`PNG image data, 1280 x 720, 8-bit/color RGBA`.

Raw render logs: `arena_default_1280x720.log`, `arena_wide_1280x720.log`,
`arena_playable_1280x720.log` (next to the PNGs). Renderer proven in-log:
`ADAPTER=llvmpipe (LLVM 21.1.8, 256 bits) API=4.5 (Core Profile) Mesa 26.0.8`.

### PNG artefacts (sha256)

| file | sha256 |
|---|---|
| `arena_default_1280x720.png` | `88e764b58fa1af3acbfe3b50f20c572900e23349293aeaae36f1fbd624074921` |
| `arena_wide_1280x720.png` | `13c3b193a7d1934a2e289dc9e953c6505112315647480c84f7469344c6be611a` |
| `arena_playable_1280x720.png` | `0784303fee52520abd3c9bb61e01955ef81c480dcaba0439de6b234e9a0e813e` |

## 6. What rendered, and what did not

Rendered (verified by reading the PNGs back and by the log):

- the court plane at 20.000 x 12.700 m with perimeter, centre and both service
  lines (SERVICE_LINE_OFFSET -> 3.150 m);
- the net as a dark mesh band with a white tape on top, 0.950 m, at mid-court;
- four glass walls, 3 m, alpha 0.14;
- the yellow ball (r 0.10 m, spike-enlarged) at (1.2, 0.4, 3.5), visible in all
  three renders;
- the athlete: `GLB_LOADED in 320 ms`, `ATHLETE_ANIMATIONS=["Armature|clip0|baselayer"]`,
  `ATHLETE_ANIM 'Armature|clip0|baselayer' length=0.300 tracks=7`,
  `ATHLETE_POSE held at t=0.300 (base pose; NO idle clip exists)`,
  `ATHLETE_BONE_EXTENT bones=24 world_y=0.0450..1.7233 -> height 1.6783 m`,
  standing at (2.6, 0, 2.4) in the near half, casting a shadow. In the
  `playable` render it reads as an upright four-limbed character in the base
  pose (the asset is the white "volpe" anthro rig), which is what the base pose
  should look like.

Honest gaps / not done:

- **Skinned AABB is misleading, and was a real trap here.** The naive
  "mesh AABB x node transform" measured 0.018 m (1.8 cm) for the athlete because
  the GLB root `Armature` node has `scale 0.01` while the skin is driven by bone
  transforms; the mesh node transform is ignored for skinned meshes. The reliable
  in-engine measure is the bone extent (1.6783 m, above). Anyone re-measuring
  the rig should use the bones, not the mesh AABB.
- **Facing is unverified.** The athlete is rotated 180° about Y as a guess; the
  spike does not verify which way the base pose faces the net.
- **No play/jump/idle motion**: the ticketed x/y/z ball motion from `BALANCE`, a
  diagonal serve and camera tuning in the editor were NOT built — this artifact
  covers only the static framing question. The ball is placed, not simulated.
- **No racket, no opponent, no HUD, no crowd/arena art.**
- **The 20x10 vs 1.575 aspect mismatch is unresolved** (section 3) and needs a
  decision before the port locks a court mesh.
- `playable` renders with the near baseline behind the camera, so the
  `FRAMING near_*` lines in that log are meaningless by construction (unproject
  of a point behind the camera); the other six points are valid.
- Lighting is flat (gl_compatibility on llvmpipe, no SSAO/volumetrics); the
  per-pixel look is not representative of a final target quality.
- Only static single frames are captured; no frame-time or FPS measurement was
  made, so the spike says nothing about performance.

## 7. Budget

No metered spend; zero paid calls. No Meshy, image-generation, or other external
API was called; the render ran fully offline through Xvfb + llvmpipe, and every
Godot process was started under `timeout 180` and exited (exit code 0 each run).
