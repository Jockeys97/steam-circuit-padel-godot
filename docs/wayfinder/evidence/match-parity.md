# Cross-engine MATCH parity — three whole matches, tick by tick, frozen JS reference vs Godot port core

- **Date:** 2026-09-16 (CEST) · **Lane:** `crew-parity` · **Host:** Linux 3,910 MB RAM, 2 GiB swap, other lanes active
- **Repo:** `/root/projects/steam-circuit-padel-pro` @ working tree (browser build frozen at commit `2979588`)
- **Engines:** Node (frozen browser reference, `js/game.js`) vs `Godot_v4.7.2-stable_linux.x86_64` (4.7.2.stable.official.ed1daf0bf, headless, no rendering)
- **Question answered:** does the Godot port play the **SAME MATCH** as the frozen browser reference — same seed, same scripted input, tick by tick, over a whole match, for three different matches?
- **Answer, first line:** **IDENTICAL — no divergence to bisect. All three matches agree line for line over every tick played (22 210 / 12 813 / 16 858 ticks, `every=1`), equal `digestSha256`, and every event the digest cannot print (net-cord contacts, wall/glass bounces, serve strikes, the double fault, set closure, result) fires on the same tick with the same values on both engines.**
- **Nothing was fixed** — the comparison found no divergence, so no `godot/src/sim/**` change was needed or made.
- **Untouched, verified by hash:** `scripts/parity-digest.mjs` = `2b24dd26b20e3b5a856a2368e6425bd4cbd98592d58144e36f2d73b87d26fdcd` (the frozen harness), `js/game.js` = `c19277add6a035f7da6c2db4b162b1cd9d58d26e1fa97cd6c81f6f99e69455c9`. `godot/src/sim/**` not modified (only the *new* harness `godot/tests/parity/match_digest_gd.gd`, which is outside it). No commit, no push, no deploy, no network retrieval, **$0 spend, 0 Meshy credits**.

---

## 1. Headline table

Every number below is from a stored artifact (paths, bytes and sha256 in §6).

| # | match | seed | script / athlete / setsToWin | ticks compared (`every=1`) | digestSha256 (both engines) | digest gate | event gate | verdict |
|--:|---|--:|---|---:|---|---|---|---|
| **M1** | plain match to the result | 12345 | `frozen` / 0 maestro / 1 | **22 210** | `69a10a201e9b33db4554c0dd75fc12fe0eef830fd26e902de86abc6dc93205d7` | `IDENTICAL` (exit 0) | `IDENTICAL` (254 records) | **IDENTICAL** |
| **M2** | match containing a **double fault** | 999 | `full-charge` / 1 pantera / 1 | **12 813** | `c2cd281d6093eef071e12818c287095531f4109662f7d71b4a355c1a89161f11` | `IDENTICAL` (exit 0) | `IDENTICAL` (186 records) | **IDENTICAL** |
| **M3** | match containing **wall/glass bounces + net-cord contacts** | 11 | `frozen` / 0 maestro / 1 | **16 858** | `6917dfdf0df8724afa3c7052cfbe11a6b5af6a70e4774fc4c43be56d8c4a8619` | `IDENTICAL` (exit 0) | `IDENTICAL` (219 records) | **IDENTICAL** |

| # | earliest divergence | net-cord | wall/glass | serve strikes | double fault | set closed | result |
|--:|---|---|--:|---|--:|---:|---:|---|
| M1 | **none** | 6 (ticks 5386, 8589, 9138, 11440, 13128, 15184) | 29 glass + 15 wall | 32 | 0 | 1 @ tick 22 209 | tick 22 210, winner `ai` |
| M2 | **none** | 0 | 28 glass + 14 wall | 29 | **1 @ tick 377, server `player`** | 1 @ tick 12 812 | tick 12 813, winner `ai` |
| M3 | **none** | 9 (ticks 1208, 1755, 2868, 4103, 4603, 5230, 6554, 7753, 11203) | 25 glass + 13 wall | 26 | 0 | 1 @ tick 16 857 | tick 16 858, winner `ai` |

The three matches cover the three behaviours the brief names, and *each one actually contains what it is named for* — checked, not assumed: `compare-match.mjs --require=…` returns `NOT-DONE` (exit 2) if the required event family is absent from either stream, and all three runs printed `present on both engines`.

Independent confirmations of the same three pairs (details §4):

