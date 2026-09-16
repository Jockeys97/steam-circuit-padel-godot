# Parity digest — Godot side (slice S1, lane `crew-xray`)

**Status: DELIVERED — 25/25 digest lines byte-identical to the frozen JavaScript
harness for `--seed=12345 --ticks=1440 --every=60`, and 21/21 for a second seed
(999, different tick schedule). No divergence found.**

This file is the Godot counterpart of `parity-digest-js.md`. It records what was
actually run and what the output actually was; the numbers below are copied from
real command output, not from the JavaScript digest.

## 1. The command

```
tools/sim-port/parity-digest-gd.sh --seed=12345 --ticks=1440 --every=60
```

which is exactly:

```
env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
  --script res://src/sim/parity_digest_gd.gd -- --seed=12345 --ticks=1440 --every=60
```

The JavaScript reference for the same seed, for comparison only:

```
node scripts/parity-digest.mjs --seed=12345 --ticks=1440 --every=60 \
  --json=tools/parity/parity-digest-seed12345.json
```

The frozen seam script is untouched:
`sha256(scripts/parity-digest.mjs) = 2b24dd26b20e3b5a856a2368e6425bd4cbd98592d58144e36f2d73b87d26fdcd`
— identical to the hash in the slice contract.

## 2. Result

Real tails of the two runs:

```
PARITY-DIGEST JS PASS seed=12345 ticks=1440 sampledTicks=25 every=60 finalRngState=-319693640 digestSha256=a71366820986b4bd9a9c2c30fd51e82b9fda6dd3caa23c6860949f2d215c27dd
PARITY-DIGEST GD PASS seed=12345 ticks=1440 sampledTicks=25 every=60 finalRngState=-319693640 digestSha256=a71366820986b4bd9a9c2c30fd51e82b9fda6dd3caa23c6860949f2d215c27dd
```

Verification that the two 25-line digest bodies are the same bytes:

```
$ grep '^tick=' js.txt > js-lines.txt; grep '^tick=' gd.txt > gd-lines.txt
$ wc -c js-lines.txt gd-lines.txt
10527 js-lines.txt
10527 gd-lines.txt
$ sha256sum js-lines.txt gd-lines.txt
a71366820986b4bd9a9c2c30fd51e82b9fda6dd3caa23c6860949f2d215c27dd  js-lines.txt
a71366820986b4bd9a9c2c30fd51e82b9fda6dd3caa23c6860949f2d215c27dd  gd-lines.txt
$ diff js-lines.txt gd-lines.txt && echo IDENTICAL
IDENTICAL: all 25 digest lines byte-for-byte
```

The Godot tool's own per-tick verdict:

```
# compare sampledTicks=25 discreteMismatchTicks=0 floatToleranceTicks=0 firstDivergence=none
#   tick=000000 discrete=OK floats(max abs)=0.000000000
#   ...
#   tick=001440 discrete=OK floats(max abs)=0.000000000
```

So, for this scenario:

| question | answer |
| --- | --- |
| digest lines matching | **25 / 25** |
| first divergence | **none found up to tick 1440** |
| discrete fields (rngState, rngCalls, shotType, smashStage, bounces, all score counters) | all equal |
| worst float deviation over all 15 per-tick float fields | **< 5e-10** (printed as `0.000000000`), at every sample |
| `finalRngState` | `-319693640`, equal on both sides |
| `digestSha256` | `a7136682…c27dd`, equal on both sides |

### Second seed (independent of the first)

```
$ node scripts/parity-digest.mjs --seed=999 --ticks=900 --every=45 --json=/tmp/parity-999.json
PARITY-DIGEST JS PASS seed=999 ticks=900 sampledTicks=21 every=45 finalRngState=-823658262 digestSha256=6dd0965de2f666f1b778fb0a8489cba0c92dd67ae05d41c6d88d4b3866054c51
$ tools/sim-port/parity-digest-gd.sh --seed=999 --ticks=900 --every=45 --js=/tmp/parity-999.json
PARITY-DIGEST GD PASS seed=999 ticks=900 sampledTicks=21 every=45 finalRngState=-823658262 digestSha256=6dd0965de2f666f1b778fb0a8489cba0c92dd67ae05d41c6d88d4b3866054c51
$ diff <(grep '^tick=' js999.txt) <(grep '^tick=' gd999.txt) && echo SEED-999-IDENTICAL
SEED-999-IDENTICAL          # 21/21 lines, different seed and different tick schedule
```

## 3. Why the digest is computed, not read

Three properties, each checked by running something:

1. **The Godot values do not come from the JSON.** Running with the reference
   file absent produces the *same* 25 lines and the *same* digest hash
   (`--js=/tmp/does-not-exist.json` → `diff` of the 25 lines is empty,
   `digestSha256=a7136682…c27dd`); the line-by-line comparison only decides the
   PASS/FAIL word in the summary. The JSON is never an input to simulation
   state.
2. **The comparison discriminates.** Godot with `--seed=12345` against the
   seed-999 reference fails loudly, and names the first divergence:
   `firstDivergence=tick=000000 field=rngState js=999 gd=12345` →
   `PARITY-DIGEST GD FAIL`, exit 1. A comparator that always passed would not do
   that.
3. **A different seed changes the output.** Seed 999 gives a different
   `finalRngState` and a different `digestSha256` than seed 12345 on both sides,
   so the digest is not a constant.

Additionally the `rngCalls` column is not trusted blindly: the port keeps a real
counter incremented inside `nextRandom`, and the harness pairs it with a
reconstruction from the `rngState` delta (`Rng.count_calls`). A disagreement
would print `# rngCalls reconstruction mismatch: …`; that line is absent, i.e.
`rngState` is only ever written by `nextRandom`.

