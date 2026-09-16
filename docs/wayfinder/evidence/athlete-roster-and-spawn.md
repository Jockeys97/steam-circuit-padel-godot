# Athlete roster, outfit catalogue and the spawn seam

Slice 2 of the athlete lane, Godot 4.7.2 port of Steam Circuit Padel Pro.
Continues `docs/wayfinder/evidence/athlete-animation-slice.md` (the rig itself).
Nothing here was committed, pushed or published. Zero paid spend, zero Meshy
credits, zero new asset generation: this slice reuses the existing rig and the
frozen browser reference's own data.

---

## 1. What exists

| What | Where |
|---|---|
| The reference's six athletes and 26 outfits, derived not retyped | `tools/character/extract_reference_catalogue.py` -> `godot/assets/athletes/reference_catalogue.json` |
| Catalogue module: resolves (athlete, outfit) onto rig material parameters | `godot/src/character/outfit_catalogue.gd` |
| The recolour itself, per-fragment | `godot/src/character/outfit_recolour.gdshader` |
| Spawn seam for the match scene | `godot/src/character/athlete_spawn.gd` |
| Headless gate | `godot/tests/athlete_roster_test.gd` |
| Render evidence scene + wrapper | `godot/src/character/roster_render.gd`, `RosterRender.tscn`, `roster_render.sh` |
| Pixel measurement + contact sheet | `tools/character/measure_roster_outfits.py` |
| Rendered evidence | `godot/src/character/out/roster_*`, `godot/src/character/out/athlete_*_base_x0_*` |

Two additive functions were added to `godot/src/character/athlete_rig.gd`
(`get_base_material()`, `note_catalogue_outfit()`/`get_catalogue_outfit()`) plus one
key in `get_pose()`. Nothing existing was changed; `godot/tests/athlete_rig_test.gd`
was not touched and still prints `PASS 41/41` (section 6).

### Where the numbers come from

`js/data.js` (frozen reference, sha256 `c63c496cd967663a5ec9f708e77b6f6948e4b523ba5b0e4280a40af642ec6403`)
defines `ATHLETES[]` and `ATHLETE_OUTFITS{}`. The extractor parses both and emits JSON;
`--check` re-derives and exits 1 on drift, so the port cannot quietly diverge from the
reference. Counts: **6 athletes, 26 outfit entries** (maestro/pantera/steamer/fiamma
5 each, oracolo/colosso 3 each).

The reference describes an outfit as exactly two colours, `colors: [a, b]`. The rig is
one mesh with one baked 2048x2048 atlas whose only garment-shaped texel families are
the navy body panels (`#22304a`) and the gold trim (`#ffc94a`) — measured by the
previous slice, `tools/character/outfits-strong.json`. The mapping is therefore
positional and uniform across all 26 entries:

```
outfit colors[0]  ->  the #22304a family   (top, shorts, sneaker panels)
outfit colors[1]  ->  the #ffc94a family   (chevron, collar, wristbands, shoe stripes)
```

No per-outfit tuning exists anywhere in this lane. No colour was invented.

---

## 2. Commands, exit codes, key output

Every Godot invocation is wrapped in the shared engine lock with `timeout` inside, per
the host rule (3910 MB RAM, 0 swap, other agents concurrent).

**(a) Derive the catalogue from the reference**
```
python3 tools/character/extract_reference_catalogue.py
```
exit `0` — `CATALOGUE_WRITTEN godot/assets/athletes/reference_catalogue.json athletes=6 outfit_entries=26`

```
python3 tools/character/extract_reference_catalogue.py --check
```
exit `0` — `CATALOGUE_CHECK_OK athletes=6 outfit_entries=26 source_sha256=c63c496cd967663a`

**(b) Render every outfit** (xvfb + software GL; NOT `--headless`, which captures blank)
```
flock -w 900 /tmp/padel-godot.lock ./godot/src/character/roster_render.sh 512x512
```
exit `0` — `ROSTER_RENDER_PASS frames=33` / `RESULT: ROSTER_RENDER_PASS`
(33 captures = 1 background + 26 outfits + 6 per-athlete base duplicates)

