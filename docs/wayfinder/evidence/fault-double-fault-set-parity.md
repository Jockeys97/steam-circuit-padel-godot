# Fault / double-fault / completed-set parity — A3 and D2 on both engines

- **Date:** 2026-09-16 (CEST) — written INCREMENTALLY (each section as its run finished).
- **Repo:** `/root/projects/steam-circuit-padel-pro` @ git HEAD `297958852bafdd1b5811afc41b4030b55d0750eb`, working tree dirty only with untracked dirs.
- **Scenario spec:** `docs/wayfinder/evidence/parity-coverage-frontier.md` §4, rows **A3** (double fault) and **D2** (completed set, match still healthy), plus §4's "What a new file under `tools/sim-port/**` must do".
- **Prior lane, not re-derived:** `docs/wayfinder/evidence/fault-second-serve-parity.md` (A1 first-serve fault + A2 second serve, already IDENTICAL on both engines) — **re-run here and still byte-identical** (§2).
- **Question this lane answers:** does the ported Godot core reproduce a **DOUBLE FAULT** and a **COMPLETED SET with the match still healthy**, byte-identically with the frozen JavaScript reference?
- **Answers, one line each:**
  - **A3 — YES, with one honest qualification.** A double fault is **not reachable with the frozen harness's athlete** (`ATHLETES[0]` "maestro", `control 1.28`), for a structural reason given in §1.3. Reached and proven IDENTICAL on both engines with `--athlete=1` ("pantera", `control 0.96`): first-serve fault during tick **250**, second serve struck at **full charge 1.000000** during tick **253**, the reserve serve itself out of the box during tick **377** → `doubleFaults 1/0`.
  - **D2 — YES.** `setsToWin=3`, 28 800 ticks: set 1 closed **0-6** during tick **12691**, set 2 closed **0-6** during tick **25537**, `resultTick=none`, no `ball.z` runaway (|z| ≤ 164.13, last sample z = 34.0) — and the two streams are **byte-identical**, `parity-compare.mjs` strict `--tol=0`, `IDENTICAL`, equal `digestSha256`, on 481 samples (`--every=60`) **and on 28 801 samples (`--every=1`)**.
- **Engine budget:** ONE heavy process at a time, always through `tools/sim-port/fault-digest-gd.sh` (`timeout 120`, headless, `env -u DISPLAY`). Never xvfb, never rendering, never two engines at once; at most one `node` process besides Godot. Every Godot run was preceded by `free -m` (available 610–772 MB, host 3910 MB, 0 swap); all runs finished with exit 0 and no OOM.

**Nothing in `js/**`, `scripts/**`, `docs/mission/**`, `docs/wayfinder/map.md`, `tools/character/**`, `tools/audio-port/**`, `godot/prototypes/**` or any tracked file was modified. No git write command, no commit, no push, no deployment, no paid API call, no network retrieval, zero spend.**

Frozen harness integrity: `scripts/parity-digest.mjs` sha256
`2b24dd26b20e3b5a856a2368e6425bd4cbd98592d58144e36f2d73b87d26fdcd` before and after (§7).

`git status --porcelain` (read-only) lists only untracked directories (`docs/ tools/ godot/ meshy/ scripts/parity-digest.mjs`) — no tracked file is modified.

---

## 1. What was extended, and why one flag was needed

### 1.1 The change (extend, do not fork)

Both existing full-charge serve runners were extended **in place**; no second divergent implementation:

| file | change |
|---|---|
| `tools/sim-port/fault-digest.mjs` | new `--athlete=<index>` (default **0**, so every pre-existing scenario is byte-identical); strike detector, double-fault detector, set-closure detector |
| `godot/src/sim/fault_digest_gd.gd` | the exact mirror of all of the above |
| `tools/sim-port/trace-compare.py` | additionally compares the new `# strike` / `# double-fault` / `# set-closed` comment families textually (old streams have none, so their verdicts are unchanged) |
| `tools/sim-port/double-fault-probe.mjs` | **new, recon only** (§1.3): measures the second-serve fault rate in isolation. Read-only w.r.t. `js/**` |
| `tools/sim-port/fault-digest-gd.sh` | **unchanged** (sha256 `3cf8f588…5afd`) |
| `docs/wayfinder/evidence/fault-double-fault-set-parity.md` | this document |

