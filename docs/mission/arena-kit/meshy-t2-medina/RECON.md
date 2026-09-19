# RECON — Meshy API for Medina Mesh T2 pack

Date: 2026-09-18 · Captain: Scout · Read-only (no POSTs, no generation, no keys read or printed)
Gate 1 evidence for `docs/mission/arena-kit/meshy-t2-medina/CHARTER.md`

Method: every claim below was fetched live today (web_extract) from docs.meshy.ai / help.meshy.ai,
cross-checked against the machine-readable contract `https://docs.meshy.ai/openapi.json`
(openapi 3.1.0, `servers[0].url = https://api.meshy.ai/openapi`), plus three unauthenticated
GET probes of the live API (route existence only; no key sent, nothing created).
Companion in-repo notes: `../scan/meshy-props.md` (S-numbers below refer to that doc's source table)
and `tools/arena-kit/pull_meshy.py`.

## Evidence fetched today (all undated pages fetched 2026-09-18)

| # | URL | Type |
|---|-----|------|
| R1 | https://docs.meshy.ai/api/image-to-3d.md (md mirror of /en/api/image-to-3d) | [doc] |
| R2 | https://docs.meshy.ai/en/api/image-to-3d (HTML build) | [doc] |
| R3 | https://docs.meshy.ai/llms.txt | [doc] index |
| R4 | https://docs.meshy.ai/openapi.json | [doc] machine contract |
| R5 | https://docs.meshy.ai/api/pricing.md | [doc] |
| R6 | https://docs.meshy.ai/api/quick-start.md | [doc] |
| R7 | https://docs.meshy.ai/api/authentication.md | [doc] |
| R8 | https://docs.meshy.ai/api/multi-image-to-3d.md | [doc] |
| R9 | https://docs.meshy.ai/api/retexture.md | [doc] |
| R10 | https://docs.meshy.ai/api/remesh.md | [doc] |
| R11 | https://docs.meshy.ai/api/asset-retention.md | [doc] |
| R12 | https://docs.meshy.ai/api/changelog.md | [doc] |
| R13 | https://docs.meshy.ai/en/webapp/guides/3d-model/remesh | [doc] webapp |
| R14 | https://help.meshy.ai/en/articles/16815622-how-many-credits-does-each-meshy-api-task-cost ("Updated this week") | [help] |
| R15 | https://intercom.help/meshy/en/articles/16497761-why-can-t-i-view-my-api-generated-assets-in-workspace ("Updated over 2 weeks ago") | [help] |
| R16 | https://help.meshy.ai/en/articles/15723950-how-to-make-meshy-models-game-ready ("Updated over 3 weeks ago") | [help] |

Live probes (unauthenticated GETs, 2026-09-18):

```
401  GET https://api.meshy.ai/openapi/v1/image-to-3d/<zero-uuid>     -> route exists, auth required
401  GET https://api.meshy.ai/openapi/v2/text-to-3d/<zero-uuid>      -> route exists, auth required (control)
404  GET https://api.meshy.ai/openapi/v2/image-to-3d/<zero-uuid>     -> NO SUCH ROUTE
404  GET https://api.meshy.ai/openapi/v9/nonsense                    -> NO SUCH ROUTE (control)
401  GET https://api.meshy.ai/openapi/v1/balance                     -> route exists
```

---

## 1. Model id / `ai_model` value for Mesh T2

**Request value: `ai_model: "meshy-t2"`** — the official slug, always paired with
`model_type: "smart-topology"`. The user's "Mesh T2" is Meshy's marketing name
"Smart Topology (Meshy T2)"; no rename is needed.

Exact quotes:

- R1, `model_type`: "`smart-topology`: Choose a Smart Topology model with `ai_model` (`meshy-t1` or `meshy-t2`)."
  and under `ai_model`: "`meshy-t2` (default, recommended): the Smart Topology model — cleaner topology,
  natively separated parts, triangle output, and a face count you can set with `target_polycount`."
- R2 (HTML build, same page): "Choose a Smart Topology model with `ai_model` (`meshy-t2`)."
- R12 changelog, Sep 1 2026: "Removed `meshy-t1` from the documented `ai_model` values for the
  Image to 3D API's Smart Topology `model_type`. Smart Topology now only documents `meshy-t2`...
  if your integration currently sends `ai_model: \"meshy-t1\"`, migrate to `meshy-t2`."
- R4 machine contract, POST /v1/image-to-3d body: `ai_model` enum
  `["meshy-4","meshy-6","meshy-6-lite","meshy-7","latest","meshy-t2"]`, default `latest`, with
  description: "`meshy-t2` requires `model_type: smart-topology`. `meshy-7` requires account entitlement."

Send both fields. `model_type` alone is not enough (default ai_model under it is `latest` = Meshy 7);
`ai_model: meshy-t2` alone is invalid (400 risk — the contract says it *requires* `model_type: smart-topology`).

## 2. Smart Topology — field, values, range, topology, multi-image

- **Field: `model_type`** (string, default `standard`). Allowed values [R1, R4]:
  `standard` | `smart-topology` | `lowpoly` (deprecated — "We recommend using `smart-topology` instead").
  Not to be confused with `ai_model` (the model id) or `topology` (mesh output form, see below).
- **Polycount: `target_polycount`** — for Smart Topology: "Range 100 to 15,000, default 4,000.
  The model is generated directly at this face count; no remesh runs and `should_remesh` is not required" [R1].
  (The 100–300,000 range in R1/R4 is the *remesh* case; the 15,000 ceiling is the T2-specific one.)
- **Triangle only.** T2 is documented as "triangle output" [R1, R12], and the machine contract says
  on `topology`: "`quad` is not supported for meshy-t2." Quad is a remesh/standard concern only.
- **Ignored under smart-topology:** `topology`, `should_remesh`, `save_pre_remeshed_model` [R1].
  Also **not supported under smart-topology**, per the machine contract [R4]:
  `remove_lighting` ("Not supported under smart-topology"), `image_enhancement` ("Not supported under smart-topology").
  Do not send them expecting an effect (sending is harmless per the docs' null-typed fields; they just do nothing).
- **Not image-to-3D only.** Smart Topology also exists on Text to 3D — R12 changelog Aug 13 2026 adds
  `model_type: smart-topology` to the Text to 3D API, and R4 shows the same enum on POST /v2/text-to-3d.
  For this pack the relevant fact: it is on Image to 3D (single image) and Text to 3D, **not** on Multi-Image.
- **Does NOT combine with multi-image.** `POST /openapi/v1/multi-image-to-3d` has **no `model_type`
  parameter at all** in either the prose [R8] or the machine contract [R4]; its only `ai_model` enum is
  `["meshy-6","meshy-6-lite","meshy-7","latest"]`. Multi-view inputs therefore cannot use T2 —
  the scan's note (S2/S28) stands. Our pack is single-image per prop, which is exactly where T2 lives.

## 3. Texture + PBR — same create call, not a later step

**Texture and PBR are requested on the create call itself.** There is no separate "texture" call for an
image-to-3D job; the pipeline is one POST.

Same-call fields [R1, R4]:

| Field | Value for us | Exact doc language |
|---|---|---|
| `should_texture` | `true` (default is already `true`) | "Determines if textures are generated. Setting it to `false` skips the texture phase, providing a mesh without textures." |
| `enable_pbr` | `true` | "Generate PBR Maps (metallic, roughness, normal) in addition to the base color." Constraint: "`enable_pbr` is only supported when `should_texture` is true" (400 otherwise). |
| `texture_resolution` | `"2k"` | One of `2k` (2048×2048), `4k` (4096×4096), `8k` (8192×8192); default `2k`. |

Texture-later alternative (documented, but not our plan): the Retexture API
(`POST /openapi/v1/retexture`) with `input_task_id` or `model_url`, a style input
(`text_style_prompt` / `image_style_url` / `multiview_image_urls`, exactly one required),
plus `enable_pbr`, `texture_resolution`, `enable_original_uv` [R9]. Notes:
`multiview_image_urls` requires explicit `ai_model: "meshy-7"`; Retexture's `ai_model` enum is
`meshy-4/6/6-lite/7/latest` — **there is no T2 texturing model**, so a later texturing pass is never "T2".
Cost of that pass: 10 credits (2K/4K) per the pricing table [R5].

**Remesh-after-texture warning (docs say):** the workflow order is remesh → then texture.
R13 (Remesh guide, FAQ/related links): "When should I Remesh in my workflow? Remesh the final asset
**before** UV unwrapping, texturing, or rigging", "AI Texturing — Retexturing after Remesh produces
better results", "Unwrap UV — **UV needs to be regenerated after Remesh**". The in-repo scan already
records the sharper vendor line (S38): marking Remesh after texturing breaks UV alignment.
Practical rule for this pack: because T2 sets the face count **at generation**, no remesh should ever
be needed on a T2 prop — do not remesh a textured GLB; if a prop is off-budget, regenerate with a
different `target_polycount` instead.

## 4. Salvage paths

**a) Untextured API-generated model with a live task id → YES, texturable later.**
R9, `input_task_id`: "The ID of the completed Image to 3D or Text to 3D task you wish to retexture.
This task must be one of the following tasks: Text to 3D Preview, Text to 3D Refine, Image to 3D or
Remesh. In addition, it must have a status of `SUCCEEDED`." Set `enable_original_uv: true` to reuse
the mesh's Meshy-generated UVs [R9]. Cost 10 credits (2K/4K) [R5]. Caveat (untested, flag to pipeline
captain): no doc explicitly confirms Retexture on a task that was generated via Smart Topology; the
docs list "Image to 3D" tasks without excluding T2, but treat T2→retexture as unverified until tried.

