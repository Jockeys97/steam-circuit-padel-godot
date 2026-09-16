# Parity coverage — slice S1 scenario matrix (live cross-engine)

- **Date:** 2026-09-16T07:53:52+02:00 (CEST)
- **Repo:** `/root/projects/steam-circuit-padel-pro` @ working tree, 12 scenarios
- **Engines:** Node (JS reference) vs `/root/tools/godot/Godot_v4.7.2-stable_linux.x86_64` (4.7.2.stable, headless)
- **Harness (frozen, unmodified):** `scripts/parity-digest.mjs`
  sha256 `2b24dd26b20e3b5a856a2368e6425bd4cbd98592d58144e36f2d73b87d26fdcd` — matches the frozen contract.
- **Scope:** frozen deterministic-simulation parity proof for slice S1. Nothing in `js/**`,
  `scripts/**`, `docs/mission/**`, `docs/wayfinder/map.md` or any tracked file was modified.
  `godot/src/sim/**` was **not** modified (see *Fix attempt*, §6).

## 1. Headline

The single tracer scenario the mission owner verified was **reproduced exactly**, and then
**widened to 12 scenarios across 5 seeds**. The widening **fails**: the port is exact only for
the first ~12 s of match time (serve + first rally). Every scenario that runs past that window
diverges, and the first break is a **real, large port difference — not float noise**.

| | |
|--|--|
| Scenarios run | 12 |
| `IDENTICAL` | **4** |
| `DIVERGED` | **8** |
| NOT-COMPARABLE / usage error | 0 |
| Earliest true first divergence | **tick 2207** (seed 2024), field `v.x` / `spin` on a `smash-x2` hit |
| Largest observed break delta | `ball.x` Δ = **1.780803** (seed 999983) — 1780× the `1e-3` gate |

**The S1 parity claim, as it stood, was a statement about a 12-second window.** It does not hold
for a match. Details and the exact reproduction are in §5.

## 2. Repeatable commands

Every row below was produced by exactly these three commands (per scenario, sequentially):

```bash
cd /root/projects/steam-circuit-padel-pro
S=<seed>; T=<ticks>; E=<every>

# JS reference
node scripts/parity-digest.mjs --seed=$S --ticks=$T --every=$E \
  --json=tools/sim-port/out/js-$S-$T-$E.json > tools/sim-port/out/js-$S-$T-$E.txt

# Godot port (ported GDScript core), one process at a time, hard-capped
timeout 300 tools/sim-port/parity-digest-gd.sh --seed=$S --ticks=$T --every=$E \
  --js=$PWD/tools/sim-port/out/js-$S-$T-$E.json > tools/sim-port/out/gd-$S-$T-$E.txt

# live comparator (exit 0 IDENTICAL, 1 DIVERGED, 2 NOT-COMPARABLE, 3 usage)
node tools/parity/parity-compare.mjs tools/sim-port/out/js-$S-$T-$E.txt \
  tools/sim-port/out/gd-$S-$T-$E.txt \
  --json=tools/sim-port/out/cmp-$S-$T-$E.json \
  > tools/sim-port/out/cmp-$S-$T-$E.stdout.txt
```

`parity-digest-gd.sh` wraps the engine identically to the frozen recipe
(`env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 <godot> --headless --path godot/ --script
res://src/sim/parity_digest_gd.gd -- ...`).

The driver that ran the matrix sequentially and appended each row to disk as it finished:
`/tmp/matrix.sh` (scratch — intentionally outside the repo). Machine-readable results:
`tools/sim-port/out/coverage-matrix.jsonl` (12 lines, one per scenario, appended on completion).

Sanity anchor first: **seed 12345 / ticks 1440 / every 60** reproduced both digest sha256
`a71366820986b4bd9a9c2c30fd51e82b9fda6dd3caa23c6860949f2d215c27dd` and `finalRngState
-319693640` with 25 sampled ticks — identical to the owner's known-good baseline, on both sides.

## 3. Scenario matrix

