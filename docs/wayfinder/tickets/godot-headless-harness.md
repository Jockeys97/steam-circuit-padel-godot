# Godot headless harness

- Status: resolved
- Type: research
- Mode: AFK
- Owner: crew-bravo
- Blocked by: none

## Question

**Which** engine version, and **how** does a headless test run? Decision record:
the pin, the headless command, and the failure signal, with the evidence that
proves each one on this host.

## Resolution

### 1. Engine pin: Godot 4.7.2 stable, Linux x86_64, official build

Installed at `/root/tools/godot/Godot_v4.7.2-stable_linux.x86_64` (sha256
`8d106cbe6144c2dc7e881d61d2429c1a8a76e6b22ef48bd5e48dcf934953f71e`, from
`/root/tools/godot/godot-linux.zip`). `--version` prints
`4.7.2.stable.official.ed1daf0bf`.

Confirmed against upstream, two independent statements:

- <https://godotengine.org/article/maintenance-release-godot-4-7-2/> — the
  maintenance-release announcement, dated 18 August 2026: *"This release is
  built from commit ed1daf0bf."*
- <https://github.com/godotengine/godot/releases/tag/4.7.2-stable> — official
  release tag, published 2026-08-18T16:12:28Z, which carries
  `Godot_v4.7.2-stable_linux.x86_64.zip` among its assets.

Checksums **are** published (per-asset `.sha256` files and a `SHA512-SUMS.txt`
in the release assets), but they were not fetched: this host was worked offline
and that file is not on disk, so the archive is only self-consistent with the
binary extracted from it, not proven byte-identical to upstream.

**Rule for moving the pin.** Only to another *stable* maintenance release, and
only with the release notes' own "built from commit" line as the source. The
pin is not a comment: `godot/tests/smoke_test.gd` asserts the full build hash
inside the run, so a runner carrying a different binary goes red. On real output
that assertion reads `Engine.get_version_info().hash` =
`ed1daf0bf001b61586d9930840f2f1394092c079`.

### 2. The headless run contract

```sh
timeout 120 /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/
```

- **`--headless` alone is enough. `xvfb-run` is not required for a headless
  run.** Proved, not assumed: the command above runs with `DISPLAY` unset and
  exits 0. Dropping `--headless` on the same host, still with no display, dies
  in `DisplayServerX11`/`DisplayServerWayland` with *"Unable to create
  DisplayServer, all display drivers failed"* and exit 1. `xvfb-run` is only
  relevant to tests that genuinely need a rendering context — it works on this
  host via software GL (`llvmpipe`), with audio falling back to the dummy
  driver, no GPU involved.
- **Failure signal.** Each check prints one machine-readable line,
  `ok <name>` or `FAIL <name>: expected <x>, got <y>`, and the run ends with
  `PASS <n>/<n>` or `FAIL <n>/<n>` on stdout, the failing line also on stderr.
  The process runs every check and then exits 0 if all passed or 1 if any
  failed, via `get_tree().quit(code)`, so CI needs no output parser — just the
  exit code, and `grep '^FAIL'` for the message.
- **`timeout` is part of the contract, not decoration.** A runtime error that
  aborts `_ready()` before `quit()` is reached leaves the main loop spinning:
  the job *hangs* instead of going red. `timeout` converts that into a kill and
  a non-zero code (observed 124). Verified with a deliberate bad call in
  `smoke_test.gd` (`-- --inject-abort`). `--quit-after N` also bounds the run,
  but it exits **0** — a hung run would read as green. Do not use it as the
  CI bound.
- **No test framework needed.** GUT and gdUnit are neither installed nor
  required; a plain scene-plus-script runner covers this. Trade-off recorded
  honestly: GUT would bring test discovery, per-test isolation, doubles and a
  JUnit report a CI runner can consume; the plain runner has none of that but
  is dependency-free and mirrors the existing shape of `run-audits.mjs`, which
  spawns one process per audit. One process per test scene is the same model.
  Revisit when the ported suite outgrows a single scene or needs isolation.

### 3. What exists now