Framing, logged and identical for every frame:
```
EXTENT world pos=(-0.522217, 0.044973, -0.277535) size=(1.041607, 1.678306, 0.266738) (framed height 2.0140 m)
CAM pos=(0.0, 0.884126, 2.622499) fov=40.000 FRAMING_SHIFT_PX dx=0.0000 dy=0.0000
RIG { "load_error": 0, "joints": 24, "triangles": 31325, "surfaces": 1, ... }
```

**(c) Measure the frames** (offline, no engine)
```
/root/scrappy/.venv/bin/python3 tools/character/measure_roster_outfits.py --res 512x512 --floor 8.0
```
exit `0`
```
MEASURE_OK frames=26 body_px=47977 garment_window_px=2102 bbox=[201, 234, 244, 312]
FLOOR 8.0/255 on garment_mask_mean_abs_255
SAME_ATHLETE min=2.557 max=164.777  below_floor=2 of 46
  BELOW steamer:signature|steamer:mythic garment_mask=2.557 window=3.043 whole_model=0.344
  BELOW pantera:signature|pantera:mythic garment_mask=6.304 window=6.947 whole_model=0.847
CROSS_ATHLETE min=0.742 (maestro:legend|fiamma:legend)
```
(`/root/scrappy/.venv/bin/python3` is the only interpreter on this host with numpy+PIL.)

**(d) The new headless gate**
```
flock -w 900 /tmp/padel-godot.lock timeout 180 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
  --script res://tests/athlete_roster_test.gd
```
exit `0` — `PASS 67/67`, including
```
ok exactly the documented pairs fall below the 8.0/255 floor
ok min separation outside the quarantine is >= 8.0/255 (measured 13.277)
ok the quarantined pairs are still measured, at 6.304/255
```

Red signal proven (same command, `-- --inject-failure`): exit `1`, `FAIL 65/67`.

**(e) The previous slice's gate, unchanged, still green**
```
flock ... --script res://tests/athlete_rig_test.gd
```
exit `0` — `PASS 41/41`

**(f) Engine harness**
```
flock -w 900 /tmp/padel-godot.lock timeout 120 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/
```
exit `0` — `PASS 8/8`. `run/main_scene` and `godot/project.godot` untouched.

---

## 3. The separation floor, and the measured table

### The floor

> **A pair of outfits on the same athlete is visibly distinct when the mean absolute
> per-channel difference between their two rendered frames, over the GARMENT MASK,
> is at least 8.0/255.**

Why **8.0/255**: the repo's own recolour tool (`tools/character/recolour_outfits.py`)
already treats 2/255 as "this texel changed at all" and 10/255 euclidean as "this texel
changed visibly". 8.0/255 mean-abs per channel is ~13.9 euclidean over three channels —
above that visible-change threshold — but demanded as an **average over the whole
garment**, not of a lucky texel. It also sits an order of magnitude above the previous
slice's failing pair (1.93/255 whole-model) and well below its succeeding pair
(21.73/255 in the shorts window), so it separates the two outcomes that run observed.

Why the **garment mask** and not the whole model: the recolour can only move the pixels
an outfit controls. Measured here, that is **6,447 of 47,977 body pixels (13.4%)** — the
shorts, chevron, collar, wristbands and shoe stripes. The large white top and the ivory
fur are near-neutral in the baked atlas and are deliberately protected by the
saturation guard (`protect_sat = 0.22`), which is the same guard that keeps the fur from
being tinted. Diluting every measurement by 86.6% of unchangeable pixels would measure
the model, not the outfit. The whole-model number is reported for every pair anyway,
because it is what the previous slice reported and the two runs should stay comparable.

**Method correction, recorded openly.** The first pass of the measurement tool stated
the floor on the *largest connected garment component* (the shorts, bbox
`[201,234,244,312]`, 2,102 px). That region called `maestro base` vs `maestro signature`
a tint at 3.31/255 — wrong: those two share a shorts colour (`#08bfe8` vs `#03c7ed`) and
differ on the chevron, wristbands and shoe stripes, with **4,861 body pixels moving by
more than 8/255**. The region was corrected to the full garment mask before the floor
was fixed. Both numbers are in the table below and in the JSON dump, so the correction
is auditable rather than something you have to take on trust.

### Regions (derived from the frames, none hand-drawn)

