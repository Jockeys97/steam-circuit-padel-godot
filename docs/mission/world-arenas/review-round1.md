# World arenas — council review, round 1

Written 2026-09-17 18:57 CEST by the docs-ledger lane (docs only; no source edits by this
record). Ledger: `ccl-ledger.jsonl` (5 rows, one per arena). **Status: technical gates green
pre-refinement — NOT mission complete, NOT merge-approved.** The round-1 scoring is a
**same-family review**, not the heterogeneous council the contract prefers; the gap is
recorded here and in every ledger row. Owner taste: unapproved.

## What was reviewed, and on what contract

- Contract / rubric: `COUNCIL.md`, sha256 `aea2971556bc10d0edc30ae5eb9c04f60f3644a4f35bf9a570dfd5827bb7982f`
  (8 gating items; fingerprint taken at ledger-write time — the directory is untracked, so no
  earlier revision exists to compare against).
- Frames: `proof/captures/{default,wide,playable}/arena-{torii,medina,carioca,aurora,egeo}.png`
  — 15 PNGs, all 1280x720, 15 distinct hashes, frozen from run `resume-04`
  (`tools/world-arenas/out/resume-04`: runner exit 0, `run green: True`, tree stable
  `9661fc8add2d1908 -> 9661fc8add2d1908`, head `bcecd9bf`).
  Hash list: `proof/captures/sha256.txt` (`11fd0128183dfb75e5099bbce5e740b89f4b90092a7a8cf1c9aa6add5b859098`);
  freeze record: `proof/CAPTURE_MANIFEST.md`
  (`935e85a24805a01614ba673780b177f05289055b1ba32639d0d78f2a5ec9f7af`);
  run manifest re-hash: `proof/captures/MANIFEST.json`
  (`114a393b8354bfc92f1daa1820d4508e62dd831c31124d257a36a1340b65dd17`);
  run record: `proof/captures/captures.json`
  (`d9e01561a81fdd6363fee43cf4fe7dc2c56f4bd4684d33eadf61e4e7e9f245f3`).
- Reference art (read-only, never imported at runtime): `art/concepts/world-arenas-r1/`.
- Oracle: `tools/world-arenas/out/resume-04/` (results.tsv, per-step logs): 8 steps, **all
  exit 0** — slice **342/342**, demo **293/293**, field law **63/63**, frame **11/11**,
  selection **13/13**, selection-demo **8/8**, capture **111/111** = **841 checks**; plus the
  parent's independent re-run `tools/world-arenas/out/ceo-verify-01/` — same 8 steps, same
  tallies, all exit 0, `run green: True`, same tree digest.
- Re-verification done for this ledger (Python, from bytes on disk, no engine): all **15/15**
  frozen hashes re-hash OK in `proof/captures/`, and the 15 captures in **both** `resume-04/`
  and `ceo-verify-01/` equal the frozen set **15/15** — the parent's check reproduced.

## Reviewers and identities

| critic | lens | model identity | result |
|---|---|---|---|
| critic-a | environmental art (palette/landmark vs concept briefs) | `opencode-go/deepseek-flash` | 8/8 PASS per arena |
| critic-b | gameplay/rendering (framing, glass, field law, selectability) | `opencode-go/deepseek-flash` | 8/8 PASS per arena |

Both critics ran the mandated native delegation model — one family. The auxiliary vision model
behind the critics' image reading is **unknown**; the review therefore cannot claim family
diversity, and none is claimed. Exact dispatch-prompt hash: **unavailable** (not preserved in
the repo — not invented). Verdicts are relayed from the critic returns via the parent dispatch;
this record cross-checks their factual anchors (captures, tallies, hashes, paths) against the
frozen artifacts and does not re-invent per-item prose.

## Result matrix (round 1)

| arena | critic-a (8 items) | critic-b (8 items) | note |
|---|---|---|---|
| torii | PASS 8/8 | PASS 8/8 | full played match on record (`WORLD_PLAYTHROUGH arena=torii ticks=31295 points=26 result={"winner":"ai"}`) |
| medina | PASS 8/8 | PASS 8/8 | |
| carioca | PASS 8/8 | PASS 8/8 | |
| aurora | PASS 8/8 | PASS 8/8 | **snow-ridge lens split recorded** (see below); art lens kept the landmark item PASS |
| egeo | PASS 8/8 | PASS 8/8 | |

Arithmetic audit (computed with Python, not asserted): 5 arenas × 8 items = **40 verdicts per
critic → 40/40 each**; two critics → **80/80 total**; 10 arena-reviews; **15 captures** =
5 arenas × 3 presets; oracle total **342+293+63+11+13+8+111 = 841**.

## Strongest disconfirming evidence (recorded, not hidden)

1. **Aurora snow ridge — split verdict.** The art lens reads the snow ridge as unreadable in
   the frozen frames, while the engineer lens reports it visible; the art lens still marks the
   landmark item overall PASS. Two same-family lenses disagreeing on the same pixels means the
   item is not independently settled.
2. **Playthrough coverage: 1 of 5.** The only end-to-end played match in evidence is on torii
   (selection preflight log; the same section runs green in the sweep). The other four arenas
   are proven selectable and built (`selection` 13/13 + demo 8/8) but were never played to a
   result — item 7's PASS for them rests on that generalization.
3. **Law-plane margin.** The codified field law is `z <= -8.0` (`FIELD_LAW_Z`), but the rear
   rebound glass sits at `z = -10.0` (backdrop wall `-12.0`, props `-11.65`). Current geometry
   satisfies the stricter glass plane with ≥ 1.65 m margin, yet no frozen gate asserts
   scenery-vs-glass separation directly — a static check would also pass scenery stopping
   between -8 and -10, inside the play volume. Ticket `glass-safety-proof` requires the proof
   instead of leaving it implicit.

## Parent decision (round 1 → round 2)

- All-pass kept; **no arena retired**; no tie-break was needed for scored items (the contract
  requires an independent tie-break for splits, never averaging — none arose at verdict level).
- Parent elected the **one refinement** the contract allows — improve the Aurora ridge and close
  the proof-coverage gaps (glass-safety proof, five playthroughs) — then the final re-score,
  which is the last scoring pass before closure.
- **No merge authorized.** Nothing committed or pushed; working tree as the lanes left it.

## Budget

- Additional spend **$0** used of the $0 cap; no paid API calls, no provider changes.
- Inference ran on the existing opencode-go subscription (native delegation, deepseek-flash);
  telemetry unavailable ⇒ **cost unknown, not zero**. This ledger lane: zero engine runs, zero
  source edits, zero paid calls.

## Next actions (tickets, with dependency edges)

`aurora-ridge-refinement` (integrator) → `glass-safety-proof`, `five-playthroughs` (proof
engineer, on the post-refinement tree) → `final-rescore` (council round 2) → closure decision
(owner taste + merge — separate approvals).
