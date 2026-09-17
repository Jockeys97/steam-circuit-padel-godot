# PROVENANCE — gate-a-review pack

Record of where every artifact in this directory came from, what was verified, and what was not
touched. Compiled 2026-09-17 by the docs-only verification pass (read-only git, no engine, $0).
Updated the same day by the post-pull closeout pass (one merged-tip capture run in the real
checkout; cross-checks 6–7 and the sources-table additions).

## Copy discipline

- Every PNG in `pairs/` is a **byte-identical copy** of its source: the copy step asserts
  `sha256(source) == sha256(destination)` and fails otherwise (`compose_sheets.py`).
- No pixel of any copy or panel was altered. The only derived images are the contact sheets in
  `sheets/`, composed with Pillow 12.3.0 by pasting the copied panels unmodified and drawing caption
  bands (title, role, source path, viewport, hash prefix, provenance notes). Composition script:
  `compose_sheets.py` (kept here so the sheets can be regenerated and audited).
- Hash list for `pairs/` + `sheets/`: `pairs/SHA256SUMS.txt`. Whole-directory manifest:
  `SHA256SUMS.txt` (this directory, generated at pack close).

## Sources (verified facts)

| Artifact (in `pairs/`) | Source path | sha256 |
|---|---|---|
| `menu-reference-web-1280x720.png` | `../evidence/reference-captures/menu.png` (frozen web-build capture) | `6ad40de750b86db5…` |
| `menu-before-ported-1280x720.png` | `../integration-prep/before-set/menu.png` (UIR-00 register baseline) | `bb2d929c09f8d703…` |
| `menu-after-prototype-1280x720.png` | `/tmp/padel-uir-pull-20260917/repo/godot/game/out/ui-prototype-menu.png` | `badf1ec05243dd43…` |
| `hud-reference-web-1280x720.png` | `../evidence/reference-captures/game.png` (frozen web-build capture) | `1d1d5d5f4a085a0a…` |
| `hud-before-ported-1280x720.png` | `../integration-prep/before-set/quickmatch-serve.png` (UIR-00 register baseline) | `0a2696dd78438215…` |
| `hud-after-prototype-1152x648.png` | `/tmp/padel-uir-pull-20260917/repo/godot/game/out/quickmatch-serve.png` | `e13b4d845af59fc2…` |
| `hud-after-prototype-hud-1152x648.png` | `/tmp/padel-uir-pull-20260917/repo/godot/game/out/hud.png` | `c603430c313e0783…` |
| `hud-after-prototype-rally-1152x648.png` | `/tmp/padel-uir-pull-20260917/repo/godot/game/out/rally.png` | `36be85042f3263a0…` |
| `hud-prototype-premerge-1280x720.png` | `/tmp/padel-uir-pull-20260917/repo/godot/game/out/ui-prototype-hud-rally.png` | `1bd985050a1011e3…` |
| `hud-after-prototype-serve-1280x720.png` | real checkout `godot/game/out/quickmatch-serve.png` (merged-tip recapture, staged `/tmp/padel-gatea-1280-20260917/out-after/`) | `93799b94ced8ca32…` |
| `hud-after-prototype-hud-1280x720.png` | real checkout `godot/game/out/hud.png` (same run) | `91e0a6d31b716e23…` |
| `hud-after-prototype-rally-1280x720.png` | real checkout `godot/game/out/rally.png` (same run) | `14a75224f6d9bfe4…` |

(Full hashes are in `pairs/SHA256SUMS.txt`.)

## Cross-checks run this pass (all executed)

1. **Register baseline vs prep register:** `shasum -a 256` of the two `before-set/` files used here
   matches `integration-prep/SHA256SUMS.txt` (`before-set/menu.png bb2d929c09f8d703…`,
   `before-set/quickmatch-serve.png 0a2696dd78438215…`). The register is unchanged.
