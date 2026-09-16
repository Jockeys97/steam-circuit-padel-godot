# Independent review 2 — tick-18 integration (accumulator, latch, demo gate, audit fix, log gate, 211 checks)

Reviewer: `crew-review-2` (independent; wrote no production code and no test; this file is the only
thing it wrote). Date: 2026-09-16. Repo: `/root/projects/steam-circuit-padel-pro` @ working tree.
Reference: `js/**` (frozen, not modified).

Engine: `/root/tools/godot/Godot_v4.7.2-stable_linux.x86_64`, `4.7.2.stable.official.ed1daf0bf`.
Every Godot invocation below ran as
`flock -w 900 /tmp/padel-godot.lock timeout <t> env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 <godot> --headless --path godot/ …`,
one engine at a time. Exit codes are the shell's for that exact command. Two Godot processes were run
inside the range `-- --demo` and one full run was killed after the tree under test went unparsable
(see §6). No file in `godot/`, `js/`, `tools/`, `docs/mission/**` or another lane's evidence was
touched; the synthetic logs the gate was fed live in `/tmp`.

## 0. Revisions this review is about, and the drift under it

The tree moved while I reviewed it. The hashes below are what each measurement was taken against.

| file | reviewed revision | hash at review time | now (17:0x) | matches the lane's pin? |
|---|---|---|---|---|
| `godot/tests/game_slice_test.gd` | 99,620 B | `7ae710583551a7f8` | **130,412 B, unparsable** | yes (pin `7ae71058…`) |
| `godot/game/check_log.sh` | 4,317 B | `f9045a36f7dcb043` | unchanged | yes |
| `godot/src/audits/audit_base.gd` | 6,466 B | `a8732ab803e9ad4e` | unchanged | yes |
| `godot/tests/audits/run_all.gd` | 8,329 B | `16b89a0a585c02c8` | unchanged | yes |
| `godot/game/menu_focus.gd` | 12,220 B | `7d45de3e265b5260` | unchanged | yes |
| `godot/game/main_menu.gd` | 23,563 B | `f168d578ef00c41a` | unchanged | yes |
| `godot/game/match_controller.gd` | 34,556 B (849 lines) | `5a2159a8e3cda933` | **47,682 B (1161 lines), 16:03:58** | no |
| `godot/game/mode_screen.gd` | 14,415 B | — | **22,107 B, 16:06:43** | no |

`match_controller.gd` and `mode_screen.gd` were edited by the mode-playability lane during the
review. I re-read the current `match_controller.gd` `advance_frame`/`apply_frame`/`latch_one_shots`/
`_with_queued`/`_observe`/`start_match`/`_unhandled_input` bodies and they are **textually the same
code** as the reviewed revision (they moved from :444-531 to :633-733); the 312 new lines are the
mode-session work (`_start_mode_session`, `_adopt_session`, `_finish_mode`, `_run_mode_capture`).
Line numbers below are given for the file as it stands **now**, except where a finding is about the
slice test, whose line numbers are for `7ae71058…` (the revision every number in
`quick-match-playable.md` §12 was measured against, and the one my slice run exercised).

## 1. Claim table

