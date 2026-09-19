# Arena props, all five worlds — log

## 2026-09-19 — charter

Event: CEO wrote the charter. Full set across five arenas, mounted, decluttered, plus a 2D plan.
Owner: CEO
Status: open
Handle: `docs/mission/arena-kit/arena-props/CHARTER.md`

## 2026-09-19 — wave one dispatched

Event: Captain A (generation) and Captain B (pre-viz) in parallel, disjoint file ownership. Captain C (mount and declutter) sequenced after A because the mount proof needs the GLBs.
Owner: CEO
Status: dispatched
Handle: `deleg_e404fb4e`

## 2026-09-19 — gate 1, generation, verified

Event: Forty GLBs generated on the first attempt, four arenas times ten slots. Parent verified independently: parsed all fifty GLBs' own JSON chunks (every one carries a base-colour texture), recounted the ledger at 600 credits, and re-read the live balance at 1697, matching the ledger delta from 2297.
Facts: fifty GLBs on disk, 43 to 49 MB per arena folder, triangles 3378 to 4432 against a 4000 target, 229 MB total. No retries, no failures. Approved spend used exactly.
Owner: CEO
Status: gate 1 passed
Handle: `LEDGER.jsonl`, `GEN-RESULT.md`, `godot/assets/arenas/*/**.glb`

## 2026-09-19 — gate 2, 2D pre-viz, verified

Event: Five arena plans plus a combined sheet, built from a headless dump of the engine's own `SPECS` table rather than hand-copied numbers. Parent recounted the instances directly from the dump: torii 27, medina 31, carioca 30, aurora 28, egeo 29, total 145, matching the plan exactly. Recomputed every footprint's front and back face: worst front face anywhere is -10.20, so nothing crosses the field-law plane at -8.0 and nothing crosses the glass at -10.02; no declared depth exceeds the 3.26 m budget. The HTML is self-contained with six embedded images and no external references.
Owner: CEO
Status: gate 2 passed
Handle: `previz/index.html`, `previz/*-plan.png`, `previz/arena_kit_specs.json`, `PREVIZ-RESULT.md`

## 2026-09-19 — findings carried forward, not hidden

Finding 1: ten instances, the hero landmark and the vegetation cluster in every arena, have declared back faces at -12.15 to -12.50, i.e. behind the backdrop wall at -12.0. The depth budget is gated on the glass rather than the backdrop, so this passes the written rule. Whether the landmark should be half-buried in the backdrop is Luca's call.
Finding 2: the engine scales x by the running preset, so instances sit at authored x times 1.34375 under the default preset and the frame law is drawn at plus or minus 19.283 in world space.
Finding 3: the plan draws each slot's declared width from its footprint note, because the spec entry carries a depth but no width field. Real Meshy meshes will not be exactly that wide. Captain C's census measures the real mounted boxes, which closes this gap.
Owner: CEO
Status: open
Handle: `PREVIZ-RESULT.md`, `CENSUS.md`

## 2026-09-19 — wave two dispatched

Event: Captain C turns suppress on where a mounted GLB doubles its procedural counterpart, proves the doubling with measured numbers before and after, censuses real mounted bounding boxes, and keeps the frozen arena suites green. Anchors and repeat counts are frozen; only suppress may change, so the plan above stays valid.
Owner: CEO
Status: dispatched
Handle: `deleg_621c3df7`

## 2026-09-19 — gate 3, mount, verified with four red gates carried forward

Event: Clutter fixed. Captain C measured the doubling first: sixteen slots carried both a procedural prop and a mounted GLB, standing 296 procedural meshes beside 145 mounted pieces. After the suppress flip that is zero slots and zero stray meshes, with all 145 mounted pieces unchanged. The parent verified the flags directly in the table, sixteen true and thirty-four false, none of them true with an empty kinds list, and confirmed all fifty GLBs are still sha256-identical to the pre-run fingerprint. Suppression only touched the sixteen slots that had a procedural counterpart.
Passing: mount height against spec, frame law, material policy, culling inside the 1280x720 frame.
Owner: CEO
Status: gate 3 partially passed, four gates red
Handle: `CENSUS.md`, `PROPS-RESULT.md`

## 2026-09-19 — the real defect, measured

Event: The Meshy meshes are deeper than the spec table assumed. Seventeen mounted pieces push forward through the rear glass at -10.02 and overlap the court volume, worst front face at -8.99. The parent reproduced this independently: the field-law suite reads FAIL 79/88 with zero script errors, down from a green 88/88 in the pre-kit proof runs. Root cause is geometric, not a coding error: the usable band between the glass at -10.02 and the backdrop wall at -12.0 is under two metres, while the offending pieces measure 2.4 to 3.9 metres deep. A piece cannot both stay behind the glass and stay fully in front of the wall.
Decision: pull the offending anchors back rather than shrink the pieces, because scale changes what the owner already approved. Pieces that end up embedded in the backdrop wall get reported instead of silently resized.
Owner: CEO
Status: fix dispatched
Handle: `deleg_fc97262d`, `BRIEF-FIT.md`

## 2026-09-19 — nobody has seen the 3D yet

Event: Every pass so far is headless geometry. The arena visuals have never been rendered, so the owner's look verdict cannot be made from the numbers. Wave three renders five 1280x720 captures and regenerates the now-stale 2D plan, since anchors are moving.
Owner: CEO
Status: in flight
Handle: `captures/`

## 2026-09-19 — gate 4, placement fit, verified

Event: Eight anchors moved, all backwards in z, x and y untouched, totalling 3.91 m. The parent confirmed this from the diff itself: only anchor z values and the declared depths changed, and target_h, repeats, spread, suppress and kinds are unchanged. All fifty GLBs still sha256-identical. Glass and court gates now pass, worst front margin per arena between 5 and 10 cm behind the glass at -10.02, zero pieces over the playable footprint.
The headline gate is green on the parent's own run, not the captain's: field law PASS 88/88, exit 0, zero script errors, up from FAIL 79/88. The remaining ERROR lines in that log are the dummy-renderer shutdown leaks that every headless run prints, classified not ignored.
Also green: frame 14/14, selection 18/18 and 8/8 demo, arena selector 30/30, screen audit 180/180. The declared depth now equals the measured mesh for all fifty slots, and the plan was rebuilt from a fresh engine dump at 145 instances.
Owner: CEO
Status: gate 4 passed
Handle: `FIT-RESULT.md`, `captures/`, `previz/`

## 2026-09-19 — open for the owner

Finding 1: seven pieces in four slots still exceed the 3.26 m depth budget, because the models themselves are deeper than the band between the glass and the backdrop: carioca hero landmark 3.71 m, carioca ornament 3.62 m across four repeats, aurora hero landmark 3.84 m, egeo hero landmark 3.93 m. This cannot pass without changing a model's size, which the brief forbade. Options are to accept, rescale in engine, or regenerate those four models at 15 credits each.
Finding 2: twenty-three pieces now have their back face behind the backdrop wall at -12.0. Ten were already there before this pass, thirteen are newly behind because clearing the glass required moving them back. The deepest is egeo's hero landmark, 2.01 m past the wall. No camera looks there, so it is likely invisible, but the owner's eye decides.
Owner: Luca
Status: awaiting verdict
Handle: `FIT-RESULT.md`, `captures/default/arena-*.png`
