# Rules and simulation audits ported to Godot (slice S3)

- Date: 2026-09-16
- Baseline: git commit `2979588` (frozen web reference; `js/**` and `scripts/**`
  verified untouched — see §Boundaries)
- Godot: `/root/tools/godot/Godot_v4.7.2-stable_linux.x86_64`
  (`4.7.2-stable (official)`, build `ed1daf0bf001b61586d9930840f2f1394092c079`)
- Ticket: `docs/implementation/tickets/sim-rules-audits.md` (row S3 of
  `docs/implementation/PLAN.md`)
- Result: **10/10 audits ported and green**, `PASS 10/10`, 221 checks, 0 failures,
  0 assertions dropped. No divergence from the reference was found.

## What was built

Ten new Godot audits, one per reference audit, under their original name stems, each
runnable on its own, plus a combined runner:

| Reference audit (`scripts/`) | Godot audit | Checks | Exit | Summary line |
|---|---|---|---|---|
| `wall-rules-audit.mjs` | `godot/tests/audits/wall_rules_audit.gd` | 22 | 0 | `PASS 22/22` |
| `court-speed-audit.mjs` | `godot/tests/audits/court_speed_audit.gd` | 25 | 0 | `PASS 25/25` |
| `match-format-audit.mjs` | `godot/tests/audits/match_format_audit.gd` | 26 | 0 | `PASS 26/26` |
| `shot-quality-audit.mjs` | `godot/tests/audits/shot_quality_audit.gd` | 13 | 0 | `PASS 13/13` |
| `shot-balance-audit.mjs` | `godot/tests/audits/shot_balance_audit.gd` | 23 | 0 | `PASS 23/23` |
| `smash-input-audit.mjs` | `godot/tests/audits/smash_input_audit.gd` | 24 | 0 | `PASS 24/24` |
| `difficulty-audit.mjs` | `godot/tests/audits/difficulty_audit.gd` | 35 | 0 | `PASS 35/35` |
| `ai-attack-audit.mjs` | `godot/tests/audits/ai_attack_audit.gd` | 16 | 0 | `PASS 16/16` |
| `lineup-audit.mjs` | `godot/tests/audits/lineup_audit.gd` | 23 | 0 | `PASS 23/23` |
| `controller-tactics-audit.mjs` | `godot/tests/audits/controller_tactics_audit.gd` | 14 | 0 | `PASS 14/14` |
| — (runner) | `godot/tests/audits/run_all.gd` | 221 | 0 | `PASS 10/10` |

Support modules (not audits; the runner does not report them):

- `godot/src/audits/audit_base.gd` — the `ok` / `FAIL <name>: expected <x>, got <y>` /
  `PASS n/n` contract of `godot/tests/smoke_test.gd`, plus a `# not-ported <name>: <why>`
  line kind that never counts as a passed check.
- `godot/src/audits/audit_support.gd` — the `VUOTO`/`EMPTY_INPUT` scenario input, the
  seed injection (including the exact reproduction of `js/game.js:218`'s
  `(Math.random() * 0xffffffff) | 0`), the shared rally bench and the cleared
  serve-reception keys every AI-facing audit needs.

Evidence logs: `tools/audit-port/logs/` (`<name>_audit.log` per audit,
`run_all.log`, `individual-runs.txt` with every exit code, `engine-harness.log`,
`web-baseline.log`, and `<name>_audit.reference.log` = the reference audit's own
printed report).

## Exact invocations (verified verbatim on this host)

One audit:

```sh
cd /root/projects/steam-circuit-padel-pro && \
  flock -w 900 /tmp/padel-godot.lock timeout 180 \
  env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
  --script res://tests/audits/wall_rules_audit.gd
```

`timeout 180` is enough for eight of the ten. Two need more because their reference
sample counts are the expensive part and were NOT reduced:
`ai_attack` 47 s, `difficulty` 100 s, `shot_balance` 165 s — the runner's script
uses 600 s for those three. All ten, plus the runner, in one command:

```sh
cd /root/projects/steam-circuit-padel-pro && bash tools/audit-port/run-godot-audits.sh
# -> wall_rules exit=0 PASS 22/22 ... run_all exit=0 PASS 10/10 (script exit 0)
```

The combined runner (one log, one summary line, one exit code, 3 m 13 s):

```sh
cd /root/projects/steam-circuit-padel-pro && \
  flock -w 900 /tmp/padel-godot.lock timeout 1800 \
  env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/ \
  --script res://tests/audits/run_all.gd
# exit=0 ; "# totals checks=221 failures=0 not-ported=0" ; "PASS 10/10"
```

## Parity: the reference's own numbers, reproduced

The four statistical audits print the same report the reference prints, and the five
discrete ones assert the same values. Measured on this host:

