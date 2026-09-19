# Medina Mesh T2 pack — log

## 2026-09-18 — charter

Event: CEO wrote CHARTER.md. Outcome is ten textured Medina GLBs via Meshy API Mesh T2 + Smart Topology.
Owner: CEO
Status: open
Handle: `docs/mission/arena-kit/meshy-t2-medina/CHARTER.md`

## 2026-09-18 — recon hire

Event: Scout + Inventory captains dispatched native, read-only.
Owner: CEO
Status: dispatched
Handle: `deleg_3bc6367f`

## 2026-09-18 — recon verified

Event: Parent verified both files on disk and independently fetched https://docs.meshy.ai/en/api/image-to-3d and https://docs.meshy.ai/api/pricing.md.
Decision: Mesh T2 request is `model_type: smart-topology` plus `ai_model: meshy-t2`, texture on the same POST (`should_texture: true`, `enable_pbr: true`, `texture_resolution: 2k`). List price 15 credits per textured T2 image-to-3D job (10 slots → 150 credits). GUI Workspace models are not API-visible; no saved task ids; no arena GLBs. Key missing on this Mac.
Owner: CEO
Status: gate 1 blocked on key
Handle: `RECON.md`, `INVENTORY.md`

## 2026-09-18 — key intake

Event: Generation not started. Intake script at `/tmp/meshy-api-key-intake.sh`. Luca types the key in his own terminal. Nothing pasted in chat.
Owner: Luca
Status: waiting
Handle: `/tmp/meshy-api-key-intake.sh`

## 2026-09-19 — key in, balance read back

Event: Key present in the dev-work profile env and the config copy. Parent called the balance endpoint directly: HTTP 200, 2447 credits.
Owner: CEO
Status: gate 1 cleared
Handle: `GET /openapi/v1/balance` → balance 2447

## 2026-09-19 — pipeline dispatch

Event: One pipeline captain, sequential dependent work, no fan-out.
Owner: CEO
Status: dispatched
Handle: `deleg_dbc2caa9`

## 2026-09-19 — generated and verified

Event: Ten of ten Medina props generated on the first attempt with Mesh T2 plus Smart Topology, textured 2K PBR on the same create call. Parent verified independently, not from the captain report: parsed each GLB's own JSON chunk (3 embedded images and a base-colour plus metallic-roughness texture on every file), recounted triangles in the parent, re-summed the ledger at 150 credits, and re-read the live balance at 2297, matching the ledger delta exactly. Preview thumbnails re-checked numerically.
Decision: accept gate 2. The look verdict is Luca's, not the parent's.
Owner: CEO
Status: gate 2 passed, gate 3 awaiting Luca
Handle: `LEDGER.jsonl`, `PIPELINE-RESULT.md`, `godot/assets/arenas/medina/*.glb`, contact sheet `run/tmp/arena-kit/medina-t2-contact-sheet.png`

## 2026-09-19 — note on the railing preview

Event: The railing_segment preview measures zero per cent coloured pixels while every other slot carries colour. The GLB does have a base-colour texture, so the texture is grey by content, not missing. Flagged for Luca rather than fixed unilaterally; a brass or terracotta tint may be wanted.
Owner: CEO
Status: open, owner decision
Handle: `previews/railing_segment.png`

## 2026-09-19 — pipeline run (Gate 2)

Event: Ten Medina GLBs generated via the Meshy Image-to-3D API through one batch script (`tools/arena-kit/gen_medina_t2.py`): Mesh T2 + Smart Topology, textured 2K PBR, `target_polycount` 4000, base64 data-URI uploads, GLBs downloaded on `SUCCEEDED`. All ten slots SUCCEEDED on the first create attempt, no retries. Credits: 15 per job, 150 total; balance 2447 → 2297 (all ten debited at creation, confirmed by the balance endpoint). GLBs re-hashed against the ledger — all match. Previews (task thumbnails) saved for all ten.
Owner: Pipeline captain
Status: gate 2 complete — GLBs + ledger + previews + result on disk; Luca judges look (gate 3)
Handle: `docs/mission/arena-kit/meshy-t2-medina/PIPELINE-RESULT.md`, `LEDGER.jsonl`, `previews/`, `godot/assets/arenas/medina/*.glb`, `tools/arena-kit/gen_medina_t2.py`
