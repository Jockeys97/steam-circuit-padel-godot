# UIR pack verification — the shipping pack is real, and the strict red is closed

**Run:** 2026-09-17 02:32–02:37 CEST (00:32–00:37 UTC) · engine `4.7.2.stable.official.ed1daf0bf`
**Host:** macOS 27.0 arm64 · **Repo:** `/Users/lucafantini/Desktop/Personal/Padel-3D/steam-circuit-padel-godot`
**HEAD at every engine run:** `c9470e2306465aa2b34ffc9a17f9b2bcc2db0f97` (merge `c6837b2`, + the reconcile fix)
**Role:** sole engine/build writer for this wave. No test was edited; no pack was faked; nothing was pushed.

This closes the one remaining red the last worker reported on the merged tree — the strict slice
check *"the shipping pack exists (export it before running this test)"* — by producing the real
Linux export with the official 4.7.2 templates **already installed on this Mac**, then re-running
the whole battery on the real checkout, serially, one engine at a time.

---

## 1. The claim being closed

`c9470e2`'s own message: *"base-slice 322/325 -> 339/340; base-slice-demo 267/274 -> 290/291. The single
remaining red in both is the branch's deliberate pack check … which needs an exported `padel.pck` —
reported, not worked around."* Reproduced by the previous worker on an isolated copy as
**339/340** and **290/291**, sole red = `res://build/linux-x86_64/padel.pck` absent.

Pre-state of this run, on the real checkout: **`godot/build/` did not exist** (no pack anywhere:
`find . -name '*.pck'` empty). Nothing was overwritten; the pack below is the first artifact this
checkout has ever produced, at the pinned tip — its provenance is this file.

## 2. Toolchain provenance — nothing was downloaded, nothing was paid

`~/Library/Application Support/Godot/export_templates/4.7.2.stable/` was **already populated**
(all platforms; `version.txt` = `4.7.2.stable`). The Linux release template:

```
d9f79ab89b5ae369aeed11c6052d402e8218cd503bf85b4a235f9c30c46a7c63  linux_release.x86_64 (73,519,416 B)
```

That sha256 is byte-identical to the `padel.x86_64` the S12 slice built on Linux
(`docs/wayfinder/evidence/demo-and-export.md` §4) — the official template, same file, and it is also
the hash of the three binaries exported here. Zero spend; no download was needed.

## 3. The export (exact commands, all exit 0)

