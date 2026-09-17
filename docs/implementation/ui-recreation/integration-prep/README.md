# integration-prep — durable preparation for the brother-branch integration

**What this is.** The durable, hash-verified record and checklist for integrating the brother's
branch `codex/gameplay-and-map` into this repo. Prepared 2026-09-17 while the UI-recreation
mission was still running, as **preparation only**.

**Authority / limits of this folder.** Nothing here was merged, pulled, checked out, stashed,
reset, rebased or fetched; no commit, no push, no engine run was made for it. The active checkout
was never mutated — only read. This folder is new; nothing in it overwrites existing evidence.

## Contents

| Path | What it is |
|---|---|
| `branch-review-2752d9a2.md` | **Authoritative** branch review (exact copy of the compatibility report), anchored at tip `2752d9a2eda9dafb692c66e91fb423bd0f92f60f`. PR count 0. |
| `scout-report-61f3ee71-SUPERSEDED.md` | Earlier scout report at tip `61f3ee71`. **Superseded** — its R1 "partial pad" warning is stale for the reviewed tip; do not act on it as current. |
| `HANDOVER.md` | Concise handover: verified state, live/volatile conditions, stale items, next actions. |
| `MERGE-CHECKLIST.md` | The durable future-merge checklist: reconcile, re-pin, protect, rerun, hand over. |
| `PROVENANCE.md` / `PROVENANCE.json` | Every copied file: source path, sha256 before/after, byte-identical verdict. |
| `before-set/` | **UIR-00 before-set screenshots (20 files), byte-identical to the register** (`evidence/uir-00-before-set.md`), stored outside `godot/game/out/` so no pull can overwrite them. |
| `manifests/` | Exact copies of the review's snapshots: branch change lists, local status, unstaged patches (t1/t2), branch diffs, the three-merge-probe inputs and the corrected 0-conflict output, `scout-branch-inventory-61f3ee71.json`. |
| `SHA256SUMS.txt` | sha256 of every file above (shasum-compatible; excludes itself). Verify: `cd integration-prep && shasum -a 256 -c SHA256SUMS.txt`. |

## Sources (volatile, listed for traceability)

Copied from `/tmp/padel-brother-prep/` (`compatibility/report.md`, `compatibility/snapshot/`,
`remote/REPORT.md`, `remote/branch-inventory.json`, `remote/changed-files.txt`). `/tmp` is not
durable; the copies here are. The scouts' private clone (`compatibility/repo/`) was **not**
copied — it is a throwaway partial clone with no unique content.

## How to use at integration time

1. Read `HANDOVER.md` first, then work through `MERGE-CHECKLIST.md` top to bottom.
2. Re-verify `before-set/` hashes against `PROVENANCE.md` before and after the pull.
3. If any snapshot in `manifests/` is re-probed, add the new file — never overwrite these ones.
