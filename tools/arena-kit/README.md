# tools/arena-kit — the arena-kit intake side

This directory carries both halves of the arena-kit pipeline. **This file covers the intake
half** (pulling finished GLBs into the engine tree). The image half (`build_packs.py`,
`gen_assets.py`, `prompts/`) generates the slot images and is documented by its own lane;
the end-to-end recipe is `docs/mission/arena-kit/PIPELINE.md`.

## What the engine reads

    godot/assets/arenas/<arena>/<slot>.glb        <arena> ∈ torii medina carioca aurora egeo
                                                 <slot>  ∈ the ten slots in KIT-STANDARD §1

Drop a GLB there (or pull it with the tool below) and the arena mounts it on the next
build. Nothing else is required: no `.import`, no scene file, no code change. A slot with
no file keeps its procedural blockout. The engine side is
`godot/game/arenas/arena_kit.gd` (+ the additive call in `arena_scenery.gd::build()`).

## pull_meshy.py

    python3 tools/arena-kit/pull_meshy.py --from-inbox --arena torii --slot hero_landmark
    python3 tools/arena-kit/pull_meshy.py --from-inbox --all
    python3 tools/arena-kit/pull_meshy.py --arena torii --slot hero_landmark --task <meshy-id>
    python3 tools/arena-kit/pull_meshy.py --report
    python3 tools/arena-kit/pull_meshy.py --slots
    python3 tools/arena-kit/pull_meshy.py --retire --arena torii --slot hero_landmark

Two ways in, because the owner may or may not want to hand over an API key:

* **`--from-inbox`** — copies `meshy/inbox/<arena>/<slot>.glb` into the slot path. Zero
  credentials; this is the path the offline verification runs and the one that always
  works. The manual drop inbox is the KIT-STANDARD §2 contract.
* **live** — `--task <id>` GETs
  `https://api.meshy.ai/openapi/v2/image-to-3d/<id>` and downloads `model_urls.glb`. The
  key comes from `$MESHY_API_KEY`, else `~/.config/meshy/api_key`. **Unverified until a key
  exists** (`--report` and the log work either way).
  Download immediately: Meshy retains an asset for 3 days and its URLs are signed and
  time-limited.

Bookkeeping: every write is atomic (temp file + rename) and its sha256 is appended to
`run/tmp/arena-kit/pull-log.jsonl` with the source, so a re-run is a no-op
(`skipped-identical`), a re-generated model is `overwritten`, and `--report` tells you what
is in place, from where, and whether the bytes still match. `--retire` takes a slot's file
back out (logged) — the un-stage path for a prop that is not good enough yet.

Exit codes: `0` done · `2` usage · `3` task not ready · `4` no key · `5` source/target
problem · `6` not a GLB (the file is checked for the `glTF` magic before it is written).

## fixtures/

`make_tiny_prop.py` builds `tiny_prop.glb` — a 1 KB static box, 0.50 m tall, bottom at
y = 0, carrying deliberately wrong Meshy-style material values (metallic 0.9, roughness
0.2, emissive white). It exists so the engine test can check the placement math to the
millimetre (`scale = target_h / 0.50`) and so the material policy has something real to
correct. Stdlib only, no engine, no network:

    python3 tools/arena-kit/fixtures/make_tiny_prop.py           # write it
    python3 tools/arena-kit/fixtures/make_tiny_prop.py --check   # rebuild and compare

The engine test (`godot/tests/arena_kit_test.gd`) uses it as one of its two fixtures: it
copies this file at a slot path for the exact placement / material-policy proof, and a real
repo GLB (`res://assets/athletes/volpe-rigged.glb`, 8.9 MB, skinned) at another slot so the
intake is also proven against a real export. Both are removed again, and the test fails if
any `.glb` is left under `godot/assets/arenas/` — so running the suite leaves no stray
files behind.