| # | seed | ticks | every | samples | JS digest (sha256[0:16]) | GD digest (sha256[0:16]) | verdict | first divergence |
|--:|--:|--:|--:|--:|---|---|---|---|
| 1 | 12345 | 1440 | 60 | 25 | `a71366820986b4bd` | `a71366820986b4bd` | **IDENTICAL** (exit 0) | — |
| 2 | 12345 | 1440 | 120 | 13 | `775ced903c0d2981` | `775ced903c0d2981` | **IDENTICAL** (exit 0) | — |
| 3 | 999 | 1440 | 60 | 25 | `3ee635b338daf5ae` | `3ee635b338daf5ae` | **IDENTICAL** (exit 0) | — |
| 4 | 999 | 28800 | 120 | 241 | `8b65103577ba7a5c` | `9a236333dbf8f792` | DIVERGED (exit 1) | tick 003000 / ball.x |
| 5 | 7 | 4320 | 60 | 73 | `5357f8a36bd1c9b1` | `8d2c841254ede183` | DIVERGED (exit 1) | tick 004200 / ball.x |
| 6 | 7 | 14400 | 60 | 241 | `9c76d8878e01bc5b` | `c9d94fc339fc15c6` | DIVERGED (exit 1) | tick 004200 / ball.x |
| 7 | 2024 | 14400 | 120 | 121 | `a5157f4567dab124` | `7b70b0990fec72e4` | DIVERGED (exit 1) | tick 002280 / ball.x |
| 8 | 2024 | 720 | 7 | 103 | `4d5882456c2ec9ad` | `4d5882456c2ec9ad` | **IDENTICAL** (exit 0) | — |
| 9 | 999983 | 28800 | 60 | 481 | `630e1adb59b43099` | `6dfdc7441c747094` | DIVERGED (exit 1) | tick 003780 / ball.x |
| 10 | 2024 | 28800 | 120 | 241 | `33a741c3cfac7d21` | `6b6002849716c60d` | DIVERGED (exit 1) | tick 002280 / ball.x |
| 11 | 999983 | 4320 | 60 | 73 | `fb452b8d39f1c1d6` | `b3f057f7b121249b` | DIVERGED (exit 1) | tick 003780 / ball.x |
| 12 | 12345 | 28800 | 60 | 481 | `912e7d6cc334d4c9` | `2c449b6ee56943b4` | DIVERGED (exit 1) | tick 003900 / ball.x |

Digest sha256 values are truncated to 16 hex chars here; the full values are in
`tools/sim-port/out/coverage-matrix.jsonl`. `finalRngState` matched between engines in all 4
IDENTICAL rows and in one DIVERGED row (999983/4320: `-766294381` on both sides — the RNG
stream itself had not yet been disturbed when the run ended).

## 4. Raw streams

All under `tools/sim-port/out/` (Godot streams start with the engine banner line; the comparator
tolerates it).

