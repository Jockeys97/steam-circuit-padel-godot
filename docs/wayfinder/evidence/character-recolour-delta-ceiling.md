# Evidence: how much visible outfit difference one baked texture can carry

- Date: 2026-09-16
- Ticket: [`../tickets/character-pipeline-economics.md`](../tickets/character-pipeline-economics.md)
  (the one open item: *an in-engine render proving two visually distinct outfits
  from one model via the proposed path*)
- Lane: **offline half of the ticket's own named two-step diagnostic** — quantify
  the ceiling and prescribe the fix, so the later render lane spends its single
  engine slot on a run that is guaranteed to be informative.
- Method: one new offline analysis script, `tools/character/analyse_recolour_delta.py`,
  run in stages. Sampled/strided reads only (`--stride 4` → 512×512 = 262,144
  samples from the 2048×2048 atlas). At most two images in memory at a time.
  **No Godot, no render, no GLB, no network, no paid API, 0 Meshy credits.**
- Hard constraint honoured: `python3 tools/character/recolour_outfits.py` was
  **not run** (a full recolour pass is banned in this lane). `outfit-a.png` /
  `outfit-b.png` are read, never written. The script re-implements the tool's
  operators on the strided sample *in order to build the analytic model*; the
  existing PNGs are then used to validate that model.

This document is written incrementally; each section was appended after the
command that produced it exited 0.

## 0. Baseline restated (every number with its source handle)

Nothing here is re-measured; each row cites the file it already lives in.

| Quantity | Value | Source |
|---|---|---|
| Source texture | `meshy/rigged/volpe/volpe-texture.png`, 2048×2048 RGB | `tools/character/out/diff-report.json` (`source_size`, `source_mode`) |
| Source sha256 | `6cd22f862bab619c8e18aaf1fd3237e1dc4f2e15fa6c5098ad831d651aaf0b38` | `tools/character/out/diff-report.json` |
| `protect_sat` (mask sat floor) | 0.22 | `tools/character/outfits.json` `defaults` |
| Movable-atlas fraction (mask mean) | 0.142226 | `tools/character/out/diff-report.json` `movable_fraction` |
| `outfit-a` sha256 / `outfit-b` sha256 | `4b7c15d8…0b80` / `a7e266e8…c9b` | `tools/character/out/PROVENANCE.md` |
| Atlas A−B mean abs | **4.873/255** | `diff-report.json` `outfit_vs_outfit.outfit-a__vs__outfit-b.mean_abs_overall_255` |
| Atlas A−B per channel | 5.616, 2.392, 6.611 | same object, `mean_abs_per_channel_255` |
| Atlas texels changed (any channel >2) | 0.145998 | same object, `frac_changed_any_channel` |
| Atlas A−B mean euclidean / RMS | 9.982 / 20.566 | same object |
| Atlas A−B restricted to changed texels: abs / signed | 33.60 / (−12.76, +8.13, +44.86) | `docs/wayfinder/evidence/character-material-render.md` §3.4 |
| Rendered model mean RGB A vs B | (138.00, 139.13, 141.58) vs (138.49, 140.31, 142.76), signed A−B = (−0.49, −1.18, −1.18) | `character-material-render.md` §3.3 |
| Rendered whole-model mean abs delta | **1.2/255** | `character-material-render.md` §3.3 (ticket calls it "moves only 1.2/255") |
| Largest rendered garment window (shorts) | ~6/255 | `character-material-render.md` §3.3 |
| Confound | two copies at ±0.75 m off-axis → view-vector term of order 1/255 mixed into every cross-copy number | `character-material-render.md` §4; ticket *Remaining* |
| Engine render exit / pass | exit 0, `RESULT: CM_PASS`, 3 PNGs, 4.74 s, max RSS 380,828 kB | `character-material-render.md` §5 |

### 0.1 Input hashes re-checked this tick (stage `inputs`, exit 0)