The digest line itself was **not** touched: same 21 fields, same order, same `%.6f` formatting, same
`PARITY-DIGEST … digestSha256=` summary — `parity-compare.mjs` and `compare-digests.py` read the new
streams unchanged. `state.stats.doubleFaults` was deliberately kept **out** of the digest line (adding
a field would make every stream `NOT-COMPARABLE`) and printed as diagnostics instead:

```
# strike tick=NNNNNN kind=first|second charge=X.XXXXXX serveSide=<player|ai>
# double-fault tick=NNNNNN server=<player|ai> total=N
# set-closed tick=NNNNNN sets=p-a games=p-a
# serves=N firstServes=N secondServes=N
# second-serve-charges=<distinct charges>
# doubleFaults=p/a     # doubleFaultTicks=…     # setClosures=…     # resultTick=…
```

Tick convention, unchanged from the prior lane: a `# tr` line printed at tick `T` is the state **after**
the step that started at `T-1`; a `# strike` / `# double-fault` line at tick `T` means the event happened
**during tick `T`**.

### 1.2 The mission's explicit requirement — "the second serve must ALSO be struck at full charge" — is now printed, not assumed

The runner's own trigger predicate (`state.serving && state.shotCharge >= 0.999`) is satisfied on the
second serve too, and the charge the predicate observed is now emitted:

```
# strike tick=000126 kind=first  charge=1.000000 serveSide=player
# strike tick=000253 kind=second charge=1.000000 serveSide=player
# second-serve-charges=1.000000
```

Identical text on both engines (`TRACE-COMPARE … STRIKE identical`). So the second serve **is** a
full-charge serve; that is a measured fact here, not an inference from `performServe`'s default of 0.62.

### 1.3 Why A3 needed `--athlete` (the honest part)

With the frozen harness's athlete (`ATHLETES[0]` "maestro", `control 1.28`) a **full-charge second serve
can never fault**, even though a full-charge first serve can. The arithmetic
(`js/game.js:728-734`, `js/data.js:136-139`):

```
spread        = 60 · (0.42 + 0.58·charge²) · clamp(1.62 − control, 0.3, 1.0) · (secondServe ? 0.70 : 1)
aim depth     = 126 · (0.24 + 0.52·charge) + depthError,  |depthError| ≤ 1.15 · spread
service box   = 126 px deep  (SERVICE_LINE_OFFSET, js/game.js:30-32)
```

| athlete | control | clamp factor | spread @ charge 1 (2nd serve) | worst aim depth |
|---|---:|---:|---:|---:|
| 0 maestro | 1.28 | 0.34 | 14.28 | 112.2 (< 126) |
| 1 pantera | 0.96 | 0.66 | 27.72 | 127.6 (> 126) |

Measured with `tools/sim-port/double-fault-probe.mjs` (300 seeds × one serve, second-serve condition,
charge 1.0, first bounce inspected):

| athlete | first-serve faults / 300 | **second-serve faults / 300** |
|---|---:|---:|
| 0 maestro | 33 | **0** |
| 1 pantera | 78 | **63** |

and in the live runner at the default athlete: 4 000 ticks × seeds {999, 2024, 7, 12345, 999983} →
12 first-serve faults, `# doubleFaults=0/0` on all five. So the double fault is an **athlete-dependent
reachability** property of the reference, exactly like the earlier finding that the frozen *documented*
serve trigger caps at charge 0.3254 against a ≈0.90 first-serve fault threshold. `--athlete=1` is the
smallest honest input-driver change that reaches the branch; the default stays 0 and nothing else moves.

---

## 2. Non-regression — the two prior-lane scenarios still reproduce byte-identically

```bash
node        tools/sim-port/fault-digest.mjs   --seed=999   --ticks=600 --every=1   # exit 0
tools/sim-port/fault-digest-gd.sh             --seed=999   --ticks=600 --every=1   # exit 0
node        tools/sim-port/fault-digest.mjs   --seed=12345 --ticks=600 --every=1   # exit 0
tools/sim-port/fault-digest-gd.sh             --seed=12345 --ticks=600 --every=1   # exit 0
node tools/parity/parity-compare.mjs <js> <gd> --quiet                             # exit 0 ×2
```

| seed | ticks | every | samples | digestSha256 (both engines) | parity-compare |
|---:|---:|---:|---:|---|---|
| 999 | 600 | 1 | 601 | `bfc734410016741f10d0fdb253ec2e63f511672cbc84d1910ff014192bf92a46` | `RESULT=IDENTICAL`, exit 0 |
| 12345 | 600 | 1 | 601 | `1486e011738776f6afcb45d587228ce9018a80799bbf5f6ce4cba7eac1448a14` | `RESULT=IDENTICAL`, exit 0 |

