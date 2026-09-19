# Game-pace presets: Realistic and the slower rungs

Date: 2026-09-19 · Repo `steam-circuit-padel-godot`, worktree `luca-game-mechanics`.

## What shipped

A player-selectable pace preset, reachable from Settings. The owner asked for a `Realistic`
rung plus scaled-down variants (`2:1`, `1.5:1`, "half the speeds") chosen so the game can be
played at true sport tempo and dialled back from there.

Five rungs, anchored on the real-padel crossing time rather than on taste:

| Preset | real : game | factor | smash | crossing 20 m |
|---|---|---|---|---|
| Realistic | 1:1 | 1.50 | 870 px/s | 584 ms |
| Brisk *(default)* | 1.5:1 | 1.00 | 580 px/s | 876 ms |
| Standard | 2:1 | 0.75 | 435 px/s | 1168 ms |
| Relaxed | 2.5:1 | 0.60 | 348 px/s | 1460 ms |
| Learning | 3:1 | 0.50 | 290 px/s | 1752 ms |

The anchor is the verified real band of 541 to 689 ms for a smash crossing, against the
876 ms measured in `tools/audit-port/logs/court_speed_audit.log`. A factor of 1.5 turns 876 ms
into 584 ms, inside that band, so 1.5 is `Realistic` and every other rung is a clean division
of it. The owner's current tuning is exactly the `1.5:1` rung: the game has been running at two
thirds of real padel pace, and the ladder corrects the zero point rather than inventing one.

## Why the clock, and not `BALANCE`

A preset is one number, `k`, applied to the `dt` that feeds the simulation
(`match_controller.advance_frame`, the accumulator and its catch-up cap). Multiplying every
speed by `k` is the same statement as dividing every duration by `k`, so scaling the sim's
rate is the exact implementation of "all speeds times `k`" rather than an approximation of it.

The consequence is the reason to prefer it: every trajectory, bounce point, angle, timing
window and therefore every balance ratio is preserved by construction, and the crossings
simply happen sooner. `BALANCE` in `js/data.js` and the frozen tables are never touched, so
browser parity holds and all three promises in `tests/audits/court_speed_audit.gd` keep
passing untended. Editing ball and player velocities separately would have changed the
trajectories instead: a projectile's range and flight time do not scale linearly in launch
speed, so the shapes would have drifted.

One clock, one seam: modes and drills are driven through the same accumulator
(`match_controller.gd:1274` → `session.step` → `mode_session.gd:256` → `drill.step`), so they
inherit the factor and must not scale again. `mode_screen.gd:380` steps a 120-frame warm-up
burst to compute drill list previews; it is a stat burst rather than a gameplay clock and is
deliberately left unscaled.

## Changing it by hand

`godot/src/sim/pace.gd` is the table. Edit a `factor`, or add a rung, and the setting row, the
save field and the tests follow. `Pace.default_id()` names the rung a fresh profile gets; it is
`brisk` so that nothing silently retunes for an existing player, and moving it to `realistic`
is the one-line change that makes true sport tempo the default.

The rungs carry their own display strings inside `pace.gd`, because `locale_data.gd` is
generated from `js/i18n.js` and `tools/i18n-port/verify-i18n-port.mjs` fails any key the
reference does not have. The UI lane's literal scan stays clean because no sentence is written
into a screen.

## Verification

| Gate | Result |
|---|---|
| `tests/pace_presets_test.gd` (new) | PASS, 59 checks |
| `tests/save_steam_test.gd` | PASS 138/138 |
| `tests/audits/court_speed_audit.gd` | PASS 25/25 |
| `_probe_pace_clock.gd` (ad-hoc, below) | PASS 16/16, 0 `SCRIPT ERROR` |
| `tools/i18n-port/hud-coverage.mjs --fail-on-leak` | exit 0 |
| `tests/game_slice_test.gd` | FAIL 342/343, sole red is the absent export pack |
| `tools/i18n-port/verify-i18n-port.mjs` | red, pre-existing |

The i18n verifier failure is not from this change: `godot/src/locale/`, `tools/i18n-port/` and
`js/` are unmodified, and the complaint is that `resolve-rules.json`'s recorded reference hash
no longer matches the live `js/i18n.js`, plus a key (`betaCareerNote`) the reference carries and
the port does not. It stands as it was found.

## The clock was measured, not inferred

The unit test proves the table. It cannot prove the table reaches the simulation, because
`advance_frame` is the only place real frame time becomes simulated time and no suite drives
it. So `godot/_probe_pace_clock.gd` (project root, outside the sweep's hashed trees) boots one
match per rung and counts the whole `FIXED_STEP` ticks a span of real frames buys:

```
ticks over 60 real frames: {brisk:120, learning:60, realistic:180, relaxed:72, standard:90}
```

60 frames at 1/60 is exactly 2.0 ticks per frame at factor 1.0, so these are exact integers
rather than a tolerance: 120 = the count this build ran before the feature existed, and the
rest are 120 × factor. The probe also asserts that an unknown stored id reads back as the
default with factor 1.0, so a save from a build without the key cannot stop the clock.

Run it with the import cache populated, or headless will report missing font and theme
resources and fail the HUD mount in the slice for reasons unrelated to any change:

```
"$GODOT" --headless --path godot/ --import
"$GODOT" --headless --path godot/ --script res://_probe_pace_clock.gd
```

## Open

- The ratio direction is read as game-relative-to-real: `2:1` is half of real pace. Inverting
  it is a `factor` edit per rung.
- The default is the current tuning, not `Realistic`. Flipping `default_id()` is one line.
- The drill list preview carries unscaled numbers, since it is computed from a warm-up burst
  rather than played.
- Nothing is committed. Spend $0 (owner's own Claude Code subscription).