| Region | Pixels | How it is derived |
|---|---|---|
| body | 47,977 | any outfit frame differs from the background-only frame by >6/255 in any channel |
| garment mask (**floor region**) | 6,447 | body pixels whose per-channel range across all 26 frames exceeds 8/255 |
| garment window | 2,102, bbox `[201,234]-[244,312]` | largest 4-connected component of the garment mask (the shorts) |

### Same-athlete pairs — all 46, ascending

Floor = 8.0/255 on the garment-mask column.

| athlete | pair | garment mask | garment window | whole model | |
|---|---|---:|---:|---:|---|
| steamer | signature vs mythic | 2.56 | 3.04 | 0.34 | TINT |
| pantera | signature vs mythic | 6.30 | 6.95 | 0.85 | TINT |
| oracolo | signature vs mythic | 13.28 | 17.96 | 1.78 | ok |
| pantera | base vs signature | 18.17 | 8.80 | 2.44 | ok |
| steamer | base vs signature | 18.30 | 10.65 | 2.46 | ok |
| steamer | base vs mythic | 20.45 | 13.41 | 2.75 | ok |
| fiamma | signature vs mythic | 21.53 | 17.49 | 2.89 | ok |
| pantera | base vs mythic | 22.44 | 12.93 | 3.02 | ok |
| maestro | base vs signature | 24.42 | 3.31 | 3.28 | ok |
| fiamma | base vs legend | 39.99 | 45.45 | 5.37 | ok |
| steamer | base vs legend | 44.71 | 52.21 | 6.01 | ok |
| maestro | base vs circuit | 47.18 | 60.55 | 6.34 | ok |
| fiamma | circuit vs signature | 53.22 | 59.87 | 7.15 | ok |
| oracolo | base vs signature | 53.55 | 64.14 | 7.20 | ok |
| pantera | base vs legend | 54.15 | 68.14 | 7.28 | ok |
| maestro | circuit vs mythic | 56.31 | 67.76 | 7.57 | ok |
| maestro | circuit vs signature | 62.73 | 63.85 | 8.43 | ok |
| steamer | legend vs signature | 62.94 | 62.76 | 8.46 | ok |
| fiamma | circuit vs mythic | 63.03 | 65.73 | 8.47 | ok |
| pantera | legend vs signature | 63.27 | 64.26 | 8.50 | ok |
| steamer | legend vs mythic | 64.93 | 65.29 | 8.73 | ok |
| oracolo | base vs mythic | 65.95 | 82.10 | 8.86 | ok |
| pantera | legend vs mythic | 69.39 | 70.98 | 9.33 | ok |
| colosso | base vs mythic | 78.05 | 84.23 | 10.49 | ok |
| steamer | base vs circuit | 87.40 | 101.91 | 11.75 | ok |
| fiamma | base vs signature | 89.13 | 120.01 | 11.98 | ok |
| fiamma | legend vs signature | 92.20 | 118.61 | 12.39 | ok |
| maestro | base vs mythic | 93.51 | 126.34 | 12.57 | ok |
| maestro | legend vs mythic | 97.31 | 131.65 | 13.08 | ok |
| fiamma | legend vs mythic | 98.14 | 124.93 | 13.19 | ok |
| fiamma | base vs mythic | 98.56 | 126.33 | 13.25 | ok |
| steamer | circuit vs signature | 98.93 | 111.62 | 13.30 | ok |
| colosso | base vs signature | 100.47 | 131.07 | 13.50 | ok |
| steamer | circuit vs mythic | 101.20 | 114.43 | 13.60 | ok |
| steamer | circuit vs legend | 112.51 | 147.49 | 15.12 | ok |
| maestro | signature vs mythic | 113.67 | 129.64 | 15.28 | ok |
| pantera | base vs circuit | 120.04 | 146.84 | 16.13 | ok |
| maestro | base vs legend | 123.87 | 163.16 | 16.65 | ok |
| pantera | circuit vs mythic | 126.58 | 148.68 | 17.01 | ok |
| pantera | circuit vs signature | 132.64 | 155.63 | 17.83 | ok |
| fiamma | circuit vs legend | 134.90 | 176.09 | 18.13 | ok |
| fiamma | base vs circuit | 137.14 | 177.50 | 18.43 | ok |
| maestro | legend vs signature | 138.49 | 166.46 | 18.61 | ok |
| maestro | circuit vs legend | 140.98 | 181.55 | 18.95 | ok |
| pantera | circuit vs legend | 143.39 | 188.19 | 19.27 | ok |
| colosso | signature vs mythic | 164.78 | 214.57 | 22.14 | ok |

