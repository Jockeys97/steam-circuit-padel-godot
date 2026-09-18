# LOG — Arena Kit Standard (append-only, one entry per step)

## 2026-09-18 15:35 CEST — charted, scan dispatched (CEO)

Owner directive (verbatim intent): "The 3D arenas suck ass and don't look like they
should — either create 3D assets for it to look nice … or use meshy api to generate
some from image-gen prototypes, asset by asset. /sota-landscape-scan for sota
methodology, and let's go." Follow-up: "give me a batch of image gen assets for each
map … I'm just going to make them in Meshi myself … you can pull them from the API …
I can go up to 10 3D models in Meshi … for each map, let's create at least a
standardized set of assets so that we create a pipeline for repeatable arena creation
and arena modification."

Event: recon of the primary tree (main == origin/main == deab8cf; foreign dirt left
untouched). Charter written. Five read-only scouts dispatched (4 SOTA methodology
lanes + 1 repo seam lane); no engine runs, no paid calls.

Decision: image batches are the immediate owner-visible deliverable (M1); Meshy
generation stays owner-side in the GUI; the puller must work with a key or a drop
folder; assembly keeps the procedural fallback so nothing regresses while assets trickle in.

Next: synthesize scan reports into the frozen Kit Standard v1, then hire Captain-I
(images) and Captain-K (kit + intake).

## 2026-09-18 15:50 CEST — five scan reports verified, standard frozen, two lanes hired

Scan landed (2,937 lines, all five reports read for section-level sanity): meshy-props,
image-prototyping, env-kits-godot, stylized-look-godot, repo-arena-seams. Key numbers
adopted: Smart Topology props (100–15,000 faces, 3-day Meshy retention), single square
image per prop, runtime GLTFDocument load, depth budget ~3.6 m behind the field-law
plane, no auto-instancing under GL Compatibility.

`KIT-STANDARD.md` frozen (10 slots + image-only ground_texture; T1 = 6 core models per
map, T2 = 4 more = the owner's 10-model Meshy limit).

Probe: parent generated `art/arena-kits/torii/hero_landmark.png` (1024×1024, passed all
six checklist items; open question answered — square = exactly 1024²). Ledger opened at
`art/arena-kits/image-spend.json` (cap 66 total, includes probes + regenerations).

Dispatched: Captain-I (`deleg_e420802a`) — full image batch, 5 arenas × 11 files, resumable
generator + per-arena manifests + INDEX; Captain-K (`deleg_b3309294`) — arena_kit.gd slot
loader, additive seam in arena_scenery, headless mount test, Meshy puller with inbox mode,
PIPELINE.md. Both report back with handles; the CEO verifies before any commit.

## 2026-09-18 16:30 CEST — both lanes delivered, CEO-verified, committed

**Captain-I (`deleg_e420802a`)**: 55 images (5 arenas × 11 slots) + `tools/arena-kit/gen_assets.py`
(resumable) + prompt packs + per-arena MANIFEST + INDEX + upload list. Ledger 57/66 calls
(1 parent probe + 54 slots + 2 regenerations), 0 failures.

**Captain-K (`deleg_b3309294`)**: `godot/game/arenas/arena_kit.gd` (776 lines, spec table for
5×10 slots, runtime load, `mount()/has_kit()/slot_report()`), additive seam in
`arena_scenery.gd` (+37/−6), `godot/tests/arena_kit_test.gd` (734 lines, 83 checks),
`tools/arena-kit/pull_meshy.py` (keyed + inbox modes), PIPELINE.md, `godot/assets/arenas/` READMEs.

**CEO verification (independent, not the makers' word):**
- 55/55 files present, all 1024², zero sha256 mismatches vs the ledger; sheets at 1280-wide
  contact sheets reviewed by the parent for all five arenas (visual gate — not delegable).
- Engine re-runs by the CEO: `arena_kit_test` **PASS 83/83**, `world_arenas_field_law_test`
  **PASS 88/88**, both 0 SCRIPT ERRORs.
- `arena_scenery.gd` diff read line-by-line before staging; suppression list empty today.
- meshy/ incident check: 81 tracked = 81 on disk, `git diff HEAD` empty (restore genuine).
- Rejected attempts moved out of the arena dirs → `art/arena-kits/_rejected/`; the five
  arena dirs now hold exactly the 11 deliverable images each (owner batches 1-by-1).
- Stale egeo contact sheet identified (pre-regen church frame) → sheets rebuilt; file on
  disk is the correct stone cluster (verified at full size).

**Corrections recorded:** KIT-STANDARD §5 `ResourceLoader.exists` → `FileAccess.file_exists`
(a dropped, unimported GLB fails the former — the kit would never fire); `field_law_report()`
now walks the full transform chain (nested kit pieces; no measured value changes today).

**Inherited reds (not ours):** `game_slice_test` 344/345 before and after; the one failure is
the locale table size (689 keys vs 688 expected) from another lane's uncommitted edit.

**Honest gaps:** the live Meshy API pull path is unverified (no key on this machine) — the
inbox path is proven end-to-end. No Meshy models exist yet (owner-side generation pending).