## 4. What the samples prove (coverage)

The 1440-tick window is a live match, not a frozen table:

- sampled `shotType` values: `serve`, `drive`, `lob`, `smash-x2`;
- `rngCalls` per sample: 0 0 3 0 0 6 0 5 7 5 0 0 0 0 0 0 0 3 0 0 6 0 0 0 0 — the
  RNG is genuinely exercising the hit-quality, shot-choice and error paths;
- the point column advances (`playerScore=0` → `15` at sample 15, `points=1-0`),
  `longestRally=4`, and ball velocities reach ~466 units/s with `bounces` going
  0/0 → 0/1 → 0/2, so ground bounces and net crossing are traversed.

## 5. Honest limits — what is NOT proven

These are the reasons this is a tracer bullet, not a finished port:

1. **25 sample points, not 1441 ticks.** The comparison is at the digest's
   sampling rate. A divergence that appeared and healed entirely between two
   samples would not be caught. It is very unlikely (`rngState`, `rngCalls` and
   ball position are cumulative, so a healed divergence would still have to
   reconverge bit-for-bit), but it is not ruled out. Sampling every tick is a
   strictly stronger check and has not been run.
2. **One scenario only.** Mode `quick`, `ATHLETES[0]` / `ARENAS[0]` /
   `AI_OPPONENTS[1]`, solo human input, 22-field empty input plus four scripted
   fields. `coop`, `pvp`, tournament/career formats, other athletes, arenas and
   AI difficulty profiles are NOT covered by this evidence.
3. **Untraversed branches.** In this window `serveAttempts=0` (no double fault,
   so the second-serve / fault / let paths never ran), `games` and `sets` stay
   `0-0` (no game, set, tiebreak or match end), and only four shot types appear.
   `smash-x3`, `smash-flat`, `cut-volley`, `globo`, `vibora`, `chiquita`, drop
   and the special/burst shots are unexercised by this seed.
4. **The 1e-3 tolerance is not the operative constraint here.** The worst
   absolute float deviation observed was below 5e-10 on all 15 float fields, so
   the ticket's proposed tolerance is not what makes this pass — but it remains
   *unmeasured for other scenarios*, and the ticket already flags it as a
   proposal.
5. **Four couplings are stripped, by design.** Audio (`audio.js`), i18n
   (`t()` from `i18n.js`), FX emitters (`fx.js`) and the reduced-motion branch
   (`js/game.js:1058`) are not ported. The port keeps the *event ids*, the
   `shotFeedback` record and the `fx`/feedback fields so the state stays
   comparable, but there is no audio, no text lookup and no particle motion in
   the Godot core. A running Godot game (as opposed to a headless digest) would
   need them re-attached.
6. **Godot-side values are the port's own.** Equal hashes mean the two engines
   agree; they do not by themselves prove the port is a faithful reading of
   every line of `js/game.js`. The mechanism that makes "undetected
   transcription error" unlikely is coverage: any wrong constant or wrong branch
   weighting would move `rngState`/`rngCalls` off the JS track within a few
   hundred ticks, and it does not.

## 6. What was written

| file | lines | bytes | sha256 |
| --- | --- | --- | --- |
| `godot/src/sim/sim.gd` | 3071 | 141833 | `67f980136dbac16000aa27f4d396b0a3b0d63ef70b8d49338afbbaa1c3b9c74d` |
| `godot/src/sim/state.gd` | 170 | 5789 | `85c4482f45a655aad94c8ae5ded02c7c3e55fbd1ce9ef78f5ae39130ad081e33` |
| `godot/src/sim/entities.gd` | 174 | 5028 | `dcb61eab3f976d21eba067696d1d3da1900400784d3dcd64f09d093fd58f4cb8` |
| `godot/src/sim/rng.gd` | 80 | 3596 | `cbc4ffbb5fa979efb99e637fe9111eca0c508d6713513eec2b30e84eee36eefc` |
| `godot/src/sim/frozen.gd` | 67 | 2402 | `3c9db96954cdcab7236b0c488bd1770a2bae71d17ad05d0b5d23177d8c8b7e7c` |
| `godot/src/sim/digest.gd` | 111 | 4483 | `8717b8bfefc0862d2375c080f46db95f25499b7fa12250894ee38526398b2152` |
| `godot/src/sim/parity_digest_gd.gd` | 318 | 11650 | `db64ecb855c0b532929ad1e8f0c7abe76466443f490db5737664a58ae36d5d94` |
| `godot/src/sim/frozen/data.json` | — | 19204 | `eb2fcbc48eb94bb06464898ed7915e87b0f2f1ba53067f3f653a955bd8b6cd4b` |
| `tools/sim-port/extract-constants.mjs` | 76 | 2887 | `03ff86236359e54d0fbc36beb02712847a9d32a37ab1cc3ec95873fc3cb7e341` |
| `tools/sim-port/parity-digest-gd.sh` | — | 817 | `8c58647276f1f819cd7d90405e00363da7db8a314d68b0c711cc42459cad834c` |

`frozen/data.json` is **generated**, never hand-written:
`node tools/sim-port/extract-constants.mjs` reads `js/data.js` and dumps the
tables the port needs, so no balance constant is re-typed and none can drift.
`js/data.js` is not modified.

## 7. Divergence table

Empty. First divergence: **none up to tick 1440** (seed 12345, 25 samples) and
**none up to tick 900** (seed 999, 21 samples). If a later scenario diverges,
the same command prints the offending tick, field and both values, and exits 1.

## 8. Regression gate

`env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 timeout 120 \
/root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/`
→ `PASS 8/8`, exit 0 (unchanged). The main scene and `godot/tests/smoke_test.gd`
were not touched; `git status --porcelain --untracked-files=no` is empty.