2. **Pre-merge capture identity:** `ui-prototype-menu.png` (post-merge, 02:26) md5 `b99f1cc7…` is
   byte-identical to the pre-merge `ui-menu.png` (01:59) and matches the closeout capture record
   (`../evidence/uir-pre-gate-a-captures.log`: `ui-prototype-menu.png 437950 1280x720 b99f1cc7…`).
   The court merge provably did not alter the menu frame.
3. **Post-merge capture identity:** the AFTER frames' sha256/md5 match the pull-wave copy's files;
   the capture event is recorded in `../evidence/uir-pull-wave/captures.log` (menu lane) and the
   legacy-name plan lanes; timestamps 02:26 CEST. The `/tmp` copy itself was created 02:25–02:28
   (rsync of the merged tree; `sweep-results.txt` records 833 files verified identical).
4. **Freshness note (no silent substitution):** the main checkout's legacy-name PNGs
   (`hud.png`, `quickmatch-serve.png`, …) are the *merge's* renders and differ from the pull copy's
   re-captures (md5s differ; recorded in `REPORT.md` §2). This pack sources AFTER frames from the
   pull copy (the sanctioned real captures), never from the stale working-tree files.
5. **Frame identification:** the AFTER frames were read with vision to confirm the recreated HUD
   family (no legacy dev strip; `SCORE`/`MAPPA` card) and the scenario; the BEFORE frames likewise
   (legacy `SEED·TIER·TICK·RNG` strip + `CRONACA` box). Identification only — no taste verdict.
6. **Merged-tip 1280×720 recapture (closeout pass, one engine run):** the capture rewrote seven
   `godot/game/out/` PNGs; the directory was snapshotted first (104 files) and restored
   byte-identical afterwards (name-level delta empty; byte-delta exactly the seven outputs;
   post-restore hashes equal the snapshot; `git status` unchanged; tracked plan-lane PNGs equal to
   `HEAD`). Per-file before/after hashes and the full transcript:
   `../evidence/uir-gate-a-hud-1280x720-capture.log`. The three new AFTER panels copy-verify
   against the staged raw outputs (`/tmp/padel-gatea-1280-20260917/out-after/`, md5s in that log).
7. **Composer determinism:** a dry-run rerun of `compose_sheets.py` into a temp directory (before
   the script was extended) reproduced both earlier sheets byte-identically — `hud-before-after.png
   6fdf014b…`, `menu-before-after-1280x720.png 3d3534eb…`, and `pairs/SHA256SUMS.txt` identical.
   The extended script then regenerated both unchanged and composed
   `sheets/hud-before-after-1280x720.png` (`61ab1a56…`).

## File inventory (this directory)

| File | Role |
|---|---|
| `REPORT.md` | the handoff report: merge provenance, ticket assessment, pairs, open items |
| `PROVENANCE.md` | this record |
| `pairs/` (12 PNGs + `SHA256SUMS.txt`) | byte-identical captures, labeled by role+viewport in the filename |
| `sheets/menu-before-after-1280x720.png` | composed contact sheet (REFERENCE/BEFORE/AFTER) |
| `sheets/hud-before-after-1280x720.png` | composed contact sheet, post-merge 1280×720 recapture (REFERENCE/BEFORE/AFTER) |
| `sheets/hud-before-after.png` | composed contact sheet at 1152×648 (retained as composed) |
| `compose_sheets.py` | composition script (rerunnable; asserts copy hashes) |
| `assess_ticket_status.py` + `ticket-status-assessment.txt` | programmatic 28-ticket assessment (as found) |
| `SHA256SUMS.txt` | whole-directory manifest (generated at pack close) |

**State at closeout:** the frozen web reference untouched; `godot/**` runtime code untouched (the
one capture run wrote seven `godot/game/out/` PNGs and they were restored byte-identical —
cross-check 6); the UIR-00 register and `integration-prep/before-set/` re-hashed unchanged;
historical reports and evidence logs preserved as written. Ticket frontmatter (UIR-08/09/24) and
the pack README/docs were reconciled by the closeout pass — recorded in `REPORT.md` §8, `BOARD.md`
and `LOG.md`; nothing pushed.
