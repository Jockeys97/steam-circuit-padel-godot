# Evidence: cross-engine digest comparator (`tools/parity/parity-compare.mjs`)

- Date: 2026-09-16
- Host: Linux, `node v22.22.1`, Godot `4.7.2.stable.official.ed1daf0bf`
  (`/root/tools/godot/Godot_v4.7.2-stable_linux.x86_64`)
- Repo: `/root/projects/steam-circuit-padel-pro`, baseline commit `2979588`
- Lane: crew-yankee (consumer half of slice S1)
- Writes limited to `tools/parity/**` and this file. No GDScript written, no
  simulation logic ported, no edit to `scripts/**`, `js/**` or `godot/**`.

## Headline result

The comparator works **and** the first real cross-engine comparison has been run:
the GDScript port under `godot/src/sim/**` (crew-xray) reproduces the JavaScript
digest **byte-for-byte**, at two independent seeds, on all 25 sampled ticks and
all 21 compared fields.

| Run | JS digestSha256 | Godot digestSha256 | Verdict |
|---|---|---|---|
| seed 12345 | `a71366820986b4bd9a9c2c30fd51e82b9fda6dd3caa23c6860949f2d215c27dd` | same | `PARITY-COMPARE IDENTICAL`, exit 0 |
| seed 999 | `3ee635b338daf5aed4a225322ae4904e96f7dbfb7acc5bd0d8ca599e5a282171` | same | `PARITY-COMPARE IDENTICAL`, exit 0 |

`finalRngState` also matches on both sides (`-319693640` / `376071881`). The
comparison was **strict** (exact text on every float field too, no tolerance
applied), so positions and velocities agree to all 6 printed decimals at every
sampled tick.

### Why this is not an artifact of the Godot script reading the JS reference

The Godot harness loads the JS JSON for its own internal comparison, so an echo
was a real risk. Two checks rule it out:

1. **Seed sensitivity**: `--seed=999` produces `3ee635b3…`, and the 12345 hash
   appears **zero** times in that output — the digest is computed from the ported
   simulation, not copied from the reference file.
2. **Second-seed parity against a live JS run** (not the frozen artifact): a
   fresh `node scripts/parity-digest.mjs --seed=999` stream compared against a
   fresh Godot `--seed=999` stream: `IDENTICAL`, matching `finalRngState`
   `376071881` and matching digest sha.

## What this is

The comparator answers, for two parity-digest streams: **equal, or where exactly
does the first difference appear**. It consumes the frozen stream shape defined by
the read-only `scripts/parity-digest.mjs` and specified in
`docs/wayfinder/tickets/simulation-port-boundary.md` §6. It ports nothing and
knows no Godot: a producer only has to print the documented lines.

Left/right may each be a producer's **stdout text**, its **JSON artifact**, or
**`-`** (stdin), and the formats may differ between the sides.

## The command

```bash
node tools/parity/parity-compare.mjs tools/parity/parity-digest-seed12345.json <gd-digest-stream>
godot --headless --path godot --script res://src/sim/parity_digest_gd.gd -- --seed=12345 --ticks=1440 --every=60 \
  | node tools/parity/parity-compare.mjs tools/parity/parity-digest-seed12345.json -
```

Exit codes: `0` IDENTICAL, `1` DIVERGED, `2` NOT-COMPARABLE, `3` usage/IO.

Note on how the Godot side was executed in this lane: from a **copy** of the
project (`cp -r godot /tmp/godot-probe`) so that nothing — not even the engine's
`.godot/` import cache — was written under the repo's `godot/**`. The repo's
`godot/` is byte-untouched and contains no `.godot/`.

## What was run

### 1. Real cross-engine comparison, seed 12345

