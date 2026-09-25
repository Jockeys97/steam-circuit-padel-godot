# Charge movement on a pad — the athlete no longer stops to charge

Repair session, 2026-09-20. Owner's report: *"I should be able to move/run and charge
a shot without the character stopping to charge."*

Nothing committed, nothing pushed. Working tree only, by the owner's standing rule for
repairs.

## What was wrong

`godot/game/input_map.gd` zeroed the left stick's movement vector for as long as a shot
button was held — the port of the reference's own freeze (`js/main.js:924`,
`g.move = { x: 0, y: 0 }`), plus the same one-tick freeze on the smash / cut-volley /
globo upgrade taps (`js/main.js:880`).

The **simulation never froze anyone**. It prices the charge in itself with
`chargeMovement` (0.58 solo, 0.32 co-op — `js/game.js:3072` / `:2748`, `sim.gd:2816` /
`:2673`), and the keyboard path has always moved through a charge at that speed, because
the keyboard's movement does not come from the stick the aim uses. The pad was therefore
the only device on which charging and running were mutually exclusive — and the pad is
what is plugged into this desk (`hidutil`: `XboxSeriesXGamepad`; the engine reports it as
device 0, name "Xbox One").

## Measured, before and after

Probe: `godot/_probe_charge_move.gd` (ad-hoc, project root, outside the sweep's hashed
trees). It injects real input events with `Input.parse_input_event`, **reads them back**
(an injection that did not register is reported as `INJECTION_FAILED`, never as a
result), then drives the shipping sampler, the shipping simulation and the shipping
athlete view. The gait word in the table is the live rig's own clip state
(`athlete_rig.get_pose()["locomotion"]`), not the probe's guess.

A rally state, not a serve (`tests/audits/controller_tactics_audit.gd::state_at_contact`
recipe): nothing human moves during a serve, and the serve positioner moves the server,
which reads as movement whatever the input says. Both traps were hit and corrected
before these numbers existed.

```
$GODOT --path godot/ --script res://_probe_charge_move.gd        # non-headless: a headless engine enumerates NO pads
```

| 60 ticks, `Xbox One` device 0, A held + left stick at 0.9 | sampled `moveX` | ground covered | rig gait |
|---|---|---|---|
| **committed sampler** | **0.000** | **0.00 px** | **idle** |
| **this change** | 0.852 (aim kept: `aim=0.891`, `analogAim=true`) | 75.19 px — 150.4 px/s | **run** |
| keyboard, Space + D, before AND after | 1.000 | 88.25 px — 176.5 px/s | run |
| keyboard, uncharged yardstick | 1.000 | 152.16 px — 304.3 px/s | run |

150.4 px/s is exactly `0.852 × 304.3 × 0.58`: the stick's own curved value, through the
reference's charge share. The keyboard row is identical before and after, which is the
point — this change is a no-op for the keyboard, which never froze.

## The change

`godot/game/input_map.gd` only:

- the two `move = Vector2.ZERO` assignments are gone (the charge hold and the upgrade
  taps), so the left stick always moves the athlete;
- the file header states the deviation from `js/main.js:924` as a **PORT ADDITION**, with
  its cost in the open: the stick that aims now also walks, ~184 px/s at a full charge
  (`0.58 × basePaddleSpeed 317`, `js/data.js:137`) — a quarter of the 800 px court across
  a 1.05 s charge.

No balance constant, no simulation line, no audit assertion was changed.

## The guard

`tests/input/switch_mode_audit.gd` — new section `_charge_keeps_the_feet` (question 7 in
its header), 6 checks:

- behavioural, through the real core: a charging tick moves the athlete, costs speed, and
  costs **exactly** 0.58 of the free travel (band 0.5–0.62, so co-op's 0.32 fails here),
  and `paddle.motion` stays above `athletes_view.gd`'s `RUN_MOTION`;
- source, because a headless engine enumerates no pads and a guard that only works on a
  desk with a controller is not a guard: no stripped line in `input_map.gd` is the
  assignment `move = Vector2.ZERO` (a line scan, so the file's own comment naming it is
  allowed), and the port-addition note is present.

Negative control: with the committed sampler restored, the section fails
`FAIL 89/91` — `expected 0, got 2` on the freeze scan and the missing note. With the
change, `PASS 91/91`.

## The sweep (clone at /private/tmp/padel-charge-check, so the owner's live game was never touched)

Serial, one engine process at a time, journalled to `sweep.log` + `runs-sweep/*.log`:

| run | exit | tally | SCRIPT ERROR |
|---|---|---|---|
| `tests/input/run_all.gd` | 0 | PASS 5/5 (399 checks, 0 failures, 7 not-ported) | 0 |
| `tests/audits/run_all.gd` | 0 | PASS 10/10 | 0 |
| `tests/game_slice_test.gd` | 1 | FAIL 344/345 | 0 |
| `tests/game_slice_test.gd -- --demo` | 1 | FAIL 295/296 | 0 |
| `tests/timing_feedback_test.gd` | 0 | PASS 100/100 | 0 |
| `tests/save_steam_test.gd` | 0 | PASS 137/137 | 0 |
| `tests/shot_logic_parity_test.gd` | 0 | PASS 675/675 | 0 |
| `tests/court_timing_marks_test.gd` | 0 | PASS 87/87 | 0 |

**The one red is pre-existing and not this change's.** Both slice runs fail the same
check, `locale table sizes match the reference (688 keys each): expected true, got
it=689 en=689` — one extra key in each locale table, which arrived with `8398e4c`
("feat(fornaio): add IL FORNAIO special athlete…", the `athlete_fornaio_name` pair). The
proof of ownership is scope, per `padel-godot-port-ops`: `git diff --stat` is
`godot/game/input_map.gd` plus this file's own audit section, and `git status --short` on
`godot/src/locale`, `tools/i18n-port` and `js/` is empty. The pack check is green here
(`godot/build/linux-x86_64/padel.pck` exported 2026-09-17, 138,142,952 bytes).

## What is NOT measured here

- **The pad's feel.** The rows above are numbers, not a verdict: whether running at 58 %
  of the stick reads as "running" or still as "stopping" while charging is the owner's
  call, and this Mac cannot capture a frame of the pad-driven charge.
- **Full-speed charging.** The charge still costs 42 % of the athlete's speed. Lifting it
  to 1.0 is a one-constant change, but it is a balance decision: it contradicts
  `controller_tactics_audit`'s `charge_slows_the_step` and the reference's own tune, so it
  is parked for the owner rather than taken.
- **360° aim while standing still.** With the stick moving the athlete, the aim and the
  heading are now the same stick: a shot cannot be lined up to one side while running the
  other way (that was the reference's reason for the freeze). The aim itself is unchanged
  and still absolute (`aim=0.891` sampled above).
