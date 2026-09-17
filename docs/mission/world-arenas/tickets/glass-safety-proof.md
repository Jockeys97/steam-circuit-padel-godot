# Glass-safety proof (scenery vs rear glass)

- Status: **resolved 2026-09-17** (measured-glass plane check + red control green, field law 88/88)
- Owner: proof engineer
- Depends on: [aurora-ridge-refinement](aurora-ridge-refinement.md) (final run on the post-refinement tree)
- Blocks: [final-rescore](final-rescore.md)

## Why

The codified field law is `z <= -8.0` (`FIELD_LAW_Z`), while the rear rebound glass sits at
`z = -10.0` and the backdrop wall / props at `-12.0` / `-11.65`. Current geometry satisfies
the stricter glass plane with ≥ 1.65 m margin, but no frozen gate asserts scenery-vs-glass
separation directly — as written, the law would also pass scenery that stopped between -8 and
-10, inside the play volume. Round 1 recorded this as its third-strongest doubt.

## Deliverable

- A non-vacuous proof (suite extension in `godot/tests/world_arenas*`, transformed vertices
  not inflated AABBs) that every scenery vertex stays behind the rear glass plane with margin,
  alongside the existing `z <= -8.0` law; document the three planes (-8.0 law / -10.0 glass /
  -12.0 wall) explicitly in the run manifest.
- No bound, tolerance or allowance relaxed; RED-run history kept, not deleted.

## Resolved when

- The new proof runs green in the serialized runner with tallies and log hashes journaled, and
  round 2 can cite the plane separation as proven, not assumed.

## Resolution (2026-09-17)

- `z<=-8` law untouched and still gated; ADDED an independent check against the MEASURED
  rear-glass plane from the real pane geometry (`-10.02`). Every scenery mesh stays behind it,
  per arena, closest meshes `-10.59`…`-11.13`; `GearRing` / `AccentPostL/R` classified as
  shared structural court dressing and covered by measurement; a `z=-9` red control is REJECTED
  by the glass check and PASSED by the `-8` law (5 REJECTED + 5 independence checks, all ok).
- Field law 88/88 in the official run (`refinement-01`) and in the parent re-run
  (`ceo-final-01`); log `proof/round2/logs/field_law.log` (sha256 `5e59eb6a…`, matches record).
- Cited by round 2 as proven plane separation: rows `wa-r2-*` (item 6) in `ccl-ledger.jsonl`.