| Audit | Reference (V8, `node scripts/<name>-audit.mjs`) | Port (Godot, `godot/src/sim/**`) |
|---|---|---|
| court-speed | ball 212 / 520 / 580 px/s; athletes 292 / 304 / 412; AI 281 / 378 | 211.6 / 520.4 / 580.2; 291.6 / 304.3 / 412.1; 280.9 / 378.1 |
| shot-quality | quality 1.000 / 0.642 / 0.779; energy 0.943 / 0.860; speed 227.1 / 357.4 | identical (same 6 decimals) |
| shot-balance | lob depth 210.2827 / 172.1167 / 119.3042; Pantera error 0.430; X3-medium 0.6033; repertoire 7 shots | 210.283 / 172.117 / 119.304; 0.430; 0.603; same 7 shots |
| difficulty | per tier: 280.9/313.7/352.9/378.1 px/s, 165/130/90/85 ms, 23.8/17.6/10.6/4.4 px, errors 0.275/0.138/0.071/0.032, serve return 1.0, X2 0.371/0.100/0.046/0.017, X3 0.938/0.592/0.321/0.279 | identical, field for field |
| ai-attack | short-lob attack 92%, forward 74 px, lobbed-against net/mid/back 53/29/12%, angles easy 41% / hard 57% | identical |
| lineup | racket 117.33 / 111.37; rival speed 406.5 / 287.7 (ref 313.7); shot power 428.2 / 335.2; energy 0.529 / 0.440 | identical |
| controller-tactics | movement split-step 3.14, charging 2.94, normal 5.07, sprint 5.07 | identical |
| smash-input | `smash-x2` / `smash-x3` / `smash-flat` / `bandeja` / `bandeja` / buffered `smash-x2` / missed `drive`+`player` | identical |
| wall-rules, match-format | no numeric report (discrete prompts) | same discrete outcomes, asserted |

The seed arithmetic is not approximated: `node tools/audit-port/seed-vectors.mjs`
prints V8's own `(seededRandom(seed)() * 0xffffffff) | 0` for the seeds the audits
use, and `run_all.gd`'s harness checks assert `Support.seeded_rng_state` against all
six of them (plus the `Math.random = () => 0.5` case). They agree exactly, which is
why the sampled audits reproduce the reference's samples rather than merely its bands.

## Reference assertions: ported, substituted, dropped

- **Ported: every assertion site in the ten reference audits.** Nothing was weakened,
  no case was dropped, no band was widened and no table was re-tuned. Checks that the
  reference writes as one `assert` over two conditions are split into two checks
  (`match-format`'s `deepEqual({p:5,a:5})` → two checks; `ai-attack`'s
  `aRete > aMeta && aMeta > alFondo` → two; `shot-balance`'s
  `shortLob > mediumLob && mediumLob > deepLob` → two), which can only make a red
  more visible, never less.
- **Substituted (ported, not dropped) — localized text is never compared.** The
  port's contract forbids asserting on translated strings (`sim-rules-audits.md`
  §Failure criteria) and the port stores message ids, so two assertions are made on
  the id the reference's label comes from:
  1. `shot-quality` asserts `shotFeedback.mode == "shotMode:control"` / `"shotMode:power"`
     where the reference compares `"CONTROLLO"` / `"POTENZA"`. Same value:
     `js/game.js:1070` builds the label as `t("shotMode" + Mode)` and
     `js/i18n.js:173-175` maps `shotModeControl` → `CONTROLLO`.
  2. `controller-tactics` asserts `state.events[0] == "tactic_attack"` where the
     reference compares `"Tattica di coppia: conquista la rete."`
     (`js/i18n.js:98`).
- **Not ported: none.** `not-ported=0` in the runner. Nothing in the ten audits
  depends on rendering, the DOM or browser-only state: every one drives
  `Sim.update_match` / `Sim.hit_ball` / `Sim.perform_serve` with a scripted per-tick
  input dictionary. `scripts/modules-audit.mjs` and
  `scripts/module-contract-audit.mjs` were never in this slice: they read the
  repository's file shape, not the game, and the ticket keeps them out.

## Divergences found

None. No audit in this slice reported a band failure, a discrete mismatch or a
position drift, so there is no finding for the sim core's owner and no entry for
`s3-divergences.md`. Two harness bugs found while porting were in **this slice's own
runner** and were fixed here, not in the core:

- the runner's `Math.random = () => 0.5` vector was computed with an extra `-1`
  (the helper takes the draw, the check passed the truncated product), and
- the runner asserted 24 fields for `Sim.empty_input()`, which carries 23.

Both were caught by the first full runner pass (that pass reported
`# totals checks=221 failures=0` with the two harness checks red, i.e. the ten audits
were already green) and are fixed in the recorded run below.
`s3-divergences.md` was not written, because writing one before all ten audits had run
is what the ticket forbids and there is nothing to put in it now that they have.

## Boundaries held

- Written: `godot/tests/audits/**`, `godot/src/audits/**`, `tools/audit-port/**`,
  this file. Nothing else.
- `js/**` and `scripts/**`: no file modified in the working window
  (`find js scripts -newermt '-4 hours'` returns nothing).
