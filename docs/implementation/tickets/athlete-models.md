# Athlete models, rig and locomotion clips for the roster (slice S7)

- Status: open
- Type: task
- Mode: AFK
- Owner: unassigned
- Blocked by: [Nine arenas in 3D](nine-arenas.md) is not a blocker; the real blockers are [Athlete roster order](../../wayfinder/tickets/athlete-roster-order.md) (open, HITL, owner Luca), which decides which athletes become 3D models, in what order and under what spend cap, and [Character pipeline economics](../../wayfinder/tickets/character-pipeline-economics.md) (open, AFK, one item remaining), which must prove an in-engine render of two visually distinct outfits from one rigged model before the outfit route is buildable at all. Neither is a reason to stop: the imported mesh, the stroke retarget interface and the recolour test harness can be built against the one existing rig now. The slice may not be called done while the roster order and the spend cap stay unset.

This ticket implements row S7 of `docs/implementation/PLAN.md` ("Athlete models, rig and locomotion clips for the roster"). It does not change that plan, its slice numbering or its open-decision table, and it does not start S8 through S13.

## Objective

Get the six athletes — `maestro`, `pantera`, `steamer`, `fiamma`, `oracolo`, `colosso` — onto the court in 3D, with locomotion clips and Godot-authored padel strokes, in the order and under the spend cap that Luca sets, and with outfits that are recolours of one rigged model rather than per-outfit models. The slice is built in three separable halves, because only the first is unblocked today:

1. **The rig and the import path**, proven against the one rig that exists. `volpe-rigged.glb` is a generated pipeline trial, not a roster athlete, and it has a base pose only — one clip, one key at 0.300 s, duration 0.0, with walking and running living in companion files. So the import path is proven by loading the trial rig, retargeting a locomotion clip onto it, retargeting a Godot-authored stroke onto it, and rendering the result. Volpe stays a test asset unless Luca promotes it; nothing in the slice names it as a roster member.
2. **The recolour route**, carried forward from the character-pipeline work, whose remaining item is exactly one thing: an in-engine render proving two *visually distinct* outfits from one model via the proposed path. The measurement that exists says the ceiling is authoring coverage, not the render path — only about 14.25 % of the packed atlas is recolourable, capping the rendered whole-model difference at about 8.95/255 with today's mask against a measured 1.2/255. A stronger set of targets exists on disk and is untested in engine. This half turns that remaining item into a test, not a promise.
3. **The roster itself**, one athlete at a time, in Luca's order, each with its own frozen `stats` block and its own outfit set — the part that cannot start until the order and the cap land.

## Existing source anchors

