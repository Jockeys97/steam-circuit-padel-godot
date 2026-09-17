# World arenas — council review, round 2 (final re-score)

Written 2026-09-17 19:27 CEST by the docs-ledger lane (docs only; no source edits by this
record). Ledger: `ccl-ledger.jsonl` (10 rows: 5 round-1 + 5 round-2, one per arena per round).
**Status: technical and visual gates PASS on the frozen round-2 tree — protocol compliance
remains PARTIAL (no cross-family council), code/tests uncommitted on branch
`feat/native-world-arenas` (head `bcecd9bf7f2e3cf075e8b74d41417e30be924d88`), NOT merged, NOT
pushed, merge NOT authorized, owner taste unapproved. The original review contract is
therefore NOT fully complete.** The round-2 re-score is a **same-family review** (both
critic contexts: `opencode-go/deepseek-flash`), not the heterogeneous council the contract
prefers; the gap is recorded here and in every ledger row, never fabricated into diversity.

## What was reviewed, and on what contract

- Contract / rubric: `COUNCIL.md`, sha256
  `aea2971556bc10d0edc30ae5eb9c04f60f3644a4f35bf9a570dfd5827bb7982f` — **unchanged since
  round 1** (re-hashed at round-2 ledger-write time, byte-identical; 8 gating items, same
  contract). Round-1 rows' `rubric_fingerprint` and round-2 rows' agree.
- Frames (round-2 freeze): `proof/round2/captures/` — **15 arena PNGs + 1 menu PNG**, all
  1280x720, frozen from run `refinement-01`
  (`tools/world-arenas/out/refinement-01`: runner exit 0, `run green: True`, tree stable
  `6e0dad26fcce00fc -> 6e0dad26fcce00fc`, head `bcecd9bf`). 16 distinct hashes; hash list
  `proof/round2/captures/sha256.txt`
  (`9e3180079c4f57cefe9abf3cd6daa1244abb1759060fe9a13d198ac2264edb2c`); freeze record
  `proof/round2/CAPTURE_MANIFEST.md`
  (`1b476a91d96b8e86e73d654052cb4d389910c250e06c4691ae9ad8f81c6586c2`); run manifest
  re-hash `proof/round2/MANIFEST.json`
  (`574544d0d30afb465ebf2464752fd9b081a2979f822bdf7fc77478b9c37467a1`); run records
  `proof/round2/captures/captures.json`
  (`7ed2dbad2fb20fe59f388877f8bc2d0e736f8a5ca5adf8d54af56b7de3c367ab`) and
  `proof/round2/captures/menu_capture.json`
  (`e34b576f3c842c6f7cd6e11ba8163a2b6739ed593ecdfec505cb2631566ebeea`).
- Delta vs round 1 (verified from bytes, both freezes on disk): **only the three aurora
  frames changed** (`default`/`wide`/`playable`); **12 of 15 arena frames byte-identical**
  to `proof/captures/`; **round-1 freeze untouched — 15/15 hashes recomputed and matching**.
- Reference art (read-only, never imported at runtime): `art/concepts/world-arenas-r1/`,
  including its pre-existing modified `README.md` (sha256
  `478c104db61fe46d7e5d75860870ab1360a5ae62d34269e856b2cc37ecb0e7dd`) — preserved.
- Oracle: `tools/world-arenas/out/refinement-01/` (official round-2 run) plus the parent's
  personal independent re-run — command and tallies below.
- Preserved unrelated files (not deleted, not committed): `godot/=/` malformed-path debris,
  the generated/unrelated `.uid` sidecars (e.g. `world_arenas_capture.gd.uid`), and the
  concept README above.

## Reviewer identities and protocol gap

| critic | lens | model identity | result |
|---|---|---|---|
| critic-a | environmental art (palette/landmark vs concept briefs) | `opencode-go/deepseek-flash` | 8/8 PASS per arena |
| critic-b | gameplay/rendering (framing, glass, field law, selectability) | `opencode-go/deepseek-flash` | 8/8 PASS per arena |

Both critics were independent read-only contexts, never implementers; both re-hashed the
**16 frozen round-2 captures (15 arenas + menu)** and the **9 step logs** against their
records before scoring, and both re-read the frozen frames only. The auxiliary vision model
behind the critics' image reading is **unknown**; no family diversity is claimed. Exact
dispatch-prompt hash: **unavailable** (not preserved — recorded as unavailable, never
invented). Verdicts are relayed from the critic returns via the parent dispatch; this record
cross-checks their factual anchors (captures, tallies, hashes, paths) against the frozen
artifacts and does not re-invent per-item prose.

## Result matrix (round 2)

| arena | critic-a (8 items) | critic-b (8 items) | note |
|---|---|---|---|
| torii | PASS 8/8 | PASS 8/8 | `WORLD_PLAYTHROUGH ticks=31295 points=26` reproduces round 1 exactly |
| medina | PASS 8/8 | PASS 8/8 | full played match on record |
| carioca | PASS 8/8 | PASS 8/8 | full played match on record |
| aurora | PASS 8/8 | PASS 8/8 | **round-1 split settled**: refined frames; caps read bright and jagged, clearly visible across all three presets |
| egeo | PASS 8/8 | PASS 8/8 | full played match on record |

Arithmetic audit (computed with Python, not asserted): 5 arenas × 8 items = **40 verdicts per
critic → 40/40 each**; two critics → **80/80 total** for round 2; 10 arena-reviews; **16
captures** = 15 arenas × 3 presets + 1 menu chooser; oracle total
**342+293+88+14+18+8+111+9 = 883** checks (9 steps).