- `godot/src/sim/**`, `godot/src/audio/**`, `godot/src/locale/**`,
  `godot/src/character/**`, `godot/game/**`, `godot/project.godot` and the existing
  `godot/tests/*.gd` were not edited; no audit re-implements a physics or scoring
  rule, every one calls the ported core.
- The engine harness is still green: `--headless --path godot/` → `PASS 8/8`,
  exit 0 (`tools/audit-port/logs/engine-harness.log`).
- The web control is still green: `npm run audit` → `27/27 audit passano`, exit 0
  (`tools/audit-port/logs/web-baseline.log`).
- One heavy process at a time: every Godot invocation in this slice is wrapped in
  `flock -w 900 /tmp/padel-godot.lock` with `timeout` inside. Zero paid spend; no
  commit, push or deploy.

## Open questions this slice does not answer

- **Parity gate definition** (owner Luca, open): whether the four statistical audits
  (`court-speed`, `shot-balance`, `difficulty`, `ai-attack`) must be *sample
  identical* or *band identical*. On this host and this seed set they are sample
  identical, which is stronger than either reading — but that is a measurement, not
  a policy decision, and this slice does not treat it as one.
- **Web build strangler policy** (owner Luca, open): the comparisons above are
  measured against the frozen baseline `2979588`. If a different commit is named,
  the numbers are re-measured.
- The `controller-tactics` port drives the simulation with a per-tick dictionary.
  Whether a real gamepad reaches those fields is the input map's question, owned by
  the quick-match vertical slice, and is not touched here.

## How to reproduce

```sh
cd /root/projects/steam-circuit-padel-pro
bash tools/audit-port/run-godot-audits.sh                  # 10 audits + runner, exit 0
node tools/audit-port/seed-vectors.mjs                     # V8's own seed vectors
npm run audit                                              # control: 27/27, exit 0
flock -w 900 /tmp/padel-godot.lock env -u DISPLAY GODOT_SILENCE_ROOT_WARNING=1 \
  timeout 120 /root/tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot/
```

## File digests (as recorded)

| File | Bytes | sha256 |
|---|---|---|
| `godot/src/audits/audit_base.gd` | 5432 | `3c89d77015cf7950b76726f67120e476f11605cbcfc2890f2fcf424cc51fccd7` |
| `godot/src/audits/audit_support.gd` | 6450 | `11c6d738b664d9bbaa166504cd87a674c77b2d6bfd0d0029f5c6baea41d044cc` |
| `godot/tests/audits/wall_rules_audit.gd` | 11296 | `015f153eb0cbbec3fc4e5fc528ee2447dab55ce922c8c9c502e40966be9eed83` |
| `godot/tests/audits/court_speed_audit.gd` | 7635 | `2dea762bab29a2262add1837e311f2080bb9975e7d5e7befcfde2d3a92495abb` |
| `godot/tests/audits/match_format_audit.gd` | 7958 | `c65db38ff5120bbecf1708cc707eb7008753d7a53a3e117fa4ecaca1b75549c6` |
| `godot/tests/audits/shot_quality_audit.gd` | 5541 | `dafe0b55668253348c0ce7adf5fdd465313f4ec1361aeb27ebbd1418fdffcf58` |
| `godot/tests/audits/shot_balance_audit.gd` | 12266 | `d82405a7b77eafad151f302e14b916cef6624fc421ad29a2a98a1777bd69eb4f` |
| `godot/tests/audits/smash_input_audit.gd` | 8914 | `9bb0ed363e59563814bf667cf6ccc5f5d742e96e5f89de1c6ed9614f35f5528b` |
| `godot/tests/audits/difficulty_audit.gd` | 11722 | `6ea2d2aa9e62a714b5dea48b176772a334ac9bd9c6e717171d136fa4ae586379` |
| `godot/tests/audits/ai_attack_audit.gd` | 11790 | `928a5a9dedf2109726de62f5fa87991464cf17ff2b8a7e76e5ec4304ad56653f` |
| `godot/tests/audits/lineup_audit.gd` | 9487 | `d24e27890bffd95e35e85358a94aa7f1280acb7f66f7d4f87096e0354b4c8fa0` |
| `godot/tests/audits/controller_tactics_audit.gd` | 6791 | `9b2f3d74490790a66c414cca355df56d33621fed38ebd21851d0ebb5d2405e0c` |
| `godot/tests/audits/run_all.gd` | 5202 | `4e299fb8ec447359335dad7791bf3395aeee90d7fbba6f38befe569a1a3962f7` |
| `tools/audit-port/seed-vectors.mjs` | 1289 | `77be706ca5ee574f0da66bb1f4c7ba076d458d19a180f97f7f2157eb095306fa` |
| `tools/audit-port/run-godot-audits.sh` | 1791 | `7901149d0131844f358488f9d5cdf22e9c24a6afa0096a33935686a7d6c9436e` |
