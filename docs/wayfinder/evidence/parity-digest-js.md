# Evidence: JS parity digest harness (`scripts/parity-digest.mjs`)

- Date: 2026-09-16
- Host: Linux, `node v22.22.1`
- Repo: `/root/projects/steam-circuit-padel-pro`
- Writer: crew subagent (parity-digest lane), writes limited to
  `scripts/parity-digest.mjs`, `tools/parity/` and this file.

## What was run

```
$ cd /root/projects/steam-circuit-padel-pro
$ node scripts/parity-digest.mjs --seed=12345 --ticks=1440 --every=60 --json=tools/parity/parity-digest-seed12345.json
```

- Exit code: **0**
- Seed: **12345** (explicit integer, assigned to `state.rngState` after
  `createMatchState`, because that constructor has no seed parameter and seeds
  from `Math.random` at `js/game.js:218`; same injection the existing audits use,
  `scripts/determinism-audit.mjs:24`)
- Tick count: **1440**, fixed step `1/120` s (= 12 s of match time), one
  `updateMatch(state, 1/120, input, null)` call per tick
- Sample grid: every **60** ticks, i.e. ticks 0, 60, 120, ... 1440
- Digest lines on stdout: **25** (one per sampled tick)
- Total stdout lines: **30** (3 header comment lines, 25 digest lines, 1
  `# json=` line, 1 summary line). `wc -l` = 30.
- Final `state.rngState`: `-319693640`
- sha256 of the 25 digest lines (trailing newline included):
  `a71366820986b4bd9a9c2c30fd51e82b9fda6dd3caa23c6860949f2d215c27dd`
  (printed by the tool itself in the summary line)

### Scripted input sequence

One input object **per tick**, not per frame, which is the shape
`docs/wayfinder/tickets/simulation-port-boundary.md` section 6 prescribes. The
script is a pure function of the tick index:

- ticks 0..59: the 22-field empty input (the match sits in its prepared serve)
- from tick 60: `charging: true` held
- `hit: true` on every tick where `tick % 30 === 0` (the explicit, named-tick
  swing the harness needs); the first of those, tick 60, is also what performs
  the serve, through the real loop (`js/game.js:2625`)
- `moveX = ((floor(tick/120) % 3) - 1) * 0.5`, `moveY = tick % 240 < 120 ? -1 : 0`

No randomness and no wall clock in the script. The serve is performed by the
engine itself, not by the harness calling `performServe`, so the path under test
is the path the game uses.

### First 5 lines of stdout (verbatim)

```
# parity-digest.mjs seed=12345 ticks=1440 every=60 step=0.008333333333333333
# digest-shape=rngState,rngCalls,ball,v,paddles,score (see simulation-port-boundary.md sec.6)
# format=js-side-only no-godot-comparison
tick=000000 rngState=12345 rngCalls=0 ball=(596.000000,462.000000,34.000000) v=(0.000000,0.000000,0.000000) spin=0.000000 bounces=0/0 shotType=serve smashStage=0 player=(568.000000,486.000000) playerMate=(328.000000,372.000000) opponent=(304.000000,130.000000) opponentMate=(656.000000,130.000000) points=0-0 games=0-0 sets=0-0 playerScore=0 aiScore=0 pointsWon=0-0 rallyHits=0 serveAttempts=0 longestRally=0
tick=000060 rngState=12345 rngCalls=0 ball=(596.000000,462.000000,34.000000) v=(0.000000,0.000000,0.000000) spin=0.000000 bounces=0/0 shotType=serve smashStage=0 player=(568.000000,486.000000) playerMate=(328.000000,372.000000) opponent=(304.000000,130.000000) opponentMate=(656.000000,130.000000) points=0-0 games=0-0 sets=0-0 playerScore=0 aiScore=0 pointsWon=0-0 rallyHits=0 serveAttempts=0 longestRally=0
```

### Last 5 lines of stdout (verbatim)

```
tick=001320 rngState=-319693640 rngCalls=0 ball=(397.660562,466.670318,74.780491) v=(-292.949792,267.810437,-390.156413) spin=-8.499490 bounces=0/0 shotType=lob smashStage=0 player=(385.006160,352.000000) playerMate=(481.016000,398.000000) opponent=(440.810908,200.025093) opponentMate=(372.762010,210.634880) points=1-0 games=0-0 sets=0-0 playerScore=15 aiScore=0 pointsWon=1-0 rallyHits=1 serveAttempts=0 longestRally=4
tick=001380 rngState=-319693640 rngCalls=0 ball=(258.574153,518.286482,66.865595) v=(-263.950875,-217.602035,80.134062) spin=1.653498 bounces=1/0 shotType=lob smashStage=0 player=(429.132560,352.000000) playerMate=(617.960000,398.000000) opponent=(597.670908,202.719467) opponentMate=(209.082010,209.446400) points=1-0 games=0-0 sets=0-0 playerScore=15 aiScore=0 pointsWon=1-0 rallyHits=1 serveAttempts=0 longestRally=4
tick=001440 rngState=-319693640 rngCalls=0 ball=(129.550233,411.859029,16.932626) v=(-252.057935,-208.019970,-279.865938) spin=1.021184 bounces=1/0 shotType=lob smashStage=0 player=(473.258960,352.000000) playerMate=(656.000000,398.000000) opponent=(640.000000,140.000000) opponentMate=(152.000000,148.000000) points=1-0 games=0-0 sets=0-0 playerScore=15 aiScore=0 pointsWon=1-0 rallyHits=1 serveAttempts=0 longestRally=4
# json=/root/projects/steam-circuit-padel-pro/tools/parity/parity-digest-seed12345.json
PARITY-DIGEST JS PASS seed=12345 ticks=1440 sampledTicks=25 every=60 finalRngState=-319693640 digestSha256=a71366820986b4bd9a9c2c30fd51e82b9fda6dd3caa23c6860949f2d215c27dd
```