- **44 of 46 pairs clear the floor.** Minimum outside the quarantine: **13.28/255**
  (oracolo signature vs mythic), i.e. 1.66x the floor. Maximum: **164.78/255**
  (colosso signature vs mythic).
- Whole-model range across the same 46 pairs: **0.34/255 to 22.14/255**.
- **2 pairs fail, and they are an owner decision, not a tuning failure** — see section 4.

### Cross-athlete pairs (informational, not under the floor)

All six athletes share one placeholder model, so an outfit on athlete A and an outfit on
athlete B are directly comparable pixels here in a way they never are in the browser
build (where the athletes differ by their own sprites and silhouettes). 279 cross-athlete
pairs were measured; the six tightest:

| a | b | garment mask | whole model |
|---|---|---:|---:|
| maestro:legend | fiamma:legend | 0.74 | 0.10 |
| pantera:circuit | fiamma:circuit | 1.15 | 0.15 |
| pantera:legend | colosso:base | 2.92 | 0.39 |
| maestro:circuit | fiamma:circuit | 6.89 | 0.93 |
| maestro:circuit | pantera:circuit | 7.57 | 1.02 |
| pantera:signature | steamer:mythic | 7.59 | 1.02 |

`maestro:legend` (`#d5a62a`/`#fff0a3`) and `fiamma:legend` (`#f2a72b`/`#fff0a7`) are
near-identical in the reference's own data. This is not a defect of this lane and the
floor is not stated against it; it is listed here because on a one-model roster it is
visible, and the owner may want to know.

---

## 4. Open owner decisions

**OD-1 — two outfit pairs cannot be told apart from the reference's colours alone.**

| pair | reference colours | garment mask | whole model |
|---|---|---:|---:|
| `steamer:signature` vs `steamer:mythic` | `#e85d16`/`#252a31` vs `#cf531c`/`#29211c` | 2.56 | 0.34 |
| `pantera:signature` vs `pantera:mythic` | `#d20d43`/`#17151e` vs `#bd174a`/`#11131c` | 6.30 | 0.85 |

In raw sRGB distance those colour records are 27.6+23.2 and 24.3+6.6 apart. In the
browser build these outfits are told apart by their **six dedicated sprite sheets**, not
by their colours — the colour record is a swatch for the menu, the artwork is the
outfit. On a rig whose only lever is those two colours they collapse to a tint, and the
only way to raise them is to invent colours the reference does not have. That is an
art-direction call, so they are **quarantined in the open**: `BELOW_FLOOR_PAIRS` in
`godot/tests/athlete_roster_test.gd` asserts the list is *exact*, so a new pair dropping
below the floor turns the gate red, and a quarantined pair rising above it turns the
gate red too. Nothing was shipped as a tint silently.

**OD-2 — the reference contradicts itself on oracolo's base outfit.**
`ATHLETES.oracolo.visual` says `kit #6b3df0` / `accent #e3c6ff`; `ATHLETE_OUTFITS.oracolo`
`base` says `colors ["#6d42b8", "#a96cff"]`. The catalogue uses the **outfit record**,
because the outfit record is what an outfit is. Five athletes agree; only oracolo
disagrees. Reversible in one line if the owner prefers `visual`.

**OD-3 — PBR defaults (inherited from slice 1, unchanged).** The GLB imports at
`metallic = 1.0`, at which albedo barely reaches the frame. Both the rig and this
catalogue default to `metallic = 0.0, roughness = 0.85`. Fully reversible:
`AthleteSpawn.make(..., {"glb_pbr": true})`.

**OD-4 — the athlete's non-outfit `visual` fields are not expressible on this rig, and
are reported rather than faked.** `OutfitCatalogue.resolve()` returns a
`not_expressible` list per entry:
`skin`, `hair`, `hairStyle`, `kitStyle` (`diagonal`/`side`/`raglan`), `frame`
(`athletic`/`slim`/`broad`), `beard`, `secondary`. The placeholder model is a furred
spitz with one baked atlas and two recolourable texel families; a body frame, a human
skin tone and a kit-cut pattern have nowhere to go. All six athletes currently differ
**by outfit colour only**.