```
$ node tools/parity/parity-compare.mjs tools/parity/parity-digest-seed12345.json tools/parity/fixtures/godot-side-real-seed12345.txt
# left  left format=json ... seed=12345 ticks=1440 every=60 sampledTicks=25 finalRngState=-319693640 digestSha256=a7136682... integrity=OK side=js
# right right format=digest-text ... digestSha256=a7136682... integrity=OK step=0.008333333333333333
# WARNING [right] il producer ha auto-dichiarato un fallimento: PARITY-DIGEST GD FAIL ...
PARITY-COMPARE RESULT=IDENTICAL firstTick=- field=- comparedSamples=25 comparedFields=21 digestSha256-identical
PRODUCER-SELF-CHECK un producer ha auto-dichiarato FAIL mentre TUTTE le righe di digest coincidono campo per campo: la divergenza e' nel controllo interno di quel producer (formattazione dei suoi valori di riferimento), non nei dati del digest.
PARITY-COMPARE IDENTICAL sampledTicks=25 digestSha256=a71366820986b4bd9a9c2c30fd51e82b9fda6dd3caa23c6860949f2d215c27dd
$ echo $?
0
```

### 2. Hands-off comparison against the frozen JSON artifact

The frozen artifact and a live stdout capture of the harness are cross-format
byte-equal on all 21 fields of all 25 samples, which also proves the artifact's
`samples[]` reconstruct the digest lines whose sha256 it declares.

```
PARITY-COMPARE RESULT=IDENTICAL firstTick=- field=- comparedSamples=25 comparedFields=21 digestSha256-identical
$ echo $?
0
```

### 3. First divergence, located exactly (injected)

```
$ node tools/parity/parity-compare.mjs tools/parity/parity-digest-seed12345.json tools/parity/fixtures/R1-rngState-drift.right.txt
PARITY-COMPARE RESULT=DIVERGED firstTick=000120 field=rngState kind=discrete leftAt="json-sample#3" rightAt="line 6"
FIRST-DIVERGENCE tick=000120 field=rngState kind=discrete
  left : 1199742488
  right: 1199742489
BRANCH-MISMATCH ... per §6 una singola differenza puo' far scattare un gate di probabilita' ...
CASCADE divergentTicksAfter=0 of 22 remaining samples (...)
$ echo $?
1
```

### 4. Streams that must not be compared at all

```
$ node tools/parity/parity-compare.mjs tools/parity/parity-digest-seed12345.json tools/parity/fixtures/R16-seed-mismatch.right.txt
PARITY-COMPARE RESULT=NOT-COMPARABLE reason="parametri di run diversi"
DETAIL seed: left=12345 right=999
$ echo $?
2
```

### 5. Self-test

```
$ node tools/parity/parity-compare-selftest.mjs
# frozen seam: scripts/parity-digest.mjs sha256=2b24dd26b20e3b5a856a2368e6425bd4cbd98592d58144e36f2d73b87d26fdcd
# frozen input: tools/parity/parity-digest-seed12345.json sha256=1032fb20df663a8e0db44ad85d15bcd00a840a1a80b9611cba06c368bb70f0dc
# live JS digest: samples=25 digestSha256=a7136682... finalRngState=-319693640 integrity=OK
  ok   G1-live-js-vs-live-js              exit=0 RESULT=IDENTICAL
  ok   G2-live-js-vs-frozen-json          exit=0 RESULT=IDENTICAL
  ok   G3-rendered-vs-live                exit=0 RESULT=IDENTICAL
  ok   G4-no-summary-line                 exit=0 RESULT=IDENTICAL
  ok   G5-crlf-and-blank-lines            exit=0 RESULT=IDENTICAL
  ok   G6-noise-in-tol-strict             exit=1 RESULT=DIVERGED first=000240/ball.x
  ok   G7-noise-in-tol-with-tol           exit=0 RESULT=IDENTICAL
  ok   R1-rngState-drift                  exit=1 first=000120/rngState
  ok   R2-rngCalls-off-by-one             exit=1 first=000120/rngCalls
  ok   R3-ball-x-beyond-tol               exit=1 first=000240/ball.x
  ok   R4-ball-z-mid-stream               exit=1 first=000900/ball.z
  ok   R5-velocity-component              exit=1 first=001320/v.y
  ok   R6-pointsWon-score-field           exit=1 first=001320/pointsWon
  ok   R7-shotType-sequence               exit=1 first=001380/shotType
  ok   R8-smashStage-enum                 exit=1 first=000060/smashStage
  ok   R9-bounces-counter                 exit=1 first=001380/bounces
  ok   R10-paddle-position                exit=1 first=000060/opponentMate.x
  ok   R11-missing-sample-tick            exit=1 first=000600/samples
  ok   R12-extra-sample-tick              exit=1 first=000030/samples
  ok   R13-earliest-wins                  exit=1 first=000480/ball.y
  ok   R20-producer-self-reported-fail    exit=0 IDENTICAL + WARNING/PRODUCER-SELF-CHECK surfaced
  ok   R20b-fail-verdict-does-not-mask-drift exit=1 first=000060/rngCalls
  ok   R21-cascade-counted-not-listed     exit=1 first=000120/rngState, exactly one FIRST-DIVERGENCE line
  ok   R14-field-order-swapped            exit=2 NOT-COMPARABLE
  ok   R15-missing-field                  exit=2 NOT-COMPARABLE
  ok   R16-seed-mismatch                  exit=2 NOT-COMPARABLE
  ok   R17-tampered-line-intact-summary   exit=2 NOT-COMPARABLE
  ok   R18-duplicate-tick                 exit=2 NOT-COMPARABLE
  ok   R19-truncated-stale-summary        exit=2 NOT-COMPARABLE
  ok   R19b-shorter-consistent-grid       exit=1 first=001200/samples
  ok   U1..U4                             exit=3
SELFTEST PASS cases=34 green=7 red=23 usage=4 failed=0
$ echo $?
0
```