| Anchor | What it is |
|---|---|
| `js/data.js:324-483` | `ATHLETES`, the six entries, in roster order. `maestro` at `:326` |
| `js/data.js:341, 365, 389, 413, 438, 463` | The six `stats` blocks — `{ speed, power, control, reach, stamina }`. **Simulation data**, read by `statRatio`/`paddleRatio`, and not this slice's to change |
| `js/data.js:342-345, 366-369, 390-393, 414-417, 439-442, 464-467` | The six `special` blocks with their `cooldown` (3.0, 2.6, 3.4, 2.8, 3.1, 3.2). A cooldown is simulation data; the special's *look* is this slice's |
| `js/data.js:484-497` | `ROSTER_AVERAGE`, computed from `ATHLETES` at load. Never hardcoded |
| `js/data.js:498-512` | `outfitSpritePaths(athleteId, outfitId)`, the six-spritesheet layout every current outfit points at. The 3D route replaces sprites with one recoloured model, so this function is the thing being retired — and the count it produces is what the port's tests still assert |
| `js/data.js:515-555` | `ATHLETE_OUTFITS`, 26 entries: six base plus twenty unlockable (maestro 5, pantera 5, steamer 5, fiamma 5, oracolo 3, colosso 3). Each non-base entry carries `colors`, a `challenge`, a `preview` and its `sprites` |
| `js/data.js:556` | `outfitsForAthlete(athleteId)` — the lookup any 3D outfit resolver must reproduce |
| `assets/athletes/*.webp` | The six painted athlete portraits — the only per-athlete art on disk, and the zero-spend texture source for an athlete until a roster decision says otherwise |
| `assets/outfits/<athlete>/<outfit>-preview.webp` | Twenty outfit previews, one per unlockable. **Note:** the base outfits have no preview file, so a preview-driven recolour test must handle the base case explicitly instead of asserting six previews per athlete |
| `meshy/rigged/volpe/volpe-rigged.glb` | The one rigged body: 24 joints, about 31,325 triangles, one baked `Material_1` with an embedded base-colour texture, no vertex colours, no garment materials. **Base pose only** |
| `meshy/rigged/volpe/volpe-walking.glb`, `volpe-running.glb` | The locomotion clips. They exist as companion files and are **not** inside the rigged GLB |
| `meshy/rigged/volpe/hashes.json` | Sizes and hashes of the trial assets — the provenance record the import test asserts against |
| `meshy/rigged/volpe/rig_final.json` | The rigging response. It contains signed expiring download URLs; nothing may quote them |
| `meshy/rigged/RESULT.md` | The pipeline result record, including the observed mesh defects (fused fingers and toes, a tail/shorts seam, leg texture smearing) that were never checked in engine |
| `godot/prototypes/arena_spike/assets/volpe-rigged.glb` | A byte-identical copy already loading in a Godot project, with a measured 1.678 m standing height from the bone extent. This is the proof that the import path works at all |
| `godot/prototypes/arena_spike/arena_spike.gd` | The prototype that loads the rig and holds it at t=0.300 s of its single key. It does not claim an idle clip |
| `godot/prototypes/character_material/character_material.gd`, `render.sh`, `Main.tscn` | The in-engine material proof: the GLB rendered twice in one frame with two different `albedo_texture` overrides on the duplicated `Material_1`, one lit `StandardMaterial3D`, surface override logged, 31,325 triangles re-measured in engine |
| `godot/prototypes/character_material/measure-report.json`, `measure-regions.json`, `measure-blocks.json`, `measure-aligned.json`, `measure-local-shift.json` and their `.py` scripts | The measurement suite behind the recolour numbers: region masks, block statistics and alignment checks |
| `tools/character/recolour_outfits.py`, `tools/character/outfits.json` | The recolour tool and its target-colour set |
| `tools/character/outfits-strong.json` | The prescribed stronger target set: same schema, same tool, fur guard untouched, so a render against it changes exactly one variable |
| `tools/character/analyse_recolour_delta.py`, `tools/character/out/diff-report.json`, `tools/character/out/PROVENANCE.md` | The offline delta analysis and its provenance, including the source texture's sha256 |
| `tools/character/glb_tri_count.py`, `tools/character/out/tri-count.json` | The triangle counter and its measured 31,325 per GLB |
| `docs/wayfinder/evidence/character-material-render.md` | The render proof's full write-up: what it proves mechanically, and the measured 1.2/255 whole-model movement that fails visible distinctness |
| `docs/wayfinder/evidence/character-recolour-delta-ceiling.md` | The measured ceiling: 14.25 % recolourable atlas, 36.35/255 atlas under today's mask, 8.95/255 on the whole rendered model, a stable 0.246 transfer ratio, and the 3.74/255 prediction for the stronger targets |

The seams this slice sits next to, each with one owner: `godot/src/locale/**` owns every athlete name and outfit name — the data carries keys, not text, and this slice adds no strings; `godot/src/audio/**` owns every sound; `godot/src/view/camera/**` (owned by [3D camera and feel integration into the slice](camera-feel-integration.md)) owns how a body is framed, and this slice does not tune the camera around a model. The simulation's `stats` and `special.cooldown` values are read from `godot/src/sim/frozen.gd` and are never re-declared.

## File ownership / allowlist

New files this ticket creates:

