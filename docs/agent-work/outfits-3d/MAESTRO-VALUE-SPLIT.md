# MAESTRO — the value gate that separates the two garment families

The Maestro profile of `OUTFIT_PROFILES`, the shader gate it needs, and the measurement
that chose the split. Checkout: `/Users/alessiofantini/Documents/steam-circuit-padel-11m`,
branch `codex/integrate-arena-11m`. The tree was already dirty with other lanes' work and
was not touched outside this lane's three files. No commit, no push.

## 1. The problem this closes

The masked recolour path tells a baked atlas's two recolourable families apart by HUE
around two anchors. Maestro's anchors are `#102040` navy (hue 217.1°) and `#68a8c8` sky
(hue 196.5°) — **20.0° apart under a 42° tolerance** — so the hue test accepts both
families for most of the mask and the six slots collapse onto one colour per region.

Measured on all 1,518,775 masked texels, with the constants a profile material actually
runs on (see §3): **973,915 texels (64.13%) answer to both anchors at once.** The mask
lane reported the same failure for the constants it assumed (988,162 with 45°/0.18): the
verdict does not depend on which set you use.

**Fix, implemented:** a per-profile VALUE band per family, multiplied into the hue weight.
Off unless a profile declares it, so the path every other athlete uses is unchanged.

## 2. The split, measured on the atlas — not chosen

Tool: `tools/character/measure_maestro_value_split.py` (numpy + PIL, read-only).
Report: `docs/agent-work/outfits-3d/evidence/maestro-value-split/maestro-value-split-report.json`.

Population = texels inside the mask (`alpha ≥ 128`) that the shader can recolour at all:
`sat ≥ sat_min(0.25)` and hue in `[150°, 270°)` → **994,860 texels (65.5% of the mask)**.
Without that saturation filter the "population" is dominated by the white/grey shoes,
which no anchor can ever match.

| fact | value |
|---|---|
| masked texels (`alpha ≥ 128`) | 1,518,775 |
| recolourable (blue-hued, `sat ≥ 0.25`) | 994,860 |
| the atlas's only density discontinuity | **value 0.76**, a **5.34×** jump (787 → 4,206 texels per 0.01 bin) |
| dark family, value < 0.74 | **969,284** texels |
| light family, value ≥ 0.76 | **24,067** texels |
| edge band, value 0.74–0.76 | 1,509 texels, **92.2%** of them within 5 px of the light cluster |
| light family shape | 23 components ≥ 64 px, largest 3,471 px (bbox 113×53) — painted panels, not speckle |
| light family by region | torso 3,498 · hip 20,590 · **foot 0** |

**Wired:** `band_a = [0.0, 0.74]`, `band_b = [0.76, 1.0]`, `feather = 0.01`. The two ramps
meet at 0.75 — which is the accent's own antialiased edge, the band where 92.2% of texels
sit next to the light cluster. The split is therefore on the atlas's real painted edge, and
it is narrow enough that nothing in the middle of a painted area is left behind.

### Texels that fall in neither family

* **524,424 masked texels (34.5%)** keep their baked colour. They are texels no anchor
  claims by hue or saturation — the white shoes and stripes, skin, greys. This is the same
  set as today (524,321), i.e. the gate does not widen it.
* **103 texels (0.0068%)** are orphaned BY THE GATE: bright texels (value ≥ 0.75) whose hue
  (238.5°–259.1°) sits outside both anchors' tolerance windows. 12 components, largest 36
  px. They keep their baked colour.
* Cutting the dark band lower is worse, measured: `band_a` upper bound 0.60 → **5,199**
  orphans in 503 components (370 of them ≤ 4 px); 0.65 → 3,349 in 475; 0.70 → 1,882 in 535;
  0.72 → 1,175 in 510; 0.74 → **103** in 12. Those extra orphans are isolated texels of the
  garment's own baked shading: preserved navy inside a recoloured jersey, i.e. speckle.

## 3. A finding that changes a number in the mask lane's report

