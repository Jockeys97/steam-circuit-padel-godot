# Meshy image-to-3D for environment props & architecture — current workflow, API, params, cost

Date: 2026-09-18. Scope: the CURRENT (as of 2026-09-18) Meshy image-to-3D workflow for
ENVIRONMENT PROPS AND ARCHITECTURE — not characters. Two consumers:

1. **The owner (Luca), in the Meshy web GUI** — he generates ~10 low-poly props per arena by
   hand (limit: 10 models per map) and needs the best settings to pick.
2. **Us (Hermes), later** — an automated pull of the resulting GLB/FBX into Godot 4.7.2
   (GL Compatibility renderer) via the Meshy REST API.

Companion doc: `image-prototyping.md` in this same `scan/` dir covers the INPUT images
(prompt recipe, silhouette rules). This doc covers Meshy's side: versions, endpoints, params,
credits, image requirements, limits, and the recommended config. No overlap intended.

Read-only scan. All claims carry a URL. Tags: `[doc]` (vendor documentation), `[help]`
(vendor help center), `[vendor-blog]` (Meshy-authored tutorial/marketing page), `[oss]`
(official Meshy open-source tool source), `[inference]` (my reasoning from the cited facts —
treat as hypothesis, not fact).

**Every URL below was fetched and read on 2026-09-18** (`web_extract`), not taken from search
snippets. Pages that carry no absolute date say so.

## Sources

| # | Source | Page date | Type |
|---|--------|-----------|------|
| S1 | docs.meshy.ai/en/api/image-to-3d | undated | [doc] API |
| S2 | docs.meshy.ai/en/api/multi-image-to-3d | undated | [doc] API |
| S3 | docs.meshy.ai/en/api/remesh | undated | [doc] API |
| S4 | docs.meshy.ai/api/pricing.md (md mirror of /en/api/pricing) | undated | [doc] API pricing |
| S5 | docs.meshy.ai/api/quick-start.md | undated | [doc] API |
| S6 | docs.meshy.ai/api/errors.md | undated | [doc] API (error codes) |
| S7 | docs.meshy.ai/en/api/asset-retention | undated | [doc] |
| S8 | help.meshy.ai/en/articles/16815622-how-many-credits-does-each-meshy-api-task-cost | "Updated this week" (2026-09-18) | [help] |
| S9 | help.meshy.ai/en/articles/15643844-how-long-does-meshy-keep-api-generated-assets | "Updated over a week ago" | [help] |
| S10 | docs.meshy.ai/en/webapp/pricing | undated | [doc] webapp |
| S11 | docs.meshy.ai/en/webapp/image-to-3d | undated | [doc] webapp |
| S12 | help.meshy.ai/en/articles/15723519-how-to-get-better-image-to-3d-results-in-meshy | no absolute date | [help] |
| S13 | help.meshy.ai/en/articles/15697060-meshy-7-vs-meshy-6-vs-meshy-5-which-ai-model-should-you-use | "Updated this week" | [help] |
| S14 | docs.meshy.ai/en/webapp/changelog | undated | [doc] changelog |
| S15 | help.meshy.ai/en/articles/16102789-meshy-multi-view-best-practices-angles-and-images | "Updated over a week ago" | [help] |
| S16 | help.meshy.ai/en/articles/9996860-how-to-use-meshy-image-to-3d | "Updated over 2 weeks ago" | [help] |
| S17 | docs.meshy.ai/en (docs home: modules, model table, formats) | undated | [doc] |
| S18 | docs.meshy.ai/en/webapp/guides/3d-model/remesh | undated | [doc] webapp |
| S19 | docs.meshy.ai/en/webapp/guides/use-cases/game-assets | undated | [doc] webapp |
| S20 | docs.meshy.ai/en/webapp/guides/choosing/post-processing | undated | [doc] webapp |
| S21 | help.meshy.ai/en/articles/16100257-meshy-to-blender-cleanup-workflow | "Updated this week" | [help] |
| S22 | help.meshy.ai/en/articles/15723950-how-to-make-meshy-models-game-ready | "Updated over 3 weeks ago" | [help] |
| S23 | docs.meshy.ai/en/webapp/guides/3d-model/ai-texturing | undated | [doc] webapp |
| S24 | docs.meshy.ai/en/webapp/guides/platform/export-formats | undated | [doc] webapp |
| S25 | intercom.help/meshy/en/articles/16497761-why-can-t-i-view-my-api-generated-assets-in-workspace | "Updated over 2 weeks ago" | [help] |
| S26 | help.meshy.ai/en/articles/9992036-why-do-i-consistently-encounter-errors-when-retrieving-the-models-from-generation-result-using-api | "Updated this week" | [help] |
| S27 | raw.githubusercontent.com/meshy-dev/meshy-mcp-server/main/src/tools/workspace.ts | undated | [oss] official MCP server |
| S28 | raw.githubusercontent.com/meshy-dev/meshy-3d-agent/main/skills/meshy-3d-generation/reference.md | undated | [oss] official skill pack (stale — see §8) |
| S29 | docs.meshy.ai/api/retexture.md | undated | [doc] API |
| S30 | docs.meshy.ai/api/convert.md | undated | [doc] API |
| S31 | docs.meshy.ai/api/resize.md | undated | [doc] API |
| S32 | docs.meshy.ai/api/text-to-image.md | undated | [doc] API |
| S33 | docs.meshy.ai/api/ai.md (MCP tool list) | undated | [doc] |
| S34 | help.meshy.ai/en/articles/16102795-how-to-create-seamless-pbr-textures-with-meshy | "Updated over a week ago" | [help] |
| S35 | docs.meshy.ai/en/webapp/concepts | undated | [doc] webapp |
| S36 | docs.meshy.ai/en/webapp/guides/scene-video/scene-compose | undated | [doc] webapp |
| S37 | www.meshy.ai/tutorials/3d-game-environment-props | "2026 guide", no absolute date | [vendor-blog] |
| S38 | www.meshy.ai/tutorials/make-low-poly-3d-models | "2026", no absolute date | [vendor-blog] |
| S39 | docs.meshy.ai/en/webapp/guides/image/ai-image-generation | undated | [doc] webapp |
| S40 | docs.meshy.ai/en/webapp/guides/choosing/generation-method | undated | [doc] webapp |
| S41 | docs.meshy.ai/llms.txt | machine index, "regenerated every time the docs site builds" | [doc] index |
| S42 | docs.meshy.ai/en/api/changelog (dated entries cited inline) | entries dated 2026 | [doc] changelog |
| S43 | help.meshy.ai/en/articles/15898622-how-does-auto-split-work-in-meshy | no absolute date | [help] |
| S44 | docs.meshy.ai/en/blender-plugin/bridge-to-blender | undated | [doc] plugin |