- **byte-level**, comparator-free: `grep '^tick=' <js> | cmp` with `grep '^tick=' <gd>` → **byte-identical** on all three (22 210 / 12 813 / 16 858 lines); the same for the event lines excluding the localized `family=message` text (85 / 75 / 76 lines, counting the shared `# event-families=…` header line, byte-identical).
- the **pre-existing** Godot hook `godot/src/sim/parity_digest_gd.gd`, run against the JSON artifact *my* JS runner produced, prints `PARITY-DIGEST GD PASS … discreteMismatchTicks=0 floatToleranceTicks=0 firstDivergence=none` on 501 samples of a 30 000-tick run.
- the whole gate **can fail**: two mutations of the real M2 artifact are caught, at the right tick and field (§5).

---

## 2. Scenario selection — measured, not guessed

**Seeds for M3.** A seed probe (`ref-match.mjs --probe`, counting the event families the digest cannot show, over the frozen script, 6 000 ticks) selected seed 11 as the richest wall/glass + net-cord seed:

```
# probe script=frozen athlete=0 sets=-1 ticks=6000 every=60 seeds=1,2,3,7,11,999,2024,12345,999983,424242
seed=1    netCord=2 glass=12 wall=6 strike=9 doubleFault=0 setClosed=0 resultTick=none samples=101
seed=2    netCord=1 glass=8  wall=4 strike=8 doubleFault=0 setClosed=0 resultTick=none samples=101
seed=3    netCord=3 glass=8  wall=4 strike=10 doubleFault=0 setClosed=0 resultTick=none samples=101
seed=7    netCord=2 glass=10 wall=5 strike=8 doubleFault=0 setClosed=0 resultTick=none samples=101
seed=11   netCord=6 glass=5  wall=3 strike=9 doubleFault=0 setClosed=0 resultTick=none samples=101
seed=999  netCord=2 glass=6  wall=3 strike=8 doubleFault=0 setClosed=0 resultTick=none samples=101
seed=2024 netCord=4 glass=6  wall=3 strike=8 doubleFault=0 setClosed=0 resultTick=none samples=101
seed=12345 netCord=1 glass=8 wall=4 strike=9 doubleFault=0 setClosed=0 resultTick=none samples=101
seed=999983 netCord=2 glass=8 wall=4 strike=8 doubleFault=0 setClosed=0 resultTick=none samples=101
seed=424242 netCord=1 glass=8 wall=4 strike=6 doubleFault=0 setClosed=0 resultTick=none samples=101
```

Note the count contract: `glass` counts `postGlassSide` *transitions* (every wall/back-wall bounce after a ground bounce), `wall` counts cooldown re-arms — the cooldown (`wallEventCooldown = 1.4 s`) suppresses the second line of a burst, which is why the wall count is lower. Both counters are printed, so the difference is visible rather than hidden.

**Athlete and script for M2.** A double fault needs a *second-serve fault*, and with the frozen script the serve charge caps at 0.3254 against a measured ≈0.90 fault threshold (`parity-coverage-frontier.md` §2), so the frozen harness cannot reach one at all. M2 therefore uses the recipe `tools/sim-port/fault-digest.mjs` already established — full-charge serve trigger + `ATHLETES[1]` "pantera" (control 0.96) — under which `fault-double-fault-set-parity.md` §1.3 measures 63/300 second-serve faults against maestro's 0/300. Seed 999 is that document's own A3 seed, so M2 **reproduces its result exactly**: second serve struck at tick 253 with `charge=1.000000`, double fault during tick 377 with `server=player total=1`, set closed 0-1 at 12 812, match result at 12 813. Two independent lanes, same numbers.

---

## 3. Commands, exit codes, key output lines

All of it through one driver, which appends each scenario row to disk the moment it finishes (two lanes in this mission were killed mid-run; nothing here is held in memory):

```bash
cd /root/projects/steam-circuit-padel-pro
bash tools/parity-godot/run-match-matrix.sh            # all three, sequentially
bash tools/parity-godot/run-match-matrix.sh m1-plain   # or one at a time (what was run here)
```

Per scenario the driver runs, in this order, **never two engine processes alive at once**:

