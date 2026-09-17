# World arenas — board

Updated 2026-09-17 19:27 CEST by the docs-ledger lane, after the round-2 re-score was recorded.
Ledger: `ccl-ledger.jsonl` (10 rows) · Reviews: `review-round1.md`, `review-round2.md` · Map: `MAP.md` · Tickets: `tickets/`

**Status: round-2 re-score recorded — technical/visual gates PASS on the frozen round-2 tree, but
protocol compliance is PARTIAL (no cross-family council) and the work is uncommitted: NOT merged,
NOT pushed, merge NOT authorized. The original review contract is NOT fully complete. Owner taste:
unapproved.**

The five world arenas are built, selectable, playable on all five, captured across three presets
plus the real menu chooser, and passed the final same-family re-score (80/80 item verdicts on the
round-2 freeze). The one authorised refinement is spent; round 2 was the final scoring pass.
Owner taste remains unapproved but does not block this run. Merge requires separate authorization; the cross-family review requirement remains unmet.

## Shipped

- Five native world arenas (torii, medina, carioca, aurora, egeo) as port additions — frozen
  roster of nine untouched, demo restrictions preserved; provisional neutral physics documented
  as a recommendation, not invented balance.
- Selection seam: content gate / match config / legacy menu world row / capture enumeration;
  **five complete deterministic playthroughs, one per arena**.
- Proof tooling: field-law, frame, selection and capture suites + serialized runner
  (`tools/world-arenas/run_proof.sh`) + manifests that re-hash every PNG from bytes; new
  measured-glass safety check with a `z=-9` red control; new real-viewport menu capture step.
- Aurora snow-ridge refined locally (three aurora frames changed, 12/15 round-1 frames
  byte-identical); round-1 freeze preserved, untouched.

## Verified (evidence, not claims)

| claim | evidence (path) |
|---|---|
| Round-2 oracle green, 9 steps all exit 0: slice 342/342, demo 293/293, field law 88/88, frame 14/14, selection 18/18, selection-demo 8/8, capture 111/111, menu capture 9/9 = **883 checks, zero `SCRIPT ERROR`** | `tools/world-arenas/out/refinement-01/` and the parent's personal re-run `tools/world-arenas/out/ceo-final-01/` (command: `tools/world-arenas/run_proof.sh --baseline --run-id=ceo-final-01`) |
| 16 captures frozen, 1280x720, 16 distinct hashes; re-verified from bytes (16/16 in `proof/round2/captures` and 16/16 matching in `ceo-final-01/captures`); round-1 15/15 unchanged | `proof/round2/captures/sha256.txt`, `proof/round2/CAPTURE_MANIFEST.md`; round 1: `proof/captures/sha256.txt` |
| Council round 2: 5 arenas × 2 critics × 8 items = **80/80 PASS** — **same-family only**, not the heterogeneous council requested; gap explicit; rubric hash unchanged | `ccl-ledger.jsonl` (rows `wa-r2-*`), `review-round2.md` |
| Five complete matches — one exact `WORLD_PLAYTHROUGH` per arena, `ticks=31295 points=26` each | `proof/round2/logs/selection.log`; `tools/world-arenas/out/ceo-final-01/logs/selection.log` |
| Round-1 doubts closed: aurora split (refined frames, ridge legible on all presets), glass-safety (measured plane `-10.02` + red control), playthrough coverage (5/5) | `refinement.md` §4–§7, `proof/round2/logs/{field_law,selection}.log` |
| RED → green history kept, not hidden (menu-fit regression + 2 proof-mechanics defects, fixed on evidence, no bound relaxed) | `tools/world-arenas/out/resume-01/` (RED.md), `-02/`, `-03/`; `integrator.md` §9.8 |

## Open (gaps, not failures)

- **Cross-family council capacity: unfilled** — single native model constraint; permanent
  evidence gap, recorded everywhere, never fabricated into a diverse council. Protocol
  compliance stays PARTIAL even though technical/visual gates pass.
- **Uncommitted**: all code/tests/proof on branch `feat/native-world-arenas` (head `bcecd9bf`),
  not merged, not pushed; merge is a separate, unauthorized decision.
- **Owner taste verdict** pending (never self-approved); UIR `ArenaScreen` grid still pins the
  frozen nine (world set offered via the legacy menu seam only); production `--capture=arenas`
  not re-run (writes tracked evidence; wired statically).
- **Warning caveats (existing, classified)**: shutdown `resources still in use at exit`
  (audio-stream class) appears in some suites — classified in `integrator.md` §9.7/§9.8, not a
  new leak; not zero warnings, `SCRIPT ERROR` 0. Provisional physics (`wallBounce 0.89`,
  `floorGrip 1.0`, `unlock: null`) remain recommendations for the owner. Minor stylisation
  notes (petals/steam vs concept stills) recorded. Shared `GearRing`/`AccentPostL/R`
  structural dressing classified and measured.

## Blocked

- Technical execution is finished. Cross-family review remains unavailable under the mandated native model. No taste approval stop applies. Nothing auto-merges.

## Budget

- Additional spend: **$0 used of $0 authorized**. No paid calls, no provider changes.
- Inference on the existing opencode-go subscription; telemetry unavailable ⇒ **unknown, not
  zero**. This board's lane: zero engine runs, zero source edits.

## Open decisions

- Round-1 parent decision (refine once despite all-pass) is spent; round-2 re-score is the last
  scoring pass. No tie-break needed (no scored split in round 2).
- Closure sequence: owner taste verdict and the merge decision are separate approvals.

## Next action

1. **Owner** — taste verdict on the frozen round-2 frames (`proof/round2/captures/`, incl. the
   menu chooser frame); then the merge decision.
2. If merge is authorized: stage the untracked payload explicitly (no `git add -A`), preserving
   `godot/=/` debris, unrelated `.uid` files and the modified concept README as recorded.