```json
{"stage": "inputs", "stride": 4,
 "source_sha256": "6cd22f862bab619c8e18aaf1fd3237e1dc4f2e15fa6c5098ad831d651aaf0b38",
 "outfit_a_sha256": "4b7c15d842f245d419ecf9a5ccd151c293b770bb7509d1308527df46a0430b80",
 "outfit_b_sha256": "a7e266e8160a9d5d2b8b113d788c54e87f1f2ad34128dedb18bd1251f0359c9b"}
```

All three agree with `PROVENANCE.md` and with `character-material-render.md` §1.3,
so every number below is about the same bytes the engine rendered.

## 1. The analytic model, read out of `recolour_outfits.py` v1.0.1

The recolour tool never looks at UVs, polygons or the mesh. Its entire visible
effect is a per-texel function of the source atlas, so the visible delta is
fully determined by three quantities. Writing them out is what makes the ceiling
computable rather than arguable.

### 1.1 How a target colour becomes a texel delta

Per outfit, `build_outfit()` does exactly two things (source lines 169–183):

1. `chroma_mask(rgb, protect_sat)` — one mask, computed once from the **source**
   atlas: `mask = smoothstep((s − protect_sat) / 0.10)` (line 128). `s` is HSV
   saturation. This is the "region mask" the packed atlas does not give us.
2. For each anchor, `apply_anchor()` (lines 142–166) blends the texel toward the
   target:
   `out = rgb·(1 − w) + shaded·w`, with
   `w = smoothstep((hue_tol − Δhue)/hue_tol) · smoothstep((s − sat_min)/0.12)
        · smoothstep((v − val_min)/0.12) · smoothstep((val_max − v)/0.12)
        · mask · strength`
   and `shaded = linear_to_srgb( srgb_to_linear(target) · r )`,
   `r = clamp(pixel_luma / luma(source_anchor_colour), 0.45, 1.7)`.

So a texel that reaches `w = 1` goes **exactly to the target colour**, times the
shading ratio `r` that preserves its baked folds. Two consequences, both of which
the numbers below confirm:

- **`mask` is a hard coverage ceiling.** A texel with `mask = 0` (near-neutral
  fur, skin) can never move, whatever the target colours are. `protect_sat` is
  the fur guard, and it is deliberately *not* loosened in the prescription.
- **`|t_A − t_B|` is the free lever.** Everything else in the formula is shared
  between the two outfits of a pair, so the pairwise delta is approximately
  `per_texel_Δ ≈ w · r · |t_A − t_B|`.

Therefore:

```
atlas_mean_Δ   = coverage_effective × per_texel_Δ          (mean over all texels)
rendered_Δ     = atlas_mean_Δ × T                          (empirical transfer, T = 0.2463)
legal_max_Δ    = mask_mean × 255 = 0.142532 × 255 = 36.35/255      (atlas)
                 → 36.35 × 0.2463 = 8.95/255                      (rendered, whole model)
```

### 1.2 Measured coverage: the ceiling is already saturated

Stage `mask`, stride 4, 262,144 samples, exit 0:

| Quantity | Value |
|---|---|
| `protect_sat` | 0.22 |
| mask mean (sampled) | **0.142532** — agrees with the full-atlas `movable_fraction` 0.142226 to 3·10⁻⁴ |
| mask ≥ 0.99 (fully movable) | 0.135212 |
| mask > 0.01 (touchable at all) | 0.151688 |
| saturation percentiles (of 255) | p10 26.07, p25 32.19, **p50 36.13**, p75 39.81, p90 131.04, p95 163.70, p99 196.84 |
| mean saturation over the whole atlas | 0.1964 |

The atlas is overwhelmingly near-neutral: three-quarters of all texels sit at
saturation ≤ 39.8/255 (0.156) — that is the ivory fur and skin. Only ~10 % of the
atlas exceeds 131/255 (0.514) saturation, and that saturated tenth is the garment.

Hue composition of the movable (mask ≥ 0.5) region:

| Hue bin | Share of the movable region |
|---|---|
| 210–240° (navy — shorts, top, sneaker panels) | **57.52 %** |
| 30–60° (gold — trim, wristbands) | **35.77 %** |
| 0–30°, 240–270°, others | 6.71 % combined |

