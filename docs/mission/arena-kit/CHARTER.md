# CHARTER — Arena Kit Standard (repeatable arena pipeline + concept-matching looks)

Mission: `docs/mission/arena-kit/`. Owner: Luca. CEO: this session. Started 2026-09-18.

## Outcome (what Luca must be able to do)

1. Open the build, pick any world arena, and see an environment that reads like its
   designed still (`art/concepts/world-arenas-r1/*.png`) — not a grey blockout.
2. Add or modify an arena by dropping slot-named assets into a folder — no code edits.
3. Hand us image batches today, generate models in Meshy himself (≤10 models per map),
   and have the GLBs pulled into the right slot folders via the API.

## Owner-visible milestones

| # | Milestone | Proof |
|---|---|---|
| M1 | Per-arena image batches (standard slot set × 5 arenas) ready to drag into Meshy | `art/arena-kits/<arena>/` + MANIFEST + spend ledger |
| M2 | Meshy GLBs land in `godot/assets/arenas/<arena>/<slot>.glb` (API pull or drop folder) | pull log + file stats |
| M3 | In-engine assembly swaps procedural blockout per slot; fallback intact | engine captures + council verdict |
| M4 | Pipeline doc: add/modify an arena in N steps | `docs/mission/arena-kit/PIPELINE.md` |

## Gates (observable, no self-certification)

- G1 — Kit standard frozen (slot names, dimensions, folders, naming) and documented.
- G2 — Image batch: every image passes the Meshy-readiness checklist; reviewed by a
  critic that is not the maker; spend ledgered with purpose/batch/cost stated up front.
- G3 — Intake: a headless engine test proves a GLB dropped into a slot mounts in-game;
  procedural fallback when the slot is empty; frozen audits stay green
  (`arena_selector_contract_test.gd`, `screen_arena_audit.gd`, `game_slice_test.gd`).
- G4 — Meshy pull script verified against a recorded task fixture (live run needs Luca's key).
- G5 — Council (CCL) round on the assembled torii arena vs its concept still. Owner's
  taste verdict stays the last gate and is never self-approved.

## Hard limits

- Meshy: owner-side GUI generation. We never spend Meshy credits unless Luca says so;
  the API key stays owner-supplied (`~/.config/meshy/api_key` or pasted by Luca).
- Image gen: capped batch (60 images for M1), provider `openai/gpt-image-2.5-flare`,
  telemetry to `art/arena-kits/image-spend.json`; purpose/batch/cost stated before call 1.
- One Godot process at a time; research lanes never run the engine.
- Frozen: `js/**`, `scripts/**`, the nine frozen arena node names and audit pins, the
  foreign dirty files owned by other lanes (explicit staging only, never `git add -A`).
- No commits by children; the CEO stages and commits only verified work.

## Teams

| Role | Realm | Notes |
|---|---|---|
| Scout batch (5) | SOTA methodology + repo seams | dispatched 2026-09-18, read-only |
| Captain-K (kit + intake) | kit standard, Godot slot loader, Meshy puller, docs | integrator |
| Captain-I (image batch) | 5 × slot images, manifests, spend ledger | feeds Meshy |
| Council | CCL round at M3 | convenes after assembly |

## Fog (open, do not guess)

- Whether the nine steampunk arenas get kits in this pass or the next.
- Sky strategy: procedural sky shader vs generated panorama (GL Compatibility limits matter).
- Single-view vs multi-view images per prop for Meshy input.
- How Luca's key or drop-folder path reaches the puller (both supported; his call).

## Evidence handles

- Scan reports: `docs/mission/arena-kit/scan/*.md`
- Image batch: `art/arena-kits/<arena>/` + `image-spend.json`
- Intake: `godot/assets/arenas/` + engine logs under `run/tmp/` and mission `LOG.md`