Both hashes are exactly the ones the prior lane recorded, and the non-comment output of the extended
runner is byte-identical to its own pre-change output (`diff` clean). **The known-good reproduction is
preserved.** The same run prints `# strike tick=000253 kind=second charge=1.000000` on both engines.

---

## 3. A3 — the DOUBLE FAULT

### 3.1 Command lines

```bash
cd /root/projects/steam-circuit-padel-pro

# JS reference (one node process at a time)
node tools/sim-port/fault-digest.mjs --seed=999   --ticks=4000 --every=1 --athlete=1 \
     --json=tools/sim-port/out/a3-js-999-4000-1.json   > tools/sim-port/out/a3-js-999-4000-1.txt    # exit 0
node tools/sim-port/fault-digest.mjs --seed=12345 --ticks=4000 --every=1 --athlete=1 \
     --json=tools/sim-port/out/a3-js-12345-4000-1.json > tools/sim-port/out/a3-js-12345-4000-1.txt  # exit 0

# Godot port (headless, timeout 120, memory-gated: 732 MB / 763 MB available)
tools/sim-port/fault-digest-gd.sh --seed=999   --ticks=4000 --every=1 --athlete=1 \
     > tools/sim-port/out/a3-gd-999-4000-1.txt     # exit 0, 1.2 s
tools/sim-port/fault-digest-gd.sh --seed=12345 --ticks=4000 --every=1 --athlete=1 \
     > tools/sim-port/out/a3-gd-12345-4000-1.txt   # exit 0

# comparators (unchanged tools)
node    tools/parity/parity-compare.mjs <a3-js> <a3-gd> --quiet      # exit 0 ×2
python3 tools/sim-port/compare-digests.py <a3-js> <a3-gd>            # exit 0 ×2
python3 tools/sim-port/trace-compare.py  <a3-js> <a3-gd>             # exit 0 ×2
```

### 3.2 Observed — the double fault actually happens (seed 999; seed 12345 identical in every field)

```
# ev tick=000251 events0="Serve out of the diagonal box. Second serve."
# ev tick=000254 events0="Second serve from below: aim for the diagonal."
# ev tick=000378 events0="Double fault: serve out of the diagonal box."
# tr tick=000251 serving=1 serveAttempts=1        <- reserve armed
# tr tick=000254 serving=0                        <- second serve struck
# tr tick=000378 serveAttempts=0 points=0-1
# strike tick=000126 kind=first  charge=1.000000 serveSide=player
# strike tick=000253 kind=second charge=1.000000 serveSide=player
# double-fault tick=000377 server=player total=1
# serves=9 firstServes=8 secondServes=1
# second-serve-charges=1.000000
# doubleFaults=1/0
# doubleFaultTicks=377:player
# resultTick=none
```

Tick by tick, with the digest line as the witness (`--every=1`, so every tick is on the record):

| tick | ball (x,y,z) | bounces | serveAttempts | what happens |
|---:|---|---|---|---|
| 250 | — | 0/0 | 0→ (trace at 251 = 1) | **first-serve fault** (`serveOutBox`), reserve armed |
| 253 | — | 0/0 | 1 | **second serve struck at full charge 1.000000** |
| 377 | — | 0/0 | 1 | second serve's first bounce is out of the box → **DOUBLE FAULT** (`doubleFaults` 0→1) |
| 378 | (283.691661, **183.292955**, -3.090340) | 0/0 | **0** | `points=0-1`, `playerScore=0`, `aiScore=15`, `pointsWon=0-1` |

`183.292955 < SERVICE_TOP = 184` — the reserve serve was **long by 0.71 px**, i.e. it faulted on exactly
the same `serveOutBox` path as the first serve, not on some incidental path. The contrast that makes the
athlete flag necessary is visible in the existing A1/A2 evidence: with maestro the *same* tick-377 second
serve lands at `y = 192.081774` (inside the box, `bounces 0/1`, point played out normally).

`doubleFaults > 0` was therefore **observed, at tick 377, on the player's serve, on both seeds.**

### 3.3 Cross-engine verdict — IDENTICAL, byte for byte