| file | bytes | sha256 |
|---|---:|---|
| `tools/sim-port/out/js-12345-1440-60.txt` | 10999 | `5a4926a257b677b899d5c153b6e60d4d3ecf86b3b1e29134506b0e9e108c9994` |
| `tools/sim-port/out/gd-12345-1440-60.txt` | 12571 | `4cfc29cd1854fee0261d78fb845602be869e0e0b71ce93d21cdce481c0e1d49b` |
| `tools/sim-port/out/cmp-12345-1440-60.stdout.txt` | 1450 | `36e259b2ffc1fbe3c80b72147cfb730fe6e97fb2211e4a59976f05a487b8458a` |
| `tools/sim-port/out/js-12345-1440-120.txt` | 5951 | `3d82c987cc20de9bcfd86e273180e48af371280669845a27f9483f1c3fe2158e` |
| `tools/sim-port/out/gd-12345-1440-120.txt` | 6851 | `e09845b4acafdd4533a62f14a53ad7a18b2bb9aa909bd80f6ab299e3349d78c5` |
| `tools/sim-port/out/cmp-12345-1440-120.stdout.txt` | 1457 | `082bf4c43f891439276e9144fee2c3f5be22ec24c13bae1c5165df1dc467c659` |
| `tools/sim-port/out/js-999-1440-60.txt` | 10992 | `41b7252a05bd3468c32b0482e54cac7aa8a0e47fbacd6739f1162344c0b0ed91` |
| `tools/sim-port/out/gd-999-1440-60.txt` | 12564 | `a2b84ac33743f8f234bdb10d1404943a15fe4afa130fdd589d636e391e8e3395` |
| `tools/sim-port/out/cmp-999-1440-60.stdout.txt` | 1434 | `6bdcfbcfef07cf8c100affa4bcf3761acddf554322f33f138cb81361974e09c8` |
| `tools/sim-port/out/js-999-28800-120.txt` | 103003 | `a2077b3f8e8ff541e9d654d6bdff4697bb83a8e958a9848a9d1ecce2a7022099` |
| `tools/sim-port/out/gd-999-28800-120.txt` | 171560 | `25612f4f55b164f02cee40b2454ddc936622460263d9f5e7d410ba2bb1af159f` |
| `tools/sim-port/out/cmp-999-28800-120.stdout.txt` | 1902 | `af3ad36b10cd47dbfceab8e53fbb1cac23fc7a96a602105d07e148e5f0cc2273` |
| `tools/sim-port/out/js-7-4320-60.txt` | 31211 | `2b5942233fc6dcd64c1472bdf0ca74e88107a5e6376b8a5d144963a1df7169d7` |
| `tools/sim-port/out/gd-7-4320-60.txt` | 35557 | `cc4679a25b1ad54f6d66701548bbaf9df34aeb226f1a0a2a6117b7db5916367c` |
| `tools/sim-port/out/cmp-7-4320-60.stdout.txt` | 1860 | `5b1600d61911b2fd98a45e4d1b1fc828e2adf25058d2a75e5fd7d6c157954f7f` |
| `tools/sim-port/out/js-7-14400-60.txt` | 102162 | `1537e5ae96e0415e61fea4e73a4c99f3d9f25b6cbb74a77abaac72735e7b9f0a` |
| `tools/sim-port/out/gd-7-14400-60.txt` | 153380 | `7dcdb8cb08520ee20cd2874947b40ffe1274fdb6572468578ae6627d591d2d32` |
| `tools/sim-port/out/cmp-7-14400-60.stdout.txt` | 1880 | `499557d46edef9f179e7c89c46e47dace886fdc60b5b46c49461fadc9c01122a` |
| `tools/sim-port/out/js-2024-14400-120.txt` | 51673 | `a676c4bf9623351af7ad77941e1100f674cbb503ac547cf042d7ac82e6b330c9` |
| `tools/sim-port/out/gd-2024-14400-120.txt` | 62094 | `f1eaf070527a6aa2e3d4999638b45789aa869d7989db8d9c367a73d425800a16` |
| `tools/sim-port/out/cmp-2024-14400-120.stdout.txt` | 1907 | `f4aea05855c11e4faa6db62ea2ec2e661abe6eae0350d283d8b117678aa5552d` |
| `tools/sim-port/out/js-2024-720-7.txt` | 43849 | `07cc1b568ff236ce83bf31ef7c1e25023ae466a263adf129f1d7662253eec8e1` |
| `tools/sim-port/out/gd-2024-720-7.txt` | 49790 | `e928624405c3478f9f47be4519f7bcb27f770f15adabf7950cb154a911bf9721` |
| `tools/sim-port/out/cmp-2024-720-7.stdout.txt` | 1437 | `06e111fdc53e74c90a302cf122b52022dcf9f790a543f0a4c2a9cca5fc786f22` |
| `tools/sim-port/out/js-999983-28800-60.txt` | 204920 | `7162e96e547cd74ed0321e09f4590c39b0184a44dc3243f1acbc5e5a592f2e5c` |
| `tools/sim-port/out/gd-999983-28800-60.txt` | 380444 | `e858f08cec8a3753145e17f7875e3e32b2f3a754fb59c3ac11000f86967ad885` |
| `tools/sim-port/out/cmp-999983-28800-60.stdout.txt` | 1917 | `57c519f1af91691250d9a796a6fc384311f940d0ac71386b9f3aea0a25d9802d` |
| `tools/sim-port/out/js-2024-28800-120.txt` | 103135 | `782e995f1697af812e5812634a97eaff55ba930e8caaea7c2b406d77ff3ef31d` |
| `tools/sim-port/out/gd-2024-28800-120.txt` | 160448 | `3f41358760c069384edc7c025b76c329adb83063a2ed0c6e5de3be03f31b05d5` |
| `tools/sim-port/out/cmp-2024-28800-120.stdout.txt` | 1911 | `daf26d9ca6681452c31a91c32e98ecd159dc2eed05c224bcc3f31c6d42f5eab5` |
| `tools/sim-port/out/js-999983-4320-60.txt` | 31248 | `2dcaa719d2741fe1985f29210ef64b8a6a49d1c72f46d9ccdeaf016f24b384fe` |
| `tools/sim-port/out/gd-999983-4320-60.txt` | 35644 | `7b59de3352e23e13262f573137cea66176a49d380c01665d3ea6c324af3a2ff3` |
| `tools/sim-port/out/cmp-999983-4320-60.stdout.txt` | 1901 | `60b59b7b53eb87a56d5cc6eb65ceb15e77d5a928ec10671f80c2eba160acdc57` |
| `tools/sim-port/out/js-12345-28800-60.txt` | 205055 | `889703f15df0992ea418f360a3db6b5c1f7c32a1bf28543be1ae3735f8fa44d4` |
| `tools/sim-port/out/gd-12345-28800-60.txt` | 303105 | `00549a05a2f30a4ff1aca12a2c0a39998f03384d7e1070d41506813f4d49b894` |
| `tools/sim-port/out/cmp-12345-28800-60.stdout.txt` | 1905 | `a4e9733d40d73623217702ea93faad656e6b7129c015b92da82a90b848193964` |