**OD-5 — no owner visual verdict.** Nobody has looked at the contact sheet and said the
colours are right. This lane measured that they are *different*; it did not decide that
they are *good*.

---

## 5. The spawn seam

### API — `godot/src/character/athlete_spawn.gd`

```gdscript
# factory
AthleteSpawn.make(athlete_id: StringName, outfit_id := &"base", opts := {}) -> Node3D
AthleteSpawn.set_outfit(rig: Node3D, athlete_id, outfit_id) -> bool
AthleteSpawn.describe(rig: Node3D) -> Dictionary

# menus
AthleteSpawn.ids() -> Array                              # 6, reference order
AthleteSpawn.outfit_ids(athlete_id) -> Array             # per athlete, reference order
AthleteSpawn.display_name(athlete_id) -> String          # "LA PANTERA"
AthleteSpawn.outfit_name_key(athlete_id, outfit_id) -> String   # "outfitLegend" (i18n key)
AthleteSpawn.outfit_is_locked_by_default(athlete_id, outfit_id) -> bool
AthleteSpawn.is_known(athlete_id, outfit_id := &"base") -> bool
```

`opts` (all optional): `position` Vector3, `facing_degrees` float, `locomotion`
(`&"idle"`/`&"walk"`/`&"run"`), `speed_scale` float, `glb_pbr` bool, `strict` bool
(`false` falls back to that athlete's `base` instead of failing), `name` String.

`make()` returns **`null`, never a half-built node**, for an unknown athlete id, an
outfit that athlete does not own, or a rig whose GLBs failed to load.

### Integration recipe — the exact lines another lane adds

```gdscript
const AthleteSpawn := preload("res://src/character/athlete_spawn.gd")

var rig := AthleteSpawn.make(&"pantera", &"legend", {
    "position": Vector3(-1.5, 0.0, 4.0),
    "facing_degrees": 180.0,
})
add_child(rig)
```

Then drive it with the rig's own API, unchanged from slice 1:

```gdscript
rig.play_locomotion(&"run")              # &"idle" | &"walk" | &"run"
rig.play_stroke(&"drive")                # one-shot; locomotion resumes by itself
rig.face_towards(ball_position)
rig.set_locomotion_speed_scale(speed / WALK_SPEED)
AthleteSpawn.set_outfit(rig, &"pantera", &"mythic")   # in place, allocates nothing
```

The same recipe is in the file's comment header, so the call site never has to read
this document.

### Verified properties of what comes back (from `athlete_roster_test.gd`)

`load_error = OK`, **24 joints**, 31,325 triangles, 1 surface, `opts.position` and
`opts.facing_degrees` applied, `opts.locomotion` is the live clip
(`get_pose()["clip"] == "run"`), all three locomotion clips and all four strokes
registered, the run clip actually moves the skeleton (max per-bone quaternion swing
> 0.01), a stroke can be played and reports in flight, and switching outfit in place
leaves the locomotion state alone.

### Cost, stated honestly

Each `make()` loads three GLBs. On a two-player match that is paid twice at scene setup.
**Do not call `make()` per frame**; use `AthleteSpawn.set_outfit()` to change outfit,
which writes four shader uniforms and allocates nothing.

---

## 6. What actually changed versus the previous run

| | previous slice | this slice |
|---|---|---|
| Outfits available | 5 diagnostic ids (`glacier`, `vermilion`, `midnight_violet`, `ember`, `base`) — explicitly "NOT a proposed palette" | **26**, every entry the reference defines, for **6** athletes |
| Source of colours | hand-authored diagnostic targets in `outfits-strong.json` | parsed from `js/data.js`, re-derivable, `--check`able |
| Recolour mechanism | 4 baked 2048x2048 PNG atlases on disk, one per outfit | one `.gdshader`, per-fragment, **0 baked atlases** (26 atlases would be ~416 MB on a 3910 MB / 0-swap host) |
| Weakest pair | **1.93/255** whole-model (`midnight_violet` vs `ember`) — a tint | **0.34/255** whole-model for the two quarantined pairs, but they are now *identified, gated and escalated* rather than shipped; the weakest non-quarantined pair is **13.28/255** garment mask / **1.78/255** whole model |
| Strongest pair | 11.91/255 whole-model, 21.73/255 shorts window | **22.14/255** whole-model, **214.58/255** garment window (colosso signature vs mythic) |
| Spawn | none — the rig had to be instantiated and configured by hand | `AthleteSpawn.make()` + menu accessors |
| Gate | `athlete_rig_test.gd` `PASS 41/41` | plus `athlete_roster_test.gd` `PASS 67/67`; rig test still `PASS 41/41` |

The previous run's headline weakness (a "strong" pair only reaching 11.91/255
whole-model) was a *mechanism* limit. That limit is now roughly doubled (22.14/255) at
the same camera and pose, because the shader moves both anchors together and the
per-outfit colours are stronger. What remains weak is *data*: two outfit pairs whose
reference colours are nearly identical. That is OD-1, not a mechanism defect.