- `godot/src/athlete/AthleteRig.gd` and `godot/src/athlete/AthleteRig.tscn` — one rigged scene, instantiated per athlete, with the mesh instance, the skeleton and the animation player
- `godot/src/athlete/AthleteImport.gd` — the import and validation step: loads a GLB, asserts joint count, material count and triangle count against a recorded expectation, and fails loudly on a mismatch instead of loading a partially-parsed mesh. The engine-side version of `tools/character/glb_tri_count.py`
- `godot/src/athlete/LocomotionSet.gd` — the locomotion clips, mapped by role (`idle`, `walk`, `run`) with an explicit `null` for any clip that does not exist. The base rig has no idle clip; the set must be able to say so rather than substitute one
- `godot/src/athlete/StrokeLibrary.gd` — the Godot-authored padel strokes (serve, forehand, backhand, volley, smash, lob), per the confirmed animation split
- `godot/src/athlete/Retarget.gd` — the retarget path from the imported humanoid skeleton onto the authored strokes, with a stated joint map, not an implicit one
- `godot/src/athlete/OutfitResolver.gd` — resolves an outfit id to a set of material/texture overrides on one model, using `js/data.js`'s 26-entry table as the name and colour source; returns the base look explicitly when an outfit has no preview
- `godot/src/athlete/Recolour.gd` — the runtime-side recolour application, matching whatever the offline tool produces, and asserting the fur guard is untouched
- `godot/tests/athlete_import_audit.gd` and `.tscn` — the import contract per GLB
- `godot/tests/athlete_recolour_audit.gd` and `.tscn` — the ported form of the remaining pipeline item: two outfits, one model, one render, a measured difference above a stated floor
- `godot/tests/athlete_roster_audit.gd` and `.tscn` — the roster table: six athletes, their frozen stats read from `frozen.gd`, 26 outfit entries with the right per-athlete counts, and the base-outfit case handled explicitly
- `godot/tests/athlete_retarget_audit.gd` and `.tscn` — the locomotion clip and one authored stroke actually animate the imported skeleton
- `godot/tests/capture_athletes.gd` — the capture harness
- `godot/shots/athlete-<id>.png` and `godot/shots/athlete-recolour-ab.png`, plus an append to `godot/shots/README.md`
- `docs/implementation/evidence/s7-*` — the evidence files listed below