| # | Claim | What I observed | Exit | Verdict |
|---|---|---|---|---|
| 1 | `# FRAME_CLOCK 30fps=120 60fps=120 240fps=120` in one wall second, arbitrary frame patterns | `bash godot/game/run.sh test`-equivalent run, `# FRAME_CLOCK 30fps=120 60fps=120 240fps=120 (one wall second each)`, 18 `ok` lines for the clock+latch section, `PASS 211/211` | 0 | **CONFIRMED** |
| 1b | the algorithm tracks wall clock beyond one second (drift) | double-precision model of `advance_frame` (identical order, clamps and constants): 3,600 s at 60 fps → 432,000 ticks (120.000000/s), at 240 fps → 432,000 (120.000000/s), at 144 fps → 431,999 (119.999722/s). No accumulating drift; steady-state deficit ≤1 tick/hour | n/a | **CONFIRMED** (algorithm model, not an engine run — see §5) |
| 2 | clamp/order/constants are the reference's | `match_controller.gd:633-657` vs `js/main.js:1186-1211`: `dt = min(delta, 0.25)` → `acc = min(acc+dt, FIXED_STEP*8)` → `while acc >= FIXED_STEP and steps < 8` → subtract → `steps += 1` → break on result → `if steps == 1: consumeOneShot`. Same order, same two clamps, same constants (1/120, 8, 0.25). One deliberate divergence found — F-11 | 0 | **CONFIRMED-WITH-DIVERGENCE** |
| 3 | a press+release inside one rendered frame still fires the shot | `ok the shot still fires: the tick sees the PRESS, not the release (H-3)`, `ok a half-step frame runs no sub-step`, `ok the press is latched while no sub-step has spent it`, `ok the shot still fires…`, `ok the one-shot is consumed once and not left armed` | 0 | **CONFIRMED** |
| 4 | the latch cannot double-fire / survive a match reset | `advance_frame:653-654` clears on `steps > 0`; `start_match:584-586` and `_adopt_session:281-285` clear it; `rematch()` → both. But the **pause** path clears nothing — F-4. `_paused` is never cleared on reset — F-3 | 0 | **CONFIRMED-WITH-CAVEAT** |
| 5 | excluded-path scan over `game/**`+`src/**` and a byte-search of the two real packs | `ok no res:// path in game/** or src/** lives in a tree the exporters exclude`; independently: `grep -c -a "assets/athletes/volpe-rigged.glb" padel.pck` → 2, `grep -c -a "res://prototypes/"` → 0 on both packs | 0 | **CONFIRMED** (with the revision caveat F-9) |
| 6 | `audits/run_all.gd` pins real per-audit counts, aggregate RED if permuted | `# totals checks=221 failures=0 not-ported=0 expected-checks=221 mismatched=[] audits_failed=0`; every `ok <name> (n checks)` equals `EXPECTED_CHECKS[name]` (14/26/22/25/13/24/23/16/35/23) and sums to 221 → **measured, not guessed**. Permutation→RED is `run_all.gd:132-135`, confirmed by inspection, **not re-run** (needs editing the runner) | 0 | **CONFIRMED** (permutation: confirmed-by-inspection) |
| 7 | an aborted/incomplete audit fails the run | `finish()` fails only `checks == 0` (`audit_base.gd:118-125`); a mid-section abort leaves `checks > 0, failures == 0` → returns 0. The aggregate is saved by the pin; `tests/input/run_all.gd` and every per-audit invocation are **not** — F-7 | 0 | **REFUTED as stated** |
| 8 | the strict log gate fails a suite on SCRIPT ERROR / unexplained ERROR and allows exactly two named lines | gate on the real full log → `ok game_slice_test: PASS 211/211 exit=0 script-errors=0 errors=2(allowed=1+1) fails=0(allowed=0)`; on the audits log and the probe log likewise. Bypasses found — F-5/F-6 | 0 | **CONFIRMED-WITH-BYPASSES** |
| 9 | the slice test grew to 211 checks with 19 section markers and an object-count check | `# sections ran 19/19`, `ok every test section ran to completion`, `# OBJECTS start=1550 end=1945 delta=395 nodes=1 orphans=0 resources=56`, `ok the run does not accumulate objects`, `PASS 211/211`, `ok` 211 / `FAIL` 0 | 0 | **CONFIRMED** (6 of the 211 cannot fail — §4) |
| 10 | demo gate: a demo build lists 2 athletes / 1 arena / 1 tier and locks the third mode | full run `# MENU_ON_SCREEN build=full … athletes=6 arenas=9 tiers_enabled=4`; demo run `build=demo tiers_shown=4 tiers_enabled=1 athletes=2 arenas=1 modes=[all disabled]`; shipped demo selfcheck `arenas:["clockwork"] athletes:["maestro","steamer"] locked_athletes:4 locked_modes:2` | 0 | **CONFIRMED** |
| 11 | the demo gate cannot be bypassed | **REFUTED twice**: `-- --full` flips the shipped demo to the full game (F-1); the match scene ignores the gate entirely (F-2) | 0 | **REFUTED** |
| 12 | harness contract unchanged (`run/main_scene` = SmokeTest, 8 checks) | `--headless --path godot/` → `PASS 8/8` | 0 | **CONFIRMED** |
| 13 | input audits green through the gate | `--script res://tests/input/run_all.gd` → `ok reachability (21)`, `ok input_coverage (40)`, `ok gamepad_nav (164)`, `# totals checks=308 failures=0 not-ported=7`, `PASS 4/4` | 0 | **CONFIRMED** |
| 14 | locale: no raw id on screen | `node tools/i18n-port/hud-coverage.mjs --fail-on-leak` → `# ids the sim can emit: 108 — 108 get a readable line, 0 print the id (or contain it)` | 0 | **CONFIRMED-WITH-CAVEAT** (M-6 of the first review is unfixed, §4/§5) |
| 15 | deterministic replay: same seed twice → same result | `# PLAYTHROUGH ticks=25962 crossings=174 points=24 max_rally=16 result={ "winner": "ai" }` **identical** in the full run and the demo run (same seed, two different `match_controller.gd` revisions) | 0 / 1 | **CONFIRMED** |
| 16 | keyboard routes / HUD at 1152×648 / arena selection not regressed | `# MENU_FIT 1152x648 needs 1078x615`, `ok the menu fits its frame at 1280x720 and 1152x648 (arena row included)`, `ok no HUD panel leaves the frame at 1280x720 or 1152x648`, `ok every arena button selects its own arena`, `ok every match control is a named input action` | 0 | **CONFIRMED** |
| 17 | audio requests per event unchanged | `# AUDIO driver=Dummy requests=260 counts={ "serve": 24, "bounce": 33, "hit": 142, "wall": 33, "point-loss": 23, "net": 4, "defeat": 1 }` in both runs; the "engine state" assertion is still `.size() > 0` (M-3 unfixed) | 0 | **CONFIRMED-WITH-CAVEAT** |
| 18 | the demo-gate row `slice-demo: ok … PASS 211/211` still holds | `--script res://tests/game_slice_test.gd -- --demo` → `FAIL 208/211`, exit 1, three reds all in `_mode_screens` | 1 | **NOT-REPRODUCED due to concurrent edits** (§6) |

