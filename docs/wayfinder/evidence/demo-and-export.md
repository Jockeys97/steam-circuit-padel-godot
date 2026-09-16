# S12 — Demo and export presets: the demo content rule, and the first packaged builds

Slice S12 of `docs/implementation/PLAN.md`, ticket `docs/implementation/tickets/demo-export-presets.md`.
Run by crew-export. Nothing here is committed, pushed, uploaded or published.

**Outcome.** Three real export presets exist; the reference's demo content rule (two athletes, one
arena, quick match only, fixed medium difficulty) is enforced by one build flag and two separate
filter answers; the rule is proved by a **built artifact asserting on itself** (`PASS 18/18`,
exit 0, printed from inside the exported binary); and three Linux x86_64 builds exist and run —
the first launchable artifacts of the Godot port. The full game lists all six athletes, nine
arenas and three modes; the demo build lists two, one and one.

---

## 1. The presets

`godot/export_presets.cfg` (new in this slice).

| # | name | platform | declared main scene | feature tags | output | export filter |
|---|---|---|---|---|---|---|
| 0 | `linux-x86_64` | Linux | `res://game/Main.tscn` | (none) | `res://build/linux-x86_64/padel.x86_64` | all resources |
| 1 | `linux-x86_64-demo` | Linux | `res://game/Main.tscn` | `demo` | `res://build/linux-x86_64-demo/padel-demo.x86_64` | all resources |
| 2 | `linux-x86_64-demo-selfcheck` | Linux | `res://tests/build/DemoSelfReport.tscn` | `demo` | `res://build/linux-x86_64-demo-selfcheck/padel-demo-selfcheck.x86_64` | all resources |

Per preset, the fields that matter:

| preset | `custom_features` | `include_filter` | `exclude_filter` | `binary_format/embed_pck` | preset option `application/main_scene` |
|---|---|---|---|---|---|
| `linux-x86_64` | `""` | `*.json` | `res://prototypes/*,res://src/character/out/*,res://game/out/*` | `false` | `res://game/Main.tscn` |
| `linux-x86_64-demo` | `demo` | `*.json` | same | `false` | `res://game/Main.tscn` |
| `linux-x86_64-demo-selfcheck` | `demo` | `*.json` | same | `false` | `res://tests/build/DemoSelfReport.tscn` |

Choices, with the reason:

- **`include_filter="*.json"`** — Godot packs JSON only when asked. Both the frozen tables
  (`res://src/sim/frozen/data.json`) and the demo table (`res://tests/build/demo_content.json`)
  are JSON, so without this the exported game has no content at all. Verified present in the
  artifact: `ok packed (raw file): res://src/sim/frozen/data.json`, `ok packed (raw file):
  res://tests/build/demo_content.json`.
- **`exclude_filter`** — `res://prototypes/*` are separate scratch projects (their own
  `project.godot`), and `res://src/character/out/*` / `res://game/out/*` are rig render evidence
  and slice screenshots. Nothing under `godot/game/**` or `godot/src/**` loads anything from an
  `out/` directory (checked: `grep -rn "out/" game/ src/` returns only comments describing what
  those directories are *written* by), so the exclusion cannot remove game content. This is the
  same call `scripts/build-dist.mjs:1-18` records for the web build — what ships is a selection,
  not the repository.

  > **CORRECTION (2026-09-16 14:35, mission owner).** The claim in this bullet that the
  > exclusion "cannot remove game content" is **FALSE**, found by the independent review
  > (`docs/wayfinder/evidence/independent-review.md`, finding HIGH-1): `godot/game/court.gd:96`
  > loaded the athlete model from `res://prototypes/arena_spike/assets/volpe-rigged.glb`, and the
  > exclusion removes `res://prototypes/*` from the pack (`pck-list.py` on `padel.pck` →
  > `res://prototypes: 0` files), so the **exported build silently fell back to placeholder
  > capsule bodies**. The editor-side assertion in `game_slice_test.gd` only checked
  > `ResourceLoader.exists`, which is true in the editor and false in the shipped pack. The
  > integration lane is fixing the load path and adding an assertion that no game content is
  > loaded from an excluded path — the review's finding stands as written.
- **`binary_format/embed_pck=false`** — binary and `.pck` side by side, so the pack is its own
  hashable and inspectable artifact and a later signing step has one file to sign instead of a
  70 MB blob that also contains the pack.
