# World arenas map

Updated 2026-09-17 19:27 CEST. Current frontier: round-2 re-score recorded (same-family,
80/80 all-pass on the frozen round-2 tree; round-1 doubts closed by evidence). One refinement
spent; no further scoring rounds. **Technical/visual gates pass; protocol compliance stays
PARTIAL (no cross-family council).** Nothing committed or pushed; no merge authorized. The
frontier is now the owner's closure decision, not engineering work.

- **Arena integrator** — owned `tickets/aurora-ridge-refinement.md`; landed the local snowridge
  refinement (3 frames changed, 12/15 identical); re-freeze done. **[done; resolved]**
- **Proof engineer** — owned `tickets/glass-safety-proof.md` and `tickets/five-playthroughs.md`;
  both delivered on the post-refinement tree (measured-glass check + red control; five complete
  matches). **[done; resolved]**
- **Council round 2** — owned `tickets/final-rescore.md`; rows `wa-r2-*` appended to
  `ccl-ledger.jsonl`, record `review-round2.md`; same-family gap recorded again; no split to
  tie-break. **[done; resolved]**
- **Closure** — owner taste verdict + merge decision. **[not started; no merge authorized]**

Edges: `aurora-ridge-refinement` → {`glass-safety-proof`, `five-playthroughs`} →
`final-rescore` → closure decision. All four upstream tickets resolved 2026-09-17; the closure
edge is the only one open, and it is a human decision.

Fog: cross-family council capacity (single-native-model constraint — evidence gap, recorded
not fabricated); owner taste; whether the UIR `ArenaScreen` grid gains world rows (today the
legacy menu seam only); whether the owner accepts or replaces the provisional physics
(`wallBounce 0.89`); who stages/authorizes any future merge (today everything is uncommitted
on `feat/native-world-arenas`).
