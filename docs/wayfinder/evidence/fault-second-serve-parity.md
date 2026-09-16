# Fault / second-serve parity — the full-charge serve scenario on both engines

- **Date:** 2026-09-16 (CEST)
- **Repo:** `/root/projects/steam-circuit-padel-pro` @ working tree
- **Scenario spec:** `docs/wayfinder/evidence/parity-coverage-frontier.md` §4, rows **A1** (first serve fault)
  and **A2** (second serve).
- **Question this lane answers:** does the **ported Godot core** reproduce a first-serve FAULT and a
  SECOND SERVE for the first time, and does it agree with the frozen JavaScript reference tick for tick?
- **Answer:** **YES, on both counts.** First-serve fault at **tick 250**, second serve struck at
  **tick 253**, second serve lands in the box at **tick 377**, point lost at **tick 576** — identical on
  both engines, and the two digest streams are **byte-identical** (`parity-compare.mjs` strict,
  `--tol=0`, verdict `IDENTICAL`, same `digestSha256`).
- **Engine budget:** ONE heavy process at a time (host: 3910 MB, 0 swap, 300–750 MB free during this
  lane). Every Godot invocation ran under `timeout 120`, headless only, never two at once, and only
  after a `free -m` gate (available ≥ 350 MB, up to 3 waiting rounds of 120 s). One round of the gate
  fired SKIP (available 316 MB) and the run was retried later — nothing was run under the gate.

**Nothing in `js/**`, `scripts/**`, `docs/mission/**`, `docs/wayfinder/map.md`, `docs/wayfinder/tickets/**`,
`godot/prototypes/**` or any tracked file was modified. No git command that writes was run.
No commit, no push, no deployment, no paid API call, zero spend. `godot/src/sim/**` was NOT touched:
the comparison found no divergence, so there was nothing to fix.**

New files written (all inside the allowlist):

| file | role |
|---|---|
| `tools/sim-port/fault-digest.mjs` | the JS full-charge serve runner (frozen harness untouched) |
| `godot/src/sim/fault_digest_gd.gd` | the Godot full-charge serve runner |
| `tools/sim-port/fault-digest-gd.sh` | headless wrapper for the Godot runner |
| `tools/sim-port/trace-compare.py` | diffs the two engines' `# tr` / `# ev` traces |
| `docs/wayfinder/evidence/fault-second-serve-parity.md` | this document |

Frozen harness integrity: `scripts/parity-digest.mjs` sha256
`2b24dd26b20e3b5a856a2368e6425bd4cbd98592d58144e36f2d73b87d26fdcd` **before** the work and
`2b24dd26b20e3b5a856a2368e6425bd4cbd98592d58144e36f2d73b87d26fdcd` **after** (§7). Byte-identical,
never edited, never reformatted.

---

## 1. The runners (one new file per engine, no change to the frozen harness)

Serve trigger — a pure function of the simulated state, no `tick % N`:

```
charging: true every tick
hit:      (state.serving && state.shotCharge >= 0.999)
```

plus `state.setsToWin = 3` right after `createMatchState` (§4 item 3, keeps the match in the healthy
regime) and a stop at `state.result` (§4 item 4, so the post-result free-fall tail is never emitted as
if it were gameplay). Everything else — the digest field order, the `%.6f` formatting, the RNG-call
reconstruction, the `# ` headers and the `PARITY-DIGEST ... digestSha256=` summary — is the frozen
harness's shape, copied, so `tools/parity/parity-compare.mjs` and `tools/sim-port/compare-digests.py`
read both streams unchanged. `state.stats.doubleFaults` was deliberately **not** added to the digest
line: that would change the frozen field set and make every stream `NOT-COMPARABLE` for the comparator.
It is printed as a comment diagnostic instead (`# doubleFaults=p/a`), together with
`# fault-events`-style counts, `# resultTick=` and the two trace families below.

Both runners additionally print comment-only diagnostics, ignored by both comparators:

- `# tr tick=NNNNNN <key>=<value> ...` — one line per tick where a discrete field of the state moved
  (`serving`, `serveAttempts`, `bounces`, `points`, `games`, `sets`, `rallyHits`, `lastHitterSide`).
  It makes the fault tick and the second-serve tick visible **at tick resolution**, not only on the
  `--every` grid.
- `# ev tick=NNNNNN events0="..."` — the newest in-game event.

**Tick convention used everywhere below.** A trace line printed at tick `T` is the state *after* the
step that started at tick `T-1`. So "the trace shows `serveAttempts=1` at tick 251" means the fault
happened **during tick 250** — the same convention `parity-coverage-frontier.md` uses, and the same tick
that carries the fault event.