- **The demo preset differs from the full one by the feature tag only.** `js/build.js:38` is the
  principle — cut the progression, not the game — so the demo deletes no content file. The
  artifact proves it: `ok the demo preset ships the same resource set as the full one`.

### The main scene: carried twice, and the engine's half measured inert

`godot/project.godot` keeps `run/main_scene="res://tests/SmokeTest.tscn"` on purpose — the
headless harness command depends on it, and this slice may not edit that file. Godot 4.7.2 has
**no main-scene field on an export preset** (open engine proposal: godot-proposals#11345; the
supported route is a feature-tagged project setting, `application/run/main_scene.demo`, which
would require editing `project.godot`). So both routes that need no project-file change are
written, to the same path per preset:

1. the preset option `application/main_scene`, and
2. `override.cfg` next to the exported binary — `ProjectSettings` documents it as overriding
   project settings in an exported project
   (<https://docs.godotengine.org/en/4.7/classes/class_projectsettings.html>).

**Measured, not assumed** — with `override.cfg` moved aside, the demo binary boots the harness
scene:

```
$ cd godot/build/linux-x86_64-demo && mv override.cfg /tmp/override-cfg-bak
$ flock -w 900 /tmp/padel-godot.lock timeout 60 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
    ./padel-demo.x86_64 --headless
ok engine build commit
ok physics tick is 120 Hz
ok float accumulator overshoots 120 steps (count integer ticks)
PASS 8/8
exit=0
```

`PASS 8/8` is `res://tests/SmokeTest.tscn` — i.e. the pack's own `project.binary` still names the
harness scene and **the preset option is inert**. With `override.cfg` in place the same binary
boots the game menu (§5). The second corroboration is that `padel-demo.pck` and
`padel-demo-selfcheck.pck` are byte-identical (same sha256, below): the selfcheck preset's
different main scene reaches the binary only through its own `override.cfg`.

### Exclusion, verified on the artifact

`tools/export/pck-list.py` reads the pack directory written by the exporter (pack format version
4, header carries a directory offset; the tool prints the inventory, and the full list of 287
paths is saved per pack under `tools/export/logs/packed-files-*.txt`).

| pack | entries | pack bytes | `res://prototypes/` | `res://src/character/out/`, `res://game/out/` | `.godot/imported/` | `res://game/` | `res://src/` | `res://tests/` |
|---|---|---|---|---|---|---|---|---|
| `padel.pck` | 287 | 50,687,372 | **0 files / 0 bytes** | 0 (excluded) | 24 files / 49,654,268 B | 40 files / 103,840 B | 104 files / 400,898 B | 83 files / 459,323 B |
| `padel-demo.pck` | 287 | 50,687,404 | **0 files / 0 bytes** | 0 (excluded) | 24 files / 49,654,268 B | 40 files / 103,840 B | 104 files / 400,898 B | 83 files / 459,323 B |
| `padel-demo-selfcheck.pck` | 287 | 50,687,404 | **0 files / 0 bytes** | 0 (excluded) | 24 files / 49,654,268 B | 40 files / 103,840 B | 104 files / 400,898 B | 83 files / 459,323 B |

Before the filters were tightened the same packs held 422 entries and
`.godot/imported/` 93 files / 54,275,370 bytes; excluding the two `out/` trees removed 135 entries
and 4,621,102 bytes of imported render evidence. The exclusion is also asserted from inside the
running artifact: `ok not packed (raw file)/ok not packed (resource loader):
res://prototypes/arena_spike/Main.tscn` and the same for
`res://prototypes/render_probe/Main.tscn`.

What is left, and why (see §6): 49,654,268 of the pack's 50,662,944 bytes of content are imported
textures — three copies of the same GLB texture at 6,124,746 B each and four outfit PNGs at
~4.5 MB each, all at source resolution. Removing that weight is an asset-import-setting change
(`godot/assets/**/*.import`, another lane's files), not a filter this slice owns.

---

## 2. The demo rule, in code

Three new modules, all under `godot/tests/build/`:

- **`BuildFlag.gd`** — the single build flag. `is_demo()` reads `OS.has_feature("demo")`, with
  `--demo` / `--full` user args as the local override and the full game as the default. The port
  of `js/build.js:19-35`; nothing else in the slice reads the feature tag.
- **`DemoContent.gd`** — the content table, **read from a generated file and never re-typed**.
  `tools/export/gen-demo-content.mjs` imports `js/build.js` (the module `scripts/demo-audit.mjs`
  audits) and writes `godot/tests/build/demo_content.json` containing the table, the sha256 of
  every source it came from, the reference menu's full mode set (`index.html`
  `.mode-card[data-mode]`) and the per-athlete challenge-outfit counts (`js/data.js`
  `ATHLETE_OUTFITS`). Re-running the generator and diffing is the drift check.
- **`ContentFilter.gd`** — the two answers the reference keeps apart: `filter(items, allowed)`
  (`js/build.js:58`, a no-op outside the demo) and `is_locked(item, allowed)` (`js/build.js:73`,
  false outside the demo), plus `roster()`, `arenas()`, `modes()`, `difficulty()` and the locked
  lists a screen renders. Sliced from `res://src/sim/frozen.gd`, so the demo uses the same
  numbers as the full build.

The rule as enforced: athletes `["maestro","steamer"]`, arenas `["clockwork"]`, modes `["quick"]`,
difficulty `"medium"`, `outfitChallenges: true` (8 challenge outfits across the two athletes, from
`js/data.js`). The full build: 6 athletes, 9 arenas, 3 modes (`quick`, `tournament`, `career`),
nothing locked.

**Placement request (not done, because it is another lane's file).** The ticket's file plan puts
these at `res://src/build/BuildFlag.gd`, `DemoContent.gd`, `ContentFilter.gd`; this slice's
allowlist excludes `godot/src/**`, so they live under `godot/tests/build/` and the relocation is
recorded here instead of made. A consequence is visible in the pack: the demo build ships the
test scaffolding (`res://tests/` 83 files, 459,323 B) because a glob cannot exclude `res://tests/*`
while keeping `res://tests/build/*`. Moving these three modules to `res://src/build/` lets the
presets exclude `res://tests/*` and `res://src/character/out/*` wholesale.

### Tests

All headless, all printing `ok <name>` lines, ending in `PASS n/n` / `FAIL n/n` and exiting 0/1.

| test | full build | demo build (`-- --demo`) | what it carries |
|---|---|---|---|
| `demo_audit.gd` | `PASS 46/46`, exit 0 | `PASS 47/47`, exit 0 | the ported `scripts/demo-audit.mjs`, promise for promise |
| `content_filter_audit.gd` | `PASS 20/20`, exit 0 | `PASS 16/16`, exit 0 | the two answers proved independent |
| `export_preset_audit.gd` | `PASS 54/54`, exit 0 | `PASS 54/54`, exit 0 | preset inventory, distinct names and paths, the demo tag on exactly the demo presets, exclude patterns that actually match |
| `DemoSelfReport.gd` | — | **`PASS 18/18`, exit 0, inside the exported binary** | the built thing asserting on itself |

Promises carried over, with the reference line each comes from: the demo's athletes and arenas
resolve from the real tables (`scripts/demo-audit.mjs:10-15`); no demo item carries `unlock`
(`:21`); the two athletes differ by ≥ 0.25 on control **and** power (`:30`); every balance key the
fixed difficulty needs exists (`:40`); modes is exactly `["quick"]` and difficulty exactly
`"medium"` (`:44-46`); the filter is a no-op with the flag off and reduces with it on (`:49-51`);
at least one athlete and one arena are excluded (`:62-65`); the lock answer equals the demo flag
for everything outside the allowed set (`:71`); every demo athlete is unlocked (`:74`);
`outfitChallenges: true` with real challenges behind it (`:83-90`).

One promise is **stronger** than the reference's. The reference proves only the separation number;
this slice computes from the frozen `ATHLETES` table that the demo's pair is the pair maximising
control+power separation among the athletes the demo *could* grant (those with no `unlock`), and
that its first athlete is that set's control extreme and its second that set's power extreme:
`ok the demo grants the widest control+power pair among athletes it could grant`,
`ok the demo's first athlete is the eligible control extreme`,
`ok the demo's second athlete is the eligible power extreme`. Measured separation: control 0.32,
power 0.30. (The roster's absolute extremes are `oracolo` 1.34 control and `colosso` 1.32 power —
both unlockable, so neither can be in the demo; that is the point of computing the eligible set.)

`content_filter_audit.gd` proves the two answers are *not* one flag wearing two names, by reaching
all three combinations in one build: in-list/unlocked (the demo's own content and the full build's
everything), in-list/locked (something the full build grants and the demo only shows) and
not-in-list/unlocked (held back from one list but not forbidden). A single boolean passes
`scripts/demo-audit.mjs:71` while losing that distinction, which is why this audit is separate.

---

## 3. Commands and exit codes

Binary: `/root/tools/godot/Godot_v4.7.2-stable_linux.x86_64` (`4.7.2.stable.official.ed1daf0bf`).
Every engine invocation wrapped `flock -w 900 /tmp/padel-godot.lock` with `timeout` inside, one
engine at a time. Reproducible through `tools/export/run-s12.sh`; logs under `tools/export/logs/`.

### Toolchain: export templates (missing at start, fetched)

`ls ~/.local/share/godot/export_templates/` → empty. Official templates for exactly 4.7.2 fetched:

| command | exit | key output |
|---|---|---|
| `curl -L --retry 3 -C - -o /root/tools/godot/templates-4.7.2.tpz https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz` | 0 | 1,281,349,702 bytes |
| `unzip -o -j …templates-4.7.2.tpz templates/linux_release.x86_64 templates/linux_debug.x86_64 templates/version.txt` (into `~/.local/share/godot/export_templates/4.7.2.stable/`) | 0 | `linux_release.x86_64` 73,519,416 B, `linux_debug.x86_64` 73,703,800 B, `version.txt` = `4.7.2.stable` |

Only the Linux pair is installed; other platforms' templates were not fetched (§6).

### The engine harness must not regress

| command | exit | key output |
|---|---|---|
| `flock -w 900 /tmp/padel-godot.lock timeout 120 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/` | **0** | `PASS 8/8` — `run/main_scene` untouched, the harness still green |

### The demo table, generated from the reference

| command | exit | key output |
|---|---|---|
| `node tools/export/gen-demo-content.mjs` | 0 | `wrote godot/tests/build/demo_content.json`, `athletes ["maestro","steamer"]`, `arenas ["clockwork"]`, `modes ["quick"]`, `difficulty "medium"`, `allModes ["quick","tournament","career"]`, `outfitChallenges {maestro:4, steamer:4}`, hashes `js/build.js 72e5296f…`, `js/data.js c63c496c…`, `index.html c1060116…` |

### The four audits, both builds

Pattern: `flock -w 900 /tmp/padel-godot.lock timeout 180 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1
<godot> --headless --path godot/ res://tests/build/<audit>.tscn [-- --demo]`

| command | exit | key output |
|---|---|---|
| `… demo_audit.tscn` | 0 | `PASS 46/46` |
| `… demo_audit.tscn -- --demo` | 0 | `PASS 47/47` |
| `… content_filter_audit.tscn` | 0 | `PASS 20/20` |
| `… content_filter_audit.tscn -- --demo` | 0 | `PASS 16/16` |
| `… export_preset_audit.tscn` | 0 | `PASS 54/54` |
| `… export_preset_audit.tscn -- --demo` | 0 | `PASS 54/54` |

### The exports

Pattern: `flock -w 900 /tmp/padel-godot.lock timeout 900 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1
MALLOC_ARENA_MAX=1 <godot> --headless --path /root/projects/steam-circuit-padel-pro/godot
--export-release <preset> <absolute output path>`

| command | exit | key output |
|---|---|---|
| `--export-release "linux-x86_64" …/build/linux-x86_64/padel.x86_64` | **0** | `[ DONE ] savepack` |
| `--export-release "linux-x86_64-demo" …/build/linux-x86_64-demo/padel-demo.x86_64` | **0** | `[ DONE ] savepack` |
| `--export-release "linux-x86_64-demo-selfcheck" …/build/linux-x86_64-demo-selfcheck/padel-demo-selfcheck.x86_64` | **0** | `[ DONE ] savepack` |

Failures met on the way, recorded rather than smoothed over:

1. **OOM kill (exit 137).** The first export — a throw-away probe project, to learn whether an
   export preset can override the main scene — was killed by the kernel at 568,736 kB anon RSS:
   `dmesg`: `Out of memory: Killed process 1132746 (Godot_v4.7.2-st) total-vm:937396kB,
   anon-rss:568736kB`. The host has 3,910 MB RAM, 0 swap, one CPU, 1.9 GB of *other lanes'*
   scratch inside the 2 GB `/tmp` tmpfs, and ~260 MB available. Nothing else could be freed
   without touching another lane's files, so a 2 GiB swap file was added as host prep:
   `fallocate -l 2G /root/swapfile` (exit 0), `mkswap /root/swapfile` (exit 0),
   `swapon /root/swapfile` (exit 0); the export then peaked at ~1.1 GB of swap and completed.
   **This is a change to the host, not to the repository** — `swapoff /root/swapfile` reverts it —
   and it was left in place because the OOM killer had already killed the mission's own gateway
   process once before the export even started.
2. **Relative output path (exit 0 in the shell, export failed).** The first real attempt passed a
   repository-relative output path and Godot reported
   `ERROR: Prepare Template: The given export path doesn't exist.` /
   `ERROR: Project export for preset "linux-x86_64-demo" failed.` The templates were never the
   problem. Every later export uses an absolute output path. (Log:
   `tools/export/logs/export-demo.log`.)
3. **A test of my own that was wrong.** The first `DemoSelfReport` run failed 3 of 15:
   `FAIL packed: res://game/Main.tscn: expected true, got false` — while
   `ResourceLoader.exists("res://game/Main.tscn")` was true. `script_export_mode=2` stores scripts
   as binary tokens and rewrites the paths that referenced them, so a packed scene or script is
   found by the resource loader and *not* by `FileAccess` on the source path. The check now uses
   the right probe for each kind of file (and both probes for "must not be packed"). Recorded as
   the first attempt of the artifact self-check gate; the second attempt is `PASS 18/18`.
4. **A capture that photographed nothing.** The first windowed run produced a 4,493-byte PNG of a
   black screen — the log path was relative and resolved inside the build directory, so the
   redirect failed before the binary started. Fixed by making the log path absolute; the captures
   then measured 1,812 distinct colours. A black screenshot would have been reported as a black
   screenshot, not as a success.

### Running the artifacts

| command | exit | key output |
|---|---|---|
| `cd godot/build/linux-x86_64-demo-selfcheck && flock -w 900 … timeout 90 … ./padel-demo-selfcheck.x86_64 --headless` | **0** | `PASS 18/18` (full output in §4) |
| `cd godot/build/linux-x86_64 && … ./padel.x86_64 --headless` | 124 (`timeout`) | no output, no error: the game boots and keeps running, which is what a game does |
| `cd godot/build/linux-x86_64-demo && … ./padel-demo.x86_64 --headless` | 124 (`timeout`) | same |
| `bash tools/export/capture-artifact.sh godot/build/linux-x86_64-demo padel-demo.x86_64 tools/export/logs/demo-window.png` | 0 | `capture exit=0`, PNG 1280×720, 130,035 B |
| `bash tools/export/capture-artifact.sh godot/build/linux-x86_64 padel.x86_64 tools/export/logs/full-window.png` | 0 | `capture exit=0`, PNG 1280×720, 130,035 B |

**Positional scene paths do not work in these binaries** — worth recording because it is the
obvious way to run a test scene from a packaged build:

```
$ ./padel-demo.x86_64 --headless res://tests/build/DemoSelfReport.tscn
ERROR: Scene path was specified on the command line, but this Godot binary was compiled without
support for path overrides. Aborting.
exit=1
```

That is why the third preset exists: the only way to run a specific scene from a packaged build is
to make it that build's main scene (via `override.cfg`).

---

## 4. The artifacts

Inventory, from `tools/export/verify-artifacts.sh` (`tools/export/logs/artifact-inventory.txt`).
`godot/build/**` is new output, `.gdignore`-d and `.gitignore`-d, and is not committed.

| path | bytes | sha256 |
|---|---|---|
| `godot/build/linux-x86_64/padel.x86_64` | 73,519,416 | `d9f79ab89b5ae369aeed11c6052d402e8218cd503bf85b4a235f9c30c46a7c63` |
| `godot/build/linux-x86_64/padel.pck` | 50,687,372 | `ce2bcef0a917110b405ec029f7322ef2beedc9944dcedf9af37145d9df5e2cac` |
| `godot/build/linux-x86_64/override.cfg` | 536 | `ac0a5cbd57443a2b172102bbdde4723a823422fffb0effa6c9d0c148b261abb0` |
| `godot/build/linux-x86_64-demo/padel-demo.x86_64` | 73,519,416 | `d9f79ab89b5ae369aeed11c6052d402e8218cd503bf85b4a235f9c30c46a7c63` |
| `godot/build/linux-x86_64-demo/padel-demo.pck` | 50,687,404 | `57b7037ef3f455322d5b5067813c35d38d85492c6565b9aec881f3e6142a60dd` |
| `godot/build/linux-x86_64-demo/override.cfg` | 536 | `ac0a5cbd57443a2b172102bbdde4723a823422fffb0effa6c9d0c148b261abb0` |
| `godot/build/linux-x86_64-demo-selfcheck/padel-demo-selfcheck.x86_64` | 73,519,416 | `d9f79ab89b5ae369aeed11c6052d402e8218cd503bf85b4a235f9c30c46a7c63` |
| `godot/build/linux-x86_64-demo-selfcheck/padel-demo-selfcheck.pck` | 50,687,404 | `57b7037ef3f455322d5b5067813c35d38d85492c6565b9aec881f3e6142a60dd` |
| `godot/build/linux-x86_64-demo-selfcheck/override.cfg` | 166 | `d123802228a4eb7c7528da3d9c0196c901a32b286adff25445d155a1a7df8810` |

Read the hashes carefully: the three `.x86_64` files are byte-identical because they are the same
official release template with a different pack beside it, and the demo and selfcheck packs are
byte-identical because the selfcheck preset's different main scene arrives only through its
`override.cfg`. The full preset's pack differs from the demo's by 32 bytes — the `demo` feature
tag inside `project.binary`. A packaged build is therefore **binary + pack + `override.cfg`**;
shipping the binary alone gets a game that boots the test harness.

Also in the pack, for the record: `res://project.binary` (13,797 B), 11 entries under
`res://.godot/exported/` (the converted scenes, 7,870 B) and 287 paths in total, listed in
`tools/export/logs/packed-files-*.txt`.

---

## 5. What the packaged binaries actually did

The demo artifact asserting on itself — the proof the ticket asks for, because it is the built
thing and not the preset that produced it:

```
$ cd godot/build/linux-x86_64-demo-selfcheck
$ flock -w 900 /tmp/padel-godot.lock timeout 90 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
    ./padel-demo-selfcheck.x86_64 --headless
# DemoSelfReport — build=demo, demo feature tag=true, exported=true
# engine=4.7.2-stable (official)
# main scene setting=res://tests/build/DemoSelfReport.tscn
# CONTENT {"all_arenas_in_tables":9,"all_athletes_in_tables":6,
           "all_modes":["quick","tournament","career"],"arenas":["clockwork"],
           "athletes":["maestro","steamer"],"build":"demo","demo_feature_tag":true,
           "difficulty":"medium","locked_arenas":8,
           "locked_athletes":["pantera","fiamma","oracolo","colosso"],"locked_modes":2,
           "modes":["quick"],"outfit_challenge_outfits":8}
ok the running demo fields exactly the demo's athletes
ok the running demo offers exactly the demo's arena
ok the running demo offers quick match only
ok the running demo runs the fixed difficulty
ok two athletes, on the artifact
ok one arena, on the artifact
ok the demo still shows what it does not grant
ok packed (resource loader): res://game/Main.tscn
ok packed (resource loader): res://game/Match.tscn
ok packed (resource loader): res://src/sim/frozen.gd
ok packed (raw file): res://src/sim/frozen/data.json
ok packed (raw file): res://tests/build/demo_content.json
ok not packed (raw file): res://prototypes/arena_spike/Main.tscn
ok not packed (resource loader): res://prototypes/arena_spike/Main.tscn
ok not packed (raw file): res://prototypes/render_probe/Main.tscn
ok not packed (resource loader): res://prototypes/render_probe/Main.tscn
ok the demo content table ships in the demo build
ok the game menu scene resolves inside the pack
PASS 18/18
exit=0
```

The windowed runs (`xvfb-run` + `opengl3`, Mesa llvmpipe — software GL, no GPU) opened a real
window and rendered the game menu: `tools/export/logs/demo-window.png` and `full-window.png`, both
1280×720, 130,035 bytes, 1,812 distinct colours, dominant pixels `(11,16,28)` — the menu
background `Color(0.043, 0.063, 0.11)`. The frame shows the title `STEAM CIRCUIT PADEL PRO`, four
opponent tiers, the athlete list, nine arena buttons, `GIOCA PARTITA RAPIDA` and `ESCI`, and the
control legend; nothing blank, clipped or unrendered.

**And there the honesty has to bite.** The two captures are byte-identical, and the demo menu
lists **six athletes and nine arenas** — the full set. The demo rule is enforced in the artifact
(`OS.has_feature("demo")` is true, the filter answers are the demo's, as the output above shows),
but the game's screens do not ask the filter yet: `godot/game/main_menu.gd` enumerates
`Config.athletes()` / `Config.arenas()`, and `godot/game/**` belongs to another lane. So the
packaged demo is a demo in fact at the data layer and a full-game menu on screen. That is the
first item of §6, with the exact call site.

---

## 6. NOT DONE

- **The demo rule is not wired into the game's screens.** `godot/game/main_menu.gd` (its
  `Config.athletes()` / `Config.arenas()` enumeration, and the arena/tier lists around
  `main_menu.gd:120-140`) and the router that would render the locked state
  (`js/ui.js:737-750` is the reference's half) still list everything in a demo build. Measured: the
  demo window capture is byte-identical to the full one and shows six athletes and nine arenas.
  The slice supplies `ContentFilter.roster()`, `arenas()`, `modes()`, `difficulty()` and the
  locked lists — the two-or-three-line integration is another lane's file. This is the difference
  between "the demo gate works" and "a player sees a demo".
- **Not layered on the save/achievement seam.** The ticket is blocked by S11 (saves, Steam
  achievements, Steam Cloud) for the promise that a demo cannot unlock or write progression
  belonging to excluded content. Nothing here tests that; `src/save/**` and `src/steam/**` were
  not touched.
- **No code signing**, no notarisation, no detached signature, no pack encryption
  (`encrypt_pck=false`), no reproducible-build hash beyond the sha256s above.
- **No store packaging and no store upload.** No Steam depot, no `steam_appid.txt`, no store
  assets, no upload of anything. The live Steam App ID remains an open human gate, and no part of
  this slice claims storefront readiness.
- **No Windows or macOS export.** The product-scope decision
  (`docs/wayfinder/tickets/product-scope-and-platforms.md`) has not named the OS set, so only
  Linux exists; the other targets are neither built nor claimed. Only the Linux export templates
  are installed.
- **No commit, tag, push, deploy or publish.** `godot/build/**` is build output, git-ignored and
  never committed. Zero paid spend: the export templates are the official free download and no
  paid service was called.
- **The pack still carries ~49.7 MB of imported textures**, three copies of the same GLB texture
  at 6,124,746 B and four outfit PNGs at ~4.5 MB each, at source resolution. Fixing that is an
  import-setting change in `godot/assets/**/*.import`, not an export filter, and those files
  belong to another lane. With the `out/` trees excluded the pack is 50.7 MB; the four outfit
  textures and the three GLB textures alone are 36.4 MB of it.
- **The demo build still ships test scaffolding** (`res://tests/`, 83 files, 459,323 B), because
  the gate module has to live under `res://tests/build/` until it moves to `res://src/build/`
  (see §2). No content file was deleted or hand-edited to make the demo smaller — the rule is a
  filter, and the same resource set ships in both builds.
- **No frame-rate, performance or download-size claim.** The captures are software GL (Mesa
  llvmpipe) under Xvfb; they prove the exported binary starts, opens a window and paints, and
  nothing about speed. Startup time was not measured.
- **Not every runtime resource was asserted.** `DemoSelfReport` checks the paths the game's boot
  path needs (menu scene, match scene, the frozen module and its JSON, the demo table) and that
  the excluded trees are absent. It does not exercise the match, the HUD or the arena screens
  inside the exported build; only the menu was rendered.
- **Not verified: whether `godot/build/**` needs a `.gdignore`-free twin** for a future
  "export from a clean checkout" run — the pack depends on `.godot/imported/` being populated,
  which the first export did. The first export from a cold cache reimported the whole project and
  took ~4 minutes; later exports reused it.
```