Comparator detail streams (`*-stdout.txt`) carry the human-readable first-divergence report and
the `CASCADE` tail count. `coverage-matrix.jsonl` = 7009 bytes, 12 lines,
sha256 `14a92df098a69f9bb3ebf4426c66b85e121907fe8689730f43969ffdd4c128de`.

Fine-grained probe (see §5):

| file | bytes | sha256 |
|---|---:|---|
| `tools/sim-port/out/fine-2024-2285-1-js.txt` | 964027 | `d3393240a4fe8b225f52bb86af16e903513e26a1f04a8621704f4b1aaeb8e4d0` |
| `tools/sim-port/out/fine-2024-2285-1-gd.txt` | 1092838 | `352d9802e1bf2e186af79d93e307d45ea5656f80ed2528f329a2c7881b48622e` |
| `tools/sim-port/out/fine-2024-2285-1-js.ticks.txt` | 963619 | `73e28dc14086e383bbc76d1434f09ace05ac19171616b99b787ad008545ea993` |
| `tools/sim-port/out/fine-2024-2285-1-gd.ticks.txt` | 963619 | `910f30bd93de5be28e8d6164f8f5eb073bde782bd983d1ab61d16b0b5c7ce4c3` |

(`*.ticks.txt` = only the `tick=` lines, extracted for byte-level `cmp`.)

## 5. The divergence, exactly

The sampled grid understates the failure: at `every=120` the first *sampled* difference for seed
2024 appears at tick 2280, but the true first differing tick is **2207**. So the matrix was
re-run at `every=1` for seed 2024 up to tick 2285:

```bash
node scripts/parity-digest.mjs --seed=2024 --ticks=2285 --every=1 --json=/tmp/fine-js.json > /tmp/fine-js.txt
timeout 300 tools/sim-port/parity-digest-gd.sh --seed=2024 --ticks=2285 --every=1 --js=/tmp/fine-js.json > /tmp/fine-gd.txt
cmp tools/sim-port/out/fine-2024-2285-1-js.ticks.txt tools/sim-port/out/fine-2024-2285-1-gd.ticks.txt
# -> differ: byte 930299, line 2208   (lines 1..2207 are byte-identical: ticks 1..2206)
```

Last identical tick **2206**; first differing tick **2207**. Field-by-field at 2207:

| field | JS | GD |
|---|---|---|
| `rngState` | -1903081286 | -1903081286 (same) |
| `rngCalls` | 7 | 7 (same) |
| `ball` | (501.579959, 223.000000, 74.000000) | identical |
| `v.y` | 467.924202 | 467.924202 (same) |
| `v.z` | 122.068019 | 122.068019 (same) |
| **`v.x`** | **-164.480614** | **-165.878629** (Δ 1.398015) |
| **`spin`** | **-6.579225** | **-6.635145** (Δ 0.055920) |
| `shotType` | `smash-x2` (this tick is the first tick of the smash: `rallyHits` goes 2→3) | identical |
| `bounces`, `player*`, `opponent*`, `points`, `games`, `sets`, `scores` | identical | identical |

What this pins down:

1. **Not the RNG.** At the break tick both engines are in the same RNG state with the same call
   count, and every one of the 2206 preceding ticks is byte-identical. The RNG stream is advanced
   identically; the difference is arithmetic inside the shot resolution.
2. **`spin` is a consequence, not a second bug.** For `smash-x2`, `spin = clamp(vx*0.04, -24, 24)`:
   JS `-164.480625*0.04 = -6.579225` ✔, GD `-165.878625*0.04 = -6.635145` ✔. Spin simply restates
   the `v.x` break.