`outfit_catalogue.gd::_apply_profile` never pushes `MASK_DEFAULTS` into the material, so a
**profile material runs on the shader's own declared literals** — `hue_tol_deg 42.0`,
`sat_min 0.25`, `val_min 0.06`, `val_max 0.99` — not on the mask lane's assumed
`45.0 / 0.18 / 0.02 / 0.98` (that set is what `make_material()` pushes for the legacy
Volpe path). Both are measured in the report; the separation verdict is identical for both
(973,915 vs 988,162 texels matching both anchors), so nothing downstream changes. The
constants were not re-tuned.

## 4. Which of the 18 slots actually change something

Movable texels are a property of (region × family) — identical for the three outfits.
ΔE76 is the target against the modal baked colour of the texels the slot moves.

| slot | movable texels | share of region | baked modal | ΔE76 circuit / legend / signature |
|---|---|---|---|---|
| `torso_a` | 200,325 | 82.0% | `#102040` | 80.0 / 102.9 / 70.6 |
| `torso_b` | 3,673 | 1.5% | `#68a8c0` | 48.8 / 60.9 / 32.8 |
| `hip_a` | 260,622 | 77.6% | `#102040` | 80.0 / 53.9 / 24.5 |
| `hip_b` | 21,201 | 6.3% | `#68a8c8` | 31.6 / 68.3 / 51.4 |
| `foot_a` | 508,780 | 54.2% | `#102840` | 18.3 / 87.7 / 21.8 |
| `foot_b` | **0** | 0.0% | — | — |

**15 of the 18 slots move texels. `foot_b` is INERT on all three outfits.** The shoe accent
in this atlas is desaturated white/grey (`sat < sat_min`), so the declared accents
(`#9ef8ff` / `#5a4617` / `#17c8fe`) have no texel to land on: `sat_min` rejects them, and
that is the known limit, now measured rather than suspected. The white it points at
(425,393 neutral texels in the `foot` region) is the base kit's own white, not an outfit
colour — the same white in base, circuit and signature.

Also live but small: `torso_b` (1.5% of the torso) and `hip_b` (6.3% of the hip) are the
light-blue accent. The three `a` slots are the garment's mass.

## 5. Files

| file | change |
|---|---|
| `godot/src/character/outfit_region_recolour.gdshader` | optional per-profile value gate: `value_gate_enabled` (default false), `value_band_a`, `value_band_b`, `value_band_feather`, and `value_band_weight()` multiplied into `family_weight()`. With the gate off it returns exactly 1.0, so the shipped path is bit-identical |
| `godot/src/character/outfit_catalogue.gd` | `&"maestro"` in `OUTFIT_PROFILES` (mask, anchors, `mask_sha256_prefix dc39e62c92bc5b8e`, `value_gate`, circuit/legend/signature with `port_only: ["hip_a"]` on circuit); `profile_value_gate()` + `_apply_value_gate()`, written on every apply so a cached material can never carry a stale gate |
| `godot/tests/outfit_maestro_profile_test.gd` | new headless gate: profile shape, mask sha256 against the file, rig switching, base round-trip, Fiamma gate-off assertion, and an in-engine re-measurement of the separation on the real atlas + mask |
| `tools/character/measure_maestro_value_split.py` | the measurement tool (new) |
| `docs/agent-work/outfits-3d/evidence/maestro-value-split/maestro-value-split-report.json` | machine report (new) |

Nothing else was modified. `godot/src/character/outfit_region_recolour.gdshader.uid` is a
Godot-generated sidecar that appeared when the engine loaded the shader; untracked, like
~25 other `.uid` files in this tree.

## 6. Verification, with exit codes