**Coverage is already at the ceiling.** `diff-report.json` records
`frac_changed_any_channel` = 0.145998 for the existing pair, against a mask mean
of 0.142226. The tool already moves every texel the mask permits; there is no
untapped garment region being skipped. Stage `predict` confirms it independently:
predicted changed fraction 0.146034 vs predicted mask mean 0.142532.

### 1.3 What this means before any measurement

Two levers exist and only one is open:

- **Coverage** — closed. Widening it means lowering `protect_sat`, which is the
  fur guard; `outfits-strong.json` deliberately keeps `protect_sat = 0.22` so the
  next render changes exactly one variable (target strength), which is what the
  ticket's step 2 asks for.
- **`|t_A − t_B|`** — open, and currently used at 33.5/255 out of a reachable
  ~170/255.

## 2. Validation of the model against the real PNGs

Stage `predict`, stride 4, exit 0. The script re-implemented the operators above
and ran them on the sampled atlas to *predict* `outfit-a` and `outfit-b`; those
predictions were then compared against a strided read of the real
`tools/character/out/outfit-a.png` / `outfit-b.png` (the same bytes the engine
rendered — hashes in §0.1).

| Comparison | Predicted | Measured (sampled) | Residual |
|---|---|---|---|
| A−B atlas mean abs | 4.8765/255 | 4.8767/255 | **0.0002/255** |
| A−B per channel | 5.6120, 2.4006, 6.6170 | 5.6139, 2.3972, 6.6192 | 0.0522, 0.0489, 0.0506 |
| A−B mean euclidean | 9.9873 | 9.9896 | 0.0023 |
| A−B RMS | 20.5643 | 20.5682 | 0.0039 |
| A−B mean abs over the changed set | 33.3739/255 | 33.4751/255 | 0.1012 |
| A vs source atlas mean abs | 4.0046 | 4.0056 | 0.0010 |
| B vs source atlas mean abs | 2.1927 | 2.1884 | 0.0043 |
| Per-sample euclidean delta, Pearson r | — | — | **0.99999** |

- Mean per-sample absolute residual: **0.0506/255**, i.e. the model reproduces
  the tool to ±1/20 of one 8-bit level per channel. The residual is round-off
  from the tool's `(clip(x)·255 + 0.5).astype(uint8)` quantisation, not model error.
- Cross-check against the tool's own full-atlas report: model 4.8765 vs
  `diff-report.json` 4.873 → residual 0.0035/255 (0.07 %). Stride-4 sampling is
  unbiased at this precision, so the sampled numbers below are trustworthy.
- Cross-check against the render evidence: model's signed A−B over the changed
  set is (−12.6727, +8.1598, +44.6877); `character-material-render.md` §3.4
  independently reports (−12.76, +8.13, +44.86). Two separate reads, same answer.
- **Fur guard holds.** Over the protected region (mask < 0.01, i.e. 84.83 % of the
  atlas) the predicted `|outfit-a − source|` is **0.00007/255** — zero. All
  movement is inside the movable saturated region; nothing bleeds into the fur.

**Model status: verified, not assumed.** The formula in §1.1 is validated to
0.0002/255 on the aggregate and r = 0.99999 per sample.

## 3. Prescription: exact target colours for a visibly distinct pair

Written to a **new** file, `tools/character/outfits-strong.json` (the existing
`tools/character/outfits.json` is untouched). Same schema, same tool, same source
texture, same single `albedo_texture` slot — so it is a drop-in spec for the
existing pipeline, 0 credits and 0 API calls.

Gate used: two attempts on the strong spec, both measured (stage `strong`,
stride 4, exit 0 each).

| Candidate | Atlas A−B mean abs | Per-texel over changed | Verdict |
|---|---|---|---|
| attempt 1 — targets changed, `hue_shift_deg` +20 kept on outfit-b | 9.2806/255 | 62.8121 | 1.90× — rejected |
| **attempt 2 — the prescription below** | **15.1938/255** | **102.4252** | **3.12× — prescribed** |