| seed | sampled ticks | JS digestSha256 | GD digestSha256 | parity-compare (strict) | exit |
|---:|---:|---|---|---|---:|
| 999 | 4001 | `23f5fb1595b6bd0e9aa7c1c8fb6acbc2e063b6dab9d9faa591eb8cbed969207e` | same | `RESULT=IDENTICAL comparedSamples=4001 digestSha256-identical` | 0 |
| 12345 | 4001 | `f0df289bb5b92d3ab6fd44ff5ccb2063b4a25d30c5852465cf0f07461fba4631` | same | `RESULT=IDENTICAL comparedSamples=4001 digestSha256-identical` | 0 |

`compare-digests.py`: `IDENTICAL common_ticks=4001` on both. `trace-compare.py`: `TRACE-COMPARE
RESULT=IDENTICAL`, `# tr` identical on all **39** transition ticks, `STRIKE identical (9 lines)` with every
strike at `charge=1.000000`, `DOUBLE-FAULT identical: [(377, 'server=player total=1')]`, and the same
`serveAttempts` transitions `[(251, 0, 1), (378, 1, 0)]` on both engines.

**First differing tick: none.** No `godot/src/sim/**` fix was needed, so none was made.

---

## 4. D2 — the COMPLETED SET, match still healthy

### 4.1 Command lines

```bash
node tools/sim-port/fault-digest.mjs --seed=12345 --ticks=28800 --every=60 --sets=3 \
     --json=tools/sim-port/out/d2-js-12345-28800-60.json > tools/sim-port/out/d2-js-12345-28800-60.txt  # exit 0
node tools/sim-port/fault-digest.mjs --seed=999   --ticks=28800 --every=60 --sets=3 \
     --json=tools/sim-port/out/d2-js-999-28800-60.json   > tools/sim-port/out/d2-js-999-28800-60.txt    # exit 0

tools/sim-port/fault-digest-gd.sh --seed=12345 --ticks=28800 --every=60 --sets=3 \
     > tools/sim-port/out/d2-gd-12345-28800-60.txt   # exit 0, 3.1 s
tools/sim-port/fault-digest-gd.sh --seed=999   --ticks=28800 --every=60 --sets=3 \
     > tools/sim-port/out/d2-gd-999-28800-60.txt     # exit 0, 2.9 s

# strongest form: every tick, whole run
node tools/sim-port/fault-digest.mjs --seed=12345 --ticks=28800 --every=1 --sets=3 \
     > tools/sim-port/out/d2-js-12345-28800-1.txt                                                    # exit 0
tools/sim-port/fault-digest-gd.sh --seed=12345 --ticks=28800 --every=1 --sets=3 \
     > tools/sim-port/out/d2-gd-12345-28800-1.txt                                                    # exit 0
```

### 4.2 Observed — a real completed set, match still healthy

Seed 12345 (`--every=60`):

```
# set-closed tick=012691 sets=0-1 games=0-0      # set-closed tick=025537 sets=0-2 games=0-0
# serves=62 firstServes=56 secondServes=6
# doubleFaults=0/0
# resultTick=none
```

Set 1 is a genuinely completed set, six games, not a single lucky point — the game transitions inside set 1
(`--every=1` stream) are

```
tick 0      games 0-0 sets 0-0
tick 2341   games 0-1
tick 4273   games 0-2
tick 6764   games 0-3
tick 8696   games 0-4
tick 10760  games 0-5
tick 12692  games 0-0 sets 0-1     <- set 1 won 6-0, games reset, MATCH STILL ALIVE
tick 15279  games 0-1              <- set 2 under way
…
tick 25538  games 0-0 sets 0-2     <- set 2 won 6-0, match still alive
tick 27650  games 0-1              <- set 3 under way at the end of the 28 800-tick budget
```

Health of the run (all 28 801 `--every=1` samples): `ball.z ∈ [−1.865345, +164.129474]`, final sample
`tick=028800 ball=(364.000000,158.000000,34.000000) sets=0-2 games=0-1 points=0-2` — i.e. a normal
pre-serve ball placement, **no post-result free-fall** (`z → −1e6`) and `resultTick=none`: `setsToWin=3`
kept the match alive exactly as `parity-coverage-frontier.md` §4 item 3 requires. Seed 999 gives the same
shape with its own ticks (`setClosures=12595:0-1,24681:0-2`, also 6-0, also `resultTick=none`).

> Honest deviation from the spec's estimate: §4 predicted the first closed set at **~22 260 ticks**. That
> number came from the *frozen* input script (`frontier-probe.mjs --mode=frozen --sets=3`). With this
> runner's **full-charge** serve trigger the server wins points far faster, so set 1 closes at **12 691**
> (seed 12345) / **12 595** (seed 999). The row's substance — a completed set with the match healthy — is
> met; only the tick estimate moves, and it moves because the input driver differs by design.

