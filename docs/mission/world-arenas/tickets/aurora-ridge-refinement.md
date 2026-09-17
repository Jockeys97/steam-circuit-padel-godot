# Aurora ridge refinement

- Status: **resolved 2026-09-17** (round-2 art lens re-read: ridge clearly visible on all three presets)
- Owner: arena integrator (production writer)
- Blocks: [glass-safety-proof](glass-safety-proof.md), [five-playthroughs](five-playthroughs.md), [final-rescore](final-rescore.md)

## Why

Round 1 recorded a two-lens split on the Aurora snow ridge: the environmental-art lens reads
it unreadable in the frozen frames; the gameplay/rendering lens reads it visible. Both kept
the landmark item PASS, so it is a doubt, not a failure — the parent elected the one
refinement the contract allows to settle it before the final re-score.

## Constraints

- Improve ridge legibility on aurora only, within `godot/game/arenas/`; no camera-preset
  edits, no frozen roster or demo-restriction changes, no bound/tolerance relaxed anywhere.
- Other arenas must not regress; if shared builder code changes, all four others re-run green.
- Old freeze is superseded, never deleted: keep `proof/captures/` round-1 frames and hashes.

## Evidence to produce

- A fresh serialized proof run (new run-id) with all 8 steps green — same tallies except the
  capture hash set (new aurora hashes expected) — journaled in `tools/world-arenas/out/`.
- Fresh frozen captures + manifest for round 2 to score.

## Resolved when

- Both same-family lenses re-read the new aurora frames and agree (ridge legible, or it is
  explicitly carried to the owner as stylised); round 2 consumes the new freeze.

## Resolution (2026-09-17)

- Refinement landed in the `snowridge` branch only (rock lifted one step, caps larger
  `0.38r/0.40h -> 0.52r/0.46h` and brighter); `_peak` and every other arena untouched; no
  camera preset edited; container stays at table z `-11.65`, behind the `-10.02` glass.
- Measured: exactly the three aurora frames changed vs round 1 (12/15 arena frames
  byte-identical; changed regions 0.43–1.41% of frame, strictly brighter); frame suite 14/14 and
  capture suite 111/111 still green with worst margins unchanged.
- Round-2 re-score: both critics kept landmark item PASS; the art lens re-read the refined
  frames and reads the snow-ridge caps clearly visible (bright, jagged) across all three
  presets — the round-1 split is settled by evidence. Row `wa-r2-aurora` in `ccl-ledger.jsonl`.