Attempt 1 failed for a diagnosable reason worth recording: `chroma` runs *before*
the anchors, so a hue rotation moves texels **away** from the anchor hue and
multiplies their anchor weight down — outfit-b's navy anchor topped out at
1.1·10⁻⁵ of the atlas at `w ≥ 0.99` with `hue_shift_deg` +20, versus 1.7044·10⁻²
at 0°. The prescription therefore sets `hue_shift_deg` 0 on both outfits, widens
`hue_tol_deg` 22 → 45 so the whole movable class reaches `w = 1`, and puts all of
the difference into the target colours. Anchor coverage became symmetric between
the pair (1.7025·10⁻² vs 1.7044·10⁻² at `w ≥ 0.99`), which is what a fair
comparison needs.

### 3.1 The prescribed values (`tools/character/outfits-strong.json`)

`defaults`: `protect_sat` **0.22** (unchanged — the fur guard, so the render
changes exactly one variable), `hue_tol_deg` **45.0**, `sat_min` **0.18**,
`val_min` **0.02**, `val_max` **0.98**, `strength` **1.0**, `luma_clamp`
**[0.45, 1.7]** (unchanged).

| Outfit | `chroma` | anchor `from` | anchor `to` (the prescribed target) |
|---|---|---|---|
| `outfit-a` **Glacier** | `{hue_shift_deg 0.0, sat_scale 1.15, val_scale 0.95}` | `#22304a` | **`#12a7e0`** (vivid azure) |
| | | `#ffc94a` | **`#7ff0ff`** (icy cyan) |
| `outfit-b` **Vermilion** | `{hue_shift_deg 0.0, sat_scale 1.30, val_scale 1.08}` | `#22304a` | **`#e8451a`** (vivid vermilion) |
| | | `#ffc94a` | **`#ff9a1f`** (hot orange) |

Per-channel, the dominant lever is the navy anchor (`#22304a` = 57.5 % of the
movable region):

| | R | G | B | `|t_A − t_B|` |
|---|---|---|---|---|
| `outfit-a` navy target | 18 | 167 | 224 | |
| `outfit-b` navy target | 232 | 69 | 26 | |
| **separation** | **214** | **98** | **198** | mean abs **170.0/255** |

Against today's navy targets (`#3d2360` vs `#6b1420`, separation mean abs
**41.7/255**) that is a **4.08×** increase in nominal target separation, of which
**3.06×** survives to the atlas after the soft mask edge and the shading ratio
(102.4252 / 33.4751).

### 3.2 Predicted outcome, with the transfer factor stated as an assumption

```
empirical render transfer T = 1.2 / 4.873 = 0.2463     (dimensionless)
```
T is taken directly from the measured pair — whole-model rendered mean abs delta
1.2/255 (`character-material-render.md` §3.3) divided by the atlas mean abs delta
4.873/255 (`diff-report.json`) — as the task specifies.

| Statistic | Today (measured) | Prescription (predicted) | Ratio |
|---|---|---|---|
| Atlas A−B mean abs | 4.873/255 | **15.194/255** | 3.12× |
| Atlas A−B over the changed set | 33.475/255 | **102.425/255** | 3.06× |
| Atlas A−B per channel | 5.616, 2.392, 6.611 | 18.644, 7.149, 19.788 | ~3.1× |
| **Rendered whole-model mean abs** = atlas × 0.2463 | 1.2/255 (measured) | **3.74/255** | 3.12× |
| Rendered garment-window mean abs | ~6/255 (measured, shorts) | **18.4 – 25.2/255** | 3.1–4.2× |

**Assumptions behind the transfer, stated plainly.** Transferring an *atlas* delta
to a *rendered* delta through one scalar T assumes: (a) the mapping is linear in
the delta, which §2 supports (the model is exact on the atlas side and the render
is a linear albedo→pixel chain); (b) the model's visible surface samples the atlas
with roughly uniform texel density, which it does not — UV texel density varies
across a packed atlas, so this is the weakest link; (c) **T itself is an
over-estimate**, because its numerator carries the unresolved ±0.75 m view-vector
confound (order 1/255) that the ticket flags and this offline lane cannot
separate. T should be read as an upper bound on the whole-model transfer.