3. **The trajectory formula is not the site.** `setComputerTrajectory` is line-for-line identical
   (`js/game.js:1338-1347` vs `godot/src/sim/sim.gd:1416-1423`), as is the whole `smash-x2/x3`
   target block (`js/game.js:1443-1451` vs `godot/src/sim/sim.gd:1493-1502`). Since `v.y` — whose
   target component is a pure constant (`court.top+44`) — matches exactly, `flightTime/dragCompensation`
   is the same on both sides. Solving `v.x = (targetX - ball.x)/flightTime * dragCompensation`
   with the identical `ball.x` gives **GD's smash target `x` ≈ 0.535 court units away from JS's**,
   i.e. the divergence is in the *target*, upstream of the trajectory setter.
4. The only non-constant contributor to that target `x` in this branch is the pre-trajectory jitter
   `target.x += (nextRandom(state) - 0.5) * executionSpread * 150` with
   `executionSpread = assessment.risk * (1 - profile.skill * 0.45)` — i.e. either the pre-jitter
   smash target or `assessment.risk`/`skill` differs on the GD side. **Not confirmed** — see §6.
5. **It compounds.** The comparator reports the tail as `CASCADE` (67 of 101 remaining samples for
   2024/14400/120; 192 of 215 for 999/28800/120). After the break the GD state leaves the court
   entirely (`bounces=57/0`, `ball.z ≈ -1.4e5` by tick 27660 in `gd-12345-28800-60.txt`), so
   everything after the first break is a consequence and is *not* reported as separate findings.

The JS reference behaves the same way over long horizons: the frozen reference itself leaves the
healthy regime in the long runs (e.g. `js-999-28800-120.txt` ends at `ball≈(-1543, 2176, -415323)`,
`bounces=53/0`). That is a property of the frozen JS harness, not of the port — but it caps how
much the very long scenarios can prove (§7).

## 6. Fix attempt — NOT MADE (blocker, deliberately stopped)

The task authorises one bounded fix **only if the matrix finds a real divergence**. It did. The
diagnosis above stops, however, at two gates and **no patch was written**, for one reason:
the root cause is not confirmed, and the candidate sites differ only by an unmeasured scalar —
patching `assessment.risk`/`executionSpread` speculatively would *redefine the frozen reference's
own arithmetic*, which is exactly the failure mode a parity proof exists to prevent. Gate budget
was respected (fine-grained probe + code diff; 2 gates, no OOM, no failed attempt), and the
deadline for this lane arrived before a third gate (instrumenting the GD smash target to print
`target.x`/`executionSpread` and diffing it against the JS value) could be run.

**To resolve, the next lane needs one thing:** print `target.x`, `executionSpread`,
`assessment.risk`, `profile.skill` and `nextRandom(state)` immediately before
`set_computer_trajectory` in `godot/src/sim/sim.gd:1493-1495` and the same in `js/game.js:1443-1445`
for seed 2024 tick 2207. Whichever scalar differs is the bug; the derived Δtarget x is ≈ 0.535
courts, Δv.x = 1.398015.

### Minimal reproduction

```bash
cd /root/projects/steam-circuit-padel-pro
node scripts/parity-digest.mjs --seed=2024 --ticks=2285 --every=1 --json=/tmp/fine-js.json > /tmp/fine-js.txt
timeout 300 tools/sim-port/parity-digest-gd.sh --seed=2024 --ticks=2285 --every=1 --js=/tmp/fine-js.json > /tmp/fine-gd.txt
grep '^tick=' /tmp/fine-js.txt > /tmp/fj.txt; grep '^tick=' /tmp/fine-gd.txt > /tmp/fg.txt
cmp /tmp/fj.txt /tmp/fg.txt     # differ: byte 930299, line 2208
```

First differing line pair (JS left, GD right), abridged to the differing fields:

```
tick=002207 ... ball=(501.579959,223.000000,74.000000) v=(-164.480614,467.924202,122.068019) spin=-6.579225 ... shotType=smash-x2 ...
tick=002207 ... ball=(501.579959,223.000000,74.000000) v=(-165.878629,467.924202,122.068019) spin=-6.635145 ... shotType=smash-x2 ...
```

## 7. What this proves / what it does not prove

**Proves**