---

## 7. File inventory

| file | bytes | sha256 |
|---|---:|---|
| `godot/src/character/outfit_catalogue.gd` | 13894 | `cdb084bdd75c6fea451c07a778fe3a92984fe77e412dea4bb39fe9cde4925ae3` |
| `godot/src/character/outfit_recolour.gdshader` | 5324 | `42f0ae7657d3f11bad9d462f9dd2a42fc26f271b380bf42d17ac2e54c5b09141` |
| `godot/src/character/athlete_spawn.gd` | 8276 | `c52435cd7645f9c8b71e30a299792cd0c4479259a4afcdbb376d803042ec1fb3` |
| `godot/src/character/roster_render.gd` | 7526 | `e2683bfba80a6b95262ef10fd7b584b4235ac7b8ea6533fe92633599814f9fa8` |
| `godot/src/character/RosterRender.tscn` | 208 | `9d6a242bdd0f733dd4bb4ac26c246c5ba8aa9ddf85ec1592a2de9c5e4a659f81` |
| `godot/src/character/roster_render.sh` | 1597 | `9277c04a84cdb645ca7a83b9a83061bcb9155a780238f939360f69fc920d3dcc` |
| `godot/src/character/athlete_rig.gd` | 24882 | `e1286a5360e46ee85b6ca8b53900e126d4502e523b84ae0b755b354968413954` |
| `godot/tests/athlete_roster_test.gd` | 17979 | `608af5310ac2bbf7d29c4215d1e02140b0afd7326334e3f5b6dc9366c659105e` |
| `godot/assets/athletes/reference_catalogue.json` | 11350 | `9158387c4311de486666f6eeeaffe4be0f1c8822ef606af2133ea3fed5dea89e` |
| `tools/character/extract_reference_catalogue.py` | 8225 | `ee1b50a2bbd3ed1debcc37f258fec7ecbedf649226f7b1fa4b10eb465a16a71c` |
| `tools/character/measure_roster_outfits.py` | 13323 | `9d53cc67409983f57d39e247cb762b27a759f901bc37e1b342e8c1e323165381` |
| `godot/src/character/out/roster_contact_sheet_512x512.png` | 272510 | `46bd275bf7f148c45e092f6dd09a3d1b3a5ac94296ce566e1e5bccb385acc86f` |
| `godot/src/character/out/roster_pixel_measurements.json` | 80775 | `917ae0a329c94c056a13ff8b12275af62560e4f86e3262a08bde658439a11c38` |
| `godot/src/character/out/roster_manifest_512x512.json` | 21388 | `60de54fc5760f06e6a6d1e00f4586763e2036576a8b31d3509d696c3f4209fd9` |
| `godot/src/character/out/roster_render_512x512.log` | 6060 | `3f3720b9f0605eebc93f943bbd3ad9ef5cdff5e62bc3c9c13fa57cfd77a1b08d` |
| `godot/src/character/out/roster_render_shell_512x512.log` | 7488 | `55cd4ca6a451e45477fc62208937cd783c53f3153fc596595d3df9a8f84f1d68` |
| `godot/src/character/out/roster_background_only_512x512.png` | 2216 | `6f8d260043d68434289bd59cfaece234b5f38c37ac79aec63d2f95b7574698f1` |
| `godot/src/character/out/athlete_colosso_base_x0_512x512.png` | 97010 | `d03ff746063d2314855638cff1fd9ad06ab1175e1daebece604812b4b26b44c2` |
| `godot/src/character/out/athlete_fiamma_base_x0_512x512.png` | 97113 | `2da237c830d4c1e4a16c76e917c2faadc0ecac997a70df6531f17b2eba325c91` |
| `godot/src/character/out/athlete_maestro_base_x0_512x512.png` | 96327 | `2c8ff1cdb8558cf7b5d78b71fc611bc7017ed5071a7d0da8d6590c16d7c13679` |
| `godot/src/character/out/athlete_oracolo_base_x0_512x512.png` | 97374 | `9732eb6d39232773e21dbef6c1092d92568f42329f5b0fdfd7510c74992c0d69` |
| `godot/src/character/out/athlete_pantera_base_x0_512x512.png` | 95275 | `8f1a1d6c3ec6fd7b4b6d5e4fbfcd546e4792055897e0b4658f8428b4d48288ff` |
| `godot/src/character/out/athlete_steamer_base_x0_512x512.png` | 96303 | `ff5e627d48a4439bf7109b31f57d05f04a2de943784ba4de2f787b077167d1a2` |
| `godot/src/character/out/roster_colosso_base_x0_512x512.png` | 97010 | `d03ff746063d2314855638cff1fd9ad06ab1175e1daebece604812b4b26b44c2` |
| `godot/src/character/out/roster_colosso_mythic_x0_512x512.png` | 95162 | `e947f00c0532984cb9b40898afdbd13dcdb8cfc464c68e8f30488b831b658ee0` |
| `godot/src/character/out/roster_colosso_signature_x0_512x512.png` | 93825 | `7be5ae9c1fb0f9915a2a45601ee972908ab028b07b626104879db42f6d993da5` |
| `godot/src/character/out/roster_fiamma_base_x0_512x512.png` | 97110 | `0f2082930c74fc941ff459bd98f4151f07f056d0b2e109958078065e7a4e059d` |
| `godot/src/character/out/roster_fiamma_circuit_x0_512x512.png` | 95459 | `e29bcff7f807bb93796b0983d46f22a9425db79d58165f3d9cdb1677f69fde09` |
| `godot/src/character/out/roster_fiamma_legend_x0_512x512.png` | 97096 | `4d6c31afaeadf88d0925f6bcb229472a98d7fd4bad3084e12b001618f5514227` |
| `godot/src/character/out/roster_fiamma_mythic_x0_512x512.png` | 94588 | `acf43e84868a52f15bf2210f448202a566ef448e1afc3117cc48f8a763b3ac0b` |
| `godot/src/character/out/roster_fiamma_signature_x0_512x512.png` | 95837 | `6facd35599cca802e2b1a16d0c93a6a5fdeb813685c742272165e851b3788a57` |
| `godot/src/character/out/roster_maestro_base_x0_512x512.png` | 96327 | `2c8ff1cdb8558cf7b5d78b71fc611bc7017ed5071a7d0da8d6590c16d7c13679` |
| `godot/src/character/out/roster_maestro_circuit_x0_512x512.png` | 95159 | `9f965784b4137ae31e05654d26aac391468ed7373f4bbdab29610ffb78a23dda` |
| `godot/src/character/out/roster_maestro_legend_x0_512x512.png` | 97001 | `7bec328f0b78daae53ff105ea23b5b72c7cf2bdd09f2a9fc0f6661d1f9d524af` |
| `godot/src/character/out/roster_maestro_mythic_x0_512x512.png` | 93977 | `4c7e6a061f0a175f78a4241db3d953ad43b27e32bfd7fe61fa2995d86b41d89f` |
| `godot/src/character/out/roster_maestro_signature_x0_512x512.png` | 95486 | `6df504753b711c36183e8adfa89969f47c8b6330460d18125773001f95fc9f18` |
| `godot/src/character/out/roster_oracolo_base_x0_512x512.png` | 97378 | `ffb7ba25f00ff2dc6868c46458b05b292a8bb0fe72385e352f012568dc120bbd` |
| `godot/src/character/out/roster_oracolo_mythic_x0_512x512.png` | 93922 | `100e2d8b32e4e19d0a44eabddf15961995ae0d328467958ecaa3be0762fe54f1` |
| `godot/src/character/out/roster_oracolo_signature_x0_512x512.png` | 94509 | `a5c68e1946e5916ca41555931faa02690eeb9e439efa59513bc34575c68f6886` |
| `godot/src/character/out/roster_pantera_base_x0_512x512.png` | 95275 | `ede34bbf7336775aca121d08d000c82d6ee210ab94b6d5cdcc12a4b7459ba5dc` |
| `godot/src/character/out/roster_pantera_circuit_x0_512x512.png` | 95584 | `7cc90522864bc51d287dccc8de7e65fcb1f43816d8dce1eca73db0135f9ff8f8` |
| `godot/src/character/out/roster_pantera_legend_x0_512x512.png` | 97203 | `c643180cd79a880c9a602a6b2fc469732d8c779e432c93e7ef1c329a69022b3a` |
| `godot/src/character/out/roster_pantera_mythic_x0_512x512.png` | 97114 | `052442c0381aa82e1bc40e00746b3f54dc9ccdb8154dfa908b7824108b05da45` |
| `godot/src/character/out/roster_pantera_signature_x0_512x512.png` | 95555 | `c2b00e9ddd3d480ae485a17dc1d80dd9d6e63fc4cbaa648ab111f761b7976191` |
| `godot/src/character/out/roster_steamer_base_x0_512x512.png` | 96303 | `ff5e627d48a4439bf7109b31f57d05f04a2de943784ba4de2f787b077167d1a2` |
| `godot/src/character/out/roster_steamer_circuit_x0_512x512.png` | 96058 | `01fa42535f26486da1e07a4e658e4185365777fd56b43fa57096b56a9e2b8b46` |
| `godot/src/character/out/roster_steamer_legend_x0_512x512.png` | 96485 | `4ec6698ed249a049d94ff52869f764517382950bb3655392ade186e9d208fa65` |
| `godot/src/character/out/roster_steamer_mythic_x0_512x512.png` | 95932 | `6653beffc13a6fde249e5ff01d00ba008ad503bcac4d8f4e094aafa20ddcd93f` |
| `godot/src/character/out/roster_steamer_signature_x0_512x512.png` | 96245 | `9653304bdf087b3ce2a30b5ee4378838ee245bf741a9d33ea5ef85304e524f96` |