The garment-window figure is bracketed for the same reason: applying T to the
changed-set separation gives 25.2/255, which over-predicts — the same rule applied
to today's pair gives 33.475 × 0.2463 = 8.25/255 against a *measured* shorts window
of ~6/255, an over-prediction of 38 %. Scaling the measured 6/255 by the 3.06×
separation ratio instead gives **18.4/255**. So the honest prediction for the
shorts window is **18–25/255**, no worse than 18/255.

**Is that visibly distinct?** Yes, by the ticket's own yardstick. 6/255 on the
shorts is what the render evidence calls "a tint, not an outfit"; 18–25/255 is a
3–4× larger shift in a garment region and is a different colour family (azure vs
vermilion) rather than two dark greens. The whole-model mean stays small (3.74/255)
because 84.8 % of the atlas is protected fur that by design never moves — that
statistic dilutes the garment by ~6× and should not be the acceptance criterion.

## 4. What this implies for the 20 unlockable outfits

`ATHLETE_OUTFITS` needs 26 entries (6 base + 20 unlockable). The question this
section answers: how many *visually distinct* outfits can one baked texture carry?

**Distinctness threshold, derived from the measurement.** A pair reads as distinct
when the rendered garment window clears ~15/255. The window transfer measured this
tick is 6.0/255 rendered per 33.475/255 atlas over the changed set = **0.1792**, so
the threshold in atlas terms is 15 / 0.1792 = **~84/255 per-texel separation**.
Two outfits are therefore visibly distinct iff their targets differ by ≳84/255
mean-abs over the movable set.

**Capacity.** The nominal target separation achievable on the dominant garment
class is bounded by the colour solid: our prescription already uses 170/255 of the
~211/255 reachable between maximally opposite garment colours, and achieves
102.4/255 after the soft mask edge and shading ratio (a 0.60 yield). So:

- Along one colour axis: 211/255 nominal ≈ **2–3 mutually distinct steps**.
- Across hue, which reads as different at smaller Δ than lightness does, **~6 hue
  families** fit around the circle at ≥60° spacing — which is exactly why the
  roster has 6 base athletes.
- Within a family, a second variant needs to clear 84/255 from the first, and a
  pure lightness change generally cannot (it saturates). Realistically **1.5
  variants per family**.

**Roster-wide rule: ~8–12 truly distinct recolours per baked texture, against a
20-unlockable set — the unlock set is roughly 2× past what one texture can carry
as visually distinct recolours.** Handing out 20 recolours from this one atlas is
possible mechanically and free, but outfits 9+ will read as near-duplicates to a
player. That is an authoring/roster-design limit, not a rendering limit.

**Authoring cost — three numbers, two already in the repo:**
- 0 Meshy credits, 0 API calls per outfit (the whole set is offline arithmetic;
  the ticket already records the 20 unlockable textures at 0 credits, 0 calls).
- One 2048×2048 PNG per outfit, measured mean **5,624,012.5 B** per authored
  outfit texture (ticket *Evidence*). 20 outfits = **112,480,250 B ≈ 107.3 MiB**,
  consistent with the ticket's 272,777,666 B roster projection.
- Wall-clock and RSS of one recolour pass: **still unmeasured** (the pass is banned
  in this lane); the ticket lists the documenting command.

**The way past the ceiling is coverage, not colour.** If true garment UV zones
existed (Meshy UV Unwrap or manual polygon selection), `mask_mean` would rise from
0.1425 toward the garment's real share of the model surface — at 0.40, the legal
maximum rises from 36.35/255 to 102/255 atlas and from 8.95/255 to 25.1/255
rendered whole-model, tripling the distinct-outfit capacity. That is the one
authoring investment that changes the roster economics.

## 5. Verified vs inferred