---

## 1. Model versions / tiers available for image-to-3D, and what to pick for props

**Three generation "model types" exist on Image to 3D, selected by `model_type` in the API**
[S1]:

- `standard` (default) — "Regular high-detail 3D mesh generation."
- `smart-topology` — "Choose a Smart Topology model with `ai_model` (`meshy-t2`)"; the current
  low-poly pipeline. `model_type: lowpoly` is **deprecated** ("We recommend using
  `smart-topology` instead" [S1]).

**`ai_model` values map to those types** [S1]:

- `standard` → `meshy-6-lite`, `meshy-6`, `meshy-7`, `latest` (**`latest` = Meshy 7**).
  `meshy-5` is deprecated ("superseded by `meshy-6-lite`, which takes the same parameters and
  costs the same").
- `smart-topology` → `meshy-t2` (default): "the Smart Topology model — cleaner topology,
  natively separated parts, triangle output, and a face count you can set with
  `target_polycount`."

**Meshy 7 is the flagship.** Docs home: "Image to 3D runs on Meshy 7, our latest foundation
model" and the model table lists Meshy 7 (2026, "Most detail, highest precision"), Meshy 6
(2025), Smart Topology (2026, "Optimized for game development and real-time rendering",
~10 sec generation) [S17]. Meshy 7 "launched August 2026"; Meshy 6 "released January 2026"
[S13]. The API changelog adds the detail that Smart Topology shipped 2026-07-13 with two
models: `meshy-t1` ("the current low-poly model") and `meshy-t2` ("cleaner topology, natively
separated parts, triangle output, and a face count you can set"), `meshy-t2` being the default
under `smart-topology` [S42]. `meshy-4` is retired (requests return 400) [S28, S42 — retired
2026-03-20 per S42].

**GUI surface** [S13, S16]: the Image to 3D panel's Model Type offers **Standard** (high-poly,
fine detail) and **Smart Topology** (clean, low poly, game/real-time); the Model Version
dropdown offers **Meshy 7 / Meshy 6 / Meshy 6 lite** [S16]. Standard is for printing/cinematic
renders/sculpt bases; "If you're unsure, start with Smart Topology — it's easier to add detail
later than to clean up a dense mesh." [S16]

**What to pick for stylized low-poly arena props: `smart-topology` / `meshy-t2`.** Reasons,
each sourced: it is the game-dev-oriented pipeline [S16, S17]; it outputs triangles directly at
a face count you set, with natively separated parts (useful for re-materialing one piece, e.g.
a lantern's frame vs its glass) [S1, S16]; ~10 seconds per mesh makes iteration cheap [S16,
S17]; and it avoids the "dense mesh" cleanup cost that Standard incurs (a Standard prop came
back "just over 300,000 triangles" in Meshy's own env-prop walkthrough [S37]).

`[inference]` Standard + Remesh is the fallback when a prop needs surface detail Smart Topology
can't hold (e.g. ornate carving) — but for a stylized low-poly padel arena, Smart Topology is
the default path, and Remesh (free in the GUI, [S38]) covers overshoot.

---

## 2. API endpoints that matter

Base URL `https://api.meshy.ai/openapi/`, Bearer auth `Authorization: Bearer msy_…`; API keys
from meshy.ai/settings/api [S41]. All generation is **asynchronous**: POST returns a task id,
and you poll `GET …/:id`, use SSE `GET …/:id/stream`, or register a webhook [S41].

### 2.1 Image to 3D
- `POST /openapi/v1/image-to-3d` — body: `image_url` (public URL or base64 data URI;
  `.jpg/.jpeg/.png`) **or** `input_task_id` (a SUCCEEDED Text-to-Image / Image-to-Image API task
  producing exactly one image) [S1].
- `GET /openapi/v1/image-to-3d/:id` — task object incl. `model_urls`, `texture_urls`,
  `status`, `progress`, `expires_at`, `consumed_credits` [S1].
- `GET /openapi/v1/image-to-3d` — **List Image to 3D Tasks**; `page_num` (default 1),
  `page_size` (default 10, **max 100**), `sort_by` (`+created_at` / `-created_at`) [S1].
- `DELETE /openapi/v1/image-to-3d/:id`; `GET /openapi/v1/image-to-3d/:id/stream` (SSE) [S1].

### 2.2 Multi-Image to 3D
- `POST /openapi/v1/multi-image-to-3d` — body: `image_urls` (**1 to 4 images**, same object
  from different angles) or `input_task_id`; "For `meshy-7` (or `latest`), the first image is
  used as the primary (front) view. The order of the remaining images doesn't matter." [S2]
- `image_urls` must contain between 1 and 4 images (400 otherwise) [S2].
- `ai_model`: `meshy-5`, `meshy-6`, `meshy-7`, `latest` — **there is no `model_type`
  parameter on this endpoint at all**, so no Smart Topology and no `target_polycount`-at-
  generation; reduce polycount afterwards with Remesh [S2, and explicitly stated in S28].
- `GET` retrieve / `GET` list (`page_size` max 50 here [S3-style; S2 list section]) / `DELETE`
  / `/stream` [S2].
- `texture_image_urls` (1–4 view images to guide TEXTURING only) is `meshy-7`/`latest`-only and
  cannot be combined with `texture_image_url` or `texture_prompt` [S2].

### 2.3 Remesh (post-processing polycount/format)
- `POST /openapi/v1/remesh` — `input_task_id` (a SUCCEEDED Text to 3D, Image to 3D or Retexture
  task) **or** `model_url` (public URL/data URI; `.glb/.gltf/.obj/.fbx/.stl`) [S3].
- Params that matter: `topology` (`quad`/`triangle`), `target_polycount` (**100–300,000**,
  default 30,000), `decimation_mode` (1–4 adaptive; **overrides `target_polycount`**),
  `target_formats` (default `["glb"]`; also `fbx`, `obj`, `usdz`, `blend`, `stl`, `3mf`),
  `save_pre_remeshed_model`-style pre/post backups are handled at generation time [S3].
- `resize_height`, `resize_longest_side`, `auto_size`, `origin_at`, `convert_format_only` on
  Remesh are **deprecated** in favour of the standalone **Convert API (1 credit)** and
  **Resize API (1 credit)**, which accept any `model_url` [S3, S30, S31].
- `GET /openapi/v1/remesh/:id`, `GET /openapi/v1/remesh` (list, `page_size` max **50**),
  `DELETE`, `/stream` [S3].

### 2.4 Download URLs, signed expiry, and how to re-fetch
- `model_urls` keys: `glb`, `fbx`, `obj`, `usdz`, `stl`, `pre_remeshed_glb` (present only if
  that format/backup was generated; "The property for a format will be omitted if the format is
  not generated instead of returning an empty string") [S1, S3]. Remesh additionally returns
  `blend` [S3].
- Each format is "a signed, time-limited URL" [S5]. **The URL signature TTL itself is not
  documented** — no page states an hours/days figure. The documented outer bound is asset
  retention: "any models generated through our API will only be retained for a maximum of
  **3 days**" for non-Enterprise [S7]; "Tasks and their outputs — model files, preview images,
  and textures — are retained for 3 days from the time the task completes. After this window,
  the task and all associated download URLs will no longer be accessible." [S9] Every task
  response carries `expires_at` ("Timestamp of when the task result expires, in milliseconds")
  [S1, S9].
- **Re-fetch path:** while the task still exists, `GET` the task by id again — the response
  contains freshly signed `model_urls`/`texture_urls`. After `expires_at` passes, the task and
  its URLs 404 permanently: "You will need to re-submit the generation task." [S9] There is no
  documented "refresh signature" endpoint. Practical rule `[inference]`: persist **task ids**
  (not URLs) and re-GET to mint URLs at pull time; download immediately on `SUCCEEDED`.
- Failure-mode note: retrieving URLs before `status` is terminal is the top reported API error
  ("ensure that you verify the task status progress has reached 100% in your code before
  retrieving the model") [S26], and format entries can legitimately be missing — check the key
  exists before downloading [S41].
- **API-generated assets do NOT appear in the Workspace, by design** — "The Workspace only
  displays assets generated through Meshy's Workspace interface… API and Workspace have
  separate asset lifecycles" [S25, S9]. This is the single most consequential fact for the
  owner's plan (§7, gotcha G1).
- Close-to-workspace alternatives for GUI-generated models: manual Download in the GUI, or the
  **DCC Bridge / Meshy for Blender plugin** (Pro and above), which transfers models from the
  Workspace into Blender in one click (`POST` to `localhost:5324`; supports GLB and GLB-in-ZIP)
  [S44].

### 2.5 Other endpoints worth knowing
- `POST /openapi/v1/retexture` — re-texture any GLB/GLTF/OBJ/FBX/STL via `text_style_prompt`,
  `image_style_url` or `multiview_image_urls` (the latter `meshy-7` only); `enable_original_uv`
  preserves Meshy-generated UVs; `enable_pbr`, `texture_resolution`, `remove_lighting` [S29].
- `POST /openapi/v1/text-to-image` — 2D images from text (`nano-banana` 3cr, `nano-banana-2`
  6cr, `nano-banana-pro` 9cr, `gpt-image-2` 9cr), `aspect_ratio` 1:1…16:9, optional
  `generate_multi_view`, optional `remove_background` (RGBA PNG) [S32]. This is the API path to
  make prop references without leaving the API (then chain via `input_task_id` [S1]).
- `GET /openapi/v1/balance` [S41]; `GET /openapi/v1/uv-unwrap`-family: UV Unwrap API = 5
  credits, max 40,000 faces [S42].

---

## 3. Parameters that matter for props

### Polycount
- **Smart Topology path (`meshy-t2`)**: `target_polycount` "100 to 15,000, default 4,000. The
  model is generated directly at this face count; no remesh runs" [S1]. GUI wording: "set a
  target anywhere from 100 to 15,000 polygons" [S11], and the GUI exposes a "Poly Count slider"
  [S38].
- **Remesh path (standard generation + remesh)**: `target_polycount` **100 to 300,000, default
  30,000**; "The actual count may deviate from the target depending on the geometry" [S1, S3].
  GUI presets: 3K, 10K, 30K, 100K, or a custom slider 100–300k [S38].
- **Budget guidance** (for choosing the number): Meshy's game-ready help page — "PC / console
  environment prop: 500–5,000 tris" [S22]; the game-assets doc table — Prop: mobile casual
  500–2K, mobile AAA 2K–5K, PC/console 5K–15K; Environment piece: mobile casual 1K–5K,
  PC/console 10K–50K [S19]; Remesh detail-loss table — `<5K` = "Mobile AR, casual games —
  noticeable" detail loss, `5K–20K` = "mobile games, web viewers — minor" [S18].
- `decimation_mode` (1=ultra … 4=low) is the "adaptive" alternative; when set,
  `target_polycount` is ignored [S1].

### Topology
- `topology: quad` = "quad-dominant mesh"; `triangle` (default) = "decimated triangle mesh"
  [S1]. Docs guidance: "Pick Quad if you plan to edit or rig the model later, Triangle for
  direct use in engines or printing." [S38] For static props → `triangle`.
- Smart Topology **ignores** `topology`, `should_remesh` and `save_pre_remeshed_model`, and is
  documented as "triangle output" [S1].
- Smart Topology also yields "Native part segmentation: the model comes split into clean,
  accurate parts" [S11] — the GUI analog of this is Auto Split, which is 3D-printing-only
  (Standard + untextured, Meshy 6/7, 10 credits, unavailable for low-poly) [S43].

### Symmetry
- `symmetry_mode` (`off`/`auto`/`on`) is **deprecated and "no longer affects output"**
  (deprecated 2026-05-11 per changelog) [S1, S42]. Do not build any expectation of symmetric
  props on this parameter. `[inference]` For symmetric architecture (temple gates, arches),
  enforce symmetry in Godot/Blender or generate the mirrored half once, not via Meshy.

### Texture / PBR
- `should_texture` (default true) — "Setting it to `false` skips the texture phase, providing a
  mesh without textures" [S1].
- `enable_pbr` (default false) — metallic/roughness/normal in addition to base color; an
  emission map is ALSO included when `ai_model: meshy-6` (except at 8k). "`meshy-5`,
  `meshy-6-lite`, `meshy-7` and `latest` do not produce an emission map." [S1]
- `texture_resolution`: `2k` (2048², default), `4k`, `8k`; "`4k` and `8k` are not available with
  `ai_model` `meshy-5` or `meshy-6-lite`" [S1]. 8K = 15 credits vs 10 for 2K/4K [S4, S42].
- `remove_lighting` (default true) — "Removes highlights and shadows from the base color
  texture, producing a cleaner result that works better under custom lighting setups" — and
  note the source conflict: S1 scopes it to `meshy-6` only, while S2 scopes the same parameter
  to `meshy-6`, `meshy-7` or `latest`. Verify empirically per endpoint.
- `texture_prompt` (≤800 chars on image-to-3d; ≤600 on multi-image) / `texture_image_url`;
  if both are given, `texture_prompt` wins [S1, S2].
- `image_enhancement` (default true) — AI preprocessing of the INPUT image; set false to
  "preserve the exact appearance of the input image without any style processing" [S1].

### `should_remesh`
- Default **false for `meshy-6`/`meshy-7`, true for others** [S1]. Docs: "For the highest-quality
  model, we recommend setting `should_remesh` to `false`." [S1] When true, the mesh is remeshed
  (decimated) to `target_polycount`; `save_pre_remeshed_model: true` also stores the pre-remesh
  GLB (`model_urls.pre_remeshed_glb`) [S1]. `[inference]` For props: prefer Smart Topology
  (no remesh at all) or `should_remesh: true` + explicit `target_polycount` when you need a
  hard budget.

### `target_formats`
- "Only the requested formats will be generated and returned, which can reduce task completion
  time. When omitted, all formats except `3mf` are generated." Values `glb`, `obj`, `fbx`,
  `stl`, `usdz`, `3mf`; 3MF is opt-in only [S1, S28]. For our pipeline: `["glb"]` (GLB embeds
  textures; FBX/OBJ keep textures as separate files) [S24].

### Pose / rig — AVOID for props
- `pose_mode`: `a-pose`, `t-pose`, or `""` (default). `is_a_t_pose` is deprecated in its favour
  [S1, S42]. The GUI help is explicit: "Enable Pose only for humanoid or character models — it
  has no effect on objects, vehicles, or non-character subjects." [S16] → leave Pose at Default
  for every prop.
- Rigging API is humanoid-only, requires a textured mesh, and errors at >300,000 faces; it is
  irrelevant to props [S28, S42]. The GUI warning equivalents (Custom Pose, "humanoid models")
  are the same story [S11, S16].
- Also avoid `auto_size`/`origin_at` unless you actually want AI-estimated real-world scale
  [S1, S31]; and skip the 3D-printing-only tools (Auto Split, Multi-Color Print) [S43].

---

## 4. Credits per task type / version

Two pricing surfaces exist and they disagree — see §8 C1. The API-side numbers:

**API pricing page [S4] — "Image to 3D":**

| Model (`ai_model`/type) | no texture | + texture (2K/4K) | + 8K texture |
|---|---|---|---|
| `meshy-6` | 20 | 30 | 35 |
| `meshy-7` (`latest`) | 20 | 30 | 35 (+5 with `ultra_mode`) |
| `lowpoly` (Meshy T1, deprecated) | 20 | 30 | 35 |
| **Smart Topology (`meshy-t2`)** | **5** | **15** | **20** |
| other models | 5 | 15 | — |

**Multi Image to 3D [S4]:** Meshy-6 and Meshy-7: 20 / 30 / 35 (no-tex / tex / 8K); other
models: 5 / 15.

**Other task types that matter to us [S4, S8]:** Text to 3D Preview 20 (Meshy-6), 20 (+5
Ultra for Meshy-7), 5 (Smart Topology T2), 5 (other); Text to 3D Refine / texture generation
10 (2K/4K), 15 (8K); **Retexture 10 (2K/4K) / 15 (8K)**; **Remesh 5**; **Convert 1**;
**Resize 1**; UV Unwrap 5 [S42]; Auto-Rigging 5; Animation 3; Text to Image 3/6/9/9;
Image to Image 3/6/9/12.

**Billing semantics** [S8, S42]: "Costs are the same across all paid plans and are charged when
a task is successfully submitted"; failed tasks are refunded — `consumed_credits` "Returns `0`
for `FAILED` tasks (credits are refunded on failure)" [S1]; each GET response carries
`consumed_credits`, which is the authoritative per-task number to log [S42, S28].

**Rate limits** (Pro/Studio/Enterprise) [S41]: 20/20/100 requests per second; queue 10/20/50+.
Exceeding → 429.

**Licensing** [S10]: Free = CC BY 4.0 (attribution required), Pro and above = Private, full
commercial use, user owns output. (Relevant because arena props ship in a commercial game.)

---

## 5. Input image requirements (and what breaks thin/openwork geometry)

### Hard requirements
- Formats: API accepts **`.jpg`, `.jpeg`, `.png`** only (public URL or base64 data URI) [S1].
  The GUI additionally takes `.webp`, max **20 MB** [S16].
- No pixel floor is enforced, but the documented recommendation is: "**at least 512 × 512 px;
  1024 × 1024 px or higher is ideal**" [S12]; the webapp doc repeats "resolution ≥ 512×512"
  [S11]. "Generation ignores image details → cause: Image resolution too low" [S11].
- Matched reference requirement for data URIs; unreachable URLs return 400 "Unreachable URL"
  [S1]. Max 1 image on `/image-to-3d`, 1–4 on `/multi-image-to-3d` [S1, S2].

### Background
- "Use a plain white or transparent background for the cleanest object isolation… Avoid
  reflective or gradient backgrounds — they can bleed into the model's texture" [S12]. "For
  complex backgrounds, use AI Background Removal first" [S11]. Reference-image generation
  should therefore bake in "white background, even lighting, front view" [S12, S39].

### Subject framing
- "Frame the object so it fills most of the image" / recommended **subject fill 70–90% of
  frame** [S12]. "No part of the object should touch or extend beyond the image boundary"
  [S12]. "Use a front-facing or slightly angled view… Avoid extreme top-down or bottom-up
  angles — these limit the model's ability to infer depth" [S12]. "Model proportions distorted
  → severe perspective distortion… use photos with near-orthographic projection or telephoto
  lens" [S11]. Even, diffused lighting; "shadows bake into the texture" [S12].

### How many views
- API: 1–4 images on `/multi-image-to-3d`; "All images should depict the same object from
  different angles" [S2].
- GUI: multi-view is documented as "Multiple (2–8)" in one place [S11] and "2 to 8 angles" in
  another [S38], while S16 says "Multi-View is currently only supported on Meshy 7". The
  practical angle set is consistent everywhere: "Front view / Side view (left or right) / Back
  view / Top view (optional)" [S15], "Front + Side + Back + 3/4 view" [S11], and "for the
  clearest asymmetric reconstruction, upload a front, a true 90° side, and a back view — with
  backgrounds removed from all three" [S16]. Consistency rules: same lighting/scale/pose across
  views, all backgrounds removed, and views at least 45°–90° apart or the result comes out
  artificially symmetric [S15, S16].

### What breaks thin / openwork geometry (gates, fences, railings, foliage, lanterns)
This is the documented weak spot, in Meshy's own words:
- **`image_too_complex` error code** [S6] — "the input image or prompt describes a subject that
  is too geometrically complex for the 3D generation model to process. Common examples include:
  **intricate repeating patterns (e.g., lattice structures, scaffolding, wire meshes)**; dense
  piles of small objects; complex building structures (e.g., multi-story buildings with many
  windows and balconies); multiple distinct objects in one image." Resolution list: single
  object per image; simplify; **avoid scene-level prompts** ("Entire buildings, city blocks,
  interiors filled with furniture, or landscapes are likely to exceed the model's capacity");
  avoid dense repeating structures.
- **Thin features under-reconstruct**: "Fine details like hair strands or **thin wires** may not
  fully reconstruct" [S12]; "thin features like hair strands, jewellery chains, or intricate
  surface patterns are difficult to reconstruct accurately in 3D from a single image" [S16].
- **Transparent/reflective fails**: "Highly transparent or reflective objects (glass, mirrors)
  are difficult to reconstruct — use opaque references instead" [S12] — relevant to lantern
  glass and any window/gate panels.
- **Decimation eats small parts**: Remesh troubleshooting — "Small accessories disappear →
  Uneven face budget distribution → **Remesh complex models part by part**"; "Holes after
  remeshing → original mesh has non-manifold edges → try a higher face count, or repair the
  original mesh first" [S18].
- **Post-export repair path** (documented workarounds) [S21, S22]: Blender Decimate (Collapse)
  to cut polycount with silhouette preserved; Voxel Remesh first if topology is uneven; then
  "Object > Apply > All Transforms" and origin-to-geometry before re-export; for floating
  geometry/holes, "Merge by Distance" + "Fill Holes"; and a warning that decimating/remeshing
  "can distort UVs and cause visible texture seams — re-unwrap if needed".
- **The only documented "thicken thin surfaces" control is printing-only**: Auto Split's
  "Avoid Thin Walls" toggle thickens thin surfaces, but Auto Split works only on Standard,
  untextured (draft) Meshy 6/7 models, costs 10 credits, and is explicitly "not available for
  Low Poly or other model types" [S43].

**Workarounds synthesis for our arena props** `[inference]`, built from the above:
1. Design the prop's reference image with **stylized thick members** (chunky gate posts, deep
   fence rails, wide lantern frame bars) — this is an input-image problem first, per Meshy's
   own "fix the input images before touching any other setting" [S37].
2. **Split openwork into several simple props** within the 10-model-per-arena budget rather
   than one fence panel with 40 pickets — each generated model should read as ONE closed
   silhouette [S11, S12].
3. **Do the fine lattice in-engine** (Godot quads/alpha cards/instanced picket meshes), not in
   Meshy — Meshy has no documented alpha-card or thin-lattice output.
4. If a small part vanishes after Remesh, **remesh part by part** [S18] or raise the target.
5. Expect the back of a single-image prop to be hallucinated; multi-view (front/90° side/back)
   is the documented fix [S12, S16].

---

## 6. Raw textures and skyboxes/panoramas

### Raw textures: YES
- The task object exposes `texture_urls[]` with **downloadable PNG maps**: `base_color`,
  `metallic`, `normal`, `roughness`, and (only when `enable_pbr: true` and only on `meshy-6`)
  `emission`; the PBR keys are omitted entirely when `enable_pbr` is false [S1]. These are
  separate files you can reuse in Godot/Blender on other models — "once exported, PBR texture
  maps can be applied to other models in your external 3D tool" [S34].
- You can also texture meshes that Meshy did not generate ("upload external meshes (OBJ, FBX,
  GLB, up to 50MB)") via AI Texturing in the GUI [S23], or via the **Retexture API** with a
  text prompt, an image, or 1–4 view images [S29].
- Tileable/seamless textures are achievable but prompt-driven, not a mode: "describe the
  material itself rather than an object — for example, 'rough brushed aluminum' or 'cracked
  terracotta tile' — and avoid prompts that describe a single centered object" [S34].
- There is no texture-only endpoint (Text to Texture was renamed to Retexture and requires a
  model input) [S29, S28].

### Skyboxes / panoramas: NOT DOCUMENTED — treat as unavailable
Evidence of absence across the current product surface (retrieved 2026-09-18):
- The machine-readable API index lists every endpoint; there is **no** environment/skybox/
  panorama/HDRI endpoint (generation, post-processing, and image sections) [S41].
- The workspace is documented as "six modules: Image, 3D Model, 3D Printing, Animate, Scene,
  and Video" [S17]. Scene Compose is drag-and-drop arrangement of 3D **models** ("Ideal for
  game level prototypes, architecture visualization"); Video generates rendered videos from
  scenes/models. Neither produces a 360° environment map [S36].
- Export formats are model formats only (GLB/FBX/OBJ/STL/USDZ/3MF) [S17, S24].
- The 2D image APIs produce perspective images: `aspect_ratio` up to 16:9, optional
  `generate_multi_view` (a multi-angle sheet of one subject, for 3D input) and optional
  `remove_background`; no equirectangular/360 option [S32]. The UI presets are "Realistic,
  Anime, Chibi" style presets for 3D-ready images [S39].
- The only Meshy page that mentions environment images is a glossary definition of image-based
  lighting (IBL), which explains equirectangular/cube-map HDR maps as a rendering INPUT concept
  ("uses HDR environment images to light 3D scenes") and is not a generation feature:
  www.meshy.ai/3d-glossary/image-based-lighting — undated concept page, fetched 2026-09-18.
`[inference]` → If arenas need skyboxes, they must come from elsewhere (Godot `PanoramaSky`,
our own procedural gradient skies, or a pano-capable image model), not from Meshy. Keep this as
a re-check item: absence of documentation is not proof of absence, but nothing in the current
docs contradicts it.

---

## 7. Recommended Meshy config for low-poly stylized arena props

### 7a. What the owner clicks in the GUI (per prop, ~10 per arena)
| Setting | Value | Why (source) |
|---|---|---|
| Module | 3D Model → Image to 3D | [S11] |
| Input image | 1 clean ref (front or slight 3/4), white/transparent bg, subject 70–90% of frame, ≥1024² | [S12] |
| Multi-view | On only if the back matters: front + true 90° side + back, same lighting/scale, all bg-removed | [S15, S16] |
| Model Type | **Smart Topology** | game/real-time pipeline [S16, S17] |
| Poly Count | **~1,000–3,000** faces for small props; up to ~4,000 for large set pieces | inside 100–15,000 range [S11]; prop budgets 500–5,000 [S22] |
| Pose | Default (never A/T pose) | character-only, "no effect on objects" [S16] |
| Image Enhancement | On (off only for pristine refs) | [S12, S16] |
| Auto Split | Off | printing-only [S43] |
| Texture | AI Texturing on, **PBR maps on**, **2K**, Remove Lighting ON | [S11, S23, S24] |
| If polycount overshoots | Remesh (free in GUI) **before** texturing | [S18, S38] |
| Export | **GLB** (embedded textures) | [S24] |

### 7b. What we call in the API later
```json
POST https://api.meshy.ai/openapi/v1/image-to-3d
{
  "image_url": "<public url or data URI of the approved reference>",
  "model_type": "smart-topology",
  "ai_model": "meshy-t2",
  "target_polycount": 2000,
  "should_texture": true,
  "enable_pbr": true,
  "texture_resolution": "2k",
  "target_formats": ["glb"],
  "image_enhancement": true
}
```
Then: poll `GET /openapi/v1/image-to-3d/{id}` (5 s interval, break on terminal status), read
`model_urls.glb`, download immediately, log `consumed_credits`, store the task id. Keep
`pose_mode` out, keep `auto_size` out, never request FORMATS you don't need (extra formats add
time) [S1, S28, S41]. For props with real back detail, switch the endpoint to
`/openapi/v1/multi-image-to-3d` (1–4 images) and add a Remesh follow-up to hit the budget,
because multi-image has no Smart Topology [S2, S28].

Cost expectation per prop: **15 credits** (Smart Topology T2 + 2K/4K texture) per the API
pricing page [S4] — but see C1; the help-center table says 20. Verify per task via
`consumed_credits` [S1, S42].

---

## 8. Contradictions and uncertainty (recorded, not smoothed over)

- **C1 — Credit tables disagree.** API pricing page: Smart Topology T2 = 5 (no texture) / 15
  (2K–4K) / 20 (8K) [S4]. Help-center credits article (same week): Smart Topology T2 = 15 (no
  texture) / 20 (2K–4K) [S8]. Also the webapp pricing table shows "Image to 3D 20 (Meshy 6) /
  10 (Meshy 5)" and "Remesh 0" [S10], while API Remesh is 5 credits [S4]. The webapp table also
  has no column for `smart-topology` at all. Resolution path: the per-task `consumed_credits`
  field is authoritative [S1, S42] — measure, don't trust the tables. `[inference]` The webapp
  table is the stalest of the three.
- **C2 — GUI Remesh is free, API Remesh is not.** GUI docs/marketing: "Remesh … costs no
  credits" [S38], webapp pricing table lists Remesh 0 [S10]; API pricing lists Remesh 5 credits
  [S4]. Both can be true (different cost planes), but any automation over the API pays.
- **C3 — `remove_lighting` model support differs per page.** S1: "Only supported when
  `ai_model` is `meshy-6`"; S2 (multi-image): "`meshy-6`, `meshy-7` or `latest`".
- **C4 — Multi-view counts and model gating differ.** GUI: 2–8 images [S11, S38] and
  "currently only supported on Meshy 7" [S16]; API: 1–4 images [S2] and accepts `meshy-5`,
  `meshy-6`, `meshy-7` [S2]. The GUI doc's "Model Version: Meshy 6 / Meshy 5" table [S11] is
  also stale against the docs home and help article listing Meshy 7 [S17, S16].
- **C5 — The official OSS tooling lags the docs.** The Meshy-authored `meshy-3d-agent`
  reference still says "`latest` always resolves to the newest model (currently Meshy 6)", makes
  `meshy-t1` sound like the default, and lists pre-June prices [S28]; live docs say `latest` =
  Meshy 7 and `meshy-t2` is the `smart-topology` default [S1, S42]. Agents that read that repo
  will produce stale configs — prefer docs.meshy.ai/en/api at call time.
- **C6 — The MCP "list workspace models" tool is mislabelled.**
  `docs.meshy.ai/api/ai.md` describes `meshy_list_models` as "list all models in the
  authenticated user's workspace" [S33], but the server source calls
  `client.get("/openapi/v2/text-to-3d", {status: SUCCEEDED, …})` — i.e. it lists API
  text-to-3d tasks, not GUI workspace models [S27]. Combined with S25 ("API and Workspace have
  separate asset lifecycles"), `[inference]` there is **no documented REST endpoint that
  enumerates GUI-generated models**; the GUI → disk paths are manual Download or the Blender
  DCC Bridge (Pro+) [S44]. **This is the load-bearing risk for the owner's plan (see G1).**
- **Uncertainty — signed-URL TTL.** Docs say "signed, time-limited" [S5] but never state the
  lifetime; the examples in the API reference are visibly synthetic (`expires_at` = `created_at`
  + 28 s in every sample) [S1, S2]. The only trustworthy bound is the 3-day retention window
  [S7, S9] plus the `expires_at` field per task. Treat URLs as valid for minutes-to-hours and
  re-GET before each pull.

### Three concrete gotchas
1. **G1 — GUI-generated models are not reachable by the API.** The API cannot enumerate or
   download Workspace assets [S25]; the MCP tool that claims otherwise reads API tasks [S27];
   and the API list endpoints return API tasks [S1]. Consequence: if the owner generates his 50
   props in the GUI, the "automatic pull" is not possible — his options are manual GUI download,
   the Blender Bridge (Pro+) [S44], or re-issuing the same reference images through
   `/openapi/v1/image-to-3d` (re-paying credits). Decide this before he starts clicking;
   the cheapest split is: he designs references, we submit them via API.
2. **G2 — Everything API-side dies after 3 days, and the URLs are signed.**
   Non-Enterprise API assets are deleted 3 days after completion, URLs incl.; after that only a
   fresh generation works [S7, S9]. Never commit `assets.meshy.ai/...?Expires=…` URLs into the
   repo — store task ids and re-GET.
3. **G3 — Thin/openwork props fail by generation, not by tuning.** Lattice/scaffolding/wire
   meshes and multi-object scenes are named `image_too_complex` triggers [S6]; thin wires
   under-reconstruct [S12, S16]; and Remesh can delete small parts or open holes [S18]. A fence,
   gate grille or lantern cage must be re-designed as chunky closed members, split into several
   simple props, or hand-built in Godot — not fixed by parameter tuning after the fact.
   (Bonus, same family: marking Remesh after texturing breaks UV alignment [S38].)