```bash
# 1+2. JS reference, twice (the second run is the reference's own control)
node tools/parity-godot/ref-match.mjs --quiet --out=tools/parity-godot/out/<id>-js.txt \
     --seed=<S> --ticks=<T> --every=1 --script=<frozen|full-charge> --athlete=<A> --sets=1 --stop-at-result
# 3.   cmp <id>-js.txt <id>-js-rerun.txt
# 4.   Godot ported core — flock -w 900 /tmp/padel-godot.lock, timeout inside the lock, headless
bash tools/parity-godot/run-match-gd.sh --seed=<S> --ticks=<T> --every=1 --script=<…> --athlete=<A> --sets=1 --stop-at-result
# 5.   the verdict (digest gate delegated to the established comparator, then the event gate)
node tools/parity-godot/compare-match.mjs <id>-js.txt <id>-gd.txt --require=<families> --json=<id>-compare.json
```

| scenario | step | exit | key output line |
|---|---|--:|---|
| M1 | JS reference ×2 | 0, 0 | `PARITY-DIGEST JS PASS seed=12345 ticks=30000 sampledTicks=22210 every=1 finalRngState=-2140352356 digestSha256=69a10a20…05d7` |
| M1 | `cmp` js vs rerun | 0 | js_rerun=**identical** (both files sha256 `3e7fbee2a4b9201dd9d6783b29bed05d2f999d4fb33b31354b48ee724d4104fa`) |
| M1 | Godot core | 0 | `PARITY-DIGEST GD PASS seed=12345 ticks=30000 sampledTicks=22210 every=1 finalRngState=-2140352356 digestSha256=69a10a20…05d7` |
| M1 | compare-match | 0 | `MATCH-COMPARE RESULT=IDENTICAL digest=IDENTICAL events=IDENTICAL coverage=OK sampledTicks=22210/22210 digestSha256=69a10a20… (identical)` |
| M2 | JS reference ×2 | 0, 0 | `PARITY-DIGEST JS PASS seed=999 ticks=14000 sampledTicks=12813 every=1 finalRngState=1120637345 digestSha256=c2cd281d…1f11` |
| M2 | Godot core | 0 | `PARITY-DIGEST GD PASS … sampledTicks=12813 … digestSha256=c2cd281d…1f11` |
| M2 | compare-match | 0 | `MATCH-COMPARE RESULT=IDENTICAL … ; # event-counts js: double-fault=1 glass=28 …; # required-families double-fault,glass -> present on both engines` |
| M3 | JS reference ×2 | 0, 0 | `PARITY-DIGEST JS PASS seed=11 ticks=30000 sampledTicks=16858 every=1 finalRngState=-357587474 digestSha256=6917dfdf…8619` |
| M3 | Godot core | 0 | `PARITY-DIGEST GD PASS … sampledTicks=16858 … digestSha256=6917dfdf…8619` |
| M3 | compare-match | 0 | `MATCH-COMPARE RESULT=IDENTICAL … ; # event-parity: js=219 gd=219 records, mismatched=0` |

Comparator internals for the three pairs (from `<id>-compare.txt`):

```
M1  # engine-parity: tools/parity/parity-compare.mjs --tol=0 exit=0
M1  #   PARITY-COMPARE RESULT=IDENTICAL firstTick=- field=- comparedSamples=22210 comparedFields=21 digestSha256-identical
M1  # event-counts js: glass=29 message=170 net-cord=6 result=1 set-closed=1 strike=32 wall=15
M1  # event-counts gd: glass=29 message=170 net-cord=6 result=1 set-closed=1 strike=32 wall=15
M1  # event-parity: js=254 gd=254 records, mismatched=0 (message family compared by tick only)

M2  #   PARITY-COMPARE RESULT=IDENTICAL firstTick=- field=- comparedSamples=12813 comparedFields=21 digestSha256-identical
M2  # event-counts js: double-fault=1 glass=28 message=112 result=1 set-closed=1 strike=29 wall=14
M2  # event-parity: js=186 gd=186 records, mismatched=0

M3  #   PARITY-COMPARE RESULT=IDENTICAL firstTick=- field=- comparedSamples=16858 comparedFields=21 digestSha256-identical
M3  # event-counts js: glass=25 message=144 net-cord=9 result=1 set-closed=1 strike=26 wall=13
M3  # event-parity: js=219 gd=219 records, mismatched=0
```

**First divergence: none on any of the three.** The comparator has nothing to bisect, so no field-level, file:line root-cause analysis is reported — there is no divergence to explain. *What that does and does not mean is in §8.*

### Engine hygiene (the rule that no `PASS` sits next to an unhandled error)