| command | result |
|---|---|
| `python3 tools/character/measure_maestro_value_split.py` | exit 0 |
| `Godot --path godot --headless --script res://tests/outfit_maestro_profile_test.gd` | **PASS 118/118, exit 0** |
| `… res://tests/outfit_fiamma_profile_test.gd` | PASS 108/108, exit 0 (identical to the pre-change baseline) |
| `… res://tests/modes/outfit_challenges_audit.gd` | PASS 89/89, exit 0 (baseline identical) |
| `… res://tests/ui/screen_characters_audit.gd` | PASS 170/170, exit 0 (baseline identical) |
| `… res://tests/athlete_roster_test.gd` | FAIL 56/60, exit 1 — **broken before this lane**, same 8 failures, same count |
| `… res://tests/maestro_asset_test.gd` | FAIL 31/34, exit 1 — pre-existing; proved by re-running it with the pristine `HEAD` copies of the two files this lane changed (same 3 failures: 12,253-triangle mesh vs 30,980 expected, and the walk clip not moving) |
| `… tests/athlete_rig_test.gd`, `colosso_asset_test.gd`, `meshy_fiamma_integration_test.gd`, `three_athlete_assets_test.gd`, `outfit_profile_probe.gd` | exit 0 |
| `git diff --check` | exit 0 |

The new test also caught a real shader bug during development: the gate helper was declared
after its first call, and Godot's shader parser rejected it (`No matching function found for
'value_band_weight'`). So the headless run does compile the shader — it is not a no-op check.
The render lane hit the same error in its first profile-present capture, which is the second,
independent confirmation of that fix.

The in-engine measurement agrees with the offline one: 0.6420 of sampled masked texels match
both families today (offline 0.6413), **0** with the gate, the light family in the hip and
torso, and 0 in the foot.

### The render evidence, from the render lane (not this one)

`godot/tests/outfit_maestro_capture.gd` + `tools/character/compare_maestro_renders.py` ran the
real 64-frame studio capture with **this profile and this shader in place** (frames at 16:43,
after the shader-ordering fix; no functional edit to either file after that — the A/B
experiment in §6 restored byte-identical content, `shasum -c` OK). Their report is
`docs/agent-work/outfits-3d/MAESTRO-RENDER.md`, machine report
`evidence/maestro-render-compare.json`, `ok: true`. Quoted from it, because it is the visual
check this lane cannot run:

| their measurement | value |
|---|---|
| circuit vs base, body pixels changed > 4/255 | 47.67% (mean abs 35.5/255) |
| legend vs base | mean abs 67.1/255 |
| **circuit vs signature** | **42.69% changed, mean 21.36/255, 50.03/255 over changed pixels** |
| skin heuristic, mean over selected skin pixels | 1.88/255 per channel, under their 2.5 gate |
| verdict | all three variants move pixels; `circuit ≠ signature` on screen |

So the collapse this lane fixed is gone where it counts: the two outfits the palette lane
flagged as closest are still visibly different, and skin is not repainted.

## 7. Limits, said plainly

1. **This lane produced no render.** A headless Godot has no framebuffer, so the family test is
   mirrored in GDScript in the test (exact mirror, constants read from the shader source, gate
   uniforms read off the material). What is proven here is the split and the wiring. The visual
   check exists and is another lane's: the 64-frame capture in §6, made with this profile in
   place. It ages with the profile: if the bands or the anchors change, re-run
   `godot/tests/outfit_maestro_capture.gd` (needs a real window, not `--headless`).
2. **103 texels stay baked** (bright, hue 238.5°–259.1°): no anchor claims them and the hue
   tolerance was not touched. 0.0068% of the mask.
3. **The `b` slots paint the accent, not the sprite's second family.** The palette lane's
   table maps `b` to the sprite's second cluster, which for circuit/legend is a *dark* panel;
   in the atlas the second family is the *light* accent. With the gate the `b` slots are now
   addressable, so those colours land on the accent (1.5% of the torso, 6.3% of the hip).
   Whether that reads well is an art call and needs the render.
4. **The mask is another lane's and moves.** If it is regenerated the sha256 changes; the new
   test fails on the prefix, which is the intended tripwire.
5. `mythic` stays out of scope: it has no target set and the rig restores its own material.