## Round-1 doubts — closed by evidence (or explicitly carried)

1. **Aurora snow ridge (lens split)** — CLOSED. Local `snowridge` refinement only (no camera
   touched, behind glass, inside the band); exactly the three aurora frames changed, 12/15
   round-1 frames byte-identical, change regions 0.43–1.41% of frame and strictly brighter.
   Round-2 art lens re-read: ridge clearly visible across all three presets.
2. **Playthrough coverage (1 of 5)** — CLOSED. **Five complete deterministic matches, one per
   arena**, one exact `WORLD_PLAYTHROUGH` line each: `ticks=31295 points=26` for torii,
   medina, carioca, aurora, egeo (selection 18/18 + demo 8/8). Identity across arenas is the
   expected determinism of the same provisional neutral `wallBounce` (0.89) and the same
   scripted match; each arena ran its own scene and its own 31,295 ticks.
3. **Glass-safety (law plane vs rear glass)** — CLOSED. `z<=-8` law untouched and still gated;
   ADDED a measured-glass plane check from the real pane geometry (`-10.02`): every scenery
   mesh behind it per arena (closest `-10.59`…`-11.13`); `GearRing`/`AccentPostL/R` classified
   as shared structural court dressing (built by `court_builder.gd` into every arena including
   the frozen nine) and covered by measurement; a `z=-9` red control is REJECTED by the glass
   check and PASSED by the `-8` law — the checks are independent. Field law `88/88`.

## Parent proof (personal re-run, not a relayed claim)

```
tools/world-arenas/run_proof.sh --baseline --run-id=ceo-final-01
```

Runner exit **0**; `run green: True`; `tree stable during run: True`
(`6e0dad26fcce00fc -> 6e0dad26fcce00fc`, 695 files, head `bcecd9bf`); **nine steps, all exit
0** — slice **342/342**, demo **293/293**, field law **88/88**, frame **14/14**, selection
**18/18**, selection demo **8/8**, capture **111/111**, menu capture **9/9**, import clean;
**zero `SCRIPT ERROR` lines** across all nine step logs (883 gated checks total). The
parent's run re-produced the 16 frozen captures byte-for-byte (16/16 match against
`proof/round2/captures/`; 15/15 arena + menu PNG identical) and re-verified the frozen 9 log
hashes from `MANIFEST.json` (`log_sha256_matches_record: true` on every step). Run dir:
`tools/world-arenas/out/ceo-final-01/` (`MANIFEST.json` sha256
`24671d6a4991c92fc35884f3748ce724c159f6839ef3e59d400bf65c23db8314`, `MANIFEST.md`
`9c1c92d3b0cab0ef209affcdcb3f22729afb313b67cd50ffff7ebd3a0936a23f`, `results.tsv`
`c97e681eacda05c01bae23171b1680f15b53ece84232e92b26ac1afbca863a9d`).

Re-verification done for this ledger (Python, from bytes on disk, no engine): all **16/16**
round-2 frozen hashes re-hash OK; the same 16 in `ceo-final-01/captures` equal the frozen
set (16/16); all **15/15** round-1 frozen hashes still match `proof/captures/sha256.txt`; the
9 frozen round-2 logs match their MANIFEST `log_sha256` records.

## Caveats carried (recorded, not smoothed)

- **Protocol: partial.** The requested heterogeneous cross-family council is unfulfilled
  (single-native-model constraint, recorded in `COUNCIL.md` and every ledger row). Technical
  and visual gates pass; the review contract itself does not.
- **Shutdown warnings are classified, not zero.** Engine shutdown emits `resources still in
  use at exit` (audio-stream census: `AudioStreamPlaybackWAV`/`AudioStreamWAV`, ObjectDB
  dominated by the same; `integrator.md` §9.7/§9.8) in baseline_demo and selection on
  `ceo-final-01` (baseline_slice/slice-demo/selection on `refinement-01`). Classified, no
  bound relaxed; `SCRIPT ERROR` stays 0.
- **Provisional physics.** `wallBounce 0.89`, `floorGrip 1.0`, `unlock: null` are
  provisional recommendations (library defaults / `officina` midpoints), NOT frozen balance —
  the owner must replace or accept them.
- **Shared structural dressing.** `GearRing` / `AccentPostL/R` are shared across all arenas
  including the frozen nine; classified and measured, not world-arena scenery.
- **Minor stylisation.** Critic notes: petals/steam simplified vs the concept stills — read
  as acceptable stylisation, recorded here rather than hidden.
- **Uncommitted.** All code/tests/proof live on uncommitted branch `feat/native-world-arenas`
  (untracked payload + modified working tree); **not merged, not pushed**; merge remains a
  separate, unauthorized decision.

## Budget

- Additional spend **$0** used of the $0 cap; no paid API calls, no provider changes;
  `inference_telemetry: null` ⇒ **cost unknown, not zero**.
- This ledger lane: zero engine runs, zero source edits, zero paid calls.

## Next actions (owner decision, not a claim)

Closure is handed to the owner as a **decision**: owner taste verdict + merge decision —
separate approvals, nothing auto-merges. The world set stays offered through the legacy menu
seam only (`ArenaScreen` UIR grid still pins the frozen nine); production `--capture=arenas`
not re-run (writes tracked evidence; wired statically).