## What this proves

- The digest harness runs headlessly under plain `node` (no jsdom, no npm
  install, no browser) against the REAL `js/game.js`, reusing the proven
  cache-busted import technique of `scripts/determinism-audit.mjs`: the
  `?v=20260814-feedback-confirm-v39` query specifier resolves in Node ESM.
- Two runs with the same arguments produced byte-identical stdout
  (`diff` of two runs: empty).
- A different seed (`--seed=999`) produces a different digest, so the seed is
  really in control.
- `--json` writes the same samples as JSON: `tools/parity/parity-digest-seed12345.json`
  (11 samples verified in a smaller `--ticks=300 --every=30` run as well).
- Failures exit non-zero: `--seed=abc` exits 1 with
  `PARITY-DIGEST JS FAIL: --seed deve essere un intero, ricevuto "abc"`.
- A successful run ends with an unmistakable summary line:
  `PARITY-DIGEST JS PASS seed=12345 ticks=1440 sampledTicks=25 every=60 finalRngState=-319693640 digestSha256=a7136682...`
- There is real game in the digest, not a frozen state: the run serves (tick
  120, 3 RNG calls), rallies (`rallyHits` 1..4), produces a point at the end of
  the first rally (`points=1-0`, `playerScore=15`), and the match re-serves.
- Nothing existing was touched: `git status --porcelain` shows only untracked
  additions (`scripts/parity-digest.mjs`, `tools/`), and the simulation audits
  still pass (`node scripts/determinism-audit.mjs` exits 0 with
  `reproducible: true, seedSensitive: true, strayMathRandom: 0`).

## Artifacts

| File | sha256 |
|---|---|
| `scripts/parity-digest.mjs` | `2b24dd26b20e3b5a856a2368e6425bd4cbd98592d58144e36f2d73b87d26fdcd` |
| `tools/parity/parity-digest-seed12345.json` | `1032fb20df663a8e0db44ad85d15bcd00a840a1a80b9611cba06c368bb70f0dc` |

The JSON artifact carries the same samples plus `inputScript`, `sampledTicks`,
`digestSha256` and `finalRngState`, for a machine comparison later.

## Limits / not proven

- **No Godot-side comparison exists.** This harness produces the JavaScript side
  only. Nothing here has been compared against a GDScript port, and no GDScript
  port digest exists to compare against. The `# format=js-side-only
  no-godot-comparison` header line in the output says so.
- **The position tolerance is a proposal, not a gate.** The absolute `1e-3` px
  (and `1e-3` px/s) position tolerance in
  `docs/wayfinder/tickets/simulation-port-boundary.md` section 6 is stated there
  as a proposal and explicitly "not measured". No tolerance has been validated
  by this work.
- **`rngCalls` is reconstructed, not counted by the engine.** `js/game.js`
  tracks only `state.rngState`, so the harness replays the generator from the
  previous sample's state to the next one to count the calls exactly
  (`countRngCalls`). If something ever wrote `state.rngState` outside
  `nextRandom`, the reconstruction would return -1 and the run would exit
  non-zero. It did not fire in this run. A future Godot side should increment a
  real counter inside its `nextRandom` and this reconstruction is a check on it,
  not a replacement.
- **The digest is a rerun, not a golden file.** No expected digest is stored and
  no assertion compares this output against a recorded baseline. If `js/`
  changes, this digest changes silently; nothing here would go red.
- **`shotType`/`smashStage` and the score fields are printed but not asserted.**
  They are visible in the samples; no invariant over them is checked.
- **A short run only.** 12 s of match time, 25 samples, one point. The digest
  covers the serve, one rally and one point; games, sets, tie-breaks, faults
  and the special are not exercised at this length.
- **`Math.random` outside the seeded path is untouched by design** (particles in
  `js/fx.js`, audio noise buffers, the match seed line). Those streams stay
  outside the digest, per section 6 of the boundary ticket.
- **Not wired into `npm run audit` on purpose.** The file is named
  `parity-digest.mjs`, not `*-audit.mjs`, so `scripts/run-audits.mjs` does not
  pick it up.
