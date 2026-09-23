# tools/parity-godot — cross-engine MATCH parity (lane `crew-parity`)

> **2026-09-23 — the Godot build is now the authority on the rules.** The browser
> build is an archive: `sim.gd` has already diverged from `js/game.js` on purpose
> (the AI's low-drive "containment" of commit `067584e` exists only in the 3D sim;
> measured, m1 and m3 split at the first such shot, m2 is still identical). The
> JS-vs-Godot matrix below is kept for history and is **expected to diverge**.
> The gate is now `bash tools/parity-godot/run-golden.sh`: the same three matches
> replayed through the Godot sim and compared with `golden/` (final digest, every
> event, one full sample every 250 ticks). After an intended rule change, re-record
> with `--record` and commit the golden diff together with the rule change.


The playable thing a player cares about: **does the Godot port play the same match
as the frozen browser reference?** Same seed, same scripted input, whole match,
tick by tick.

The verdict for the three matches run here, with artifacts on disk, is in
`docs/wayfinder/evidence/match-parity.md`. This directory holds the tooling.

It builds on the frozen contract of `tools/parity/**` (which is a *digest*
comparator for the port boundary) and on the runner family of
`tools/sim-port/**` (which reached faults and sets). It adds the two things
neither had: a **whole match played to its result on both engines**, and
**event families the digest line does not print** (net-cord contact, wall/glass
bounce, serve strike, double fault, set closure, result).

## The command

```bash
cd /root/projects/steam-circuit-padel-pro

# all three matches, sequentially, each row appended to out/matrix.jsonl on completion
bash tools/parity-godot/run-match-matrix.sh

# one at a time
bash tools/parity-godot/run-match-matrix.sh m1-plain
bash tools/parity-godot/run-match-matrix.sh m2-double-fault m3-wall-glass-netcord
```

Per scenario the driver does: JS reference → JS reference again (`cmp`: the
reference's own reproducibility control) → the Godot ported core → the verdict,
and records a row immediately (a kill mid-run costs nothing already finished).

Manual form of one step:

```bash
node tools/parity-godot/ref-match.mjs --quiet --out=out/m1-js.txt \
  --seed=12345 --ticks=30000 --every=1 --script=frozen --athlete=0 --sets=1 --stop-at-result

bash tools/parity-godot/run-match-gd.sh \
  --seed=12345 --ticks=30000 --every=1 --script=frozen --athlete=0 --sets=1 --stop-at-result

node tools/parity-godot/compare-match.mjs out/m1-js.txt out/m1-gd.txt \
  --require=net-cord,glass --json=out/m1-compare.json
```

`ref-match.mjs` also has a recon mode used to choose the scenarios:

```bash
node tools/parity-godot/ref-match.mjs --probe --script=frozen --ticks=6000 --every=60 \
  --seeds=1,2,3,7,11,999,2024,12345,999983,424242
```

## Files

| file | side | role |
|---|---|---|
| `ref-match.mjs` | JavaScript | plays a match with the frozen `js/game.js` and prints the frozen digest stream + `# ev` event lines; `--probe` counts events across seeds |
| `run-match-gd.sh` | Godot | runs `res://tests/parity/match_digest_gd.gd` headless, `flock -w 900 /tmp/padel-godot.lock` + `timeout` **inside** the lock, one engine at a time |
| `godot/tests/parity/match_digest_gd.gd` | Godot | the mirror runner: same seed injection, same athlete, same `setsToWin`, same scripted input, same field order, same event lines, driving the ported core (`res://src/sim/**`) — not the game scene |
| `compare-match.mjs` | — | the verdict: delegates the digest gate to `tools/parity/parity-compare.mjs` (strict, `--tol=0`), then compares the `# ev` families and the required-coverage list |
| `run-match-matrix.sh` | — | the three-match driver |
| `out/**` | — | artifacts (streams, compare reports, `matrix.jsonl`, `selftest/` mutants) |

## Scripted input

Two variants, both pure functions of `(tick, state at entry)`, identical on both
engines:

| `--script=` | serve trigger | source |
|---|---|---|
| `frozen` | charging from tick 60, swing on `tick % 30 === 0` | `scripts/parity-digest.mjs:89-98` |
| `full-charge` | charging every tick, swing when `state.serving && state.shotCharge >= 0.999` | `tools/sim-port/fault-digest.mjs:118-125` |

`frozen` reproduces the frozen harness exactly (same `digestSha256` on the
known-good `seed=12345 ticks=1440 every=60` run). `full-charge` is the only
recipe that can fault, because the frozen trigger caps the serve charge at
0.3254 against a measured ≈0.90 fault threshold
(`docs/wayfinder/evidence/parity-coverage-frontier.md` §2).

## Gate semantics

- **Digest gate** — `tools/parity/parity-compare.mjs`, unchanged and strict
  (`--tol=0`): all 21 printed fields, discrete exactly, floats exactly at printed
  precision, tick grid identical. Exit `0` IDENTICAL, `1` DIVERGED, `2`
  NOT-COMPARABLE (contract breach / run-parameter mismatch / tampered stream).
- **Event gate** — the `# ev` families read back from both streams and compared
  record by record:
  - exact tick **and** value: `net-cord`, `glass`, `wall`, `strike`,
    `double-fault`, `set-closed`, `result` — every one of them a number read from
    state the digest does not print (`ball.netCord`, `ball.postGlassSide`,
    `wallEventTimer`, `stats.doubleFaults`);
  - tick only: `family=message`, because the reference stores localized display
    text (`js/i18n.js`) while the port stores message ids (`state.gd:18`). The
    same limitation, and the same reason, as `tools/sim-port/trace-compare.py`.
- **Coverage gate** — `--require=<family,…>` fails the run as `NOT-DONE` (exit 2)
  if a required family is absent from either stream. A match that claims to
  contain a double fault is not evidence for one unless the double fault is in
  the stream.
- **Exit codes**: `0` IDENTICAL, `1` DIVERGED, `2` NOT-DONE / NOT-COMPARABLE,
  `3` usage/IO.

## The gate can fail (selftest)

Both gates were mutated on the real artifacts and both caught the mutation at
the right tick — see `out/selftest/` and `match-parity.md` §5:

```bash
# digest mutation (ball.x at tick 012812, hash kept consistent) -> exit 1, FIRST-DIVERGENCE tick=012812 field=ball.x
node tools/parity-godot/compare-match.mjs out/m2-double-fault-js.txt out/selftest/mut-digest.txt
# event mutation (double-fault event 377 -> 378)               -> exit 1, digest still IDENTICAL
node tools/parity-godot/compare-match.mjs out/m2-double-fault-js.txt out/selftest/mut-event.txt
```

## Not proven

- Three matching matches are **not** parity over all matches: other seeds,
  athletes, tie-breaks, tournament rounds, human/co-op/PvP input and any field
  the digest does not print are outside this gate.
- "IDENTICAL" is agreement at the digest's **6 printed decimals**, at every tick
  (`every=1`) — not bit-identical float64 vs float32.
- `family=message` is compared by tick, not by text, by design.
- No performance, latency or feel claim: every run was headless on a software-GL
  host. A frame-rate claim is not possible here and none is made.
- Drill mode (`js/drill.js` places targets from unseeded `Math.random`) is
  untouched and unverified — `ref-match.mjs` never enters it.