---

## 8. NOT DONE

1. **Not wired into the match scene.** `godot/game/**` belongs to another lane that is
   working in it right now and was not touched. The seam is correct stand-alone and the
   integration recipe is section 5, but nothing calls it yet.
2. **No owner visual verdict.** Nobody has approved the look. The contact sheet proves
   the outfits are *different*, not that they are *right* (OD-5).
3. **Software-GL renders cannot support frame-rate or final-art claims.** Every frame
   here is Mesa llvmpipe through `xvfb-run --rendering-driver opengl3`. Valid for
   correctness screenshots and pixel deltas; **invalid** for any performance number and
   for any judgement about final shading, anti-aliasing or material quality.
4. **Two outfit pairs are still a tint** (OD-1) and are quarantined, not fixed.
5. **All six athletes are the same model.** Body frame, skin, hair, beard and kit cut
   are not expressible (OD-4). Six athletes currently differ by garment colour only.
6. **86.6% of the athlete cannot change colour.** The garment mask is 6,447 of 47,977
   body pixels. The large white top is near-neutral in the baked atlas and is protected
   by the same saturation guard that protects the fur; separating them would need a UV
   or vertex-colour garment mask the model does not have. Not attempted.
7. **Only one pose was rendered** (`idle` at t = 0.15 s, facing 180 deg). No per-outfit
   motion strip, no per-athlete stroke frames.
8. **512x512 only.** Higher-resolution or anti-aliased contact sheets were not produced.
9. **No outfit unlock logic.** `outfit_is_locked_by_default()` reports the reference's
   `challenge` flag; the career/unlock state machine itself is not ported here.
10. **The legacy texture-swap outfit path in `athlete_rig.gd` still exists**
    (`set_outfit()`, the 4 diagnostic PNG atlases). It is untouched so
    `athlete_rig_test.gd` keeps passing. Both it and the catalogue own surface override
    0; do not mix them. Removing the legacy path is a follow-up that would require
    editing another lane's passing test.
11. **Nothing was committed or pushed.**