Two consecutive runs produced byte-identical stdout (`diff -q`: no output), so the
suite is rerunnable; fixtures are regenerated into `tools/parity/fixtures/`.

### 6. Proof that the suite can fail (mutation testing)

Two deliberately weakened copies of the comparator (in `/tmp`, the delivered file
untouched) via `PARITY_COMPARE_BIN=...`:

| Mutation | Self-test verdict |
|---|---|
| divergence walk disabled (`if (divergence) {` → `if (false) {`) | **exit 1**, 13 cases failed |
| default tolerance silently set to the unvalidated `1e-3` | **exit 1**, G6 (`strict must still catch 5e-4`) failed |

The unmutated comparator then returned to `SELFTEST PASS ... failed=0` (exit 0).

### 7. Nothing existing was touched

```
$ git status --porcelain
?? docs/
?? godot/
?? meshy/
?? scripts/parity-digest.mjs
?? tools/
$ git diff --stat          # empty: no tracked file modified
$ git log --oneline -1
2979588 fix: il feedback deve arrivare anche dove non si puo' spedire
$ sha256sum scripts/parity-digest.mjs tools/parity/parity-digest-seed12345.json
2b24dd26b20e3b5a856a2368e6425bd4cbd98592d58144e36f2d73b87d26fdcd  scripts/parity-digest.mjs
1032fb20df663a8e0db44ad85d15bcd00a840a1a80b9611cba06c368bb70f0dc  tools/parity/parity-digest-seed12345.json
```

No commit, no push.

## Finding for the other lane (not fixed here — its file, my boundary)

`godot/src/sim/parity_digest_gd.gd` computes an internal comparison and reports
`PARITY-DIGEST GD FAIL` even when its digest lines are byte-identical to the JS
reference. Its `_compare()`/`_text()` formats the JS side through
`Digest.fixed()` (`"0.000000"`, `"1.000000"`) and the GDScript side through
`str()` (integers print as `"0"`, `"1"`), so every integer-shaped discrete field
compares unequal:

```
#   tick=001440 ball.bounces.ai: js=0.000000 gd=0
#   tick=001440 score.rallyHits: js=1.000000 gd=1
#   tick=001440 discrete=MISMATCH floats(max abs)=0.000000000
```

Because `ok` requires `discrete_mismatch_ticks == 0`, that harness can never print
PASS, while its own `body_hash == reference.digestSha256` check (the strongest
signal available) does hold. The fix belongs on the Godot side: compare canonical
digest **text** on both sides, or compare the GD digest lines against the JS
digest lines, rather than re-formatting raw JSON numbers. `tools/parity/parity-compare.mjs`
does exactly that comparison and returns `IDENTICAL` for the same two streams.

