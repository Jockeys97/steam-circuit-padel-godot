# Arena kit image batch — notes (agent lane, 2026-09-18)

Deliverable of the image-batch subagent. Owner-facing page: `art/arena-kits/INDEX.md`.
Machine-side: `tools/arena-kit/gen_assets.py` (+ `build_packs.py`, `prompts/*.json`).

## Outcome

- 55/55 slot images delivered (`art/arena-kits/<arena>/<slot>.png`), all 1024×1024 PNG,
  all passing the KIT-STANDARD §4 checklist (programmatic + visual).
- Ledger `art/arena-kits/image-spend.json`: cap raised **60 → 66**; **57/66 used, 9 left**;
  0 failed calls. 2 single regenerations (torii/ground_dressing margin, egeo/ground_dressing
  subject mismatch); replaced attempts archived in `<arena>/_rejected/`.
- Parent probe `torii/hero_landmark.png` reused untouched (sha256 matches ledger call 1).

## Open questions answered (from image-prototyping.md Appendix A)

1. *Reference still as `reference_image_urls` — palette vs scene drag?* **Keeps the
   palette (vermilion/indigo/gold), drags no scene content** — verified once on
   `torii/gate_portal`, which is the delivered image. n=1.
2. *White subject on white for egeo?* **Survives** when the subject carries a
   non-white edge (pale grey-stone base course + cobalt dome/doors/trim). Silhouette
   *acceptable*, not bold. No transparent-background pass needed for this batch.
3. Square 1024 (answered by the parent probe) confirmed across all 57 calls.

## Decisions recorded here so nobody re-argues them

- `ground_texture` is a full-bleed tileable swatch: checklist items "white background"
  and "single subject" are N/A by design; dims/format/size + matte check still gate it.
  It is never uploaded to Meshy.
- Fill gate: Meshy's hard rule is *no part touching/leaving the frame*; the 70–90 %
  fill figure is a detail heuristic. The verifier therefore gates on measured
  per-side margin (≥12 px) and reports fill (long-axis) for the record: delivered
  images run 78–95 % fill with ≥22 px margin on every side, white ring 100 %.
- Regeneration budget: at most one regen per failing slot; a regen archives the
  previous attempt (`_rejected/<slot>-attempt1.png`) instead of overwriting it.

## Resuming

`python3 tools/arena-kit/gen_assets.py --status | --verify | --run --arena X |
--regen --arena X --slot Y | --manifest --arena X`. The runner skips anything already
delivered; every call is journaled to `run/tmp/arena-kit/image-batch-journal.txt`
before the next one starts. Backend: Hermes image tool (the script imports the same
provider the in-session `image_generate` tool uses, re-execs itself under
`~/.hermes/hermes-agent/venv/bin/python`, key resolved via Hermes secret scope — no key
is ever printed or stored by the tooling).
