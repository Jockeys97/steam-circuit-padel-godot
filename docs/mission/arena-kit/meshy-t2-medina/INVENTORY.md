# Medina Meshy T2 pack — INVENTORY (local recon)

Date: 2026-09-18 · Captain: Inventory · Evidence for the CHARTER's inventory lane
Tree: `/Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot` (primary `main`). The `feat-native-world-arenas` worktree was not touched.
Read-only recon: no Meshy API calls, no image generation, no secret read or printed, no commits. The only file written by this lane is this INVENTORY.md.

Read: `docs/mission/arena-kit/meshy-t2-medina/CHARTER.md`, `docs/mission/arena-kit/KIT-STANDARD.md`, `tools/arena-kit/pull_meshy.py`, `tools/arena-kit/README.md`, `meshy/arenas/medina/MANIFEST.md`, `meshy/arenas/UPLOAD-LIST.md`, `art/arena-kits/INDEX.md`.

## 1. Slot set — the kit ten (Meshy) + `ground_texture` (image-only)

Ten Meshy slots (KIT-STANDARD §1; mirrored in `pull_meshy.py`'s fallback list and read at runtime from `godot/game/arenas/arena_kit.gd`):

| # | slot | intake image | target GLB |
|---|------|--------------|------------|
| 1 | `hero_landmark` | `meshy/arenas/medina/hero_landmark.png` = `art/arena-kits/medina/hero_landmark.png` | `godot/assets/arenas/medina/hero_landmark.glb` |
| 2 | `gate_portal` | `…/gate_portal.png` | `…/gate_portal.glb` |
| 3 | `light_source` | `…/light_source.png` | `…/light_source.glb` |
| 4 | `vegetation_cluster` | `…/vegetation_cluster.png` | `…/vegetation_cluster.glb` |
| 5 | `ground_dressing` | `…/ground_dressing.png` | `…/ground_dressing.glb` |
| 6 | `ornament_accent` | `…/ornament_accent.png` | `…/ornament_accent.glb` |
| 7 | `column_pillar` | `…/column_pillar.png` | `…/column_pillar.glb` |
| 8 | `railing_segment` | `…/railing_segment.png` | `…/railing_segment.glb` |
| 9 | `furniture` | `…/furniture.png` | `…/furniture.glb` |
| 10 | `signage_banner` | `…/signage_banner.png` | `…/signage_banner.glb` |

**`ground_texture` must NOT go to Meshy — confirmed.** KIT-STANDARD §1 lists it as `image-only … no Meshy model, used as a material`; `art/arena-kits/INDEX.md` §1: "**never upload it to Meshy** — it is the material swatch for the apron"; `meshy/arenas/medina/MANIFEST.md` closes with the same rule. Consistent with that, it exists only under `art/arena-kits/medina/` and is absent from `meshy/arenas/medina/` (the Meshy upload area). 11th PNG, 10 Meshy jobs.

## 2. Intake PNGs on disk (byte sizes recorded)

All ten slot PNGs exist in both locations. Each pair is **byte-identical** (sha256 equal) and **1024×1024** (PNG IHDR checked):

| slot | bytes | sha256[0:12] | both locations identical |
|------|-------|--------------|--------------------------|
| `hero_landmark` | 848,294 | `ca928df26c32` | yes |
| `gate_portal` | 1,020,146 | `0166c370603b` | yes |
| `light_source` | 788,869 | `7dde96cc7a51` | yes |
| `vegetation_cluster` | 890,792 | `9eed87e62420` | yes |
| `ground_dressing` | 991,511 | `ecd999fb1919` | yes |
| `ornament_accent` | 962,952 | `9328d9f37bdd` | yes |
| `column_pillar` | 881,938 | `727292b1922b` | yes |
| `railing_segment` | 916,508 | `50a745e31e6c` | yes |
| `furniture` | 1,017,216 | `fba2755b5b5a` | yes |
| `signage_banner` | 844,957 | `a2c415d79700` | yes |
| `ground_texture` (art-only, N/A to Meshy) | 1,135,502 | `f5aabe388374` | — |

GLBs: `godot/assets/arenas/medina/` contains **only `README.md` (456 B)** — no `.glb` files yet. The drop inbox `meshy/inbox/` (contract path `meshy/inbox/<arena>/<slot>.glb`, KIT-STANDARD §2) **does not currently exist** — it must be created before an inbox pull, or the live task-id path must be used (which needs a key, see §4).

## 3. Saved Meshy task ids for torii or medina — NONE

- `run/tmp/arena-kit/pull-log.jsonl` (18 entries): **zero `task_id` fields.** Every row is `mode: inbox` or `retire`; the only medina/torii rows are the offline puller check's fixtures (a 1,028 B fixture GLB copied to `medina/furniture.glb` and later retired; a 17 B `not-a-glb` for `torii/gate_portal`). All places were retired — nothing is staged.
- Image-spend ledgers (`art/arena-kits/image-spend.json`, `meshy/image-spend.json`, `meshy/image-spend-fornaio.json`): image-generation books only, no Meshy task ids.
- `tools/meshy/` does not exist. `docs/mission/arena-kit/meshy-t2-medina/` held only `CHARTER.md` when this scan began; the scout's `RECON.md` (20,897 B, sha256[0:12] `eafc75988324`) landed concurrently and was re-checked: **no task ids in it either.** `LEDGER.jsonl` does not exist yet.
- The only Meshy task ids anywhere in the repo belong to the **volpe athlete rig** (`meshy/rigged/volpe/`), not to torii/medina — do not reuse or repurpose: gen `01a0a77f-…`, remesh `01a0a78d-…`, rig `01a0a794-…` (full ids in that folder's `*_final.json` / `run_*.py`).

**task_ids_found = false.** No id is assumed or invented; fresh tasks must be created.

## 4. Meshy API key — exists = FALSE (name-only scan; no secret read or printed)

| check | result |
|-------|--------|
| repo `.env` | absent |
| `~/.hermes/profiles/dev-work/.env` | exists (file) — **no `MESHY*` variable names** |
| `~/.config/meshy/` (pull_meshy KEY_FILE dir; key file would be `~/.config/meshy/api_key`) | absent |
| `~/.meshy/` (extra check) | absent |
| repo `tools/meshy/` | absent |
| env var `MESHY_API_KEY` | not set (this session's shell) |
| env var `MESHY_KEY` | not set |

`pull_meshy.meshy_key()` resolves `$MESHY_API_KEY` first, else `~/.config/meshy/api_key` — both empty here, so the live path currently exits `4` ("no key"). CHARTER: "Abort the rest … if the key is missing" → generation is blocked until a key is provided (or the credential-free drop-folder path is used). Lead only, not a local key: `meshy/rigged/RESULT.md` line 59 records that a prior run kept a key at `/root/.config/meshy/api_key` — that is another host, nothing to read on this machine.

## 5. `pull_meshy.py` — what it already does, and what it cannot

Pull-only tool (373 lines, stdlib). Its only HTTP calls are a `GET https://api.meshy.ai/openapi/v2/image-to-3d/<task-id>` and the asset download — **it never POSTs; it cannot create tasks.**

- **live mode** (`--task <id>`): GET the task, require `status == SUCCEEDED`, take `model_urls.glb`, download. Single status check, **not a polling loop** — exits `3` if the task is not ready. Needs the key (`$MESHY_API_KEY` else `~/.config/meshy/api_key`), else exits `4`.
- **`--from-inbox`**: copies `meshy/inbox/<arena>/<slot>.glb` → `godot/assets/arenas/<arena>/<slot>.glb`. Zero credentials; the path the offline verification runs. `--all` sweeps every inbox file that exists.
- **Writes**: GLB-magic check (`6` if not a GLB), atomic write (temp + rename), read-back sha256; every pull logged to `run/tmp/arena-kit/pull-log.jsonl`. Idempotent: same source+hash = `skipped-identical`; differing destination = `overwritten`; `--force` re-pulls.
- **Other modes**: `--retire --arena X --slot Y` (unstage a bad model, logged), `--report` (verifies what is in place against the log), `--slots` (prints the frozen slot set read from `arena_kit.gd`).

CLI flags exactly as defined in the argparse block: `--arena`, `--slot`, `--task`, `--from-inbox`, `--all`, `--force`, `--retire`, `--report`, `--slots`.
Exit codes: `0` done · `2` usage · `3` task not ready · `4` no key · `5` source/target problem · `6` not a GLB.

Documented usages (docstring / `tools/arena-kit/README.md`):
```
python3 tools/arena-kit/pull_meshy.py --arena torii --slot hero_landmark --task <id>
python3 tools/arena-kit/pull_meshy.py --from-inbox --arena torii --slot hero_landmark
python3 tools/arena-kit/pull_meshy.py --from-inbox --all
python3 tools/arena-kit/pull_meshy.py --report
python3 tools/arena-kit/pull_meshy.py --retire --arena torii --slot hero_landmark
python3 tools/arena-kit/pull_meshy.py --slots
```

**Mesh T2 / Smart Topology / texture support: none.** The tool exposes no generation parameters at all (no model type, no topology, no texture, no credits). Flag gap: creation (the POST with `meshy-t2`-class Mesh T2 + Smart Topology + 2K PBR texture + bottom origin — exact param names to be pinned by RECON) has no home in this tool; the pipeline must create tasks separately, then feed the resulting id to `pull_meshy.py --task`. `pull_meshy_can_create = false`.

## 6. Dirty tree note — primary `main`, recorded 2026-09-18

`git status --porcelain`:

```
 M godot/game/arenas/arena_look.gd
?? art/arena-kits/GROUND-TEXTURE-NOTE.md
?? docs/mission/arena-kit/meshy-t2-medina/
?? docs/mission/arena-kit/proof/look/after/
?? godot/tests/arena_look_test.gd
```

`arena_look.gd` (modified) and `arena_look_test.gd` (untracked) are the **look lane's unrelated work — the Medina pipeline must not touch, stage, or commit them** (CHARTER lists those files and commits as out of scope). `meshy-t2-medina/` is this mission's own untracked dir (CHARTER + this file); `proof/look/after/` is the look lane's captures.

## 7. Pipeline-relevant gaps (from this recon)

1. **No key** anywhere checked → the abort condition in CHARTER's frugal-spend section is live; generation needs a key provisioned, else the drop-folder path only.
2. **No create tooling** — `pull_meshy.py` pulls/polls-once/downloads; task creation (POST) is a pipeline-captain deliverable (param shape gated by RECON).
3. **No polling loop** — live pulls must be re-run (exit `3` while not ready) or wrapped.
4. **Drop inbox missing** — `meshy/inbox/` must be created before `--from-inbox` works.
5. **`ground_texture` is never uploaded** — intake for Meshy is exactly the ten slot PNGs in §2.