---

## 2. JavaScript reference — fault and second serve reproduced

```bash
node tools/sim-port/fault-digest.mjs --seed=999 --ticks=600 --every=60 \
  --json=tools/sim-port/out/fault-js-999-600-60.json > tools/sim-port/out/fault-js-999-600-60.txt   # exit 0
```

Transition trace, seed 999 (seed 12345 is the same except the point is lost one tick earlier):

```
# tr tick=000000 serving=1 serveAttempts=0 bounces=0/0 points=0-0 games=0-0 sets=0-0 rallyHits=0 lastHitterSide=null
# tr tick=000127 serving=0 lastHitterSide=player          <- first serve STRUCK, charge full
# tr tick=000251 serving=1 serveAttempts=1                 <- FAULT during tick 250, reserve armed
# tr tick=000254 serving=0                                 <- SECOND SERVE struck during tick 253
# tr tick=000378 bounces=0/1                               <- second serve LANDS IN THE BOX (tick 377)
# tr tick=000380 bounces=0/0 rallyHits=1 lastHitterSide=ai
# tr tick=000500 bounces=1/0
# tr tick=000577 serveAttempts=0 bounces=2/0 points=0-1    <- point lost during tick 576
# doubleFaults=0/0   # resultTick=none
```

Event heads (JS stores localized text in `state.events`; the port stores message ids — `state.gd:18`):

```
# ev tick=000251 events0="Serve out of the diagonal box. Second serve."
# ev tick=000254 events0="Second serve from below: aim for the diagonal."
# ev tick=000378 events0="Valid serve: bounce in the opposite box."
# ev tick=000577 events0="Second bounce: point lost."
```

This reproduces the previously-verified probe exactly: **fault at tick 250**, reason `serveOutBox`
(`js/game.js:2163`, the out-of-box path, *not* the glass path), `serveAttempts` 0→1 at 250, **second
serve struck at 253**, second serve lands in the box at **377**, point lost at **576**
(`serveAttempts` back to 0). `doubleFaults` stays 0/0, no `state.result` inside 600 ticks.

The fault is visible **in the digest line itself**, not only in the trace — and the reserve reset is
unmistakable (`prepareServe` re-places the ball at the server, `z=34`, `bounces=0/0`):

| tick | ball (x,y,z) | bounces | serveAttempts |
|---:|---|---|---|
| 249 | (297.552850, 183.241758, 3.607891) | 0/0 | 0 |
| **250** | (295.328131, 181.232823, 0.283776) | 0/0 | **0 → FAULT here** |
| **251** | (596.000000, 462.000000, 34.000000) | 0/0 | **1** (reserve armed, ball re-placed) |
| 252 | (597.268000, 460.529120, 34.000000) | 0/0 | 1 |
| **253** | (598.536000, 459.058240, 34.000000) | 0/0 | 1 → **SECOND SERVE struck** |
| 254 | (599.804000, 457.587360, 34.000000) | 0/0 | 1 |
| 377 | (287.425450, 194.125621, 0.283776) | 0/0 | 1 → **lands in the box** |
| 378 | (284.988823, 192.081774, 1.864183) | **0/1** | 1 |

On the 60-tick grid the fault window 250–575 shows up as `serveAttempts` 0→1 between the samples at
tick 240 and tick 300, and back to 0 at tick 600 — for both engines identically.

---

## 3. Godot leg — the ported core reproduces it

```bash
tools/sim-port/fault-digest-gd.sh --seed=999   --ticks=600 --every=60   # exit 0, 11 digest lines
tools/sim-port/fault-digest-gd.sh --seed=12345 --ticks=600 --every=60   # exit 0, 11 digest lines
tools/sim-port/fault-digest-gd.sh --seed=999   --ticks=600 --every=1    # exit 0, 601 digest lines
tools/sim-port/fault-digest-gd.sh --seed=12345 --ticks=600 --every=1    # exit 0, 601 digest lines
```

The Godot transition trace is **character-for-character the same** as the JavaScript one, for both
seeds:

```
[seed 999]   identical 8-line trace: 000000 / 000127 / 000251 / 000254 / 000378 / 000380 / 000500 / 000577
[seed 12345] identical 8-line trace: 000000 / 000127 / 000251 / 000254 / 000378 / 000379 / 000499 / 000576
```

Event ticks are identical too (`0, 127, 251, 254, 378, 534, 577` for seed 999; `…, 525, 576` for seed
12345); the message *text* differs by design, id for id:

| tick | JavaScript (localized text) | Godot (message id) |
|---:|---|---|
| 127 | `First serve from below: aim for the diagonal.` | `serveHint` |
| **251** | `Serve out of the diagonal box. Second serve.` | **`serveOutBox secondServe`** |
| 254 | `Second serve from below: aim for the diagonal.` | `serveHint` |
| 378 | `Valid serve: bounce in the opposite box.` | `evServeValid` |
| 534 / 525 | `Valid glass after the bounce!` | `evWallValid` |
| 577 / 576 | `Second bounce: point lost.` | `msgDoubleBounce` |

So the port hits the **same** fault path (`serveOutBox`, `sim.gd`'s `serve_fault`) on the **same** tick,
arms the reserve the same way, and strikes the second serve on the same tick. `# doubleFaults=0/0` and
`# resultTick=none` on both sides.

One honest caveat about a *diagnostic counter*, not about behaviour: the JS runner reports
`# first-serve-faults=2` against the port's `1` for seed 999. That counter is a text match on the event
buffer, and the JavaScript reference's *second-serve hint text* ("**Second serve** from below…") also
matches it, while the port's `serveHint` id does not. The fault itself occurs exactly once, at tick 251,
on both engines — as the identical transition traces show. The counter is a heuristic; the traces and
the digest are the evidence.

---

## 4. Cross-engine comparison — VERDICT: IDENTICAL (strict, no tolerance)

`tools/parity/parity-compare.mjs` with **`--tol=0` (the strict, honest default): the printed text of all
21 compared fields, on every sampled tick, is identical — floats included, not merely within the
unmeasured `1e-3` proposal.**

| seed | every | sampled ticks | JS digestSha256 | GD digestSha256 | parity-compare.mjs (strict) | exit | compare-digests.py | trace-compare.py |
|---:|---:|---:|---|---|---|---:|---|---|
| 999 | 60 | 11 | `fb323d83…7bdd18` | `fb323d83…7bdd18` | `RESULT=IDENTICAL firstTick=- comparedSamples=11 comparedFields=21 digestSha256-identical` | 0 | `IDENTICAL common_ticks=11` | `IDENTICAL` |
| 12345 | 60 | 11 | `45cebcff…e9164a` | `45cebcff…e9164a` | `RESULT=IDENTICAL … comparedSamples=11 … digestSha256-identical` | 0 | `IDENTICAL common_ticks=11` | `IDENTICAL` |
| 999 | 1 | 601 | `bfc73441…92a46` | `bfc73441…92a46` | `RESULT=IDENTICAL … comparedSamples=601 … digestSha256-identical` | 0 | `IDENTICAL common_ticks=601` | `IDENTICAL` (transitions `(251,0→1), (577,1→0)` on both) |
| 12345 | 1 | 601 | `1486e011…448a14` | `1486e011…448a14` | `RESULT=IDENTICAL … comparedSamples=601 … digestSha256-identical` | 0 | `IDENTICAL common_ticks=601` | `IDENTICAL` (transitions `(251,0→1), (576,1→0)` on both) |

Because `digestSha256` (the sha256 of the digest lines joined by `\n` plus a trailing `\n`) is equal, the
two streams are **byte-identical**, not merely field-equal within a tolerance. `integrity=OK` on all
eight streams (each producer's declared hash matches the hash recomputed from the lines present).

Fine-probe (`--every=1`) sample lines around the fault are byte-identical too — e.g. seed 999, tick 250
`ball=(295.328131,181.232762,0.283776) bounces=0/0 serveAttempts=0` and tick 251
`ball=(596.000000,462.000000,34.000000) bounces=0/0 serveAttempts=1` are the same bytes on both engines,
and tick 378 `bounces=0/1` marks the landing on both.

**No divergence was found, so `godot/src/sim/**` was not modified and no fix was applied** (the
allowlist permitted a fix only for a real divergence).

### What this means for the coverage frontier

`js/game.js:727` (`const secondServe = state.serveAttempts > 0`), the `serveSecondSafety` factor, the
whole `serveFault` reserve branch and the `serveAttempts`-driven `prepareServe` path were, per
`parity-coverage-frontier.md` §2.6, **unexercised on both engines** (0 non-zero `serveAttempts` in all
31 existing streams, including a 2286-tick `every=1` probe). This scenario exercises them for the first
time and they agree bit for bit. That closes the coverage gap the frontier document named as the
parity claim's main risk.

---

## 5. Commands run (exact, with exit codes)

```bash
cd /root/projects/steam-circuit-padel-pro

# JS side (light, one node process at a time)
node tools/sim-port/fault-digest.mjs --seed=999   --ticks=600 --every=60  --json=…json > …      # exit 0
node tools/sim-port/fault-digest.mjs --seed=999   --ticks=600 --every=1   --json=…json > …      # exit 0
node tools/sim-port/fault-digest.mjs --seed=12345 --ticks=600 --every=60  --json=…json > …      # exit 0
node tools/sim-port/fault-digest.mjs --seed=12345 --ticks=600 --every=1   --json=…json > …      # exit 0

# Godot side — memory-gated (free -m >= 350 MB, up to 3 x 120 s wait), one process at a time,
#              every run under `timeout 120` inside fault-digest-gd.sh
tools/sim-port/fault-digest-gd.sh --seed=999   --ticks=600 --every=60    # exit 0  (gate: 416 MB)
tools/sim-port/fault-digest-gd.sh --seed=12345 --ticks=600 --every=60    # exit 0  (gate: 366 MB)
tools/sim-port/fault-digest-gd.sh --seed=999   --ticks=600 --every=1     # exit 0  (1st gate SKIP @316 MB, retried @485 MB)
tools/sim-port/fault-digest-gd.sh --seed=12345 --ticks=600 --every=1     # exit 0  (gate: 745 MB)

# comparators, unchanged tools, four streams each
node  tools/parity/parity-compare.mjs <js.txt> <gd.txt> --json=…      # exit 0 x4, RESULT=IDENTICAL
python3 tools/sim-port/compare-digests.py <js.txt> <gd.txt>           # exit 0 x4, IDENTICAL
python3 tools/sim-port/trace-compare.py  <js.txt> <gd.txt>            # exit 0 x4, RESULT=IDENTICAL

sha256sum scripts/parity-digest.mjs                                    # 2b24dd26…fdcd, before and after
git status --porcelain                                                 # read-only: no tracked file modified
```

`free -m` was checked before each Godot run; available memory moved between 316 MB and 745 MB. Exactly
one engine process existed at any moment. No xvfb, no `--rendering-driver`, no rendering of any kind.

---

## 6. VERIFIED vs INFERRED

**VERIFIED (ran it, both engines)**

- First-serve **FAULT at tick 250** (event `serveOutBox`, `js/game.js:2163`; reserve armed), seed 999
  and seed 12345 — with the ball actually leaving the diagonal box (tick 250 ball y=181.23 against a
  service line at y=184 with the receiver's box requiring the ball inside it).
- **SECOND SERVE struck at tick 253** and **landing in the box at tick 377**; point lost at **576**
  (`serveAttempts` 1→0, `bounces` 2/0, `points` 0-1).
- The **ported Godot core reproduces every one of these ticks** and the whole digest stream
  byte-identically (`parity-compare.mjs` strict `IDENTICAL`, equal `digestSha256`) at `--every=60`
  (11 samples) and `--every=1` (601 samples), for both seeds.
- `doubleFaults` stays 0/0 and no `state.result` occurs inside the 600-tick budget — the run stays in
  the healthy regime, as §4 requires.
- The full-charge serve reaches a charge the frozen harness can never reach (the frozen script caps at
  0.3254 against a ≈0.90 fault threshold), which is why this branch was dead before.

**INFERRED (not measured here)**

- That these two seeds are the only, or the cheapest, seeds that fault on the first serve. Only two
  seeds were run in this lane.
- That the port's behaviour generalises to a *double* fault (A3): `serveAttempts` reaches 1 here and
  returns to 0 via a lost point, never via a second fault inside 600 ticks. A3 is out of this lane's
  scope and remains unmeasured.
- That longer budgets keep the agreement (a set/game-scale run needs the §4 D2 configuration and
  ~22 000 ticks; not run here).

**NOT proven / explicitly out of scope**

- Anything about the post-`state.result` tail: the runners stop at the result by construction, so no
  line after a match-ending point is ever compared as gameplay.

---

## 7. Drift statement

- Files created, all allowlisted: the four new files plus this document (§ header table).
- Files modified: **none**. `scripts/parity-digest.mjs` is byte-identical to the frozen reference
  (`2b24dd26b20e3b5a856a2368e6425bd4cbd98592d58144e36f2d73b87d26fdcd`, before and after).
- `godot/src/sim/**` was **not** touched: the cross-engine comparison exposed no divergence, so the
  conditional fix permission was never exercised (no backup, no md5 before/after to report).
- `git status --porcelain` (read-only) lists only untracked directories (`docs/`, `godot/`, `meshy/`,
  `tools/`, `scripts/parity-digest.mjs`) — no tracked file shows as modified.
- No git write command, no commit, no push, no deployment, no provider/model configuration change.
- **Spend: $0 — 0 paid calls, 0 metered inference, no network access used by this lane.**