- The ported core is **exactly equal** to the frozen JS reference for the tracer window: seeds
  12345, 999 and 2024 within the first 1440 ticks (12 s) — at sampling `every=7`, `every=60`,
  `every=120`, compared strictly (every printed field, all 4 discrete+float groups, no tolerance).
- The verification chain works end to end and can **fail**: the comparator returns 1 with a tick+field
  verdict, and the byte-level stream comparison independently confirms the same break.
- The parity failure is **real and large**, not print noise: deltas 0.040627 (seed 7) to 1.780803
  (seed 999983) in `ball.x`, against a `1e-3` proposal. Every DIVERGED row fails even under
  `--tol=0.001`.
- The break is deterministic and seeds-independent in kind: it appears the first time a rally
  carries play past ~tick 2200–4200 (i.e. the first longer rally), always first in a shot-resolution
  field.

**Does not prove**

- **Nothing beyond ~12 s of match time is parity-verified.** 8 of 12 scenarios diverge; the
  IDENTICAL rows are all short (≤ 1440 ticks, ≤ 4 rally hits).
- **Faults and second serves are entirely unexercised.** `serveAttempts` is 0 at every sampled tick
  of all 12 scenarios.
- **No completed set, no tie-break.** `games` reached 0-5 in the long runs, but `sets` leaves `0-0`
  only in the runaway tail, where the ball has left the court; the magnitudes (0-102 … 0-442) are
  not meaningful set counts. Treat set/tie-break logic as unverified.
- **The long runs are not clean exercise.** Both sides leave the healthy regime; the matrix reaches
  240 s of wall-tick time but only ~0-5 games of *sane* match.
- **Other diverging seeds were not fine-probed.** The tick-2207 root cause is established for seed
  2024 only; seeds 7, 999, 999983 and 12345/28800 show first *sampled* divergences at 4200 / 3000 /
  3780 / 3900 and were not reduced to `every=1`.
- **Not bit-exactness.** See §8.
- Nothing here asserts the JS digest is correct — it is the reference by definition of this slice.

## 8. Precision limits (explicit)

The digest prints floats at **6 decimals**. Every comparison here is against those *printed*
values, so `IDENTICAL` means "identical to six decimals at the sampled ticks", not bit-identical
`float64`/`float32`. Sub-5e-7 drift would not show, and divergence *between* samples is invisible
at `every=7/60/120` — which is exactly how the sampled grid reported tick 2280 for a break that
actually starts at 2207 (74 ticks of undetected divergence). The §6 deltas (0.040627 … 1.780803)
are four to six orders of magnitude above that floor, so they are real differences and not
printing artifacts. The `1e-3` tolerance of §6 remains a **proposal, still unvalidated**: the 4
IDENTICAL scenarios passed under *strict* comparison and needed no tolerance, while every DIVERGED
scenario exceeds `1e-3` and would still fail with it.

## 9. Memory constraint (why this ran the way it did)

The host is small: **3910 MB RAM, 0 swap, ~450 MB available**, and two earlier attempts at this
task were killed by the OOM killer before writing anything. Measured here:

- Each Godot run peaked at **~129 MB RSS** (129400 kB); each JS run at **~76 MiB** (77428 kB); one
  run of 1440 ticks takes ~0.7 s on both sides, and 28800 ticks ~5 s total per scenario.
- All 12 scenarios ran **strictly sequentially** — never two Godot processes alive at once — each
  wrapped in `timeout 300`, each output streamed to a file rather than held in memory, with the
  scenario row appended to `coverage-matrix.jsonl` immediately on completion.
- The whole matrix finished in **35 s wall clock** (first scenario start 07:51:02, matrix complete
  07:51:37; sum of per-scenario times 34 s) with no OOM. `free -m` after the run: 133 MB
  free / 458 MB available — unchanged in character from before.

Consequence: the OOM deaths were not caused by the scenario budget. **The sequential discipline is
the load-bearing part**, and it should be kept even though the fits-per-run measurement looks cheap.

## 10. Incomplete or deferred runs

- **None of the 12 matrix scenarios was incomplete** — each has both streams, a comparator verdict
  and a row in `coverage-matrix.jsonl`.
- Fine-grain probe: done for seed 2024 only (tick ≤ 2285).
- Fix: **not attempted** (§6) — reported as a blocker instead.
- Not attempted at all: fault/second-serve scenarios, set/tie-break scenarios, cross-check against a
  fixed-point/integer digest, bit-exact float probe.