- `grep -c "SCRIPT ERROR"` over all three Godot stdout streams and their stderr files: **0**.
- `grep -E "^(ERROR|USER ERROR|USER SCRIPT ERROR):"`: **0**; all three `<id>-gd.stderr` are **0 bytes** (sha256 `e3b0c442…`).
- The engine harness is still green after adding the new files: `flock -w 900 /tmp/padel-godot.lock timeout 120 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/` → `PASS 8/8`, exit 0, no `SCRIPT ERROR`.
- One engine at a time: every Godot invocation went through `flock -w 900 /tmp/padel-godot.lock` with `timeout` **inside** the lock. No rendering was requested and none happened; **no frame-rate claim is made anywhere in this document** (software GL on this host cannot support one).

---

## 4. The independent confirmations

### 4.1 Comparator-free byte comparison

The digest gate is also checked without the comparator, by byte-comparing the extracted tick lines (`cmp` reports `<file> differ: byte …` iff they do):

```
m1-plain               lines=22210/22210 byte-identical
m2-double-fault        lines=12813/12813 byte-identical
m3-wall-glass-netcord  lines=16858/16858 byte-identical
# event lines, `family=message` excluded (localized text vs message ids):
m1-plain               event-lines=85  byte-identical
m2-double-fault        event-lines=75  byte-identical
m3-wall-glass-netcord  event-lines=76  byte-identical
```

Source of the byte difference between the *files* (`m1-plain-js.txt` 9 412 085 B vs `m1-plain-gd.txt` 9 407 784 B): the engine banner line and the harness-specific `#` header text. The tick lines themselves are identical, which is what the gate is about.

### 4.2 The pre-existing hook agrees with my JavaScript runner

The brief asks for the ported core to be driven "via the existing hook". My three scenarios need options that hook does not have (`--athlete`, `--sets`, `--stop-at-result`) and `godot/src/sim/**` is outside my write scope, so the three matches run through the **new** harness `godot/tests/parity/match_digest_gd.gd`, which uses the same core (`Sim.create_match_state` / `Sim.update_match`) and the same formatter (`digest.gd`). As a cross-check, the *existing* hook was run unchanged against **my** JS runner's JSON artifact, on the exact M1 configuration (frozen script, athlete 0, `setsToWin` default, 30 000 ticks, `every=60`):

```
$ flock -w 900 /tmp/padel-godot.lock timeout 300 env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
    /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
    --script res://src/sim/parity_digest_gd.gd -- \
    --seed=12345 --ticks=30000 --every=60 --js=<abs>/legacyhook-js-12345-30000-60.json
# compare sampledTicks=501 discreteMismatchTicks=0 floatToleranceTicks=0 firstDivergence=none
PARITY-DIGEST GD PASS seed=12345 ticks=30000 sampledTicks=501 every=60 finalRngState=-500610134 digestSha256=df095356f273f691f405fbe99d834ad1cc05df7489efbb3023993468f33d1a22
$ node tools/parity/parity-compare.mjs legacyhook-js…txt legacyhook-gd…txt   # exit 0
PARITY-COMPARE IDENTICAL sampledTicks=501 digestSha256=df095356…1a22
```

Two things this adds: (a) the pre-existing hook validates *my* JS numbers, not only its own; (b) the 501 samples at `every=60` span ticks 0–30 000, i.e. they **include the post-result harness tail** past tick 22 210 (`result` @ 22 210) — the tail the `parity-coverage-frontier.md` §3 document calls unreachable in the shipped game. It matches too, so a `--stop-at-result` run is not hiding a tail divergence.

---

## 5. The gate can fail (mutation test on the real artifacts)

A proof that never fails is not a proof. Both gates were mutated on the real M2 artifacts, in `tools/parity-godot/out/selftest/`, and both mutations were caught at the right tick with the right field:

**(A) one float moved on one digest line** — `ball.x` at tick 012812 changed by +1.0, with the declared `digestSha256` recomputed so the stream is internally consistent (otherwise the integrity guard trips first and the *field* gate is never exercised — that mistake was made once here and is on the record):

```
# engine-parity: tools/parity/parity-compare.mjs --tol=0 exit=1
#   FIRST-DIVERGENCE tick=012812 field=ball component=ball.x kind=float
#   left : 165.269338
#   delta: 1
MATCH-COMPARE RESULT=DIVERGED digest=DIVERGED events=IDENTICAL coverage=OK   (exit 1)
```

**(B) one event tick moved** — the M2 double-fault event shifted 377 → 378, digest lines untouched:

```
# engine-parity: tools/parity/parity-compare.mjs --tol=0 exit=0
# first-event-divergence index=5 tick=000377 family=double-fault
#   js: 000377 family=double-fault server=player total=1
#   gd: 000378 family=double-fault server=player total=1
MATCH-COMPARE RESULT=DIVERGED digest=IDENTICAL events=DIVERGED coverage=OK   (exit 1)
```

(B) is the case the digest alone is blind to: the digest gate says `IDENTICAL` and the event gate still reports the divergence, at tick 377. For completeness, a *tampered* stream whose declared hash no longer matches its body is refused as `NOT-COMPARABLE` (exit 2) by the frozen comparator's integrity check before any field walk — that is the comparator's own self-check, and it was observed (exit 2, not 0).

---

## 6. Artifacts (path, bytes, sha256)

All under `tools/parity-godot/` (new, this lane's only write scope besides this document). Streams are `every=1`, so the tick count equals the sample count.

| path | bytes | sha256 |
|---|---:|---|
| `tools/parity-godot/ref-match.mjs` (source) | 19 080 | `9f4b7d30799e6c9797650dd7e437cc7396837fa8cff12f27657aeeb73e3088a7` |
| `tools/parity-godot/compare-match.mjs` (source) | 11 956 | `824cf02f4c25d275f3c41179d5fe0b8da76d6f7aa8eb1b1ff91cb81643edcdfd` |
| `tools/parity-godot/run-match-gd.sh` (source) | 1 118 | `fb883a7b45ec1774174cb3dc0338b5efc12edf41f25b5e12c304f232fae29dbd` |
| `tools/parity-godot/run-match-matrix.sh` (source) | 5 354 | `1d8e19b8fa379ee8c6b41ac7e7c194f68db91496d03e42b7a5d152f19350f09a` |
| `tools/parity-godot/README.md` (source) | 6 449 | `994a56a4175bfed71af50870390c93316b22b500908149a2cff9bcf12599f101` |
| `godot/tests/parity/match_digest_gd.gd` (source) | 10 930 | `68bb657010292cd7a470a7fa1760a3d27caf04b7271f3dd47cb85f46e69b0f64` |
| `out/m1-plain-js.txt` | 9 412 085 | `3e7fbee2a4b9201dd9d6783b29bed05d2f999d4fb33b31354b48ee724d4104fa` |
| `out/m1-plain-js-rerun.txt` | 9 412 085 | `3e7fbee2a4b9201dd9d6783b29bed05d2f999d4fb33b31354b48ee724d4104fa` |
| `out/m1-plain-gd.txt` | 9 407 784 | `520d436b3b00afef76382946fa5e4374d11b922c0b6c5bba869f56a62f606aef` |
| `out/m2-double-fault-js.txt` | 5 430 937 | `27dc85c2969ea792f3fdd48aeb3eb0687eb890c331866a59e0a8f8b2be0b8ff4` |
| `out/m2-double-fault-js-rerun.txt` | 5 430 937 | `27dc85c2969ea792f3fdd48aeb3eb0687eb890c331866a59e0a8f8b2be0b8ff4` |
| `out/m2-double-fault-gd.txt` | 5 428 312 | `0a0c6d21ce3873169308212efc359f1de9cf00cf48b706b9ee45c68331b6b942` |
| `out/m3-wall-glass-netcord-js.txt` | 7 139 811 | `1d8ea1365c38d1edf65395d45fd4fa66faefa7b9f56d5390deb5c59d3200a1e1` |
| `out/m3-wall-glass-netcord-js-rerun.txt` | 7 139 811 | `1d8ea1365c38d1edf65395d45fd4fa66faefa7b9f56d5390deb5c59d3200a1e1` |
| `out/m3-wall-glass-netcord-gd.txt` | 7 135 983 | `d06bba36ec719fda10d85452228c214263d24bada23273e6e578f5fe359d4af3` |
| `out/m1-plain-compare.txt` | 1 775 | `547cc006ba767b5c5489392da206d5d4ac40e75ade060b33fc51355a8db2db65` |
| `out/m2-double-fault-compare.txt` | 1 816 | `320723f484933a7df1f0cf94a0ab503f2cd2589cb542caf8c75a650e218a9584` |
| `out/m3-wall-glass-netcord-compare.txt` | 1 837 | `a5aa9e8055972545293928c5ff62783d12afab0c008710cb1d09a4f078ef784e` |
| `out/matrix.jsonl` (6 rows = 3 scenarios × 2 runs, machine-readable) | 3 166 | `29059bd28fa0e118255c8b5740f9554d3f52883ec6568f1348b5e7a7ca7f98bf` |
| `out/*-compare.json`, `out/*-compare-parity-compare.json` (9 files) | 1 171–1 390 each | see `out/` |
| `out/legacyhook-js-12345-30000-60.{txt,json}` | 293 573 / 550 484 | `7b2be0dd…5336` / `97a09295…aada` |
| `out/legacyhook-gd-12345-30000-60.txt` | 242 011 | `405e3c8aa3f1b69dcf81d50bd5f02cdf9450b517736cc970474056f473011852` |
| `out/selftest/mut-digest.txt`, `mut-event.txt` + their compare outputs | 5 428 328 / 5 428 312 | `out/selftest/` |
| `out/*-gd.stderr` (3 files) | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |

`matrix.jsonl` (the three rows of the **first** run, verbatim; hashes truncated to 16 hex chars in these JSONL rows only — full values in the table above and in the streams themselves. The file on disk now holds 6 rows: the documented headline command `bash tools/parity-godot/run-match-matrix.sh` was then run **with no arguments**, which played all three matches a second time. The 3 second-run rows are equal to these 3 in every field (`verdict`, `digest_js`, `digest_gd`, `digest_equal`, `gd_exit`, `gd_script_errors`) and **all six stream files re-hashed to exactly the run-1 sha256 values** — the whole proof reproduces end to end, not just the JS half):

```json
{"athlete": 0, "compare_exit": 0, "digest_equal": true, "digest_gd": "69a10a20…05d7", "digest_js": "69a10a20…05d7", "every": 1, "gd_exit": 0, "gd_script_errors": 0, "gd_unexpected_errors": 0, "id": "m1-plain", "js_exit": 0, "js_rerun": "identical", "js_rerun_exit": 0, "require": ["net-cord", "glass"], "script": "frozen", "seed": 12345, "setsToWin": 1, "ticks": 30000, "verdict": "MATCH-COMPARE RESULT=IDENTICAL"}
{"athlete": 1, "compare_exit": 0, "digest_equal": true, "digest_gd": "c2cd281d…1f11", "digest_js": "c2cd281d…1f11", "every": 1, "gd_exit": 0, "gd_script_errors": 0, "gd_unexpected_errors": 0, "id": "m2-double-fault", "js_exit": 0, "js_rerun": "identical", "js_rerun_exit": 0, "require": ["double-fault", "glass"], "script": "full-charge", "seed": 999, "setsToWin": 1, "ticks": 14000, "verdict": "MATCH-COMPARE RESULT=IDENTICAL"}
{"athlete": 0, "compare_exit": 0, "digest_equal": true, "digest_gd": "6917dfdf…8619", "digest_js": "6917dfdf…8619", "every": 1, "gd_exit": 0, "gd_script_errors": 0, "gd_unexpected_errors": 0, "id": "m3-wall-glass-netcord", "js_exit": 0, "js_rerun": "identical", "js_rerun_exit": 0, "require": ["net-cord", "glass", "wall"], "script": "frozen", "seed": 11, "setsToWin": 1, "ticks": 30000, "verdict": "MATCH-COMPARE RESULT=IDENTICAL"}
```

(hashes truncated to 16 hex chars in the JSONL rows only; full values in the table above and in the streams themselves)

### What the JS runner is, and why it is not the frozen harness

`tools/parity-godot/ref-match.mjs` drives `js/game.js` with the frozen harness's own contract — `FIXED_STEP = 1/120`, one `updateMatch` per tick, the same seed injection at `scripts/parity-digest.mjs:242`, the same `scriptedInputFor` (`:89-98`), the same 21-field digest line rendered through the comparator's own formatter (`parity-stream.mjs` `valuesFromJsonSample` + `lineFromValues`). Its fidelity is checkable, not asserted: on the frozen known-good scenario it reproduces the frozen artifact **exactly** —

```
$ node tools/parity-godot/ref-match.mjs --seed=12345 --ticks=1440 --every=60 --out=…
PARITY-DIGEST JS PASS seed=12345 ticks=1440 sampledTicks=25 every=60 finalRngState=-319693640 digestSha256=a71366820986b4bd9a9c2c30fd51e82b9fda6dd3caa23c6860949f2d215c27dd
$ node tools/parity/parity-compare.mjs tools/parity/parity-digest-seed12345.json <that stream>   # exit 0
PARITY-COMPARE RESULT=IDENTICAL … digestSha256-identical
```

That hash is the frozen artifact's own (`tools/parity/parity-digest-seed12345.json`, READ-ONLY) — the same value the mission owner's baseline and every earlier lane quote. The stream itself is a runner-fidelity check rather than a match result, and lives in scratch (`/tmp/crew-parity/selfcheck-12345-1440-60.txt`); the command takes about one second to reproduce.

It exists because the frozen harness (a) cannot reach a fault at all (serve-charge cap 0.3254 vs a 0.90 threshold) and (b) runs past `state.result` into the free-fall tail, so it cannot play "a match to the result" in the sense this proof needs. It was **not** modified: `scripts/parity-digest.mjs` still hashes to `2b24dd26…fdcd`.

---

## 7. Reference reproducibility — the brief's `Math.random` warning

The brief warns that a previous lane found `js/drill.js` placing drill targets from unseeded `Math.random`, and asks that non-reproducibility be stated rather than papered over. Stated precisely:

- **`js/game.js` has exactly one `Math.random` on the match path**: the initial `rngState: (Math.random() * 0xffffffff) | 0` (`js/game.js:218`). Both runners overwrite it immediately after `createMatchState` (`state.rngState = seed`, the same injection the frozen harness and `scripts/determinism-audit.mjs` use). No other `Math.random` exists in `js/game.js` outside comments.
- **Measured, not assumed:** each scenario's JS reference was run twice and the two streams compared with `cmp` — byte-identical on all three (identical sha256 for `-js.txt` and `-js-rerun.txt`, §6). The reference is therefore reproducible *for these matches*, on this host, run to run.
- **Out of scope and untouched:** `js/drill.js`'s three unseeded `Math.random` calls (lines 155, 159-160) are in **drill mode**, which this proof does not enter. A drill-mode parity claim would need its target placement seeded first; **no such claim is made here**, and nothing in this lane changes `js/**`.

---

## 8. Precision limits of "IDENTICAL" (explicit)

- The digest prints floats at **6 decimals**. `IDENTICAL` means identical *to the printed precision* — not bit-identical `float64` vs the port's float32 nodes. Sub-5e-7 drift at a sample would not show. The deltas that would matter, if they existed, are orders of magnitude larger: the one real port bug found so far (`sim.gd:1114`, the mistranslated `??`) produced a `v.x` delta of 1.398 on its first tick.
- **No sampling gap:** every match was run at `every=1`, so there is no "divergence between two samples" hole for these three runs. This is the difference between this proof and the 12-scenario matrix (which sampled at 7/60/120 and, at tick 2207, spent 74 ticks not noticing).
- `--stop-at-result` truncates at the result. The tail is *not* unverified as a result: §4.2 runs 30 000 ticks without the flag through the pre-existing hook and is `IDENTICAL` across the tail too. The digest is sampled *before* the step, so the last digest line of a `--stop-at-result` run is the **entry state of the tick during which the match-winning point was resolved** — the set closure and the result appear only as `# ev` lines (M1: set closed during tick 22 209, result at tick 22 210, last digest line `tick=022209 … sets=0-0 games=0-5`). Both engines stop on the same tick, so the sample grids are identical; do not read that last digest line as "the state after the match ended".
- The event families are observations of state the digest does not print; they are printed at 6 decimals as well, and `family=message` is compared by **tick only** (localized text vs message ids, by design — same limitation as `tools/sim-port/trace-compare.py:14-17`). Every other family is compared value for value.
- Agreement on the digest is agreement on the **21 printed fields**. Fields neither printed nor observed here (`motion`, `runPhase`, `swing`, `charge` per paddle, `replayFrames`, FX timers, the ten-rules audit surface) are outside this gate; `parity-divergence-2207.md` is the standing proof that such a field can hide a real divergence (`paddle.motion` did).

---

## 9. VERIFIED vs INFERRED vs NOT DONE

**VERIFIED (ran it, both engines, artifacts on disk)**

- Three whole matches, three configurations (plain / double fault / wall-glass + net-cord), `every=1`: **22 210, 12 813 and 16 858 ticks compared, first divergence none, `digestSha256` equal per pair**, confirmed three ways (frozen comparator at `--tol=0`, comparator-free byte `cmp`, and for M1's configuration also the pre-existing Godot hook).
- Every claimed behaviour is present in the run that claims it, machine-checked by `--require`: M1 net-cord ×6 + glass ×29; M2 double fault ×1 @ tick 377 + glass ×28; M3 net-cord ×9 + glass ×25 + wall ×13.
- The M2 double fault reproduces the earlier lane's A3 numbers exactly (first serve tick 126 charge 1.000000, second serve tick 253 charge 1.000000, double fault tick 377 `server=player total=1`, set 0-1 @ 12 812, result @ 12 813).
- The reference is reproducible: two JS runs per scenario, byte-identical.
- **The whole proof reproduces.** The documented headline command (`run-match-matrix.sh`, no arguments) was run a second time end to end: identical verdicts, identical `digestSha256` per scenario, and all six stream files re-hashed to the same sha256 as the first run.
- The gate fails when it should: two mutation tests on the real M2 artifact, each caught at the correct tick (a float → `ball.x` @ 012812; an event tick → `family=double-fault` 377 vs 378 with the digest still `IDENTICAL`).
- Engine hygiene: 0 `SCRIPT ERROR`, 0 `ERROR:`-class lines, 0-byte stderr on all three runs; `PASS 8/8` engine harness after the new files; one engine at a time under `flock`.

**INFERRED**

- Nothing about other seeds or other athletes. What generalises is the *method* (§3), not the result: three matches are three points in a large scenario space.

**NOT DONE / NOT PROVEN**

- **Three matching matches are not a proof over all matches.** They are a proof that parity holds on the full length of these three specific deterministic matches (and, via §4.2, on a fourth 30 000-tick run). A divergence reachable only in a different seed, a different athlete, a tie-break, a tournament round, human-mode/co-op/PvP input, or a field the digest does not print would be invisible here.
- **No frame-rate, latency or "feel" claim of any kind.** All three runs were headless on a software-GL host that cannot render; nothing in this document measures or implies performance, responsiveness or playability.
- **No tie-break coverage.** All three matches closed `sets=0-1` with no tie-break reached — verified, not assumed: `games` only ever took the values `0-0 … 0-5` in all three runs (uniqued over every tick), so each set was won **0-6** and a tie-break needs 6-6; `tieBreak`/`tieBreakPoints` are unexercised.
- **No human/analog input, no slice/lob/variant input, no specials.** The scripted input is a pure function of the tick (plus, in M2, `state.serving` and `state.shotCharge` at entry) — the same shape the frozen harness uses. Only the two scripted variants were exercised; `slice`, `shotVariant`, `special`, `sprint`, `analogAim` are all left at their empty values.
- **Only one double fault per match was reached** (M2, one; the seed probe shows 1–2 per match for the full-charge recipe). The double-fault *rate* is not measured here; `fault-double-fault-set-parity.md` §1.3 covers reachability.
- **The net-cord/glass coverage is by event, not by consequence.** The events are observed and compared; that a net-cord contact always follows every rule in the same way afterwards, across all seeds, is not proven.
- **`--stop-at-result` was used for the primary trio**, so the primary streams end at the result tick by construction. The tail is covered separately (§4.2, `every=60`), not at `every=1`.
- **No goldens committed**: all streams are untracked artifacts under `tools/parity-godot/out/`; they are large (≈48 MB total) and can be regenerated with `run-match-matrix.sh` (≈45 s per match). Whether they should be frozen into the repo is a decision for the mission owner.

---

## 10. Drift statement

- **Written** (all new): `tools/parity-godot/{ref-match.mjs, compare-match.mjs, run-match-gd.sh, run-match-matrix.sh, README.md, out/**}`, `godot/tests/parity/match_digest_gd.gd`, and this document.
- **Read only, hash-verified unchanged:** `scripts/parity-digest.mjs` (`2b24dd26…fdcd`), `js/game.js` (`c19277ad…55c9`), `js/data.js`, `js/i18n.js`, `godot/src/sim/**` (no edit — no divergence was found), `tools/parity/**`, `tools/sim-port/**`, `godot/game/**` (another lane is editing it; not touched, not executed).
- **`git status --porcelain`** shows only untracked trees (`docs/ godot/ tools/ meshy/ .claude/ scripts/parity-digest.mjs`) — via `git status --porcelain` reading only; no tracked file modified by this lane. No git write command was run.
- **Spend: $0** — 0 paid calls, 0 metered inference, no network access used by this lane. No Meshy credits.