Must not be touched by this ticket: `js/` (any file), `scripts/` (any file), `meshy/` (read-only: the trial assets are read, and the URLs inside `rig_final.json` are never quoted), `tools/character/` (read-only, and **no regeneration**: the stronger outfit targets already exist and re-running the generator would change the variable under test), `godot/src/sim/` (owned by [Sim core parity](sim-core-parity.md); `stats` and `cooldown` are read from `frozen.gd`), `godot/src/arena/**` (owned by [Nine arenas in 3D](nine-arenas.md)), `godot/src/ui/**`, `godot/src/locale/**`, `godot/src/audio/**`, `godot/src/input/**`, `godot/src/view/camera/**`, `godot/prototypes/` (read-only: the two character prototypes are references, and their projects are not this slice's to edit), and `godot/src/view/PlayerRig.gd` (owned by [Quick-match vertical slice in 3D](quick-match-slice.md), which reuses one rigged body four times).

## Inputs and outputs

Inputs:

- The roster order and the credit cap from [Athlete roster order](../../wayfinder/tickets/athlete-roster-order.md). Until they land, the slice builds its import, retarget, recolour and audit paths against the one existing rig, and the per-athlete work waits.
- The recolour route's remaining proof from [Character pipeline economics](../../wayfinder/tickets/character-pipeline-economics.md), consumed, not re-derived.
- The six frozen `stats` blocks and special cooldowns, read from `godot/src/sim/frozen.gd`. A model that changes a stat is a re-tune.
- The 26-entry outfit table, read from the same frozen data. The engine does not re-type it.
- The existing assets: six athlete portraits, twenty outfit previews, the trial rig and its two locomotion GLBs, and the two offline outfit texture sets (`outfits.json`, `outfits-strong.json`).

Outputs:

- One rigged athlete scene, instantiated per roster member, with an explicit `idle`-is-null capability rather than a fabricated idle.
- Locomotion clips retargeted from the imported skeleton, and Godot-authored strokes retargeted onto it, both proven by a headless animation assertion and by a capture.
- One recolour render with two outfits from one model, with the measured difference reported as a number next to a stated floor — the number that closes the pipeline ticket's remaining item, or the honest statement that the floor is not met and why.
- A roster table render: each athlete's look, its outfit set and its frozen stats, one capture each, in Luca's order.
- An import contract per GLB: joint count, material count, triangle count, and a loud failure on mismatch.

Explicitly not output: new athletes, a seventh roster member, Volpe promoted by anything other than Luca's decision, new outfits beyond the 26, any Meshy credits spent, any re-run of the outfit generator, and any claim that the recolour route is proven before the render exists. The mesh defects recorded in `meshy/rigged/RESULT.md` — fused fingers and toes, the tail/shorts seam, leg texture smearing — are checked in engine here and reported, not silently ignored.

## Tests

There is no web audit for 3D characters; the web build's athlete check is sprite-path bookkeeping, which the 3D route retires. The audits that bear on this slice, by real file name under `scripts/`:

- `scripts/assets-audit.mjs` — every image named in code exists. The Godot equivalent is load-time plus an explicit assertion that every athlete's declared textures resolve, which the import audit makes.
- `scripts/outfit-assets-audit.mjs` and `scripts/outfit-challenges-audit.mjs` — the 26-entry outfit set and its challenge wiring. The roster audit reproduces the **counts** (6 base plus 20 unlockable, per athlete 5/5/5/5/3/3) from the frozen data, so a 3D route that loses an outfit fails the same promise the web suite already holds.
- `scripts/unlockable-animation-audit.mjs` — a sprite-sheet promise that does not port; its replacement is the retarget audit, since the thing being replaced is animation coverage.
- `scripts/modules-audit.mjs` and `scripts/module-contract-audit.mjs` — the replacement stays the headless load with zero script errors.

Godot-side equivalents:

- `godot/tests/athlete_import_audit.gd` — for each GLB: joint count, material count, triangle count and texture presence asserted against a recorded expectation; a mismatch is a failure, never a warning. This is also where the `RESULT.md` mesh defects are checked rather than assumed.
- `godot/tests/athlete_retarget_audit.gd` — asserts that a locomotion clip and at least one authored stroke each move the imported skeleton, that the stroke's key times advance across a tick, and that a missing clip (`idle`) is reported as missing rather than substituted.
- `godot/tests/athlete_recolour_audit.gd` — renders one model twice with two outfit sets, measures the difference the same way the offline analysis does (whole-model mean absolute difference, plus the largest garment-window shift), and asserts it clears a floor. The floor is chosen before the run and stated; if the stronger target set predicts about 3.74/255 and the measured value lands below, that is a reported finding against the authoring coverage, not a widened floor.
- `godot/tests/athlete_roster_audit.gd` — six athletes read from `frozen.gd`, their `stats` and `cooldown` values asserted against `frozen/data.json`, the 26 outfit entries counted per athlete, and the base-outfit case (no preview file) asserted explicitly.
- `godot/tests/capture_athletes.gd` — one capture per athlete under one camera preset, plus the two-outfit comparison frame.

## Execution commands

Pinned binary `/root/tools/godot/Godot_v4.7.2-stable_linux.x86_64` (4.7.2.stable.official, `ed1daf0bf`). Godot is the heavy process on this host and this slice is the heaviest of the ticket set — the character-material prototype measured about 380 MB peak RSS for one render — so every invocation is wrapped in the shared lock and the capture loop runs one render at a time, never in parallel.

The four headless audits:

```sh
cd /root/projects/steam-circuit-padel-pro && for a in athlete_import_audit athlete_roster_audit athlete_retarget_audit; do \
  flock -w 900 /tmp/padel-godot.lock \
  env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 timeout 300 \
    /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
    res://tests/${a}.tscn > docs/implementation/evidence/s7-${a//_/-}.log 2>&1; \
  echo "$a exit=$?"; grep -E '^(FAIL|PASS)' docs/implementation/evidence/s7-${a//_/-}.log; \
done
```

The recolour render — a real rendering context, one process, the shared lock held:

```sh
cd /root/projects/steam-circuit-padel-pro && \
  flock -w 900 /tmp/padel-godot.lock \
  env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 timeout 600 xvfb-run -a \
    /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path godot/ --rendering-driver opengl3 \
    res://tests/athlete_recolour_audit.tscn -- \
    --outfit-a=tools/character/out/outfit-a.png --outfit-b=tools/character/out/outfit-b.png \
    > docs/implementation/evidence/s7-recolour.log 2>&1; echo "exit=$?"
```

Per-athlete captures, sequentially, one lock acquisition each:

```sh
cd /root/projects/steam-circuit-padel-pro && for id in maestro pantera steamer fiamma oracolo colosso; do \
  flock -w 900 /tmp/padel-godot.lock \
  env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 timeout 600 xvfb-run -a \
    /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path godot/ --rendering-driver opengl3 \
    res://tests/capture_athletes.tscn -- --athlete=${id} --preset=playable \
    >> docs/implementation/evidence/s7-capture.log 2>&1 || echo "CAPTURE FAILED: ${id}"; \
done; echo done
```

The prototype route this slice reuses, run once as the provenance check:

```sh
cd /root/projects/steam-circuit-padel-pro/godot/prototypes/character_material && \
  flock -w 900 /tmp/padel-godot.lock ./render.sh 1280x720 2>&1 | tail -5
```

The frozen data and the recolor provenance this slice must not change, printed for the record:

```sh
cd /root/projects/steam-circuit-padel-pro && \
  python3 tools/character/glb_tri_count.py 2>&1 | tail -5; \
  sha256sum meshy/rigged/volpe/volpe-rigged.glb; \
  sed -n '1,20p' tools/character/out/PROVENANCE.md
```

## Expected evidence

- `docs/implementation/evidence/s7-athlete-import-audit.log`, `s7-athlete-roster-audit.log`, `s7-athlete-retarget-audit.log` — each with an exit code and a `PASS n/n` line, with the per-GLB joint, material and triangle numbers printed.
- `docs/implementation/evidence/s7-recolour.log` — the recolour render's exit code, the two source textures with their hashes, the measured whole-model difference and the largest garment-window shift, the pre-declared floor, and the verdict against it.
- `docs/implementation/evidence/s7-capture.log` — one line per athlete: id, outfit, stats source, camera preset, tick and rendering driver.
- `godot/shots/athlete-maestro.png` and the other five, plus `godot/shots/athlete-recolour-ab.png` — 1280x720, one camera preset.
- `godot/shots/README.md` — appended: preset, scale and the software-GL caveat.
- `docs/implementation/evidence/s7-athlete-notes.md` — the joint map used by the retarget, the locomotion clips present and the clips absent (an idle clip does not exist), the mesh defects found in engine with the ones from `meshy/rigged/RESULT.md` marked, whether Volpe was used only as a pipeline test asset, the roster order actually built, and the credits spent (zero, unless Luca names an arena and a cap).
- `docs/implementation/evidence/s7-recolour-verdict.md` — the one-item answer the pipeline ticket is waiting for: two visually distinct outfits from one model, or the measured reason they are not distinct, with the numbers and the discriminating statistic named. Written to be read by the ticket's owner, not as a claim of success.

What does not count as proof: an outfit difference described in words without the measured statistic; a sprite-path or preview-image comparison standing in for a render; a claimed idle clip; a triangle or joint count repeated from a previous chat rather than measured in engine; and any frame-rate claim.

## Failure and recovery criteria

Red means any of these:

- Any audit exits non-zero, or hangs and `timeout` kills it (exit 124).
- A GLB imports partially and is used anyway. A missing surface, a missing texture or a changed triangle count is a hard failure.
- The slice claims an idle clip, or substitutes a locomotion clip for one without saying so.
- An athlete's `stats` or special `cooldown` differs from `frozen/data.json`, or a stat is re-declared in an athlete file.
- The recolour test widens its floor after measuring, or reports a pass while the rendered difference stays at the order of magnitude the pipeline evidence already measured as a failure.
- A new athlete, a seventh roster member, a new outfit, or a Volpe promotion appears without Luca's decision.
- The slice spends credits, re-runs the outfit generator, or fetches anything from the Meshy lane.
- A relative URL or a signed download URL from `rig_final.json` appears in any log or evidence file.
- A file outside the allowlist changes, or `js/`, `scripts/`, `meshy/` or `tools/character/` changes at all.
- The recolour audit renders in parallel with another Godot process, or without the lock. The host has no swap and the neighbouring jobs are already memory-bound.

What stops the slice: a red audit after the retry rule below; the roster order not landing, in which case the import, retarget and recolour halves are still completed against the one rig and the per-athlete half is recorded as blocked rather than guessed; or the recolour render not dispatched because the host is memory-starved, which is a schedule blocker and is recorded as such rather than replaced with a weaker offline proxy.

Retry rule: two attempts per gate, then a blocker with the failing check, the log line and both attempts. No identical third retry; unrelated unblocked work continues.

Recovery paths worth trying before declaring a blocker: confirm the render uses `xvfb-run` with `--rendering-driver opengl3`, since `--headless` installs the dummy driver and a viewport capture under it is blank; put both copies at the same axis distance for the comparison so a view-dependent shading term is not mixed into the cross-copy number; confirm the recolour harness applies the override to a lit `StandardMaterial3D` on the duplicated `Material_1`, which is the mechanism the prototype already proved; confirm the roster audit reads counts from the frozen data rather than a hardcoded 26.

## Human gates that block this slice (open, owner Luca)

- **Athlete roster order** — which athletes become 3D models, in what order, the credit cap, and the Volpe fate (a seventh athlete is new scope; the trial asset is the default). This slice builds the pipeline on the one existing rig and presents the roster table; it does not choose the order and does not promote Volpe.
- **Character pipeline economics** — the recolour route's remaining item, an in-engine render of two visually distinct outfits from one model. This slice owns the engine half of that item and reports the measured result; whether the route is economically viable is Luca's, and the recommended default (do not assume recolouring is cheap, do not spend credits to find out) is respected.