Serial, `--headless`, absolute output paths (the S12 failure mode — relative path → *"The given
export path doesn't exist"* — was avoided by construction):

```
cd <repo>
$GODOT --headless --path godot/ --import                              # exit 0, 45 steps, 0 errors
$GODOT --headless --path godot/ --export-release linux-x86_64                  <repo>/godot/build/linux-x86_64/padel.x86_64                  # exit 0, [ DONE ] savepack
$GODOT --headless --path godot/ --export-release linux-x86_64-demo             <repo>/godot/build/linux-x86_64-demo/padel-demo.x86_64            # exit 0, [ DONE ] savepack
$GODOT --headless --path godot/ --export-release linux-x86_64-demo-selfcheck   <repo>/godot/build/linux-x86_64-demo-selfcheck/padel-demo-selfcheck.x86_64  # exit 0, [ DONE ] savepack
```

Artifacts (sha256, full log: `uir-pack-export-full.log` / `-demo.log`):

| path | bytes | sha256 |
|---|---|---|
| `godot/build/linux-x86_64/padel.x86_64` | 73,519,416 | `d9f79ab89b5ae369aeed11c6052d402e8218cd503bf85b4a235f9c30c46a7c63` |
| `godot/build/linux-x86_64/padel.pck` | 138,142,952 | `7aefc19e0063829a85fda893e12246a9c57cab6af54b80dc7272003cf1c70071` |
| `godot/build/linux-x86_64-demo/padel-demo.x86_64` | 73,519,416 | `d9f79ab8…` (same template) |
| `godot/build/linux-x86_64-demo/padel-demo.pck` | 138,142,984 | `849647825b8f324de939e34e4c7d3928fc46bd2c66c7a606ef08a025bcd1c22a` |
| `godot/build/linux-x86_64-demo-selfcheck/padel-demo-selfcheck.pck` | 138,142,984 | `8496478…` (byte-identical to the demo pack — same 32-byte `demo`-tag delta pattern as S12) |

`godot/build/**` is gitignored: the artifacts are working evidence, not commit content.

## 4. What the pack is (verified on the artifact, `tools/export/pck-list.py`)

`padel.pck`: magic GDPC v4, **466 entries**, 138,142,952 B — `res://.godot` 86 files/136.3 MB
(the imported assets at source resolution), `res://assets` 59/23 KB, `res://game` 60/198 KB,
`res://src` 138/748.5 KB, `res://tests` 122/771.9 KB, `project.binary` 13,537 B.

- `res://prototypes/` → **0 files**, `res://src/character/out/` → 0, `res://game/out/` → 0
  (the only "out" hits in the inventory are `outfit_catalogue.gd` / `outfit_recolour.gdshader`).
- The slice's own two probes on the real artifact: `ok the athlete scene is INSIDE
  res://build/linux-x86_64/padel.pck (the packaged build can draw the rigs)` and
  `ok no excluded tree is inside res://build/linux-x86_64/padel.pck` — and the same for the demo
  pack (`ok the demo pack carries the athlete scene too`), with `Court.GLB_PATH` =
  `res://assets/athletes/volpe-rigged.glb` (packed tree, verified by independent substring scan in
  the sweep log as well).
- Extracted `project.binary` (13,537 B, md5 `4c82faeff26a3e47f71f002f75891dfe`): contains
  `res://tests/SmokeTest.tscn` ×1, `res://game/Main.tscn` ×0 — the documented "the preset option
  `application/main_scene` is inert" holds at this tip too.
- **Delta to record, not smoothed over:** the macOS 4.7.2 exporter wrote **no `override.cfg`** next
  to any of the three binaries (S12's Linux directories carried one; no script in the repo writes
  it — `grep -rn '"override.cfg"'` over the tree finds only comments). So the boot-scene override
  leg of the packaged build is **not re-verified here**; the slice's pack checks do not involve it.
  Pack size also grew 50.7 MB → 138.1 MB vs S12 because the merged tree carries more content
  (nine arenas, six athletes + clips + outfits, UI assets/fonts — 466 vs 287 entries), not because
  an exclusion stopped working: the exclusions were re-checked on the artifact above.

## 5. The red, closed — re-measured on the real checkout, strict gate applied

Applied `godot/game/check_log.sh` (the strict gate: exit code + check counts + clean error stream;
`SCRIPT ERROR` never allowed; only its two named allowances) to every suite below.

| suite | command (`--path godot/`) | tally | exit | gate |
|---|---|---|---|---|
| **slice, full** | `--script res://tests/game_slice_test.gd` | **PASS 342/342** | 0 | ok — errors=2(allowed 1+1), script-errors=0 |
| **slice, demo** | `--script res://tests/game_slice_test.gd -- --demo` | **PASS 293/293** | 0 | ok — errors=2(allowed 1+1), script-errors=0 |
| **court dimensions (orphan gate, run explicitly)** | `--script res://tests/court_dimensions_test.gd` | **PASS court dimensions: 1111 checks, 0 failures** | 0 | ok |

Arithmetic reconciles with the c9470e2 message: 340 (339 pass + 1 strict pack red) − that red
+ the two pack-content checks + the demo-pack check = 342/342; demo: 291 → 293/293. **No test was
changed to get here** — `git status` shows zero modifications under `godot/`; the absent→fail
branch (`game_slice_test.gd:1234-1237`) is still strict; the artifact is real (hashes in §3).

## 6. Baseline + UI + build suites on the same checkout (serial, every one strict-gated)

| suite | tally | | suite | tally |
|---|---|---|---|---|
| harness (main scene) | PASS 8/8 | | ui data (`tests/ui/data_audit.gd`) | PASS 131/131 |
| input (`tests/input/run_all.gd`) | PASS 5/5 | | ui data `-- --demo` | PASS 134/134 |
| audits (`tests/audits/run_all.gd`) | PASS 10/10 | | ui input/a11y | PASS 117/117 |
| modes (`tests/modes/run_all.gd`) | PASS 6/6 | | ui hud | PASS 172/172 |
| save | PASS 137/137 | | ui menu | PASS 97/97 |
| music | PASS 32/32 | | ui menu `-- --demo` | PASS 98/98 |
| shot-logic parity | PASS 675/675 | | ui legibility | PASS 76/76 |
| timing-feedback parity | PASS 100/100 | | ui theme probe | PASS 271/271 |
| switch-mode audit | PASS 85/85 | | ui fonts/assets | PASS 75/75 |
| demo_audit full/demo | 46/46 · 47/47 | | content_filter full/demo | 20/20 · 16/16 |
| export_preset_audit full/demo | 54/54 · 54/54 | | `python3 docs/wayfinder/validate.py` | `PASS: 0 errors, 0 warnings` |

All exit 0, `SCRIPT ERROR` count 0 in all **28** engine runs (see `uir-pack-verification-sweep.log`
for the per-run line: command family, exit, error counts, tally).

## 7. Refusal vs `SCRIPT ERROR` — the classification the parent asked for

Engine `ERROR:` lines observed, all deliberate:
- `ERROR: ScreenRouter.register: 'nope' is not one of the thirteen reference screens` and
  `ERROR: ScreenRouter.register: 'menu' was handed a null scene` — ui-router (2) and ui-menu (1
  each, full and demo) logs; each is flanked by `ok router/register_refuses_an_id_outside_the_table`
  / `ok menu/register_refuses_an_id_outside_the_table` — the router's refusal probe.
- `ERROR: arena_library: unknown arena id 'nope'` ×1 and `ERROR: 3 resources still in use at exit` ×1
  — the slice's two named-and-justified allowances in `check_log.sh`, exactly one each.
- The parent's earlier menu `ERROR` is this same class (ScreenRouter / MENU_BACK refusal); in the
  capture runs below it does not appear — the prototype mounts cleanly at this tip. **No line
  matching `SCRIPT ERROR` occurred in any run.**

## 8. Captures (menu, real window, opengl3) — opt-in path intact

```
$GODOT --rendering-driver opengl3 --path godot res://game/Main.tscn -- --capture=menu --out=ui-packverify-menu-legacy
$GODOT --rendering-driver opengl3 --path godot res://game/Main.tscn -- --ui=new --capture=menu --out=ui-packverify-menu-new
```

- legacy (default): `MENU_ON_SCREEN {…"focus":"tier:0", 9 arenas, 4 tiers, 3 modes…}`,
  `CAPTURE_SAVE err=0` → `godot/game/out/ui-packverify-menu-legacy.png` (1152x648, sha256
  `b5277b48766053c14413f3bf69dd9c11e053d6b890270098a0675a1e86aa16c1`).
- `--ui=new`: `UI_PROTOTYPE_ON_SCREEN {"router":"menu","screen":"menu"}`, `CAPTURE_SAVE err=0` →
  `godot/game/out/ui-packverify-menu-new.png` (1152x648, sha256
  `08ea2b50f34568b48375a78e43d02d577ba34f13793905559b2f1383760e012a`).
- **`--ui=new` stays opt-in**: `_ui_new = _arg(args,"--ui=","legacy") == "new"` (match_controller) and
  the same guarded default in main_menu; no `preload` of `res://src/ui` in `godot/game/*.gd`; only the
  three guarded `load()` sites. New `--out` names — the frozen before-set register files were not
  touched (the two PNGs above are new untracked files).
- GATE-A is **not** performed and not approved; nothing here certifies visuals.

## 9. Byte pins re-measured (review appendix §7) and housekeeping

All §7 pins reproduce byte-for-byte at this tip: `hud.gd` `883b8ff5…`, `input_map.gd` `a1780ce4…`,
`project.godot` `3aef17de…`, `match_controller.gd` `a0f56fec…`, `court.gd` `844891ea…`,
`match_config.gd` `ec73fd28…`, `court_dimensions_test.gd` `581adcdc…`, `shot_logic_parity_test.gd`
`211f8e7a…`, `timing_feedback_test.gd` `35960e28…`, `input/run_all.gd` `533a14b6…`,
`src/ui/Hud.gd` `3afad319…`, `ViewState.gd` `584a080a…`, `Hud.tscn` `746a7b9f…`,
`hud_audit.gd` `cf588c9a…`. **One expected drift:** `game_slice_test.gd` is `f13273af…` (pinned
`a259e63e…` at the branch tip) — because `c9470e2` itself rewrote it (+140/−17, "restore the slice
assertions the branch rewrite dropped"); that fixed file is the one that reads 342/342 above.
Refresh parity, reproduced with word-boundary regex: 10 genuine `_hud.refresh(` sites (lines
498, 513, 881, 977, 1144, 1152, 1695, 1715, 1745, 1815), each with a co-located
`_refresh_ui(`/`_ui_hud.refresh(` (lines 499, 514, 882, 979, 1146, 1158, 1696, 1716, 1746, 1816 —
plus the two wrapper-definition sites 752/754).

Housekeeping: `python3 docs/wayfinder/validate.py` rewrites `docs/wayfinder/validation.md`
(its count moved 61 → 64 markdown files); the file was **restored to its committed state** to keep
this wave's no-shared-doc-changes constraint — the stale count is recorded here instead. New
untracked engine-generated files left in place (not committed, not deleted): `court_dimensions_test.gd.uid`,
`timing_feedback_test.gd.uid`, `tests/ui/capture_ui.gd.uid`, `tests/ui/ui_legibility_audit.gd.uid`,
the `.import` sidecars the import pass emitted under `godot/game/out/`, and the two capture PNGs.
All pre-existing untracked lanes (`.hermes/`, `art/`, `meshy/**`) are untouched, as is the
pre-existing `M meshy/README.md`.

## 10. NOT DONE / non-claims

- **The exported binaries cannot execute on this host** (Linux x86_64; this Mac cannot run them):
  the S12 artifact-run evidence (self-report `PASS 18/18` inside the binary, windowed captures) is
  **not** re-produced here; only in-editor pack-content checks were re-measured on the real artifact.
- `override.cfg` leg (§4) not re-verified; `demo rule in the game's screens` (S12 §6) remains as
  reported there; no store/ packaging, no signing, no upload.
- No ticket is marked done; GATE-A not run; `--ui=new` opt-in unchanged; camera/court-aspect remain
  the owner's call; no feel/framing claims.
- Nothing pushed. Commit scope: this evidence file + the logs it names.