## 2. Findings, by severity

### F-1 · **HIGH** · the demo gate is one launch argument away from the full game (shipped artifact)

`godot/tests/build/BuildFlag.gd:29-35` tests user args **before** the export feature tag:

```
static func is_demo() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg == "--demo": return true
		if arg == "--full": return false
	return OS.has_feature(FEATURE_TAG)
```

The reference does it the other way round: `js/build.js:19-35` reads `window.__PADEL_BUILD` (the
container's announcement) **first** and only then the `?build=` URL flag, so a browser demo cannot be
talked out of being a demo by anything the player controls. The port inverted that priority: the
feature tag — the container's equivalent — is the fallback, and `--full` wins.

Reproduction (the shipped demo binary, no display needed):

```
B=godot/build/linux-x86_64-demo-selfcheck/padel-demo-selfcheck.x86_64
flock -w 900 /tmp/padel-godot.lock timeout 300 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 $B --headless
flock -w 900 /tmp/padel-godot.lock timeout 300 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 $B --headless -- --full
```

Output, run 1 (exit 0): `# DemoSelfReport — build=demo, demo feature tag=true, exported=true` /
`…"arenas":["clockwork"],"athletes":["maestro","steamer"],"difficulty":"medium","locked_arenas":8,
"locked_athletes":["pantera","fiamma","oracolo","colosso"],"locked_modes":2…` / `PASS 18/18`.

Output, run 2 (`-- --full`, exit 0): `# DemoSelfReport — build=full, demo feature tag=true, exported=true` /
`…"arenas":["officina","locomotive","clockwork","cattedrale","forgia","tempesta","abissale","caldera","orrery"],
"athletes":["maestro","pantera","steamer","fiamma","oracolo","colosso"],"difficulty":"","locked_arenas":0,
"locked_athletes":[],"locked_modes":0…` / `PASS 15/15`.

Why it matters: `demo_feature_tag` is still `true` in the second run — the tag the export preset sets is
present and simply overridden. The demo's own self-report passes in both modes (18 vs 15 checks), so
"the gate is proved by the built thing asserting on itself" cannot detect the flip. In a Steam demo a
launch option or a CLI launch is player-controlled.

Not covered by any test: nothing in the repo asserts the *priority* order, only the two answers
(`demo_audit.gd` runs the file twice, once with `--demo`, and never with `--full` against a demo tag).

### F-2 · **MEDIUM** · the match scene ignores the demo gate: `--athlete/--tier/--arena/--seed` are applied unconditionally

`Config.apply_build_limits()` — the function that pins a demo to its granted athlete/arena/tier — is
called from exactly one place in the whole tree:

```
grep -rn "apply_build_limits" godot/
godot/game/main_menu.gd:78:	var limits := Config.apply_build_limits()
godot/game/match_config.gd:101:static func apply_build_limits() -> Dictionary:
```

`match_config.gd:157-169` then resolves `athlete()/arena()/tier()` by clamping over the **full frozen
tables** (`clampi(athlete_index, 0, athletes().size()-1)`), and `set_arena_id()` (`:145-150`) accepts any
id in the frozen table with no gate. `match_controller.gd:162-169` writes those indices straight from
the command line:

```
162:	if tier != "":      Config.tier_index = int(tier)
164:	if athlete != "":   Config.athlete_index = int(athlete)
166:	if arena_arg != "": Config.set_arena_id(arena_arg)
168:	if seed_arg != "":  Config.seed_value = int(seed_arg)
```

Reproduction (demo build, editor project — the only way to reach the match scene directly):

```
flock -w 900 /tmp/padel-godot.lock timeout 25 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ res://game/Match.tscn \
  -- --demo --athlete=5 --arena=orrery --tier=3
```

Output (exit 124 = killed by the timeout, as intended):
`MATCH_START tier=leggenda athlete=colosso arena=orrery seed=20260916 camera=default models=false headless=true`
— all three are items the demo does not grant. The same command against `res://game/Main.tscn` prints
`MENU_BUILD_LIMITS {"arena_index":2,"tier_index":1}` and nothing else, i.e. the menu *is* gated.

Reachability of each route in the **packed** demo (checked, not assumed):

| route | reachable in the shipped demo? | evidence |
|---|---|---|
| scene path on the command line (`padel-demo.x86_64 res://game/Match.tscn …`) | **no** | `ERROR: Scene path was specified on the command line, but this Godot binary was compiled without support for path overrides. Aborting.` (exit 1) |
| user args on a normal boot, then the menu's Play button | **yes by code path** | `main_menu.gd:416-418` → `change_scene_to_file("res://game/Match.tscn")`; the match scene then re-reads the same args at `:162-169` and overwrites the gated `Config` the menu just set. Not reproduced end-to-end (needs a Play press; no display here) |
| locked athlete/arena referenced by id | **yes** | `Config.set_arena_id("orrery")` returns true in a demo (`match_config.gd:145-150` has no gate); proved above |
| career/tournament load in demo mode | **no** | the mode screens are locked and the new `_start_mode_session` refuses unnamed modes; `--` args cannot set `pending_mode` |
| a save file carrying full-build progression into a demo build | **no route found** | `grep -rn "is_demo\|BuildFlag\|Gate\." godot/src/save godot/src/modes` → nothing; the only consumers (career/tournament) are refused in a demo. Left in "not checked" |

### F-3 · **MEDIUM** · `_paused` is never cleared on any reset: ESC then R freezes the match with the HUD saying it is running

`grep -n "_paused" godot/game/match_controller.gd`:

```
146:var _paused: bool = false
677:	if not _paused:                 # apply_frame: the ONLY gate on the accumulator
1069:			_paused = not _paused    # _unhandled_input: the ONLY writer
1071:				_hud.set_paused(_paused)
1110:		_hud.set_paused(false)       # rematch(): resets the HUD only
```

`_unhandled_input:1078-1082` handles `KEY_R` → `rematch()` with **no `_paused` guard**, and `rematch()`
(`:1094-1110`) calls `start_match()` / `_adopt_session()` — neither of which touches `_paused` — then
calls `_hud.set_paused(false)`. So ESC (pause) followed by R leaves `_paused == true` with the HUD
hint switched back to the unpaused text: `apply_frame` (line 677) never calls `advance_frame` again and
the match is frozen for good, while the on-screen state says otherwise. `start_match():571-600` and
`_adopt_session():272-303` clear the accumulator, the latch and the tick counter but not this flag.

Reproduced: no (needs a windowed ESC+R; no display in this environment). Evidence is the write-set
above — `rematch()` cannot clear the flag because nothing else in the file writes it. The smallest
end-to-end proof: run `--capture=match`-less windowed play, press ESC then R, and read
`# FRAME_CLOCK`-style tick growth or screenshot the ball.

### F-4 · **MEDIUM** · pausing does not clear the one-shot latch (the reference's pause does)

`apply_frame:676-678` latches `sample` **before** the `_paused` test, and `_process:687-699` keeps
calling `apply_frame` while paused. A shot (or `special`, or a tactic) sampled during the pause is armed
and survives, then lands on the first sub-step after resume. The browser does the opposite on both
edges of a pause: `pauseGame`/`resumeGame` (`js/main.js:1532,1543`) both call `resetTransientInput()`,
which zeroes `hitQueued`/`specialQueued`/`switchQueued`/`switchDirectionQueued` (`js/main.js:333-339`),
and `resumeGame` also resets `simAccumulator = 0` (the port's equivalent — not accumulating while paused
— is fine).

Reproduced: no (needs a rendered pause; the code path is unambiguous). One-line check for whoever
fixes it: `one_shot_armed("hit")` after a paused `apply_frame` with a `hit: true` sample is `true` today.

### F-5 · **MEDIUM** · `check_log.sh` is foolable, and nothing in the repo calls it

The gate is well built for the shapes it was written for (SCRIPT ERROR, unexplained `ERROR:`, non-zero
exit, missing PASS, FAIL beyond the allowance — all verified, see §3). Four holes:

1. **A truncated log passes.** Demonstrated:

   ```
   tail -5 /tmp/rev2-slice.log > /tmp/e_trunc.log
   bash godot/game/check_log.sh e_trunc 0 /tmp/e_trunc.log
   ok e_trunc: PASS 211/211 exit=0 script-errors=0 errors=1(allowed=0+1) fails=0(allowed=0) /tmp/e_trunc.log   # exit 0
   ```

   A log whose *head* carried `SCRIPT ERROR` is green as soon as a caller pipes through `tail`/`head`/a
   size cap. The gate cannot tell "no SCRIPT ERROR occurred" from "no SCRIPT ERROR in the part I read".
2. **No check-count pin.** `PASS 15/15` is accepted exactly like `PASS 22/22`:

   ```
   printf 'ok some/check\nPASS 15/15\n' > /tmp/e_shrunk.log
   bash godot/game/check_log.sh wall_rules 0 /tmp/e_shrunk.log
   ok wall_rules: PASS 15/15 exit=0 script-errors=0 errors=0(allowed=0+0) fails=0(allowed=0)   # exit 0
   ```

   The gate's own header claims it closes the M-1 class; it does not — it delegates entirely to the
   in-suite section markers (`game_slice_test.gd`) and the count pins (`tests/audits/run_all.gd`), and
   the other suites have neither (F-7).
3. **`allowed_fails` and the exit code are caller-supplied.** The probe's allowance of 3 only holds when
   the caller merges stderr: run the probe log stdout-only and the three `FAIL` lines drop to one
   (`audit_base.finish()` writes its failure lines with `printerr`, `audit_base.gd:124,132`), so the
   gate goes **RED on a passing suite**. Same option, both a false green and a false red depending on
   how the caller redirects. `run.sh` merges correctly (`2>&1 | tee`, `run.sh:44,51`) but does not use
   the gate at all.
4. **Casing.** `grep -c "SCRIPT ERROR"` is case-sensitive; `Script Error: …` passes. Not reproduced as a
   defect — Godot's macro always prints the upper-case prefix — reported only as unnecessary fragility
   (`grep -ci` costs nothing).

**No caller.** `grep -rn check_log.sh` over the tree finds the script itself, two comments in
`game_slice_test.gd:145,161`, and the docs. It is invoked by nothing: `godot/game/run.sh` (`test` uses
`grep`-free exit-code passthrough) and `tools/audit-port/run-godot-audits.sh` (which greps
`^(PASS|FAIL) ` and the exit code — the false-green pattern the gate exists to kill) do not call it.
The only caller is an untracked, unversioned `/tmp/crew2-gates4.sh` left over from the lane's own run.
So "a strict log gate now exists" is true of the file and false of the workflow: no committed runner
applies it, and a fresh checkout cannot reproduce the lane's gate table without retyping that script.

### F-6 · **MEDIUM** · the gate is blind to Godot's leak warning, and the object-count check has 55 objects of slack

`check_log.sh:71` counts `^ERROR:|USER ERROR` and `:68` counts `SCRIPT ERROR`. Godot reports leaked
objects as a **WARNING**, so neither sees it. The real full slice run contains:

```
$ grep -n "WARNING\|ERROR" /tmp/rev2-slice.log
201:ERROR: arena_library: unknown arena id 'nope' (have: officina, …)
295:WARNING: 45 ObjectDB instances were leaked at exit (run with `--verbose` for details).
297:ERROR: 7 resources still in use at exit (run with --verbose for details).
```

and the gate reports `ok … errors=2(allowed=1+1)`. The in-suite guard is
`game_slice_test.gd:162-164`, `objects_delta <= 450`, against a measured `delta=395` (demo run: `397`) —
so up to 55 objects of real accumulation read green, and the engine's own 45-object leak warning is
wired to nothing and named nowhere in `quick-match-playable.md` (`grep -n ObjectDB` → 0 hits). The
doc's claim "so a run that leaves objects behind is a red check rather than a line in the log" holds
only above +55 objects, and only for `Object` counts, not for the WARNING channel. (The line is
intermittent — absent in the demo run, present in the full run — which is also why it should be named
explicitly in the gate's allowance table if it is tolerated, or fixed.)

### F-7 · **MEDIUM** · the audit-runner fix is incomplete: two of the three paths that can abort mid-section are still green

`audit_base.finish()` (`audit_base.gd:117-135`) catches `checks == 0` and nothing else. A section that
dies after its 5th assertion leaves `checks = 5, failures = 0` → `return 0`. The aggregate runner now
covers that with `EXPECTED_CHECKS` (`tests/audits/run_all.gd:127-135`). The other two paths do not:

* `godot/tests/input/run_all.gd` — the same file shape, **no** `EXPECTED_CHECKS`, and its verdict line
  is still the constant expression the first review named:
  `run_all.gd:73: print("PASS %d/%d" % [AUDITS.size(), AUDITS.size()])`.
  (Its *value* is coincidentally right when it prints — `_failures == 0` implies `passed == 4` — but the
  number is not derived from `passed`, and nothing pins the 308 checks I measured.) A mid-section abort
  in `gamepad_nav_audit.gd` (164 checks) reads `ok gamepad_nav (109 checks)` / `PASS 4/4`, exit 0.
* every **per-audit** invocation, which is what `tools/audit-port/run-godot-audits.sh` actually runs:
  `--script res://tests/audits/<name>_audit.gd` → `AuditBase.finish()` prints `PASS <reached>/<reached>`
  (`audit_base.gd:126-129`), the runner greps `tail -1` of `^(PASS|FAIL) ` and checks the exit code → green
  over a shrunken audit.

Reproduced: no (injecting an early `return` means editing a test, which this review may not do). The
smallest proving experiment — the lane's own words for the aggregate — is to put an early `return` in
one section of `wall_rules_audit.gd` and run the individual-script path.

### F-8 · **LOW–MEDIUM** · the checks the first review called out as unfalsifiable are still in the suite, plus one new duplicate

Full list in §4. Three of them are unchanged from `independent-review.md` (M-2, M-3, L-2) in a file this
lane rewrote and re-counted (131 → 211) without removing them, and one (`:441-442`) is a verbatim
restatement of a check 90 lines earlier.

### F-9 · **LOW** · the two halves of the packed-asset claim are about different revisions

`_packed_asset_paths` (`game_slice_test.gd:900-950`) scans **current** sources and byte-searches the
**packs on disk**, which are the previous slice's export (`ls -l` → both `.pck` files dated 13:25, i.e.
older than every file this lane changed: `check_log.sh` 15:36, `match_controller.gd` 16:03). The claim
"the athlete scene is INSIDE the pack" is therefore true of an artifact built before the fix landed;
the lane says so itself in §12.11 ("no fresh export"), but the check reads as if it proved the current
tree. Independently confirmed anyway: `assets/athletes/volpe-rigged.glb` appears twice in each pack and
`res://prototypes/` zero times.

### F-10 · **LOW** · the shipped demo's content rule lives in the test tree and ships only by accident of the export filter

`content_gate.gd:29-30` preloads `res://tests/build/BuildFlag.gd` and `ContentFilter.gd`, and
`DemoContent.gd` reads `res://tests/build/demo_content.json`. Both packs carry them only because
`export_presets.cfg:60,92` say `export_filter="all_resources"` (pack listing: `res://tests: 83`) — the
previous review's N-1 nit asked for exactly the opposite (`padel.pck` ships the whole test suite). Add
`tests/*` to `exclude_filter` — a reasonable hardening, since the tickets plan these modules at
`res://src/build/` — and the demo build fails to load its own gate. Bytes are present today
(`grep -c -a "tests/build/BuildFlag" padel.pck` → 4), so this is a fragility, not a break.

### F-11 · **LOW** · the port's latch deliberately diverges from the browser, and the comment says otherwise

The browser consumes the queued one-shots at the **start of every frame**, before the sub-step loop:
`getInput()` (`js/main.js:1006-1052`) reads `hit: hitQueued` and then clears `hitQueued = false`
(`:1041-1051`) whether or not the loop body runs. So a one-shot that arrives on a frame justifying **no**
sub-step is **dropped** by the reference. The port keeps it (`match_controller.gd:711-725`), which is why
H-3 is fixed — but `game_slice_test.gd:671` justifies the behaviour with
"(`js/main.js:2573-2580`: the browser's flags stay queued until consumed)", which is not what that code
does; `:2573-2580` is the *keyup handler* that sets the flag. At render rates above 120 Hz the port
fires shots the browser would lose. That is arguably the right call, but it is a behaviour change
relative to the frozen reference and belongs in the evidence file under "deliberate divergences", not
under "as the browser does".

## 3. The gate, as run (all through `godot/game/check_log.sh`)

| log | exit passed to the gate | gate verdict | gate exit |
|---|---|---|---|
| full slice test (`7ae71058`) | 0 | `ok game_slice_test: PASS 211/211 exit=0 script-errors=0 errors=2(allowed=1+1) fails=0(allowed=0)` | 0 |
| ten audits aggregate | 0 | `ok audits: PASS 10/10 exit=0 script-errors=0 errors=0(allowed=0+0) fails=0(allowed=0)` | 0 |
| `audit_base` probe, allowance 3 | 0 | `ok audit-probe: PASS 6/6 exit=0 script-errors=0 errors=0(allowed=0+0) fails=3(allowed=3)` | 0 |
| probe with allowance 0 | 0 | `FAIL audit-probe: 1 PASS line(s), 3 FAIL line(s) (allowed 0)` | 1 |
| input runner | 0 | `ok input-runner: PASS 4/4 exit=0 script-errors=0 errors=0(allowed=0+0) fails=0(allowed=0)` | 0 |
| synthetic `SCRIPT ERROR` + `PASS` | 0 | `FAIL e_script: 1 SCRIPT ERROR line(s) despite exit 0` | 1 |
| synthetic non-zero exit, no `FAIL` line | 1 | `FAIL e_code: exit 1` | 1 |
| synthetic `Script Error:` (casing) | 0 | `ok e_case: …` | 0 ← F-5.4 |
| synthetic, no `PASS` line | 0 | `FAIL e_nopass: 0 PASS line(s)` | 1 |
| synthetic, two arena-guard lines | 0 | `FAIL e_twoarena: 2 engine error line(s) — 2 arena-guard (max 1)` | 1 |
| real log truncated with `tail -5` | 0 | `ok e_trunc: … errors=1(allowed=0+1)` | 0 ← F-5.1 |
| `PASS 15/15` where 22 is pinned | 0 | `ok wall_rules: PASS 15/15 …` | 0 ← F-5.2 |
| demo slice run (currently red, §6) | 1 | `FAIL slice-demo: exit 1` + the three reds | 1 |

## 4. Checks I believe can never fail

Line numbers are for `godot/tests/game_slice_test.gd` @ `7ae71058…` (the reviewed revision).

| # | check | why it cannot go red |
|---|---|---|
| 1 | `:441-442` "the focus check covers every choice row on the menu" | Same predicate (`b.toggle_mode`) over the same local array `selectable`, and the same expected expression (`tiers + exposed_athletes.size() + exposed_arenas.size()`) as `:349-351`. It restates an assertion 90 lines earlier; it can only fail if that one fails too. |
| 2 | `:604` "no engine clock is needed for a tick" | Asserts `node.engine_driven == false`, which `harness_mode()` (`match_controller.gd:1087-1091`) set two calls earlier in `_new_match_node` (`:586`). It is a check of the test's own setup line — the shape the first review listed as L-2 (old `:340`), carried over. |
| 3 | `:1179` "the event log does not repeat the same line twice in a row" | `hud.gd:456-465` skips any line equal to the previous one by construction (`if line == previous: continue`), so `_log_lines` cannot hold two identical consecutive entries. This is `independent-review.md` M-2, unchanged. |
| 4 | `:1736-1737` "a voice was observed playing after a request" | `match_audio.gd:250` inserts a key per event id regardless of the boolean (`last_playing_probe[event_id] = port.is_playing(event_id)`), and the check only asserts `.size() > 0`, which `:1713` ("the match asked for sounds at all") already implies. `independent-review.md` M-3, unchanged. |
| 5 | `:1085` "the score display followed the match" | `history.size() == points_scored` — both are written in the same branch of `_observe` (`match_controller.gd:778-781`), so the equality is a property of the writer, not of the match. `independent-review.md` L-2, unchanged. |
| 6 | `:653-654` "the tick count does not follow the render rate" | Implied by `:644-652` (three checks each within ±1 of 120); it can differ only if two of them land 2 apart while all three stay within ±1. Near-derivable, not strictly tautological. |

Vacuous-by-design, not counted above: the `else` (full-build) branch of the demo assertions
(`:360-366`) in a demo run, and the `want_locked` branch of `_mode_screens` in a full run — the lane
runs both variants, which is the right mitigation.

Checks I tried to falsify and could not: the section-marker check (`:140`), the object-count check
(`:162`), the six clock checks (`:645-664`), the seven latch checks (`:678-700`), the pack checks
(`:926-943`), the nine-arena/palette/monotone-alpha checks (`:1481-1500`), the per-arena reference-spec
checks (`:1844-1875`), the focus-model reachability checks (`:475-483`), the mode-screen row checks
(`:1791-1793`), and the HUD safe-area pass (`:1678-1691`) — each has a constructible input that turns
it red.

## 5. Not checked, and why

* **Any rendered/audible behaviour.** No display (`--headless` only) and the audio driver is `Dummy`.
  The pause/rematch findings (F-3, F-4) and the menu→match arg override (F-2) are code-path findings:
  the write-sets and call sites are exact, the end-to-end keystroke run is not.
* **Frame-rate behaviour measured on a real clock.** Claim 1's engine measurement is the suite's own
  `apply_frame` feed (30/60/240 fps, one wall second each); the long-run drift answer comes from a
  double-precision model of the same code, not from an engine run at 144 Hz (no display, and a
  windowed run is out of scope).
* **A fresh export.** The packs on disk are from 13:25 (F-9); this review did not rebuild them.
* **The per-audit runner path under a mid-section abort** (F-7) — needs an edit to a test file.
* **The browser build.** `js/**` was read as the frozen authority (accumulator `:1164-1211`, one-shot
  queue `:1006-1052`/`:2573-2580`, pause `:1532-1547`, `updateMatch`'s `paused` guard `js/game.js:2974`).
  No browser was run.
* **A save file carrying full-build progression into a demo build** — no route found (F-2 table); the
  save layer has no demo awareness at all, so this is "not reachable", not "safe by design".
* **`docs/wayfinder/evidence/modes-playable.md`'s claimed divergence** (the demo locking the drill too) —
  another lane's document, out of scope; it is the cause of §6, not a finding of this review.

## 6. Operational note: the tree changed under the review (not a defect of tick-18)

While this review ran, the mode-playability lane edited `godot/game/match_controller.gd` (16:03:58),
`godot/game/mode_screen.gd` (16:06:43) and `godot/tests/game_slice_test.gd` (16:10:01, 99,620 → 130,412 B).

* The full-build slice run I report as `PASS 211/211` ran before those edits and matches the lane's
  pinned hash for the test file; the accumulator/latch code it exercised is textually unchanged in the
  current file.
* My second run (intended as a determinism re-run on the current tree) started while the test file was
  mid-write and died on
  `SCRIPT ERROR: Parse Error: Cannot infer the type of "needle" variable because the value doesn't have a set type. at: GDScript::reload (res://tests/game_slice_test.gd:2576)`.
  I killed that process rather than report a parse error of another lane's in-flight work, and the lock
  is free again.
* **Retry, near the end of the review.** The test file is now `d94d5e58` (130,412 B, unchanged since
  16:10:01) and it **parses** again — the `Parse Error: Cannot infer the type of "needle"` at `:2576`
  is gone. A 20-second probe of the **full** build
  (`--script res://tests/game_slice_test.gd`, killed by `timeout 20` before the suite finished,
  exit 124) already shows the same three reds:

  ```
  FAIL the drill screen's lock state matches the reference's own demo rule (lasciato fuori: false): expected true, got locked=true want=false
  FAIL an open drill screen lists the mode's own rows: expected true, got 0 rows: []
  FAIL the drill screen runs a real DrillSession and shows its own phase and target: expected true, got  {  }
  ```

  So the current revision is red in **both** build variants, and the cause is sharper than "demo only":
  the new `is_locked()` is `return not Gate.modes().has(_mode)`, while `Gate.modes()` /
  `DemoContent.all_mode_ids()` is `["quick","tournament","career"]` — it has never contained `"drill"`.
  Removing the old `if _mode == "drill": return false` therefore locks the drill screen in the **full**
  build as well; the frozen test expects `want_locked = demo and mode != "drill"`. A complete
  `-- --demo` run of the same revision (`d94d5e58`) gave `FAIL 208/211`, exit 1, with exactly those
  three reds.
  **Not reproduced as a defect of this lane due to concurrent edits** — but two claims now fail at once
  against the tree as it stands at 17:0x: `quick-match-playable.md` §12.9's `slice-demo: ok … PASS 211/211`
  row, and the current `game_slice_test.gd:1782-1796` contract. Whichever way it is resolved, the two
  lanes disagree about a rule both cite the reference as the authority for (`index.html`'s `to-drill`
  makes training reachable in the browser demo), and the disagreement is currently expressed as a red
  suite rather than a changed test.
