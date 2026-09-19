# Brief for Captain A — generate the remaining forty arena props

Owner: Captain A (generation). Read `docs/mission/arena-kit/arena-props/CHARTER.md` first.

Workdir: `/Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot` (primary `main`).

## You own exactly

- `tools/arena-kit/gen_arena_t2.py` (new; model it on the proven `gen_medina_t2.py`)
- `godot/assets/arenas/torii/*.glb`, `godot/assets/arenas/carioca/*.glb`,
  `godot/assets/arenas/aurora/*.glb`, `godot/assets/arenas/egeo/*.glb`
- `docs/mission/arena-kit/arena-props/LEDGER.jsonl`, `.../previews/`, `.../GEN-RESULT.md`

Do NOT edit `godot/game/arenas/arena_kit.gd`, any test, any file under `art/arena-kits/`,
or `tools/arena-kit/gen_medina_t2.py`. Do NOT touch the `feat-native-world-arenas` worktree.
Do NOT commit or push.

## Job

Forty image-to-3D jobs: four arenas (`torii`, `carioca`, `aurora`, `egeo`) times ten slots.
Medina is already done; do not regenerate it.

Slots, identical for every arena:
hero_landmark, gate_portal, light_source, vegetation_cluster, ground_dressing,
ornament_accent, column_pillar, railing_segment, furniture, signage_banner

Sources: `meshy/arenas/<arena>/<slot>.png`, all 1024x1024 and already on disk.
Targets: `godot/assets/arenas/<arena>/<slot>.glb`.

## The proven call (copy it, do not reinvent it)

`tools/arena-kit/gen_medina_t2.py` already generated ten textured props on the first
attempt. Read it and generalize it. The request shape that worked:

    model_type: "smart-topology"
    ai_model: "meshy-t2"
    target_polycount: 4000
    should_texture: true
    enable_pbr: true
    texture_resolution: "2k"
    target_formats: ["glb"]

Endpoint `POST https://api.meshy.ai/openapi/v1/image-to-3d`, poll
`GET https://api.meshy.ai/openapi/v1/image-to-3d/<task_id>`, key from `MESHY_API_KEY` in
`~/.hermes/profiles/dev-work/.env` or `~/.config/meshy/api_key`.

Rules that bit before, keep them: images are local so they go as base64 data URIs; never
send `topology`, `should_remesh`, or `save_pre_remeshed_model` with `smart-topology` (they
are ignored); download `model_urls.glb` immediately on `SUCCEEDED` because the signed URL
expires; record `consumed_credits` as the authoritative cost; back off on HTTP 429; never
print or log the API key or the Authorization header.

Keep the ground texture out of Meshy.

## Budget

40 create calls plus at most 2 retries. 15 credits each, 600 total. Balance at dispatch is
2297; stop launching if it drops below 600. Journal every slot to
`run/tmp/arena-kit/gen-arena-journal.txt` so a crash loses nothing, and make the script
resumable: skip any slot whose GLB already exists and is over 50 KB.

## Gates

| Gate | Threshold |
|---|---|
| GLBs | 40 files, each over 50 KB, named to slot |
| Texture | every GLB carries a base-colour image in its material |
| Ledger | 40 lines with task_id and consumed_credits, no missing slot |
| Balance | remaining balance recorded, reconciled against the ledger sum |
| Scope | `git status --short` shows only your owned paths |

Report each gate honestly. If one fails, say so with the per-slot table.

## Return

Short plain prose: slots generated per arena, credits consumed, remaining balance, triangle
range, failures, ledger path, GLB root. No ids in prose.