**Verified by measurement this tick (offline, exit 0, script and stride recorded):**

- The recolour operators reproduce the existing `outfit-a.png`/`outfit-b.png` to a
  mean absolute residual of 0.0506/255 per channel and r = 0.99999 per sample; the
  aggregate A−B residual is 0.0002/255 (§2).
- The movable-mask coverage is **0.142532** and coverage is **saturated**: the
  changed-texel fraction 0.145998 (`diff-report.json`) already meets the 0.142226
  mask ceiling; no garment region is being skipped (§1.2).
- The movable region is 57.52 % navy (210–240°) + 35.77 % gold (30–60°) (§1.2).
- The fur guard is exact: predicted movement over the protected 84.83 % of the
  atlas is 0.00007/255 (§2).
- The absolute ceiling: atlas ≤ 36.35/255, rendered whole-model ≤ 8.95/255 (§1.1).
- The prescription's atlas delta: **15.1938/255**, per-texel 102.4252/255, 3.12×
  today's pair, with anchor coverage symmetric between the two outfits (§3).
- Input hashes match `PROVENANCE.md` byte-for-byte (§0.1).

**Inferred, not measured (labelled as such):**

- **The render-transfer factor T = 0.2463.** It is an empirical ratio taken from a
  render whose cross-copy statistics carry the unresolved ±0.75 m view-vector
  confound. It transfers atlas delta to rendered delta only under uniform UV texel
  density, which a packed atlas does not have. Treat as an upper bound (§3.2).
- **The garment-window prediction 18–25/255.** Bracketed from two different rules;
  the only way to settle it is the render lane's step 1 (one copy at x = 0, one
  frame per outfit).
- **The ~84/255 distinctness threshold and the ~15/255 window threshold.** Derived
  from the single data point "6/255 reads as a tint, not an outfit" quoted in the
  render evidence. It is a reasonable working threshold, not a measured
  psychovisual limit; no human viewing test exists on disk.
- **The 8–12 distinct-outfit capacity.** Arithmetic on the above two inferences.
- **Why the atlas is only 14.25 % movable** — that the ivory fur is the reason and
  a packed atlas with no garment zones is the cause. Consistent with the hue/sat
  histograms and with `PROVENANCE.md`'s "region-mask caveat", but the UV layout
  itself was not inspected in this lane.
- The render/override path is **transparent** — i.e. it passes the texture delta
  through without attenuating it beyond the measured T — is an inference from the
  linearity of the model plus the engine log's `albedo_texture` override record.
  Step 2 of the render diagnostic either confirms or refutes it in one frame.

## 6. Does the visible-difference limit sit in the authored textures, or in the render/override path?

**In the authored textures** — specifically in the *coverage* those textures are
allowed to move (0.1425 of the atlas, capped by the fur guard the packed atlas
forces), and secondarily in how far apart the authored target colours were placed
(33.5/255 of a reachable ~170/255 at the time of the render). The render/override
path is transparent and linear: it delivered 24.6 % of the atlas delta to the
whole-model mean, and the same ratio scaled both the weak pair and the
prescription's 3.12×-stronger pair with no sign of attenuation. A stronger render
cannot manufacture difference the texture does not carry; a stronger texture can.

## 7. Reproduce

```bash
cd /root/projects/steam-circuit-padel-pro
timeout 180 python3 tools/character/analyse_recolour_delta.py --stage inputs  --stride 4   # exit 0
timeout 240 python3 tools/character/analyse_recolour_delta.py --stage mask    --stride 4   # exit 0
timeout 300 python3 tools/character/analyse_recolour_delta.py --stage predict --stride 4   # exit 0
timeout 300 python3 tools/character/analyse_recolour_delta.py --stage strong \
    --spec tools/character/outfits-strong.json --stride 4                                  # exit 0
```

Read-only with respect to every existing artefact. `outfit-a.png`, `outfit-b.png`,
`outfits.json`, `PROVENANCE.md` and `diff-report.json` are opened for reading and
never written; the recolour tool is never invoked.

