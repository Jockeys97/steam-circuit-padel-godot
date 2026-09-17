# Pull-wave verification evidence — UI checkpoint + `codex/gameplay-and-map`

Date: 2026-09-17 (CEST). Engine: Godot 4.7.2.stable.official `ed1daf0bf`
(`/Applications/Godot.app/Contents/MacOS/Godot`). One engine at a time
(`pgrep -x Godot` guard; a pre-existing owner process is never killed).

Chain under test (local, **not pushed**): `249d55a` (UI checkpoint) →
`c6837b2` (merge of the branch tip `a1e10f04f9896de6ebbaff3e29f6d2c0dba77590`) →
the reconciliation commit that adds this directory.

All runs happened in an isolated rsync copy of the merged tree
(`/tmp/padel-uir-pull-20260917/repo`, 833 files verified identical against the
working tree). The owner's checkout was not used for engine runs.

## Files

| File | What it is | Status |
|---|---|---|
| `sweep-results.txt` | the combined sweep table — 19 runs + import, exit codes, tallies, script/error/warning counters, durations | record |
| `sweep-commands.txt` | exact invocation of every sweep run | record |
| `slice-before-reconcile.log` | `base-slice` **before** the reconciliation (`FAIL 322/325`) | superseded |
| `slice-demo-before-reconcile.log` | `base-slice-demo` before (`FAIL 267/274`) | superseded |
| `slice-rerun-full.log` | `base-slice` **after** the reconciliation (`FAIL 339/340`) | current |
| `slice-rerun-demo.log` | `base-slice-demo` after (`FAIL 290/291`) | current |
| `slice-rerun-ui-new.log` | slice under `--ui=new` — informational, **not a gate** (see below) | informational |
| `captures.log` | real-GPU capture transcript of the merged tree (Metal, Apple M4) + md5s | record |

## Reading the reds (the only ones left)

1. **`the shipping pack exists (export it before running this test)`** — the sole red in
   `slice-rerun-full.log` and `slice-rerun-demo.log`. This is the branch rewrite's own
   deliberate strictness (upstream policy): it requires an exported `padel.pck` in the
   project, which no source checkout has and which is gitignored by design. Pre-merge this
   case read "not scored"; the branch flipped it. Kept as-is and reported; it passes on a
   host where the pack is exported before the gate runs. It is **not** a code defect and it
   was not worked around.
2. **`slice-rerun-ui-new.log`** — the slice's menu/mode sections drive the *ported* menu's
   API; under `--ui=new` the prototype menu is mounted, so those sections are not
   applicable and one (`_menu_reaches_match`) throws; the object ceiling also reads ~472
   because the prototype scenes are loaded — which is exactly what `--ui=new` adds. The
   recorded UIR-09 decision is "both constructions runnable", which the capture runs prove;
   slice-under-`--ui=new` was never a gate. Logged for UIR-22.

The menu audit's single `ERROR:` engine line (`ScreenRouter.register: 'nope' …`) is the
audit's own deliberate refusal probe — see `../uir-pre-gate-a-menu-audit.log` and the
journal §6; `script_errors=0` there.

## Reproduce

```sh
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
cd <checkout>
rsync -a --exclude='/.git' --exclude='/.godot' ./ /tmp/padel-uir-pull-20260917/repo/
cd /tmp/padel-uir-pull-20260917/repo
$GODOT --headless --path godot/ --script res://tests/game_slice_test.gd            # 339/340 (pack red)
$GODOT --headless --path godot/ --script res://tests/game_slice_test.gd -- --demo  # 290/291 (pack red)
$GODOT --rendering-driver opengl3 --path godot --resolution 1152x648 \
  res://game/Match.tscn -- --ui=new --capture=match --tier=3 --seed=20260916
```

The full sweep with all 19 commands is in `sweep-commands.txt`.