`godot/` — 4 files, 24 KB, no addons, no art, no assets, nothing downloaded:

- `godot/project.godot` — physics tick **120 Hz** (the fixed step
  `js/main.js:1164` runs the web build on), `gl_compatibility` renderer, main
  scene `res://tests/SmokeTest.tscn`.
- `godot/tests/SmokeTest.tscn`, `godot/tests/smoke_test.gd` — 8 assertions
  covering the engine pin, the 120 Hz tick, and a measured property of the
  fixed-step loop (below).
- `godot/.gitignore` — ignores `.godot/`.

Verified run: `PASS 8/8`, exit 0. A headless run leaves no cache directory
behind; `godot/` stays at 4 files.

### 4. First ported assertion, and one finding the port needs

The 120 Hz tick is asserted already. The substantive finding: summing
`1.0/120.0` as floats **121 times** is what it takes to reach 1 s, because the
fraction accumulates past 1.0 on the 120th step. This is a measured value, now
pinned as an assertion, and it is the whole argument for the port counting
**integer ticks** rather than accumulating a float timestep — a float
accumulator drifts out of phase with the web build, which is exactly what
`determinism-audit.mjs` exists to catch. Ties directly to the "which assertion
ports first" question: `determinism-audit.mjs`, as `parity-harness.md` already
recommends.

### 5. Web baseline, for comparison

`npm run audit` → `node scripts/run-audits.mjs`: one process per
`scripts/*-audit.mjs`, sorted by name, exit 1 if any is red. A fresh read-only
run on 2026-09-16 scores **27/27, exit 0**. Note that
`evidence/baseline-audit.log` records **25/27** — `outfit-assets` and
`unlockable-animation` are green now (`sharp` resolves on this host). That
older red is stale, not repaired by this ticket; nothing under `scripts/` or
`js/` was touched.

CI wiring: the Godot harness is a **second job** beside the Node suite, not a
replacement. It proves the project loads, the pin holds, and the tick is right;
the Node suite keeps proving the rules until each audit is ported under its own
name.

## Evidence

- [`../evidence/godot-harness-smoke.log`](../evidence/godot-harness-smoke.log) —
  7 scenarios: the contract run, scene passed positionally, injected assertion
  failure, aborted `_ready` under `timeout` and under `--quit-after`, windowed
  without a display, windowed under `xvfb-run`. Includes stdout, stderr and
  exit code for each.
- [`../evidence/godot-harness-web-baseline.log`](../evidence/godot-harness-web-baseline.log) —
  the `npm run audit` run above.

Reproduce the smoke test (the env var only silences Godot's "started as root"
warning, so the log lines and the ticket match):

```sh
cd /root/projects/steam-circuit-padel-pro && \
  env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 timeout 120 \
    /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/; \
  echo "exit=$?"
```

## Residual unknowns

- **No GPU on this host.** All rendering evidence is software GL (`llvmpipe`).
  Whether a rendering-dependent test — screenshot comparison, shader
  compilation, visibility culling, frame-time budgets — behaves the same on a
  GPU runner or on the Steam target is **unproven**. The harness currently
  asserts nothing that needs a frame drawn, so this does not weaken the result
  above; it does bound it.
- **Upstream byte-identity unproven.** The published `SHA512-SUMS.txt` was not
  fetched (offline), so the archive/binaries are self-consistent only.
- **The hang is characterised, not eliminated.** Proved for a runtime error in
  `_ready`. Other failure classes (missing main scene, an import that fails,
  an out-of-memory kill) were not exercised; `timeout` covers them by
  construction, but that is reasoning, not measurement.
- **`--quit-after` semantics** observed only at 5 and 600 frames; not
  characterised in general, and it is known to exit 0 on an aborted run.
- **Only the editor binary was tested**, in headless mode. An exported release
  build in `--headless` is unmeasured.
- **Cross-platform determinism** of the fixed-step loop (x86_64 here versus
  arm64 / macOS Metal) is untested; the float-accumulator finding may differ.
- **The map still lists this ticket as open.** The map is maintained by another
  owner and was deliberately not touched here.