### 4.3 Cross-engine verdict — IDENTICAL, byte for byte

| seed | ticks | every | samples | digestSha256 (both engines) | parity-compare | exit |
|---:|---:|---:|---:|---|---|---:|
| 12345 | 28800 | 60 | 481 | `568a5290b2606f63a6d55bb86050de1a2a33f639542fbc128887c6d8e38236ff` | `RESULT=IDENTICAL … comparedSamples=481 digestSha256-identical` | 0 |
| 999 | 28800 | 60 | 481 | `49992da82ea299a19d8afceac4606649a9b246c3766bb0bf8a67da06d397acf9` | `RESULT=IDENTICAL … comparedSamples=481 digestSha256-identical` | 0 |
| **12345** | **28800** | **1** | **28801** | `cea85c2ae92cfab4f70c18fd1c795db0c73c389dbcf8a02d30820e49ba122cf4` | `RESULT=IDENTICAL … comparedSamples=28801 digestSha256-identical` | 0 |

`compare-digests.py`: `IDENTICAL common_ticks=481 / 481 / 28801`. `trace-compare.py`: `TRACE-COMPARE
RESULT=IDENTICAL` on all three pairs — `# tr` identical on all 289 (seed 12345) / 287 (seed 999)
transition ticks, all 62 / 60 strike lines identical with `charge=1.000000`, and
`SET-CLOSED identical: [(12691, 'sets=0-1 games=0-0'), (25537, 'sets=0-2 games=0-0')]`.

Because `digestSha256` (sha256 of the 21-field digest lines) is equal on 28 801 consecutive ticks —
**not a sampled subset, every tick of a 4-minute match** — the two streams are byte-identical, floats
included, under the strict `--tol=0` reading. **First differing tick: none.**

---

## 5. Commands run (exact) — one engine process at a time

```bash
cd /root/projects/steam-circuit-padel-pro

# reconnaissance (JS only, read-only w.r.t. js/**)
node tools/sim-port/double-fault-probe.mjs --seeds=300 --q=1.0                # exit 0
node tools/sim-port/double-fault-probe.mjs --seeds=300 --q=1.0 --athlete=1    # exit 0
node tools/sim-port/fault-digest.mjs --seed={999,2024,7,12345,999983} --ticks=4000 --every=1000   # exit 0 ×5

# non-regression (A1/A2)          · Godot runs memory-gated, `timeout 120`, headless
node tools/sim-port/fault-digest.mjs --seed=999   --ticks=600 --every=1        # exit 0
tools/sim-port/fault-digest-gd.sh    --seed=999   --ticks=600 --every=1        # exit 0  (gate 763 MB)
node tools/sim-port/fault-digest.mjs --seed=12345 --ticks=600 --every=1        # exit 0
tools/sim-port/fault-digest-gd.sh    --seed=12345 --ticks=600 --every=1        # exit 0

# A3
node tools/sim-port/fault-digest.mjs --seed=999   --ticks=4000 --every=1 --athlete=1   # exit 0
tools/sim-port/fault-digest-gd.sh    --seed=999   --ticks=4000 --every=1 --athlete=1   # exit 0  (gate 732 MB)
node tools/sim-port/fault-digest.mjs --seed=12345 --ticks=4000 --every=1 --athlete=1   # exit 0
tools/sim-port/fault-digest-gd.sh    --seed=12345 --ticks=4000 --every=1 --athlete=1   # exit 0

# D2
node tools/sim-port/fault-digest.mjs --seed=12345 --ticks=28800 --every=60 --sets=3    # exit 0
tools/sim-port/fault-digest-gd.sh    --seed=12345 --ticks=28800 --every=60 --sets=3    # exit 0  (2.9–3.1 s)
node tools/sim-port/fault-digest.mjs --seed=999   --ticks=28800 --every=60 --sets=3    # exit 0
tools/sim-port/fault-digest-gd.sh    --seed=999   --ticks=28800 --every=60 --sets=3    # exit 0
node tools/sim-port/fault-digest.mjs --seed=12345 --ticks=28800 --every=1  --sets=3    # exit 0
tools/sim-port/fault-digest-gd.sh    --seed=12345 --ticks=28800 --every=1  --sets=3    # exit 0

# comparators, unchanged tools
node    tools/parity/parity-compare.mjs <js> <gd> --quiet    # exit 0 ×8, RESULT=IDENTICAL
python3 tools/sim-port/compare-digests.py <js> <gd>          # exit 0 ×8, IDENTICAL
python3 tools/sim-port/trace-compare.py  <js> <gd>           # exit 0 ×8, TRACE-COMPARE RESULT=IDENTICAL

sha256sum scripts/parity-digest.mjs    # 2b24dd26…fdcd, before and after
git status --porcelain                 # read-only: no tracked file modified
```

