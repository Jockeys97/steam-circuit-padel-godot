# Pipeline brief — Medina Mesh T2 generation

You are the Pipeline captain (integrator) for the Medina Mesh T2 pack. You own creation,
polling, download, and the ledger. Nobody else is working in this tree.

Workdir: `/Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot` (primary `main`).
Do NOT touch the `feat-native-world-arenas` worktree. Do NOT edit `godot/game/arenas/arena_look.gd`,
`godot/tests/arena_look_test.gd`, or any file under `art/arena-kits/`. Do NOT commit or push.

Read first: `docs/mission/arena-kit/meshy-t2-medina/CHARTER.md`, `RECON.md`, `INVENTORY.md`.

## Approved spend

Luca approved this run. Balance measured live by the parent: 2447 credits.
Ten jobs at 15 credits each is 150. Hard stop: if the balance read at any point drops below 150,
stop launching new jobs. Max 12 create calls total (10 slots + at most 2 retries). One retry
per failed slot; credits are refunded on FAILED, so a retry is cheap.

## Deliverables

1. Ten GLBs: `godot/assets/arenas/medina/<slot>.glb` for these slots:
   hero_landmark, gate_portal, light_source, vegetation_cluster, ground_dressing,
   ornament_accent, column_pillar, railing_segment, furniture, signage_banner
2. Ledger: `docs/mission/arena-kit/meshy-t2-medina/LEDGER.jsonl` — one JSON object per line:
   slot, task_id, status, consumed_credits, created_at, finished_at, glb_bytes, glb_sha256, attempt
3. Previews: `docs/mission/arena-kit/meshy-t2-medina/previews/<slot>.png` from each task's
   `thumbnail_url` (evidence handle for the parent). Download while the task is live.
4. `docs/mission/arena-kit/meshy-t2-medina/PIPELINE-RESULT.md` — plain-English result:
   what generated, per-slot credits and triangle count, what failed and why, remaining balance.

`ground_texture` is NOT generated. It is a material swatch and never uploads.

## Exact API shape (verified today from docs.meshy.ai)

Auth: header `Authorization: Bearer <key>`. Read the key from `MESHY_API_KEY` in
`~/.hermes/profiles/dev-work/.env`, falling back to `~/.config/meshy/api_key`.
Never print the key, never echo the header.

Create: `POST https://api.meshy.ai/openapi/v1/image-to-3d`
Poll:   `GET  https://api.meshy.ai/openapi/v1/image-to-3d/<task_id>`
Balance: `GET https://api.meshy.ai/openapi/v1/balance`

Create body for every slot (these field names are exact):

    {
      "image_url": "<base64 data URI of the slot PNG>",
      "model_type": "smart-topology",
      "ai_model": "meshy-t2",
      "target_polycount": 4000,
      "should_texture": true,
      "enable_pbr": true,
      "texture_resolution": "2k",
      "target_formats": ["glb"]
    }

Source images: `meshy/arenas/medina/<slot>.png` (1024x1024, byte-identical to
`art/arena-kits/medina/<slot>.png`). Local files must go as a base64 data URI
(`data:image/png;base64,...`); there is no public host for them.

Notes that matter:
- When `model_type` is `smart-topology`, the fields `topology`, `should_remesh`, and
  `save_pre_remeshed_model` are IGNORED. Do not send them.
- `target_polycount` for smart-topology is generated directly at that face count,
  range 100 to 15000, default 4000. No remesh phase runs.
- `enable_pbr` is only valid with `should_texture` true.
- GLB carries the texture embedded. Do not chase separate texture maps.
- Poll `status` until `SUCCEEDED` or `FAILED`. `model_urls.glb` is a SIGNED URL that
  expires in about three days: download it in the same run, immediately after success.
  Persist the task_id, never the URL.
- `consumed_credits` on the task response is the authoritative per-task cost.
- Grow-backoff on HTTP 429. Back off and continue; do not hammer.

## Procedure

1. Write ONE Python script (e.g. `tools/arena-kit/gen_medina_t2.py`) that does the whole batch:
   load key, read each slot PNG, create the task, poll to terminal status, download the GLB and
   the thumbnail, append the ledger line, and stop on the balance floor. Journal progress to
   `run/tmp/arena-kit/medina-t2-journal.txt` after every slot so a crash loses nothing.
2. Run it once in the background with `notify_on_complete`, or foreground with a generous
   timeout. Do not hand-poll task-by-task from the shell.
3. After the GLB lands, record its triangle count. `tools/character/glb_tri_count.py` exists —
   use it if it runs, otherwise parse the GLB JSON chunk yourself and say which method you used.

## Gates (report each honestly, and say so if one fails)

| Gate | Threshold |
|---|---|
| GLBs on disk | ten files at `godot/assets/arenas/medina/<slot>.glb`, each over 50 KB |
| Texture present | each GLB has a material with a base-colour image, and enable_pbr was accepted |
| Triangles | per-slot count recorded in the ledger |
| Ledger | ten lines with task_id and consumed_credits, no missing slot |
| Balance | remaining balance recorded in PIPELINE-RESULT.md |
| Tree scope | `git status --short` shows only Medina GLBs, the new script, and the mission docs |

If any gate fails, report failure honestly with the per-slot table. Do not massage a pass.

## Return

Short final answer, plain prose: slots generated, total credits consumed, remaining balance,
per-slot triangle counts as a table, what failed, the ledger path, and the path of every GLB.