## Gate semantics implemented (and where they come from)

- **Discrete, must be bit-identical (14 fields)**: `rngState`, `rngCalls`,
  `bounces`, `shotType`, `smashStage`, `points`, `games`, `sets`, `playerScore`,
  `aiScore`, `pointsWon`, `rallyHits`, `serveAttempts`, `longestRally` — including
  the fields the JS harness prints but does not assert (§6 wants them identical).
- **Float, engine-dependent (7 fields / 18 components)**: `ball`, `v`, `spin` and
  the four paddles' `{x,y}`. Compared **exactly by default**, because the `1e-3`
  in §6 is stated there as a proposal and "not measured". `--tol=0.001` opts in and
  the report says `PROPOSTA §6, MAI MISURATA - non e' un gate validato`.
  (The real runs above needed no tolerance at all.)
- **Cascade, not findings**: after a discrete break the tail is counted and
  labelled `CASCADE` (§6: one probability-gate flip diverges the engines for good).
- **Integrity before comparison**, exit 2 with **no field walk**: a declared
  `digestSha256`/`sampledTicks` that contradicts the lines present, a JSON artifact
  whose `samples[]` disagree with its `digestSha256`, or a contract violation
  (field order, field count, duplicate or non-increasing tick).
- **A producer's own FAIL verdict is a warning, not a veto**: it describes that
  producer's self-check, not the lines it printed; refusing to compare would hide
  the field-level evidence. The integrity checks above are the real guard, and
  case R20b proves a FAIL verdict cannot mask a genuine drift.

## Limits / not proven

- **Two seeds, one segment.** 12 s of match time, 25 samples, one point, seeds
  12345 and 999. Games, sets, tie-breaks, faults, the special and long rallies are
  not exercised; parity beyond this window is unmeasured.
- **Agreement is at printed precision.** The digest prints 6 decimals, so
  "identical" means identical to 6 decimals at the sampled ticks, not bit-identical
  float64/float32. Any drift smaller than 5e-7 at a sampled tick, or divergence
  between samples, would not show here. The `1e-3` §6 tolerance is therefore still
  unvalidated, though the observed agreement is ~1000× tighter than it at every
  sample.
- **`rngCalls` provenance differs by side**: reconstructed on the JS side by the
  harness, a real counter inside `nextRandom` on the Godot side. Equality holds
  for the JS reconstruction vs the GDScript counter, which is the useful direction,
  but a JS-side mis-reconstruction would not be detected by this comparator.
- **The comparison is only as good as the digest.** Fields outside the frozen
  shape (events, messages, fx, `state.fx.shake`) are out of scope by §6, so two
  engines could match here and still differ where §6 says not to look.
- **The Godot producer may still change** (crew-xray holds that lane and was
  writing `godot/src/sim/**` during this run); the digests compared here are a
  snapshot of those files at this timestamp, not a released artifact.

## Artifacts

| File | Bytes | sha256 |
|---|---|---|
| `tools/parity/parity-stream.mjs` | 15949 | `120f5beeb31be9fd511fcd0f6d495885a7e97013ef0b734828af1e83838e10dd` |
| `tools/parity/parity-compare.mjs` | 18168 | `127e47a768c902237ca77b25f51815554ac6d71ae37529307b73d0213dc0fa96` |
| `tools/parity/parity-compare-selftest.mjs` | 26411 | `690d6d8cde1fe62f77eb6063bfaddc287bc77b8345e4a36b3f96454a54eed6c0` |
| `tools/parity/README.md` | 5077 | `2ec778e84dcc5352e3c368cd9a4122e6db66e682713d50363efad4776e94166f` |
| `tools/parity/fixtures/**` | generated | includes `godot-side-real-seed12345.txt`, `godot-side-real-seed999.txt`, `js-seed999-live.txt` — the real streams of the two comparisons above |

Read-only inputs consumed unchanged: `scripts/parity-digest.mjs` (`2b24dd26…`)
and `tools/parity/parity-digest-seed12345.json` (`1032fb20…`).

## Cost

0 metered spend authorised; existing OpenCode Go subscription only
(provider `opencode-go`, model `deepseek-v4.1-flash`).