---

## 6. VERIFIED vs INFERRED

**VERIFIED (ran it, both engines)**

- A full-charge **second serve is struck at charge 1.000000** — printed by the runner's own trigger
  predicate on both engines (`# strike tick=000253 kind=second charge=1.000000`), not inferred from
  `performServe`'s internal default.
- **Double fault reached** (`ATHLETES[1]` pantera): first-serve fault during tick **250**
  (`serveOutBox`), second serve struck tick **253**, second serve out of the box during tick **377**
  (`y = 183.292955 < SERVICE_TOP = 184`, long by **0.71 px**), `doubleFaults 1/0`,
  `doubleFaultTicks=377:player`, `points 0-1`, `aiScore 15` — identical on seeds 999 and 12345.
- **The ported Godot core reproduces every one of those ticks** and the whole 4 001-tick digest stream
  byte-identically (strict `IDENTICAL`, equal `digestSha256`).
- **Completed set, match healthy**: sets closed 0-1 during tick **12 691** and 0-2 during tick **25 537**
  (seed 12345; 12 595 / 24 681 for seed 999), each after six games won 6-0, games reset to 0-0, match
  still playing; `resultTick=none`; `ball.z` bounded in [−1.87, 164.13] over all 28 801 ticks.
- Godot reproduces the 28 800-tick run **byte-identically at `--every=1`**, i.e. on all 28 801 samples
  and all 289 transition ticks — no drift accumulated over 4 minutes of match time.
- A1/A2 (first-serve fault + second serve) still reproduce their prior-lane digests exactly
  (`bfc73441…`, `1486e011…`); the extended runner's non-comment output is unchanged from its pre-change
  self.
- **Why A3 is athlete-dependent**: spread formula + measurements in §1.3 — maestro (control 1.28) aims at
  worst 112.2 px against a 126 px service line on a full-charge **second** serve (0/300 isolated second
  serves fault), pantera (0.96) reaches 127.6 px (63/300 double faults).

**INFERRED / not measured**

- The exact second-serve fault probability as a *game* statistic: only one double fault occurs in each
  4 000-tick A3 run (the point sequence is dominated by full-charge serves that are won outright).
- That the fault rate of the reserve serve is monotone in the athlete's `control` beyond the two athletes
  sampled; only indices 0 and 1 were measured.
- That every seed closes its first set in exactly the 6-game pattern seen here; two seeds were run at the
  full length.

**NOT proven / explicitly out of scope**

- Anything about the post-`state.result` tail: both runners stop at the result by construction, so no line
  after a match-ending point is ever compared as gameplay (`parity-coverage-frontier.md` §3).
- Whether a double fault is reachable with **`ATHLETES[0]`** — on the evidence in §1.3 it is **not**
  (structurally 112.2 px worst-case aim against a 126 px line, 0/300 measured), which is exactly why the
  A3 evidence is quoted at `--athlete=1` and labelled as such.

---

## 7. Drift statement

- Files modified, all inside the allowlist: `tools/sim-port/fault-digest.mjs`,
  `godot/src/sim/fault_digest_gd.gd`, `tools/sim-port/trace-compare.py`, plus new files
  `tools/sim-port/double-fault-probe.mjs` and this document. Run artifacts were written to the existing
  untracked `tools/sim-port/out/`.
- **`scripts/parity-digest.mjs` is byte-identical to the frozen reference** before and after
  (`2b24dd26b20e3b5a856a2368e6425bd4cbd98592d58144e36f2d73b87d26fdcd`).
- **`godot/src/sim/**` simulation code was not touched**: the comparison exposed no divergence, so the
  allowlist's conditional fix permission was never exercised (only the runner
  `fault_digest_gd.gd` changed, which is a harness, not the ported core: `sim.gd`, `state.gd`, `digest.gd`,
  `frozen.gd` and `frozen/data.json` all unmodified).
- `git status --porcelain`: only untracked directories — no tracked file modified by this lane.
- No git write command, no commit, no push, no deployment, no provider or model configuration change.
- **Spend: $0 — 0 paid calls, 0 metered inference, no network access used by this lane.**