**b) Model made in the GUI Workspace → NO, the API cannot see it.** Two independent facts:
- R15: "The Workspace only displays assets generated through Meshy's Workspace interface. If you
  generated assets via the API, they will not appear in the Workspace." (API ≠ Workspace lifecycles.)
- No API surface accepts a Workspace model id: the only model inputs anywhere in R4 are `input_task_id`
  (API tasks only — R1: "it must have been run via the API") and `model_url` (a public URL or base64
  data URI of a file). The task-id contract is enforced: an ID from the GUI is not an API task id.

**Manual escape hatch (outside the charter's spend plan):** download the untextured GLB from the
GUI by hand, then POST it as `model_url` (data URI, `application/octet-stream`) to `/openapi/v1/retexture`.
That is the only documented way to texture a GUI-made mesh via API. The charter already says to skip
salvage and go fresh if GUI models are unreachable — this recon confirms that expectation, so
**plan on 10 fresh T2 jobs, not on salvaging old ids**.

## 5. Credits per job (list-price vs measured)

Config priced: Image to 3D, `model_type: smart-topology`, `ai_model: meshy-t2`, `should_texture: true`,
`enable_pbr: true`, `texture_resolution: "2k"`.

**List price — the two official tables still disagree (same conflict the scan logged as C1):**

| Source | T2, no texture | T2 + texture 2K/4K | T2 + 8K |
|---|---|---|---|
| API pricing page R5, exact rows | "Smart Topology (Meshy T2) models: 5 credits (without texture)" | **15 credits (with texture)** | 20 credits (with 8K texture) |
| Help center R14 (updated this week) | 15 credits | **20 credits** | (cell garbled in fetch; the readable pair is 15/20) |

Quoting R5 verbatim: "Smart Topology (Meshy T2) models: 5 credits (without texture), 15 credits
(with texture), 20 credits (with 8K texture)". R14 lists "Smart Topology T2" under Image to 3D as
15 credits (no texture) / 20 credits (with texture 2K/4K). The two tables are irreconcilable on the
same page set; this recon does not pick a winner beyond noting both.

**Authority = per-task `consumed_credits`.** R1 task object: "The number of credits consumed by this
task. Present when the task status is `PENDING`, `IN_PROGRESS`, or `SUCCEEDED`.
Returns `0` for `FAILED` tasks (credits are refunded on failure)." R12 (Apr 27 2026) added the field
"across every API endpoint" precisely for cost tracking. So: **log `consumed_credits` per task in
LEDGER.jsonl and treat it as the measured number; the tables are list-price only.**

**Measured: none yet** — recon ran zero jobs (read-only). Expected spend per the charter budget:
10 jobs × 15–20 credits = 150–200 credits; abort threshold is 30 credits/job, and both readings sit
under it, so Gate 2 can proceed on price without a re-plan. Budget check available read-only:
`GET /openapi/v1/balance`.

## 6. Protocol — auth, base URL, endpoints, fields

- **Auth header:** `Authorization: Bearer msy_...` — "All requests require a Bearer token in the
  `Authorization` header" [R3]; "The `Bearer ` prefix in the header value is mandatory" [R7].
  Keys are minted at https://www.meshy.ai/settings/api and start with `msy_` [R3].
  (Key existence for this machine is the Inventory captain's check — `$MESHY_API_KEY` or
  `~/.config/meshy/api_key` per `pull_meshy.py`; this recon did not read either and never prints secrets.)
- **Base URL:** `https://api.meshy.ai/openapi/` [R3; R4 `servers[0].url = https://api.meshy.ai/openapi`].
- **Create:** `POST https://api.meshy.ai/openapi/v1/image-to-3d` → `{"result": "<task id>"}` [R1, R6].
  ("The `result` property of the response contains the task `id` of the newly created Image to 3D task.")
- **Poll:** `GET https://api.meshy.ai/openapi/v1/image-to-3d/:id` — loop until `status` is terminal:
  `PENDING` → `IN_PROGRESS` → `SUCCEEDED` | `FAILED` | `CANCELED` [R3, R6]. Reference loop polls every 5 s [R6].
- **Alternatives:** SSE `GET /openapi/v1/image-to-3d/:id/stream` (`Accept: text/event-stream`), webhooks [R3].
- **Download field names (GET task object) [R1]:**
  - `model_urls.glb` (also `fbx`, `obj`, `usdz`, `stl`, `mtl`, `3mf`, `pre_remeshed_glb` — a format key
    "will be omitted if the format is not generated instead of returning an empty string").
  - `texture_urls[0].base_color` / `.metallic` / `.normal` / `.roughness` (PBR keys omitted unless
    `enable_pbr: true`; no `emission` for T2 — the emission map is a `meshy-6`-only extra).
  - `thumbnail_url`, `status`, `progress`, `task_error.message`, `created_at` / `finished_at` /
    `expires_at` (epoch ms), `preceding_tasks`, `consumed_credits`.
- **Persist task ids, never signed URLs.** Each format URL is "a signed, time-limited URL" [R6];
  assets are retained **3 days** for non-Enterprise ("only be retained for a maximum of 3 days",
  R11), and each task carries `expires_at`. Re-GET the task by id to mint fresh URLs; after expiry the
  task 404s and "You will need to re-submit the generation task" (S9). So the ledger stores
  `task_id` + `consumed_credits`; the GLB is downloaded immediately on `SUCCEEDED` (do not retrieve
  URLs before `status` is terminal — top reported API failure mode, S26).

### ⚠ FLAG for the pipeline captain — `pull_meshy.py` points at a dead route

`tools/arena-kit/pull_meshy.py` line: `API_BASE = "https://api.meshy.ai/openapi/v2/image-to-3d"`.
The API's image-to-3D route is **v1**, not v2 (v2 is the *text*-to-3D version). Evidence: R4 lists
`/v1/image-to-3d` (get/post) and no v2 image path among all 51 documented paths; live probe today
returned **404 on `v2/image-to-3d`** while `v1/image-to-3d` returns 401 (auth-gated, exists) and
`v2/text-to-3d` returns 401 (control). The tool's live mode will fail until the base is corrected to
`/openapi/v1/image-to-3d`. (Recon wrote this file only — the fix is Gate-2 work.)

## 7. Recommended create JSON — one square PNG prop

Per prop slot (square intake PNG, origin bottom, no rig, matte, ~4000 faces):

```json
POST https://api.meshy.ai/openapi/v1/image-to-3d
{
  "image_url": "<public URL or data:image/png;base64,... of the slot's square PNG>",
  "model_type": "smart-topology",
  "ai_model": "meshy-t2",
  "target_polycount": 4000,
  "should_texture": true,
  "enable_pbr": true,
  "texture_resolution": "2k",
  "target_formats": ["glb"],
  "name": "medina-<slot>"
}
```

Field-by-field justification against the docs (all names copied from R1/R4):

- `image_url` — square PNG is fine; ".png" is supported, public URL **or** base64 data URI [R1].
  "at least 512 × 512 px; 1024 × 1024 px or higher is ideal" [S12 in the scan, unchanged]. Ground
  texture is never uploaded to this field.
- `model_type: "smart-topology"` + `ai_model: "meshy-t2"` — §1/§2 above; the pair is mandatory together.
- `target_polycount: 4000` — docs agree with the charter's number: T2 default is exactly 4,000,
  range 100–15,000 [R1]. Explicit is better than default (ledger clarity). Within the game-budget
  guidance (PC/console environment prop 500–5,000 tris [R16]; mobile casual 1K–5K [S19]).
- `should_texture: true` + `enable_pbr: true` + `texture_resolution: "2k"` — §3. PBR means
  base_color + metallic + normal + roughness land in `texture_urls` on the same task.
- `target_formats: ["glb"]` — GLB bundles geometry+texture for Godot 4 GL Compatibility;
  "Only the requested formats will be generated and returned, which can reduce task completion time."
  Omitted formats default to everything-except-3mf [R1].
- `name` — documented field ("Task name.", R4); zero-risk way to tag each job with its slot.

**Deliberately omitted, with reasons:**

- *Rig*: there is no rig flag on generation. Rigging is a separate humanoid-only API; `pose_mode`
  is for characters ("Enable Pose only for humanoid or character models — it has no effect on objects",
  S16). Omit `pose_mode` entirely.
- *Matte*: **no matte parameter exists.** `surface_mode` (`organic`|`hard`) is "Deprecated; use
  `ai_model`" [R4] and unrelated. The two finish knobs the scan once suggested are both inert on T2:
  `remove_lighting` — machine contract: "Not supported under smart-topology" [R4];
  `image_enhancement` — "Not supported under smart-topology" [R4]. **This supersedes the scan's §7b
  example JSON, which included `image_enhancement` (and the scan's §7a GUI advice on Remove Lighting).**
  Matte is therefore handled by (a) the reference PNG (flat/powder finishes drawn in), (b) optional
  `texture_prompt` describing the finish (≤800 chars on this endpoint per R2; ≤600 per R1 — conflict
  noted below), and (c) roughness/material tuning in Godot after import.
- *`should_remesh` / `topology` / `save_pre_remeshed_model`* — ignored under smart-topology [R1]; T2
  sets the count at generation, and remeshing after texture is the documented UV-breaker (§3).
- *`auto_size` / `origin_at`* — "origin bottom" is the documented default posture, but `origin_at` is
  scoped: "Position of the origin **when `auto_size` is enabled**... default `bottom`" [R1/R2].
  Leaving `auto_size` off (recommended — no AI rescale for a game asset we size in-engine) means
  `origin_at` is not actionable. Action: verify the origin of the first pulled GLB (bbox min-y vs
  model transform) and, if it is not bottom, fix it in Godot or re-request that slot with
  `auto_size: true, origin_at: "bottom"` (accepting the AI height estimate). One slot flag, not a
  whole-pack re-plan.
- *`symmetry_mode`* — deprecated, "no longer affects output" [R1, R12]. *`ultra_mode`* — meshy-7 only.

## 8. Contradictions and traps found today (recorded, not smoothed over)

1. **Credit tables** — §5. 15 (API pricing) vs 20 (help center) for the exact T2+2K config.
   Resolve by measuring `consumed_credits`; both under the 30-credit abort gate.
2. **`pull_meshy.py` uses a dead v2 image-to-3D route** — §6 FLAG. Verified by probe + spec.
3. **`meshy-t1` still appears in the R1 md mirror** ("`meshy-t1` or `meshy-t2`", and it also still
   lists `meshy-t1` as an ai_model), but the Sep 1 2026 changelog removed T1 from the docs and the
   live machine contract (R4) does not list it. T2 is the only correct value; the md mirror lags.
4. **`texture_prompt` max length differs by page**: 600 chars (R1 md) vs 800 (R2 HTML, and 800 on
   multi-image R8). Keep prompts well under 600 to be safe on both readings.
5. **List `page_size` max differs by page**: 100 (R2) vs 50 (R1 md) on `/image-to-3d`. Use ≤50.
6. **`remove_lighting` / `image_enhancement` are inert on T2** (R4: "Not supported under
   smart-topology") — corrects the scan's §7b JSON and its GUI-facing advice for this pack.
7. **`page_size`/response fields** — not blockers, listed for the ledger writer: the task object's
   `type` is `"image-to-3d"`, ids are k-sortable UUIDs whose format "you should not make any
   assumptions about" [R1].

## 9. Gate-1 verdict (docs half)

| Gate-1 requirement (CHARTER) | Status |
|---|---|
| Official Mesh T2 param name | ✅ `ai_model: "meshy-t2"` + `model_type: "smart-topology"` (R1/R4/R12) |
| Smart Topology param | ✅ `model_type: "smart-topology"`; `target_polycount` 100–15,000 (default 4,000), triangle only, single-image or text, **no multi-image** (R1/R4/R8) |
| Texture-on-create vs texture-later | ✅ On create: `should_texture: true` + `enable_pbr: true` + `texture_resolution`; later-pass exists (Retexture, 10 cr) but is never T2 and remesh-after-texture breaks UVs (R1/R9/R13) |
| Key present | ⏳ Not this doc — Inventory captain (`$MESHY_API_KEY` / `~/.config/meshy/api_key`); recon only confirms the correct header form `Authorization: Bearer msy_...` |

Ready for Gate 2 with: 10 fresh `v1/image-to-3d` T2 jobs at 2K PBR, expected 15–20 credits each
(measured via `consumed_credits`), GLB download immediately on `SUCCEEDED`, task ids (not URLs)
persisted to `LEDGER.jsonl`, and the `pull_meshy.py` v2→v1 base-URL fix as the first pipeline task.
